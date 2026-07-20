# WI-25 — Economic Sinks: Wages, Upkeep, ARC Levy, Economy UI, Bankruptcy

## Goal
Recurring costs force the player to keep earning: crew wages (scaled from hire cost, with a fire option), per-module upkeep, an ARC levy (% of income + periodic flat fee), an economy info page breaking it all down, and a bankruptcy arc (ARC loan at 20% interest; extended insolvency → warned, then game over). All costs are toggleable and start OFF until the first ARC inspection (WI-26 flips them on; a debug toggle covers the gap while WI-26 is unbuilt).

## Design
- **`EconomyManager`** (new manager node in `main.tscn` under `Managers/`, `Global.economy_manager`). Owns: cost toggles (`wages_enabled`, `upkeep_enabled`, `levy_enabled`), the ledger, loan state, and bankruptcy tracking. Registers after ResourceManager/MarketManager.
- **Wages.** Charged on `cycle_changed`: per crew pawn, `wage_per_cycle = pawn.hire_price * wage_fraction` (exported; drones/robots exempt — no needs component is the existing "is organic" test, but use `CrewManager.get_crew()` which already excludes drones). **Fire option:** button in the pawn panel → severance confirm → routes through the existing resignation departure (`SignalBus.crew_resigned` → `Job_LeaveStation`), flagged so it doesn't count as morale-driven. Fired/resigned pawns stop costing at the next cycle tick.
- **Module upkeep.** `ModuleData.upkeep_per_cycle` (default 0; .tres sweep for industrial/comfort modules). Charged on `cycle_changed` over built modules only (blueprints/truss free).
- **ARC levy.** Two parts: (1) income tax — every credit *earned* routes through `EconomyManager.record_income(amount, category) -> int` which skims `levy_fraction` immediately and returns the net; call sites: TraderManager sell fulfillment, ContractManager payouts, instant-market sells, (later) visitor spending. (2) flat fee every `levy_fee_cycles` cycles. Late-game "separate from ARC" turning it off is Phase 4; the toggle exists now.
- **Ledger.** Rolling per-cycle records `{cycle, income: {category: amount}, costs: {wages, upkeep, levy_fee, levy_skim, loan_payment}}`, kept for the last N cycles. Every charge/skim writes it — the UI is a pure view.
- **Negative credits.** Credits are a global-store resource (`credit_resource.global_total`) — verify `change_global_total`/`force_withdraw` tolerate negatives and that build/hire/trade affordability checks (`can_afford`) treat negative as broke (they compare totals, should hold; sweep call sites). Charges always apply in full, driving balance negative rather than partially failing.
- **Loan.** Player-initiated from the economy page (and offered via an event card when first insolvent): principal N credits (exported tiers), repayment auto-drafted over X cycles at 20% total interest, charged on cycle tick ahead of other costs. One loan at a time.
- **Bankruptcy.** While balance < 0: `insolvent_cycles` accrues per cycle; at `warning_cycles` a hard alert + event card warns that ARC will repossess in `grace_cycles`; if balance returns ≥ 0 the counter resets. Expiry → `SignalBus.game_over` (existing game-over screen; add reason text support if it lacks one).
- **Economy page UI.** New window (top-bar button next to contracts): current balance, this-cycle and last-cycle breakdown by category (each cost category expandable — wages list pawns, upkeep lists modules), levy summary, loan status + take/repay-early buttons, and the cost toggles displayed read-only (state what's active and why — "costs begin after your first ARC inspection").
- **Save:** toggles, ledger tail, loan state, insolvency counters in an `economy` section.

## Files to touch
- **New:** `scripts/managers/economy_manager.gd`, `ui/windows/economy_screen.gd/.tscn`
- `scripts/managers/global.gd` — slot; `main.tscn` — node
- `data/modules/module_data.gd` — `upkeep_per_cycle` + .tres sweep
- `scripts/managers/trader_manager.gd`, `contract_manager.gd`, `market_manager.gd` (instant-sell path), `ui/windows/trade/*` — income routes through `record_income`
- `pawns/pawn_base.gd` / `ui/pawns/pawn_info_panel.gd` — wage display + fire button; `scripts/managers/crew_manager.gd` — fire flow flag
- `scripts/managers/save_manager.gd` — economy section; `signal_bus.gd` — `economy_changed` (UI refresh) if needed
- `ui/game_over_screen.gd` — reason text
- WI-19 followup: ledger math + loan schedule unit tests; `Global.cheats.set_credits`

## Implementation order
1. EconomyManager skeleton + toggles + ledger + economy page showing income only (record_income call sites).
2. Wages + fire option.
3. Upkeep.
4. Levy (skim + periodic fee).
5. Negative-balance sweep + loan.
6. Bankruptcy warning → game over.

## Edge cases
- All costs land on the same `cycle_changed`: charge order fixed and documented (loan → wages → upkeep → fee) so the ledger reads deterministically; one combined alert, not four.
- Pawn hired mid-cycle: first wage at the next cycle tick (no proration — simple, predictable).
- Firing your last crew member to dodge wages: allowed; the existing abandonment lose-condition (crew 0 + can't afford hire) still applies and now interacts with negative balance — verify the two game-over paths don't double-fire.
- `record_income` on a levy-disabled game returns gross; call sites must use the return value, never re-read the gross amount.
- Loan taken while already insolvent: allowed (that's its purpose); repayment draft can itself drive negative — insolvency counter logic runs *after* all charges.
- Save/load mid-grace-period: warning state restores, no re-fired warning card.
- Contract penalty payments and event credit deltas: costs, not negative income — they bypass `record_income` (no levy refund on losses) but do write the ledger.
- Difficulty (WI-37) will scale these — read all rates through exported vars now, no literals.

## Verification
1. Toggles off (fresh game): zero charges, ledger still records income; enable via debug → all three cost streams charge on the next cycle and the economy page matches hand-computed numbers.
2. Sell 100 ore to a trader with levy on: credits received = gross × (1 − levy), skim visible in ledger.
3. Fire a pawn: severance flow, wage stops next cycle, roster/lose-condition regression intact.
4. Drive balance negative (cheat): warning at the configured cycle, event card, recovery resets; letting it expire shows game over with the repossession reason.
5. Loan: draft schedule totals principal × 1.2 across X cycles; early repay clears it.
6. Save/load at each stage (mid-loan, mid-grace) round-trips; GUT ledger/loan tests green.
7. Regression: trading, contracts, hiring all work with costs off (default new game unchanged until WI-26).
