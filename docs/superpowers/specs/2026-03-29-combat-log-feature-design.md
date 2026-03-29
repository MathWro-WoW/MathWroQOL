# Combat Log Feature — Design Spec

**Date:** 2026-03-29
**Feature key:** `combatLog`
**File:** `Features/CombatLog.lua`

---

## Overview

Automatically start combat logging when the player enters a supported instance type, and stop it when they leave. Each instance type is individually toggleable. If the player manually stops logging mid-instance, the addon respects that and leaves it off for the remainder of that instance; the flag resets fresh on the next instance entry.

---

## Settings

Stored in `addon.db.combatLog`. All default to `false`.

| Key        | Instance type string | Description                        |
|------------|----------------------|------------------------------------|
| `dungeon`  | `"party"`            | Regular dungeons and Mythic+       |
| `raid`     | `"raid"`             | All raid difficulties              |
| `scenario` | `"scenario"`         | Scenarios                          |
| `pvp`      | `"pvp"`              | Battlegrounds                      |
| `arena`    | `"arena"`            | Arenas                             |

Defaults added to `Core.lua`:

```lua
combatLog = {
    dungeon  = false,
    raid     = false,
    scenario = false,
    pvp      = false,
    arena    = false,
},
```

---

## Runtime State (not persisted)

Two boolean flags local to the feature, reset on each instance exit:

- `startedByAddon` — true if this feature called `LoggingCombat(true)` in the current instance
- `manuallyDisabled` — true if the user stopped logging after the addon started it this instance

---

## Event Handling

Registers two events on a top-level frame (not inside `Initialize()`, consistent with `AuctionFilter.lua` pattern):

- `PLAYER_ENTERING_WORLD` — fires after every loading screen (multi-floor transitions, instance entry/exit)
- `ZONE_CHANGED_NEW_AREA` — fires on seamless zone transitions without a loading screen

Both events share the same handler:

```
function onZoneTransition()
    inInstance, instanceType = IsInInstance()

    if not inInstance:
        if startedByAddon:
            LoggingCombat(false)
        startedByAddon = false
        manuallyDisabled = false
        return

    -- detect manual stop
    if startedByAddon and not LoggingCombat():
        manuallyDisabled = true

    -- map instanceType to db key
    key = instanceType == "party" and "dungeon" or instanceType

    -- start logging if applicable
    if db[key] and not manuallyDisabled:
        LoggingCombat(true)
        startedByAddon = true
        print("[MathWro QOL] Combat logging started.")
```

When stopping on instance exit:
```
    LoggingCombat(false)
    print("[MathWro QOL] Combat logging stopped.")
```

No message is printed when a manual stop is detected (we didn't stop it — the user did).

---

## Feature Contract

- `Initialize()` — no-op; event frame registered at top level
- `Apply()` — no-op; settings only take effect on next zone transition

---

## Options Panel

New section appended to `BuildGeneralPanel()` in `Config.lua`, after the Auction House Filters section:

- Separator
- Section header: **"Combat Logging"**
- Description: *"Automatically start combat logging when entering selected instance types. Stops on exit. Respects manual stop for the rest of that instance."*
- Five checkboxes, one per type:
  - Dungeon (includes Mythic+)
  - Raid
  - Scenario
  - Battleground
  - Arena

---

## Changes Required

1. `Features/CombatLog.lua` — new file implementing the feature
2. `Core.lua` — add `combatLog` defaults to `defaults` table
3. `Config.lua` — add Combat Logging section to `BuildGeneralPanel()`
4. `MathWro QOL_Mainline.toc` — add `Features\CombatLog.lua` entry
