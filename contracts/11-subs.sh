#!/usr/bin/env bash
# NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
# Contrato 11: legendas via addon OpenSubtitles (walk por perfil) — shape
# {subtitles:[{id,url,lang}]}, lang ISO-639-2 ("por" disponível), e FORMATO do
# arquivo: SRT (content-type x-subrip ou timestamp HH:MM:SS,mmm) — o M0 assumia
# VTT; sondagem de 26/11 provou SRT. O app percorre os perfis p/ achar um perfil
# com addon de subtitles (o perfil 1 do usuário não tem — app lida com ausência).
source "$(dirname "$0")/lib.sh"

ANON="$(json_get "$(wellknown "$NUVIO_BACKEND_URL")" .publishable_key)"
TOKEN="$(nuvio_login "$NUVIO_BACKEND_URL" "$ANON")"
assert_not_empty "login para subs" "$TOKEN"

PROFILES="$(curl -sS -m 15 "$NUVIO_BACKEND_URL/rest/v1/profiles?select=profile_id&order=profile_index.asc" \
    -H "apikey: $ANON" -H "Authorization: Bearer $TOKEN")"
OS_URL="" ; OS_PROFILE=""
for PID in $(echo "$PROFILES" | jq -r '.[].profile_id'); do
    ADDONS="$(curl -sS -m 15 \
        "$NUVIO_BACKEND_URL/rest/v1/addons?select=url&profile_id=eq.$PID&enabled=eq.true" \
        -H "apikey: $ANON" -H "Authorization: Bearer $TOKEN")"
    FOUND="$(echo "$ADDONS" | jq -r '.[] | select(.url | test("opensubtitles"; "i")) | .url' | head -1)"
    if [ -n "$FOUND" ]; then OS_URL="$FOUND"; OS_PROFILE="$PID"; break; fi
done
assert_not_empty "algum perfil tem addon OpenSubtitles" "$OS_URL"
echo "  perfil c/ OS: $OS_PROFILE"

OS_BASE="${OS_URL%/manifest.json}"; case "$OS_BASE" in *.json) OS_BASE="${OS_BASE%/*}";; esac
SUBS="$(curl -sS -m 30 "$OS_BASE/subtitles/series/tt0944947:1:1.json")"
assert_contains "subs resposta com estrutura válida" '"subtitles"' "$SUBS"
assert_gt "episódio tem legendas" 0 "$(echo "$SUBS" | jq '.subtitles | length')"
assert_gt "legendas pt (por) disponíveis" 0 "$(echo "$SUBS" | jq '[.subtitles[] | select(.lang == "por")] | length')"
assert_eq "lang é ISO-639-2 (3 letras)" "true" "$(echo "$SUBS" | jq -r '[.subtitles[].lang | test("^[a-z]{3}$")] | all')"

POR_URL="$(echo "$SUBS" | jq -r '[.subtitles[] | select(.lang == "por")][0].url')"
assert_not_empty "url da 1ª legenda por" "$POR_URL"
FIRST="$(curl -sSL -m 20 "$POR_URL" | head -c 60 || true)" # || true: head fecha o pipe (SIGPIPE→curl 23) e pipefail abortaria o script

case "$FIRST" in
    *","*"-->"*|*"-->"*) echo "  ok: formato SRT (timestamp HH:MM:SS,mmm)"; PASS_COUNT=$((PASS_COUNT + 1));;
    WEBVTT*) echo "  FAIL: veio VTT — o app esperava SRT (x-subrip)"; FAIL_COUNT=$((FAIL_COUNT + 1));;
    *) echo "  FAIL: formato desconhecido: $FIRST"; FAIL_COUNT=$((FAIL_COUNT + 1));;
esac
CT="$(curl -sSL -m 20 -o /dev/null -w '%{content_type}' "$POR_URL")"
assert_contains "content-type é subrip" "subrip" "$CT"

finish_contract "11-subs"
