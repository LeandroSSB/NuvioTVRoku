#!/usr/bin/env bash
# Contrato 03: tabela `addons` (PostgREST) — lista de addons instalados na conta.
# É daqui que o app tira as URLs dos addons (inclui OpenSubtitles v3 público).
source "$(dirname "$0")/lib.sh"

ANON="$(json_get "$(wellknown "$NUVIO_BACKEND_URL")" .publishable_key)"
TOKEN="$(nuvio_login "$NUVIO_BACKEND_URL" "$ANON")"
assert_not_empty "login para addons" "$TOKEN"

ADDONS="$(curl -sS -m 15 \
    "$NUVIO_BACKEND_URL/rest/v1/addons?select=name,url,enabled&order=sort_order.asc" \
    -H "apikey: $ANON" -H "Authorization: Bearer $TOKEN")"
assert_contains "resposta é array (não erro RLS)" '"url"' "$ADDONS"

COUNT="$(echo "$ADDONS" | jq 'length')"
assert_gt "conta tem addons instalados" 0 "$COUNT"

URLS="$(echo "$ADDONS" | jq -r '.[].url' | tr '\n' ' ')"
assert_contains "addon OpenSubtitles presente" "opensubtitles" "$URLS"
assert_contains "addon AIOStreams presente (host aio)" "aio." "$URLS"

echo "  addons:"
echo "$ADDONS" | jq -r '.[] | "    \(.sort // "")\(.name // "?") -> \(.url)"' 2>/dev/null | head -8

finish_contract "03-addons"
