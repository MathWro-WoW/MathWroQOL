local _, addon = ...
local UI = addon.SettingsUI

local function readDB(key)
    return addon.db and addon.db[key] or {}
end

local function editDB(key)
    addon.db = addon.db or {}
    if type(addon.db[key]) ~= "table" then addon.db[key] = {} end
    return addon.db[key]
end

local function outOfCombat()
    return not InCombatLockdown()
end

local function boolean(value, fallback)
    if value == nil then return fallback == true end
    return value == true
end

local events = { "ADDON_LOADED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }

local function gate(check, watch, shown)
    return {
        enabled = check,
        guard = check,
        watch = watch,
        events = events,
        shown = shown,
    }
end

local function elvAvailable()
    return ElvUI ~= nil
end

local function ellesmereBarsAvailable()
    return EllesmereUI ~= nil and UI.IsAddonLoaded("EllesmereUIActionBars")
end

local builtins = {
    { key = "atonement", label = "Atonement", spellID = 194384,
        color = { r = 0.95, g = 0.72, b = 0.22 }, spec = 256 },
    { key = "lifebloom", label = "Lifebloom", spellID = 33763,
        color = { r = 0.20, g = 0.85, b = 0.25 }, spec = 105 },
    { key = "prayerOfMending", label = "Prayer of Mending", spellID = 41635,
        color = { r = 0.95, g = 0.88, b = 0.42 }, spec = 257 },
    { key = "riptide", label = "Riptide", spellID = 61295,
        color = { r = 0.16, g = 0.62, b = 0.95 }, spec = 264 },
    { key = "beaconOfTheSavior", label = "Beacon of the Savior", spellID = 1244893,
        color = { r = 1, g = 0.78, b = 0.50 }, spec = 65 },
    { key = "renewingMist", label = "Renewing Mist", spellID = 448430,
        color = { r = 0.35, g = 0.92, b = 0.70 }, spec = 270 },
}
local builtinByKey = {}
for _, entry in ipairs(builtins) do builtinByKey[entry.key] = entry end

local healerSpecs = {
    { id = 256, label = "Discipline Priest" },
    { id = 257, label = "Holy Priest" },
    { id = 65, label = "Holy Paladin" },
    { id = 105, label = "Restoration Druid" },
    { id = 264, label = "Restoration Shaman" },
    { id = 270, label = "Mistweaver Monk" },
}

local function copyColor(color)
    color = color or builtins[1].color
    return { r = color.r or 1, g = color.g or 1, b = color.b or 1 }
end

local function copySpecs(specs)
    local result = {}
    for id, value in pairs(specs or {}) do
        result[tonumber(id) or id] = value == true
    end
    return result
end

local function hasSpecs(specs)
    if type(specs) ~= "table" then return false end
    for _, value in pairs(specs) do
        if value == true then return true end
    end
    return false
end

local function containsSpec(specs, id)
    return type(specs) == "table"
        and (specs[id] == true or specs[tostring(id)] == true) or false
end

local function spellName(id)
    local info = C_Spell.GetSpellInfo(id)
    return info and info.name
end

local function spellIcon(id)
    return C_Spell.GetSpellTexture(id)
end

local function inferSpecs(spellID)
    local inferred = {}
    local current
    if GetSpecialization and GetSpecializationInfo then
        local index = GetSpecialization()
        if index then current = tonumber(GetSpecializationInfo(index)) end
    end
    local book = C_SpellBook
    if book and book.GetNumSpellBookSkillLines and book.GetSpellBookSkillLineInfo
        and book.GetSpellBookItemInfo and Enum and Enum.SpellBookSpellBank then
        for lineIndex = 1, book.GetNumSpellBookSkillLines() or 0 do
            local line = book.GetSpellBookSkillLineInfo(lineIndex)
            if line then
                local spec = tonumber(line.offSpecID) or current
                local offset = line.itemIndexOffset or 0
                for slot = offset + 1, offset + (line.numSpellBookItems or 0) do
                    local item = book.GetSpellBookItemInfo(slot, Enum.SpellBookSpellBank.Player)
                    if item and tonumber(item.spellID) == spellID and spec then
                        inferred[spec] = true
                    elseif item and Enum.SpellBookItemType
                        and item.itemType == Enum.SpellBookItemType.Flyout
                        and GetFlyoutInfo and GetFlyoutSlotInfo then
                        local _, _, count = GetFlyoutInfo(item.actionID)
                        for flyoutSlot = 1, count or 0 do
                            local id, _, _, _, slotSpec = GetFlyoutSlotInfo(item.actionID, flyoutSlot)
                            local inferredSpec = tonumber(slotSpec) or spec
                            if tonumber(id) == spellID and inferredSpec then
                                inferred[inferredSpec] = true
                            end
                        end
                    end
                end
            end
        end
    end
    if not hasSpecs(inferred) and current and IsPlayerSpell and IsPlayerSpell(spellID) then
        inferred[current] = true
    end
    return inferred
end

local function buildBuffEditor(page)
    local function selectedKey()
        local db = readDB("buffHealthColor")
        local key = db.selectedBuff
        if builtinByKey[key] or (db.buffs and type(db.buffs[key]) == "table") then
            return key
        end
        return "atonement"
    end

    local function profile()
        local db = readDB("buffHealthColor")
        return db.buffs and db.buffs[selectedKey()] or {}
    end

    local function available()
        return elvAvailable() and outOfCombat()
    end

    local function editable()
        return available() and readDB("buffHealthColor").enabled == true
    end

    local function choices()
        local key, p = selectedKey(), profile()
        local builtin = builtinByKey[key]
        if builtin then
            local specs = { [builtin.spec] = true }
            if key == "prayerOfMending" then specs[256] = true end
            return specs, false
        end
        if hasSpecs(p.validSpecs) then return p.validSpecs, false end
        return {}, true
    end

    local function fixedSpec()
        local specs, allowAll = choices()
        if allowAll then return nil end
        local only, count = nil, 0
        for _, option in ipairs(healerSpecs) do
            if containsSpec(specs, option.id) then
                only, count = option.id, count + 1
            end
        end
        if count == 1 then return only end
    end

    -- Only edits initialize profiles. Rendering never repairs saved data.
    local function editProfile()
        local key = selectedKey()
        local db = editDB("buffHealthColor")
        db.buffs = db.buffs or {}
        local p = db.buffs[key]
        if type(p) ~= "table" then
            p = {}
            db.buffs[key] = p
        end
        local builtin = builtinByKey[key]
        if builtin then
            if p.enabled == nil then p.enabled = key == "atonement" end
            p.label = p.label or builtin.label
            p.spellID = p.spellID or builtin.spellID
            p.color = p.color or copyColor(builtin.color)
            p.frames = p.frames or {
                player = false, target = false, party = true,
                raid1 = true, raid2 = true, raid3 = true,
            }
            p.specs = p.specs or { [builtin.spec] = true }
            p.validSpecs = { [builtin.spec] = true }
            if key == "prayerOfMending" then p.validSpecs[256] = true end
            p.allSpecs = false
            if key ~= "prayerOfMending" then p.specs = { [builtin.spec] = true } end
        end
        return p
    end

    local function changed()
        addon:NotifyFeature("buffHealthColor")
        UI.Refresh(page)
    end

    UI.Header(page, "Buff Health Color")
    UI.Text(page, function()
        if not elvAvailable() then
            return "ElvUI must be loaded to configure buff health colors. EllesmereUI Raid Frames provides native Buff Manager health bar coloring."
        end
        return "Recolor selected ElvUI health bars while units have configured buffs."
    end)
    UI.Checkbox(page, "buffHealthColor_enabled", "Enable buff health colors", false,
        function() return readDB("buffHealthColor").enabled == true end,
        function(value)
            if not available() then return end
            editDB("buffHealthColor").enabled = value == true
            changed()
        end, gate(available))

    local function options()
        local db, result, seen = readDB("buffHealthColor"), {}, {}
        for _, builtin in ipairs(builtins) do
            local p = db.buffs and db.buffs[builtin.key] or {}
            result[#result + 1] = {
                value = builtin.key, label = p.label or builtin.label,
                icon = spellIcon(p.spellID or builtin.spellID),
            }
            seen[builtin.key] = true
        end
        for _, key in ipairs(db.customOrder or {}) do
            local p = db.buffs and db.buffs[key]
            if type(p) == "table" and not seen[key] then
                seen[key] = true
                result[#result + 1] = {
                    value = key, label = p.label or ("Spell " .. tostring(p.spellID or key)),
                    icon = p.spellID and spellIcon(p.spellID),
                }
            end
        end
        return result
    end

    local config = gate(editable, { "buffHealthColor_enabled" })
    config.refresh = true
    UI.Dropdown(page, "buffHealthColor_selectedBuff", "Buff profile", nil, selectedKey,
        function(value)
            if not editable() then return end
            for _, option in ipairs(options()) do
                if option.value == value then
                    editDB("buffHealthColor").selectedBuff = value
                    UI.Refresh(page)
                    return
                end
            end
        end, options, config)

    UI.Button(page, "Custom buff", "Add custom ID", function()
        if not editable() then return end
        local owner = readDB("buffHealthColor")
        local function popupGuard()
            return editable() and readDB("buffHealthColor") == owner
        end
        UI.Input(page, "Add buff spell ID", "", function(text)
            if not popupGuard() then return false, "Buff settings are no longer available." end
            local id = tonumber(text)
            if not id or id < 1 or id == math.huge or id ~= math.floor(id) then
                return false, "Enter a positive whole spell ID."
            end
            local db = editDB("buffHealthColor")
            db.buffs = db.buffs or {}
            local key = "custom:" .. tostring(id)
            if not db.buffs[key] then
                local specs = inferSpecs(id)
                local inferred = hasSpecs(specs)
                db.buffs[key] = {
                    enabled = true, label = spellName(id) or ("Spell " .. id), spellID = id,
                    color = copyColor(), allSpecs = not inferred,
                    specs = copySpecs(specs), validSpecs = inferred and copySpecs(specs) or nil,
                    frames = {
                        player = false, target = false, party = true,
                        raid1 = true, raid2 = true, raid3 = true,
                    },
                }
            end
            local order, seen = {}, {}
            for _, existing in ipairs(db.customOrder or {}) do
                if not seen[existing] then
                    order[#order + 1], seen[existing] = existing, true
                end
            end
            if not seen[key] then order[#order + 1] = key end
            db.customOrder, db.selectedBuff = order, key
            changed()
            return true
        end, { guard = popupGuard })
    end, gate(editable, { "buffHealthColor_enabled" }))

    UI.Text(page, function()
        local builtin = builtinByKey[selectedKey()]
        return "Spell ID: " .. tostring(profile().spellID or (builtin and builtin.spellID) or "")
    end)
    UI.Checkbox(page, "buffHealthColor_buffs_enabled", "Enable selected buff",
        function() return not builtinByKey[selectedKey()] or selectedKey() == "atonement" end,
        function()
            local p, key = profile(), selectedKey()
            return boolean(p.enabled, not builtinByKey[key] or key == "atonement")
        end,
        function(value)
            if not editable() then return end
            editProfile().enabled = value == true
            changed()
        end, gate(editable, { "buffHealthColor_enabled" }))
    UI.Color(page, "buffHealthColor_buffs_color", "Buff color",
        function()
            local builtin = builtinByKey[selectedKey()]
            return builtin and builtin.color or builtins[1].color
        end,
        function()
            local builtin = builtinByKey[selectedKey()]
            return copyColor(profile().color or (builtin and builtin.color))
        end,
        function(color)
            if not editable() then return end
            editProfile().color = copyColor(color)
            changed()
        end, gate(editable, { "buffHealthColor_enabled" }))

    UI.Header(page, "Frames to Recolor")
    local frames = {
        { "player", "Player" }, { "target", "Target" }, { "party", "Party" },
        { "raid1", "Raid 1" }, { "raid2", "Raid 2" }, { "raid3", "Raid 3" },
    }
    for _, option in ipairs(frames) do
        local key, label = option[1], option[2]
        local default = key ~= "player" and key ~= "target"
        UI.Checkbox(page, "buffHealthColor_buffs_frames_" .. key, label, default,
            function()
                local p = profile()
                return boolean(p.frames and p.frames[key], default)
            end,
            function(value)
                if not editable() then return end
                local p = editProfile()
                p.frames = p.frames or {
                    player = false, target = false, party = true,
                    raid1 = true, raid2 = true, raid3 = true,
                }
                p.frames[key] = value == true
                changed()
            end, gate(editable, { "buffHealthColor_enabled" }))
    end

    UI.Header(page, "Specs to Load In")
    local function allowAll()
        local _, allowed = choices()
        return allowed
    end
    UI.Checkbox(page, "buffHealthColor_buffs_allSpecs", "All specs", true,
        function() return allowAll() and boolean(profile().allSpecs, true) end,
        function(value)
            if not editable() or not allowAll() then return end
            editProfile().allSpecs = value == true
            changed()
        end, gate(editable, { "buffHealthColor_enabled" }, allowAll))

    for _, option in ipairs(healerSpecs) do
        local id, label = option.id, option.label
        local function shown()
            local specs, all = choices()
            return all or containsSpec(specs, id)
        end
        local function specEditable()
            return editable() and shown() and fixedSpec() ~= id
        end
        UI.Checkbox(page, "buffHealthColor_buffs_specs_" .. id, label,
            function()
                local builtin = builtinByKey[selectedKey()]
                if builtin then return builtin.spec == id end
                return containsSpec(profile().validSpecs, id)
            end,
            function()
                if fixedSpec() == id then return true end
                local p, builtin = profile(), builtinByKey[selectedKey()]
                if p.specs == nil and builtin then return builtin.spec == id end
                return containsSpec(p.specs, id)
            end,
            function(value)
                if not specEditable() then return end
                local p = editProfile()
                p.specs = p.specs or {}
                p.specs[tostring(id)] = nil
                p.specs[id] = value == true or nil
                p.allSpecs = false
                changed()
            end, gate(specEditable, { "buffHealthColor_enabled" }, shown))
    end

    local function removable()
        return tostring(selectedKey()):match("^custom:") ~= nil
    end
    local function canRemove()
        return editable() and removable()
    end
    UI.Button(page, "Selected custom buff", "Remove", function()
        if not canRemove() then return end
        local key = selectedKey()
        local db = editDB("buffHealthColor")
        if db.buffs then db.buffs[key] = nil end
        for i = #(db.customOrder or {}), 1, -1 do
            if db.customOrder[i] == key then table.remove(db.customOrder, i) end
        end
        db.selectedBuff = "atonement"
        changed()
    end, gate(canRemove, { "buffHealthColor_enabled" }, removable))
end

function UI.BuildIntegrations(parentCategory, provider)
    local isElv = provider == "elvui"
    local page = UI.Page(parentCategory, isElv and "ElvUI" or "EllesmereUI")
    local suffix = isElv and "elvui" or "ellesmere"
    local function providerAvailable()
        if isElv then return elvAvailable() end
        return ellesmereBarsAvailable()
    end
    local function available()
        return providerAvailable() and outOfCombat()
    end
    local enabledID = "vehicleBar_enabled_" .. suffix
    local function barsEnabled()
        return available() and readDB("vehicleBar").enabled == true
    end
    UI.Header(page, "Vehicle Bar Visibility")
    UI.Text(page, function()
        if not providerAvailable() then
            return isElv and "ElvUI must be loaded to use these options."
                or "EllesmereUI Action Bars must be loaded to use these options."
        end
        return "Keep selected bars visible in vehicle combat, including override states and mouseover fading."
    end)
    UI.Checkbox(page, enabledID, "Enable vehicle bar visibility", false,
        function() return readDB("vehicleBar").enabled == true end,
        function(value)
            if not available() then return end
            editDB("vehicleBar").enabled = value == true
            addon:NotifyFeature("vehicleBar")
        end, gate(available))
    for i = 1, 10 do
        local index = i
        UI.Checkbox(page, "vehicleBar_bars_" .. index .. "_" .. suffix, "Bar " .. index, index == 1,
            function()
                local bars = readDB("vehicleBar").bars
                return bars and bars[index] == true or false
            end,
            function(value)
                if not barsEnabled() then return end
                local db = editDB("vehicleBar")
                db.bars = db.bars or {}
                db.bars[index] = value and true or nil
                addon:NotifyFeature("vehicleBar")
            end, gate(barsEnabled, { enabledID }))
    end
    if isElv then
        buildBuffEditor(page)
    else
        UI.Header(page, "Buff Health Color")
        UI.Text(page, function()
            if EllesmereUI and UI.IsAddonLoaded("EllesmereUIRaidFrames") then
                return "Built into EllesmereUI Raid Frames: create a Buff Manager indicator and choose Health Bar Color."
            end
            return "EllesmereUI Raid Frames must be loaded to use native Buff Manager health bar coloring."
        end)
        UI.Header(page, "Unlock Mode Nudge")
        local function nudgeAvailable()
            return EllesmereUI ~= nil and type(EllesmereUI.RegisterUnlockModeListener) == "function"
                and outOfCombat()
        end
        UI.Text(page, "Arrow controls and pixel coordinates for EllesmereUI Unlock Mode. Enabled separately from Blizzard Edit Mode nudging.")
        UI.Checkbox(page, "editModeNudge_ellesmereEnabled", "Enable nudge overlay", false,
            function() return readDB("editModeNudge").ellesmereEnabled == true end,
            function(value)
                if not nudgeAvailable() then return end
                editDB("editModeNudge").ellesmereEnabled = value == true
                addon:NotifyFeature("editModeNudge")
            end, gate(nudgeAvailable))
    end
    return page
end

function UI.BuildCDMPlugins(parentCategory)
    local page = UI.Page(parentCategory, "Cooldown Manager Tweaks")
    local function available()
        return UI.IsAddonLoaded("CooldownManagerCentered")
            and LibStub ~= nil and LibStub("Masque", true) ~= nil and outOfCombat()
    end
    local function viewersEnabled()
        return available() and readDB("cmcMasque").enabled == true
    end
    UI.Header(page, "Centered Cooldown Manager")
    UI.Text(page, "Register icon viewers with Masque for skinning. Requires CooldownManagerCentered and Masque.")
    UI.Checkbox(page, "cmcMasque_enabled", "Enable Masque skinning", false,
        function() return readDB("cmcMasque").enabled == true end,
        function(value)
            if not available() then return end
            editDB("cmcMasque").enabled = value == true
            addon:NotifyFeature("cmcMasque")
        end, gate(available))
    local viewers = {
        { "essential", "Essential icons" }, { "utility", "Utility icons" },
        { "buffIcons", "Buff icons" },
    }
    for _, option in ipairs(viewers) do
        local key, label = option[1], option[2]
        UI.Checkbox(page, "cmcMasque_viewers_" .. key, label, true,
            function()
                local db = readDB("cmcMasque")
                return boolean(db.viewers and db.viewers[key], true)
            end,
            function(value)
                if not viewersEnabled() then return end
                local db = editDB("cmcMasque")
                db.viewers = db.viewers or {}
                db.viewers[key] = value == true
                addon:NotifyFeature("cmcMasque")
            end, gate(viewersEnabled, { "cmcMasque_enabled" }))
    end
    if addon.isForever then return page end

    UI.Header(page, "Arms Warrior — Heroic Strike")
    UI.Text(page, "Show a proc companion beside EllesmereUI's Buffs row, or Blizzard's Buff Icons viewer. Arms only; no Masque dependency. Not a sortable CDM entry.")
    UI.Checkbox(page, "heroicStrike_enabled", "Enable Heroic Strike proc icon", false,
        function() return readDB("heroicStrike").enabled == true end,
        function(value)
            if not outOfCombat() then return end
            editDB("heroicStrike").enabled = value == true
            addon:NotifyFeature("heroicStrike")
        end, gate(outOfCombat))
    local function heroicEnabled()
        return outOfCombat() and readDB("heroicStrike").enabled == true
    end
    UI.Dropdown(page, "heroicStrike_side", "Placement", "right",
        function() return readDB("heroicStrike").side or "right" end,
        function(value)
            if not heroicEnabled() then return end
            if value == "right" or value == "left" then
                editDB("heroicStrike").side = value
                addon:NotifyFeature("heroicStrike")
            end
        end, {
            { value = "right", label = "Right" }, { value = "left", label = "Left" },
        }, gate(heroicEnabled, { "heroicStrike_enabled" }))
    UI.Dropdown(page, "heroicStrike_glowType", "Glow", "none",
        function() return readDB("heroicStrike").glowType or "none" end,
        function(value)
            if not heroicEnabled() then return end
            if value == "none" or value == "classic" or value == "proc" or value == "assist" then
                editDB("heroicStrike").glowType = value
                addon:NotifyFeature("heroicStrike")
            end
        end, {
            { value = "none", label = "None" }, { value = "classic", label = "Classic" },
            { value = "proc", label = "Modern Proc" }, { value = "assist", label = "Assisted Combat" },
        }, gate(heroicEnabled, { "heroicStrike_enabled" }))
    UI.Text(page, "Follows EllesmereUI row size, spacing, appearance and visibility. Empty rows use their starting position. On vertical rows, Right uses the growth end; Left uses the opposite end.")
    UI.Text(page, "Without EllesmereUI CDM, enable Blizzard's Cooldown Manager. Glow appears only while the proc is available.")
    return page
end

function UI.BuildOtherAddonTweaks(parentCategory)
    local page = UI.Page(parentCategory, "Other Addon Tweaks")
    UI.Header(page, "Other Addon Tweaks")
    UI.Text(page, "Expand this category on the left to choose an addon. Unavailable integrations remain disabled; existing preferences are preserved.")
    local children = {
        UI.BuildIntegrations(page.category, "elvui"),
        UI.BuildIntegrations(page.category, "ellesmere"),
        UI.BuildCDMPlugins(page.category),
    }
    local pally = UI.Page(page.category, "PallyPower")
    local function available()
        return addon.isForever and UI.IsAddonLoaded("PallyPower")
            and select(2, UnitClass("player")) == "PALADIN" and outOfCombat()
    end
    UI.Header(pally, "PallyPower Forever")
    UI.Checkbox(pally, "pallyPower_enabled", "Hide when assigned blessings are satisfied", false,
        function() return readDB("pallyPower").enabled == true end,
        function(value)
            if not available() then return end
            editDB("pallyPower").enabled = value == true
            addon:NotifyFeature("pallyPower")
        end, gate(available))
    UI.Text(pally, "Requires PallyPower Forever and a Paladin. Outside combat, hide the buff bar only when your assigned blessings are confirmed present with more than four minutes remaining. Missing or unknown buffs keep it visible.")
    UI.Text(pally, "Combat restores normal access to the enabled buff buttons. Other paladins' assignments, seals, Righteous Fury and auras are not checked. Assignments and minimap access are unchanged. This option cannot be changed in combat.")
    children[#children + 1] = pally
    for _, child in ipairs(children) do
        local target = child.category
        UI.Button(page, target:GetName(), "Open " .. target:GetName(), function()
            Settings.OpenToCategory(target:GetID())
        end)
    end
    return page
end

function UI.BuildDebug(parentCategory)
    local page = UI.Page(parentCategory, "Debug")
    UI.Header(page, "Buff Health Color")
    UI.Text(page, "Print ElvUI buff health color diagnostics for a unit to chat.")
    local function buffAvailable()
        return elvAvailable() and type(addon.DebugBuffHealthColor) == "function"
    end
    local units = {
        { "Target", "target" }, { "Party 1", "party1" },
        { "Raid 1", "raid1" }, { "Player", "player" },
    }
    for _, option in ipairs(units) do
        local label, unit = option[1], option[2]
        UI.Button(page, "Buff diagnostics: " .. label, label, function()
            if not buffAvailable() then return end
            addon.DebugBuffHealthColor(unit)
        end, gate(buffAvailable))
    end
    UI.Header(page, "Vehicle Bar")
    UI.Text(page, "Print provider, vehicle state and action slot diagnostics, or toggle diagnostic watching.")
    local function vehicleAvailable()
        return (elvAvailable() or ellesmereBarsAvailable())
            and type(addon.DebugVehicleBar) == "function"
    end
    UI.Button(page, "Vehicle diagnostics", "Print State", function()
        if not vehicleAvailable() then return end
        addon.DebugVehicleBar("button")
    end, gate(vehicleAvailable))
    UI.Button(page, "Vehicle diagnostic watching", "Toggle Watch", function()
        if not vehicleAvailable() then return end
        addon.DebugVehicleBar("watch")
    end, gate(vehicleAvailable))
    return page
end