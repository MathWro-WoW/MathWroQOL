-- Developer-only: Forever must expose its verified buff/racial catalogue and match rank auras.
local frames, containers, auraSounds = {}, {}, {}

local methods = {}
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:SetPoint(...) self.point = { ... } end
function methods:ClearAllPoints() self.point = nil end
function methods:SetFrameStrata(strata) self.strata = strata end
function methods:SetFrameLevel(level) self.level = level end
function methods:SetClampedToScreen() end
function methods:SetAllPoints() end
function methods:SetMouseMotionEnabled() end
function methods:SetMouseClickEnabled() end
function methods:SetDrawEdge() end
function methods:SetHideCountdownNumbers() end
function methods:SetEnabled(enabled) self.enabled = enabled end
function methods:SetUnit(unit) self.unit = unit end
function methods:SetShown(shown) self.shown = shown end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:UnregisterEvent(event) self.events[event] = nil end
function methods:UnregisterAllEvents() self.events = {} end
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:CreateTexture()
    return setmetatable({ SetAllPoints = function() end, SetTexCoord = function() end, SetTexture = function() end }, { __index = methods })
end
function methods:CreateFontString() return setmetatable({ SetPoint = function() end }, { __index = methods }) end
function methods:SetFont(path, size, flags)
    self.fontPath, self.fontSize, self.fontFlags = path, size, flags
end
function methods:GetFrameLevel() return 1 end
function methods:SetIcon(icon) self.icon = icon end
function methods:SetDurationCooldown(cooldown) self.cooldown = cooldown end
function methods:SetDurationText(text) self.durationText = text end
function methods:AddAuraSlot(key, _, options)
    local button = CreateFrame("AuraButton", nil, self)
    self.slots[key] = { button = button, candidates = {}, options = options }
    options.initializeFrame(button)
end
function methods:SetAuraSlotCandidateFilters(key, candidates) self.slots[key].candidates = candidates end

function CreateFrame(kind, _, parent)
    local frame = setmetatable({ kind = kind, parent = parent, slots = {}, scripts = {}, events = {} }, { __index = methods })
    frames[#frames + 1] = frame
    if kind == "AuraContainer" then containers[#containers + 1] = frame end
    return frame
end

UIParent = {}
C_AddOns = { IsAddOnLoaded = function() return true end }
C_Spell = {
    GetSpellInfo = function(id) return { iconID = id } end,
    GetSpellTexture = function(id) return 100000 + id end,
}
C_UnitAuras = {
    AddAuraSound = function(_, info)
        auraSounds[info.spellID] = info
        return info.spellID
    end,
    RemoveAuraSound = function(id) auraSounds[id] = nil end,
}
local knownSpells = { [1259705] = true }
local raceKey = "Skyborne"
C_SpellBook = { IsSpellKnown = function(id) return knownSpells[id] == true end }
C_Timer = { After = function(_, callback) callback() end }
Enum = { UnitAuraSoundTrigger = { Added = 0 } }
function InCombatLockdown() return false end
function UnitRace(unit)
    assert(unit == "player")
    return raceKey, raceKey
end

local media = { Fetch = function() return "Interface\\AddOns\\Sounds\\Bell.ogg" end, RegisterCallback = function() end,
    UnregisterCallback = function() end }
LibStub = function(name)
    if name == "LibSharedMedia-3.0" then return media end
end

local CT = {}
function CT:RegisterSection(section) self.racials = section end
function CT:GetHostKey(key) return key end
function CT:CreateButton()
    local button = { icon = { SetTexture = function(self, texture) self.texture = texture end } }
    function button:SetSize() end
    function button:Show() self.shown = true end
    function button:Hide() self.shown = false end
    function button:IsShown() return self.shown == true end
    return button
end
function CT:ApplySectionFont() end
function CT:ApplyCooldownFont() end
function CT:LayoutSection() end
function CT:UpdateButtonCooldownFromSpell() end
function CT._masqueGroups() return nil end

local addon = {
    isForever = true,
    combatTracker = CT,
    db = {
        externalTracker = {
            enabled = true, point = "CENTER", x = 0, y = 0, iconSize = 40, iconZoom = 8, glowType = "none",
            spells = {
                [1022] = { enabled = true, mode = "both", sound = "Bell" },
                [1044] = { enabled = true, mode = "icon", sound = "Bell" },
                [33206] = { enabled = true, mode = "both", sound = "Bell" },
            },
        },
        combatTracker = {
            enabled = true, masque = { enabled = false }, racials = { hiddenSpells = {} },
            frames = { racials = { enabled = true, iconWidth = 36, iconHeight = 36 } },
        },
    },
}
function addon:ApplyIconGlow() end
function addon:RegisterFeature(feature) self.features = self.features or {}; self.features[feature.name] = feature end

assert(loadfile("Features/ExternalTracker.lua"))("MathWroQOL", addon)
addon.features.externalTracker:Initialize()
local slot = assert(containers[1].slots["1022"], "Forever Blessing of Protection must create one aura slot")
assert(slot.candidates.includeSpellIDs[1022] and slot.candidates.includeSpellIDs[5599] and slot.candidates.includeSpellIDs[10278],
    "Forever Blessing of Protection must match every verified aura rank")
assert(auraSounds[1022] and auraSounds[5599] and auraSounds[10278],
    "Forever external sound alerts must match every verified aura rank")
assert(not containers[1].slots["33206"] and not auraSounds[33206],
    "Forever must not create icons or sounds for unsupported Retail external buffs")
local freedomSlot = assert(containers[1].slots["1044"], "Forever Blessing of Freedom must create an aura slot")
assert(freedomSlot.candidates.includeSpellIDs[1044], "Forever Blessing of Freedom must match its buff aura")
addon.db.externalTracker.spells[1022].enabled = false
addon.features.externalTracker:Apply()
assert(not next(slot.candidates.includeSpellIDs) and not auraSounds[1022] and not auraSounds[5599] and not auraSounds[10278],
    "disabling Blessing of Protection must clear every rank candidate and sound")

assert(loadfile("Features/CombatTracker_Racials.lua"))("MathWroQOL", addon)
local function assertRacial(race, spellID)
    raceKey, knownSpells = race, { [spellID] = true }
    CT.racials:RebuildIcons()
    local button = CT.racials.buttons[1]
    assert(#CT.racials.buttons == 1 and button._spellID == spellID and button.icon.texture == 100000 + spellID,
        "Forever " .. race .. " must render its verified racial")
end

assertRacial("Skyborne", 1259705)
assertRacial("Human", 1259718)
assertRacial("NightElf", 20580)
assertRacial("Troll", 20554)

print("Forever catalog smoke test: PASS")
