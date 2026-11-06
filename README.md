# MathWro QOL

A personal World of Warcraft addon for quality-of-life tweaks. Targets Retail Midnight 12.1.0 (`120100`) and WoW Forever 1.60.1 (`16001`).

## Compatibility

Retail loads `MathWroQOL.toc`; Forever loads `MathWroQOL_Camelot.toc`. Both manifests ship in one package, use the same Lua files, and retain a single interface number each. Keep their version, dependencies, SavedVariables, and file lists synchronized. The existing BigWigs release workflow discovers both clients automatically; no second CurseForge project is needed.

Forever uses the modern Mainline UI/API family, including Midnight's secret-value restrictions and secure Aura Containers—not the Classic API. The audit below uses the exported Blizzard UI for **Forever 1.60.1.70707**. **Shared** means the required API/UI path exists; it does not mean the feature has been tested in-game on Forever.

| Feature | Forever compatibility | Limits |
|---|---|---|
| Game Menu scale, dragging, Reset Position | Shared | Native pooled Game Menu and frame APIs are present. |
| CDM button and shortcuts | Shared, conditional | Requires Blizzard's Cooldown Manager UI; class/spell coverage is supplied by Blizzard. |
| Auction House filters | Shared | Uses modern auction filters. “Current expansion only” follows Forever's own item data. |
| Automatic combat logging | Shared | Dungeons, raids, and battlegrounds where available; Mythic+, scenarios, and other absent content types do not become available through the addon. Max-level gating uses the client-reported cap. |
| Camera distance and Spell Queue Window | Shared | Opt-in enforcement through `C_CVar`; no changes while disabled. |
| Edit Mode Nudge | Shared | Native Edit Mode and bundled LibEditMode; Ellesmere Unlock Mode also requires its compatible provider module. |
| Combat Tracker: trinkets | Shared | Discovers equipped on-use items dynamically. |
| Combat Tracker: racials | Client-specific | Forever uses its own active-racial catalog, including Human, Night Elf, Troll, Gnome, and Skyborne abilities; only spells the character knows are shown. |
| Combat Tracker: consumables | Client-specific | Forever has its own potion and Healthstone item families; item-use spell IDs come from the client. Midnight retains its own potion/fleeting catalog. Optional food and water icons select usable items from character bags on either client. |
| External and Bloodlust trackers | Client/data-dependent | Forever's externals use Protection and Sacrifice rank families, Freedom, Power Infusion, Fear Ward, and Innervate. Midnight retains its own external catalog. Bloodlust still matches the existing cataloged buff IDs; no Forever-specific replacement is assumed. |
| Vehicle Bar visibility | Provider-dependent | Requires compatible ElvUI or EllesmereUI Action Bars and a relevant vehicle/override state. |
| Buff Health Color | Provider/data-dependent | Requires compatible ElvUI and matching spell IDs. Built-ins use Retail healer data; custom profiles can use Forever spell IDs. Retail specialization filters are unavailable when the client's deprecated specialization globals are absent; use all-spec custom profiles. Ellesmere Raid Frames provides its own indicators. |
| CMC Masque skinning | Provider-dependent | Requires compatible CooldownManagerCentered and Masque plus populated Blizzard viewers. |
| Arms Heroic Strike proc companion | Retail only | Tracks Midnight's temporary Arms spell, not Forever's Heroic Strike. Runtime is not registered and the entire settings card is omitted on Forever. |
| Folio Equipment Sets | Retail only | Omnium Folio system/tree IDs are Retail-specific. Runtime is not registered and the entire settings card is omitted on Forever, even if saved settings enable it. Saved preferences are preserved. |

Provider integrations remain inactive when their provider is unavailable. Their presence in this table is not a certification of a third-party addon's Forever release. No deprecated global API shim or Classic API fork is installed.

**Install:** extract the same `MathWroQOL` folder into each client's `Interface/AddOns` directory (`_retail_` and `_forever_`). Leave both TOCs in the folder. Each client's WTF directory keeps its own settings; this addon does not copy Retail settings into Forever.

**Launch validation:** load Forever, open `/mqol`, confirm Folio Equipment Sets is absent from General and Heroic Strike is absent from CDM Plugins, then exercise shared features with that character's actual items/spells and optional providers. Confirm both cards remain available on Midnight. Test cooldowns and aura icons in combat, menu positioning, Edit Mode dragging, `/reload`, and a full logout/relaunch for saved settings. Check `!BugGrabber`/BugSack for errors. Early beta builds had community-reported SavedVariables loading failures; persistence on the launch client still needs an in-game check. No macro/CVar persistence workaround is included.

**Developer checks:** run `lua tests/ClientFeatures_smoke.lua`, `lua tests/ForeverCatalogs_smoke.lua`, `lua tests/CombatTracker_MainlineNamespaces_smoke.lua`, `lua tests/CombatTracker_Consumables_food_water_smoke.lua`, and `lua tests/CombatTracker_EditMode_smoke.lua` alongside the existing feature smoke suite, then `luac -p Core.lua Config.lua Features/*.lua tests/*.lua`. These harnesses cover client gating, ranked external buffs, client-specific racial/consumable selection, food/water selection and counts, and native Edit Mode selection/dialog/widget interactions—not Blizzard's live UI rendering or third-party provider compatibility.

Sources: [Blizzard Forever UI source, build 70707](https://github.com/Gethe/wow-ui-source/tree/aff0d8cd53bf4d9ef1c1dd2786b94461a276fb16), [Forever API notes and TOC aliases](https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes), [BigWigs multi-client packaging](https://github.com/BigWigsMods/packager#building-for-multiple-game-versions), [early beta API/persistence measurements](https://github.com/Thunderz96/forever-addon-kit).

Tracker catalog references: the installed Forever EllesmereUI `EllesmereUI_BuffPresets.lua` and CDM racial catalog, [Forever Alchemy](https://questing.wiki/wow-forever/professions/alchemy/), [Forever First Aid](https://questing.wiki/wow-forever/professions/first-aid/), and [Midnight Food & Drink](https://www.wowhead.com/spell=1291857/food-drink). Catalog data is client-specific; additional consumables can still be added by item ID.
Forever food examples: [Spiced Wolf Meat](https://questing.wiki/wow-forever/items/2680/) and [Nightfin Soup](https://questing.wiki/wow-forever/items/13931/) use Nutritious Food effects; [Tough Jerky](https://questing.wiki/wow-forever/items/117/) uses a plain restoration effect.

## Features

### General

**Game Menu Scale**
Scale the Escape menu up or down. Range: 0.5× – 2.0×. Persists across sessions.

**Game Menu Dragging**
Make the Escape menu freely draggable. Position is saved and restored on each login. Includes a Reset Position button to snap it back to centre.

**CDM Button**
Adds a "CDM" button to the Escape menu that directly opens the Cooldown Manager window (`CooldownViewerSettings`). It discovers the lowest visible custom menu button between Shop/Options and AddOns, hides its stale position while other integrations arrange themselves, then inserts itself without hardcoded addon-button names or unnecessary menu spacing. The button uses ElvUI styling when only ElvUI is active, an exact guarded EllesmereUI popup-menu skin when only EllesmereUI is active, and native Blizzard styling when both or neither suite is active. Also registers `/wa` and `/cm` chat commands as shortcuts. All three (button, `/wa`, `/cm`) can be toggled independently in the options panel.

**Auction House Filters**
Automatically pre-enables selected filters each time you open the Auction House. Two independent toggles in the options panel: "Current expansion only" and "Usable only". Filters are re-applied on every AH open so any in-session manual changes are reset.

**Folio Equipment Sets** *(disabled by default)*
In `/mqol` → **General**, enable **Folio Equipment Sets**. Open Blizzard's **Omnium Folio**: an attached panel beneath the Folio window contains the equipment-set selector and **Save current Folio**, **Apply saved Folio**, and **Clear saved Folio** buttons. Choose your runes, select an equipment set, then save. Repeat for each set—for example, Haste for Anni and Critical Strike for Havoc. A successful gear-set swap restores that set's saved choices across all purchased choice rows.

A separate stat-rune icon appears beside each linked set's **name** in the built-in Equipment Manager, without covering its gear icon or native buttons. It shows the **saved** fourth-row stat, not the currently active rune. Hover for the saved setup; click for **Apply saved Folio** or **Clear saved Folio**. The Folio panel also supports explicit Apply when Blizzard disables Equip because the gear is already worn or multiple sets contain identical items. Management controls are locked in combat; `/mqol` contains only the module toggle.

**Clear saved Folio** removes only the association and icon; it does not delete the equipment set or change gear/current runes. Associations are character-specific, survive `/reload` and set renames, and are removed when an enabled module observes set deletion. Disabled modules retain their saved setups but perform no gameplay work and hide their icons and Folio panel.

The module never purchases unselected rows or spends Folio currency. It preserves unfinished manual Folio edits, rejects unavailable saved choices before changing any rows, and waits for combat to end when a successful set swap requires a rune change. A newer successful set swap supersedes an older deferred request. Busy/restricted Folio changes report a reason; apply again when available. Commit completion is checked against committed selections, with no automatic resubmissions. Another Folio automation addon can compete for these choices; enable only one automatic controller.

### Combat Logging

**Automatic Combat Logging**
Automatically starts combat logging only while you are in a selected instance type: dungeons, Mythic+ dungeons, raids, scenarios, PvP, and arenas each have independent toggles. When you transition to an unselected type or leave instances, the addon stops only logging it started. Optional max-level-only gate also stops addon-started logging while levelling. Respects manual stop — if you disable logging mid-instance, the addon will not re-enable it until you leave all instances.

For Mythic+-only logging, enable **Mythic+** and leave **Dungeon** disabled. Logging starts when the keystone run starts, not when you enter the dungeon beforehand; normal, heroic, Mythic 0, and timewalking dungeons remain excluded. Keystone resets recheck the instance type and stop addon-started logging when it returns to a non-keystone dungeon.

### CVars and Settings

**Camera Distance** *(disabled by default)*
Checks `cameraDistanceMaxZoomFactor` each login and restores the Retail maximum of 2.6 when enabled.

**Spell Queue Window** *(disabled by default)*
Never changes your existing queue window until you explicitly enable it. First activation captures your current value unchanged; use the 0–400ms slider only when you want to enforce a different value on later logins. The options panel shows the client-reported WoW default alongside the selected value.

### Combat Tracker

**Racials, Trinkets & Consumables**
Displays icon bars for racial abilities, equipped trinkets, and consumable items (combat potions, healing potions, mana potions, healthstones). Each section tracks cooldowns with swipe animations and optional countdown text. Consumables show stack counts from your inventory. Individual racial abilities can be hidden via the options panel; the Trinkets panel accepts a comma-separated list of item IDs to exclude lore-only or otherwise unwanted on-use trinkets. When both a regular and fleeting version of a consumable are in your bags, only the fleeting version is shown.

On-use trinkets use their equipped item's full cooldown, including in combat, rather than the potentially shorter use-spell cooldown. Disabled or finished cooldowns clear the countdown and restore icon color. This path is verified against the WoW 12.1.5 APIs.

**Food & Water** *(disabled by default)*

In `/mqol` → **Combat Tracker** → **Consumables**, enable **Food** and/or **Water**. By default, highest required level takes priority. **Same-level food/water preference** chooses the next rule:

- **Highest item level** (default): keep the previous selection rule.
- **Most in bags**: choose the item with the greatest total count across every bag stack. Equal counts fall back to item level; remaining ties use the lowest item ID.

**Prefer mage food and water** defaults off. Enable it to prefer eligible conjured food/water over ordinary items, even when the ordinary item has a higher required level or count. Within each group, the existing level and same-level preference rules still apply. If no eligible mage item remains, selection falls back to ordinary food/water. Buff-food exclusion and character requirements still apply; combined food/water refreshments show one icon.

**Exclude food that grants buffs** defaults off. When enabled, automatic selection accepts only verified restoration-only food effects; buff-granting and unrecognized effects are skipped. This is deliberately conservative because the item API has no food-buff flag. A rejected food/water hybrid cannot bypass the filter through the water selection. Explicitly configured **Custom Items** are unaffected. The checkbox tooltip explains this policy.

Counts combine every bag stack of the selected item and show even when only one remains; the existing stack-count toggle and font settings apply. A selected item that restores both health and mana appears once. These icons follow the normal consumable order and disappear when no eligible item remains, regardless of “Hide icon if not in inventory.” Bag changes, level-ups, and item-data completion refresh the selection. Bank contents are excluded.

Food/water eligibility uses character requirements, not whether you can consume the item at that instant. Full health/mana and temporary eating/drinking restrictions do not remove eligible bag items from the tracker. Plain foods such as Darnassian Bleu (`2070`) and Healing Herb (`961`) remain eligible with buff-food exclusion enabled.

**Click food and water out of combat** defaults off. Enable it to left-click the automatically selected food/water icons to consume them. Clicking is inactive during combat and native Edit Mode; potions and unrelated custom-item icons remain display-only. The option works in either the normal consumables group or the separate frame.

**Show food and water in a separate frame** defaults off. Enable it to move the selected food/water out of the other consumables. In native Edit Mode, select **MathWroQOL - CT Food & Water** to position it and change its own icon size and text appearance. It remains independent of merged consumable groups. Hybrid refreshments still occupy one icon, selected custom-item overlap is not duplicated, and disabling the separate frame restores the combined display. Both displays follow the Combat Tracker and Consumables enable switches.

**Create Smart Macro** creates **MQOL Food** and **MQOL Water** in the **General Macros** tab. Drag them onto your action bars once; their targets follow the current character's automatic food/water selections, including mage preference, buff filtering, and a shared hybrid refreshment. This works independently of clickable icons and the separate frame. Enable Food and/or Water to supply the respective selection.

The macros use items only outside combat. Selection changes during combat update their bodies after combat ends; missing or disabled selections clear the corresponding use command. Repeated button presses reuse addon-owned macros instead of creating duplicates. Unrelated same-name General macros are preserved and reported as a conflict; both missing slots are checked before creating either macro. Deleted or renamed macros are not automatically recreated—press **Create Smart Macro** again to repair them. General macros are account-wide, so these managed macro bodies follow whichever character is currently playing.

**Layout & Positioning**
Each section can be positioned independently via Blizzard Edit Mode (LibEditMode integration) or merged into another section's bar. With Combat Tracker and the section enabled, enter Edit Mode and **click** the highlighted **MathWroQOL - CT Racials**, **CT Trinkets**, or **CT Consumables** selection to open a floating settings window beside the game UI. Dragging moves the group; clicking opens its settings. Layout, merge target, grid columns, and growth direction remain under `/mqol` → **Combat Tracker**.

**Customisation**
The floating Edit Mode window owns **Icon width**, **Icon height**, and stack/cooldown text visibility, font, and font-size controls. Existing saved appearance settings are preserved. For merged groups, select the visible host and use **Text section** to choose whose text you are editing; icon dimensions apply to the host's whole group. Controls cannot change settings in combat or while the tracker/section is disabled. Custom items, display order, exclusions, desaturation, and optional Masque integration remain in `/mqol`; appearance controls are not duplicated there.

### External Tracker *(disabled by default)*

Track buffs applied to you. Midnight offers Pain Suppression, Guardian Spirit, Ironbark, Life Cocoon, Blessing of Sacrifice, Blessing of Protection, Blessing of Spellwarding, Blessing of Freedom, Time Dilation, Power Infusion, and Innervate. Forever offers Blessing of Protection, Blessing of Sacrifice, Blessing of Freedom, Power Infusion, Fear Ward, and Innervate; one setting covers all supported ranks of Protection or Sacrifice for both icons and sound alerts.

Open **External Tracker** in `/mqol`, enable the module, then select and enable individual spells. Each spell independently supports **Icon with duration**, **Sound only**, or **Icon and sound**. Sound choices come from LibSharedMedia provided by your enabled addons, with a Preview Sound button. The dropdown scrolls through long lists and picks up newly registered sounds whenever it opens. Select a sound explicitly; **None** is silent. Missing libraries or sound packs do not affect icons and never substitute another sound.

Blizzard's secure Aura Slots manage icon visibility and remaining duration; native aura sound registrations play on buff application. The tracker-wide **Sound Channel** dropdown selects **Master** (default), **Sound Effects**, **Music**, **Ambience**, or **Dialog** for both alerts and Preview Sound. Playback follows the selected channel's volume and mute settings. Selected buffs include self-casts because the sound API cannot filter by caster. Settings are locked during combat.

**Edit Mode appearance:** enable the tracker, open Blizzard Edit Mode, then select **External Tracker** to open its settings panel. Adjust **Icon size** (20–80px), **Show duration text**, **Duration text size** (8–40px), **Icon zoom** (0–30% cropped per edge), and **Glow type** (None, Classic, Modern Proc, or Assisted Combat). These settings apply to all tracked icons. A Power Infusion example with sample duration text previews changes even when no spells are enabled; it disappears on exit and never triggers a sound. Text defaults to visible at 18px; glow defaults to None. Size and visibility changes apply to existing icons without changing Blizzard's duration binding. Settings cannot be changed in combat. Enable/spell/sound options and Reset Position remain in `/mqol`.

### Bloodlust Tracker *(disabled by default)*

In `/mqol` → **External Tracker**, enable **Bloodlust Tracker** for a separate duration icon. It works whether the external tracker is enabled or disabled. Bloodlust, Heroism, Time Warp, Fury of the Aspects, Primal Rage (including its alternate aura), legacy hunter equivalents, and drums through Void-touched Drums are recognized automatically. The icon shows the active buff and its remaining duration, not the Exhaustion/Sated lockout.

Select **Bloodlust Tracker** in Blizzard Edit Mode to open its own settings panel for icon size, duration-text visibility and size, zoom, and glow. Position and appearance are independent of the external tracker; its Reset Position button is in the same submenu. Its preview includes sample duration text. Bloodlust tracking is icon-only and does not change external spell sounds.

### Edit Mode

**Edit Mode Nudge**
Adds arrow buttons and a coordinate readout when a Blizzard Edit Mode or LibEditMode frame is selected. Nudge frames by 1px per click, or 10px with Shift held. Coordinates display the frame's position relative to screen centre.

### UI Integrations

Integrations are split into **ElvUI** and **EllesmereUI** submenus. Each provider's controls are disabled when that provider (or its required module) is not loaded.

**Unlock Mode Nudge — EllesmereUI** *(requires EllesmereUI Unlock Mode; disabled by default)*
Adds the same arrow controls to EllesmereUI Unlock Mode movers and uses EUI's native pixel-grid coordinate readout and movement units.

**Vehicle Bar Visibility** *(requires ElvUI or EllesmereUI Action Bars)*
Keep selected action bars (1–10) visible during vehicle combat and override bar states (e.g. shapeshift-style encounters). Handles each provider's secure visibility drivers and prevents its mouseover fade from hiding selected bars while usable vehicle abilities are active. Normal visibility and fade behaviour are restored on exit. By default only bar 1 is enabled.

**Buff Health Color — ElvUI** *(requires ElvUI)*
Recolor selected ElvUI unit frame health bars while units have configured player-cast buffs. The tint is rendered by secure 12.1 Aura Slots, preserving the feature in combat without exposing restricted aura state to addon Lua. Includes per-buff settings for Atonement, Lifebloom, Prayer of Mending, Riptide, Beacon of the Savior, Renewing Mist, plus custom spell IDs that add more buff profiles alongside the built-ins. Each buff can be enabled, colored, assigned to player, target, party, or ElvUI raid frame sizes, and restricted to relevant player specializations independently.

**Buff Health Color — EllesmereUI**
EllesmereUI Raid Frames already provides this functionality natively. In its Buff Manager, create an indicator and select **Health Bar Color** to configure spell assignment, ownership, color, and opacity. MathWroQOL deliberately does not install a second competing recolor runtime.

### CDM Plugins

**Centered Cooldown Manager Masque Skinning** *(requires CooldownManagerCentered and Masque)*
Registers CooldownManagerCentered's icon viewers with Masque so their icons can use the same skins as the rest of the UI. The Essential, Utility, and Buff Icons viewers can be enabled independently in the options panel. When enabled, three groups appear in Masque under MathWroQOL: CMC Essential, CMC Utility, and CMC Buff Icons.

**Heroic Strike Proc Icon** *(disabled by default; Arms Warrior only)*
Enable **Heroic Strike proc icon** in `/mqol` → **CDM Plugins**. The icon appears while Heroic Strike is temporarily available and disappears when consumed.
Choose **Glow** below the toggle: **None** (default), **Classic**, **Modern Proc**, or **Assisted Combat**. These built-in effects follow the icon's displayed dimensions and appear only while the proc icon is visible, with either supported CDM provider.
Choose **Placement** to put the companion on the **Right** (default) or **Left**. For vertical Ellesmere rows, Right retains the growth-end placement and Left uses the opposite end.

With **EllesmereUI CDM** enabled, it docks at the selected edge of the primary **Buffs** row, following its rendered icon size, spacing, crop, border, shape, visibility, and opacity. When the row is empty, the proc occupies its starting position rather than appending to stale container bounds. This compatibility uses capability-checked Ellesmere CDM internals; if its required helpers are unavailable, the companion stays hidden instead of appearing at an unrelated native anchor.

Without EllesmereUI CDM, it sits just outside the selected side of Blizzard's **Buff Icons** viewer and follows that viewer's position, visibility, and native icon scale; keep Blizzard's Cooldown Manager enabled. Other replacements are not independently integrated. This remains a docked companion, not a sortable entry, with no countdown or Masque dependency.

After `/reload`, check repeated procs in combat, a row with no other buffs, and live Ellesmere icon-size/crop/border changes. The companion should remain adjacent with matching dimensions and appearance, and disappear when consumed or its row is hidden.

### Debug

**Buff Health Color Diagnostics**
Adds a Debug section to the options panel with quick buttons for Target, Party 1, Raid 1, and Player. Each button prints Buff Health Color diagnostic details to chat, including Aura Container availability, active profiles, configured Aura Slot counts, specialization, and matching ElvUI unit frames. Aura presence is intentionally reported as engine-managed. The same diagnostic is available with `/mqolbuffdebug <unit>`.

## Slash Commands

| Command | Description |
|---------|-------------|
| `/mqol` | Open the MathWro QOL options panel |
| `/mqolbuffdebug <unit>` | Print Buff Health Color diagnostics for a unit token, such as `target`, `party1`, or `raid1` |
| `/wa` | Open WeakAuras (requires CDM Button → Enable /wa command) |
| `/cm` | Open Cooldown Manager (requires CDM Button → Enable /cm command) |

---

*This addon was developed with the assistance of AI.*
