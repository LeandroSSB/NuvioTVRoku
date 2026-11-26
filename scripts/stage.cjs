// NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later
// Empacota o canal sem dispositivo (roku-deploy.package = stage+zip locais).
// Falha se nenhum zip sair — é o gate de bundling das tasks M1+.
const fs = require('fs');
const path = require('path');
const rokuDeploy = require('roku-deploy');

const ROOT = path.join(__dirname, '..');
const DIST = path.join(ROOT, 'dist');

(async () => {
  await rokuDeploy.createPackage({
    rootDir: ROOT,
    outDir: DIST,
    files: ['manifest', 'source/**/*.*', 'components/**/*.*', 'assets/**/*.*']
  });
  const zips = fs.readdirSync(DIST).filter((f) => f.endsWith('.zip'));
  if (zips.length === 0) {
    console.error('STAGE-FAIL: nenhum zip gerado');
    process.exit(1);
  }
  console.log('STAGE-OK:', zips[0]);
})().catch((e) => {
  console.error('STAGE-FAIL:', e.message);
  process.exit(1);
});
