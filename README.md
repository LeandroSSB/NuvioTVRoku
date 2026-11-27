<div align="center">

  <img src="assets/images/icon_hd.png" alt="Nuvio TV" width="120" />

  <p>A free, open-source media app for the TV you already own — Roku edition.</p>

</div>

> **Status:** M4 (search + collections + addons screen + settings + session
> cache) on top of M1–M3 (auth + profiles + home + detail; streams + player +
> subtitles + resume; watch-progress sync + continue watching). Port of
> [NuvioMedia/NuvioTV](https://github.com/NuvioMedia/NuvioTV) to Roku
> BrightScript/SceneGraph. Code-complete without a device: contracts + lint +
> packaging are green; UI/player validation happens when a Roku is available.

## Roadmap

- [x] M0 — foundation: repo, skeleton, lint toolchain, data contracts
- [x] M1 — auth + profiles + home + detail (blind-validated; device checks pending)
- [x] M2 — streams + player + subtitles + local resume (blind-validated; E2E pending device)
- [x] M3 — watch-progress sync (PostgREST; server-preferred resume; continue-watching row)
- [x] M4 — search, collections, addons screen, settings, session cache (blind-validated; E2E pending device)
- [ ] M5 — upstream PR to NuvioMedia

## Platform cuts (honest, documented)

Roku cannot run the Kotlin/web codebases of sibling Nuvio clients. This port
covers the platform-applicable surface only:

- No P2P/torrent streaming (`libtorrent4j`) — Roku forbids P2P; debrid/direct URLs only
- No CloudStream plugins (JVM-only)
- Trakt/Simkl integrations: post-upstream phase
- Dolby Vision: relies on Roku native DV decoding (no DV7 RPU conversion)
- Subtitle formats: Roku player supports SRT/VTT sidecar; ASS falls back to VTT conversion

## App flow (M1–M4)

Boot → restore session (refresh token grant) or login (e-mail/password, GoTrue)
→ profile selection (PostgREST `profiles`, RLS-scoped) → Home rows (catalogs of
the profile's Stremio addons, eager 2/addon + lazy on focus) → Detail
(seasons/episodes via meta, walking addons until one serves real meta — some
addons declare a `meta` resource but return none). Detail "Assistir" plays the
first compatible stream (AVI filtered; error → next stream); "Escolher stream"
opens the picker; subtitles: the profile's OpenSubtitles-class addons feed
sidecar SRT (PT-BR first); resume: position saved to Registry every 15s and on
pause/back, cleared on finish. Playback pushes position to PostgREST
`watch_progress` (15s timer, pause, back, finish); Home prepends a "Continuar
assistindo" row enriched from the meta addons; resume prefers the server
position (local Registry as offline fallback).

M4 surfaces: search walks the profile's addons that declare a `search` extra
using PATH-form extras (`/catalog/{type}/{id}/search={q}.json` — the query
param is ignored by addons), deduped and capped; collections read PostgREST
`library_items` with add/remove from Detail via the table's sync RPCs; the
addons screen lists the profile's addons and enables/disables them via backend
upsert; settings cover backend override (logout + re-login), connection test,
remember-last-profile boot skip, and logout. Manifests are cached for the
session (m.global, URL-keyed, no TTL — dies with the process), so a play or
search does ~1 manifest fetch per addon instead of dozens.

Registry keys (`nuvio` section): `backend_url`, `anon_key`, `anon_key_backend`,
`refresh_token`, `active_profile_id`, `remember_last_profile`, `user_id`,
`res_<itemId>`. Access tokens are never persisted (2 h expiry; refreshed on use).

Deliberate cuts (tracked for M5+): profile PIN, profile create/edit/delete,
avatar images (color tile + initial instead), manual subtitle/audio track
selection. M4 notes: addon enable/disable goes through a backend upsert
(`POST ?on_conflict=id` merge-duplicates — roUrlTransfer has no PATCH); library
add/remove uses the `library_items` sync RPCs (add validated live; the delete
RPC authenticates but is a silent no-op with the documented key shape — pending
device-phase investigation).

- Full-charset password entry: the on-screen MiniKeyboard is case-insensitive —
  use the Roku mobile app keyboard or voice input for passwords with
  uppercase/symbols (the standard path on Roku); a full-Keyboard/KeyboardDialog
  flow is a device-phase decision.
- VTT sidecar from subtitle-svc (embedded subs): pending firmware validation
  when the device arrives — OpenSubtitles SRT is native and already covered.

## Build & lint

`scripts/lint-megalan.sh` (bslint) and `scripts/stage-megalan.sh`
(roku-deploy package → `dist/*.zip`, validates bundling without a device) run
BrightScript tooling in Docker on a remote host; nothing heavy runs locally.
CI runs bslint, the stage-zip gate, and the live contract suite on GitHub
Actions (repo secrets; forks skip the contracts job).

## Repo layout

```
manifest            Roku channel manifest
assets/images/      channel icon/splash art (SD/HD/FHD, generated from assets/brand/)
assets/brand/       official NuvioMedia logo mark + wordmark (art sources)
source/main.brs     entry point
source/config/      backend config (Registry + well-known resolve)
components/         SceneGraph screens + tasks (MainScene; M1–M4 add home/detail/player/streams/progress/search/library/addons/settings/...)
contracts/          curl suite that freezes the JSON contracts the app consumes
scripts/            lint-megalan.sh (bslint in Docker on a remote host)
package.json        toolchain (bslint, roku-deploy)
bslint.json         lint rules
LICENSE             GPLv3
```

Note: addon URLs stored in the account's addons table are a mix of base URLs and full manifest URLs — consumers must normalize (contracts/06-subs.sh shows the pattern).

## Contracts

Data contracts run anywhere with `curl` + `jq` (they are light HTTP checks):

```bash
cp contracts/creds/creds.env.example contracts/creds/creds.env  # fill once
bash contracts/run-contracts.sh
```

Coverage: `01` backend discovery (`.well-known/nuvio`, official + self-host) ·
`02` auth (Supabase GoTrue password grant) · `03` account addons (PostgREST
`addons`) · `04` catalog+stream (Stremio protocol via AIOStreams) · `05` series
meta with correct seasons (TMDB episode groups) · `06` subtitles (OpenSubtitles
v3) · `07` profiles + per-profile addons (RLS) · `08` refresh grant · `09`
per-profile addon walk: manifests → catalogs → meta fallback · `10` streams for
movie and episode `tt:s:e` (shape frozen, AVI present, ≥1 compatible
mkv/mp4/mov/m4v/hls) · `11` subtitles via OpenSubtitles-class addon found by
walking profiles (shape + `lang` + SRT format probe) · `12` `watch_progress`
read + write round-trip (ms/epoch shape, `last_watched.desc`, upsert requiring
`user_id` + `video_id`; fake row always cleaned up) · `13` search PATH-form
extras + `library_items` library RPCs (push validated live; the delete RPC
authenticates but is a documented no-op with the shipped key shape — row always
cleaned via table DELETE) + addons CRUD incl. the real toggle (upsert-by-id) +
RLS cross-account isolation.

## Sideload (developer mode)

1. On the Roku home screen press Home 3×, Up 2×, Right, Left, Right, Left, Right
   (developer settings prompt) → agree → the device reboots into dev mode.
2. Build the package zip (any machine with Docker; nothing installs locally):

   ```bash
   bash scripts/stage-megalan.sh   # → dist/nuviotvroku-<version>.zip
   ```

3. Open `http://<ROKU_IP>/plugin_dev`, upload the zip, **Install** — the channel
   launches. BrightScript console: `telnet <ROKU_IP> 8085`.
4. Drive the UI from a terminal (ECP, works for dev channels):

   ```bash
   curl -d '' http://<ROKU_IP>:8060/keypress/Select   # keys: Up Down Left Right Select Backspace Home Info
   curl -d '' 'http://<ROKU_IP>:8060/launch/dev'      # launch the dev channel
   ```

Screenshots require a signed package: `telnet <ROKU_IP> 8080` → `genkey`, then
the installer's Package tab → package with that key → sideload the `.pkg` →
installer → Utilities → Screenshot.

## License

[GNU General Public License v3.0](./LICENSE)
