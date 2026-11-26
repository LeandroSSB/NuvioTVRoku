#!/usr/bin/env bash
# NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
# Contrato 10: streams via AIOStreams (perfil 1) — movie E episódio (id tt:s:e).
# Congela: {streams:[{url,name,description,behaviorHints.filename}]}; formato
# detectável por extensão da URL OU behaviorHints.filename; AVI existe (Roku não
# reproduz — o app filtra); sempre há ≥1 stream compatível mkv|mp4|mov|m4v|hls.
source "$(dirname "$0")/lib.sh"

ANON="$(json_get "$(wellknown "$NUVIO_BACKEND_URL")" .publishable_key)"
TOKEN="$(nuvio_login "$NUVIO_BACKEND_URL" "$ANON")"
assert_not_empty "login para streams" "$TOKEN"

ADDONS="$(curl -sS -m 15 \
    "$NUVIO_BACKEND_URL/rest/v1/addons?select=url&profile_id=eq.1&enabled=eq.true&order=sort_order.asc" \
    -H "apikey: $ANON" -H "Authorization: Bearer $TOKEN")"
AIO="$(echo "$ADDONS" | jq -r '.[] | select(.url | test("aio\\.")) | .url' | head -1)"
assert_not_empty "addon AIOStreams no perfil" "$AIO"
BASE="${AIO%/manifest.json}"; case "$BASE" in *.json) BASE="${BASE%/*}";; esac

MOVIE_S="$(curl -sS -m 60 "$BASE/stream/movie/tt0111161.json")"
EPISODE_S="$(curl -sS -m 60 "$BASE/stream/series/tt0944947:1:1.json")"
assert_contains "movie streams é array" '"streams"' "$MOVIE_S"
assert_contains "episode streams é array" '"streams"' "$EPISODE_S"
assert_gt "movie tem streams" 0 "$(echo "$MOVIE_S" | jq '.streams | length')"
assert_gt "episódio tem streams" 0 "$(echo "$EPISODE_S" | jq '.streams | length')"

detect() { # url filename → mp4|mkv|hls|avi|unknown (espelha lib/Streams.brs DetectStreamFormat)
    python3 - "$1" "$2" <<'PY'
import re, sys
for s in sys.argv[1:]:
    if not s: continue
    m = re.search(r'\.(mkv|mk3d|mka|mks)(\?.*)?$', s, re.I)
    if m: print("mkv"); raise SystemExit
    m = re.search(r'\.(mp4|m4v|mov)(\?.*)?$', s, re.I)
    if m: print("mp4"); raise SystemExit
    m = re.search(r'\.m3u8(\?.*)?$', s, re.I)
    if m: print("hls"); raise SystemExit
    m = re.search(r'\.avi(\?.*)?$', s, re.I)
    if m: print("avi"); raise SystemExit
print("unknown")
PY
}

COUNT_OK=0
for BODY in "$MOVIE_S" "$EPISODE_S"; do
    N_PLAY=$(echo "$BODY" | jq -r '.streams[] | [.url, (.behaviorHints.filename // "")] | @tsv' \
        | while IFS=$'\t' read -r U FN; do detect "$U" "$FN"; done | grep -cvE '^(avi|unknown)$' || true)
    COUNT_OK=$((COUNT_OK + N_PLAY))
done
assert_gt "≥1 stream compatível (movie + episódio somados)" 1 "$COUNT_OK"
assert_gt "streams AVI existem (app DEVE filtrar)" 0 "$(echo "$EPISODE_S" | jq -r '.streams[] | [.url, (.behaviorHints.filename // "")] | @tsv' | while IFS=$'\t' read -r U FN; do detect "$U" "$FN"; done | grep -c '^avi$' || true)"
echo "  movie: $(echo "$MOVIE_S" | jq '.streams | length') streams; episódio: $(echo "$EPISODE_S" | jq '.streams | length'); compatíveis detectados: $COUNT_OK"

finish_contract "10-streams"
