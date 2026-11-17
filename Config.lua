local addonName, addon = ...

local function ElvSkin()
    if not ElvUI then return nil end
    return ElvUI[1]:GetModule("Skins")
end

local function ApplyFrameBackdrop(frame, useFadeColor)
    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile     = false,
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })

    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    frame:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)

    if ElvUI then
        local E = ElvUI[1]
        if useFadeColor then
            frame:SetBackdropColor(unpack(E.media.backdropfadecolor))
        else
            frame:SetBackdropColor(unpack(E.media.backdropcolor))
        end
        frame:SetBackdropBorderColor(unpack(E.media.bordercolor))
    end
end

local _dropdownCount = 0
local function MakeFolioSetDropdown(parent, options, getValue, setValue)
    _dropdownCount = _dropdownCount + 1
    local optionSource = options

    local btn = CreateFrame(
        "DropdownButton",
        "MathWroQOL_Dropdown" .. _dropdownCount,
        parent,
        "WowStyle1DropdownTemplate"
    )
    btn:SetSize(170, 28)
    btn:SetDefaultText("")

    local function formatOptionLabel(option)
        if option.icon then
            return string.format("|T%s:14:14|t %s", option.icon, option.label)
        end
        return option.label
    end

    local function getSelectedLabel()
        local currentOptions = type(optionSource) == "function" and optionSource() or optionSource
        local current = getValue()
        for _, option in ipairs(currentOptions) do
            if option.value == current then
                return formatOptionLabel(option)
            end
        end
        return currentOptions[1] and formatOptionLabel(currentOptions[1]) or ""
    end

    local function refreshText()
        local text = getSelectedLabel()
        if btn.OverrideText then
            btn:OverrideText(text)
        elseif btn.SetText then
            btn:SetText(text)
        end
    end

    btn:SetupMenu(function(_, rootDescription)
        local currentOptions = type(optionSource) == "function" and optionSource() or optionSource
        rootDescription:SetScrollMode(320)
        for _, option in ipairs(currentOptions) do
            rootDescription:CreateRadio(
                formatOptionLabel(option),
                function(value) return getValue() == value end,
                function(value)
                    setValue(value)
                    refreshText()
                end,
                option.value
            )
        end
    end)

    function btn:Refresh()
        -- Closing clears the native scroll provider before its pooled rows change.
        if self:IsMenuOpen() then self:CloseMenu() end
        if self.GenerateMenu then
            self:GenerateMenu()
        end
        refreshText()
    end


    function btn:SetDropdownWidth(width)
        width = tonumber(width)
        if width then self:SetWidth(width) end
    end

    btn:Refresh()
    return btn
end

function addon:CreateFolioEquipmentSetControls(host)
    if not host then return nil end

    local frame = CreateFrame("Frame", nil, host, "BackdropTemplate")
    frame:SetSize(500, 132)
    frame:ClearAllPoints()
    frame:SetPoint("TOP", host, "BOTTOM", 0, -12)
    ApplyFrameBackdrop(frame, true)

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -8)
    title:SetText("Folio Equipment Sets")
    title:SetTextColor(1, 0.82, 0, 1)

    local setLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    setLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -7)
    setLabel:SetText("Equipment set:")

    local selectedSetID
    local status
    local function getFeature()
        local db = addon.db.folioEquipmentSets
        if not db or not db.enabled then return nil end
        return addon.folioEquipmentSets
    end

    local function getOptions()
        if not frame:IsVisible() then return {} end
        local feature = getFeature()
        if not feature or not feature.GetEquipmentSetOptions then return {} end
        return feature:GetEquipmentSetOptions()
    end

    local dropdown
    local summary = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    summary:SetWidth(476)
    summary:SetJustifyH("LEFT")

    local statusText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    statusText:SetWidth(476)
    statusText:SetJustifyH("LEFT")

    local saveButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    saveButton:SetSize(148, 22)
    saveButton:SetText("Save current Folio")

    local applyButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    applyButton:SetSize(148, 22)
    applyButton:SetText("Apply saved Folio")

    local clearButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clearButton:SetSize(148, 22)
    clearButton:SetText("Clear saved Folio")

    local skin = ElvSkin()
    if skin then
        skin:HandleButton(saveButton)
        skin:HandleButton(applyButton)
        skin:HandleButton(clearButton)
    end

    local function layout()
        local summaryHeight = math.max(14, summary:GetStringHeight())
        local statusHeight = math.max(14, statusText:GetStringHeight())
        summary:ClearAllPoints()
        summary:SetPoint("TOPLEFT", setLabel, "BOTTOMLEFT", 0, -10)
        statusText:ClearAllPoints()
        statusText:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -6)
        saveButton:ClearAllPoints()
        saveButton:SetPoint("TOPLEFT", statusText, "BOTTOMLEFT", 0, -8)
        applyButton:ClearAllPoints()
        applyButton:SetPoint("LEFT", saveButton, "RIGHT", 6, 0)
        clearButton:ClearAllPoints()
        clearButton:SetPoint("LEFT", applyButton, "RIGHT", 6, 0)
        frame:SetHeight(30 + 28 + 10 + summaryHeight + 6 + statusHeight + 8 + 22 + 10)
    end

    dropdown = MakeFolioSetDropdown(frame, getOptions,
        function() return selectedSetID end,
        function(value)
            selectedSetID = value
            status = nil
            frame:Refresh()
        end
    )
    dropdown:ClearAllPoints()
    dropdown:SetPoint("LEFT", setLabel, "RIGHT", 8, 0)
    dropdown:SetDropdownWidth(342)

    local function setButtonEnabled(button, enabled)
        button:SetEnabled(enabled)
        button:SetAlpha(enabled and 1 or 0.4)
    end

    function frame:Refresh(message)
        if message then status = message end
        if not self:IsVisible() then return end

        local feature = getFeature()
        local options = feature and getOptions() or {}
        local found = false
        for _, option in ipairs(options) do
            if option.value == selectedSetID then
                found = true
                break
            end
        end
        if not found then selectedSetID = options[1] and options[1].value or nil end

        local editable = feature ~= nil and not InCombatLockdown()
        local hasSaved = editable and selectedSetID and feature.HasSavedSet and feature:HasSavedSet(selectedSetID)
        setButtonEnabled(saveButton, editable and selectedSetID ~= nil and feature.SaveSet ~= nil)
        setButtonEnabled(applyButton, hasSaved == true and feature.ApplySet ~= nil)
        setButtonEnabled(clearButton, hasSaved == true and feature.ClearSet ~= nil)
        dropdown:SetEnabled(editable)
        dropdown:SetAlpha(editable and 1 or 0.4)
        dropdown:Refresh()

        if not feature then
            summary:SetText("Folio Equipment Sets is disabled.")
        elseif not selectedSetID then
            summary:SetText("No built-in equipment sets are available.")
        else
            summary:SetText((feature.GetSummary and feature:GetSummary(selectedSetID)) or "No Folio snapshot saved for this equipment set.")
        end
        statusText:SetText(status or (InCombatLockdown() and "Folio actions are unavailable in combat." or ""))
        layout()
    end

    local function runAction(method)
        local feature = getFeature()
        if InCombatLockdown() or not feature or not selectedSetID or not feature[method] then return end
        if (method == "ApplySet" or method == "ClearSet") and (not feature.HasSavedSet or not feature:HasSavedSet(selectedSetID)) then return end
        local success, message = feature[method](feature, selectedSetID)
        frame:Refresh(message or (success and "Folio updated." or "Folio action failed."))
    end

    saveButton:SetScript("OnClick", function() runAction("SaveSet") end)
    applyButton:SetScript("OnClick", function() runAction("ApplySet") end)
    clearButton:SetScript("OnClick", function() runAction("ClearSet") end)
    frame:HookScript("OnShow", function(self) self:Refresh() end)
    frame:HookScript("OnHide", function() if dropdown:IsMenuOpen() then dropdown:CloseMenu() end end)
    frame:Show()
    return frame
end

local frame = CreateFrame("Frame")
-- Core initializes feature catalogs on PLAYER_LOGIN before this frame runs.
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    local UI = addon.SettingsUI
    local root = UI.Page(nil, "MathWro QOL")
    UI.Header(root, "MathWro QOL")
    UI.Text(root, "v" .. C_AddOns.GetAddOnMetadata(addonName, "Version") .. " by MathWro. Choose a page on the left; use Blizzard Edit Mode for tracker positioning and appearance.")
    local general = UI.BuildGeneral(root.category)
    UI.Button(root, "Addon settings", "Open General", function()
        Settings.OpenToCategory(general.category:GetID())
    end)
    UI.BuildSmallTweaks(root.category)
    UI.BuildCombatLog(root.category)
    UI.BuildCVars(root.category)
    UI.BuildCombatTracker(root.category)
    UI.BuildExternalTracker(root.category)
    UI.BuildIntegrations(root.category, "elvui")
    UI.BuildIntegrations(root.category, "ellesmere")
    UI.BuildCDMPlugins(root.category)
    UI.BuildEditMode(root.category)
    UI.BuildDebug(root.category)
    Settings.RegisterAddOnCategory(root.category)

    SLASH_MQOL1 = "/mqol"
    SlashCmdList["MQOL"] = function()
        Settings.OpenToCategory(general.category:GetID())
    end
end)
