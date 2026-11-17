-- Native Settings behavior on both supported clients.
local H = dofile("tests/SettingsHarness.lua")

for _, interface in ipairs({ 120100, 16001 }) do
    local addon = H.load(interface)
    local tracker = H.catalogs()
    local names = tracker.sections.racials._allRacialNames
    tracker.sections.racials._allRacialNames = nil
    local resets = 0
    addon:RegisterFeature({ name = "gameMenu", ResetPosition = function() resets = resets + 1 end })
    addon:RegisterFeature({ name = "racialCatalog", Initialize = function()
        tracker.sections.racials._allRacialNames = names
    end })
    addon.db.gameMenu.scale = 1.35
    addon.db.cdmButton.slashCM = true
    addon.db.heroicStrike.enabled = true
    addon.db.folioEquipmentSets.enabled = true
    local saved = H.snapshot(addon.db)
    for _, file in ipairs({ "CombatTracker", "ExternalTracker", "Integrations" }) do
        assert(loadfile("Config/" .. file .. ".lua"))("MathWroQOL", addon)
    end
    assert(loadfile("Config.lua"))("MathWroQOL", addon)
    H.fire("PLAYER_LOGIN")
    H.flush()
    assert(H.snapshot(addon.db) == saved and #H.notified == 0 and #H.itemRequests == 0,
        "registering every page must preserve saved preferences without applying features or scanning items")
    SlashCmdList.MQOL()
    local general
    for _, category in ipairs(H.categories) do
        if category:GetID() == H.openedCategoryID then general = { category = category } end
    end
    assert(general and general.category:GetName() == "General", "/mqol must open usable General settings")
    H.open(general)
    assert(H.get("gameMenu_scale") == 1.35)
    H.set("gameMenu_scale", 1.4)
    assert(addon.db.gameMenu.scale == 1.4 and H.notified[#H.notified] == "gameMenu")
    H.setting("gameMenu_scale"):SetValueToDefault()
    assert(addon.db.gameMenu.scale == 1)
    H.click("Reset Position")
    assert(resets == 0, "position reset must not act while dragging is disabled")
    H.set("gameMenu_moveable", true)
    H.click("Reset Position")
    assert(resets == 1, "position reset must reach the game menu")
    H.set("cdmButton_slashCM", false)
    assert(addon.db.cdmButton.slashCM, "a disabled shortcut control must not overwrite saved preferences")
    H.set("cdmButton_enabled", true)
    local applied = #H.notified
    H.set("cdmButton_slashCM", false)
    assert(not addon.db.cdmButton.slashCM and #H.notified == applied,
        "shortcut selection must save without reapplying the button")
    H.set("auctionFilter_usableOnly", true)
    H.set("hearthstoneZone_enabled", true)
    assert(addon.db.auctionFilter.usableOnly and addon.db.hearthstoneZone.enabled)
    applied = #H.notified
    H.set("combatLog_raid", true)
    assert(addon.db.combatLog.raid and #H.notified == applied,
        "logging choices must not override a manual logging stop")
    H.set("combatTracker_enabled", true)
    H.set("combatTracker_racials_hiddenSpells_Stoneform", false)
    assert(addon.db.combatTracker.racials.hiddenSpells.Stoneform,
        "racial choices must be available after feature catalog initialization")
    local retail = interface == 120100
    assert((H.settings.MathWroQOL_folioEquipmentSets_enabled ~= nil) == retail)
    assert((H.settings.MathWroQOL_heroicStrike_enabled ~= nil) == retail)
    assert(addon.db.heroicStrike.enabled and addon.db.folioEquipmentSets.enabled,
        "unsupported client pages must leave saved Retail preferences alone")
    if retail then
        H.inCombat = true
        H.fire("PLAYER_REGEN_DISABLED")
        H.set("folioEquipmentSets_enabled", false)
        local folio = H.setting("folioEquipmentSets_enabled")
        assert(not folio.row.enabled and folio.displayedValue and addon.db.folioEquipmentSets.enabled,
            "combat rejection must restore the displayed value after native notification")
        H.inCombat = false
        H.fire("PLAYER_REGEN_ENABLED")
        H.set("folioEquipmentSets_enabled", false)
        assert(not addon.db.folioEquipmentSets.enabled and folio.row.enabled)
    end
end

-- Exercise the real CVar feature, including first activation and Defaults.
local addon = H.load(120100, "Features/CVarSettings.lua")
H.fire("PLAYER_LOGIN")
local page = addon.SettingsUI.BuildCVars({})
H.open(page)
assert(addon.db.spellQueueWindow.value == nil and #H.cvarWrites == 0)
H.set("spellQueueWindow_value", 123)
assert(addon.db.spellQueueWindow.value == nil and #H.cvarWrites == 0,
    "disabled sliders must not invent an enforced queue window")
H.set("spellQueueWindow_enabled", true)
assert(addon.db.spellQueueWindow.value == 277 and #H.cvarWrites == 0,
    "first activation captures the current CVar without writing it")
H.set("spellQueueWindow_value", 150)
assert(H.cvars.SpellQueueWindow == "150" and addon.db.spellQueueWindow.value == 150)
H.setting("spellQueueWindow_value"):SetValueToDefault()
assert(addon.db.spellQueueWindow.value == 150 and H.cvars.SpellQueueWindow == "150",
    "Defaults must not replace a captured/user-selected queue window with 400")
H.set("spellQueueWindow_enabled", false)
H.cvars.SpellQueueWindow = "210"
H.set("spellQueueWindow_enabled", true)
assert(H.cvars.SpellQueueWindow == "150", "subsequent activation restores the saved value")
print("Config native smoke PASS: both clients, navigation, saved values, guards, and real CVar activation")
