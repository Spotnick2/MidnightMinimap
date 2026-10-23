-- Offline startup smoke test; run with Lua 5.1 from the repository root.
local frames = {}
local function frame(name)
    local f = { name = name, scripts = {}, shown = true }
    setmetatable(f, { __index = function(_, key)
        if key == "CreateTexture" or key == "CreateFontString" then
            return function(_, name)
                local region = frame(name)
                if name then _G[name] = region end
                return region
            end
        elseif key == "SetScript" then
            return function(self, event, fn) self.scripts[event] = fn end
        elseif key == "GetFrameLevel" then
            return function() return 10 end
        elseif key == "SetShown" then
            return function(self, shown) self.shown = shown end
        elseif key == "IsShown" then
            return function(self) return self.shown end
        elseif key == "SetText" then
            return function(self, text) self.text = text end
        end
        return function() end
    end })
    return f
end

function GetBuildInfo() return "1.60.1", "70450", "", 16001 end
function CreateFrame(_, name)
    local f = frame(name)
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
MinimapCluster.MinimapContainer = frame()

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
SlashCmdList.MIDNIGHTMINIMAP("coords")
assert(MidnightMinimapDB.showCoords == true, "Coordinates setting did not change")
assert(#tickers == 1, "Coordinates ticker did not start")
SlashCmdList.MIDNIGHTMINIMAP("header")
assert(MidnightMinimapDB.hideHeader == true, "Header setting did not change")
SlashCmdList.MIDNIGHTMINIMAP("reset")
assert(MidnightMinimapDB.hideHeader == false and MidnightMinimapDB.showCoords == false,
    "Reset did not restore Forever defaults")
assert(tickers[1].cancelled, "Coordinates ticker did not stop")
io.write("Forever startup smoke test passed\n")
