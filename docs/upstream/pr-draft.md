<!-- NuvioTVRoku — SPDX-License-Identifier: GPL-3.0-or-later -->
<!--
  Draft body for the upstream PR (M5 Task A3). Published in Task B8 with
  explicit user confirmation. The PR carries ONE commit: a new "Community
  clients" section in the upstream README (snippet below) — no port code.

  Suggested title:
    Add NuvioTVRoku (community Roku BrightScript port) to community clients

  The upstream README has no community-clients section today (checked on
  main: sections are "Get Nuvio TV", "Build from source", "License"), so the
  PR proposes the new section between "Build from source" and "License".
-->

Companion to the issue "BrightScript/SceneGraph port (community)" (issue
link inserted at publish time), which carries the full description; this PR
is the smaller ask.

## What this PR proposes

1. A "Community clients" section in this README, linking the port (diff
   below).
2. Screenshots of the running channel as evidence (embedded below).

## The port, briefly

[NuvioTVRoku](https://github.com/LeandroSSB/NuvioTVRoku) ports Nuvio TV to
Roku BrightScript/SceneGraph — GPLv3, backend-configurable (official
nuvio.tv backend by default, self-host override in Settings), validated by
13 contracts-frozen `curl` suites plus CI (bslint, packaging gate, live
contract run). Coverage: auth, profiles, home, detail, streams, player,
PT-BR SRT subtitles, progress sync, continue watching, search,
library/collections, addons screen, settings.

Platform cuts apply (no P2P — Roku forbids it; no CloudStream plugins —
JVM-only; no DV7 RPU conversion; SRT/VTT sidecar only): the full list is in
the issue.

## Proposed README change

The PR commit adds one section to `README.md`:

```markdown
## Community clients

- [NuvioTVRoku](https://github.com/LeandroSSB/NuvioTVRoku) — community
  BrightScript/SceneGraph port of Nuvio TV for Roku devices (GPLv3; official
  nuvio.tv backend by default, self-host override in Settings; install via
  developer-mode sideload).
```

## Scope note (why no code here)

This PR intentionally carries no port code: the port lives in its own repo so
its CI can hold the secrets the live contract suite needs. If maintainers
would rather host it in this org, that decision is theirs — the repo
transfers cleanly (GPLv3, single origin, upstream attribution in its README).

## Evidence

<!-- screenshots: embedded at publish time (M5 Task B8) -->
