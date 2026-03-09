local _, addon = ...

-- ── Widget helpers ────────────────────────────────────────────────────────────

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

    -- ── Game Menu Scale ───────────────────────────────────────────────────────

    local gmLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    gmLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
    gmLabel:SetText("Game Menu Scale")

    local gmDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    gmDesc:SetPoint("TOPLEFT", gmLabel, "BOTTOMLEFT", 0, -4)
    gmDesc:SetText("Scale the Escape menu. Default is 1.0.")

    local slider = CreateFrame("Slider", "MathWroQOL_GameMenuSlider", panel, "OptionsSliderTemplate")
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

    local moveableCB = MakeCheckbox(panel, "Allow dragging", 16, -148,
        function() return addon.db.gameMenu and addon.db.gameMenu.moveable == true end,
        function(val)
            if not addon.db.gameMenu then addon.db.gameMenu = {} end
            addon.db.gameMenu.moveable = val
            addon:NotifyFeature("gameMenu")
        end
    )

    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
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

    if not elvuiLoaded then
        local notice = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        notice:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
        notice:SetTextColor(1, 0.3, 0.3)
        notice:SetText("ElvUI is not loaded. These options are unavailable.")
    end

    -- ── Vehicle Bar Visibility ────────────────────────────────────────────────

    local sectionLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sectionLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -44)
    sectionLabel:SetText("Vehicle Bar Visibility")

    local sectionDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sectionDesc:SetPoint("TOPLEFT", sectionLabel, "BOTTOMLEFT", 0, -4)
    sectionDesc:SetText("Keep selected action bars visible while in vehicle combat.")

    local widgets = {}

    local enabledCB = MakeCheckbox(panel, "Enable", 16, -110,
        function() return addon.db.vehicleBar and addon.db.vehicleBar.enabled end,
        function(val)
            if addon.db.vehicleBar then
                addon.db.vehicleBar.enabled = val
                addon:NotifyFeature("vehicleBar")
            end
        end
    )
    widgets[#widgets + 1] = enabledCB

    local barsLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    barsLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -140)
    barsLabel:SetText("Bars to keep visible:")

    for i = 1, 10 do
        local col = (i - 1) % 5
        local row = math.floor((i - 1) / 5)
        local cb = MakeCheckbox(panel, "Bar "..i, 16 + col * 90, -160 - row * 26,
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

-- ── Registration ──────────────────────────────────────────────────────────────

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, arg1)
    if arg1 ~= "MathWroQOL" then return end
    self:UnregisterEvent("ADDON_LOADED")

    local parentPanel  = BuildParentPanel()
    local generalPanel = BuildGeneralPanel()
    local elvuiPanel   = BuildElvUIPanel()

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local parentCat = Settings.RegisterCanvasLayoutCategory(parentPanel, parentPanel.name)
        Settings.RegisterCanvasLayoutSubcategory(parentCat, generalPanel, generalPanel.name)
        Settings.RegisterCanvasLayoutSubcategory(parentCat, elvuiPanel,   elvuiPanel.name)
        Settings.RegisterAddOnCategory(parentCat)
    else
        -- Fallback for older API
        InterfaceOptions_AddCategory(parentPanel)
        InterfaceOptions_AddCategory(generalPanel, parentPanel)
        InterfaceOptions_AddCategory(elvuiPanel,   parentPanel)
    end
end)
