local H = dofile("tests/SettingsHarness.lua")
for _, interface in ipairs({ 120100, 16001 }) do
    local addon = H.load(interface, "Config/CombatTracker.lua")
    local tracker = H.catalogs()
    local frame = addon.db.combatTracker.frames.consumables
    local section = tracker.sections.consumables
    local combatID, healingID = section.CONSUMABLE_IDS.combatPotions[1], section.CONSUMABLE_IDS.healingPotions[1]
    frame.customItems[900001] = true
    frame.itemOrder = { 900001, healingID, combatID }
    local saved = H.snapshot(addon.db)
    local page = addon.SettingsUI.BuildCombatTracker({})
    H.open(page)
    H.options("combatTracker_frames_consumables_selectedItem")
    assert(H.snapshot(addon.db) == saved and #H.notified == 0 and #H.itemRequests == 0,
        "opening the menu must not rewrite item order, add defaults, or scan inventory")
    H.set("combatTracker_frames_consumables_hideIfMissing", false)
    assert(frame.hideIfMissing, "disabled tracker controls must preserve their saved values")
    H.set("combatTracker_enabled", true)
    H.set("combatTracker_frames_consumables_selectedItem", healingID)
    H.click("Move Up")
    assert(frame.itemOrder[1] == healingID and frame.itemOrder[2] == 900001 and frame.itemOrder[3] == combatID)
    H.click("Move Down")
    assert(frame.itemOrder[1] == 900001 and frame.itemOrder[2] == healingID)
    H.set("combatTracker_frames_consumables_selectedItem", combatID)
    H.click("Remove")
    assert(frame.itemOrder[3] == combatID, "catalog items must not be removable as custom items")
    H.set("combatTracker_frames_consumables_selectedItem", 900001)
    H.click("Remove")
    assert(not frame.customItems[900001] and frame.itemOrder[1] == healingID
        and H.get("combatTracker_frames_consumables_selectedItem") == 0)
    H.click("Add")
    H.input("12.5")
    assert(H.popup and not frame.customItems[12.5], "invalid item IDs must leave an editable dialog")
    H.input("900002")
    H.click("Add")
    H.input("900002")
    local count = 0
    for _, id in ipairs(frame.itemOrder) do if id == 900002 then count = count + 1 end end
    assert(frame.customItems[900002] and count == 1, "adding an existing custom item must not duplicate its display order")
    H.set("combatTracker_frames_consumables_showCombatPotions", false)
    for _, id in ipairs(frame.itemOrder) do assert(id ~= combatID, "disabling a category must remove its tracked entries") end
    assert(frame.customItems[900002], "category changes must retain explicit custom items")
    H.set("combatTracker_frames_consumables_showCombatPotions", true)
    H.click("Reset Order")
    assert(H.snapshot(frame.itemOrder) == H.snapshot(section.BuildDefaultOrder(frame)), "reset must restore the real client-specific catalog order")
    H.set("combatTracker_frames_consumables_foodWaterPreference", "quantity")
    assert(frame.foodWaterPreference == "quantity" and H.notified[#H.notified] == "combatTracker")

    H.set("combatTracker_frames_consumables_layout", "grid")
    H.set("combatTracker_frames_consumables_gridCols", 3)
    assert(H.setting("combatTracker_frames_consumables_gridCols").row.shown)
    H.set("combatTracker_frames_consumables_mergeInto", "trinkets")
    assert(not H.setting("combatTracker_frames_consumables_layout").row.shown)
    H.set("combatTracker_frames_consumables_gridCols", 4)
    assert(frame.gridCols == 3, "merged sections must keep their standalone layout preferences")
    H.set("combatTracker_frames_consumables_mergeInto", "none")
    assert(frame.mergeInto == nil and H.setting("combatTracker_frames_consumables_gridCols").row.shown)

    H.click("Edit Exclusions")
    H.input("321, invalid")
    assert(H.popup and not next(addon.db.combatTracker.frames.trinkets.excludedItems))
    H.input("321, 456, 321")
    local excluded = addon.db.combatTracker.frames.trinkets.excludedItems
    assert(excluded[321] and excluded[456])
    H.click("Edit Exclusions")
    H.input("")
    assert(not next(addon.db.combatTracker.frames.trinkets.excludedItems), "an empty exclusion dialog must clear exclusions")
    H.set("combatTracker_racials_hiddenSpells_Stoneform", false)
    H.set("combatTracker_racials_hiddenSpells_Fireblood", false)
    H.set("combatTracker_racials_hiddenSpells_Stoneform", true)
    assert(not addon.db.combatTracker.racials.hiddenSpells.Stoneform and addon.db.combatTracker.racials.hiddenSpells.Fireblood)

    local macros = 0
    function tracker:CreateFoodWaterMacros()
        assert(self == tracker)
        macros = macros + 1
        return true, "Created food and water macros."
    end
    H.inCombat = true
    H.fire("PLAYER_REGEN_DISABLED")
    H.flush()
    H.set("combatTracker_frames_consumables_clickableFoodWater", true)
    H.set("combatTracker_frames_foodWater_enabled", true)
    H.button("Create Smart Macro").data.buttonClick()
    assert(not frame.clickableFoodWater and not addon.db.combatTracker.frames.foodWater.enabled and macros == 0,
        "secure food/water actions must reject combat writes and direct clicks")
    H.inCombat = false
    H.fire("PLAYER_REGEN_ENABLED")
    H.set("combatTracker_frames_consumables_clickableFoodWater", true)
    H.set("combatTracker_frames_foodWater_enabled", true)
    H.click("Create Smart Macro")
    assert(frame.clickableFoodWater and addon.db.combatTracker.frames.foodWater.enabled and macros == 1)
    local status
    for _, row in ipairs(page.layout.rows) do if row.displayedText == "Created food and water macros." then status = true end end
    assert(status, "macro action feedback must remain visible in the menu")
end
print("Config Combat Tracker smoke PASS: client catalogs, ordering, exclusions, merging, and secure food/water actions")
