# Settings Panel Scroll + Backdrop Design Spec

**Date:** 2026-03-29

---

## Overview

Refactor `BuildGeneralPanel()` and `BuildElvUIPanel()` in `Config.lua` to:
1. Add a dark ElvUI-style backdrop behind the content area
2. Wrap all content in a `ScrollFrame` so it never overflows the panel bounds

---

## Structure (per panel)

Each panel gets three new layers inserted between the title and the content:

### 1. Backdrop frame

- Type: `CreateFrame("Frame", nil, panel, "BackdropTemplate")`
- Anchored: `TOPLEFT` of title's `BOTTOMLEFT` (offset -6, -8) to `BOTTOMRIGHT` of panel (offset -6, 6)
- Background: `(0.1, 0.1, 0.1, 0.9)`, single-pixel white texture tile
- Border: `1px`, `(0.25, 0.25, 0.25, 1)`
- If ElvUI is loaded: override with `E.media.backdropfadecolor` and `E.media.bordercolor`

### 2. ScrollFrame

- Type: `CreateFrame("ScrollFrame", nil, backdrop, "UIPanelScrollFrameTemplate")`
- Anchored: `TOPLEFT` of backdrop + (8, -8) to `BOTTOMRIGHT` of backdrop + (-28, 8)
  - The -28 right inset reserves space for the scrollbar
- Mouse wheel scrolling enabled via `EnableMouseWheel(true)` + `OnMouseWheel` script calling `ScrollFrameTemplate_OnMouseWheel`

### 3. ScrollChild

- Type: `CreateFrame("Frame", nil, scrollFrame)`
- Size: `530 × 900` (width matches existing 550px content minus scrollbar; height comfortably exceeds all content)
- Set as scroll child via `scrollFrame:SetScrollChild(scrollChild)`
- All content anchors to `scrollChild` instead of `panel`

---

## Content changes

- All `panel:CreateFontString`, `MakeCheckbox`, `MakeSeparator`, `CreateFrame` calls inside `BuildGeneralPanel()` and `BuildElvUIPanel()` change their `parent` argument from `panel` to `scrollChild`
- All `SetPoint` anchor references to `panel` as a `relativeTo` target change to `scrollChild`
- No layout offsets, spacing, or widget order changes

---

## ElvUI colors

If `ElvUI ~= nil` at panel build time:
```lua
local E = ElvUI[1]
backdrop:SetBackdropColor(unpack(E.media.backdropfadecolor))
backdrop:SetBackdropBorderColor(unpack(E.media.bordercolor))
```

---

## Scope

- `Config.lua` only — no changes to feature files, TOC, or Core.lua
- `BuildParentPanel()` is not changed (it only has a title and a version line, no overflow risk)
