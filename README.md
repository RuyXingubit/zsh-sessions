# zsh-sessions (`zs`)

Plugin para **Oh My Zsh / Zsh** que organiza suas sessões diárias de terminal como **conversas/threads persistentes e retomáveis**, capturando comandos, saídas (`stdout`/`stderr`) e trechos editados de arquivos (`diff -u`), com proteção nativa de dados sensíveis (`[REDACTED]`), regra "Zero Lixo" e interface interativa no terminal via `fzf`.

---

## Principais Funcionalidades

* **IDs Cronológicos (UUIDv7 - RFC 9562):** Cada aba do terminal recebe um identificador único ordenável por timestamp em milissegundos.
* **Captura de Saída + Diff de Arquivos Editados:**
  * Registra o que os comandos imprimiram na tela (`stdout`/`stderr`) sem quebrar programas interativos (`vim`, `nano`, `htop`, `less`, `ssh`).
  * Quando um arquivo (ex.: `docker-compose.yml`, `config.json`) é editado durante a sessão, grava o **diff exato (`+` / `-`)** das linhas alteradas.
* **Segurança em Primeiro Lugar (Redaction Nativo):**
  * Arquivos sensíveis (`.env`, `*.pem`, `*.key`, `id_rsa`, `credentials`) nunca têm seu conteúdo exposto no diff.
  * Senhas, tokens, chaves de API (`password`, `secret`, `token`, `api_key`, `ghp_...`, `sk-...`, `AKIA...`, JWTs) são mascarados automaticamente como `[REDACTED]`.
  * Armazenamento local restrito com permissões `0700`/`0600`.
* **Regra "Zero Lixo":** Abas abertas apenas com comandos triviais (`ls`, `cd`, `pwd`, `clear`, `exit`) sem alterações de arquivos são descartadas automaticamente ao fechar.
* **Categorias Manuais (Sem depender de LLM) + IA Opcional:**
  * Crie suas próprias categorias (`zs cat add "DevOps"`) e organize suas conversas.
  * Ao fechar uma sessão relevante sem categoria (`exit`), o plugin pergunta se deseja adicioná-la a uma categoria existente ou criar uma nova.
  * Se fechar a janela no `Cmd+W`, salva como `[Sem Categoria]` e avisa discretamente na próxima sessão.

---

## Instalação no Oh My Zsh

```zsh
git clone https://github.com/RuyXingubit/zsh-sessions.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-sessions
```

Adicione `zsh-sessions` à lista de plugins no seu `~/.zshrc`:

```zsh
plugins=(... zsh-sessions)
```

---

## Comandos (`zs`)

| Comando | Descrição |
| :--- | :--- |
| `zs` | Abre o painel interativo (`fzf`) com a lista de sessões à esquerda e a conversa completa à direita |
| `zs status` | Mostra os dados da sessão atual (UUIDv7, projeto, categoria, contagem de comandos) |
| `zs show [id]` | Exibe o histórico completo (comandos, saídas e diffs coloridos) da sessão |
| `zs resume <id>` | Retoma uma sessão anterior (faz `cd` para a última pasta e continua gravando na mesma conversa) |
| `zs rename "<título>"` | Define um título personalizado para a sessão |
| `zs cat` | Abre o seletor para classificar a sessão em uma categoria existente ou criar uma nova |
| `zs cat add "<nome>"` | Cria uma nova categoria |
| `zs cat list` | Lista todas as categorias e a quantidade de sessões em cada uma |
| `zs ai [id]` | Classifica e gera título automaticamente (usa `GEMINI_API_KEY` se definida ou heurística local) |
| `zs rm <id>` | Remove uma sessão específica |

---

## Atalhos Multiplataforma no Painel `fzf` (macOS, Linux, WSL, SSH)

* `Enter`: Retomar a sessão selecionada
* `Tab`: Abrir o **Menu de Ações** navegável por setas (`Retomar`, `Mudar/Criar Categoria`, `Renomear`, `Categorizar com IA`, `Excluir`)
* `Ctrl+T`: Mudar ou criar Categoria
* `Ctrl+R`: Renomear sessão
* `Ctrl+F`: Alternar filtro (Todas / Projeto Atual / Por Categoria)
* `Ctrl+A`: Categorizar com IA
* `Ctrl+X`: Excluir sessão
* `Ctrl+U` / `Ctrl+D`: Rolar a conversa para cima / para baixo
