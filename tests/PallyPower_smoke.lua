-- Protected-frame/aura boundaries are stubbed; exercise the real feature lifecycle.
local frames, hooks, pending, timers = {}, {}, {}, {}
local combat, restricted, now, scans = false, false, 100, 0
local secret = {}
function InCombatLockdown() return combat end
function GetTime() return now end
function issecretvalue(value) return value == secret end
function canaccesstable(value) return value ~= secret end
function UnitClass() return "Paladin", "PALADIN" end
function UnitIsConnected() return true end
function UnitIsVisible() return true end
function UnitIsDeadOrGhost() return false end
function GetUnitName(unit) return unit == "player" and "Me" or "Friend" end
local aura = { expirationTime = 3700 }
C_Secrets = { ShouldAurasBeSecret = function() return restricted end }
C_UnitAuras = { GetAuraDataBySpellName = function(unit, name)
    assert(not combat and not restricted, "must not query restricted auras")
    scans = scans + 1
    if name == "Wisdom" then return aura end
end }
C_Timer = {
    After = function(_, callback) pending[#pending + 1] = callback end,
    NewTimer = function(delay, callback)
        local timer = { at = now + delay, callback = callback }
        function timer:Cancel() self.cancelled = true end
        timers[#timers + 1] = timer
        return timer
    end,
}
function CreateFrame()
    local frame = { events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterAllEvents() self.events = {} end
    function frame:SetScript(_, callback) self.callback = callback end
    frames[#frames + 1] = frame
    return frame
end
local root = { shown = true }
function root:IsShown() return self.shown end
function root:Show() assert(not combat); self.shown = true end
function RegisterStateDriver(frame, state, condition)
    assert(not combat and state == "visibility")
    frame.driver = condition
    frame.shown = not condition:find("; hide", 1, true)
end
function UnregisterStateDriver(frame) assert(not combat); frame.driver = nil end
function hooksecurefunc(object, name, callback)
    local original = object[name]
    object[name] = function(...) local result = original(...); callback(...); return result end
end
local unit = { unitid = "party1", name = "Friend" }
local assigned = 1
PallyPower = { Header = root, opt = { enabled = true }, Spells = { "Wisdom", "Might" }, GSpells = {} }
function PallyPower:GetUnit(class, index) if class == 1 and index == 1 then return unit end end
function PallyPower:GetSpellID() return assigned, assigned end
function PallyPower:GetBuffAlternatives(normal, greater) return normal, greater end
function PallyPower:ButtonsUpdate() end
function PallyPower:UpdateRoster() end
function PallyPower:UpdateLayout() end
local addon = { isForever = true, db = { pallyPower = { enabled = false } } }
function addon:RegisterFeature(feature) self.feature = feature end
local chunk = loadfile("Features/PallyPower.lua")
assert(chunk, "PallyPower visibility feature must exist")
chunk("MathWroQOL", addon)
local feature = assert(addon.feature)
local function flush()
    while #pending > 0 do
        local work = pending; pending = {}
        for _, callback in ipairs(work) do callback() end
    end
end
local function event(name)
    for _, frame in ipairs(frames) do if frame.events[name] then frame.callback(frame, name) end end
    flush()
end
local function refresh() PallyPower:ButtonsUpdate(); flush() end
feature:Initialize(); flush()
assert(root.shown and scans == 0, "disabled feature must leave provider untouched")
addon.db.pallyPower.enabled = true
feature:Apply(); flush()
assert(not root.shown, "confirmed assigned blessing must hide buff bar")
aura = nil; refresh()
assert(root.shown, "missing blessing must reveal buff bar")
aura = { expirationTime = now + 240 }; refresh()
assert(root.shown, "blessing at refresh threshold must reveal buff bar")
aura = { expirationTime = now + 1000 }; refresh()
assert(not root.shown)
local expiryTimer
for _, timer in ipairs(timers) do if not timer.cancelled then expiryTimer = timer end end
assert(expiryTimer and expiryTimer.at == now + 760, "hidden bar needs a scheduled pre-expiry wakeup")
now = expiryTimer.at; expiryTimer.callback(); flush()
assert(root.shown, "time alone must reveal a blessing needing refresh")
aura = secret; refresh(); assert(root.shown, "secret aura tables are unknown, not satisfied")
aura = { expirationTime = secret }; refresh(); assert(root.shown, "secret expiry must not be compared")
aura = { expirationTime = now + 1000 }
assigned = 2; refresh(); assert(root.shown, "wrong assigned blessing must not satisfy the bar")
assigned = 1; refresh(); assert(not root.shown)
restricted = true; refresh(); assert(root.shown, "restricted aura state must fail open")
restricted = false; refresh(); assert(not root.shown)
event("GROUP_ROSTER_UPDATE"); assert(root.shown, "roster change must reveal until provider refresh")
PallyPower:UpdateRoster(); flush(); assert(not root.shown)
unit.name = "Previous occupant"; refresh(); assert(root.shown, "recycled unit token must not satisfy an old assignment")
unit.name = "Friend"; refresh(); assert(not root.shown)
combat = true
-- Simulate Blizzard's preinstalled secure driver, never an insecure frame call.
assert(root.driver:find("[combat] show", 1, true)); root.shown = true
local before = scans
refresh(); assert(root.shown and scans == before, "combat must preserve access without scanning auras")
addon.db.pallyPower.enabled = false; feature:Apply(); flush()
assert(root.driver, "combat disable must defer protected cleanup")
combat = false; event("PLAYER_REGEN_ENABLED")
assert(root.shown and not root.driver, "deferred disable must restore ordinary provider visibility")
before = scans; refresh(); assert(scans == before, "retained hooks must be inert after disable")
addon.db.pallyPower.enabled = true; assigned = 0; feature:Apply(); flush()
assert(root.shown, "no assignments must not hide the bar")
assigned = 1; PallyPower.opt.enabled = false; refresh()
assert(root.shown and not root.driver, "disabled provider must release visibility ownership")
PallyPower.opt.enabled = true; refresh(); assert(not root.shown)
addon.db.pallyPower.enabled = false; feature:Apply(); flush(); assert(root.shown)
local provider = PallyPower
PallyPower = nil
addon.db.pallyPower.enabled = true; feature:Apply(); flush()
assert(root.shown and not root.driver, "absent provider must remain inert")
PallyPower = provider; event("ADDON_LOADED")
assert(not root.shown, "late provider loading must activate the saved preference")
addon.db.pallyPower.enabled = false; feature:Apply(); flush()
-- Simulate reloading with the setting saved on while already in combat.
local reloaded = { isForever = true, db = { pallyPower = { enabled = true } } }
function reloaded:RegisterFeature(value) self.feature = value end
chunk("MathWroQOL", reloaded)
combat = true; before = scans
reloaded.feature:Initialize(); flush()
assert(scans == before and not root.driver, "combat login must defer setup and scans")
combat = false; event("PLAYER_REGEN_ENABLED")
assert(not root.shown, "combat login must initialize on regeneration")
aura = nil; event("UNIT_AURA")
assert(root.shown, "regeneration must restore all active event subscriptions")
reloaded.db.pallyPower.enabled = false; reloaded.feature:Apply(); flush()
function UnitClass() return "Warrior", "WARRIOR" end
before = scans
reloaded.db.pallyPower.enabled = true; reloaded.feature:Apply(); flush()
assert(root.shown and scans == before and not root.driver, "non-Paladins must never activate")
local retail = { isForever = false }
function retail:RegisterFeature() error("Retail must not register this runtime") end
chunk("MathWroQOL", retail)
print("PallyPower smoke PASS: confirmed buffs, overrides, expiry wakeup, restrictions, roster identity, combat, and cleanup")
