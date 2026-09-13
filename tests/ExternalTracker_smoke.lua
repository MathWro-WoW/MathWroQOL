-- Developer-only: mode transitions must not leak icons or native sound registrations.
local frames, containers, sounds = {}, {}, {}
local nextSoundID, registrations, inCombat = 0, 0, false
local loaded, mediaAvailable = false, true
local media = { Bell = "Interface\\AddOns\\Sounds\\Bell.ogg", Numeric = 123456 }
local sharedMedia = {}
function sharedMedia:Fetch(_, key) return media[key] end
function sharedMedia:RegisterCallback() end
function sharedMedia:UnregisterCallback() end
local editMode = { callbacks = {}, settings = {}, settingsByFrame = {}, moves = {}, frameSelections = {}, editing = false,
    SettingType = { Slider = 1, Dropdown = 2 } }
function editMode:RegisterCallback(event, callback)
    self.callbacks[event] = self.callbacks[event] or {}
    table.insert(self.callbacks[event], callback)
end
function editMode:IsInEditMode() return self.editing end
function editMode:AddFrame(frame, callback)
    self.anchor, self.move = frame, callback
    self.moves[frame] = callback
    self.frameSelections[frame] = { ShowHighlighted = function() end }
end
function editMode:AddFrameSettings(frame, settings)
    self.settings = {}
    self.settingsByFrame[frame] = self.settings
    for _, setting in ipairs(settings) do self.settings[setting.name] = setting end
end
local function toggleEditMode(editing)
    editMode.editing = editing
    for _, callback in ipairs(editMode.callbacks[editing and "enter" or "exit"] or {}) do callback() end
end
LibStub = function(name)
    if name == "LibSharedMedia-3.0" and mediaAvailable then return sharedMedia end
    if name == "LibEditMode" then return editMode end
end
UIParent = {}
Enum = { UnitAuraSoundTrigger = { Added = 0 } }
function InCombatLockdown() return inCombat end
C_AddOns = {
    IsAddOnLoaded = function() return loaded end,
    LoadAddOn = function() loaded = true end,
}
C_Spell = { GetSpellInfo = function(id) return { name = tostring(id), iconID = id } end }
C_UnitAuras = {
    AddAuraSound = function(trigger, info)
        assert(not inCombat, "sound registration must wait until combat ends")
        assert(trigger == Enum.UnitAuraSoundTrigger.Added)
        assert(info.unitToken == "player", "external sounds must only target the player")
        nextSoundID = nextSoundID + 1
        registrations = registrations + 1
        sounds[nextSoundID] = info
        return nextSoundID
    end,
    RemoveAuraSound = function(id) sounds[id] = nil end,
    GetAuraDataByIndex = function() error("must not scan restricted aura data") end,
    GetPlayerAuraBySpellID = function() error("must not inspect restricted aura state") end,
}
C_Timer = { After = function(_, callback) callback() end }
local methods = {}
for _, name in ipairs({ "SetSize", "SetPoint", "ClearAllPoints", "SetFrameStrata", "SetFrameLevel",
    "SetClampedToScreen", "SetAllPoints", "SetTexCoord", "SetTexture", "SetHideCountdownNumbers",
    "SetDrawEdge", "SetReverse", "SetDrawSwipe", "SetFont", "SetJustifyH", "SetText",
    "SetMouseMotionEnabled", "SetMouseClickEnabled", "EnableMouse", "RegisterForDrag", "SetMovable",
    "SetAlpha", "SetTextColor", "SetColorTexture", "SetCooldown", "SetCooldownFromDurationObject",
    "SetScriptAccessAllowed", "SetWidth", "SetHeight" }) do
    methods[name] = function(self)
        assert(not self.restricted, "secret aura buttons cannot be accessed after initialization")
    end
end
function methods:SetSize(width, height)
    assert(not self.restricted, "secret aura button resized")
    self.width, self.height = width, height
end
function methods:SetTexCoord(...) self.texCoords = { ... } end
function methods:SetTexture(texture) self.texture = texture end
function methods:SetAtlas(atlas) self.atlas = atlas end
function methods:SetBlendMode() end
function methods:IsShown()
    return self.shown ~= false and (not self.parent or not self.parent.IsShown or self.parent:IsShown())
end
function methods:CreateAnimationGroup()
    local group = { parent = self }
    function group:SetLooping() end
    function group:Play() self.playing = true end
    function group:Stop() self.playing = false end
    function group:IsPlaying() return self.playing == true end
    function group:CreateAnimation()
        local animation = {}
        for _, name in ipairs({ "SetFlipBookRows", "SetFlipBookColumns", "SetFlipBookFrames",
            "SetFlipBookFrameWidth", "SetFlipBookFrameHeight", "SetDuration" }) do
            animation[name] = function() end
        end
        return animation
    end
    self.animation = group
    return group
end
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:HookScript(event, callback) self.scripts[event] = callback end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:UnregisterEvent(event) self.events[event] = nil end
function methods:UnregisterAllEvents() self.events = {} end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:SetShown(value) self.shown = value end
function methods:GetFrameLevel() return 1 end
function methods:GetPoint() return "CENTER", UIParent, "CENTER", 0, 150 end
function methods:CreateTexture()
    local texture = setmetatable({ parent = self }, { __index = methods })
    self.textures = self.textures or {}
    self.textures[#self.textures + 1] = texture
    return texture
end
function methods:CreateFontString() return setmetatable({}, { __index = methods }) end
function methods:SetIcon(texture) self.icon = texture end
function methods:SetDurationCooldown(cooldown) self.cooldown = cooldown end
function methods:SetDurationText(text) self.durationText = text end
function methods:SetUnit(unit) self.unit = unit end
function methods:SetEnabled(value) self.enabled = value end
function methods:UpdateAllAuras() end
function methods:AddAuraSlot(key, filter, options)
    local button = CreateFrame("AuraButton", nil, self)
    self.slots[key] = { button = button, filter = filter, candidates = options.candidateFilters }
    options.initializeFrame(button)
    -- Aura secrecy can outlast combat; returned buttons deny tainted access.
    button.restricted = true
    return button
end
function methods:SetAuraSlotCandidateFilters(key, candidates) self.slots[key].candidates = candidates end
function CreateFrame(kind, name, parent, template)
    local frame = setmetatable({ kind = kind, parent = parent, scripts = {}, events = {}, slots = {}, shown = true }, { __index = methods })
    frames[#frames + 1] = frame
    if name then _G[name] = frame end
    if kind == "AuraContainer" then
        assert(template == "CustomAuraContainerTemplate")
        containers[#containers + 1] = frame
    end
    return frame
end
local function fire(event, ...)
    for _, frame in ipairs(frames) do
        if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, ...) end
    end
end
local function hasIcon(spellID)
    for _, container in ipairs(containers) do
        if container.enabled ~= false and container.shown ~= false then
            for _, slot in pairs(container.slots) do
                if slot.candidates.includeSpellIDs[spellID] then
                    assert(slot.button.icon and (slot.button.cooldown or slot.button.durationText), "visible externals need duration display")
                    return true
                end
            end
        end
    end
    return false
end
local function soundFor(spellID)
    local result
    for _, info in pairs(sounds) do
        if info.spellID == spellID then
            assert(not result, "duplicate aura sound registration")
            result = info
        end
    end
    return result
end
local addon = { db = { externalTracker = {
    enabled = false, point = "CENTER", x = 0, y = 150, iconSize = 40,
    spells = { [33206] = { enabled = true, mode = "both", sound = "Bell" } },
} } }
addon.db.bloodlustTracker = {
    enabled = false, point = "CENTER", x = 0, y = 90, iconSize = 40, iconZoom = 8, glowType = "none",
}
SlashCmdList = {}
assert(loadfile("Core.lua"))("MathWroQOL", addon)
function addon:RegisterFeature(feature)
    self.features = self.features or {}
    self.features[feature.name] = feature
    if feature.name == "externalTracker" then self.feature = feature end
end
local chunk = loadfile("Features/ExternalTracker.lua")
if chunk then chunk("MathWroQOL", addon) end
assert(addon.feature, "External Tracker feature is missing")
local tracker, db = addon.feature, addon.db.externalTracker
tracker:Initialize()
assert(not loaded and #containers == 0 and not next(sounds), "disabled tracker must remain inert")
db.enabled = true
db.spells[33206].enabled = false
tracker:Apply()
assert(not loaded and #containers == 0 and not next(sounds), "master enable alone must not opt into spells")
db.spells[33206].enabled = true
tracker:Apply()
assert(hasIcon(33206) and soundFor(33206).soundFileName == media.Bell, "both mode must show duration and register sound")
local initialRegistrations = registrations
tracker:Apply()
assert(registrations == initialRegistrations, "unchanged settings must not re-arm sounds")
db.spells[47788] = { enabled = true, mode = "both", sound = "Numeric" }
tracker:Apply()
assert(hasIcon(33206) and hasIcon(47788) and soundFor(33206) and soundFor(47788), "spells must track independently")
db.spells[47788].enabled = false
tracker:Apply()
assert(hasIcon(33206) and soundFor(33206) and not hasIcon(47788) and not soundFor(47788), "disabling one spell must preserve another")
assert(registrations == initialRegistrations + 1, "editing another spell must not re-arm unchanged alerts")
db.spells[33206].mode = "icon"
tracker:Apply()
assert(hasIcon(33206) and not soundFor(33206), "icon mode must remove the previous sound")
db.spells[33206].mode = "sound"
tracker:Apply()
assert(not hasIcon(33206) and soundFor(33206), "sound mode must remove the previous icon")
db.spells[33206].sound = "Numeric"
tracker:Apply()
assert(soundFor(33206).soundFileID == 123456 and not soundFor(33206).soundFileName, "numeric media must use soundFileID")
db.spells[33206].sound = "Missing"
tracker:Apply()
assert(not soundFor(33206), "missing sound must not retain an old alert or substitute another sound")
db.spells[33206].sound = "Bell"
db.spells[33206].mode = "both"
mediaAvailable = false
tracker:Apply()
assert(hasIcon(33206) and not soundFor(33206), "icons must work without LibSharedMedia")
mediaAvailable = true
tracker:Apply()
assert(soundFor(33206), "available shared media must restore configured sounds")
db.spells[33206].enabled = false
tracker:Apply()
assert(not hasIcon(33206) and not next(sounds), "per-spell disable must clear both outputs")
db.spells[33206].enabled = true
inCombat = true
tracker:Apply()
assert(not next(sounds), "combat settings changes must defer registration")
inCombat = false
fire("PLAYER_REGEN_ENABLED")
assert(hasIcon(33206) and soundFor(33206), "deferred settings must apply after combat")
db.enabled = false
tracker:Apply()
assert(not hasIcon(33206) and not next(sounds), "master disable must clear both outputs")
fire("ADDON_LOADED", "SomeSoundPack")
fire("PLAYER_REGEN_ENABLED")
assert(not hasIcon(33206) and not next(sounds), "callbacks must not reactivate a disabled tracker")
-- Edit Mode is a visual preview, never a synthetic buff or sound trigger.
db.enabled = true
db.spells[33206].enabled = false
tracker:Apply()
local soundCount = registrations
toggleEditMode(true)
local example = _G.MathWroQOL_ExternalTrackerPreview
assert(example and example:IsShown(), "Edit Mode needs a visible Power Infusion example without active spells")
assert(example.textures[1].texture == 10060, "the example must use the Power Infusion spell icon")
assert(not next(sounds) and registrations == soundCount, "preview must not trigger or register spell sounds")
local size = assert(editMode.settings["Icon size"], "icon size control must live in Edit Mode")
local zoom = assert(editMode.settings["Icon zoom"], "icon zoom control must live in Edit Mode")
local glow = assert(editMode.settings["Glow type"], "glow choices must live in Edit Mode")
size.set("Test layout", 64, false)
zoom.set("Test layout", 15, false)
assert(example.width == 64 and example.textures[1].texCoords[1] == 0.15, "preview must immediately reflect visual controls")
glow.set("Test layout", "proc", false)
assert(example.textures[2].animation:IsPlaying(), "selected preview glow must animate")
glow.set("Test layout", "none", false)
assert(not example.textures[2].animation:IsPlaying(), "None must stop the previous glow")
glow.set("Test layout", "classic", false)
toggleEditMode(false)
assert(not example:IsShown(), "leaving Edit Mode must hide the example")
assert(not example.textures[2].animation:IsPlaying(), "leaving Edit Mode must stop preview animation")
assert(not hasIcon(10060), "preview must not enable Power Infusion tracking")
toggleEditMode(true)
assert(example:IsShown() and example.textures[2].animation:IsPlaying(), "reentering Edit Mode must restore the styled preview")
editMode.move(nil, nil, "TOPLEFT", 100, -200)
assert(db.point == "TOPLEFT" and db.x == 100 and db.y == -200, "moving the preview must save its position")
inCombat = true
fire("PLAYER_REGEN_DISABLED")
assert(not example:IsShown(), "combat must dismiss the preview even before Edit Mode exits")
inCombat = false
toggleEditMode(false)
fire("PLAYER_REGEN_ENABLED")
db.spells[33206].enabled = true
tracker:Apply()
local auraButton
for _, auraContainer in ipairs(containers) do
    for _, slot in pairs(auraContainer.slots) do
        if slot.candidates.includeSpellIDs[33206] then auraButton = slot.button end
    end
end
assert(auraButton.icon.texCoords[1] == 0.15, "live icons must inherit the configured zoom")
local glowFrame
for _, frame in ipairs(frames) do
    if frame.parent == auraButton and frame.textures and frame.textures[1].animation then glowFrame = frame end
end
assert(glowFrame and glowFrame:IsShown(), "active icons must display the configured glow")
local frameCount, registeredSounds = #frames, registrations
toggleEditMode(true)
assert(not hasIcon(33206) and soundFor(33206), "editing must replace live icons without disabling real sound alerts")
for _, style in ipairs({ "proc", "assist", "classic" }) do
    glow.set("Test layout", style, false)
    assert(glowFrame.textures[1].animation:IsPlaying(), "each glow choice must animate on the live icon")
end
size.set("Test layout", 48, false)
zoom.set("Test layout", 0, false)
assert(#frames == frameCount and registrations == registeredSounds, "appearance edits must reuse frames and retain sound registrations")
toggleEditMode(false)
assert(hasIcon(33206) and glowFrame:IsShown(), "leaving Edit Mode must restore the live icon")
auraButton:Hide()
assert(not glowFrame:IsShown(), "glow visibility must follow aura removal without addon callbacks")
auraButton:Show()
glow.set("Test layout", "none", false)
assert(not glowFrame.textures[1].animation:IsPlaying(), "disabling glow must stop the live animation")
db.enabled = false
tracker:Apply()
toggleEditMode(true)
assert(not example:IsShown(), "disabled tracker must not show its Edit Mode preview")

-- Bloodlust is a separate window, not another toggle under the external master.
toggleEditMode(false)
local bloodlust = assert(addon.features.bloodlustTracker, "independent Bloodlust Tracker is missing")
local lustDb = addon.db.bloodlustTracker
local containersBefore = #containers
bloodlust:Initialize()
assert(#containers == containersBefore and not hasIcon(2825), "disabled bloodlust tracker must remain inert")
lustDb.enabled = true
bloodlust:Apply()
assert(hasIcon(2825) and hasIcon(32182) and hasIcon(80353) and hasIcon(390386)
    and hasIcon(264667) and hasIcon(357650) and hasIcon(1243972), "bloodlust variants must share tracking automatically")
assert(not hasIcon(57724) and not hasIcon(80354), "exhaustion is not an active bloodlust buff")
assert(not hasIcon(33206) and not next(sounds), "bloodlust must work without enabling external spells or their sounds")
local lustContainer
for _, candidate in ipairs(containers) do
    for _, slot in pairs(candidate.slots) do
        if slot.candidates.includeSpellIDs[2825] then lustContainer = candidate end
    end
end
local activeSlots = 0
for _, slot in pairs(lustContainer.slots) do
    if next(slot.candidates.includeSpellIDs) then activeSlots = activeSlots + 1 end
end
assert(activeSlots == 1, "variants must use one icon rather than separate windows")
db.enabled = true
tracker:Apply()
assert(hasIcon(33206) and hasIcon(80353) and soundFor(33206), "both trackers must coexist")
toggleEditMode(true)
local lustPreview = _G.MathWroQOL_BloodlustTrackerPreview
assert(lustPreview and lustPreview:IsShown() and example:IsShown(), "each tracker needs its own Edit Mode preview")
assert(lustPreview.textures[1].texture == 2825, "bloodlust preview must use Bloodlust, not Power Infusion")
local lustAnchor = _G.MathWroQOL_BloodlustTracker
local lustSettings = editMode.settingsByFrame[lustAnchor]
local previousSize, previousZoom, previousX = db.iconSize, db.iconZoom, db.x
lustSettings["Icon size"].set("Test layout", 60, false)
lustSettings["Icon zoom"].set("Test layout", 12, false)
lustSettings["Glow type"].set("Test layout", "proc", false)
editMode.moves[lustAnchor](nil, nil, "CENTER", 180, -120)
assert(lustPreview.width == 60 and lustPreview.textures[1].texCoords[1] == 0.12
    and lustPreview.textures[2].animation:IsPlaying(), "bloodlust appearance controls must update its own preview")
assert(lustDb.x == 180 and lustDb.y == -120 and db.iconSize == previousSize
    and db.iconZoom == previousZoom and db.x == previousX, "bloodlust settings must not change external tracker settings")
toggleEditMode(false)
db.enabled = false
tracker:Apply()
assert(hasIcon(80353) and not hasIcon(33206), "disabling externals must not disable bloodlust")
db.enabled = true
tracker:Apply()
lustDb.enabled = false
bloodlust:Apply()
assert(hasIcon(33206) and soundFor(33206) and not hasIcon(80353), "disabling bloodlust must preserve externals")
toggleEditMode(true)
assert(example:IsShown() and not lustPreview:IsShown(), "disabled bloodlust must not reactivate through Edit Mode")
toggleEditMode(false)
db.enabled = false
tracker:Apply()
print("ExternalTracker smoke passed: modes, appearance, previews, and independent Bloodlust variants")
