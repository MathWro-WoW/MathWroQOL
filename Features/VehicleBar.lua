local _, addon = ...
if not ElvUI then return end  -- skip all feature code if ElvUI is not loaded

local VehicleBar = { name = "vehicleBar" }
addon:RegisterFeature(VehicleBar)

-- Remove vehicle-related hide tokens from a visibility condition string.
-- ElvUI default: "[vehicleui][petbattle][overridebar] hide; show"
-- In most vehicle encounters both [vehicleui] and [overridebar] are active,
-- so we strip all three vehicle tokens to keep the bar visible.
local function stripVehicleHide(condition)
    local result = condition
    result = result:gsub("%[vehicleui%]", "")   -- vehicle UI active
    result = result:gsub("%[overridebar%]", "") -- override action bar (common in vehicle encounters)
    result = result:gsub("%[possessbar%]", "")  -- possess/mind-control bar
    result = result:gsub("[ \t]+;", ";")        -- clean extra spaces before semicolons
    result = result:gsub(";%s*;", ";")          -- collapse double semicolons
    result = result:gsub("^%s*;%s*", "")        -- trim any leading semicolon
    result = result:gsub("%s+", " ")            -- normalise whitespace
    return result
end

-- Guard flag to prevent our own RegisterStateDriver calls from re-triggering the hook.
local applying = false

-- Returns true when an override or vehicle bar is active AND it has at least
-- one populated action slot (filters out taxis, RP vehicles, etc.).
local function isVehicleLikeWithAbilities()
    if not (HasOverrideActionBar() or HasVehicleActionBar() or IsPossessBarVisible()) then
        return false
    end
    local barIndex = GetOverrideBarIndex() or GetVehicleBarIndex()
    if not barIndex then return false end
    local baseSlot = (barIndex - 1) * NUM_ACTIONBAR_BUTTONS
    for i = 1, NUM_ACTIONBAR_BUTTONS do
        if HasAction(baseSlot + i) then
            return true
        end
    end
    return false
end

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

-- Force all enabled mouseover bars fully visible. Called on vehicle-like entry.
local function forceShowEnabledBars()
    local E = ElvUI[1]
    if not E then return end
    local db = addon.db.vehicleBar
    if not db or not db.enabled then return end
    for i, enabled in pairs(db.bars) do
        if enabled then
            local bar = _G["ElvUI_Bar"..i]
            if bar and bar.mouseover then
                E:UIFrameFadeIn(bar, 0.2, bar:GetAlpha(), (bar.db and bar.db.alpha) or 1)
            end
        end
    end
end

-- Fade out enabled mouseover bars back to hidden. Called on vehicle-like exit.
local function forceHideEnabledBars()
    local E = ElvUI[1]
    if not E then return end
    local db = addon.db.vehicleBar
    if not db or not db.enabled then return end
    for i, enabled in pairs(db.bars) do
        if enabled then
            local bar = _G["ElvUI_Bar"..i]
            if bar and bar.mouseover then
                E:UIFrameFadeOut(bar, 0.2, bar:GetAlpha(), 0)
            end
        end
    end
end

function VehicleBar:Initialize()
    -- Hook RegisterStateDriver to strip vehicle hide conditions from visibility drivers.
    hooksecurefunc("RegisterStateDriver", onStateDriverRegistered)

    local E = ElvUI[1]

    -- Bars using ElvUI's individual mouseover fade are NOT covered by ElvUI's own
    -- vehicle mouseLock (which only protects the global fade parent). Hook
    -- UIFrameFadeOut to cancel any fade-out targeting a selected bar while in a vehicle.
    if E and E.UIFrameFadeOut then
        hooksecurefunc(E, "UIFrameFadeOut", function(self, frame, fadeTime, startAlpha, endAlpha)
            if not isVehicleLikeWithAbilities() then return end
            local db = addon.db.vehicleBar
            if not db or not db.enabled then return end
            for i, enabled in pairs(db.bars) do
                if enabled and frame == _G["ElvUI_Bar"..i] and frame.mouseover then
                    -- Overwrite the fade-out with a fade-in before the FadeManager
                    -- processes its first OnUpdate tick — effectively a no-op fade.
                    E:UIFrameFadeIn(frame, 0.1, frame:GetAlpha(), (frame.db and frame.db.alpha) or 1)
                    break
                end
            end
        end)
    end

    -- Force bars visible on vehicle-like entry; fade them back out on exit.
    -- UPDATE_OVERRIDE_ACTIONBAR fires on both override bar entry and exit.
    -- UNIT_ENTERED_VEHICLE / UNIT_EXITED_VEHICLE cover traditional vehicle UI.
    local vehicleEvents = CreateFrame("Frame")
    vehicleEvents:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
    vehicleEvents:RegisterEvent("VEHICLE_UPDATE")
    vehicleEvents:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", "player")
    vehicleEvents:RegisterUnitEvent("UNIT_EXITED_VEHICLE", "player")
    vehicleEvents:SetScript("OnEvent", function(self, event)
        if isVehicleLikeWithAbilities() then
            forceShowEnabledBars()
        else
            forceHideEnabledBars()
        end
    end)

    -- Handle reload-while-already-in-vehicle-like-state.
    if isVehicleLikeWithAbilities() then
        forceShowEnabledBars()
    end

    self:Apply()
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
