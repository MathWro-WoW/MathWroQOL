# MathWroQOL — Architecture Reference

Canonical reference for architecture, code style, and WoW API patterns.
`AGENTS.md` is the repository instruction entry point and defers to this document.

When adding or moving controls into the floating Edit Mode window, read [Edit Mode settings](EDIT_MODE_SETTINGS.md) for the registration recipe, ownership/reset pitfalls, and verification.

---

## Interface Version & TOC

- Retail target: `120100` (Midnight 12.1.0) in `MathWroQOL.toc`. Forever target: `16001` (1.60.1) in `MathWroQOL_Camelot.toc`. **Single value per TOC only** — do not combine the clients into a comma-separated interface list.
- The fallback TOC basename must match the addon folder (`MathWroQOL/MathWroQOL.toc`); client-specific manifests use recognized suffixes such as `MathWroQOL_Camelot.toc`. Do not rename the addon folder independently.
- Any hardcoded addon name strings (e.g. `ADDON_LOADED` checks) must use `"MathWroQOL"`.
- Optional addon integrations are declared via `## OptionalDeps:` so ElvUI, EllesmereUI modules, Masque, CooldownManagerCentered, and PallyPower load first when present.
- The settings subtitle reads `## Version:` through `C_AddOns.GetAddOnMetadata`; keep the release version in the TOC rather than duplicating it in Config.lua.
- Forever is a Mainline-family game type (`Camelot`, with `Forever` as a client alias), not a Classic API client. The base TOC remains Retail's fallback; the suffixed TOC is selected by Forever. Keep both file lists and all metadata except `Interface` synchronized. BigWigs Packager `@v2` discovers both TOCs and advertises both game versions without a second release job.
- `Core.lua` sets `addon.isForever` from the interface band `16000 <= interface < 17000`. Do not distinguish the clients with `WOW_PROJECT_ID`: both report Mainline. Do not use `interface >= 100000` to select modern APIs.
- Heroic Strike, Bloodlust Tracker, and Folio Equipment Sets are Retail-only: return before their feature registration on Forever and omit their entire settings sections, including Edit Mode controls. PallyPower auto-hide is Forever-only: omit its entire settings category and navigation button on Retail. Shared General, External Tracker, and Cooldown Manager Tweaks settings remain available. Preserve saved preferences, but never allow saved enabled settings to activate unsupported runtimes. The README compatibility table records provider and game-data limits.
- Use current namespaces (`C_Item.GetItemInfo`/`GetItemSpell`/`IsItemDataCachedByID`, `C_SpellBook.IsSpellKnown`, `C_Spell.GetSpellTexture`, `C_CVar`) rather than depending on deprecated global shims. Do not invent Forever catalog IDs from Retail names.
- Forever source audit baseline: [1.60.1.70707](https://github.com/Gethe/wow-ui-source/tree/aff0d8cd53bf4d9ef1c1dd2786b94461a276fb16). Shared APIs do not certify third-party providers or prove in-game behavior. Validate combat, `/reload`, and cold-start settings persistence on each client.

---

## Libraries

Loaded before `Core.lua`:

- `Libs\LibStub\LibStub.lua`
- `Libs\LibEditMode\LibEditMode.lua` plus `pools.lua` and `widgets\*.lua` — enables native Edit Mode glow + drag for custom frames

---

## Load Order

Defined in `MathWroQOL.toc`:

1. Vendored LibStub, then LibEditMode and its pools/widgets.
2. `Core.lua`: framework, defaults, and login event handler.
3. `Config\Native.lua`, `Config\Widgets.xml`, and the page builders in `Config\Simple.lua`, `Config\CombatTracker.lua`, `Config\ExternalTracker.lua`, and `Config\Integrations.lua`; then `Config.lua` for category assembly and the attached Folio controls.
4. Feature modules in manifest order. `CombatTracker.lua` precedes its section and food/water modules.

Core's `PLAYER_LOGIN` handler initializes features before Config's handler builds categories. This makes initialized racial catalogs available without adding settings-driven gameplay scans. Keep the two TOCs authoritative for the exact file sequence.

---

## Core Framework

`Core.lua` is the addon framework. On `ADDON_LOADED`:

- Initialises `MathWroQOLDB` (SavedVariables)
- Runs `applyDefaults()` recursively — merges missing keys from `defaults` without overwriting saved values
- Exposes `addon:RegisterFeature(feature)` for module self-registration
- Exposes `addon:NotifyFeature(name)` to call `feature:Apply()` when settings change

On `PLAYER_LOGIN`, iterates registered features and calls `feature:Initialize()` on each.

`addon:ApplyIconGlow(display, host, glowType, width, height)` shares native Classic, Modern Proc, and Assisted Combat flipbooks between Heroic Strike and External/Bloodlust Tracker. Pass an addon-owned host and retain `display` for cached animation state. Width and height are independent rendered dimensions; `"none"` stops and hides an existing effect without allocating one. Callers own feature/visibility gating, and no aura button is accessed by the helper.

---

## Feature Contract

Every feature file follows this pattern:

```lua
local _, addon = ...

local MyFeature = { name = "myFeature" }
addon:RegisterFeature(MyFeature)

function MyFeature:Initialize()
    -- Called once on PLAYER_LOGIN.
    -- Register hooks, events, one-time setup here.
    -- Safe to call self:Apply() at the end to apply initial state.
end

function MyFeature:Apply()
    -- Called by addon:NotifyFeature("myFeature") when settings change.
    -- Re-apply current settings. Do NOT re-register hooks here.
end
```

Every feature must have a top-level `enabled = false` default in `Core.lua` unless there is a documented reason to ship it on. Treat `enabled` as a hard execution gate: `Initialize()`, `Apply()`, event handlers, hooks, timers, and helper callbacks must return before doing feature work when `addon.db.<featureName>.enabled` is false. Disabled features may keep only the inert registration needed to notice settings changes or required early Blizzard addon events; they must not scan state, update frames, register recurring timers, or process gameplay events while disabled.

Features that have no lifecycle needs (e.g. `AuctionFilter`, `CombatLog`) may have no-op or absent `Initialize()`/`Apply()` and instead register event frames at file top level — see [Event Registration](#event-registration).

---

## Adding a New Feature

Four surfaces to wire:

1. Create `Features/MyFeature.lua` with the feature contract above
2. Add `Features\MyFeature.lua` to `MathWroQOL.toc` (use backslash path separator in TOC)
3. Add default values to the `defaults` table in `Core.lua`, including top-level `enabled = false`
4. Add native controls to the appropriate page builder in `Config/`; see Settings Menus below.

---

## Settings Storage

`addon.db` is a direct reference to `MathWroQOLDB`. Each feature owns `addon.db.<featureName>` (e.g. `addon.db.gameMenu`, `addon.db.vehicleBar`). New keys get defaults from `applyDefaults()` in `Core.lua` — add new defaults to the `defaults` table there.

---

## Feature Inventory

| Feature | File(s) | DB key | Notes |
|---|---|---|---|
| Vehicle Bar | `VehicleBar.lua` | `vehicleBar` | ElvUI and EllesmereUI Action Bars integration; keeps selected action bars visible in vehicle encounters |
| Game Menu | `GameMenu.lua` | `gameMenu` | Drag, scale, persist position of Escape menu |
| CDM Button | `CDMButton.lua` | `cdmButton` | Injects a provider-aware CDM button into the Escape menu, positioned after ElvUI or EllesmereUI custom buttons; `/wa` and `/cm` slashes |
| CMC Masque | `CMCMasque.lua` | `cmcMasque` | Registers CooldownManagerCentered Essential, Utility, and Buff Icon viewer buttons with Masque when both addons are loaded |
| Heroic Strike | `HeroicStrike.lua` | `heroicStrike` | Opt-in Arms proc companion beside EllesmereUI's primary Buffs row or Blizzard's Buff Icons viewer; no aura or sortable CDM entry |
| Auction Filter | `AuctionFilter.lua` | `auctionFilter` | Pre-enables AH filters on open |
| Hearthstone Destination Zone | `HearthstoneZone.lua` | `hearthstoneZone` | Opt-in, character-specific bind-zone capture and ordinary Hearthstone tooltip enhancement on Retail and Forever |
| Combat Log | `CombatLog.lua` | `combatLog` | Auto-starts/stops combat logging by instance type and level cap |
| PallyPower auto-hide | `PallyPower.lua` | `pallyPower` | Forever-only opt-in visibility of your assigned blessings; secure combat-show driver and fresh nonsecret out-of-combat confirmation |
| Camera Distance | `CVarSettings.lua` | `cameraDistance` | When enabled, checks `cameraDistanceMaxZoomFactor` on each login and restores `2.6` on Retail or `3.4` on Forever, selected via `addon.isForever`; enabling applies immediately, disabling leaves the CVar untouched |
| Spell Queue Window | `CVarSettings.lua` | `spellQueueWindow` | Never writes a value until explicitly enabled; first activation captures the current queue window, and later logins restore that captured or subsequently user-selected value |
| Edit Mode Nudge | `EditModeNudge.lua` | `editModeNudge` | Provider-split arrow buttons + coordinate display: `enabled` covers native Edit Mode/LibEditMode; `ellesmereEnabled` covers EllesmereUI Unlock Mode and is disabled by default |
| Buff Health Color | `BuffHealthColor.lua` | `buffHealthColor` | ElvUI health bar recoloring through 12.1 secure Aura Slots for configured player-cast buffs such as Atonement, Lifebloom, Prayer of Mending, Riptide, Beacon of the Savior, Renewing Mist, and custom spell IDs. Aura presence and slot visibility stay engine-managed; each profile retains frame, color, and specialization filters. EllesmereUI Raid Frames already provides equivalent Health Bar Color indicators in its Buff Manager, so MathWroQOL does not duplicate that runtime |
| Combat Tracker | `CombatTracker.lua` + 3 section files | `combatTracker` | Cooldown icon display system (racials, trinkets, consumables); trinkets honor the configured `frames.trinkets.excludedItems` set |
| External Tracker | `ExternalTracker.lua` | `externalTracker` | Independently opt-in external buffs on the player; secure duration icons, native aura-triggered LibSharedMedia sounds, or both |
| Bloodlust Tracker | `ExternalTracker.lua` | `bloodlustTracker` | Retail-only duration icon for Bloodlust variants and drums; shares the External Tracker submenu and runtime implementation |
| Folio Equipment Sets | `FolioEquipmentSets.lua` | `folioEquipmentSets` | Opt-in full purchased Folio choice snapshots per character/equipment-set ID; saved stat badges and Apply/Clear actions in native Equipment Manager |

### Heroic Strike CDM Companion

`HeroicStrike.lua` checks `C_SpellBook.IsSpellInSpellBook(1269383)` on `SPELLS_CHANGED`; availability is temporary spellbook presence, not an aura or a resource/range usability check. Only Arms (spec `71`) processes proc events. Enabling and world entry resynchronize state; late `Blizzard_CooldownViewer` loading is handled through `ADDON_LOADED`.

Without EllesmereUI CDM, the addon-owned frame is parented to `BuffIconCooldownViewer`, marked `ignoreInLayout`, and anchored six pixels outside the selected top corner. `heroicStrike.side` defaults to `"right"`; `"left"` selects the opposite edge. A post-hook on `RefreshLayout` applies the native 40px buff-icon size multiplied by `iconScale`.

With EllesmereUI CDM enabled, use its module namespace's `GetCDMBarFrame("buffs")` and `GetCDMBarIcons("buffs")`, not the unrelated native viewer bounds. Parent to the provider bar and dock to the selected edge icon using rendered dimensions, with scale conversion and provider spacing. On horizontal rows, side selection is independent of growth direction. On vertical rows, Right preserves the growth end and Left uses the opposite end. Select layout participants without aura/visibility queries; skip the provider's shift-hidden entries. An empty row uses its starting anchor regardless of side, since Ellesmere retains stale empty-container bounds.

`_AuraCustomPoke("buffs")` covers layout, visibility, and opacity; it fires before final positions are written, so coalesce refreshes with `C_Timer.After(0, ...)`. `RefreshAuraCustomStyle` also covers settings-only appearance changes. Reuse `ApplyShapeToCDMIcon` and `PP.CreateBorder` on the addon-owned frame for crop/border/shape parity; this is an approved compatibility exception to the public skin API. Capability-check the helpers: an enabled but unsupported Ellesmere CDM suppresses the companion instead of falling back to the misplaced native anchor. Native mode is restored when Ellesmere CDM is disabled.

Native pooled items, aura state, and provider icon lists are left untouched. Disabling hides the companion and unregisters events; retained hooks and queued callbacks return before feature work. Only the primary Ellesmere Buffs row and native viewer are supported.

`heroicStrike.glowType` defaults to `"none"` and is selected in Other Addon Tweaks → Cooldown Manager Tweaks. Its native glow uses the shared helper on the companion frame, follows rendered width/height, and inherits provider visibility. Proc consumption, leaving Arms, and feature disable stop the animation; a subsequent proc restarts it.

---

## CombatTracker Subsystem

`CombatTracker.lua` is a **framework**, not a simple feature. It exposes a `RegisterSection(def)` API that the three section files use to self-register:

```lua
-- In a section file (e.g. CombatTracker_Racials.lua):
local CT = addon.combatTracker  -- set by CombatTracker.lua at load time

local Racials = { name = "racials", hostKey = "frames.racials" }
CT:RegisterSection(Racials)

function Racials:RebuildIcons() ... end
function Racials:UpdateCooldowns() ... end
function Racials:Initialize() ... end
```

Key CT methods available to sections:

| Method | Purpose |
|---|---|
| `CT:RegisterSection(def)` | Self-registration for section plugins |
| `CT:CreateButton(parent)` | Pool factory — 36×36 button with icon, cooldown frame, stack count text |
| `CT:LayoutSection(section)` | Stable-anchor grid/horizontal/vertical layout engine |
| `CT:CreateSectionFrame(section)` | Creates anchor frame, registers with LibEditMode, hooks EditModeNudge overlay |
| `CT:ApplyMasque(section)` | Lazy Masque group creation + button registration |
| `CT:UpdateButtonCooldownFromSpell(btn, spellID)` | Applies a restricted-safe `LuaDurationObject` directly to the cooldown frame |

Trinkets are the exception: they use `GetInventoryItemCooldown("player", slotID)`, whose three returns are start, duration, and numeric enable (there is no modRate return). Start the cooldown with `CooldownFrame:SetCooldown(start, duration)` only when enable is `1` and both timing values are positive; otherwise clear it and restore icon saturation. Never inspect the on-use spell's cooldown state: it can be secret in combat and its duration can be shorter than the equipped item cooldown. `BAG_UPDATE_COOLDOWN` and `SPELL_UPDATE_COOLDOWN` refresh the equipped slots through a coalesced next-frame callback, including during combat.

Verified against the exported Blizzard UI source for **12.1.5.70448**, commit [`b9be9379719047977fca4dba1bb1d9988e8840b3`](https://github.com/Gethe/wow-ui-source/tree/b9be9379719047977fca4dba1bb1d9988e8840b3): `Blizzard_UIPanels_Game/Mainline/PaperDollFrame.lua` uses the same inventory API and bag cooldown event; `Blizzard_FrameXMLUtil/Cooldown.lua` checks enable/start/duration before setting or clearing the cooldown. The addon TOC interface remains unchanged.

`CombatTracker` exposes itself globally so section files can reference the parent:
```lua
addon.combatTracker = CT  -- in CombatTracker.lua top-level
```

`EditModeNudge` similarly exposes itself for CombatTracker to attach the nudge overlay to section frames:
```lua
addon.editModeNudge = EditModeNudge  -- in EditModeNudge.lua top-level
```

### Combat Tracker's floating Edit Mode settings

`CT:CreateSectionFrame` registers both the movable anchor and appearance settings with LibEditMode. Clicking a native highlighted selection opens LibEditMode's floating dialog, using its actual pooled slider/checkbox/dropdown widgets. `Config/CombatTracker.lua` retains section enablement, layout/merge/growth, desaturation, exclusions, and item controls, but does not duplicate icon-size or count/cooldown-text appearance controls.

Existing `frames.<section>` appearance keys are reused without migration: `iconWidth`/`iconHeight` (16–80), `stackCountEnabled`/`stackCountFontSize` (8–24)/`stackCountFont`, and `cdCountEnabled`/`cdCountFontSize` (8–24)/`cdCountFont`. Setters return in combat or while their tracker/section is disabled. Size setters only relayout; font setters apply to existing buttons without rescanning gameplay state. Empty anchors keep the configured footprint so they can still be selected.

Merged groups expose a **Text section** dropdown in the host's dialog. Icon dimensions belong to the host; text controls target the selected contributor's own saved keys. The selector is transient UI state and ignores Reset Settings' default invocation so resetting a selected contributor cannot silently switch to the host's text settings. Refresh through public `LibEditMode:RefreshFrameSettings`, not library internals. Refresh the section registrations when merge settings change. Native Edit Mode exit owns selection/dialog cleanup.


### Client catalogs and bag-selected food/water

Racials select a separate Forever active-spell catalog via `addon.isForever`, including distinct Human, Night Elf, Troll, and Skyborne IDs. Known-spell filtering and per-name visibility settings remain shared.

Consumables likewise select client-specific potion/Healthstone item families; ordinary potion and custom-item cooldown spells come from `C_Item.GetItemSpell`, not Retail spell constants. Healthstone shared-cooldown mappings are per item. Config reads the selected `CONSUMABLE_IDS` for its order list and does not assign Midnight rank badges to Forever entries.

`frames.consumables.showFood` and `showWater` default false. The existing bag scan combines character-bag stacks, then identifies food/drink by consumable subclass and effect spell IDs/localized canonical spell-name identity (never English tooltip parsing). Forever's Nutritious Food effects are eligible food, including their localized name family. Explicit hybrid effects are handled separately; the hybrid `65422` is named Food and must not be used as a hybrid name reference, because ordinary health-only food has that same localized name. Eligibility uses `C_PlayerInfo.CanUseItem` and the required level, not `C_Item.IsUsableItem`: temporary action usability must not hide inventory food/water at full health/mana or during combat. `foodWaterPreference` defaults `"itemLevel"`: required level, item level, then lowest item ID. `"quantity"` instead compares summed bag count after required level, with item level and item ID as subsequent tie-breakers. At most one food and one water selection are appended after configured items, with duplicate IDs suppressed, including hybrids/custom overlap. Selected counts include one and respect the stack-count toggle. Missing food/water never creates fallback icons.

`preferMageFood` defaults false. When enabled, eligible conjured candidates sort ahead of non-conjured candidates before required level and the existing same-level preference. Identify conjured status only for eligible candidates and only while enabled: scan `C_TooltipInfo.GetItemByID(itemID).lines` for an exact `leftText == ITEM_CONJURED` match, using Blizzard's localized marker rather than English item-name matching or a fixed rank catalog. Missing tooltip data grants no priority and does not remove the candidate from ordinary ranking. This is item-ID metadata, not a live aura scan. Eligibility and buff-food exclusion run first; ordinary fallback, stack totals, and hybrid de-duplication remain unchanged.

`excludeBuffFood` defaults false. With it enabled, food candidates must match verified restoration-only effect IDs (`FOOD_SPELL_IDS` or explicit hybrid IDs); a localized name match alone cannot prove absence of an additional buff. Unknown effects and known Nutritious Food are skipped. Filter before either dynamic selection so excluded hybrids cannot enter as water. This restriction applies only to automatic selections, not explicitly configured custom items. There is no aura scan, buff-tooltip parsing, or inference from the player's currently active buffs.

`BAG_UPDATE`, `PLAYER_LEVEL_UP`, and requested `ITEM_DATA_LOAD_RESULT` completions coalesce into next-frame scans; deferring level-up allows `UnitLevel` to settle. Uncached item data is requested once while pending. Disabled sections do not scan. Food/water uses the existing button pool, fonts, Masque group, merge/layout path, and engine-owned cooldown display.

`frames.foodWater.enabled` defaults false and selects an independent, non-mergeable Food & Water display. `CombatTracker_Consumables.lua` registers it as `managedBy = "consumables"` before the normal section. One bag scan partitions selected food/water into its own button pool, preserving hybrid/custom overlap de-duplication and food-first ordering. The framework skips duplicate managed-section scans while retaining independent Edit Mode position, size/text defaults, fonts, and Masque group. Parent/master disable hides both pools.

`frames.consumables.clickableFoodWater` defaults false. `CombatTracker_FoodActions.lua`, loaded immediately after consumables in both TOCs, reuses at most two ordinary child overlays with Blizzard's `InsecureActionButtonTemplate`. Its native handler refuses combat dispatch; display frames remain unprotected and can still relayout in combat. Left-button release uses the selected item through native `type1 = "item"`/`item1` attributes, never a direct protected item-use call. Creation waits until outside combat; an inert regeneration listener handles combat reload and refreshes selection on exit. Disable, depletion, stale selection, and native Edit Mode clear click actions; the split and click options are independent.

`CombatTracker_FoodMacros.lua` owns the explicit **Create Smart Macro** action. It creates `MQOL Food` and `MQOL Water` with `CreateMacro(..., nil)` in account/General slots, then enables `frames.consumables.smartFoodWaterMacros` (default false). Bag scans publish `selectedFood`/`selectedWater` before display de-duplication so both macros can target one hybrid, independent of click/split options. Macro bodies have an ownership marker, `#showtooltip`, and `/use [nocombat] item:ID`; no selection means no use command. Only owned account macros are edited, only outside combat, only when the body changes. Resolve indices after creation because account ordering can change. Preflight both name conflicts and required free slots; preserve character macros and unrelated General macros. Automatic updates never recreate deleted/renamed entries. Combat exit refreshes selection before updating; disabled tracker/section/toggles clear stale commands without scanning gameplay state. See [CreateMacro](https://warcraft.wiki.gg/wiki/API_CreateMacro) and [EditMacro](https://warcraft.wiki.gg/wiki/API_EditMacro).

Macro capacity checks use `Constants.MacroConsts.MAX_ACCOUNT_MACROS`, as Blizzard's Macro UI does on both Retail and Forever. The legacy global `MAX_ACCOUNT_MACROS` can be nil; the regression harness deliberately leaves it undefined. Creation must work before the user opens the Macro UI, without loading that UI or supplying a hardcoded capacity fallback.

For the unresolved Forever report of food icons returning later, possibly after opening bags, read [food/water refresh notes](FOOD_WATER_REFRESH_NOTES.md) before diagnosing or claiming a fix. The original cause and live-client resolution remain unconfirmed.

---

## External Tracker

`ExternalTracker.lua` exports `addon.externalTracker.spells` as the catalog consumed by `Config/ExternalTracker.lua`. The master switch defaults off; an absent numeric entry in `externalTracker.spells[spellID]` is disabled. Each configured entry stores `enabled`, `mode` (`icon`, `sound`, `both`), and a LibSharedMedia `sound` key.

The external catalog is selected with `addon.isForever`. Forever groups Protection (`1022`, `5599`, `10278`) and Sacrifice (`6940`, `20729`) into one setting/secure slot per family, and also offers Freedom, Power Infusion, Fear Ward, and Innervate. `spellID` remains the saved-setting key; optional `spellIDs` is the aura candidate map. Sound registrations are per actual aura ID, so disabling a family removes every rank's registration. Midnight's catalog and saved settings are unchanged; unsupported saved entries cannot activate Forever slots or sounds.

The same file registers `bloodlustTracker` through the private `registerTracker` function. Each registration owns its events, aura container, anchor, preview, sounds, and Edit Mode callbacks. Bloodlust defaults off with separate position/appearance settings; it has no per-spell settings or sound mode. One `HELPFUL` slot accepts the grouped `spellIDs` map, covering class buffs (including Primal Rage's alternate aura), legacy hunter variants, and drums through Void-touched Drums. Use buff IDs, not cast IDs or Exhaustion/Sated debuffs. Blizzard supplies the actual matching buff's icon and duration.

Bloodlust registration stops after the shared External Tracker on Forever; no Bloodlust feature, events, aura container, or Edit Mode controls are exposed there. Config likewise returns before its entire Bloodlust section. Preserve `bloodlustTracker` saved values without applying them on Forever.

- Icons use `CustomAuraContainerTemplate` on `player`, with one `HELPFUL` Aura Slot per selected icon spell. Blizzard owns visibility, duration cooldowns, and duration text. Lua arranges ordinary anchor frames from settings only; each aura button is anchored during initialization and never accessed afterward, because aura secrecy can deny access even outside combat. Lua never reads combat aura data or slot visibility.
- Sounds use `C_UnitAuras.AddAuraSound(Enum.UnitAuraSoundTrigger.Added, info)` with the selected media's file path or file ID. The tracker-wide `externalTracker.soundChannel` defaults to `"Master"`; Config offers Master, SFX, Music, Ambience, and Dialog and uses the same channel for previews. Keep registrations whose sound and channel are unchanged; replace them when either changes, and remove obsolete registrations on mode changes, spell disable, or master disable. No LibSharedMedia library or missing media means no sound, not a substitute.
- Native sounds cannot filter by caster, so both outputs include self-cast instances of the listed buffs. This is an incoming buff-duration tracker, not a tracker of other players' cooldown availability.
- Config controls are combat-gated; enabled runtime changes requested during combat are deferred to `PLAYER_REGEN_ENABLED`. Disabled runtime unregisters its events and media callback, removes sounds, stops glows, and disables/hides its containers. The ordinary Edit Mode anchor is created on enable; Blizzard_AuraContainer and aura slots still load only when an icon spell is enabled.
- LibEditMode's frame settings own each tracker's `iconSize`, `durationTextEnabled`, `durationTextSize`, `iconZoom` (percentage cropped per edge), and `glowType` controls. Duration text defaults visible at 18px, with an 8–40px size range. Text size is disabled in the panel when text is hidden. Both setters are combat- and enable-gated, save directly to the owning tracker's DB, and update existing icons. Its `enter`/`exit` callbacks show/hide an ordinary preview (Power Infusion for externals; Bloodlust for bloodlust), independent of spell enablement and sound registrations. The preview includes static sample duration text; it never simulates an aura or sound. Real icons are hidden during editing, then restored; preview frames and glow textures are reused.
- Glow styles use native looping FlipBook animations (Classic, Modern Proc, Assisted Combat), not Lua animation drivers. Their owned child frames inherit engine-managed aura visibility. Appearance updates use retained references to addon-owned textures, font strings, and frames only; they never re-access the restricted AuraButton. Duration text's native binding owns secret Text/Alpha/VertexColor aspects, so appearance only changes its font and non-secret Shown aspect; never read or overwrite the live duration text, alpha, or color.

---

## Folio Equipment Sets

`Features/FolioEquipmentSets.lua` exposes `addon.folioEquipmentSets` for the native Folio management panel; General options retain only its enable toggle and guidance. `folioEquipmentSets.enabled` defaults off; `characters[playerGUID][equipmentSetID]` stores `{ choices = { [nodeID] = entryID }, summary, stat = { label, name, icon, spellID } }`. `stat` is absent if the stat row was not selected when saved. Runtime config IDs are resolved afresh, not persisted. Set names are display-only, so rename preserves identity and different characters cannot inherit another character's set association.

- Folio is Blizzard's Runes of Power trait system `48`, tree `1186`. Save reads `entryIDsWithCommittedRanks` for purchased multi-entry nodes, resolves their rune metadata through entry/definition/spell APIs, and leaves single-entry ranks untouched. Stat badges identify the selection spells `1279609` (Crit), `1279610` (Haste), `1279612` (Mastery), and `1279613` (Versatility), not proc auras.
- `EQUIPMENT_SWAP_FINISHED(true, setID)` requests a restore. Failed, unidentified, and unlinked swaps do not change runes. Enabling/login never guesses from `isEquipped`, because multiple sets may contain identical gear; explicit **Apply saved Folio** supports already-equipped sets. The latest successful request supersedes combat-deferred or commit-queued requests.
- Before staging, check `IsReadyForCommit`, `CanEditConfig`, existing staged edits, and every saved node/entry. Empty/unpurchased or removed saved rows reject the whole restore without purchasing currency ranks. `SetSelection` changes only differing choices, followed by `CommitConfig`. Roll back only this operation's staging when selection/submission is synchronously rejected.
- An accepted commit is observed read-only for at most 30 checks at 0.1-second intervals. Completion requires readiness, no staged changes, and all saved committed choices matching. Never resubmit or roll back an accepted commit: subsequent manual edits may own the staging. `CONFIG_COMMIT_FAILED` terminates the matching observation. Disabling cancels local observers/queued requests; an already-submitted server operation cannot be undone.
- Post-hook native `PaperDollEquipmentManagerPane_InitButton` and `PaperDollEquipmentManagerPane_Update` only after enable/API availability. Each pooled gear row reuses a 16px addon-owned stat icon beside the set name, before the equipped check and above edit/delete controls. Reserve name width without cumulative shrinking; restore it on unlink/disable while respecting provider adjustments. The icon reads saved metadata and hides for unlinked/New Set rows. Its tooltip describes the full saved setup; its context menu applies or clears the captured set ID.
- Config's `addon:CreateFolioEquipmentSetControls(host)` reuses the shared dropdown/backdrop/skin helpers to create the equipment-set selector and Save/Apply/Clear footer beneath the native Folio overlay. Runtime hooks the concrete `ExpansionLandingPage` frame's `OnShow` and `RefreshExpansionOverlay`, mounts only an `overlayFrame` with `RunesOfPowerFrame`, and never forces Blizzard UI loading. Reuse the current host's controls, hide them on disable, and use `IsVisible` to avoid gameplay queries when their native parent is hidden.
- `SaveSet`, `ApplySet`, `ClearSet`, `HasSavedSet`, `GetSummary`, and `GetEquipmentSetOptions` are the management interface. Runtime owns `RefreshControls(message)`, forwarding to the panel's `Refresh(message)`; saved summary and operation status remain separate. Combat entry/exit refreshes lock all management controls. Clearing removes the association only. `EQUIPMENT_SETS_CHANGED` prunes deleted associations while enabled. Disabled runtime unregisters events/hides owned UI; retained hooks, menu actions, and timer callbacks return before gameplay work.

## PallyPower auto-hide

`Features/PallyPower.lua` registers `pallyPower` only on Forever; its default is disabled. Only a Paladin processes provider work. OptionalDeps orders PallyPower first; an enabled ADDON_LOADED listener also handles late providers. Capability checks require the installed port's root frame, assignments accessors, spell-name tables, and blessing-alternative helper.

The feature checks only the local paladin's effective assignments through `GetSpellID(class, name)`; personal assignments override class defaults. `GetBuffAlternatives` receives normal/Greater names for that effective blessing, not the overridden class blessing. Fresh `C_UnitAuras.GetAuraDataBySpellName(unit, name, "HELPFUL")` confirmation avoids the provider's remembered `FindBuff` results. The named API has `RequiresNonSecretAura`, unlike error-producing index queries. Guard global aura restriction state, table access, expiry numbers, unit identity, connectivity, visibility, and death before evaluating. Missing/unknown data, no assignments, and dirty rosters leave the bar visible.

A visibility driver on `PallyPower.Header` (the actual PallyPowerFrame root) uses `[combat] show; hide` only for confirmed blessings with more than 240 seconds left; otherwise it shows. Register/unregister only outside combat. Existing child visibility and all provider preferences remain untouched. A one-shot timer wakes at the four-minute refresh threshold; provider update/layout/roster post-hooks and coalesced unit-aura events refresh state. Roster changes reveal immediately and wait for the provider's completed roster refresh before hiding again. No OnUpdate or combat aura scans. Disabled hooks are inert; combat disable retains only a regeneration listener to release owned visibility safely. A bar already hidden before ownership is not taken over.

API baseline: Forever [1.60.1.70938](https://github.com/Gethe/wow-ui-source/tree/bebcb6bf309cf41b41bd74f8ca651e6a105b2676), UnitAuraDocumentation and SecureStateDriver. The smoke harness covers visibility decisions and lifecycle, not native rendering, secure sibling overlay visibility, or live taint. Validate these in-game.

## Hearthstone Destination Zone

`hearthstoneZone.enabled` defaults false. `characters[playerGUID]` stores only the current `{ location, zone }` destination per character. Capture both localized strings from `GetBindLocation()` and `GetRealZoneText()` on `HEARTHSTONE_BOUND`, never on login or enable. A bind with missing location/zone data clears the old record rather than retaining a stale destination.

Register the event and one retained `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, ...)` callback lazily on enable. The callback returns immediately while disabled, only touches `GameTooltip` for ordinary Hearthstone item `6948`, rejects secret item IDs/text, and verifies the saved inn against the current bind before editing. A mismatch discards the record. Use `GetLeftLine()` and literal substring matching to append the zone to the existing localized destination text, preserving surrounding text and avoiding duplicate suffixes or identical inn/zone names. Blizzard's tooltip processor calls `Show()` after post-callbacks to recalculate layout. Disable unregisters gameplay events; retained hooks stay inert.

No inn catalog, tooltip-English parsing, periodic scan, or current-zone guess. Players must bind once while enabled; unobserved bindings cannot supply new zone data. Verified API contracts against Forever `1.60.1.70938`, commit [`bebcb6bf309cf41b41bd74f8ca651e6a105b2676`](https://github.com/Gethe/wow-ui-source/tree/bebcb6bf309cf41b41bd74f8ca651e6a105b2676). Native rendering/event timing and real SavedVariables loading require in-game validation.

---

## Settings Menus

Every page uses `Settings.RegisterVerticalLayoutCategory` / `Settings.RegisterVerticalLayoutSubcategory` and Blizzard's native list initializers. Flat section headers replace custom cards and nested configuration buttons. Other Addon Tweaks uses the native category list's recursive expansion, not a custom collapsible content block. Both supported Mainline-family clients provide the required APIs.

- **Parent** — "MathWro QOL": version, navigation guidance, and Open General action.
  - **General** — Game Menu scale/drag/reset, CDM button and slash commands, Auction House filters, and Retail-only Folio enablement.
  - **Small Tweaks** — Hearthstone destination-zone toggle and bind-once guidance.
  - **Combat Logging** — instance-type choices and maximum-level restriction; edits save without overriding manual logging state.
  - **CVars and Settings** — camera distance and opt-in Spell Queue Window enforcement.
  - **Combat Tracker** — Racials, Trinkets, Consumables, Item Display Order, and Masque sections. Native selected-item editor with move/add/remove/reset actions; native dialogs accept custom IDs and trinket exclusions.
  - **External Tracker** — selected-spell enable/mode/sound controls, preview, and independent External/Bloodlust enablement and position resets.
  - **Other Addon Tweaks** — native collapsible group with navigation buttons.
    - **ElvUI** — shared Vehicle Bar preferences and a selected-buff editor with native color, frame, spec, and custom-ID controls.
    - **EllesmereUI** — shared Vehicle Bar preferences, native Raid Frames guidance, and independent Unlock Mode Nudge enablement.
    - **Cooldown Manager Tweaks** — CMC Masque viewers and Retail-only Heroic Strike placement/glow; formerly CDM Plugins.
    - **PallyPower** — Forever-only category for opt-in assigned-blessing auto-hide; provider-dependent controls remain disabled without a Paladin and PallyPower.
  - **Edit Mode** — native nudge enablement and appearance-control guidance.
  - **Debug** — provider-gated Buff Health Color and Vehicle Bar actions.

`/mqol` opens General via `Settings.OpenToCategory`. Tracker appearance and position remain owned by Edit Mode as described in [Edit Mode settings](EDIT_MODE_SETTINGS.md); existing layout/merge/growth controls remain in the main menu. Folio's save/apply/clear controls remain attached to Omnium Folio, not duplicated in Settings.

### Shared Native Controls

`Config/Native.lua` exposes `addon.SettingsUI`; page builders use it rather than creating or skinning Settings widgets themselves.

| Helper | Purpose |
|---|---|
| `UI.Page` | Native category/subcategory and vertical layout |
| `UI.Header`, `UI.Text` | Blizzard section heading; addon-owned wrapping note row |
| `UI.Checkbox`, `UI.Slider`, `UI.Dropdown`, `UI.Color` | Namespaced proxy settings backed by existing DB getters/setters |
| `UI.Button` | Native action row with a guarded callback |
| `UI.Input` | Native StaticPopup edit dialog; `apply(text)` returns `false, message` to retain invalid input or `true` to accept |
| `UI.Refresh` | Coalesced next-frame redraw of the currently visible category only |

Control configuration:

- `enabled` controls the native modify predicate; `guard` independently enforces writes/actions, including direct setters and Defaults.
- `watch` lists short setting IDs for `AddEvaluateStateCVar`; `events` lists native state-evaluation events. `shown` controls conditional rows; `refresh` requests a redraw after an edit.
- `tooltip` supplies native hover text; sliders can supply a value `formatter`.
- Getters and registration are read-only. Setters own DB writes and `NotifyFeature`; editor-only selection does not apply gameplay features. An absent spell entry stays absent until an actual edit.
- A rejected proxy write defers `Settings.NotifyUpdate` until after native notification, restoring the saved displayed value. Provider and combat checks belong in guards, not only disabled visuals.
- Defaults uses these same setters and guards. Transient spell/item/profile selectors have no default. Selected-buff defaults resolve against that profile; Spell Queue Window has no invented default value.
- Native colors use opaque ARGB strings at the Settings boundary; saved colors remain `{ r, g, b }`.
- Dropdown options are fresh functions, with `customOptionHandler` enabling native scrolling. Never regenerate or retain a pooled native dropdown while its menu is open.
- `Config/Widgets.xml` defines the standalone note row with its own prefixed mixin. Do not modify Blizzard mixins or manually skin native list rows.

The remaining local backdrop/dropdown helpers in `Config.lua` serve only `addon:CreateFolioEquipmentSetControls(host)`. Its dropdown closes before regeneration to release live scroll rows. The removed canvas/card/collapsible settings helpers are not an alternate UI convention.

### Settings Verification

`tests/SettingsHarness.lua` models the native boundary for the Config smoke tests: registration must preserve saved values, unavailable controls must reject writes, selectors must retain independent profiles, and edits must reach feature handlers. The harness does not certify native textures, layout, taint, or third-party runtime compatibility. Check every category in-game at the current UI scale, including long sound lists, ID dialogs, Defaults, combat transitions, optional providers, and Edit Mode.

---

## Code Style

### Language & Environment

- **Lua 5.1** (WoW embedded). No external modules. All WoW API is global.
- No `pcall`/`xpcall` — let errors surface to `!BugGrabber`. Don't silently swallow errors.
- Guard with nil checks before nested table access: `if not db or not db.enabled then return end`
- Use early `return` to short-circuit, not deep nesting.

### Formatting

- 4-space indentation, no tabs
- `local` everything — avoid polluting the global namespace
  - Exceptions: prefixed XML mixins such as `MathWroQOLSettingsTextMixin`; `MathWroQOL = addon` in Core.lua; cross-file fields such as `addon.SettingsUI`, `addon.combatTracker`, and `addon.editModeNudge`
- Section headers: `-- ── Section Name ──...` comment bars
- Inline comments: `--` with two spaces before on the same line
- No trailing whitespace

### Naming

| Kind | Convention | Example |
|---|---|---|
| Feature table | PascalCase | `local VehicleBar = { name = "vehicleBar" }` |
| Feature `.name` key | camelCase | `"editModeNudge"` |
| Local functions | camelCase | `local function applyFilters()` |
| Feature methods | PascalCase | `function MyFeature:Initialize()` |
| Constants | UPPER_SNAKE | `local COORD_UPDATE_INTERVAL = 0.05` |
| Guard flags | camelCase | `local applying = false` |
| DB keys | camelCase | `addon.db.vehicleBar.enabled` |
| Frame globals | prefixed | `"MathWroQOL_CDMButton"` |

### Cross-file Access

When a feature needs to be accessed by another feature, expose it on the addon table at top level:

```lua
addon.editModeNudge = EditModeNudge  -- EditModeNudge.lua, after local table definition
```

Use `local self = self` as an upvalue inside closures that need method access after `Initialize()` returns.

---

## Hooking Patterns

- Use `hooksecurefunc()` — post-hook only, never pre-hook
- When a hook can re-enter itself (e.g. a `RegisterStateDriver` hook that calls `RegisterStateDriver`), use an `applying` guard flag:

```lua
local applying = false
hooksecurefunc("RegisterStateDriver", function(frame, attr, condition)
    if applying then return end
    applying = true
    -- ... modify and re-register
    applying = false
end)
```

- One-time hook registration: use a `local hooked = false` flag or a `frame._mqolHookName` sentinel to prevent double-hooking
- Hook concrete singletons, not mixin tables (e.g. hook `EditModeSystemSettingsDialog`, not `EditModeSystemMixin` — mixin functions are copied to instances at init)
- `GameMenuFrame`: hook `Layout()` not `OnShow` — `Layout()` runs after button pooling; `OnShow` is too early

---

## Event Registration

Features that must receive events before a LoD Blizzard addon loads, or before early zone events fire, must register their event frame at **file top level** (outside any function):

```lua
-- At top level — ensures frame exists before Blizzard_AuctionHouseUI loads:
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Blizzard_AuctionHouseUI" then
        eventFrame:UnregisterEvent("ADDON_LOADED")
    end
    -- ...
end)
```

`AuctionFilter.lua` and `CombatLog.lua` are the reference examples. All other features register events inside `Initialize()`.

General event rules:
- Use a dedicated local frame per feature, not an existing frame handling unrelated events
- Unregister events when a feature is disabled: call `frame:UnregisterAllEvents()` in `Apply()` when `enabled == false`, re-register when re-enabled
- `SPELL_UPDATE_COOLDOWN` and `BAG_UPDATE_COOLDOWN` are safe to handle synchronously — they fire at sensible rates and per-spell/item queries are cheap

---

## ElvUI and EllesmereUI Integration

- Provider-dependent files must return early only when none of their supported providers is loaded.
- Provider-specific hooks and runtime branches must be registered and executed only when that provider is loaded. A shared feature may remain registered, but its callbacks must return before touching an absent provider.
- Access ElvUI via `local E = ElvUI[1]`; modules via `E:GetModule("ModuleName", true)`.
- Access EllesmereUI modules through `EllesmereUI.Lite.GetAddon("<folder>", true)`. EllesmereUI action bar frames are named `EABBar_MainBar` and `EABBar_Bar2` through `EABBar_Bar10`.
- ElvUI visibility uses `RegisterStateDriver(frame, "visibility", condition)`. EllesmereUI Action Bars uses `RegisterAttributeDriver(frame, "state-visibility", condition)`. Compatibility hooks need an `applying` guard for both APIs.
- `EditModeNudge` integrates with EllesmereUI through `RegisterUnlockModeListener`, registered mover frame discovery, and the `_unlockNudge(dx, dy, mover, skipCollapse)` bridge. Its EllesmereUI toggle is independent from native Edit Mode/LibEditMode nudging, defaults off, and reuses EUI's own coordinate readout for pixel parity. Both provider-specific hooks return when their toggle is disabled or the provider is unavailable.
- Config.lua always builds separate ElvUI and EllesmereUI submenus. Provider-specific controls are disabled and greyed when their provider or required module is absent.
- Do not duplicate EllesmereUI Raid Frames' Buff Manager. Its `Health Bar Color` indicator already covers player-cast healer buffs with per-spell ownership and color settings.
- Game-menu integrations must discover visible, menu-sized custom `Button` children between Shop/Options and AddOns after deferred layout settles. CDM stays hidden during peer discovery so geometry-based integrations cannot anchor to each other and drift. Shift only the pooled lower section, and only by the measured collision amount; do not hardcode provider button names or fixed menu growth.
- CDM Button styling is mutually exclusive: use ElvUI when only ElvUI is active, the exact EllesmereUI popup-menu skin when only EllesmereUI is active, and native Blizzard styling when both or neither suite is active.
- Skin MathWroQOL-owned widgets through EllesmereUI's public `RegisterSkin("MathWroQOL", callback)` API by default. Approved exceptions: CDM Button uses the popup border helper because the public `Button` primitive lacks popup-specific settings (capability-check, call through `securecallfunction`, retain the public API fallback); the Heroic Strike companion uses the CDM appearance helper on its own frame for per-bar crop/border/shape parity (see its feature contract above). Do not copy EllesmereUI textures.

---

## Performance Rules

### No OnUpdate Polling

Never use `frame:SetScript("OnUpdate", ...)` to track cooldowns, scan bags, or monitor state. Use events. The only permitted `OnUpdate` usage is time-critical visual feedback with no event equivalent (e.g. coordinate display during an Edit Mode drag — see `EditModeNudge.lua`).

### Debounce High-Frequency Events

`BAG_UPDATE` fires 50–100× per loot interaction. `UNIT_AURA` can also fire at high rates. Debounce with a pending flag + `C_Timer.After(0, ...)`:

```lua
local scanPending = false
frame:SetScript("OnEvent", function(_, event)
    if event == "BAG_UPDATE" then
        if scanPending then return end
        scanPending = true
        C_Timer.After(0, function()
            scanPending = false
            RebuildIcons()  -- runs once per loot event, not 50+
        end)
    end
end)
```

### Cooldown Frames Are Self-Managing

`CooldownFrameTemplate` animates the swipe and countdown text internally. Combat
cooldown timing may be secret in 12.1, including item and inventory APIs.

1. Spell-backed sections query `C_Spell.GetSpellCooldownDuration(spellID, true)`
   to obtain an engine-owned `LuaDurationObject` with the global cooldown
   excluded.
2. Pass that object directly to
   `cooldown:SetCooldownFromDurationObject(duration, true)`. Addon code must not
   unpack, compare, or reconstruct its restricted timing.
3. Trinkets are item-backed: query `GetInventoryItemCooldown("player", slotID)`
   and pass start/duration/modRate directly to `cooldown:SetCooldown(...)`.
   Do not drive trinkets from the item spell cooldown; some on-use trinkets
   expose a shorter internal spell cooldown than the real equipped item cooldown.
4. `SetCooldownFromDurationObject(..., true)` clears the frame when the engine
   returns a zero duration. If the duration-object API returns `nil`, call
   `Clear()`.
5. `LuaDurationObject:IsZero()` may return a secret boolean in combat; never
   evaluate it with Lua `not`, `and`, `or`, or `if`. For styling, only inspect
   the `NeverSecret` `SpellCooldownInfo.isActive` and `isOnGCD` fields.

```lua
local duration = C_Spell.GetSpellCooldownDuration(spellID, true)
if duration then
    button.cooldown:SetCooldownFromDurationObject(duration, true)
else
    button.cooldown:Clear()
end
```

### Event Scope — Register Only What You Need

- Register events on a dedicated local frame per feature
- Unregister events when a feature is disabled
- `SPELL_UPDATE_COOLDOWN` and `BAG_UPDATE_COOLDOWN` are safe to handle synchronously

---

## WoW API Pitfalls

- **`GameMenuFrame` position**: Blizzard re-centers to `CENTER, UIParent, CENTER` on every `OnShow`. Saved positions must be re-applied from an `OnShow` hook.
- **`GameMenuFrame` buttons (Retail)**: Retail uses a `buttonPool` system — named globals like `GameMenuButtonShop` do not exist. Iterate `GameMenuFrame.buttonPool:EnumerateActive()` and match `button:GetText()` against globals like `_G.BLIZZARD_STORE`. Use `MainMenuFrameButtonTemplate` (200×35), not `GameMenuButtonTemplate`. ElvUI's game menu button is `GameMenuFrame.ElvUI` (not a named global).
- **`AUCTION_HOUSE_DEFAULT_FILTERS`**: Only exists after `Blizzard_AuctionHouseUI` loads (LoD addon). Correct event is `AUCTION_HOUSE_SHOW` (not `AUCTION_HOUSE_OPENED` — that event does not exist).
- **`RegisterStateDriver`**: Last call wins. Hooks that call `RegisterStateDriver` must use an `applying` guard to prevent recursion.
- **ElvUI fade systems**: Two parallel systems exist — individual mouseover fading (`bar.mouseover = true`, fades via `E:UIFrameFadeOut` on `Bar_OnLeave`) and global fade parent (`bar.inheritGlobalFade = true`, parented to `AB.fadeParent`, respects `mouseLock`). ElvUI sets `mouseLock = true` for vehicle/override/combat states. Vehicle visibility logic must handle both.
- **EllesmereUI action bar visibility**: Secondary bars use `RegisterAttributeDriver(frame, "state-visibility", ...)` with `[vehicleui]` and `[overridebar]` hide clauses. Reapplying an externally adjusted driver requires clearing the frame's `_eabLastVisStr` cache before calling the module visibility refresh methods.
- **EllesmereUI mouseover bars**: Mouseover mode fades bar alpha to zero independently of the secure visibility driver. Vehicle integration must preserve the configured `_savedBarAlpha` while vehicle abilities are active and honor `UNIT_EXITING_VEHICLE` / `UNIT_EXITED_VEHICLE` even while vehicle APIs still report the stale prior state.
- **`AB:PLAYER_ENTERING_WORLD`**: Does NOT call `UpdateButtonSettings` — state drivers are only re-registered during `AB:Initialize()` and explicit `Apply()` calls.
- **Vehicle-like state detection**: `HasOverrideActionBar() or HasVehicleActionBar() or IsPossessBarVisible() or UnitExists("vehicle")`. Override-bar shapeshifts trigger `HasOverrideActionBar()` but NOT `UNIT_ENTERED_VEHICLE`.
- **Inventory API availability**: `GetInventoryItemID()` and related calls are not reliable at `PLAYER_LOGIN`, and can still be transient immediately on `PLAYER_ENTERING_WORLD` after loading screens. Defer trinket scans with `C_Timer.After(0, ...)` from `PLAYER_ENTERING_WORLD` / `PLAYER_EQUIPMENT_CHANGED` so equipped slots settle first (see `CombatTracker_Trinkets.lua`).
- **`C_Spell.GetSpellInfo()` has no cooldown field**: The `SpellInfo` struct only contains `name`, `iconID`, `originalIconID`, `castTime`, `minRange`, `maxRange`, `spellID`, `rank`. There is no `cooldownMS`. To get a spell's base cooldown, use `GetSpellBaseCooldown(spellID)` which returns `cooldownMS, gcdMS` (both in milliseconds, unrestricted).
- **12.1 aura restrictions**: `C_UnitAuras` index-, slot-, instance-ID-, and restricted spell-ID results plus `UNIT_AURA` payload data cannot be used to drive addon logic while aura data is secret. `BuffHealthColor` declares `HELPFUL|PLAYER` Aura Slots with spell-ID candidate filters; Blizzard owns aura detection and button visibility, while the slot's child texture provides the health-fill tint.
- **ElvUI skinning game menu button**: Apply via `hooksecurefunc(GameMenuFrame, "InitButtons", fn)` → `E:GetModule("Skins"):HandleButton(btn, nil, nil, nil, true)`. Guard with a `IsSkinned` flag to avoid re-skinning.
- **Lazy frame creation**: Prefer `local function EnsureWidget()` pattern for UI that may never be needed. Named globals get the `MathWroQOL_` prefix and explicit `FrameStrata`/`FrameLevel`.
