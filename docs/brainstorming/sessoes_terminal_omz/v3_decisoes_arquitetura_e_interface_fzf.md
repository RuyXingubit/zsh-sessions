# Brainstorming v3: Arquitetura 100% Terminal (Espírito OMZ), TUI com `fzf` e Anti-Lixo

**Data:** 2026-10-26
**Evolução sobre a v2:** Definição da Abordagem A (captura híbrida + diffs de arquivos editados) e escolha da interface 100% nativa de terminal via `fzf` (Opção 1), descartando geração de arquivos Markdown soltos para evitar acúmulo de lixo e manter a essência do Oh My Zsh.

---

## 1. Decisões Consolidadas até Agora
1. **Motor de Captura (Abordagem A):**
   - Captura nativa de `stdout`/`stderr` para comandos de linha de comando (com limite de linhas por comando para evitar logs gigantes).
   - Bypass automático para programas interativos de tela cheia (`vim`, `nvim`, `nano`, `less`, `htop`, `ssh`, `fzf`).
   - **Snapshot & Diff (`diff -u`)** automático para editores e modificadores de arquivos (ex.: `.yml`, `.json`, `.conf`), registrando exatamente as linhas adicionadas (`+`) e removidas (`-`).
   - **3 Camadas de Segurança:** Lista negra de arquivos sensíveis inteiros (`.env`, `.pem`, `.key`), mascaramento via regex (`[REDACTED]`) de senhas/tokens em saídas e diffs, e permissão `0600` nos arquivos de armazenamento.
2. **Interface 100% Terminal (`fzf`) — Espírito Oh My Zsh:**
   - Nada de exportar arquivos `.md` espalhados.
   - Armazenamento interno compacto e oculto dentro do diretório de dados do Zsh (`${XDG_DATA_HOME:-$HOME/.local/share}/omz-sessions`), estruturado apenas para alimentar a interface de terminal.
   - Identificador único de sessão usando **UUIDv7** (ordenável por timestamp de criação).

---

## 2. Como Evitar "Lixo" nas Sessões (Higiene Automática)
Uma preocupação central levantada é **não gerar lixo**. No dia a dia, muitas vezes abrimos uma aba do terminal só para rodar um `ls`, `git status` ou `clear` e fechamos. Se salvarmos tudo cegamente, a lista de sessões ficará poluída.

**Regras "Zero Lixo" Propostas:**
1. **Filtro de Sessões Triviais (Lazy Commit / Auto-Prune):**
   - Só persistir definitivamente a sessão se ela tiver substância (ex.: pelo menos 2 comandos relevantes, ou qualquer edição de arquivo/diff, ou se o usuário der um nome manual). Abas abertas apenas com `ls`, `cd`, `pwd`, `clear` ou `exit` são descartadas ao fechar.
2. **Deduplicação de Ruído:**
   - Comandos idênticos repetidos em sequência sem efeito (ex.: 5 `ls` seguidos) ou comandos vazios não poluem a linha do tempo.
3. **Limite de Retenção Configurável:**
   - Limpeza automática opcional de sessões não-favoritadas mais antigas que `N` dias (ex.: 30 ou 60 dias) ou limite de tamanho por output de comando (ex.: máx. 100 linhas por comando).

---

## 3. Experiência de Uso no Terminal (Comandos e Atalhos)

### A. Painel Interativo (`fzf` TUI)
Ao digitar um comando curto (ex.: `zs` ou `session`) ou pressionar um atalho de teclado (ex.: `Ctrl+G`):
- **Painel Esquerdo (Lista de Threads):**
  ```text
  [Data / Categoria]        [Projeto]       [Título / Resumo da Sessão]               [Cmds]
  Hoje 21:15 [DevOps]       bold-newton     Ajuste de portas e senha no docker-compose   8
  Hoje 18:40 [Git/Fix]      api-gateway     Resolução de conflito rebase main           14
  Ontem 16:10 [Config]      ~/.oh-my-zsh    Edição de plugins e testes de alias          6
  ```
- **Painel Direito (Preview Rolável da "Conversa"):**
  Mostra a linha do tempo completa do início ao fim daquela sessão, colorida com ANSI:
  - Horário, pasta, branch Git, duração e código de saída (`✓ 0` ou `✗ 1`).
  - Saída do comando (`stdout`/`stderr`).
  - Blocos de `diff` coloridos (verde para `+`, vermelho para `-`) de arquivos `.yml`/configs editados.

### B. Ações Rápidas dentro do `fzf` (ou via CLI)
- `Enter` -> **Retomar Sessão (Resume):** Entra na última pasta daquela sessão (`cd`), reativa o `SESSION_ID` (novos comandos passam a ser gravados na continuação dessa mesma conversa) e mostra os últimos comandos para você lembrar onde parou.
- `Ctrl+R` (ou `zs rename "Novo nome"`) -> **Renomear** manualmente a sessão.
- `Ctrl+A` (ou `zs ai`) -> **Categorizar com LLM:** Chama a API configurada (ex.: Gemini Flash) enviando apenas os comandos e diffs já sanitizados para gerar `[Categoria] Título curto`.
- `Ctrl+F` -> **Alternar Agrupamento:** Todos / Por Projeto (Pasta atual) / Por Categoria / Por Data.
- `Ctrl+D` -> **Apagar Sessão** selecionada.
