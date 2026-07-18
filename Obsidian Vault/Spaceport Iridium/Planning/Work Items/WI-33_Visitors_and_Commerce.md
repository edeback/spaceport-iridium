# WI-33 — Visitors, Tourists, Shops & Hotels

## Goal
New revenue: shop modules where crew (paid since WI-25) and visitors spend money, hotel rooms where visitors sleep, and a visitor system — pawns who arrive with a wallet, enjoy the station, and leave when broke or unhappy. Happy departures attract more visitors; unhappy ones fewer.

## Design
- **Personal wallets.** Crew gain `personal_credits`: WI-25 wages *route to the pawn* (station pays wage → pawn wallet) instead of vanishing; crew spend at shops (money returns to station income, levy applies). Wallet on PawnBase (crew + visitors), saved. Crew with no shops just accumulate (harmless).
- **Shops.** One `shop` module scene + `ShopComponent`, customized by `ShopTypeData` .tres (`data/shops/`): name, sprite frame (via the existing sprite_selection_component pattern), price per visit band, recreation payout, flavor. Player picks the type at placement/in the panel (like processor recipe selection). Shopping is a **recreation provider**: `Job_Shop` (NEEDS category, personal-queue like other recreation) — pawn with recreation need *and* wallet ≥ price visits, pays price (wallet → `EconomyManager.record_income(price, "shops")`), gains recreation per the type. Shops need no staffing v1 (a WI-23 workspace assignment slot is a natural later upgrade — note only).
- **Hotel rooms.** `hotel_room` module: a SleepComponent variant flagged `visitor_only` (crew never claim these bunks; visitors *only* sleep here — crew quarters refuse visitors). Quality tiers via module variants/local upgrades: better rooms restore more sleep + add a visitor-mood bonus + cost more per night (charged on wake: wallet → income "hotels").
- **Visitors.** `VisitorPawn` (crew scene variant: needs component tuned — recreation/sleep/hunger yes, no schedule, no skills/traits needed v1, `is_visitor` flag excluded from CrewManager roster like WI-26's inspector): arrives via passenger shuttle (ArrivalShuttle pattern) at the docking bay — or teleporter if installed (route through its normal arrival path), wallet rolled in a band, stay timer.
  - **Behavior loop:** entirely need-driven with money gates: recreation via shops/entertainment (paying where applicable), sleep via hotel, food via a paid meal at the sustenance module (small charge, income "dining"). Leaves when: wallet below the cheapest activity, happiness below threshold, or stay timer up. Departs via bay/teleporter; despawn cleanly (`Job_LeaveStation` reuse).
  - **`VisitorManager`** (new manager, `Global.visitor_manager`): arrival pacing — `reputation: float` moves up on happy departures, down on unhappy; expected arrivals/cycle = f(reputation, hotel+shop capacity, station tier ≥ threshold per WI-26); no visitors during raids (WI-32 signal) or when no bay.
  - **Disease hook (WI-31):** arriving visitors roll a small infection chance (`acquisition: visitor` diseases).
- **Capacity gating:** visitors only spawn if a free hotel bunk exists at arrival time (the WI-07 sleep-capacity pattern applied to hotels).
- **UI:** visitor panel (wallet, mood, time left), a visitors summary in the economy screen (count, reputation, income by category).
- **Save:** visitors in the pawn section (typed like robots — scene registry), wallets, reputation + pacing state in a `visitors` section.

## Files to touch
- **New:** `pawns/visitor_pawn.gd/.tscn`, `scripts/managers/visitor_manager.gd` (+ Global slot + main.tscn), `modules/commerce/shop.tscn`, `hotel_room.tscn` + mdata/unlock .tres (tier-gated), `data/shops/shop_type_data.gd` + ~6 type .tres, `modules/components/shop_component.gd`, `scripts/jobs/job_shop.gd`
- `pawns/pawn_base.gd` — `personal_credits`; `scripts/managers/economy_manager.gd` (WI-25) — wages→wallet, income categories
- `modules/components/sleep_component.gd` — `visitor_only` flag + claim gating + wake billing hook
- `modules/components/sustenance_component.gd` / `job_eat.gd` — paid-meal branch for visitors
- `scripts/managers/crew_manager.gd` — roster exclusions (shared `is_visitor`-style flag with WI-26 inspector)
- `pawns/pawn_disease_component.gd` (WI-31) — arrival infection roll
- `scripts/managers/save_manager.gd` — pawn typing, visitors section
- `ui/` — visitor panel, economy-screen section
- WI-19: reputation/pacing math tests. WI-21: `Job_Shop` save entry.
- Remember: `filesystem_manage(op="scan")` after new `class_name` files

## Implementation order
1. Wallets + crew shopping (shops work for crew alone before visitors exist — immediate value, exercises the money loop).
2. Shop types + selection UI; hotel rooms + visitor_only gating (idle until visitors).
3. VisitorPawn + arrival/departure + need loop against shops/hotels/dining.
4. VisitorManager pacing/reputation + capacity gate + raid/tier gates.
5. Disease hook, UI, save.

## Edge cases
- Visitor goes broke mid-stay far from the bay: leaves unhappy (broke = unhappy departure for reputation) — walking out is free.
- Visitor stranded (bay deconstructed, teleporter gone): they wander needs-driven for free, unhappy, reputation sinks — alert "visitors cannot depart"; despawn via any rebuilt exit.
- Visitor caught in a raid or vented module: harmed visitors leave unhappy (or die — pawn death still doesn't exist; they leave at critical health), heavy reputation hit.
- Crew wages accumulate with no shops: fine v1; note a future "savings tax"/remittance sink.
- Hotel bunk claimed by a visitor at save time: claim re-derives on load like crew bunks.
- Reputation death spiral (no capacity → no visitors → no signal): pacing floor guarantees a trickle of brave visitors whenever capacity exists.
- Levy (WI-25) applies to shop/hotel/dining income via `record_income` — verify visitors' spending isn't double-taxed through crew wallets (crew spending station-paid wages back is intentional recirculation, taxed once at the shop).
- Sustenance stock consumed by paying visitors can starve crew: sustenance module serves crew first when stock is low (crew priority flag) — the paid meal is a surplus product.

## Verification
1. Crew-only: payday fills wallets; crew visit the shop off-shift, recreation rises, wallet drains, ledger shows "shops" income.
2. Build hotel + shops at the qualifying tier: visitors arrive at a rate matching reputation, tour shop→dinner→hotel paying at each stop, leave happy → arrivals increase over cycles; make the station miserable (no recreation, cold food) → unhappy departures → arrivals fall.
3. Wallet/timer exhaustion paths both produce clean departures; stranded-visitor alert works.
4. Raid pauses arrivals; inspector (WI-26) and visitors coexist.
5. Save/load with 3 visitors mid-activities: wallets, needs, reputation round-trip; visitors resume.
6. Regression: crew sleep never lands in hotel bunks and vice versa; crew dining unchanged and crew-prioritized; economy ledger categories reconcile (income = spending observed).
