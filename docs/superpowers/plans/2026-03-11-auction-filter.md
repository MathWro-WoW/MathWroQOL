# Auction House Filter Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Auto-enable "Current expansion only" and/or "Usable only" AH filters each time the player opens the Auction House, controlled by two independent toggles in the General settings panel.

**Architecture:** Blizzard exposes `AUCTION_HOUSE_DEFAULT_FILTERS` (a global table keyed by `Enum.AuctionHouseFilter.*` integers) which the AH reads each time it opens. The feature writes the two managed entries into this table on `ADDON_LOADED` for `Blizzard_AuctionHouseUI` and again on every `AUCTION_HOUSE_SHOW`. The event frame must be registered at **top level** (not inside `Initialize()`) to ensure it is in place before `Blizzard_AuctionHouseUI` loads. No widget manipulation needed.

**Tech Stack:** WoW Retail Lua addon (interface 120001). No build step. Test by `/reload` in-game and opening the AH.

> **Status:** ✅ Fully implemented and shipped in v1.1.0 (commit `4ddf75b`, default adjusted in `737d150`).

---

## Chunk 1: Core feature file and registration

**Files:**
- Create: `Features/AuctionFilter.lua`
- Modify: `MathWroQOL.toc` (add load entry)
- Modify: `Core.lua` (add defaults)

### Task 1: Add DB defaults

**Files:**
- Modify: `Core.lua`

- [x] **Step 1: Add `auctionFilter` defaults to the `defaults` table in `Core.lua`**

```lua
    auctionFilter = {
        currentExpansionOnly = false,
        usableOnly = false,
    },
```

Both default to `false` — the player opts in explicitly.

- [x] **Step 2: Register the TOC entry**

In `MathWroQOL.toc`, add after `Features\CDMButton.lua`:

```
Features\AuctionFilter.lua
```

- [x] **Step 3: Commit** *(done as part of the combined feature commit)*

---

### Task 2: Create the feature file

**Files:**
- Create: `Features/AuctionFilter.lua`

- [x] **Step 1: Create `Features/AuctionFilter.lua`**

The event frame is registered at **top level** (not inside `Initialize()`) so it catches the `Blizzard_AuctionHouseUI` `ADDON_LOADED` event regardless of load order. The correct AH open event is `AUCTION_HOUSE_SHOW` (not `AUCTION_HOUSE_OPENED`, which does not exist).

```lua
local _, addon = ...

local AuctionFilter = { name = "auctionFilter" }
addon:RegisterFeature(AuctionFilter)

-- Write the two managed filter entries into AUCTION_HOUSE_DEFAULT_FILTERS.
-- Only touches CurrentExpansionOnly and UsableOnly — all other entries untouched.
local function applyFilters()
    if not AUCTION_HOUSE_DEFAULT_FILTERS then return end
    local db = addon.db and addon.db.auctionFilter
    if not db then return end
    AUCTION_HOUSE_DEFAULT_FILTERS[Enum.AuctionHouseFilter.CurrentExpansionOnly] = db.currentExpansionOnly == true
    AUCTION_HOUSE_DEFAULT_FILTERS[Enum.AuctionHouseFilter.UsableOnly] = db.usableOnly == true
end

-- Register at top level so the handler is in place before Blizzard_AuctionHouseUI loads.
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Blizzard_AuctionHouseUI" then
        self:UnregisterEvent("ADDON_LOADED")
        applyFilters()
    elseif event == "AUCTION_HOUSE_SHOW" then
        -- Re-apply on every open so in-session manual changes are reset.
        applyFilters()
    end
end)

function AuctionFilter:Apply()
    applyFilters()
end

function AuctionFilter:Initialize()
    -- Event frame already registered at top level.
end
```

- [x] **Step 2: Reload and verify no Lua errors**
- [x] **Step 3: Verify filters are applied**
- [x] **Step 4: Commit**

---

## Chunk 2: Settings UI

**Files:**
- Modify: `Config.lua` (add separator + two checkboxes to `BuildGeneralPanel`)

### Task 3: Add checkboxes to General panel

- [x] **Step 1: Add the AH Filter section to `BuildGeneralPanel` in `Config.lua`**

All sections use a `MakeSeparator` line followed by relative anchoring (not hardcoded y-offsets). The AH section follows this same pattern, anchored below the `/cm` checkbox:

```lua
    -- ── Auction House Filters ─────────────────────────────────────────────────

    local ahSep = MakeSeparator(panel, cmCB, -12)

    local ahLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    ahLabel:SetPoint("TOPLEFT", ahSep, "BOTTOMLEFT", 0, -10)
    ahLabel:SetText("Auction House Filters")

    local ahDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    ahDesc:SetPoint("TOPLEFT", ahLabel, "BOTTOMLEFT", 0, -4)
    ahDesc:SetText("Automatically enable selected filters each time you open the Auction House.")

    local ahExpCB = MakeCheckbox(panel, "Auto-enable 'Current expansion only' filter", 16, 0,
        function() return addon.db.auctionFilter and addon.db.auctionFilter.currentExpansionOnly end,
        function(val)
            if not addon.db.auctionFilter then addon.db.auctionFilter = {} end
            addon.db.auctionFilter.currentExpansionOnly = val
            addon:NotifyFeature("auctionFilter")
        end
    )
    ahExpCB:ClearAllPoints()
    ahExpCB:SetPoint("TOPLEFT", ahDesc, "BOTTOMLEFT", 0, -8)

    local ahUsableCB = MakeCheckbox(panel, "Auto-enable 'Usable only' filter", 16, 0,
        function() return addon.db.auctionFilter and addon.db.auctionFilter.usableOnly end,
        function(val)
            if not addon.db.auctionFilter then addon.db.auctionFilter = {} end
            addon.db.auctionFilter.usableOnly = val
            addon:NotifyFeature("auctionFilter")
        end
    )
    ahUsableCB:ClearAllPoints()
    ahUsableCB:SetPoint("TOPLEFT", ahExpCB, "BOTTOMLEFT", 0, -4)
```

**Note:** Pass `0` as the y argument to `MakeCheckbox` when using relative anchoring — the value is ignored after `ClearAllPoints()`.

- [x] **Step 2: Reload and verify UI**
- [x] **Step 3: Verify toggle works**
- [x] **Step 4: Commit**
