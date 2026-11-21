-- Offline startup smoke test; run with Lua 5.1 from the repository root.
local frames = {}
local function frame(name)
    local f = { name = name, scripts = {}, shown = true, events = {}, points = {} }
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
function print() end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
strlower = string.lower
SlashCmdList = {}
C_AddOns = { LoadAddOn = function() end }

-- Blizzard's coordinates settings, with CVAR_UPDATE sent to the frames that
-- registered it (cvarName, value), as the client does.
local cvars = { minimapShowPlayerCoords = "0", coordsByTenths = "0" }
function GetCVarBool(name) return cvars[name] == "1" end
function SetCVar(name, value)
    cvars[name] = tostring(value)
    for _, f in ipairs(frames) do
        if f.events.CVAR_UPDATE and f.scripts.OnEvent then f.scripts.OnEvent(f, "CVAR_UPDATE", name, cvars[name]) end
    end
end

local tickers = {}
C_Timer = { NewTicker = function(_, callback)
    local ticker = { callback = callback, Cancel = function(self) self.cancelled = true end }
    tickers[#tickers + 1] = ticker
    return ticker
end }
C_Map = { GetBestMapForUnit = function() return 1 end,
          GetPlayerMapPosition = function() return { GetXY = function() return 0.5, 0.25 end } end }
UIParent = frame()
Minimap = frame("Minimap")
Minimap.SetParent = function() error("Forever must not reparent Minimap") end
Minimap.SetMaskTexture = function() error("Forever must keep Blizzard's mask") end
Minimap.CreateTexture = function() error("Forever must draw nothing on Minimap") end
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
local container = frame("MinimapContainer")
container.PlayerCoords = frame("PlayerCoords")
MinimapCluster.MinimapContainer = container

-- v1.1.0's own coordinates toggle, on: it becomes Blizzard's setting.
MidnightMinimapDB = { showCoords = true }

dofile("MidnightMinimap.lua")
assert(#frames == 0, "Classic startup ran on Forever")
dofile("Forever.lua")
assert(#frames == 1, "Forever login handler missing")
frames[1].scripts.OnEvent(frames[1], "PLAYER_LOGIN")
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
assert(not coords.shown and tickers[1].cancelled, "coordinates still shown with Blizzard's setting off")
SetCVar("minimapShowPlayerCoords", "1")
assert(coords.shown and #tickers == 2, "coordinates did not follow Blizzard's setting")

SlashCmdList.MIDNIGHTMINIMAP("header")
assert(MidnightMinimapDB.hideHeader == true, "Header setting did not change")
SlashCmdList.MIDNIGHTMINIMAP("reset")
assert(MidnightMinimapDB.hideHeader == false, "Reset did not restore Forever defaults")
assert(cvars.minimapShowPlayerCoords == "1" and coords.shown, "Reset changed Blizzard's coordinates setting")
io.write("Forever startup smoke test passed\n")
