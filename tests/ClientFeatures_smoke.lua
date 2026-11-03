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
        assert(name == "cameraDistanceMaxZoomFactor" and value == "2.6")
        setCalls = setCalls + 1
        cameraValue = value
    end,
}
local cameraAddon = {
    db = { cameraDistance = { enabled = true }, spellQueueWindow = { enabled = false } },
    RegisterFeature = function(self, feature)
        self.features = self.features or {}
        self.features[feature.name] = feature
    end,
}
loadFeature("Features/CVarSettings.lua", cameraAddon)
local camera = cameraAddon.features.cameraDistance
camera:Apply()
camera:Apply()
assert(getCalls == 2 and setCalls == 1, "camera setting must use C_CVar and avoid redundant writes")
cameraAddon.db.cameraDistance.enabled = false
camera:Apply()
assert(setCalls == 1, "disabled camera setting must not write")

print("Client feature smoke test: PASS")
