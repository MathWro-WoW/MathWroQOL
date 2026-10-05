local _, addon = ...

local FolioEquipmentSets = { name = "folioEquipmentSets" }
addon:RegisterFeature(FolioEquipmentSets)
addon.folioEquipmentSets = FolioEquipmentSets

local SYSTEM_ID = 48
local TREE_ID = 1186
local STAT_NAMES = {
    [1279609] = "Critical Strike",
    [1279610] = "Haste",
    [1279612] = "Mastery",
    [1279613] = "Versatility",
}
local eventFrame
local badges = {}
local uiHooked = false
local nativePage
local nativeControls
local nativeHost
local requestSet

local function settings()
    local db = addon.db and addon.db.folioEquipmentSets
    if db and db.enabled then return db end
end

local function characterSets(create)
    local db = settings()
    if not db then return end
    local guid = UnitGUID("player")
    if not guid then return end
    if create and not db.characters then db.characters = {} end
    local sets = db.characters and db.characters[guid]
    if create and not sets then
        sets = {}
        db.characters[guid] = sets
    end
    return sets
end

local function savedSet(setID)
    if not setID then return end
    local sets = characterSets()
    return sets and sets[setID]
end

local function contains(list, value)
    for _, entry in ipairs(list) do
        if entry == value then return true end
    end
    return false
end

local function setStatus(message, report)
    FolioEquipmentSets.status = message
    if report then print("|cff33ff99MathWroQOL Folio:|r " .. message) end
    FolioEquipmentSets:RefreshControls(message)
end

local function configID()
    if not C_Traits or not C_Traits.GetConfigIDBySystemID then return end
    return C_Traits.GetConfigIDBySystemID(SYSTEM_ID)
end

local function runeInfo(config, entryID)
    local entry = C_Traits.GetEntryInfo(config, entryID)
    local definition = entry and C_Traits.GetDefinitionInfo(entry.definitionID)
    local spellID = definition and definition.spellID
    local spell = spellID and C_Spell.GetSpellInfo(spellID)
    local name = definition and definition.overrideName or spell and spell.name
    return name or ("Rune " .. entryID), spell and spell.iconID, spellID
end

function FolioEquipmentSets:HasSavedSet(setID)
    return savedSet(setID) ~= nil
end

function FolioEquipmentSets:GetSummary(setID)
    local saved = savedSet(setID)
    return saved and saved.summary or "No Folio setup saved for this equipment set."
end

function FolioEquipmentSets:GetEquipmentSetOptions()
    if not settings() then return {} end
    local options = {}
    for _, id in ipairs(C_EquipmentSet.GetEquipmentSetIDs()) do
        local name, icon = C_EquipmentSet.GetEquipmentSetInfo(id)
        if name then options[#options + 1] = { label = name, value = id, icon = icon } end
    end
    table.sort(options, function(a, b) return a.label < b.label end)
    return options
end

-- Saved stat data, not live trait state, drives pooled Equipment Manager badges.
local function restoreBadgeName(badge)
    if badge and badge.nameText and badge.nameText:GetWidth() == badge.reservedNameWidth then
        badge.nameText:SetWidth(badge.nameWidth)
    end
    if badge then
        badge.nameText = nil
        badge.nameWidth = nil
        badge.reservedNameWidth = nil
    end
end

local function reserveBadgeName(row, badge)
    local nameText = row.text
    if not nameText then return end
    if badge.nameText ~= nameText then
        restoreBadgeName(badge)
        badge.nameText = nameText
        badge.nameWidth = nameText:GetWidth()
    elseif nameText:GetWidth() ~= badge.reservedNameWidth then
        badge.nameWidth = nameText:GetWidth()
    end
    badge.reservedNameWidth = math.min(badge.nameWidth, math.max(20, row:GetWidth() - 91))
    nameText:SetWidth(badge.reservedNameWidth)
end

local function updateBadge(row)
    if not settings() then return end
    local saved = savedSet(row.setID)
    local stat = saved and saved.stat
    local badge = badges[row]
    if not stat then
        if badge then
            restoreBadgeName(badge)
            badge:Hide()
        end
        return
    end
    if not badge then
        badge = CreateFrame("Button", nil, row, "BackdropTemplate")
        badge:SetSize(16, 16)
        badge:SetPoint("RIGHT", row, "RIGHT", -29, 5)
        badge:SetFrameStrata("MEDIUM")
        badge:SetFrameLevel(row:GetFrameLevel() + 3)
        badge:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        badge:SetBackdropBorderColor(0.8, 0.7, 0.4, 1)
        local texture = badge:CreateTexture(nil, "ARTWORK")
        texture:SetPoint("TOPLEFT", 1, -1)
        texture:SetPoint("BOTTOMRIGHT", -1, 1)
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        badge.icon = texture
        badge:SetScript("OnEnter", function(self)
            if not settings() then return end
            local snapshot = savedSet(row.setID)
            if not snapshot or not snapshot.stat then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Saved Folio: " .. snapshot.stat.label, 1, 0.82, 0)
            GameTooltip:AddLine(snapshot.stat.name, 1, 1, 1)
            GameTooltip:AddLine(snapshot.summary, 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine("Click to apply or clear the saved Folio setup.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        badge:SetScript("OnLeave", function()
            if not settings() then return end
            GameTooltip:Hide()
        end)
        badge:SetScript("OnClick", function(self)
            if not settings() or not savedSet(row.setID) then return end
            local setID = row.setID
            GameTooltip:Hide()
            MenuUtil.CreateContextMenu(self, function(_, root)
                if not settings() then return end
                root:CreateTitle("Saved Folio")
                local apply = root:CreateButton("Apply saved Folio", function()
                    if not settings() then return end
                    FolioEquipmentSets:ApplySet(setID)
                end)
                apply:SetEnabled(not InCombatLockdown())
                local clear = root:CreateButton("Clear saved Folio", function()
                    if not settings() then return end
                    FolioEquipmentSets:ClearSet(setID)
                end)
                clear:SetEnabled(not InCombatLockdown())
            end)
        end)
        badges[row] = badge
    end
    reserveBadgeName(row, badge)
    badge.icon:SetTexture(stat.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    badge:Show()
end

local function refreshBadges()
    if not settings() then return end
    local pane = PaperDollFrame and PaperDollFrame.EquipmentManagerPane
    if not pane or not pane.ScrollBox or not pane:IsShown() then return end
    pane.ScrollBox:ForEachFrame(updateBadge)
end

local function hookEquipmentManager()
    if not settings() or uiHooked or not PaperDollEquipmentManagerPane_InitButton then return end
    uiHooked = true
    hooksecurefunc("PaperDollEquipmentManagerPane_InitButton", updateBadge)
    hooksecurefunc("PaperDollEquipmentManagerPane_Update", function()
        if not settings() then return end
        refreshBadges()
    end)
end

function FolioEquipmentSets:RefreshControls(message)
    if not settings() or not nativeControls or not nativeControls.Refresh then return end
    nativeControls:Refresh(message)
end

local function mountNativeControls()
    if not settings() or not nativePage or not nativePage:IsShown() then return end
    local host = nativePage.overlayFrame
    if not host or not host.RunesOfPowerFrame then return end
    if nativeControls and nativeHost == host then
        nativeControls:Show()
        FolioEquipmentSets:RefreshControls()
        return
    end
    if nativeControls then nativeControls:Hide() end
    if not addon.CreateFolioEquipmentSetControls then return end
    nativeControls = addon:CreateFolioEquipmentSetControls(host)
    nativeHost = nativeControls and host or nil
    FolioEquipmentSets:RefreshControls()
end

local function hookNativeFolio()
    if not settings() then return end
    local page = ExpansionLandingPage
    if not page then return end
    if nativePage ~= page then
        nativePage = page
        if page.RefreshExpansionOverlay then
            hooksecurefunc(page, "RefreshExpansionOverlay", function()
                if not settings() then return end
                mountNativeControls()
            end)
        end
        page:HookScript("OnShow", function()
            if not settings() then return end
            mountNativeControls()
        end)
    end
    mountNativeControls()
end

function FolioEquipmentSets:SaveSet(setID)
    if not settings() then return false, "Folio equipment sets are disabled." end
    if InCombatLockdown() then return false, "Save Folio selections outside combat." end
    if not setID or not C_EquipmentSet.GetEquipmentSetInfo(setID) then
        return false, "Select an existing equipment set."
    end
    local config = configID()
    if not config then return false, "The Omnium Folio is not available on this character." end
    if not C_Traits.IsReadyForCommit() or C_Traits.ConfigHasStagedChanges(config) then
        return false, "Finish your Folio changes before saving a setup."
    end
    local nodeIDs = C_Traits.GetTreeNodes(TREE_ID)
    if not nodeIDs then return false, "Folio selections have not loaded yet." end
    local nodes = {}
    for _, nodeID in ipairs(nodeIDs) do
        local info = C_Traits.GetNodeInfo(config, nodeID)
        if not info then return false, "Folio selections have not loaded yet." end
        if #info.entryIDs > 1 and #info.entryIDsWithCommittedRanks == 1 then
            nodes[#nodes + 1] = info
        end
    end
    table.sort(nodes, function(a, b)
        if a.posY == b.posY then return a.ID < b.ID end
        return a.posY < b.posY
    end)
    if #nodes == 0 then return false, "Choose your purchased runes in the Folio first." end
    local snapshot = { choices = {} }
    local names = {}
    for _, info in ipairs(nodes) do
        local entryID = info.entryIDsWithCommittedRanks[1]
        local name, icon, spellID = runeInfo(config, entryID)
        snapshot.choices[info.ID] = entryID
        names[#names + 1] = name
        if STAT_NAMES[spellID] then
            snapshot.stat = { label = STAT_NAMES[spellID], name = name, icon = icon, spellID = spellID }
        end
    end
    snapshot.summary = table.concat(names, "\n")
    local sets = characterSets(true)
    if not sets then return false, "Character data has not loaded yet." end
    sets[setID] = snapshot
    refreshBadges()
    setStatus("Saved the current Folio selections.")
    return true, self.status
end

function FolioEquipmentSets:ClearSet(setID)
    if not settings() then return false, "Folio equipment sets are disabled." end
    if InCombatLockdown() then return false, "Clear saved Folio selections outside combat." end
    local sets = characterSets()
    if not sets or not setID or not sets[setID] then return false, "No Folio setup is saved for this set." end
    sets[setID] = nil
    if self.requestedSetID == setID then self.requestedSetID = nil end
    refreshBadges()
    setStatus("Cleared the saved Folio setup; gear and current runes are unchanged.")
    return true, self.status
end

local function verifyCommit(token)
    if not settings() or FolioEquipmentSets.commit ~= token then return end
    local matches = configID() == token.configID and C_Traits.IsReadyForCommit()
        and not C_Traits.ConfigHasStagedChanges(token.configID)
    if matches then
        for nodeID, entryID in pairs(token.choices) do
            local info = C_Traits.GetNodeInfo(token.configID, nodeID)
            if not info or #info.entryIDsWithCommittedRanks ~= 1 or info.entryIDsWithCommittedRanks[1] ~= entryID then
                matches = false
                break
            end
        end
    end
    if matches then
        FolioEquipmentSets.commit = nil
        setStatus("Applied the saved Folio selections.")
        local requested = FolioEquipmentSets.requestedSetID
        FolioEquipmentSets.requestedSetID = nil
        if requested and requested ~= token.setID then requestSet(requested) end
        return
    end
    token.checks = token.checks + 1
    if token.checks >= 30 then
        FolioEquipmentSets.commit = nil
        FolioEquipmentSets.requestedSetID = nil
        setStatus("Could not confirm the Folio change. Check your runes before retrying.", true)
        return
    end
    -- Bounded, read-only acknowledgement; never resubmit or roll back an accepted commit.
    C_Timer.After(0.1, function()
        if not settings() then return end
        verifyCommit(token)
    end)
end

function FolioEquipmentSets:ApplySet(setID)
    if not settings() then return false, "Folio equipment sets are disabled." end
    local snapshot = savedSet(setID)
    self.requestedSetID = snapshot and setID or nil
    if not snapshot then return false, "No Folio setup is saved for this set." end
    if InCombatLockdown() then
        setStatus("Folio change queued until combat ends.", true)
        return false, self.status
    end
    if self.commit then return false, "Waiting for the previous Folio change to finish." end
    self.requestedSetID = nil
    local config = configID()
    if not config then return false, "The Omnium Folio is not available on this character." end
    if not C_Traits.IsReadyForCommit() then return false, "The Folio is busy. Try applying the saved setup again." end
    local canEdit, errorMessage = C_Traits.CanEditConfig(config)
    if not canEdit then return false, errorMessage end
    if C_Traits.ConfigHasStagedChanges(config) then return false, "Finish your manual Folio edits before applying a saved setup." end

    -- Validate the entire snapshot before staging any changes. Never buy an empty row.
    local changes = {}
    for nodeID, entryID in pairs(snapshot.choices) do
        local info = C_Traits.GetNodeInfo(config, nodeID)
        if not info or not contains(info.entryIDs, entryID) or #info.entryIDsWithCommittedRanks ~= 1 then
            return false, "A saved Folio row is unavailable. Choose your runes and save the setup again."
        end
        if info.entryIDsWithCommittedRanks[1] ~= entryID then changes[#changes + 1] = nodeID end
    end
    if #changes == 0 then
        setStatus("The saved Folio selections are already active.")
        return true, self.status
    end
    table.sort(changes)
    for _, nodeID in ipairs(changes) do
        if not C_Traits.SetSelection(config, nodeID, snapshot.choices[nodeID]) then
            C_Traits.RollbackConfig(config)
            return false, "Blizzard rejected a Folio selection; your previous runes were kept."
        end
    end
    local token = { configID = config, setID = setID, choices = snapshot.choices, checks = 0 }
    self.commit = token
    if not C_Traits.CommitConfig(config) then
        self.commit = nil
        C_Traits.RollbackConfig(config)
        return false, "Blizzard rejected the Folio change; your previous runes were kept."
    end
    if self.commit ~= token then return false, self.status end
    setStatus("Applying the saved Folio selections...")
    verifyCommit(token)
    return true, self.status
end

requestSet = function(setID)
    if not settings() then return end
    local success, message = FolioEquipmentSets:ApplySet(setID)
    if not success and FolioEquipmentSets:HasSavedSet(setID) and not InCombatLockdown() then
        setStatus(message, true)
    end
end

local function onEvent(_, event, ...)
    if not settings() then return end
    if event == "EQUIPMENT_SWAP_FINISHED" then
        local success, setID = ...
        if success then requestSet(setID) end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if FolioEquipmentSets.requestedSetID and not FolioEquipmentSets.commit then
            requestSet(FolioEquipmentSets.requestedSetID)
        end
        FolioEquipmentSets:RefreshControls()
    elseif event == "PLAYER_REGEN_DISABLED" then
        FolioEquipmentSets:RefreshControls()
    elseif event == "EQUIPMENT_SETS_CHANGED" then
        local sets = characterSets()
        if sets then
            for setID in pairs(sets) do
                if not C_EquipmentSet.GetEquipmentSetInfo(setID) then
                    sets[setID] = nil
                    if FolioEquipmentSets.requestedSetID == setID then FolioEquipmentSets.requestedSetID = nil end
                end
            end
        end
        refreshBadges()
        FolioEquipmentSets:RefreshControls()
    elseif event == "ADDON_LOADED" then
        hookEquipmentManager()
        hookNativeFolio()
        refreshBadges()
    elseif event == "CONFIG_COMMIT_FAILED" then
        local config = ...
        if FolioEquipmentSets.commit and FolioEquipmentSets.commit.configID == config then
            FolioEquipmentSets.commit = nil
            FolioEquipmentSets.requestedSetID = nil
            setStatus("Blizzard could not apply the saved Folio setup. Check your runes.", true)
        end
    end
end

function FolioEquipmentSets:Apply()
    if not settings() then
        if eventFrame then eventFrame:UnregisterAllEvents() end
        self.requestedSetID = nil
        self.commit = nil
        for _, badge in pairs(badges) do
            restoreBadgeName(badge)
            badge:Hide()
        end
        if nativeControls then nativeControls:Hide() end
        return
    end
    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        eventFrame:SetScript("OnEvent", onEvent)
    end
    eventFrame:RegisterEvent("EQUIPMENT_SWAP_FINISHED")
    eventFrame:RegisterEvent("EQUIPMENT_SETS_CHANGED")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("CONFIG_COMMIT_FAILED")
    eventFrame:RegisterEvent("ADDON_LOADED")
    hookEquipmentManager()
    hookNativeFolio()
    refreshBadges()
    self:RefreshControls()
end

function FolioEquipmentSets:Initialize()
    if not settings() then return end
    self:Apply()
end
