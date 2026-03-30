local _, addon = ...

-- ── Widget helpers ────────────────────────────────────────────────────────────

local function MakeSeparator(parent, anchor, offsetY)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.4, 0.4, 0.4, 0.5)
    line:SetHeight(1)
    line:SetWidth(550)
    line:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY)
    return line
end

local function MakeCheckbox(parent, label, x, y, getValue, setValue)
    local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    cb.Text:SetText(label)
    cb:SetChecked(getValue())
    cb:SetScript("OnClick", function(self)
        setValue(self:GetChecked() == true)
    end)
    return cb
end

-- ── Parent panel (title only) ─────────────────────────────────────────────────

local function BuildParentPanel()
    local panel = CreateFrame("Frame")
    panel.name = "MathWro QOL"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("MathWro QOL")

    local ver = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    ver:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    ver:SetText("v1.0.0 by MathWro  |  Select a category on the left.")

    return panel
end

-- ── General subpage ───────────────────────────────────────────────────────────

local function BuildGeneralPanel()
    local panel = CreateFrame("Frame")
    panel.name = "General"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("General")

    -- Dark backdrop below the title
    local bg = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    bg:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -6, -8)
    bg:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -6, 6)
    bg:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile     = false,
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    bg:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    bg:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    if ElvUI then
        local E = ElvUI[1]
        bg:SetBackdropColor(unpack(E.media.backdropfadecolor))
        bg:SetBackdropBorderColor(unpack(E.media.bordercolor))
    end

    local scrollFrame = CreateFrame("ScrollFrame", "MathWroQOL_GeneralScroll", bg, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     bg, "TOPLEFT",     8,   -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", -28,  8)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * 20)))
    end)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(530, 900)
    scrollFrame:SetScrollChild(scrollChild)

    -- ── Game Menu Scale ───────────────────────────────────────────────────────

    local gmLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    gmLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 8, -12)
    gmLabel:SetText("Game Menu Scale")

    local gmDesc = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    gmDesc:SetPoint("TOPLEFT", gmLabel, "BOTTOMLEFT", 0, -4)
    gmDesc:SetText("Scale the Escape menu. Default is 1.0.")

    local slider = CreateFrame("Slider", "MathWroQOL_GameMenuSlider", scrollChild, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", gmDesc, "BOTTOMLEFT", 0, -16)
    slider:SetMinMaxValues(0.5, 2.0)
    slider:SetValueStep(0.05)
    slider:SetObeyStepOnDrag(true)
    slider:SetWidth(200)
    _G[slider:GetName().."Low"]:SetText("0.5x")
    _G[slider:GetName().."High"]:SetText("2.0x")
    _G[slider:GetName().."Text"]:SetText("Scale: 1.0x")

    slider:SetScript("OnValueChanged", function(self, value, userInput)
        _G[self:GetName().."Text"]:SetText(string.format("Scale: %.2fx", value))
        if not userInput then return end
        if not addon.db.gameMenu then addon.db.gameMenu = {} end
        addon.db.gameMenu.scale = value
        addon:NotifyFeature("gameMenu")
    end)

    panel:HookScript("OnShow", function()
        local scale = (addon.db.gameMenu and addon.db.gameMenu.scale) or 1.0
        slider:SetValue(scale)
    end)

    -- ── Game Menu Dragging ────────────────────────────────────────────────────

    local moveableCB = MakeCheckbox(scrollChild, "Allow dragging", 0, 0,
        function() return addon.db.gameMenu and addon.db.gameMenu.moveable == true end,
        function(val)
            if not addon.db.gameMenu then addon.db.gameMenu = {} end
            addon.db.gameMenu.moveable = val
            addon:NotifyFeature("gameMenu")
        end
    )
    moveableCB:ClearAllPoints()
    moveableCB:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -16)

    local resetBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
    resetBtn:SetSize(120, 22)
    resetBtn:SetPoint("TOPLEFT", moveableCB, "BOTTOMLEFT", 0, -8)
    resetBtn:SetText("Reset Position")
    resetBtn:SetScript("OnClick", function()
        for _, f in ipairs(addon.features) do
            if f.name == "gameMenu" and f.ResetPosition then
                f:ResetPosition()
                break
            end
        end
    end)

    -- ── CDM Button ────────────────────────────────────────────────────────────

    local cdmSep = MakeSeparator(scrollChild, resetBtn, -12)

    local cdmLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    cdmLabel:SetPoint("TOPLEFT", cdmSep, "BOTTOMLEFT", 0, -10)
    cdmLabel:SetText("CDM Button")

    local cdmDesc = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    cdmDesc:SetPoint("TOPLEFT", cdmLabel, "BOTTOMLEFT", 0, -4)
    cdmDesc:SetText("Adds a CDM button to the Game Menu that opens the Cooldown Manager.")

    local cdmEnabledCB = MakeCheckbox(scrollChild, "Show CDM button in game menu", 0, 0,
        function() return addon.db.cdmButton and addon.db.cdmButton.enabled end,
        function(val)
            if not addon.db.cdmButton then addon.db.cdmButton = {} end
            addon.db.cdmButton.enabled = val
            addon:NotifyFeature("cdmButton")
        end
    )
    cdmEnabledCB:ClearAllPoints()
    cdmEnabledCB:SetPoint("TOPLEFT", cdmDesc, "BOTTOMLEFT", 0, -8)

    local slashNote = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    slashNote:SetPoint("TOPLEFT", cdmEnabledCB, "BOTTOMLEFT", 0, -8)
    slashNote:SetText("Slash commands:")

    local waCB = MakeCheckbox(scrollChild, "Enable /wa command", 0, 0,
        function() return addon.db.cdmButton and addon.db.cdmButton.slashWA end,
        function(val)
            if not addon.db.cdmButton then addon.db.cdmButton = {} end
            addon.db.cdmButton.slashWA = val
        end
    )
    waCB:ClearAllPoints()
    waCB:SetPoint("TOPLEFT", slashNote, "BOTTOMLEFT", 0, -8)

    local cmCB = MakeCheckbox(scrollChild, "Enable /cm command", 0, 0,
        function() return addon.db.cdmButton and addon.db.cdmButton.slashCM end,
        function(val)
            if not addon.db.cdmButton then addon.db.cdmButton = {} end
            addon.db.cdmButton.slashCM = val
        end
    )
    cmCB:ClearAllPoints()
    cmCB:SetPoint("TOPLEFT", waCB, "BOTTOMLEFT", 0, -4)

    -- ── Auction House Filters ─────────────────────────────────────────────────

    local ahSep = MakeSeparator(scrollChild, cmCB, -12)

    local ahLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    ahLabel:SetPoint("TOPLEFT", ahSep, "BOTTOMLEFT", 0, -10)
    ahLabel:SetText("Auction House Filters")

    local ahDesc = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    ahDesc:SetPoint("TOPLEFT", ahLabel, "BOTTOMLEFT", 0, -4)
    ahDesc:SetText("Automatically enable selected filters each time you open the Auction House.")

    local ahExpCB = MakeCheckbox(scrollChild, "Auto-enable 'Current expansion only' filter", 0, 0,
        function() return addon.db.auctionFilter and addon.db.auctionFilter.currentExpansionOnly end,
        function(val)
            if not addon.db.auctionFilter then addon.db.auctionFilter = {} end
            addon.db.auctionFilter.currentExpansionOnly = val
            addon:NotifyFeature("auctionFilter")
        end
    )
    ahExpCB:ClearAllPoints()
    ahExpCB:SetPoint("TOPLEFT", ahDesc, "BOTTOMLEFT", 0, -8)

    local ahUsableCB = MakeCheckbox(scrollChild, "Auto-enable 'Usable only' filter", 0, 0,
        function() return addon.db.auctionFilter and addon.db.auctionFilter.usableOnly end,
        function(val)
            if not addon.db.auctionFilter then addon.db.auctionFilter = {} end
            addon.db.auctionFilter.usableOnly = val
            addon:NotifyFeature("auctionFilter")
        end
    )
    ahUsableCB:ClearAllPoints()
    ahUsableCB:SetPoint("TOPLEFT", ahExpCB, "BOTTOMLEFT", 0, -4)

    -- ── Combat Logging ────────────────────────────────────────────────────────

    local clSep = MakeSeparator(scrollChild, ahUsableCB, -12)

    local clLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    clLabel:SetPoint("TOPLEFT", clSep, "BOTTOMLEFT", 0, -10)
    clLabel:SetText("Combat Logging")

    local clDesc = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    clDesc:SetPoint("TOPLEFT", clLabel, "BOTTOMLEFT", 0, -4)
    clDesc:SetWidth(500)
    clDesc:SetJustifyH("LEFT")
    clDesc:SetText("Automatically start combat logging when entering selected instance types. Stops on exit. If you manually stop logging mid-instance, it stays off until the next instance.")

    -- No NotifyFeature call needed: CombatLog:Apply() is a no-op; settings
    -- take effect on the next zone transition (PLAYER_ENTERING_WORLD / ZONE_CHANGED_NEW_AREA).

    -- Row 1: Dungeon | Raid
    local clDungeonCB = MakeCheckbox(scrollChild, "Dungeon (includes Mythic+)", 0, 0,
        function() return addon.db.combatLog and addon.db.combatLog.dungeon end,
        function(val)
            if not addon.db.combatLog then addon.db.combatLog = {} end
            addon.db.combatLog.dungeon = val
        end
    )
    clDungeonCB:ClearAllPoints()
    clDungeonCB:SetPoint("TOPLEFT", clDesc, "BOTTOMLEFT", 0, -8)

    local clRaidCB = MakeCheckbox(scrollChild, "Raid", 0, 0,
        function() return addon.db.combatLog and addon.db.combatLog.raid end,
        function(val)
            if not addon.db.combatLog then addon.db.combatLog = {} end
            addon.db.combatLog.raid = val
        end
    )
    clRaidCB:ClearAllPoints()
    clRaidCB:SetPoint("TOPLEFT", clDungeonCB, "TOPLEFT", 200, 0)

    -- Row 2: Scenario | Battleground
    local clScenarioCB = MakeCheckbox(scrollChild, "Scenario", 0, 0,
        function() return addon.db.combatLog and addon.db.combatLog.scenario end,
        function(val)
            if not addon.db.combatLog then addon.db.combatLog = {} end
            addon.db.combatLog.scenario = val
        end
    )
    clScenarioCB:ClearAllPoints()
    clScenarioCB:SetPoint("TOPLEFT", clDungeonCB, "BOTTOMLEFT", 0, -4)

    local clPvpCB = MakeCheckbox(scrollChild, "Battleground", 0, 0,
        function() return addon.db.combatLog and addon.db.combatLog.pvp end,
        function(val)
            if not addon.db.combatLog then addon.db.combatLog = {} end
            addon.db.combatLog.pvp = val  -- IsInInstance() returns "pvp" for battlegrounds
        end
    )
    clPvpCB:ClearAllPoints()
    clPvpCB:SetPoint("TOPLEFT", clScenarioCB, "TOPLEFT", 200, 0)

    -- Row 3: Arena
    local clArenaCB = MakeCheckbox(scrollChild, "Arena", 0, 0,
        function() return addon.db.combatLog and addon.db.combatLog.arena end,
        function(val)
            if not addon.db.combatLog then addon.db.combatLog = {} end
            addon.db.combatLog.arena = val
        end
    )
    clArenaCB:ClearAllPoints()
    clArenaCB:SetPoint("TOPLEFT", clScenarioCB, "BOTTOMLEFT", 0, -4)

    local clMaxLevelCB = MakeCheckbox(scrollChild, "Only at max level", 0, 0,
        function() return addon.db.combatLog and addon.db.combatLog.maxLevelOnly end,
        function(val)
            if not addon.db.combatLog then addon.db.combatLog = {} end
            addon.db.combatLog.maxLevelOnly = val
        end
    )
    clMaxLevelCB:ClearAllPoints()
    clMaxLevelCB:SetPoint("TOPLEFT", clArenaCB, "BOTTOMLEFT", 0, -8)

    return panel
end

-- ── ElvUI Plugins subpage ─────────────────────────────────────────────────────

local function BuildElvUIPanel()
    local panel = CreateFrame("Frame")
    panel.name = "ElvUI Plugins"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("ElvUI Plugins")

    local elvuiLoaded = ElvUI ~= nil

    -- Dark backdrop below the title
    local bg = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    bg:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -6, -8)
    bg:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -6, 6)
    bg:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile     = false,
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    bg:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    bg:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    if ElvUI then
        local E = ElvUI[1]
        bg:SetBackdropColor(unpack(E.media.backdropfadecolor))
        bg:SetBackdropBorderColor(unpack(E.media.bordercolor))
    end

    local scrollFrame = CreateFrame("ScrollFrame", "MathWroQOL_ElvUIScroll", bg, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     bg, "TOPLEFT",     8,   -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", -28,  8)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * 20)))
    end)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(530, 900)
    scrollFrame:SetScrollChild(scrollChild)

    -- ── Vehicle Bar Visibility ────────────────────────────────────────────────

    -- The "not loaded" notice anchors to scrollChild top; sectionLabel follows it.
    -- When ElvUI is loaded, sectionLabel anchors directly to scrollChild top.
    local sectionLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sectionLabel:SetText("Vehicle Bar Visibility")

    if not elvuiLoaded then
        local notice = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        notice:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 8, -12)
        notice:SetTextColor(1, 0.3, 0.3)
        notice:SetText("ElvUI is not loaded. These options are unavailable.")
        sectionLabel:SetPoint("TOPLEFT", notice, "BOTTOMLEFT", 0, -16)
    else
        sectionLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 8, -12)
    end

    local sectionDesc = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sectionDesc:SetPoint("TOPLEFT", sectionLabel, "BOTTOMLEFT", 0, -4)
    sectionDesc:SetWidth(500)
    sectionDesc:SetJustifyH("LEFT")
    sectionDesc:SetText("Keep selected action bars visible while in vehicle combat, including override bar states. Prevents mouseover fade from hiding bars during these encounters.")

    local widgets = {}

    local enabledCB = MakeCheckbox(scrollChild, "Enable", 0, 0,
        function() return addon.db.vehicleBar and addon.db.vehicleBar.enabled end,
        function(val)
            if addon.db.vehicleBar then
                addon.db.vehicleBar.enabled = val
                addon:NotifyFeature("vehicleBar")
            end
        end
    )
    enabledCB:ClearAllPoints()
    enabledCB:SetPoint("TOPLEFT", sectionDesc, "BOTTOMLEFT", 0, -12)
    widgets[#widgets + 1] = enabledCB

    local barsLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    barsLabel:SetPoint("TOPLEFT", enabledCB, "BOTTOMLEFT", 0, -8)
    barsLabel:SetText("Bars to keep visible:")

    local barRefs = {}
    for i = 1, 10 do
        local col = (i - 1) % 5
        local cb = MakeCheckbox(scrollChild, "Bar "..i, 0, 0,
            function()
                return addon.db.vehicleBar and addon.db.vehicleBar.bars[i] == true
            end,
            function(val)
                if addon.db.vehicleBar then
                    addon.db.vehicleBar.bars[i] = val and true or nil
                    addon:NotifyFeature("vehicleBar")
                end
            end
        )
        cb:ClearAllPoints()
        if i == 1 then
            cb:SetPoint("TOPLEFT", barsLabel, "BOTTOMLEFT", 0, -8)
        elseif i == 6 then
            cb:SetPoint("TOPLEFT", barRefs[1], "BOTTOMLEFT", 0, -4)
        elseif col == 0 then
            cb:SetPoint("TOPLEFT", barRefs[i - 5], "BOTTOMLEFT", 0, -4)
        else
            cb:SetPoint("TOPLEFT", barRefs[i - 1], "TOPLEFT", 90, 0)
        end
        barRefs[i] = cb
        widgets[#widgets + 1] = cb
    end

    if not elvuiLoaded then
        for _, w in ipairs(widgets) do
            w:Disable()
        end
        sectionLabel:SetTextColor(0.5, 0.5, 0.5)
        sectionDesc:SetTextColor(0.5, 0.5, 0.5)
        barsLabel:SetTextColor(0.5, 0.5, 0.5)
    end

    return panel
end

-- ── Edit Mode subpage ─────────────────────────────────────────────────────────

local function BuildEditModePanel()
    local panel = CreateFrame("Frame")
    panel.name = "Edit Mode"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Edit Mode")

    local bg = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    bg:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -6, -8)
    bg:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -6, 6)
    bg:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile     = false,
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    bg:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    bg:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    if ElvUI then
        local E = ElvUI[1]
        bg:SetBackdropColor(unpack(E.media.backdropfadecolor))
        bg:SetBackdropBorderColor(unpack(E.media.bordercolor))
    end

    local scrollFrame = CreateFrame("ScrollFrame", "MathWroQOL_EditModeScroll", bg, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     bg, "TOPLEFT",     8,   -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", -28,  8)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * 20)))
    end)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(530, 900)
    scrollFrame:SetScrollChild(scrollChild)

    -- ── Nudge Overlay ─────────────────────────────────────────────────────────

    local nudgeLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nudgeLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 8, -12)
    nudgeLabel:SetText("Nudge Overlay")

    local nudgeDesc = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    nudgeDesc:SetPoint("TOPLEFT", nudgeLabel, "BOTTOMLEFT", 0, -4)
    nudgeDesc:SetWidth(500)
    nudgeDesc:SetJustifyH("LEFT")
    nudgeDesc:SetText("Shows arrow buttons and exact coordinates when selecting a UI element in Edit Mode. Click arrows to nudge 1 px, Shift-click for 10 px.")

    local nudgeCB = MakeCheckbox(scrollChild, "Enable nudge overlay", 0, 0,
        function() return addon.db.editModeNudge and addon.db.editModeNudge.enabled end,
        function(val)
            if not addon.db.editModeNudge then addon.db.editModeNudge = {} end
            addon.db.editModeNudge.enabled = val
            addon:NotifyFeature("editModeNudge")
        end
    )
    nudgeCB:ClearAllPoints()
    nudgeCB:SetPoint("TOPLEFT", nudgeDesc, "BOTTOMLEFT", 0, -8)

    return panel
end

-- ── Registration ──────────────────────────────────────────────────────────────

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, arg1)
    if arg1 ~= "MathWroQOL" then return end
    self:UnregisterEvent("ADDON_LOADED")

    local parentPanel   = BuildParentPanel()
    local generalPanel  = BuildGeneralPanel()
    local elvuiPanel    = BuildElvUIPanel()
    local editModePanel = BuildEditModePanel()

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local parentCat = Settings.RegisterCanvasLayoutCategory(parentPanel, parentPanel.name)
        Settings.RegisterCanvasLayoutSubcategory(parentCat, generalPanel,  generalPanel.name)
        Settings.RegisterCanvasLayoutSubcategory(parentCat, elvuiPanel,    elvuiPanel.name)
        Settings.RegisterCanvasLayoutSubcategory(parentCat, editModePanel, editModePanel.name)
        Settings.RegisterAddOnCategory(parentCat)

        SLASH_MQOL1 = "/mqol"
        SlashCmdList["MQOL"] = function()
            Settings.OpenToCategory(parentCat:GetID())
        end
    else
        -- Fallback for older API
        InterfaceOptions_AddCategory(parentPanel)
        InterfaceOptions_AddCategory(generalPanel, parentPanel)
        InterfaceOptions_AddCategory(elvuiPanel,   parentPanel)
        InterfaceOptions_AddCategory(editModePanel, parentPanel)

        SLASH_MQOL1 = "/mqol"
        SlashCmdList["MQOL"] = function()
            InterfaceOptionsFrame_OpenToCategory(parentPanel)
        end
    end
end)
