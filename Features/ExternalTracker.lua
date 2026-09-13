local _, addon = ...

local ExternalTracker = {
    name = "externalTracker",
    spells = {
        { spellID = 33206, label = "Pain Suppression" },
        { spellID = 47788, label = "Guardian Spirit" },
        { spellID = 102342, label = "Ironbark" },
        { spellID = 116849, label = "Life Cocoon" },
        { spellID = 6940, label = "Blessing of Sacrifice" },
        { spellID = 1022, label = "Blessing of Protection" },
        { spellID = 204018, label = "Blessing of Spellwarding" },
        { spellID = 1044, label = "Blessing of Freedom" },
        { spellID = 357170, label = "Time Dilation" },
        { spellID = 10060, label = "Power Infusion" },
        { spellID = 29166, label = "Innervate" },
    },
}
addon.externalTracker = ExternalTracker


local function applyAppearance(display, db, enabled)
    local zoom = (db.iconZoom or 8) / 100
    if display.zoom ~= zoom then
        display.icon:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
        display.zoom = zoom
    end
    addon:ApplyIconGlow(display, display.glowHost, enabled and db.glowType or "none", db.iconSize, db.iconSize)
end

local function registerTracker(Tracker, title, previewSpellID)
    local frameName = "MathWroQOL_" .. title:gsub(" ", "")
    local eventFrame, anchor, container, sharedMedia
    local slots, soundRegistrations = {}, {}
    local editMode, preview, previewAppearance

    local function hidePreview()
        if not preview then return end
        preview:Hide()
        if previewAppearance.glowGroup then previewAppearance.glowGroup:Stop() end
    end

    local function getDb()
        return addon.db and addon.db[Tracker.name]
    end

    local function removeSound(spellID)
        local registration = soundRegistrations[spellID]
        if not registration then return end
        C_UnitAuras.RemoveAuraSound(registration.id)
        soundRegistrations[spellID] = nil
    end

    local function detachMedia()
        if not sharedMedia then return end
        sharedMedia.UnregisterCallback(Tracker, "LibSharedMedia_Registered")
        sharedMedia = nil
    end

    local function syncMedia()
        local media = LibStub and LibStub("LibSharedMedia-3.0", true)
        if media == sharedMedia then return end
        detachMedia()
        sharedMedia = media
        if not media then return end
        media.RegisterCallback(Tracker, "LibSharedMedia_Registered", function(_, mediaType)
            local db = getDb()
            if db and db.enabled and mediaType == "sound" then Tracker:Apply() end
        end)
    end

    local function ensureEvents()
        if eventFrame then return end
        eventFrame = CreateFrame("Frame")
        eventFrame:SetScript("OnEvent", function(_, event, name)
            local db = getDb()
            if not db or not db.enabled then return end
            -- Loading the secure container can synchronously fire ADDON_LOADED.
            if event == "ADDON_LOADED" and name == "Blizzard_AuraContainer" then return end
            Tracker:Apply()
        end)
    end

    local function ensureAnchor(db)
        if anchor then return end
        anchor = CreateFrame("Frame", frameName, UIParent)
        anchor:SetSize(db.iconSize, db.iconSize)
        anchor:SetFrameStrata("MEDIUM")
        anchor:SetFrameLevel(10)
        anchor:SetClampedToScreen(true)
        anchor:SetPoint(db.point, UIParent, db.point, db.x, db.y)

        editMode = LibStub and LibStub("LibEditMode", true)
        if editMode then
            editMode:AddFrame(anchor, function(_, _, point, x, y)
                local current = getDb()
                if not current or not current.enabled or InCombatLockdown() then return end
                current.point = point
                current.x = math.floor(x + 0.5)
                current.y = math.floor(y + 0.5)
                Tracker:Apply()
            end, { point = db.point, x = db.x, y = db.y }, "MathWroQOL - " .. title)
            editMode:AddFrameSettings(anchor, {
                {
                    kind = editMode.SettingType.Slider, name = "Icon size", default = 40,
                    minValue = 20, maxValue = 80, valueStep = 1,
                    get = function() return getDb().iconSize end,
                    set = function(_, value)
                        local current = getDb()
                        if not current or not current.enabled or InCombatLockdown() then return end
                        current.iconSize = math.max(20, math.min(80, math.floor(value + 0.5)))
                        Tracker:Apply()
                    end,
                },
                {
                    kind = editMode.SettingType.Slider, name = "Icon zoom", default = 8,
                    desc = "Crop a percentage from each edge of the icon. Applies to all tracked icons.",
                    minValue = 0, maxValue = 30, valueStep = 1,
                    get = function() return getDb().iconZoom or 8 end,
                    set = function(_, value)
                        local current = getDb()
                        if not current or not current.enabled or InCombatLockdown() then return end
                        current.iconZoom = math.max(0, math.min(30, math.floor(value + 0.5)))
                        Tracker:Apply()
                    end,
                },
                {
                    kind = editMode.SettingType.Dropdown, name = "Glow type", default = "none",
                    desc = "Animated glow for all active icons. The preview uses the same glow.",
                    values = {
                        { text = "None", value = "none" },
                        { text = "Classic", value = "classic" },
                        { text = "Modern Proc", value = "proc" },
                        { text = "Assisted Combat", value = "assist" },
                    },
                    get = function() return getDb().glowType or "none" end,
                    set = function(_, value)
                        local current = getDb()
                        if not current or not current.enabled or InCombatLockdown() then return end
                        current.glowType = value
                        Tracker:Apply()
                    end,
                },
            })
            for _, event in ipairs({ "enter", "exit" }) do
                editMode:RegisterCallback(event, function()
                    local current = getDb()
                    if current and current.enabled then Tracker:Apply() end
                end)
            end
            if editMode:IsInEditMode() then editMode.frameSelections[anchor]:ShowHighlighted() end
        end

    end

    local function ensureContainer()
        if container then return true end
        if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
            C_AddOns.LoadAddOn("Blizzard_AuraContainer")
        end
        if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then return false end
        container = CreateFrame("AuraContainer", nil, anchor, "CustomAuraContainerTemplate")
        container:SetSize(1, 1)
        container:SetPoint("TOPLEFT", anchor, "TOPLEFT")
        container:SetEnabled(false)
        container:SetUnit("player")
        return true
    end

    local function createSlot(spellID)
        local key = tostring(spellID)
        -- Only this ordinary anchor is resized later; aura buttons can deny access
        -- whenever aura data is secret, including outside combat.
        local host = CreateFrame("Frame", nil, anchor)
        local slot = { key = key, host = host, enabled = false }
        container:AddAuraSlot(key, "HELPFUL", {
            candidateFilters = { includeSpellIDs = {} },
            initializeFrame = function(auraButton)
                auraButton:SetAllPoints(host)
                auraButton:SetMouseMotionEnabled(false)
                auraButton:SetMouseClickEnabled(false)
                local icon = auraButton:CreateTexture(nil, "ARTWORK")
                icon:SetAllPoints()
                slot.icon = icon
                auraButton:SetIcon(icon)

                local cooldown = CreateFrame("Cooldown", nil, auraButton, "CooldownFrameTemplate")
                cooldown:SetAllPoints()
                cooldown:SetDrawEdge(false)
                cooldown:SetHideCountdownNumbers(true)
                auraButton:SetDurationCooldown(cooldown)

                local text = cooldown:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
                text:SetPoint("CENTER")
                auraButton:SetDurationText(text, {})
                slot.glowHost = CreateFrame("Frame", nil, auraButton)
                slot.glowHost:SetAllPoints(auraButton)
                slot.glowHost:SetFrameLevel(cooldown:GetFrameLevel() + 1)
            end,
        })
        applyAppearance(slot, getDb(), false)
        slots[spellID] = slot
        return slot
    end

    local function syncSound(spellID, settings)
        local mode = settings and settings.mode or "icon"
        local wantsSound = settings and settings.enabled and (mode == "sound" or mode == "both")
        local sound
        if wantsSound and sharedMedia and settings.sound and settings.sound ~= "None" then
            sound = sharedMedia:Fetch("sound", settings.sound, true)
        end
        if sound == "" or sound == 1 then sound = nil end
        local registration = soundRegistrations[spellID]
        if registration and registration.sound == sound then return end
        removeSound(spellID)
        if not sound then return end

        -- Blizzard owns the trigger; Lua never needs to inspect secret aura state.
        local info = { unitToken = "player", spellID = spellID, outputChannel = "Master" }
        if type(sound) == "number" then
            info.soundFileID = sound
        else
            info.soundFileName = sound
        end
        local id = C_UnitAuras.AddAuraSound(Enum.UnitAuraSoundTrigger.Added, info)
        if id then soundRegistrations[spellID] = { id = id, sound = sound } end
    end

    function Tracker:Apply()
        local db = getDb()
        if not db or not db.enabled then
            if eventFrame then eventFrame:UnregisterAllEvents() end
            detachMedia()
            for spellID in pairs(soundRegistrations) do removeSound(spellID) end
            if container then container:SetEnabled(false) end
            hidePreview()
            for _, slot in pairs(slots) do
                if slot.glowGroup then slot.glowGroup:Stop() end
                slot.glowType = nil
            end
            if anchor then anchor:Hide() end
            return
        end

        ensureEvents()
        local editing = editMode and editMode:IsInEditMode() and not InCombatLockdown()
        if not editing then hidePreview() end
        if container then container:SetShown(not editing) end
        if InCombatLockdown() then
            eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
            return
        end
        eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        eventFrame:RegisterEvent("ADDON_LOADED")
        eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
        ensureAnchor(db)
        editing = editMode and editMode:IsInEditMode()
        if db.spells then syncMedia() end

        local iconCount = 0
        for _, spell in ipairs(self.spells) do
            local spellID = spell.spellID
            local settings = db
            if db.spells then settings = db.spells[spellID] end
            local mode = settings and settings.mode or "icon"
            local wantsIcon = settings and settings.enabled and (mode == "icon" or mode == "both")
            local slot = slots[spellID]
            if wantsIcon and ensureContainer() then
                slot = slot or createSlot(spellID)
                slot.host:SetSize(db.iconSize, db.iconSize)
                slot.host:ClearAllPoints()
                slot.host:SetPoint("TOPLEFT", anchor, "TOPLEFT", iconCount * (db.iconSize + 4), 0)
                iconCount = iconCount + 1
            end
            if slot and slot.enabled ~= (wantsIcon == true) then
                slot.enabled = wantsIcon == true
                container:SetAuraSlotCandidateFilters(slot.key, {
                    includeSpellIDs = slot.enabled and (spell.spellIDs or { [spellID] = true }) or {},
                })
            end
            if slot then applyAppearance(slot, db, wantsIcon) end
            syncSound(spellID, settings)
        end

        if container then
            container:SetEnabled(iconCount > 0)
            container:SetShown(not editing)
        end
        if editing then
            if not preview then
                preview = CreateFrame("Frame", frameName .. "Preview", anchor)
                preview:SetPoint("TOPLEFT", anchor, "TOPLEFT")
                local icon = preview:CreateTexture(nil, "ARTWORK")
                icon:SetAllPoints()
                icon:SetTexture(C_Spell.GetSpellInfo(previewSpellID).iconID)
                previewAppearance = { icon = icon, glowHost = preview }
            end
            preview:SetSize(db.iconSize, db.iconSize)
            applyAppearance(previewAppearance, db, true)
            preview:Show()
        end
        anchor:SetShown(iconCount > 0 or editing == true)
        anchor:SetSize(math.max(1, iconCount) * (db.iconSize + 4) - 4, db.iconSize)
        anchor:ClearAllPoints()
        anchor:SetPoint(db.point, UIParent, db.point, db.x, db.y)
    end

    function Tracker:Initialize()
        local db = getDb()
        if not db or not db.enabled then return end
        self:Apply()
    end

    addon:RegisterFeature(Tracker)
end

registerTracker(ExternalTracker, "External Tracker", 10060)

local BloodlustTracker = {
    name = "bloodlustTracker",
    spells = {
        {
            spellID = 2825, label = "Bloodlust",
            -- Helpful aura IDs, not cast IDs or Sated/Exhaustion debuffs.
            spellIDs = {
                [2825] = true, -- Bloodlust
                [32182] = true, -- Heroism
                [80353] = true, -- Time Warp
                [390386] = true, -- Fury of the Aspects
                [264667] = true, -- Primal Rage
                [357650] = true, -- Primal Rage (Lone Wolf)
                [90355] = true, -- Ancient Hysteria
                [160452] = true, -- Netherwinds
                [146555] = true, -- Drums of Rage
                [178207] = true, -- Drums of Fury
                [230935] = true, -- Drums of the Mountain
                [256740] = true, -- Drums of the Maelstrom
                [309658] = true, -- Drums of Deathly Ferocity
                [381301] = true, -- Feral Hide Drums
                [444257] = true, -- Thunderous Drums
                [1243972] = true, -- Void-touched Drums
            },
        },
    },
}
addon.bloodlustTracker = BloodlustTracker
registerTracker(BloodlustTracker, "Bloodlust Tracker", 2825)
