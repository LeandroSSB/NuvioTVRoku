#!/usr/bin/env bash
# NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
# Contrato 09: walk de addons POR PERFIL — os pipelines Home (rows de catálogo) e Detail (meta)
# do M1, congelados ponta a ponta antes do código .brs que os consumirá.
# Inclui o caminho crítico de FALLBACK de meta: o 1º addon com resource "meta" pode NÃO
# entregar meta real (AIOStreams hoje) — o app itera até um addon entregar.
source "$(dirname "$0")/lib.sh"

ANON="$(json_get "$(wellknown "$NUVIO_BACKEND_URL")" .publishable_key)"
TOKEN="$(nuvio_login "$NUVIO_BACKEND_URL" "$ANON")"
assert_not_empty "login para walk" "$TOKEN"

PROFILES="$(curl -sS -m 15 \
    "$NUVIO_BACKEND_URL/rest/v1/profiles?select=profile_id&order=profile_index.asc" \
    -H "apikey: $ANON" -H "Authorization: Bearer $TOKEN")"
PROFILE_ID="$(echo "$PROFILES" | jq -r '.[0].profile_id // empty')"
assert_not_empty "profile_id do 1º perfil" "$PROFILE_ID"

ADDONS="$(curl -sS -m 15 \
    "$NUVIO_BACKEND_URL/rest/v1/addons?select=profile_id,name,url,enabled&profile_id=eq.$PROFILE_ID&enabled=eq.true&order=sort_order.asc" \
    -H "apikey: $ANON" -H "Authorization: Bearer $TOKEN")"
assert_contains "resposta é array" '"url"' "$ADDONS"
assert_gt "perfil tem addons habilitados" 0 "$(echo "$ADDONS" | jq 'length')"
assert_eq "todas as rows do perfil filtrado" "$PROFILE_ID" \
    "$(echo "$ADDONS" | jq -r '[.[].profile_id] | unique | .[0]')"

# normaliza (3 formas) + dedupe — mesmo algoritmo de lib/Addons.brs BuildAddonList
MANIFESTS="$(echo "$ADDONS" | jq -r '.[].url
    | if endswith("/manifest.json") or endswith(".json") then . else . + "/manifest.json" end' \
    | sort -u)"
N_MAN="$(echo "$MANIFESTS" | grep -c . || true)"
assert_gt "manifests únicos ≥ 4" 4 "$N_MAN"

TOTAL_CATS=0
HAS_MOVIE_URL=""
HAS_SERIES_ID=""
META_BASES=""

while IFS= read -r M; do
    [ -z "$M" ] && continue
    MAN="$(curl -sS -m 20 "$M")"
    BASE="$(base_of "$M")"
    NCAT="$(echo "$MAN" | jq '[.catalogs // [] | length] | .[0]' 2>/dev/null)"
    TOTAL_CATS=$((TOTAL_CATS + ${NCAT:-0}))
    CAT_MOVIE_ID="$(echo "$MAN" | jq -r '[.catalogs[] | select(.type == "movie")][0].id // empty' 2>/dev/null)"
    CAT_SERIES_ID="$(echo "$MAN" | jq -r '[.catalogs[] | select(.type == "series")][0].id // empty' 2>/dev/null)"
    if [ -z "$HAS_MOVIE_URL" ] && [ -n "$CAT_MOVIE_ID" ]; then
        HAS_MOVIE_URL="$BASE/catalog/movie/$CAT_MOVIE_ID.json?skip=0"
    fi
    if [ -z "$HAS_SERIES_ID" ] && [ -n "$CAT_SERIES_ID" ]; then
        HAS_SERIES_ID="$CAT_SERIES_ID"
    fi
    HASMETA="$(echo "$MAN" | jq 'any((.resources // [])[]; (if type=="string" then . else .name end) == "meta")' 2>/dev/null)"
    if [ "$HASMETA" = "true" ]; then
        META_BASES="$META_BASES$BASE"$'\n'
    fi
done <<< "$MANIFESTS"

assert_gt "catálogo total de rows ≥ 10" 10 "$TOTAL_CATS"
assert_not_empty "existe catálogo movie" "$HAS_MOVIE_URL"
assert_not_empty "existe catálogo series" "$HAS_SERIES_ID"

CATALOG="$(curl -sS -m 30 "$HAS_MOVIE_URL")"
assert_gt "catálogo movie retorna metas" 0 "$(echo "$CATALOG" | jq '.metas // [] | length')"
FIRST_META="$(echo "$CATALOG" | jq -r '.metas[0] // empty')"
assert_contains "meta[0].id é imdb" "tt" "$(echo "$FIRST_META" | jq -r '.id')"
assert_not_empty "meta[0].name" "$(echo "$FIRST_META" | jq -r '.name')"
assert_not_empty "meta[0].poster" "$(echo "$FIRST_META" | jq -r '.poster // empty')"
MOVIE_ID="$(echo "$FIRST_META" | jq -r '.id')"
echo "  1º meta movie: $(echo "$FIRST_META" | jq -r '.name') ($MOVIE_ID)"

# FALLBACK de meta série: primeiro addon com resource meta que ENTREGUE videos
SERIES_META=""
SERIES_PROVIDER=""
for BASE in $META_BASES; do
    RESP="$(curl -sS -m 30 "$BASE/meta/series/tt0944947.json")"
    if [ "$(echo "$RESP" | jq '.meta.videos // [] | length' 2>/dev/null)" -gt 0 ]; then
        SERIES_META="$RESP"
        SERIES_PROVIDER="$BASE"
        break
    fi
done
assert_not_empty "algum addon entrega meta de série (fallback funciona)" "$SERIES_META"
assert_gt "série com episódios" 0 "$(echo "$SERIES_META" | jq '.meta.videos | length')"
assert_eq "video[0].season é número" '"number"' "$(echo "$SERIES_META" | jq '.meta.videos[0].season | type')"
echo "  provider série: $(echo "$SERIES_PROVIDER" | sed -E 's#(https?://[^/]+)/.*#\1#') ($(echo "$SERIES_META" | jq '.meta.videos | length') eps)"

# FALLBACK de meta filme: primeiro addon com resource meta que ENTREGUE meta.name
MOVIE_META=""
for BASE in $META_BASES; do
    RESP="$(curl -sS -m 30 "$BASE/meta/movie/$MOVIE_ID.json")"
    if [ -n "$(echo "$RESP" | jq -r '.meta.name // empty' 2>/dev/null)" ]; then
        MOVIE_META="$RESP"
        break
    fi
done
assert_not_empty "algum addon entrega meta de filme (fallback funciona)" "$MOVIE_META"

finish_contract "09-addon-walk"
