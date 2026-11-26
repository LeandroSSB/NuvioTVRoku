#!/usr/bin/env bash
# NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
# Contrato 08: refresh grant GoTrue — boot do app restaura sessão sem re-pedir senha.
# Congela: resposta {access_token, refresh_token (pode rotacionar — app SEMPRE sobrescreve),
# expires_in 7200}; refresh inválido → 400 (caminho de re-login do app).
source "$(dirname "$0")/lib.sh"

ANON="$(json_get "$(wellknown "$NUVIO_BACKEND_URL")" .publishable_key)"
LOGIN="$(curl -sS -m 30 -X POST "$NUVIO_BACKEND_URL/auth/v1/token?grant_type=password" \
    -H "apikey: $ANON" -H "Content-Type: application/json" \
    -d "{\"email\":\"$NUVIO_EMAIL\",\"password\":\"$NUVIO_PASSWORD\"}")"
RT="$(json_get "$LOGIN" .refresh_token)"
assert_not_empty "login retorna refresh_token" "$RT"

REFRESH="$(curl -sS -m 30 -X POST "$NUVIO_BACKEND_URL/auth/v1/token?grant_type=refresh_token" \
    -H "apikey: $ANON" -H "Content-Type: application/json" \
    -d "{\"refresh_token\":\"$RT\"}")"
NEW_ACCESS="$(json_get "$REFRESH" .access_token)"
NEW_RT="$(json_get "$REFRESH" .refresh_token)"
assert_not_empty "refresh retorna access_token" "$NEW_ACCESS"
assert_contains "access renovado parece JWT" "eyJ" "$NEW_ACCESS"
assert_not_empty "refresh retorna refresh_token (rotacionado ou igual)" "$NEW_RT"
assert_eq "expires_in 7200" "7200" "$(json_get "$REFRESH" .expires_in)"
if [ -n "$NEW_RT" ] && [ "$NEW_RT" != "$RT" ]; then
    echo "  ok: refresh_token rotaciona (app deve sempre sobrescrever)"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "  ok: refresh_token estável nesta chamada"
    PASS_COUNT=$((PASS_COUNT + 1))
fi

USER_EMAIL="$(curl -sS -m 15 "$NUVIO_BACKEND_URL/auth/v1/user" \
    -H "apikey: $ANON" -H "Authorization: Bearer $NEW_ACCESS" | jq -r '.email // empty')"
assert_eq "token renovado é válido em /auth/v1/user" "$NUVIO_EMAIL" "$USER_EMAIL"

BAD_CODE="$(curl -sS -m 15 -o /dev/null -w "%{http_code}" \
    -X POST "$NUVIO_BACKEND_URL/auth/v1/token?grant_type=refresh_token" \
    -H "apikey: $ANON" -H "Content-Type: application/json" \
    -d '{"refresh_token":"invalido-propositadamente"}')"
assert_eq "refresh inválido → 400 (re-login)" "400" "$BAD_CODE"

finish_contract "08-refresh"
