# CLAUDE.md

MidnightMinimap: a minimap restyle for **TBC Anniversary** (Interface 20505, `MidnightMinimap.lua`)
and **World of Warcraft: Forever** (Interface 16001, `Forever.lua`), in one TOC for both clients.
Each file returns early on the other client. The Forever port has never been tested in game: its
client facts come from Glass MiniMap's measurements (`..\GlassMiniMap\docs\FOREVER-PROBE.md`) and
Blizzard's UI source (`..\wow-ui-source`, branch `forever`).

## Testing

```powershell
pwsh tests\run.ps1                                                   # luac -p on the TOC's files and the tests, then every tests\test_*.lua
& 'C:\Program Files (x86)\Lua\5.1\lua.exe' tests\test_forever.lua   # one test, from the repo root, once run.ps1 has fetched the kit
```

The test scaffolding is WowTestKit (`C:\Projects\WoW\WowTestKit`; its README is the reference)
at the commit and client build `tests\kit.pin` names. `tests\run.ps1` puts that commit in
`%LOCALAPPDATA%\WowTestKit\<sha>` and hands off to the kit's runner; CI fetches it with
`tests\fetch_kit.sh`. `tests\kit.lua`, `kit.ps1` and `fetch_kit.sh` are the kit's bootstrap
copies: never edit them here. A kit need is an issue on the kit, worked around in
`tests\wow_stubs.lua` with a `-- WowTestKit #N:` comment meanwhile. `tests\run.ps1 -KitDev`
runs against the `..\WowTestKit` working copy instead of the pin.

On top of the kit: `tests\wow_stubs.lua` (the Forever minimap cluster `Forever.lua` touches, and
the client APIs it calls), `tests\harness.lua` (`loadAddon`, `allWidgets`, `lastPrint`),
`test_forever.lua` (startup, the frames' anchors and visibility, the coordinates settings),
`test_methods.lua` (`Kit.checkMethods`: every widget method called exists on that type in the
pinned build) and `test_toc.lua`. The kit has Forever data only: `MidnightMinimap.lua`'s TBC path
is syntax-checked, not run. Mutation-test every new test.

Shell heredocs here collapse `\\` to `\`: write files that hold Windows paths or Lua backslash
escapes with the Write/Edit tools.

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
