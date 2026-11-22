local _, addon = ...
if not addon.isForever then return end

local PallyTweaks = { name = "pallyPower" }
addon:RegisterFeature(PallyTweaks)

local REFRESH_SECONDS = 240
local eventFrame, hookedProvider, ownedFrame, driver, expiryTimer
local pending, rosterDirty = false, false

local function enabled()
    return addon.db and addon.db.pallyPower and addon.db.pallyPower.enabled
        and select(2, UnitClass("player")) == "PALADIN"
end

local function cancelExpiry()
    if expiryTimer then expiryTimer:Cancel(); expiryTimer = nil end
end

local function releaseVisibility()
    if not ownedFrame then return end
    UnregisterStateDriver(ownedFrame, "visibility")
    ownedFrame:Show()
    ownedFrame, driver = nil, nil
end

local function setVisibility(frame, hide)
    if ownedFrame ~= frame then
        releaseVisibility()
        -- Do not take ownership of a bar another controller already hid.
        if not frame:IsShown() then return end
        ownedFrame = frame
    end
    local condition = hide and "[combat] show; hide" or "show"
    if driver ~= condition then
        RegisterStateDriver(frame, "visibility", condition)
        driver = condition
    end
end

local function readable(value)
    return not issecretvalue(value)
end

-- Named lookup has RequiresNonSecretAura (returns nothing for restricted auras),
-- unlike index scans, which can raise RequiresUnitAuraAccess errors on Forever.
local function remainingFor(unit, name, now)
    if not name or name == "" then return end
    local aura = C_UnitAuras.GetAuraDataBySpellName(unit, name, "HELPFUL")
    if not readable(aura) or not aura or not canaccesstable(aura) then return end
    local expiration = aura.expirationTime
    if not readable(expiration) or type(expiration) ~= "number" then return end
    if expiration == 0 then return math.huge end
    return expiration - now
end

local function satisfaction(provider)
    if rosterDirty or not C_Secrets or not C_Secrets.ShouldAurasBeSecret
        or C_Secrets.ShouldAurasBeSecret() or not C_UnitAuras
        or not C_UnitAuras.GetAuraDataBySpellName then return end
    local count, minimum, now = 0, math.huge, GetTime()
    -- Forever's Vanilla layout has nine class columns and at most forty players.
    for class = 1, 9 do
        for index = 1, 40 do
            local unit = provider:GetUnit(class, index)
            if not unit then break end
            local blessing = provider:GetSpellID(class, unit.name)
            if blessing and blessing > 0 then
                local token = unit.unitid
                if not token then return end
                local name = GetUnitName(token, true)
                local connected, visible, dead = UnitIsConnected(token), UnitIsVisible(token), UnitIsDeadOrGhost(token)
                if not readable(name) or not readable(connected) or not readable(visible) or not readable(dead)
                    or name ~= unit.name or not connected or not visible or dead then return end
                -- A personal assignment overrides the class blessing. Greater and
                -- normal ranks of that SAME blessing (and accepted substitutes) count.
                local normal, greater, substitute = provider:GetBuffAlternatives(
                    provider.Spells[blessing], provider.GSpells[blessing])
                local best = math.max(remainingFor(token, normal, now) or 0,
                    remainingFor(token, greater, now) or 0,
                    remainingFor(token, substitute, now) or 0)
                if best <= REFRESH_SECONDS then return end
                count = count + 1
                minimum = math.min(minimum, best)
            end
        end
    end
    return count > 0, minimum
end

local function refresh()
    pending = false
    if InCombatLockdown() then return end
    cancelExpiry()
    if not enabled() then
        releaseVisibility()
        if eventFrame then eventFrame:UnregisterAllEvents() end
        return
    end
    local provider = PallyPower
    if not provider or not provider.Header or not provider.opt or not provider.opt.enabled
        or not provider.GetUnit or not provider.GetSpellID or not provider.GetBuffAlternatives
        or not provider.Spells or not provider.GSpells then
        releaseVisibility()
        return
    end
    local hide, remaining = satisfaction(provider)
    setVisibility(provider.Header, hide)
    if hide and remaining < math.huge then
        expiryTimer = C_Timer.NewTimer(remaining - REFRESH_SECONDS, function()
            expiryTimer = nil
            refresh()
        end)
    end
end

local function queueRefresh()
    if not enabled() or InCombatLockdown() or pending then return end
    pending = true
    C_Timer.After(0, refresh)
end

local function hookProvider()
    local provider = PallyPower
    if not provider or hookedProvider == provider or not provider.ButtonsUpdate
        or not provider.UpdateRoster or not provider.UpdateLayout then return end
    hookedProvider = provider
    hooksecurefunc(provider, "ButtonsUpdate", queueRefresh)
    hooksecurefunc(provider, "UpdateLayout", queueRefresh)
    hooksecurefunc(provider, "UpdateRoster", function()
        if not enabled() or InCombatLockdown() then return end
        rosterDirty = false
        queueRefresh()
    end)
end

function PallyTweaks:Apply()
    if not eventFrame then
        if not enabled() then return end
        eventFrame = CreateFrame("Frame")
        eventFrame:SetScript("OnEvent", function(_, event)
            if event == "PLAYER_REGEN_ENABLED" then
                PallyTweaks:Apply()
                return
            end
            if not enabled() then return end
            if event == "GROUP_ROSTER_UPDATE" then rosterDirty = true end
            if InCombatLockdown() then return end
            if event == "ADDON_LOADED" then hookProvider() end
            queueRefresh()
        end)
    end
    if InCombatLockdown() then
        -- Even disabling must retain this one listener until protected cleanup.
        eventFrame:UnregisterAllEvents()
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    eventFrame:UnregisterAllEvents()
    if not enabled() then refresh(); return end
    for _, event in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
        "GROUP_ROSTER_UPDATE", "UNIT_AURA" }) do
        eventFrame:RegisterEvent(event)
    end
    hookProvider()
    refresh()
end

function PallyTweaks:Initialize()
    self:Apply()
end
