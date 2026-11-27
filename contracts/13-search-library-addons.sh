#!/usr/bin/env bash
# NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
# Contrato 13: M4 — search (path-form!), library_items, CRUD de addons e RLS
# cross-account. Usa a CONTA SUB (NUVIO_SUB_*) para todas as escritas — a conta
# main nunca é mutada. Search: extras Stremio são PATH segments (?search= é ignorado
# pelos addons — provado 26/11; Xperience e Nuvio Catalog respondem, AIOStreams não
# tem search). library_items = meta snapshot rico + os RPCs de sync do app
# (sync_push_library_items funcional; sync_delete_library_items autentica mas é
# no-op com a shape p_keys — documentado, cleanup via DELETE de tabela). addons:
# INSERT/PATCH/DELETE + UPSERT-BY-ID (?on_conflict=id merge-duplicates — o
# mecanismo REAL do toggle do app) por RLS do próprio usuário.
source "$(dirname "$0")/lib.sh"

ANON="$(json_get "$(wellknown "$NUVIO_BACKEND_URL")" .publishable_key)"
: "${NUVIO_SUB_EMAIL:?creds.env faltando NUVIO_SUB_EMAIL}"
: "${NUVIO_SUB_PASSWORD:?creds.env faltando NUVIO_SUB_PASSWORD}"
SUB_LOGIN="$(curl -sS -m 30 -X POST "$NUVIO_BACKEND_URL/auth/v1/token?grant_type=password" \
    -H "apikey: $ANON" -H "Content-Type: application/json" \
    -d "{\"email\":\"$NUVIO_SUB_EMAIL\",\"password\":\"$NUVIO_SUB_PASSWORD\"}")"
SUB_TOKEN="$(json_get "$SUB_LOGIN" .access_token)"
SUB_USER="$(json_get "$SUB_LOGIN" .user.id)"
assert_not_empty "login da conta sub" "$SUB_TOKEN"
assert_not_empty "user.id da sub" "$SUB_USER"

MAIN_LOGIN="$(curl -sS -m 30 -X POST "$NUVIO_BACKEND_URL/auth/v1/token?grant_type=password" \
    -H "apikey: $ANON" -H "Content-Type: application/json" \
    -d "{\"email\":\"$NUVIO_EMAIL\",\"password\":\"$NUVIO_PASSWORD\"}")"
MAIN_TOKEN="$(json_get "$MAIN_LOGIN" .access_token)"
assert_not_empty "login da conta main" "$MAIN_TOKEN"
SH=(-H "apikey: $ANON" -H "Authorization: Bearer $MAIN_TOKEN")
SU=(-H "apikey: $ANON" -H "Authorization: Bearer $SUB_TOKEN")

# RLS cross-account: sub NÃO vê dados do main
assert_eq "RLS: sub vê 0 rows de progress do main" "0" \
    "$(curl -sS -m 10 "$NUVIO_BACKEND_URL/rest/v1/watch_progress?select=progress_key&limit=5" "${SU[@]}" | jq 'if type=="array" then length else -1 end')"
assert_eq "RLS: sub vê 0 library_items do main" "0" \
    "$(curl -sS -m 10 "$NUVIO_BACKEND_URL/rest/v1/library_items?select=id&limit=5" "${SU[@]}" | jq 'if type=="array" then length else -1 end')"
MAIN_NAMES="$(curl -sS -m 10 "$NUVIO_BACKEND_URL/rest/v1/profiles?select=name" "${SH[@]}" | jq -c 'if type=="array" then map(.name) else [] end')"
assert_eq "RLS: sub não vê NENHUM perfil do main" "true" \
    "$(curl -sS -m 10 "$NUVIO_BACKEND_URL/rest/v1/profiles?select=name" "${SU[@]}" | jq --argjson main "$MAIN_NAMES" 'type=="array" and all(.[]; . as $n | $main | index($n.name) == null)')"

# SEARCH (path form) — descobre um catalog c/ extra search no Xperience
XP="$(curl -sS -m 15 "$NUVIO_BACKEND_URL/rest/v1/addons?select=url&profile_id=eq.1&order=sort_order.asc" "${SH[@]}" | jq -r '.[] | select(.url | test("xperience"; "i")) | .url' | head -1)"
assert_not_empty "addon Xperience presente (main)" "$XP"
XPB="${XP%/manifest.json}"
SCAT="$(curl -sS -m 20 "$XPB/manifest.json" | jq -r '[.catalogs[] | select(.extra != null and ([.extra[]?.name] | index("search") != null))][0] | "\(.type)|\(.id)"' 2>/dev/null)"
STYPE="${SCAT%%|*}"; SCID="${SCAT##*|}"
assert_not_empty "Xperience tem catalog c/ search" "$SCID"
RESULTS="$(curl -sS -m 30 "$XPB/catalog/$STYPE/$SCID/search=the%20matrix.json")"
assert_gt "search path-form retorna metas" 0 "$(echo "$RESULTS" | jq '.metas // [] | length')"
assert_contains "resultado é The Matrix" "The Matrix" "$(echo "$RESULTS" | jq -r '[.metas[]][0].name')"
assert_eq "query param ?search= é IGNORADO (protocolo é PATH)" "true" \
    "$(curl -sS -m 30 "$XPB/catalog/$STYPE/$SCID.json?search=the%20matrix" | jq '(.metas // [] | length) == 0 or ([.metas[]][0].name != "The Matrix")' 2>/dev/null)"

# LIBRARY_ITEMS shape (main, read-only)
LIB="$(curl -sS -m 15 "$NUVIO_BACKEND_URL/rest/v1/library_items?select=*&limit=3" "${SH[@]}")"
assert_contains "library_items é array" '"content_id"' "$LIB"
assert_eq "library row tem meta snapshot (name/poster)" "true" \
    "$(echo "$LIB" | jq -r '[.[] | .name != null and .poster != null] | all')"
assert_eq "added_at é epoch ms" "true" "$(echo "$LIB" | jq -r '[.[].added_at | type == "number"] | all')"

# ADDONS CRUD (sub account — INSERT → PATCH → DELETE)
# cleanup defensivo: remove M4TEST de runs interrompidos (o assert final exige 0 rows)
curl -sS -m 10 -X DELETE "$NUVIO_BACKEND_URL/rest/v1/addons?name=eq.M4TEST" "${SU[@]}" -o /dev/null || true
INS="$(curl -sS -m 15 -X POST "$NUVIO_BACKEND_URL/rest/v1/addons" "${SU[@]}" \
    -H "Content-Type: application/json" -H "Prefer: return=representation" \
    -d "{\"name\":\"M4TEST\",\"url\":\"https://example.com/manifest.json\",\"enabled\":true,\"sort_order\":99,\"profile_id\":1,\"user_id\":\"$SUB_USER\"}")"
assert_contains "INSERT addon na sub" '"M4TEST"' "$INS"
ADDON_ID="$(json_get "$INS" 'if type=="array" then .[0].id else empty end')"
assert_not_empty "addon id retornado" "$ADDON_ID"
# UPSERT-BY-ID (o mecanismo REAL do toggle do app — roUrlTransfer não tem PATCH).
# A row PARCIAL (id+enabled) falha 23502 NOT NULL url — o payload PRECISA carregar
# a row inteira (name/url/sort_order).
TOGGLE="$(curl -sS -m 15 -X POST "$NUVIO_BACKEND_URL/rest/v1/addons?on_conflict=id" "${SU[@]}" \
    -H "Content-Type: application/json" -H "Prefer: return=representation,resolution=merge-duplicates" \
    -d "{\"id\":\"$ADDON_ID\",\"enabled\":false,\"name\":\"M4TEST\",\"url\":\"https://example.com/manifest.json\",\"sort_order\":99,\"profile_id\":1,\"user_id\":\"$SUB_USER\"}")"
assert_contains "upsert-by-id faz toggle (mecanismo real do app)" '"enabled":false' "$(echo "$TOGGLE" | jq -c 'if type=="array" then .[0] else . end | {enabled: .enabled}')"
PATCH_CODE="$(curl -sS -m 10 -X PATCH "$NUVIO_BACKEND_URL/rest/v1/addons?id=eq.$ADDON_ID" "${SU[@]}" \
    -H "Content-Type: application/json" -d '{"enabled":false}' -o /dev/null -w "%{http_code}")"
assert_eq "PATCH enabled=false → 204" "204" "$PATCH_CODE"
assert_eq "PATCH persistiu" "false" \
    "$(curl -sS -m 10 "$NUVIO_BACKEND_URL/rest/v1/addons?id=eq.$ADDON_ID&select=enabled" "${SU[@]}" | jq -r '.[0].enabled')"
DEL_CODE="$(curl -sS -m 10 -X DELETE "$NUVIO_BACKEND_URL/rest/v1/addons?id=eq.$ADDON_ID" "${SU[@]}" -o /dev/null -w "%{http_code}")"
assert_eq "DELETE addon fake → 204" "204" "$DEL_CODE"
assert_eq "cleanup: 0 rows M4TEST" "0" \
    "$(curl -sS -m 10 "$NUVIO_BACKEND_URL/rest/v1/addons?name=eq.M4TEST" "${SU[@]}" | jq 'length')"

# LIBRARY RPCs (os mecanismos REAIS de add/remove do app)
# cleanup defensivo: remove rows fake de runs anteriores via DELETE de TABELA
# (o RPC delete é no-op — ver abaixo; o curl do contrato tem DELETE, o app não)
curl -sS -m 10 -X DELETE "$NUVIO_BACKEND_URL/rest/v1/library_items?content_id=eq.ttTEST0000&profile_id=eq.1" "${SU[@]}" -o /dev/null || true
SNAP='{"content_id":"ttTEST0000","content_type":"movie","name":"M4 Test Movie","poster":"","background":"","description":"","genres":"","imdb_rating":"","release_info":"","poster_shape":"poster","addon_base_url":""}'
PUSH="$(curl -sS -m 15 -X POST "$NUVIO_BACKEND_URL/rest/v1/rpc/sync_push_library_items" "${SU[@]}" \
    -H "Content-Type: application/json" \
    -d "{\"p_items\":[$SNAP],\"p_profile_id\":1,\"p_origin_client_id\":\"nuviotvroku\"}" \
    -o /dev/null -w "%{http_code}")"
assert_eq "sync_push_library_items → 204 (add do app)" "204" "$PUSH"
DEL="$(curl -sS -m 15 -X POST "$NUVIO_BACKEND_URL/rest/v1/rpc/sync_delete_library_items" "${SU[@]}" \
    -H "Content-Type: application/json" \
    -d '{"p_keys":["ttTEST0000"],"p_profile_id":1}' \
    -o /dev/null -w "%{http_code}")"
assert_eq "sync_delete_library_items autentica (shape p_keys sob validação device)" "204" "$DEL"
LEFT="$(curl -sS -m 10 "$NUVIO_BACKEND_URL/rest/v1/library_items?content_id=eq.ttTEST0000&profile_id=eq.1" "${SU[@]}" | jq 'length')"
# OBSERVADO 26/11: o RPC delete autentica (204) mas é NO-OP — a row permanece (1).
# Congela o comportamento REAL (investigação device-phase; ver README "Deliberate cuts").
assert_eq "estado pós-RPCs (delete no-op documentado — fix device-phase)" "1" "$LEFT"
# cleanup INCONDICIONAL: nada vaza — o row fake sai via DELETE de tabela
curl -sS -m 10 -X DELETE "$NUVIO_BACKEND_URL/rest/v1/library_items?content_id=eq.ttTEST0000&profile_id=eq.1" "${SU[@]}" -o /dev/null || true
assert_eq "cleanup: 0 rows ttTEST0000 (no-op do RPC não vaza)" "0" \
    "$(curl -sS -m 10 "$NUVIO_BACKEND_URL/rest/v1/library_items?content_id=eq.ttTEST0000&profile_id=eq.1" "${SU[@]}" | jq 'length')"

finish_contract "13-search-library-addons"
