# Testing MathWroQOL

Run commands from the repository root with Lua 5.1 installed. There is no build step or linter.

## Automated checks

Run every smoke script, then parse all addon and test Lua files:

```bash
set -e
for test in tests/*_smoke.lua; do
    lua "$test"
done
luac -p Core.lua Config.lua Config/*.lua Features/*.lua tests/*.lua
```

For focused changes, run the relevant feature smoke script. Client compatibility is covered by `tests/ClientFeatures_smoke.lua` and `tests/ForeverCatalogs_smoke.lua`. Native settings coverage lives in the `tests/Config_*_smoke.lua` scripts; tracker appearance controls are exercised by `tests/CombatTracker_EditMode_smoke.lua` and `tests/ExternalTracker_smoke.lua`.

These harnesses cover Lua behavior, saved values, provider/combat guards, and simulated UI interactions. They do not certify live Blizzard rendering, secure-frame taint, third-party provider compatibility, or real SavedVariables loading.

## In-game checks

Validate on each client affected by the change:

1. Load the addon, run `/reload`, and check the default error frame or BugGrabber/BugSack.
2. Open `/mqol` and inspect controls at the current UI scale: sliders, scrolling dropdowns, color selection, input dialogs, Defaults, unavailable providers, and combat locks.
3. Confirm Retail omits PallyPower, while Forever omits Bloodlust, Heroic Strike, and Folio. Check shared features against the character's actual spells, items, and installed providers.
4. Exercise combat entry/exit, Edit Mode selection and dragging, feature disable/re-enable, and missing dependencies.
5. Verify saved preferences after `/reload` and a full logout/relaunch on both clients. Their settings are stored separately.

The per-feature validation table in [AGENTS.md](../AGENTS.md#per-feature-validation) contains the broader gameplay checklist. Additional cases moved from the README:

### Bounded taint capture

Keep global tracing off (`/console taintLog 0`); level 4 previously crashed the user's client and must not be retried for this investigation. Run `/mqoltaint on`, then `/reload` once so the probes precede other MathWroQOL feature initializers. Play normally without changing other feature settings. `/mqoltaint` reports status. After the next matching failure, use `/mqoltaint off` and log out to flush SavedVariables.

Inspect `_forever_/WTF/Account/<account>/SavedVariables/MathWroQOL.lua` (or the corresponding Retail path), under `MathWroQOLDB.taintDiagnostics.current` and `.previous`. Captures contain first-observed native snap/flyout taint stacks, first blocked-action details, ownership snapshots, build/settings context, and an occurrence count; they do not log every table access. Check `observation`: `already-tainted` is not evidence of an originating caller. Startup should do no diagnostic work when disabled; repeated layout calls and blocked actions must not append records or repeatedly build stacks.

Automated coverage: `lua tests/TaintDiagnostics_smoke.lua` checks command enable/disable, preservation of modeled native behavior, first-observation ownership, stack/retention bounds, repeated-error counting, and two-session persistence. Actual native post-hook isolation and the original taint source still require in-game evidence. This diagnostic is not a fix for that error.

### Hearthstone destination zone

Enable the feature, bind at an inn, travel away, and hover the Hearthstone from bags and action bars. Include an inn inside a keep/castle: its suffix must name the enclosing zone rather than the inn or keep. After upgrading from local-zone-only capture, bind again to replace the previously saved label. Check `/reload`, character isolation, stale or changed binds, and disable/re-enable. The zone must come from the observed bind, not the current location. Automated coverage: `tests/HearthstoneZone_smoke.lua` includes synthetic interior-to-zone map parents, direct zone maps, and unavailable-map/continent fallback cases on both clients; it does not certify the live map hierarchy.

### Heroic Strike companion

On Retail Arms, check repeated procs in combat, an Ellesmere Buffs row with no other buffs, and live icon-size/crop/border changes. The companion must remain adjacent, match the row's appearance, and disappear when consumed or its parent is hidden. Test native CDM and Ellesmere CDM independently. Automated coverage: `tests/HeroicStrike_smoke.lua`.

### PallyPower auto-hide

On Forever, expand/collapse Other Addon Tweaks, confirm saved integration preferences, enable auto-hide, finish blessings, and remove one. The bar must return for missing or unknown buffs and at the four-minute refresh threshold. Check personal overrides, roster changes, death/resurrection, restricted/PvP state, entering combat while hidden, combat `/reload`, and disable/re-enable. Inspect native aura overlays as well as the secure casting buttons. Automated coverage: `tests/PallyPower_smoke.lua` and `tests/Config_AddonTweaks_smoke.lua`.

## Implementation references

Client-specific API baselines, ownership contracts, and source links are maintained in [Architecture](ARCHITECTURE.md). Use [Edit Mode settings](EDIT_MODE_SETTINGS.md) when changing tracker appearance controls and [food/water refresh notes](FOOD_WATER_REFRESH_NOTES.md) when investigating the unresolved Forever food-icon report.
