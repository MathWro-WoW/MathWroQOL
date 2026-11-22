-- Retail-only features must stay inert on Forever; camera settings use modern C_CVar APIs.
local frames = {}
function CreateFrame()
    local frame = { events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetScript(_, callback) self.callback = callback end
    frames[#frames + 1] = frame
    return frame
end

local function loadFeature(path, addon)
    assert(loadfile(path))("MathWroQOL", addon)
end

local function loadClient(interfaceVersion)
    frames = {}
    SlashCmdList = {}
    GetBuildInfo = function() return nil, nil, nil, interfaceVersion end
    local addon = {}
    loadFeature("Core.lua", addon)
    local coreFrame = frames[1]
    coreFrame.callback(coreFrame, "ADDON_LOADED", "MathWroQOL")
    addon.db.heroicStrike.enabled = true
    addon.db.folioEquipmentSets.enabled = true
    loadFeature("Features/HeroicStrike.lua", addon)
    loadFeature("Features/FolioEquipmentSets.lua", addon)
    return addon, #frames
end

local forever, foreverFrames = loadClient(16001)
assert(#forever.features == 0, "enabled Retail-only Forever settings must not register features")
assert(foreverFrames == 1, "Retail-only Forever features must not allocate frames")
assert(forever.folioEquipmentSets == nil, "Forever must not expose Folio feature globally")

local retail = loadClient(120100)
assert(#retail.features == 2, "Retail must register both Retail-only features")
assert(retail.folioEquipmentSets ~= nil, "Retail must expose Folio feature")

for _, client in ipairs({ forever, retail }) do
    client.db.bloodlustTracker.enabled = true
    loadFeature("Features/ExternalTracker.lua", client)
    local bloodlust
    for _, feature in ipairs(client.features) do
        if feature.name == "bloodlustTracker" then bloodlust = feature end
    end
    assert((bloodlust ~= nil) == (not client.isForever),
        "Bloodlust runtime must register only on Retail, regardless of saved enabled state")
    assert(client.db.bloodlustTracker.enabled, "client gating must preserve saved preferences")
    assert(client.externalTracker, "shared external tracker must remain available on both clients")
end

local function checkCameraDistance(addon, expectedValue)
    local getCalls, setCalls = 0, 0
    local cameraValue = "2.0"
    GetCVar = function() error("camera settings must not use global GetCVar") end
    SetCVar = function() error("camera settings must not use global SetCVar") end
    C_CVar = {
        GetCVar = function(name)
            assert(name == "cameraDistanceMaxZoomFactor")
            getCalls = getCalls + 1
            return cameraValue
        end,
        SetCVar = function(name, value)
            assert(name == "cameraDistanceMaxZoomFactor")
            setCalls = setCalls + 1
            cameraValue = value
        end,
    }
    addon.db.cameraDistance.enabled = true
    loadFeature("Features/CVarSettings.lua", addon)
    local camera = addon.features[#addon.features - 1]
    camera:Initialize()
    assert(cameraValue == expectedValue, "login must restore the client-specific camera maximum")
    camera:Apply()
    assert(getCalls == 2 and setCalls == 1, "camera setting must avoid redundant writes")
    addon.db.cameraDistance.enabled = false
    cameraValue = "1.5"
    camera:Apply()
    assert(cameraValue == "1.5" and getCalls == 2 and setCalls == 1,
        "disabled camera setting must not read or write")
    addon.db.cameraDistance.enabled = true
    camera:Apply()
    assert(cameraValue == expectedValue, "enabling must restore the client-specific camera maximum")
end

checkCameraDistance(retail, "2.6")
checkCameraDistance(forever, "3.4")

print("Client feature smoke test: PASS")
