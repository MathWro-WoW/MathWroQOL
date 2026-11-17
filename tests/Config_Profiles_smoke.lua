local H = dofile("tests/SettingsHarness.lua")
local addon = H.load(120100, "Config/Integrations.lua")
local UI = addon.SettingsUI
local saved = H.snapshot(addon.db)
local elv = UI.BuildIntegrations({}, "elvui")
local ellesmere = UI.BuildIntegrations({}, "ellesmere")
local plugins = UI.BuildCDMPlugins({})
local debugPage = UI.BuildDebug({})
assert(H.snapshot(addon.db) == saved and #H.notified == 0)
H.open(elv)
H.set("vehicleBar_enabled_elvui", true)
H.set("buffHealthColor_enabled", true)
assert(not addon.db.vehicleBar.enabled and not addon.db.buffHealthColor.enabled,
    "missing providers must reject writes, including direct/default writes")
ElvUI = {}
H.fire("ADDON_LOADED", "ElvUI")
H.set("vehicleBar_enabled_elvui", true)
H.set("vehicleBar_bars_1_elvui", false)
assert(not addon.db.vehicleBar.bars[1] and not H.get("vehicleBar_bars_1_elvui"),
    "unchecking the initially enabled bar must stay unchecked")
H.set("buffHealthColor_enabled", true)
H.set("buffHealthColor_selectedBuff", "prayerOfMending")
H.set("buffHealthColor_buffs_specs_257", false)
H.set("buffHealthColor_selectedBuff", "atonement")
H.set("buffHealthColor_selectedBuff", "prayerOfMending")
assert(not addon.db.buffHealthColor.buffs.prayerOfMending.specs[257]
    and not H.get("buffHealthColor_buffs_specs_257"), "profile selection must preserve explicit false spec choices")
H.set("buffHealthColor_selectedBuff", "lifebloom")
local atonementColor = H.snapshot(addon.db.buffHealthColor.buffs.atonement.color)
H.set("buffHealthColor_buffs_enabled", true)
H.set("buffHealthColor_buffs_color", "ff112233")
H.setting("buffHealthColor_buffs_enabled"):SetValueToDefault()
H.setting("buffHealthColor_buffs_color"):SetValueToDefault()
H.flush()
assert(not addon.db.buffHealthColor.buffs.lifebloom.enabled and H.get("buffHealthColor_buffs_color") == "ff33d940",
    "Defaults must use the selected profile's defaults, not Atonement's")
assert(H.snapshot(addon.db.buffHealthColor.buffs.atonement.color) == atonementColor)
H.click("Add custom ID")
H.input("1e999")
assert(H.popup and not addon.db.buffHealthColor.buffs["custom:inf"], "invalid spell IDs must leave the dialog editable")
H.input("52999")
local custom = addon.db.buffHealthColor.buffs["custom:52999"]
assert(custom and custom.enabled and custom.allSpecs and addon.db.buffHealthColor.selectedBuff == "custom:52999")
H.set("buffHealthColor_buffs_frames_party", false)
H.click("Add custom ID")
H.input("52999")
assert(#addon.db.buffHealthColor.customOrder == 1 and not custom.frames.party,
    "adding an existing custom spell must select it without resetting its preferences or duplicating it")
H.click("Remove")
assert(not addon.db.buffHealthColor.buffs["custom:52999"] and addon.db.buffHealthColor.selectedBuff == "atonement")
H.click("Add custom ID")
H.inCombat = true
H.fire("PLAYER_REGEN_DISABLED")
H.input("53000")
assert(not addon.db.buffHealthColor.buffs["custom:53000"], "combat entry must cancel a pending protected edit")
H.inCombat = false
H.fire("PLAYER_REGEN_ENABLED")

H.open(ellesmere)
EllesmereUI = { RegisterUnlockModeListener = function() end }
H.fire("ADDON_LOADED", "EllesmereUI")
H.set("editModeNudge_ellesmereEnabled", true)
assert(addon.db.editModeNudge.ellesmereEnabled, "Unlock Mode nudge must not require the Action Bars module")
H.set("vehicleBar_bars_2_ellesmere", true)
assert(not addon.db.vehicleBar.bars[2], "vehicle options require the relevant provider module")
H.loaded.EllesmereUIActionBars = true
H.fire("ADDON_LOADED", "EllesmereUIActionBars")
H.set("vehicleBar_bars_2_ellesmere", true)
assert(addon.db.vehicleBar.bars[2] and H.get("vehicleBar_bars_2_elvui"),
    "provider pages must edit the existing shared vehicle preference")

H.open(plugins)
H.set("cmcMasque_enabled", true)
assert(not addon.db.cmcMasque.enabled)
H.loaded.CooldownManagerCentered, H.libs.Masque = true, {}
H.fire("ADDON_LOADED", "Masque")
H.set("cmcMasque_enabled", true)
H.set("cmcMasque_viewers_utility", false)
assert(addon.db.cmcMasque.enabled and not addon.db.cmcMasque.viewers.utility)
H.set("heroicStrike_enabled", true)
H.set("heroicStrike_side", "left")
H.set("heroicStrike_glowType", "proc")
assert(addon.db.heroicStrike.side == "left" and addon.db.heroicStrike.glowType == "proc"
    and H.notified[#H.notified] == "heroicStrike", "placement and glow changes must apply immediately")
H.inCombat = true
H.fire("PLAYER_REGEN_DISABLED")
H.set("heroicStrike_side", "right")
assert(addon.db.heroicStrike.side == "left" and H.setting("heroicStrike_side").displayedValue == "left")
H.inCombat = false
local units, actions = {}, {}
addon.DebugBuffHealthColor = function(unit) units[#units + 1] = unit end
addon.DebugVehicleBar = function(action) actions[#actions + 1] = action end
H.open(debugPage)
H.click("Party 1")
H.click("Print State")
H.click("Toggle Watch")
assert(units[1] == "party1" and actions[1] == "button" and actions[2] == "watch")

for _, interface in ipairs({ 120100, 16001 }) do
    addon = H.load(interface, "Config/ExternalTracker.lua")
    H.catalogs()
    UI = addon.SettingsUI
    local first, second = addon.externalTracker.spells[1].spellID, addon.externalTracker.spells[2].spellID
    saved = H.snapshot(addon.db)
    local page = UI.BuildExternalTracker({})
    H.open(page)
    assert(H.snapshot(addon.db) == saved and #H.notified == 0)
    H.set("bloodlustTracker_enabled", true)
    assert(addon.db.bloodlustTracker.enabled and not addon.db.externalTracker.enabled)
    H.set("externalTracker_enabled", true)
    H.set("externalTracker_spell_mode", "both")
    assert(not addon.db.externalTracker.spells[first], "disabled spells must not gain settings from rejected writes")
    H.set("externalTracker_spell_enabled", true)
    H.set("externalTracker_spell_mode", "both")
    local notifications = #H.notified
    H.set("externalTracker_spell", second)
    H.setting("externalTracker_spell"):SetValueToDefault()
    assert(H.get("externalTracker_spell") == second and #H.notified == notifications,
        "spell selection is an editor target, not a gameplay change or a resettable preference")
    H.set("externalTracker_spell_enabled", true)
    assert(H.get("externalTracker_spell_mode") == "icon" and addon.db.externalTracker.spells[first].mode == "both")
    H.set("externalTracker_spell", first)
    local names, files = { "None" }, { None = 1 }
    for index = 1, 40 do
        local name = string.format("Sound %02d", index)
        names[#names + 1], files[name] = name, 100 + index
    end
    H.libs["LibSharedMedia-3.0"] = {
        List = function() return names end,
        Fetch = function(_, _, name, noDefault) assert(noDefault); return files[name] end,
    }
    H.fire("ADDON_LOADED", "SoundPack")
    H.flush()
    H.set("externalTracker_spell_sound", "Sound 40")
    H.click("Preview Sound")
    assert(H.played.file == 140 and H.played.channel == "Master")
    table.insert(names, 2, "AirHorn")
    files.AirHorn = "Interface\\AddOns\\Sounds\\AirHorn.ogg"
    assert(H.options("externalTracker_spell_sound")[2].value == "AirHorn", "late media must appear the next time options are requested")
    H.set("externalTracker_spell_sound", "AirHorn")
    H.set("externalTracker_soundChannel", "SFX")
    H.click("Preview Sound")
    assert(H.played.file == files.AirHorn and H.played.channel == "SFX")
    files.AirHorn = nil
    H.fire("ADDON_LOADED", "RemovedPack")
    H.flush()
    local options = H.options("externalTracker_spell_sound")
    assert(options[#options].value == "AirHorn" and options[#options].label:find("unavailable", 1, true))
    H.played = nil
    H.click("Preview Sound")
    assert(not H.played and addon.db.externalTracker.spells[first].sound == "AirHorn", "missing packs must preserve the selection and never preview a replacement")
    H.set("externalTracker_spell_sound", "None")
    H.click("Preview Sound")
    assert(not H.played, "None must remain silent even when SharedMedia maps it to 1")
    H.set("externalTracker_enabled", false)
    addon.db.bloodlustTracker.x = 999
    H.click("Reset Bloodlust Position")
    assert(addon.db.bloodlustTracker.enabled and addon.db.bloodlustTracker.x == 0,
        "Bloodlust must remain independently usable with externals disabled")
    H.inCombat = true
    H.fire("PLAYER_REGEN_DISABLED")
    H.set("bloodlustTracker_enabled", false)
    assert(addon.db.bloodlustTracker.enabled and H.setting("bloodlustTracker_enabled").displayedValue)
end
print("Config profiles smoke PASS: providers, per-profile defaults, custom IDs, independent trackers, and dynamic sound media")
