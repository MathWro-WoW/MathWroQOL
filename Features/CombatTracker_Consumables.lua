local _, addon = ...
local CT = addon.combatTracker

-- ── Known consumable item IDs ─────────────────────────────────────────────────
-- Midnight (12.x) item IDs.  Verify in-game:
--   /script local n=C_Item.GetItemInfo(ITEMID); print(n)
-- Use the options panel "Custom Items" field to add new IDs without code changes.
local CONSUMABLE_IDS = {
    combatPotions = {
        -- Fleeting versions first — prioritised when both are in bags
        245902,  -- Fleeting Potion of Recklessness (Rank 1)
        245903,  -- Fleeting Potion of Recklessness (Rank 2)
        245897,  -- Fleeting Light's Potential (Rank 1)
        245898,  -- Fleeting Light's Potential (Rank 2)
        241288,  -- Potion of Recklessness (Rank 1)
        241289,  -- Potion of Recklessness (Rank 2)
        241308,  -- Light's Potential (Rank 1)
        241309,  -- Light's Potential (Rank 2)
    },
    healingPotions = {
        241304,  -- Silvermoon Health Potion (Rank 1)
        241305,  -- Silvermoon Health Potion (Rank 2)
    },
    manaPotions = {
        -- Fleeting versions first — prioritised when both are in bags
        245916,  -- Fleeting Lightfused Mana Potion (Rank 1)
        245917,  -- Fleeting Lightfused Mana Potion (Rank 2)
        241300,  -- Lightfused Mana Potion (Rank 1)
        241301,  -- Lightfused Mana Potion (Rank 2)
    },
    healthstone = {
        224464,  -- Demonic Healthstone
        5512,    -- Healthstone (conjured item)
    },
}

-- Maps a regular potion item ID to its fleeting equivalent.
-- When both are in bags, only the fleeting version is shown.
local FLEETING_OF = {
    [241288] = 245902,  -- Potion of Recklessness R1
    [241289] = 245903,  -- Potion of Recklessness R2
    [241308] = 245897,  -- Light's Potential R1
    [241309] = 245898,  -- Light's Potential R2
    [241300] = 245916,  -- Lightfused Mana Potion R1
    [241301] = 245917,  -- Lightfused Mana Potion R2
}

-- Forever has a distinct catalog. Healthstones use the original shared cooldown;
-- Midnight's Demonic Healthstone has its own cooldown.
local HEALTHSTONE_CD_SPELLS = { [224464] = 452930, [5512] = 6262 }
if addon.isForever then
    CONSUMABLE_IDS = {
        combatPotions = {
            -- Combat Frenzy, Spellblasting, Mender's, rage, and offensive potions
            250938, 250939, 250940, 250941, 250942, 250943,
            250932, 250933, 250934, 250935, 250936, 250937,
            250944, 250945, 250946, 250947, 250948, 250949,
            5631, 5633, 13442, 250952, 250951, 250953,
        },
        healingPotions = { 287966, 118, 858, 929, 1710, 3928, 13446, 223913,
            4596, 247239, 247240, 247241, 247242, 241650 },
        manaPotions = { 2455, 3385, 3827, 6149, 13443, 13444 },
        healthstone = { 9421, 19012, 19013, 5510, 19010, 19011, 5509,
            19008, 19009, 5511, 19006, 19007, 19004, 19005 },
    }
    FLEETING_OF = {}
    for _, itemID in ipairs(CONSUMABLE_IDS.healthstone) do
        HEALTHSTONE_CD_SPELLS[itemID] = 6262
    end
end

-- Food and drink use stable effect spell IDs, rather than localized item names
-- or tooltip text. Their localized spell names extend that classification to
-- future ranks without parsing an item tooltip.
local FOOD_SPELL_IDS = { [433] = true, [434] = true, [435] = true,
    [1127] = true, [1129] = true, [1131] = true, [274911] = true }
local WATER_SPELL_IDS = { [430] = true, [431] = true, [432] = true,
    [1133] = true, [1135] = true }
local HYBRID_FOOD_WATER_SPELL_IDS = { [65422] = true, [283383] = true, [1291857] = true }
local FOOD_SPELL_NAME_IDS = { 433, 274911 }
local WATER_SPELL_NAME_IDS = { 430 }
local HYBRID_FOOD_WATER_SPELL_NAME_IDS = { 283383, 1291857 }
-- Forever's cooked buff foods use Nutritious Food rather than the plain Food effect.
local BUFF_FOOD_SPELL_IDS = { [1248378] = true, [1249513] = true }
local BUFF_FOOD_SPELL_NAME_IDS = { 1248378 }

-- Fallback icon shown when hideIfMissing=false and item is not in bags
local FALLBACK_ICON = 134400  -- classic potion flask icon

-- Builds the default display order from enabled categories + custom items.
-- Used to populate itemOrder when empty and by Config.lua to reset order.
local function buildDefaultOrder(frameDb)
    local order = {}
    if frameDb.showCombatPotions then
        for _, id in ipairs(CONSUMABLE_IDS.combatPotions) do
            table.insert(order, id)
        end
    end
    if frameDb.showHealingPotions then
        for _, id in ipairs(CONSUMABLE_IDS.healingPotions) do
            table.insert(order, id)
        end
    end
    if frameDb.showManaPotions then
        for _, id in ipairs(CONSUMABLE_IDS.manaPotions) do
            table.insert(order, id)
        end
    end
    if frameDb.showHealthstone then
        for _, id in ipairs(CONSUMABLE_IDS.healthstone) do
            table.insert(order, id)
        end
    end
    local customIDs = {}
    for id in pairs(frameDb.customItems or {}) do
        table.insert(customIDs, id)
    end
    table.sort(customIDs)
    for _, id in ipairs(customIDs) do
        table.insert(order, id)
    end
    return order
end

local consumables = {
    name           = "consumables",
    buttons        = {},
    eventFrame     = nil,
    bagScanPending = false,
    pendingItems   = {},
    -- Cached scan results: { [itemID] = { icon, count } }
    cachedItems    = {},
}

local function requestItemData(self, itemID)
    if self.pendingItems[itemID] then return end
    self.pendingItems[itemID] = true
    C_Item.RequestLoadItemDataByID(itemID)
end

local function matchesEffectSpellName(spellName, referenceSpellIDs)
    if not spellName or not C_Spell or not C_Spell.GetSpellName then return false end
    for _, spellID in ipairs(referenceSpellIDs) do
        if spellName == C_Spell.GetSpellName(spellID) then return true end
    end
    return false
end

local function getFoodWaterType(self, itemID, excludeBuffFood)
    local itemName, _, _, itemLevel, minLevel, _, _, _, _, _, _, classID, subclassID = C_Item.GetItemInfo(itemID)
    if not itemName then
        requestItemData(self, itemID)
        return nil
    end
    if classID ~= 0 or subclassID ~= 5 then return nil end

    local spellName, spellID = C_Item.GetItemSpell(itemID)
    if not spellID then return nil end
    local isHybrid = HYBRID_FOOD_WATER_SPELL_IDS[spellID] == true
        or matchesEffectSpellName(spellName, HYBRID_FOOD_WATER_SPELL_NAME_IDS)
    local isFood = isHybrid or FOOD_SPELL_IDS[spellID] == true
        or BUFF_FOOD_SPELL_IDS[spellID] == true
        or matchesEffectSpellName(spellName, FOOD_SPELL_NAME_IDS)
        or matchesEffectSpellName(spellName, BUFF_FOOD_SPELL_NAME_IDS)
    local isWater = isHybrid or WATER_SPELL_IDS[spellID] == true
        or matchesEffectSpellName(spellName, WATER_SPELL_NAME_IDS)
    if not isFood and not isWater then return nil end

    -- No buff flag exists in the item API. When requested, only allow effects
    -- verified to restore health/mana without an additional food buff.
    if excludeBuffFood and isFood
        and not FOOD_SPELL_IDS[spellID] and not HYBRID_FOOD_WATER_SPELL_IDS[spellID] then
        return nil
    end

    -- Character requirements, not temporary action usability (full health/mana,
    -- combat, or sitting state), determine which bag items belong in this display.
    if (minLevel or 0) > UnitLevel("player") or not C_PlayerInfo.CanUseItem(itemID) then return nil end
    return isFood, isWater, spellID, minLevel or 0, itemLevel or 0
end

local function isBetterCandidate(candidate, current, preference)
    if not current then return true end
    if candidate.minLevel ~= current.minLevel then
        return candidate.minLevel > current.minLevel
    end
    if preference == "quantity" and candidate.count ~= current.count then
        return candidate.count > current.count
    end
    if candidate.itemLevel ~= current.itemLevel then
        return candidate.itemLevel > current.itemLevel
    end
    return candidate.itemID < current.itemID
end

function consumables:GetIcons()
    local visible = {}
    for _, btn in ipairs(self.buttons) do
        if btn:IsShown() then table.insert(visible, btn) end
    end
    return visible
end

-- Full bag scan. Builds active item list and updates button pool.
function consumables:ScanBags()
    local db      = addon.db.combatTracker
    local frameDb = db.frames.consumables

    if not db.enabled or not frameDb.enabled then
        for _, btn in ipairs(self.buttons) do btn:Hide() end
        CT:LayoutSection(CT:GetHostKey("consumables"))
        return
    end

    -- Build lookup set of all tracked item IDs → category
    local tracked = {}
    if frameDb.showCombatPotions then
        for _, id in ipairs(CONSUMABLE_IDS.combatPotions) do
            tracked[id] = "combatPotions"
        end
    end
    if frameDb.showHealingPotions then
        for _, id in ipairs(CONSUMABLE_IDS.healingPotions) do
            tracked[id] = "healingPotions"
        end
    end
    if frameDb.showManaPotions then
        for _, id in ipairs(CONSUMABLE_IDS.manaPotions) do
            tracked[id] = "manaPotions"
        end
    end
    if frameDb.showHealthstone then
        for _, id in ipairs(CONSUMABLE_IDS.healthstone) do
            tracked[id] = "healthstone"
        end
    end
    for id in pairs(frameDb.customItems or {}) do
        tracked[id] = "custom"
    end

    -- Scan character bags only. Food and water candidates are evaluated from
    -- their item data after their stacks have been combined.
    local found = {}  -- { [itemID] = { icon, count } }
    local bagItems = (frameDb.showFood or frameDb.showWater) and {} or nil
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                local itemID = info.itemID
                local count = info.stackCount or 1
                if tracked[itemID] then
                    local existing = found[itemID]
                    if existing then
                        existing.count = existing.count + count
                    else
                        found[itemID] = { icon = info.iconFileID, count = count }
                    end
                end
                if bagItems then
                    local existing = bagItems[itemID]
                    if existing then
                        existing.count = existing.count + count
                    else
                        bagItems[itemID] = { icon = info.iconFileID, count = count }
                    end
                end
            end
        end
    end
    self.cachedItems = found

    local foodCandidate, waterCandidate
    if bagItems then
        for itemID, item in pairs(bagItems) do
            local isFood, isWater, spellID, minLevel, itemLevel = getFoodWaterType(self, itemID, frameDb.excludeBuffFood)
            local candidate = (isFood or isWater) and {
                itemID = itemID, icon = item.icon, count = item.count, spellID = spellID,
                minLevel = minLevel, itemLevel = itemLevel,
            }
            if candidate and isFood and frameDb.showFood
                and isBetterCandidate(candidate, foodCandidate, frameDb.foodWaterPreference) then
                foodCandidate = candidate
            end
            if isWater and frameDb.showWater
                and isBetterCandidate(candidate, waterCandidate, frameDb.foodWaterPreference) then
                waterCandidate = candidate
            end
        end
    end

    -- Build ordered active list using saved itemOrder (or default fallback)
    local active = {}

    local showMissing = (frameDb.hideIfMissing == false)

    local order = frameDb.itemOrder
    if not order or #order == 0 then
        order = buildDefaultOrder(frameDb)
        frameDb.itemOrder = order
    else
        --  Append any tracked IDs missing from saved order (covers addon updates
        --  that introduce new built-in IDs like Demonic Healthstone).
        local inOrder = {}
        for _, id in ipairs(order) do inOrder[id] = true end
        for id in pairs(tracked) do
            if not inOrder[id] then table.insert(order, id) end
        end
    end

    local added = {}
    for _, id in ipairs(order) do
        if tracked[id] and not added[id] then
            local fleetingID = FLEETING_OF[id]
            if fleetingID and found[fleetingID] then
                -- Fleeting version present — suppress the regular one
            elseif found[id] or showMissing then
                local f = found[id]
                if not f then
                    local _, _, _, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(id)
                    f = { icon = itemIcon or FALLBACK_ICON, count = 0 }
                end
                local _, spellID = C_Item.GetItemSpell(id)
                if tracked[id] == "healthstone" then
                    spellID = HEALTHSTONE_CD_SPELLS[id] or spellID
                end
                table.insert(active, {
                    itemID   = id,
                    icon     = f.icon,
                    count    = f.count,
                    category = tracked[id],
                    spellID  = spellID,
                })
                added[id] = true
            end
        end
    end
    local activeByItemID = {}
    for _, entry in ipairs(active) do activeByItemID[entry.itemID] = entry end
    local selectedDynamicItems = added
    if foodCandidate then
        local entry = activeByItemID[foodCandidate.itemID]
        if entry then
            entry.showSingleCount = true
        else
            entry = {
                itemID = foodCandidate.itemID, icon = foodCandidate.icon, count = foodCandidate.count,
                category = "food", spellID = foodCandidate.spellID, showSingleCount = true,
            }
            table.insert(active, entry)
            activeByItemID[entry.itemID] = entry
            selectedDynamicItems[entry.itemID] = true
        end
    end
    if waterCandidate and not selectedDynamicItems[waterCandidate.itemID] then
        table.insert(active, {
            itemID = waterCandidate.itemID, icon = waterCandidate.icon, count = waterCandidate.count,
            category = "water", spellID = waterCandidate.spellID, showSingleCount = true,
        })
    end

    -- Register any pre-existing pool buttons with Masque (if active)
    local mg = CT._masqueGroups()
    if mg and addon.db.combatTracker.masque.enabled and mg[self.name] then
        for _, btn in ipairs(self.buttons) do
            if not btn._masqueRegistered then
                CT._registerButtonMasque(mg[self.name], btn)
                btn._masqueRegistered = true
            end
        end
    end

    -- Grow pool if needed
    local hostKey = CT:GetHostKey(self.name)
    local frameW  = addon.db.combatTracker.frames[hostKey].iconWidth
    local frameH  = addon.db.combatTracker.frames[hostKey].iconHeight
    while #self.buttons < #active do
        local btn = CT.CreateButton()
        btn._sectionName = self.name
        btn:SetSize(frameW, frameH)  -- pre-size before Masque registers the button
        if mg and addon.db.combatTracker.masque.enabled and mg[self.name] then
            CT._registerButtonMasque(mg[self.name], btn)
            btn._masqueRegistered = true
        end
        table.insert(self.buttons, btn)
    end

    -- Update pool entries
    for i, btn in ipairs(self.buttons) do
        local entry = active[i]
        if entry then
            btn.icon:SetTexture(entry.icon)
            btn._itemID   = entry.itemID
            btn._category = entry.category
            btn._spellID  = entry.spellID
            if btn.countText then
                local count   = entry.count or 0
                local enabled = addon.db.combatTracker.frames.consumables.stackCountEnabled ~= false
                if enabled and (count > 1 or entry.showSingleCount) then
                    btn.countText:SetText(tostring(count))
                    btn.countText:Show()
                else
                    btn.countText:Hide()
                end
            end
            btn:Show()
        else
            btn._itemID   = nil
            btn._category = nil
            btn._spellID  = nil
            if btn.countText then btn.countText:Hide() end
            btn:Hide()
        end
    end

    CT:ApplySectionFont("consumables")
    CT:ApplyCooldownFont("consumables")
    C_Timer.After(0, function() self:UpdateCooldowns() end)
    CT:LayoutSection(CT:GetHostKey("consumables"))
end

function consumables:RebuildIcons()
    self:ScanBags()
end

-- Refreshes cooldown overlays through engine-owned duration objects.
function consumables:UpdateCooldowns()
    for _, btn in ipairs(self.buttons) do
        if btn:IsShown() and btn._itemID then
            CT.UpdateButtonCooldownFromSpell(btn, btn._spellID)
        end
    end
end

function consumables:QueueBagScan()
    if self.bagScanPending then return end
    self.bagScanPending = true
    C_Timer.After(0, function()
        self.bagScanPending = false
        self:ScanBags()
    end)
end

function consumables:Initialize()
    local self = self
    -- Ensure hideIfMissing is a boolean; nil (missing from old saves) defaults to true
    local frameDb = addon.db.combatTracker.frames.consumables
    if frameDb.hideIfMissing == nil then
        frameDb.hideIfMissing = true
    end
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("BAG_UPDATE")
    self.eventFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    self.eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
    self.eventFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
    self.eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")

    self.eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2)
        local db = addon.db.combatTracker
        local frameDb = db and db.frames and db.frames.consumables
        if not db.enabled or not frameDb.enabled then return end

        if event == "BAG_UPDATE" or event == "PLAYER_LEVEL_UP" then
            -- BAG_UPDATE and level changes can arrive before item state settles.
            self:QueueBagScan()
        elseif event == "ITEM_DATA_LOAD_RESULT" then
            local itemID, success = arg1, arg2
            if itemID and self.pendingItems[itemID] then
                self.pendingItems[itemID] = nil
                if success ~= false then self:QueueBagScan() end
            end
        elseif event == "BAG_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_COOLDOWN" then
            if not self._cdPending then
                self._cdPending = true
                C_Timer.After(0, function()
                    self._cdPending = false
                    self:UpdateCooldowns()
                end)
            end
        end
    end)
end

consumables.BuildDefaultOrder = buildDefaultOrder
consumables.CONSUMABLE_IDS    = CONSUMABLE_IDS
consumables.FLEETING_OF       = FLEETING_OF

CT:RegisterSection(consumables)
