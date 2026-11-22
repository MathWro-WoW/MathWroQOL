local H = dofile("tests/SettingsHarness.lua")
for _, interface in ipairs({16001, 120100}) do
    local addon = H.load(interface, "Config/Integrations.lua")
    function UnitClass() return "Paladin", "PALADIN" end
    local UI = addon.SettingsUI
    local root = UI.Page(nil, "MathWro QOL")
    assert(UI.BuildOtherAddonTweaks, "grouped addon settings must be available")
    local saved = H.snapshot(addon.db)
    local page = UI.BuildOtherAddonTweaks(root.category)
    assert(H.snapshot(addon.db) == saved, "group registration must preserve saved preferences")
    H.open(page)
    H.click("Open ElvUI")
    local selected
    for _, category in ipairs(H.categories) do
        if category.id == H.openedCategoryID then selected = category end
    end
    assert(selected and selected.name == "ElvUI" and selected.parent == page.category,
        "group navigation must open the nested integration page")
    local pally
    for _, category in ipairs(H.categories) do
        if category.name == "PallyPower" then pally = category end
    end
    assert(pally and pally.parent == page.category)
    H.open({ category = pally })
    H.set("pallyPower_enabled", true)
    assert(not addon.db.pallyPower.enabled, "missing provider must reject saved changes")
    H.loaded.PallyPower = true
    H.fire("ADDON_LOADED", "PallyPower")
    H.set("pallyPower_enabled", true)
    assert(addon.db.pallyPower.enabled == (interface == 16001), "PallyPower runtime is Forever only")
    if interface == 16001 then
        H.inCombat = true; H.fire("PLAYER_REGEN_DISABLED")
        H.set("pallyPower_enabled", false)
        assert(addon.db.pallyPower.enabled, "combat must reject edits")
        H.inCombat = false; H.fire("PLAYER_REGEN_ENABLED")
        H.setting("pallyPower_enabled"):SetValueToDefault(); H.flush()
        assert(not addon.db.pallyPower.enabled and H.notified[#H.notified] == "pallyPower",
            "Defaults must disable through the ordinary feature handler")
    end
end
print("Addon tweaks settings smoke PASS: nested navigation, saved values, and provider/client/combat guards")
