local _, addon = ...
local CT = addon.combatTracker
local actions = {}
local eventFrame, editMode

local function enabled()
    local db = addon.db.combatTracker
    local consumables = db.frames.consumables
    return db.enabled and consumables.enabled and consumables.clickableFoodWater
end

local function editing()
    return (editMode and editMode.isEditing)
        or (EditModeManagerFrame and EditModeManagerFrame:IsShown())
end

local function hideTooltip(action)
    if GameTooltip:IsOwned(action) then GameTooltip:Hide() end
end

local function clearAction(action)
    action:SetAttribute("type1", nil)
    action:SetAttribute("item1", nil)
    action._itemID, action._host = nil, nil
    hideTooltip(action)
    action:Hide()
end

local function selectedHost(host, itemID)
    if not host or not host:IsVisible() or not host._isFoodWater or host._itemID ~= itemID then return false end
    local db = addon.db.combatTracker.frames
    local sectionName = db.foodWater.enabled and "foodWater" or "consumables"
    return host._sectionName == sectionName and C_Item.GetItemCount(itemID, false, false) > 0
end

local function canClick(action)
    return enabled() and not InCombatLockdown() and not editing() and action:IsVisible()
        and selectedHost(action._host, action._itemID)
end

local function createAction(index, host)
    -- This native template has no protected inheritance. Its own OnClick refuses
    -- combat before dispatching, including hidden /click calls. Verified in
    -- Blizzard_FrameXML/SecureTemplates.xml on Retail 12.1.5.70783 (297d7aaa)
    -- and Forever 1.60.1.70707 (aff0d8cd); no state driver/protected geometry needed.
    local action = CreateFrame("Button", "MathWroQOL_CT_FoodAction" .. index, host, "InsecureActionButtonTemplate")
    action:RegisterForClicks("LeftButtonUp")
    action:SetAttribute("useOnKeyDown", false)
    action:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    -- Keep the inherited native OnClick intact. PreClick only disarms stale or
    -- disabled selections; it never calls an item-use API or chooses a new item.
    action:SetScript("PreClick", function(self)
        if not canClick(self) then clearAction(self) end
    end)
    action:SetScript("OnEnter", function(self)
        if not canClick(self) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self._itemID)
        GameTooltip:AddLine("Left-click to use (out of combat).", 1, 1, 1)
        GameTooltip:Show()
    end)
    action:SetScript("OnLeave", hideTooltip)
    action:SetScript("OnHide", hideTooltip)
    actions[index] = action
    return action
end

local function ensureCallbacks()
    if eventFrame then return end
    eventFrame = CreateFrame("Frame")
    eventFrame:SetScript("OnEvent", function(_, event)
        if not enabled() then
            CT:UpdateFoodActions()
            return
        end
        if event == "PLAYER_REGEN_ENABLED" then
            -- Bag selection may have changed while combat actions were inert.
            -- Also handles an enabled cold /reload in combat with no later bag event.
            CT.sections.consumables:RebuildIcons()
        end
        CT:UpdateFoodActions()
    end)
    editMode = LibStub and LibStub("LibEditMode", true)
    if editMode then
        local function update() CT:UpdateFoodActions() end
        editMode:RegisterCallback("enter", update)
        editMode:RegisterCallback("exit", update)
    end
end

function CT:UpdateFoodActions()
    if not enabled() then
        for _, action in ipairs(actions) do clearAction(action) end
        if eventFrame then eventFrame:UnregisterAllEvents() end
        return
    end

    -- Register the inert regen listener before deferring cold combat creation.
    ensureCallbacks()
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    if InCombatLockdown() or editing() then
        for _, action in ipairs(actions) do clearAction(action) end
        return
    end

    local db = addon.db.combatTracker.frames
    local section = self.sections[db.foodWater.enabled and "foodWater" or "consumables"]
    local count = 0
    for _, host in ipairs(section.buttons) do
        if count < 2 and host._itemID and selectedHost(host, host._itemID) then
            count = count + 1
            local action = actions[count] or createAction(count, host)
            action:SetParent(host)
            action:ClearAllPoints()
            action:SetAllPoints(host)
            action:SetFrameStrata(host:GetFrameStrata())
            action:SetFrameLevel(host:GetFrameLevel() + 2)
            action._host, action._itemID = host, host._itemID
            action:SetAttribute("item1", "item:" .. host._itemID)
            action:SetAttribute("type1", "item")
            action:Show()
        end
    end
    for i = count + 1, #actions do clearAction(actions[i]) end
end
