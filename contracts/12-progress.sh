#!/usr/bin/env bash
# NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
# Contrato 12: watch_progress (PostgREST, RLS por usuário) — o sync M3.
# Congela: leitura (shape ms/epoch, ordem last_watched.desc, filtro profile_id) e
# ESCRITA (POST Prefer merge-duplicates exigindo user_id + video_id — INSERT sem
# eles viola RLS/not-null, provado 26/11). Round-trip de escrita usa row FAKE
# ttTEST0000 com cleanup obrigatório — nunca tocar nas rows reais da conta.
source "$(dirname "$0")/lib.sh"

ANON="$(json_get "$(wellknown "$NUVIO_BACKEND_URL")" .publishable_key)"
LOGIN_BODY="$(curl -sS -m 30 -X POST "$NUVIO_BACKEND_URL/auth/v1/token?grant_type=password" \
    -H "apikey: $ANON" -H "Content-Type: application/json" \
    -d "{\"email\":\"$NUVIO_EMAIL\",\"password\":\"$NUVIO_PASSWORD\"}")"
TOKEN="$(json_get "$LOGIN_BODY" .access_token)"
USER_ID="$(json_get "$LOGIN_BODY" .user.id)"
assert_not_empty "login para progress" "$TOKEN"
assert_not_empty "user.id no response de login" "$USER_ID"

ROWS="$(curl -sS -m 15 \
    "$NUVIO_BACKEND_URL/rest/v1/watch_progress?select=content_id,content_type,season,episode,position,duration,progress_key,video_id,last_watched,profile_id&profile_id=eq.1&order=last_watched.desc&limit=50" \
    -H "apikey: $ANON" -H "Authorization: Bearer $TOKEN")"
assert_contains "resposta é array de progress" '"progress_key"' "$ROWS"
assert_gt "conta tem rows de progresso" 0 "$(echo "$ROWS" | jq 'length')"
assert_eq "last_watched é epoch ms (número)" "true" "$(echo "$ROWS" | jq -r '[.[].last_watched | type == "number"] | all')"
assert_eq "position/duration em ms (números)" "true" "$(echo "$ROWS" | jq -r '[.[] | .position | type == "number" and . >= 0] | all')"
assert_eq "séries têm video_id tt:s:e" "true" "$(echo "$ROWS" | jq -r '[.[] | select(.content_type == "series") | .video_id | test("^tt[0-9]+:[0-9]+:[0-9]+$|^kitsu:[0-9]+:[0-9]+:[0-9]+$|^[a-z]+:[0-9]+:[0-9]+:[0-9]+$|^[a-z]+:[0-9]+:[0-9]+$")] | all')"
echo "  rows do perfil: $(echo "$ROWS" | jq 'length'); mais recente: $(echo "$ROWS" | jq -r '.[0].progress_key')"

# WRITE round-trip (row FAKE)
# upsert = POST ?on_conflict=user_id,profile_id,progress_key + Prefer merge-duplicates (PK-only default mira id e dá 409 — provado 26/11)
FAKE_POST="$(curl -sS -m 15 -X POST "$NUVIO_BACKEND_URL/rest/v1/watch_progress?on_conflict=user_id,profile_id,progress_key" \
    -H "apikey: $ANON" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    -H "Prefer: return=representation,resolution=merge-duplicates" \
    -d "{\"content_id\":\"ttTEST0000\",\"content_type\":\"movie\",\"position\":5000,\"duration\":100000,\"progress_key\":\"ttTEST0000\",\"video_id\":\"ttTEST0000\",\"last_watched\":1700000000000,\"profile_id\":1,\"user_id\":\"$USER_ID\"}")"
assert_contains "POST upsert cria row fake" '"ttTEST0000"' "$FAKE_POST"

FAKE_REPOST="$(curl -sS -m 15 -X POST "$NUVIO_BACKEND_URL/rest/v1/watch_progress?on_conflict=user_id,profile_id,progress_key" \
    -H "apikey: $ANON" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    -H "Prefer: return=representation,resolution=merge-duplicates" \
    -d "{\"content_id\":\"ttTEST0000\",\"content_type\":\"movie\",\"position\":7000,\"duration\":100000,\"progress_key\":\"ttTEST0000\",\"video_id\":\"ttTEST0000\",\"last_watched\":1700000100000,\"profile_id\":1,\"user_id\":\"$USER_ID\"}")"
assert_contains "re-POST faz upsert (sem duplicar)" '"ttTEST0000"' "$FAKE_REPOST"
assert_eq "upsert atualizou position (1 row)" "1" "$(curl -sS -m 10 \
    "$NUVIO_BACKEND_URL/rest/v1/watch_progress?progress_key=eq.ttTEST0000" \
    -H "apikey: $ANON" -H "Authorization: Bearer $TOKEN" | jq 'length')"
assert_eq "position atualizada para 7000ms" "7000" "$(curl -sS -m 10 \
    "$NUVIO_BACKEND_URL/rest/v1/watch_progress?progress_key=eq.ttTEST0000" \
    -H "apikey: $ANON" -H "Authorization: Bearer $TOKEN" | jq -r '.[0].position')"

# INSERT SEM user_id → viola RLS (comportamento que o app evita)
BAD="$(curl -sS -m 15 -X POST "$NUVIO_BACKEND_URL/rest/v1/watch_progress?on_conflict=user_id,profile_id,progress_key" \
    -H "apikey: $ANON" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    -d '{"content_id":"ttTEST0001","content_type":"movie","position":5000,"duration":100000,"progress_key":"ttTEST0001","video_id":"ttTEST0001","last_watched":1700000000000,"profile_id":1}')"
assert_contains "INSERT sem user_id viola RLS" 'row-level security' "$BAD"

# CLEANUP obrigatório (ambas as keys fake — BAD probe não pode deixar órfão se RLS relaxar)
curl -sS -m 10 -X DELETE "$NUVIO_BACKEND_URL/rest/v1/watch_progress?progress_key=in.(ttTEST0000,ttTEST0001)" \
    -H "apikey: $ANON" -H "Authorization: Bearer $TOKEN" -o /dev/null
LEFT="$(curl -sS -m 10 "$NUVIO_BACKEND_URL/rest/v1/watch_progress?progress_key=in.(ttTEST0000,ttTEST0001)" \
    -H "apikey: $ANON" -H "Authorization: Bearer $TOKEN" | jq 'length')"
assert_eq "cleanup removeu a row fake" "0" "$LEFT"

finish_contract "12-progress"
