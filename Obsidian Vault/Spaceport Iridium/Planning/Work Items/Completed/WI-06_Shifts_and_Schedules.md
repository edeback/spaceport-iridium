# WI-06 — Shifts & Schedules

## Goal
Pawns work on schedules: two default 12-hour shifts (A: 06–18, B: 18–06) so the station runs around the clock. On-shift pawns take board jobs; off-shift pawns only satisfy needs and idle socially. Includes the default-workplace assignment concept from the design notes in its minimal form.

## Design
- `ScheduleData` per pawn: 24 slots of `{WORK, REST}` v1 (SLEEP as a distinct slot type can wait; pawns already self-manage sleep via needs). Default: shift A; new arrivals alternate A/B (WI-07).
- On `hour_changed` (WI-02): pawns entering REST finish their current job (no interrupt) and stop taking board jobs; pawns entering WORK become eligible again.
- **Assignment (minimal):** `PawnBase.assigned_module: ModuleBase` (nullable). When on-shift and the assigned module's components offer work (v1: only `MiningComponent`-style direct sources don't apply to crew — so v1 assignment means: prefer jobs whose target module is the assigned one, via a filter pass in find_job), else fall back to the full board. If this filtering proves awkward, ship shifts alone and defer assignment — it's separable.
- Off-shift job filter uses WI-04 categories: REST allows only NEEDS/MOVE/MISC.
- UI: schedule row on the pawn info panel (24 cells, click-drag paint WORK/REST); shift indicator next to pawn name.

## Files to touch
- **New:** `pawns/schedule_data.gd` (Resource)
- `pawns/pawn_base.gd` — schedule field, `is_on_shift()`, gate in `start_job()` (board lookup only when on shift)
- `scripts/managers/job_manager.gd` — `find_job(pawn, allowed_categories)` already exists post-WI-04; pawns pass categories per shift state
- `pawns/crew_pawn.tscn` — default schedule resource
- `ui/pawns/pawn_info_panel.gd` + **new** `ui/pawns/pawn_schedule_tab.gd/.tscn` — schedule editor
- `scripts/managers/time_manager.gd` — nothing new (hour_changed exists)
- WI-03 followup: schedule + assignment into pawn save section

## Implementation order
1. ScheduleData + `is_on_shift()` + board gating in `start_job()`.
2. Alternate default schedules for the two starter crew (hand-set in starting module data or first-ready assignment).
3. Schedule tab UI (paint cells).
4. (Optional, assess after 1–3) assigned_module preference filter. *Assessed 2026-07-14: deferred.* Nothing can set an assignment yet (no UI, no arrival flow until WI-07), so the filter would be dead code; revisit alongside WI-07 arrivals.
5. Save section.

## Edge cases
- Shift ends mid-long-job (construction) → job completes; the pawn just doesn't take another. Long hauls are fine too.
- ALL pawns off-shift simultaneously (player paints everyone REST) → station stalls; that's player choice, but critical construction/hunger jobs still work (needs are exempt; construction is not — acceptable).
- Off-shift pawn with empty needs queue → Job_IdleWander only (already the fallback); consider weighting wander toward social modules (one-line: prefer connections containing SocialComponent).
- Schedule edited while pawn mid-job → applies at next job selection, no interrupt.
- Clock loaded from save mid-hour → `is_on_shift` derives from current hour, stateless — safe.
- Drones ignore schedules (`MiningDronePawn.start_job` override doesn't consult the board — already bypasses; verify no schedule gate leaks into it).

## Verification
1. Two crew on opposite shifts: at hour 18 the A-pawn stops taking haul jobs and goes to eat/sleep; B-pawn picks up the queue. Production modules keep running across the boundary.
2. Paint a custom schedule (e.g. 4-on/4-off) → pawn honors it across a full cycle.
3. Needs jobs still execute during WORK hours when urgent (hunger below threshold mid-shift → pawn eats, returns to work).
4. Save/load: schedules persist; shift state correct immediately after load at an arbitrary hour.
5. No stalls: watch 2 full cycles at 4× — job board doesn't accumulate unclaimed-forever jobs while B shift sleeps (aging from WI-04 helps surface any).
