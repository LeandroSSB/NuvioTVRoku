#!/usr/bin/env bash
# Contrato 04: protocolo Stremio no AIOStreams — manifest → catalog → stream.
# Prefere catálogo de movies (stream de série exige id ttXXX:S:E, escopo do M1).
source "$(dirname "$0")/lib.sh"

M="$AIOSTREAMS_MANIFEST_URL"
MANIFEST="$(curl -sS -m 20 "$M")"
assert_contains "manifest tem catalogs" '"catalogs"' "$MANIFEST"
assert_contains "manifest tem resources" '"stream"' "$MANIFEST"

CAT_TYPE="$(echo "$MANIFEST" | jq -r '[.catalogs[] | select(.type == "movie")][0].type // empty')"
CAT_ID="$(echo "$MANIFEST" | jq -r '[.catalogs[] | select(.type == "movie")][0].id // empty')"
assert_not_empty "existe catálogo tipo movie" "$CAT_TYPE"
assert_not_empty "catalog[0].id" "$CAT_ID"

BASE="${M%/manifest.json}"
CATALOG="$(curl -sS -m 30 "$BASE/catalog/$CAT_TYPE/$CAT_ID.json?skip=0")"
N_METAS="$(echo "$CATALOG" | jq '.metas | length')"
assert_gt "catálogo retorna metas" 0 "$N_METAS"
FIRST_ID="$(echo "$CATALOG" | jq -r '.metas[0].id')"
assert_contains "meta id imdb" "tt" "$FIRST_ID"
echo "  primeiro meta: $(echo "$CATALOG" | jq -r '.metas[0].name') ($FIRST_ID)"

STREAMS="$(curl -sS -m 60 "$BASE/stream/$CAT_TYPE/$FIRST_ID.json")"
N_STREAMS="$(echo "$STREAMS" | jq '.streams | length')"
assert_gt "stream retorna opções" 0 "$N_STREAMS"
assert_contains "há stream com url direta (TorBox resolvido)" '"url"' "$STREAMS"
echo "  streams: $N_STREAMS opções; primeira: $(echo "$STREAMS" | jq -r '.streams[0].name // .streams[0].title // "?"' | head -c 60)"

finish_contract "04-catalog-stream"
