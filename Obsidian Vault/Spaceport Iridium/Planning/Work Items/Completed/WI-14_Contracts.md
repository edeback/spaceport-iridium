# WI-14 — Trade Contracts

> **Status: Implemented** (2026-07-16, together with WI-13). Deviations/decisions:
> - Contract goods are consigned freight: they use no trader cargo space and never touch the shared market settlement; the issuer pays on completion.
> - Partial goods are paid at market sell price *at failure resolution* (not at pickup), keeping the all-or-nothing bonus clean.
> - Contract demand on the bay's TradeComponent is re-synced lazily each slow_tick against whichever constructed bay exists — one mechanism covers accept, save/load, bay destruction, and rebuilt bays. Demand is not saved on the component.
> - The final-day courier dispatches (via slow_tick check) only once staged goods can fully complete the contract.
> - Debug: F7 forces an offer; the "Rush Delivery Request" event (WI-13) adds offers with a +20% premium.

## Goal
Deadline-driven delivery contracts: "Deliver 40 steel by cycle 12 for a 30% premium; penalty on failure." Offered periodically (and via events), accepted from a contracts screen, fulfilled through the docking-bay export flow (WI-08), paid on completion. This is the game's first proactive economic goal-setting for the player.

## Design
- **`ContractData` (runtime object, not .tres):** resource id, amount, unit price (market price at offer × premium), deadline cycle, penalty credits, issuing party name (flavor), state {Offered, Accepted, Fulfilled, Failed, Expired}.
- **Generation:** `ContractManager` rolls 1–2 offers per trader visit (WI-08 `trader_arrived`) plus occasional standalone offers (own timer) via event system; offer parameters scale with station output (amount ≈ fraction of station's recent production of that resource — v1 proxy: fraction of current stored total, min floor). Offers expire if unaccepted by next visit.
- **Fulfillment:** an accepted contract registers a *reserved sell order* on the docking bay's TradeComponent (WI-08 order machinery): goods hauled into the export bin count toward the contract first (contract allocation before generic sell orders). Delivery completes when the allocated amount has been picked up by any trader visit before the deadline (contract goods leave with the trader).
- **Resolution:** on completion → payout (amount × unit price) + small reputation counter (stored for future foreign-relations work, invisible v1 or a simple number). On deadline miss → penalty deducted, alert.
- **UI:** contracts screen (button near Research): offered list (accept/decline), active list (progress bar: delivered/required, time remaining), history. Alert on new offers, near-deadline (1 cycle), and resolution.

## Files to touch
- **New:** `scripts/managers/contract_manager.gd` (+ Global slot + main.tscn), `scripts/contracts/contract_data.gd`
- `modules/components/trade_component.gd` — contract allocation in the export flow (tag exported units against a contract before generic sales)
- `scripts/managers/trader_manager.gd` (WI-08) — offer-generation hook, pickup handling
- **New:** `ui/windows/contracts_screen.gd/.tscn`; `ui/ui_main.gd` — open button
- Alerts strip — offer/deadline/resolution notices
- `scripts/managers/signal_bus.gd` — `contract_offered/accepted/completed/failed`
- WI-03 followup: ContractManager save section (full contract states)

## Implementation order
1. ContractData + manager with debug-forced offers; accept/decline lifecycle.
2. Export-bin allocation + trader-pickup completion.
3. Payout/penalty/deadline resolution on cycle ticks.
4. Contracts screen + alerts.
5. Generation scaling + save.

## Edge cases
- Contract resource also has a generic sell order → contract allocation takes priority; generic sales only from surplus above contract needs.
- Partial delivery at deadline → contract pays only on full completion; partial shipped goods are paid at ordinary market sell price (they left with a trader after all), penalty applies. Document on the card ("all-or-nothing bonus").
- Player accepts more contracts than storage/production can serve → their problem; but cap concurrent accepted contracts (e.g. 3) to bound UI/logic.
- Deadline passes while no trader ever visited (goods sat ready in the bin) → if it reaches the final day without being completed, a special trader is dispatched near the deadline that only picks up contract-related goods.
- Trader arrives with contract partially staged → picks up what's allocated, remainder can still complete by deadline via later visits.
- Contract resource's market price crashes post-acceptance → contract price locked at offer time (that's the point of contracts).
- Save/load with staged-but-unshipped contract goods → allocation counters persist.
- Docking bay destroyed with active contracts → contracts fail-able but pause the "issuer pickup" rule; alert the player hard.

## Verification
1. Debug-offer a steel contract; accept; produce and haul steel → progress bar advances as the bin fills; trader visit ships it → payout = amount × locked price; history entry.
2. Let one expire unaccepted, fail one by deadline → penalty deducted, alerts correct.
3. Generic ore sell order + ore contract simultaneously → contract fills first, surplus sells normally (verify credited amounts separately).
4. Deadline with goods staged → final trader arrives for pickup.
5. Accept-cap enforced; declined offers disappear.
6. Save/load mid-contract (half-staged) → resumes exactly.
