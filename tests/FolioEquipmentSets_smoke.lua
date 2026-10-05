-- Developer-only: wrong-set restores, manual-edit loss, and stale pooled badges
-- are consumer-visible failures. WoW's trait state and frames are simulated.
local frames, timers, hooks = {}, {}, {}
local combat, guid, queries = false, "Player-A", 0
local sets = { [1] = "Anni", [2] = "Havoc", [3] = "Unlinked" }
local committed = { [101] = 11, [102] = 21, [103] = 31, [104] = 42, [105] = 51 }
local entries = { [101] = { 11, 12 }, [102] = { 21, 22 }, [103] = { 31 },
    [104] = { 41, 42, 43, 44 }, [105] = { 51, 52 } }
local spells = { [41] = 1279609, [42] = 1279610, [43] = 1279612, [44] = 1279613 }
local staged, submitted, editable, ready, rejectNode, rejectCommit = {}, nil, true, true, nil, false
local writes, rollbacks = 0, 0
local Frame = {}
Frame.__index = Frame
function Frame:RegisterEvent(event) self.events[event] = true end
function Frame:UnregisterEvent(event) self.events[event] = nil end
function Frame:UnregisterAllEvents() self.events = {} end
function Frame:SetScript(event, callback) self.scripts[event] = callback end
function Frame:HookScript(event, callback)
    local previous = self.scripts[event]
    self.scripts[event] = function(...) if previous then previous(...) end; callback(...) end
end
function Frame:SetSize(w, h) self.width, self.height = w, h end
function Frame:SetPoint(...) self.point = {...} end
function Frame:ClearAllPoints() self.point = nil end
function Frame:SetFrameStrata() end
function Frame:SetFrameLevel(level) self.level = level end
function Frame:GetFrameLevel() return self.level or 1 end
function Frame:SetBackdrop() end
function Frame:SetBackdropColor() end
function Frame:SetBackdropBorderColor() end
function Frame:SetTexCoord() end
function Frame:SetAllPoints() end
function Frame:SetTexture(texture) self.texture = texture end
function Frame:SetText(text) self.text = text end
function Frame:SetWidth(width) self.width = width end
function Frame:GetWidth() return self.width end
function Frame:EnableMouse() end
function Frame:RegisterForClicks() end
function Frame:SetShown(shown) self.shown = shown end
function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false end
function Frame:IsShown() return self.shown end
function Frame:GetParent() return self.parent end
function Frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function Frame:SetHeight(height) self.height = height end
function Frame:SetAlpha(alpha) self.alpha = alpha end
function Frame:SetTextColor() end
function Frame:SetJustifyH() end
function Frame:SetDefaultText(text) self.text = text end
function Frame:SetEnabled(enabled) self.enabled = enabled end
function Frame:Enable() self.enabled = true end
function Frame:Disable() self.enabled = false end
function Frame:GetTop() return nil end
function Frame:GetBottom() return nil end
function Frame:GetChildren()
    local children = {}
    for _, frame in ipairs(frames) do if frame.parent == self then children[#children + 1] = frame end end
    return unpack(children)
end
function Frame:GetRegions() return unpack(self.regions) end
function Frame:IsObjectType(kind) return self.kind == kind end
function Frame:CreateFontString()
    local region = setmetatable({ parent = self, shown = true }, Frame)
    self.regions[#self.regions + 1] = region
    return region
end
function Frame:GetStringHeight()
    if not self.text or self.text == "" then return 0 end
    local _, lines = self.text:gsub("\n", "")
    return (lines + 1) * 12
end
Frame.OverrideText = Frame.SetText
function Frame:SetupMenu(generator) self.generator = generator end
function Frame:GenerateMenu()
    local root = { items = {}, SetScrollMode = function() end }
    function root:CreateRadio(label, selected, select, value)
        self.items[#self.items + 1] = { label = label, selected = selected, select = select, value = value }
    end
    self.generator(self, root)
    self.description = root
end
function Frame:IsMenuOpen() return self.menuOpen end
function Frame:CloseMenu() self.menuOpen = false end
function Frame:GetRect()
    local width, height = self.width or 0, self.height or 0
    if not self.point then return 0, 0, width, height end
    local point, relative, relativePoint, x, y = unpack(self.point)
    relative = relative or self.parent
    local left, bottom, relativeWidth, relativeHeight = relative:GetRect()
    local function offset(anchor, w, h)
        return anchor:find("LEFT") and 0 or (anchor:find("RIGHT") and w or w / 2),
            anchor:find("BOTTOM") and 0 or (anchor:find("TOP") and h or h / 2)
    end
    local rx, ry = offset(relativePoint, relativeWidth, relativeHeight)
    local sx, sy = offset(point, width, height)
    return left + rx + (x or 0) - sx, bottom + ry + (y or 0) - sy, width, height
end
function Frame:CreateTexture()
    local texture = setmetatable({ parent = self }, Frame)
    self.regions[#self.regions + 1] = texture
    return texture
end
function CreateFrame(kind, name, parent)
    local frame = setmetatable({ kind = kind, parent = parent, events = {}, scripts = {}, regions = {}, shown = true }, Frame)
    frames[#frames + 1] = frame
    if name then _G[name] = frame end
    return frame
end
function hooksecurefunc(target, method, callback)
    if type(target) == "string" then callback, method, target = method, target, _G end
    local original = target[method]
    target[method] = function(...) local result = original(...); callback(...); return result end
    hooks[#hooks + 1] = callback
end
function UnitGUID() queries = queries + 1; return guid end
function InCombatLockdown() return combat end
C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
C_EquipmentSet = {
    GetEquipmentSetIDs = function() queries = queries + 1; local ids = {}; for id in pairs(sets) do ids[#ids + 1] = id end; return ids end,
    GetEquipmentSetInfo = function(id) queries = queries + 1; if sets[id] then return sets[id], 1000 + id, id, false end end,
}
C_Spell = { GetSpellInfo = function(id)
    local names = { [1279609] = "Rune of Critical Power", [1279610] = "Rune of Burning Haste",
        [1279612] = "Rune of Masterful Cunning", [1279613] = "Rune of the Versatile Warrior" }
    return { name = names[id] or "Rune " .. id, iconID = id + 100 }
end }
C_Traits = {
    GetConfigIDBySystemID = function(id) queries = queries + 1; assert(id == 48); return 900 end,
    GetTreeNodes = function(id) queries = queries + 1; assert(id == 1186); return { 105, 103, 101, 104, 102 } end,
    GetNodeInfo = function(config, node)
        queries = queries + 1; assert(config == 900)
        if not entries[node] then return end
        return { ID = node, entryIDs = entries[node], entryIDsWithCommittedRanks = committed[node] and {committed[node]} or {},
            activeEntry = (staged[node] or committed[node]) and { entryID = staged[node] or committed[node], rank = 1 },
            posY = node * 10, posX = 0, isAvailable = true, currentRank = committed[node] and 1 or 0 }
    end,
    GetEntryInfo = function(_, entry) return { definitionID = entry } end,
    GetDefinitionInfo = function(entry) return { spellID = spells[entry] or entry } end,
    ConfigHasStagedChanges = function() return next(staged) ~= nil end,
    IsReadyForCommit = function() return ready end,
    CanEditConfig = function() return editable, "Cannot edit Folio now" end,
    SetSelection = function(config, node, entry)
        assert(config == 900); writes = writes + 1
        if node == rejectNode then return false end
        assert(committed[node], "must never purchase an unselected row")
        staged[node] = entry; return true
    end,
    CommitConfig = function(config)
        assert(config == 900)
        if rejectCommit then return false end
        submitted = staged; staged = {}; ready = false; return true
    end,
    RollbackConfig = function() rollbacks = rollbacks + 1; staged = {}; return true end,
}
local tooltipLines = {}
GameTooltip = { SetOwner = function() tooltipLines = {} end, AddLine = function(_, line) tooltipLines[#tooltipLines + 1] = line end,
    Show = function() end, Hide = function() end }
local menuItems
MenuUtil = { CreateContextMenu = function(owner, generate)
    menuItems = {}
    local root = { CreateTitle = function() end, CreateDivider = function() end }
    function root:CreateButton(label, callback)
        local item = { label = label, callback = callback, SetEnabled = function(self, enabled) self.enabled = enabled end }
        menuItems[#menuItems + 1] = item; return item
    end
    generate(owner, root)
end }
local addon = { db = { folioEquipmentSets = { enabled = false, characters = {} } } }
function addon:RegisterFeature(feature) self.feature = feature end
function addon:NotifyFeature(name) assert(name == "folioEquipmentSets"); self.feature:Apply() end
assert(loadfile("Config.lua"))("MathWroQOL", addon)
local function fire(event, ...)
    for _, frame in ipairs(frames) do
        if frame.events[event] then frame.scripts.OnEvent(frame, event, ...) end
    end
end
local function flush()
    local callbacks = timers; timers = {}
    for _, callback in ipairs(callbacks) do callback() end
end
local function finishCommit()
    for node, entry in pairs(submitted or {}) do committed[node] = entry end
    submitted = nil; ready = true
    fire("TRAIT_CONFIG_UPDATED", 900)
    flush()
end
local function resetChoices(crit)
    committed = { [101] = crit and 12 or 11, [102] = crit and 22 or 21, [103] = 31,
        [104] = crit and 41 or 42, [105] = crit and 52 or 51 }
end
local chunk = loadfile("Features/FolioEquipmentSets.lua")
if chunk then chunk("MathWroQOL", addon) end
assert(addon.feature, "Folio equipment-set feature is missing")
local feature = addon.feature
feature:Initialize()
assert(queries == 0 and #hooks == 0, "disabled initialization must not query gameplay state or install UI hooks")
addon.db.folioEquipmentSets.enabled = true
feature:Apply()
assert(feature:SaveSet(1))
resetChoices(true)
assert(feature:SaveSet(2))
local saved = addon.db.folioEquipmentSets.characters[guid]
assert(saved[1].choices[104] == 42 and saved[2].choices[104] == 41, "each set must retain its own committed stat choice")
assert(saved[1].choices[101] == 11 and saved[2].choices[105] == 52, "snapshot must include all selected choice rows")
assert(saved[1].choices[103] == nil, "single-entry purchased ranks must not be restored as choices")
fire("EQUIPMENT_SWAP_FINISHED", false, 1)
assert(committed[104] == 41 and writes == 0, "failed equipment swap must not change Folio")
fire("EQUIPMENT_SWAP_FINISHED", true, 1)
assert(committed[104] == 41, "accepted asynchronous commit is not yet a completed restore")
finishCommit()
assert(committed[101] == 11 and committed[102] == 21 and committed[104] == 42 and committed[105] == 51, "successful swap must restore the full Anni setup")
fire("EQUIPMENT_SWAP_FINISHED", true, 2)
finishCommit()
assert(committed[101] == 12 and committed[104] == 41 and committed[105] == 52, "Havoc must restore its independent choices")
local before = writes
fire("EQUIPMENT_SWAP_FINISHED", true, nil)
fire("EQUIPMENT_SWAP_FINISHED", true, 3)
assert(writes == before, "unidentified and unlinked swaps must leave choices unchanged")
-- Existing manual edits are not owned by the feature and must never be rolled back.
staged[104] = 44
local rollbackBefore = rollbacks
fire("EQUIPMENT_SWAP_FINISHED", true, 1)
assert(staged[104] == 44 and rollbacks == rollbackBefore, "restore must preserve unfinished manual edits")
assert(not feature:SaveSet(1), "saving while manual choices are staged must not overwrite the saved snapshot")
staged = {}
-- No partial changes when an old snapshot references an unpurchased or removed row.
committed[105] = nil
before = writes
fire("EQUIPMENT_SWAP_FINISHED", true, 1)
assert(writes == before, "unselected saved row must reject the restore before changing other rows")
resetChoices(true)
rejectNode = 104
assert(not feature:ApplySet(1))
assert(next(staged) == nil and rollbacks > rollbackBefore and committed[104] == 41, "rejected selection must roll back only the feature's staging")
rejectNode = nil; rejectCommit = true
assert(not feature:ApplySet(1))
assert(next(staged) == nil and committed[104] == 41, "rejected submission must leave committed choices intact")
rejectCommit = false
-- A failed request is not permission to change runes after an unrelated combat.
resetChoices(true)
editable = false
assert(not feature:ApplySet(1))
editable = true
before = writes
fire("PLAYER_REGEN_ENABLED")
assert(writes == before, "a rejected non-combat request must not revive on a later combat exit")
-- Rapid swaps during an accepted commit serialize to the newest set.
assert(feature:ApplySet(1))
fire("EQUIPMENT_SWAP_FINISHED", true, 2)
finishCommit()
finishCommit()
assert(committed[104] == 41 and committed[101] == 12, "latest gear set must win after the older commit finishes")
-- An accepted submission must never be resubmitted or roll back later manual edits.
assert(feature:ApplySet(1))
staged[104] = 44
before = writes
rollbackBefore = rollbacks
for _ = 1, 40 do flush() end
assert(writes == before and rollbacks == rollbackBefore and staged[104] == 44,
    "unconfirmed accepted commit must stop observing without retrying or overwriting newer edits")
assert(#timers == 0, "unconfirmed commit must not leave an unbounded timer chain")
submitted = nil; staged = {}; ready = true
assert(feature:ApplySet(1))
fire("CONFIG_COMMIT_FAILED", 900)
submitted = nil; ready = true
before = writes
flush()
assert(writes == before and committed[104] == 41, "failed asynchronous commit must not be treated as a successful restore")
-- Latest completed gear-set request wins when combat deferred an earlier one.
combat = true
fire("EQUIPMENT_SWAP_FINISHED", true, 1)
fire("EQUIPMENT_SWAP_FINISHED", true, 3)
combat = false; before = writes
fire("PLAYER_REGEN_ENABLED")
assert(writes == before, "unlinked newer gear set must cancel an older combat-deferred restore")
combat = true; fire("EQUIPMENT_SWAP_FINISHED", true, 1); combat = false
fire("PLAYER_REGEN_ENABLED"); finishCommit()
assert(committed[104] == 42, "combat-deferred restore must apply at combat exit")
-- Reusing a pooled Blizzard row must replace/hide the saved stat badge.
PaperDollFrame = { EquipmentManagerPane = { ScrollBox = {}, shown = true } }
local row = CreateFrame("Button")
row:SetSize(169, 44)
row.text = row:CreateFontString()
row.text:SetWidth(98)
row.text.height = 38
row.text:SetPoint("LEFT", row, "LEFT", 44, 0)
local rows = { row }
function PaperDollFrame.EquipmentManagerPane:IsShown() return self.shown end
function PaperDollFrame.EquipmentManagerPane.ScrollBox:ForEachFrame(callback) for _, button in ipairs(rows) do callback(button) end end
function PaperDollEquipmentManagerPane_InitButton(button, data) button.setID = data.setID end
function PaperDollEquipmentManagerPane_Update() end
feature:Apply()
PaperDollEquipmentManagerPane_InitButton(row, { setID = 1 })
local badge
for _, frame in ipairs(frames) do if frame.parent == row and frame.scripts.OnEnter then badge = frame end end
assert(badge and badge.shown and badge.regions[1].texture == 1279710, "Anni row must display saved Haste, not currently selected Crit")
local badgeLeft, badgeBottom, badgeWidth, badgeHeight = badge:GetRect()
local nameLeft, _, nameWidth = row.text:GetRect()
assert(nameLeft + nameWidth <= badgeLeft, "saved stat icon must have its own space beside the set name")
assert(badgeLeft >= 40 and badgeLeft + badgeWidth <= 145 and badgeBottom >= 18,
    "saved stat icon must not overlap the gear icon, equipped check, or edit/delete buttons")
PaperDollEquipmentManagerPane_InitButton(row, { setID = 2 })
assert(badge.shown and badge.regions[1].texture == 1279709, "recycled row must display the new set's saved Crit")
PaperDollEquipmentManagerPane_InitButton(row, { setID = 3 })
assert(not badge.shown, "unlinked row must not inherit a recycled badge")
assert(row.text:GetWidth() == 98, "recycled unlinked row must regain its full name width")
row.text:SetWidth(110)
PaperDollEquipmentManagerPane_InitButton(row, { setID = 2 })
PaperDollEquipmentManagerPane_InitButton(row, { setID = 3 })
assert(row.text:GetWidth() == 110, "unlinking must restore a provider-adjusted name width, not the native default")
row.text:SetWidth(98)
PaperDollEquipmentManagerPane_InitButton(row, { setID = nil })
assert(not badge.shown, "New Set row must not inherit a recycled badge")
PaperDollEquipmentManagerPane_InitButton(row, { setID = 1 })
resetChoices(true)
badge.scripts.OnEnter(badge)
assert(table.concat(tooltipLines, " "):find("Rune of Burning Haste", 1, true), "badge tooltip must describe saved selection, not live selection")
badge.scripts.OnClick(badge)
local clearAction
for _, item in ipairs(menuItems) do if item.label:lower():find("clear", 1, true) then clearAction = item.callback end end
assert(clearAction, "badge must expose a clear-association action")
clearAction()
assert(saved[1] == nil and sets[1] == "Anni" and not badge.shown and committed[104] == 41, "clearing must remove badge/association without changing gear or live runes")
-- Rename keeps identity; another character's set with the same ID has no link.
sets[2] = "Havoc renamed"
guid = "Player-B"; before = writes
fire("EQUIPMENT_SWAP_FINISHED", true, 2)
assert(writes == before, "another character's equipment-set ID must not inherit the saved profile")
guid = "Player-A"
sets[2] = nil; fire("EQUIPMENT_SETS_CHANGED")
assert(saved[2] == nil, "deleted equipment set must lose its association")
sets[2] = "Replacement"
assert(feature:SaveSet(1))
-- The native Folio may load before its overlay exists; opening later must attach controls.
ExpansionLandingPage = CreateFrame("Frame")
ExpansionLandingPage.shown = false
function ExpansionLandingPage:RefreshExpansionOverlay()
    if not self.overlayFrame then
        self.overlayFrame = CreateFrame("Frame", nil, self)
        self.overlayFrame.RunesOfPowerFrame = CreateFrame("Frame", nil, self.overlayFrame)
    end
end
fire("ADDON_LOADED", "Blizzard_ExpansionLandingPage")
ExpansionLandingPage.shown = true
ExpansionLandingPage:RefreshExpansionOverlay()
if ExpansionLandingPage.scripts.OnShow then ExpansionLandingPage.scripts.OnShow(ExpansionLandingPage) end
local saveButton, applyButton, clearButton, dropdown
for _, frame in ipairs(frames) do
    if frame.text == "Save current Folio" then saveButton = frame end
    if frame.text == "Apply saved Folio" then applyButton = frame end
    if frame.text == "Clear saved Folio" then clearButton = frame end
    if frame.description then dropdown = frame end
end
assert(saveButton and applyButton and clearButton and dropdown, "the Folio UI must expose equipment-set save/apply/clear controls")
resetChoices(false)
saveButton.scripts.OnClick(saveButton)
assert(saved[1].choices[104] == 42, "Folio Save must capture the selected set's Haste setup")
local havocOption
for _, option in ipairs(dropdown.description.items) do
    if option.value == 2 then havocOption = option end
end
assert(havocOption)
resetChoices(true)
havocOption.select(havocOption.value)
saveButton.scripts.OnClick(saveButton)
assert(saved[2].choices[104] == 41 and saved[1].choices[104] == 42, "browsing and saving in the Folio must keep equipment sets independent")
resetChoices(false)
applyButton.scripts.OnClick(applyButton)
finishCommit()
assert(committed[104] == 41, "Folio Apply must restore the selected set without equipping gear")
clearButton.scripts.OnClick(clearButton)
assert(saved[2] == nil and sets[2] == "Replacement" and committed[104] == 41, "Folio Clear must preserve the set and current runes")
assert(not clearButton.enabled and not applyButton.enabled, "cleared Folio setup must disable restore/clear controls")
combat = true
fire("PLAYER_REGEN_DISABLED")
assert(not saveButton.enabled and not dropdown.enabled, "Folio controls must lock on entering combat")
combat = false
fire("PLAYER_REGEN_ENABLED")
ExpansionLandingPage:Hide()
local hiddenQueries = queries
combat = true; fire("PLAYER_REGEN_DISABLED")
combat = false; fire("PLAYER_REGEN_ENABLED")
assert(queries == hiddenQueries, "closed Folio controls must not scan gameplay state when combat changes")
ExpansionLandingPage:Show()
ExpansionLandingPage.scripts.OnShow(ExpansionLandingPage)
assert(saveButton.parent:IsVisible() and saveButton.enabled, "reopening Folio must restore its management controls")
combat = true; fire("EQUIPMENT_SWAP_FINISHED", true, 1)
addon.db.folioEquipmentSets.enabled = false
feature:Apply()
combat = false; before = writes
local queryBefore = queries
fire("PLAYER_REGEN_ENABLED"); flush()
PaperDollEquipmentManagerPane_InitButton(row, { setID = 1 })
assert(writes == before and queries == queryBefore and not badge.shown, "disable must cancel deferred work and keep retained hooks inert")
assert(row.text:GetWidth() == 98, "disable must restore the native equipment-set name layout")
assert(not saveButton.parent:IsVisible(), "disable must hide the Folio controls as well as badges")
assert(not feature:SaveSet(1) and not feature:ClearSet(1) and not feature:ApplySet(1), "disabled controls must not mutate saved or live state")
addon.db.folioEquipmentSets.enabled = true
feature:Apply()
assert(saveButton.parent:IsVisible() and saveButton.enabled, "re-enabling must reuse and restore the open Folio controls")
addon.db.folioEquipmentSets.enabled = false
feature:Apply()
print("Folio equipment sets smoke PASS: snapshots, swaps, transaction safety, combat cancellation, character isolation, pooled name-row icons, native Folio controls, hidden-window gating, and clearing")
