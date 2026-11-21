-- test_toc.lua: the TOC. WowTestKit's checks (interface, the packager's version
-- token, every listed .lua file exists and is listed once), then MidnightMinimap's.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

-- One TOC for both clients: Forever (16001) and TBC Anniversary (20505).
Kit.checkToc(TOC, { interface = "16001, 20505" })

-- CurseForge matches files by X-Curse-Project-ID, and the `wago` job uploads to
-- the project the packaged TOC's X-Wago-ID names (References/Docs/RELEASING.md §1).
local f = assert(io.open(TOC, "rb"))
local toc = f:read("*a"):gsub("\r", "")
f:close()
check(toc:find("\n## X%-Curse%-Project%-ID: 1508638\n"), "the CurseForge project ID")
check(toc:find("\n## X%-Wago%-ID: EGPaPEN1\n"), "the Wago project ID")
check(toc:find("\n## SavedVariables: MidnightMinimapDB\n"), "the saved variables")
-- The TBC file first: it returns on Forever, where Forever.lua takes over.
local files = Kit.tocFiles(TOC)
eq(table.concat(files, ","), "MidnightMinimap.lua,Forever.lua", "the TOC's files, in order")

done("test_toc")
