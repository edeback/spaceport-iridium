# WI-44 — Job System Refactor (Actions / Toils)

> **Status: IN PROGRESS (started 2026-07-28).** Stage 1 of 7 complete.
>
> Scope decisions taken up front (see [[#Decisions taken]]): execution layer + a unified claim registry; toil-level save/resume *with* per-action progress; typed `Action_*` classes (no lambdas); `JobData` `.tres` per job type; auto-generated report text + a station-wide board inspector; **big-bang** conversion of all job types in one work item.
>
> **Progress** — baseline at start was 400 GUT tests; now **470 green**, plus a **31/31 in-game probe**.
> - **Stage 1 — runtime + registry + pure test suite: DONE.** `JobData`, `JobTarget`, `ActionBase`, `JobDriver`, `ClaimSpec`, `Job` (the runner), `ClaimRegistry`. +36 `test_job_runner`, +14 `test_claim_registry`.
> - **Stage 2 — `JobTarget` + persistence round-trip: DONE.** `Job.to_dict()/from_dict()/restore_into()`, the signature guard, per-action state, DURATION elapsed, claim re-acquisition on resume; `JobDataRegistry` scanning `data/jobs/`; `SaveManager.pawn_ref`/`resolve_pawn_ref`. +20 `test_job_persistence`.
> - **Stage 3 — action library: STARTED.** `Action_GotoTarget`, `Action_Wait`. The remaining ~18 actions are still to write.
> - **Stage 4 — first drivers in a real station: PARTIAL.** `JobDriver_Move` + `JobDriver_Wait` with `data/jobs/move_to_location.tres` and `wait.tres`. A temporary headless autoload probe ran **31/31** against a live station: the `.tres` loads, the driver instantiates, a real pawn walks a real path, the job ends successfully, claims are released, the movement signal is disconnected, and an encoded job restores to the *same* module. The `haul` driver is not done — it needs the storage-claimable work in stage 5.
>   - Probe stashed outside the repo (session scratchpad, `wi44_probe.gd`) rather than deleted, since stages 5–7 will want it. It registers as an autoload and calls `get_tree().quit()`, so it must never be left wired into `project.godot`.
>
> **Not yet started:** stage 5 (the remaining ~17 drivers + migrating the 5 slot-owning components, `StorageData`, and `PathComponent` to the claimable contract), stage 6 (delete the legacy path; convert `PawnBase`/`JobManager`/`SaveManager`; the `SAVE_VERSION 1→2` migration), stage 7 (UI).
>
> **Deviations from the design above, so far**
> - **`JobDriver` is stateless: every hook takes `job` as its first parameter** (`is_valid(job)`, `can_do(job, pawn)`, `make_actions(job)`, `next_index_after(job, i)`, `required_claims(job, i)`). The doc gave the driver a `var job` field and proposed breaking the resulting `Job → driver → job` cycle in `end()`. That defence doesn't hold: `JobManager` calls `is_valid()` on *unclaimed* board jobs, which builds a driver for jobs that may never run and therefore may never call `end()`. Measured as a real leak (GUT's leaked-instance count rose 121 → 196 with the field, back to 141 without it). The same no-back-reference rule that `ActionBase` already had now covers drivers too, which also makes the two consistent.
> - **`ClaimSpec.Kind`, not `ClaimRegistry.Kind`.** Keeps the dependency one-way (the registry knows about specs; specs know nothing about the registry) and lets `ClaimSpec` be used in pure tests with no registry present.
> - **`Job.install_driver()` added** as an explicit seam. The load path needs a driver before the action list exists, and the runner tests inject a stub rather than routing through a `.tres` on disk.
> - **The runner ticks the action *before* checking completion.** Not specified either way in the design; doing it in this order means progress accumulated on a frame counts toward finishing on that same frame instead of the next one. Pinned by a test.
> - **`subtask_changed` fires only when the runner settles on a non-instant action.** Chained `INSTANT` steps complete within one frame, and emitting per step would strobe the UI through text nobody can read. Pinned by a test.
> - **DURATION progress needed its own save key (`elapsed`).** The design says per-action progress goes in `ActionBase.save_state()`, but a `DURATION` action's remaining time lives on the *runner*, not the action — so without an explicit carry, a job saved four seconds into a six-second wait silently restarted the wait. `Job._resume_elapsed` applies it on the first `_enter()` of a resume. Pinned by a test.
> - **`Job.restore_into(job, encoded)` split out of `restore()`.** A driver can legitimately be installed before the decode, and `restore()` must not clobber it.
> - **`JobTarget.Slot` (A/B/C) is a separate enum from `JobTarget.Kind`.** Actions take a *slot*, not a target, so an action can be constructed before the thing it will operate on is known — which is what lets `Action_FindBestTarget` write into a slot that a later action then reads.
> - **`Action_Wait` replaces `Job_Wait`'s `await`.** The old job did `await Global.time_manager.sim_seconds(duration)`, which could outlive an early cancel and leaned on the `_ended` latch to make the resulting second cancel harmless. A `DURATION` action can't outlive its job, and it gains resumable elapsed time for free.
> - **`ClaimRegistry` is a `Managers/` node in `main.tscn`, placed immediately after `JobManager`.** Nothing in its `_ready()` depends on another manager; it only has to exist before any job claims.
> - **Two probe findings worth keeping:** `PawnMovementComponent` does not begin moving on the frame `move_to()` is called (it stages a pending target and starts it in its own `_process`), so anything asserting "is travelling" must poll. And `Action_GotoTarget`'s "already there, skip the walk" early-out needs an explicit null-module guard — an exterior target has no module and a pawn outside has a null `current_module`, so the two nulls compare equal and every EVA trip would be skipped.

## Goal

Replace the hand-rolled per-job state machine with a composable action (toil) pipeline, so that:

1. **New jobs are cheap.** A new job type is one `.tres` + one small driver class that returns a list of actions. It gets save/restore, UI text, claim release, and target-loss handling for free.
2. **Jobs resume where they stopped.** A pawn who has already walked to the workstation resumes *working*, not walking. A pawn carrying cargo resumes *depositing*, not hauling it back to a bin and starting the trip again.
3. **Reservations cannot leak.** One release path, structurally, instead of a discipline repeated in 14 `_on_end()` bodies.
4. **The UI has something to show.** Report text composed from the job's targets rather than hardcoded per class, plus a board inspector for the player and for debugging stuck pawns.

Explicit non-goal: this is **not primarily a line-count reduction**. `scripts/jobs/` is 3,278 lines today; the post-refactor total (drivers + action library + runtime) lands in the same order of magnitude. The win is that the *duplicated* lines become *shared* lines, and the marginal cost of job #24 drops from ~180 lines to ~40.

## What's wrong today

Measured, not asserted:

| Duplication | Count | Where |
|---|---|---|
| `movement_ended.connect(..., CONNECT_ONE_SHOT)` + `_ended` guard + `not prev_success` branch | **22 sites across 18 job files** | every job that moves |
| `SignalBus.module_removed.connect` / matching disconnect in `_on_end()` | **11 job files** | every job with a module target |
| Bespoke `enum XState { Starting, Moving…, Finished, Failed }` + setter emitting `subtask_changed` + `is_finished()`/`is_failed()` pair | **~17 job files** | every non-trivial job |
| "Scan a group → filter free/reachable/accepts → score by distance → return best" | **7 near-copies** | `job_sleep._find_pod`, `job_recharge._find_charger`, `job_get_repaired._find_bay`, `job_get_treatment._find_bay`, `job_eat.find_best_sustenance`, `job_recreate._gather_candidates`, `job_shop._gather_candidates` |
| `claim_slot`/`release_slot` pairs with release in `_on_end()` | 6 job files against 5 component classes (`SleepComponent`, `RecreationProviderComponent` → `ShopComponent`, `RechargeComponent`, `RobotRepairComponent`, `MedicalComponent`) | |
| `claim_anchor`/`release_anchor` pairs | 4 job files | sleep, get_treatment, work_processor, doctor, repair |
| Hand-written `get_save_data()` + `static restore()` | 17 registered types in `JobSerializer._ensure_registry()` | |

And three specific consequences:

**Reload replays work.** Every restored job restarts at its first state. `Job_WorkProcessor.restore()` re-walks to a workstation the pawn is already standing at. `Job_MineAsteroid.get_save_data()` gives up entirely (`state > MineAsteroid` → `{}`) rather than express "on the way home, full". `Job_GetResource` is the worst case: the pawn's cargo is swept by `Job_StoreInventory` into *some* bin first (`pawn_base.gd:211`), and then the restored haul walks back to the source and does the whole trip again. That is the "negative player experience" this WI exists to fix.

**Reservation discipline is manual.** The `_ended` latch in `JobBase` (`job_base.gd:41`) and the eight-line comment above it exist purely to make the per-job release blocks safe. It works, but every new job has to know about it — and the one place it *wasn't* worth the trouble, `Job_CollectPile`, simply skips deposit reservation and documents the omission (`job_collect_pile.gd:7-14`).

**Reservations are hard-typed to one job.** `StorageData.add_withdraw_job(job: Job_GetResource)` reads `job.amount` off the job object (`storage_data.gd:91`). That signature is exactly why `Job_CollectPile` can't reserve.

**UI is a dead end.** `get_job_description()` returns a literal; `get_subtask_description()` is a `match` on a private enum. `pawn_job_tab.gd` shows two labels. There is no way to ask "why is this job not being taken".

## Decisions taken

| Question | Decision |
|---|---|
| Scope | Execution layer **+ unified claim/reservation registry**. Job *generation* (components post to the board) and pawn *selection* (`find_job`, needs queue, shift filter) are untouched. |
| Save fidelity | Resume at the current action, **restoring that action's own progress**. Not full path persistence. |
| Action authoring | **Typed `Action_*` classes only.** No `Callable` hooks. |
| Job definitions | **`JobData` `.tres` per job type**; the action sequence stays in code. |
| Claim registry persistence | **Not saved.** Re-claimed on resume (see [[#Resume and claims]] — this is the one place the decision has teeth). |
| UI | Auto-generated report text **+ station-wide board inspector**. Per-pawn action-list panel not in scope. |
| Migration | **Big-bang**: all job types convert in this WI, legacy path deleted in the same diff. |

---

## Architecture

Four objects, mirroring RimWorld's `JobDef` / `Job` / `JobDriver` / `Toil` split, with the names adapted to this codebase's conventions.

```
JobData (.tres)      one per job type: id, category, report template, skill, xp, driver script
   │
   ▼
Job (Resource)       runtime instance: targets A/B/C, count, resource, priority, age,
   │                 workspace, action index, per-action state.  ← the thing that is saved
   ▼
JobDriver (RefCounted)  per-type behaviour: make_actions(), is_valid(), can_do(pawn)
   │
   ▼
Array[ActionBase]    the step sequence.  ← the thing that is shared between job types
```

### 1. `JobData` — the definition resource

`data/jobs/*.tres`, discovered by `ResourceScanner` exactly like `ModuleData` and `UnlockData`. **This replaces `JobSerializer._ensure_registry()`** — the hand-maintained `StringName → Callable` table goes away, and a new job type becomes discoverable by existing in the directory.

```gdscript
class_name JobData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
## "{a}"/"{b}"/"{c}"/"{resource}"/"{count}" are substituted from the Job's targets.
@export_multiline var report_template: String = ""
@export var category: JobBase.Category = JobBase.Category.MISC
@export var skill: StringName = &""
@export var xp_reward: float = 0.0
@export var player_cancelable: bool = true
## false = a system re-derives this job on load; the pawn's copy is dropped.
## (Today's "deliberately NOT registered" list in job_serializer.gd:9-19.)
@export var saveable: bool = true
## GDScript file whose class extends JobDriver. Held as a Script, not a
## class_name string, so a rename is caught by the editor rather than at runtime.
@export var driver: Script = null
```

Balance-ish numbers (`xp_reward`, default priority band) move out of code into data, satisfying the CLAUDE.md invariant. `JobBase.Category` stays exactly as-is.

### 2. `Job` — the runtime instance

```gdscript
class_name Job
extends Resource

var data: JobData
var pawn: PawnBase = null

# --- targets -------------------------------------------------------------
var target_a: JobTarget = null
var target_b: JobTarget = null
var target_c: JobTarget = null
var count: int = 0
var resource: ResourceData = null

# --- board state (unchanged semantics from JobBase) -----------------------
var priority: int = 0
var age: float = 0.0
var workspace: WorkspaceComponent = null

# --- runner state --------------------------------------------------------
var _driver: JobDriver = null
var _actions: Array[ActionBase] = []
var _index: int = -1
var _outcome: Outcome = Outcome.ONGOING
var _ended: bool = false

enum Outcome { ONGOING, SUCCEEDED, FAILED, INTERRUPTED }
```

`Outcome` replaces today's `cancel(as_failed: bool)` bool. Three values, not RimWorld's nine — `INTERRUPTED` is what `PawnBase.interrupt_with_job()` already means by `cancel(false)`, and distinguishing it from `FAILED` is what lets an action decide whether to keep its progress or discard it. `ErroredPather`, `QueuedNoLongerValid`, etc. have no consumer here.

**Three slots is enough.** Checked against all 23 current jobs: haul (A=source storage, B=sink storage, `resource`, `count`), mine (A=asteroid, B=mining component), construct (A=module), work processor (A=processor), sleep/recharge/medical/shop/recreation/eat (A=the provider component), collect pile (A=pile, B=sink storage, `resource`), leave station (A=recruitment component), move (A=module). Nothing needs D. Do **not** pre-build a fourth slot; add it when a real job needs it.

### 3. `JobTarget` — the polymorphic reference

This is what makes generic serialization possible. Every job's save data today is hand-written because each job knows *which kind* of thing its targets are. `JobTarget` moves that knowledge into one place.

```gdscript
class_name JobTarget

enum Kind { NONE, MODULE, COMPONENT, PAWN, ASTEROID, PILE, CELL }

var kind: Kind = Kind.NONE
var _obj: Object = null       ## Node targets; null-checked via is_instance_valid
var _cell: Vector2i = Vector2i.ZERO

func module() -> ModuleBase
func component() -> ComponentBase
func node() -> Node2D          ## whatever a movement action should path to
func is_alive() -> bool        ## instance-valid AND still in the world
func describe() -> String      ## "Hydroponics Bay", "Iron Ore Pile", "Ada Voss"

func to_dict() -> Dictionary   ## delegates to SaveManager.module_ref / component_ref /
static func from_dict(d) -> JobTarget   ## asteroid_ref / pile_ref (all already exist)
```

The four `SaveManager` ref helpers already exist and are already the right shape (`save_manager.gd:157-226`). This WI adds a fifth, `pawn_ref` / `resolve_pawn_ref` keyed on the existing stable `pawn_id` (`pawn_base.gd:127`), and puts all five behind `JobTarget`.

Consequence: **no job type writes serialization code.** The whole of `Job.to_dict()` is generic (see [[#Persistence]]).

### 4. `JobDriver` — per-type behaviour

```gdscript
class_name JobDriver
extends RefCounted

var job: Job = null       ## set by Job; a Node-free RefCounted, so no Resource cycle

## The step sequence. Called once at start, and again on load (RimWorld's
## SetupToils in PostLoadInit). Must be deterministic: the saved action index
## indexes into whatever this returns.
func make_actions() -> Array[ActionBase]:
	return []

## Board-level "is this job still worth existing" (today's JobBase.is_valid).
func is_valid() -> bool: return true

## Per-pawn claimability (today's JobBase.can_do_job).
func can_do(_pawn: PawnBase) -> bool: return true

## Board inspector only, never per-frame: why can_do() said no.
func explain_block(_pawn: PawnBase) -> String: return ""

## Claims the job must be holding for the CURRENT action to be meaningful.
## Re-acquired on load, since claims aren't saved. See "Resume and claims".
func required_claims(_action_index: int) -> Array[ClaimSpec]: return []

## Optional: non-linear control flow. Default is "the next one".
func next_index_after(finished: int) -> int: return finished + 1
```

`make_actions()` **must be deterministic** — that's the contract that lets a saved integer index mean the same thing after a reload. Worth an assertion in debug: rebuild the list on load and compare its length + action class names against a short signature stored in the save.

`next_index_after()` is the typed replacement for RimWorld's `JumpToToil`. A branch is an integer, which is serializable and greppable; lambdas that mutate a driver's index are neither. Loops (mine → not full? → mine again) become `return MINE_INDEX`.

---

## The action runner

### `ActionBase`

```gdscript
class_name ActionBase
extends Resource

enum Status { ONGOING, DONE, FAILED }

enum CompleteMode {
	INSTANT,     ## on_start() is the whole action
	MOVEMENT,    ## finishes when the pawn's movement ends
	DURATION,    ## finishes after `duration` sim-seconds
	CONDITION,   ## finishes when check() says DONE
}

@export var complete_mode: CompleteMode = CompleteMode.INSTANT
@export var duration: float = 0.0
@export var label: StringName = &""   ## jump target name, for next_index_after()

func on_start(job: Job) -> Status
func on_resume(job: Job) -> Status    ## after a load — NOT on_start()
func tick(job: Job, delta: float) -> Status
func check(job: Job) -> Status
func on_finish(job: Job, outcome: Job.Outcome) -> void
func report(job: Job) -> String

func save_state() -> Dictionary: return {}
func load_state(_d: Dictionary) -> void: pass
```

**`job` is passed in, never stored.** GDScript `Resource` is `RefCounted` with no cycle collector: `Job → Array[ActionBase] → job` would leak every job object for the session. This is a hard rule, not a style preference, and it should be stated at the top of `action_base.gd`.

**`on_resume()` is separate from `on_start()`** and is the whole reason toil-level resume works without replaying side effects. `Action_TakeFromStorage.on_start()` withdraws stock; if load called `on_start()` the pawn would withdraw twice. `on_resume()` for that action is "I already have it — verify and continue". For `Action_GotoTarget`, `on_resume()` re-issues `move_to` from wherever the pawn is standing (cheap, and correct — the user declined full path persistence). Default `on_resume()` = `on_start()`, overridden only where it matters.

### Tick loop

`Job.process(delta)`, called from `PawnBase._process` exactly where `current_job.process_job(sim_delta)` is called today:

```
1. if driver.is_valid() == false → end(FAILED)                    [global fail condition]
2. if any target with fail_on_loss is not alive → end(FAILED)     [replaces 11 _module_removed handlers]
3. status = current action's completion check, by complete_mode:
     INSTANT   → DONE (already returned from on_start)
     MOVEMENT  → the movement flag set by the runner's one-shot handler
     DURATION  → elapsed >= duration
     CONDITION → action.check(job)
4. if ONGOING → action.tick(job, delta); re-read status
5. if FAILED  → end(FAILED)
6. if DONE    → action.on_finish(job, SUCCEEDED)
                index = driver.next_index_after(index)
                if index >= actions.size() → end(SUCCEEDED)
                else advance and on_start() the new one (loop, so INSTANT
                     actions chain within one frame — bounded by a guard count)
```

`Job.end(outcome)` is the single termination path and does, in order: `current_action.on_finish(outcome)` → `ClaimRegistry.release_all(self)` → `_ended = true` → `job_end.emit()`. The `_ended` latch and its idempotency contract carry over from `JobBase` verbatim; what changes is that **subclasses no longer participate in it**, so the eight-line warning comment at `job_base.gd:34-41` becomes a runner-internal concern instead of a rule every job author must remember.

### Movement

One place in the whole system connects `movement_ended`: the runner, when it starts a `CompleteMode.MOVEMENT` action. It connects `CONNECT_ONE_SHOT`, records success/failure into a runner field, and disconnects on job end. The `_ended` guard lives there once.

`PawnMovementComponent` needs no changes — the existing `movement_ended(as_success)` signal, `path_invalidated`, and the `CONVEYED` state all work as-is. (The `CONVEYED`/`exit_conveyed()` design, which already re-runs pathfinding from the drop-off floor rather than resuming a path index, is the same philosophy this WI applies to jobs; nothing there needs to move.)

---

## Action library

Derived from what the 23 existing jobs actually do. Roughly 20 classes; the first six cover most of every job.

### Movement & positioning
| Action | Replaces |
|---|---|
| `Action_GotoTarget` — slot, speed, `in_space`, optional anchor claim type | the 22 `movement_ended.connect` sites |
| `Action_GotoAnchor` — claim an anchor of a type on the current target, then walk to it | sleep/treatment BUNK, processor/doctor/repair WORKSTATION |
| `Action_StayAt` — glue the pawn to a target's position each tick | `job_mine_asteroid.mine_asteroid`'s `pawn.position = asteroid.position` |
| `Action_ShiftSpotPeriodically` — reposition within a module every N seconds | `job_construct_module.shift_spot_elapsed` |

### Target acquisition
| Action | Replaces |
|---|---|
| `Action_FindBestTarget(finder: TargetFinder, into: slot)` | the **7 near-copy finders** |

`TargetFinder` is a small strategy `Resource` in the same spirit as the existing `PathBehavior` objects: `group: StringName`, `accepts(pawn, candidate) -> bool`, `score(pawn, candidate) -> float`, plus a shared `distance_tolerance_band` (the `desirability_distance_tolerance` idea from `job_sleep.gd:18`, which several other finders would want and don't have). Concrete finders: `Finder_FreeSlotComponent`, `Finder_StorageSource`, `Finder_StorageSink` (both thin wrappers over the existing `StorageQuery` — **do not reimplement it**, WI-40 just finished consolidating those rules), `Finder_Asteroid`, `Finder_Sustenance`.

### Storage & inventory
| Action | Notes |
|---|---|
| `Action_ReserveStorage(slot, direction, amount)` | goes through `ClaimRegistry`, not `add_withdraw_job` |
| `Action_TakeFromStorage(slot)` | `on_resume` = "already carrying, skip" |
| `Action_DepositToStorage(slot)` | leftover stays on the pawn — the existing invariant |
| `Action_TakeFromPile(slot)` | folds in the reservation-shrinking logic at `job_collect_pile.gd:149-152` |
| `Action_DumpInventory` | `Job_StoreInventory`'s deposit loop |

### Work
| Action | Notes |
|---|---|
| `Action_Work(progress_target, rate_skill)` | the generic "push a progress bar at `pawn.work_rate(skill)`" used by construct, deconstruct, repair, work_processor, doctor. `save_state()` returns nothing when the progress lives on the component (construction `work_seconds_done`, processor batch) — those already persist. |
| `Action_Mine` | asteroid extraction incl. richness sampling and trickled xp; `save_state()` = `{resources_mined_count, time_mining}` |
| `Action_RestoreNeed(need, rate_source)` | sleep, eat, recreate, shop, recharge, get_repaired, get_treatment — **7 jobs collapse to one action** with different targets and need ids |

### Flow & effects
| Action | Notes |
|---|---|
| `Action_ClaimSlot(slot)` / released automatically | the 6 `claim_slot` sites |
| `Action_Wait(duration)` | `Job_Wait`; uses `Global.time_manager.sim_seconds` semantics via the runner's DURATION mode, so no `await` |
| `Action_PlayAnimation(name)` / `Action_BeginAnchorAnimation` | `lay_down`, `begin_anchor_animation` |
| `Action_Pay(amount_source)` | `job_shop._pay`, hotel billing |
| `Action_QueueFollowup` | today's `get_followup_job` synchronous-handoff pattern, preserved (see risks) |
| `Action_Fail(reason)` | explicit dead-end for a branch |

**No `Action_Custom` / no `Callable` slot.** Per the authoring decision. A one-off step is a one-off `Action_*` class next to its driver; that keeps everything serializable and typed.

---

## Claim registry

### Shape

```gdscript
class_name ClaimRegistry
extends Node    ## a Managers/ node registering itself into Global.claim_registry

enum Kind { SLOT, ANCHOR, STORAGE_WITHDRAW, STORAGE_DEPOSIT, PILE, WORK }

func can_claim(job: Job, target: Object, kind: Kind, amount: int = 1) -> bool
func claim(job: Job, target: Object, kind: Kind, amount: int = 1) -> bool
func release(job: Job, target: Object, kind: Kind) -> void
func release_all(job: Job) -> void          ## called by Job.end(), always
func claimed_amount(target: Object, kind: Kind) -> int
func claims_of(job: Job) -> Array[ClaimSpec]  ## board inspector / debugging
```

### The important restraint: the registry is a ledger, not an accountant

RimWorld's `ReservationManager` is the single source of truth for every reservation on the map. **Do not copy that here**, for one concrete reason: `StorageData` owns `reserved_withdraw` / `reserved_deposit`, `available()` and `space_available()` read them, and `StorageData` is a **pure class with a GUT suite that constructs it directly and never touches `Global`** (CLAUDE.md: "Tests cover pure classes only"). Making `StorageData` consult a global registry breaks that suite and that rule.

So:

- **Capacity and amount accounting stay in the owning object.** `StorageData` keeps its counters. `SleepComponent` keeps `_claims.size() < capacity`. `PathComponent` keeps `_anchor_claims`.
- **The registry owns the claim *records* and the release path.** On `claim()` it calls through to the owner (`storage.reserve_withdraw(amount)`, `component.take_slot()`, `path.claim_anchor(type)`) and records the tuple. On `release()`/`release_all()` it calls the matching un-reserve and forgets the record.
- Ownership is duck-typed (`has_method("release_claim")`) rather than an interface — GDScript has none, and the targets don't share a base (`ComponentBase` vs `ResourcePile`). This matches how the codebase already probes for capability (`get_component_by_type`).

What this buys, concretely:

1. **`Job.end()` releases everything, always.** The 14 `_on_end()` release blocks and the whole "release on EVERY termination path" discipline become one line in the runner. The `_ended` latch stops being load-bearing for correctness at the job-author level.
2. **`StorageData.add_withdraw_job(job: Job_GetResource)` loses its hard type.** The claim carries its own amount, so the signature becomes `reserve_withdraw(amount: int)`. That unblocks `Job_CollectPile` reserving deposit space — the omission documented at `job_collect_pile.gd:7-14` becomes fixable, and the "whatever doesn't fit stays on the pawn" fallback becomes a genuine fallback rather than the plan.
3. **Leak detection becomes central.** `PathComponent._purge_dead_claims()` (`path_component.gd:238-242`) is a per-component self-heal for exactly this class of bug. One registry means one `assert(claims_of(job).is_empty())` after `end()`, in one place, catching all six claim kinds.

Migrate the existing per-component `claim_slot(job: JobBase)` methods to `take_slot()/free_slot()` (no `JobBase` parameter — the registry owns the identity of the claimant). That's a mechanical change across 5 component classes.

---

## Persistence

### Format

A saved job is one generic dict. **No job type contributes serialization code.**

```json
{
  "def": "haul_resource",
  "a": {"layer": 0, "cell": [16, 8], "path": "StorageComponent"},
  "b": {"layer": 0, "cell": [22, 8], "path": "StorageComponent"},
  "count": 12,
  "resource": "iron_ore",
  "index": 3,
  "sig": "GotoTarget|Take|GotoTarget|Deposit",
  "state": {"3": {"deposited": 4}}
}
```

- `def` → `JobData` by id → driver script. Replaces `JobSerializer`'s registry entirely.
- `a`/`b`/`c` → `JobTarget.to_dict()`, which delegates to the existing `SaveManager` ref helpers.
- `index` → the saved action; `sig` is a cheap integrity check that `make_actions()` still produces the same shape (a code change between save and load invalidates the index — drop the job rather than resume into the wrong action).
- `state` → sparse: only actions whose `save_state()` returned something. Usually one entry.
- Jobs whose `JobData.saveable == false` serialize to `{}` — the same "a system re-derives this on load" set documented at `job_serializer.gd:9-19` (idle, store-inventory, leave-station), now a data flag instead of an omission from a hand-maintained list.

### Load

`SaveManager._load_pawn_jobs` keeps its shape. `Job.from_dict()`:

1. resolve `JobData`; missing → drop
2. resolve targets; a target marked required that resolves null → drop
3. build driver, `make_actions()`, compare `sig`; mismatch → drop
4. `_index = saved index`; `actions[_index].load_state(state[index])`
5. re-acquire `driver.required_claims(_index)`; any failure → drop (cleanly, through the normal release path)
6. `actions[_index].on_resume(job)`

Steps 1-3 replicate today's "null propagates as drop this job" behaviour. Step 5 is new and is the subject of the next section.

### Resume and claims

Claims are not saved (decision taken; also CLAUDE.md's "derived state is re-derived, never saved"). But the saved action index deliberately points *past* the claim actions — a pawn resuming mid-sleep is at `Action_RestoreNeed`, and `Action_ClaimSlot` already ran before the save. Naively resuming would leave the pawn sleeping in a bed nobody has reserved, and a second pawn could claim it.

The answer is `JobDriver.required_claims(action_index)`: a declaration of what must be held for a given action to be meaningful, re-acquired at load before the action resumes. For sleep, `required_claims(RESTORE_INDEX)` returns the pod slot and the bunk anchor. If the re-claim fails — another pawn got there first during load ordering — the job drops cleanly and the need re-queues, which is strictly better than today (today the slot is also re-claimed, but as a side effect of restarting the whole job from `Starting`).

This is the load-bearing detail of the "don't persist reservations" decision. It should be written into the driver template so it isn't forgotten.

### Save version

The format change is not backward-compatible with the 17 hand-written job dicts. Rather than breaking saves outright:

**Bump `SAVE_VERSION` to 2 and register a `1 → 2` migration that strips `current_job` and `job_queue` from every pawn entry.** The mechanism already exists and is currently unused (`save_manager.gd:39`, `:591-599`). Pre-WI-44 saves then load with idle pawns who immediately pick fresh jobs off the board — the same thing that already happens for every unregistered job type today. ~20 lines, and no save file is lost. Strongly preferred over a hard break given the big-bang choice.

---

## UI

### Report text

`Job.report()` = `JobData.report_template` with `{a}`, `{b}`, `{c}`, `{resource}`, `{count}` substituted via `JobTarget.describe()`. `Job.subtask_report()` = `actions[_index].report(job)`, whose `ActionBase` default is derived per action class ("Walking to {target}", "Working", "Resting", "Waiting"). A new job type gets usable text without writing any.

`pawn_job_tab.gd` needs no structural change — it reads two strings today and will read two strings after, just better ones. `subtask_changed` becomes a runner-emitted signal on action advance rather than 17 hand-written property setters.

RimWorld's `ReportStringProcessed` / `GetResolvedJobReport` is the same idea; the substitution set here is smaller because we don't have `targetQueue`.

### Board inspector

New UI panel (station-level, alongside the existing economy/environment/visitor pages). Reads:

- `JobManager.get_board_snapshot() -> Array[Job]` — a read-only view across all six category queues, sorted by `effective_priority()`.
- claimed jobs, by sweeping pawns for `current_job` (the board doesn't hold claimed jobs — `find_job` removes them, `job_manager.gd:81`). `get_waiting_haul_jobs()` already does this union dance for the WI-35 logistics overlay; the inspector generalises it.
- per row: def name, report text, category, priority, age, workspace, claimant.
- for unclaimed rows, a **"blocked because"** column driven by `JobDriver.explain_block(pawn)`, evaluated on demand for the selected pawn only — never per frame.

This is the piece that pays for itself in debugging. "Why is nobody hauling?" currently has no answer short of a probe script.

---

## Worked example: `Job_GetResource` → `JobDriver_Haul`

**Today:** 207 lines, 2 movement one-shots, 2 storage reservation pairs, a 5-state enum, a bespoke `get_save_data`/`restore` pair, and a save story that makes the pawn redo the trip.

**After** — the whole driver:

```gdscript
class_name JobDriver_Haul
extends JobDriver

const RESERVE := 0
const GOTO_SOURCE := 1
const TAKE := 2
const GOTO_SINK := 3
const DEPOSIT := 4

func make_actions() -> Array[ActionBase]:
	return [
		Action_ReserveStorage.new(JobTarget.Slot.A, ClaimRegistry.Kind.STORAGE_WITHDRAW),
		Action_GotoTarget.new(JobTarget.Slot.A),
		Action_TakeFromStorage.new(JobTarget.Slot.A),
		Action_GotoTarget.new(JobTarget.Slot.B),
		Action_DepositToStorage.new(JobTarget.Slot.B),
	]

func is_valid() -> bool:
	return job.resource != null and (job.target_a.is_alive() or job.target_b.is_alive())

func can_do(pawn: PawnBase) -> bool:
	# unchanged logic, lifted verbatim from job_get_resource.gd:46-62
	...

func required_claims(index: int) -> Array[ClaimSpec]:
	var out: Array[ClaimSpec] = []
	if index >= RESERVE:
		out.append(ClaimSpec.storage(job.target_a, ClaimRegistry.Kind.STORAGE_WITHDRAW, job.count))
	if index >= GOTO_SOURCE:
		out.append(ClaimSpec.storage(job.target_b, ClaimRegistry.Kind.STORAGE_DEPOSIT, job.count))
	return out
```

Plus `data/jobs/haul_resource.tres`:
```
id = "haul_resource"
display_name = "Haul"
report_template = "Hauling {resource} to {b}"
category = HAUL
driver = job_driver_haul.gd
```

Gone: the state enum, both movement handlers, both `_ended` guards, `_on_cancel`'s release block, `get_save_data`, `restore`, `get_job_description`, `get_subtask_description`. Kept: the one genuinely job-specific thing, `can_do()`'s pull/push/fully-specified branching, and the trip-cap narrowing (which moves into `Action_ReserveStorage.on_start`, since it's a reservation concern and `StorageQuery.trip_cap` already exists).

**And the save behaviour changes qualitatively.** Saved at `index = 4` with cargo aboard, the pawn resumes by depositing. No sweep to a random bin, no second trip.

One coupling this exposes and the WI must handle: `PawnBase.start_job()` preempts *any* pawn with a non-empty inventory into `Job_StoreInventory` (`pawn_base.gd:211-217`). A restored job that intends to use its cargo must not be preempted. Fix: check the pawn's restored `current_job` before the sweep — a job whose current action expects carried cargo (`ActionBase.expects_cargo() -> bool`, default false) suppresses it.

## Worked example: the seven need jobs

`Job_Sleep`, `Job_Eat`, `Job_Recreate`, `Job_Shop`, `Job_Recharge`, `Job_GetRepaired`, `Job_GetTreatment` — 1,022 lines today — are all the same four steps with different finders and different need channels:

```gdscript
func make_actions() -> Array[ActionBase]:
	return [
		Action_FindBestTarget.new(finder, JobTarget.Slot.A),
		Action_ClaimSlot.new(JobTarget.Slot.A),
		Action_GotoAnchor.new(JobTarget.Slot.A, anchor_type),
		Action_RestoreNeed.new(need_id),
	]
```

Seven drivers of ~30 lines each, differing in their `TargetFinder` and `need_id`, plus the genuinely distinct bits: hotel billing (`Action_Pay` at the end of the sleep sequence for visitors), the shop's payment gate, the meal quality → mood application. The candidate-scoring band that only `Job_Sleep` has today (`desirability_distance_tolerance`) becomes available to all seven for free — a small, real gameplay improvement that falls out of the consolidation.

---

## Files

**New**
- `scripts/jobs/job.gd` (`Job` runtime + runner), `job_driver.gd`, `job_target.gd`, `job_data.gd`, `job_data_registry.gd`
- `scripts/jobs/actions/action_base.gd` + ~20 `action_*.gd`
- `scripts/jobs/finders/target_finder.gd` + ~5 finders
- `scripts/jobs/drivers/job_driver_*.gd` (~20)
- `scripts/managers/claim_registry.gd` + node in `main.tscn` under `Managers/`
- `data/jobs/*.tres` (~20)
- `ui/station/job_board_panel.tscn` + `.gd`
- `tests/unit/test_job_runner.gd`, `test_job_target.gd`, `test_claim_registry.gd`

**Changed**
- `pawn_base.gd` — `current_job: Job`, the cargo-preemption guard, `_end_current_job` xp via `JobData`
- `job_manager.gd` — `Array[Job]`, `get_board_snapshot()`, `effective_priority` moves onto `Job`
- `save_manager.gd` — `pawn_ref`, `SAVE_VERSION = 2`, the `1→2` migration, generic job (de)serialization
- 5 slot-owning components — `claim_slot(job)` → `take_slot()`
- `storage_component.gd` / `storage_data.gd` — `add_withdraw_job(Job_GetResource)` → `reserve_withdraw(amount)`
- every component that posts a job (~15) — construct a `Job` with targets instead of a subclass
- `overlay_flow_layer.gd` — reads `Job_GetResource` fields directly today; retarget to `Job` targets

**Deleted**
- all 23 `scripts/jobs/job_*.gd` job classes and `job_serializer.gd`
- `job_base.gd` — except `Category`, which moves to `job_data.gd` or stays as a small enum holder

**Ordering.** Big-bang is the decision, and it holds — one diff, no dual-path code. But sequence the *work* so it isn't untestable until the end: (1) runtime + registry + a pure GUT suite against stub actions; (2) `JobTarget` + persistence round-trip; (3) the action library, verified by (4) the first three drivers — haul, goto, wait — running in a real station; (5) the remaining ~17 drivers; (6) delete the legacy path; (7) UI. Stages 1-4 are ~40% of the work and de-risk the rest.

## Testing

GUT covers pure classes only, and most actions touch `Global`. But the highest-risk new code *is* pure:

- **`test_job_runner.gd`** — stub `ActionBase` subclasses that just record calls. Index advance, `next_index_after` jumps and loops, INSTANT chaining (and its runaway guard), outcome propagation, `end()` idempotency, `on_finish` ordering, guaranteed `release_all`. This is the single most valuable new suite.
- **`test_job_target.gd`** — dict round-trip per kind. Ref *resolution* needs `Global`; the encoding doesn't.
- **`test_claim_registry.gd`** — with fake claimables: over-claim rejection, `release_all` completeness, the post-end `claims_of(job).is_empty()` assertion.
- **`test_job_persistence.gd`** — save → mutate → restore against a stub driver, including `sig` mismatch → drop and `required_claims` failure → drop.

In-game verification follows the pattern that has actually worked through Phase 3: a temporary autoload probe running a numbered checklist headlessly. Two runs worth planning: a **differential** on job outcomes (do the converted jobs produce the same station state after N sim-hours as the old ones — the WI-40 approach), and a **save/resume matrix** (save each job type at each action index, reload, assert the pawn resumes at that index without redoing work).

## What not to port from RimWorld

Feedback requested, so — the things that look attractive in `Toil.cs` / `JobDriver.cs` and shouldn't be copied:

- **Lambda toils** (`initAction = delegate {...}`). Already decided against; the reasons are worth recording: GDScript lambdas can't be serialized, so toil-progress persistence — the main deliverable — would be impossible; they trip `untyped_declaration`/`unsafe_method_access`, which are enabled project-wide; and capture-by-value has already bitten this project once (WI-39).
- **Toil pooling** (`ToilMaker`, `inPool`, `Clear()`). RimWorld pools because it ticks thousands of pawns at 60 Hz. Spaceport ticks tens. Allocating a fresh `Array[ActionBase]` per job start is free at this scale; pooling would add a whole lifecycle-bug surface for nothing.
- **`atomicWithPrevious`, `FinishedBusy`, the stance system.** There is no stance/busy concept here and no reason to invent one.
- **`TryMakePreToilReservations`.** RimWorld reserves every target before the driver runs. Our jobs can't: the need jobs *find* their target as their first step. Progressive claiming is correct here; a pre-claim phase would force every finder to run at post time.
- **`targetQueueA/B` + `countQueue`.** RimWorld's opportunistic multi-pickup hauling. No current job needs it. Note in `job.gd` where it would go if opportunistic hauling is ever wanted, and don't build it.
- **The nine-value `JobCondition`.** Three (`SUCCEEDED`/`FAILED`/`INTERRUPTED`) have consumers here; the rest are RimWorld-specific error plumbing.
- **`Log.Error`-and-recover** (`JobUtility.TryStartErrorRecoverJob`). RimWorld wraps every toil call in try/catch because mods throw. GDScript has no exceptions to catch and no mod surface; a runaway-guard counter on INSTANT chaining is the only equivalent worth having.
- **Data-driven action sequences in `.tres`** (already declined). Reaffirming why: mining's "full? → return, else keep mining" and the processor's "more batches? → chain" are branches, and authoring branches in the inspector is worse than authoring them in `next_index_after()`.
- **A fully centralized reservation manager** — see the restraint above. Copying `ReservationManager` wholesale would break `StorageData`'s purity and its GUT suite for no gameplay gain.

## Risks

1. **`make_actions()` determinism is a silent correctness dependency.** A code change between save and load shifts the meaning of a saved index. The `sig` check catches it; it must be in from day one, not added later.
2. **Followup handoff races.** The current synchronous `get_followup_job()` handoff exists because component `_process` order isn't guaranteed (`job_get_resource.gd:151-154`, `job_work_processor.gd:120-124`). `Action_QueueFollowup` must resolve and queue *inside* the deposit/completion action, not after `end()`. Losing this reintroduces a real, already-solved race.
3. **The claim-kind boundary.** If a claim kind's accounting drifts between the registry's record and the owner's counter, you get phantom reservations that are worse than today's leaks (which at least fail loudly via `assert(reserved_withdraw >= 0)`). Keep the owner authoritative for amounts and the assertions where they are.
4. **Big-bang means one large unverifiable window.** Mitigated by the staging above, but ~20 drivers converting at once with no A/B comparison against the old behaviour is the main schedule risk. The differential probe is what makes it recoverable.
5. **MCP has been unreliable all through Phase 3.** Plan on headless probes, not the editor loop.
6. **`Resource` reference cycles.** Stated as a hard rule (`job` is a parameter, never a field on an action) — but it's the kind of rule that gets broken by the twentieth driver. Worth an explicit note in the driver template and a scan before merge.

## Open questions

- **Does the board inspector belong in the player UI or behind a dev toggle?** Specified as player-facing above; if it turns out to expose too much of the simulation's guts, the same panel behind an F-key costs nothing to change. Answer: Player UI
- **Should `JobData` carry the default priority**, or does that stay with the posting component? Storage priority is the routing language and is computed per-post (`±99` bands); a `.tres` default would only serve the jobs that post at a fixed priority. Leaning: leave priority on the `Job`, set by the poster, and don't put it in `JobData` at all. Answer: Stay with posting component.
- **Does `Job_Idle`/`Job_IdleWander` deserve the full pipeline?** They're 38 and 113 lines and never saved. Converting them is cheap and keeps one mechanism; skipping them keeps two. Leaning: convert, for the "one mechanism" property. Answer: Convert them.

## Related
[[WI-21_Job_Serialization]] · [[WI-40_Storage_Query_Helper]] · [[WI-23_Work_Improvements]] · [[01_Technical_Specification]]
