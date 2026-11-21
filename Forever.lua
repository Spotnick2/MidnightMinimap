-- WoW: Forever minimap styling. Blizzard owns the Edit Mode minimap cluster;
-- all new art follows it and the original controls stay under Blizzard's parent.
--
-- Nothing of ours is parented or anchored to Minimap. Another addon may borrow
-- the map for a few frames: NodeRadar's scan mode moves it under the cursor at
-- alpha 0, and anything anchored to it went along (measured by Glass MiniMap,
-- its #56, on 1.60.1.70862). Our pieces hang from a host on
-- MinimapCluster.MinimapContainer's CENTER, where Blizzard puts the map, sized
-- once to the map's 198 px (Minimap.xml; 198x198 at every Edit Mode scale,
-- Glass MiniMap's probe on 70450). Edit Mode scales the container, so the host
-- follows it.
--
-- The coordinates are Blizzard's setting, not ours: "Player Minimap
-- Coordinates" (minimapShowPlayerCoords) shows them and "Coordinates by
-- Tenths" (coordsByTenths) rounds them, both in Options > Interface. Blizzard's
-- own text (MinimapContainer.PlayerCoords) is faded and ours shows in its
-- place, so there is one readout and one setting (Glass MiniMap's way).
local interface = select(4, GetBuildInfo())
if interface < 16000 or interface >= 17000 then return end

local TEXPATH = "Interface\\AddOns\\MidnightMinimap\\Textures\\"
local ATLAS = TEXPATH .. "uiminimap2x"
local BORDER_L, BORDER_R = 0.001953125, 0.857421875
local BORDER_T, BORDER_B = 0.056640625, 0.505859375
local PANEL_L, PANEL_R = 0.861328, 0.9375
local PANEL_T, PANEL_B = 0.392578, 0.429688
local TRACK_L, TRACK_R = 0.291016, 0.349609
local TRACK_T, TRACK_B = 0.507812, 0.535156
local MAIL_L, MAIL_R = 0.08203125, 0.158203125
local MAIL_T, MAIL_B = 0.5078125, 0.537109375
local MAP_SIZE = 198
local SHOW_COORDS, BY_TENTHS = "minimapShowPlayerCoords", "coordsByTenths"

local defaults = {
    hideZoneText = false,
    hideClock = false,
    hideHeader = false,
}
local db, host, header, panel, zone, coords, mail, clock, coordTicker
local hidden = setmetatable({}, { __mode = "k" })

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function ZoneText()
    local ok, text = pcall(GetMinimapZoneText)
    if ok and not IsSecret(text) and type(text) == "string" then return text end
    return ""
end

local function GameRuleActive(name)
    local rule = Enum and Enum.GameRule and Enum.GameRule[name]
    if not (rule and C_GameRules and C_GameRules.IsGameRuleActive) then return false end
    local ok, active = pcall(C_GameRules.IsGameRuleActive, rule)
    return ok and not IsSecret(active) and active == true
end

local function CVarOn(name)
    local ok, on = pcall(GetCVarBool, name)
    return ok and not IsSecret(on) and on == true
end

local function Fade(region)
    if not region or not region.SetAlpha then return end
    if hidden[region] then return end
    hidden[region] = true
    local busy
    local function refade(self)
        if not hidden[self] or busy then return end
        busy = true
        pcall(self.SetAlpha, self, 0)
        if self.EnableMouse then pcall(self.EnableMouse, self, false) end
        busy = false
    end
    for _, method in ipairs({ "Show", "SetShown", "SetAlpha" }) do
        if type(region[method]) == "function" then
            pcall(hooksecurefunc, region, method, refade)
        end
    end
    refade(region)
end

local function SetPanelTexture(texture)
    texture:SetTexture(ATLAS)
    texture:SetTexCoord(PANEL_L, PANEL_R, PANEL_T, PANEL_B)
    texture:SetAllPoints()
    if texture.SetTextureSliceMode then
        texture:SetTextureSliceMode(1)
        texture:SetTextureSliceMargins(20, 20, 25, 25)
    end
end

local function UpdateHeader()
    local show = not db.hideHeader
    header:SetShown(show)
    panel:SetShown(show and (not db.hideZoneText or not db.hideClock))
    zone:SetShown(show and not db.hideZoneText)
    if clock then
        clock:SetAlpha(show and not db.hideClock and 1 or 0)
        clock:EnableMouse(show and not db.hideClock)
    end
end

local function UpdateCoords()
    if not coords:IsShown() then return end
    local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
    if ok and not IsSecret(mapID) and mapID then
        local got, position = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
        if got and not IsSecret(position) and position then
            local xy, x, y = pcall(position.GetXY, position)
            if xy and not IsSecret(x) and not IsSecret(y) and type(x) == "number" and type(y) == "number" then
                -- Rounded as Blizzard's PlayerCoords does (MinimapPlayerCoordsMixin).
                if CVarOn(BY_TENTHS) then
                    coords.text:SetFormattedText("%.1f, %.1f", x * 100, y * 100)
                else
                    coords.text:SetFormattedText("%d, %d", math.floor(x * 100 + 0.5), math.floor(y * 100 + 0.5))
                end
                return
            end
        end
    end
    coords.text:SetText("---")
end

-- Shown while Blizzard's "Player Minimap Coordinates" is on (CVAR_UPDATE
-- calls this again when either setting changes).
local function ApplyCoords()
    local show = CVarOn(SHOW_COORDS)
    coords:SetShown(show)
    if show then
        if not coordTicker then coordTicker = C_Timer.NewTicker(0.5, UpdateCoords) end
        UpdateCoords()
    elseif coordTicker then
        coordTicker:Cancel()
        coordTicker = nil
    end
end

local function UpdateMail()
    local ok, hasMail = pcall(HasNewMail)
    if not ok or IsSecret(hasMail) then hasMail = false end
    mail:SetShown(hasMail == true and not GameRuleActive("IngameMailNotificationDisabled"))
end

local function ShowMailTooltip()
    GameTooltip:SetOwner(mail, "ANCHOR_LEFT")
    local senders = {}
    if GetLatestThreeSenders then
        local ok, a, b, c = pcall(GetLatestThreeSenders)
        if ok then
            local got = { a, b, c }
            for i = 1, 3 do
                local name = got[i]
                if not IsSecret(name) and type(name) == "string" and name ~= "" then
                    senders[#senders + 1] = name
                end
            end
        end
    end
    local title = #senders > 0 and (HAVE_MAIL_FROM or "Unread mail from:") or (HAVE_MAIL or "You have unread mail")
    if FormatUnreadMailTooltip then
        FormatUnreadMailTooltip(GameTooltip, title, senders)
    else
        GameTooltip:SetText(title)
    end
    GameTooltip:Show()
end

local function Init()
    MidnightMinimapDB = MidnightMinimapDB or {}
    db = MidnightMinimapDB
    for key, value in pairs(defaults) do
        if db[key] == nil then db[key] = value end
    end

    local cluster = MinimapCluster
    local map = Minimap
    local container = cluster and cluster.MinimapContainer
    if not (cluster and cluster.ZoneTextButton and map and container) then
        print("|cffff8800MidnightMinimap|r: Forever minimap frames are unavailable.")
        return
    end

    -- v1.1.0 had its own coordinates toggle (showCoords). The setting is now
    -- Blizzard's: a player who had ours on gets Blizzard's turned on, once.
    -- SetCVar can fail without an error (C_CVar.SetCVar returns false), so the
    -- old flag goes only once the setting reads on; else the next login
    -- retries, unless the player changes the setting first (CVAR_UPDATE below:
    -- their choice wins, Codex, #4).
    if db.showCoords == true then
        pcall(SetCVar, SHOW_COORDS, "1")
        if CVarOn(SHOW_COORDS) then db.showCoords = nil end
    elseif db.showCoords ~= nil then
        db.showCoords = nil
    end

    -- Blizzard reapplies its compass atlas when rotation changes. Leave the
    -- stock minimap mask in place; it is also reapplied there.
    Fade(MinimapCompassTexture)
    Fade(MinimapCompassTextureUnderlay)
    Fade(MinimapBackdrop and MinimapBackdrop.StaticOverlayTexture)
    Fade(cluster.BorderTop)
    Fade(cluster.ZoneTextButton)
    Fade(cluster.Tracking and cluster.Tracking.Button)
    Fade(cluster.Tracking and cluster.Tracking.Background)
    Fade(container.PlayerCoords)

    -- The host stands where the map is, never on it (see the top of the file).
    -- One level over the map, as the border texture on the map's OVERLAY was.
    host = CreateFrame("Frame", nil, container)
    host:SetSize(MAP_SIZE, MAP_SIZE)
    host:SetPoint("CENTER", container, "CENTER", 0, 0)
    host:SetFrameLevel(map:GetFrameLevel() + 1)
    -- Shown with the map. The Toggle Minimap binding (ToggleMinimap) hides
    -- Minimap but not its container, and a border drawn on the map used to go
    -- with it (Codex, #4). Only the shown state is followed: a borrow (alpha
    -- 0, moved) never hides the map, so the host stays put through a scan.
    -- The map's own Show/Hide/SetShown calls are hooked, not its OnShow and
    -- OnHide scripts: with the UI hidden, the map's flag changes without
    -- either script running, and the host would come back stale (Codex, #4).
    local function FollowMap()
        local ok, shown = pcall(map.IsShown, map)
        if ok and not IsSecret(shown) then host:SetShown(shown == true) end
    end
    for _, method in ipairs({ "Show", "Hide", "SetShown" }) do
        pcall(hooksecurefunc, map, method, FollowMap)
    end
    FollowMap()

    local border = host:CreateTexture("MidnightMinimapForeverBorder", "OVERLAY", nil, 7)
    border:SetTexture(ATLAS)
    border:SetTexCoord(BORDER_L, BORDER_R, BORDER_T, BORDER_B)
    border:SetSize(220, 229)
    border:SetPoint("CENTER", host, "CENTER", 1, 0)

    header = CreateFrame("Frame", "MidnightMinimapForeverHeader", cluster)
    header:SetAllPoints(cluster.ZoneTextButton)
    header:SetFrameLevel(cluster.ZoneTextButton:GetFrameLevel() + 1)
    panel = header:CreateTexture(nil, "BACKGROUND")
    SetPanelTexture(panel)

    zone = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    zone:SetPoint("LEFT", header, "LEFT", 25, 0)
    zone:SetPoint("RIGHT", header, "RIGHT", -41, 0)
    zone:SetJustifyH("LEFT")
    zone:SetText(ZoneText())

    local tracking = CreateFrame("Button", "MidnightMinimapForeverTracking", header)
    tracking:SetSize(20, 20)
    tracking:SetPoint("LEFT", header, "LEFT", 3, 0)
    local icon = tracking:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ATLAS)
    icon:SetTexCoord(TRACK_L, TRACK_R, TRACK_T, TRACK_B)
    icon:SetAllPoints()
    tracking:SetScript("OnClick", function()
        local button = cluster.Tracking and cluster.Tracking.Button
        if button and button.OpenMenu then button:OpenMenu() end
    end)
    tracking:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Tracking")
        GameTooltip:Show()
    end)
    tracking:SetScript("OnLeave", function() GameTooltip:Hide() end)
    if not (cluster.Tracking and cluster.Tracking.Button) or GameRuleActive("IngameTrackingDisabled") then
        tracking:Hide()
    end

    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_TimeManager")
    end
    clock = TimeManagerClockButton
    if clock then clock:SetFrameLevel(header:GetFrameLevel() + 1) end
    UpdateHeader()

    coords = CreateFrame("Frame", "MidnightMinimapForeverCoords", container)
    coords:SetSize(80, 18)
    coords:SetFrameLevel(map:GetFrameLevel() + 2)
    coords:SetPoint("TOP", host, "BOTTOM", 0, -10)
    local bg = coords:CreateTexture(nil, "BACKGROUND")
    SetPanelTexture(bg)
    coords.text = coords:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    coords.text:SetPoint("CENTER")
    ApplyCoords()

    mail = CreateFrame("Frame", "MidnightMinimapForeverMail", container)
    mail:SetSize(20, 16)
    mail:SetFrameLevel(map:GetFrameLevel() + 2)
    mail:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 12, 12)
    local envelope = mail:CreateTexture(nil, "ARTWORK")
    envelope:SetTexture(ATLAS)
    envelope:SetTexCoord(MAIL_L, MAIL_R, MAIL_T, MAIL_B)
    envelope:SetAllPoints()
    mail:EnableMouse(true)
    mail:SetScript("OnEnter", ShowMailTooltip)
    mail:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Fade(cluster.IndicatorFrame and cluster.IndicatorFrame.MailFrame)
    UpdateMail()

    local events = CreateFrame("Frame")
    for _, event in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "UPDATE_PENDING_MAIL", "PLAYER_ENTERING_WORLD", "CVAR_UPDATE" }) do
        events:RegisterEvent(event)
    end
    events:SetScript("OnEvent", function(_, event, name)
        if event == "CVAR_UPDATE" then
            if name == SHOW_COORDS then
                -- A change the player makes supersedes a migration still pending.
                db.showCoords = nil
                ApplyCoords()
            elseif name == BY_TENTHS then
                UpdateCoords()
            end
            return
        end
        if event == "UPDATE_PENDING_MAIL" or event == "PLAYER_ENTERING_WORLD" then UpdateMail() end
        if event ~= "UPDATE_PENDING_MAIL" then zone:SetText(ZoneText()) end
    end)

    SLASH_MIDNIGHTMINIMAP1 = "/midnightminimap"
    SLASH_MIDNIGHTMINIMAP2 = "/mm"
    SlashCmdList.MIDNIGHTMINIMAP = function(msg)
        local cmd = strlower(strtrim(msg or ""))
        if cmd == "header" then
            db.hideHeader = not db.hideHeader
            UpdateHeader()
        elseif cmd == "clock" then
            db.hideClock = not db.hideClock
            UpdateHeader()
        elseif cmd == "zone" then
            db.hideZoneText = not db.hideZoneText
            UpdateHeader()
        elseif cmd == "coords" or cmd == "coord" or cmd == "xy" then
            -- Blizzard's setting, the same as the Options checkbox. CVAR_UPDATE
            -- then shows or hides ours. Success is the setting reading back as
            -- asked: SetCVar can return false instead of raising (Codex, #4).
            local on = not CVarOn(SHOW_COORDS)
            pcall(SetCVar, SHOW_COORDS, on and "1" or "0")
            if CVarOn(SHOW_COORDS) ~= on then
                print("|cffff8800MidnightMinimap|r: Coordinates are Blizzard's setting: Options > Interface > Player Minimap Coordinates.")
                return
            end
            -- Here too, in case CVAR_UPDATE doesn't come for our own write.
            db.showCoords = nil
            ApplyCoords()
            print("|cffff8800MidnightMinimap|r: Coordinates " .. (on and "shown" or "hidden") .. " (Blizzard's Player Minimap Coordinates setting).")
            return
        elseif cmd == "reset" then
            -- Our own choices only: the coordinates are Blizzard's setting.
            for key, value in pairs(defaults) do db[key] = value end
            UpdateHeader()
        elseif cmd == "lock" or cmd == "scale" then
            print("|cffff8800MidnightMinimap|r: Use Edit Mode to move or scale the Forever minimap.")
            return
        else
            print("|cffff8800MidnightMinimap|r: /mm header, clock, zone, coords, reset. Move and scale in Edit Mode.")
            return
        end
        print("|cffff8800MidnightMinimap|r: Settings updated.")
    end
    print("|cffff8800MidnightMinimap|r loaded for Forever. Use /mm for options and Edit Mode to move or scale.")
end

local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    Init()
end)
