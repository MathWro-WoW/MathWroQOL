-- Developer-only smoke test for content-scoped combat logging.
-- This file is outside MathWroQOL.toc and is never loaded by the addon.

local eventFrame
local inInstance = false
local instanceType
local difficultyID = 1
local combatLogging = false
local loggingChanges = {}
local playerLevel = 80
local maxLevel = 80
local originalPrint = print

function CreateFrame(kind)
    assert(kind == "Frame")
    eventFrame = { events = {} }

    function eventFrame:RegisterEvent(event)
        self.events[event] = true
    end

    function eventFrame:SetScript(script, callback)
        self[script] = callback
    end

    return eventFrame
end

function IsInInstance()
    return inInstance, instanceType
end

function GetInstanceInfo()
    return nil, nil, difficultyID
end

function LoggingCombat(enabled)
    if enabled == nil then return combatLogging end

    combatLogging = enabled
    loggingChanges[#loggingChanges + 1] = enabled
end

function UnitLevel(unit)
    assert(unit == "player")
    return playerLevel
end

function GetMaxLevelForPlayerExpansion()
    return maxLevel
end

function print() end

local addon = {
    db = {
        combatLog = {
            dungeon = false,
            mythicPlus = false,
            raid = true,
            scenario = false,
            pvp = false,
            arena = false,
            maxLevelOnly = false,
        },
    },
}

function addon:RegisterFeature(feature)
    self.feature = feature
end

local function fireEvent(event)
    if eventFrame.events[event] then
        eventFrame:OnEvent(event)
    end
end

local function transition(isInInstance, newInstanceType, newDifficultyID)
    inInstance = isInInstance
    instanceType = newInstanceType
    difficultyID = newDifficultyID or 1
    fireEvent("ZONE_CHANGED_NEW_AREA")
end

assert(loadfile("Features/CombatLog.lua"))("MathWroQOL", addon)
assert(addon.feature, "CombatLog did not register")
assert(eventFrame and eventFrame.OnEvent, "combat-log events were not registered")

transition(true, "raid")
assert(combatLogging, "enabling Raid must start logging when entering a raid")
assert(loggingChanges[#loggingChanges] == true, "raid entry must enable logging")

transition(true, "party")
assert(not combatLogging, "entering a disabled dungeon must stop raid-started logging")
assert(loggingChanges[#loggingChanges] == false, "disabled content must disable addon-started logging")

transition(true, "raid")
assert(combatLogging, "re-entering a raid must restart logging")
addon.db.combatLog.dungeon = true
transition(true, "party", 8)
assert(not combatLogging, "Dungeon must not start logging in Mythic+")

addon.db.combatLog.dungeon = false
addon.db.combatLog.mythicPlus = true
transition(true, "party", 8)
assert(combatLogging, "Mythic+ must start logging in a keystone dungeon")
transition(true, "party", 1)
assert(not combatLogging, "Mythic+ must not start logging in a non-keystone dungeon")

-- Starting a key changes difficulty in place, without another zone transition.
for _, dungeonDifficulty in ipairs({ 1, 2, 23, 24 }) do
    transition(true, "party", dungeonDifficulty)
    assert(not combatLogging, "Mythic+ alone must exclude normal, heroic, Mythic 0, and timewalking")
end
transition(true, "party", 23)
difficultyID = 8
fireEvent("CHALLENGE_MODE_START")
assert(combatLogging, "starting a keystone in place must enable Mythic+-only logging")
local changesAfterKeyStart = #loggingChanges
fireEvent("CHALLENGE_MODE_START")
assert(#loggingChanges == changesAfterKeyStart, "duplicate key events must not restart logging")
difficultyID = 23
fireEvent("CHALLENGE_MODE_RESET")
assert(not combatLogging, "resetting to Mythic 0 must stop Mythic+-only logging")

addon.db.combatLog.mythicPlus = false
addon.db.combatLog.dungeon = true
transition(true, "party", 23)
assert(combatLogging, "Dungeon alone must log Mythic 0")
difficultyID = 8
fireEvent("CHALLENGE_MODE_START")
assert(not combatLogging, "Dungeon alone must stop logging when a keystone starts")
addon.db.combatLog.dungeon = false
addon.db.combatLog.mythicPlus = true
transition(false)

local categories = {
    { instanceType = "party", difficultyID = 1, setting = "dungeon" },
    { instanceType = "party", difficultyID = 8, setting = "mythicPlus" },
    { instanceType = "raid", setting = "raid" },
    { instanceType = "scenario", setting = "scenario" },
    { instanceType = "pvp", setting = "pvp" },
    { instanceType = "arena", setting = "arena" },
}

for _, category in ipairs(categories) do
    addon.db.combatLog[category.setting] = true
end

for _, source in ipairs(categories) do
    transition(false)
    transition(true, source.instanceType, source.difficultyID)
    assert(combatLogging, source.instanceType .. " entry must start logging")

    local changesBeforeTransitions = #loggingChanges
    for _, target in ipairs(categories) do
        transition(true, target.instanceType, target.difficultyID)
        assert(combatLogging, source.instanceType .. " to " .. target.instanceType
            .. " must keep logging active")
        assert(#loggingChanges == changesBeforeTransitions, source.instanceType .. " to "
            .. target.instanceType .. " must not stop or restart logging")
    end
end

addon.db.combatLog.dungeon = false

LoggingCombat(false)
local changesAfterManualStop = #loggingChanges
transition(true, "raid")
assert(not combatLogging, "manual stop must suppress restart within the instance session")
assert(#loggingChanges == changesAfterManualStop, "manual stop must not be overridden")

transition(false)
transition(true, "raid")
assert(combatLogging, "leaving instances must clear the manual-stop suppression")

addon.db.combatLog.maxLevelOnly = true
playerLevel = 79
transition(true, "raid")
assert(not combatLogging, "max-level gate must stop addon-started logging")

addon.db.combatLog.maxLevelOnly = false
playerLevel = maxLevel
LoggingCombat(true)
transition(true, "party")
assert(combatLogging, "disabled content must not stop manually started logging")

originalPrint("CombatLog content transition smoke test: PASS")
