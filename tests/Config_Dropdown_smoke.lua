-- Developer-only: opening a sound menu must not recycle its live scroll rows.
-- Models Blizzard Menu.lua's row-pool reuse: SetMenuDescription replaces frames,
-- but an existing scroll data provider is only cleared when the menu closes.
local frames, mediaNames, mediaFiles = {}, {}, { None = 1 }
local inCombat = false
local methods = {}
for _, name in ipairs({ "SetPoint", "ClearAllPoints", "SetSize", "SetWidth", "SetHeight",
    "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "SetTextColor", "SetJustifyH",
    "EnableMouseWheel", "SetScrollChild", "EnableMouse", "SetAlpha", "SetDefaultText" }) do
    methods[name] = function() end
end
function methods:SetText(text) self.text = text end
methods.OverrideText = methods.SetText
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:HookScript(event, callback)
    local previous = self.scripts[event]
    self.scripts[event] = function(...) if previous then previous(...) end; callback(...) end
end
function methods:RegisterEvent() end
function methods:GetChildren() return unpack(self.children) end
function methods:GetRegions() return unpack(self.regions) end
function methods:GetParent() return self.parent end
function methods:GetTop() return nil end
function methods:IsShown() return true end
function methods:IsObjectType(kind) return self.kind == kind end
function methods:SetEnabled(enabled) self.enabled = enabled end
function methods:Enable() self.enabled = true end
function methods:Disable() self.enabled = false end
function methods:SetChecked(checked) self.checked = checked end
function methods:GetChecked() return self.checked end
function methods:CreateFontString()
    local region = setmetatable({ parent = self }, { __index = methods })
    self.regions[#self.regions + 1] = region
    return region
end
methods.CreateTexture = methods.CreateFontString
function CreateFrame(kind, name, parent)
    local frame = setmetatable({ kind = kind, parent = parent, scripts = {}, children = {}, regions = {}, enabled = true, pool = {} }, { __index = methods })
    frames[#frames + 1] = frame
    if parent then parent.children[#parent.children + 1] = frame end
    if kind == "CheckButton" then frame.Text = frame:CreateFontString() end
    return frame
end
local rootMethods = {}
function rootMethods:SetScrollMode(height) self.scrollHeight = height end
function rootMethods:CreateRadio(label, isSelected, select, value)
    local item = { label = label, isSelected = isSelected, select = select, value = value }
    self.items[#self.items + 1] = item
    return item
end
function methods:RebuildLiveRows()
    local menu = self.menu
    for _, row in ipairs(menu.frames or {}) do self.pool[#self.pool + 1] = row end
    menu.frames = {}
    for _, item in ipairs(self.description.items) do
        local row = table.remove(self.pool) or {}
        row.item = item
        menu.frames[#menu.frames + 1] = row
    end
    if self.description.scrollHeight and #menu.frames * 20 > self.description.scrollHeight then
        if not menu.rows then
            menu.rows = {}
            for index, row in ipairs(menu.frames) do menu.rows[index] = row end
        end
    else
        menu.rows = menu.frames
    end
end
function methods:SetupMenu(generator) self.generator = generator end
function methods:GenerateMenu()
    self.description = setmetatable({ items = {} }, { __index = rootMethods })
    self.generator(self, self.description)
    if self.menu then self:RebuildLiveRows() end
end
function methods:IsMenuOpen() return self.menu ~= nil end
function methods:CloseMenu() self.menu = nil end
function methods:OpenMenu()
    self:GenerateMenu()
    self.menu = {}
    self:RebuildLiveRows()
end
function methods:MouseDown()
    -- The intrinsic opens first; HookScript("OnMouseDown") runs afterward.
    if self:IsMenuOpen() then self:CloseMenu() else self:OpenMenu() end
    if self.scripts.OnMouseDown then self.scripts.OnMouseDown(self) end
end
function methods:Pick(value)
    for _, row in ipairs(self.menu.rows) do
        if row.item.value == value then
            row.item.select(value)
            self:CloseMenu()
            return
        end
    end
    error("Sound cannot be selected: " .. value)
end
local function registerSound(name, file)
    if not mediaFiles[name] then mediaNames[#mediaNames + 1] = name; table.sort(mediaNames) end
    mediaFiles[name] = file
end
registerSound("BigWigs: Alarm", 123456)
for index = 1, 40 do registerSound("Sound " .. index, "Interface\\Sounds\\" .. index .. ".ogg") end
registerSound("Yellow", "Interface\\Sounds\\Yellow.ogg")
local media = {}
function media:List() return mediaNames end
function media:Fetch(_, name) return mediaFiles[name] end
LibStub = function() return media end
C_Spell = { GetSpellInfo = function(id) return { name = tostring(id), iconID = id } end }
C_Timer = { After = function(_, callback) callback() end }
function InCombatLockdown() return inCombat end
local settings = { enabled = true, mode = "both", sound = "None" }
local addon = {
    db = { externalTracker = { enabled = true, spells = { [33206] = settings } }, bloodlustTracker = { enabled = false } },
    externalTracker = { spells = { { spellID = 33206, label = "Pain Suppression" } } },
    NotifyFeature = function() end,
}
assert(loadfile("Config.lua"))("MathWroQOL", addon)
local function upvalue(fn, wanted)
    for index = 1, 100 do
        local name, value = debug.getupvalue(fn, index)
        if name == wanted then return value end
        if not name then break end
    end
    error("Missing test entry point: " .. wanted)
end
local buildPanel = upvalue(frames[#frames].scripts.OnEvent, "BuildExternalTrackerPanel")
local panel = buildPanel()
local soundDropdown, preview
for _, frame in ipairs(frames) do
    if frame.description then
        for _, item in ipairs(frame.description.items) do
            if item.value == "BigWigs: Alarm" then soundDropdown = frame end
        end
    end
    if frame.text == "Preview Sound" then preview = frame end
end
assert(soundDropdown, "sound selector was not built")
soundDropdown:MouseDown()
assert(soundDropdown:IsMenuOpen(), "opening the sound selector must leave it open")
assert(soundDropdown.menu.rows[1].item.value == "None", "opening a scrolling menu must not recycle live rows into reversed/overlapping entries")
assert(soundDropdown.menu.rows[#soundDropdown.menu.rows].item.value == "Yellow", "last sound must remain at the bottom")
soundDropdown:Pick("Yellow")
assert(settings.sound == "Yellow", "selecting the last sound must save that sound")
-- Another addon registers media after the options panel was already built.
registerSound("AirHorn", "Interface\\AddOns\\MiniAuras\\Sounds\\Effects\\AirHorn.ogg")
soundDropdown:MouseDown()
assert(soundDropdown.menu.rows[2].item.value == "AirHorn", "newly registered sounds must appear on opening, without rebuilding the open menu")
soundDropdown:Pick("AirHorn")
local played
PlaySoundFile = function(file) played = file end
preview.scripts.OnClick(preview)
assert(settings.sound == "AirHorn" and played == "Interface\\AddOns\\MiniAuras\\Sounds\\Effects\\AirHorn.ogg", "selection and preview must resolve the newly registered sound")
-- An addon load can refresh controls while a scrolling menu is already open.
soundDropdown:MouseDown()
panel.scripts.OnEvent(panel, "ADDON_LOADED", "SomeSoundPack")
if not soundDropdown:IsMenuOpen() then soundDropdown:MouseDown() end
assert(soundDropdown.menu.rows[1].item.value == "None" and soundDropdown.menu.rows[2].item.value == "AirHorn", "panel refresh must not corrupt the active scroll provider")
soundDropdown:Pick("BigWigs: Alarm")
preview.scripts.OnClick(preview)
assert(settings.sound == "BigWigs: Alarm" and played == 123456, "numeric SharedMedia files must remain selectable and previewable")
-- A missing pack preserves the selection without substituting another sound.
mediaFiles.AirHorn = nil
for index, name in ipairs(mediaNames) do if name == "AirHorn" then table.remove(mediaNames, index); break end end
settings.sound = "AirHorn"
panel.scripts.OnEvent(panel, "ADDON_LOADED", "RemovedSoundPack")
soundDropdown:MouseDown()
local unavailable
for _, row in ipairs(soundDropdown.menu.rows) do if row.item.value == "AirHorn" then unavailable = row.item end end
assert(unavailable and settings.sound == "AirHorn" and not preview.enabled, "unavailable selections must remain visible without enabling a replacement preview")
print("Config dropdown smoke PASS: live row stability, late media, selection, preview, and missing packs")
