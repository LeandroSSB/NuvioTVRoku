<div align="center">

  <img src="assets/images/icon_hd.png" alt="Nuvio TV" width="120" />

  <p>A free, open-source media app for the TV you already own — Roku edition.</p>

</div>

> **Status:** M2 (streams + player + subtitles + local resume) on top of M1
> (auth + profiles + home + detail). Port of
> [NuvioMedia/NuvioTV](https://github.com/NuvioMedia/NuvioTV) to Roku
> BrightScript/SceneGraph. Code-complete without a device: contracts + lint +
> packaging are green; UI/player validation happens when a Roku is available.

## Roadmap

- [x] M0 — foundation: repo, skeleton, lint toolchain, data contracts
- [x] M1 — auth + profiles + home + detail (blind-validated; device checks pending)
- [x] M2 — streams + player + subtitles + local resume (blind-validated; E2E pending device)
- [ ] M3 — watch-progress sync
- [ ] M4 — search, collections, addons screen, settings
- [ ] M5 — upstream PR to NuvioMedia

## Platform cuts (honest, documented)

Roku cannot run the Kotlin/web codebases of sibling Nuvio clients. This port
covers the platform-applicable surface only:

- No P2P/torrent streaming (`libtorrent4j`) — Roku forbids P2P; debrid/direct URLs only
- No CloudStream plugins (JVM-only)
- Trakt/Simkl integrations: post-upstream phase
- Dolby Vision: relies on Roku native DV decoding (no DV7 RPU conversion)
- Subtitle formats: Roku player supports SRT/VTT sidecar; ASS falls back to VTT conversion

## App flow (M1–M2)

Boot → restore session (refresh token grant) or login (e-mail/password, GoTrue)
→ profile selection (PostgREST `profiles`, RLS-scoped) → Home rows (catalogs of
the profile's Stremio addons, eager 2/addon + lazy on focus) → Detail
(seasons/episodes via meta, walking addons until one serves real meta — some
addons declare a `meta` resource but return none). Detail "Assistir" plays the
first compatible stream (AVI filtered; error → next stream); "Escolher stream"
opens the picker; subtitles: the profile's OpenSubtitles-class addons feed
sidecar SRT (PT-BR first); resume: position saved to Registry every 15s and on
pause/back, cleared on finish.

Registry keys (`nuvio` section): `backend_url`, `anon_key`, `anon_key_backend`,
`refresh_token`, `active_profile_id`. Access tokens are never persisted (2 h
expiry; refreshed on use).

Deliberate M1–M2 cuts (tracked for M4+): profile PIN, profile create/edit/delete,
logout UI, "remember last profile" toggle, avatar images (color tile + initial
instead), manual subtitle/audio track selection.

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
CI runs bslint + stage on GitHub Actions (no secrets needed).

## Repo layout

```
manifest            Roku channel manifest
assets/images/      placeholder icon/splash art (HD/SD)
source/main.brs     entry point
source/config/      backend config (Registry + well-known resolve)
components/         SceneGraph screens (MainScene; M1–M2 add home/detail/player/streams/...)
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
walking profiles (shape + `lang` + SRT format probe).

## Distribution (Roku)

Roku has no download links: a channel is installed via (1) developer sideload
(enable Developer Mode on the device, then `roku-deploy` against the device IP),
(2) an *unlisted* channel link (`my.roku.com/account/add?channel=...`, free
Roku Developer account), or (3) the public Channel Store. Community distribution
target: unlisted channel at M5.

## License

[GNU General Public License v3.0](./LICENSE)
