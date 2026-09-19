# WI-69 — Integration Test Fixture

> **Status: DONE (2026-09-19), not committed. Ready for the author's verification pass.** First of six hardening items (WI-69…WI-74) drafted from the second-pass audit in [[03_Bugs_and_Improvements]] and [[05_Architecture_Review]] §A1. **§0 was settled on the recommended default for all three decisions** (the author's instruction, 2026-09-19): a separate `tests/integration/` with its own command, the rule change in CLAUDE.md, and the quiet world.
>
> **Results.**
> - **Integration: 9 suites, 31 tests, green twice in a row from a clean `user://`.** 29 s of GUT time, ~35 s wall, against the three-minute target. Per suite: boot 3.5 s, self-checks 4.2 s, known bugs 7.3 s, restored jobs 2.9 s, idempotence 2.5 s, scene cycles 2.8 s, the 24-sim-hour soak 4.4 s, WI-68 regressions 1.8 s.
> - **Unit: 92 suites, 1,740 tests, green.** That is +20: `test_pawn_opinion.gd` (9), `test_module_graph_vertex.gd` (10) and one F39 test in `test_job_persistence.gd`.
> - **The player's saves were never touched.** `user://saves/` kept its 16 Sep timestamps through every run, and no `user://gut_saves/` survives a run.
> - No error or warning reaches the integration log except the self-checks' planted ones.
>
> **Verification §3: every guard was seen to fail.** Each fix below was patched out, its suite run, and the file restored byte for byte:
>
> | Undone | Suite | Failed with |
> |---|---|---|
> | F13's rotation snap | `test_save_idempotence` | three asteroids' rotation one float32 ulp apart (`3538.99926757813 != 3538.9990234375`) |
> | F2's `change_suit` adoption | `test_restored_jobs` | the component does not know the restored trip; **2** trips, not 1 |
> | F21's resume-first | `test_restored_jobs` | the first job after the load is `store_inventory`, not `haul_resource` |
> | F23's pile setter | `test_wi68_regressions` | the pile still holds its freed module |
> | F22's gateway check | `test_wi68_regressions` | crew 2 → **3** (delivered into the truss), and no refund |
> | F3's `graph.clear()` ×2 | `test_scene_cycles` | **+35.0** objects per cycle, which is the first audit's own figure for the starter station |
> | F39 (below) | `test_save_idempotence` | `job_queue[0]/elapsed: only in the first` |
>
> The known-bug pins were proven the other way round: applying the audit's one-line F25 fix (`not is_finished()`) fails the F25 pin (the site completes), and a minimal `repair_module` adoption fails the F26 repair pin (1 job, not 2). So an accidental fix fails loudly, as §4 intends.
>
> **§3's self-checks, as built.** The spec's three, plus four more:
> - the spec's three: a runtime script error in a ticked node (Godot 4.7 words it "Cannot call method … on a null value"), a planted `reserved_deposit`, and a pause hold;
> - an INPUT slot over its cap;
> - the player's own pause flag;
> - a pawn stranded on an ended job;
> - an inner class for errors outside the test body (below).
>
> **Deviations and findings:**
> - **F39 (new, fixed): a restored job's DURATION progress was lost by a second save before it resumed.** `Job.to_dict()` wrote `_elapsed`, which is 0 until the pawn re-enters the action; the progress sits in `_resume_elapsed` until then. So save → load → save before the pawn resumed restarted any mid-way wait, meal or sleep. The realistic path is a game saved while paused, loaded (it reloads paused), and saved again. R4 found it the first time a pawn was mid-DURATION at the save. The first audit's R4 read "identical" only because none was. The fix is one line: write `_resume_elapsed` while one is pending. It is pinned by `test_duration_progress_survives_a_second_save_before_the_resume`, which failed before the fix, and by R4. It is recorded in the audit doc as F39. The fix is outside this item's "one production seam", and is recorded here as §2 asks: R4's strict comparison could not be green without it, and pinning it broken would have left a known save bug in place for no reason.
> - **The fixture resumes *inside* the frame the game bootstraps.** It uses a `CONNECT_DEFERRED` listener on `game_bootstrapped`, which runs after every manager's own handler and before the sim moves. The first version polled, resumed a frame late, and one frame at 4× changed 23 fields between a save and the save after its reload.
> - **R4 compares two things.** Two post-load saves are compared exactly. A live save is compared with the post-load save after one documented rewrite: the current job moves to the head of the queue, which is WI-44's restore form and not a defect. Nothing else is normalised.
> - **R4 had to spin the asteroids to be able to catch F13.** F13 is float32 losing digits at thousands of degrees (3,457° on the real quicksave), and a young station's rocks are all under 360°. With F13 undone, R4 stayed green until the test spawned three rocks and gave each a long session's spin.
> - **GUT does catch runtime script errors, but only inside a test body.** Errors in `before_each` and `after_each` (a boot, a teardown) go to GUT's "no test" bucket and fail nothing. The fixture therefore installs its own `Logger`, which records exactly those, and `finish()` fails the test on them. It reads GUT 9.7.1's `GutErrorTracker._current_test_id`, and the self-check suite pins both halves.
> - **Under GUT, `get_tree().current_scene` is null**, not the test runner as §2 expected. `DialogueRunner`'s fallback would mount on the root. With the quiet defaults no balloon opens, and one would mount under `UIMain` anyway (`main.tscn` has its HUD), so nothing needed changing.
> - **F33 was not a blocker.** `main.tscn` boots whole under the fixture, HUD included. The review's "F33 first" is still worth doing for its own sake (WI-74), but the fixture did not need it.
> - **The fixture's API grew beyond §1:**
>   - `corridor()`: `place()` puts a corridor only at a module's own door, so a row of modules is a row of islands until it runs;
>   - `tick_until()`, which measures elapsed time on the clock, because a tick overshoots by up to a frame;
>   - `save()` and `read_save()`;
>   - `live_jobs(type, target)`: the F26 question asked of the board plus every pawn, rather than of the owner's own pointer;
>   - a structural save `diff()`;
>   - `pawns()`, `piles()`, `modules()` and `storages()`;
>   - `check_invariants()`, `describe_pause()`, `build_production_line()` and `finish()`;
>   - the `on_failure` hook, which the self-checks use to capture a failure instead of failing.
> - **`test_known_bugs.gd` has seven tests:** F38 and a live-teardown control beside it, F25, and F26 four times. On the starter station the control's refund stays in the site's OUTPUT bin, because the Command Center's 80-unit pool is full, so the site never removes itself; the control waits for `Deconstructed`, not removal.
> - **Two setup traps, now in CLAUDE.md:**
>   - A module's first `StorageComponent` is its construction bin, so a processor's intake is `processor.storage`. The F26 processor pin first "deposited" into the construction bin, and waited 14 sim-hours for drones to deliver ore.
>   - The processor pin uses a slim station (processor and power next to the Command Center), where an operator arrives in about 5 sim-seconds.
> - **R6's bound is 5 objects per cycle.** The first measurements were +0.5, then 0.0 (3,142 flat over five cycles), and F3 undone gives +35.
> - **§5, GUT's own exit leak:**
>
>   | Run | Leaked at exit |
>   |---|---|
>   | no tests at all | **652** |
>   | one pure suite | 653 |
>   | the full unit suite | 1,032 (380 above GUT's baseline) |
>   | the integration suite | 842 (190 above, mostly caches a boot fills for the process's lifetime) |
>
>   F19's "~1,000 from tests that don't `autofree`" is therefore about two-thirds GUT and the addons, as the draft expected. Recorded, not chased.
> - **Timing note:** the unit suite read 37 s of GUT time today against 10.9 s at the start of the session. The identical figure on the pre-WI-69 tree (stashed and re-run) shows it is environmental, not this item's.
>
> **Files, as built:**
> - **New:**
>   - `tests/integration/`: `station_fixture.gd`, `test_fixture_self_checks.gd`, `test_boot.gd`, `test_save_idempotence.gd`, `test_soak.gd`, `test_scene_cycles.gd`, `test_restored_jobs.gd`, `test_wi68_regressions.gd`, `test_known_bugs.gd`;
>   - `tests/unit/`: `test_pawn_opinion.gd`, `test_module_graph_vertex.gd`.
> - **Changed:**
>   - `scripts/managers/save_manager.gd` (the seam: `_save_dir`, `set_save_dir_for_test()`, `save_dir()`, routed through `slot_path`, `list_slots` and `save_slot`'s mkdir);
>   - `scripts/jobs/job.gd` (F39);
>   - `tests/unit/test_job_persistence.gd` (F39);
>   - `CLAUDE.md`, and the Planning docs (`01` §1.19, `02`, `03`, `05` §A1, WI-70).

## Goal

GUT covers the pure tier of the codebase thoroughly: `scripts/utility/` has a suite for nearly every class. It covers almost none of the rest: the managers (10,014 lines), the module components (6,411) and the pawns (4,672). Every finding from F2 to F38 is an integration fault between two owners in that untested half. Each one was found by reading, or by a scratch-copy probe that was written, run once and deleted.

This item makes that probe permanent. After it:
- a GUT fixture boots the real `main.tscn` headless, places modules, runs the sim, saves and reloads, and checks the station's invariants after every test;
- the first audit's runtime probes (R4 idempotence, R5 invariants, R6 scene cycles, R7 suit trip) are tests that run on every change;
- the open job-lifecycle bugs (F25, F26, F38) are pinned as tests that assert today's broken behaviour, and WI-70 flips each one as it fixes it.

## 0 — Decisions (settled 2026-09-19: the recommended default on all three)

1. **Integration tests live in `tests/integration/` and run as a second command.** *Recommended.* Booting `main.tscn` costs about a second per test and a soak costs several, so folding them into the unit run would make the fast suite slow. *Alternative:* one directory, one command, and a slower suite.
2. **CLAUDE.md's "GUT covers pure classes only" becomes "unit suites are pure; integration suites go through the fixture".** *Recommended.* The extraction rule stays for *rules*. What changes is that behaviour between systems is testable without extracting anything. A test must never hand-build a partial scene, because that is exactly the fixture this item exists to replace.
3. **The fixture's default world is quiet:** Peaceful difficulty (raids off), onboarding skipped, natural events off and the critical-alert pause off. Each can be switched back on per test. *Recommended.* The 2026-09-19 scratch probe for F38 is the argument. Its first run silently measured nothing, because the new-game onboarding took its `&"dialogue"` pause hold and the sim never advanced. A soak that crosses cycle 2 can hit the same thing through a random event's balloon. *Alternative:* Normal with everything on, which makes long tests non-deterministic and prone to freezing.

## Scope

**In:**
- the fixture and its one production seam (§1, §2);
- proving the fixture fails when it should (§3);
- the first residents: the first-pass probes, WI-68's regressions, and the three open bugs pinned as known-broken (§4);
- the two coverage gaps F19 left open, `PawnOpinion` and `ModuleGraphVertex` (§5);
- the CLAUDE.md and tech-spec updates (§6).

**Out:**
- fixing F25, F26 or F38 (WI-70);
- any refactor to make scenes easier to test. If `main.tscn` refuses to run as a child of a test, fix the specific cause and record it; don't restructure around it.

## Design

### 1 — `StationFixture`

`tests/integration/station_fixture.gd`, `class_name StationFixture`, constructed per test with the `GutTest` it serves (`StationFixture.new(self)`), so it can `add_child` and await frames. Its API:

| Method | Does |
|---|---|
| `boot(options := {})` (await) | Stages `Global` (difficulty, `set_skip_onboarding(true)`, `clear_staged_start()`, `SaveManager.clear_pending_load()`), instantiates `main.tscn`, adds it under the test, and awaits `game_bootstrapped` with a timeout. Then applies the quiet defaults: `EventManager.expected_cycles_between_events = 0` (which `_natural_roll` already treats as off) and `AlertManager.pause_on_critical = false`. `options` switches any of them back on. |
| `place(module_id, cell, built := true) -> ModuleBase` | `WorldManager.add_module(..., force_complete = built)`. No connectivity check, which is fine for tests and must be said in the doc comment. |
| `tick(sim_seconds, speed := 4.0)` (await) | Sets `TimeManager.speed` and awaits frames. **Fails the test, naming the holders, if `is_paused()` is true on any frame.** A soak on a paused game is the silent failure §0.3 describes. |
| `save_and_reload()` (await) | Saves to the fixture's own slot (§2), frees the scene, awaits a frame so every `NOTIFICATION_PREDELETE` runs, then `SaveManager.stage_load()`, re-instances and awaits `game_bootstrapped`. **Never `load_slot`:** that calls `reload_current_scene`, and under GUT the current scene is the test runner. |
| `world_total(resource) -> int` | Every module's storages, every pile, every pawn's inventory and the global store: the F38 probe's helper. |
| `invariants() -> PackedStringArray` | Every broken invariant as a sentence; empty means clean. See below. |
| `loose_objects() -> int` | `OBJECT_COUNT − OBJECT_RESOURCE_COUNT − OBJECT_NODE_COUNT`, the first audit's leak metric. |
| `teardown()` (await) | Frees the scene, deletes the fixture save directory, and clears `Global`'s staging. |

`invariants()` checks what CLAUDE.md claims and the R5 soak measured:
- **reservations reconcile:** for every `StorageData`, `reserved_withdraw` and `reserved_deposit` equal `ClaimRegistry.claimed_amount()` for that bin and kind;
- **capacity holds:** no pool over `max_stored` or `output_capacity`, and no INPUT slot over its `desired`;
- **no stranded jobs:** no pawn holds an ended `current_job` for more than one frame.

Suites call it in `after_each` through a one-line helper, so every test checks the whole station for free.

### 2 — The one production seam

`SaveManager.SAVE_DIR` is a `const`, so a test would write into the player's real `user://saves/`. Add `static var _save_dir: String = SAVE_DIR` and `static func set_save_dir_for_test(dir: String)`, and route `slot_path`, `list_slots` and `make_dir_recursive_absolute` through it. The fixture uses `user://gut_saves/` and deletes it in `teardown()`.

Nothing else should need changing. If something does, fix the specific cause, record it in the status block, and keep it small. The known suspect is `DialogueRunner`'s fallback host (`dialogue_runner.gd:191`, `get_tree().current_scene`), which under GUT is the test runner; with the quiet defaults no balloon should open.

Statics carry across fixtures exactly as they carry across a Quit to Menu in the game. That covers `SaveManager._sections` (pruned by `is_live()`), the pawn and pile id counters, and the content registries. It is correct, and it is what the game does. A test must not assume a fresh id counter.

### 3 — The fixture proves itself first

Before any real test, three deliberately failing checks, each kept as a test that asserts the failure is caught:
- **a script error inside a ticked scene fails the test.** Plant a call on null in a throwaway node's `_process` and `tick` over it. GUT fails on an unexpected `push_error` (WI-68 relied on this), but a *runtime* script error raised by the engine may not reach it. If it doesn't, the fixture installs a `Logger` through `OS.add_logger()` (Godot 4.5+), records errors, and fails the test in `after_each`;
- **a broken invariant is reported:** bump a bin's `reserved_deposit` by hand and `invariants()` must name it;
- **a pause hold fails `tick`:** take a hold, tick, and expect the failure message to name the holder.

### 4 — First residents

| Suite | Pins |
|---|---|
| `test_boot.gd` | A new game boots with the starting modules and two crew, no pause holders, and clean invariants after one sim-hour. |
| `test_save_idempotence.gd` | R4: save, reload, save, and the two `sections` blocks are identical. F13 made this exact, so it's a strict equality. |
| `test_soak.gd` | R5, shortened: a fixture station with a processor, a storeroom and a mining bay runs 24 sim-hours at 4×, with `invariants()` checked every sim-hour. |
| `test_scene_cycles.gd` | R6: five boot and teardown cycles; loose-object growth per cycle stays under a bound set from the first measurement (WI-68 recorded +6). |
| `test_restored_jobs.gd` | F2 (a suit trip across a reload: one trip, suited once) and F21 (a restored haul's cargo is not swept first). |
| `test_wi68_regressions.gd` | F22 (a bay removed mid-flight refunds the hire) and F23 (a pile tagged with a removed module survives the next save). |
| `test_known_bugs.gd` | **F25** (interrupt a builder and the site never re-posts), **F26** (after a reload a second job is posted for a site mid-build, a manned processor mid-batch, a repair in flight and a pile being collected), and **F38** (a save mid-deconstruction loses the refund). Each asserts *today's broken behaviour*, is named for its finding, and says so in a comment. The suite stays green and each defect is pinned. WI-70 flips each assertion as it fixes the bug, and an accidental fix fails loudly instead of passing unnoticed. |

The F38 test ports the 2026-09-19 scratch probe: two `large_storage` far from the station, one torn down live as the control (the refund appears), one saved in the frame its deconstruction starts (the refund never appears).

### 5 — Coverage gaps from F19

Two unit suites, pure, in `tests/unit/`:
- `test_pawn_opinion.gd`;
- `test_module_graph_vertex.gd`.

Also measure GUT's own exit leak once and record it. The F38 probe run leaked about 700 objects at exit running a single three-test file, so most of the "~1,000" F19 attributed to un-`autofree`d tests is GUT's and the addons' baseline. Record it; don't chase it.

### 6 — Docs

- **CLAUDE.md, Running & verifying:** the integration command (below), the rule change from §0.2, and a line on the quiet defaults.
- **[[01_Technical_Specification]] §1.19:** the fixture, and that R4–R7 now run as tests.

```
godot --headless --fixed-fps 60 -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit
```

`--fixed-fps 60` makes every frame 1/60 s whatever the wall clock does, which is what makes `tick` deterministic. Confirm on day one that the flag is honoured under `-s`. The first audit's probes used it with a scene rather than a script.

## Files to touch

| | Files |
|---|---|
| New | `tests/integration/station_fixture.gd`, the seven suites in §4, and `tests/unit/test_pawn_opinion.gd`, `tests/unit/test_module_graph_vertex.gd` |
| Changed | `scripts/managers/save_manager.gd` (the save-dir seam), `CLAUDE.md`, `01_Technical_Specification.md` |

`tests/` is already excluded from the export preset. Run `godot --headless --import` after adding the fixture's `class_name`.

## Implementation order

1. The save-dir seam and a fixture that can only `boot()` and `teardown()`. Get one test green, run the integration command twice in a row, and confirm nothing leaks into `user://saves/`.
2. §3's three self-checks. The fixture isn't trusted until all three pass.
3. `tick`, `place`, `world_total`, `invariants`, `save_and_reload`.
4. The residents in §4's order. `test_known_bugs.gd` last, because it depends on everything else.
5. §5, then §6.

## Edge cases

- **Two scenes alive at once.** `save_and_reload` must free the old scene and await a frame before instancing the new one, or two sets of managers fight over `Global`.
- **Speed.** 4× is the game's own ceiling and the default. A soak may use 8×: at 1/60 s frames that is 0.13 sim-seconds per frame, which movement's distance loop handles. Don't go higher without checking that door and ride timing still resolve.
- **An event with a balloon** opens only if a test turns events back on, and it will hold the pause, which `tick` then reports. That is the intended behaviour.
- **The unit command must not pick up integration suites.** `-gdir=res://tests/unit` already excludes them; keep the two directories separate.
- **Headless has no `_draw()` output.** Anything that needs a screenshot still needs one; the fixture doesn't change that rule.

## Verification

1. The full unit suite stays green, and the integration suite runs green twice in a row from a clean `user://`.
2. §3's three self-checks each fail the way they should.
3. Where WI-68 proved a fix by temporarily undoing it, undo the same fix once and watch the matching integration test fail: F13's rotation snap for R4, F2's adoption for `test_restored_jobs`, and F23's pile setter for `test_wi68_regressions`.
4. Record the integration suite's runtime in the status block. Aim for under three minutes.

## Related

- [[05_Architecture_Review]] §A1 argues for this item; §4 of the review lists what it must not disturb.
- [[WI-68_Audit_Fix_Pass]] is the source of R4–R7 and of the scratch-copy method this makes permanent.
- [[WI-70_Job_Ownership_Contract]] flips `test_known_bugs.gd`.
