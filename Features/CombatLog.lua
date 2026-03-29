local _, addon = ...

local CombatLog = { name = "combatLog" }
addon:RegisterFeature(CombatLog)

local startedByAddon = false
local manuallyDisabled = false

local instanceTypeToKey = {
    party    = "dungeon",
    raid     = "raid",
    scenario = "scenario",
    pvp      = "pvp",
    arena    = "arena",
}

local function onZoneTransition()
    local db = addon.db and addon.db.combatLog
    if not db then return end

    local inInstance, instanceType = IsInInstance()

    if not inInstance then
        if startedByAddon and LoggingCombat() then
            LoggingCombat(false)
            print("[MathWro QOL] Combat logging stopped.")
        end
        startedByAddon = false
        manuallyDisabled = false
        return
    end

    -- Detect manual stop: we started it but it's no longer running
    if startedByAddon and not LoggingCombat() then
        manuallyDisabled = true
    end

    local key = instanceTypeToKey[instanceType]
    if key and db[key] and not manuallyDisabled and not LoggingCombat() then
        LoggingCombat(true)
        startedByAddon = true
        print("[MathWro QOL] Combat logging started.")
    end
end

-- Register at top level so the frame exists before any zone events fire.
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:SetScript("OnEvent", function(self, event)
    onZoneTransition()
end)

function CombatLog:Initialize()
    -- Event frame registered at top level; nothing to do here.
end

function CombatLog:Apply()
    -- Settings only take effect on next zone transition; nothing to re-apply now.
end
