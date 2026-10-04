#!/usr/bin/env bash
# lib.sh — helpers da suíte de contratos do NuvioTVRoku.
# Contratos = curl/jq leves (podem rodar no WSL). Segredos ficam em creds/creds.env (gitignored).
set -euo pipefail

CREDS_ENV="${CREDS_ENV:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/creds/creds.env}"
if [ ! -f "$CREDS_ENV" ]; then
    echo "FAIL: $CREDS_ENV não existe — copie de creds.env.example e preencha." >&2
    exit 2
fi
# shellcheck disable=SC1090
source "$CREDS_ENV"

: "${NUVIO_BACKEND_URL:?creds.env faltando NUVIO_BACKEND_URL}"
: "${NUVIO_EMAIL:?creds.env faltando NUVIO_EMAIL}"
: "${NUVIO_PASSWORD:?creds.env faltando NUVIO_PASSWORD}"
: "${AIOSTREAMS_MANIFEST_URL:?creds.env faltando AIOSTREAMS_MANIFEST_URL}"

PASS_COUNT=0
FAIL_COUNT=0

assert_eq() { # desc expected actual
    if [ "$2" = "$3" ]; then echo "  ok: $1"; PASS_COUNT=$((PASS_COUNT + 1));
    else echo "  FAIL: $1 — esperado '$2', obtido '$3'"; FAIL_COUNT=$((FAIL_COUNT + 1)); fi
}
assert_contains() { # desc needle haystack
    case "$3" in *"$2"*) echo "  ok: $1"; PASS_COUNT=$((PASS_COUNT + 1));;
        *) echo "  FAIL: $1 — '$2' não encontrado"; FAIL_COUNT=$((FAIL_COUNT + 1));; esac
}
assert_not_empty() { # desc value
    if [ -n "$2" ]; then echo "  ok: $1"; PASS_COUNT=$((PASS_COUNT + 1));
    else echo "  FAIL: $1 — vazio"; FAIL_COUNT=$((FAIL_COUNT + 1)); fi
}
assert_gt() { # desc min actual (numérico)
    if [ "$3" -gt "$2" ] 2>/dev/null; then echo "  ok: $1"; PASS_COUNT=$((PASS_COUNT + 1));
    else echo "  FAIL: $1 — '$3' não é > $2"; FAIL_COUNT=$((FAIL_COUNT + 1)); fi
}
finish_contract() { # nome
    echo "== $1: $PASS_COUNT ok, $FAIL_COUNT fail"
    [ "$FAIL_COUNT" -eq 0 ] || exit 1
}

json_get() { # json jqPath
    echo "$1" | jq -r "$2 // empty"
}

wellknown() { # backendUrl
    curl -sS -m 15 "$1/.well-known/nuvio"
}

# Login GoTrue (Supabase password grant). Imprime access_token (vazio em falha).
nuvio_login() { # backendUrl anonKey
    curl -sS -m 30 -X POST "$1/auth/v1/token?grant_type=password" \
        -H "apikey: $2" -H "Content-Type: application/json" \
        -d "{\"email\":\"$NUVIO_EMAIL\",\"password\":\"$NUVIO_PASSWORD\"}" \
        | jq -r '.access_token // empty'
}
