# WI-08 — Traders, Docking Flow & the Caravan Safety Valve

## Goal
Trade stops being an instant menu and becomes ship-mediated: trader ships arrive at the docking bay periodically, and buy/sell orders are fulfilled only while (or when) a trader is present. A guaranteed periodic trader (the "caravan") removes the early-game death loop. The docking bay's export/import bins become the physical staging ground: sold goods must be hauled to the export bin before departure; bought goods land in the import bin and are hauled out by crew.

## Design
- **`TraderManager`** (new): schedules trader visits — guaranteed caravan every C cycles (data-tunable, e.g. 2), plus random extra visits with frequency scaling with station wealth later (hook, not v1). Emits `trader_arrived(trader)`, `trader_departed(trader)`. Trader stays for D game-hours.
- **Trader entity v1:** a data object (`TraderData`: name, per-resource stock, per-resource price multiplier, cargo hold size - maximum space for imports/exports), not a full ship sim. Visual: a shuttle sprite docking at the bay (simple tween from off-screen). First trader is always the same - always has a lot of steel available cheap while buys ore at a high price (plus normal trades for other resources), otherwise stock and prices are based on current values in MarketManager.
- **Order flow (the "intermediate" model from [[03_Bugs_and_Improvements]] D2):**
  - The trade screen is available anytime, but becomes an **order sheet**: player sets standing sell orders ("keep exporting ore") and buy orders ("import 50 steel").
  - Sell orders configure the docking bay **export storage** (accepts those resources at low priority → haul jobs feed it continuously; this mechanism already exists via storage priorities).
  - On `trader_arrived`: UI **trader screen** pops up to confirm trades, showing **actual** values of what is being imported/exported and the final cost or earnings. This is different than the **order sheet**: the order sheet is what is desired, this screen is for what is actually possible. Player can modify final numbers here before committing to the trade, at which point contents of the export bin matching sell orders are sold at current market sell price (as much as is available instantly); buy orders are fulfilled into the **import bin** up to market stock/credits; import bin then exports to station (high-priority source → hauled out; export flow exists). If there wasn't enough stock currently in the docking bay to fulfill the order, this will be rechecked on slow_tick to buy/sell goods as resources are hauled in. The order sheet is updated to account for any fulfilled trades.
  - The player may reopen the **trader screen** later to update trades as long as the trader is in dock.
  - Trades are done against the **trader's** inventory as opposed to the entire market.
  - Market stock moves accordingly (MarketManager withdraw/deposit already exist) but only *after* the trader leaves, to allow for price stability during the duration of the trader's visit.
- **UI:** trade screen reworked into order rows (resource, mode buy/sell, target amount, current price preview); docking bay panel shows "Next trader: ~X hours" and, while docked, a countdown. An alert is given shortly (~1 hr) before the trader is due to depart. Game is paused while the UI is up so the trader doesn't leave mid-trade.

## Files to touch
- **New:** `scripts/managers/trader_manager.gd` (+ `Global` slot, `main.tscn` node between UnlockManager and SaveManager), `data/traders/trader_data.gd` + `.tres` profiles — including the fixed **first-caravan profile** (cheap steel stock, high ore buy price) plus at least one market-derived generic
- `modules/components/trade_component.gd` — order-sheet storage (Dictionary[ResourceData, order struct]), wiring orders → export/import StorageComponent configs (`desired`, priority), and the slow_tick fulfillment loop for committed-but-unfilled trades while docked
- `ui/windows/trade/trade_screen.gd`, `trade_resource_row.gd` (+ scenes) — order-sheet rework (standing buy/sell targets + price preview)
- **New:** `ui/windows/trade/trader_screen.gd/.tscn` — the arrival popup: shows *actual* fulfillable amounts vs. the order sheet, lets the player edit numbers before committing, reopenable while docked; pauses the sim while open (`Global.time_manager.paused` — UI stays real-time by design, so the screen keeps working)
- `ui/windows/component_ui_panels/trade_component_ui.gd` — "Next trader: ~X hours" / docked countdown
- `market_manager.gd` — price/stock helpers already exist (`get_buy_price`/`get_sell_price`/`get_quantity_available`, `withdraw_resource`/`deposit_resource`); add a deferred-settlement path so market stock/prices apply the visit's net trades **at departure**, not during
- `scripts/managers/signal_bus.gd` — `trader_arrived`/`trader_departed`; the ~1h departure warning reuses the existing `station_alert` (WI-07 alerts strip)
- Shuttle visual: **reuse the WI-07 `objects/arrival_shuttle.gd` pattern** (sim-scaled movement — NOT a tween; tweens run on the wall clock and ignore pause/speed). New scene with the trader sprite reusing/subclassing that script. Dock-position and approach-side helpers already exist in `CrewManager` (`_bay_dock_position`/`_bay_approach_sign`) — hoist them onto `DockingBay` so both managers share them
- WI-03 followup: TraderManager save section — next-visit timer AND the active visit (profile id, remaining docked hours, **remaining trader stock/cargo** — trades are against the trader's inventory, so partial fills must persist); order sheet lives on TradeComponent → module save section

## Implementation order
1. TraderManager with caravan scheduling + TraderData profiles (fixed first caravan, market-derived generics) + signals + docked-state; debug countdown.
2. Order model on TradeComponent; orders configure the bins (sell order → export bin accepts resource, desired=capacity, priority very low so station surplus flows in; buy order → import bin as high-priority source once stocked).
3. Fulfillment: commit flow against the **trader's** inventory + credits (deposit via `credit_resource.change_global_total` — check how trade rows currently do it and reuse); slow_tick recheck of committed-but-unfilled trades while docked; net market settlement at departure.
4. Trade screen rework to order sheet.
5. Trader screen (arrival popup: actual vs. ordered, editable, commit, reopen-while-docked, sim pause while open).
6. Shuttle visual (shared ArrivalShuttle pattern) + docking bay panel status + ~1h departure warning alert.
7. Save sections; remove/flag legacy instant trade.

## Edge cases
- Trader arrives, export bin still being filled → committed sell trades fulfill **continuously on slow_tick while docked** (decided in Design), so late-hauled goods still sell; the order sheet updates as trades fulfill.
- Charge/credit on fulfillment, not on commit: if the trader departs with part of a committed buy unfilled (bin full, goods never hauled in), the unfilled remainder costs nothing and the standing order stays on the sheet.
- Buy order with insufficient credits at commit → trader screen shows the affordable actual; partial fill, order stays standing.
- **Trader** stock exhausted for a buy → partial fill against what the trader carries (trades are per-trader, not against the whole market); the market itself only moves at departure settlement, so prices stay stable for the entire visit.
- Trader screen open → sim paused, so the departure countdown is frozen and the trader cannot leave mid-trade (this is the intent, not a bug); closing unpauses.
- Import bin full (player never hauls it out) → buys stop; alert.
- Sell order removed while goods sit in export bin → stock is dumped into a ResourcePile in the Docking bay, is removed by haulers later
- Docking bay deconstructed while trader docked → trader departs immediately (settling whatever was already fulfilled), orders suspended (no crash); pending goods stay in the deconstruction pile.
- Two docking bays → v1: TraderManager targets the first/any bay with a TradeComponent; document that multi-bay routing is future work.
- No docking bay at all → caravan still "arrives" (parks off-station) but can't trade → alert "trader passing — no docking bay" via station_alert.
- Save/load while docked → trader resumes with remaining visit time AND remaining trader inventory/cargo (partial fills must not reset).
- Save/load while the trader screen is open (game paused) → screen state isn't persisted; reopening from the bay panel after load is acceptable v1.

## Verification
1. New game (with a docking bay built/present per the edge-case decision) → within the configured cycles, the trader shuttle flies in from the bay's clear side, docks for D hours, departs. Countdown UI matches, and the ~1h departure warning alert fires.
2. Trader arrival pops the trader screen (sim pauses); it shows actual fulfillable amounts vs. the order sheet; edit a number down, commit → only the edited amount trades. Reopen the screen later in the visit and adjust again.
3. Standing sell order for refined ore: watch crew haul ore products to the export bin over time; committed sales fulfill incrementally on slow_tick as goods arrive, credits rising by (amount × sell price shown at commit). Prices do NOT move during the visit.
4. Buy order for steel: steel lands in the import bin from the **trader's** stock, crew haul it to storerooms, credits deducted per fulfilled amount. After departure, market stock/prices reflect the visit's net trades (check the next trader's market-derived prices).
5. First-caravan profile: the first visitor always carries cheap plentiful steel and pays high for ore, regardless of market state.
6. Remove a sell-order resource with stock still in the bin → stock is dropped into a ResourcePile.
7. Death-loop test: burn all steel on modules with no refining → caravan still shows up, selling raw ore at the first caravan's high ore price buys enough steel → recoverable.
8. Save/load mid-visit and mid-haul: orders, bins, visit timer, and the trader's remaining inventory all resume.
