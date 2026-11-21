-- test_methods.lua: every widget method the Forever port calls exists on that
-- widget type in the pinned build (Kit.checkMethods, WowTestKit's README).
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

-- The exercise: as much of Forever.lua as is cheap to reach.
loadAddon({ showCoords = true }, { before = function()
    WoW.cvars = { minimapShowPlayerCoords = false, coordsByTenths = true }
    WoW.mail, WoW.senders = true, { "Thrall", "Jaina" }
end })
WoW.fireAllRegistered()
WoW.advance(2)                                 -- the coordinates ticker
for _, cmd in ipairs({ "header", "header", "clock", "clock", "zone", "zone", "coords", "coords",
                       "reset", "lock", "scale", "" }) do
    SlashCmdList.MIDNIGHTMINIMAP(cmd)
end
SetCVar("coordsByTenths", "0")
WoW.position = nil                             -- no position: the dash
WoW.advance(1)
for _, name in ipairs({ "MidnightMinimapForeverTracking", "MidnightMinimapForeverMail" }) do
    local w = _G[name]
    WoW.enter(w)
    WoW.leave(w)
end
WoW.click(MidnightMinimapForeverTracking)
check(WoW.trackingMenuOpened == 1, "the tracking button opens Blizzard's menu")
Minimap:Hide()
Minimap:Show()
WoW.tick()

local recorded = Kit.checkMethods()
check(recorded >= 40, "the exercise reached the addon (" .. recorded .. " recorded)")

done("test_methods")
