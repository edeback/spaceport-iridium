# WI-26 — Spacestation Tier Levels

## Goal
Pacing: the station starts at Tier 1 and climbs to 5. Each tier-up requires meeting export goals, then passing an ARC inspection (an inspector pawn physically walks your station). Tiers gate buildings/upgrades/systems so a new player isn't buried in options. The first passed inspection also switches on the WI-25 recurring costs.

**Gating decision (user-confirmed):** `min_tier` on unlocks — the existing tech tree is the single progression system; nodes above the current tier show tier-locked in the unlock panel and become purchasable on tier-up.

## Design
- **`TierData`** .tres per tier in `data/tiers/` (scanned via ResourceScanner): tier number, display name, export goals (`{resource id: amount}`), inspection checklist (module *tags* the inspector must visit — tags already exist on ModuleData), flavor text. Tier state (current tier, per-goal export progress, inspection state) lives in **UnlockManager** — it already owns progression and its save section; no new manager.
- **`min_tier`** on `UnlockData` (default 1 = today's behavior). `UnlockManager.can_purchase` gains the tier check; `unlock_panel`/`unlock_node_card` render tier-locked nodes distinctly ("Requires Station Tier 3"). Content pass: re-bucket existing unlock .tres across tiers 1–3, reserving 4–5 for Phase 3/4 content (weapons → the combat WIs, teleporter high, etc.). This re-bucketing is design-judgment work — do it in one reviewable commit.
- **Export tracking.** New `SignalBus.resources_exported(resource: ResourceData, amount: int)` emitted where goods actually leave: TraderManager sell fulfillment, instant-market sell, ContractManager deliveries. UnlockManager accumulates progress against the current tier's goals — counts normal exports, never takes goods (explicitly not a contract). Progress UI: a tier panel section in the unlock screen (goals, progress bars, inspection status).
- **Inspection offer.** Once goals are met: each `cycle_changed`, a chance to fire an "ARC Inspection" event card (EventData through the normal event system, but *offered* by UnlockManager via `EventManager.fire_event_by_id` so it isn't subject to natural-roll pacing). Decline = no penalty, another offer rolls later. Accept → inspection begins.
- **Inspection run.** ARC ship docks (ArrivalShuttle pattern, docking bay required — no bay means the offer card says so and aborts harmlessly). Inspector = a distinct pawn scene (PawnBase + breathing + health, no needs/schedule, not in crew roster — exclude from `get_crew` like drones, via an `is_visitor`-style flag that WI-33 will reuse). Behavior: sequentially `Job_MoveToLocation` to one built module per checklist tag (nearest instance), dwell a sim-hour, next; then returns to the bay and departs.
  - **Pass:** all checklist modules visited → tier +1 (`SignalBus.station_tier_changed`), alert + card, newly unlockable nodes ping. First-ever pass flips WI-25 cost toggles on.
  - **Fail:** inspector harmed (health below threshold — low O2 is the realistic path), ejected to space (module under them removed), or a checklist target unreachable (`is_reachable` checked before each leg — cheap by design). On fail: inspector leaves (or is gone), alert with the reason, goals stay met, a new offer rolls after a cooldown. No further penalty v1.
- **Tier unlocks beyond the tree:** systems gated by tier (e.g. "visitors arrive from Tier 3") are consumed by later WIs reading `UnlockManager.current_tier` — this WI just exposes the query + signal.
- **Save:** tier, export progress, inspection state (offer pending/in-progress aborts on save → v1: an in-progress inspection cancels cleanly on save with the offer re-rolling; noted simplification, avoids serializing the inspector).

## Files to touch
- **New:** `data/tiers/tier_data.gd` + `tier_1..5.tres`, `pawns/inspector_pawn.tscn` (scene reusing crew sprite + tint), inspection logic (`scripts/managers/inspection_runner.gd` or a section in unlock_manager — keep it a separate `class_name InspectionRunner` node spawned per inspection)
- `data/unlocks/unlock_data.gd` — `min_tier`; unlock .tres re-bucket sweep
- `scripts/managers/unlock_manager.gd` — tier state, export accumulation, offer pacing, save
- `scripts/managers/signal_bus.gd` — `resources_exported`, `station_tier_changed`
- `scripts/managers/trader_manager.gd`, `contract_manager.gd`, instant-sell path — emit `resources_exported`
- `data/events/arc_inspection_offer.tres` (+ a tiny effect/choice wiring that calls back into UnlockManager)
- `ui/windows/unlocks/unlock_panel.gd`, `unlock_node_card.gd` — tier locks + tier/goals panel
- `scripts/managers/crew_manager.gd` — roster exclusion flag
- `scripts/managers/economy_manager.gd` (WI-25) — first-pass toggle flip
- WI-19 followup: goal-accumulation and tier-gate unit tests

## Implementation order
1. TierData + tier state + `min_tier` gating + unlock panel rendering (tiers work with a debug `tier_up` cheat before inspections exist).
2. Export tracking + goals UI.
3. Inspection offer event plumbing.
4. Inspector run: ship, pawn, checklist walk, pass/fail detection.
5. First-pass cost-toggle flip + content re-bucket sweep.

## Edge cases
- Goals met for multiple resources via one big sale: single emission per fulfillment tick is fine, accumulation is additive.
- Checklist tag with zero built instances: goal-met check must include "at least one module per checklist tag exists", surfaced in the tier panel ("Build a Medical Bay before requesting inspection") — otherwise accept→instant-fail feels unfair.
- Player deconstructs a checklist module mid-inspection: that leg becomes unreachable → fail with reason; module-under-inspector removal → ejected → fail (both are the documented sabotage-proofing).
- Inspector walks into a vacuum section: breathing component damages them like crew; fail threshold triggers before death (inspector never dies v1, just leaves angry).
- Turbolift-only routes: inspector rides cabs like any pawn (WI-20 conveyed state) — verify.
- Offer card while another card is open: normal pending_events queue behavior.
- Export progress across tier-up: progress resets to the new tier's goals; overflow doesn't carry (simple; note for balance).
- Loaded pre-WI-26 save: migrate to tier 1 with goals fresh, but *don't* re-lock already-purchased unlocks above the tier (purchased stays purchased).

## Verification
1. Fresh game: tier 1 shows, high-tier unlock nodes visibly tier-locked and unpurchasable; `Global.cheats.tier_up()` unlocks them.
2. Export the tier-1 goal amounts via trader + contract: progress bars fill from both paths; goals met → inspection offer card appears within a few cycles; decline → re-offers later.
3. Accept: ship docks, inspector tours the checklist modules (watch pathing incl. a turbolift leg), departs, tier 2 banner; costs (WI-25) now active; new unlocks purchasable.
4. Fail paths: (a) vent the module the inspector is in → harmed → fail+reason; (b) deconstruct a checklist target mid-run → fail; (c) block the only corridor → unreachable → fail. Each recovers to a later re-offer.
5. Save/load: tier + progress round-trip; save mid-inspection cancels it cleanly and re-offers.
6. Regression: unlock purchases at legal tiers unchanged; pre-WI-26 save loads per migration rule.
