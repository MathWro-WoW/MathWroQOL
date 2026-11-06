-- Developer-only smoke test for bag-selected food and water tracker icons.
-- This file is outside MathWroQOL.toc and is never loaded by the addon.

local section
local bags = {}
local items = {}
local requested = {}
local timers = {}
local eventFrame
local playerLevel = 30

local function defineItem(itemID, spellID, minLevel, itemLevel, usable, cached, spellName)
    items[itemID] = {
        spellID = spellID,
        spellName = spellName,
        minLevel = minLevel,
        itemLevel = itemLevel,
        usable = usable ~= false,
        cached = cached ~= false,
    }
end

local function setBags(...)
    bags = { ... }
end

C_Container = {
    GetContainerNumSlots = function(bag)
        return bags[bag + 1] and #bags[bag + 1] or 0
    end,
    GetContainerItemInfo = function(bag, slot)
        return bags[bag + 1] and bags[bag + 1][slot] or nil
    end,
}

C_Item = {
    GetItemInfo = function(itemID)
        local item = items[itemID]
        if not item or not item.cached then return nil end
        return "Item " .. itemID, nil, nil, item.itemLevel, item.minLevel, nil, nil, nil,
            nil, 100000 + itemID, nil, 0, 5
    end,
    GetItemSpell = function(itemID)
        local item = items[itemID]
        if not item or not item.cached then return nil end
        return item.spellName or ("Spell " .. item.spellID), item.spellID
    end,
    IsUsableItem = function(itemID)
        local item = items[itemID]
        return item and item.usable or false, false
    end,
    RequestLoadItemDataByID = function(itemID)
        requested[itemID] = (requested[itemID] or 0) + 1
    end,
}

C_PlayerInfo = {
    CanUseItem = function(itemID)
        local item = items[itemID]
        return item and item.usable or false
    end,
}

ITEM_CONJURED = "Herbeigezaubert"
C_TooltipInfo = {
    GetItemByID = function(itemID)
        local item = items[itemID]
        if not item or not item.cached or item.tooltipMissing then return nil end
        local lines = { { leftText = "Item " .. itemID } }
        if item.conjured then lines[#lines + 1] = { leftText = ITEM_CONJURED } end
        return { lines = lines }
    end,
}

C_Spell = {
    GetSpellName = function(spellID)
        if spellID == 433 or spellID == 274911 or spellID == 65422 then return "Food" end
        if spellID == 430 then return "Drink" end
        if spellID == 283383 then return "Eat" end
        if spellID == 1291857 then return "Food & Drink" end
        if spellID == 1248378 then return "Nahrhafte Nahrung" end
    end,
}

function UnitLevel(unit)
    assert(unit == "player")
    return playerLevel
end

C_Timer = {
    After = function(_, callback)
        timers[#timers + 1] = callback
    end,
}

local function flushTimers()
    while #timers > 0 do
        local pending = timers
        timers = {}
        for _, callback in ipairs(pending) do callback() end
    end
end

function CreateFrame()
    local frame = { events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetScript(_, handler) self.onEvent = handler end
    eventFrame = frame
    return frame
end

local CT = {}
function CT:RegisterSection(def) section = def end
function CT:GetHostKey(key) return key end
function CT:ApplySectionFont() end
function CT:ApplyCooldownFont() end
function CT:LayoutSection() end
function CT.UpdateButtonCooldownFromSpell() end
function CT._masqueGroups() return nil end
function CT:CreateButton()
    local button = { cooldown = {}, countText = {} }
    button.icon = { SetTexture = function(_, texture) button.texture = texture end }
    function button.countText:SetText(text) button.count = text end
    function button.countText:Show() button.countShown = true end
    function button.countText:Hide() button.countShown = false end
    function button:SetSize() end
    function button:Show() self.shown = true end
    function button:Hide() self.shown = false end
    function button:IsShown() return self.shown == true end
    return button
end

local addon = {
    combatTracker = CT,
    db = {
        combatTracker = {
            enabled = true,
            masque = { enabled = false },
            frames = {
                consumables = {
                    enabled = true,
                    hideIfMissing = false,
                    showCombatPotions = false,
                    showHealingPotions = false,
                    showManaPotions = false,
                    showHealthstone = false,
                    showFood = true,
                    showWater = true,
                    customItems = {},
                    itemOrder = {},
                    iconWidth = 36,
                    iconHeight = 36,
                    stackCountEnabled = true,
                },
            },
        },
    },
}

assert(loadfile("Features/CombatTracker_Consumables.lua"))("MathWroQOL", addon)
assert(section, "consumables section did not register")

-- Food spell ranks, drink spell ranks, and the health-and-mana Food spell use
-- stable spell IDs, rather than localized item names or tooltip text.
defineItem(100, 433, 20, 30)       -- food, lower required level
defineItem(101, 434, 30, 25)       -- food, selected over 100
-- Same level: higher item level wins; same item level: lowest item ID wins.
defineItem(102, 435, 30, 50)
defineItem(103, 900003, 30, 50, true, true, "Food")  -- future Food rank
defineItem(200, 430, 30, 60)       -- water; must not displace food
-- Current Food & Drink effect can satisfy both toggles, but remains one icon.
defineItem(300, 1291857, 30, 70)
-- A food-class item with an unrelated use spell must not be shown.
defineItem(400, 900000, 30, 999)
-- A level-locked and an otherwise unusable food must not replace the usable best item.
defineItem(500, 1129, 31, 999)
defineItem(600, 1129, 30, 999, false)
setBags(
    {
        { itemID = 100, iconFileID = 100100, stackCount = 2 },
        { itemID = 102, iconFileID = 100102, stackCount = 3 },
        { itemID = 103, iconFileID = 100103, stackCount = 4 },
        { itemID = 200, iconFileID = 100200, stackCount = 1 },
        { itemID = 300, iconFileID = 100300, stackCount = 5 },
        { itemID = 400, iconFileID = 100400, stackCount = 9 },
        { itemID = 500, iconFileID = 100500, stackCount = 9 },
        { itemID = 600, iconFileID = 100600, stackCount = 9 },
    },
    {
        { itemID = 102, iconFileID = 100102, stackCount = 7 },
        { itemID = 200, iconFileID = 100200, stackCount = 2 },
    }
)
section:ScanBags()
assert(#section.buttons == 1 and section.buttons[1]._itemID == 300,
    "the highest eligible hybrid must satisfy both categories with one icon")
assert(section.buttons[1]:IsShown(), "a hybrid food and water selection must render")
assert(section.buttons[1].count == "5" and section.buttons[1].countShown,
    "food and water stack counts must include one-stack-capable count rendering")

-- Removing the hybrid makes food select by required level, item level, then item ID.
setBags(
    {
        { itemID = 100, iconFileID = 100100, stackCount = 2 },
        { itemID = 102, iconFileID = 100102, stackCount = 3 },
        { itemID = 103, iconFileID = 100103, stackCount = 4 },
        { itemID = 200, iconFileID = 100200, stackCount = 1 },
    },
    {
        { itemID = 102, iconFileID = 100102, stackCount = 7 },
        { itemID = 200, iconFileID = 100200, stackCount = 2 },
    }
)
section:ScanBags()
assert(section.buttons[1]._itemID == 102 and section.buttons[1].count == "10",
    "food selection must sum matching bag stacks and break equal item-level ties by item ID")
assert(section.buttons[2]._itemID == 200 and section.buttons[2].count == "3",
    "water selection must sum matching bag stacks")

addon.db.combatTracker.frames.consumables.stackCountEnabled = false
section:ScanBags()
assert(not section.buttons[1].countShown and not section.buttons[2].countShown,
    "the stack-count setting must hide food and water counts")
addon.db.combatTracker.frames.consumables.stackCountEnabled = true

-- Depleting the best food falls back to the remaining eligible food, never a missing icon.
setBags({ { itemID = 100, iconFileID = 100100, stackCount = 1 } })
section:ScanBags()
assert(section.buttons[1]._itemID == 100 and section.buttons[1].count == "1" and section.buttons[1].countShown,
    "depleting the selected food must choose the next usable bag food and show one")
assert(not section.buttons[2]:IsShown(), "food/water icons must disappear when their bag match is absent")

addon.db.combatTracker.frames.consumables.showFood = false
section:ScanBags()
assert(not section.buttons[1]:IsShown(), "disabled food tracking must show no food icon")
addon.db.combatTracker.frames.consumables.showFood = true
local consumablesFrameDb = addon.db.combatTracker.frames.consumables
consumablesFrameDb.customItems = { [100] = true }
consumablesFrameDb.itemOrder = { 100 }
section:ScanBags()
assert(section.buttons[1]._category == "custom" and section.buttons[1].countShown,
    "a selected food also tracked as custom must still show its one-item count")
consumablesFrameDb.customItems = {}
consumablesFrameDb.itemOrder = {}

-- Uncached food is requested once and becomes eligible through ITEM_DATA_LOAD_RESULT.
defineItem(700, 1129, 30, 70, true, false)
setBags({ { itemID = 700, iconFileID = 100700, stackCount = 6 } })
section:Initialize()
section:ScanBags()
assert(requested[700] == 1 and not section.buttons[1]:IsShown(),
    "uncached bag food must request data and remain hidden until data is available")
items[700].cached = true
eventFrame:onEvent("ITEM_DATA_LOAD_RESULT", 700, true)
flushTimers()
assert(section.buttons[1]._itemID == 700 and section.buttons[1].count == "6",
    "item-data completion must refresh the selected food without polling")

-- Level changes must reevaluate selection, including candidates previously too high.
defineItem(701, 1129, 31, 80)
setBags({ { itemID = 700, iconFileID = 100700, stackCount = 6 }, { itemID = 701, iconFileID = 100701, stackCount = 2 } })
playerLevel = 30
section:ScanBags()
assert(section.buttons[1]._itemID == 700, "items above the player level must not be selected")
playerLevel = 31
eventFrame:onEvent("PLAYER_LEVEL_UP")
flushTimers()
assert(section.buttons[1]._itemID == 701, "level-up must refresh to the highest newly usable food")

-- Inventory display must not depend on temporary eating/drinking usability.
local policyDb = addon.db.combatTracker.frames.consumables
policyDb.excludeBuffFood = true
policyDb.foodWaterPreference = "quantity"
defineItem(2070, 433, 1, 5)
defineItem(961, 433, 0, 5)
defineItem(159, 430, 1, 5)
local originalIsUsableItem = C_Item.IsUsableItem
C_Item.IsUsableItem = function() return false, false end
setBags({
    { itemID = 2070, stackCount = 2, iconFileID = 132354 },
    { itemID = 961, stackCount = 8, iconFileID = 134181 },
    { itemID = 159, stackCount = 4, iconFileID = 132794 },
}, { { itemID = 2070, stackCount = 3, iconFileID = 132354 } })
section:ScanBags()
assert(section.buttons[1]:IsShown() and section.buttons[1]._itemID == 2070
    and section.buttons[1].count == "5" and section.buttons[2]._itemID == 159,
    "food and water must remain visible when temporarily unusable, including with buff exclusion enabled")
setBags({ { itemID = 961, stackCount = 8, iconFileID = 134181 } })
section:ScanBags()
assert(section.buttons[1]:IsShown() and section.buttons[1]._itemID == 961
    and section.buttons[1].count == "8",
    "Healing Herb must remain an eligible plain-food fallback")
C_Item.IsUsableItem = originalIsUsableItem
policyDb.excludeBuffFood = false
policyDb.foodWaterPreference = "itemLevel"

-- Quantity preference uses total bag counts only after required level matches.
local selectionDb = addon.db.combatTracker.frames.consumables
defineItem(800, 435, 31, 80)
defineItem(801, 435, 31, 70)
defineItem(802, 435, 30, 99)
defineItem(810, 430, 31, 80)
defineItem(811, 430, 31, 70)
setBags({
    { itemID = 800, stackCount = 2 },
    { itemID = 801, stackCount = 3 },
    { itemID = 802, stackCount = 100 },
    { itemID = 810, stackCount = 6 },
    { itemID = 811, stackCount = 4 },
}, {
    { itemID = 801, stackCount = 17 },
    { itemID = 811, stackCount = 8 },
})
section:ScanBags()
assert(section.buttons[1]._itemID == 800 and section.buttons[2]._itemID == 810,
    "existing selection must prefer item level when no quantity preference is saved")
selectionDb.foodWaterPreference = "quantity"
section:ScanBags()
assert(section.buttons[1]._itemID == 801 and section.buttons[1].count == "20"
    and section.buttons[2]._itemID == 811 and section.buttons[2].count == "12",
    "same-level quantity preference must sum all stacks for both food and water, without preferring lower-level food")
bags[1][1].stackCount = 20
eventFrame:onEvent("BAG_UPDATE")
flushTimers()
assert(section.buttons[1]._itemID == 800,
    "equal quantities must fall back to item level on a bag refresh")
selectionDb.foodWaterPreference = "itemLevel"

-- Forever's Nutritious Food grants a buff; identify its localized effect, not an item name.
defineItem(2680, 1248378, 31, 90, true, true, "Nahrhafte Nahrung")
setBags({ { itemID = 800, stackCount = 2 }, { itemID = 2680, stackCount = 10 },
    { itemID = 810, stackCount = 6 } })
section:ScanBags()
assert(section.buttons[1]._itemID == 2680,
    "buff-granting food must remain eligible when exclusion is off")
selectionDb.excludeBuffFood = true
section:ScanBags()
assert(section.buttons[1]._itemID == 800 and section.buttons[2]._itemID == 810,
    "buff exclusion must retain plain restoration food and water")

-- Unknown effects cannot safely be called restoration-only, including hybrid effects.
defineItem(899, 900899, 31, 100, true, true, "Food & Drink")
setBags({ { itemID = 899, stackCount = 100 }, { itemID = 800, stackCount = 2 },
    { itemID = 810, stackCount = 6 } })
section:ScanBags()
assert(section.buttons[1]._itemID == 800 and section.buttons[2]._itemID == 810,
    "an unverified hybrid must not bypass buff exclusion through the water selection")
selectionDb.excludeBuffFood = false
section:ScanBags()
assert(section.buttons[1]._itemID == 899 and not section.buttons[2]:IsShown(),
    "turning exclusion off must restore normal hybrid recognition and de-duplication")
selectionDb.excludeBuffFood = true
setBags({ { itemID = 2680, stackCount = 10 } })
section:ScanBags()
assert(not section.buttons[1]:IsShown() and not section.buttons[2]:IsShown(),
    "an all-buff-food bag must show no automatic food icon rather than a missing-item fallback")
selectionDb.excludeBuffFood = false

-- Opt-in mage priority outranks level/quantity, but never character requirements.
defineItem(1113, 433, 1, 5)
defineItem(5350, 430, 1, 5)
items[1113].conjured, items[5350].conjured = true, true
setBags({
    { itemID = 1113, stackCount = 1 }, { itemID = 5350, stackCount = 2 },
    { itemID = 800, stackCount = 40 }, { itemID = 810, stackCount = 40 },
})
selectionDb.foodWaterPreference = "quantity"
section:ScanBags()
assert(section.buttons[1]._itemID == 800 and section.buttons[2]._itemID == 810,
    "without mage priority, higher-level ordinary food and water must still win")
selectionDb.preferMageFood = true
section:ScanBags()
assert(section.buttons[1]._itemID == 1113 and section.buttons[1].count == "1"
    and section.buttons[2]._itemID == 5350 and section.buttons[2].count == "2",
    "mage priority must prefer eligible conjured food and water over higher-level, more plentiful ordinary items")

defineItem(1114, 434, 1, 10)
items[1114].conjured = true
bags[1][#bags[1] + 1] = { itemID = 1114, stackCount = 3 }
section:ScanBags()
assert(section.buttons[1]._itemID == 1114,
    "normal same-level preference must still choose among mage foods")
bags[1][1].stackCount = 8
section:ScanBags()
assert(section.buttons[1]._itemID == 1113,
    "quantity preference must rank mage foods by count rather than item level")
selectionDb.foodWaterPreference = "itemLevel"
section:ScanBags()
assert(section.buttons[1]._itemID == 1114,
    "item-level preference must still rank mage foods by item level")
items[1114].minLevel = 32
items[1113].usable = false
section:ScanBags()
assert(section.buttons[1]._itemID == 800 and section.buttons[2]._itemID == 5350,
    "unusable mage food must fall back to eligible ordinary food without losing mage water")

-- A mage refreshment can satisfy both categories without creating duplicate icons.
defineItem(113509, 1291857, 20, 30)
items[113509].conjured = true
setBags({
    { itemID = 113509, stackCount = 2 },
    { itemID = 800, stackCount = 40 }, { itemID = 810, stackCount = 40 },
}, { { itemID = 113509, stackCount = 4 } })
selectionDb.excludeBuffFood = true
section:ScanBags()
assert(section.buttons[1]._itemID == 113509 and section.buttons[1].count == "6"
    and not section.buttons[2]:IsShown(),
    "mage food/water hybrids must sum stacks, remain one icon, and work with buff exclusion")
items[113509].tooltipMissing = true
section:ScanBags()
assert(section.buttons[1]._itemID == 800 and section.buttons[2]._itemID == 810,
    "missing conjured tooltip metadata must leave normal selection available")
items[113509].tooltipMissing = false
items[113509].spellID, items[113509].spellName = 1248378, "Nahrhafte Nahrung"
section:ScanBags()
assert(section.buttons[1]._itemID == 800 and section.buttons[2]._itemID == 810,
    "mage priority must not bypass buff-food exclusion")
items[113509].spellID, items[113509].spellName = 1291857, nil
selectionDb.preferMageFood = false
section:ScanBags()
assert(section.buttons[1]._itemID == 800 and section.buttons[2]._itemID == 810,
    "turning mage priority off must restore normal food/water ranking")
selectionDb.excludeBuffFood = false
selectionDb.foodWaterPreference = "itemLevel"

-- Forever uses a separate verified catalog and retains item-spell cooldowns.
addon.isForever = true
assert(loadfile("Features/CombatTracker_Consumables.lua"))("MathWroQOL", addon)
local frameDb = addon.db.combatTracker.frames.consumables
frameDb.showFood = false
frameDb.showWater = false
frameDb.showCombatPotions = true
frameDb.showHealingPotions = false
frameDb.showManaPotions = false
frameDb.showHealthstone = false
frameDb.hideIfMissing = true
frameDb.itemOrder = {}
defineItem(250938, 910001, 1, 1)
setBags({ { itemID = 250938, iconFileID = 350938, stackCount = 2 } })
section:ScanBags()
assert(section.buttons[1] and section.buttons[1]._itemID == 250938 and section.buttons[1]._spellID == 910001,
    "Forever combat potions must use their verified catalog and item spell")

frameDb.showCombatPotions = false
frameDb.showHealthstone = true
frameDb.itemOrder = {}
defineItem(9421, 910002, 1, 1)
setBags({ { itemID = 9421, iconFileID = 309421, stackCount = 1 } })
section:ScanBags()
assert(section.buttons[1] and section.buttons[1]._itemID == 9421 and section.buttons[1]._spellID == 6262,
    "Forever Healthstone ranks must use the shared Healthstone cooldown")

print("CombatTracker consumables food/water smoke test: PASS")
