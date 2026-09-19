# Architecture Review — 2026-09-18

> **Status: review, not a plan.** Written alongside the second-pass audit in [[03_Bugs_and_Improvements]] (findings F25–F37), after WI-68's stages 1–4 and 3b. Nothing here is committed to; §5 suggests how it would bundle into work items if the author agrees with the diagnosis. Where a claim rests on a number, the number was measured on the tree at commit `cc53f388`.
>
> **Update (2026-09-19): written up as six work items, [[WI-69_Integration_Test_Fixture]] … [[WI-74_Layering_And_Consolidations]]**, after WI-68 merged. The mapping is in §5 and in [[03_Bugs_and_Improvements]]. Three corrections from scoping them are noted in place below. The review's own numbers stand at `cc53f388`. A new finding, **F38** (a save taken mid-deconstruction loses the refund; confirmed), joined the job-ownership class.

## 0. Why this document exists

Sixty-eight work items have gone in as individual pieces, each verified on its own terms, and the last two audits have both found the same *shape* of bug: a system that keeps a pointer to something it does not own - a job, a module, a manager - and is wrong about that thing's lifetime. F2, F21, F22, F23, F24, F25, F26, F28 and F29 are nine instances of one rule that was never written down. The purpose of this review is to name the rules the per-item work has been circling, say where the code already has the right pattern (it usually does, somewhere), and propose the handful of structural changes that would close whole classes instead of instances.

The codebase is in good shape for its size. Composition is real, the pure-logic extraction discipline has given it 91 GUT suites and 1,718 green tests, the load-bearing rules are mostly stated in CLAUDE.md, and the last three items (WI-65, WI-67, WI-68) each closed a real class of defect. What follows is the disagreement, not the praise; §4 records what should be protected.

## 1. Where the codebase stands

| Area | Lines | Files | Tested by GUT |
|---|---|---|---|
| `scripts/managers/` | 10,014 | 33 | statics only (`EconomyManager.*`, `SaveManager.*`, `VisitorManager.*`) |
| `scripts/utility/` | 7,175 | 33 | yes - this is the tested tier |
| `modules/components/` | 6,411 | 37 | four pure pieces (`StorageData`, `StatModifiers`, `ProcessorComponent.runs_for`, save contracts) |
| `pawns/` | 4,672 | 22 | `SuitRules`, `PawnStatus`, `CandidateRoller` (all extracted) |
| `ui/` | 22,607 | 111 | the theme/palette/metrics sweeps and the panel *models* |
| `scripts/jobs/` | 5,080 | 73 | `Job` runner, serialization, claims, haul sizing |
| total (non-test, non-vendored) | 64,867 | 396 | 91 suites |

Coupling, measured as "files that reach `Global.<something>`":

| Slot | Files | Slot | Files |
|---|---|---|---|
| `time_manager` | 78 | `crew_manager` | 16 |
| `world_manager` | 40 | `economy_manager` | 15 |
| `path_manager` | 33 | `job_manager` | 12 |
| `unlock_manager` | 25 | `heat_manager` | 11 |
| `resource_manager` | 25 | `alert_manager` | 10 |
| `save_manager` | 19 | `adjacency_manager` | 10 |
| `ui_main` | 18 | `claim_registry` | 3 |

**193 of 396 files (49%) touch `Global`.** `ClaimRegistry` at 3 is what a well-encapsulated manager looks like - everything reaches it through `Job`. `TimeManager` at 78 is the other end: it is the clock, and the clock is everywhere.

Per-frame work: 39 gameplay classes implement `_process`, 39 subscribe to `TimeManager`'s ticks, 53 `get_nodes_in_group` call sites remain (4 in `SaveManager`, 4 in `CrewManager`, the rest scattered), 21 bare `print`s remain in gameplay code after F18, and 15 `assert`s guard gameplay (F31).

## 2. The pattern behind the last nine findings

Every one of F2, F21, F22, F23, F24, F25, F26, F28 and F29 reduces to a *holder* keeping a reference to an *owned thing* and being wrong about one of three questions:

1. **Is it still alive?** (F22, F23, F24, F28, F29) - a `ModuleBase`, a bay, a manager, a door node, held across a frame, a flight, a scene swap, or an `await`.
2. **Is it still mine?** (F2, F26) - a job pointer that was cleared by the wrong job, or never set after a load.
3. **Is it still running?** (F25) - a job whose outcome was read with the wrong predicate.

The codebase already contains the right answer to each, in one place:

- **Alive:** `JobTarget` wraps every reference a job holds, answers `is_alive()` through `is_instance_valid`, and encodes/decodes through `SaveManager`'s `*_ref` helpers. Nothing that holds a `JobTarget` has ever had a freed-object bug.
- **Mine:** `PawnSuitComponent.apply_change(putting_on, job)` and `trip_refused(job)` after F2 - *only the job that made the change may clear the pointer*.
- **Running:** `Job.is_ended()` / `is_finished()`, which every owner except `ConstructionComponent` uses.

So the structural recommendations in §3 are mostly "take the pattern that exists and make it the only one", plus the tests that would have caught each finding.

## 3. Structural findings

Each entry: what is there, what it costs, what to do, and roughly how big the change is.

### A1. Half the codebase reaches a service locator, and the tested half is the half that doesn't

**What.** `Global` is a service locator: 30 typed slots, written by each manager in `_ready`, read by 193 files. The "pure logic must be extracted to be testable" rule exists because of this - a `GutTest` cannot construct a `StorageComponent` that reads `Global.time_manager` in `_ready`. The result is a two-tier codebase: `scripts/utility/` (7.2k lines, thoroughly tested) and everything else (managers 10k, components 6.4k, pawns 4.7k - untested except by probe).

**Cost.** Every finding in §2 lives in the untested tier, and every one is an *integration* fault between two owners. The extraction rule cannot reach them, because the rule is what the fault is *between*. WI-68's own verification method - a scratch copy of the project, an autoload probe, the real quicksave - is the right tool and is thrown away after every item. F26 was found by reading; the probe that would have caught it (load a save with a mid-build site, count board jobs) is thirty lines.

**Do.** Not dependency injection across 193 files - that is a rewrite for a benefit the codebase does not need. Instead:
- **A permanent integration suite** (`tests/integration/`, GUT, still headless): a `StationFixture` that instantiates `main.tscn` under `add_child_autofree`, waits for `game_bootstrapped`, and exposes `place(module_id, cell)`, `spawn_crew()`, `tick(sim_seconds)`, `save_and_reload()`. The first-pass probe already did all of this in an autoload; it moves into a fixture and stays. Each of F2, F21, F22, F23, F25 and F26 is then a ten-line test against the real managers, and the "reservations reconcile to zero after any cancel path" invariant becomes an assertion the suite runs after every test rather than a sentence in CLAUDE.md.
- **F33 first**, because a manager that `@onready`-binds a UI node by tree path is the one thing that stops `main.tscn` booting without its HUD.
- Keep the extraction rule for *rules*; stop treating it as the only way to test *behaviour*.

**Size.** Fixture: one file, a day. Converting the first-pass probes into tests: another day. `main.tscn` boots headless today (the probes prove it), so the cost is the fixture, not the scene.

> *Built (2026-09-19) as [[WI-69_Integration_Test_Fixture]].* One correction: **F33 was not a prerequisite.** The fixture boots the whole of `main.tscn`, HUD included, so a manager bound to a UI node by tree path boots fine. F33 is still worth fixing for its own sake, and it stays in WI-74. The fixture's permanent R4 also found a new bug in the first week, **F39**: a restored job lost its DURATION progress on a second save.

### A2. Job ownership is a contract nine owners each re-implement, and three got it wrong

**What.** A component that posts a job keeps a pointer, connects `job_end` to clear it, and (for pawn-side owners only) has an `adopt_*` hook `SaveManager` calls after a load. Nine owners: `ConstructionComponent`, `ProcessorComponent`, `ModuleBase` (repair), `MedicalComponent`, `StorageData` (×2), `ResourcePile`, `PawnNeedsComponent`, `RobotPowerComponent`, `RobotIntegrityComponent`, `PawnDiseaseComponent`, `PawnSuitComponent`. Three variants of "when do I clear it" (`is_failed()`, `is_ended()`, `== job` guards), two variants of "how do I re-link after a load" (an if-chain in `SaveManager`, or nothing), and two dead hooks.

**Cost.** F2, F25, F26 - and the next job type will get it wrong again, because the contract lives in each owner's head. `SaveManager._adopt_if_need_job` is an if-chain over job ids that has to be extended by hand for every job an owner remembers; the comment says so, and F2 was the case where nobody did.

**Do.** One `JobSlot` (pure, RefCounted, tested): `post(job)`, `is_live()`, `adopt(job)`, `clear_if(job)`, with the outcome predicate written once. Every owner holds one instead of a `Job` field and three lines of listener. Then make adoption structural the way WI-47 M2 made component saving structural: on restore, `Job` offers itself to each set target's component through a duck-typed `adopt_restored_job(job)` - the claimable contract's shape - and `StorageData`/`ResourcePile` implement it for their kinds. `_adopt_if_need_job` is deleted. **Rule to write down:** *an owner that remembers a job it posted owns exactly one `JobSlot`, and a job is re-linked to its owner by its target, never by its type.*

**Size.** `JobSlot` is ~40 lines with tests; the nine conversions are mechanical; the adoption hook replaces ~30 lines in `SaveManager` with one loop. Fixes F25 and F26 as a side effect.

### A3. `Job.Outcome` offers the wrong predicate to owners

**What.** `is_finished()`, `is_failed()`, `is_ended()`. The question an owner asks is "did this job not complete, so should I re-post?", and the honest answer is `is_ended() and not is_finished()`. `is_failed()` reads like that answer and excludes `INTERRUPTED`.

**Do.** Add `did_not_complete()` (or `needs_repost()`), make `is_failed()` internal or delete it, and the F25 class cannot recur. A one-line grep rule for the sweep suite: no `is_failed()` outside `job.gd`.

### A4. Two persistence models for jobs coexist, and the owners believe the old one

**What.** WI-21/WI-44 made in-flight jobs save and resume. The owners were written under the earlier rule ("the board re-derives from deficits within a tick of loading") and still behave as if it held: `StorageComponent` says so in a comment (F35), `ConstructionComponent` collapses `Constructing` to `NotStarted` and re-posts, every module-side owner re-posts on its first tick. The result is that a load is a duplicate-job generator (F26).

**Do.** Decide one rule and finish it. WI-44 chose "restored jobs resume", and it is the right choice (a haul mid-carry resuming is the whole point of F21). So: every owner re-adopts (A2), and no owner re-posts until its slot is empty. Write the rule into the persistence section of CLAUDE.md beside the load-order sentence, because it is the same kind of load-bearing fact.

### A5. Three hand-numbered orderings hold the boot and load together

**What.** Manager ready order is the `Managers/` child order in `main.tscn` ("tree order = ready order and it is load-bearing"). Save-section order is an integer each manager passes to `register_section`. Component restore order is `save_order()`. Each is a number chosen by reading the others; `test_component_save_contract` pins some component pairs and `test_save_sections` pins the registry's sort, but nothing pins the scene, and the scene is the one that gets edited in the editor.

**Do.** The cheapest guard: a GUT test that loads `main.tscn` as a `PackedScene`, walks its `Managers/` children, and asserts the order against a declared list in `Global` (or in the test), so a drag in the editor fails a test rather than a load. The better shape, later: sections declare `after: [&"world"]` rather than `60`, and the registry topologically sorts - numbers were chosen because a mod needs to slot in, and "after everything vanilla" is easier to say by name than by picking 1000.

### A6. Freed-object hygiene is four rules where it should be one

**What.** F8 (node-keyed dictionaries), F23/F24 (typed parameters), F28 (awaits on freeable nodes), F29 (`Global` slots). CLAUDE.md has one sentence for the first. The sanctioned patterns already exist: `JobTarget` for references a job holds, `*_ref` for anything saved, `get_instance_id()` keys for dictionaries, `Variant` parameters with `is_instance_valid` for anything bound to a signal.

**Do.** Write the one rule - *nothing holds a typed reference to a `Node` it does not own across a frame boundary without a validity discipline, and the four disciplines are these* - then enforce the greppable halves as source sweeps in the `test_ui_theme` shape: `Dictionary[ModuleBase|PawnBase|ComponentBase,` outside an allowlist; `is_instance_valid(<param>)` where `<param>` is typed (the F24 sweep); `Global\.\w+ (==|!=) null` (F29); `await` outside an allowlist of files that have earned it. Each sweep is twenty lines and each would have failed on a real finding.

> *Correction (2026-09-19):* the `Global\.\w+ (==|!=) null` sweep is dropped. WI-68 established that in Godot 4.7 a freed object compares `== null` as true, so those guards already catch a freed slot. F29 is hygiene, and [[WI-71_Reference_Hygiene]] §7 keeps only the `_exit_tree` nulling. The same fact is why most F24 sites are safe in practice, which is the triage question WI-71 §2 asks of each.

### A7. Doors are the last suspended coroutine in the movement pipeline

**What.** WI-20 made turbolift rides an explicit `CONVEYED` state because "cancelling a job mid-ride can never strand a suspended coroutine". Door hooks (`path_enter`/`path_exit`/`traverse`) still `await` inside `reached_next_node`, guarded by `_busy_in_hook`, with a cancel signal nobody reads (F28).

**Do.** Finish WI-20: a `DOOR_WAIT` state with a sim-time timer, the door animation kicked off and forgotten, `PathBehaviorContext.cancelled` deleted, `_busy_in_hook` deleted. Then `is_traveling()` is a pure function of `state`, which is what `PawnStatus` and the robot drain want.

> *Correction (2026-09-19):* doors are not the last one. The teleporter's `traverse` awaits its lightning animation, and turbolift *boarding* (the walk to the waiting spot and the wait for a cab) is still an `await` chain; WI-20 made only the ride itself a state. Boarding already re-checks `request.cancelled` and the pawn after every await, so [[WI-71_Reference_Hygiene]] guards the teleporter with the doors and leaves boarding out, with the reason recorded.

### A8. `SaveManager` is three things, and one of them is the last hand-enumerated chain

**What.** 1,171 lines: slot IO and migration (static), the ref helpers (static), and the pawn and pile sections. WI-47 M2 replaced `ModuleBase`'s hand-written component chain with `save_key()`/`save_order()` hooks and did the same for pawn *components* - but the pawn *kinds* are still an `if pawn is X` chain in `SaveManager` (`:696-706` on save, `:1062-1110` on load): `robot_index`, `mining_comp`, `logistics_bay`, `visitor`. A modded pawn kind with one field of its own cannot persist it, which is exactly the hole M2 closed for components.

**Do.** `PawnBase.get_save_data()`/`load_save_data()` virtuals with the subclasses overriding (`RobotPawnBase` → `robot_index`, `MiningDronePawn` → its bay ref, `VisitorPawn` → its visit block), and the pawn section becomes a walk. Then the slot IO and the ref helpers can be their own files (`SaveSlots`, `SaveRefs`) and `SaveManager` is the orchestrator it says it is.

### A9. Job picking is a template method written three times

**What.** `PawnBase.start_job`, `RobotPawnBase.start_job`, `VisitorPawn`: the same sequence (restored job → cargo sweep → personal queue → board or wander) with kind-specific gates spliced in. F21 had to be patched into all three.

**Do.** One `start_job` in `PawnBase` with overridable steps (`_before_sweep()`, `_board_categories()`, `_fallback_job()`), or a `JobPicker` strategy object. Small, and it makes the next policy change one edit.

### A10. Content registries are twelve copies of one static cache

**What.** `BuildCategoryData`, `DifficultyData`, `DiseaseData`, `PawnData`, `PlanetVariant`, `ShipData`, `ShopTypeData`, `SkillData`, `StarClass`, `TraitData`, `RecipeData`, `JobDataRegistry`, `MoodCatalog`, `NameGenerator` each hold `static var _registry/_ordered/_scanned` and a `clear_for_test`. None is ever invalidated in a running process, so WI-47's deferred stage 5 (patch ops) and any runtime mod enable/disable would have to reach fourteen statics.

**Do.** One `ContentRegistry` base (or a `ContentPaths.invalidated` hook every static subscribes to) so "the content set changed" is one call. Pairs naturally with WI-47 stage 5 when it is picked up.

### A11. The simulation reaches up into the HUD in six places

**What.** `ModuleBase._on_footprint_input_event` → `Global.ui_main.module_clicked`; `PawnBase._on_collision_clicked` → `Global.ui_main.pawn_clicked`; `ResourcePile` → `Global.ui_main.resource_pile_clicked`; `AsteroidBase` likewise; `PathManager`/`StructureManager` (F33); `ModuleTurbolift`. World objects deciding what a click means is the sim depending on the UI.

**Do.** World objects emit one `SignalBus.world_object_clicked(object)`; `UIMain` subscribes. Then a headless fixture (A1) needs no `UIMain` at all, and the click-cycle logic lives in one place.

### A12. The stat vocabulary, the mod API, and the balance numbers are undeclared

**What.** Seventeen stat names are free-form (F30). Ten `SignalBus` signals have no listener and one is never emitted (F11) - if they are the mod API, nothing says so. ~40 balance literals sit in gameplay code (`randf() < 0.5` breakdown split, `max_hp() * 0.15`, `lerpf(0.5, 1.1, happiness)`, `SECONDS_PER_HOUR = 10.0` still marked "temp for testing") against an invariant that says balance lives in data.

**Do.** `Stats` constants + sweep (F30); a `## MOD API` block in `signal_bus.gd` naming the signals a mod may rely on and deleting the rest (F11); a one-time pass moving the balance literals into the `.tres` or an exported var - the invariant is right, it just was never swept.

## 4. What is right and should be protected

- **Composition over inheritance is real.** Three pawn kinds differ by components, not overrides; a new module is a scene plus data; WI-44's job system is the cleanest part of the codebase.
- **The pure-extraction discipline** produced `StorageQuery`, `SuitRules`, `MultiplacementPlan`, `PawnStatus`, `AlertRules`, `HeatMath` - each a rule argued once and tested. A1 adds to this; it does not replace it.
- **"Declared or it does not exist"** (`Groups`, `UIType`, `StoryFlags`, `TutorialTriggers`, ledger categories) is the right instinct and the reason F30 is a finding rather than a mystery.
- **The source sweeps** (`test_ui_theme`, `test_keybinds`, `test_pause_holds`, the content sweeps) are the highest-yield tests in the project; every one has caught a real defect. A6 asks for more of them.
- **The audit method itself** - scratch copy, own `user://`, real quicksave, A/B a one-line patch - is what turns "read from code" into "confirmed". A1 is the argument for keeping it instead of rebuilding it per item.
- **`ClaimRegistry`'s ownership split** (owner authoritative for capacity, registry authoritative for records and release) is exactly right and is why reservation drift has been zero across every soak.

## 5. If this became work items

> *Update (2026-09-19):* written up in dependency order rather than the order below. The fixture comes first as [[WI-69_Integration_Test_Fixture]], because item 1's verification is defined in terms of it, and item 1 would otherwise have been verified by probes the fixture then replaces. The others follow as [[WI-70_Job_Ownership_Contract]] (now also carrying F38), [[WI-71_Reference_Hygiene]], [[WI-72_Declared_Vocabularies_And_Content_Guards]], [[WI-73_Save_Orchestration]] and [[WI-74_Layering_And_Consolidations]]. F33 moved from the fixture item to WI-74: `main.tscn` boots whole under the fixture, so the path-bound UI node isn't a blocker, and it belongs with A11.

Ordered by defect-class closed per line changed:

1. **Job ownership contract** (A2, A3, A4; fixes F25, F26, F32): `JobSlot`, generic adoption, `did_not_complete()`, the persistence rule in CLAUDE.md. Verified by the integration fixture below on a save with a mid-build site, a manned processor and a repair in flight.
2. **Integration fixture** (A1; unblocks everything that has been probe-only): `tests/integration/StationFixture`, the first-pass probes as tests, F33 to let `main.tscn` boot without its HUD.
3. **Reference hygiene** (A6, A7; fixes F27, F28, F29, closes F8 and the rest of F24): the rule, the four sweeps, `_exit_tree` nulling, `DOOR_WAIT`.
4. **Declared vocabularies** (A12; fixes F30, F31, F11): `Stats`, the content sweep, the mod-API block, asserts to `push_error`.
5. **Save orchestration** (A5, A8): scene-order test, pawn-kind hooks, `SaveManager` split.
6. **Small consolidations** (A9, A10, A11) as they are touched.

WI-68's stages 5 and 6 (F6, F7, F16–F18) stand as they are and should land first: the typed-warnings-as-errors flip in particular changes what every item above compiles against.
