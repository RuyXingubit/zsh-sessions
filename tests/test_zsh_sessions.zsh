#!/usr/bin/env zsh
# ==============================================================================
# Unit Test Suite for zsh-sessions (zs)
# Run with: zsh tests/test_zsh_sessions.zsh
# ==============================================================================

setopt ERR_EXIT PIPE_FAIL

TEST_ROOT=$(mktemp -d "${${TMPDIR:-/tmp}%/}/zs_unit_tests.XXXXXX")
export ZS_DATA_DIR="$TEST_ROOT/data"
WORKSPACE_TMP="$TEST_ROOT/workspace"
mkdir -p "$WORKSPACE_TMP"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

PLUGIN_PATH="${0:A:h:h}/zsh-sessions.plugin.zsh"
source "$PLUGIN_PATH"

integer PASS_COUNT=0
integer FAIL_COUNT=0

assert_eq() {
  local expected="$1"
  local actual="$2"
  local msg="$3"
  if [[ "$expected" == "$actual" ]]; then
    print -P "%F{green}  ✓ PASS:%f $msg"
    (( PASS_COUNT++ )) || true
  else
    print -P "%F{red}  ✗ FAIL:%f $msg"
    print -r -- "    Expected: '$expected'"
    print -r -- "    Actual:   '$actual'"
    (( FAIL_COUNT++ )) || true
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local msg="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    print -P "%F{green}  ✓ PASS:%f $msg"
    (( PASS_COUNT++ )) || true
  else
    print -P "%F{red}  ✗ FAIL:%f $msg"
    print -r -- "    Missing '$needle' in:"
    print -r -- "$haystack"
    (( FAIL_COUNT++ )) || true
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local msg="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    print -P "%F{green}  ✓ PASS:%f $msg"
    (( PASS_COUNT++ )) || true
  else
    print -P "%F{red}  ✗ FAIL:%f $msg"
    print -r -- "    Found forbidden '$needle' in:"
    print -r -- "$haystack"
    (( FAIL_COUNT++ )) || true
  fi
}

print -P "\n%B=== 1. Testes de UUIDv7 (RFC 9562 & Ordenação Cronológica) ===%b"
uuid1="$(_zs_uuidv7)"
sleep 0.02
uuid2="$(_zs_uuidv7)"

if [[ "$uuid1" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$ ]]; then
  print -P "%F{green}  ✓ PASS:%f Formato UUIDv7 válido ($uuid1)"
  (( PASS_COUNT++ )) || true
else
  print -P "%F{red}  ✗ FAIL:%f Formato UUIDv7 inválido ($uuid1)"
  (( FAIL_COUNT++ )) || true
fi

if [[ "$uuid1" < "$uuid2" ]]; then
  print -P "%F{green}  ✓ PASS:%f Ordenação cronológica lexicográfica UUIDv7 ($uuid1 < $uuid2)"
  (( PASS_COUNT++ )) || true
else
  print -P "%F{red}  ✗ FAIL:%f UUIDv7 fora de ordem ($uuid1 vs $uuid2)"
  (( FAIL_COUNT++ )) || true
fi

print -P "\n%B=== 2. Testes de Segurança: Mascaramento de Segredos (Redaction) ===%b"
raw_secret_sample='
REDIS_PASSWORD: super_secret_redis_123
api_key="sk-1234567890abcdefghijklmnop"
export GITHUB_TOKEN=ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789
redis-server --requirepass MinhaSenhaForte99
postgres://usuario:senha_banco_123@localhost:5432/prod
'
redacted_sample=$(print -r -- "$raw_secret_sample" | _zs_redact_text)

assert_not_contains "$redacted_sample" "super_secret_redis_123" "Remove valor de REDIS_PASSWORD"
assert_not_contains "$redacted_sample" "sk-1234567890abcdefghijklmnop" "Remove chave sk-..."
assert_not_contains "$redacted_sample" "ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ" "Remove token ghp_..."
assert_not_contains "$redacted_sample" "MinhaSenhaForte99" "Remove argumento de --requirepass"
assert_not_contains "$redacted_sample" "senha_banco_123" "Remove senha em URL de conexão"
assert_contains "$redacted_sample" "[REDACTED]" "Insere marcador [REDACTED]"

print -P "\n%B=== 3. Testes de Captura de Output e Diff de Arquivo .yml Editado ===%b"
cd "$WORKSPACE_TMP"
_zs_start_new_session
active_sid="$ZS_SESSION_ID"

cat <<'EOF' > docker-compose.yml
services:
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
EOF

# Simula comando que imprime saída e edita o arquivo .yml incluindo dado sensível
zs_record_exec 'sed -i.bak "s/6379:6379/127.0.0.1:6379:6379/" docker-compose.yml && echo "    environment: [REDIS_PASSWORD=segredo_real_999]" >> docker-compose.yml && rm -f docker-compose.yml.bak && echo "Compose atualizado com sucesso"'

session_log_content=$(< "$ZS_DATA_DIR/sessions/$active_sid.log")
assert_contains "$session_log_content" "Compose atualizado com sucesso" "Captura stdout do comando executado"
assert_contains "$session_log_content" "📝 Diff em docker-compose.yml:" "Registra cabeçalho de Diff para arquivo .yml editado"
assert_contains "$session_log_content" "-      - \"6379:6379\"" "Registra linha removida (-) no diff do .yml"
assert_contains "$session_log_content" "+      - \"127.0.0.1:6379:6379\"" "Registra linha adicionada (+) no diff do .yml"
assert_not_contains "$session_log_content" "segredo_real_999" "Mascara senha adicionada dentro do diff do .yml"

print -P "\n%B=== 4. Testes de Proteção de Arquivos Sensíveis (.env) e Permissões ===%b"
echo "DB_PASS=inicial" > .env
sleep 1
zs_record_exec 'echo "DB_PASS=super_secreto_env" > .env'
session_log_content=$(< "$ZS_DATA_DIR/sessions/$active_sid.log")
assert_contains "$session_log_content" "🔒 [Arquivo sensível editado: .env — diff omitido por segurança]" "Omite diff de arquivo .env e registra aviso de segurança"
assert_not_contains "$session_log_content" "super_secreto_env" "Jamais vaza conteúdo do .env no log da sessão"

dir_perm=$(command stat -f "%Lp" "$ZS_DATA_DIR" 2>/dev/null || command stat -c "%a" "$ZS_DATA_DIR")
file_perm=$(command stat -f "%Lp" "$ZS_DATA_DIR/sessions/$active_sid.log" 2>/dev/null || command stat -c "%a" "$ZS_DATA_DIR/sessions/$active_sid.log")
assert_eq "700" "$dir_perm" "Permissão 0700 no diretório de dados ($ZS_DATA_DIR)"
assert_eq "600" "$file_perm" "Permissão 0600 no arquivo de log da sessão"

print -P "\n%B=== 5. Testes da Regra 'Zero Lixo' (Descarte de Sessões Triviais e Deduplicação) ===%b"
_zs_start_new_session
trivial_sid="$ZS_SESSION_ID"
zs_record_exec "ls"
zs_record_exec "ls"
zs_record_exec "pwd"

assert_eq "2" "$ZS_SESSION_CMD_COUNT" "Deduplica comando trivial 'ls' repetido em sequência"
if _zs_should_keep_session; then
  print -P "%F{red}  ✗ FAIL:%f Sessão trivial deveria ser marcada para descarte"
  (( FAIL_COUNT++ )) || true
else
  print -P "%F{green}  ✓ PASS:%f Sessão apenas com 'ls' e 'pwd' é identificada como trivial"
  (( PASS_COUNT++ )) || true
fi

_zs_on_zshexit
if [[ ! -f "$ZS_DATA_DIR/sessions/$trivial_sid.log" ]]; then
  print -P "%F{green}  ✓ PASS:%f Sessão trivial removida automaticamente no fechamento (Zero Lixo)"
  (( PASS_COUNT++ )) || true
else
  print -P "%F{red}  ✗ FAIL:%f Arquivo de sessão trivial não foi removido"
  (( FAIL_COUNT++ )) || true
fi

print -P "\n%B=== 6. Testes de Categorias Manuais, Renomeação e Retomada (Resume) ===%b"
zs cat add "DevOps" >/dev/null
zs cat set "DevOps" "$active_sid" >/dev/null
zs rename "Ajuste de portas Redis no docker-compose" "$active_sid" >/dev/null

cat_list_out=$(zs cat list)
assert_contains "$cat_list_out" "DevOps" "Lista categoria manual criada pelo usuário"

mkdir -p "$TEST_ROOT/other_dir"
cd "$TEST_ROOT/other_dir"
zs resume "$active_sid" >/dev/null

assert_eq "$WORKSPACE_TMP" "$PWD" "zs resume restaura o diretório de trabalho (cd) da sessão"
assert_eq "$active_sid" "$ZS_SESSION_ID" "zs resume restaura o UUIDv7 da sessão ativa"
assert_eq "DevOps" "$ZS_SESSION_CATEGORY" "zs resume preserva a categoria da sessão"
assert_eq "Ajuste de portas Redis no docker-compose" "$ZS_SESSION_TITLE" "zs resume preserva o título da sessão"

print -P "\n======================================================================"
print -P "Resultado Final: %F{green}${PASS_COUNT} passaram%f | %F{red}${FAIL_COUNT} falharam%f"
print -P "======================================================================"

(( FAIL_COUNT == 0 ))
