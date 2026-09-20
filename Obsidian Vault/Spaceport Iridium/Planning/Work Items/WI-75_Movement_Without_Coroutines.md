# WI-75 — Movement Without Coroutines

> **Status: DRAFT (2026-09-19), not started. Depends on [[WI-69_Integration_Test_Fixture]]** (which is what makes it affordable) **and follows [[WI-71_Reference_Hygiene]]**, whose §5 guards keep F28 fixed in the meantime. Split out of WI-71 §6 on the author's question, 2026-09-19: doors alone cannot finish the job. This is the largest item in Phase 4.5 and the one with the most regression risk, because it rewrites the code that moves every pawn. §0's three decisions are the author's to settle; the recommended default is marked on each.

## Goal

WI-20 established the rule and applied it to one case: *anything that owns a pawn's position is an explicit, serializable state, never a suspended `await`*. Rides became `CONVEYED`, and the doc said awaits remain "only for cosmetic waits (door animations)". They are not only cosmetic and they are not only doors. **37 awaits across nine files** still sit in the movement pipeline, and they form one connected chain with a single entry point:

| File | Awaits | What suspends |
|---|---|---|
| `pawns/pawn_movement_component.gd` | 9 | `move` → `reached_next_node` → `reached_next_subpath` → `move`, plus the three module hooks |
| `modules/templates/module_base.gd` | 3 | `path_enter` / `path_exit` / `traverse` forwarding to behaviours |
| `scripts/pathing/behavior_sliding_door.gd`, `behavior_linked_doors.gd` | 10 | door animations, the open hold, and the auto-close lambdas |
| `modules/transport/module_turbolift.gd` | 5 | the queue walk, the ride request, its own door animations |
| `modules/transport/turbolift_shaft.gd` | 2 | `assign_waiting_slot`, then `request.finished` (boarding) |
| `modules/transport/turbolift_cab.gd` | 3 | door close, boarding, the walk into the cab |
| `modules/transport/module_teleporter.gd` | 2 | the lightning animation |
| `pawns/pawn_base.gd` | 1 | `walk_straight_to`'s per-frame loop |

Three things follow from that being one chain rather than several:
- **A door-only fix buys almost nothing.** `PawnMovementComponent` awaits `path_exit`; the turbolift *overrides* `path_exit` and awaits through boarding. So `_busy_in_hook` stays load-bearing, `is_traveling()` stays a lie whenever a coroutine is stranded, and `PathBehaviorContext.cancelled` stays dead but present. That is why WI-71 §6 was pulled out.
- **F28's class stays open.** Guards stop a resumed coroutine from touching a freed node; they do not stop the coroutine being abandoned mid-crossing, which is what strands the pawn's own progress.
- **These are the last places the game can't be inspected or stepped.** A state machine can be asserted mid-flight by an integration test; a suspended coroutine cannot. Every other long-running thing in the game (rides, jobs, construction, heat) is already state.

After this item, `is_traveling()` is a pure function of `state`, nothing in the movement pipeline awaits, and a module or cab freed under a pawn can only ever leave that pawn in a state the next frame resolves.

## 0 — Decisions for the author (not yet settled)

1. **Do all of it in one item, rather than door-then-turbolift.** *Recommended.* The hooks have exactly one caller, so the API changes once and every implementation moves with it. Two passes would mean two hook signatures, and the intermediate state is the half-measure §0 of WI-71 just rejected. *Alternative:* doors and the teleporter first, turbolift second, accepting one release with two shapes.
2. **The hooks return a verdict, they don't take a callback.** *Recommended.* `path_enter` / `path_exit` / `traverse` return a small `PathHookResult` (`CONTINUE`, `WAIT(seconds)`, `TAKEN_OVER`, `FAIL`), and the movement component acts on it. It reads like the job runner's `Status`, which is the same problem solved in the same codebase. *Alternative:* the component asks each module for a duration before crossing (`door_wait_seconds()`), which keeps hooks `void` but splits the decision across two calls.
3. **Rides stay unsaved.** *Recommended.* Boarding becomes state, so a pawn mid-board *could* be saved, but `RideRequest`'s contract ("a Conveyed pawn saves as standing at the cab's current floor") is deliberate and works. Note in the doc that it is now possible; don't do it here. *Alternative:* save the ride, which pulls the cab, the queue anchors and the shaft into the save format.

## Scope

**In:** the hook verdict (§1), the movement component's own chain (§2), doors and their auto-close (§3), the teleporter (§4), turbolift queueing, boarding and the cab (§5), `walk_straight_to` (§6), the deletions (§7).

**Out:**
- saving rides (§0.3);
- the turbolift's *scheduling* (which cab serves which request, `_best_cab_for`) - untouched, it is not a coroutine;
- anything a manager awaits outside movement (`sim_seconds` before a shuttle departs, the dialogue balloon). Those own nothing and block nobody.

## Design

### 1 — The hook verdict

`scripts/pathing/path_hook_result.gd`: a tiny RefCounted (or an int plus a float, if that measures better) carrying `CONTINUE`, `WAIT` with sim-seconds, `TAKEN_OVER`, `FAIL`.

`ModuleBase.path_enter` / `path_exit` / `traverse` stop being `void` coroutines and return one. The base implementation forwards to the `PathBehavior`, which returns the same type. `cancel_signal` and `PathBehaviorContext.cancelled` are deleted: nothing has ever read them, and a state machine cancels by changing state.

### 2 — The movement component becomes a state machine

Today `move()` awaits `reached_next_node()`, which awaits the hooks and `reached_next_subpath()`, which awaits `move()` again. The recursion exists *only* because the hooks can await. With §1, each becomes a step the component runs inside its own `_process`:

- `State.Moving` advances along the path exactly as now;
- reaching a node or a sub-path point runs the hook, and the verdict decides: continue this frame, enter `State.DoorWait` with a sim-time countdown, hand off (`TAKEN_OVER`, which the carrier resolves - today's `CONVEYED`, and boarding, §5), or fail;
- `State.DoorWait` ticks its timer with `Global.time_manager.scale(delta)` and returns to `Moving` at zero.

**The four "snap before the await" comments in `move()` and `reached_next_node()` are load-bearing** (WI-16): the pawn is placed exactly on the point before the hook runs, because a post-await reset to `global_position` would otherwise strand it a frame short of its anchor. In a state machine the same rule reads as "snap, then change state" - keep each comment with the line it explains.

### 3 — Doors

`Behavior_SlidingDoor` and `Behavior_LinkedDoors` start their animation and return `WAIT(open_seconds)`. Their **auto-close** stops being an `animation_finished` lambda that awaits `sim_seconds`: the close countdown becomes a field on the behaviour's per-module state (`LinkedDoorsState` and a new sliding equivalent), ticked by the owning `PathComponent`. It then dies with the module instead of resuming on a freed sprite.

Door *animation* timing is unchanged, and this is the part a player would notice: same open, same hold, same close, at 1× and at 4×.

### 4 — The teleporter

`ModuleTeleporter.traverse` awaits its lightning animation twice. It returns `WAIT` for the animation's sim-length and starts it, exactly like a door. The module is buildable data (`data/modules/teleporter_mdata.tres`), so it is in scope even though the feature is half-finished (D5).

### 5 — The turbolift: queue, board, ride

The ride is already a state (`CONVEYED`); what is still a coroutine is everything *before* it. `RideRequest` already has an explicit lifecycle and a boarding-only `finished` signal, so this is mostly promoting its comments into a field:

- `RideRequest.phase`: `REQUESTED → QUEUEING → WAITING → BOARDING → ONBOARD → DONE / CANCELLED`.
- `ModuleTurbolift.path_exit` returns `TAKEN_OVER` and calls the shaft, instead of awaiting `request_ride`. The shaft assigns a queue anchor and sets the pawn walking to it (§6); no await.
- `TurboliftCab._process` gains the states its `await`s currently stand in for: `DOORS_OPENING` (timer), `UNLOADING`, `BOARDING` (one pawn at a time, each a straight-line walk that the cab watches for completion), `DOORS_CLOSING`, then today's `MOVING` / `IDLE`. The cab already has a `CabState` enum; this extends it.
- Cancellation keeps its current meanings, and they get easier to state: a cancelled request in `QUEUEING` or `WAITING` releases its anchor and fails the movement; in `BOARDING` or `ONBOARD` the pawn rides to the next stop, as today.

A floor disabled mid-queue, a cab destroyed mid-boarding and a pawn retargeted mid-ride all already have handling (`recheck_requests`, `destroy`, `_cancel_conveyor_ride`); each becomes a phase change rather than a signal a coroutine is waiting on.

### 6 — `walk_straight_to`

`PawnBase.walk_straight_to` is a coroutine that drives the pawn frame by frame, with `in_manual_walk` telling the suspended movement component not to stomp the animation. Its two callers are the queue walk and the cab boarding walk, both §5.

It becomes a movement state: `State.ManualWalk` with a destination, advanced in `_process`, reporting completion through the existing `movement_ended`-style path or a small `walk_finished` signal the cab and the shaft listen for. `in_manual_walk` is then redundant, because the state *is* the answer.

### 7 — What gets deleted

`_busy_in_hook`, `in_manual_walk`, `PathBehaviorContext.cancelled` (and the whole context, if nothing else uses it), the `cancel_signal` parameters on the three hooks, and `walk_straight_to`. `is_traveling()` becomes `state in [Moving, Paused, DoorWait, ManualWalk, Conveyed]`, which is what `PawnStatus` and `RobotPowerComponent` have always wanted to ask.

## Files to touch

| | Files |
|---|---|
| New | `scripts/pathing/path_hook_result.gd`, integration suite `tests/integration/test_movement_states.gd` |
| Core | `pawns/pawn_movement_component.gd`, `pawns/pawn_base.gd`, `modules/templates/module_base.gd`, `scripts/pathing/path_behavior.gd`, `path_behavior_context.gd` (probably deleted), `behavior_sliding_door.gd`, `behavior_linked_doors.gd`, `modules/components/path_component.gd` |
| Transport | `modules/transport/module_turbolift.gd`, `turbolift_shaft.gd`, `turbolift_cab.gd`, `ride_request.gd`, `module_teleporter.gd` |
| Readers | `scripts/utility/pawn_status.gd`, `pawns/robot_power_component.gd` (both only read `is_traveling()`) |
| Docs | `CLAUDE.md` (the *Pathfinding & movement* paragraph: awaits no longer "remain for cosmetic waits"), [[01_Technical_Specification]] §1.4 |

## Implementation order

Each step ends green, and the fixture's movement tests run after every one.

1. **§1 and §2 with today's behaviours returning `WAIT`/`CONTINUE` only** - doors still await internally, so nothing visible changes yet. This is the risky refactor; do it alone and prove pawns still arrive.
2. **§3 doors**, then **§4 teleporter**.
3. **§6 `ManualWalk`**, which the turbolift needs.
4. **§5 turbolift**, cab last.
5. **§7 deletions**, then the docs.

## Edge cases

- **A module freed mid-crossing** must leave the pawn in a state its next frame resolves: `module_removed` already repaths, and `DoorWait` on a dead module ends immediately.
- **A cab destroyed mid-boarding** drops the pawn in the corridor, as `destroy()` does now; with phases the half-boarded case is explicit rather than a coroutine that never resumes.
- **Pause.** Every new timer uses `scale(delta)`, so a door hold and a boarding walk freeze with the sim, as they do today.
- **4× speed** must not skip a door: the timer subtracts scaled delta and clamps, so a long frame ends the wait rather than overshooting into the next node.
- **Two pawns boarding one cab** is already serialised by the cab's own loop; `BOARDING` keeps that, one pawn at a time.
- **A save mid-crossing** is unchanged: the pawn saves where it stands, and movement re-runs pathfinding on load. `DoorWait` and `ManualWalk` are not saved, and a load simply repaths.
- **The teleporter's unfinished design** (D5) is not resolved here; it keeps whatever behaviour it has, minus the coroutine.

## Verification

1. **GUT integration (WI-69),** `test_movement_states.gd`: a two-floor station with a turbolift and an airlock.
   - a crew member crosses an airlock: arrives, and `is_traveling()` is false afterwards;
   - a module is destroyed while a pawn is inside its door wait: no script error, the pawn repaths, and nothing reports travelling forever (WI-71's F28 test, which must still pass);
   - a pawn rides between floors: queue, board, ride, drop off, and the job it was doing completes;
   - a floor is disabled mid-queue, and a cab is destroyed mid-boarding: the pawn ends up somewhere valid, walking;
   - a 24-hour soak with turbolift traffic: the fixture's invariants stay clean and no pawn is stuck.
2. **Screenshots and a short capture:** a crew member crossing an airlock and riding a lift, at 1× and 4×, before and after. Door timing and the boarding walk are the two things only a human eye will judge.
3. **Scratch copy on the real quicksave:** 12 sim-hours with lifts in use, zero script errors, and `dump_*` output showing no pawn in a wait state for longer than its timer.
4. **Grep:** zero `await` in the nine files above, except where a manager awaits `sim_seconds` for its own reasons.

## Related

- [[WI-20_Movement_and_Animation]]: `CONVEYED`, and the rule this finishes.
- [[WI-16_Micro_Anchors_and_Pawn_Positioning]]: the anchor snapping §2 must preserve, and the QUEUE anchors §5 keeps.
- [[WI-71_Reference_Hygiene]] §5: the guards that hold F28 until this lands.
- [[WI-69_Integration_Test_Fixture]]: without it, this item would have to be verified by hand.
