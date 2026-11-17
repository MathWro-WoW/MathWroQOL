-- Native Settings boundary for behavioral menu tests; never loaded by the addon.
local H = {}
local timers, nextCategory, frames
local Frame = {}
Frame.__index = Frame
function Frame:RegisterEvent(event) self.events[event] = true end
function Frame:UnregisterEvent(event) self.events[event] = nil end
function Frame:SetScript(event, callback) self.scripts[event] = callback end
function Frame:HookScript(event, callback)
    local previous = self.scripts[event]
    self.scripts[event] = function(...) if previous then previous(...) end; callback(...) end
end
function Frame:IsShown() return self.shown ~= false end
function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false end
function Frame:GetParent() return self.parent end
function Frame:SetText(text) self.text = text end
function Frame:GetText() return self.text or "" end
function Frame:SetFocus() end
function Frame:HighlightText() end
function Frame:GetEditBox() return self.edit end
function Frame:GetName() return self.name end

local Row = {}
Row.__index = Row
function Row:AddModifyPredicate(predicate) self.predicates[#self.predicates + 1] = predicate end
function Row:AddShownPredicate(predicate) self.shownPredicates[#self.shownPredicates + 1] = predicate end
function Row:AddEvaluateStateCVar(id) self.watch[id] = true end
function Row:AddEvaluateStateFrameEvent(event) self.events[event] = true end
function Row:SetSettingIntercept(callback) self.intercept = callback end
function Row:EvaluateModifyPredicates()
    for _, predicate in ipairs(self.predicates) do if not predicate() then return false end end
    return true
end
function Row:ShouldShow()
    for _, predicate in ipairs(self.shownPredicates) do if not predicate() then return false end end
    return true
end
function Row:GetName()
    if self.data.setting then return self.data.setting:GetName() end
    return self.data.name
end
function Row:EvaluateState()
    self.enabled, self.shown = self:EvaluateModifyPredicates(), self:ShouldShow()
end
local function row(template, data)
    local result = setmetatable({ template = template, data = data, predicates = {}, shownPredicates = {},
        watch = {}, events = {}, enabled = true, shown = true }, Row)
    H.rows[#H.rows + 1] = result
    return result
end
local function changed(id)
    for _, entry in ipairs(H.rows) do if entry.watch[id] then entry:EvaluateState() end end
end
local function category(parent, name)
    nextCategory = nextCategory + 1
    local result = { id = nextCategory, parent = parent, name = name }
    function result:GetID() return self.id end
    function result:GetName() return self.name end
    local layout = { rows = {}, category = result }
    function layout:AddInitializer(entry)
        entry.category = self.category
        self.rows[#self.rows + 1] = entry
    end
    result.layout = layout
    H.categories[#H.categories + 1] = result
    return result, layout
end
local function control(template, cat, setting, options, tooltip)
    local entry = row(template, { setting = setting, options = options, tooltip = tooltip })
    cat.layout:AddInitializer(entry)
    setting.row = entry
    return entry
end

function H.load(interfaceVersion, module)
    H.settings, H.rows, H.categories, H.notified, H.messages = {}, {}, {}, {}, {}
    H.inCombat, H.current, H.popup = false, nil, nil
    H.root, H.openedCategoryID = nil, nil
    H.played, H.redraws = nil, 0
    H.loaded, H.libs, H.items, H.itemRequests = {}, {}, {}, {}
    H.cvars, H.cvarWrites = { SpellQueueWindow = "277", cameraDistanceMaxZoomFactor = "2.0" }, {}
    timers, frames, nextCategory = {}, {}, 0
    ElvUI, EllesmereUI, MathWroQOLDB = nil, nil, nil
    SlashCmdList = {}
    ACCEPT, CANCEL, YES, NO = "Accept", "Cancel", "Yes", "No"
    StaticPopupDialogs = {}
    function GetBuildInfo() return nil, nil, nil, interfaceVersion or 120100 end
    function InCombatLockdown() return H.inCombat end
    function CreateFrame(kind, name, parent)
        local result = setmetatable({ kind = kind, name = name, parent = parent, events = {}, scripts = {} }, Frame)
        frames[#frames + 1] = result
        return result
    end
    C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
    C_AddOns = {
        IsAddOnLoaded = function(name) return H.loaded[name] == true end,
        GetAddOnMetadata = function() return "test" end,
    }
    C_CVar = {
        GetCVar = function(name) return H.cvars[name] end,
        GetCVarInfo = function(name) return H.cvars[name], "400" end,
        SetCVar = function(name, value)
            H.cvars[name] = tostring(value)
            H.cvarWrites[#H.cvarWrites + 1] = { name, value }
        end,
    }
    C_Spell = {
        GetSpellInfo = function(id) return { name = "Spell " .. id, iconID = id } end,
        GetSpellTexture = function(id) return id end,
    }
    C_SpellBook = { GetNumSpellBookSkillLines = function() return 0 end }
    Enum = { SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Flyout = 4 } }
    function GetSpecialization() return 1 end
    function GetSpecializationInfo() return 256 end
    function IsPlayerSpell() return false end
    C_Item = {
        GetItemInfo = function(id)
            local item = H.items[id]
            if item then return item.name, "item:" .. id, 1, item.level or 1, 1, "Consumable", "Food", 1, "", item.icon or id end
        end,
        RequestLoadItemDataByID = function(id) H.itemRequests[#H.itemRequests + 1] = id end,
        IsItemDataCachedByID = function(id) return H.items[id] ~= nil end,
    }
    LibStub = function(name) return H.libs[name] end
    function PlaySoundFile(file, channel) H.played = { file = file, channel = channel } end
    Settings = {
        VarType = { Boolean = "boolean", Number = "number", String = "string" },
        ControlType = { Radio = 1, Checkbox = 2 },
        RegisterVerticalLayoutCategory = function(name) return category(nil, name) end,
        RegisterVerticalLayoutSubcategory = category,
        RegisterAddOnCategory = function(cat) H.root = cat end,
        OpenToCategory = function(id) H.openedCategoryID = id end,
        RegisterProxySetting = function(cat, id, valueType, label, default, get, set)
            assert(not H.settings[id], "duplicate native setting variable: " .. id)
            local setting = { variable = id, default = default, variableType = valueType, name = label, category = cat }
            function setting:GetValue() return get() end
            function setting:GetName() return type(label) == "function" and label() or label end
            function setting:SetValue(value)
                assert(type(value) == valueType, "native setting type mismatch: " .. id)
                if get() ~= value then set(value) end
                self.displayedValue = value
                changed(id)
            end
            function setting:SetValueToDefault()
                if default == nil then return end
                local value = default
                if type(value) == "function" then value = value() end
                self:SetValue(value)
            end
            function setting:NotifyUpdate() self.displayedValue = get(); changed(id) end
            setting.displayedValue = get()
            H.settings[id] = setting
            return setting
        end,
        NotifyUpdate = function(id) if H.settings[id] then H.settings[id]:NotifyUpdate() end end,
        CreateElementInitializer = row,
        CreateCheckbox = function(cat, setting, tooltip)
            return control("SettingsCheckboxControlTemplate", cat, setting, nil, tooltip)
        end,
        CreateSliderOptions = function(min, max, step)
            local options = { minValue = min, maxValue = max, steps = (max - min) / step }
            function options:SetLabelFormatter(_, formatter)
                self.formatter = formatter or tostring
            end
            return options
        end,
        CreateSlider = function(cat, setting, options, tooltip)
            return control("SettingsSliderControlTemplate", cat, setting, options, tooltip)
        end,
        CreateDropdown = function(cat, setting, options, tooltip)
            return control("SettingsDropdownControlTemplate", cat, setting, options, tooltip)
        end,
        CreateColorSwatch = function(cat, setting, tooltip)
            return control("SettingsColorSwatchControlTemplate", cat, setting, nil, tooltip)
        end,
    }
    MinimalSliderWithSteppersMixin = { Label = { Right = 1 } }
    function CreateSettingsListSectionHeaderInitializer(name, tooltip)
        return row("SettingsListSectionHeaderTemplate", { name = name, tooltip = tooltip })
    end
    function CreateSettingsButtonInitializer(name, buttonText, callback, tooltip, searchable)
        assert(searchable ~= nil)
        return row("SettingButtonControlTemplate", { name = name, buttonText = buttonText, buttonClick = callback, tooltip = tooltip })
    end
    SettingsPanel = {}
    function SettingsPanel:IsShown() return H.current ~= nil end
    function SettingsPanel:GetCurrentCategory() return H.current end
    function SettingsPanel:DisplayCategory(cat)
        H.redraws = (H.redraws or 0) + 1
        for _, entry in ipairs(cat.layout.rows) do
            entry:EvaluateState()
            if entry.data.setting then entry.data.setting:NotifyUpdate() end
            if entry.template == "MathWroQOLSettingsTextTemplate" then
                MathWroQOLSettingsTextMixin.Init({
                    Text = { SetText = function(_, text) entry.displayedText = text end },
                }, entry)
            end
        end
    end
    function StaticPopup_Show(which, title, _, data)
        local dialog = setmetatable({ data = data, which = which, title = title }, Frame)
        dialog.edit = setmetatable({ parent = dialog }, Frame)
        H.popup = dialog
        local definition = StaticPopupDialogs[which]
        if definition.OnShow then definition.OnShow(dialog, data) end
        return dialog
    end
    function StaticPopup_OnClick(dialog)
        local keep = StaticPopupDialogs[dialog.which].OnAccept(dialog, dialog.data)
        if not keep then H.popup = nil end
    end
    local addon = {}
    assert(loadfile("Core.lua"))("MathWroQOL", addon)
    frames[1].scripts.OnEvent(frames[1], "ADDON_LOADED", "MathWroQOL")
    local notify = addon.NotifyFeature
    function addon:NotifyFeature(name)
        H.notified[#H.notified + 1] = name
        notify(self, name)
    end
    assert(loadfile("Config/Native.lua"))("MathWroQOL", addon)
    assert(loadfile("Config/Simple.lua"))("MathWroQOL", addon)
    addon.SettingsUI.Message = function(message)
        if message then H.messages[#H.messages + 1] = message end
    end
    if module then assert(loadfile(module))("MathWroQOL", addon) end
    H.addon = addon
    return addon
end

function H.flush()
    local rounds = 0
    while #timers > 0 do
        rounds = rounds + 1
        assert(rounds < 30, "settings timers must settle")
        local pending = timers
        timers = {}
        for _, callback in ipairs(pending) do callback() end
    end
end
function H.fire(event, ...)
    for _, entry in ipairs(H.rows) do if entry.events[event] then entry:EvaluateState() end end
    for _, frame in ipairs(frames) do
        if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, ...) end
    end
end
function H.open(page)
    H.current = page.category
    SettingsPanel:DisplayCategory(page.category)
    H.flush()
end
function H.options(id)
    local setting = assert(H.settings[id] or H.settings["MathWroQOL_" .. id], "missing dropdown: " .. id)
    return setting.row.data.options()
end
function H.button(text)
    for index = #H.rows, 1, -1 do
        local entry = H.rows[index]
        if entry.data.buttonText == text and (not H.current or entry.category == H.current) then return entry end
    end
    error("missing settings button: " .. text)
end
function H.click(text)
    local entry = H.button(text)
    entry:EvaluateState()
    if entry.enabled and entry.shown then entry.data.buttonClick() end
    H.flush()
end
function H.input(text)
    assert(H.popup, "no input dialog open")
    H.popup.edit:SetText(text)
    StaticPopup_OnClick(H.popup, 1)
    H.flush()
end
function H.cancelInput() H.popup = nil end
function H.setting(id) return assert(H.settings["MathWroQOL_" .. id], "missing setting: " .. id) end
function H.set(id, value) H.setting(id):SetValue(value); H.flush() end
function H.get(id) return H.setting(id):GetValue() end
function H.snapshot(value)
    if type(value) ~= "table" then return type(value) .. ":" .. tostring(value) end
    local keys, parts = {}, {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, key in ipairs(keys) do parts[#parts + 1] = H.snapshot(key) .. "=" .. H.snapshot(value[key]) end
    return "{" .. table.concat(parts, ",") .. "}"
end
function H.catalogs()
    local addon = H.addon
    local tracker = { sections = {} }
    function tracker:RegisterSection(section) self.sections[section.name] = section end
    addon.combatTracker = tracker
    assert(loadfile("Features/CombatTracker_Consumables.lua"))("MathWroQOL", addon)
    tracker.sections.racials = { _allRacialNames = { { name = "Stoneform" }, { name = "Fireblood" } } }
    local count = #addon.features
    assert(loadfile("Features/ExternalTracker.lua"))("MathWroQOL", addon)
    -- Exercise real catalogs without initializing gameplay displays in a Settings fixture.
    for index = #addon.features, count + 1, -1 do table.remove(addon.features, index) end
    return tracker
end
return H
