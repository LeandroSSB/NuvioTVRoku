<!-- NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later -->

# Upstream PR scope: what the PR carries vs. what stays in this repo

Decision record for M5 (Task A3). Companion drafts:
`docs/upstream/issue-draft.md` and `docs/upstream/pr-draft.md`.

## Decision

The port lives in `LeandroSSB/NuvioTVRoku` and stays there. The PR to
`NuvioMedia/NuvioTV` is link-only — it does not carry the port's diff:

| Carried by the upstream PR | Stays in this repo |
| --- | --- |
| One README section ("Community clients") linking the port — a new section, since the upstream README has none today | The entire BrightScript/SceneGraph port |
| Screenshots as evidence (captured in Task B7, embedded in Task B8) | `contracts/` — the 13-suite frozen contract layer |
| A reference to the issue (full description, platform cuts, known gaps) | CI workflows plus the repo secrets the live contract run needs (backend URL + account credentials) |
| | The release ritual: branch → PR → CI green (lint-stage + contracts) → merge rebase |

## Why

1. **CI secrets.** The contract suite is the port's only automated validation
   (no Roku emulator exists), and it needs live-backend credentials as repo
   secrets — fork PRs already get no secrets and skip the job. Keeping the
   repo where those secrets exist keeps every push validated end to end.
2. **Ritual independence.** This repo's merge rite runs at the cadence the
   port needs — notably during the device phase, where fix waves land
   back-to-back — without coupling to org CI policy, branch protection, or
   org-level defaults.

## Rejected alternative

Moving the port into the NuvioMedia org (a code PR or a repo transfer):

- **Loses the CI secrets.** A freshly transferred (or newly created in-org)
  repo starts without the backend credentials, so the contract suite — the
  TDD layer that substitutes for a Roku emulator — goes dark until an org
  admin re-provisions them.
- **Loses the ritual independence.** Merge rites, branch protection, and CI
  policy would follow org defaults instead of the port's own.

## If the org prefers to own the code

That call is the org's (Task B8 posture: publish link-only, offer the
transfer). The repo moves cleanly — GPLv3, single origin, upstream
attribution in its README — and the contracts job resumes as soon as the
secrets are re-provisioned on the org side.
