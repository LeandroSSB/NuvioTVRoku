#!/usr/bin/env bash
# Contrato 06: legendas via addon OpenSubtitles v3 (URL descoberta na tabela addons).
# Shawshank (tt0111161): catálogo garantido de legendas pt/en.
source "$(dirname "$0")/lib.sh"

ANON="$(json_get "$(wellknown "$NUVIO_BACKEND_URL")" .publishable_key)"
TOKEN="$(nuvio_login "$NUVIO_BACKEND_URL" "$ANON")"
assert_not_empty "login para descobrir addon" "$TOKEN"

ADDONS="$(curl -sS -m 15 \
    "$NUVIO_BACKEND_URL/rest/v1/addons?select=url" \
    -H "apikey: $ANON" -H "Authorization: Bearer $TOKEN")"
OS_URL="$(echo "$ADDONS" | jq -r '.[] | select(.url | test("opensubtitles"; "i")) | .url' | head -1)"
assert_not_empty "addon OpenSubtitles encontrado na conta" "$OS_URL"

# A tabela addons guarda a URL base (sem /manifest.json) — normaliza antes de buscar.
OS_MANIFEST_URL="$OS_URL"
case "$OS_URL" in *manifest.json) ;; *) OS_MANIFEST_URL="$OS_URL/manifest.json";; esac
OS_MANIFEST="$(curl -sS -m 15 "$OS_MANIFEST_URL")"
assert_contains "manifest OS tem resource subtitles" '"subtitles"' "$OS_MANIFEST"

OS_BASE="${OS_MANIFEST_URL%/manifest.json}"
SUBS="$(curl -sS -m 30 "$OS_BASE/subtitles/movie/tt0111161.json")"
assert_contains "resposta subtitles com estrutura válida" '"subtitles"' "$SUBS"
N_SUBS="$(echo "$SUBS" | jq '.subtitles | length')"
assert_gt "Shawshank tem legendas disponíveis" 0 "$N_SUBS"
echo "  $N_SUBS legendas; idiomas: $(echo "$SUBS" | jq -r '[.subtitles[].lang // .subtitles[].id | strings] | unique | .[0:5] | join(",")' 2>/dev/null)"

finish_contract "06-subs"
