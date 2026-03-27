----------------------------------------------------------------------
-- MidnightMinimap
-- Lightweight addon that applies the Midnight/Dragonflight-style
-- minimap border to WoW TBC Anniversary (or Classic).
-- Textures from DragonflightUI by Karl-Heinz Schneider.
----------------------------------------------------------------------

local addonName = ...
local TEXPATH = "Interface\\AddOns\\MidnightMinimap\\Textures\\"
local ATLAS  = TEXPATH .. "uiminimap2x"
local MASK   = TEXPATH .. "tempportraitalphamask"

-- Border texcoords from the atlas
local BORDER_L, BORDER_R = 0.001953125, 0.857421875
local BORDER_T, BORDER_B = 0.056640625, 0.505859375

-- Info panel button background texcoords
local PANEL_L, PANEL_R = 0.861328, 0.9375
local PANEL_T, PANEL_B = 0.392578, 0.429688

-- Tracking button texcoords
local TRACK_NORM_L, TRACK_NORM_R = 0.291016, 0.349609
local TRACK_NORM_T, TRACK_NORM_B = 0.507812, 0.535156
local TRACK_OVER_L, TRACK_OVER_R = 0.228516, 0.287109
local TRACK_OVER_T, TRACK_OVER_B = 0.507812, 0.535156

-- Mail icon texcoords
local MAIL_L, MAIL_R = 0.08203125, 0.158203125
local MAIL_T, MAIL_B = 0.5078125, 0.537109375

-- Defaults
local defaults = {
    scale = 1.0,
    anchor = "TOPRIGHT",
    x = -4,
    y = -4,
    hideZoneText = false,
    hideClock = false,
    hideHeader = false,
    showCoords = false,
    locked = true,
}

----------------------------------------------------------------------
-- Saved Variables
----------------------------------------------------------------------
local db

local function InitDB()
    if not MidnightMinimapDB then
        MidnightMinimapDB = {}
    end
    db = MidnightMinimapDB
    for k, v in pairs(defaults) do
        if db[k] == nil then
            db[k] = v
        end
    end
end

----------------------------------------------------------------------
-- Frames & Textures
----------------------------------------------------------------------
local baseFrame, topFrame, midFrame
local infoPanelFrame, infoPanelBG
local minimapBorder, minimapBorderRound
local calendarFrame
local IsTBC = (MinimapCluster and MinimapCluster.BorderTop) and true or false

local function HideDefaultStuff()
    -- Hide default blizzard border
    if MinimapBorder then MinimapBorder:Hide() end
    if MinimapBorderTop then MinimapBorderTop:Hide() end
    if MinimapCluster and MinimapCluster.BorderTop then
        MinimapCluster.BorderTop:Hide()
    end
    if MinimapToggleButton then MinimapToggleButton:Hide() end

    -- Hide world map button
    if MiniMapWorldMapButton then
        MiniMapWorldMapButton:Hide()
        hooksecurefunc(MiniMapWorldMapButton, "Show", function(self)
            self:Hide()
        end)
    end

    -- Hide north tag
    if MinimapNorthTag then
        MinimapNorthTag:Hide()
        hooksecurefunc(MinimapNorthTag, "Show", function(self)
            self:Hide()
        end)
    end
end

local function CreateBaseFrame()
    baseFrame = CreateFrame("Frame", "MidnightMinimapBase", UIParent)
    baseFrame:SetSize(178, 200)
    baseFrame:SetPoint(db.anchor, UIParent, db.anchor, db.x, db.y)
    baseFrame:SetClampedToScreen(true)

    -- Top area for zone text + clock
    topFrame = CreateFrame("Frame", "MidnightMinimapTop", baseFrame)
    topFrame:SetPoint("TOPLEFT", baseFrame, "TOPLEFT", 0, 0)
    topFrame:SetPoint("TOPRIGHT", baseFrame, "TOPRIGHT", 0, 0)
    topFrame:SetHeight(18)

    -- Mid area for the actual minimap
    local padding = 4
    midFrame = CreateFrame("Frame", "MidnightMinimapMid", baseFrame)
    midFrame:SetPoint("TOP", topFrame, "BOTTOM", 0, -padding)
    midFrame:SetSize(140, 160)

    baseFrame:SetHeight(18 + padding + 160 + padding)
end

local function CreateInfoPanel()
    infoPanelFrame = CreateFrame("Frame", "MidnightMinimapInfoPanel", baseFrame)
    infoPanelFrame:SetSize(140, 18)
    infoPanelFrame:SetPoint("CENTER", topFrame, "CENTER", 0, 0)

    infoPanelBG = infoPanelFrame:CreateTexture("MidnightMinimapInfoPanelBG", "ARTWORK")
    infoPanelBG:SetTexture(ATLAS)
    infoPanelBG:SetSize(39, 38)
    infoPanelBG:SetTexCoord(PANEL_L, PANEL_R, PANEL_T, PANEL_B)
    infoPanelBG:SetPoint("TOPLEFT", infoPanelFrame, "TOPLEFT", 0, 0)
    infoPanelBG:SetPoint("BOTTOMRIGHT", infoPanelFrame, "BOTTOMRIGHT", 0, 0)
    if infoPanelBG.SetTextureSliceMode then
        infoPanelBG:SetTextureSliceMode(1)
        infoPanelBG:SetTextureSliceMargins(20, 20, 25, 25)
    end
end

local function StyleZoneText()
    local btn = MinimapZoneTextButton
    if not btn then return end
    btn:ClearAllPoints()
    btn:SetHeight(16)
    btn:SetParent(infoPanelFrame)
    btn:SetPoint("LEFT", infoPanelFrame, "LEFT", 4, 0)
    btn:SetWidth(92)

    local text = MinimapZoneText
    if text then
        text:ClearAllPoints()
        text:SetSize(130, 10)
        text:SetPoint("LEFT", btn, "LEFT", 1, 0)
        text:SetPoint("RIGHT", btn, "RIGHT", -1, 0)
        local path, size, flags = text:GetFont()
        if path then
            text:SetFont(path, 10, flags)
        end
    end
end

local function StyleClock()
    local ok, _ = pcall(function()
        if C_AddOns and C_AddOns.LoadAddOn then
            C_AddOns.LoadAddOn("Blizzard_TimeManager")
        elseif LoadAddOn then
            LoadAddOn("Blizzard_TimeManager")
        end
    end)

    local btn = TimeManagerClockButton
    if not btn then return end

    local regions = { btn:GetRegions() }
    if regions[1] then regions[1]:Hide() end

    btn:ClearAllPoints()
    btn:SetSize(40, 16)
    btn:SetPoint("RIGHT", infoPanelFrame, "RIGHT", 0, 0)
    btn:SetParent(infoPanelFrame)

    local ticker = TimeManagerClockTicker
    if ticker then
        local path, size, flags = ticker:GetFont()
        if path then
            ticker:SetFont(path, 9, flags)
        end
    end

    if TimeManagerFrame then
        TimeManagerFrame:ClearAllPoints()
        TimeManagerFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -10, -220)
    end
end

local function StyleTracking()
    -- Detect Era-style tracking (MiniMapTrackingFrame) vs TBC/Wrath (MiniMapTracking)
    local trackingFrame = MiniMapTracking or MiniMapTrackingFrame
    if not trackingFrame then return end

    if MiniMapTracking then
        -- TBC / Wrath style
        local trackingIcon = MiniMapTrackingIcon
        local trackingBG = MiniMapTrackingBackground
        local btn = MiniMapTrackingButton
        local btnBorder = MiniMapTrackingButtonBorder

        if trackingFrame.ClearAllPoints then
            trackingFrame:ClearAllPoints()
            trackingFrame:SetPoint("RIGHT", infoPanelFrame, "LEFT", -1, 0)
            trackingFrame:SetSize(18, 18)
            trackingFrame:SetFrameStrata("MEDIUM")
            trackingFrame:SetParent(infoPanelFrame)
        end
        if trackingIcon then trackingIcon:Hide() end
        if trackingBG then
            trackingBG:ClearAllPoints()
            trackingBG:SetPoint("CENTER", trackingFrame, "CENTER")
            trackingBG:SetSize(18, 18)
            trackingBG:SetTexture(ATLAS)
            trackingBG:SetTexCoord(PANEL_L, PANEL_R, PANEL_T, PANEL_B)
        end
        if btnBorder then btnBorder:Hide() end
        if btn then
            btn:SetSize(14, 15)
            btn:ClearAllPoints()
            btn:SetPoint("CENTER", trackingFrame, "CENTER")
            btn:SetParent(infoPanelFrame)
            btn:SetNormalTexture(ATLAS)
            btn:GetNormalTexture():SetTexCoord(TRACK_NORM_L, TRACK_NORM_R, TRACK_NORM_T, TRACK_NORM_B)
            btn:SetHighlightTexture(ATLAS)
            btn:GetHighlightTexture():SetTexCoord(TRACK_OVER_L, TRACK_OVER_R, TRACK_OVER_T, TRACK_OVER_B)
            btn:SetPushedTexture(ATLAS)
            btn:GetPushedTexture():SetTexCoord(TRACK_OVER_L, TRACK_OVER_R, TRACK_OVER_T, TRACK_OVER_B)
        end
    else
        -- Era / Classic style with MiniMapTrackingFrame
        local function updatePos()
            trackingFrame:ClearAllPoints()
            trackingFrame:SetPoint("CENTER", Minimap, "CENTER", -52.56, 53.51)
            trackingFrame:SetParent(Minimap)
        end
        updatePos()
        trackingFrame:SetSize(31, 31)
        trackingFrame:SetFrameStrata("MEDIUM")

        local bg = trackingFrame:CreateTexture("MidnightMinimapTrackingBG", "BACKGROUND")
        bg:SetSize(24, 24)
        bg:SetTexture(TEXPATH .. "ui-minimap-background")
        bg:ClearAllPoints()
        bg:SetPoint("CENTER", trackingFrame, "CENTER")

        if MiniMapTrackingBorder then
            MiniMapTrackingBorder:SetSize(50, 50)
            MiniMapTrackingBorder:SetTexture(TEXPATH .. "minimap-trackingborder")
            MiniMapTrackingBorder:ClearAllPoints()
            MiniMapTrackingBorder:SetPoint("TOPLEFT", trackingFrame, "TOPLEFT")
        end

        if MiniMapTrackingIcon then
            MiniMapTrackingIcon:SetSize(20, 20)
            MiniMapTrackingIcon:ClearAllPoints()
            MiniMapTrackingIcon:SetPoint("CENTER", trackingFrame, "CENTER", 0, 0)
        end

        if SetLookingForGroupUIAvailable then
            hooksecurefunc("SetLookingForGroupUIAvailable", function()
                updatePos()
            end)
        end
    end
end

local function StyleMail()
    if not MiniMapMailFrame then return end
    if MiniMapMailBorder then MiniMapMailBorder:Hide() end
    if MiniMapMailIcon then MiniMapMailIcon:Hide() end

    MiniMapMailFrame:SetSize(19.5, 15)
    MiniMapMailFrame:ClearAllPoints()
    MiniMapMailFrame:SetParent(Minimap)
    MiniMapMailFrame:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", 5, 5)
    MiniMapMailFrame:SetFrameStrata("MEDIUM")
    MiniMapMailFrame:SetFrameLevel(Minimap:GetFrameLevel() + 5)

    local mail = MiniMapMailFrame:CreateTexture("MidnightMinimapMail", "ARTWORK")
    mail:ClearAllPoints()
    mail:SetTexture(ATLAS)
    mail:SetTexCoord(MAIL_L, MAIL_R, MAIL_T, MAIL_B)
    mail:SetSize(19.5, 15)
    mail:SetPoint("CENTER", MiniMapMailFrame, "CENTER", 0, 0)

    -- Ensure the blizzard code can't re-hide our custom texture
    hooksecurefunc(MiniMapMailFrame, "Show", function()
        mail:Show()
    end)
end

local function SetupMinimapBorder()
    -- Parent minimap into our frame
    Minimap:ClearAllPoints()
    Minimap:SetPoint("CENTER", midFrame, "CENTER", 0, 0)
    Minimap:SetParent(baseFrame)

    -- Set round mask
    Minimap:SetMaskTexture(MASK)

    -- Create the decorative border from the atlas
    minimapBorder = Minimap:CreateTexture("MidnightMinimapBorder", "ARTWORK")
    minimapBorder:SetDrawLayer("ARTWORK", 7)
    minimapBorder:SetTexture(ATLAS)
    minimapBorder:SetTexCoord(BORDER_L, BORDER_R, BORDER_T, BORDER_B)
    minimapBorder:SetPoint("CENTER", Minimap, "CENTER", 1, 0)

    local delta = 22
    local dx = 6
    minimapBorder:SetSize(140 + delta - dx, 140 + delta)

    -- Also handle MinimapCompassTexture for rotation mode
    if MinimapCompassTexture then
        MinimapCompassTexture:SetTexture(ATLAS)
        MinimapCompassTexture:SetTexCoord(BORDER_L, BORDER_R, BORDER_T, BORDER_B)
        MinimapCompassTexture:SetSize(140 + delta - dx, 140 + delta)
        MinimapCompassTexture:SetScale(1)
        MinimapCompassTexture:ClearAllPoints()
        MinimapCompassTexture:SetPoint("CENTER", Minimap, "CENTER", 1, 0)

        hooksecurefunc(MinimapCompassTexture, "Show", function()
            minimapBorder:Hide()
        end)
        hooksecurefunc(MinimapCompassTexture, "Hide", function()
            minimapBorder:Show()
        end)
    end
end

local function HookMouseWheel()
    Minimap:SetScript("OnMouseWheel", function(self, delta)
        if delta == -1 then
            MinimapZoomIn:Enable()
            Minimap:SetZoom(math.max(Minimap:GetZoom() - 1, 0))
            if Minimap:GetZoom() == 0 then MinimapZoomOut:Disable() end
        elseif delta == 1 then
            MinimapZoomOut:Enable()
            Minimap:SetZoom(math.min(Minimap:GetZoom() + 1, Minimap:GetZoomLevels() - 1))
            if Minimap:GetZoom() == (Minimap:GetZoomLevels() - 1) then MinimapZoomIn:Disable() end
        end
    end)
end

----------------------------------------------------------------------
-- Coordinates Display
----------------------------------------------------------------------
local coordFrame, coordText, coordBG, coordUpdateTimer

local function CreateCoordsDisplay()
    coordFrame = CreateFrame("Frame", "MidnightMinimapCoords", baseFrame)
    coordFrame:SetSize(80, 16)
    coordFrame:SetPoint("TOP", midFrame, "BOTTOM", 0, -2)

    coordBG = coordFrame:CreateTexture("MidnightMinimapCoordsBG", "ARTWORK")
    coordBG:SetTexture(ATLAS)
    coordBG:SetSize(39, 38)
    coordBG:SetTexCoord(PANEL_L, PANEL_R, PANEL_T, PANEL_B)
    coordBG:SetPoint("TOPLEFT", coordFrame, "TOPLEFT", 0, 0)
    coordBG:SetPoint("BOTTOMRIGHT", coordFrame, "BOTTOMRIGHT", 0, 0)
    if coordBG.SetTextureSliceMode then
        coordBG:SetTextureSliceMode(1)
        coordBG:SetTextureSliceMargins(20, 20, 25, 25)
    end

    coordText = coordFrame:CreateFontString("MidnightMinimapCoordsText", "OVERLAY", "GameFontNormalSmall")
    coordText:SetPoint("CENTER", coordFrame, "CENTER", 0, 0)
    coordText:SetTextColor(1, 0.82, 0)
    local path, size, flags = coordText:GetFont()
    if path then
        coordText:SetFont(path, 10, flags)
    end

    coordFrame:Hide()
end

local function UpdateCoords()
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if mapID then
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        if pos then
            local x, y = pos:GetXY()
            coordText:SetFormattedText("%.1f, %.1f", x * 100, y * 100)
            return
        end
    end
    coordText:SetText("---")
end

local function ToggleCoords()
    db.showCoords = not db.showCoords
    if db.showCoords then
        coordFrame:Show()
        if not coordUpdateTimer then
            coordUpdateTimer = C_Timer.NewTicker(0.5, UpdateCoords)
        end
    else
        coordFrame:Hide()
        if coordUpdateTimer then
            coordUpdateTimer:Cancel()
            coordUpdateTimer = nil
        end
    end
end

local function ApplyCoordsState()
    if db.showCoords then
        coordFrame:Show()
        if not coordUpdateTimer then
            coordUpdateTimer = C_Timer.NewTicker(0.5, UpdateCoords)
        end
        UpdateCoords()
    else
        coordFrame:Hide()
    end
end

local function UpdateHeaderVisibility()
    if db.hideHeader then
        infoPanelFrame:Hide()
        topFrame:SetHeight(0.0001)
        baseFrame:SetHeight(4 + 160 + 4)
    else
        infoPanelFrame:Show()
        baseFrame:SetHeight(18 + 4 + 160 + 4)

        local clockSpace = 0
        if not db.hideClock then
            clockSpace = 40
            if C_CVar then C_CVar.SetCVar("showMinimapClock", 1) end
        else
            if C_CVar then C_CVar.SetCVar("showMinimapClock", 0) end
        end

        if db.hideZoneText then
            if MinimapZoneTextButton then MinimapZoneTextButton:Hide() end
        else
            if MinimapZoneTextButton then MinimapZoneTextButton:Show() end
        end

        local w = clockSpace + (db.hideZoneText and 0 or 100)
        if w > 0 then
            infoPanelBG:Show()
            infoPanelFrame:SetWidth(w)
        else
            infoPanelBG:Hide()
            infoPanelFrame:SetWidth(0.0001)
        end
    end
end

local function EnableDragging()
    baseFrame:SetMovable(true)
    baseFrame:EnableMouse(true)
    baseFrame:RegisterForDrag("LeftButton")

    -- Unlock indicator (green border glow when unlocked)
    local unlockGlow = baseFrame:CreateTexture("MidnightMinimapUnlockGlow", "BACKGROUND")
    unlockGlow:SetColorTexture(0, 1, 0, 0.3)
    unlockGlow:SetPoint("TOPLEFT", baseFrame, "TOPLEFT", -3, 3)
    unlockGlow:SetPoint("BOTTOMRIGHT", baseFrame, "BOTTOMRIGHT", 3, -3)
    unlockGlow:Hide()

    local function UpdateLockVisual()
        if db.locked then
            unlockGlow:Hide()
        else
            unlockGlow:Show()
        end
    end

    local function SavePosition()
        local point, _, relPoint, x, y = baseFrame:GetPoint()
        db.anchor = point
        db.x = x
        db.y = y
    end

    baseFrame:SetScript("OnDragStart", function(self)
        -- Shift+drag always works; normal drag only when unlocked
        if IsShiftKeyDown() or not db.locked then
            self:StartMoving()
        end
    end)
    baseFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)

    -- Right-click to toggle lock, pass everything else through (including left-click pings)
    Minimap:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" and IsShiftKeyDown() then
            db.locked = not db.locked
            UpdateLockVisual()
            if db.locked then
                print("|cffff8800MidnightMinimap|r: |cffff4444Locked.|r")
            else
                print("|cffff8800MidnightMinimap|r: |cff00ff00Unlocked|r - drag to reposition. Shift+Right-click to lock again.")
            end
        else
            Minimap_OnClick(self)  -- default handler (pings on left-click, tracking menu on right-click)
        end
    end)

    -- Expose for slash command use
    MidnightMinimap_UpdateLockVisual = UpdateLockVisual
end

----------------------------------------------------------------------
-- Slash Commands
----------------------------------------------------------------------
local function PrintHelp()
    local c = "|cff00ccff"
    local r = "|r"
    print("|cffff8800MidnightMinimap|r commands:")
    print("  |cff88ff88Shift+Drag|r the minimap to reposition (works anytime)")
    print("  |cff88ff88Shift+Right-click|r minimap to toggle lock/unlock")
    print("  " .. c .. "/mm lock" .. r .. " - Toggle frame lock")
    print("  " .. c .. "/mm scale <n>" .. r .. " - Set scale (e.g. 1.0, 1.25)")
    print("  " .. c .. "/mm coords" .. r .. " - Toggle coordinate display")
    print("  " .. c .. "/mm header" .. r .. " - Toggle zone text / clock header")
    print("  " .. c .. "/mm clock" .. r .. " - Toggle clock display")
    print("  " .. c .. "/mm zone" .. r .. " - Toggle zone text display")
    print("  " .. c .. "/mm reset" .. r .. " - Reset to defaults")
end

SLASH_MIDNIGHTMINIMAP1 = "/midnightminimap"
SLASH_MIDNIGHTMINIMAP2 = "/mm"
SlashCmdList["MIDNIGHTMINIMAP"] = function(msg)
    local cmd, arg = strsplit(" ", strlower(strtrim(msg)), 2)

    if cmd == "lock" then
        db.locked = not db.locked
        if MidnightMinimap_UpdateLockVisual then MidnightMinimap_UpdateLockVisual() end
        print("|cffff8800MidnightMinimap|r: Frame " .. (db.locked and "locked" or "|cff00ff00unlocked - drag to reposition|r"))
    elseif cmd == "scale" then
        local s = tonumber(arg)
        if s and s >= 0.5 and s <= 3 then
            db.scale = s
            baseFrame:SetScale(s * 1.25)
            print("|cffff8800MidnightMinimap|r: Scale set to " .. s)
        else
            print("|cffff8800MidnightMinimap|r: Usage: /mm scale <0.5-3.0>")
        end
    elseif cmd == "header" then
        db.hideHeader = not db.hideHeader
        UpdateHeaderVisibility()
        print("|cffff8800MidnightMinimap|r: Header " .. (db.hideHeader and "hidden" or "shown"))
    elseif cmd == "clock" then
        db.hideClock = not db.hideClock
        UpdateHeaderVisibility()
        print("|cffff8800MidnightMinimap|r: Clock " .. (db.hideClock and "hidden" or "shown"))
    elseif cmd == "zone" then
        db.hideZoneText = not db.hideZoneText
        UpdateHeaderVisibility()
        print("|cffff8800MidnightMinimap|r: Zone text " .. (db.hideZoneText and "hidden" or "shown"))
    elseif cmd == "coords" or cmd == "coord" or cmd == "xy" then
        ToggleCoords()
        print("|cffff8800MidnightMinimap|r: Coordinates " .. (db.showCoords and "shown" or "hidden"))
    elseif cmd == "reset" then
        for k, v in pairs(defaults) do
            db[k] = v
        end
        baseFrame:ClearAllPoints()
        baseFrame:SetPoint(db.anchor, UIParent, db.anchor, db.x, db.y)
        baseFrame:SetScale(db.scale * 1.25)
        UpdateHeaderVisibility()
        ApplyCoordsState()
        if MidnightMinimap_UpdateLockVisual then MidnightMinimap_UpdateLockVisual() end
        print("|cffff8800MidnightMinimap|r: Reset to defaults.")
    else
        PrintHelp()
    end
end

----------------------------------------------------------------------
-- Init
----------------------------------------------------------------------
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        InitDB()

        CreateBaseFrame()
        CreateInfoPanel()
        HideDefaultStuff()
        StyleZoneText()
        StyleClock()
        StyleTracking()
        StyleMail()
        SetupMinimapBorder()
        HookMouseWheel()
        CreateCoordsDisplay()
        EnableDragging()

        -- Apply saved settings
        baseFrame:SetScale(db.scale * 1.25)
        baseFrame:ClearAllPoints()
        baseFrame:SetPoint(db.anchor, UIParent, db.anchor, db.x, db.y)
        UpdateHeaderVisibility()
        ApplyCoordsState()

        -- Tell GetMinimapShape that we're round
        function GetMinimapShape()
            return "ROUND"
        end

        print("|cffff8800MidnightMinimap|r loaded. |cff88ff88Shift+Drag|r to move, |cff00ccff/mm|r for options.")
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
