-- Developer-only: bounded diagnostics must not turn a repeated taint failure into an unbounded log.
local function runtime(saved)
    local H = { owners = {}, frames = {}, messages = {}, stackCalls = 0, reads = 0 }
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.SlashCmdList = {}
    env.MathWroQOLDB = saved or { enabled = false }
    local addon = {
        db = { taintDiagnostics = env.MathWroQOLDB, editModeNudge = {}, vehicleBar = {},
            combatTracker = { frames = { consumables = {} } } },
    }
    function addon:RegisterFeature(feature) H.feature = feature end
    function env.CreateFrame()
        local frame = { events = {} }
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:UnregisterAllEvents() self.events = {} end
        function frame:SetScript(_, callback) self.callback = callback end
        H.frames[#H.frames + 1] = frame
        return frame
    end
    env.MainActionBar = { anchor = "original", direction = "UP" }
    function env.MainActionBar:SetSnappedToFrame(target) self.anchor = target end
    function env.MainActionBar:UpdateSpellFlyoutDirection(direction) self.direction = direction end
    env.ActionButton7, env.ActionButton10, env.EditModeManagerFrame = {}, {}, {}
    env.SettingsPanel = {}
    local visibilitySetting = {}
    env.Settings = { GetSetting = function(variable)
        if variable == "PROXY_SHOW_ACTIONBAR_2" then return visibilitySetting end
    end }
    function env.MultiActionBar_GetBarForPage(page) return page end
    function env.issecurevariable(frame, key)
        H.reads = H.reads + 1
        local owner = H.owners[frame] and H.owners[frame][key]
        return owner == nil, owner
    end
    function env.hooksecurefunc(frame, method, callback)
        local original = frame[method]
        frame[method] = function(self, ...)
            local result = original(self, ...)
            callback(self, ...)
            return result
        end
    end
    function env.debugstack()
        H.stackCalls = H.stackCalls + 1
        return H.stack or "producer.lua:42: native positioning caller"
    end
    function env.GetTime() return 10 end
    function env.date() return "2026-11-23 18:00:00" end
    function env.GetBuildInfo() return "1.60.1", "70938", "", 16001 end
    env.C_AddOns = { GetAddOnMetadata = function() return "test" end }
    function env.InCombatLockdown() return false end
    function env.print(message) H.messages[#H.messages + 1] = message end
    local chunk = loadfile("Features/TaintDiagnostics.lua")
    assert(chunk, "bounded taint diagnostics must be available without global taint logging")
    setfenv(chunk, env)("MathWroQOL", addon)
    H.env, H.db = env, addon.db.taintDiagnostics
    function H.command(text) env.SlashCmdList.MQOLTAINT(text) end
    function H.owner(frame, field, owner)
        H.owners[frame] = H.owners[frame] or {}
        H.owners[frame][field] = owner
    end
    function H.fire(event, name, action)
        for _, frame in ipairs(H.frames) do
            if frame.events[event] then frame.callback(frame, event, name, action) end
        end
    end
    H.feature:Initialize()
    return H
end

local H = runtime()
assert(not H.db.current and H.reads == 0 and #H.frames == 0, "disabled logging must stay inert")
H.command("on")
assert(H.db.enabled and H.db.current, "enable command must start a bounded capture")
local env, current = H.env, H.db.current
assert(current.initial.MainActionBar.flyoutDirection == "secure-or-unset", "capture must distinguish clean baseline from later taint")
H.owner(env.MainActionBar, "snappedToFrame", "OtherAddon")
env.MainActionBar:SetSnappedToFrame("other anchor")
assert(current.initial.PROXY_SHOW_ACTIONBAR_2 and current.initial.PROXY_SHOW_ACTIONBAR_2.GetValueDerived == "secure-or-unset",
    "startup capture must retain ownership of native visibility-setting inputs")
H.owner(env.Settings.GetSetting("PROXY_SHOW_ACTIONBAR_2"), "GetValueDerived", "MathWroQOL")
assert(env.MultiActionBar_GetBarForPage(6) == 6, "cache tracing must preserve the native API result")
assert(current.firstBarCacheCall.method == "MultiActionBar_GetBarForPage" and
    current.firstBarCacheCall.stack == "producer.lua:42: native positioning caller",
    "the first public cache entry must retain its caller")
local cacheCall, cacheStacks = current.firstBarCacheCall, H.stackCalls
for _ = 1, 10000 do env.MultiActionBar_GetBarForPage(6) end
assert(current.firstBarCacheCall == cacheCall and H.stackCalls == cacheStacks,
    "cache tracing must stop building stacks after the first call")
assert(not current.probes.snappedToFrame, "another addon's state must not be blamed on MathWroQOL")
H.owner(env.MainActionBar, "snappedToFrame", "MathWroQOL")
env.MainActionBar.customGamepadModeVisibilityHandling = true
H.owner(env.MainActionBar, "customGamepadModeVisibilityHandling", "MathWroQOL")
env.MainActionBar:SetSnappedToFrame("new anchor")
assert(env.MainActionBar.anchor == "new anchor", "diagnostics must leave native placement working")
assert(current.probes.snappedToFrame.stack == "producer.lua:42: native positioning caller", "first observation must retain its caller stack")
assert(current.probes.snappedToFrame.observation == "posthook", "live observation must not be confused with preexisting taint")
local first = current.probes.snappedToFrame
local calls, reads = H.stackCalls, H.reads
for _ = 1, 10000 do env.MainActionBar:SetSnappedToFrame("later anchor") end
assert(current.probes.snappedToFrame == first and H.stackCalls == calls and H.reads == reads,
    "repeated layout calls must stop collecting data after the first matching observation")
assert(current.probes.snappedToFrame.frames.PROXY_SHOW_ACTIONBAR_2.GetValueDerived == "MathWroQOL",
    "first producer observation must include the native settings input ownership at that moment")
assert(current.probes.snappedToFrame.frames.metadata and
    current.probes.snappedToFrame.frames.metadata.MainActionBar.fields.customGamepadModeVisibilityHandling == "MathWroQOL",
    "producer snapshot must expose tainted native layout inputs beyond the original watched fields")
H.stack = string.rep("x", 100000)
H.owner(env.MainActionBar, "flyoutDirection", "MathWroQOL")
env.MainActionBar:UpdateSpellFlyoutDirection("DOWN")
assert(env.MainActionBar.direction == "DOWN" and #current.probes.flyoutDirection.stack <= 8192,
    "flyout observation must preserve native behavior while bounding saved stack size")
H.owner(env.ActionButton10, "action", "MathWroQOL")
H.fire("ADDON_ACTION_BLOCKED", "OtherAddon", "ActionButton10:SetAttribute()")
assert(not current.firstBlocked, "unrelated addon failures must be ignored")
H.fire("ADDON_ACTION_BLOCKED", "MathWroQOL", "ActionButton10:SetAttribute()")
assert(current.firstBlocked.action == "ActionButton10:SetAttribute()" and
    current.firstBlocked.frames.ActionButton10.action == "MathWroQOL", "blocked record must contain the actual action and field ownership")
local blocked, count = current.firstBlocked, H.stackCalls
for _ = 1, 10000 do H.fire("ADDON_ACTION_BLOCKED", "MathWroQOL", "ActionButton7:SetAttribute()") end
assert(current.firstBlocked == blocked and H.stackCalls == count and current.blockedCount == 10001,
    "repeated errors must increment a counter, not append snapshots or stacks")
H.command("off")
calls, reads = H.stackCalls, H.reads
H.fire("ADDON_ACTION_FORBIDDEN", "MathWroQOL", "Other()")
env.MainActionBar:UpdateSpellFlyoutDirection("UP")
assert(not H.db.enabled and H.stackCalls == calls and H.reads == reads, "disable must stop events and retained probe work")
H.command("on")
assert(H.db.current == current, "same-session re-enable must not rotate or erase evidence")
local reloaded = runtime(H.db)
assert(reloaded.db.previous == current and reloaded.db.current ~= current, "reload must retain the preceding capture")
local second = reloaded.db.current
local third = runtime(reloaded.db)
assert(third.db.previous == second and third.db.current ~= second and not third.db.previous.previous,
    "retention must stop at current and previous sessions")
H = runtime()
H.owner(H.env.MainActionBar, "flyoutDirection", "MathWroQOL")
H.command("on")
assert(H.db.current.probes.flyoutDirection.observation == "already-tainted" and
    not H.db.current.probes.flyoutDirection.stack, "starting after contamination must not invent an originating stack")
local limited = runtime()
for index = 1, 600 do limited.env.MainActionBar["layoutField" .. index] = true end
limited.command("on")
local metadata = limited.db.current.initial.metadata.MainActionBar
assert(metadata.scanned <= 512 and metadata.truncated,
    "unexpectedly large native objects must stop metadata inspection at the documented limit")
print("Taint diagnostics bounded capture smoke: PASS")
