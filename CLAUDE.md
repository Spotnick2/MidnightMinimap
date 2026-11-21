# CLAUDE.md

MidnightMinimap: a minimap restyle for **TBC Anniversary** (Interface 20505, `MidnightMinimap.lua`)
and **World of Warcraft: Forever** (Interface 16001, `Forever.lua`), in one TOC for both clients.
Each file returns early on the other client. The Forever port has never been tested in game: its
client facts come from Glass MiniMap's measurements (`..\GlassMiniMap\docs\FOREVER-PROBE.md`) and
Blizzard's UI source (`..\wow-ui-source`, branch `forever`).

## Releasing

`..\References\Docs\RELEASING.md` is the guide. A tag publishes three ways:
- **CurseForge** project **1508638** builds from the tag webhook through `.pkgmeta`
  (`## X-Curse-Project-ID`). No CurseForge key lives in the repo.
- **GitHub**: the `release` job of `.github/workflows/package-check.yml` publishes `check`'s zip
  with `release.json` and the tag's `## vX.Y.Z` section of `CHANGELOG.md` as the notes.
- **Wago Addons** project **EGPaPEN1** (https://addons.wago.io/addons/EGPaPEN1): the `wago` job
  uploads the same zip (`## X-Wago-ID`, the `WAGO_API_TOKEN` secret).

The workflow differs from the template because the TOC lists two clients: the zip is
`MidnightMinimap-<tag>.zip` (no `-forever`), `release.json` lists `forever` 16001 and `bcc` 20505,
and Wago gets `supported_forever_patches` and `supported_bc_patches`. A failed target is published
again from Actions > Package check > Run workflow (from `main`: `tag`, `publish`).

`README.curseforge.md` is the CurseForge (and Wago) description: untracked (`.git/info/exclude`),
kept out of the zip by `.pkgmeta`, pasted by the owner after a release.
