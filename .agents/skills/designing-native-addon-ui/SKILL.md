---
name: designing-native-addon-ui
description: Use when designing or reviewing World of Warcraft addon settings, section hierarchy, sliders, textures, navigation, or deciding which controls belong in native Edit Mode.
---

# Designing native addon UI

**Use the game's actual controls, not an imitation of their appearance. Give each setting one owner.**

## Choose the surface first

Read the project's architecture, existing settings implementation, and Edit Mode guide. Map each control to its saved-state owner before moving it. Existing ownership contracts override the default split below; layout, merge, growth, and desaturation are not automatically Edit Mode settings merely because they affect visuals.

| Control's responsibility | Default home |
| --- | --- |
| Enablement, tracked spells/items, exclusions, activation rules | Main addon settings |
| Sounds, output mode, dependency/provider choices | Main addon settings |
| Position, dimensions, scale of a selected movable display | Native Edit Mode |
| That display's text visibility/font/size, crop/zoom, border, glow style | Native Edit Mode |
| Layout, spacing, growth, columns | Edit Mode when presentation-only; preserve an established main-settings owner |
| Group merging, contributor selection, shared configuration | Follow the feature's topology/ownership contract |
| Save/apply/clear actions tied to another game interface | That interface, with discovery guidance in main settings |

For example, an icon tracker's enablement and spell selection belong in main settings; its icon size and duration-text appearance belong beside its selected Edit Mode anchor. “Show duration text” changes presentation; “only track selected buffs” changes behavior.

## Build native settings

- Compare addons embedded in the **same container**. Standalone suites have different space, navigation, and styling constraints. Inspect their implementation to distinguish native widgets from custom artwork.
- Describe shipped behavior in platform terms. Keep comparison-addon names out of UI copy, documentation, skills, and commit/release notes. Retain third-party names only for actual integrations/dependencies or required licensing attribution.
- Prefer native vertical Settings layouts and section initializers over canvas cards. Use `Settings.RegisterVerticalLayoutCategory`/`Subcategory`, `CreateSettingsListSectionHeaderInitializer`, and native checkbox, dropdown, slider, color-swatch, and button initializers. Confirm availability on each target client using current documentation/source.
- Use native slider-with-steppers controls through `Settings.CreateSlider` and `CreateSliderOptions`: meaningful bounds, steps, units, and a readable value formatter. Native controls supply textures, fonts, hover states, and alignment; leave pooled controls unskinned. Configure dropdown scrolling explicitly rather than assuming native widgets provide it automatically.
- Group with clear headings and spacing. Keep common controls visible; avoid nested accordions, cog menus, and nearly empty categories. Fewer categories is not a win if it adds hidden navigation.
- Use short labels and tooltips for detail. Keep essential prerequisites, combat restrictions, and corrective guidance discoverable. Preserve saved values during registration; edits and Defaults must use the feature's normal apply path. Guard restricted setters as well as disabling their controls.
- Use native StaticPopup edit dialogs for IDs and exclusion lists instead of embedding custom editors in the native list. Validate on acceptance, recheck the owning profile and dependency/combat guard, and preserve long lists. Cancel leaves saved state unchanged. Supplementary note rows use an addon-owned template and prefixed mixin, not modifications to Blizzard's shared mixins.

### Dropdowns and editor state

Supply dropdown options as a function returning the current choices when the menu is generated. Enable scrolling through the initializer's native menu hook:

```lua
local function createScrollingDropdown(category, setting, options, tooltip)
    local initializer = Settings.CreateDropdown(category, setting, options, tooltip)
    initializer.customOptionHandler = function(rootDescription)
        rootDescription:SetScrollMode(320)
    end
    return initializer
end
```

Keep late-loaded choices fresh without regenerating an open pooled menu. Retain unavailable saved sound selections, disable their preview, and never substitute another sound; a silent selection remains silent.

- Register namespaced proxy settings over existing saved keys. Getters and registration remain read-only: no normalization, feature application, or inventory scans. Build catalog-dependent controls after feature initialization.
- Keep selected-buff/spell/item controls on the same page as their editor. Give editor-target selectors no native default (`nil`) so Defaults cannot switch the target midway; selection refreshes the editor without applying gameplay features. Resolve per-profile enable/color defaults against the selected owner rather than the first profile.
- Enforce provider, dependency, and combat restrictions in setters and action callbacks, including Defaults and dialog acceptance. Native modify/shown predicates reflect those gates and reevaluate on relevant setting/game events.
- A rejected proxy write may still publish the proposed value after its setter returns. Defer `Settings.NotifyUpdate` until after that notification to redisplay the saved value. Redraw only the visible category through public APIs; retain no pooled control references.
- Adapt native opaque ARGB color strings at the UI boundary while preserving existing saved RGB tables.


## Build native Edit Mode

Use the project's supported Edit Mode integration, such as its bundled LibEditMode. Register settings on the same addon-owned anchor as selection/dragging; extend its complete settings list rather than replacing it with only new rows. Reuse saved keys and remove duplicate main-settings controls when ownership moves.

For merged displays, dimensions belong to the host; contributor-specific text belongs to the explicitly selected contributor. Transient selectors are UI state: ignore their reset invocation so Reset Settings cannot change the text target midway. Keep Reset Position separate from appearance resets. Refresh through the integration's public API and use narrow live updates.

Keep empty **enabled** displays selectable. Editor previews use isolated sample data, never live restricted aura reads or real alerts. Honor feature enablement; a preview does not authorize starting disabled runtime work. Preserve combat guards and native exit cleanup. Leave engine-owned aura visibility, duration, and live text values untouched.

## Verify the result

Exercise real control handlers, saved values, dependency updates, Defaults/reset ownership, empty state, and combat/disable transitions. Include profile-specific defaults, target selection without writes, rejected-write redisplay, dialog cancel/accept, and late/missing media with the last entry of a long dropdown. Inspect the in-game surface after reload at the user's UI scale and with relevant skins. Report exactly what smoke tests exercised. A generated mockup is only a layout approximation; without the game, explicitly leave textures, rendering, taint, and live integration unverified.
