-- wow_stubs.lua: MidnightMinimap's WoW: Forever mock for Lua 5.1 unit tests.
-- dofile("tests/wow_stubs.lua") FIRST in every test; drive it via the WoW table.
--
-- The mechanics are WowTestKit's core (tests/kit.lua loads the commit and the
-- build tests/kit.pin names; its README is the reference): strict globals,
-- secrets, event names checked against the build, widgets that record every
-- method called (and answer only the methods their type has on that build),
-- print with the stray-"|" check done() fails on, timers, hooksecurefunc,
-- visibility with OnShow / OnHide, fire / fireAllRegistered / tick, check / eq
-- / done. This file adds what Forever.lua touches beyond those: the Forever
-- minimap cluster as Blizzard_Minimap builds it (the same frames as Glass
-- MiniMap's stub, ..\GlassMiniMap\tests\wow_stubs.lua), and the client APIs
-- it calls. The TBC file (MidnightMinimap.lua) only reads GetBuildInfo here
-- and returns: the kit has no TBC data.

dofile("tests/kit.lua")
local newWidget = WoW.newWidget

--------------------------------------------------------------------------------
-- The Forever minimap cluster (Blizzard_Minimap\Mainline\Minimap.xml + Camelot)
--------------------------------------------------------------------------------

local function buildCluster()
    MinimapCluster = CreateFrame("Frame", "MinimapCluster", UIParent)
    local c = MinimapCluster
    c.BorderTop = CreateFrame("Frame", nil, c)
    c.ZoneTextButton = CreateFrame("Button", nil, c)
    c.ZoneTextButton._mouse = true
    -- The tracking dropdown: a DropdownButton (Menu API), whose OpenMenu is
    -- its mixin's, so a field here, not a widget method.
    c.Tracking = CreateFrame("Frame", nil, c)
    c.Tracking.Background = c.Tracking:CreateTexture(nil, "BACKGROUND")
    c.Tracking.Button = CreateFrame("Button", nil, c.Tracking)
    c.Tracking.Button._mouse = true
    c.Tracking.Button.OpenMenu = function() WoW.trackingMenuOpened = (WoW.trackingMenuOpened or 0) + 1 end
    -- 253x253: Camelot\Skin.lua sizes the container to the frame atlas (Glass
    -- MiniMap measured it on 70374); the map is 198x198 at its CENTER.
    c.MinimapContainer = CreateFrame("Frame", nil, c)
    c.MinimapContainer._width, c.MinimapContainer._height = 253, 253
    Minimap = CreateFrame("Minimap", "Minimap", c.MinimapContainer)
    Minimap._width, Minimap._height = 198, 198
    Minimap._points = { { "CENTER", c.MinimapContainer, "CENTER", 0, 0 } }
    c.MinimapContainer.Minimap = Minimap
    MinimapBackdrop = CreateFrame("Frame", "MinimapBackdrop", Minimap)
    MinimapBackdrop.StaticOverlayTexture = MinimapBackdrop:CreateTexture(nil, "OVERLAY")
    MinimapCompassTexture = MinimapBackdrop:CreateTexture(nil, "OVERLAY")
    MinimapCompassTextureUnderlay = MinimapBackdrop:CreateTexture(nil, "OVERLAY")
    c.MinimapContainer.PlayerCoords = CreateFrame("Frame", nil, c.MinimapContainer)
    -- The mail icon: a mouse-enabled frame in IndicatorFrame, shown by
    -- Blizzard on UPDATE_PENDING_MAIL while there's mail.
    c.IndicatorFrame = CreateFrame("Frame", nil, c)
    c.IndicatorFrame.MailFrame = CreateFrame("Frame", nil, c.IndicatorFrame)
    c.IndicatorFrame.MailFrame._mouse = true
    WoW.setShown(c.IndicatorFrame.MailFrame, false)
end

--------------------------------------------------------------------------------
-- State WoW.reset() clears besides the core's (WoW.onReset): the client's
-- data, and the frames Blizzard makes, built again
--------------------------------------------------------------------------------

local function resetMinimap()
    -- Blizzard's coordinates settings (Options > Interface). WoW.cvarFails:
    -- SetCVar returns false and writes nothing, as C_CVar.SetCVar can;
    -- WoW.cvarSilent: it writes without CVAR_UPDATE.
    WoW.cvars = { minimapShowPlayerCoords = false, coordsByTenths = false }
    WoW.cvarFails, WoW.cvarSilent = false, false
    WoW.zone = "Thendal Village"
    WoW.position = { 0.5, 0.25 }
    WoW.mail, WoW.senders = false, {}
    WoW.rules = {}
    WoW.trackingMenuOpened = nil
    UIParent = newWidget("Frame", nil, "UIParent")
    UIParent._level = 0
    UIParent._width, UIParent._height = 1024, 768
    GameTooltip = newWidget("GameTooltip", UIParent, "GameTooltip")
    TimeManagerClockButton = nil
    buildCluster()
    -- The stub's own calls while building Blizzard's frames are not the
    -- addon's: test_methods checks only what the addon calls (Kit.strict
    -- forgets them for the first build the same way).
    WoW.methodsCalled = {}
end
table.insert(WoW.onReset, resetMinimap)
resetMinimap()

--------------------------------------------------------------------------------
-- Client APIs (each in the 71037 dump, or a FrameXML global Blizzard's
-- Minimap.lua reads)
--------------------------------------------------------------------------------

SlashCmdList = {}
function GetBuildInfo() return "1.60.1", "71037", "Nov 18 2026", 16001 end

-- Blizzard_TimeManager makes the clock button (MinimapCluster's) when loaded.
C_AddOns = {
    LoadAddOn = function(name)
        if name == "Blizzard_TimeManager" and not rawget(_G, "TimeManagerClockButton") then
            TimeManagerClockButton = CreateFrame("Button", "TimeManagerClockButton", MinimapCluster)
        end
        return true
    end,
}

-- The names Blizzard's Minimap.lua passes (:501, :722); the values are
-- the stub's own, compared only with each other.
Enum = { GameRule = { IngameMailNotificationDisabled = 1, IngameTrackingDisabled = 76 } }
C_GameRules = { IsGameRuleActive = function(rule) return WoW.rules[rule] == true end }

function GetCVarBool(name) return WoW.cvars[name] == true end
-- Blizzard's SetCVar (CvarUtil.lua) returns C_CVar.SetCVar's boolean; the
-- client then sends CVAR_UPDATE (cvarName, value).
function SetCVar(name, value)
    if WoW.cvarFails then return false end
    local on = value == true or value == "1" or value == 1
    WoW.cvars[name] = on
    if not WoW.cvarSilent then WoW.fire("CVAR_UPDATE", name, on and "1" or "0") end
    return true
end

C_Map = {
    GetBestMapForUnit = function() return WoW.position and 1429 or nil end,
    GetPlayerMapPosition = function()
        if not WoW.position then return nil end
        return { GetXY = function() return WoW.position[1], WoW.position[2] end }
    end,
}
function GetMinimapZoneText() return WoW.zone end
function HasNewMail() return WoW.mail end
function GetLatestThreeSenders() return unpack(WoW.senders) end
-- Blizzard_Minimap's tooltip helper and its two GlobalStrings.
HAVE_MAIL = "You have unread mail"
HAVE_MAIL_FROM = "Unread mail from:"
function FormatUnreadMailTooltip(tooltip, title, senders)
    tooltip:AddLine(title)
    for _, s in ipairs(senders) do tooltip:AddLine(s) end
end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
strlower = string.lower

-- Strict globals, last: what may read as nil.
Kit.strict({ MidnightMinimapDB = true, SLASH_MIDNIGHTMINIMAP1 = true, SLASH_MIDNIGHTMINIMAP2 = true,
             TimeManagerClockButton = true })
