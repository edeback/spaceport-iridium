# WI-08 — Traders, Docking Flow & the Caravan Safety Valve

## Goal
Trade stops being an instant menu and becomes ship-mediated: trader ships arrive at the docking bay periodically, and buy/sell orders are fulfilled only while (or when) a trader is present. A guaranteed periodic trader (the "caravan") removes the early-game death loop. The docking bay's export/import bins become the physical staging ground: sold goods must be hauled to the export bin before departure; bought goods land in the import bin and are hauled out by crew.

## Design
- **`TraderManager`** (new): schedules trader visits — guaranteed caravan every C cycles (data-tunable, e.g. 2), plus random extra visits with frequency scaling with station wealth later (hook, not v1). Emits `trader_arrived(trader)`, `trader_departed(trader)`. Trader stays for D game-hours.
- **Trader entity v1:** a data object (`TraderData`: name, price modifier, stock multiplier vs. market), not a full ship sim. Visual: a shuttle sprite docking at the bay (simple tween from off-screen; skippable if time is short — but strongly recommended, it's the station's heartbeat).
- **Order flow (the "intermediate" model from [[03_Bugs_and_Improvements]] D2):**
  - The trade screen is available anytime, but becomes an **order sheet**: player sets standing sell orders ("keep exporting ore") and buy orders ("import 50 steel").
  - Sell orders configure the docking bay **export storage** (accepts those resources at low priority → haul jobs feed it continuously; this mechanism already exists via storage priorities).
  - On `trader_arrived`: contents of the export bin matching sell orders are sold at current market sell price (instantly, over the visit duration for flavor); buy orders are fulfilled into the **import bin** up to market stock/credits; import bin then exports to station (high-priority source → hauled out; export flow exists).
  - Market stock moves accordingly (MarketManager withdraw/deposit already exist).
- **Compatibility:** keep the current instant trade screen behind a debug flag during transition; remove when stable.
- **UI:** trade screen reworked into order rows (resource, mode buy/sell, target amount, current price preview); docking bay panel shows "Next trader: ~X hours" and, while docked, a countdown.

## Files to touch
- **New:** `scripts/managers/trader_manager.gd` (+ `Global` slot, `main.tscn` node), `data/traders/trader_data.gd` + a couple of `.tres` trader profiles
- `modules/components/trade_component.gd` — order storage (Dictionary[ResourceData, order struct]), wiring orders → export/import StorageComponent configs (`add_stored_resource`/`remove_stored_resource`, `desired`, priority)
- `ui/windows/trade/trade_screen.gd`, `trade_resource_row.gd` (+ scenes) — order-sheet rework
- `ui/windows/component_ui_panels/trade_component_ui.gd` — next-trader/docked status
- `market_manager.gd` — no structural change; add price-preview helpers if missing (they exist)
- `scripts/managers/signal_bus.gd` — trader signals
- `modules/docking_bays/docking_bay.gd` — dock point marker + shuttle visual hookup (sprite scene **new:** `objects/trader_shuttle.tscn`)
- WI-03 followup: TraderManager save section (next-visit timers, active orders live on TradeComponent → module save)

## Implementation order
1. TraderManager with caravan scheduling + signals + docked-state; debug UI showing countdown.
2. Order model on TradeComponent; orders configure the bins (sell order → export bin accepts resource, desired=capacity, priority very low so station surplus flows in; buy order → import bin as high-priority source once stocked).
3. Fulfillment on arrival: sell export-bin contents (credit deposit via `credit_resource.change_global_total` — check how trade rows currently do it and reuse), execute buys against market + credits.
4. Trade screen rework to order sheet.
5. Shuttle visual + docking bay panel status.
6. Save sections; remove/flag legacy instant trade.

## Edge cases
- Trader arrives, export bin still being filled → sell what's there at departure too (fulfill on arrival AND on departure sweep — recommend: fulfill continuously while docked, per slow_tick, so late-hauled goods still sell).
- Buy order with insufficient credits at arrival → partial fill, order stays standing.
- Market stock exhausted for a buy → partial fill; stock replenishes via drift (WI-02 hour ticks).
- Import bin full (player never hauls it out) → buys stop; alert.
- Sell order removed while goods sit in export bin → per the design note, bin keeps accepting nothing new but existing stock still sells on next visit (implement exactly this — it's section 03 D-item "remove option without destroying").
- Docking bay deconstructed while trader docked → trader departs immediately, orders suspended (no crash); pending goods stay in the deconstruction pile.
- Two docking bays → v1: TraderManager targets the first/any bay with a TradeComponent; document that multi-bay routing is future work.
- No docking bay at all → caravan still "arrives" (parks off-station) but can't trade → alert "trader passing — no docking bay". Preserves the pressure without a bailout contradiction? **Decision:** since the station starts with a docking bay, this state means the player deconstructed it; alert is the right answer.
- Save/load while docked → trader resumes with remaining visit time.

## Verification
1. New game → within the configured cycles, shuttle arrives, docks for D hours, departs. Countdown UI matches.
2. Standing sell order for refined ore: watch crew haul ore products to the export bin over time; on trader visit, bin empties and credits rise by (amount × sell price). Prices visible pre-sale match amounts credited.
3. Buy order for steel: on visit, steel lands in import bin, crew haul it to storerooms, credits deducted, market stock drops (buy again immediately → price rose).
4. Remove a sell-order resource with stock still in the bin → no new intake, stock sells on next visit, then the bin slot disappears.
5. Death-loop test: burn all steel on modules with no refining → caravan still shows up, selling raw ore generates enough credits to buy steel → recoverable.
6. Save/load mid-visit and mid-haul: orders, bins, timers all resume.
