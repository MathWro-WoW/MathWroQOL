-- Developer-only: never show another character's or an outdated bind's zone.
local function runClient(interface)
    local frames, postCalls = {}, {}
    local guid, bind, zone = "Player-A", "Deepwater Tavern", "Wetlands"
    local queries = 0
    local secret = {}
    function GetBuildInfo() return nil, nil, nil, interface end
    function UnitGUID(unit) assert(unit == "player"); queries = queries + 1; return guid end
    function GetBindLocation() queries = queries + 1; return bind end
    function GetRealZoneText() queries = queries + 1; return zone end
    function issecretvalue(value) return value == secret end
    function CreateFrame()
        local frame = { events = {} }
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:UnregisterAllEvents() self.events = {} end
        function frame:SetScript(_, callback) self.onEvent = callback end
        frames[#frames + 1] = frame
        return frame
    end
    Enum = { TooltipDataType = { Item = 0 } }
    TooltipDataProcessor = { AddTooltipPostCall = function(kind, callback)
        assert(kind == Enum.TooltipDataType.Item)
        postCalls[#postCalls + 1] = callback
    end }
    GameTooltip = {}
    local function hover(itemID, text)
        local lines = { { text = "Hearthstone" }, { text = text } }
        for _, line in ipairs(lines) do
            function line:GetText() return self.text end
            function line:SetText(value) self.text = value end
        end
        function GameTooltip:NumLines() return #lines end
        function GameTooltip:GetLeftLine(index) return lines[index] end
        local data = { type = Enum.TooltipDataType.Item, id = itemID }
        for _, callback in ipairs(postCalls) do callback(GameTooltip, data) end
        return lines[2].text, function()
            for _, callback in ipairs(postCalls) do callback(GameTooltip, data) end
            return lines[2].text
        end
    end
    local function bound()
        for _, frame in ipairs(frames) do
            if frame.events.HEARTHSTONE_BOUND then frame.onEvent(frame, "HEARTHSTONE_BOUND") end
        end
    end
    local function login(saved)
        frames, postCalls = {}, {}
        MathWroQOLDB = saved
        local addon = {}
        SlashCmdList = {}
        assert(loadfile("Core.lua"))("MathWroQOL", addon)
        local core = frames[1]
        core.onEvent(core, "ADDON_LOADED", "MathWroQOL")
        assert(loadfile("Features/HearthstoneZone.lua"), "Hearthstone zone feature is missing")("MathWroQOL", addon)
        core.onEvent(core, "PLAYER_LOGIN")
        return addon
    end
    local addon = login()
    local native = "Use: Returns you to Deepwater Tavern. Speak to an Innkeeper to change your home."
    local wanted = "Use: Returns you to Deepwater Tavern (Wetlands). Speak to an Innkeeper to change your home."
    bound()
    assert(hover(6948, native) == native and queries == 0, "disabled feature must not query locations or change tooltips")
    addon.db.hearthstoneZone.enabled = true
    addon:NotifyFeature("hearthstoneZone")
    assert(hover(6948, native) == native, "enabling must not guess the zone from the player's current location")
    bound()
    zone = "Dun Morogh"
    local text, repeatHover = hover(6948, native)
    assert(text == wanted, "Hearthstone must display the zone captured at binding, not the current zone")
    assert(repeatHover() == wanted, "repeated tooltip processing must not duplicate the zone")
    assert(hover(12345, native) == native, "unrelated item tooltips must stay untouched")
    assert(hover(secret, native) == native and hover(6948, secret) == secret, "restricted tooltip values must not be inspected")

    addon = login(MathWroQOLDB)
    assert(hover(6948, native) == wanted, "a reload must retain the character's saved bind zone")
    guid = "Player-B"
    assert(hover(6948, native) == native, "another character with the same inn name must not inherit the zone")
    bound()
    assert(hover(6948, native) == "Use: Returns you to Deepwater Tavern (Dun Morogh). Speak to an Innkeeper to change your home.", "each character must retain its own zone")
    guid = "Player-A"
    assert(hover(6948, native) == wanted, "saving an alt must preserve the first character's destination")
    bind = "Lion's Pride Inn"
    assert(hover(6948, "Lion's Pride Inn") == "Lion's Pride Inn", "a changed bind must never display the previous inn's zone")
    bind = "Deepwater Tavern"
    assert(hover(6948, native) == native, "an invalidated destination must not reappear if its name is later reused")
    zone = "Wetlands"
    bound()
    addon.db.hearthstoneZone.enabled = false
    addon:NotifyFeature("hearthstoneZone")
    local before = queries
    bind, zone = "Other Inn", "Elwynn Forest"
    bound()
    assert(hover(6948, native) == native and queries == before, "disabling must stop capture and tooltip work")
    addon.db.hearthstoneZone.enabled = true
    addon:NotifyFeature("hearthstoneZone")
    assert(hover(6948, "Other Inn") == "Other Inn", "re-enabling after a missed bind must not reuse a stale zone")
    bound()
    assert(hover(6948, "Other Inn") == "Other Inn (Elwynn Forest)", "re-enabling must resume bind capture")
    zone = ""
    bound()
    assert(hover(6948, "Other Inn") == "Other Inn", "a bind with unavailable zone data must invalidate the old destination")
    bind, zone = "Inn (100%)", "Wetlands"
    bound()
    assert(hover(6948, "Return to Inn (100%).") == "Return to Inn (100%) (Wetlands).", "inn names must be treated as literal text, not Lua patterns")
    bind, zone = "Stormwind City", "Stormwind City"
    bound()
    assert(hover(6948, "Stormwind City") == "Stormwind City", "a destination already named after its zone needs no repeated name")
end
runClient(16001)
runClient(120100)
print("HearthstoneZone smoke PASS: saved zones, reload, character isolation, stale binds, toggles, and safe tooltip replacement on Forever and Retail")
