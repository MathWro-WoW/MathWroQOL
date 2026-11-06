local _, addon = ...
local CT = addon.combatTracker
local eventFrame
local names = { food = "MQOL Food", water = "MQOL Water" }
local kinds = { "food", "water" }
local markers = { food = "# MathWroQOL food\n", water = "# MathWroQOL water\n" }
local QUESTION_MARK = 134400

local function settings()
    return addon.db.combatTracker.frames.consumables
end

-- Account indices can shift when a macro is created or renamed. Resolve names
-- afresh, and require our ownership marker rather than trusting a matching name.
local function findMacros()
    local found = {}
    local count = GetNumMacros()
    for index = 1, count do
        local name, _, body = GetMacroInfo(index)
        local kind = name == names.food and "food" or name == names.water and "water"
        if kind then
            if found[kind] or not body or body:sub(1, #markers[kind]) ~= markers[kind] then
                return nil, "A General macro named " .. name .. " already exists and is not uniquely owned by MathWroQOL. Rename it first."
            end
            found[kind] = index
        end
    end
    return found
end

local function macroBody(kind)
    local db = addon.db.combatTracker
    local consumables = CT.sections.consumables
    local selected = kind == "food" and consumables.selectedFood or nil
    if kind == "water" then selected = consumables.selectedWater end
    local frameDb = db.frames.consumables
    local shown = kind == "food" and frameDb.showFood or kind == "water" and frameDb.showWater
    local body = markers[kind] .. "#showtooltip"
    if db.enabled and frameDb.enabled and shown and selected then
        local item = "item:" .. selected.itemID
        body = body .. " " .. item .. "\n/use [nocombat] " .. item
    end
    return body
end

local function ensureEvents()
    if eventFrame then return end
    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", function()
        if not settings().smartFoodWaterMacros then return end
        local db = addon.db.combatTracker
        if db.enabled and settings().enabled then CT.sections.consumables:ScanBags() end
        CT:UpdateFoodMacros()
    end)
end

function CT:UpdateFoodMacros()
    if not settings().smartFoodWaterMacros then return end
    ensureEvents()
    if InCombatLockdown() then return end
    local found, message = findMacros()
    if not found then return false, message end
    for _, kind in ipairs(kinds) do
        local index = found[kind]
        if index then
            local _, _, current = GetMacroInfo(index)
            local body = macroBody(kind)
            if current ~= body then EditMacro(index, nil, nil, body) end
        end
    end
    return true
end

function CT:CreateFoodWaterMacros()
    if InCombatLockdown() then return false, "Leave combat before creating food and water macros." end
    local found, message = findMacros()
    if not found then return false, message end
    local missing = (found.food and 0 or 1) + (found.water and 0 or 1)
    if GetNumMacros() + missing > MAX_ACCOUNT_MACROS then
        return false, "Not enough General macro slots. Free " .. missing .. " slot(s), then try again."
    end
    CT.sections.consumables:ScanBags()
    for _, kind in ipairs(kinds) do
        -- Creating the first macro may reorder an existing second macro.
        found, message = findMacros()
        if not found then return false, message end
        if not found[kind] then
            if not CreateMacro(names[kind], QUESTION_MARK, macroBody(kind), nil) then
                return false, "Could not create " .. names[kind] .. ". Try Create Smart Macro again."
            end
        end
    end
    settings().smartFoodWaterMacros = true
    local updated, updateMessage = self:UpdateFoodMacros()
    if not updated then return false, updateMessage end
    return true, "MQOL Food and MQOL Water are ready in General Macros. Drag them onto your action bars; they follow the current character's selected food and water."
end
