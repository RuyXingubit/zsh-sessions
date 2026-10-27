# Brainstorming v5: Gestão de Categorias pelo Usuário (Sem LLM) e Fluxo no Fechamento da Sessão

**Data:** 2026-10-26
**Evolução sobre a v4:** Foco na autonomia total do usuário sem depender de API de LLM — permitindo criar categorias próprias, organizar conversas dentro delas e solicitar categorização ao encerrar uma sessão que ainda não possua categoria.

---

## 1. Novos Requisitos Definidos pelo Usuário
1. **Independência de LLM:** O uso de API de LLM deve ser 100% opcional. O sistema principal de categorias deve funcionar perfeitamente de forma manual/local pelo próprio usuário.
2. **Criação e Gestão de Categorias:** O usuário pode criar categorias primeiro (ex.: `Infra`, `Bugfix`, `Deploy`, `Cliente-X`, `Estudos`) e colocar as sessões/conversas dentro delas.
3. **Verificação no Fechamento da Sessão:** Se uma sessão válida (que passou pelo filtro "Zero Lixo") estiver sendo fechada e **ainda não tiver uma categoria atribuída**, o sistema deve perguntar se o usuário quer:
   - Adicionar a uma **categoria existente**; ou
   - **Criar uma nova categoria** na hora e vinculá-la.

---

## 2. Como Funciona na Prática: Comportamento no Fechamento da Sessão

No terminal (macOS/Linux), existem **duas formas** de uma sessão ser encerrada, e precisamos tratar ambas com elegância:

### Cenário A: Fechamento via Teclado (`exit` ou `Ctrl+D`) — *Interativo na Hora*
Quando o usuário digita `exit` (ou pressiona `Ctrl+D`), a janela do terminal **ainda está aberta e ativa**.
1. O plugin intercepta o comando `exit` / `EOF` antes de encerrar o processo do Zsh.
2. Verifica a regra **Zero Lixo**:
   - Se a sessão só teve comandos triviais (`ls`, `cd`, `pwd`), fecha silenciosamente e descarta.
3. Se a sessão teve comandos relevantes/edições de arquivos e **já possui categoria** (definida antes pelo usuário), salva e fecha imediatamente.
4. Se a sessão é relevante e **NÃO possui categoria**:
   - Exibe o seletor rápido (`fzf` ou prompt compacto):
     ```text
     📂 Esta sessão (8 comandos) ainda não tem categoria:
       > [+] Criar nova categoria...
         📁 DevOps / Docker
         📁 Backend API
         📁 Banco de Dados
         ⏭️  Salvar sem categoria (classificar depois)
         🗑️  Descartar esta sessão
     ```
   - Se escolher **[+] Criar nova categoria...**, o usuário digita o nome (ex.: `Rede-Neutra`), ela é salva na lista de categorias permanentes e a sessão já é guardada dentro dela antes de fechar a aba!

### Cenário B: Fechamento Forçado da Janela (Botão `X` ou `Cmd+W`) — *Recuperação Segurança*
- **Explicação técnica:** Quando o usuário aperta `Cmd+W` no Mac ou clica no `X` da janela com o mouse, a interface gráfica destrói a janela instantaneamente e envia um sinal `SIGHUP` para o Zsh em segundo plano. Nesse milissegundo final não existe mais tela para abrir um menu.
- **Como resolver sem perder nada:**
  - O hook `zshexit` salva a sessão automaticamente com a tag `[Sem Categoria]`.
  - Na próxima vez que o usuário abrir o painel `zs` (ou por um aviso discreto no topo da próxima aba: *"💡 1 sessão anterior aguarda categoria — digite `zs cat`"*), ele atribui a uma categoria existente ou cria uma nova em 2 segundos!

---

## 3. Comandos e Atalhos de Categorias (100% Manual ou Híbrido)

1. **Gerenciar Categorias a qualquer momento:**
   - `zs cat` -> Abre o seletor de categorias para classificar a sessão atual (escolhendo uma existente ou criando uma nova).
   - `zs cat add "Nome da Categoria"` -> Cria uma categoria nova vazia pronta para uso.
   - `zs cat list` -> Lista suas categorias e quantas conversas existem em cada uma.
2. **Dentro do painel `fzf` (`zs`):**
   - Ao navegar pelas conversas passadas, o usuário pode apertar `Ctrl+T` (ou escolher no menu `Tab` -> `📂 Mudar Categoria`) para mover qualquer conversa para uma categoria existente ou criar uma categoria nova na hora.
   - E com `Ctrl+F` (Filtro), ele pode filtrar por uma categoria específica: abre a lista das categorias dele, ele escolhe p.ex. `DevOps`, e o `fzf` mostra apenas as conversas daquela categoria!
