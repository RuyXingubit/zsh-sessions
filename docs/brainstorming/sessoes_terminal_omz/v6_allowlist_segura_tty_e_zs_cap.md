# v6 — Allowlist Segura de Captura (`ZS_CAPTURE_MODE="safe"`) e Proteção Total de `isatty(1)` / TUI (`agy`, `git`, REPLs)

**Data:** 2026-11-01
**Contexto:** Ao executar `agy` (Antigravity CLI), a aplicação não abria sua interface interativa porque o hook `_zs_preexec` redirecionava globalmente `fd 1` (`stdout`) e `fd 2` (`stderr`) para um pipe `>(tee ... > /dev/tty)`. Como um pipe não é um dispositivo TTY (`isatty(1) == 0` / `process.stdout.isTTY == false`), qualquer CLI moderna que consulte `isatty(1)` ou `ioctl(1, TIOCGWINSZ)` no `stdout` (como `agy`, `gemini`, `git commit`, `python`, `node`, `flutter run`, etc.) falha ao abrir a TUI, perde cores ou entra em modo pipe aguardando `EOF`.

---

## 1. Decisão Arquitetural Aprovada (Opção 1)

Substituir a interceptação global de `fd 1`/`fd 2` baseada em *Blocklist* por uma arquitetura de **Allowlist Segura (`ZS_CAPTURE_MODE="safe"` por padrão) + Subcomando Explícito `zs cap <cmd>`**:

1. **Preservação Nativa de `isatty(1)` por Padrão:**
   - Para qualquer aplicação interativa, TUI, REPL, ferramenta de desenvolvimento (`agy`, `antigravity`, `gemini`, `claude`, `codex`, `git`, `docker`, `kubectl`, `python`, `node`, `flutter`, `npm`, `brew`, scripts `.sh`, etc.), o `zsh-sessions` **jamais redireciona `fd 1` ou `fd 2`**.
   - Os descritores `0`, `1` e `2` permanecem 100% conectados ao pseudo-terminal real (`/dev/tty`).
   - O plugin continua gravando automaticamente em **100% dos comandos**:
     - Linha de comando executada (com mascaramento `[REDACTED]`),
     - Timestamp, diretório (`PWD`), branch do Git, duração (`0s`) e código de saída (`exit`),
     - **Todos os `diff -u` de arquivos editados** (`.yml`, `.json`, `.conf`, etc.) via motor de *Snapshot & Diff* (que opera em disco sem tocar no `stdout`/`TTY`).

2. **Allowlist Segura (`ZS_CAPTURE_MODE="safe"`):**
   - A captura automática de `stdout`/`stderr` via `tee` em `_zs_preexec` só ocorre quando:
     - `ZS_CAPTURE_OUTPUT=1` e `ZS_CAPTURE_MODE="safe"` (padrão),
     - O comando é simples (sem pipes `|`, encadeamentos `&&`/`;`, execução em background `&` ou redirecionamentos `>`),
     - E o binário pertence à lista branca de comandos puros de inspeção/texto não-interativos (`cat`, `head`, `tail`, `wc`, `stat`, `file`, `uname`, `hostname`, `whoami`, `id`, `groups`, `date`, `uptime`, `df`, `du`, `free`, `env`, `printenv`, `which`, `whereis`, `expr`, `seq`, `basename`, `dirname`, `tr`, `cut`, `sort`, `uniq`, `md5`, `md5sum`, `shasum`, `sha256sum`, `dig`, `nslookup`, `host`, `ifconfig`, `ip`, `route`, `arp`, `netstat`, `ss`, `lsof`, `ps`, `lsblk`, `sysctl`, `echo`, `printf`, `curl`, além de comandos extras definidos pelo usuário em `$ZS_SAFE_CAPTURE_CMDS`).

3. **Captura Sob Demanda (`zs cap <comando...>`):**
   - Novo subcomando `zs cap <comando...>` (ou `zs run <comando...>`) para quando o usuário desejar gravar explicitamente toda a saída (`stdout`/`stderr`) de qualquer comando ou script fora da allowlist dentro do log da sessão, exibindo na tela em tempo real e salvando no histórico.
