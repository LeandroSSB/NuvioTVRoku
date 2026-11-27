#!/usr/bin/env bash
# NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
# Automação ECP do device Roku (dev channel): navegação + launch + screenshot.
# Screenshot requer o canal EMPACOTADO (genkey + .pkg assinado) — ver README §Sideload.
# Uso: ROKU_IP=192.168.0.x scripts/shot-roku.sh keys "Select Down Select"
#      ROKU_IP=... scripts/shot-roku.sh launch
#      ROKU_IP=... scripts/shot-roku.sh shot docs/screenshots/home
set -euo pipefail
: "${ROKU_IP:?export ROKU_IP=<ip do roku>}"
BASE="http://$ROKU_IP:8060"

case "${1:-}" in
  keys)   for k in ${2:?sequência de keys}; do curl -sfS -d '' "$BASE/keypress/$k"; sleep 0.6; done ;;
  launch) curl -sfS -d '' "$BASE/launch/dev" ;;
  shot)   # Utilities→Screenshot é página web (multipart) — helper captura via POST:
          # requer o canal assinado instalado; salva PNG local.
          NAME=${2:?nome do arquivo sem extensão}
          curl -sS -f "http://$ROKU_IP/plugin_inspect/screenshot" -o "$NAME.png" \
            || { echo "FAIL: screenshot indisponível — canal empacotado c/ dev key? (Task B7)"; exit 1; }
          file "$NAME.png" ;;
  *) echo "uso: $0 {keys|launch|shot} [arg]"; exit 2 ;;
esac
