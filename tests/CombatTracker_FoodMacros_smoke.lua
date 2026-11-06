-- Developer-only: managed General macros follow the current food/water selection.
local combat, events, macros, characterMacros = false, {}, {}, {}
local writes = 0
MAX_ACCOUNT_MACROS = 6
function InCombatLockdown() return combat end
function CreateFrame()
    return {
        RegisterEvent = function(_, event) events[event] = true end,
        SetScript = function(self, _, callback) self.onEvent = callback; events.frame = self end,
    }
end
function GetNumMacros() return #macros, #characterMacros end
function GetMacroInfo(index)
    local macro = index <= MAX_ACCOUNT_MACROS and macros[index] or characterMacros[index - MAX_ACCOUNT_MACROS]
    if macro then return macro.name, macro.icon, macro.body end
end
function CreateMacro(name, icon, body, perCharacter)
    assert(not combat, "must not create macros in combat")
    assert(not perCharacter, "smart macros belong in General, not character slots")
    assert(#macros < MAX_ACCOUNT_MACROS, "must preflight available account slots")
    macros[#macros + 1] = { name = name, icon = icon, body = body }
    table.sort(macros, function(a, b) return a.name < b.name end)
    writes = writes + 1
    for index, macro in ipairs(macros) do if macro.name == name then return index end end
end
function EditMacro(index, name, icon, body)
    assert(not combat, "must defer macro edits in combat")
    local macro = assert(macros[index], "must edit the correct General slot")
    assert(not name, "selection updates must not rename macros or disturb indices")
    macro.icon, macro.body = icon or macro.icon, body
    writes = writes + 1
    return index
end
local db = { enabled = true, frames = { consumables = { enabled = true, showFood = true, showWater = true } } }
local food = { selectedFood = { itemID = 2070 }, selectedWater = { itemID = 159 } }
function food:ScanBags() end
local CT = { sections = { consumables = food } }
local addon = { combatTracker = CT, db = { combatTracker = db } }
assert(loadfile("Features/CombatTracker_FoodMacros.lua"))("MathWroQOL", addon)
local function named(name)
    for _, macro in ipairs(macros) do if macro.name == name then return macro end end
end
local inventory = { [2070] = 4, [159] = 8, [113509] = 6 }
local function use(name)
    local macro = assert(named(name))
    local itemID = tonumber(macro.body:match("/use %[%s*nocombat%s*%] item:(%d+)"))
    if not combat and itemID and (inventory[itemID] or 0) > 0 then inventory[itemID] = inventory[itemID] - 1 end
end
CT:UpdateFoodMacros()
assert(#macros == 0 and writes == 0, "normal bag scans must not create unrequested macros")
characterMacros[1] = { name = "MQOL Food", body = "/say character-owned" }
local ok, message = CT:CreateFoodWaterMacros()
assert(ok, message)
assert(#macros == 2 and named("MQOL Food") and named("MQOL Water"), "one button creates both General macros")
use("MQOL Food"); use("MQOL Water")
assert(inventory[2070] == 3 and inventory[159] == 7, "macros must consume their respective displayed selections")
assert(characterMacros[1].body == "/say character-owned", "character macros must remain untouched")
local before = writes
assert(CT:CreateFoodWaterMacros())
CT:UpdateFoodMacros()
assert(#macros == 2 and writes == before, "repeated creation and unchanged selections must not duplicate or rewrite macros")
combat = true
food.selectedFood, food.selectedWater = { itemID = 113509 }, { itemID = 113509 }
CT:UpdateFoodMacros()
use("MQOL Food")
assert(writes == before and inventory[2070] == 3, "combat must block edits and macro item use")
combat = false
assert(events.PLAYER_REGEN_ENABLED, "pending selection changes need a combat-exit path")
events.frame:onEvent("PLAYER_REGEN_ENABLED")
use("MQOL Food"); use("MQOL Water")
assert(inventory[113509] == 4 and inventory[2070] == 3, "both hybrid macros must follow the latest selection after combat")
food.selectedWater = nil
CT:UpdateFoodMacros()
local hybridCount = inventory[113509]
use("MQOL Water")
assert(inventory[113509] == hybridCount, "missing water must clear stale use commands")
-- A user deleting a managed macro is not permission to recreate it on bag updates.
for index, macro in ipairs(macros) do if macro.name == "MQOL Water" then table.remove(macros, index); break end end
CT:UpdateFoodMacros()
assert(not named("MQOL Water"), "automatic updates must not recreate deleted macros")
assert(CT:CreateFoodWaterMacros())
assert(named("MQOL Water"), "explicit creation must repair a missing managed macro")
for index, macro in ipairs(macros) do if macro.name == "MQOL Food" then table.remove(macros, index); break end end
assert(CT:CreateFoodWaterMacros())
local beforeRepairUse = inventory[113509]
use("MQOL Food"); use("MQOL Water")
assert(inventory[113509] == beforeRepairUse - 1,
    "creating food before an existing water macro must preserve targets after account indices reorder")
-- Names alone do not establish ownership.
named("MQOL Food").body = "/say user food"
before = writes
local created = CT:CreateFoodWaterMacros()
assert(not created and named("MQOL Food").body == "/say user food" and writes == before,
    "unrelated same-name macros must never be overwritten")
CT:UpdateFoodMacros()
assert(named("MQOL Food").body == "/say user food", "automatic updates must also honor ownership")
-- Preflight both names and capacity before allocating either macro.
macros = {}
for index = 1, MAX_ACCOUNT_MACROS - 1 do macros[index] = { name = "User " .. index, body = "/say kept" } end
before = writes
assert(not CT:CreateFoodWaterMacros() and #macros == MAX_ACCOUNT_MACROS - 1 and writes == before,
    "one free slot must not leave a half-created pair")
macros = {}
combat = true
assert(not CT:CreateFoodWaterMacros() and #macros == 0, "button invocation must not bypass combat locking")
combat = false
assert(CT:CreateFoodWaterMacros())
db.enabled = false
CT:UpdateFoodMacros()
local last = inventory[113509]
use("MQOL Food")
assert(inventory[113509] == last, "disabled tracker must not retain a stale food action")
print("CombatTracker smart food/water macro smoke: PASS")
