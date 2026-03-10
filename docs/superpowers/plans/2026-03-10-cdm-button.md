# CDM Button Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "CDM" button to the Game Menu that opens the Cooldown Manager window, with optional `/wa` and `/cm` slash commands.

**Architecture:** A self-contained feature file (`Features/CDMButton.lua`) following the existing feature contract. The button is inserted between Shop and AddOns by hooking `GameMenuFrame:OnShow` to re-anchor `GameMenuButtonAddOns` below our button each time the menu opens. When ElvUI is active, CDM anchors below ElvUI's button instead of directly below Shop.

**Tech Stack:** WoW Lua API (Interface 120001), GameMenuButtonTemplate, slash command registration via `SLASH_*` globals.

---

## Chunk 1: Feature file and TOC registration

### Task 1: Add DB defaults to Core.lua

**Files:**
- Modify: `Core.lua:6-11`

- [ ] **Step 1: Add `cdmButton` defaults to the `defaults` table**

In `Core.lua`, extend the `defaults` table (currently ends at line 11):

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
}
```

- [ ] **Step 2: Verify in-game (after all tasks complete — note here for reference)**

After `/reload`, run in chat:
```
/dump MathWroQOLDB.cdmButton
```
Expected output: `table: { enabled = true, slashWA = true, slashCM = true }`

---

### Task 2: Create Features/CDMButton.lua

**Files:**
- Create: `Features/CDMButton.lua`

- [ ] **Step 1: Create the feature file**

```lua
local _, addon = ...

local CDMButton = { name = "cdmButton" }
addon:RegisterFeature(CDMButton)

-- The button widget, created once and reused.
local btn

local function openCDM()
    if CooldownViewerSettings then
        CooldownViewerSettings:Show()
    end
end

-- Re-anchor GameMenuButtonAddOns below `anchorFrame` and resize the menu.
-- Called every OnShow because Blizzard rebuilds button layout on each open.
local function repositionButtons(anchorFrame)
    if not btn or not btn:IsShown() then return end

    -- One button height + standard spacing used by the game menu template
    local BUTTON_HEIGHT = 24
    local SPACING = 1

    -- Anchor CDM button below anchorFrame
    btn:ClearAllPoints()
    btn:SetPoint("TOP", anchorFrame, "BOTTOM", 0, -SPACING)

    -- Shift AddOns (and everything below it) down by inserting our button
    if GameMenuButtonAddOns then
        GameMenuButtonAddOns:ClearAllPoints()
        GameMenuButtonAddOns:SetPoint("TOP", btn, "BOTTOM", 0, -SPACING)
    end

    -- Expand the frame to fit the extra button
    local extraHeight = BUTTON_HEIGHT + SPACING
    GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() + extraHeight)
end

local function getAnchorFrame()
    -- If ElvUI's game menu button exists and is shown, group below it.
    -- ElvUI names its button "ElvUIGameMenuButton".
    if ElvUI and _G["ElvUIGameMenuButton"] and _G["ElvUIGameMenuButton"]:IsShown() then
        return _G["ElvUIGameMenuButton"]
    end
    -- Otherwise anchor directly below Shop.
    return GameMenuButtonShop
end

function CDMButton:Apply()
    if not btn then return end
    local db = addon.db.cdmButton
    if db and db.enabled then
        btn:Show()
    else
        btn:Hide()
        -- If hidden, restore AddOns to its default anchor (below Shop or ElvUI btn)
        -- Blizzard will reset layout on next OnShow anyway, so nothing extra needed.
    end
end

function CDMButton:Initialize()
    local db = addon.db.cdmButton

    -- Create button once
    btn = CreateFrame("Button", "MathWroQOL_CDMButton", GameMenuFrame, "GameMenuButtonTemplate")
    btn:SetText("CDM")
    btn:SetScript("OnClick", function()
        HideUIPanel(GameMenuFrame)
        openCDM()
    end)

    -- Hook OnShow to reposition every time the menu opens
    if not GameMenuFrame._mqolCDMHooked then
        GameMenuFrame:HookScript("OnShow", function()
            if addon.db.cdmButton and addon.db.cdmButton.enabled then
                repositionButtons(getAnchorFrame())
            end
        end)
        GameMenuFrame._mqolCDMHooked = true
    end

    -- Register slash commands (cannot be unregistered; toggled by db flag at fire time)
    if db.slashWA then
        SLASH_MQOLWA1 = "/wa"
        SlashCmdList["MQOLWA"] = function()
            openCDM()
        end
    end

    if db.slashCM then
        SLASH_MQOLCM1 = "/cm"
        SlashCmdList["MQOLCM"] = function()
            openCDM()
        end
    end

    self:Apply()
end
```

- [ ] **Step 2: Commit**

```bash
git add "Features/CDMButton.lua"
git commit -m "feat: add CDMButton feature file"
```

---

### Task 3: Register CDMButton.lua in TOC

**Files:**
- Modify: `MathWroQOL.toc`

- [ ] **Step 1: Add the new file after GameMenu.lua**

```
Core.lua
Config.lua
Features\VehicleBar.lua
Features\GameMenu.lua
Features\CDMButton.lua
```

- [ ] **Step 2: Commit**

```bash
git add MathWroQOL.toc
git commit -m "feat: register CDMButton in TOC"
```

---

## Chunk 2: Config UI and final commit

### Task 4: Add CDM Button section to Config.lua GeneralPanel

**Files:**
- Modify: `Config.lua` — inside `BuildGeneralPanel()`, after the existing Game Menu Dragging section (currently ends around line 98)

- [ ] **Step 1: Add the CDM Button config section**

Append the following inside `BuildGeneralPanel()` before `return panel`:

```lua
    -- ── CDM Button ────────────────────────────────────────────────────────────

    local cdmLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    cdmLabel:SetPoint("TOPLEFT", resetBtn, "BOTTOMLEFT", 0, -24)
    cdmLabel:SetText("CDM Button")

    local cdmDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    cdmDesc:SetPoint("TOPLEFT", cdmLabel, "BOTTOMLEFT", 0, -4)
    cdmDesc:SetText("Adds a CDM button to the Game Menu that opens the Cooldown Manager.")

    local cdmEnabledCB = MakeCheckbox(panel, "Show CDM button in game menu", 16, -280,
        function() return addon.db.cdmButton and addon.db.cdmButton.enabled end,
        function(val)
            if not addon.db.cdmButton then addon.db.cdmButton = {} end
            addon.db.cdmButton.enabled = val
            addon:NotifyFeature("cdmButton")
        end
    )

    local slashNote = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    slashNote:SetPoint("TOPLEFT", cdmEnabledCB, "BOTTOMLEFT", 0, -8)
    slashNote:SetText("Slash commands (requires /reload to take effect):")

    local waCB = MakeCheckbox(panel, "Enable /wa command", 16, -330,
        function() return addon.db.cdmButton and addon.db.cdmButton.slashWA end,
        function(val)
            if not addon.db.cdmButton then addon.db.cdmButton = {} end
            addon.db.cdmButton.slashWA = val
        end
    )

    local cmCB = MakeCheckbox(panel, "Enable /cm command", 16, -356,
        function() return addon.db.cdmButton and addon.db.cdmButton.slashCM end,
        function(val)
            if not addon.db.cdmButton then addon.db.cdmButton = {} end
            addon.db.cdmButton.slashCM = val
        end
    )
```

- [ ] **Step 2: Commit**

```bash
git add Config.lua
git commit -m "feat: add CDM Button config UI to General panel"
```

---

### Task 5: Final Core.lua defaults commit

- [ ] **Step 1: Commit the Core.lua change from Task 1 if not yet committed**

```bash
git add Core.lua
git commit -m "feat: add cdmButton defaults to Core.lua"
```

---

### Task 6: In-game verification

- [ ] **Step 1: Load the addon in WoW retail and `/reload`**

- [ ] **Step 2: Open the Game Menu (Escape)**

Expected:
- CDM button appears between Shop and AddOns
- If ElvUI is active, CDM appears directly below the ElvUI button
- All other buttons are shifted down correctly with no overlap

- [ ] **Step 3: Click the CDM button**

Expected: Game Menu closes, `CooldownViewerSettings` window opens

- [ ] **Step 4: Test slash commands**

Type `/wa` and `/cm` in chat.
Expected: `CooldownViewerSettings` window opens (no error)

- [ ] **Step 5: Test config toggles**

Open Settings → MathWro QOL → General.
- Uncheck "Show CDM button in game menu", reopen Escape menu → button gone
- Re-enable → button returns on next open

- [ ] **Step 6: Test with ElvUI absent (optional)**

Disable ElvUI, `/reload`. CDM button should appear directly below Shop.
