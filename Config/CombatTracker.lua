local _, addon = ...
local UI = addon.SettingsUI

local SECTION_KEYS = { "racials", "trinkets", "consumables" }
local SECTION_NAMES = {
    racials = "Racials",
    trinkets = "Trinkets",
    consumables = "Consumables",
}
local CATEGORIES = {
    { field = "showCombatPotions", catalog = "combatPotions", label = "Combat Potions", category = "Combat Potion", default = true },
    { field = "showHealingPotions", catalog = "healingPotions", label = "Healing Potions", category = "Healing Potion", default = true },
    { field = "showManaPotions", catalog = "manaPotions", label = "Mana Potions", category = "Mana Potion", default = true },
    { field = "showHealthstone", catalog = "healthstone", label = "Healthstone", category = "Healthstone", default = true },
    { field = "showFood", label = "Food", default = false },
    { field = "showWater", label = "Water", default = false },
}
local LAYOUT_OPTIONS = {
    { label = "Horizontal", value = "horizontal" },
    { label = "Vertical", value = "vertical" },
    { label = "Grid", value = "grid" },
}
local GROW_OPTIONS = {
    { label = "Grow Right", value = "growRight" },
    { label = "Grow Left", value = "growLeft" },
    { label = "Grow Down", value = "growDown" },
    { label = "Grow Up", value = "growUp" },
    { label = "Center Horiz.", value = "centerH" },
    { label = "Center Vert.", value = "centerV" },
}
local COLUMN_OPTIONS = {
    { label = "2", value = 2 },
    { label = "3", value = 3 },
    { label = "4", value = 4 },
    { label = "5", value = 5 },
}
local COMBAT_EVENTS = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }

local function copyOrder(source)
    local result = {}
    for index, value in ipairs(source or {}) do result[index] = value end
    return result
end

local function positiveInteger(text)
    local value = tonumber(text)
    if not value or value ~= value or value == math.huge
        or value <= 0 or value ~= math.floor(value) then
        return nil
    end
    return value
end

local function outOfCombat()
    return not InCombatLockdown()
end

function UI.BuildCombatTracker(parentCategory)
    local page = UI.Page(parentCategory, "Combat Tracker")
    local itemInfo = CreateFrame("Frame")
    itemInfo:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    itemInfo:SetScript("OnEvent", function()
        if SettingsPanel:IsShown() and SettingsPanel:GetCurrentCategory() == page.category then UI.Refresh(page) end
    end)
    local selectedItem = 0
    local macroStatus = "Creates MQOL Food and MQOL Water in General Macros. Updates follow this character's selections after combat."

    local function db()
        return addon.db.combatTracker
    end

    local function frameDB(key)
        return db().frames[key]
    end

    local function consumablesSection()
        local tracker = addon.combatTracker
        return tracker and tracker.sections and tracker.sections.consumables
    end

    local function trackerEnabled()
        return db().enabled == true
    end

    local function sectionEnabled(key)
        return trackerEnabled() and frameDB(key).enabled == true
    end

    local function consumablesEnabled()
        return sectionEnabled("consumables")
    end

    local function orderAvailable()
        local section = consumablesSection()
        return consumablesEnabled() and section ~= nil
            and type(section.BuildDefaultOrder) == "function"
            and type(section.CONSUMABLE_IDS) == "table"
    end

    local function changed()
        addon:NotifyFeature("combatTracker")
        UI.Refresh(page)
    end

    local function frameID(key, field)
        return "combatTracker_frames_" .. key .. "_" .. field
    end

    local function frameWatch(key)
        return { "combatTracker_enabled", frameID(key, "enabled") }
    end

    -- The section's static catalog builder returns a fresh order without writes.
    local function defaultOrder()
        local section = consumablesSection()
        if not section or type(section.BuildDefaultOrder) ~= "function" then
            return {}
        end
        return section.BuildDefaultOrder(frameDB("consumables"))
    end

    local function synchronizedOrder(source)
        local frame = frameDB("consumables")
        local section = consumablesSection()
        if not section or type(section.CONSUMABLE_IDS) ~= "table" then
            return copyOrder(source)
        end

        local tracked = {}
        for _, category in ipairs(CATEGORIES) do
            if category.catalog and frame[category.field] then
                for _, id in ipairs(section.CONSUMABLE_IDS[category.catalog] or {}) do
                    tracked[id] = true
                end
            end
        end
        for id in pairs(frame.customItems or {}) do
            tracked[id] = true
        end

        local existing, result = {}, {}
        for _, id in ipairs(source or {}) do
            existing[id] = true
            if tracked[id] then
                result[#result + 1] = id
            end
        end
        for id in pairs(tracked) do
            if not existing[id] then
                result[#result + 1] = id
            end
        end
        return result
    end

    local function currentOrder()
        local saved = frameDB("consumables").itemOrder
        local source = saved
        if not source or #source == 0 then
            source = defaultOrder()
        end
        return synchronizedOrder(source)
    end

    local function selectedIndex(order)
        if selectedItem == 0 then return nil end
        for index, id in ipairs(order) do
            if id == selectedItem then return index end
        end
    end

    local function selectedValue()
        if selectedIndex(currentOrder()) then return selectedItem end
        return 0
    end

    local function itemCategory(id)
        local section = consumablesSection()
        local catalog = section and section.CONSUMABLE_IDS or {}
        for _, category in ipairs(CATEGORIES) do
            if category.catalog then
                for index, catalogID in ipairs(catalog[category.catalog] or {}) do
                    if id == catalogID then
                        local rank
                        if category.catalog ~= "healthstone" and not addon.isForever then
                            rank = index % 2 == 1 and 1 or 2
                        end
                        return category.category, rank
                    end
                end
            end
        end
        return "Custom"
    end

    local function itemOptions()
        local options = {}
        local order = currentOrder()
        if #order == 0 then
            return { { value = 0, label = "No items" } }
        end
        options[#options + 1] = { value = 0, label = "Select an item" }
        for index, id in ipairs(order) do
            local name, link, icon
            if C_Item and C_Item.GetItemInfo then
                local info = { C_Item.GetItemInfo(id) }
                name, link, icon = info[1], info[2], info[10]
            end
            local category, rank = itemCategory(id)
            if not rank and category ~= "Healthstone"
                and C_TradeSkillUI and C_TradeSkillUI.GetItemCraftedQualityByItemInfo then
                rank = C_TradeSkillUI.GetItemCraftedQualityByItemInfo(link or id)
            end
            local label = tostring(index) .. ". " .. (name or ("Item #" .. tostring(id)))
                .. " (" .. category .. ")"
            if rank then
                label = label .. " |A:Professions-Icon-Quality-12-Tier"
                    .. tostring(rank) .. "-Small:14:14|a"
            end
            options[#options + 1] = {
                value = id,
                label = label,
                icon = icon or 134400,
            }
        end
        return options
    end

    local function frameCheckbox(key, field, label, default, extra)
        local config = {
            enabled = function() return sectionEnabled(key) end,
            guard = function() return sectionEnabled(key) end,
            watch = frameWatch(key),
        }
        for name, value in pairs(extra or {}) do
            config[name] = value
        end
        UI.Checkbox(page, frameID(key, field), label, default,
            function()
                local value = frameDB(key)[field]
                if value == nil then return default end
                return value == true
            end,
            function(value)
                frameDB(key)[field] = value
                changed()
            end,
            config)
    end

    local function buildSection(key)
        UI.Header(page, SECTION_NAMES[key])
        UI.Checkbox(page, frameID(key, "enabled"), "Enable " .. SECTION_NAMES[key], true,
            function() return frameDB(key).enabled == true end,
            function(value)
                frameDB(key).enabled = value
                changed()
            end,
            {
                enabled = trackerEnabled,
                guard = trackerEnabled,
                watch = { "combatTracker_enabled" },
            })

        local mergeOptions = { { label = "Standalone", value = "none" } }
        for _, other in ipairs(SECTION_KEYS) do
            if other ~= key then
                mergeOptions[#mergeOptions + 1] = {
                    label = "-> " .. SECTION_NAMES[other],
                    value = other,
                }
            end
        end

        local function standalone()
            return (frameDB(key).mergeInto or "none") == "none"
        end

        UI.Dropdown(page, frameID(key, "mergeInto"), "Merge into", "none",
            function() return frameDB(key).mergeInto or "none" end,
            function(value)
                if value == "none" then
                    frameDB(key).mergeInto = nil
                else
                    frameDB(key).mergeInto = value
                end
                changed()
            end,
            mergeOptions,
            {
                enabled = function() return sectionEnabled(key) end,
                guard = function() return sectionEnabled(key) end,
                watch = frameWatch(key),
                refresh = true,
            })

        UI.Dropdown(page, frameID(key, "layout"), "Layout", "horizontal",
            function() return frameDB(key).layout or "horizontal" end,
            function(value)
                frameDB(key).layout = value
                changed()
            end,
            LAYOUT_OPTIONS,
            {
                enabled = function() return sectionEnabled(key) end,
                guard = function() return sectionEnabled(key) and standalone() end,
                watch = frameWatch(key),
                shown = standalone,
                refresh = true,
            })

        UI.Dropdown(page, frameID(key, "gridCols"), "Icons per row", 2,
            function() return tonumber(frameDB(key).gridCols) or 2 end,
            function(value)
                frameDB(key).gridCols = value
                changed()
            end,
            COLUMN_OPTIONS,
            {
                enabled = function() return sectionEnabled(key) end,
                guard = function()
                    return sectionEnabled(key) and standalone() and frameDB(key).layout == "grid"
                end,
                watch = frameWatch(key),
                shown = function() return standalone() and frameDB(key).layout == "grid" end,
            })

        UI.Dropdown(page, frameID(key, "growDirection"), "Anchor direction", "growRight",
            function() return frameDB(key).growDirection or "growRight" end,
            function(value)
                frameDB(key).growDirection = value
                changed()
            end,
            GROW_OPTIONS,
            {
                enabled = function() return sectionEnabled(key) end,
                guard = function() return sectionEnabled(key) and standalone() end,
                watch = frameWatch(key),
                shown = standalone,
            })

        frameCheckbox(key, "desaturateOnCD", "Desaturate icon on cooldown", false)
    end

    UI.Header(page, "Combat Tracker")
    UI.Text(page, "Track racials, trinkets, and consumables. In Blizzard Edit Mode, click a highlighted section for icon and text appearance; merged sections use their host's text controls.")
    UI.Checkbox(page, "combatTracker_enabled", "Enable Combat Tracker", false,
        function() return db().enabled == true end,
        function(value)
            db().enabled = value
            changed()
        end)

    UI.Button(page, "Restore default frame positions", "Reset Positions", function()
        local positions = {
            racials = { x = -220, y = 200 },
            trinkets = { x = 0, y = 200 },
            consumables = { x = 220, y = 200 },
            foodWater = { x = 220, y = 140 },
        }
        for key, position in pairs(positions) do
            local frame = frameDB(key)
            frame.point, frame.x, frame.y = "CENTER", position.x, position.y
        end
        changed()
    end)

    buildSection("racials")
    UI.Text(page, "Choose which racial abilities to show.")
    local tracker = addon.combatTracker
    local racials = tracker and tracker.sections and tracker.sections.racials
    for _, entry in ipairs(racials and racials._allRacialNames or {}) do
        local name = entry.name
        if name then
            UI.Checkbox(page, "combatTracker_racials_hiddenSpells_" .. name, name, true,
                function() return db().racials.hiddenSpells[name] ~= true end,
                function(value)
                    db().racials.hiddenSpells[name] = not value and true or nil
                    changed()
                end,
                {
                    enabled = function() return sectionEnabled("racials") end,
                    guard = function() return sectionEnabled("racials") end,
                    watch = frameWatch("racials"),
                })
        end
    end

    buildSection("trinkets")
    frameCheckbox("trinkets", "onUseOnly", "On-use only (hide passive trinkets)", true)

    local function exclusionsText()
        local ids = {}
        for id in pairs(frameDB("trinkets").excludedItems or {}) do
            ids[#ids + 1] = id
        end
        table.sort(ids)
        for index, id in ipairs(ids) do ids[index] = tostring(id) end
        return table.concat(ids, ", ")
    end

    local function trinketsEnabled()
        return sectionEnabled("trinkets")
    end

    UI.Button(page, "Excluded trinket item IDs", "Edit Exclusions", function()
        UI.Input(page, "Exclude trinket item IDs (comma-separated)", exclusionsText(),
            function(text)
                if not trinketsEnabled() then
                    return false, "Enable the Trinkets section first."
                end
                local excluded = {}
                local trimmed = text:match("^%s*(.-)%s*$")
                if trimmed ~= "" then
                    if trimmed:sub(1, 1) == "," or trimmed:sub(-1) == ","
                        or trimmed:match(",%s*,") then
                        return false, "Enter positive integer item IDs separated by commas."
                    end
                    for token in trimmed:gmatch("[^,]+") do
                        local id = positiveInteger(token)
                        if not id then
                            return false, "Enter positive integer item IDs separated by commas."
                        end
                        excluded[id] = true
                    end
                end
                frameDB("trinkets").excludedItems = excluded
                changed()
                return true
            end,
            { guard = trinketsEnabled })
    end, {
        enabled = trinketsEnabled,
        guard = trinketsEnabled,
        watch = frameWatch("trinkets"),
    })
    UI.Text(page, function()
        local text = exclusionsText()
        return "Excluded trinkets: " .. (text ~= "" and text or "None")
    end)

    buildSection("consumables")
    frameCheckbox("consumables", "hideIfMissing", "Hide icon if not in inventory", true)
    UI.Text(page, "Track these consumable types:")
    for _, entry in ipairs(CATEGORIES) do
        local category = entry
        UI.Checkbox(page, frameID("consumables", category.field), category.label, category.default,
            function()
                local value = frameDB("consumables")[category.field]
                if value == nil then return category.default end
                return value == true
            end,
            function(value)
                local frame = frameDB("consumables")
                -- Materialize the old effective order before changing its tracked set.
                local order = currentOrder()
                frame[category.field] = value
                frame.itemOrder = synchronizedOrder(order)
                changed()
            end,
            {
                enabled = consumablesEnabled,
                guard = consumablesEnabled,
                watch = frameWatch("consumables"),
            })
    end

    UI.Dropdown(page, frameID("consumables", "foodWaterPreference"),
        "Same-level food/water preference", "itemLevel",
        function() return frameDB("consumables").foodWaterPreference or "itemLevel" end,
        function(value)
            frameDB("consumables").foodWaterPreference = value
            changed()
        end,
        {
            { label = "Highest item level", value = "itemLevel" },
            { label = "Most in bags", value = "quantity" },
        },
        {
            enabled = consumablesEnabled,
            guard = consumablesEnabled,
            watch = frameWatch("consumables"),
        })

    frameCheckbox("consumables", "preferMageFood", "Prefer mage food and water", false)
    frameCheckbox("consumables", "excludeBuffFood", "Exclude food that grants buffs", false, {
        tooltip = "Only verified restoration-only food effects are eligible. Buff-granting and unrecognized food effects are excluded, including food used by automatic water selection. Explicit Custom Items are unaffected.",
    })

    local function secureFoodWaterAvailable()
        return consumablesEnabled() and outOfCombat()
    end

    frameCheckbox("consumables", "clickableFoodWater", "Click food and water out of combat", false, {
        enabled = secureFoodWaterAvailable,
        guard = secureFoodWaterAvailable,
        events = COMBAT_EVENTS,
    })

    UI.Checkbox(page, frameID("foodWater", "enabled"), "Show food and water in a separate frame", false,
        function() return frameDB("foodWater").enabled == true end,
        function(value)
            frameDB("foodWater").enabled = value
            changed()
        end,
        {
            enabled = secureFoodWaterAvailable,
            guard = secureFoodWaterAvailable,
            watch = frameWatch("consumables"),
            events = COMBAT_EVENTS,
            tooltip = "Enter Blizzard Edit Mode and click MathWroQOL - CT Food & Water to move it and configure its own icon size and text settings.",
        })

    local function macroAvailable()
        return secureFoodWaterAvailable() and addon.combatTracker ~= nil
            and type(addon.combatTracker.CreateFoodWaterMacros) == "function"
    end

    UI.Button(page, "Food and water macros", "Create Smart Macro", function()
        local _, message = addon.combatTracker:CreateFoodWaterMacros()
        macroStatus = message
        UI.Refresh(page)
    end, {
        enabled = macroAvailable,
        guard = macroAvailable,
        watch = frameWatch("consumables"),
        events = COMBAT_EVENTS,
    })
    UI.Text(page, function() return macroStatus end)
    UI.Text(page, "Mage priority, when enabled, comes first. Highest required level wins within each group; Most in bags compares total counts at the same level.")

    UI.Header(page, "Item Display Order")
    UI.Button(page, "Restore the default item order", "Reset Order", function()
        frameDB("consumables").itemOrder = synchronizedOrder(defaultOrder())
        changed()
    end, {
        enabled = orderAvailable,
        guard = orderAvailable,
        watch = frameWatch("consumables"),
    })

    UI.Dropdown(page, frameID("consumables", "selectedItem"), "Selected item", nil,
        selectedValue,
        function(value)
            selectedItem = tonumber(value) or 0
            UI.Refresh(page)
        end,
        itemOptions,
        {
            variableType = "number",
            enabled = orderAvailable,
            guard = orderAvailable,
            watch = frameWatch("consumables"),
            events = { "GET_ITEM_INFO_RECEIVED" },
            refresh = true,
        })

    local function canMove(direction)
        if not orderAvailable() then return false end
        local order = currentOrder()
        local index = selectedIndex(order)
        return index ~= nil and index + direction >= 1 and index + direction <= #order
    end

    local function moveSelected(direction)
        local order = currentOrder()
        local index = selectedIndex(order)
        if not index or index + direction < 1 or index + direction > #order then return end
        order[index], order[index + direction] = order[index + direction], order[index]
        frameDB("consumables").itemOrder = order
        changed()
    end

    local selectionWatch = {
        "combatTracker_enabled",
        frameID("consumables", "enabled"),
        frameID("consumables", "selectedItem"),
    }
    UI.Button(page, "Move selected item earlier", "Move Up", function()
        moveSelected(-1)
    end, {
        enabled = function() return canMove(-1) end,
        guard = function() return canMove(-1) end,
        watch = selectionWatch,
    })
    UI.Button(page, "Move selected item later", "Move Down", function()
        moveSelected(1)
    end, {
        enabled = function() return canMove(1) end,
        guard = function() return canMove(1) end,
        watch = selectionWatch,
    })

    local function canRemove()
        if not orderAvailable() or not selectedIndex(currentOrder()) then return false end
        return itemCategory(selectedItem) == "Custom"
    end

    UI.Button(page, "Remove selected custom item", "Remove", function()
        local id = selectedItem
        local order = currentOrder()
        local index = selectedIndex(order)
        if not index then return end
        local frame = frameDB("consumables")
        if frame.customItems then frame.customItems[id] = nil end
        table.remove(order, index)
        frame.itemOrder = order
        selectedItem = 0
        changed()
    end, {
        enabled = canRemove,
        guard = canRemove,
        watch = selectionWatch,
    })

    UI.Button(page, "Add a custom item by item ID", "Add", function()
        UI.Input(page, "Add custom item ID", "", function(text)
            if not orderAvailable() then
                return false, "The consumable catalog is unavailable or the section is disabled."
            end
            local id = positiveInteger(text)
            if not id then return false, "Enter a positive integer item ID." end
            local order = currentOrder()
            local frame = frameDB("consumables")
            frame.customItems = frame.customItems or {}
            frame.customItems[id] = true
            local found = false
            for _, existingID in ipairs(order) do
                if existingID == id then
                    found = true
                    break
                end
            end
            if not found then order[#order + 1] = id end
            frame.itemOrder = synchronizedOrder(order)
            selectedItem = id
            changed()
            return true
        end, { guard = orderAvailable })
    end, {
        enabled = orderAvailable,
        guard = orderAvailable,
        watch = frameWatch("consumables"),
    })

    UI.Header(page, "Masque")
    local function masqueAvailable()
        return LibStub ~= nil and LibStub("Masque", true) ~= nil
    end
    local function masqueEnabled()
        return trackerEnabled() and masqueAvailable()
    end

    UI.Checkbox(page, "combatTracker_masque_enabled", "Enable Masque skinning", false,
        function() return db().masque.enabled == true end,
        function(value)
            db().masque.enabled = value
            changed()
        end,
        {
            enabled = masqueEnabled,
            guard = masqueEnabled,
            watch = { "combatTracker_enabled" },
            events = { "ADDON_LOADED" },
        })
    UI.Text(page, function()
        if masqueAvailable() then
            return "When enabled, Masque groups appear under MathWroQOL: CT Racials, CT Trinkets, CT Consumables."
        end
        return "Install the Masque addon to enable icon skinning."
    end)

    return page
end