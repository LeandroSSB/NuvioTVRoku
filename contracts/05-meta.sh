#!/usr/bin/env bash
# Contrato 05: meta de séries com temporadas corretas (tmdb-meta self-host).
# GoT (tt0944947): multi-season garantido — valida o caminho episode groups/default.
source "$(dirname "$0")/lib.sh"

M="$NUVIO_BACKEND_URL/tmdb-meta/manifest.json"
MANIFEST="$(curl -sS -m 15 "$M")"
assert_eq "manifest id" "org.leandrossb.tmdbmeta" "$(json_get "$MANIFEST" .id)"
assert_contains "manifest tem resource meta" '"meta"' "$MANIFEST"

META="$(curl -sS -m 60 "$NUVIO_BACKEND_URL/tmdb-meta/meta/series/tt0944947.json")"
N_VIDEOS="$(echo "$META" | jq '.meta.videos | length')"
assert_gt "meta com episódios" 0 "$N_VIDEOS"
MAX_SEASON="$(echo "$META" | jq '[.meta.videos[].season] | max')"
assert_gt "mais de uma temporada" 1 "$MAX_SEASON"
FIRST_VIDEO="$(echo "$META" | jq -r '.meta.videos[0].id')"
assert_contains "video id no formato imdb:s:e" ":" "$FIRST_VIDEO"
echo "  GoT: $N_VIDEOS episódios, até S$MAX_SEASON"

finish_contract "05-meta"
