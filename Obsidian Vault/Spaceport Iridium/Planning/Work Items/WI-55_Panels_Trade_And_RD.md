# WI-55 — Mode Panels: Trade & R&D

> **STATUS: planned, not started.** Seventh item of the [[04_UI_Rework_Program]]. Depends on [[WI-49_UI_Design_System]], [[WI-50_Console_And_Modes]] and [[WI-52_Vitals_And_Ledger]] (`Stepper`, `sign_color`).

## Goal

The two widest panels, **widened in place**: Trade at 1180px and R&D at 1400px. Both have all their content already; both are wearing a full-rect overlay frame that was never designed. Mockup screens 6 and 7.

Trade also absorbs two screens: the docked-trader confirmation merges into it (program decision 3), and Contracts becomes a tab (decision 1).

## Design — Trade

### 1 — Three screens become one panel with tabs

| Today | Becomes |
| --- | --- |
| `trade/trade_screen.tscn` — the order sheet: standing buy/sell targets per resource, always available, projected at current prices | The `ORDERS` tab's table |
| `trade/trader_screen.tscn` — the docked confirmation: what's *actually possible* now, capped by trader stock, cargo hold and the order sheet, at the visit's snapshot prices, editable before committing. **Pauses the sim** | The same table in its docked state, plus the footer's `CONFIRM` |
| `windows/contracts_screen.tscn` — offers (accept/decline), active (progress + deadline), history | The `CONTRACTS` tab |

Tab strip: `ORDERS` · `CONTRACTS`. The mockup also shows `PRICE HISTORY` and `ROUTES`; both are **omitted** (program decision 2) — `MarketManager` keeps only current supply and derives price from it, and routes are undesigned. The strip is built to take them; faking them is worse than their absence.

Panel header: `TRADE`, and the docked-ship line as the subtitle — `ICV MARROW · DOCKED · DEPARTS 05:20` when a trader is in, something honest like `NO SHIP DOCKED` when not. `TraderManager` already knows the visit and its remaining time.

### 2 — One table, two states

The design's table is two paged columns of commodities: `COMMODITY · BUY @ · SELL @ · HELD · AVAIL · TRADE`, with a **single `Stepper` per line where the sign carries direction** — *"positive sells and negative buys, so there are no buy/sell tabs or radio pairs to keep in sync."*

This is a real simplification of what exists: `trade_resource_row.tscn` has **two** `SpinBox`es per row, a buy and a sell, and nothing stops both being non-zero. One signed stepper makes that state unrepresentable.

**`AVAIL` is the column that earns the table.** *"Held is stock; Avail is what is not reserved. Selling into a reservation is the mistake this table exists to prevent."* `StorageData` already tracks `reserved_withdraw` and has the arithmetic (`stored - desired - reserved_withdraw`); station-wide available is a sum over `ResourceData.registered_storage`. Today the order sheet shows only market stock and total station stock, so a player can commit to selling ore that a hauler has already claimed for a construction site. Getting `AVAIL` right is the most valuable single line in this item.

Footer: `n LINES SET · n SELL · n BUY`, a running `NET` (sign-coloured), then `CLEAR` and `CONFIRM`. *"A 30-line order makes a per-item cart unreadable"* — hence a summary, not a cart.

**Undocked:** the steppers edit standing orders on the docking bay's `TradeComponent`; `NET` is a projection at current prices; `CONFIRM` is absent or reads as saved-continuously (standing orders have no commit step today and shouldn't gain one).

**Docked:** prices are the visit's snapshot, `AVAIL` is capped by trader stock and cargo hold as `trader_screen` already computes, and `CONFIRM` executes. The pure capping logic in `trader_screen._build_rows()` moves to a testable place rather than being reimplemented in the panel.

### 3 — The pause survives the merge

`trader_screen` pauses the sim while open so the trader cannot depart mid-trade, recording the prior pause state and restoring it on close. That guarantee is kept: **opening Trade while a trader is docked pauses; opening it otherwise does not.** Departure while the panel is open must still be impossible.

The prior-pause bookkeeping now has a second claimant — [[WI-53_Alerts]]' critical-alert pause. **Two independent holders each restoring "the prior state" will un-pause a game the other still wants paused.** Whichever of the two items lands second owns fixing this properly: a small reference-counted pause holder on `TimeManager` (`hold_pause(source)` / `release_pause(source)`), with the underlying `paused` flag remaining the player's own. It is a dozen lines and it removes a whole class of bug.

The mockup hides the inspector for Trade on the grounds that selection means nothing there. Implement that as `ConsolePanel.hides_inspector`, set on Trade and R&D — a flag, not a special case (WI-51 edge case).

### 4 — What the merge deletes

`trader_screen.tscn` + `.gd`; `trade_screen.tscn`'s frame; the dual-spinbox row. `trade_screen` is currently mounted directly in `ui_main.tscn` and reachable from the docking bay's `trade_component_ui` — that entry point becomes `ModeManager.open(TRADE)`, so the module inspector's trade tab gets a button rather than its own surface.

The auto-open on trader arrival is already gone (WI-50 edge case): arrival raises an alert and lights TRADE's readiness dot.

## Design — R&D

### 5 — What's already right

`unlock_panel.gd` builds each tree flowing **left-to-right by prerequisite depth**, which is exactly the design's reading order: *"Tiers advance rightward and connect with hairlines; the player's eye starts at what is done and travels toward what is expensive. Vertical trees fight the panel's shape."* The graph layout is not the problem. The frame, the density and the missing state vocabulary are.

### 6 — What changes

**Frame:** a 1400px `ConsolePanel` replacing the full-rect dimming overlay. Header: `RESEARCH`, subtitle `<TREE> · n OF m COMPLETE`, and in the header's control slot **the credit balance chip** — because *"the header carries the budget."*

**Currency is credits, not RP** (program decision 5). `UnlockData.cost` is a `Dictionary[ResourceData, int]` and stays so: the chip shows the credit balance (and, if a node costs materials, those render as cost chips on the node). No RP, no research-points income line, no ETA — the mockup's `62 RP REMAINING · ~29 CYCLES` presumes an income stream that doesn't exist. Drop the line rather than invent one.

**A second tree is a tab.** `TREE_ORDER` is `power`, `food`, `industrial`, `defense` and today they stack vertically in one scroll. The design puts them behind tabs — *"No new panel, no new mode — the layout already has the slot."* Four tabs, one tree each, each getting the full 1400px width. This is the single biggest legibility win in the panel.

**Tier columns.** The design labels each depth column `TIER 1 … TIER 5`. Note the collision: `min_tier` on `UnlockData` is the *station* tier gate (WI-26), which is a different axis from prerequisite depth. The columns are depth; the station-tier gate is a **node state** (`NEEDS TIER 3`), rendered like a locked prerequisite. Label the columns `DEPTH` or `TIER` consistently and say in the code which one it is, because two things called tier in one panel is how a bug gets written.

**Four states, four treatments** (`unlock_node_card.gd` has the states; it lacks the vocabulary):

| State | Treatment |
| --- | --- |
| Researched | GROWTH-edged, label `RESEARCHED` |
| Available and affordable | plain LIVE edge, **cost renders in place of the state label** |
| Available, unaffordable | LIVE edge dimmed, cost in `TEXT_META` |
| Locked (prereq or `min_tier`) | dashed border, dimmed, showing what gates it |

*"Cost renders in place of the state label when a tech is purchasable"* — the same slot, different content, which is why a node never needs two lines.

**Readiness dot source.** WI-50 lights R&D's console dot when an affordable, prerequisite-met, tier-met unlock exists. That predicate is `UnlockManager.can_unlock()` over the catalog, and it belongs on the manager as `has_affordable_unlock()` rather than being recomputed in the console.

**The tier/promotion section** (WI-26: export goals, inspection state) currently lives in this panel's header area. It moves to **Comms** with the rest of the ARC relationship (WI-57). Until that lands it stays here; the two items should not both try to own it in the same week.

## Files to touch

- **New:** `ui/windows/trade/trade_panel.gd` (the merged panel), `scripts/utility/trade_offer.gd` (pure: the cap-and-price arithmetic lifted out of `trader_screen`), `tests/unit/test_trade_offer.gd`
- `ui/windows/trade/trade_screen.tscn` + `.gd` — table becomes the `ORDERS` tab; frame deleted
- `ui/windows/trade/trade_resource_row.gd` + `.tscn` — two spinboxes → one signed `Stepper`; `AVAIL` column added
- **Deleted:** `ui/windows/trade/trader_screen.tscn` + `.gd` (logic absorbed)
- `ui/windows/contracts_screen.gd` + `.tscn` — becomes the `CONTRACTS` tab, frame deleted
- `ui/windows/component_ui_panels/trade_component_ui.gd` — its entry point becomes `ModeManager.open(TRADE)`
- `ui/windows/unlocks/unlock_panel.gd` — `ConsolePanel` frame, tree tabs, tier columns, credit chip
- `ui/windows/unlocks/unlock_node_card.gd` — the four state treatments and the cost-in-place-of-label rule
- `scripts/managers/unlock_manager.gd` — `has_affordable_unlock()`
- `scripts/managers/time_manager.gd` — the reference-counted pause holder (§3), if WI-53 hasn't already added it
- `modules/components/storage_data.gd` / `resource_data.gd` — a station-wide unreserved-available accessor if one doesn't fall out of what exists
- `ui/ui_main.tscn` — `TradeScreen` unmounted from the root

## Implementation order

1. `TradeOffer` + tests: the cap/price/net arithmetic, extracted from `trader_screen` before it is deleted. Pure, and it is the part that must not regress.
2. The station-wide `AVAIL` accessor, with a test.
3. Trade panel frame + `ORDERS` tab with the single signed stepper. Docked behaviour still routed to the old screen.
4. Docked state folded in; `trader_screen` deleted; the pause holder.
5. `CONTRACTS` tab.
6. R&D frame + tree tabs (biggest visible win, lowest risk).
7. Node state treatments + credit chip + `has_affordable_unlock()`.

## Edge cases

- **A trader departs while Trade is open.** Can't happen while docked-pause holds, but the panel must still handle `trader_departed` (a cheat, a load, a decline) by falling back to the undocked state rather than leaving a dead `CONFIRM`.
- **Two pause holders.** §3. Verify: open Trade docked (pause), take a critical alert (pause), acknowledge (must stay paused), close Trade (must resume) — and the same in the other order.
- **`AVAIL` must not go negative** and must be recomputed as reservations move. A haul job claiming stock while the panel is open should reduce `AVAIL` live; the panel refreshes on `slow_tick` and on `storage_changed`, not per frame.
- **Selling into a reservation** is the mistake `AVAIL` exists to prevent, so the stepper's positive limit is `AVAIL`, not `HELD`. If a player has already set an order above the new `AVAIL` (reservations moved after they set it), clamp on refresh and say so rather than silently trimming at confirm.
- **A resource with variance** (ore richness, food quality) sells a *mix*. `HELD` is a count; the price the trader pays may depend on quality. Whatever the current behaviour is, the panel must not imply a precision the sale doesn't have.
- **Contracts with no docking bay.** `contract_manager` already alerts on this; the tab should show it inline too, since that is where a player looks after reading the alert.
- **The order sheet has no commit step** and shouldn't gain one. Don't let the shared footer imply that standing orders need confirming.
- **`unlock_panel` rebuilds on every `global_unlock_changed`.** With tabs, a rebuild must preserve the selected tab and scroll position, or purchasing a node throws the player back to `power`.
- **A tree with one node**, or an empty tree from a mod (WI-47). Tab renders, panel doesn't error.
- **A node gated by both an unmet prerequisite and an unmet `min_tier`** — show the nearer gate (prerequisite), not both, or the card grows a second line.
- **1400px + the 344px right column + gutters** = 1764 at 1920. It fits with the inspector hidden; verify it fits at the smallest supported resolution, and if it doesn't, R&D is the panel that needs a scroll-x rather than a narrower design.

## Verification

1. **GUT:** `test_trade_offer` — buy capped by trader stock, by credits, and by cargo hold; sell capped by unreserved available, not by held; net-total arithmetic across a mixed order including a zero line; snapshot prices used while docked and current prices while not; a negative stepper reads as buy and positive as sell with no state where both are set. Station-wide available: sums across storages, excludes `reserved_withdraw`, never negative.
2. **Headless probe:** dock a trader via cheat, open Trade, assert the sim paused and the prior-pause state recorded; execute an order and assert stock, credits and reservations all moved consistently; close and assert resume. Assert `AVAIL` drops when a haul job claims stock.
3. **Windowed screenshot** of Trade against mockup screen 6 (two paged columns, six columns of data, footer summary) and R&D against screen 7 (tier columns, hairline connectors, all four node states visible, credit chip in the header).
4. **Manual:** run a complete trade with a docked trader from the merged panel and confirm the outcome matches what the old `trader_screen` would have done; accept and complete a contract from the Contracts tab; purchase an unlock and confirm the tab and scroll position survive the rebuild.
5. **Regression:** standing orders still fulfil on the next trader visit; contract deadlines still fire; the R&D console dot lights exactly when something is purchasable; every unlock effect (grant module, stat modifier) still applies.

## Related

- [[04_UI_Rework_Program]] — decisions 1, 2, 3 and 5.
- [[WI-08_Traders_and_Docking]] — the order sheet and the docked-visit snapshot pricing being merged.
- [[WI-14_Contracts]] — the contracts board becoming a tab.
- [[WI-26_Station_Tiers]] — `min_tier` gating, and the tier/promotion section moving to Comms.
- [[WI-53_Alerts]] — the other pause holder; whichever lands second builds the reference count.
- [[WI-51_Inspector]] — `hides_inspector`, and the docking-bay trade tab's new entry point.
- [[WI-52_Vitals_And_Ledger]] — `Stepper` and `sign_color`.
- [[WI-40_Storage_Query_Helper]] — reservation semantics behind `AVAIL`.
