<!-- NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later -->
<!--
  Draft body for the upstream issue (M5 Task A3). Published in Task B8 with
  explicit user confirmation, via:

  gh issue create --repo NuvioMedia/NuvioTV \
    --title "BrightScript/SceneGraph port (community)" \
    --body-file docs/upstream/issue-draft.md
-->

Hi! We ported NuvioTV to Roku BrightScript/SceneGraph — GPLv3, about 4k lines
of BrightScript across 36 source files plus 23 SceneGraph components,
backend-configurable (the official nuvio.tv backend by default, a self-host
override in Settings), and delivered with a contracts-frozen test layer: 13
`curl` suites that freeze every JSON contract the app consumes, running in CI
next to bslint and a packaging gate.

**Repo:** <https://github.com/LeandroSSB/NuvioTVRoku>

Honest status up front: the port is code-complete and green on CI (lint,
packaging, live contracts) but has no on-device hours yet — a Roku unit is on
its way, and UI/player validation happens when it arrives. In-app strings are
PT-BR today (matching the catalogs we test against); we're happy to take
direction on localization.

## What it covers

- **Auth** — e-mail/password via GoTrue; session restore through the
  refresh-token grant; access tokens are never persisted (refreshed on use).
- **Profiles** — RLS-scoped profiles over PostgREST, each with its own addon
  list; color tile + initial as the avatar.
- **Home** — catalog rows from the profile's Stremio addons (two eager per
  addon, lazy fetch on focus).
- **Continue watching** — a "Continuar assistindo" row prepended on Home,
  enriched from the meta addons.
- **Detail** — seasons/episodes via meta, walking addons until one serves
  real meta (some declare a `meta` resource and return none).
- **Streams** — Stremio-protocol listing with AVI filtered; the first
  compatible stream autoplays, or the picker ("Escolher stream") opens.
- **Player** — native Roku playback; position saved to the Registry every 15s
  and on pause/back, cleared on finish.
- **Subtitles (PT-BR SRT)** — OpenSubtitles-class addons feed sidecar SRT,
  PT-BR preferred.
- **Progress sync** — playback pushes position to PostgREST `watch_progress`
  (15s timer, pause, back, finish); resume prefers the server position, with
  the local Registry as offline fallback.
- **Search** — walks the profile's addons that declare a `search` extra using
  PATH-form extras, deduped and capped; manifests are cached for the session,
  so a play or search costs ~1 manifest fetch per addon.
- **Library/collections** — PostgREST `library_items` with add/remove from
  Detail via the table's sync RPCs.
- **Addons** — an addons screen that enables/disables the profile's addons
  via a backend upsert (roUrlTransfer has no PATCH, so it's
  `?on_conflict=id`).
- **Settings** — backend override (logout + re-login), connection test,
  remember-last-profile boot skip, logout.

## Platform cuts (honest, documented)

Roku cannot run the Kotlin/web codebases of sibling Nuvio clients. This port
covers the platform-applicable surface only:

- No P2P/torrent streaming (`libtorrent4j`) — Roku forbids P2P; debrid/direct URLs only
- No CloudStream plugins (JVM-only)
- Trakt/Simkl integrations: post-upstream phase
- Dolby Vision: relies on Roku native DV decoding (no DV7 RPU conversion)
- Subtitle formats: Roku player supports SRT/VTT sidecar; ASS falls back to VTT conversion

## Contracts + CI

The port has no Roku emulator to test against, so the JSON layer is frozen by
13 `curl` suites (`contracts/`): backend discovery (`.well-known/nuvio`,
official + self-host), password and refresh grants, account and per-profile
addons (RLS), catalog/stream/meta/subtitle shapes, the `watch_progress`
write/read round-trip, and search/library/addon-toggle CRUD — all against the
live backend. CI runs bslint, a packaging gate, and the contract suite on
every push.

## Known gaps (documented in the repo README)

- The on-screen MiniKeyboard is case-insensitive: passwords with uppercase or
  symbols go through the Roku mobile app keyboard (the standard Roku path).
- The library delete RPC authenticates but is a silent no-op with the
  documented key shape — under investigation in the device phase.
- VTT sidecar from embedded subs awaits firmware validation; OpenSubtitles
  SRT is native and already covered.

## Why the port lives in its own repo

CI secrets for the live contract run, plus a release rhythm independent of
org policy. The companion PR proposes only a README link plus screenshots —
and we're glad to move the port into the org if maintainers prefer to own it.

## Screens

<!-- screenshots: embedded at publish time (M5 Task B8) -->

## Try it

Developer-mode sideload (including the ECP helpers used to drive the UI) is
documented in the repo README, section "Sideload (developer mode)". Feedback
and contract corrections are very welcome — the goal is for the port to track
upstream's real contracts, not a fork of them.
