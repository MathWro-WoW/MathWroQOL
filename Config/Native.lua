local _, addon = ...
local UI = {}
addon.SettingsUI = UI

local pages = {}
local prefix = "MathWroQOL_"

local function variable(id)
    return prefix .. id
end

function UI.IsAddonLoaded(name)
    return C_AddOns.IsAddOnLoaded(name)
end

function UI.Message(message)
    if message then print("|cff33ff99MathWroQOL:|r " .. tostring(message)) end
end

function UI.Page(parent, title)
    local category, layout
    if parent then
        category, layout = Settings.RegisterVerticalLayoutSubcategory(parent, title)
    else
        category, layout = Settings.RegisterVerticalLayoutCategory(title)
    end
    local page = { category = category, layout = layout }
    pages[#pages + 1] = page
    return page
end

function UI.Refresh(page)
    if page.pending then return end
    page.pending = true
    C_Timer.After(0, function()
        page.pending = nil
        if SettingsPanel and SettingsPanel:IsShown() and SettingsPanel:GetCurrentCategory() == page.category then
            SettingsPanel:DisplayCategory(page.category)
        end
    end)
end


local function configure(initializer, config)
    if not config then return end
    if config.enabled then initializer:AddModifyPredicate(config.enabled) end
    if config.shown then initializer:AddShownPredicate(config.shown) end
    for _, id in ipairs(config.watch or {}) do
        initializer:AddEvaluateStateCVar(variable(id))
    end
    for _, event in ipairs(config.events or {}) do
        initializer:AddEvaluateStateFrameEvent(event)
    end
end

local function proxy(page, id, label, default, valueType, get, set, config)
    local name = variable(id)
    local setting = Settings.RegisterProxySetting(page.category, name, valueType, label, default, get, function(value)
        if config and config.guard and not config.guard() then
            -- A rejected Defaults/direct write still emits the proposed value.
            C_Timer.After(0, function() Settings.NotifyUpdate(name) end)
            return
        end
        set(value)
        if config and config.refresh then UI.Refresh(page) end
    end)
    return setting
end

local function finish(initializer, setting, config)
    configure(initializer, config)
    if config and config.guard then
        initializer:SetSettingIntercept(function() return not config.guard() end)
    end
    return initializer, setting
end

function UI.Header(page, title, tooltip)
    local row = CreateSettingsListSectionHeaderInitializer(title, tooltip)
    page.layout:AddInitializer(row)
    return row
end

MathWroQOLSettingsTextMixin = {}
function MathWroQOLSettingsTextMixin:Init(initializer)
    local text = initializer.data.text
    self.Text:SetText(type(text) == "function" and text() or text)
end

function UI.Text(page, text)
    local row = Settings.CreateElementInitializer("MathWroQOLSettingsTextTemplate", { text = text })
    page.layout:AddInitializer(row)
    return row
end

function UI.Checkbox(page, id, label, default, get, set, config)
    local setting = proxy(page, id, label, default, Settings.VarType.Boolean,
        function() return get() == true end, set, config)
    return finish(Settings.CreateCheckbox(page.category, setting, config and config.tooltip), setting, config)
end

function UI.Slider(page, id, label, min, max, step, default, get, set, config)
    local setting = proxy(page, id, label, default, Settings.VarType.Number, get, set, config)
    local options = Settings.CreateSliderOptions(min, max, step)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, config and config.formatter)
    return finish(Settings.CreateSlider(page.category, setting, options, config and config.tooltip), setting, config)
end

local function scrollMenu(rootDescription)
    rootDescription:SetScrollMode(320)
end

function UI.Dropdown(page, id, label, default, get, set, entries, config)
    local valueType = config and config.variableType or type(default)
    if valueType == "nil" then valueType = type(get()) end
    local setting = proxy(page, id, label, default, valueType, get, set, config)
    local function options()
        local result = {}
        local choices = type(entries) == "function" and entries() or entries
        for _, entry in ipairs(choices) do
            local text = entry.label
            if entry.icon then text = string.format("|T%s:14:14|t %s", entry.icon, text) end
            result[#result + 1] = {
                value = entry.value, label = text, text = text, tooltip = entry.tooltip,
                controlType = Settings.ControlType.Radio,
            }
        end
        return result
    end
    local row = Settings.CreateDropdown(page.category, setting, options, config and config.tooltip)
    row.customOptionHandler = scrollMenu
    return finish(row, setting, config)
end

local function colorString(color)
    return string.format("ff%02x%02x%02x", math.floor((color.r or 1) * 255 + 0.5),
        math.floor((color.g or 1) * 255 + 0.5), math.floor((color.b or 1) * 255 + 0.5))
end
function UI.Color(page, id, label, default, get, set, config)
    local defaultValue = type(default) == "function" and function() return colorString(default()) end or colorString(default)
    local setting = proxy(page, id, label, defaultValue, Settings.VarType.String,
        function() return colorString(get()) end,
        function(value)
            set({ r = tonumber(value:sub(3, 4), 16) / 255,
                g = tonumber(value:sub(5, 6), 16) / 255, b = tonumber(value:sub(7, 8), 16) / 255 })
        end, config)
    return finish(Settings.CreateColorSwatch(page.category, setting, config and config.tooltip), setting, config)
end

function UI.Button(page, label, text, callback, config)
    local row = CreateSettingsButtonInitializer(label, text, function()
        if config and config.guard and not config.guard() then return end
        callback()
        if config and config.refresh then UI.Refresh(page) end
    end, config and config.tooltip, false)
    configure(row, config)
    page.layout:AddInitializer(row)
    return row
end

function UI.Input(page, title, initial, apply, config)
    if config and config.guard and not config.guard() then return end
    local key = "MATHWROQOL_SETTINGS_INPUT"
    if not StaticPopupDialogs[key] then
        StaticPopupDialogs[key] = {
            text = "%s", button1 = ACCEPT, button2 = CANCEL, hasEditBox = true,
            maxLetters = 0, timeout = 0, whileDead = true, hideOnEscape = true,
            preferredIndex = 3,
            OnShow = function(dialog)
                local edit = dialog:GetEditBox()
                edit:SetText(dialog.data.initial)
                edit:HighlightText()
                edit:SetFocus()
            end,
            OnAccept = function(dialog, data)
                if data.guard and not data.guard() then return end
                local success, message = data.apply(dialog:GetEditBox():GetText())
                UI.Message(message)
                if success == false then return true end
                UI.Refresh(data.page)
            end,
            EditBoxOnEnterPressed = function(edit) StaticPopup_OnClick(edit:GetParent(), 1) end,
        }
    end
    return StaticPopup_Show(key, title, nil, {
        page = page, initial = tostring(initial or ""), apply = apply, guard = config and config.guard,
    })
end

local eventFrame = CreateFrame("Frame")
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
    eventFrame:RegisterEvent(event)
end
eventFrame:SetScript("OnEvent", function()
    if not SettingsPanel or not SettingsPanel:IsShown() then return end
    local current = SettingsPanel:GetCurrentCategory()
    for _, page in ipairs(pages) do
        if page.category == current then UI.Refresh(page); return end
    end
end)
