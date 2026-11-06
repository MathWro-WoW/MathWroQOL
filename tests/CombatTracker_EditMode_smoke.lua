-- Developer-only: Combat Tracker appearance controls must use the native LibEditMode dialog.
-- This file is outside MathWroQOL.toc and is never loaded by the addon.

local frames = {}
local inCombat = false

local methods = {}
for _, name in ipairs({
    "ClearAllPoints", "SetAllPoints", "SetClampedToScreen", "SetFrameLevel", "SetFrameStrata",
    "SetDrawBling", "SetDrawEdge", "SetJustifyH", "SetTextColor", "SetNormalTexture",
    "SetDontSavePosition", "RegisterForDrag", "EnableMouse", "RegisterEvent", "UnregisterEvent",
    "StartMoving", "StopMovingOrSizing", "SetPropagateKeyboardInput", "SetPropagateMouseMotion",
    "SetAutoFocus", "ClearFocus", "SetCursorPosition", "Layout", "OnLoad",
}) do
    methods[name] = function() end
end
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:SetWidth(width) self.width = width end
function methods:SetHeight(height) self.height = height end
function methods:SetPoint(point, relativeTo, relativePoint, x, y)
    if type(relativeTo) == "number" then
        x, y, relativeTo, relativePoint = relativeTo, relativePoint, nil, nil
    end
    self.point, self.relativeTo, self.relativePoint, self.x, self.y = point, relativeTo, relativePoint, x or 0, y or 0
end
function methods:GetPoint() return self.point or "CENTER", self.relativeTo, self.relativePoint, self.x or 0, self.y or 0 end
function methods:GetLeft() return nil end
function methods:GetRight() return nil end
function methods:GetTop() return nil end
function methods:GetBottom() return nil end
function methods:GetCenter() return nil, nil end
function methods:GetWidth() return self.width or 1920 end
function methods:GetHeight() return self.height or 1080 end
function methods:GetSize() return self:GetWidth(), self:GetHeight() end
function methods:GetScale() return self.scale or 1 end
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:HookScript(event, callback)
    local previous = self.scripts[event]
    self.scripts[event] = function(...)
        if previous then previous(...) end
        callback(...)
    end
end
function methods:SetParent(parent) self.parent = parent end
function methods:GetParent() return self.parent end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:IsShown() return self.shown ~= false end
function methods:IsVisible() return self:IsShown() end
function methods:SetShown(shown) self.shown = shown end
function methods:SetMovable(movable) self.movable = movable end
function methods:ShowSelected(selected) self.isSelected, self.shown = selected, true end
function methods:ShowHighlighted() self.isSelected, self.shown = false, true end
function methods:SetEnabled(enabled) self.enabled = enabled end
function methods:SetOnClickHandler(handler) self.onClick = handler end
function methods:SetText(text) self.text = text end
function methods:SetFont(path, size, flags) self.fontPath, self.fontSize, self.fontFlags = path, size, flags end
function methods:SetHideCountdownNumbers(hidden) self.hideCountdownNumbers = hidden end
function methods:Clear() self.cleared = true end
function methods:SetTexCoord(...) self.texCoords = { ... } end
function methods:SetTexture(texture) self.texture = texture end
function methods:SetChecked(checked) self.checked = checked end
function methods:Init(value, minValue, maxValue, steps, formatters)
    self.value, self.minValue, self.maxValue, self.steps, self.formatters = value, minValue, maxValue, steps, formatters
end
function methods:SetupMenu(generator) self.menuGenerator = generator end
function methods:SetCooldownFromDurationObject() end
function methods:SetDesaturated(value) self.desaturated = value end
function methods:CreateTexture()
    local texture = setmetatable({ parent = self, scripts = {}, shown = true }, { __index = methods })
    self.textures[#self.textures + 1] = texture
    return texture
end
function methods:CreateFontString()
    local text = setmetatable({ parent = self, scripts = {}, shown = true }, { __index = methods })
    self.fontStrings[#self.fontStrings + 1] = text
    return text
end

function CreateFrame(kind, name, parent, template)
    local frame = setmetatable({
        kind = kind, name = name, parent = parent, template = template, scripts = {}, textures = {}, fontStrings = {}, shown = true,
    }, { __index = methods })
    frames[#frames + 1] = frame
    if name then _G[name] = frame end
    if template == "CooldownFrameTemplate" then
        frame.cooldownText = frame:CreateFontString()
    elseif template == "EditModeSettingSliderTemplate" then
        frame.Label = frame:CreateFontString()
        frame.Slider = CreateFrame("Slider", nil, frame)
        frame.Slider.MinText = frame.Slider:CreateFontString()
        frame.Slider.MaxText = frame.Slider:CreateFontString()
        frame.Slider.RightText = frame.Slider:CreateFontString()
    elseif template == "EditModeSettingCheckboxTemplate" then
        frame.Label = frame:CreateFontString()
        frame.Button = CreateFrame("CheckButton", nil, frame)
    end
    return frame
end

UIParent = CreateFrame("Frame", "UIParent")
UIParent:SetSize(1920, 1080)

function InCombatLockdown() return inCombat end
function CopyTable(value)
    local result = {}
    for key, entry in pairs(value) do result[key] = entry end
    return result
end
function Mixin(object, mixin)
    for key, value in pairs(mixin) do object[key] = value end
    return object
end
function GenerateClosure(func, ...)
    local args = { ... }
    return function(...) return func(unpack(args), ...) end
end
function securecallfunction(callback, ...) return callback(...) end
table.wipe = function(t) for key in pairs(t) do t[key] = nil end return t end

WHITE_FONT_COLOR = { GetRGB = function() return 1, 1, 1 end }
DISABLED_FONT_COLOR = { GetRGB = function() return 0.5, 0.5, 0.5 end }
RESET_TO_DEFAULT = "Reset"
HUD_EDIT_MODE_RESET_POSITION = "Reset position"

local eventCallbacks = {}
EventRegistry = {
    RegisterFrameEventAndCallback = function(_, event, callback) eventCallbacks[event] = callback end,
    RegisterCallback = function(_, event, callback)
        eventCallbacks[event] = eventCallbacks[event] or {}
        table.insert(eventCallbacks[event], callback)
    end,
    TriggerEvent = function(_, event, ...)
        for _, callback in ipairs(eventCallbacks[event] or {}) do callback(...) end
    end,
}
EditModeManagerFrame = CreateFrame("Frame")
function EditModeManagerFrame:ClearSelectedSystem() end
EditModeSystemSettingsDialog = CreateFrame("Frame")
function hooksecurefunc(target, method, callback)
    local previous = target[method]
    target[method] = function(...)
        if previous then previous(...) end
        callback(...)
    end
end
C_EditMode = { GetLayouts = function() return { layouts = {}, activeLayout = 1 } end }
Enum = { EditModeSettingDisplayType = { Slider = 1, Dropdown = 2, Checkbox = 3 } }
DefaultTooltipMixin = { OnLeave = function() end }
SettingsTooltip = {}
SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 1 }
function PlaySound() end
MinimalSliderWithSteppersMixin = { Label = { Right = {} } }
function CreateMinimalSliderFormatter() return {} end

function CreateUnsecuredObjectPool(creationFunc, resetterFunc)
    local pool = { creationFunc = creationFunc, resetterFunc = resetterFunc, active = {}, inactive = {} }
    function pool:Acquire()
        local object = table.remove(self.inactive)
        local new = object == nil
        if new then object = self.creationFunc(self) end
        table.insert(self.active, object)
        return object, new
    end
    function pool:ReleaseAll()
        for _, object in ipairs(self.active) do
            if self.resetterFunc then self.resetterFunc(self, object) end
            table.insert(self.inactive, object)
        end
        self.active = {}
    end
    return pool
end

local libraries = {}
LibStub = setmetatable({}, {
    __call = function(_, name) return libraries[name] end,
})
function LibStub:NewLibrary(name)
    libraries[name] = libraries[name] or {}
    return libraries[name]
end

local namespace = {}
assert(loadfile("Libs/LibEditMode/LibEditMode.lua"))("LibEditMode", namespace)
local editMode = assert(libraries["LibEditMode"], "bundled LibEditMode did not load")
namespace.LibEditMode = editMode
assert(loadfile("Libs/LibEditMode/pools.lua"))("LibEditMode", namespace)
assert(loadfile("Libs/LibEditMode/widgets/button.lua"))("LibEditMode", namespace)
assert(loadfile("Libs/LibEditMode/widgets/slider.lua"))("LibEditMode", namespace)
assert(loadfile("Libs/LibEditMode/widgets/checkbox.lua"))("LibEditMode", namespace)
assert(loadfile("Libs/LibEditMode/widgets/dropdown.lua"))("LibEditMode", namespace)
assert(loadfile("Libs/LibEditMode/widgets/dialog.lua"))("LibEditMode", namespace)

local addon = {
    db = {
        combatTracker = {
            enabled = true,
            masque = { enabled = false },
            frames = {
                racials = {
                    point = "CENTER", x = -220, y = 200, layout = "horizontal", growDirection = "growRight", gridCols = 2,
                    iconWidth = 31, iconHeight = 32, enabled = true,
                    stackCountEnabled = true, stackCountFontSize = 11, stackCountFont = "Fonts\\ARIALN.TTF",
                    cdCountEnabled = true, cdCountFontSize = 13, cdCountFont = "Fonts\\MORPHEUS.TTF",
                },
                trinkets = {
                    point = "CENTER", x = 0, y = 200, layout = "horizontal", growDirection = "growRight", gridCols = 2,
                    iconWidth = 41, iconHeight = 42, enabled = true, mergeInto = "racials",
                    stackCountEnabled = false, stackCountFontSize = 15, stackCountFont = "Fonts\\skurri.TTF",
                    cdCountEnabled = false, cdCountFontSize = 17, cdCountFont = "Fonts\\ARIALN.TTF",
                },
                consumables = {
                    point = "CENTER", x = 220, y = 200, layout = "horizontal", growDirection = "growRight", gridCols = 2,
                    iconWidth = 51, iconHeight = 52, enabled = true,
                    stackCountEnabled = true, stackCountFontSize = 19, stackCountFont = "Fonts\\FRIZQT__.TTF",
                    cdCountEnabled = true, cdCountFontSize = 21, cdCountFont = "Fonts\\skurri.TTF",
                },
                foodWater = {
                    point = "CENTER", x = 220, y = 140, layout = "horizontal", growDirection = "growRight", gridCols = 2,
                    iconWidth = 36, iconHeight = 36, enabled = true,
                    stackCountEnabled = true, stackCountFontSize = 12, stackCountFont = "Fonts\\FRIZQT__.TTF",
                    cdCountEnabled = true, cdCountFontSize = 14, cdCountFont = "Fonts\\FRIZQT__.TTF",
                },
            },
        },
    },
}
function addon:RegisterFeature(feature) self.feature = feature end
assert(loadfile("Features/CombatTracker.lua"))("MathWroQOL", addon)
local tracker = assert(addon.feature, "Combat Tracker did not register")

local function makeSection(name)
    local section = { name = name, buttons = {} }
    function section:GetIcons()
        local visible = {}
        for _, button in ipairs(self.buttons) do if button:IsShown() then visible[#visible + 1] = button end end
        return visible
    end
    function section:RebuildIcons()
        if #self.buttons == 0 then
            local button = tracker.CreateButton()
            button._sectionName = self.name
            button:Show()
            self.buttons[1] = button
        end
        tracker:ApplySectionFont(self.name)
        tracker:ApplyCooldownFont(self.name)
        tracker:LayoutSection(tracker:GetHostKey(self.name))
    end
    function section:Initialize() end
    tracker:RegisterSection(section)
    return section
end

local racials = makeSection("racials")
local trinkets = makeSection("trinkets")
local consumables = makeSection("consumables")
local foodWater = makeSection("foodWater")
foodWater.managedBy = "consumables"
foodWater.displayName = "Food & Water"
local rebuildFood = foodWater.RebuildIcons
local rebuildConsumables = consumables.RebuildIcons
local consumableScans = 0
function consumables:RebuildIcons()
    consumableScans = consumableScans + 1
    rebuildFood(foodWater)
    rebuildConsumables(self)
end
function foodWater:RebuildIcons() consumables:RebuildIcons() end
tracker:Initialize()
assert(consumableScans == 2, "managed food/water must not duplicate Initialize or Apply scans")
EditModeManagerFrame.scripts.OnShow(EditModeManagerFrame)
assert(editMode:IsInEditMode(), "the bundled library must enter Edit Mode before CT selections can be clicked")


local function clickAnchor(frame)
    local selection = assert(editMode.frameSelections[frame], "section must have a LibEditMode selection")
    assert(selection.scripts.OnMouseDown, "selection must retain bundled click routing")
    selection.scripts.OnMouseDown(selection)
    local dialog = assert(editMode.internal.dialog, "bundled LibEditMode must create its floating dialog")
    assert(dialog:IsShown() and dialog.selection == selection, "clicking CT selection must open its floating dialog")
    assert(#dialog.Settings.widgets > 0, "clicking CT selection must produce visible native setting rows")
    for _, widget in ipairs(dialog.Settings.widgets) do
        assert(widget:IsShown(), "native setting rows must remain visible in the floating dialog")
    end
    return editMode.frameSettings[frame]
end

local function setting(settings, kind, value)
    for _, candidate in ipairs(settings or {}) do
        if candidate.kind == kind and candidate.get("Modern") == value then return candidate end
    end
    error("missing native setting for saved value " .. tostring(value))
end
local function settingNamed(settings, name)
    for _, candidate in ipairs(settings or {}) do
        if candidate.name == name then return candidate end
    end
    error("missing native setting " .. name)
end


local function widgetFor(settingObject)
    for _, widget in ipairs(editMode.internal.dialog.Settings.widgets) do
        if widget.setting == settingObject then return widget end
    end
    error("native setting did not create its widget")
end

local function choose(widget, value)
    local selected
    widget.Dropdown.menuGenerator(widget.Dropdown, {
        CreateRadio = function(_, _, _, select, data)
            if data.value == value then selected = { select = select, data = data } end
        end,
    })
    assert(selected, "native dropdown did not offer the requested value")
    selected.select(selected.data)
end

local racialSettings = clickAnchor(tracker.frames.racials)
local textSection = setting(racialSettings, editMode.SettingType.Dropdown, "racials")
choose(widgetFor(textSection), "trinkets")
local trinketStackSize = setting(racialSettings, editMode.SettingType.Slider, 15)
local trinketStackEnabled = settingNamed(racialSettings, "Show stack count")
local trinketCooldownSize = setting(racialSettings, editMode.SettingType.Slider, 17)
local trinketCooldownEnabled = settingNamed(racialSettings, "Show cooldown count")
local trinketStackFont = setting(racialSettings, editMode.SettingType.Dropdown, "Fonts\\skurri.TTF")
local trinketCooldownFont = setting(racialSettings, editMode.SettingType.Dropdown, "Fonts\\ARIALN.TTF")
widgetFor(trinketStackSize):OnSliderValueChanged(22)
widgetFor(trinketStackEnabled):OnCheckButtonClick()
widgetFor(trinketCooldownSize):OnSliderValueChanged(23)
widgetFor(trinketCooldownEnabled):OnCheckButtonClick()
choose(widgetFor(trinketStackFont), "Fonts\\MORPHEUS.TTF")
choose(widgetFor(trinketCooldownFont), "Fonts\\skurri.TTF")
assert(addon.db.combatTracker.frames.trinkets.stackCountFontSize == 22
    and addon.db.combatTracker.frames.trinkets.stackCountEnabled
    and addon.db.combatTracker.frames.trinkets.cdCountFontSize == 23
    and addon.db.combatTracker.frames.trinkets.cdCountEnabled,
    "merged-section controls must preserve and update their own saved preferences")
assert(trinkets.buttons[1].countText.fontPath == "Fonts\\MORPHEUS.TTF"
    and trinkets.buttons[1].countText.fontSize == 22
    and trinkets.buttons[1].cooldown.cooldownText.fontPath == "Fonts\\skurri.TTF"
    and trinkets.buttons[1].cooldown.cooldownText.fontSize == 23
    and not trinkets.buttons[1].cooldown.hideCountdownNumbers,
    "merged-section text appearance must update its existing icon without a rescan")
local racialStackSize = addon.db.combatTracker.frames.racials.stackCountFontSize
local racialStackFont = addon.db.combatTracker.frames.racials.stackCountFont
local racialCooldownSize = addon.db.combatTracker.frames.racials.cdCountFontSize
local racialCooldownFont = addon.db.combatTracker.frames.racials.cdCountFont
clickAnchor(tracker.frames.racials)
assert(setting(racialSettings, editMode.SettingType.Dropdown, "trinkets"),
    "reselecting a merged host must retain its selected text section")
editMode.internal.dialog.Settings.ResetButton.onClick()
local resetTrinkets = addon.db.combatTracker.frames.trinkets
local resetRacials = addon.db.combatTracker.frames.racials
assert(resetTrinkets.stackCountEnabled and resetTrinkets.stackCountFontSize == 12
    and resetTrinkets.stackCountFont == "Fonts\\FRIZQT__.TTF"
    and resetTrinkets.cdCountEnabled and resetTrinkets.cdCountFontSize == 14
    and resetTrinkets.cdCountFont == "Fonts\\FRIZQT__.TTF",
    "resetting a merged host must reset its selected contributor's text settings")
assert(resetRacials.stackCountFontSize == racialStackSize and resetRacials.stackCountFont == racialStackFont
    and resetRacials.cdCountFontSize == racialCooldownSize and resetRacials.cdCountFont == racialCooldownFont,
    "resetting a merged host must not reset an unselected section's text preferences")
assert(resetRacials.iconWidth == 36 and resetRacials.iconHeight == 36,
    "resetting a merged host must still reset its own icon dimensions")


local consumableSettings = clickAnchor(tracker.frames.consumables)
local width = setting(consumableSettings, editMode.SettingType.Slider, 51)
local height = setting(consumableSettings, editMode.SettingType.Slider, 52)
widgetFor(width):OnSliderValueChanged(64)
widgetFor(height):OnSliderValueChanged(29)
assert(addon.db.combatTracker.frames.consumables.iconWidth == 64
    and addon.db.combatTracker.frames.consumables.iconHeight == 29
    and consumables.buttons[1].width == 64 and consumables.buttons[1].height == 29,
    "native icon controls must immediately resize live icons")

local foodSettings = clickAnchor(tracker.frames.foodWater)
local foodWidth = settingNamed(foodSettings, "Icon width")
widgetFor(foodWidth):OnSliderValueChanged(47)
local foodStack = settingNamed(foodSettings, "Stack count font size")
widgetFor(foodStack):OnSliderValueChanged(18)
local foodFont = settingNamed(foodSettings, "Stack count font")
choose(widgetFor(foodFont), "Fonts\\MORPHEUS.TTF")
local foodCooldown = settingNamed(foodSettings, "Cooldown count font size")
widgetFor(foodCooldown):OnSliderValueChanged(20)
assert(foodWater.buttons[1].width == 47 and foodWater.buttons[1].countText.fontSize == 18
    and foodWater.buttons[1].countText.fontPath == "Fonts\\MORPHEUS.TTF"
    and foodWater.buttons[1].cooldown.cooldownText.fontSize == 20
    and consumables.buttons[1].width == 64,
    "food/water native appearance must belong to its independent frame")
local foodFrame = tracker.frames.foodWater
foodFrame:ClearAllPoints()
foodFrame:SetPoint("CENTER", UIParent, "CENTER", 310, 110)
editMode.frameCallbacks[foodFrame](foodFrame, "Modern", "CENTER", 310, 110)
assert(addon.db.combatTracker.frames.foodWater.x ~= 220
    and addon.db.combatTracker.frames.consumables.iconWidth == 64,
    "food/water movement must save independently")
inCombat = true
foodWidth.set("Modern", 25)
inCombat = false
assert(addon.db.combatTracker.frames.foodWater.iconWidth == 47,
    "food/water appearance must remain combat gated")
addon.db.combatTracker.frames.foodWater.enabled = false
foodWidth.set("Modern", 25)
tracker:Apply()
assert(addon.db.combatTracker.frames.foodWater.iconWidth == 47 and not foodFrame:IsShown()
    and not foodWater.buttons[1]:IsShown(), "food/water own enable gate must hide its display and block edits")
addon.db.combatTracker.frames.foodWater.enabled = true
addon.db.combatTracker.frames.foodWater.mergeInto = "consumables"
addon.db.combatTracker.frames.racials.mergeInto = "foodWater"
assert(tracker:GetHostKey("foodWater") == "foodWater" and tracker:GetHostKey("racials") == "racials",
    "managed food/water must neither merge nor become an ordinary merge target")
addon.db.combatTracker.frames.foodWater.mergeInto = nil
addon.db.combatTracker.frames.racials.mergeInto = nil
addon.db.combatTracker.frames.consumables.enabled = false
foodWidth.set("Modern", 30)
assert(foodWidth.disabled() and addon.db.combatTracker.frames.foodWater.iconWidth == 47,
    "food/water native settings must honor their parent section gate")
tracker:Apply()
assert(not foodFrame:IsShown() and not foodWater.buttons[1]:IsShown(),
    "parent disable must hide the independent anchor and UIParent-owned food/water icons")
addon.db.combatTracker.frames.consumables.enabled = true
tracker:Apply()
consumableSettings = clickAnchor(tracker.frames.consumables)
width = settingNamed(consumableSettings, "Icon width")
height = settingNamed(consumableSettings, "Icon height")

-- Empty anchors retain their configured footprint, so users can select and size them.
for _, button in ipairs(consumables.buttons) do button:Hide() end
tracker:LayoutSection("consumables")
assert(tracker.frames.consumables.width == 64 and tracker.frames.consumables.height == 29,
    "empty Combat Tracker anchors must use their configured icon size")

local savedWidth = addon.db.combatTracker.frames.consumables.iconWidth
inCombat = true
widgetFor(width):OnSliderValueChanged(20)
assert(addon.db.combatTracker.frames.consumables.iconWidth == savedWidth,
    "combat must not mutate native Combat Tracker settings")
inCombat = false
addon.db.combatTracker.frames.consumables.enabled = false
widgetFor(width):OnSliderValueChanged(20)
assert(addon.db.combatTracker.frames.consumables.iconWidth == savedWidth,
    "disabled sections must not mutate native Combat Tracker settings")
addon.db.combatTracker.frames.consumables.enabled = true
addon.db.combatTracker.enabled = false
widgetFor(width):OnSliderValueChanged(20)
assert(addon.db.combatTracker.frames.consumables.iconWidth == savedWidth,
    "disabled Combat Tracker must not mutate native Combat Tracker settings")
tracker:Apply()
assert(not tracker.frames.consumables:IsShown(), "disabling Combat Tracker must hide its anchor")
assert(not foodWater.buttons[1]:IsShown() and not racials.buttons[1]:IsShown(),
    "master disable must hide actual UIParent-owned display icons")

EditModeManagerFrame.scripts.OnHide(EditModeManagerFrame)
assert(not editMode.internal.dialog:IsShown(), "leaving Edit Mode must clean up the floating dialog")
inCombat = true
local selection = editMode.frameSelections[tracker.frames.racials]
selection.scripts.OnMouseDown(selection)
assert(not editMode.internal.dialog:IsShown(), "combat must not reopen a cleaned-up Edit Mode dialog")
inCombat = false
print("Combat Tracker Edit Mode smoke test: native controls, merged settings, and cleanup")
