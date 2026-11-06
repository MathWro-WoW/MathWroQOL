# Adding settings to the floating Edit Mode window

Use this guide when adding or moving tracker appearance controls into the WIM-style floating window. This is **Blizzard Edit Mode with the bundled LibEditMode dialog**, not a `/mqol` panel or EllesmereUI Unlock Mode.

## Working examples and ownership

- `Features/CombatTracker.lua`: `CT:CreateSectionFrame` registers the movable anchor; `CT:UpdateSectionFrameSettings` supplies the dialog controls; `CT:RefreshSectionFrameSettings` rebuilds registrations when merge configuration changes.
- `Features/ExternalTracker.lua`: `ensureAnchor` inside `registerTracker` registers the External/Bloodlust anchor and its controls. These trackers have separate saved settings and previews.
- `Core.lua`: saved defaults. Reuse existing keys when moving controls; moving the UI alone needs no settings migration.
- `Libs/LibEditMode/LibEditMode.lua`, `pools.lua`, and `widgets/*.lua`: the bundled implementation is the reference for what this addon supports. Both TOCs already load these before feature code.

**Choose the actual tracker first.** Combat Tracker owns racials, trinkets, consumables, stack counts, and cooldown counts. External Tracker owns incoming external buffs and their duration text. Their similarly named text controls are not interchangeable.

## Implementation recipe

### 1. Register the anchor and the controls

Obtain the optional library with `LibStub and LibStub("LibEditMode", true)` and register an ordinary addon-owned anchor through `AddFrame` before calling `AddFrameSettings` on that **same frame**. Existing trackers already do this; extend their existing settings list rather than registering their anchor twice.

`AddFrame` provides selection/dragging and position persistence through its callback. **It does not add sliders or text options.** The visible rows come from `AddFrameSettings(frame, settings)`.

`AddFrameSettings` replaces the frame's whole registered settings table. Add a row to the existing list; a second call containing only the new row would discard the previous controls. Registration alone does not refresh an already open dialog; use `RefreshFrameSettings(frame)` when necessary.

### 2. Define a row with saved-state access and a live update

Example: the existing Combat Tracker width row, inside `CT:UpdateSectionFrameSettings`, where `db`, `key`, `CT`, and `canEditSection` already exist:

```lua
{
    kind = LibEditMode.SettingType.Slider,
    name = "Icon width",
    default = 36,
    minValue = 16,
    maxValue = 80,
    valueStep = 1,
    disabled = function() return not canEditSection(key) end,
    get = function() return db.frames[key].iconWidth or 36 end,
    set = function(_, value)
        if not canEditSection(key) then return end
        db.frames[key].iconWidth = math.max(16, math.min(80, math.floor(value + 0.5)))
        CT:LayoutSection(key)
    end,
},
```

This is a row for the existing settings table, not a replacement for the whole table.

The library calls `get(layoutName)` and `set(layoutName, newValue, fromReset)`. These trackers use shared saved keys rather than per-layout appearance, so the first setter argument is intentionally ignored. Reset Settings calls every setter with its `default` and `fromReset = true`; keep defaults consistent with `Core.lua`.

Use `SettingType.Checkbox` for booleans and `SettingType.Dropdown` with `values = { { text = "Label", value = savedValue }, ... }` for choices. Optional `desc` provides a tooltip; `disabled` can be a function. Preserve explicit false values in getters (`value ~= false` for a default-on toggle).

### 3. Save to the correct owner and update the existing surface

Combat Tracker icon dimensions belong to the displayed **host** frame. In merged groups, text preferences still belong to the selected **contributing section**. Extend the existing `getTextKey()` path for text controls instead of writing all merged text settings into the host's DB.

The **Text section** dropdown is transient UI state. Its setter deliberately ignores `fromReset`; otherwise Reset Settings could switch the target to the host before resetting the selected contributor's text controls. Preserve that behavior and refresh through public `LibEditMode:RefreshFrameSettings`.

Use the narrow update already used by the neighboring control: `CT:LayoutSection` for size, `CT:ApplySectionFont` for stack fonts, `CT:ApplyCooldownFont` for cooldown text. The stack-count visibility toggle currently calls its section's `RebuildIcons`. External/Bloodlust setters use their owning `Tracker:Apply()`.

Keep the setter's enabled/combat guard even when the row has a disabled predicate. UI disabling alone does not protect reset callbacks or direct invocation. For secure external aura icons, update retained addon-owned appearance objects through the existing apply path; leave live aura visibility/duration/text values engine-owned.

### 4. Preserve discoverability and lifecycle

Users must enable Combat Tracker **and the relevant section**, enter native Edit Mode, and **click** its highlighted selection (for example, **MathWroQOL - CT Consumables**). Dragging moves the anchor; clicking opens its floating settings window. A merged contributor is edited through the host's selection and Text section dropdown.

Keep empty anchors selectable: Combat Tracker layout retains an icon-sized footprint with no active items. External/Bloodlust use ordinary preview icons in Edit Mode, including when no real tracked spell is active; preview callbacks must not trigger sound alerts. Let native Edit Mode/library exit handling close selections and dialogs rather than building a second window lifecycle.

Move appearance controls out of `Config.lua` when Edit Mode becomes their owner. Keep enablement, tracked-item/spell choices, and existing layout/merge controls in `/mqol`; preserve saved appearance values across the move.

## Verification

Run `lua tests/CombatTracker_EditMode_smoke.lua` when changing Combat Tracker's dialog. It loads the actual bundled library, pools, dialog, and widgets; enters Edit Mode; clicks selections; and invokes real widget handlers. Extend its behavioral checks for a new control rather than merely mocking `AddFrameSettings` and asserting registration.

For External/Bloodlust changes, also run `lua tests/ExternalTracker_smoke.lua`. Run the repository's remaining smoke scripts and Lua syntax checks from `AGENTS.md` when changing runtime code.

In-game, `/reload`, enable the tracker/section, enter native Edit Mode, click the selection, and verify the control visibly updates the tracker and persists after reload. Check empty state, merged contributor ownership, Reset Settings versus Reset Position, disabled/combat guards, and exit cleanup. A successful Lua harness run does not prove live client rendering; record which clients were actually exercised.

## API references

- [LibEditMode methods](https://github.com/p3lim-wow/LibEditMode/wiki/LibEditMode): `AddFrame`, `AddFrameSettings`, `RefreshFrameSettings`.
- [SettingObject and widget types](https://github.com/p3lim-wow/LibEditMode/wiki/Types): getter/setter signatures and row fields.

Upstream documentation was checked through Context7 when writing this guide; prefer the bundled implementation if upstream later changes.
