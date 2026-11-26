#!/usr/bin/env bash
# NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
# Contrato 07: tabela `profiles` (PostgREST, RLS por usuário) — tela de perfis do app (M1).
# Congela: campos profile_id/name/avatar_color_hex/pin_enabled + ordenação profile_index.asc;
# pin_hash NÃO pode vazar no select do app. Valida também o filtro profile_id na tabela addons.
source "$(dirname "$0")/lib.sh"

ANON="$(json_get "$(wellknown "$NUVIO_BACKEND_URL")" .publishable_key)"
TOKEN="$(nuvio_login "$NUVIO_BACKEND_URL" "$ANON")"
assert_not_empty "login para profiles" "$TOKEN"

PROFILES="$(curl -sS -m 15 \
    "$NUVIO_BACKEND_URL/rest/v1/profiles?select=profile_id,name,avatar_color_hex,pin_enabled&order=profile_index.asc" \
    -H "apikey: $ANON" -H "Authorization: Bearer $TOKEN")"
assert_contains "resposta é array (não erro RLS)" '"profile_id"' "$PROFILES"
COUNT="$(echo "$PROFILES" | jq 'length')"
assert_gt "conta tem perfis" 0 "$COUNT"
assert_eq "profile_id são números" "true" "$(echo "$PROFILES" | jq -r '[.[].profile_id | type == "number"] | all')"
assert_eq "nomes não vazios" "true" "$(echo "$PROFILES" | jq -r '[.[].name | length > 0] | all')"
assert_eq "avatar_color_hex #RRGGBB" "true" "$(echo "$PROFILES" | jq -r '[.[].avatar_color_hex | test("^#[0-9A-Fa-f]{6}$")] | all')"
assert_eq "pin_hash não vaza no select" "false" "$(echo "$PROFILES" | jq 'any(.[]; has("pin_hash"))')"
echo "  perfis: $(echo "$PROFILES" | jq -r '[.[].name] | join(", ")')"

# addons são POR PERFIL (fonte das duplicatas do M0): filtro profile_id=eq.N devolve só a row do perfil
FIRST_PROFILE="$(echo "$PROFILES" | jq -r '.[0].profile_id')"
ADDONS="$(curl -sS -m 15 \
    "$NUVIO_BACKEND_URL/rest/v1/addons?select=profile_id,url&profile_id=eq.$FIRST_PROFILE" \
    -H "apikey: $ANON" -H "Authorization: Bearer $TOKEN")"
assert_gt "perfil tem addons" 0 "$(echo "$ADDONS" | jq 'length')"
assert_eq "addons todas do perfil filtrado" "true" \
    "$(echo "$ADDONS" | jq --argjson p "$FIRST_PROFILE" 'all(.[]; .profile_id == $p)')"

finish_contract "07-profiles"
