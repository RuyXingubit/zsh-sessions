# Brainstorming v2: Captura de Saída (Output) e Diffs de Arquivos Editados

**Data:** 2026-10-26
**Evolução sobre a v1:** Inclusão obrigatória da saída dos comandos (`stdout`/`stderr`) e do histórico de alterações (diffs) em arquivos editados durante a sessão (ex.: `.yml`, `.env`, `.conf`), com sanitização de dados sensíveis e foco em evolução local visando futura contribuição ao Oh My Zsh.

---

## 1. Novos Requisitos Definidos pelo Usuário
1. **Salvar a saída dos comandos (`stdout`/`stderr`):** O histórico da sessão precisa mostrar não apenas o comando digitado, mas o que o terminal respondeu (erros, listagens, status, logs).
2. **Salvar o trecho editado de arquivos (Diffs):** Quando o usuário abre um arquivo (ex.: `vim docker-compose.yml` ou `nano config.yml`) ou altera via linha de comando (`sed`, `yq`, etc.) e adiciona/edita/remove linhas, a sessão deve registrar **quais linhas mudaram** (`diff`), mesmo em arquivos fora do Git.
3. **Exclusão rigorosa de dados sensíveis:** Tanto na saída dos comandos quanto nos diffs de arquivos editados, senhas, chaves, tokens e segredos devem ser mascarados (`[REDACTED]`) antes de ir para o disco ou para uma LLM.
4. **Estratégia de Entrega:** Construir e validar localmente no Zsh/OMZ até atingir uma versão sólida e usável, preparando o terreno para contribuição oficial ao projeto Oh My Zsh.

---

## 2. Arquitetura Técnica: Como resolver os 2 grandes desafios no Zsh

### Desafio A: Como capturar alterações dentro de arquivos (`.yml`, `.json`, `.conf`, etc.)?
Se tentarmos apenas gravar a tela enquanto o usuário usa `vim` ou `nano`, o arquivo de log fica cheio de códigos de controle ANSI/ncurses ilegíveis.

**Solução Proposta — "Snapshot & Diff Antes/Depois" (`preexec` + `precmd`):**
1. **No `preexec` (instante antes do comando rodar):**
   - O plugin analisa os argumentos do comando (ex.: `vim prod.yml`, `nano /etc/hosts`, `sed -i ... app.yml`).
   - Identifica quais argumentos são caminhos de arquivos (existentes ou prestes a serem criados naquele diretório).
   - Cria um snapshot temporário em memória/pasta segura (`chmod 0700`) do estado original do arquivo antes da edição.
   - *(Bônus)* Se estiver dentro de um repositório Git, também tira um snapshot rápido do `git diff` atual.
2. **No `precmd` (instante em que o comando/editor fecha):**
   - Compara o arquivo salvo com o arquivo antes da edição usando `diff -u` (Unified Diff).
   - Se houve alteração, passa o resultado do diff pelo **Motor de Sanitização (Redaction)** e anexa o trecho exato (`+` / `-`) ao registro daquele comando na sessão!
   - Remove imediatamente o snapshot temporário.

**Como fica na visualização da Sessão (estilo Antigravity):**
```text
[21:14:02] ~/projeto (main) $ vim docker-compose.yml  (exit: 0 | 18s)
  📝 Alterações em docker-compose.yml:
  @@ -10,4 +10,5 @@
     redis:
       image: redis:7-alpine
  -    ports: ["6379:6379"]
  +    ports: ["127.0.0.1:6379:6379"]
  +    command: redis-server --requirepass [REDACTED]
```

---

### Desafio B: Como capturar a saída (`stdout`/`stderr`) dos comandos sem quebrar o terminal?
No Unix/Zsh, se redirecionarmos todos os comandos cegamente para um pipe (`comando | tee log`), programas interativos de tela cheia (`vim`, `nano`, `htop`, `less`, `fzf`, `ssh`) quebram porque detectam que a saída não é um TTY direto.

**Opções Técnicas (Prós e Contras):**

1. **Opção 1: Captura Seletiva via Descritores de Arquivo (`exec > >(tee ...)`) com Bypass para TUI**
   - *Como funciona:* No `preexec`, se o comando **não** estiver na lista de programas de tela cheia (`vim`, `nano`, `htop`, `less`, `ssh`, `tmux`, `fzf`), o Zsh duplica temporariamente `stdout`/`stderr` para um arquivo de captura daquele comando, e restaura no `precmd`. Para editores (`vim`, `nano`), usa o *Snapshot & Diff* descrito acima.
   - *Prós:* 100% Zsh nativo (sem dependências binárias externas, ideal para ser aceito como plugin oficial do Oh My Zsh!). Não quebra editores nem menus interativos.
   - *Contras:* Comandos normais que mudam de cor apenas quando conectados direto ao TTY podem precisar de flag de cor ou perder coloração se não usarmos pseudo-terminal (`zpty`).

2. **Opção 2: Gravação de Sessão via `script` nativo do SO + Parser de Blocos**
   - *Como funciona:* O utilitário `script` (presente por padrão no macOS e Linux) envolve o shell em um Pseudo-Terminal (PTY), gravando tudo que passa pela tela sem quebrar cores.
   - *Prós:* Captura absolutamente tudo mantendo o comportamento de TTY.
   - *Contras:* Grava códigos de controle de cursor, barras de progresso e telas do `vim`, gerando arquivos pesados e sujos que exigem limpeza pesada de regex, além de iniciar um subshell extra.

3. **Opção 3 (Híbrida Recomendada): Captura via FD (`exec > >(tee)`) para comandos CLI + Snapshot Diff para Editores + Truncamento Inteligente**
   - *Como funciona:*
     - Comandos CLI comuns têm seu `stdout/stderr` capturado nativamente via hook do Zsh, com **limite máximo de linhas por comando** (ex.: primeiras 50 e últimas 50 linhas) para que um `cat arquivo_gigante.log` ou `docker logs` não trave nem lote o disco.
     - Comandos interativos (`vim`, `nano`, `nvim`, `less`, `htop`, `fzf`, `ssh`) rodam direto no TTY sem interceptação de pipe, e os editores acionam o **Rastreador de Diff**!

---

## 3. Camada de Segurança e Privacidade (Zero Vazamento de Segredos)
Antes de gravar qualquer output ou diff no arquivo da sessão:
1. **Bloqueio de Arquivos Sensíveis Inteiros:** Nunca gerar diff nem salvar conteúdo de arquivos como `.env`, `*.pem`, `*.key`, `id_rsa`, `credentials.json`, `.netrc`, `.aws/credentials` (registrar apenas: `🔒 [Arquivo sensível editado: .env - conteúdo omitido por segurança]`).
2. **Regex de Mascaramento (Redaction Engine):** Em arquivos `.yml`, `.json`, `.toml`, `.sh` e nas saídas de terminal, substituir valores de chaves que casem com `(password|passwd|pwd|secret|token|api_key|apikey|access_key|auth|bearer|private_key)` ou formatos conhecidos (`ghp_...`, `sk-...`, `AKIA...`, `eyJ...` JWT) por `[REDACTED]`.
