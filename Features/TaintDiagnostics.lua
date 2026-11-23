local addonName, addon = ...
local Diagnostics = { name = "taintDiagnostics" }
addon:RegisterFeature(Diagnostics)

local SETTING_FIELDS = { "variable", "GetVariable", "GetValue", "GetValueDerived", "getValue", "pendingValue" }
local CACHE_ENTRIES = { "MultiActionBar_GetBarForPage", "MultiActionBar_Update",
    "MultiActionBar_ShowAllGrids", "MultiActionBar_HideAllGrids" }
local METADATA_OBJECTS = { "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MicroMenuContainer",
    "EditModeManagerFrame", "EditModePresetLayoutManager", "EditModeUtil", "InputUtil", "C_InputInterfaceStyle" }
local LAYOUT_GLOBALS = { "CopyTable", "ACTION_BARS_RELATIVE_TO_BASE_POSITIONING",
    "MAIN_ACTION_BAR_OFFSET_X", "MAIN_ACTION_BAR_OFFSET_Y", "BOTTOM_ACTION_BARS_SPACER_Y" }
local ACTION_FIELDS = { "action", "popupDirection", "feedback_action", "UpdateAction", "OnEvent" }
local WATCHED = {
    ActionButton7 = ACTION_FIELDS,
    ActionButton10 = ACTION_FIELDS,
    MainActionBar = { "snappedToFrame", "flyoutDirection", "systemInfo", "SetPoint" },
    MultiBarBottomLeft = { "isShownExternal", "editModeForceShow", "visibility", "systemInfo", "isHorizontal" },
    SettingsPanel = { "settings", "GetSetting" },
    EditModeManagerFrame = { "editModeSystemAnchorDirty", "layoutApplyInProgress", "registeredSystemFrames" },
}
local PROBES = { snappedToFrame = "SetSnappedToFrame", flyoutDirection = "UpdateSpellFlyoutDirection" }
local current, eventFrame, hooked, cacheHooked

local function enabled()
    return addon.db and addon.db.taintDiagnostics and addon.db.taintDiagnostics.enabled
end

local function message(text)
    print("MQOL taint: " .. text)
end

local function stack()
    return debugstack(3, 20, 10):sub(1, 8192)
end

-- Fixed native UI objects only; no frame enumeration, recursive traversal, or
-- gameplay values. Retain only our tainted string-key fields and cap each walk.
local function metadataSnapshot()
    local result = {}
    local function inspect(name, object)
        if type(object) ~= "table" then result[name] = { unavailable = true }; return end
        local record = { fields = {}, scanned = 0 }
        for key in pairs(object) do
            if type(key) == "string" then
                if record.scanned == 512 then record.truncated = true; break end
                record.scanned = record.scanned + 1
                local _, owner = issecurevariable(object, key)
                if owner == addonName then record.fields[key] = owner end
            end
        end
        result[name] = record
    end
    for _, name in ipairs(METADATA_OBJECTS) do inspect(name, _G[name]) end
    local manager = EditModeManagerFrame
    local layout = manager and manager.layoutInfo
    inspect("EditModeManagerFrame.layoutInfo", layout)
    if type(layout) == "table" and type(layout.layouts) == "table" then
        inspect("activeLayout", layout.layouts[layout.activeLayout])
    end
    local bar = MainActionBar
    inspect("MainActionBar.systemInfo", bar and bar.systemInfo)
    if bar then
        for _, name in ipairs({ "EDIT_MODE_MODERN_SYSTEM_MAP", "EDIT_MODE_CLASSIC_SYSTEM_MAP" }) do
            local map = _G[name]
            local system = type(map) == "table" and map[bar.system] or nil
            if type(system) == "table" and bar.systemIndex then system = system[bar.systemIndex] end
            inspect(name .. ".MainActionBar", system)
            inspect(name .. ".MainActionBar.anchorInfo", type(system) == "table" and system.anchorInfo or nil)
        end
    end
    result.globals = {}
    for _, name in ipairs(LAYOUT_GLOBALS) do
        local secure, owner = issecurevariable(_G, name)
        result.globals[name] = secure and "secure-or-unset" or owner or "unknown"
    end
    return result
end

-- Inspect ownership only: never read live action/aura values or change native fields.
local function snapshot(extraName)
    local result = {}
    result.metadata = metadataSnapshot()
    local function inspectFrame(frame, fields)
        if not frame then return { unavailable = true } end
        local owners = {}
        for _, field in ipairs(fields) do
            local secure, owner = issecurevariable(frame, field)
            owners[field] = secure and "secure-or-unset" or owner or "unknown"
        end
        return owners
    end
    local function inspect(name, fields)
        result[name] = inspectFrame(_G[name], fields)
    end
    for name, fields in pairs(WATCHED) do inspect(name, fields) end
    -- These lookups are read-only; inspect the native setting objects, never
    -- invoke their value getters or change their registration.
    if Settings and Settings.GetSetting then
        for index = 2, 8 do
            local variable = "PROXY_SHOW_ACTIONBAR_" .. index
            result[variable] = inspectFrame(Settings.GetSetting(variable), SETTING_FIELDS)
        end
    end
    if extraName and not result[extraName] then inspect(extraName, ACTION_FIELDS) end
    return result
end

local function observe(frame, field, method, preexisting)
    if not enabled() or not current or current.probes[field] then return end
    local _, owner = issecurevariable(frame, field)
    if owner ~= addonName then return end
    current.probes[field] = {
        observation = preexisting and "already-tainted" or "posthook",
        method = method,
        elapsed = GetTime() - current.startedAt,
        stack = not preexisting and stack() or nil,
        frames = snapshot(),
    }
    message("recorded " .. field .. (preexisting and " (already tainted; reload for startup capture)." or "."))
end

local function captureBlocked(_, event, name, action)
    if not enabled() or name ~= addonName then return end
    current.blockedCount = current.blockedCount + 1
    if current.firstBlocked then return end
    local frameName = action and action:match("^([^:]+):")
    current.firstBlocked = {
        event = event,
        action = action,
        elapsed = GetTime() - current.startedAt,
        combat = InCombatLockdown(),
        stack = stack(),
        frames = snapshot(frameName),
    }
    message("saved first blocked action. Log out to flush SavedVariables; /mqoltaint off stops capture.")
end

function Diagnostics:Apply()
    if not enabled() then
        if eventFrame then eventFrame:UnregisterAllEvents() end
        return
    end
    if not current then
        local version, build, _, interface = GetBuildInfo()
        local db = addon.db
        current = {
            startedAt = GetTime(),
            date = date("%Y-%m-%d %H:%M:%S"),
            clientVersion = version,
            build = build,
            interface = interface,
            addonVersion = C_AddOns.GetAddOnMetadata(addonName, "Version"),
            settings = {
                nativeNudge = db.editModeNudge.enabled,
                ellesmereNudge = db.editModeNudge.ellesmereEnabled,
                vehicleBar = db.vehicleBar.enabled,
                foodMacros = db.combatTracker.frames.consumables.smartFoodWaterMacros,
            },
            initial = snapshot(),
            probes = {},
            blockedCount = 0,
        }
        db.taintDiagnostics.previous = db.taintDiagnostics.current
        db.taintDiagnostics.current = current
    end
    local bar = MainActionBar
    if bar and not hooked then
        hooked = true
        current.hooks = {}
        for field, method in pairs(PROBES) do
            -- Each retained post-hook performs one ownership query until captured,
            -- then returns. No timers, frame enumeration, or native field writes.
            if type(bar[method]) == "function" then
                current.hooks[method] = true
                hooksecurefunc(bar, method, function(self)
                    observe(self, field, method, false)
                end)
            end
            observe(bar, field, "startup", true)
        end
    end
    if not cacheHooked then
        cacheHooked = true
        for _, name in ipairs(CACHE_ENTRIES) do
            if type(_G[name]) == "function" then
                hooksecurefunc(_G, name, function()
                    if not enabled() or current.firstBarCacheCall then return end
                    current.firstBarCacheCall = {
                        method = name,
                        elapsed = GetTime() - current.startedAt,
                        stack = stack(),
                        frames = snapshot(),
                    }
                end)
            end
        end
    end
    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        eventFrame:SetScript("OnEvent", captureBlocked)
    end
    eventFrame:RegisterEvent("ADDON_ACTION_BLOCKED")
    eventFrame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
end

function Diagnostics:Initialize()
    self:Apply()
end

SLASH_MQOLTAINT1 = "/mqoltaint"
SlashCmdList.MQOLTAINT = function(text)
    local command = text:lower():match("^%s*(%S+)")
    local db = addon.db.taintDiagnostics
    if command == "on" then
        db.enabled = true
        Diagnostics:Apply()
        message("enabled. /reload once to capture startup from a clean UI. Global taint logging is not needed.")
    elseif command == "off" then
        db.enabled = false
        Diagnostics:Apply()
        message("disabled; saved captures retained.")
    else
        local saved = db.current
        message((db.enabled and "enabled" or "disabled") .. "; blocked actions: " .. (saved and saved.blockedCount or 0)
            .. ". Use /mqoltaint on or off. Data: MathWroQOLDB.taintDiagnostics in SavedVariables/MathWroQOL.lua.")
    end
end
