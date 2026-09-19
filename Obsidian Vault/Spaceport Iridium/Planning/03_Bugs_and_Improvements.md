# Bugs, Code Issues & Improvement Suggestions

## 2026-09-18 audit pass (post-WI-67)

*The first whole-codebase sweep since 2026-07-22. WI-38…WI-67 (~30 items) had each been verified on its own terms, but nobody had checked the whole against CLAUDE.md's invariants, several of which were written after the code they govern. Findings are numbered **F1…F20** so they don't collide with the older A/B/C/D ids below. Everything marked* confirmed *was either reproduced at runtime or A/B-tested with a one-line patch in a throwaway copy of the project; everything else is marked as read from code.*

**How it was checked.** Static: every CLAUDE.md rule that can be expressed as a grep was run, and every hit was read in context. Runtime: a temporary autoload probe ran in a **scratch copy of the project with its own `user://`**, so the real `project.godot` and saves were never touched. It had seven phases:
- **R1** GUT;
- **R2** typed warnings raised to errors;
- **R3** load every `.tres`/`.tscn`;
- **R4** save→load→save JSON diff, plus Quit-to-Menu → New Game vs a fresh boot;
- **R5** a 120-sim-hour soak at 4× on the real quicksave, checking reservations, capacity, stuck jobs, world resource totals and object counts every few ticks;
- **R6** six New Game ↔ menu cycles;
- **R7** a crew member mid-suit-trip across a save/load, against a no-reload control.

### Verified clean (so the next pass needn't redo it)

- **GUT: 89 suites, 1,672/1,672 passing** (54,286 asserts).
- **R3:** all 389 resources load and all 142 scenes instantiate; no `ModuleData` lacks a scene.
- **R4 idempotence:** a save written straight after loading another is identical to it except for F13's float drift. Pawn current jobs come back at the front of the queue with their action index intact, which is equivalent.
- **R4 scene swap:** New Game after Quit to Menu differs from a fresh boot only in random rolls and the static id counters, which keep counting and stay unique. **The A8 class stays fixed.**
- **R5, 120 sim-hours:** zero script errors, zero reservation drift between `StorageData` and `ClaimRegistry`, zero capacity overfill (pool, output or INPUT cap), zero orphan nodes, and no unexplained drop in any resource's world total (the largest hourly drop was 2 units, a batch). *Caveat:* the quicksave is Tier 1, so the cost streams, the suit rules and trader visits were not exercised by the soak.
- **Static:**
  - no `create_timer`, `Engine.time_scale` or `get_tree().paused` in gameplay code;
  - only `UITimeScaleSelect` writes `TimeManager.paused`;
  - zero bare group literals;
  - all six `record_income` callers credit the returned net;
  - every non-consuming withdraw lands in a pile or overflow pile;
  - the three hour-long manager awaits only delay a shuttle's departure;
  - both self-bound `job_end` connections are `CONNECT_ONE_SHOT`.

### A. Confirmed bugs

**F1. Every pathfinding query leaks an object — confirmed.** `ModuleQueue` is `extends Object` ([`module_queue.gd:2`](../../../scripts/utility/module_queue.gd)), so it must be freed by hand, but [`ModuleGraph.pathfind_by_vertex`](../../../scripts/utility/module_graph.gd) (`:385`) and `pathfind_to_func` (`:503`) allocate one per call and never free it. The `QueueElement`s it still holds leak with it. In the soak, non-Node, non-Resource objects grew linearly by about **240 per sim-cycle (~1.2 MB)** and never plateaued, and they were all still leaked at exit, so they aren't held by anything. Changing that one word to `extends RefCounted` cut 24-hour growth from +364 to +93 objects and brought the exit leak back to the single-load baseline. Memory grows without bound for as long as pawns walk. **Fix:** `extends RefCounted`, plus a GUT suite for `ModuleQueue`, which has none.

**F2. A suit trip in flight at save time is orphaned on load, and the crew member makes a redundant airlock round-trip — confirmed.** `PawnSuitComponent._trip` is not saved ([`pawn_suit_component.gd:71`](../../../pawns/pawn_suit_component.gd)), but the `change_suit` job it points at *is* restored. [`SaveManager._adopt_if_need_job`](../../../scripts/managers/save_manager.gd) re-links restored jobs for eat/sleep/recreate/shop/recharge/repair/treatment, and WI-67 never added `change_suit`. So after the load the component sees no trip and posts a second one. R7's trace:
- the new trip suits the crew member up at t=7 s;
- the orphaned restored trip then runs at t=16 s, walking an already-suited pawn to an airlock and back (about 15 sim-seconds, roughly 1.5 working hours);
- health ended at 94.8, against 96.0 in the control run.

**Worse case, from reading the code and not reproduced:** if the restored job is *current* rather than queued when the component first re-evaluates, `interrupt_with_job` cancels it. `JobDriver_ChangeSuit.on_job_end` then calls `trip_refused()`, which nulls `_trip` — clearing the *new* trip's pointer. That allows a re-post on every 0.25 s slow tick, and the 6-second change at the rack would never finish. **Fix:** an `adopt_restored_trip(job)` hook wired into `_adopt_if_need_job`. Also make `trip_refused()`/`apply_change()` clear `_trip` only when the ending job *is* `_trip`.

**F3. Both module graphs leak their vertices on every scene teardown — confirmed.** `ModuleGraphVertex.edges` is `Dictionary[ModuleGraphVertex, EdgeData]` ([`module_graph_vertex.gd:9`](../../../scripts/utility/module_graph_vertex.gd)), so neighbouring vertices hold each other: RefCounted cycles. Edges are only erased in `remove_vertex`/`remove_edge`, and nothing clears either graph when `PathManager`/`StructureManager` are freed. So every load (`reload_current_scene`) and every Quit to Menu leaks the whole station graph twice. On the real quicksave that is about 320 objects per load; on the starter station it's about 35 per New Game. Clearing the edges in both managers' `_exit_tree` took the exit leak after two loads from 1,305 to 631 (a fresh boot is 583), and per-New-Game growth from +42 to +7 objects. **Fix:** a `ModuleGraph.clear()` that empties every vertex's `edges`, called from both managers' `_exit_tree`.

**F4. The Finance tab's "Net" line leaves out real spending — read from code.** [`finance_tab.gd:148`](../../../ui/windows/comms/finance_tab.gd) computes `gross_income - total_cost` from the ledger, but only operating flows reach the ledger. **Trade purchases** ([`trader_manager.gd:249`](../../../scripts/managers/trader_manager.gd), `credits.change_global_total(-amount * price)`), **raid payoffs** ([`raid_manager.gd:298`](../../../scripts/managers/raid_manager.gd)) and **hire fees** ([`crew_manager.gd:180`](../../../scripts/managers/crew_manager.gd)) all leave the balance unbooked, while trade *sales* are booked as income. A cycle that buys 6,000 cr of goods and sells 250 cr reports **Net +250** while the balance falls by 5,750. Construction, research, upgrades, cabs and robots are unbooked too, which is defensible as capital spending but should be a stated rule. **Fix:** book trade purchases, raid payoffs and hire fees through `record_external_cost` under their own categories, and either book capital spending as its own section or relabel the line "Operating net".

**F5. Two debug hotkeys are live in release builds — read from code.** F6 (`debug_fire_event`, [`event_manager.gd:61`](../../../scripts/managers/event_manager.gd)) fires a random event and F7 (`debug_offer_contract`, [`contract_manager.gd:65`](../../../scripts/managers/contract_manager.gd)) generates a contract, with no `OS.is_debug_build()` gate anywhere in the project. WI-58 deliberately keeps them out of the remap screen, which also means a player can't unbind them. Panku is already disabled on release; these aren't. **Fix:** gate both handlers on `OS.is_debug_build()`.

### B. Invariant violations / design debt

**F6. The script half of the UI drift guard was never automated.** `test_ui_theme.gd` sweeps scenes, but nothing sweeps scripts. About **40 geometry literals** have crept into console-UI scripts:
- `add_theme_constant_override("separation", 5/7/8/14)`, margins and `custom_minimum_size = Vector2(72/80/84, 0)`;
- the worst files are `build_menu.gd`, `inspector_panel.gd`, `finance_tab.gd`, `pawn_social_tab.gd`, `local_upgrades_tab.gd`, `workspace_tab.gd` and `pawn_needs_tab.gd`;
- plus ten raw colours in `minimap.gd`.

`new_game_setup.gd` (WI-59) has 25 literals and is **not** on `04_UI_Rework_Program.md`'s exemption list, because the list predates it. **Fix:** a script sweep in `test_ui_theme.gd` with an explicit allowlist of the world-space files and WI-36's menus. Then decide whether WI-59's setup screen joins the menus or the console.

**F7. "Keep everything typed" is unenforced: 98 violations in project code.** The three typed warnings sit at level 1 ([`project.godot:46-48`](../../../project.godot)), so they fail nothing. Raised to errors in the scratch copy, they found **238 unique violations in 52 files**: 88 unsafe method access, 61 unsafe property access, 58 untyped declarations and 31 missing return types. 140 of those are in vendored `assets/external/pixel_planets/` (`Star.gd` 88, `StellarObjectVisual.gd` 52). The remaining **98 are in project code across ~48 files**, led by `module_base.gd` and `preview_module.gd` (7 each), `pawn_job_tab.gd` (5), and `balloon.gd`, `turbolift_cab.gd` and `ui_storage_component.gd` (4 each). This is a lower bound, because a file that fails to compile hides violations in the scripts that depend on it. **Fix:** clear the 98, then raise all three to error (2) with `assets/external/` excluded.

**F8. Eight node-keyed dictionaries, all currently safe by pairing.** They are in `heat_manager.gd:54`, `atmosphere_manager.gd:27,31`, `structure_component.gd:32`, `path_component.gd:75`, `module_graph.gd:26`, `stores_panel.gd:59` and `crew_panel.gd:102`. Each is protected by unregistering in `_exit_tree`, by `remove_module` detaching neighbours before `queue_free`, or by a rebuild on `crew_departed` — and loads are a full scene reload. The two that iterate with a typed loop variable, [`heat_manager.gd:181`](../../../scripts/managers/heat_manager.gd) over a neighbour's `module_connections` and [`crew_panel.gd:601`](../../../ui/windows/crew_panel.gd), are the ones that crash the moment a pairing slips. **Fix:** convert those two to `get_instance_id()` keys when next touched, or amend the CLAUDE.md rule to name the unregister-on-exit pairing as the sanctioned exception.

**F9. The save-key stability pin misses the newest components.** [`test_component_save_contract.gd`](../../../tests/unit/test_component_save_contract.gd) lists 15 module and 9 pawn components, but not `HeatComponent` (`temperature`), `HeatEmitterComponent` (`target_f`) or `PawnSuitComponent` (`suited`, `hold_hours`). Add them.

**F10. The load path doesn't coerce types.** After one load of the real quicksave, `social.recent[].with/cycle/hour` are floats rather than ints, because [`socialize_component.gd:442`](../../../pawns/socialize_component.gd) appends the parsed dictionaries as-is. Nothing uses `with` as a dictionary key yet, but if anything ever does, `6.0` and `6` are different keys in Godot. **Fix:** coerce on load, like every other block does.

**F11. SignalBus has one dead signal and ten with no listener.** `special_path_connection_added` is declared and never emitted or connected. `ship_destroyed`, `pawn_skill_leveled`, `station_alert_raised`, `event_triggered`, `contract_offered/accepted/completed/failed` and `visitor_arrived/departed` are emitted but nobody listens. They may be intended as WI-47 mod hooks; if so, say so in `signal_bus.gd`, and if not, delete them.

**F12. `TurboliftCab._init` registers itself with `Global.path_manager`** ([`turbolift_cab.gd:105`](../../../modules/transport/turbolift_cab.gd)). Any instantiation outside a running game errors; R3 hit it, and so would a preview cache, a tool or a test. Move the registration to `_enter_tree`.

**F13. Asteroid rotation is never wrapped** ([`asteroid_base.gd:122`](../../../objects/asteroid_base.gd) accumulates `rotation_degrees`; it reached 3,457° on the quicksave). It drifts by one float32 ulp on every save/load, which R4's diff caught. It's cosmetic and harmless at any realistic game length, but it's the only non-idempotent value in the whole save. **Fix:** `fposmod(..., 360.0)` on save.

**F14. A module saved mid-deconstruction finishes deconstructing on load.** [`construction_component.gd:250`](../../../modules/components/construction_component.gd) collapses Deconstructing → Deconstructed, so the remaining teardown work is skipped. It's documented as the mirror of Constructing → NotStarted, but it isn't a mirror: construction keeps its progress, while deconstruction completes. It's a minor save/load shortcut.

**F15. [`crew_manager.gd:272`](../../../scripts/managers/crew_manager.gd) calls `shuttle.depart()` after a sim-hour await with no `is_instance_valid` guard.** Its twin in `visitor_manager.gd:168` has one.

### C. Hygiene

**F16. Six Godot editor temp files are tracked in git:** `main.tscn22649915396.tmp`, `modules/core/hallway.tscn5672602772.tmp`, two `modules/templates/module_base.tscn*.tmp`, `modules/transport/module_airlock_right.tscn*.tmp` and `data/modules/module_airlock.tres*.tmp`. `git rm` them and add `*.tmp` to `.gitignore`.

**F17. Stale comments.** Five places still describe JobBase as coexisting with Job, which CLAUDE.md tells readers to ignore; they should be deleted instead:
- `job_data.gd:14-15`;
- `slot_pool.gd:13`;
- `job_driver.gd:33,40`;
- `workspace_component.gd:7`;
- `job.gd:707`.

Separately, `global.gd:266` says `NON_REMAPPABLE_ACTIONS` holds "the AIDE key", but WI-63 made AIDE remappable.

**F18. Carried-forward items, re-checked.**
- **B4 is closed** (`SAVE_VERSION` is 3 and two migrations exist).
- **B5 is still open** (`world_manager.gd:196-199` reads `module.module_data` after `queue_free`).
- **B6 is still open** (the empty `_process` at `world_manager.gd:66`, and commented-out code at `storage_component.gd:296`, `module_turbolift.gd:158` and `pawn_base.gd:378-382`).
- **C8 is still open** (`capacitator` in `power_consumption_component.gd:5`).
- **C11 is still open** (the `result.has()` dedupe at `world_manager.gd:298`).
- A stray `print("Trader departing…")` remains in `trader_manager.gd`, along with four `print`s in `module_turbolift.gd`.

**F19. Coverage gaps.** `ModuleQueue` (where F1 lived), `ModuleGraphVertex` and `PawnOpinion` have no suite. GUT also leaks about 1,000 objects at exit, from tests that don't `autofree`.

**F20. CLAUDE.md is stale.** It says "86 suites, 1624 tests"; the real figures are 89 and 1,672.

**Bundled as [[WI-68_Audit_Fix_Pass]]** (drafted 2026-09-18): F1–F7, F9, F10, F12, F13 and F15–F18. F8, F11, F14 and F19's `PawnOpinion` suite are deliberately left out, with the reasons recorded there.

## 2026-09-18 second-pass audit (post-WI-68 stage 4)

*A second read of the whole codebase, done after WI-68's stages 1–4 and 3b landed and before stages 5–6. The first pass ran every CLAUDE.md rule that can be expressed as a grep plus seven runtime probes; this pass deliberately took a different lens - lifecycle contracts between owners and the jobs they post, the load path's re-linking, `await` across frees, `Global`'s slots across scene swaps, and undeclared vocabularies - on the theory that a second pass with the same method finds the same things. Findings continue the numbering as **F25–F37**. The structural half of this pass is a separate document, [[05_Architecture_Review]]; the findings below are the concrete defects it argues from. As before, **confirmed** means reproduced (here: a throwaway GUT probe, deleted after the run); everything else is read from code, with the mechanism traced to the line.*

**Verified clean (second pass), so the next one needn't redo it:**
- the money loop after F4: all three booking flows, the levy skim, loans, refunds, severance, insolvency (`economy_manager.gd`), and trade fulfilment's cargo/room/affordability clamps;
- `AlertManager`'s pause latch re-derives from the live queue and releases in `_exit_tree`, so no acknowledge path can leak a hold;
- the save-section registry (static, replace-by-id, `is_live()`-pruned) and `Job.restore`'s signature check;
- `ClaimRegistry`'s release paths, `JobTarget`'s handle discipline, and `SaveManager`'s five `*_ref` helpers after 3b;
- heat and atmosphere both process each unordered pair once and conserve exactly;
- `PawnSuitComponent`'s state machine reads correctly (and R7 already ran it live);
- the `_process` handlers in gameplay code all early-return on `scale(delta) <= 0`, and no gameplay file uses `create_timer`.

### A. Confirmed bugs

**F25. A construction site whose build job ends INTERRUPTED never recovers — confirmed (GUT probe, three tests, deleted after the run).** [`construction_component.gd:155-158`](../../../modules/components/construction_component.gd) and `:193-199` reset the site only when `finished_job.is_failed()`, and `is_failed()` is exactly `outcome == FAILED`. `PawnBase.interrupt_with_job` ends the running job with `cancel(false)`, which is `Outcome.INTERRUPTED` (`job.gd:368`). Three things interrupt a crew member's job that way: resignation or firing ([`crew_manager.gd:369`](../../../scripts/managers/crew_manager.gd)), a Tier-2+ suit-up on the way to the site ([`pawn_suit_component.gd:269`](../../../pawns/pawn_suit_component.gd) — WI-67 made it interrupt *any* job on purpose), and the breathing flee (idle jobs only, so not this one). After any of them the site sits in `Constructing` with `construction_job` pointing at an ended job; the `Constructing` branch of `_process` (`:75-79`) only checks work seconds, `NotStarted` is never re-entered, and nothing re-posts. The blueprint is stuck until a save/load collapses it back to `NotStarted` (the F14 shortcut, doing something useful for once). Deconstruction has the same hole. The probe: `end(FAILED)` resets state and pointer; `end(INTERRUPTED)` leaves both. Every other owner in the game - `ProcessorComponent._ensure_work_job`, `ModuleBase._on_durability_slow_tick`, `MedicalComponent._on_slow_tick`, `ResourcePile._ensure_collection_job`, storage's `_on_posted_job_end` - asks `is_ended()`; construction is the only `is_failed()` consumer in the codebase, and that is the whole bug. **Fix:** `if not finished_job.is_finished()` in both handlers (ended is implied by `job_end`), plus a belt-and-braces check in the `Constructing` branch that an ended pointer drops the state back to `NotStarted`. The three probe tests become the regression test. This is the same class as F2: an owner reasoning about a job outcome with the wrong predicate.

**F26. Module-side job owners are never re-linked to the job a load restores, so every load posts a duplicate — read from code; two dead hooks are the evidence.** [`SaveManager._adopt_if_need_job`](../../../scripts/managers/save_manager.gd) (`:1147-1171`) re-links restored jobs to their *pawn-side* owners only (needs, robot power, robot integrity, disease, suit). The six *module-side* owners that remember a job they posted get nothing: `ConstructionComponent.construction_job`, `ProcessorComponent._work_job`, `ModuleBase._repair_job`, `MedicalComponent._doctor_job`, `StorageData.import_job`/`export_job`, and `ResourcePile.active_jobs`. `ModuleBase.adopt_repair_job()` ([`module_base.gd:413`](../../../modules/templates/module_base.gd)) and `MedicalComponent.adopt_doctor_job()` (`medical_component.gd:119`) both exist, both say "for a restored job", and **neither has a caller** - the wiring was designed and never done. What each owner does after a load with the restored job resumed on its pawn:
- **construction:** the site restores as `NotStarted`, `ready_for_construction()` is true, so a second `construct_module` goes on the board and two crew build one site (double work rate);
- **manned processor:** `_work_job` is null, so a second `work_processor` is posted; `JobDriver_WorkProcessor.can_do` does not check the operator slot, so a free pawn claims it, walks to the machine, `Action_ClaimSlot` fails on the capacity-1 pool, the job FAILs, `_work_job` clears, and it is re-posted next frame - a walk-and-fail loop for as long as the restored operator keeps chaining batches;
- **repair:** a second `repair_module`, invalidated once `needs_repair()` is false - one wasted trip;
- **doctor:** a second `doctor` job;
- **storage:** a restored haul saved before its RESERVE step holds no reservation, the posting scan's deficit doesn't see it, and a second haul is posted for the same units (the reservation checks stop an overfill, not the trip);
- **piles:** `_load_piles` → `add_stacks` posts a fresh `collect_pile` (`:1013`) while the restored one resumes; the pile's own `reserve()` stops the double-booking, so the second pawn arrives to nothing and fails.

[`storage_component.gd:743-745`](../../../modules/components/storage_component.gd) still says "import/export jobs are deliberately NOT saved: jobs aren't persisted" - false since WI-21, and the reason nobody looked here. F2 was one member of this class; the class is open on the other side. **Fix:** make re-adoption generic rather than extending the if-chain: on restore, `Job` offers itself to each set target's component through a duck-typed `adopt_restored_job(job)` (the same shape as the claimable contract), `StorageData` and `ResourcePile` implement it for their kinds, and the pawn-side owners take the same hook so `_adopt_if_need_job` is deleted. **Verify** in a scratch copy on a save with a site mid-build, a manned processor mid-batch and a repair in flight: after the load `JobManager.board_size()` shows no second job for any of them, and no pawn walks to a machine and fails.

**F27. `AlertManager` resolves a module's alerts on `module_destroyed` only, never on `module_removed`.** [`alert_manager.gd:412, 501-503`](../../../scripts/managers/alert_manager.gd). Deconstruction ends in `remove_module(owner_module, false)` (`construction_component.gd:91`) with no `module_destroyed` - that signal fires only from `_on_hp_zero`. So a deconstructed module's breakdown, low-O2, cut-vertex and breach rows stay in the feed with a freed subject: JUMP goes nowhere, and an unacknowledged HIGH stays until CLEAR ALL. Pawn-subject alerts have the same gap: `_on_crew_departed` (`:451`) resolves only `resigning`, so a departed crew member's need-critical and suit-up rows linger. Both feed `AlertRules.make_id(family, subject)` a freed object, which is on F24's list. **Fix:** resolve on `module_removed` (a superset) and on `crew_departed` for the pawn families; or have `sweep()` drop any row whose subject is no longer valid, which covers every future case at once.

**F28. The door behaviours' cancel signal is dead plumbing, and a module freed mid-hook latches the pawn's `_busy_in_hook` — read from code.** [`PathBehaviorContext.cancelled`](../../../scripts/pathing/path_behavior_context.gd) is filled by `ModuleBase.path_exit` (`module_base.gd:725`) and read by neither `Behavior_SlidingDoor` nor `Behavior_LinkedDoors`; `path_enter` doesn't forward it at all. Both behaviours `await Global.time_manager.sim_seconds(...)` and then touch the door sprite. If the module is destroyed (a raid) while a pawn is inside its door hook, the coroutine resumes on a freed node (script error), the awaiting chain in [`PawnMovementComponent.reached_next_node`](../../../pawns/pawn_movement_component.gd) (`:275-277`, `:296-298`) never completes, and `_busy_in_hook` stays true for the life of the pawn. `is_traveling()` (`:138`) then answers true forever, and two things read it: `PawnStatus` (`pawn_status.gd:347`, the roster sentence) and `RobotPowerComponent` (`robot_power_component.gd:84`, the moving-drain rate). Movement itself recovers - `module_removed` calls `run_pathfinding` and a second `move()` coroutine takes over - which is why nothing visibly sticks. WI-20 turned rides into an explicit state precisely to stop suspended coroutines owning a pawn; doors are the last place one does. **Fix:** a `DOOR_WAIT` movement state with a sim-time timer instead of an await, and delete `cancelled`. Interim: `is_instance_valid(module)` after every await in the two behaviours, and clear `_busy_in_hook` in `module_removed`.

### B. Invariant violations / design debt

**F29. `Global`'s manager slots are never cleared, and 218 `== null` / `!= null` guards test them (20 use `is_instance_valid`).** [`global.gd:5-46`](../../../scripts/managers/global.gd) holds 30 typed slots; every manager writes its own in `_ready` and none clears it in `_exit_tree`. After Quit to Menu every slot names a freed node, and `freed == null` is false. Nothing fires today because the menus reach only `Global.settings`, difficulty and the staging fields (verified: `ui/menus` touches no manager slot outside the in-game pause menu). But the guards in `data/` are wrong the moment a menu screen asks a data class a question: `module_data.gd:126` (`is_unlocked`), `local_upgrade_data.gd:49`, `condition_min_tier.gd:18`, `condition_disease_unlocked.gd:9` all test `Global.unlock_manager == null` and then call into it. A "preview your starting station" screen, or a mod's menu, would be the first to trip it. **Fix:** each manager nulls its slot in `_exit_tree` (one line each), then a GUT source sweep for `Global\.\w+ (==|!=) null` in the F24 sweep's family. **Rule:** a `Global` manager slot is live or null, never freed.

**F30. Stat names are an undeclared vocabulary.** `StatModifierSpec.stat` and `StatModifierEffect.stat` in `.tres`, `get_effective_stat(&"…")` and `set_single_modifier(&"…")` in code, together name seventeen stats - `process_time`, `mining_rate`, `power_output`, `traversal_speed_mult`, `breakdown_chance`, `scrub_rate`, `o2_release_rate`, `sleep_quality`, `shield_radius`, `shield_charge_rate`, `shield_capacity`, `hotel_rate`, `hotel_mood`, `robot_speed`, `robot_capacity`, `logistics_max_robots`, `conveyor_lanes` - as free-form StringNames with no constants file and no sweep (`module_base.gd:331-334, 364-366`; the per-component `STAT_*` consts cover five of them). A typo in an upgrade's `.tres` is an upgrade that costs credits and does nothing, silently - the failure the ledger-category rule (F4), `StoryFlags` and `TutorialTriggers` were each introduced to prevent. **Fix:** `scripts/utility/stats.gd` in the `Groups` style, code reads through it, and a content sweep over `data/unlocks/**` and `data/local_upgrades/**` asserting every `stat =` is declared (the `test_event_content` shape).

**F31. `assert()` is the only guard on four content or setup invariants, and asserts are stripped from release exports.** [`storage_component.gd:110`](../../../modules/components/storage_component.gd) (OUTPUT slots with zero `output_capacity` - the real WI-65 defect it was written after), `processor_component.gd:116-119` (null recipe/storage/power), `:264` (a recipe naming a resource as both input and output), `mining_component.gd:40-41`. In a release build a modded or hand-edited scene with any of these ships silently; the processor later null-derefs, the storage holds nothing and says nothing. **Fix:** content-shaped checks go in the GUT content sweep (R3 already instantiates every scene) with `push_error` + degrade at runtime; keep `assert` for the two genuine internal can't-happens (`processor_component.gd:386, 452`).

**F32. `JobManager.find_job` cancels an invalid job while indexing the queue it is iterating** ([`job_manager.gd:74-79`](../../../scripts/managers/job_manager.gd)): `cancel(true)` emits `job_end` *before* `remove_at(cursor)`. A listener that re-posts synchronously - `ResourcePile._on_job_end → _ensure_collection_job → add_job`, `ConstructionComponent._on_deconstruction_job_end → add_job` - inserts into the same array by bsearch and shifts the element under the cursor, so a *valid* job is removed from the board and the invalid one stays; its poster then waits forever on a job nobody holds. Neither path is reachable in that state today (the pile branch needs `get_available > 0` on a job invalid for having none; the deconstruct listener dies with its component), so this is a fragility rather than a defect - but nothing says a `job_end` listener must not `add_job` synchronously, and F26's fix is exactly the kind of change that would. **Fix:** `remove_at` before `cancel`, or collect the invalid jobs and cancel them after the scan.

**F33. `PathManager` and `StructureManager` bind a UI node by relative tree path** (`@onready var ui_in_game: UIInGame = $"../../ForegroundLayers/UiInGameLayer/UiInGame"`, [`path_manager.gd:4`](../../../scripts/managers/path_manager.gd), `structure_manager.gd:4`). PathManager writes debug paths into it (`:136-139`); StructureManager's is unused. A simulation manager that depends on the HUD's position in the tree is the layering running backwards, and it is the first thing a headless sim fixture (see the architecture review) would have to stub. **Fix:** delete StructureManager's; PathManager's debug output goes through `Global.ui_in_game` behind `is_instance_valid`, or a signal.

**F34. Cancelling a never-built blueprint forfeits its credit cost - a design gap, not a bug.** `purchase_and_add_module` ([`world_manager.gd:107-119`](../../../scripts/managers/world_manager.gd)) withdraws credits at placement; `remove_module` on a blueprint returns the delivered materials to a pile (`module_base.gd:609-621`) and returns no credits. D4 (refunds on *deconstruction*) is open by design; a blueprint cancelled a second after placement is a misclick tax with no rule stating it. Decide and document; `record_refund` now exists if the answer is a refund.

### C. Hygiene

**F35. Stale or commented-out code the second pass tripped on** (the B6 class, beyond F18's list): `storage_component.gd:743-745` (the "jobs aren't persisted" comment above); `:342-400` and `:841-847` (five commented-out legacy bodies); `slot_pool.gd:13-16` (already F17's); `turbolift_cab.gd:113, 117-126` (a commented-out `module_removed` handler - which is also F28's missing piece); `world_manager.gd:10, 26, 320-328`; `structure_manager.gd:34-51`; `pawn_base.gd:419-423, 595-598`; `pawn_movement_component.gd:190-195, 233-243`.

**F36. `UnlockManager.suits_mandatory()` `push_warning`s on every call when the tier has no data** ([`unlock_manager.gd:147-152`](../../../scripts/managers/unlock_manager.gd)). It is called per slow tick per crew member and per tick by `AtmosphereManager`, so a missing tier `.tres` floods the log at ~40 lines a second. Warn once.

**F37. Five per-frame countdowns that the "periodic work goes on `slow_tick`" rule would put on the tick:** `CrewManager._process` (the pending-hire clock), `TraderManager._process` (the visit clock), `EventManager._process` (happiness-effect countdown), `MiningComponent._process` (respawn timer), `VisitorPawn._process` (stay timer). Consistency, not cost.

**Suggested bundling:** F25, F26 and F32 are one item (the job-ownership contract, argued in [[05_Architecture_Review]] §A2); F27, F28 and F29 are one item (reference hygiene, §A6); F30 and F31 are one item (declared vocabularies and content sweeps); F33–F37 are a cleanup commit in WI-68's stage-6 shape.

---

*Re-audited 2026-07-22 against the post-WI-37 codebase (~30k lines of GDScript across 243 scripts, 58 GUT suites / 342 tests). The previous pass was 2026-07-13, before WI-01; almost everything in it has since been fixed, so this is a rewrite rather than an edit. Section E records what closed.*

*Findings below come from reading the code; only A8 had been reproduced in-game. Severity ordering is my judgement of player impact. Fixes for the section A list were bundled as [[WI-38_Bug_Fix_Pass_2]], **completed 2026-07-22** — the whole of section A is now closed and recorded in section E. The entries are kept below for the reasoning trail.*

---

## A. Confirmed Bugs — ALL FIXED by [[WI-38_Bug_Fix_Pass_2]]

### A1. Blueprint turrets fire (and draw full power)

`WeaponComponent._process` ([`weapon_component.gd:76`](../../../modules/components/weapon_component.gd)) has no build-state gate. Every sibling combat component gates on `ready_constructed` — `ShieldComponent` only joins the `"shield"` group there (`shield_component.gd:36`), which is what keeps unbuilt bubbles out of `RaidManager.try_shield_absorb`. The turret has no equivalent.

`laser_turret_mdata.tres` sets `instant_build = false`, so a turret spends real construction time as a blueprint. During that window it targets, deals `effective_damage()`, and flips its power draw to `active_power_consumption`. A player under raid can drop turret blueprints and get free defense.

**Fix:** early-return in `_process` unless `owner_module != null and owner_module.is_complete()`.

### A2. Shield capacitors are not saved

`ShieldComponent` has no `get_save_data()`, and `ModuleBase.get_save_data()` ([`module_base.gd:407`](../../../modules/templates/module_base.gd)) has no shield key. `_charge` and `_online` are pure runtime state, so `ready_constructed` re-seeds every bubble to `initial_charge_fraction` (1.0 by default) on load.

This defeats the stated WI-32 design goal: `RaidManager`'s header says a mid-raid save "restores the whole fight so you can't save-scum out of the threat" (`raid_manager.gd:12-14`) — and it does restore the ships, their HP, and the payoff discount. But the *defenses* come back better than they were. Quick-save/quick-load during a raid is a full shield recharge.

**Fix:** a `shield` block in the module save data, same shape as `sustenance`/`shop`. `WeaponComponent._fire_cooldown` has the same gap but is a sub-2-second effect, not worth a key.

### A3. Calendar signals replay on load without an `is_loading()` guard

`TimeManager.load_save_data` deliberately emits `cycle_changed` + `hour_changed` after writing the fields directly, to re-sync listeners (`time_manager.gd:168-171`). Two managers know this and guard:

- `EconomyManager._on_cycle_changed` — `if SaveManager.is_loading(): return` (`economy_manager.gd:197`)
- `UnlockManager._on_cycle_changed` — same (`unlock_manager.gd:298`)

Three do not:

- ~~**`EventManager._on_cycle_changed`** calls `_roll_midcycle_hour()` and `_natural_roll()`. **Loading a save can immediately fire a random event** — and it fires *before* `EventManager.load_save_data` restores the manager's own state.~~ **Fixed by [[WI-62_Dialogue]]** (2026-08-22). Both the natural roll and WI-62's new scheduled-event drain now gate on `SaveManager.is_loading()`. It was a stray card before; with event chaining it could drop a chapter-two event into a save that never saw chapter one, which is what made it worth fixing rather than continuing to log.
- `MarketManager._on_hour_changed` (`market_manager.gd:27`) ages every supply modifier by an hour and drifts all prices. Harmless *today* only because the market section loads afterward and overwrites it.
- `ContractManager._on_cycle_changed` (`contract_manager.gd:197`) walks `active` for expiries. Harmless *today* only because `active` is still empty at that point in the section order.

Two of the three are load-bearing on section ordering that isn't documented as load-bearing.

**Fix:** guard once at the source rather than N times at the listeners — either skip the emissions in `TimeManager.load_save_data` while `SaveManager.is_loading()`, or emit a distinct `calendar_restored` signal that only genuine re-sync listeners (clock UI) subscribe to.

### A4. Autodump destroys reserved stock

`StorageComponent._on_slow_tick` dumps `stored - desired` when `autodump` is on (`storage_component.gd:164-167`), and `destroy_resource` goes straight to `data.withdraw_stacks(...)` (`storage_component.gd:238`) without consulting `reserved_withdraw` — unlike every other withdraw path, which routes through `StorageData.can_withdraw`.

So a hauler already walking to that bin with a live withdraw reservation arrives, gets `[]` back from `complete_withdraw_job`, and cancels (`job_get_resource.gd:187`). Reservations *do* reconcile correctly (the cancel path is clean, so the invariant holds), but the trip is wasted and the player sees haul jobs silently fail near an autodump bin.

**Fix:** dump `stored - desired - reserved_withdraw`.

### A5. `Job_StoreInventory` ignores storage priority

`_find_closest_import_storage` (`job_store_inventory.gd:129`) selects purely by squared distance. Its sibling `Job_GetResource._find_deposit_storage` (`job_get_resource.gd:148`) selects by priority-then-distance.

Since storage priority *is* the routing language, a pawn sweeping leftover cargo can dump it into whatever bin happens to be nearest — including a construction site's +99 import bin or a deconstruction site's −99 export bin — after which the material has to be hauled straight back out. This is exactly the drift the 2026-07-13 pass predicted when it flagged the four near-identical query loops (old C6); the loops have now genuinely diverged.

**Fix:** fold both into one query helper (see C5) and give the sweep the same priority preference.

### A6. `game_loaded` always reports the wrong slot

`SaveManager._apply_pending_load` ends with `game_loaded.emit(QUICK_SLOT)` (`save_manager.gd:618`) — hardcoded to `"quicksave"` regardless of which slot was actually staged. `stage_load` never records the slot name anywhere it survives the scene swap. Any listener keying off the slot argument is wrong for every menu load.

**Fix:** stash the slot alongside `_pending_load` in the static, emit that.

### A7. Unguarded cast in the storage sweep

`job_store_inventory.gd:135` reads `storage.accepts_imports` directly off `node as StorageComponent` with no null check. Its three siblings all check (`job_get_resource.gd:126`, `:152`, `job_collect_pile.gd:125`). Anything ever added to the `"resource_storage"` group that isn't a `StorageComponent` is an immediate nil-access crash here and nowhere else. Low likelihood, trivial fix, worth the consistency.

### A8. Verified: New Game after Quit to Menu inherits the previous run's global totals

`ResourceData.global_total` is mutable runtime state living on a shared `.tres` (`resource_data.gd:19`; see B3). Nothing zeroes it on a new game — `Main._ready` only calls `spawn_starting_station()`, and `SaveManager._load_resources` only writes it on the *load* path.

Godot's resource cache holds `credits.tres` across the scene swap, so the mutated total survives. **Reproduced 2026-07-22:** new game → `Global.cheats.add_credits(50000)` → Quit to Menu → New Game → the new run starts with the old run's credits. Applies to every `has_global_store` resource. WI-36 made this reachable for the first time by adding Quit to Menu → New Game inside one process.

**Fix:** separate the authored seed (`starting_global_total`, exported) from the runtime value (`global_total`, plain var — which also closes B3), and reset every resource in `SaveManager._ready()` before the station spawns. See [[WI-38_Bug_Fix_Pass_2]].

---

## B. Design-Debt / Known-Disabled Code

### B1. `can_remove_module` still disabled - FIXED

~~`WorldManager.remove_module` still has the structure check commented out with the same TODO (`world_manager.gd:152-155`): under-construction modules aren't structure-connected, so the check fires constantly. Unchanged since the first audit — this has now been off for the project's entire life.~~

~~Note the scope has shrunk: WI-32's `ModuleBase._on_hp_zero` calls `remove_module(module, false)`, which bypasses the check anyway. Re-enabling it would only affect player-initiated deletes. Either fix the connectivity accounting for blueprints or delete `can_remove_module` and the `structure_check_before_delete` flag, so the codebase stops implying a feature that doesn't exist.~~

### B2. Power scans — *fixed by WI-39*

~~The per-frame scan is gone; `PowerManager` runs on `slow_tick` now with the sim-seconds interval threaded through correctly. What's left is cleanup: three `get_nodes_in_group` scans per tick (see C4), plus dead `power_generators`/`power_consumers` array fields and a block of commented-out `node_grouped`/`node_ungrouped` hooks that describe a caching design that was never built.~~

Closed by WI-39: the three arrays are now real and populated by explicit registration, the group scans are gone, and both halves of the `node_grouped`/`node_ungrouped` sketch (in `power_manager.gd` and `signal_bus.gd`) are deleted.

### B3. Runtime state `@export`ed on shared resources — *fixed by WI-38*

~~`ResourceData.global_total` is where the player's credit balance lives, and `cached_total` is a derived cache. Both are `@export`ed on `@tool` resources shared engine-wide — confusing in the inspector, a save/load foot-gun, and the direct cause of A8.~~

Closed alongside A8: the authored seed is now `starting_global_total` (the only exported one), `global_total` and `cached_total` are plain vars, and `SaveManager._ready` reseeds them on entry to the game scene.

### B4. `SAVE_VERSION` has never left 1

`save_manager.gd:15` has read `1` through WI-22, -24, -25, -26, -27, -28, -29, -31, -32, -33, -36 and -37, every one of which changed the format. The "missing keys default sensibly" convention has genuinely held — but the consequence is there's no way to *reject* a save that's too old to be sane, `_migrations` is empty, and the migration path has never been exercised even once.

Worth bumping at the next actually-breaking change and writing the first migration, if only to prove the machinery works before it's needed under pressure.

### B5. Use-after-`queue_free` ordering in `remove_module`

`world_manager.gd:170-173` calls `module.queue_free()` and then reads `module.module_data` and `module.module_cell` to decide on truss replacement. This works — `queue_free` defers to end of frame — but it's the kind of ordering that breaks silently if anyone ever swaps it for `free()`. Capture what's needed before the free (as the function already does for `replacement_location` and `replacement_points`) and move the call to the end.

### B6. Commented-out code accumulating in hot files

`storage_component.gd:130-146` and `:250-259`; `world_manager.gd:294-302`; `module_base.gd:578-586`. Also empty-but-defined `_process` handlers that still cost an engine call per frame: `world_manager.gd:65-66`. Git has the history — delete these. (The `power_manager.gd` block and its `signal_bus.gd` counterpart are gone — WI-39.)

---

## C. Improvement Suggestions (code)

*Numbering continues the original list; items 1, 2, 3, 6(part), 7 are done and moved to section E.*

**C4. Cache power group membership.** — *done by [[WI-39_Power_Registry]], 2026-07-22.* ~~Three `get_nodes_in_group` calls per slow tick. The commented-out `node_grouped` hooks show the intended design. Maintaining arrays on `ready_constructed`/`_exit_tree` also gives a natural home for per-module power priorities later (life support browns out last). Scoping this also turned up an **unsaved-state bug**: `BatteryComponent.total_power_stored` has no save key, so every battery reloads empty — same class as A2, missed because that pass audited combat components. Folded into the same WI.~~ See section E.

**~~C5. One storage-query helper.~~** **Done — [[WI-40_Storage_Query_Helper]].** The four scanners are now two static queries in `scripts/utility/storage_query.gd`: `StorageQuery.find_source(pawn, resource, trip_cap, below_priority)` and `find_sink(pawn, resource, above_priority)`, with `ANY_PRIORITY` as the explicit "no filter" sentinel the pile and the sweep pass. Priority semantics, the strictness rationale, the sweep asymmetry, and the null-in-group guard are each stated once. Per-resource indexing on `ResourceData.registered_storage` is now a one-function change and is deliberately still open (see 01_Technical_Specification §2.3).

**C8. Naming.** `sort_priority_decending` is gone. `capacitator` → `capacitor` remains (`power_consumption_component.gd:5`).

**~~C9. A `Groups` constants file.~~** **Done — [[WI-41_Group_Constants]].** `scripts/utility/groups.gd` holds 22 `const NAME: StringName = &"name"` entries grouped by owner, and every group-API call site in `.gd` now goes through one. Zero bare group literals remain outside `addons/`. Two things the conversion turned up: `container_required` is entirely addon-internal (`addons/collapsible_container/`) so it never earned a constant, and four groups — `processor`, `turbolifts`, `teleporters`, `stairs` — are joined but scanned by nothing; they kept constants with a comment saying so rather than being deleted silently. `airlock` stays duplicated in the two airlock `.tscn`s by necessity and its constant names them.

**~~C10. Turrets should read `RaidManager._ships`, not scan the tree.~~** **Done — 2026-08-03.** `RaidManager.live_ships()` exposes the wave array and `WeaponComponent._pick_target` iterates that instead of `get_nodes_in_group(Groups.PIRATE_SHIP)`. The accessor hands back the manager's own array rather than a copy — a defensive duplicate would reintroduce the per-turret-per-frame allocation the item is about — so it is documented read-only, and callers still `is_instance_valid` each entry because a ship can be freed before `_check_end` filters it out. `RaidManager` is the only thing that ever instantiates a `PirateShip`, so the array and the group had identical membership; the one behavioural difference is that a ship `queue_free`d by a mid-raid load is no longer briefly targetable while it waits out the frame, which is the better answer. The `pirate_ship` group stays — the minimap still reads it to colour hostile contacts. `_ensure_outward`'s module walk was already cached per raid and is untouched.

**C11. `get_built_modules` is O(cells²).** `world_manager.gd:265-274` dedupes with `result.has(module)` while iterating every cell entry. Called from `RaidManager.compute_strength()`. Irrelevant at current station sizes; swap the linear `has` for a seen-dictionary when it isn't.

**~~C12. `PreviewModule` instantiates a whole module scene per preview update.~~** **Done — [[WI-42_Preview_Metadata_Cache]].** The twelve read values now live in a `ModulePreviewData` inner class, cached in a `Dictionary[PackedScene, ModulePreviewData]` owned by the `PreviewModule` node (an instance member, not a static — it dies with the scene rather than holding every previewed `PackedScene` alive across a Quit-to-Menu boundary, per the A8 lesson). Keying on `PackedScene` rather than `ModuleData` gets flippable modules right for free. One instantiate per distinct scene per session: 47 across the 45 buildable modules. Also fixed a live crash found while verifying — `update_from_module_data` had no null guard on `module_data`, so pressing `flip_module` with nothing selected threw.

**~~C13. `force_withdraw` and `change_global_total` aren't symmetric.~~** **Done — [[WI-52_Vitals_And_Ledger]].** `force_withdraw` now ends in `_recalc_resource(true)` on both its branches, so it recalcs and emits `total_changed` exactly as `change_global_total` does. The lag was cosmetic while credits were one tile in a seventeen-tile strip; WI-52 makes credits a first-class vital chip, which would have put a quarter-second of stale on the most-watched number on screen. The chip is driven by `total_changed` rather than by the strip's refresh timer precisely so the fix is what makes it immediate.

~~**C14. Severance ignores the difficulty dial.** `EconomyManager.wage_for_pawn` runs through `scaled_cost(..., upkeep_multiplier())` (`economy_manager.gd:245-248`); `severance_for` does not (`:382-385`). Possibly deliberate, but it makes severance the only recurring-crew cost the WI-37 multiplier doesn't touch, and nothing says so.~~ Note: Severance is not recurring.

Fixed:
~~**C15. Raid outcome messaging is wrong for mixed outcomes.** `RaidManager._check_end` (`raid_manager.gd:190-203`) only reports `repelled` when `_destroyed_count == 0`. Kill three ships, let two flee, and the player is told "every hostile destroyed." Cheap fix, and it's the last thing the player reads about a fight they just spent five minutes on.~~

---

## D. Design Suggestions & Elaborations

**D4. Module removal refunds.** *(carried forward, still open)* Deconstruction returns 100% of materials. More interesting now that WI-25's economy is live and there's a real reason to want a lossy build/rebuild loop.

**D5. Teleporter.** *(carried forward, still open)* The module and its behaviors exist; the "does it need its own storage buffer for resource transfer" question is still unanswered. Suggestion stands: pawn-only shortcut group first (already supported by `ModuleGraph` vertex groups), resource teleportation as a separate late-game unlock.

**~~D7. Finish WI-12 (Storage QoL) deliberately.~~** **Done 2026-07-19** — though it landed the way this item warned against: by accretion rather than as a designed pass, which is exactly how the autodump slice shipped without the reservation check that became **A4**. What's in: the accepted-resource checklist, per-resource desired amounts, priority editing via `update_priority()`, dump-with-amount behind a confirmation, and a saved per-resource `autodump`. Two designed tasks were dropped — the `draining` flag (unchecking a stocked resource dumps to the module's overflow pile instead of draining in place through normal export hauls) and the trade-panel mass-sell button. Both are recorded in [[01_Technical_Specification]] §2.1; neither loses resources, so neither is a bug. The remaining complaint was presentational — every one of these controls was reachable only one module at a time — and [[WI-56_Panels_Crew_And_Stores]]' Stores panel closed it on 2026-08-11, surfacing all of them without touching the mechanics. It also found the sibling of **A4** on the other side of the same feature: the *manual* dump capped at `stored` and withdrew with `use_reserve = true`, so it deleted stock a hauler had already claimed and quoted an amount it could not honestly vent. Both halves of "dump" now respect `reserved_withdraw`.

**~~D8. Audit for unsaved stateful systems.~~** **Done — [[WI-45_Save_System_Audit]], 2026-07-30.** See section E.

~~**D9. Decide on `structure_check_before_delete`.** See B1. Either the connectivity accounting gets fixed for under-construction modules, or the flag, `can_remove_module`, and the commented block all get deleted. Leaving a disabled safety check in place for three phases is worse than either.~~ Fixed

---

## E. Resolved Since the 2026-07-13 Pass

Recorded so the history isn't lost:

- **Click-drag placement could split the station in two** — fixed 2026-08-23. Dragging a line of truss rightwards from the starting module past the docking bay built everything on both sides of the bay: the cells over the bay were refused (its approach column blocks building) and the cells past it were placed anyway, leaving an island the station could never reach. A drag judged every cell on its own and skipped the ones the world refused, and the four multiplaceable modules all carried `ignore_multiplacement_connection_check` on top of that, which turned the connection test off entirely for a drag. The flag existed for a real reason — a module halfway down a drag genuinely is touching nothing yet, because it is held up by the modules queued in front of it — but that assumption is only true while every module in front of it is actually built. **A drag is now judged as one line** (`MultiplacementPlan`, `scripts/utility/multiplacement_plan.gd`, pure + 20 GUT tests): each candidate is *anchored* (touches built structure) or *linked* to its neighbours in the drag, and only what chains back to an anchor is built. The flag is deleted from `ModuleData` and the four `.tres`. Two things fell out of it. (a) **The build order is breadth-first from the anchors, not along the drag** — so any prefix of it is a connected station, and a drag that runs out of credits partway truncates the chain instead of stranding the far end (dragging *towards* the station used to spend the money on the end that isn't attached to anything). `finalize_multiplacement` also re-asks the connection question against the world each previous placement just changed, so a failure for any reason takes its dependents with it. (b) **The structural backfill is one rule in one place now** (`ModuleBase.backfill_points`): corridors, stairs, turbolifts and airlocks each laid truss under themselves in their own `on_place()` override, and the drag planner needs that answer *before* anything is placed — a dragged corridor line is chained together by the truss under each corridor, never by the corridors, which all sit on a layer their own connection test doesn't read. A separate defect the verification screenshot caught: `PreviewModule` authored `PLACEABLE = false` on its material while `can_place` defaults to `true`, and the setter only pushes the parameter when the value *changes*, so a preview that was placeable from its first frame drew refused-red; `_ready` now syncs the shader once. Verified by a 22-check windowed probe (including sampled framebuffer pixels for the tint) that fails 8 of its checks against the old behaviour, and 1420 GUT tests green. **Follow-on, same day: cancelling a drag left its previews on screen.** Right-clicking (or Esc, or picking another module from the build menu) mid-drag goes through `change_input_mode`, which knew nothing about the drag — and nothing else could clean it up, because the previews are children of `UIInGame` and `finalize_multiplacement` is only reached on button *release* in Multiplace mode. The ghost line hung there until some later drag happened to reuse the array. `change_input_mode` now drops them first (`drop_multiplacement_previews`, shared with finalize) and revalidates the single preview, which was still carrying the verdict from wherever the drag started. Verified through the real `remove` binding pushed into the input pipeline, plus before/after screenshots; a 10-check probe, green on three consecutive runs.
- **The Trade table's sign was inverted, and a line could not be cancelled** — fixed 2026-08-22, in the same pass as the entry below. Two separate faults in the one signed stepper WI-55 built the table around. **The sign counted credits, not goods**: positive meant *sell*, so the one editable number in a row of four counts (BUY @, SELL @, HELD, AVAIL) moved opposite to every count beside it, and `-30` on a line meant thirty units arriving. It now reads as stock — **positive buys in, negative sells out** — while NET keeps earning on a sell, which is the point: goods and credits move opposite ways, they sit in different columns, and each is read in its own units. `TradeOffer` carries the flip whole (`is_sell`/`is_buy`, `signed_order`, `clamp_amount`'s two ends, `line_credits`, the commit split, and `sell_limit`'s add-back, which now un-negates the line's own value); the panel only passes the two limits the other way up, and nothing outside the panel consumes a signed trade amount. **Separately, a line could be set to anything except zero.** `_on_confirm_pressed` wrote the standing orders from `_lines()`, which drops zero rows — right for a total and for a commitment, wrong for the write, because a row the player has just zeroed is a *cancellation* and is precisely the row whose standing order needs rewriting. The commitment was withdrawn but the sheet kept the old number, and the next refresh read it straight back into the table, so cancelling a docked trade was impossible. Confirm now writes from `_rows`; `_write_order`'s existing no-change guard is what keeps that from firing `clear_sell_order` (which dumps staged stock to a pile) on the rows that were always zero. The undocked sheet, which writes on every stepper move, was already correct in both respects. 1328 GUT tests green (+2, and a dozen assertions rewritten around the new sign); verified in-engine against a docked caravan — a buy reads `+70` against `-6050 cr`, a sell `-10` against `+250 cr`, and a line zeroed and confirmed comes back zero with an empty sheet behind it.
- **The docked Trade table could not be edited — and the stepper defect underneath it** — fixed 2026-08-22. WI-55's merged Trade panel deliberately does *not* write a docked stepper move anywhere: docked, the number is a proposal until `CONFIRM`, so `_on_row_changed` skipped `_write_order` — and then refreshed. The refresh re-read the line from the only two places a docked number could live (the visit's commitments and the bay's standing sheet), neither of which had been written, and pushed the zero it found back into the stepper. Every docked edit undid itself inside the handler that made it, so trading with a trader actually present was impossible; the undocked order sheet, which does write, was unaffected, which is why the panel looked healthy right up until a ship arrived. The proposal now has somewhere to live — `TradePanel._pending`, emptied on every `TraderManager.visit_changed` — and the three-source precedence (proposal, then the visit's commitment, then the standing order) is extracted as pure `TradeOffer.displayed_amount()` so the rule is argued and tested in one place rather than inlined in a repaint. Verifying it in-engine turned up a second, older defect in [`Stepper`](../../../ui/theme/widgets/stepper.gd): `_apply_step` assigned `value` and *then* raised `_dirty`, but that assignment can run an entire commit reentrantly — the step that reaches the end of the range disables the button under the player's finger, the dropped press fires `button_up` → `_end_hold` → `_commit`, and `_commit` stops `_process`. The `_dirty = true` that followed left the widget permanently mid-edit: nothing could ever commit it, and because `is_editing()` then answered true forever, every later refresh skipped the control. A Trade line held to its cap stopped repainting for the life of the panel, and so did a haul priority dragged to ±100. `_dirty` and the clock that clears it now move together (`_mark_dirty()`); the price is that a hold ending exactly at the range's end reports its number twice rather than once, which every `value_changed` consumer absorbs as an idempotent write. 1326 GUT tests green (+10); verified in-engine against a docked caravan — a set line survives its own refresh, `CONFIRM` moved 50 steel and 30 ice for real credits, `CLEAR` empties the proposals and the sheet together, and the Stores priority stepper commits at +100 and re-sorts the list.
- **D8 — the unsaved-stateful-systems sweep** — done by [[WI-45_Save_System_Audit]], 2026-07-30. Every component, manager, pawn component and world object diffed field-by-field against the section it contributes to. Seven findings. Three were unsaved player settings: **storage `priority`** (the routing language itself — a hand-tuned station reverted to scene defaults on every load), both **`force_off` shutdown switches**, and a mining bay's **`priority_ore`**. One was resource destruction: an **unmanned processor** withdraws its batch inputs up front but only the *manned* path was ever given a save key (WI-23 added it and the gate was never revisited), so a save/load mid-batch voided the ore — the fix also carries `pending_recipe` (a queued mid-batch recipe switch that was silently dropped) and `_yield_residue` (sub-1-unit fractional carry-over — small, but still output the player's inputs paid for; the governing rule is no resource loss without a player action that loses them, and it has no size threshold). Two were bugs the sweep walked into rather than unsaved state: **`TurboliftManager` assigned `cab_cost` (500) into `shaft.max_cabs`** instead of the saved count it had just parsed, giving every shaft in every loaded save an unlimited cab budget; and the **storage priority spinbox wrote the field directly** instead of calling `update_priority()`, so already-posted haul jobs kept their old priority indefinitely. The seventh was documentation — five alert-suppression latches that are correctly derived but said nothing about it. The storage save block gained a nested shape (`{"priority", "resources"}`) with a legacy branch rather than a migration; everything else is a new absent-key-means-pristine module key, so `SAVE_VERSION` stayed at 2 and old saves load unchanged. The WI also records the fields confirmed *correctly* unsaved, so the next sweep doesn't redo the work. 505 GUT tests green (+21); verified in-engine by a 29-check headless probe running a real stage → save → load → verify cycle.
- **All of the 2026-07-22 section A** (A1–A8) — fixed by [[WI-38_Bug_Fix_Pass_2]], 2026-07-22. In short: blueprint turrets gated on `is_complete()`; shield capacitor charge/online now saved (module `shield` key, clamped to the upgraded capacity on load); `TimeManager.load_save_data` announces `calendar_restored` instead of replaying `cycle_changed`/`hour_changed`, so no manager does calendar work on load (the `is_loading()` guards in `EconomyManager`/`UnlockManager` came back out); autodump clamps to `stored - desired - reserved_withdraw` via the pure `StorageData.autodump_amount()`; `Job_StoreInventory` sweeps priority-then-distance and null-guards its cast; `game_loaded` reports the staged slot; and `ResourceData` split its authored seed (`starting_global_total`) from runtime `global_total`, reset in `SaveManager._ready` — which also closed **B3**. 351 GUT tests green.
- **C4 — power participant registry, and the battery-charge save bug** — done by [[WI-39_Power_Registry]], 2026-07-22. `PowerManager` now keeps three registration arrays (`power_generators`, `power_consumers`, `batteries`) fed by `register_*`/`unregister_*` calls from the components themselves; the `power_generator`/`power_consumer`/`battery` groups are deleted, as is the `node_grouped`/`node_ungrouped` sketch in both `power_manager.gd` and `signal_bus.gd` — closing **B2** as well. A fourth component lifecycle hook, `ready_deconstructing()`, came with it: a module that has started coming apart now leaves the registries instead of generating and drawing right up until the last plate comes off (never intended — missed when construction was implemented). A deconstructing consumer also goes `powered = false`, so processors/mining bays/conveyors on a teardown site stop rather than running for free. Balance arithmetic is otherwise untouched; iteration order (and so brownout victim order) is still incidental, now registration order instead of tree order, and is documented as such pending the power-priority feature the registry exists to enable. Alongside it, `BatteryComponent.total_power_stored` gained a `battery` save block (clamped to `max_power_stored` on load, absent key = pristine), so banks no longer reload empty. 359 GUT tests green; verified in-engine by a 34-check headless probe.
- **C5 — one storage-query helper** — done by [[WI-40_Storage_Query_Helper]], 2026-07-22. `StorageQuery` (`scripts/utility/storage_query.gd`) replaces the four near-identical scanners with two static queries, `find_source(pawn, resource, trip_cap, below_priority)` and `find_sink(pawn, resource, above_priority)`, sharing one filter+score walk. The strict-and-directional priority rule (what stops an equal-priority haul oscillating) and the deliberate no-filter asymmetry for piles and cargo sweeps are each stated once, at the helper, instead of being implied by four call sites. The scoring is extracted as pure statics plus accumulators (`sink_beats`, `source_beats_partial`, `SinkScorer`, `SourceScorer`) and pinned by a new 18-test `test_storage_query` suite — that rule set is what silently diverged and caused A5. Behavior-preserving: verified by a headless probe that ran the *old* four finders alongside the new ones on a live station across 59 samples, 14,790 checks, zero divergence. Per-resource indexing stays open by design. 377 GUT tests green.
- **All of the original 2026-07-13 section A** (the first nine confirmed bugs) — fixed by WI-01.
- **C1 — one resource-scan helper.** `ResourceScanner` (`scripts/utility/resource_scanner.gd`) now handles exported-build `.remap` suffixes and is used by the build menu, unlock trees, local upgrades and `SaveManager._build_lookups`.
- **C2 — `ModuleGraphVertex` → `RefCounted`.** Done; no manual `free()` remains in `module_graph.gd`.
- **C3 — event-driven storage job posting.** `StorageComponent`'s deficit/surplus scan moved to `_on_slow_tick` (`storage_component.gd:156`); its `_process` is now UI-only and documented as such. The posting scan also gained a shared `import_budget` so several under-desired resources in one bin can't jointly overcommit its free space.
- **C7 — `get_path_component()` null-safety.** Now `get_node_or_null` with a cached result (`module_base.gd:605`).
- **C8 (part) — `sort_priority_decending`.** Gone.
- **D1 — priority-as-routing needs a UI.** Delivered by WI-35: the Logistics overlay mode tints storage modules by routing priority and `OverlayFlowLayer` draws live haul arrows and numeric priority labels.
- **D2 — needs decay in game-hours.** Delivered by `TimeManager`; needs, disease, power, shields and market drift all consume sim-time via `slow_tick`/`hour_changed`.
- **D3 — job board spam guard.** Effectively addressed by the shared `import_budget` (a better mechanism than the per-module concurrent-notice cap originally suggested) plus one-import-job-per-resource slots.
- **D6 — extract magic group strings.** Delivered via C9 / [[WI-41_Group_Constants]] after being promoted to a code item.
