#!/usr/bin/env bash
# Contrato 02: login GoTrue (password grant) + validação do token em /auth/v1/user.
source "$(dirname "$0")/lib.sh"

ANON="$(json_get "$(wellknown "$NUVIO_BACKEND_URL")" .publishable_key)"
assert_not_empty "anon key resolvida via well-known" "$ANON"

TOKEN="$(nuvio_login "$NUVIO_BACKEND_URL" "$ANON")"
assert_not_empty "login GoTrue retorna access_token" "$TOKEN"
assert_contains "token parece JWT" "eyJ" "$TOKEN"

USER_EMAIL="$(curl -sS -m 15 "$NUVIO_BACKEND_URL/auth/v1/user" \
    -H "apikey: $ANON" -H "Authorization: Bearer $TOKEN" | jq -r '.email // empty')"
assert_eq "usuário do token confere" "$NUVIO_EMAIL" "$USER_EMAIL"

finish_contract "02-auth"
