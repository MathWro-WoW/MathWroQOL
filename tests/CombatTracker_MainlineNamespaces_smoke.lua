-- Developer-only smoke test for Mainline-only CombatTracker namespaces.
-- This file is outside MathWroQOL.toc and is never loaded by the addon.

C_SpellBook = {
    IsSpellKnown = function(spellID)
        return spellID == 33697
    end,
}

C_Spell = {
    GetSpellTexture = function(spellID)
        return 200000 + spellID
    end,
}

C_Item = {
    GetItemSpell = function(itemID)
        return "Use", itemID + 1
    end,
    GetItemInfo = function(itemID)
        return nil, nil, nil, nil, nil, nil, nil, nil, nil, 300000 + itemID
    end,
}

C_Container = {
    GetContainerNumSlots = function()
        return 0
    end,
    GetContainerItemInfo = function()
        return nil
    end,
}

C_Timer = {
    After = function(_, callback)
        callback()
    end,
}

function UnitRace(unit)
    assert(unit == "player")
    return "Orc", "Orc"
end

local CT = {}

function CT:RegisterSection(def)
    if def.name == "racials" then
        self.racials = def
    else
        self.consumables = def
    end
end

function CT:GetHostKey(key)
    return key
end

function CT:CreateButton()
    local button = {
        icon = { SetTexture = function(self, texture) self.texture = texture end },
        countText = {
            SetText = function(self, text) self.text = text end,
            Show = function(self) self.shown = true end,
            Hide = function(self) self.shown = false end,
        },
    }
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
    combatTracker = CT,
    db = {
        combatTracker = {
            enabled = true,
            masque = { enabled = false },
            racials = { hiddenSpells = {} },
            frames = {
                racials = { enabled = true, iconWidth = 36, iconHeight = 36 },
                consumables = {
                    enabled = true,
                    iconWidth = 36,
                    iconHeight = 36,
                    showCombatPotions = false,
                    showHealingPotions = false,
                    showManaPotions = false,
                    showHealthstone = false,
                    hideIfMissing = false,
                    customItems = { [9001] = true },
                },
            },
        },
    },
}

assert(loadfile("Features/CombatTracker_Racials.lua"))("MathWroQOL", addon)
CT.racials:RebuildIcons()
assert(#CT.racials.buttons == 1 and CT.racials.buttons[1]._spellID == 33697,
    "racial tracker must filter unknown variants using C_SpellBook.IsSpellKnown")

addon.db.combatTracker.racials.hiddenSpells["Blood Fury"] = true
CT.racials:RebuildIcons()
assert(not CT.racials.buttons[1]:IsShown(),
    "hidden racial names must suppress their known spell variant")

assert(loadfile("Features/CombatTracker_Consumables.lua"))("MathWroQOL", addon)

CT.consumables:ScanBags()
assert(#CT.consumables.buttons == 1 and CT.consumables.buttons[1]._itemID == 9001,
    "configured missing consumables must remain visible")

print("CombatTracker Mainline namespace smoke test: PASS")
