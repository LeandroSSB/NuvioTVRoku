<div align="center">

  <img src="assets/images/icon_hd.png" alt="Nuvio TV" width="120" />

  <p>A free, open-source media app for the TV you already own — Roku edition.</p>

</div>

> **Status:** M0 (foundation). Port of [NuvioMedia/NuvioTV](https://github.com/NuvioMedia/NuvioTV) to Roku BrightScript/SceneGraph. Not yet usable.

## Roadmap

- [x] M0 — foundation: repo, skeleton, lint toolchain, data contracts
- [ ] M1 — auth + profiles + home + detail
- [ ] M2 — streams + player + subtitles + local resume
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

## Build & lint

See `scripts/lint-megalan.sh` (BrightScript lint runs in Docker on a remote
host; nothing runs locally except `curl`/`git`).

## Data contracts

`contracts/` freezes the exact JSON the app consumes: auth (Supabase GoTrue),
addons (PostgREST `addons` table), Stremio addon protocol (catalog/meta/stream),
subtitles. Run: `bash contracts/run-contracts.sh`.

## License

[GNU General Public License v3.0](./LICENSE)
