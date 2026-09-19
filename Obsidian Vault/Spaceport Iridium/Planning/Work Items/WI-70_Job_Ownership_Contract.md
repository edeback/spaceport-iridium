# WI-70 — Job Ownership Contract

> **Status: DRAFT (2026-09-19), not started. Depends on [[WI-69_Integration_Test_Fixture]]**, which pins this item's four bugs as known-broken tests for it to flip. *(2026-09-19: WI-69 is done. The pins are in `tests/integration/test_known_bugs.gd`: F38 with a live-teardown control beside it, F25, and F26 four times (site, manned processor, repair, pile). Each asserts today's value and says what the fix makes it. `_most_jobs_after_reload()` is the helper for §3's duplicate count, and `StationFixture.live_jobs()` asks the whole station rather than the owner's pointer. A minimal F25 fix and a minimal repair adoption were each confirmed to fail their pin.)* Scoped from [[05_Architecture_Review]] §A2–A4 and the second-pass audit in [[03_Bugs_and_Improvements]]. It fixes **F25**, **F26**, **F32** and **F38**, and tests a hypothesis about WI-68's residual per-load leak. §0's three decisions are the author's to settle; the recommended default is marked on each.

## Goal

Eleven components post a job and remember it, so they don't post a second. Each one re-implements the same small contract: keep a pointer, clear it when the job ends, re-post if the job didn't finish, and (on the pawn side only) re-link to the restored job after a load. The eleven copies disagree. Three got it wrong:
- **F25 (confirmed):** `ConstructionComponent` asks `is_failed()`, which is false for an INTERRUPTED job. A builder who resigns, is fired, or is sent to suit up at Tier 2+ leaves the site stuck in `Constructing` for the rest of the session. The same hole exists for deconstruction.
- **F26 (read from code):** no module-side owner is re-linked to its restored job after a load, so every load posts duplicates: two crew on one site, a walk-and-fail loop at a manned processor, a wasted repair trip, a second pile collector. `ModuleBase.adopt_repair_job()` and `MedicalComponent.adopt_doctor_job()` were written for exactly this and have no callers.
- **F2 (fixed in WI-68)** was the pawn-side instance of the same class.

A fourth bug sits in the same code path:
- **F38 (confirmed 2026-09-19, scratch-copy probe):** a save taken while a module is being deconstructed **loses the deconstruction refund**. The load collapses `Deconstructing` to `Deconstructed` (`construction_component.gd:249`, the F14 "shortcut") but never deposits the refund: during deconstruction the material bin is empty, so there is nothing for the storage block to restore. The site finds an empty bin and removes itself within half a second. In the probe, the torn-down control refunded its 6 steel, while the module saved mid-teardown reloaded as "done", was replaced by truss, and the 6 steel never appeared. The window is wider than it looks. Deconstruction stalls whenever nobody can go outside, or when F25 strands its job. The probe's first run also hit the realistic player path: **pause, order a demolition, quicksave**, and both refunds were gone. This is silent resource loss and the most serious bug in this item.

After this item there is one contract, written once, and a job is re-linked to its owner by what it declares rather than by an if-chain that someone has to remember to extend.

## 0 — Decisions for the author (not yet settled)

1. **Restored jobs resume, and their owners re-adopt them.** *Recommended.* This is WI-44's model, and F21 already depends on it. The owners were written under the older model ("the board re-derives from deficits"), and still behave as if it held; that mismatch is F26. The rule goes into CLAUDE.md's persistence section. *Alternative:* drop in-flight jobs on load and let owners re-post, which throws away WI-21 and F21.
2. **A job's owner is declared on its `JobData`** (`origin`), overridable per post for the one type whose owner depends on direction (a haul). *Recommended.* This follows the "declared or it does not exist" rule, and it is what lets `SaveManager._adopt_if_need_job`, the if-chain F2 slipped through, be deleted. *Alternative:* keep extending the if-chain, one branch per owner.
3. **A module saved mid-deconstruction restores as `Deconstructing`, with its progress** (F38). *Recommended.* It is the mirror the code comment always claimed, and the deconstruct job re-links through decision 2 like any other. *Alternative, smaller:* keep F14's collapse but deposit the refund while collapsing. That fixes the loss, but a save still finishes the teardown for free.

## Scope

**In:** `Job.did_not_complete()` (§1), `JobSlot` and the eleven owners (§2), declared origin and generic adoption (§3), F25 (§4), F38 and F14 (§5), the leak hypothesis (§6), F32 (§7), and docs (§8).

**Out:**
- reference hygiene in general (WI-71);
- the pawn-kind save hooks (WI-73). This item only replaces the job-adoption half of `SaveManager`'s pawn path.

## Design

### 1 — The predicate owners should ask (A3)

Add `Job.did_not_complete() -> bool`, which is `_ended and _outcome != Outcome.SUCCEEDED`. "It didn't finish, so re-post" is the question every owner asks. `is_failed()` answers a narrower one and reads like the same one, which is how F25 happened. `is_failed()` stays for the runner and the tests; a source sweep (§8) fails on any call to it outside `scripts/jobs/`.

### 2 — `JobSlot`: one contract, eleven owners

`scripts/jobs/job_slot.gd`, `class_name JobSlot extends RefCounted`, pure, with its own suite:

| Member | Does |
|---|---|
| `_init(on_end: Callable)` | The owner's handler, `func(job: Job, completed: bool)`. |
| `job() -> Job` | The held job while it is live, else null. |
| `is_live() -> bool` | Held and not ended. |
| `post(job: Job) -> Job` | Holds `job` if nothing live is held. Refuses and returns the live job if something is, so an owner can never silently replace a running job. |
| `adopt(job: Job) -> bool` | The restore path. Same rule as `post`. |
| `clear_if(job: Job) -> bool` | F2's rule, made general: only the held job may clear itself. |
| `cancel_live(as_failed := true)` | What `StorageData.end_all_jobs()` needs. |

**No `.bind(job)`.** `JobSlot` connects the job's `job_end` to its own *unbound* `_on_job_end()` and reads the job from `_job`. A Callable to a method stores an ObjectID, not a reference, so the job does not keep the slot alive. By contrast, today's `job.job_end.connect(handler.bind(job))` puts a strong reference to the job inside a connection the job itself holds, which is a cycle until the signal fires (§6).

The eleven owners each replace a `Job` field and its listener with a slot:

| Owner | Field today |
|---|---|
| `ConstructionComponent` | `construction_job` |
| `ProcessorComponent` | `_work_job` |
| `ModuleBase` (repair) | `_repair_job` |
| `MedicalComponent` | `_doctor_job` |
| `StorageData` | `import_job`, `export_job` (two slots) |
| `ResourcePile` | `active_jobs` (one slot per resource) |
| `PawnNeedsComponent` | `NeedDef.pending_job` (one per need) |
| `RobotPowerComponent` | `_recharge_job` |
| `RobotIntegrityComponent` | `_repair_job` |
| `PawnDiseaseComponent` | `_treatment_job` |
| `PawnSuitComponent` | `_trip` (F2's `trip_refused`/`apply_change` guards become `clear_if`) |

`StorageData.set_job_priority()` and `end_all_jobs()` keep their signatures and act on the slots, so `test_storage_data.gd` needs only its field reads updated.

### 3 — Declared owners and generic adoption (A2, F26)

`JobData` gains `@export var origin: Origin`, with `enum Origin { NONE, PAWN, TARGET_A, TARGET_B, TARGET_C }`. `Job.origin` defaults from it, `Job.with_origin()` overrides it, and `to_dict()` writes `"origin"` only when it differs from the data default.

| Origin | Job types |
|---|---|
| `PAWN` | `eat`, `sleep`, `recreate`, `shop`, `recharge`, `get_repaired`, `get_treatment`, `change_suit` |
| `TARGET_A` | `construct_module`, `deconstruct_module`, `work_processor`, `doctor`, `repair_module`, `collect_pile` |
| set per post | `haul_resource`: a pull (the sink posted it) is `TARGET_B`; a push (the source posted it) is `TARGET_A`. `StorageComponent._on_slow_tick` sets it at both posting sites. |
| `NONE` | `idle`, `idle_wander`, `wait`, `move_to_location`, `store_inventory`, `leave_station`, `mine_asteroid` (posted but not remembered by anyone) |

**Adoption.** `SaveManager._load_pawn_jobs` stops calling `_adopt_if_need_job` and instead calls `Job.offer_to_owner()` on each restored job:
- `PAWN`: offer to each of the pawn's components that implements `adopt_restored_job(job: Job) -> bool`, until one accepts;
- `TARGET_x`: offer to that target's owner (the component; the module for a MODULE target; the pile for a PILE target);
- `NONE`: nobody.

The hook is duck-typed, in the claimable contract's shape, so a mod's component adopts its own jobs with no core edit. `_adopt_if_need_job` is deleted. The two dead hooks, `adopt_repair_job` and `adopt_doctor_job`, become the `adopt_restored_job` implementations on their owners, and the five pawn-side `adopt_restored_*` methods are renamed to it. `StorageComponent.adopt_restored_job` reads `job.origin` to know whether it is the sink (`import_job` slot) or the source (`export_job` slot) for `job.resource`.

**Old saves.** Every type's owner comes from its `.tres`, so older saves are covered, with one exception: a haul saved before this item has no `"origin"` key, takes the data default `NONE`, and is not adopted. That costs one duplicate haul trip on the first load, which is today's behaviour for every type. `SAVE_VERSION` does not move.

### 4 — F25: a builder's interruption no longer strands the site

Both construction handlers become one slot handler: when the job ended and `not completed`, reset to `NotStarted` for a build, and re-post for a teardown.

Also add a self-heal in `_process`: in `Constructing` or `Deconstructing` with no live slot job and the work not done, drop back to the state that re-posts. This is belt and braces, and it is also what un-sticks a site that is already stuck in a running session. A site stuck in a player's *save* already heals on load today, because `Constructing` collapses to `NotStarted`.

### 5 — F38 and F14: deconstruction survives a save

`load_save_data` gets a `Deconstructing` branch of its own, separate from `Deconstructed`:
- `current_state = Deconstructing`;
- `work_seconds_done` from `"work_done"` (already saved);
- `owner_module.ready_deconstructing()`, since the load's ready pass ran `ready_constructed` on it;
- `set_process(true)`, and the slot is left empty. The restored deconstruct job, if a pawn was on it, is adopted through §3. If not, the self-heal from §4 re-posts on the next frame.

The `Deconstructed` branch (`_setup_deconstructed_for_load`) stays as it is. A module saved *after* its refund was deposited restores correctly, and the probe's control confirmed that.

**Recovery for existing saves:** a save written mid-deconstruction still says `"state": 4` with its `work_done`. So after this fix, loading one restores the teardown instead of discarding the refund. Nothing already saved is lost, provided the save hasn't been loaded and re-saved in the meantime.

### 6 — The residual per-load leak (hypothesis)

WI-68 stage 1 left about 43 loose objects per load. **Hypothesis:** jobs still waiting on the board at teardown are held by their own `job_end` connections:
- `.bind(job)` in construction, processor, medical and piles puts the job inside a connection it owns;
- `.bind(data, …)` in storage puts the `StorageData` inside it, and the `StorageData` holds the job back through `import_job`.

`Job` is a Resource and isn't counted by the metric, but each one holds its driver and its `JobTarget`s, which are loose RefCounted objects. Ten to twenty board jobs at teardown would account for the residual.

**Measure before claiming:** on the real quicksave in a scratch copy, compare the board size at teardown against the per-load residual, before and after §2. If the residual falls to near zero, record it as fixed here. If it doesn't, record the measurement and carry the hunt to WI-71.

### 7 — F32: `find_job` stops mutating what it iterates

`JobManager.find_job` currently cancels an invalid job before removing it (`job_manager.gd`, the `is_valid()` branch in `find_job`). The cancel emits `job_end` synchronously, a listener that re-posts inserts into the same array, and the cursor then removes the wrong job. Swap the two lines: `remove_at` first, then `cancel`. After §2 every owner re-posts through `JobSlot.post`, which makes this path more likely than it was, so the fix belongs here.

### 8 — Docs and guard

- **CLAUDE.md, Persistence:** "In-flight jobs save and resume. The component that posted a job re-adopts it on load through `JobData.origin`, and holds it in a `JobSlot`. An owner never re-posts while its slot is live." Delete the old "Board jobs re-derive" sentence; it is still true of *unclaimed* board jobs, so say that instead.
- **CLAUDE.md, Jobs:** a new job type that an owner remembers declares its `origin`.
- **Source sweep** (a `tests/unit/` text sweep, the `test_ui_theme` shape):
  - no `is_failed()` outside `scripts/jobs/`;
  - no `job_end.connect(` outside `job_slot.gd` and the inspection runner's one-shot.
- **[[01_Technical_Specification]] §1.7 and §1.17.**

## Files to touch

| | Files |
|---|---|
| New | `scripts/jobs/job_slot.gd`, `tests/unit/test_job_slot.gd` |
| Changed, core | `scripts/jobs/job.gd` (`did_not_complete`, `origin`, `with_origin`, `offer_to_owner`, `to_dict`/`restore`), `scripts/jobs/job_data.gd` (`origin`), all 22 `data/jobs/*.tres`, `scripts/managers/job_manager.gd` (F32), `scripts/managers/save_manager.gd` (adoption loop; `_adopt_if_need_job` deleted) |
| Changed, owners | `modules/components/construction_component.gd` (F25, F38), `processor_component.gd`, `medical_component.gd`, `storage_component.gd`, `storage_data.gd`, `modules/templates/module_base.gd`, `data/resources/resource_pile.gd`, `pawns/pawn_needs_component.gd`, `robot_power_component.gd`, `robot_integrity_component.gd`, `pawn_disease_component.gd`, `pawn_suit_component.gd`, `scripts/jobs/actions/action_change_suit.gd`, `scripts/jobs/drivers/job_driver_change_suit.gd`, `scripts/utility/cheats.gd` |
| Tests | `test_storage_data.gd`, `test_suit_content.gd`, `test_job_serialization.gd` (the `origin` round trip), and WI-69's `test_known_bugs.gd` (flipped) |

## Implementation order

1. **F38 first, with its test flipped.** It is silent resource loss and the fix is local to `construction_component.gd`. Don't wait for the rest.
2. `did_not_complete()` and F25, then flip its test.
3. `JobSlot` and its suite, then convert the owners one at a time, running the full suite after each.
4. `origin` on `JobData` and the 22 `.tres`, then adoption. Delete `_adopt_if_need_job` last, once every branch it had is served by a hook. Flip the four F26 tests.
5. F32.
6. §6's measurement.
7. The sweep and the docs.

## Edge cases

- **A restored `PAWN` job whose owner component is missing** (a mod was removed) is offered to nobody. It still runs; at worst its owner posts a duplicate once.
- **Two restored jobs for one owner** (F2's old-save artefact: a save from a build with that bug) is handled by `adopt` refusing the second. The second runs once as an orphan, which is the edge WI-68 already accepted.
- **`post` while live** is refused. Any caller that relied on overwriting a live pointer was already buggy; the construction follow-up path (`offer_followup_job`) already checks first.
- **A slot handler that re-posts during teardown.** A job cancelled during a scene swap fires its owner's handler, which may call `add_job` on a `JobManager` that is being freed. Handlers check `is_inside_tree()` before re-posting.
- **The deconstruct job adopted on load** while the self-heal also wants to re-post: adoption runs during the load, before the first `_process`, so the slot is live by the time the self-heal looks.
- **A module mid-deconstruction whose save predates this item** restores correctly (§5).

## Verification

1. **GUT unit:** `test_job_slot.gd`, which covers post, refuse-while-live, adopt, `clear_if` by the wrong job, the handler's `completed` flag for all three outcomes, and a weakref proof that a slot holding an ended job keeps nothing alive. Plus the `origin` round trip and the source sweep.
2. **GUT integration (WI-69):** all six known-bug tests flipped and green. Plus two new ones: saving and reloading a station with a deconstruction stalled for lack of an airlock keeps the refund promise, and `JobManager.board_size()` right after a load has no second job for any owner that had one live at save time.
3. **Scratch copy on the real quicksave:**
   - one save and load shows no duplicate board job and no pawn walking to a machine and failing;
   - §6's leak measurement, before and after;
   - 12 sim-hours afterwards with zero reservation drift, zero overfill and zero script errors, matching WI-68's F21 run.
4. **By hand, at Tier 2:** order a build, breach the room a builder has to cross so they suit up mid-walk, and confirm the site gets a builder again. Then pause, order a demolition, quicksave, quickload, and confirm the refund lands.

## Related

- [[WI-44_Job_System_Refactor]]: `Job`, `JobData`, the runner, and the claimable contract §3 copies.
- [[WI-68_Audit_Fix_Pass]]: F2 and F21, the first two members of this class, and the leak measurement §6 continues.
- [[WI-73_Save_Orchestration]] takes the rest of `SaveManager`'s pawn path.
