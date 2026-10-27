# PRD Oficial: Plugin `zs` (Oh My Zsh Session Threads)

**Data de Consolidação:** 2026-10-26
**Status:** Aprovado para Implementação
**Histórico de Brainstorming:**
- [v1_conceito_inicial.md](file:///Users/ruy/Documents/antigravity/bold-newton/docs/brainstorming/sessoes_terminal_omz/v1_conceito_inicial.md)
- [v2_captura_output_e_diffs.md](file:///Users/ruy/Documents/antigravity/bold-newton/docs/brainstorming/sessoes_terminal_omz/v2_captura_output_e_diffs.md)
- [v3_decisoes_arquitetura_e_interface_fzf.md](file:///Users/ruy/Documents/antigravity/bold-newton/docs/brainstorming/sessoes_terminal_omz/v3_decisoes_arquitetura_e_interface_fzf.md)
- [v4_compatibilidade_atalhos_multiplataforma.md](file:///Users/ruy/Documents/antigravity/bold-newton/docs/brainstorming/sessoes_terminal_omz/v4_compatibilidade_atalhos_multiplataforma.md)
- [v5_gestao_categorias_manuais_e_fluxo_fechamento.md](file:///Users/ruy/Documents/antigravity/bold-newton/docs/brainstorming/sessoes_terminal_omz/v5_gestao_categorias_manuais_e_fluxo_fechamento.md)

---

## 1. Visão Geral do Produto
Um plugin nativo para **Oh My Zsh / Zsh** que transforma as sessões diárias do terminal em **"conversas/threads" persistentes, auditáveis e retomáveis** (inspirado no fluxo de conversas do Antigravity), operando 100% dentro do terminal sem gerar arquivos soltos nos projetos.

---

## 2. Requisitos Funcionais Consolidados

### RF01 — Identificação Cronológica com UUIDv7
- Cada sessão de terminal recebe um identificador único no formato **UUIDv7 (RFC 9562)**, embutindo o timestamp em milissegundos nos primeiros 48 bits para ordenação cronológica nativa.

### RF02 — Motor de Captura Híbrida (`preexec` / `precmd`)
1. **Metadados por Comando:** Horário, diretório (`pwd`), branch Git (se houver), comando executado, duração em segundos e código de retorno (`exit code`).
2. **Captura de Saída (`stdout` / `stderr`):**
   - Comandos comuns de CLI têm sua saída capturada (limitada por padrão às primeiras/últimas linhas configuráveis para evitar explosão de disco).
   - Programas interativos de tela cheia (`vim`, `nvim`, `nano`, `vi`, `micro`, `less`, `more`, `htop`, `top`, `Btop`, `tmux`, `ssh`, `fzf`, `man`) passam por *bypass* automático de pipe para não quebrar a interface TTY.
3. **Captura de Trechos Editados (`Snapshot & Diff`):**
   - Quando um comando edita ou toca arquivos (ex.: `vim docker-compose.yml`, `nano config.yml`, `sed -i ...`), o plugin tira um snapshot seguro antes da execução e calcula o `diff -u` após o fechamento, gravando na linha do tempo da sessão exatamente as linhas adicionadas (`+`) e removidas (`-`).

### RF03 — Regra "Zero Lixo" (Higiene Automática)
- **Filtro de Abas Triviais:** Sessões que contenham apenas comandos triviais de navegação/consulta rápida (`ls`, `ll`, `la`, `cd`, `pwd`, `clear`, `exit`, `zs`) sem edições de arquivo e sem categoria manual definida são descartadas automaticamente no fechamento.
- **Deduplicação de Ruído:** Comandos idênticos repetidos em sequência imediata sem alteração de arquivo não são duplicados consecutivamente.

### RF04 — Gestão de Categorias (100% Manual por Padrão + IA Opcional)
1. **Categorias do Usuário:**
   - Criar categorias (`zs cat add <nome>`).
   - Listar categorias (`zs cat list`).
   - Classificar a sessão atual ou sessões anteriores (`zs cat`).
2. **Interceptação no Fechamento (`exit` / `Ctrl+D`):**
   - Se a sessão atual passou pelo filtro "Zero Lixo" e **ainda não possui categoria**, o plugin intercepta o fechamento e pergunta ao usuário se deseja:
     - Adicionar a uma **categoria existente**;
     - **Criar uma nova categoria** na hora;
     - Salvar sem categoria para classificar depois; ou
     - Descartar a sessão.
3. **Proteção contra Fechamento Forçado (`Cmd+W` / `SIGHUP`):**
   - Caso a janela seja destruída pelo sistema operacional (`SIGHUP`), a sessão válida sem categoria é salva como `[Sem Categoria]`.
   - Na abertura de uma nova aba, um aviso discreto informa caso existam sessões pendentes de categorização (`zs pending` / `zs cat`).
4. **Categorização e Título via LLM (Opcional):**
   - Se o usuário configurar uma chave de API (`GEMINI_API_KEY` ou `OPENAI_API_KEY`), pode acionar `zs ai` (ou `Ctrl+A` no `fzf`) para gerar automaticamente a categoria e o título da sessão a partir do resumo sanitizado.

### RF05 — Interface 100% Terminal (`fzf`) e Compatibilidade Multiplataforma
- **Abertura:** Comando curto `zs` (universal) + atalho opcional configurável.
- **Painel `fzf`:**
  - Esquerda: Lista de sessões com Data, `[Categoria]`, Projeto/Pasta, Título e contagem de comandos.
  - Direita: Preview rolável completo do início ao fim da conversa (comandos, saídas e diffs coloridos).
- **Atalhos Multiplataforma (macOS, Linux, WSL, SSH):**
  - `Enter`: Retomar a sessão selecionada (restaura diretório `cd`, vincula o `UUIDv7` ativo para continuar gravando na mesma conversa e exibe os últimos comandos).
  - `Tab`: Abre o **Menu de Ações** navegável por setas (`Retomar`, `Mudar/Criar Categoria`, `Renomear`, `Categorizar com IA`, `Excluir`).
  - `Ctrl+R`: Renomear título da sessão.
  - `Ctrl+T`: Definir/Criar Categoria para a sessão.
  - `Ctrl+F`: Filtrar por Categoria ou Projeto.
  - `Ctrl+A`: Categorizar/Resumir com IA.
  - `Ctrl+X`: Excluir sessão.
  - `Ctrl+U` / `Ctrl+D`: Rolar o painel da conversa para cima/baixo.

---

## 3. Requisitos de Segurança (Security First)
1. **Permissões de Armazenamento:** Diretório de sessões (`0700`) e arquivos (`0600`), acessíveis exclusivamente pelo usuário dono.
2. **Lista Negra de Arquivos Sensíveis:** Arquivos como `.env`, `.env.*`, `*.pem`, `*.key`, `id_rsa*`, `id_ed25519*`, `*credentials*`, `.netrc` **nunca** têm o conteúdo do diff gravado (registra-se apenas `🔒 [Arquivo sensível editado: <nome> — diff omitido por segurança]`).
3. **Motor de Redaction (Mascaramento):** Qualquer saída de comando, argumento ou diff contendo chaves sensíveis (`password`, `passwd`, `secret`, `token`, `api_key`, `apikey`, `access_key`, `private_key`, `authorization`, `bearer`) ou formatos de tokens (`ghp_`, `sk-`, `AKIA`, `AIza`, JWT `eyJ`) tem seu valor substituído por `[REDACTED]` antes de tocar o disco.
4. **Respeito ao Espaço Inicial:** Comandos iniciados por espaço em branco são ignorados pelo gravador.
