# WI-20 — Movement & Animation Update: CONVEYED State + Sim-Time Animations

> **Status: DONE (2026-07-18).** Implementation notes / deviations from the plan below:
> - **Continuation = repath, not index-resume.** `exit_conveyed()` re-runs pathfinding from the drop-off floor instead of resuming `next_path_index` past the turbolift vertices. One mechanism covers normal arrival, diverted drop-offs (cancelled ride, deconstructed destination), and ejection identically; pathfinding from the arrival floor yields the same continuation. The `run_pathfinding` special case that retargeted `RideRequest.to_floor` mid-ride (path starting at a cab) is gone — repaths are simply deferred while Conveyed (guard in `run_pathfinding`, skip in the module-removed/group-changed handlers) and happen once at exit.
> - **No temporary legacy-path flag.** The await-across-the-ride path was removed outright; parity was verified in-session against the full checklist below instead of behind a flag.
> - **`RideRequest.finished` now resolves the boarding phase only** (true = onboard + Conveyed, false = died pre-boarding). Nothing signals arrival; the cab calls `exit_conveyed()` at drop-off.
> - **Animation mechanic**: `TimeManager.animation_speed()` (0 while paused, else speed) + a `sim_animation` node group resynced on `speed_changed`/`pause_state_changed`; door sprites register via `TimeManager.sync_animation()` in `create_state`/`_ready`. Pawn sprites instead re-apply per-frame in `PawnBase._process` — they reparent constantly (canvas layers, cab boarding) and group resyncs can't reach out-of-tree nodes. Airlock audit: its doors are `Behavior_LinkedDoors`, covered by the behavior change; its waits were already `sim_seconds`.
> - **Adjacent bugs fixed in passing**: `SaveManager._get_pawns_save` called nonexistent `ModuleTurbolift.get_waiting_slot()` (mid-ride save crashed; now `get_global_center()`); `TurboliftCab.destroy()` neither reparented riding pawns out of the cab before `queue_free` (pawn freed with cab) nor stopped `_process` (null-`shaft` crash on the post-destroy frame); `TurboliftShaft.request_ride` awaited forever when every cab was at capacity (now fails the boarding).
> - **Verified in-game** (godot-ai): 5-floor rides at 1×/4× (6.5s → 2.0s real, door time scales); mid-ride `interrupt_with_job` → next-stop exit + new job; destination floor deconstructed mid-ride → cab reversed to surviving exit, honest movement fail; whole shaft deconstructed mid-ride → pawn ejected, no stale override; pause mid-ride and mid-door-frame → exact freeze/resume; mid-ride save lands the pawn on the cab's current floor. GUT 75/75.

## Goal
Make position-ownership handoffs (turbolift rides today; trams/teleporter charge later) an explicit `CONVEYED` movement state instead of a suspended `await`, so rides are interrupt-safe and serializable (WI-21 consumes this). Sync gameplay animations (doors especially) to TimeManager speed so 4× game speed no longer means doors eat a disproportionate share of travel time.

**Scope decision (user-confirmed):** CONVEYED only. Cosmetic waits (door opens, boarding shuffles) keep their awaits — the rule of thumb stands: awaits for cosmetic waits, an explicit state for anything that *owns a pawn's position*. Full no-await PathBehavior is explicitly out of scope.

## Design
- **New state:** `PawnMovementComponent.State` gains `Conveyed`. Entry/exit API: `enter_conveyed(carrier: Node2D)` / `exit_conveyed()`. `enter_conveyed` sets `owner_pawn.path_position_override = carrier` (the existing mechanism) *and* the state, replacing the current pattern where the override is set while the component sits suspended inside a `path_enter` await. While `Conveyed`: `_process` does nothing (carrier owns position), `is_traveling()` is true, and the pawn renders wherever the carrier puts it.
- **Turbolift conversion:** the cab's PathBehavior currently awaits across the whole ride. Restructure so the await ends at boarding: behavior calls `enter_conveyed(cab)`, returns; `TurboliftCab` drives the pawn while moving and calls `exit_conveyed()` + hands the pawn its continuation (the movement component resumes its remaining `path` from the arrival floor — `next_path_index` already points past the turbolift vertices). The cosmetic legs (walk to queue spot, walk into cab) keep `walk_straight_to` awaits as today.
- **Interrupt semantics defined:** cancelling a job while `Conveyed` no longer risks a dangling suspended coroutine. Rule: the *ride completes to the next floor stop*, then the movement fails/retargets (`RideRequest` gains a `cancelled` flag the cab checks at each stop; it never dumps a pawn between floors). `interrupt_with_job` on a conveyed pawn therefore takes effect at the next stop — document this on `interrupt_with_job`.
- **Serialization contract (consumed by WI-21):** a `Conveyed` pawn saves as "at the carrier's current floor/module" — the existing WI-15 cab-save degradation formalized: on save, record the ride's `to_floor` module ref; on load the pawn stands at its *from* floor (or `to_floor` if the cab had arrived) and re-runs its job's movement. No mid-shaft positions saved.
- **Animation timescale:** door open/close (behavior_sliding_door, linked doors) and any other gameplay-blocking animation must play at `Global.time_manager.speed`. Mechanic: wherever a behavior plays an `AnimationPlayer`/tween and awaits it, set `speed_scale = Global.time_manager.speed` at play time and reconnect on `speed_changed` for long animations; waits inside behaviors use `await Global.time_manager.sim_seconds(x)` (most already should — audit). Pawn walk `AnimatedSprite2D` gets `speed_scale` synced too (walking pawns at 4× currently glide). Pure-UI animation stays real-time per the TimeManager invariant.
- **Pause behavior:** while paused, conveyed pawns don't move (cab already sim-driven); door animations freeze (speed_scale 0 via a paused check or sim-driven tween) — verify no animation finishes "for free" during pause.

## Files to touch
- `pawns/pawn_movement_component.gd` — `Conveyed` state, enter/exit API, `_process` gate, `is_traveling`
- `pawns/pawn_base.gd` — `interrupt_with_job` doc/behavior for conveyed pawns
- `modules/transport/turbolift_cab.gd`, `module_turbolift.gd`, `turbolift_shaft.gd`, `ride_request.gd` — ride restructure, cancelled flag, continuation handoff
- `scripts/pathing/behavior_sliding_door.gd`, `behavior_linked_doors.gd`, `path_behavior.gd` — animation speed sync, sim_seconds audit
- `scripts/pathing/path_behavior_context.gd` — carries whatever the continuation handoff needs
- `modules/transport/module_airlock.gd` — same audit (airlock cycle is a timed gameplay wait)
- WI-21 pre-work: note the `to_floor` module-ref rule where cab state lives

## Implementation order
1. `Conveyed` state + API, converting `path_position_override` users mechanically (no behavior change yet).
2. Turbolift ride restructure: board → `enter_conveyed` → cab drives → `exit_conveyed` + path continuation. This is the delicate step; keep the old await path behind a temporary flag until parity is verified.
3. Cancel/interrupt semantics (`RideRequest.cancelled`, next-stop drop-off).
4. Animation timescale sync (doors, airlocks, pawn sprites).
5. Remove the legacy await ride path.

## Edge cases
- Pawn's job cancelled mid-ride *and* the destination module deconstructed before arrival: cab stops at nearest surviving floor (shaft group membership already updates), `exit_conveyed` at that floor, movement fails, pawn re-evaluates. No pawn may ever be left with a stale `path_position_override`.
- Cab removed (turbolift deconstructed) while carrying: eject pawns at the shaft's nearest connected module before the cab frees — assert none conveyed at free time.
- Two pawns conveyed in one cab, one cancels: only that pawn's request flags; the other rides on.
- Speed changed mid-door-animation: `speed_changed` re-sync means no door finishes at the old rate.
- Save requested mid-ride (WI-21 will exercise): the serialization contract above must already hold — write the save-side note now even though jobs aren't saved yet.
- `movement_ended` listeners (jobs) must fire exactly once whether the movement ends normally, via next-stop cancel, or via ejection.

## Verification
1. Ride a pawn across 5+ floors at 1× and 4×: boarding shuffle, ride, exit all correct; total trip time scales with speed *including* door time (time the door segment before/after).
2. `interrupt_with_job` on a mid-ride pawn (use `Global.cheats`/debug): pawn exits at the next stop and starts the new job; no errors, no frozen pawn.
3. Deconstruct the destination floor mid-ride → pawn exits at a surviving floor and re-paths.
4. Deconstruct the whole turbolift with a riding pawn → pawn ejected safely, no orphaned override, `logs_read` clean.
5. Pause mid-ride and mid-door: everything freezes, resumes exactly.
6. Regression: mining EVA trips, airlock transit, and hauling all unaffected; pathfinding perf unchanged.
