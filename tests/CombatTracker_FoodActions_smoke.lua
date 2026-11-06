-- Developer-only behavioral test; never loaded by either TOC.
-- Catches native-template bypasses, stale item actions and protected display geometry.
-- Engine boundary: the XML OnClick below is verbatim on Retail 297d7aaaa736f346b3e036f38ee088eaf7f8c07f
-- and Forever aff0d8cd53bf4d9ef1c1dd2786b94461a276fb16, in
-- Interface/AddOns/Blizzard_FrameXML/SecureTemplates.xml. The narrowly modeled
-- SecureActionButton dispatcher handles only this feature's left-up item action;
-- inventory mutation stands in for SecureCmdItemParse / SecureCmdUseItem.
local combat = false
local frames, actions, inventory, consumed = {}, {}, {}, {}
local lib = { callbacks = {}, isEditing = false }
function lib:RegisterCallback(event, callback)
    self.callbacks[event] = self.callbacks[event] or {}
    table.insert(self.callbacks[event], callback)
end
function LibStub(name)
    if name == "LibEditMode" then return lib end
end
function InCombatLockdown() return combat end

local methods = {}
function methods:IsProtected() return self.protected == true end
local function mutable(self)
    assert(not (combat and self:IsProtected()), "protected mutation during combat")
end
function methods:SetParent(parent) mutable(self); self.parent = parent end
function methods:GetParent() return self.parent end
function methods:SetSize(w, h) mutable(self); self.w, self.h = w, h end
function methods:SetPoint(_, relative, _, x, y)
    mutable(self); self.relative, self.x, self.y = relative, x or 0, y or 0
end
function methods:ClearAllPoints() mutable(self); self.relative = nil end
function methods:SetAllPoints(relative) mutable(self); self.allPoints = relative end
function methods:GetRect()
    if self.allPoints then return self.allPoints:GetRect() end
    local x, y = 0, 0
    if self.relative then x, y = self.relative:GetRect() end
    return x + (self.x or 0), y + (self.y or 0), self.w, self.h
end
function methods:SetScale(scale) mutable(self); self.scale = scale end
function methods:GetEffectiveScale() return (self.scale or 1) * (self.parent and self.parent:GetEffectiveScale() or 1) end
function methods:SetFrameLevel(level) mutable(self); self.level = level end
function methods:GetFrameLevel() return self.level or 1 end
function methods:SetFrameStrata(strata) mutable(self); self.strata = strata end
function methods:GetFrameStrata() return self.strata or (self.parent and self.parent:GetFrameStrata()) or "MEDIUM" end
function methods:Show() mutable(self); self.shown = true end
function methods:Hide() mutable(self); self.shown = false end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:SetAttribute(key, value) mutable(self); self.attributes[key] = value end
function methods:GetAttribute(key) return self.attributes[key] end
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:HookScript(event, callback)
    local previous = self.scripts[event]
    self.scripts[event] = function(...)
        if previous then previous(...) end
        callback(...)
    end
end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:UnregisterAllEvents() self.events = {} end
function methods:UnregisterEvent(event) self.events[event] = nil end
function methods:RegisterForClicks(...) self.clicks = { ... } end
function methods:SetHighlightTexture(texture, blend) self.highlight = { texture, blend } end
function methods:EnableMouse(enabled) self.mouseEnabled = enabled end

local function dispatch(self, button, down)
    local useOnKeyDown = self:GetAttribute("useOnKeyDown")
    if useOnKeyDown == nil then useOnKeyDown = true end -- exercise user's down-click CVar
    if not ((down and useOnKeyDown) or (not down and not useOnKeyDown)) then return end
    local suffix = button == "LeftButton" and "1" or "2"
    if self:GetAttribute("type" .. suffix) ~= "item" then return end
    local item = self:GetAttribute("item" .. suffix)
    local itemID = item and tonumber(item:match("^item:(%d+)$"))
    assert(itemID, "native item action must identify the selected item, not a bag slot")
    if (inventory[itemID] or 0) > 0 then
        inventory[itemID] = inventory[itemID] - 1
        consumed[#consumed + 1] = itemID
    end
end
function SecureActionButton_OnClick(self, button, down) dispatch(self, button, down) end
function CreateFrame(kind, name, parent, template)
    local frame = setmetatable({ parent = parent, name = name, attributes = {}, scripts = {}, events = {}, shown = true }, { __index = methods })
    frames[#frames + 1] = frame
    if name then _G[name] = frame end
    if template then
        assert(template == "InsecureActionButtonTemplate", "food clicks must not protect ordinary icon geometry")
        frame.scripts.OnClick = function(self, button, down)
            if not InCombatLockdown() then SecureActionButton_OnClick(self, button, down); end
        end
        actions[#actions + 1] = frame
    end
    return frame
end
UIParent = CreateFrame("Frame")
UIParent:SetSize(1920, 1080)
EditModeManagerFrame = CreateFrame("Frame")
EditModeManagerFrame:Hide()
C_Item = { GetItemCount = function(itemID) return inventory[itemID] or 0 end }
GameTooltip = { lines = {} }
function GameTooltip:SetOwner(owner) self.owner = owner end
function GameTooltip:IsOwned(owner) return self.owner == owner end
function GameTooltip:SetItemByID(itemID) self.itemID = itemID end
function GameTooltip:AddLine(text) self.lines[#self.lines + 1] = text end
function GameTooltip:Show() self.shown = true end
function GameTooltip:Hide() self.shown = false end

local CT = { sections = {} }
local addon = { combatTracker = CT, db = { combatTracker = { enabled = true, frames = {
    consumables = { enabled = true, clickableFoodWater = false, showFood = true, showWater = true },
    foodWater = { enabled = false },
} } } }
local db = addon.db.combatTracker
local combined = CreateFrame("Frame", nil, UIParent)
combined:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, 200)
local split = CreateFrame("Frame", nil, UIParent)
split:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 600, 700)
local function icon(itemID, food, section, anchor, x)
    local btn = CreateFrame("Button", nil, UIParent)
    btn._itemID, btn._isFoodWater, btn._sectionName = itemID, food, section
    btn:SetSize(36, 40)
    btn:SetPoint("TOPLEFT", anchor, "TOPLEFT", x, 0)
    return btn
end
local potion = icon(900, false, "consumables", combined, 0)
local food = icon(101, true, "consumables", combined, 38)
local water = icon(102, true, "consumables", combined, 76)
local splitFood = icon(nil, false, "foodWater", split, 0)
local splitWater = icon(nil, false, "foodWater", split, 44)
splitFood:Hide(); splitWater:Hide()
CT.sections.consumables = { buttons = { potion, food, water }, rebuilds = 0 }
CT.sections.foodWater = { buttons = { splitFood, splitWater } }
local latestFood = 101
function CT.sections.consumables:RebuildIcons()
    self.rebuilds = self.rebuilds + 1
    local target = db.frames.foodWater.enabled and splitFood or food
    target._itemID = latestFood
    CT:UpdateFoodActions()
end
local function fire(event)
    for _, frame in ipairs(frames) do
        if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event) end
    end
end
local function click(button, mouseButton, down, raw)
    if not raw then
        assert(button:IsVisible(), "physical click requires a visible overlay")
        local wanted = (mouseButton or "LeftButton") .. (down and "Down" or "Up")
        local registered = false
        for _, clickType in ipairs(button.clicks or {}) do if clickType == wanted then registered = true end end
        if not registered then return end
    end
    if button.scripts.PreClick then button.scripts.PreClick(button, mouseButton or "LeftButton", down) end
    button.scripts.OnClick(button, mouseButton or "LeftButton", down)
    if button.scripts.PostClick then button.scripts.PostClick(button, mouseButton or "LeftButton", down) end
end
local function actionFor(itemID)
    for _, action in ipairs(actions) do
        if action:GetAttribute("item1") == "item:" .. itemID and action:IsVisible() then return action end
    end
    error("missing visible food action for " .. itemID)
end
local function assertRect(frame, x, y, w, h)
    local ax, ay, aw, ah = frame:GetRect()
    assert(ax == x and ay == y and aw == w and ah == h, "overlay must follow displayed icon geometry")
end
local function edit(editing)
    lib.isEditing = editing
    if editing then EditModeManagerFrame:Show() else EditModeManagerFrame:Hide() end
    for _, callback in ipairs(lib.callbacks[editing and "enter" or "exit"] or {}) do callback() end
end

local module = assert(loadfile("Features/CombatTracker_FoodActions.lua"))
module("MathWroQOL", addon)
assert(type(CT.UpdateFoodActions) == "function", "food click integration missing")
CT:UpdateFoodActions()
assert(#actions == 0, "default-off option must not allocate click overlays")

-- Cold /reload in combat must establish a regen path without needing a bag event.
inventory[101], inventory[102], inventory[900] = 5, 5, 5
db.frames.consumables.clickableFoodWater = true
combat = true
CT:UpdateFoodActions()
assert(#actions == 0, "cold combat load must defer action creation")
latestFood, inventory[103] = 103, 5
combat = false
fire("PLAYER_REGEN_ENABLED")
assert(CT.sections.consumables.rebuilds > 0, "combat exit must refresh latest bag selection")
local eat, drink = actionFor(103), actionFor(102)
assert(#actions == 2 and not eat:IsProtected() and not drink:IsProtected())
assert(eat.highlight and eat.scripts.OnEnter and eat.scripts.OnLeave, "native highlight and item tooltip required")
assertRect(eat, 138, 200, 36, 40)
click(eat, "LeftButton", true)
click(eat, "RightButton", false, true)
assert(#consumed == 0, "only left release may consume")
click(eat)
assert(inventory[103] == 4 and consumed[1] == 103 and inventory[900] == 5)
eat.scripts.OnEnter(eat)
assert(GameTooltip.itemID == 103 and GameTooltip.shown and #GameTooltip.lines > 0)
eat.scripts.OnLeave(eat)
assert(not GameTooltip.shown)

-- Native gate must deny even before addon combat events, including hidden /click.
combat = true
-- Invoke the saved native handler without addon PreClick as well: event cleanup
-- and our own validation must not be the only reasons combat dispatch is denied.
eat.scripts.OnClick(eat, "LeftButton", false)
assert(inventory[103] == 4, "native template itself must refuse combat actions")
eat:Hide()
eat.scripts.OnClick(eat, "LeftButton", false)
click(eat, "LeftButton", false, true)
assert(inventory[103] == 4, "hidden /click must never bypass native combat refusal")
fire("PLAYER_REGEN_DISABLED")
food:SetSize(58, 62)
food:SetPoint("TOPLEFT", combined, "TOPLEFT", 120, -20)
CT:UpdateFoodActions()
assert(not food:IsProtected(), "click feature must not protect ordinary layout")
latestFood, inventory[104] = 104, 7
food._itemID = 104
CT:UpdateFoodActions()
click(eat, "LeftButton", false, true)
assert(inventory[104] == 7 and inventory[103] == 4)
combat = false
fire("PLAYER_REGEN_ENABLED")
eat = actionFor(104)
assertRect(eat, 220, 180, 58, 62)
click(eat)
assert(inventory[104] == 6, "combat exit must activate only latest selected food")

-- Split/combined routing reuses exactly two overlays and follows parent geometry/scale.
db.frames.foodWater.enabled = true
food:Hide(); water:Hide()
splitFood._itemID, splitFood._isFoodWater = 104, true
splitWater._itemID, splitWater._isFoodWater = 102, true
splitFood:Show(); splitWater:Show()
CT:UpdateFoodActions()
eat, drink = actionFor(104), actionFor(102)
assertRect(eat, 600, 700, 36, 40)
assertRect(drink, 644, 700, 36, 40)
splitFood:SetScale(1.5)
assert(eat:GetEffectiveScale() == 1.5, "overlay must inherit displayed icon scale")
split:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 700, 750)
assertRect(eat, 700, 750, 36, 40)
click(drink)
assert(inventory[102] == 4)

-- Depleted, recycled, hidden and nonselected custom/potion icons cannot retain an action.
inventory[104] = 0
click(eat, "LeftButton", false, true)
assert(#consumed == 3)
latestFood, inventory[105] = 105, 4
splitFood._itemID = 105
CT:UpdateFoodActions()
eat = actionFor(105)
splitFood._itemID = 900
click(eat, "LeftButton", false, true)
assert(inventory[900] == 5, "recycled display must not consume either stale or wrong item")
splitFood._itemID = 105
CT:UpdateFoodActions()
eat = actionFor(105)
splitFood:Hide()
click(eat, "LeftButton", false, true)
assert(inventory[105] == 4)
splitFood:Show()
CT:UpdateFoodActions()

-- Edit Mode and independent toggles deny even /click, then resume normally.
eat = actionFor(105)
edit(true)
click(eat, "LeftButton", false, true)
assert(inventory[105] == 4)
edit(false)
eat = actionFor(105)
for _, toggle in ipairs({ { db, "enabled" }, { db.frames.consumables, "enabled" }, { db.frames.consumables, "clickableFoodWater" } }) do
    toggle[1][toggle[2]] = false
    CT:UpdateFoodActions()
    click(eat, "LeftButton", false, true)
    assert(inventory[105] == 4, "disabled feature must leave no /click action")
    local scans = CT.sections.consumables.rebuilds
    fire("PLAYER_REGEN_ENABLED")
    assert(CT.sections.consumables.rebuilds == scans, "disabled callbacks must not scan")
    toggle[1][toggle[2]] = true
    CT:UpdateFoodActions()
    eat = actionFor(105)
end

-- A hybrid has one display/action, and disabling split does not disable clicks.
splitWater._itemID, splitWater._isFoodWater = nil, false
splitWater:Hide()
CT:UpdateFoodActions()
local oldDrink = drink
click(oldDrink, "LeftButton", false, true)
assert(inventory[102] == 4, "hybrid transition must clear surplus overlay")
db.frames.foodWater.enabled = false
splitFood:Hide()
food._itemID, food._isFoodWater = 105, true
water._itemID, water._isFoodWater = nil, false
food:Show(); water:Hide()
CT:UpdateFoodActions()
eat = actionFor(105)
assertRect(eat, 220, 180, 58, 62)
click(eat)
assert(inventory[105] == 3 and #actions == 2)

-- Disable during combat; regen may only clean up, never revive stale actions.
combat = true
fire("PLAYER_REGEN_DISABLED")
db.enabled = false
CT:UpdateFoodActions()
combat = false
fire("PLAYER_REGEN_ENABLED")
click(eat, "LeftButton", false, true)
assert(inventory[105] == 3)
print("CombatTracker food action smoke checks passed")
