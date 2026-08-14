# WI-55 — Mode Panels: Trade & R&D

> **STATUS: DONE, shipped 2026-08-11.** Seventh item of the [[Spaceport Iridium/Planning/04_UI_Rework_Program]]. Depended on [[WI-49_UI_Design_System]], [[WI-50_Console_And_Modes]], [[WI-52_Vitals_And_Ledger]] (`Stepper`, `sign_color`) and [[WI-53_Alerts]] (the reference-counted pause).
>
> **965 GUT tests green** (was 935; +30 in `test_trade_offer`). **92-check headless probe green** against the real `main.tscn`. Windowed 1920×1080 screenshots captured of Trade/ORDERS undocked, Trade/ORDERS docked, Trade/CONTRACTS and R&D. **Save-neutral** — this item adds no save state and reads none that moved.
>
> Three screens are deleted: `trade_screen`, `trader_screen`, `contracts_screen`. `SignalBus.set_up_trade` went with them, `ui_main.tscn` is down to a bare root node, and **Esc lost a level** (the trader modal), so the ladder is now four: game-over → held preview → console flyout *(build flyout / ledger / alert log)* → the open mode → the selection → an active overlay.
>
> **Deviations from the design below, and why:**
>
> 1. **The docked cargo/import caps are the other way round from §Verification.** That list says "buy capped by trader stock, by credits, and by cargo hold". `TraderManager._fulfill` is the authority and it does the opposite: a **sell** fills the trader's hold (`cargo_used += amount`), and a **buy** is capped by the room left in the bay's import bin. `TradeOffer.sell_limit` therefore takes `cargo_space` and `buy_limit` takes `import_space`. Both are tested.
> 2. **`sell_limit` adds the line's own value back to AVAIL**, which the design did not anticipate and without which the column is unusable. A sell order *causes* the hauls that reserve the stock it is going to sell — the export bin's `desired` posts pull jobs, which claim withdrawals in the storerooms — so capping at the bare unreserved figure would ratchet the player's own order downward one haul at a time. Adding the line back means a line is only ever clamped by *somebody else's* claim, which is the case the column exists for. `test_trade_offer` asserts both halves.
> 3. **A docked `CONFIRM` also writes the standing order.** The two screens used to be layered — the sheet arranged the hauls, the modal committed against what the sheet had already staged, so the modal could cap itself at the sheet's numbers and never touch them. With one table there is one number and it has to mean both things, or a docked sell of sixty ore would commit sixty units that nothing would ever haul to the bay. `CLEAR` clears both for the same reason.
> 4. **Confirming closes the panel**, as `trader_screen` did. Fulfilment runs on `slow_tick` and this panel holds the sim stopped, so a confirmation that left the panel open would look like a button that did nothing.
> 5. **The summary/action bar is content, not `footer_text`.** WI-54's contract point 1 reserves the frame's foot for a panel's standing *instruction*, one line of meta text — and this is a live total with two buttons. They stack: the bar is the last non-scrolling row of the content, the instruction is welded under it. That is also how the undocked "standing orders save as you set them" line stays visible beside a `CLEAR` that does have an effect.
> 6. **`contracts_screen.gd` became `ui/windows/trade/contracts_tab.gd` (`ContractsTab`)** rather than staying at its old path. It is a tab of the Trade panel now, it lives beside the panel that owns it, and "Screen" was the thing this program is deleting.
> 7. **Two additive frame properties, both general rather than Trade-specific.** `ConsolePanel.hides_inspector` is the flag the design asked for. `ConsolePanel` also now **forwards `on_opened`/`on_closed` to its content body and re-emits the body's `close_requested` as its own** — because `ModeManager` connects to the Control the *factory returned*, which for a code-built panel is the frame, while the control that implements the hooks and asks to be closed is the body inside it. Without the bridge Trade's `CONFIRM` emitted into nothing and the panel stayed open with the manager none the wiser. Build, Crew, Stores and Comms all get it for free.
> 8. **R&D node gates say `NEEDS STATION TIER 3`, not `NEEDS TIER 3`.** The design flags the collision (columns are prerequisite depth, `min_tier` is the station tier) and asks for consistency; spelling out the one that is ARC's business is what makes a column captioned `TIER 2` and a card saying `NEEDS STATION TIER 2` read as two different things on the same screen.
> 9. **`UnlockManager` gained `tree_progress()` as well as the specified `has_affordable_unlock()`** — the per-tab `INDUSTRIAL · 1 OF 10 COMPLETE` subtitle is catalog state, and the panel should not re-scan for a headline.
> 10. **`Stepper` gained `editable` and `is_editing()`.** The first renders the table dimmed-but-present when the station has no docking bay (WI-54: locked is a state, not an absence). The second is load-bearing: a `slow_tick` refresh landing mid-drag would snatch the number back, and the commit arriving a moment later would then write *that* value out as if the player had chosen it.
>
> **Traps worth carrying forward:**
>
> - **A body's signals and hooks do not reach `ModeManager`.** See deviation 7. Every check about the *data* passed while `CONFIRM` did nothing; the probe caught it only because it asserted the panel had actually closed.
> - **The tab strip and the open tree are two answers to one question.** Driving `_on_tab_selected` directly (a probe, the screenshot driver) swapped the grid while leaving the strip painted on the old tab — the R&D capture showed `POWER` selected over an `INDUSTRIAL` tree with an `INDUSTRIAL` subtitle. `UnlockPanel.select_tree()` is now the only public way in, and it routes through the strip. **This also made two probe checks real that had been passing vacuously.**
> - **A 1px `UIPalette.EDGE` hairline over `PANEL` is very nearly invisible at 1×.** The tree's depth connectors are `CONTROL_BORDER`. Only a screenshot showed it.
> - **A probe that stocks a bin has to check it worked.** `Cheats.spawn_resource` falls back to a `ResourcePile` when no storage on the target cell accepts the resource, and a pile is not registered storage — so `AVAIL` was zero and four assertions about it passed vacuously. `deposit(…, only_if_room = true)` also fails silently when no single bin has that much room. Both now assert.

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

*As shipped.*

**New:**

| File | What it is |
| --- | --- |
| `scripts/utility/trade_offer.gd` (`TradeOffer`) | Pure: `sell_limit` / `buy_limit` / `clamp_amount`, `is_sell` / `is_buy`, `unit_price`, the `Line` record, `line_credits` / `net_credits` / `count_sells` / `count_buys` / `summary_text`, and `sell_orders` / `buy_orders` in the shape `commit_trades` takes. 30 tests. |
| `tests/unit/test_trade_offer.gd` | The caps, the direction rule, snapshot-vs-market pricing, the totals, and the station-wide `AVAIL` accessor against real `StorageComponent`s. |
| `ui/windows/trade/trade_panel.gd` (`TradePanel`) | The merged panel body. `static create()` builds its own 1180px frame; `PAUSE_HOLD`, the two tabs, the docked/undocked table, the summary bar, `CONFIRM` and `CLEAR`. |
| `ui/windows/trade/contracts_tab.gd` (`ContractsTab`) | The `CONTRACTS` tab: offers with ACCEPT/DECLINE, active contracts with a `StatBar`, capped history, and `accept_block_reason()` inline. |

**Changed:**

- `ui/windows/trade/trade_resource_row.gd` + `.tscn` — two spin boxes → one signed `Stepper`; `AVAIL` column added; `make_header()` builds the aligned captions from the same constants
- `ui/windows/component_ui_panels/trade_component_ui.gd` + `.tscn` — two buttons → one, and it opens `ModeManager.Mode.TRADE` rather than raising its own surface
- `ui/windows/unlocks/unlock_panel.gd` — `ConsolePanel` frame, per-tree tabs, depth columns with hairline connectors, credit chip, `select_tree()`
- `ui/windows/unlocks/unlock_node_card.gd` — the `State` enum, the four treatments, and the cost-in-place-of-label rule
- `scripts/managers/unlock_manager.gd` — `has_affordable_unlock()`, `tree_progress()`
- `ui/console/console_bar.gd` — the R&D dot reads the manager's predicate instead of defining its own
- `ui/theme/console_panel.gd` — `hides_inspector`, `close_requested`, and the `on_opened` / `on_closed` / `close_requested` bridge to the content body
- `ui/theme/widgets/stepper.gd` — `editable`, `is_editing()`
- `modules/components/storage_data.gd` — `available_to_withdraw()`
- `modules/components/storage_component.gd` — `available_to_withdraw(resource)`
- `data/resources/resource_data.gd` — `available_unreserved()`, the station-wide `AVAIL`
- `ui/ui_main.gd` — both factories are one call; the trader-screen mount, its departure handler and its Esc level are gone
- `ui/ui_main.tscn` — down to a bare root node
- `scripts/managers/signal_bus.gd` — `set_up_trade` deleted

**Deleted:** `ui/windows/trade/trade_screen.gd` + `.tscn`, `ui/windows/trade/trader_screen.gd` + `.tscn`, `ui/windows/contracts_screen.gd` + `.tscn`.

`scripts/managers/time_manager.gd` needed nothing: WI-53 landed second and built the reference-counted holder, exactly as §3 said whichever item got there second should.

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

*As run. 965 GUT green, 92/92 probe checks green, four windowed screenshots.*

1. **GUT, `test_trade_offer`, 30 tests:** sell capped by unreserved available rather than by held, by the trader's hold, and never negative — plus the "a line's own reservations do not count against it" rule and the third-party claim that does clamp it. Buy capped by trader stock, by credits (truncating, and not dividing by zero on free goods) and by import-bin room. A line is never both a buy and a sell, for every sign. Snapshot prices while docked, market prices while not, and a market fallback for a resource the snapshot never saw. Net across a mixed order including a zero line. The commit split, with buys as positive magnitudes. Station-wide `AVAIL`: sums across storages, excludes `reserved_withdraw`, never negative, zero for a resource nothing stores.
2. **Headless probe, 92 checks**, driving the HUD through the same entry points the player uses. `AVAIL` dropping on a claim and recovering on release while `HELD` holds still. Both panels' widths and real heights (the WI-48 zero-height lesson), `hides_inspector` actually hiding the inspector and giving it back. Undocked: a positive line writing a sell order and a negative one replacing it with a buy, never both; the stepper's sell cap being `AVAIL`; a third party's claim clamping the line *and the panel saying so*; `CLEAR` emptying both sides. Docked: the hold taken on open and the player's own `paused` flag untouched; **two pause holders composing** — a critical alert on top of the docked hold, acknowledged, with Trade's hold surviving; snapshot prices on the row; `CONFIRM` committing the buy, writing the standing order, closing the panel and releasing the hold; and a departure mid-panel dropping `CONFIRM` rather than leaving one that commits to nobody. Contracts: the tab swapping, at real height, with the order summary bar going with it. R&D: one tab per tree, the progress subtitle, the credit chip, all four node states reachable, the manager agreeing something is purchasable, a purchase leaving the tab and the open tree alone while its own card repaints in place, and a tier-gated node saying `STATION TIER`. Finally: exactly one panel visible across all six available modes, and Esc claiming the mode with no pause left behind.
3. **Windowed screenshots**, 1920×1080, each driven into the state under test. Trade/ORDERS undocked: two paged columns, all six data columns, a cyan `+60` sell against `HELD 80 / AVAIL 80` and an amber `−18` buy, `2 LINES SET · 1 SELL · 1 BUY`, an amber `NET −2400 cr`, `CLEAR` with no `CONFIRM`, and the standing-orders footer. Trade/ORDERS docked: the subtitle naming the ship and its departure, snapshot prices visibly different from the market's, `CONFIRM` present, the commit footer. Trade/CONTRACTS: four offers with terms, payout and ACCEPT/DECLINE, the empty ACTIVE and HISTORY blocks. R&D: `INDUSTRIAL · 1 OF 10 COMPLETE`, the credit chip, `TIER 1…3` columns, and researched / affordable / prerequisite-locked / tier-locked all visible at once. **Three defects were visible only here** — see the traps in the status block.
4. **Still owed by a human at the keyboard:** letting a committed order actually fulfil across several slow ticks with goods hauled to the bay, and accepting a contract through to completion. The probe covers the commit and the state machine around it, not the multi-cycle fulfilment.
5. **Regression, in the probe:** the R&D dot's predicate moved to the manager and is asserted against `can_unlock` over the catalog; `try_unlock` still applies effects (the purchased node repaints RESEARCHED in place off `global_unlock_changed`); the standing order written by a docked confirm is what makes crew stage the goods. Contract deadlines, market drift and unlock stat-modifier broadcast are untouched code paths.

## Related

- [[Spaceport Iridium/Planning/04_UI_Rework_Program]] — decisions 1, 2, 3 and 5.
- [[WI-08_Traders_and_Docking]] — the order sheet and the docked-visit snapshot pricing being merged.
- [[WI-14_Contracts]] — the contracts board becoming a tab.
- [[WI-26_Station_Tiers]] — `min_tier` gating, and the tier/promotion section moving to Comms.
- [[WI-53_Alerts]] — the other pause holder; whichever lands second builds the reference count.
- [[WI-51_Inspector]] — `hides_inspector`, and the docking-bay trade tab's new entry point.
- [[WI-52_Vitals_And_Ledger]] — `Stepper` and `sign_color`.
- [[WI-40_Storage_Query_Helper]] — reservation semantics behind `AVAIL`.
