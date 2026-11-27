<!-- NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later -->
# Release checklist

1. [ ] manifest `major_version=0 minor_version=6` (bump if applicable)
2. [ ] CI green on main (lint-stage + contracts)
3. [ ] `bash scripts/stage-megalan.sh` → dist zip installs and runs on device
4. [ ] M1–M4 E2E checklists from the M5 plan executed; findings fixed
5. [ ] Screenshots captured (docs/screenshots/) and embedded in the README
6. [ ] Package signed with dev key (genkey) — artifact for the unlisted channel
7. [ ] Unlisted channel published (my.roku.com developer account) — link tested
8. [ ] Tag `v0.6.0-m5` + upstream issue + PR
