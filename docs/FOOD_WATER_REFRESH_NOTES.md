# Food/water visibility — unresolved refresh observation

## Status and user evidence

**Unresolved in-game behavior; cause not confirmed.** This note concerns Combat Tracker's automatic bag-selected food/water on WoW Forever.

The user reported that food items `2070` (Darnassian Bleu) and `961` (Healing Herb) were not detected. They later clarified:

> it seemeed to come back and be shown at some point randomly while you were fixing that. so it might be that i had to open the bag or something for it to register again

The items reappearing is observed behavior. Opening the bag as the trigger is the user's hypothesis, not an established reproduction. The timing does not establish whether any code change caused recovery.

Both reported items use plain Food effect `433`, which is already accepted with buff-food exclusion enabled. Adding special cases for these item IDs is not the intended fix.

## Change already made, and its evidence limit

`Features/CombatTracker_Consumables.lua` now uses `C_PlayerInfo.CanUseItem` plus the required-level check instead of `C_Item.IsUsableItem` for automatic food/water eligibility. This separates character requirements from temporary action usability.

The Lua regression in `tests/CombatTracker_Consumables_food_water_smoke.lua` covers both reported items, temporary action usability returning false, buff exclusion, combined stack counts, and fallback after an item disappears. A throwaway harness also exercised selection and fallback with those IDs. These checks establish harness behavior, **not the cause or resolution of the user's intermittent in-game symptom**.

## Existing refresh path

In `Features/CombatTracker_Consumables.lua`:

- `ScanBags` gathers bag contents and selects eligible items.
- `getFoodWaterType` requests item data through `requestItemData` if `C_Item.GetItemInfo` has no item name. If `C_Item.GetItemSpell` has no spell ID, that candidate is skipped; this branch does not request data itself.
- `Initialize` listens for `BAG_UPDATE`, `PLAYER_LEVEL_UP`, and `ITEM_DATA_LOAD_RESULT`. Successful item-data completion queues a scan only for an item tracked in `pendingItems`.
- `QueueBagScan` coalesces work into the next frame. Disabled tracker/section event handlers do not scan.

These are inspection facts, not evidence that any particular branch failed in the user's client. There is no bag-open requirement in this implementation.

## Next investigation when reproducing in-game

1. Start with Food enabled and the reported items in bags. After `/reload`, leave bags closed and record whether the icon and count appear; then open bags and record any change. Repeat from a fresh login to distinguish cold item data from reload behavior.
2. If missing, capture the relevant item's bag count, `GetItemInfo` class/subclass/required level, `GetItemSpell` result, `CanUseItem` result, and temporary `IsUsableItem` result. Also record enabled settings, selection preference, and buff exclusion. Keep any instrumentation temporary and limited to ordinary item data.
3. Trace the actual event sequence, `pendingItems`, and whether `QueueBagScan` and `ScanBags` run before/after the icon returns. Check missing spell metadata as well as missing item names; identify the API result that changes rather than assuming bag opening refreshes it.
4. Only after isolating the failing transition, reproduce it in the existing smoke harness and fix that path. Preserve the current eligibility, buff filtering, stack aggregation, and selection-priority behavior.

**Expected result:** eligible food/water appears with bags closed, refreshes when inventory or required item data changes, and needs neither opening bags nor an arbitrary delay. Keep this issue unresolved until that behavior is observed in-game.
