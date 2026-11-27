# Release checklist

1. [ ] manifest `major_version=0 minor_version=6` (bump se aplicável)
2. [ ] CI verde na main (lint-stage + contracts)
3. [ ] `bash scripts/stage-megalan.sh` → dist zip instala e roda no device
4. [ ] E2E checklists M1–M4 do plano M5 executados; findings corrigidos
5. [ ] Screenshots capturados (docs/screenshots/) e embutidos no README
6. [ ] Package assinado com dev key (genkey) — artefato do canal unlisted
7. [ ] Canal unlisted publicado (my.roku.com developer account) — link testado
8. [ ] Tag `v0.6.0-m5` + upstream issue + PR
