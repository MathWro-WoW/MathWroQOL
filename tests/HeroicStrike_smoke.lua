-- Developer-only regression smoke: late CDM loading and disable/spec transitions
-- must not lose an active proc or revive a disabled icon. WoW frames are simulated.
local frames = {}
local spec = 71
local proc = false
local queries = 0
local Frame = {}
Frame.__index = Frame

function Frame:RegisterEvent(event) self.events[event] = true end
function Frame:UnregisterEvent(event) self.events[event] = nil end
function Frame:UnregisterAllEvents() self.events = {} end
function Frame:SetScript(script, callback) self[script] = callback end
function Frame:HookScript(script, callback)
    local original = self[script]
    self[script] = function(...)
        if original then original(...) end
        callback(...)
    end
end
function Frame:SetSize(width, height) self.width, self.height = width, height end
function Frame:GetSize() return self.width, self.height end
function Frame:GetParent() return self.parent end
function Frame:SetParent(parent) self.parent = parent end
function Frame:GetEffectiveScale()
    return (self.scale or 1) * (self.parent and self.parent:GetEffectiveScale() or 1)
end
function Frame:SetAlpha(alpha) self.alpha = alpha end
function Frame:GetAlpha() return self.alpha or 1 end
function Frame:GetRect()
    local scale = self:GetEffectiveScale()
    local width, height = self.width * scale, self.height * scale
    if not self.point then return self.left or 0, self.bottom or 0, width, height end
    local point, relative, relativePoint, x, y = unpack(self.point)
    local l, b, w, h = relative:GetRect()
    local function offset(p, pw, ph)
        local ox = p:find("LEFT") and 0 or (p:find("RIGHT") and pw or pw / 2)
        local oy = p:find("BOTTOM") and 0 or (p:find("TOP") and ph or ph / 2)
        return ox, oy
    end
    local rx, ry = offset(relativePoint, w, h)
    local sx, sy = offset(point, width, height)
    return l + rx + (x or 0) * scale - sx, b + ry + (y or 0) * scale - sy, width, height
end
function Frame:SetFrameStrata() end
function Frame:SetFrameLevel() end
function Frame:GetFrameLevel() return 1 end
function Frame:ClearAllPoints() self.point = nil end
function Frame:SetPoint(...) self.point = {...} end
function Frame:SetShown(shown) self.shown = shown end
function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false end
function Frame:IsShown() return self.shown end
function Frame:IsVisible()
    return self.shown and (not self.parent or self.parent:IsVisible())
end
function Frame:CreateTexture()
    local texture = {}
    function texture:SetAllPoints() end
    function texture:SetTexCoord() end
    function texture:SetTexture(value) self.value = value end
    return texture
end
function CreateFrame(_, name, parent)
    local frame = setmetatable({ events = {}, shown = true, parent = parent }, Frame)
    frames[#frames + 1] = frame
    if name then _G[name] = frame end
    return frame
end
function hooksecurefunc(object, method, callback)
    local original = object[method]
    object[method] = function(...)
        original(...)
        callback(...)
    end
end
function UnitClass() return "Warrior", "WARRIOR" end
function GetSpecialization() return 1 end
function GetSpecializationInfo() return spec end
C_SpellBook = { IsSpellInSpellBook = function(spellID)
    queries = queries + 1
    return spellID == 1269383 and proc
end }
C_Spell = { GetSpellTexture = function() return 132282 end }
local pending = {}
C_Timer = { After = function(_, callback) pending[#pending + 1] = callback end }
local function flush()
    while #pending > 0 do table.remove(pending, 1)() end
end
local addon = { db = { heroicStrike = { enabled = false } } }
function addon:RegisterFeature(feature) self.feature = feature end

local function fire(event, ...)
    for _, frame in ipairs(frames) do
        if frame.events[event] then frame.OnEvent(frame, event, ...) end
    end
end
local function loadViewer()
    BuffIconCooldownViewer = CreateFrame("Frame")
    BuffIconCooldownViewer.iconScale = 1
    BuffIconCooldownViewer:SetSize(600, 48)
    function BuffIconCooldownViewer:RefreshLayout() end
    fire("ADDON_LOADED", "Blizzard_CooldownViewer")
end

local chunk = loadfile("Features/HeroicStrike.lua")
if chunk then chunk("MathWroQOL", addon) end
assert(addon.feature, "Heroic Strike feature must register")
addon.feature:Initialize()
assert(not MathWroQOL_HeroicStrike and queries == 0, "disabled login must stay inert")

addon.db.heroicStrike.enabled = true
addon.feature:Apply()
proc = true
fire("SPELLS_CHANGED")
assert(not MathWroQOL_HeroicStrike, "missing CDM must not produce a detached icon")
loadViewer()
local icon = MathWroQOL_HeroicStrike
assert(icon and icon:IsVisible(), "late CDM loading must display an already-active proc")
assert(icon.parent == BuffIconCooldownViewer and icon.ignoreInLayout,
    "companion must follow viewer visibility without joining its native layout")

proc = false
fire("SPELLS_CHANGED")
assert(not icon:IsVisible(), "consuming Heroic Strike must hide its icon")
proc = true
fire("SPELLS_CHANGED")
assert(icon:IsVisible(), "a subsequent proc must show again")
BuffIconCooldownViewer:Hide()
assert(not icon:IsVisible(), "hidden CDM must hide the companion")
BuffIconCooldownViewer:Show()
assert(icon:IsVisible(), "showing CDM must restore a still-active proc")
BuffIconCooldownViewer.iconScale = 1.5
BuffIconCooldownViewer:RefreshLayout()
assert(icon.width == 60 and icon.height == 60, "CDM icon scaling must resize the companion")

spec = 72
fire("PLAYER_SPECIALIZATION_CHANGED", "player")
assert(not icon:IsVisible(), "leaving Arms must clear the icon even while the spell query is stale")
spec = 71
fire("PLAYER_SPECIALIZATION_CHANGED", "player")
assert(icon:IsVisible(), "returning to Arms must resynchronize an available proc")

addon.db.heroicStrike.enabled = false
addon.feature:Apply()
local before = queries
fire("SPELLS_CHANGED")
fire("PLAYER_ENTERING_WORLD")
BuffIconCooldownViewer:RefreshLayout()
assert(not icon:IsVisible() and queries == before, "disabled events/hooks must not query or revive the icon")
addon.db.heroicStrike.enabled = true
addon.feature:Apply()
assert(icon:IsVisible(), "re-enabling must restore an existing proc")

-- Ellesmere relocates native icons, leaving the Blizzard viewer's rect unrelated.
-- Docking to that rect or its iconScale reproduces the screenshot's gap/size mismatch.
local bar = CreateFrame("Frame")
bar:SetSize(300, 48)  -- Deliberately wider than its two visible icons.
bar.left, bar.bottom = 200, 100
local first = CreateFrame("Frame")
first:SetSize(48, 48)
first:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
local last = CreateFrame("Frame")
last.scale = 1.5
last:SetSize(32, 32)  -- Native scale and rendered size differ.
last:SetPoint("TOPLEFT", bar, "TOPLEFT", 50 / 1.5, 0)
local bd = { enabled = true, iconSize = 48, spacing = 2, iconShape = "none", growDirection = "CENTER" }
local eui = {
    ECME = { db = { profile = { cdmBars = { enabled = true } } } },
    barDataByKey = { buffs = bd },
    _ecmeFC = {},
    GetCDMBarFrame = function() return bar end,
    GetCDMBarIcons = function() return {first, last} end,
    EffectiveBarAlpha = function() return 0.7 end,
    ApplyShapeToCDMIcon = function() end,
    _AuraCustomPoke = function() end,
    RefreshAuraCustomStyle = function() end,
}
EllesmereUI = {
    _ModuleNS = { EllesmereUICooldownManager = eui },
    PP = { mult = 1, CreateBorder = function() end },
}
fire("ADDON_LOADED", "EllesmereUICooldownManager")
fire("PLAYER_ENTERING_WORLD")
flush()
local left, bottom, width, height = icon:GetRect()
assert(left == 300 and bottom == 100 and width == 48 and height == 48,
    "Ellesmere companion must adjoin the rendered buff row, not the native viewer or reserved bar edge")
assert(icon:GetParent() == bar and icon:GetAlpha() == 0.7, "companion must follow Ellesmere visibility and opacity")
bar:Hide()
assert(not icon:IsVisible(), "hiding Ellesmere must hide its companion")
bar:Show()

-- Deferred provider layout: the notification precedes the final icon positions.
eui._AuraCustomPoke("buffs")
last:SetSize(40, 24)
last:SetPoint("TOPLEFT", bar, "TOPLEFT", 70 / 1.5, 0)
flush()
left, bottom, width, height = icon:GetRect()
assert(left == 332 and bottom == 112 and width == 60 and height == 36,
    "companion must follow settled provider geometry, including cropped/matched icon sizes")

-- A settings-only appearance pass need not emit a layout notification.
last:SetSize(32, 32)
eui.RefreshAuraCustomStyle("buffs")
flush()
left, bottom, width, height = icon:GetRect()
assert(left == 320 and bottom == 100 and width == 48 and height == 48,
    "provider appearance changes must refresh the companion without a native layout event")

eui._ecmeFC[last] = { _cdStateShiftHidden = true }
eui._AuraCustomPoke("buffs")
flush()
left = icon:GetRect()
assert(left == 250, "shift-hidden icons must not leave a gap at the end of the visible row")
eui._ecmeFC[last] = nil
bd.growDirection = "LEFT"
eui._AuraCustomPoke("buffs")
flush()
left = icon:GetRect()
assert(left == 150, "left-growing bars must append the companion at the left edge")
bd.growDirection = "DOWN"
bd.verticalOrientation = true
last:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, -50 / 1.5)
eui._AuraCustomPoke("buffs")
flush()
left, bottom = icon:GetRect()
assert(left == 200 and bottom == 0, "vertical bars must append below their final icon")
bd.growDirection = "CENTER"
bd.verticalOrientation = false

-- An empty row retains stale bounds in Ellesmere; the companion becomes the row.
bar._acLiveW = 0
eui.GetCDMBarIcons = function() return {} end
eui._AuraCustomPoke("buffs")
flush()
left, bottom = icon:GetRect()
assert(left == 326 and bottom == 100, "empty centered buff row must center the companion, not append to stale bounds")
proc = false
fire("SPELLS_CHANGED")
eui._AuraCustomPoke("buffs")
flush()
assert(not icon:IsVisible(), "provider layout must not resurrect a consumed proc")
proc = true
fire("SPELLS_CHANGED")
assert(icon:IsVisible(), "new procs must remain visible on an empty Ellesmere row")

-- A disabled provider bar is not a reason to fall back to the misplaced native anchor.
bd.enabled = false
eui._AuraCustomPoke("buffs")
flush()
assert(not icon:IsVisible(), "disabled Ellesmere buff bar must suppress the companion")
bd.enabled = true
eui._AuraCustomPoke("buffs")
addon.db.heroicStrike.enabled = false
addon.feature:Apply()
before = queries
flush()
assert(not icon:IsVisible() and queries == before, "queued provider layout must stay inert after feature disable")

addon.db.heroicStrike.enabled = true
addon.feature:Apply()
local applyShape = eui.ApplyShapeToCDMIcon
eui.ApplyShapeToCDMIcon = nil
eui._AuraCustomPoke("buffs")
flush()
assert(not icon:IsVisible(), "missing provider styling must not fall back to a misplaced native icon")
eui.ApplyShapeToCDMIcon = applyShape
eui.ECME.db.profile.cdmBars.enabled = false
fire("PLAYER_ENTERING_WORLD")
assert(icon:IsVisible() and icon:GetParent() == BuffIconCooldownViewer and icon:GetAlpha() == 1,
    "turning off Ellesmere's CDM must restore the native companion")
print("HeroicStrike lifecycle smoke test: PASS")
