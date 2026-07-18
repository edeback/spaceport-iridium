# WI-27 — Logistics Automation: Logistics Bay & Conveyors

## Goal
Make moving goods module-to-module less crew-bound: a Logistics Bay produces hauler robots that take only hauling jobs (buy more with credits up to a max, upgrade speed/capacity), and a 1×1 Conveyor Module moves a chosen resource between two chosen neighboring storages on a rate-limited buffer, chainable through other conveyors.

## Design
- **Hauler robots.** New pawn scene `pawns/hauler_robot.tscn` + `HaulerRobotPawn` extending PawnBase, patterned on `MiningDronePawn`: overrides `start_job()` to (1) sweep inventory via `Job_StoreInventory` as usual, (2) drain the personal queue, (3) claim from the shared board with `Global.job_manager.find_job(self, [JobBase.Category.HAUL])` — HAUL only, no needs, no schedule (always on duty). Interior pawn: normal corridor/turbolift traversal (unlike EVA mining drones).
- **Logistics Bay module.** `modules/logistics/logistics_bay.tscn` + mdata + unlock (industrial tree; tier-gate per WI-26 re-bucket). `LogisticsBayComponent` (patterned on MiningComponent's drone ownership): `max_robots` (exported, upgradable), `robot_cost` credits, buy button in its UI; owns and respawns its robots (robot "home" = the bay). Robots die with the bay (bay deconstructed → robots power down and free, carried cargo dropped as a pile per the resource invariant). Local upgrades (`data/local_upgrades/`): robot speed, robot carrying capacity, +max robots — stats read via `get_effective_stat` and pushed to owned robots.
- **Conveyor module.** `modules/logistics/conveyor.tscn` (1×1, MODULE layer, cheap, no crew traversal role of its own beyond whatever corridor behavior the scene includes — decide in-scene; v1: not walkable, it's machinery). `ConveyorComponent`:
  - **Endpoints:** player configures `source` and `destination` from a dropdown of *adjacent* (4-neighbor, same-layer-or-stacked) modules' StorageComponents, plus the resource to move. Eligibility mirrors the storage flags: sources must allow exports, destinations must allow imports (the WI-12 config language) — ineligible storages simply don't appear.
  - **Transfer:** internal buffer (`buffer_size` units) + `rate_per_hour`. Each slow_tick: withdraw up to rate×interval from source into buffer (unreserved stock only), deposit buffer into destination if it accepts. Direct storage-to-storage — **no jobs, no reservations held across ticks** (withdraw-then-hold-in-buffer means the goods are physically in the conveyor; on deconstruct the buffer dumps as a pile).
  - **Chaining:** a conveyor's endpoint list includes adjacent conveyors (their buffer acts as a storage-like endpoint) — `ConveyorComponent` exposes a minimal deposit/withdraw shim so chains form without special cases.
  - Powered (`PowerConsumptionComponent`, small draw); unpowered = transfer stops, buffer holds.
- **Interaction with the job board:** conveyors move stock *before* the storage's deficit/surplus posting sees it, so they naturally reduce haul-job churn; no priority-band interaction (they never touch reserved stock and never post jobs). Robots, conversely, are pure board consumers. The two compose without coordination.
- **Save:** bay robot count (robots themselves are pawns — ensure robot pawns save/restore with type + home-bay ref, incl. WI-21 job state), conveyor config (endpoints as module refs + component paths, resource id, buffer contents).

## Files to touch
- **New:** `pawns/hauler_robot.gd/.tscn`, `modules/logistics/logistics_bay.tscn`, `conveyor.tscn`, `modules/components/logistics_bay_component.gd`, `conveyor_component.gd`, `data/modules/logistics/*.tres`, unlock .tres entries, `ui/windows/component_ui_panels/` panels for both components
- `scripts/managers/save_manager.gd` — robot pawn type in the pawn section (scene-by-type registry), conveyor/bay fields ride module save data
- `pawns/pawn_base.gd` — nothing expected; robots reuse everything (flag if not)
- WI-28 pre-work note: robots built here get energy/integrity there — keep robot-specific state in the robot class, not the bay
- Remember: `filesystem_manage(op="scan")` after new `class_name` files

## Implementation order
1. Hauler robot pawn + a debug-spawned instance hauling from the existing board (proves the HAUL-only claim path).
2. Logistics Bay module + component + buy/ownership/respawn + UI.
3. Local upgrades (speed/capacity/count).
4. Conveyor module + component: single hop source→dest.
5. Conveyor chaining + buffer dump on deconstruct.
6. Save/load for both.

## Edge cases
- Robot claims a haul into a module robots can't reach (pathing gap): `can_do_job` already fails on unreachable — verify robots don't loop-claim/fail the same job (the 1s retry throttle in `start_job` covers it, but watch a blocked station).
- All crew asleep, robots handle a construction import at +99: fine — robots serve the same board, bands preserved.
- Conveyor source and destination both set to the same storage, or two conveyors forming a loop: allowed by the UI? No — reject same-endpoint config; loops through chains are the player's prerogative (goods just cycle, rate-limited, harmless).
- Conveyor pulling from a storage a pawn has a withdraw reservation on: unreserved-only withdrawal (same rule as WI-12 venting).
- Destination fills mid-transfer: buffer holds indefinitely; UI shows "destination full".
- Endpoint module deconstructed: config half-clears, conveyor idles with a status line; buffer dumps only when the *conveyor* is removed.
- Bay at max robots with one destroyed (WI-28 later): count frees, buy button re-enables.
- Robot carrying cargo when bay deconstructs: cargo → pile at the robot's position (invariant), then robot frees.

## Verification
1. Bay built + 2 robots bought: robots take hauling jobs only (watch the board — WORK/BUILD jobs stay for crew), station storage rebalancing visibly accelerates.
2. Speed/capacity upgrades measurably change trip time and load size.
3. Conveyor from refinery output → storeroom: steady flow at the configured rate, no haul jobs posted for that stock; chain two conveyors across a gap module and goods traverse both hops.
4. Unpower the conveyor mid-buffer: flow stops, buffer holds, resumes on power.
5. Deconstruct: bay → robots free + cargo piles; conveyor → buffer pile. No resource totals lost (count before/after).
6. Save/load: robots resume hauls (WI-21), conveyor config/buffer intact.
7. Regression: mining drones unaffected; construction imports still outrank everything; crew still haul when robots are saturated.
