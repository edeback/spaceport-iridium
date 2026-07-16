# WI-07 — Crew Arrival & Departure

## Goal
Population becomes dynamic: new crew arrive by shuttle at the docking bay (player-requested, costing credits), and sustained misery makes crew resign and leave. This activates the "all crew gone" lose condition and gives happiness (WI-05) real stakes. Visual ship arrivals are minimal v1 (a shuttle sprite flying to the docking bay is nice-to-have; teleport-in with a sound is acceptable).

## Design
- **`CrewManager`** (new manager): owns the roster (`Array[PawnBase]` of organic crew), hiring, departures, and lose-condition check.
- **Hiring:** a "Recruit crew" button (docking bay info panel via a small `CrewRecruitmentComponent`: reinforces "the docking bay is your link to the world"). Cost: credits per hire (data-driven: `data/crew_costs.tres` or constants file). Requested crew arrives after a delay (N game-hours), spawning at the docking bay module.
- **Capacity gate:** hire button disabled when crew ≥ sleeping slots (sum of SleepComponent capacities) — soft-communicates the housing loop.
- **Departure:** happiness below threshold (e.g. 20%) continuously for M game-hours → pawn resigns: alert fires, pawn walks to docking bay and despawns (with a grace window to change their mind if happiness recovers, communicated in the alert). Inventory dumps to a pile at the bay (mechanism exists in PREDELETE).
- **Death v1:** none (starvation doesn't kill yet; it drives happiness → resignation). Keeps scope contained; document as deliberate.
- **Lose condition:** roster empty AND credits below cheapest hire → "station abandoned" game-over screen (simple full-screen panel, restart/load buttons).
- **Starter crew:** replace the scene-embedded pawns in `starting_module.tscn` (`PawnStorageComponent`) with CrewManager spawning N starting crew at game start — this also fixes the WI-03 double-spawn wrinkle permanently.

## Files to touch
- **New:** `scripts/managers/crew_manager.gd`; register in `Global`, add to `main.tscn`
- **New:** `modules/components/crew_recruitment_component.gd` + UI panel (`ui/windows/…`), added to `modules/docking_bays/docking_bay_*.tscn`
- `modules/special/starting_module.tscn` — remove embedded crew_pawn instances / PawnStorageComponent usage
- `modules/components/pawn_storage_component.gd` — likely delete entirely (grep usages: starting_module, basic_sleeping_pod — WI-05 should already have cleared the pod)
- `pawns/pawn_needs_component.gd` — low-happiness duration tracking, `resignation_pending` signal
- `pawns/pawn_base.gd` — despawn flow (walk to bay then queue_free — a Job_LeaveStation, new small job: MOVE category, destination = docking bay, on-complete despawn)
- **New:** `scripts/jobs/job_leave_station.gd`
- `scripts/managers/signal_bus.gd` — `crew_hired`, `crew_resigning`, `crew_departed`, `game_over` signals
- `ui/ui_main.gd` / alerts strip (WI-05) — resignation alerts; **new** `ui/game_over_screen.gd/.tscn`
- Crew count display in main UI (extend resource display row or new label)
- WI-03 followup: CrewManager save section (roster is implied by pawn section; save pending hires + departure timers)

## Implementation order
1. CrewManager + starting-crew spawn (replacing scene-embedded pawns). Verify base game unchanged.
2. Recruitment component + arrival delay + spawn at bay + cost.
3. Happiness-duration tracking + resignation flow + Job_LeaveStation.
4. Lose condition + game-over screen.
5. Alerts, crew-count UI, save section.

## Edge cases
- Hire clicked, then docking bay deconstructed before arrival → arrival falls back to starting module cell, or refund; pick refund (simpler to reason about).
- Resigning pawn can't path to the bay (disconnected) → despawn in place after timeout (they take an escape pod, flavor-wise).
- Pawn resigns while mid-job → graceful cancel (WI-04), cargo swept/piled.
- Multiple pending hires + save/load → pending hires with remaining delay persist.
- Happiness recovers during the grace window → resignation cancels, alert clears.
- Last pawn resigning while credits remain → not game over (can hire replacements); verify the AND condition.
- Recruit spam-click → queue multiple, each charged, capacity gate re-checked per click.
- Starting module removed from save compatibility: saves from before this WI have scene-embedded pawns — acceptable break (pre-release), note in save version bump.

## Verification
1. New game: starter crew spawns via CrewManager (count matches config, not scene contents).
2. Hire 2 crew → credits deducted, arrivals after the delay at the docking bay, they join shifts (alternating A/B per WI-06) and start working.
3. Torture test: remove all food and pods for one pawn's need profile → happiness collapses → resignation alert → grace period → pawn walks to bay and leaves. Roster and crew-count UI update.
4. Recover during grace (drop food back in) → resignation cancels.
5. Drive roster to zero with insufficient credits → game-over screen; load-from-game-over works.
6. Save/load with a pending hire and a pending resignation → both timelines resume.
