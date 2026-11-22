local _, addon = ...
local UI = addon.SettingsUI

function UI.BuildExternalTracker(parent)
    local page = UI.Page(parent, "External Tracker")
    local db = addon.db.externalTracker
    local catalog = addon.externalTracker.spells
    local selected = catalog[1] and catalog[1].spellID or 0
    local empty = { enabled = false, mode = "icon", sound = "None" }
    local events = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ADDON_LOADED" }
    local function editable() return not InCombatLockdown() end
    local function active() return editable() and db.enabled == true end
    local function entry() return db.spells[selected] or empty end
    local function selectedActive() return active() and entry().enabled == true end
    local function media() return LibStub and LibStub("LibSharedMedia-3.0", true) end
    local function wantsSound() return selectedActive() and (entry().mode or "icon") ~= "icon" end
    local function soundEditable() return wantsSound() and media() ~= nil end
    local function setEntry(key, value)
        if not db.spells[selected] then db.spells[selected] = { enabled = false, mode = "icon", sound = "None" } end
        db.spells[selected][key] = value
        addon:NotifyFeature("externalTracker")
    end
    local function fetchSound()
        local library = media()
        local name = entry().sound or "None"
        local file = library and name ~= "None" and library:Fetch("sound", name, true)
        if file ~= nil and file ~= false and file ~= "" and file ~= 1 then return file end
    end
    local function canPreview() return wantsSound() and fetchSound() ~= nil end
    local watch = { "externalTracker_enabled", "externalTracker_spell", "externalTracker_spell_enabled",
        "externalTracker_spell_mode", "externalTracker_spell_sound" }

    UI.Header(page, "External Buffs")
    UI.Text(page, "Track selected buffs on yourself, including self-casts. Sounds trigger when a buff is applied, not when another player's cooldown becomes ready. Settings lock in combat.")
    UI.Checkbox(page, "externalTracker_enabled", "Enable External Tracker", false,
        function() return db.enabled end,
        function(value) db.enabled = value; addon:NotifyFeature("externalTracker") end,
        { enabled = editable, guard = editable, events = events, refresh = true })
    UI.Dropdown(page, "externalTracker_soundChannel", "Sound channel", "Master",
        function() return db.soundChannel or "Master" end,
        function(value) db.soundChannel = value; addon:NotifyFeature("externalTracker") end,
        { { label = "Master", value = "Master" }, { label = "Sound Effects", value = "SFX" },
          { label = "Music", value = "Music" }, { label = "Ambience", value = "Ambience" },
          { label = "Dialog", value = "Dialog" } },
        { enabled = active, guard = active, watch = watch, events = events,
            tooltip = "Alerts and sound previews use this channel's volume and mute settings." })

    UI.Header(page, "Spell Settings")
    UI.Dropdown(page, "externalTracker_spell", "Selected spell", nil,
        function() return selected end, function(value) selected = value end,
        function()
            local options = {}
            for _, spell in ipairs(catalog) do
                local info = C_Spell.GetSpellInfo(spell.spellID)
                options[#options + 1] = { label = info and info.name or spell.label,
                    value = spell.spellID, icon = info and info.iconID }
            end
            return options
        end, { enabled = active, guard = active, watch = watch, events = events, refresh = true })
    UI.Checkbox(page, "externalTracker_spell_enabled", "Track selected spell", false,
        function() return entry().enabled end, function(value) setEntry("enabled", value) end,
        { enabled = active, guard = active, watch = watch, events = events, refresh = true })
    UI.Dropdown(page, "externalTracker_spell_mode", "Output", "icon",
        function() return entry().mode or "icon" end, function(value) setEntry("mode", value) end,
        { { label = "Icon with duration", value = "icon" }, { label = "Sound only", value = "sound" },
          { label = "Icon and sound", value = "both" } },
        { enabled = selectedActive, guard = selectedActive, watch = watch, events = events, refresh = true })
    UI.Dropdown(page, "externalTracker_spell_sound", "SharedMedia sound", "None",
        function() return entry().sound or "None" end, function(value) setEntry("sound", value) end,
        function()
            local options = { { label = "None", value = "None" } }
            local current = entry().sound or "None"
            local found = current == "None"
            local library = media()
            if library then
                for _, name in ipairs(library:List("sound") or {}) do
                    local file = library:Fetch("sound", name, true)
                    if name ~= "None" and file and file ~= "" and file ~= 1 then
                        options[#options + 1] = { label = name, value = name }
                        if name == current then found = true end
                    end
                end
            end
            if not found then options[#options + 1] = { label = current .. " (unavailable)", value = current } end
            return options
        end, { enabled = soundEditable, guard = soundEditable, watch = watch, events = events, refresh = true,
            tooltip = "None is silent. Missing sound packs never substitute a different sound." })
    UI.Button(page, "Selected sound", "Preview Sound", function()
        local file = fetchSound()
        if file then PlaySoundFile(file, db.soundChannel or "Master") end
    end, { enabled = canPreview, guard = canPreview, watch = watch, events = events })
    UI.Text(page, function()
        if not media() then return "Sound choices require an enabled addon providing LibSharedMedia-3.0. Icon tracking works without it." end
        if (entry().sound or "None") ~= "None" and not fetchSound() then
            return "The saved sound is unavailable. Enable its sound pack or choose another sound. No replacement sound will play."
        end
        return "Choose a spell and its independent icon/sound settings. Every spell starts disabled."
    end)

    UI.Header(page, "Position and Appearance")
    UI.Text(page, "Enable External Tracker, enter Blizzard Edit Mode, and click its selection for icon size, duration text, zoom, and glow. An example icon appears even when no spells are selected.")
    UI.Button(page, "External Tracker position", "Reset External Position", function()
        db.point, db.x, db.y = "CENTER", 0, 150
        addon:NotifyFeature("externalTracker")
    end, { enabled = active, guard = active, watch = watch, events = events })
    if addon.isForever then return page end
    local bloodlust = addon.db.bloodlustTracker

    UI.Header(page, "Bloodlust Tracker")
    UI.Text(page, "An independent duration icon for Bloodlust variants and drums. Works with External Tracker disabled. Its position, appearance, and preview are separate in Blizzard Edit Mode.")
    UI.Checkbox(page, "bloodlustTracker_enabled", "Enable Bloodlust Tracker", false,
        function() return bloodlust.enabled end,
        function(value) bloodlust.enabled = value; addon:NotifyFeature("bloodlustTracker") end,
        { enabled = editable, guard = editable, events = events })
    local function bloodlustActive() return editable() and bloodlust.enabled == true end
    UI.Button(page, "Bloodlust position", "Reset Bloodlust Position", function()
        bloodlust.point, bloodlust.x, bloodlust.y = "CENTER", 0, 90
        addon:NotifyFeature("bloodlustTracker")
    end, { enabled = bloodlustActive, guard = bloodlustActive, watch = { "bloodlustTracker_enabled" }, events = events })
    return page
end
