# Combat Log Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically start/stop combat logging when entering/leaving toggleable instance types (dungeon, raid, scenario, pvp, arena), with chat notifications and respect for manual stops.

**Architecture:** A new `Features/CombatLog.lua` self-registers via the addon feature contract. A top-level event frame listens to `PLAYER_ENTERING_WORLD` and `ZONE_CHANGED_NEW_AREA`, checks `IsInInstance()` on each fire, and calls `LoggingCombat()` accordingly. Two runtime-only flags track whether the addon started logging and whether the user manually stopped it this instance.

**Tech Stack:** WoW Retail Lua addon (interface 120001). No build step — test by running `/reload` in-game and entering instances. Errors appear in the default Lua error frame or BugSack if installed.

---

## File Map

| File | Change |
|------|--------|
| `Features/CombatLog.lua` | **Create** — full feature implementation |
| `Core.lua` | **Modify** — add `combatLog` defaults table |
| `Config.lua` | **Modify** — add Combat Logging section to `BuildGeneralPanel()` |
| `MathWroQOL.toc` | **Modify** — register `Features\CombatLog.lua` |

---

## Task 1: Add defaults to Core.lua

**Files:**
- Modify: `Core.lua` (lines 6–20, the `defaults` table)

- [ ] **Step 1: Add `combatLog` sub-table to the `defaults` table**

Open `Core.lua`. The `defaults` table currently ends with `auctionFilter`. Add `combatLog` after it:

```lua
local defaults = {
    vehicleBar = {
        enabled = true,
        bars = { [1] = true },
    },
    cdmButton = {
        enabled = true,
        slashWA = true,
        slashCM = true,
    },
    auctionFilter = {
        currentExpansionOnly = false,
        usableOnly = false,
    },
    combatLog = {
        dungeon  = false,
        raid     = false,
        scenario = false,
        pvp      = false,
        arena    = false,
    },
}
```

- [ ] **Step 2: Commit**

```bash
git add Core.lua
git commit -m "feat: add combatLog defaults to Core.lua"
```

---

## Task 2: Create Features/CombatLog.lua

**Files:**
- Create: `Features/CombatLog.lua`

- [ ] **Step 1: Create the file with the full implementation**

Create `Features/CombatLog.lua` with this exact content:

```lua
local _, addon = ...

local CombatLog = { name = "combatLog" }
addon:RegisterFeature(CombatLog)

local startedByAddon = false
local manuallyDisabled = false

local instanceTypeToKey = {
    party    = "dungeon",
    raid     = "raid",
    scenario = "scenario",
    pvp      = "pvp",
    arena    = "arena",
}

local function onZoneTransition()
    local db = addon.db and addon.db.combatLog
    if not db then return end

    local inInstance, instanceType = IsInInstance()

    if not inInstance then
        if startedByAddon then
            LoggingCombat(false)
            print("[MathWro QOL] Combat logging stopped.")
        end
        startedByAddon = false
        manuallyDisabled = false
        return
    end

    -- Detect manual stop: we started it but it's no longer running
    if startedByAddon and not LoggingCombat() then
        manuallyDisabled = true
    end

    local key = instanceTypeToKey[instanceType]
    if key and db[key] and not manuallyDisabled and not LoggingCombat() then
        LoggingCombat(true)
        startedByAddon = true
        print("[MathWro QOL] Combat logging started.")
    end
end

-- Register at top level so the frame exists before any zone events fire.
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:SetScript("OnEvent", function(self, event)
    onZoneTransition()
end)

function CombatLog:Initialize()
    -- Event frame registered at top level; nothing to do here.
end

function CombatLog:Apply()
    -- Settings only take effect on next zone transition; nothing to re-apply now.
end
```

- [ ] **Step 2: Commit**

```bash
git add Features/CombatLog.lua
git commit -m "feat: add CombatLog feature"
```

---

## Task 3: Register CombatLog.lua in the TOC

**Files:**
- Modify: `MathWroQOL.toc`

- [ ] **Step 1: Add the feature file after AuctionFilter**

Open `MathWroQOL.toc`. Add `Features\CombatLog.lua` as the last feature line:

```
Core.lua
Config.lua
Features\VehicleBar.lua
Features\GameMenu.lua
Features\CDMButton.lua
Features\AuctionFilter.lua
Features\CombatLog.lua
```

- [ ] **Step 2: Commit**

```bash
git add MathWroQOL.toc
git commit -m "chore: register CombatLog.lua in TOC"
```

---

## Task 4: Add Combat Logging section to Config.lua

**Files:**
- Modify: `Config.lua` — append to `BuildGeneralPanel()`, after the Auction House Filters section (currently ending at `ahUsableCB`)

- [ ] **Step 1: Add the section after the last line of the AH Filters block**

In `Config.lua`, find this line near the end of `BuildGeneralPanel()`:

```lua
    ahUsableCB:SetPoint("TOPLEFT", ahExpCB, "BOTTOMLEFT", 0, -4)

    return panel
```

Replace it with:

```lua
    ahUsableCB:SetPoint("TOPLEFT", ahExpCB, "BOTTOMLEFT", 0, -4)

    -- ── Combat Logging ────────────────────────────────────────────────────────

    local clSep = MakeSeparator(panel, ahUsableCB, -12)

    local clLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    clLabel:SetPoint("TOPLEFT", clSep, "BOTTOMLEFT", 0, -10)
    clLabel:SetText("Combat Logging")

    local clDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    clDesc:SetPoint("TOPLEFT", clLabel, "BOTTOMLEFT", 0, -4)
    clDesc:SetWidth(500)
    clDesc:SetJustifyH("LEFT")
    clDesc:SetText("Automatically start combat logging when entering selected instance types. Stops on exit. If you manually stop logging mid-instance, it stays off until the next instance.")

    local clDungeonCB = MakeCheckbox(panel, "Dungeon (includes Mythic+)", 0, 0,
        function() return addon.db.combatLog and addon.db.combatLog.dungeon end,
        function(val)
            if not addon.db.combatLog then addon.db.combatLog = {} end
            addon.db.combatLog.dungeon = val
        end
    )
    clDungeonCB:ClearAllPoints()
    clDungeonCB:SetPoint("TOPLEFT", clDesc, "BOTTOMLEFT", 0, -8)

    local clRaidCB = MakeCheckbox(panel, "Raid", 0, 0,
        function() return addon.db.combatLog and addon.db.combatLog.raid end,
        function(val)
            if not addon.db.combatLog then addon.db.combatLog = {} end
            addon.db.combatLog.raid = val
        end
    )
    clRaidCB:ClearAllPoints()
    clRaidCB:SetPoint("TOPLEFT", clDungeonCB, "BOTTOMLEFT", 0, -4)

    local clScenarioCB = MakeCheckbox(panel, "Scenario", 0, 0,
        function() return addon.db.combatLog and addon.db.combatLog.scenario end,
        function(val)
            if not addon.db.combatLog then addon.db.combatLog = {} end
            addon.db.combatLog.scenario = val
        end
    )
    clScenarioCB:ClearAllPoints()
    clScenarioCB:SetPoint("TOPLEFT", clRaidCB, "BOTTOMLEFT", 0, -4)

    local clPvpCB = MakeCheckbox(panel, "Battleground", 0, 0,
        function() return addon.db.combatLog and addon.db.combatLog.pvp end,
        function(val)
            if not addon.db.combatLog then addon.db.combatLog = {} end
            addon.db.combatLog.pvp = val
        end
    )
    clPvpCB:ClearAllPoints()
    clPvpCB:SetPoint("TOPLEFT", clScenarioCB, "BOTTOMLEFT", 0, -4)

    local clArenaCB = MakeCheckbox(panel, "Arena", 0, 0,
        function() return addon.db.combatLog and addon.db.combatLog.arena end,
        function(val)
            if not addon.db.combatLog then addon.db.combatLog = {} end
            addon.db.combatLog.arena = val
        end
    )
    clArenaCB:ClearAllPoints()
    clArenaCB:SetPoint("TOPLEFT", clPvpCB, "BOTTOMLEFT", 0, -4)

    return panel
```

- [ ] **Step 2: Commit**

```bash
git add Config.lua
git commit -m "feat: add Combat Logging section to options panel"
```

---

## Task 5: In-game verification

No automated test runner exists. Verify manually after `/reload`.

- [ ] **Step 1: Reload and open the options panel**

In WoW chat: `/reload`, then `/mqol`. Confirm the "Combat Logging" section appears at the bottom of the General panel with five checkboxes, all unchecked by default.

- [ ] **Step 2: Test auto-start in a dungeon**

Enable the "Dungeon" checkbox. Enter any dungeon (or use the LFG finder). Confirm:
- Chat prints `[MathWro QOL] Combat logging started.`
- The combat log window shows entries populating

- [ ] **Step 3: Test auto-stop on exit**

Leave the dungeon (hearthstone or walk out). Confirm:
- Chat prints `[MathWro QOL] Combat logging stopped.`
- `LoggingCombat()` returns false (check via `/run print(LoggingCombat())` in chat)

- [ ] **Step 4: Test manual-stop respect**

Enter a dungeon again (Dungeon checkbox still enabled). After logging starts, manually stop it via the combat log window toggle or `/combatlog`. Walk to a different subzone or take a floor portal. Confirm:
- No chat message fires
- Logging does not restart

- [ ] **Step 5: Test manual-stop resets on next instance**

After the manual-stop test above, leave the instance and re-enter it (or enter a different dungeon). Confirm logging starts again and chat prints the started message.

- [ ] **Step 6: Test each remaining type**

Repeat the start/stop verification for Raid, Scenario, Battleground, and Arena by entering an instance of each type with its checkbox enabled.
