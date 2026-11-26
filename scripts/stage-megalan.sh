#!/usr/bin/env bash
# NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
# Stage do canal (roku-deploy package → dist/*.zip) em Docker node:22-alpine NA MEGALAN.
set -euo pipefail

REPO_NAME=NuvioTVRoku

rsync -a --delete \
  --exclude node_modules --exclude .git --exclude .roku --exclude dist \
  --exclude contracts/creds \
  ./ "megalan:$REPO_NAME/"

ssh megalan "docker run --rm \
  -v \$HOME/$REPO_NAME:/app -w /app \
  -v nuviotvroku-npmcache:/root/.npm \
  node:22-alpine \
  sh -c 'npm install --no-audit --no-fund > /tmp/nuviotvroku-npm.log 2>&1 || { cat /tmp/nuviotvroku-npm.log >&2; exit 1; } && node scripts/stage.cjs'"
