#!/usr/bin/env bash
# NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
# Gera arte FHD em Docker python:3.12-slim NA MEGALAN (Pillow via pip) e sincroniza de volta.
set -euo pipefail

REPO_NAME=NuvioTVRoku

rsync -a --delete \
  --exclude node_modules --exclude .git --exclude .roku --exclude dist \
  --exclude contracts/creds \
  ./ "megalan:$REPO_NAME/"

ssh megalan "docker run --rm \
  -v \$HOME/$REPO_NAME:/app -w /app \
  python:3.12-slim \
  sh -c 'pip install --quiet pillow && python scripts/gen_fhd_art.py'"

rsync "megalan:$REPO_NAME/assets/images/icon_fhd.png" \
      "megalan:$REPO_NAME/assets/images/splash_fhd.png" assets/images/
file assets/images/*_fhd.png
