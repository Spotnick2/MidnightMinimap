-- The TOC declares the release targets; run with Lua 5.1 from the repository root.
-- CurseForge matches files by X-Curse-Project-ID, and the `wago` job uploads to the
-- project the packaged TOC's X-Wago-ID names (References/Docs/RELEASING.md §1).
local f = assert(io.open("MidnightMinimap.toc", "rb"))
local toc = f:read("*a"):gsub("\r", "")
f:close()
assert(toc:find("\n## X%-Curse%-Project%-ID: 1508638\n"), "the TOC has no X-Curse-Project-ID 1508638")
assert(toc:find("\n## X%-Wago%-ID: EGPaPEN1\n"), "the TOC has no X-Wago-ID EGPaPEN1")
assert(toc:find("\n## Version: @project%-version@\n"), "the TOC's version is not the packager's token")
io.write("TOC test passed\n")
