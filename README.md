# zsh-sessions plugin

This plugin organizes daily terminal sessions into **persistent, resumable conversation threads** (`zs`). It records executed commands, command outputs (`stdout`/`stderr`), and unified diffs (`diff -u`) of edited files (such as `.yml`, `.json`, or `.conf`), while automatically redacting secrets (`[REDACTED]`) and discarding trivial noise sessions.

To use it, add `zsh-sessions` to the plugins array in your `~/.zshrc` file:

```zsh
plugins=(... zsh-sessions)
```

> **Optional dependency:** Install [`fzf`](https://github.com/junegunn/fzf) (`brew install fzf` or `apt install fzf`) to enable the split-screen terminal interface with live conversation preview. When `fzf` is not installed, `zs` automatically falls back to a built-in numbered interactive menu.

## Usage

Every interactive shell session automatically receives a chronological **UUIDv7** identifier. As you work, `zsh-sessions` records:

1. **Command metadata:** Timestamp, working directory (`PWD`), Git branch, duration, and exit status.
2. **Command output (`stdout`/`stderr`):** Captures CLI output (truncated to `ZS_MAX_OUTPUT_LINES`) while automatically bypassing interactive full-screen TUI applications (`vim`, `nvim`, `nano`, `less`, `htop`, `ssh`, `tmux`, `fzf`).
3. **Edited file diffs (`Snapshot & Diff`):** When a command or editor modifies a configuration/source file (e.g., `vim docker-compose.yml`), records a clean `diff -u` block showing added (`+`) and removed (`-`) lines.
4. **Zero-Junk Filtering:** Sessions containing only trivial navigation commands (`ls`, `cd`, `pwd`, `clear`, `exit`) with no file modifications are automatically discarded on exit.
5. **Category Prompt on Exit:** When closing a meaningful session via `exit` that has not yet been categorized, `zs` prompts you to assign it to an existing category or create a new one on the spot. If the terminal window is closed abruptly (`SIGHUP` / <kbd>Cmd</kbd> + <kbd>W</kbd>), the session is preserved as `[Sem Categoria]` and a one-line notice is shown on the next shell startup.

## Commands

| Command | Description |
| :--- | :--- |
| `zs` | Open the interactive session threads TUI (`fzf` split view or numbered menu) |
| `zs status` | Display current session metadata (UUIDv7, project, category, command count) |
| `zs show [id]` | Display the full colorized timeline (commands, outputs, and file diffs) of a session |
| `zs resume <id>` | Resume a previous session (`cd` into its last directory and continue appending to that thread) |
| `zs rename "<title>" [id]` | Set a custom title for the current or specified session |
| `zs cat` | Interactively assign the session to an existing category or create a new one |
| `zs cat add "<name>"` | Create a new category |
| `zs cat list` | List all categories and the number of sessions in each |
| `zs cat set "<cat>" [id]` | Assign a category to the current or specified session |
| `zs ai [id]` | Auto-categorize and title a session (uses `GEMINI_API_KEY` if set, or local heuristics) |
| `zs rm <id>` | Delete a saved session |
| `zs help` | Display help information |

## Keyboard Shortcuts (inside `zs` / `fzf`)

All shortcuts use portable POSIX/ASCII control codes that work identically across macOS, Linux, WSL, and SSH:

| Shortcut | Description |
| :--- | :--- |
| <kbd>Enter</kbd> | Resume the selected session (`cd` + continue thread) |
| <kbd>Tab</kbd> | Open the arrow-navigable **Action Menu** (`View`, `Resume`, `Category`, `Rename`, `AI`, `Delete`) |
| <kbd>Ctrl</kbd> + <kbd>T</kbd> | Assign or create a Category for the selected session |
| <kbd>Ctrl</kbd> + <kbd>R</kbd> | Rename the selected session |
| <kbd>Ctrl</kbd> + <kbd>F</kbd> | Cycle session filters (`ALL` → `Current Project` → `By Category`) |
| <kbd>Ctrl</kbd> + <kbd>A</kbd> | Auto-categorize and title session (`AI` / heuristics) |
| <kbd>Ctrl</kbd> + <kbd>X</kbd> | Delete the selected session |
| <kbd>Ctrl</kbd> + <kbd>U</kbd> / <kbd>Ctrl</kbd> + <kbd>D</kbd> | Scroll the right-hand conversation preview up / down |

## Security & Privacy

* **Strict File Permissions:** Session storage is created with `0700` directory permissions and `0600` file permissions.
* **Sensitive File Blocklist:** Files matching `.env*`, `*.pem`, `*.key`, `id_rsa*`, `id_ed25519*`, `*credentials*`, `.netrc`, `.npmrc`, or `.pypirc` never have their contents or diffs recorded.
* **Automatic Secret Redaction:** Values assigned to keys matching `password`, `passwd`, `pwd`, `secret`, `token`, `api_key`, `access_key`, `private_key`, `auth`, `bearer`, `database_url`, CLI flags (`--requirepass`, `--password`, `--token`), URL credentials, and token prefixes (`ghp_`, `gho_`, `github_pat_`, `sk-`, `AKIA`, `AIza`, JWTs) are masked with `[REDACTED]` before touching disk.
* **`HIST_IGNORE_SPACE` Compliance:** Commands prefixed with a leading space are ignored.

## Configuration

You can customize the plugin behavior by setting these variables in your `~/.zshrc` before Oh My Zsh loads:

* `ZS_DATA_DIR`: Directory where session indexes and logs are stored (default: `${XDG_DATA_HOME:-$HOME/.local/share}/zsh-sessions`).
* `ZS_CAPTURE_OUTPUT`: Set to `0` to disable `stdout`/`stderr` capture while keeping command and file diff tracking (default: `1`).
* `ZS_MAX_OUTPUT_LINES`: Maximum number of output lines stored per command before truncating the middle section (default: `60`).
* `ZS_MIN_MEANINGFUL_CMDS`: Minimum number of non-trivial commands required to persist a session without diffs or manual metadata (default: `2`).
* `ZS_BINDKEY`: Optional ZLE keyboard shortcut to launch `zs` directly from the prompt (e.g., `export ZS_BINDKEY="^G"`).
* `GEMINI_API_KEY`: Optional Google Gemini API key used by `zs ai` to generate smart session titles and categories from sanitized command summaries.
