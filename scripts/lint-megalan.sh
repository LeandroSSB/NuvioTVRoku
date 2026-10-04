#!/usr/bin/env bash
# Lint do NuvioTVRoku — roda em Docker node:22-alpine NA MEGALAN.
# Regra da máquina: npm/build nunca no WSL; host megalan não tem node → Docker.
# node_modules persiste no volume do container via cache npm nomeado.
set -euo pipefail

REPO_NAME=NuvioTVRoku
REMOTE_DIR="\$HOME/$REPO_NAME"

# rsync >=3.2 escapa '$' no comando remoto (sem expansão de $HOME pelo shell);
# caminho relativo em destino remoto resolve a partir do home do usuário.
rsync -a --delete \
  --exclude node_modules --exclude .git --exclude .roku --exclude dist \
  ./ "megalan:$REPO_NAME/"

ssh megalan "docker run --rm \
  -v $REMOTE_DIR:/app -w /app \
  -v nuviotvroku-npmcache:/root/.npm \
  node:22-alpine \
  sh -c 'npm install --no-audit --no-fund >/dev/null 2>&1 && npx bslint'"
