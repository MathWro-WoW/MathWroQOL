local _, addon = ...

local HeroicStrike = { name = "heroicStrike" }
addon:RegisterFeature(HeroicStrike)

local SPELL_ID = 1269383
local ARMS_SPEC_ID = 71
local ICON_SIZE = 40  -- Native CooldownViewerBuffIconItemTemplate size before iconScale.
local NATIVE_STYLE = { iconZoom = 0.08, borderSize = 0 }

local eventFrame
local iconFrame
local viewerHooked
local ellesmereHooked
local skinProvider
local layoutPending = false
local displayReady = false

local function isEnabled()
    local db = addon.db and addon.db.heroicStrike
    return db and db.enabled
end

local function isArms()
    local spec = GetSpecialization()
    return spec and GetSpecializationInfo(spec) == ARMS_SPEC_ID
end

local function getEllesmere()
    local namespaces = EllesmereUI and EllesmereUI._ModuleNS
    local ns = namespaces and namespaces.EllesmereUICooldownManager
    local profile = ns and ns.ECME and ns.ECME.db and ns.ECME.db.profile
    return ns, profile and profile.cdmBars and profile.cdmBars.enabled
end

local function updateIcon()
    if not isEnabled() or not iconFrame then return end
    local shown = displayReady and isArms() and C_SpellBook.IsSpellInSpellBook(SPELL_ID)
    iconFrame:SetShown(shown)
    local width, height = iconFrame:GetSize()
    addon:ApplyIconGlow(iconFrame, iconFrame, shown and addon.db.heroicStrike.glowType or "none", width, height)
end

local function ensureFrame(parent)
    if not iconFrame then
        iconFrame = CreateFrame("Frame", "MathWroQOL_HeroicStrike", parent)
        iconFrame:Hide()
        iconFrame.ignoreInLayout = true
        iconFrame:SetFrameStrata("MEDIUM")
        local texture = iconFrame:CreateTexture(nil, "ARTWORK")
        texture:SetAllPoints()
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        texture:SetTexture(C_Spell.GetSpellTexture(SPELL_ID))
        iconFrame._tex = texture  -- Ellesmere's appearance helper accepts addon-owned icons.
    elseif iconFrame:GetParent() ~= parent then
        iconFrame:SetParent(parent)
    end
    iconFrame:SetFrameLevel(parent:GetFrameLevel() + 1)
    iconFrame:ClearAllPoints()
end

local function layoutEllesmere(ns)
    -- Explicit compatibility boundary: no native aura queries or modifications
    -- to Ellesmere's icon list. Missing capabilities do not fall back to the
    -- unrelated Blizzard viewer while Ellesmere is running.
    local pp = EllesmereUI.PP
    if not (ns.GetCDMBarFrame and ns.GetCDMBarIcons and ns.ApplyShapeToCDMIcon
        and ns.EffectiveBarAlpha and ns._AuraCustomPoke and pp and pp.CreateBorder) then return end
    local bar = ns.GetCDMBarFrame("buffs")
    local bd = ns.barDataByKey and ns.barDataByKey.buffs
    if not bar or not bd or not bd.enabled then return end

    ensureFrame(bar)
    local grow = bd.growDirection or "CENTER"
    local vertical = grow == "UP" or grow == "DOWN" or (grow == "CENTER" and bd.verticalOrientation)
    local reverse = addon.db.heroicStrike.side == "left"
    -- Vertical rows retain their growth-end placement by default.
    if vertical and grow == "UP" then reverse = not reverse end
    local icons = ns.GetCDMBarIcons("buffs")
    local reference
    if icons and bar._acLiveW ~= 0 then
        -- Use the provider's layout membership, not IsShown/alpha/aura state.
        -- Shift-hidden entries remain in its source list but do not occupy space.
        for i = 1, #icons do
            local candidate = icons[reverse and i or (#icons - i + 1)]
            local state = ns._ecmeFC and ns._ecmeFC[candidate]
            if not state or not (state._cdStateShiftHidden or state._missingActiveHidden) then
                reference = candidate
                break
            end
        end
    end

    local pixel = pp.mult or 1
    local gap = math.floor((bd.spacing or 2) / pixel + 0.5) * pixel
    if reference then
        local width, height = reference:GetSize()
        local scale = reference:GetEffectiveScale() / bar:GetEffectiveScale()
        iconFrame:SetSize(width * scale, height * scale)
        if vertical then
            if reverse then
                iconFrame:SetPoint("BOTTOMLEFT", reference, "TOPLEFT", 0, gap)
            else
                iconFrame:SetPoint("TOPLEFT", reference, "BOTTOMLEFT", 0, -gap)
            end
        elseif reverse then
            iconFrame:SetPoint("TOPRIGHT", reference, "TOPLEFT", -gap, 0)
        else
            iconFrame:SetPoint("TOPLEFT", reference, "TOPRIGHT", gap, 0)
        end
    else
        -- Ellesmere deliberately retains the empty bar's previous dimensions.
        -- With no layout participants, the proc occupies its first position.
        local size = bd.iconSize or 36
        local height = bd.iconShape == "cropped" and math.floor(size * 0.8 + 0.5) or size
        iconFrame:SetSize(math.floor(size / pixel + 0.5) * pixel, math.floor(height / pixel + 0.5) * pixel)
        local point = grow == "CENTER" and "CENTER"
            or (vertical and (grow == "UP" and "BOTTOM" or "TOP") or (grow == "LEFT" and "RIGHT" or "LEFT"))
        iconFrame:SetPoint(point, bar, point, 0, 0)
    end

    if skinProvider ~= ns then
        pp.CreateBorder(iconFrame, 0, 0, 0, 1, 1)
        skinProvider = ns
    end
    -- Reuse the provider's crop, border and shape code, including live settings.
    ns.ApplyShapeToCDMIcon(iconFrame, bd.iconShape or "none", bd)
    iconFrame:SetFrameStrata(bd.anchorTo == "mouse" and "TOOLTIP" or (bd.barStrata or "MEDIUM"))
    iconFrame:SetAlpha(ns.EffectiveBarAlpha(bd))
    displayReady = true
end

local function refreshLayout()
    if not isEnabled() or not isArms() then return end
    displayReady = false
    local ns, active = getEllesmere()
    if active then
        layoutEllesmere(ns)
    else
        local viewer = BuffIconCooldownViewer
        if viewer then
            ensureFrame(viewer)
            if skinProvider then
                skinProvider.ApplyShapeToCDMIcon(iconFrame, "none", NATIVE_STYLE)
                skinProvider = nil
            end
            local size = ICON_SIZE * (viewer.iconScale or 1)
            iconFrame:SetSize(size, size)
            if addon.db.heroicStrike.side == "left" then
                iconFrame:SetPoint("TOPRIGHT", viewer, "TOPLEFT", -6, 0)
            else
                iconFrame:SetPoint("TOPLEFT", viewer, "TOPRIGHT", 6, 0)
            end
            iconFrame:SetFrameStrata("MEDIUM")
            iconFrame:SetAlpha(1)
            displayReady = true
        end
    end
    updateIcon()
end

local function queueLayout()
    if not isEnabled() or not isArms() or layoutPending then return end
    layoutPending = true
    C_Timer.After(0, function()
        layoutPending = false
        refreshLayout()
    end)
end

local function hookProviders()
    local viewer = BuffIconCooldownViewer
    if viewer and viewerHooked ~= viewer then
        hooksecurefunc(viewer, "RefreshLayout", function()
            if not isEnabled() then return end
            local _, active = getEllesmere()
            if active then queueLayout() else refreshLayout() end
        end)
        viewerHooked = viewer
    end
    local ns = getEllesmere()
    if ns and ns._AuraCustomPoke and ellesmereHooked ~= ns then
        -- This provider notification covers layout (even unchanged/empty size),
        -- visibility and opacity. It fires BEFORE final icon positioning.
        hooksecurefunc(ns, "_AuraCustomPoke", function(barKey)
            if barKey == "buffs" then queueLayout() end
        end)
        if ns.RefreshAuraCustomStyle then
            hooksecurefunc(ns, "RefreshAuraCustomStyle", function(barKey)
                if barKey == "buffs" then queueLayout() end
            end)
        end
        ellesmereHooked = ns
    end
end

function HeroicStrike:Apply()
    if eventFrame then eventFrame:UnregisterAllEvents() end
    if iconFrame then
        iconFrame:Hide()
        addon:ApplyIconGlow(iconFrame, iconFrame, "none")
    end
    displayReady = false
    if not isEnabled() then return end

    local _, class = UnitClass("player")
    if class ~= "WARRIOR" then return end
    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        eventFrame:SetScript("OnEvent", function(_, event, unitOrAddon)
            if not isEnabled() then return end
            if event == "PLAYER_SPECIALIZATION_CHANGED" then
                if unitOrAddon == "player" then HeroicStrike:Apply() end
            elseif event == "SPELLS_CHANGED" then
                updateIcon()
            elseif event == "PLAYER_ENTERING_WORLD"
                or (event == "ADDON_LOADED" and (unitOrAddon == "Blizzard_CooldownViewer"
                    or unitOrAddon == "EllesmereUICooldownManager")) then
                hookProviders()
                refreshLayout()
            end
        end)
    end

    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    if not isArms() then return end
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("SPELLS_CHANGED")
    eventFrame:RegisterEvent("ADDON_LOADED")
    hookProviders()
    refreshLayout()
end

function HeroicStrike:Initialize()
    self:Apply()
end
