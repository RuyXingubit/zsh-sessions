# Brainstorming v4: Compatibilidade de Atalhos Multiplataforma (macOS, Linux, WSL e SSH)

**Data:** 2026-10-26
**Evolução sobre a v3:** Confirmação da regra "Zero Lixo" e análise profunda de compatibilidade de atalhos de teclado entre diferentes sistemas operacionais (macOS, Linux, Windows/WSL e sessões SSH).

---

## 1. O Problema Real dos Atalhos em Diferentes Sistemas Operacionais

A dúvida levantada pelo usuário é um dos pontos que mais quebram plugins de terminal mal projetados. No mundo dos terminais, as teclas se comportam de forma muito diferente dependendo do SO:

1. **Armadilha do `Alt` / `Option` no macOS:**
   - No Linux e Windows, `Alt + Letra` envia o código `ESC` seguido da letra.
   - No **macOS**, a tecla `Option` (`Alt`) por padrão **não funciona como atalho de terminal**; ela digita símbolos especiais da Apple (ex.: `Option+R` digita `®`, `Option+F` digita `ƒ`, `Option+X` digita `≈`). Exigir que o usuário configure "Use Option as Meta key" no Terminal/iTerm2/VS Code gera atrito.
2. **Armadilha do `Cmd (⌘)` no macOS vs `Ctrl` no Linux:**
   - O terminal nunca enxerga a tecla `Cmd` no Mac (o macOS intercepta antes para copiar/colar/abrir abas).
3. **Armadilha de Teclas Físicas Ausentes em Notebooks (`PageUp`, `PageDown`, `Delete`, `F1-F12`):**
   - Em MacBooks e notebooks compactos, não existem teclas dedicadas para `PageUp`/`PageDown`, e `F1-F12` mudam brilho/volume por padrão.
4. **Armadilha de Códigos Reservados do Kernel POSIX/TTY (`stty` e ASCII):**
   - Em qualquer Unix (Linux/macOS), algumas combinações de `Ctrl` são engolidas pelo driver do terminal ou se confundem com outras teclas no protocolo ASCII:
     - `Ctrl+S` / `Ctrl+Q`: Congelam o terminal (fluxo XON/XOFF).
     - `Ctrl+C` / `Ctrl+Z`: Matam ou suspendem o processo.
     - `Ctrl+M` é idêntico a `Enter` no protocolo ASCII; `Ctrl+I` é idêntico a `Tab`; `Ctrl+H` muitas vezes é `Backspace`.

---

## 2. Recomendações (Prós e Contras de cada abordagem)

### Decisão 1: Como ABRIR o gerenciador de sessões a partir do Zsh?

| Opção | Prós | Contras |
| :--- | :--- | :--- |
| **Comando curto `zs` (Padrão) + Atalho Opcional configurável** *(Recomendado)* | - `zs` + `Enter` funciona em **100% dos SOs** (macOS, Linux, WSL, SSH, terminal de navegador).<br>- Segue a diretriz oficial do Oh My Zsh de não sequestrar atalhos nativos do usuário sem permissão.<br>- Quem quiser atalho ativa em 1 linha (`zstyle` ou variável). | - Exige digitar 2 letras (`zs`) caso o usuário não ative o atalho de teclado. |
| **Forçar um atalho global no Zsh (ex.: `Ctrl+G`) por padrão** | - Abre com 1 combinação de teclas. | - Pode conflitar com atalhos que o usuário já usa no Zsh/Tmux/IDE e dificulta aprovação de PR no Oh My Zsh. |

### Decisão 2: Como executar ações DENTRO da interface do `fzf`?

Dentro do `fzf`, códigos `Ctrl + Letra` (bytes ASCII `0x01` a `0x1A`) funcionam de maneira **100% idêntica no macOS, Linux, Windows/WSL e SSH**, **desde que** a gente nunca use `Alt/Option`, nunca use `F1-F12` e escolha apenas letras `Ctrl` livres do kernel:

1. **Mapa de Teclas `Ctrl` Seguras (Universais POSIX/ASCII):**
   - `Enter` -> **Retomar** a sessão selecionada.
   - `Ctrl+R` -> **Renomear** a sessão.
   - `Ctrl+A` -> **Categorizar com IA** (LLM).
   - `Ctrl+F` -> **Alternar Filtro/Agrupamento** (Todas -> Pasta Atual -> Categoria -> Data).
   - `Ctrl+X` -> **Apagar** a sessão (evitando `Ctrl+D` ou `Backspace` para não apagar por acidente).
   - `Ctrl+U` / `Ctrl+D` (além do scroll do mouse e `Shift+↑`/`Shift+↓`) -> **Rolar a conversa (preview)** para cima e para baixo sem precisar de `PageUp`/`PageDown` em MacBooks!

2. **Menu de Ações via `Tab` ("Zero Decoreba de Atalhos" — Recomendação Extra):**
   - E se o usuário não quiser decorar `Ctrl+R`, `Ctrl+A`, `Ctrl+X`, ou estiver num terminal mobile/web onde o `Ctrl` é ruim de apertar?
   - Se o usuário apertar **`Tab`** em cima de uma sessão no `fzf` (ou se usarmos subcomandos `zs rename`, `zs ai`, `zs rm`), abre um sub-menu simples onde ele escolhe com as setas `↑`/`↓` e `Enter`:
     - `▶ Retomar sessão`
     - `✏️ Renomear sessão`
     - `🤖 Categorizar com IA`
     - `🗑️ Excluir sessão`
   - Isso garante **100% de funcionamento em absolutamente qualquer sistema operacional ou teclado**, porque só depende das setas e do `Enter`!
