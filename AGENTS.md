# AGENTS.md — MathWroQOL

Instructions for AI agents (Codex, OpenCode) operating in this repository.

## Architecture Reference

Read `docs/ARCHITECTURE.md` before writing or modifying any code. It contains the canonical reference for load order, feature contracts, code style, naming conventions, Config.lua helpers, performance rules, and WoW API pitfalls.
- Target Retail interface: `120100` in `MathWroQOL.toc`; keep it as one value.

Before changing addon settings visuals, sliders, textures, navigation, or Edit Mode control placement, read `.agents/skills/designing-native-addon-ui/SKILL.md`. Keep this repo's ownership contracts in `docs/ARCHITECTURE.md` and implementation recipe in `docs/EDIT_MODE_SETTINGS.md` authoritative.

---

### API Documentation

Use Context7 (`npx ctx7@latest library` followed by `npx ctx7@latest docs`) to retrieve current WoW API documentation before making API-dependent changes.

### Local Forever Addons

- Relative to this repository root, Forever's installed addons are at `../../../../_forever_/Interface/AddOns/`.
- Inspect an installed provider there when researching Forever integrations; for example, PallyPower is at `../../../../_forever_/Interface/AddOns/PallyPower/`.

### Blizzard UI Source

- Upstream exported UI/API source: [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source). Context7 library ID: `/gethe/wow-ui-source`; its indexed `live` branch is not proof of Forever behavior.
- For Forever API-dependent changes, inspect a pinned Forever export. Latest baseline used here: [1.60.1.70938, `bebcb6bf309cf41b41bd74f8ca651e6a105b2676`](https://github.com/Gethe/wow-ui-source/tree/bebcb6bf309cf41b41bd74f8ca651e6a105b2676). Earlier compatibility audit: [1.60.1.70707, `aff0d8cd53bf4d9ef1c1dd2786b94461a276fb16`](https://github.com/Gethe/wow-ui-source/tree/aff0d8cd53bf4d9ef1c1dd2786b94461a276fb16).
- Raw-file pattern: `https://raw.githubusercontent.com/Gethe/wow-ui-source/<commit>/Interface/AddOns/<path>`. Discover paths from the selected commit's tree; generated API contracts are in `Blizzard_APIDocumentationGenerated/`, native settings in `Blizzard_Settings_Shared/`, and secure visibility drivers in `Blizzard_RestrictedAddOnEnvironment/SecureStateDriver.lua`.
- Retail audit revisions and feature-specific source links live in `docs/ARCHITECTURE.md`; use the revision matching the target client and record the inspected build/commit when updating a contract.

---

## Build / Lint / Test

There is no build step or linter. Run the Lua 5.1 smoke and syntax checks:

```bash
lua tests/CombatTracker_Cooldowns_smoke.lua
lua tests/CombatTracker_TrinketExclusions_smoke.lua
lua tests/CombatLog_smoke.lua
lua tests/BuffHealthColor_smoke.lua
lua tests/EditModeNudge_smoke.lua
lua tests/ExternalTracker_smoke.lua
lua tests/Config_Dropdown_smoke.lua
lua tests/Config_Profiles_smoke.lua
lua tests/Config_CombatTracker_smoke.lua
lua tests/HeroicStrike_smoke.lua
lua tests/FolioEquipmentSets_smoke.lua
luac -p Core.lua Config.lua Config/*.lua Features/*.lua tests/*.lua
```

Then validate in-game:

1. Load the addon in WoW Retail (`_retail_`)
2. Run `/reload` after each change
3. Check the default error frame or `!BugGrabber` / `BugSack`

### Per-feature Validation
| Feature | How to test |
|---|---|
| `GameMenu.lua` | Press Escape; verify scale, drag, button placement, and Reset Position |
| `CDMButton.lua` | Press Escape; verify the CDM button appears and slash commands work |
| `HeroicStrike.lua` | On Arms, enable in `/mqol` → CDM Plugins. Test native CDM without Ellesmere, then Ellesmere CDM independently. Gain/consume repeated procs in combat; check active-proc `/reload`, disable/re-enable, spec changes, movement, scaling, and parent visibility. Check Right (default)/Left placement, None/Classic/Modern Proc/Assisted Combat, and glow removal on proc consumption. For Ellesmere, verify the primary Buffs row's empty state, growth direction, live crop/border/shape settings, and return to native mode when its CDM is disabled. |
| `AuctionFilter.lua` | Open Auction House; confirm configured filters are pre-enabled |
| `FolioEquipmentSets.lua` | Enable in `/mqol` → General; verify only the toggle remains there. Open Omnium Folio and use its attached set selector and Save/Apply/Clear controls to save Haste and Crit full setups to two gear sets. Swap both ways and verify every saved choice plus the saved-stat icons beside Equipment Manager set names, tooltips, and native button clearance. Check badge and Folio-panel Apply/Clear preserve gear/current runes and never delete the set. Test identical-gear sets with explicit Apply, long names, scrolling/recycled rows, rename/deletion, `/reload`, Folio close/reopen, disabled/re-enabled state, combat-locked controls, deferred swap cancellation, unavailable rows, and unfinished manual Folio edits. Check the footer fits the screen at the current UI scale. Use only one automatic Folio controller. |
| `CombatLog.lua` | Enter/leave an enabled instance type; confirm logging starts/stops |
| `VehicleBar.lua` | Test selected bars with ElvUI and EllesmereUI Action Bars independently when available |
| `BuffHealthColor.lua` | With ElvUI, test configured spell IDs on player, target, party, and raid frames; verify restricted aura updates produce no Lua errors |
| `EditModeNudge.lua` | Test native Edit Mode/LibEditMode and EllesmereUI Unlock Mode independently |
| `CombatTracker.lua` | Enable in `/mqol`; enter combat; trigger a racial, Healthstone or potion, and on-use trinket; verify each cooldown starts immediately without restricted-value errors. Add a trinket ID to the exclusions field and verify its icon is hidden, then remove it and verify the icon returns |
| `ExternalTracker.lua` | Enable the module and individual spells in `/mqol` → External Tracker. Have another player apply a selected external in combat; verify duration icon, selected sound, and both modes. Verify removal hides the icon/glow, disabled spells stay inactive, self-casts trigger, and missing sound packs do not replace sounds. In Edit Mode, verify the Power Infusion preview with no enabled spells, size/zoom/all glow choices, saved positioning, and that exiting or entering combat removes the preview without affecting real sound alerts |
| Bloodlust (`ExternalTracker.lua`) | In the External Tracker submenu, enable Bloodlust Tracker with externals disabled, then test both together. Verify class variants and drums show one duration icon, expiry hides it despite Exhaustion/Sated, and either master toggle leaves the other tracker unaffected. Check its separate Edit Mode preview, size/zoom/glow, saved position, Reset Position, and combat-locked controls |
| `Config.lua` | Run `/mqol`; verify provider-specific submenus, disabled dependency states, controls, and first-open layout |
| `CVarSettings.lua` | Run `/mqol`; confirm Spell Queue Window leaves the current CVar unchanged until explicitly enabled, first activation captures that value without writing it, and only that captured or subsequently user-selected value is restored after `/reload` |

---

## Releases
GitHub Actions only. Use Semantic Versioning: additive features increment MINOR; fixes increment PATCH. Bump `## Version:` in **both** `MathWroQOL.toc` and `MathWroQOL_Camelot.toc` together.

Merging a manifest version bump into `main` triggers `.github/workflows/release-on-main.yml`: validate matching versions, create/push annotated `vX.Y.Z` at the merged commit, and explicitly dispatch `.github/workflows/release.yml` → `BigWigsMods/packager@v2`. The dispatch is required because tags pushed with `GITHUB_TOKEN` do not trigger another push workflow. Existing versions on earlier commits are skipped; rerunning the same merged commit can redispatch packaging.

Manual releases remain available by creating/pushing an annotated tag, or dispatching `release.yml` with its `tag` input. Keep release tags on merged `main` commits.

Do **not** use comma-separated `## Interface:` values in the TOC — the packager will produce a broken `release.json`.

---

## Git Conventions

- Commit message format: `type(scope): short description`
  - Types: `feat`, `fix`, `docs`, `chore`, `refactor`
  - Scope is optional but useful (e.g. `fix(combat-tracker):`, `feat(trinkets):`)
- Body explains *why*, not *what*
- Keep commits atomic — one logical change per commit
