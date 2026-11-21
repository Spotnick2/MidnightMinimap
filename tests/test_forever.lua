-- test_forever.lua: the Forever port's startup, its frames and settings.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local function settings(show, tenths)
    return function() WoW.cvars = { minimapShowPlayerCoords = show, coordsByTenths = tenths } end
end
local function container() return MinimapCluster.MinimapContainer end
local function label(w) return w._name or ("<" .. w._type .. ">") end

-- The TBC file returns on Forever; Forever.lua waits for the login.
WoW.reset()
for _, file in ipairs(Kit.tocFiles(TOC)) do dofile(file) end
local waiting = false
for _, f in ipairs(WoW.frames) do if f._events.PLAYER_LOGIN then waiting = true end end
check(waiting, "Forever.lua waits for PLAYER_LOGIN")
check(rawget(_G, "MidnightMinimapForeverBorder") == nil, "nothing is built before the login")

-- A failed write keeps v1.1.0's toggle for the next login, and /mm coords
-- doesn't claim it worked. The map is hidden at login (Toggle Minimap): no border.
loadAddon({ showCoords = true }, { before = function()
    settings(false, false)()
    WoW.cvarFails = true
    WoW.setShown(Minimap, false)
end })
eq(MidnightMinimapDB.showCoords, true, "v1.1.0's coordinates toggle kept while the write fails")
eq(MidnightMinimapForeverBorder:GetParent():IsShown(), false, "no border with the map hidden at login")
SlashCmdList.MIDNIGHTMINIMAP("coords")
check(lastPrint():find("Options > Interface", 1, true), "/mm coords reports the failed write: " .. tostring(lastPrint()))
eq(MidnightMinimapForeverCoords:IsShown(), false, "no coordinates while the setting is off")
-- Then the player's own change supersedes the pending migration: through
-- /mm coords (even without a CVAR_UPDATE for it)...
WoW.cvarFails, WoW.cvarSilent = false, true
SlashCmdList.MIDNIGHTMINIMAP("coords")
eq(MidnightMinimapDB.showCoords, nil, "/mm coords retires the pending migration")
-- ...or through Blizzard's Options checkbox.
loadAddon({ showCoords = true }, { before = function() settings(false, false)(); WoW.cvarFails = true end })
eq(MidnightMinimapDB.showCoords, true, "v1.1.0's coordinates toggle kept while the write fails")
WoW.cvarFails = false
SetCVar("minimapShowPlayerCoords", "1")
SetCVar("minimapShowPlayerCoords", "0")
eq(MidnightMinimapDB.showCoords, nil, "a change in Options retires the pending migration")

-- v1.1.0's coordinates toggle, on: it becomes Blizzard's setting.
loadAddon({ showCoords = true }, { before = settings(false, false) })
for _, name in ipairs({ "MidnightMinimapForeverBorder", "MidnightMinimapForeverHeader",
        "MidnightMinimapForeverTracking", "MidnightMinimapForeverCoords", "MidnightMinimapForeverMail" }) do
    check(rawget(_G, name) ~= nil, name .. " built")
end
check(SlashCmdList.MIDNIGHTMINIMAP ~= nil, "the /mm handler")

-- Nothing of ours is drawn on, parented to or anchored to Minimap: another
-- addon can borrow it (NodeRadar's scan mode, Glass MiniMap #56).
eq(#Minimap._regions, 0, "nothing drawn on Minimap")
for _, w in ipairs(allWidgets()) do
    if w ~= MinimapBackdrop then check(w._parent ~= Minimap, "parented to Minimap: " .. label(w)) end
    for _, p in ipairs(w._points) do check(p[2] ~= Minimap, "anchored to Minimap: " .. label(w)) end
end

-- The border hangs from a host on the container's CENTER, where the map is.
local host = MidnightMinimapForeverBorder:GetParent()
eq(host:GetParent(), container(), "the border's host is on the minimap container")
local point, rel, relPoint, x, y = host:GetPoint(1)
check(point == "CENTER" and rel == container() and relPoint == "CENTER" and x == 0 and y == 0,
    "the host is on the container's CENTER")
eq(host:GetNumPoints(), 1, "the host has one anchor")
for _, name in ipairs({ "MidnightMinimapForeverCoords", "MidnightMinimapForeverMail" }) do
    local f = _G[name]
    check(f:GetParent() == container() and select(2, f:GetPoint(1)) == host, name .. " is on the host")
end

-- The border goes with the map when the Toggle Minimap binding hides it...
eq(host:IsShown(), true, "the border shown with the map")
Minimap:Hide()
eq(host:IsShown(), false, "the border hidden with the map")
Minimap:Show()
eq(host:IsShown(), true, "the border back with the map")
-- ...also while the UI is hidden: the map's scripts don't run then.
UIParent:Hide()
Minimap:Hide()
UIParent:Show()
eq(host:IsShown(), false, "the border stays hidden when the UI comes back with the map toggled off")
Minimap:SetShown(true)
eq(host:IsShown(), true, "the border follows Minimap:SetShown")

-- The old toggle migrated once; Blizzard's own text faded, ours shown.
eq(WoW.cvars.minimapShowPlayerCoords, true, "v1.1.0's coordinates toggle carried over")
eq(MidnightMinimapDB.showCoords, nil, "v1.1.0's coordinates toggle removed")
eq(container().PlayerCoords:GetAlpha(), 0, "Blizzard's coordinates faded")
local coords = MidnightMinimapForeverCoords
local function liveTickers()
    local n = 0
    for _, t in ipairs(WoW.timers) do if not t.cancelled then n = n + 1 end end
    return n
end
eq(coords:IsShown(), true, "coordinates shown with Blizzard's setting on")
eq(liveTickers(), 1, "one coordinates ticker")
eq(coords.text:GetText(), "50, 25", "whole coordinates")
SetCVar("coordsByTenths", "1")
eq(coords.text:GetText(), "50.0, 25.0", "coordinates by tenths")

-- /mm coords flips Blizzard's setting, and ours follows it.
SlashCmdList.MIDNIGHTMINIMAP("coords")
eq(WoW.cvars.minimapShowPlayerCoords, false, "/mm coords turns Blizzard's setting off")
check(lastPrint():find("hidden", 1, true), "/mm coords reports the change: " .. tostring(lastPrint()))
eq(coords:IsShown(), false, "coordinates hidden with Blizzard's setting off")
eq(liveTickers(), 0, "the coordinates ticker cancelled")
SetCVar("minimapShowPlayerCoords", "1")
eq(coords:IsShown(), true, "coordinates follow Blizzard's setting")
eq(liveTickers(), 1, "the coordinates ticker back")

-- Blizzard's pieces next to ours (#5). Nothing under Tracking shows: its
-- Background and its button are all it has.
local c = MinimapCluster
eq(c.Tracking.Background:GetAlpha(), 0, "the tracking background faded")
eq(c.Tracking.Button:GetAlpha(), 0, "Blizzard's tracking button faded")
eq(c.Tracking.Button:IsMouseEnabled(), false, "Blizzard's invisible tracking button takes no clicks")
-- The calendar stays, over our header like the clock.
local headerLevel = MidnightMinimapForeverHeader:GetFrameLevel()
eq(GameTimeFrame:GetAlpha(), 1, "Blizzard's calendar kept")
check(GameTimeFrame:GetFrameLevel() > headerLevel, "the calendar over our header")
check(TimeManagerClockButton:GetFrameLevel() > headerLevel, "the clock over our header")
-- The day/night disc is hidden by default, and stays hidden when Blizzard shows it.
local diel = c.DielFrame
eq(diel:GetAlpha(), 0, "the day/night disc hidden by default")
diel:Show(); diel:SetAlpha(1)
eq(diel:GetAlpha(), 0, "the day/night disc stays hidden through Blizzard's Show and SetAlpha")
SlashCmdList.MIDNIGHTMINIMAP("daycycle")
eq(MidnightMinimapDB.showDayCycle, true, "/mm daycycle saves the choice")
eq(diel:GetAlpha(), 1, "/mm daycycle shows the disc")
eq(diel:IsMouseEnabled(), false, "the disc's mouse as Blizzard had it")
check(lastPrint():find("shown", 1, true), "/mm daycycle reports it: " .. tostring(lastPrint()))
diel:SetAlpha(0.5)
eq(diel:GetAlpha(), 0.5, "a shown disc is Blizzard's again (the hooks idle)")
SlashCmdList.MIDNIGHTMINIMAP("daynight")
eq(diel:GetAlpha(), 0, "/mm daynight hides it again")
eq(WoW.hooked[diel].Show, 1, "hidden again without a second set of hooks")
SlashCmdList.MIDNIGHTMINIMAP("daycycle")

SlashCmdList.MIDNIGHTMINIMAP("header")
eq(MidnightMinimapDB.hideHeader, true, "/mm header")
SlashCmdList.MIDNIGHTMINIMAP("reset")
eq(MidnightMinimapDB.hideHeader, false, "/mm reset restores the defaults")
eq(MidnightMinimapDB.showDayCycle, false, "/mm reset hides the day/night disc")
eq(diel:GetAlpha(), 0, "/mm reset fades the disc again")
check(WoW.cvars.minimapShowPlayerCoords == true and coords:IsShown(), "/mm reset leaves Blizzard's coordinates setting")

-- A saved choice shows the disc from the login on.
loadAddon({ showDayCycle = true })
eq(MinimapCluster.DielFrame:GetAlpha(), 1, "the day/night disc shown at login when chosen")

done("test_forever")
