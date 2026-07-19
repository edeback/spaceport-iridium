# WI-21 — Job & Asteroid Serialization

## Goal
A player can save and re-load without pawns losing their jobs. Requires serializing the parts of the world jobs point at that aren't saved yet — asteroids above all (a miner mid-trip needs its rock to still exist). (This means Mining Drones will also need saving!)

**Depth decision (user-confirmed):** *type + targets, restart stage.* Each pawn's `current_job` and `job_queue` save as job class + target references; on load the job re-claims its reservations through the normal claim path and restarts its current stage (re-walks to the target, re-does partial work). The shared board keeps re-deriving from storage deficits/construction state exactly as today — board jobs are NOT saved. Bit-exact resume (timers, movement progress) is explicitly out of scope.

## Design
- **Asteroids first.** `AsteroidManager` gets a save section: per asteroid — stable id (assign one at spawn if none exists), position, remaining ore contents with richness (`OreInstanceData` via the existing `stacks_to_dicts` helpers), and spawn-field state (whatever drives new asteroid generation: timers/counters). `SaveManager.module_ref`-style helper: `asteroid_ref(asteroid)` / `resolve_asteroid_ref()` by id. Mining drones' bay relationship already re-links via the bay's component; verify drones themselves are excluded or handled in `_get_pawns_save` (they currently sit in the "pawn" group).
- **Job save format.** `JobBase` gains `get_save_data() -> Dictionary` (base returns `{}` = "not saveable, drop on save") and each meaningful subclass overrides it to return `{"type": <StringName job id>, ...constructor params...}`: e.g. `Job_GetResource` → from-storage (module ref + component path), resource id, amount; `Job_MineAsteroid` → asteroid ref; `Job_ConstructModule` → module ref; `Job_Eat`/`Job_Sleep`/`Job_Recreate` → provider module ref; `Job_MoveToLocation` → target ref. A static registry in `SaveManager` (or a `JobSerializer` utility) maps type id → a `restore(data) -> JobBase` factory that rebuilds the job in its *initial* state pointed at resolved targets.
- **Reservations are never saved.** Storage was saved with reservations at zero-effect (stored counts are truth). On load, a restored job re-claims through `can_do_job`/`start_job` exactly like a fresh job; if the claim now fails (stock gone, storage full), the job cancels cleanly via the standard lifecycle and the pawn finds new work. This keeps the reservation-reconciliation invariant trivially intact.
- **Load flow.** `_load_pawns` restores each pawn, then rebuilds `current_job` + `job_queue` from the pawn's job section and hands them over as: restored current job → `queue_job(job, to_front=true)` (NOT direct assignment — let `start_job()` run its normal validity/claim gauntlet on the first tick). Jobs whose targets fail to resolve are silently dropped (the board will re-post the underlying need).
- **CONVEYED (WI-20) contract honored:** a pawn saved mid-ride was recorded at a floor; its restored job simply re-paths from there.
- **Not saved, by design:** the shared board (re-derives), followup-job chains not yet queued, `Job_Idle*`, `Job_StoreInventory` (re-created automatically from carried inventory — pawn inventory is already saved), in-flight `age`/priority bonuses.

## Files to touch
- `scripts/managers/asteroid_manager.gd` — save section, asteroid ids, refs
- `scripts/managers/save_manager.gd` — `asteroids` section ordering (world → asteroids → piles → pawns), job factory registry, pawn-section job data
- `scripts/jobs/job_base.gd` — `get_save_data` hook + type id convention
- `scripts/jobs/job_get_resource.gd`, `job_mine_asteroid.gd`, `job_construct_module.gd`, `job_collect_pile.gd`, `job_eat.gd`, `job_sleep.gd`, `job_recreate.gd`, `job_move_to_location.gd`, `job_leave_station.gd` — per-class save/restore (piles need a pile ref: piles are saved, give them ids or locate by position)
- `objects/asteroid_base.gd` — id field, contents accessors for save
- `pawns/mining_drone_pawn.gd` / mining component — verify drone save/re-link behavior
- Tests (WI-19): round-trip test per job class — save dict → restore → `is_valid()` against a stubbed world where practical

## Implementation order
1. Asteroid save section + ids; verify a mid-game save round-trips the asteroid field identically (contents, richness).
2. `JobBase.get_save_data` + factory registry + pawn-section plumbing, with `Job_MineAsteroid` as the pilot (it's the one that needs asteroids).
3. Convert the remaining job classes one at a time, quicksave/quickload after each.
4. Followup/queue handling and the drop-on-unresolvable rule.
5. WI-19 round-trip tests.

## Edge cases
- Save while pawn carries cargo for a cancelled-on-load job: inventory is saved with the pawn; `start_job()`'s existing `Job_StoreInventory` sweep re-homes it. Verify no double-reservation.
- Job target is a *blueprint* module (construction): module refs resolve by layer+cell regardless of build state — fine, but verify `Job_ConstructModule.restore` tolerates the module having completed between post and save (is_valid fails → clean cancel).
- Two pawns saved targeting the same storage stock: first restored claim wins, second cancels cleanly — order-dependent but harmless. Assert reservations reconcile after load (debug check).
- Asteroid fully mined between job save and load: impossible in a consistent save (same file), but `resolve_asteroid_ref` returning null must cancel cleanly anyway (defends against hand-edited/old saves).
- Pawn saved off-shift with queued needs jobs: queue restores in order; shift gate applies as normal on pick-up.

## Verification
1. Save mid-haul (pawn walking to pick up ore) → load → pawn resumes the same haul (re-walks, completes, deposits). Repeat for mid-mine (EVA on the asteroid), mid-construction, mid-eat/sleep.
2. Save with 3+ pawns on distinct jobs + one idle → load → each resumes its own job, idle pawn finds work normally, no job duplication on the board (`board_size()` sane).
3. Save mid-turbolift-ride → load → pawn at floor per WI-20 contract, job re-paths and completes.
4. Sabotage test: hand-edit a save to point a job at a missing asteroid/module → loads without errors, job dropped, pawn re-tasks.
5. GUT round-trip suite green; reservation reconciliation assert clean after every load above.
