-- Native ProxySettingMixin validates function defaults by calling them directly.
-- That call occurs before SettingsPanel stores the setting in its shared registry.
-- Source: Forever 1.60.1.71037, 734f0653, Blizzard_Settings_Shared/Blizzard_Setting.lua.
local H = dofile("tests/SettingsHarness.lua")
local addon = H.load(16001)
local UI = addon.SettingsUI
local nativeRegister = Settings.RegisterProxySetting
local validating, contaminated = false, false
Settings.RegisterProxySetting = function(category, variable, valueType, name, default, get, set)
    validating = true
    -- The real GetDefaultValueType/GetOrCallDefaultValue boundary, not an
    -- assumption that native registration isolates arbitrary addon callbacks.
    if type(default) == "function" then default() end
    validating = false
    return nativeRegister(category, variable, valueType, name, default, get, set)
end
local selected = "first"
local enabled = { first = false, second = true }
local colors = { first = { r = 0, g = 0, b = 0 }, second = { r = 0, g = 0, b = 0 } }
local function defaultEnabled()
    if validating then contaminated = true end
    return selected == "first"
end
local function defaultColor()
    if validating then contaminated = true end
    if selected == "first" then return { r = 1, g = 0, b = 0 } end
    return { r = 0, g = 1, b = 0 }
end
local page = UI.Page(nil, "Taint boundary")
UI.Checkbox(page, "dynamic_enabled", "Selected profile", defaultEnabled,
    function() return enabled[selected] end, function(value) enabled[selected] = value end)
UI.Color(page, "dynamic_color", "Selected color", defaultColor,
    function() return colors[selected] end, function(value) colors[selected] = value end)
assert(not contaminated, "native registration validation must not execute addon default callbacks in its own context")
assert(not enabled.first and enabled.second and colors.first.r == 0,
    "resolving registration metadata must not apply defaults or alter saved choices")
selected = "second"
H.setting("dynamic_enabled"):SetValueToDefault()
H.setting("dynamic_color"):SetValueToDefault()
assert(not enabled.second and colors.second.r == 0 and colors.second.g == 1 and colors.second.b == 0,
    "Defaults must resolve against the selected profile, not freeze registration-time defaults")
assert(not enabled.first and colors.first.r == 0 and colors.first.g == 0,
    "resetting one profile must leave the other profile unchanged")
selected = "first"
H.setting("dynamic_enabled"):SetValueToDefault()
H.setting("dynamic_color"):SetValueToDefault()
assert(enabled.first and colors.first.r == 1 and colors.first.g == 0,
    "switching back must retain dynamic boolean and color default behavior")
print("Config callable-default taint boundary smoke: PASS")
