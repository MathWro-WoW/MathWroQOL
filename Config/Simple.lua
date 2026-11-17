local _, addon = ...
local UI = addon.SettingsUI

local function toggle(page, feature, key, label, config, notify)
    return UI.Checkbox(page, feature .. "_" .. key, label, false,
        function() return addon.db[feature][key] == true end,
        function(value)
            addon.db[feature][key] = value
            if notify ~= false then addon:NotifyFeature(feature) end
        end, config)
end

function UI.BuildGeneral(parent)
    local page = UI.Page(parent, "General")
    UI.Header(page, "Game Menu", "Change the Escape menu's size and saved position.")
    UI.Slider(page, "gameMenu_scale", "Menu scale", 0.5, 2, 0.05, 1,
        function() return addon.db.gameMenu.scale end,
        function(value) addon.db.gameMenu.scale = value; addon:NotifyFeature("gameMenu") end,
        { tooltip = "Resize the Escape menu.", formatter = function(value) return string.format("%.2fx", value) end })
    toggle(page, "gameMenu", "moveable", "Allow dragging", {
        tooltip = "Drag the Escape menu to move it. Its position is saved between sessions.",
    })
    local function canReset() return addon.db.gameMenu.moveable == true end
    UI.Button(page, "Menu position", "Reset Position", function()
        for _, feature in ipairs(addon.features) do
            if feature.name == "gameMenu" and feature.ResetPosition then feature:ResetPosition(); return end
        end
    end, { enabled = canReset, guard = canReset, watch = { "gameMenu_moveable" },
        tooltip = "Return the Escape menu to its default position. Requires Allow dragging." })

    UI.Header(page, "Cooldown Manager")
    toggle(page, "cdmButton", "enabled", "Show Game Menu button", {
        tooltip = "Add an Escape menu button that opens your Cooldown Manager.",
    })
    local function shortcutsEnabled() return addon.db.cdmButton.enabled == true end
    for _, entry in ipairs({ { "slashWA", "/wa" }, { "slashCM", "/cm" } }) do
        local key, command = entry[1], entry[2]
        toggle(page, "cdmButton", key, "Enable " .. command .. " command", {
            tooltip = "Open the Cooldown Manager with " .. command .. ". Requires the Game Menu button feature.",
            enabled = shortcutsEnabled, guard = shortcutsEnabled, watch = { "cdmButton_enabled" },
        }, false)
    end

    UI.Header(page, "Auction House Filters")
    UI.Text(page, "Apply these filters automatically each time you open the Auction House.")
    toggle(page, "auctionFilter", "currentExpansionOnly", "Current expansion only")
    toggle(page, "auctionFilter", "usableOnly", "Usable only")

    if not addon.isForever then
        UI.Header(page, "Folio Equipment Sets")
        local function editable() return not InCombatLockdown() end
        toggle(page, "folioEquipmentSets", "enabled", "Enable Folio equipment sets", {
            enabled = editable, guard = editable,
            events = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" },
            tooltip = "Link Folio choices to equipment sets. This setting cannot be changed in combat.",
        })
        UI.Text(page, "Open Omnium Folio to save, apply, or clear the setup linked to an equipment set.")
    end
    return page
end

function UI.BuildSmallTweaks(parent)
    local page = UI.Page(parent, "Small Tweaks")
    UI.Header(page, "Tooltips")
    toggle(page, "hearthstoneZone", "enabled", "Hearthstone destination zone", {
        tooltip = "Append the saved destination zone to the ordinary Hearthstone's tooltip.",
    })
    UI.Text(page, "Set your Hearthstone at an inn once after enabling. Its tooltip will then include that zone. Saved separately for each character.")
    return page
end

function UI.BuildCombatLog(parent)
    local page = UI.Page(parent, "Combat Logging")
    UI.Header(page, "Automatic Logging")
    UI.Text(page, "Start logging in selected instance types; stop when leaving them. Manually stopping logging keeps it off until you leave all instances.")
    for _, entry in ipairs({ { "dungeon", "Dungeon" }, { "mythicPlus", "Mythic+" },
        { "raid", "Raid" }, { "scenario", "Scenario" }, { "pvp", "Battleground" }, { "arena", "Arena" } }) do
        toggle(page, "combatLog", entry[1], entry[2], nil, false)
    end
    UI.Header(page, "Restrictions")
    toggle(page, "combatLog", "maxLevelOnly", "Only at maximum level", nil, false)
    return page
end

function UI.BuildCVars(parent)
    local page = UI.Page(parent, "CVars and Settings")
    UI.Header(page, "Camera Distance")
    toggle(page, "cameraDistance", "enabled", "Maximum camera distance", {
        tooltip = "Restore the maximum camera zoom on login. Enabling applies immediately; disabling leaves the current CVar unchanged.",
    })
    UI.Header(page, "Spell Queue Window")
    UI.Text(page, "First activation captures your current queue window without changing it. Only a captured or explicitly selected value is restored on login.")
    local function currentValue() return tonumber(C_CVar.GetCVar("SpellQueueWindow")) or 400 end
    local function enabled() return addon.db.spellQueueWindow.enabled == true end
    UI.Checkbox(page, "spellQueueWindow_enabled", "Enforce queue window", false, enabled,
        function(value)
            local db = addon.db.spellQueueWindow
            if value and db.value == nil then db.value = currentValue() end
            db.enabled = value
            addon:NotifyFeature("spellQueueWindow")
        end, { refresh = true })
    UI.Slider(page, "spellQueueWindow_value", "Queue window", 0, 400, 1, nil,
        function() return addon.db.spellQueueWindow.value or currentValue() end,
        function(value)
            addon.db.spellQueueWindow.value = value
            addon:NotifyFeature("spellQueueWindow")
        end, { enabled = enabled, guard = enabled, watch = { "spellQueueWindow_enabled" },
            formatter = function(value) return string.format("%d ms", value) end,
            tooltip = "Defaults does not replace your captured value with an arbitrary queue window." })
    UI.Text(page, function()
        local _, default = C_CVar.GetCVarInfo("SpellQueueWindow")
        return "WoW default: " .. tostring(default or "Unknown") .. " ms. The captured value is preserved until you change the slider."
    end)
    return page
end

function UI.BuildEditMode(parent)
    local page = UI.Page(parent, "Edit Mode")
    UI.Header(page, "Nudge Overlay")
    toggle(page, "editModeNudge", "enabled", "Enable nudge overlay", {
        tooltip = "Show arrow controls and exact coordinates for Blizzard Edit Mode and LibEditMode selections.",
    })
    UI.Text(page, "Enter Blizzard Edit Mode and click a highlighted tracker to edit its size and text. EllesmereUI Unlock Mode has its own nudge toggle under EllesmereUI.")
    return page
end
