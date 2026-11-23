local _, addon = ...

local HearthstoneZone = { name = "hearthstoneZone" }
addon:RegisterFeature(HearthstoneZone)

local HEARTHSTONE_ITEM_ID = 6948
local eventFrame
local hooked = false

local function getBindZone()
    local mapID = C_Map.GetBestMapForUnit("player")
    while mapID and mapID ~= 0 do
        local info = C_Map.GetMapInfo(mapID)
        if not info or info.mapType < Enum.UIMapType.Zone then break end
        -- Interiors can report the inn or keep as their real-zone text.
        if info.mapType == Enum.UIMapType.Zone then return info.name end
        mapID = info.parentMapID
    end
    return GetRealZoneText()
end

local function captureBind()
    local db = addon.db and addon.db.hearthstoneZone
    if not db or not db.enabled then return end

    local guid = UnitGUID("player")
    if not guid then return end
    local location = GetBindLocation()
    local zone = getBindZone()
    -- A successful bind replaces the destination even if its zone is unavailable.
    db.characters[guid] = nil
    if not location or location == "" or not zone or zone == "" then return end
    db.characters[guid] = { location = location, zone = zone }
end

local function enhanceTooltip(tooltip, data)
    local db = addon.db and addon.db.hearthstoneZone
    if not db or not db.enabled or tooltip ~= GameTooltip then return end
    if not data or issecretvalue(data.id) or data.id ~= HEARTHSTONE_ITEM_ID then return end

    local guid = UnitGUID("player")
    local destination = guid and db.characters[guid]
    if not destination then return end
    if destination.location ~= GetBindLocation() then
        db.characters[guid] = nil
        return
    end
    if destination.location == destination.zone then return end

    local label = destination.location .. " (" .. destination.zone .. ")"
    for index = 2, tooltip:NumLines() do
        local line = tooltip:GetLeftLine(index)
        local text = line:GetText()
        if not issecretvalue(text) and type(text) == "string" then
            if text:find(label, 1, true) then return end
            local first, last = text:find(destination.location, 1, true)
            if first then
                line:SetText(text:sub(1, first - 1) .. label .. text:sub(last + 1))
                return
            end
        end
    end
end

function HearthstoneZone:Apply()
    local db = addon.db and addon.db.hearthstoneZone
    if not db or not db.enabled then
        if eventFrame then eventFrame:UnregisterAllEvents() end
        return
    end

    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        eventFrame:SetScript("OnEvent", captureBind)
    end
    eventFrame:RegisterEvent("HEARTHSTONE_BOUND")
    if not hooked then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, enhanceTooltip)
        hooked = true
    end
end

function HearthstoneZone:Initialize()
    self:Apply()
end
