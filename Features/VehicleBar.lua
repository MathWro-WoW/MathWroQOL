local _, addon = ...
if not ElvUI then return end  -- skip all feature code if ElvUI is not loaded

local VehicleBar = { name = "vehicleBar" }
addon:RegisterFeature(VehicleBar)

-- Remove [vehicleui] tokens from a visibility condition string.
-- ElvUI visibility strings look like: "[vehicleui] hide; [petbattle] hide; show"
-- We want to strip the [vehicleui] token so the bar stays visible in vehicles.
local function stripVehicleHide(condition)
    local result = condition
    result = result:gsub("%[vehicleui%]", "")   -- remove the token
    result = result:gsub("[ \t]+;", ";")        -- clean extra spaces before semicolons
    result = result:gsub(";%s*;", ";")          -- collapse double semicolons
    result = result:gsub("^%s*;%s*", "")        -- trim any leading semicolon
    result = result:gsub("%s+", " ")            -- normalise whitespace
    return result
end

-- Guard flag to prevent our own RegisterStateDriver calls from re-triggering the hook.
local applying = false

local function onStateDriverRegistered(frame, attribute, condition)
    if applying or attribute ~= "visibility" then return end
    local db = addon.db
    if not db or not db.vehicleBar.enabled then return end

    for i, enabled in pairs(db.vehicleBar.bars) do
        if enabled and frame == _G["ElvUI_Bar"..i] then
            local newCondition = stripVehicleHide(condition)
            if newCondition ~= condition then
                applying = true
                RegisterStateDriver(frame, attribute, newCondition)
                applying = false
            end
            break
        end
    end
end

function VehicleBar:Initialize()
    -- Hook RegisterStateDriver globally. Our callback fires after ElvUI's call,
    -- and we immediately re-register with the vehicleui condition stripped.
    hooksecurefunc("RegisterStateDriver", onStateDriverRegistered)
end

-- Called when settings change. Triggers ElvUI to re-run PositionAndSizeBar on all
-- bars, which re-registers state drivers, causing our hook to fire again.
function VehicleBar:Apply()
    if not ElvUI then return end
    local E = unpack(ElvUI)
    local AB = E and E:GetModule("ActionBars", true)
    if AB and AB.UpdateButtonSettings then
        AB:UpdateButtonSettings()
    end
end
