-- Offline startup smoke test; run with Lua 5.1 from the repository root.
local frames, tickers, printed
local function frame(name)
    local f = { name = name, scripts = {}, hooks = {}, shown = true, events = {}, points = {} }
    setmetatable(f, { __index = function(_, key)
        if key == "CreateTexture" or key == "CreateFontString" then
            return function(self, name)
                local region = frame(name)
                region.parent = self
                if name then _G[name] = region end
                return region
            end
        elseif key == "SetScript" then
            return function(self, event, fn) self.scripts[event] = fn end
        elseif key == "HookScript" then
            return function(self, event, fn)
                self.hooks[event] = self.hooks[event] or {}
                table.insert(self.hooks[event], fn)
            end
        elseif key == "RegisterEvent" then
            return function(self, event) self.events[event] = true end
        elseif key == "GetFrameLevel" then
            return function() return 10 end
        elseif key == "SetShown" then
            return function(self, shown) self.shown = shown end
        elseif key == "IsShown" then
            return function(self) return self.shown end
        elseif key == "SetAlpha" then
            return function(self, alpha) self.alpha = alpha end
        elseif key == "SetText" then
            return function(self, text) self.text = text end
        elseif key == "SetFormattedText" then
            return function(self, fmt, ...) self.text = fmt:format(...) end
        elseif key == "SetPoint" then
            -- Nothing of ours may be anchored to Minimap: another addon can
            -- borrow it (NodeRadar's scan mode, Glass MiniMap #56).
            return function(self, point, relative, ...)
                if relative == Minimap then error("anchored to Minimap: " .. tostring(self.name), 2) end
                self.points[#self.points + 1] = { point, relative, ... }
            end
        end
        return function() end
    end })
    return f
end

-- Blizzard's coordinates settings, with CVAR_UPDATE sent to the frames that
-- registered it (cvarName, value), as the client does. With cvarFails set,
-- SetCVar returns false and writes nothing, as C_CVar.SetCVar can.
local cvars, cvarFails
function GetCVarBool(name) return cvars[name] == "1" end
function SetCVar(name, value)
    if cvarFails then return false end
    cvars[name] = tostring(value)
    for _, f in ipairs(frames) do
        if f.events.CVAR_UPDATE and f.scripts.OnEvent then f.scripts.OnEvent(f, "CVAR_UPDATE", name, cvars[name]) end
    end
    return true
end

function GetBuildInfo() return "1.60.1", "70450", "", 16001 end
function CreateFrame(_, name, parent)
    if parent == Minimap then error("parented to Minimap: " .. tostring(name), 2) end
    local f = frame(name)
    f.parent = parent
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
function hooksecurefunc() end
function GetMinimapZoneText() return "Test Zone" end
function HasNewMail() return false end
function print(msg) printed[#printed + 1] = msg end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
strlower = string.lower
C_AddOns = { LoadAddOn = function() end }
C_Timer = { NewTicker = function(_, callback)
    local ticker = { callback = callback, Cancel = function(self) self.cancelled = true end }
    tickers[#tickers + 1] = ticker
    return ticker
end }
C_Map = { GetBestMapForUnit = function() return 1 end,
          GetPlayerMapPosition = function() return { GetXY = function() return 0.5, 0.25 end } end }

-- A fresh client and a login with this saved state.
local container
local function boot(saved, settings, fails, mapHidden)
    frames, tickers, printed = {}, {}, {}
    cvars, cvarFails = settings, fails
    SlashCmdList = {}
    for _, name in ipairs({ "MidnightMinimapForeverBorder", "MidnightMinimapForeverHeader",
            "MidnightMinimapForeverTracking", "MidnightMinimapForeverCoords", "MidnightMinimapForeverMail" }) do
        _G[name] = nil
    end
    UIParent = frame()
    Minimap = frame("Minimap")
    Minimap.SetParent = function() error("Forever must not reparent Minimap") end
    Minimap.SetMaskTexture = function() error("Forever must keep Blizzard's mask") end
    Minimap.CreateTexture = function() error("Forever must draw nothing on Minimap") end
    Minimap.shown = not mapHidden
    -- ToggleMinimap's Hide/Show, with the scripts' hooks run as the client does.
    local function setShown(self, shown)
        if self.shown == shown then return end
        self.shown = shown
        for _, fn in ipairs(self.hooks[shown and "OnShow" or "OnHide"] or {}) do fn(self) end
    end
    Minimap.Hide = function(self) setShown(self, false) end
    Minimap.Show = function(self) setShown(self, true) end
    MinimapCompassTexture = frame()
    MinimapCompassTextureUnderlay = frame()
    MinimapBackdrop = { StaticOverlayTexture = frame() }
    TimeManagerClockButton = frame()
    GameTooltip = frame()
    MinimapCluster = frame("MinimapCluster")
    MinimapCluster.BorderTop = frame()
    MinimapCluster.ZoneTextButton = frame()
    MinimapCluster.Tracking = { Button = frame(), Background = frame() }
    MinimapCluster.IndicatorFrame = { MailFrame = frame() }
    container = frame("MinimapContainer")
    container.PlayerCoords = frame("PlayerCoords")
    MinimapCluster.MinimapContainer = container
    MidnightMinimapDB = saved

    dofile("MidnightMinimap.lua")
    assert(#frames == 0, "Classic startup ran on Forever")
    dofile("Forever.lua")
    assert(#frames == 1, "Forever login handler missing")
    frames[1].scripts.OnEvent(frames[1], "PLAYER_LOGIN")
end

-- A failed write keeps v1.1.0's toggle for the next login, and /mm coords
-- doesn't claim it worked. The map is hidden at login (Toggle Minimap): no border.
boot({ showCoords = true }, { minimapShowPlayerCoords = "0", coordsByTenths = "0" }, true, true)
assert(not MidnightMinimapForeverBorder.parent.shown, "the border shown with the map hidden at login")
assert(MidnightMinimapDB.showCoords == true, "v1.1.0's coordinates toggle dropped though the write failed")
SlashCmdList.MIDNIGHTMINIMAP("coords")
assert(printed[#printed]:find("Options > Interface", 1, true), "/mm coords reported success though the write failed")
assert(not MidnightMinimapForeverCoords.shown, "coordinates shown though the setting is off")

-- v1.1.0's coordinates toggle, on: it becomes Blizzard's setting.
boot({ showCoords = true }, { minimapShowPlayerCoords = "0", coordsByTenths = "0" }, false)
assert(MidnightMinimapForeverBorder, "Forever border missing")
assert(MidnightMinimapForeverHeader, "Forever header missing")
assert(MidnightMinimapForeverTracking, "Forever tracking button missing")
assert(MidnightMinimapForeverCoords, "Forever coordinates missing")
assert(SlashCmdList.MIDNIGHTMINIMAP, "Forever slash handler missing")

-- The border hangs from a host on the container's CENTER, where the map is.
local host = MidnightMinimapForeverBorder.parent
assert(host and host.parent == container, "the border's host is not on the minimap container")
assert(host.points[1][1] == "CENTER" and host.points[1][2] == container, "the host is not on the container's CENTER")
for _, name in ipairs({ "MidnightMinimapForeverCoords", "MidnightMinimapForeverMail" }) do
    local f = _G[name]
    assert(f.parent == container and f.points[1][2] == host, name .. " is not on the host")
end

-- The border goes with the map when the Toggle Minimap binding hides it.
assert(host.shown, "the border's host hidden with the map shown")
Minimap:Hide()
assert(not host.shown, "the border stayed with the map hidden")
Minimap:Show()
assert(host.shown, "the border did not come back with the map")

-- The old toggle migrated once; Blizzard's own text faded, ours shown.
assert(cvars.minimapShowPlayerCoords == "1", "v1.1.0's coordinates toggle was not carried over")
assert(MidnightMinimapDB.showCoords == nil, "v1.1.0's coordinates toggle was not removed")
assert(container.PlayerCoords.alpha == 0, "Blizzard's coordinates were not faded")
local coords = MidnightMinimapForeverCoords
assert(coords.shown and #tickers == 1, "coordinates not shown with Blizzard's setting on")
assert(coords.text.text == "50, 25", "whole coordinates expected, got " .. tostring(coords.text.text))
SetCVar("coordsByTenths", "1")
assert(coords.text.text == "50.0, 25.0", "coordinates by tenths expected, got " .. tostring(coords.text.text))

-- /mm coords flips Blizzard's setting, and ours follows it.
SlashCmdList.MIDNIGHTMINIMAP("coords")
assert(cvars.minimapShowPlayerCoords == "0", "/mm coords did not turn Blizzard's setting off")
assert(printed[#printed]:find("hidden", 1, true), "/mm coords did not report the change")
assert(not coords.shown and tickers[1].cancelled, "coordinates still shown with Blizzard's setting off")
SetCVar("minimapShowPlayerCoords", "1")
assert(coords.shown and #tickers == 2, "coordinates did not follow Blizzard's setting")

SlashCmdList.MIDNIGHTMINIMAP("header")
assert(MidnightMinimapDB.hideHeader == true, "Header setting did not change")
SlashCmdList.MIDNIGHTMINIMAP("reset")
assert(MidnightMinimapDB.hideHeader == false, "Reset did not restore Forever defaults")
assert(cvars.minimapShowPlayerCoords == "1" and coords.shown, "Reset changed Blizzard's coordinates setting")
io.write("Forever startup smoke test passed\n")
