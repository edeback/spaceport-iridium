# WI-68 — Audit Fix Pass

> **Status: IN PROGRESS. Stages 1–3 and 3b done (2026-09-18); stages 4–6 not started.** Scoped from the 2026-09-18 pass in [[03_Bugs_and_Improvements]]. The findings are **F1–F20**, plus **F21** (found and fixed during stage 2), **F22–F23** (found during stage 3 and fixed in stage 3b) and **F24** (found during 3b and fixed only where it touched 3b's flow). The three open questions were settled with the author the same day and all three recommended defaults were taken (§0). The finding ids are kept throughout so the audit entries and this doc stay cross-referenced.
>
> **Stage 3b (F23, F22, F15, and part of F24), added by the author after stage 3: not yet committed. 1,718 GUT tests green** (1,709 + 9 in `test_job_serialization.gd`). With the fixes undone, exactly the four targeted tests failed. On the real quicksave, the scenario that reproduced both bugs (hire, tag a pile with the bay, remove the bay mid-flight, save, reload) now passes every check. The same probe run against the pre-3b code fails all five, so it genuinely detects them:
> - **F23:** the tagged pile lets go of the bay the moment the bay is removed, and **6 piles → 6 after the reload** (pre-3b: 6 → 0, with the `module_ref` script error). No freed-reference warning fired, because the fix held at the source.
> - **F22:** crew 3 → 3, refund 1,238 booked, balance restored (pre-3b: the recruit was delivered into the truss, crew 3 → 4, refund 0).
>
> **Stage 3b design, as built:**
> - **F23 has three layers, so one bad reference can never again cost a whole section.**
>   - `ResourcePile.parent_module` gained a setter that follows the module's `tree_exiting` and lets go. Only `remove_module` ever takes a module out of the tree, so this means "removed".
>   - The five `SaveManager` `*_ref` helpers take a `Variant`, and a freed object returns `{}` with a `push_warning`.
>   - `_get_piles_save` needed no change of its own once `module_ref` stopped raising.
> - **F22:** `CrewManager._is_gateway()` means a *built crew gateway* (a `CrewRecruitmentComponent` in the `CREW_RECRUITMENT` group), which is what the rest of the game already means by one. `_arrive` and `_on_shuttle_docked` both use it, so a truss backfilled onto the bay's cells, or anything else later built there, gets a refund rather than a recruit.
> - **F24 (new) is why the helpers take `Variant`.** A typed object parameter rejects a freed object *at the call*, before any `is_instance_valid` inside can run. That made the old helpers' validity checks dead code. The same trap was fixed where it met this flow: the crew, visitor and trader-courier shuttle handlers, whose bay is bound at launch and can be freed by docking. Before this fix, a courier whose bay died in flight stranded `_courier_active`, and no courier was ever dispatched again. **37 functions** have the pattern; the rest are recorded under F24 in the audit doc.
> - **F15** moved here from stage 6: it's the same function as F22's docking handler.
>
> **Stage 3 (F4): committed `12cd0180`. 1,709 GUT tests green** (1,693 + 16 in `test_economy.gd`). Undoing two representative pieces (the balance keys in the save round trip, and `hiring` from the declared costs) failed five tests. Verified windowed in a scratch copy on the real quicksave, with every booking site driven for real: a docked trader's purchase, a raid bought off, a hire, and a truss bought through `purchase_and_add_module`:
> - Each booked flow moved the operating net by exactly what it moved the balance: Purchases 750, Pirate ransom 5,979, Hiring 890.
> - **The reconciliation holds exactly:** across the whole cycle, Balance change − Operating net = −35, which is precisely the truss (−6,764 against −6,729). No unbooked flow remains.
> - The first roll stamped `opening_balance` (and the finished cycle's `closing_balance`); both survived save/load. A record from the pre-F4 quicksave correctly has no opening balance, and the tab hides its Balance change line.
> - **Screenshot checked at 1080p:** This cycle lists Refunds +890, Hiring −890, Purchases −750, Pirate ransom −5,979, Operating net −6,729 and Balance change −6,764, with the note under them. Last cycle shows Operating net only. Nothing clips.
>
> **Stage 3 deviations and notes:**
> - **An undeclared category is reported *and* still booked.** The design said `push_error` only. Refusing it would drop real money from the books, which is the very bug being fixed, so the tab also lists any undeclared category after the declared ones. GUT fails a test on an unexpected `push_error`, so the declaration rule is enforced by the suite as well.
> - **`opening_balance` is stamped at `game_bootstrapped`, not in `_ready`.** EconomyManager readies before SaveManager resets the credit totals, so `_ready` would have read 0 (or the previous run's balance after Quit to Menu, the A8 class). A loaded record never gets a stamp, even when it lacks one, because "since the load" would be a different number.
> - **A cycle with no income or costs but a moved balance no longer says "Nothing recorded yet"**; building alone is real movement.
> - **The tests went in `test_economy.gd`, not `test_ledger_grouping.gd`.** The latter is the *resource* ledger (`LedgerModel`), which the design confused with this one. The record helpers (`add_to_record`, `record_net`, `balance_change`, `record_to_save`/`record_from_save`) are pure statics, per the file's existing pattern.
> - **The natural refund path couldn't be verified, because of F22.** The refund booking was verified by calling `_refund_hire` directly.
> - **Two new bugs, confirmed while verifying F4 and recorded in the audit doc:**
>   - **F22:** a hire whose bay is removed mid-flight is delivered into the backfilled truss instead of refunded.
>   - **F23:** a pile tagged with a since-removed module makes the next save drop *every* pile on the station (5 → 0).
>
>   Neither is part of F4, so neither is fixed yet. F23 is silent resource loss and should be fixed next.
>
> **Stage 2 (F2, F9, F10, F13, and the new F21): committed `580efc19`. 1,693 GUT tests green** (1,683 + 10: six trip-pointer tests in `test_suit_content.gd`, and two chat-log plus two rotation tests in `test_component_persistence.gd`; F9 widened the existing key tables). With each fix temporarily undone, exactly the nine targeted tests failed and nothing else did. Re-measured in a scratch copy on the real quicksave:
> - **F2, the suit trip across a reload:** one `change_suit` job ever, never two held at once, and suited after 7.4 s (the no-reload control: 7.5 s). Before, a duplicate trip was posted and the orphan walked the already-suited pawn to an airlock and back.
> - **F21, restored jobs:** all five restored in-flight jobs now resume first after the load (before: four of five were abandoned to a cargo sweep). Twelve sim-hours of play after the load showed zero reservation drift, zero overfill and zero script errors across 462 checks.
> - **F13:** save → load → save is now **exactly** identical (0 differences; it was 6 rotation diffs).
>
> **Stage 2 deviations and notes:**
> - **F21 was not in the design.** It surfaced while verifying F2: with the trip correctly adopted, a crew member restored mid-way to an airlock still spent 11 sim-seconds on a cargo sweep first (suited at 27.7 s against the target of ~7 s), standing in the harmful room. The sweep was preempting *every* restored job whose pawn carried cargo, not just suits, so it was fixed at that root and added to scope. See §Stage 2, F21.
> - **F13 snaps as well as wraps.** Wrapping alone doesn't make the save idempotent, because rotation round-trips through float32 radians and still loses a bit. `saved_rotation_of()` wraps to one turn, then snaps to 0.001°, then maps a snap-up to 360 back to 0. The test for that edge caught a bug in the first version, which snapped first.
> - **F9 needed no new round-trip test.** `test_suit_content.gd` already had one for the suit block.
> - **F10 also skips a malformed entry** rather than appending whatever `as Dictionary` produces.
> - Two read accessors were added for the new tests and the cheat dump: `PawnSuitComponent.has_live_trip()` and `trip_cooldown_remaining()`, alongside the existing `hold_remaining()`.
>
> **Stage 1 (F1, F3, F12): committed `b85090cc` on `wi-68-audit-fixes`. 1,683 GUT tests green** (1,672 + 11: the new 7-test `test_module_queue.gd`, plus 4 teardown tests in `test_module_graph.gd`). Both leak guards were proven to bite: with each fix temporarily undone, exactly the new test failed and named the leaked object. Re-measured in a scratch copy on the real quicksave:
> - **F1 + F3, in play:** loose (non-Node, non-Resource) objects now plateau after about the first sim-day and then oscillate. A 72-hour soak read 5,424 at h24 and 5,456 at h72, dipping to 5,404 in between. Before the fix the count rose monotonically by ~240 per cycle, and the exit leak grew with play time; it now reads 639 at 24 h and 649 at 72 h.
> - **F3, scene swaps:** +6 objects per New Game ↔ menu cycle (was +42). The exit leak after two loads is 631 (was 1,305). A fresh boot also fell, 583 → 544, because the starter station's graphs no longer leak either.
> - **F12:** a `TurboliftCab` instantiates cleanly outside a game. In-game, a cab made by `create_new_cab` on a freshly built two-floor shaft registers its vertex in `_ready` and lands in the shaft's group (`turboshaft_0`).
>
> **Deviations and notes:**
> - **Two verification targets were mis-specified and are corrected in §Verification.** "24-hour loose growth ≤ ~70" assumed linear growth, but the first sim-day is buffers filling to their caps (+111 in 24 h). The real criterion is a plateau after warm-up and an exit leak that doesn't grow with play time. "Within ~50 of a fresh boot" compared against a baseline this stage itself moved.
> - **Residual, not F3:** each load still keeps about 43 objects until exit (two loads: 631 against a fresh boot's 544). This is small, doesn't grow with play time, and has a different source from the graph cycles. It's worth one short investigation, but it's not in this WI's scope unless it turns out to be trivial.
> - `clear()` also empties `_linked_groups` and `_exterior_vertices`, not just `_vertices`. It deliberately emits nothing, and a test pins that.

## Goal

Fix what the 2026-09-18 audit confirmed, and put automated guards on the two rules it found drifting. This follows [[WI-38_Bug_Fix_Pass_2]]: the smallest correct fix per bug, no redesign. The one exception is F4, where "correct" depended on what the Finance tab is for (settled in §0, decision 1).

Several things make this a work item rather than a scattering of commits:
- **Two memory leaks that never stop growing.** One is ~240 objects per sim-cycle for as long as pawns walk (F1); the other is a whole station graph on every load and every Quit to Menu (F3).
- **A save/load bug in WI-67's newest system** (F2).
- **Two rules that CLAUDE.md states and nothing enforces** (F6, F7). Each fix is small, but they share a verification loop (the audit's scratch-copy probe), so they belong together.

## 0 — Decisions settled with the author (2026-09-18)

These are decisions, not suggestions. The alternatives that were turned down are recorded so nobody re-opens them by accident.

1. **The Finance tab gets "Operating net" plus "Balance change" (F4, stage 3).** "Net" is renamed **"Operating net"**, and a new **"Balance change"** line under it shows how far the balance actually moved since the cycle opened. The gap between the two lines is capital spending (construction, research, upgrades, cabs, robots), so the tab reconciles without a capital ledger. This costs one additive saved field (`opening_balance` on the current record).
   - The three unbooked operating flows (trade purchases, raid payoffs, hire fees) are booked regardless.
   - *Turned down:* a full capital section (five more booking sites and a bigger tab), and booking the three flows while leaving "Net" as it is (still wrong whenever the player builds).
2. **Typed warnings become errors (F7, stage 5).** All three `gdscript/warnings/*` settings go to 2, **after** the 97 project-code sites are clean. From then on, an untyped declaration or unsafe access stops that script compiling, and the game won't run until it's fixed. That is the intended enforcement.
   - The vendored `assets/external/pixel_planets/` (140 sites) is excluded. Use Godot 4.7's per-directory warning rules if the setting exists; otherwise put a file-top `@warning_ignore_start(...)` in `Star.gd` and `StellarObjectVisual.gd`. Record which one was used in the status block.
3. **The minimap's colours move into `UIPalette` (F6, stage 5)** as a `MAP_` block. The minimap is HUD chrome, and the rule is "nothing in `ui/`", so it does **not** join the world-space exemption list.

## Scope

**In:**
- the five confirmed bugs, **F1–F5**;
- the two drift guards, **F6** and **F7**;
- the save-key pin, **F9**;
- the small load-path fixes **F10** and **F13**;
- the cab registration, **F12**;
- a cleanup commit covering **F15–F18**, with the CLAUDE.md counts (**F20**) updated at close;
- **added during stage 2:** **F21**, restored in-flight jobs lost their turn to the cargo sweep on load. It was found while verifying F2 and blocked F2's own target.

**Out, deliberately:**
- **F8** (node-keyed dictionaries). All eight are safe today by pairing. Whether to convert them or to amend the CLAUDE.md rule so the unregister-on-`_exit_tree` pairing is sanctioned is a rule decision, not a fix.
- **F11** (listener-less SignalBus signals). Keeping or deleting them depends on whether they are the WI-47 mod API, and that deserves its own conversation.
- **F14** (Deconstructing collapses to Deconstructed on load). A design choice that's documented where it lives.
- **F19**'s `PawnOpinion` suite, and **D4/D5**.

## Design

### Stage 1 — Leaks (F1, F3, F12)

**F1. `ModuleQueue` becomes RefCounted.** [`module_queue.gd:2`](../../../../scripts/utility/module_queue.gd) changes `extends Object` to `extends RefCounted`, and that is the whole fix. Nothing calls `.free()` on one, so there is nothing to unwind. The two allocation sites, `ModuleGraph.pathfind_by_vertex` (`:385`) and `pathfind_to_func` (`:503`), stay as they are and now release the queue when the function returns. A sweep found no other raw-`Object` class in the project, so this is the whole bug class. (`ModuleBase`, `AsteroidBase` and `ResourcePile` extend `ObjectBase`, which is a Node.)

New suite `tests/unit/test_module_queue.gd`. `ModuleQueue` has had no tests at all, which is how the leak lived in it:
- extraction comes out in ascending cost order, ties included;
- extracting from an empty queue returns null;
- **a dropped queue is freed**: take a `weakref` to a new queue, drop the reference, and assert `get_ref()` is null. This fails on the current code, so it pins the fix.

**F3. A graph that is going away breaks its own cycles.** Add `ModuleGraph.clear()`:
- empty every vertex's `edges` (this is what breaks the cycles);
- then clear `_vertices`, `_linked_groups` and `_exterior_vertices`.

Call it from `_exit_tree` on both `PathManager` and `StructureManager`. `clear()` must **not** call `_emit_graph_changed()` or `_mark_dirty()`, because its listeners are being torn down in the same pass. A pawn's `NOTIFICATION_PREDELETE` still calls `Global.path_manager.remove_vertex(self)` afterwards, but on a cleared graph that is already a no-op: `remove_vertex` returns early for an unknown vertex (`module_graph.gd:163-166`). Loads never need `clear()` directly, because a load is `reload_current_scene` and goes through `_exit_tree`.

Test in `test_module_graph.gd`, "a cleared graph releases its vertices": link three vertices, take a `weakref` to one, call `clear()`, drop the graph, and assert the ref is gone.

**F12. `TurboliftCab` registers itself in `_ready`, not `_init`.** Move `Global.path_manager.add_vertex(self, true)` from [`turbolift_cab.gd:105`](../../../../modules/transport/turbolift_cab.gd) into `_ready`, and delete `_init`. The order is safe: `TurboliftShaft.create_new_cab` calls `add_child` before `add_cab`, so the vertex exists before `change_vertex_group` needs it. After this, instantiating a cab outside a running game (a preview cache, a tool, the R3 probe) stops erroring.

### Stage 2 — The suit trip across a save (F2, F9, F10, F13)

**F2.** Two changes; either alone leaves a hole.

1. **Adopt the restored job.** Add `PawnSuitComponent.adopt_restored_trip(job: Job)`, which sets `_trip = job`. Wire it into [`SaveManager._adopt_if_need_job`](../../../../scripts/managers/save_manager.gd) as an `elif job.is_type(&"change_suit")` branch beside recharge, repair and treatment, and add `change_suit` to that function's doc comment. This closes the reproduced defect: the pointer is no longer lost on load, so the component doesn't post a second trip, and nothing is left in the queue to send an already-suited crew member back to an airlock.
2. **A trip may only clear its own pointer.** Change the signatures to `trip_refused(job: Job)` and `apply_change(putting_on: bool, job: Job = null)`. Both clear `_trip` (and `trip_refused` also sets the cooldown) **only when `job == _trip`**. This closes the unreproduced worse case: interrupting a stale `change_suit` job fires its driver's `on_job_end` → `trip_refused`, which today nulls the pointer of the *new* trip that just interrupted it, allowing a re-post every slow tick.
   - Callers: `action_change_suit.gd:44, :65, :68` and `job_driver_change_suit.gd:61` pass their job.
   - The cheat at `cheats.gd:198` passes none, so a live trip survives a cheat flip. That's correct: the trip finishes and applies its own change.
   - Nothing depends on the old eager clearing, because `_trip_is_live()` already drops an ended job on its next read.

Tests, extending the existing pure setup where a component is constructed bare with `autofree()`:
- `trip_refused(other_job)` leaves `_trip` in place and sets no cooldown;
- `trip_refused(own_job)` clears `_trip` and sets `trip_retry_hours`;
- `apply_change(true, other_job)` leaves `_trip` in place;
- `apply_change(true, own_job)` clears it;
- `apply_change(true)` with no job (the cheat's call) leaves it in place.

**F9.** Add `"heat": HeatComponent`, `"heat_emitter": HeatEmitterComponent` and `"suit": PawnSuitComponent` to the two tables in [`test_component_save_contract.gd`](../../../../tests/unit/test_component_save_contract.gd). The existing key and unique-order tests then cover them. If `test_no_two_module_components_share_an_order` fails once heat (65) and heat_emitter (66) are in, the collision is a genuine finding: pick the order deliberately, don't just renumber until it passes. Also add a round-trip test for the suit block (`suited`, `hold_hours`).

**F10.** [`socialize_component.gd:442`](../../../../pawns/socialize_component.gd) coerces each `recent` entry on load instead of appending the parsed dictionary as-is: `with`, `cycle` and `hour` to int, `delta` to float, `positive` to bool, `name` to String. Add a GUT round-trip test that asserts `typeof` on each field after a JSON pass. Nothing keys on `with` today; this stops the first thing that does from missing every lookup, since `6.0` and `6` are different keys in Godot.

**F13.** [`asteroid_base.gd`](../../../../objects/asteroid_base.gd) saves `saved_rotation_of(sprite.rotation_degrees)`: wrapped to one turn, then snapped to 0.001°. Wrapping alone isn't enough, because the value round-trips through float32 radians (see the status block). That makes the save/load/save diff exactly empty, which makes the R4 probe a clean pass/fail from now on.

**F21 (added during stage 2). A restored in-flight job runs before the cargo sweep.** `start_job()` sweeps carried cargo before anything else, which is right for leftovers from a cancelled job. But on the first pick after a load, the cargo usually *belongs* to the restored job: a haul mid-carry, a drone mid-mine, and in F2's case a crew member mid-way to an airlock. On the real quicksave, four of five restored jobs were abandoned to a sweep.
- `SaveManager._load_pawn_jobs` now calls `PawnBase.mark_restored_job()` on the restored current job, after queueing it to the front as before. Queued jobs are unaffected.
- `PawnBase._resume_restored_job()` begins that job ahead of the sweep, once. The marker is spent on the first `start_job()` whatever happens. If something was queued in front of the job since the load, or it can no longer run, the normal rules take over: a cancelled job leaves its cargo on the pawn, and the next pick sweeps it as leftovers.
- The three `start_job()` implementations that sweep call it: `PawnBase`, `VisitorPawn`, and `RobotPawnBase`. The robot calls it **after** its zero-energy gate, so a drained robot still recharges first. `InspectorPawn` never sweeps and is never saved.

### Stage 3 — The Finance tab's Net (F4)

**A category is declared or it does not exist**, the same rule as `Groups`, `UIType` and `StoryFlags`. The Finance tab iterates `COST_ORDER` only, so a cost booked under any category not in that list vanishes from both the display and Net. The fix:
- Move `COST_ORDER` and `INCOME_ORDER` out of `finance_tab.gd` into `EconomyManager` as `COST_CATEGORIES` and `INCOME_CATEGORIES`, and have the tab read them.
- Make `_add_cost` and the income paths `push_error` on an undeclared category.
- `&"event"` legitimately appears in both lists.

**New categories:**
- `&"trade_purchases"` ("Purchases");
- `&"raid_payoff"` ("Pirate ransom");
- `&"hiring"` ("Hiring");
- `&"refunds"` ("Refunds"), on the income side.

Also relabel income `&"trade"` to "Sales". Ids don't change: they're in every saved ledger history.

**Booking sites.** All go through `record_external_cost`, which never touches the levy:
- [`trader_manager.gd:249`](../../../../scripts/managers/trader_manager.gd): `amount * price`, under `trade_purchases`;
- [`raid_manager.gd:298`](../../../../scripts/managers/raid_manager.gd): capture `current_payoff()` once and use the same value for both the withdraw and the booking, under `raid_payoff`;
- [`crew_manager.gd:180`](../../../../scripts/managers/crew_manager.gd): `candidate.price`, under `hiring`.

The pirate-extortion dialogue books its own credit delta through `record_event_delta` and never calls `pay_off()`, so nothing is double-booked.

**The hire refund** (`_refund_hire`, when the bay is gone before the shuttle lands) books as **income under `refunds`** through a new `record_refund(amount, category)`, which skips the levy. It is deliberately not a negative cost: a refund landing in a later cycle than its charge would then need a negative line, which the tab's `value > 0` filter hides. Charge and refund in the same cycle net to zero; in different cycles each cycle still reads true.

**Operating net and Balance change (§0, decision 1).** Stamp `opening_balance` on the current record when a cycle rolls. The tab shows "Operating net", then "Balance change" (current balance minus the opening balance). The field is additive in the `economy` section; if it's absent (an old save, or the cycle in progress when the save was written), the tab hides that line for that cycle.

**Tests** (extending `test_economy.gd` and `test_ledger_grouping.gd`):
- every declared category has a label that isn't the `capitalize()` fallback;
- booking an undeclared category errors;
- `record_refund` never skims the levy;
- a hire charged and refunded in the same cycle nets to zero.

### Stage 4 — Release build (F5)

`EventManager._unhandled_input` and `ContractManager._unhandled_input` each start with `if not OS.is_debug_build(): return`. `OS.is_debug_build()` is false only in release exports, so the editor and debug exports keep both keys. The actions stay in `NON_REMAPPABLE_ACTIONS`, because a debug build still binds them and a rebind can still collide with them. Fix the comment above that list (`global.gd:266`), which still says it holds the AIDE key; see F17.

### Stage 5 — Drift guards (F6, F7)

**F6. The script half of the UI sweep.** Add a script sweep to `test_ui_theme.gd` beside the scene sweep, reading `ui/**.gd` as text the same way.

What it flags:
- `add_theme_font_size_override(…, <digits>)`;
- `add_theme_constant_override(…, <non-zero digits>)`;
- `Color(<digit>`, `Color("#` and `Color.html(`;
- `custom_minimum_size = Vector2(<non-zero>`;
- a string literal assigned to `theme_type_variation`.

What it deliberately allows:
- **Zero.** "No gap" isn't a geometry choice.
- **Named engine constants** such as `Color.TRANSPARENT` and `Color.WHITE`.
- **Comment lines.** `pawn_schedule_tab.gd:11` and `atmosphere_component_ui.gd:25` quote old colours in prose.

Exemptions: `OVERRIDE_EXEMPT`, which already covers `ui/menus/` and so settles `new_game_setup.gd` as out-of-game flow; `ui/theme/`, where the tokens are defined; and the world-space files `preview_module.gd`, `selection_brackets.gd`, `overlay_flow_layer.gd`, `click_cycler.gd` and `overlay_palette.gd`. Like the scene half, the sweep has a "found at least N scripts" guard, so an empty scan can't pass.

Then make it pass:
- **`separation 2`** appears in nine or more places (asteroid and pile contents, turboshaft floors, crew wage, the needs tab ×2, the finance tab ×3). It becomes one `UIMetrics.ROW_GAP`.
- **Everything else** gets a per-surface token, in the style `UIMetrics` already uses (`VITALS_CHIP_GAP`, `LEDGER_COLUMN_GAP`, …): build menu rail/flyout/pad, the inspector name stack, social-tab widths, the needs-tab trail width, the trait-chip gap, overlay legend rows, local-upgrade and workspace margins.
- **`Color(0,0,0,0)`** becomes `Color.TRANSPARENT` (seven sites).
- **`module_button.gd:142`**'s 0.45 alpha becomes a `UIPalette` token.
- **The minimap's ten colours** move into `UIPalette` as a `MAP_` block (§0, decision 3). `minimap.gd` stays inside the sweep.

Record the new script half, and `new_game_setup.gd`'s place under the menus exemption, in `04_UI_Rework_Program.md`'s WI-58 section.

**F7. Typing, enforced.** Clear the 97 project-code sites (appendix), then raise the three `gdscript/warnings/*` settings in `project.godot` to 2, excluding the vendored pixel planets (§0, decision 2). Two mechanical patterns cover 34 of the 97:
- **27 sites:** `load(SCENE_PATH).instantiate()` in the static `create()` factories (every widget, alert row, console tile, …). It becomes `(load(SCENE_PATH) as PackedScene).instantiate()`.
- **7 sites:** `material.set_shader_parameter(…)` on an untyped `Material` in `module_base.gd`. Cast to `ShaderMaterial` once; `preview_module.gd`'s six unsafe property accesses are the same shape.

The rest are one or two per file. The count is a lower bound, because a script that fails to compile hides errors in the scripts that depend on it, so re-run the census after each pass until it reads zero. **Close the Godot editor before editing `project.godot`.** It rewrites the file from memory, and the file usually carries the author's uncommitted changes.

### Stage 6 — Cleanup commit (F15–F18)

- ~~**F15.** `crew_manager.gd:272`: guard `shuttle.depart()` with `is_instance_valid(shuttle)`, the way `visitor_manager.gd:168` does.~~ Done in stage 3b.
- **F16.** `git rm` the six tracked `*.tmp` editor files and add `*.tmp` to `.gitignore`.
- **F17.** Delete the stale JobBase-coexistence comments (`job_data.gd:14-15`, `slot_pool.gd:13`, `job_driver.gd:33,40`, `workspace_component.gd:7`, `job.gd:707`) and fix `global.gd:266`.
- **F18 (B5).** In `world_manager.remove_module`, capture `module_data`/`module_cell`/`interaction_layer` into locals before the free, and move `queue_free()` to the end.
- **F18 (B6).** Delete the empty `_process` at `world_manager.gd:66` and the commented-out blocks at `storage_component.gd:296`, `module_turbolift.gd:158` and `pawn_base.gd:378-382`.
- **F18 (C8).** Rename `capacitator` to `capacitor`. It's referenced only in its own file; no scene or resource sets it.
- **F18 (C11).** Give `get_built_modules` a seen-dictionary. Key it on `get_instance_id()`, per the WI-63 rule.
- **F18 (prints).**
  - Delete the four turbolift door `print`s (`module_turbolift.gd:95-106`) and `print("Trader departing…")` (`trader_manager.gd:301`).
  - Turn the genuine diagnostics into `push_warning`, so they reach the log a probe can scan:
    - `construction_component.gd:116`;
    - `pawn_movement_component.gd:249, 252`;
    - `world_manager.gd:128`;
    - `module_graph.gd:42, 184, 200`.
  - A `print` is invisible to exactly the error scan that made the audit's soak trustworthy.
  - Informational prints stay: mods loaded, saved/loaded, raid suppressed.

## Files to touch

| Stage | Files |
|---|---|
| 1 | `scripts/utility/module_queue.gd`, `scripts/utility/module_graph.gd`, `scripts/managers/path_manager.gd`, `scripts/managers/structure_manager.gd`, `modules/transport/turbolift_cab.gd`; new `tests/unit/test_module_queue.gd`, extend `test_module_graph.gd` |
| 2 | `pawns/pawn_suit_component.gd`, `scripts/managers/save_manager.gd`, `scripts/jobs/actions/action_change_suit.gd`, `scripts/jobs/drivers/job_driver_change_suit.gd`, `scripts/utility/cheats.gd`, `pawns/socialize_component.gd`, `objects/asteroid_base.gd`; F21: `pawns/pawn_base.gd`, `pawns/robot_pawn_base.gd`, `pawns/visitor_pawn.gd`; tests in `test_suit_content.gd`, `test_component_save_contract.gd`, `test_component_persistence.gd` |
| 3 | `scripts/managers/economy_manager.gd`, `ui/windows/comms/finance_tab.gd`, `scripts/managers/trader_manager.gd`, `scripts/managers/raid_manager.gd`, `scripts/managers/crew_manager.gd`; `test_economy.gd`, `test_ledger_grouping.gd` |
| 4 | `scripts/managers/event_manager.gd`, `scripts/managers/contract_manager.gd`, `scripts/managers/global.gd` |
| 5 | `tests/unit/test_ui_theme.gd`, `ui/theme/ui_metrics.gd`, `ui/theme/ui_palette.gd`, ~20 `ui/**` scripts (F6); the 50 files in the appendix plus `project.godot` (F7); `04_UI_Rework_Program.md` |
| 6 | `.gitignore`, the six `*.tmp`, `world_manager.gd`, `storage_component.gd`, `module_turbolift.gd`, `pawn_base.gd`, `power_consumption_component.gd`, `trader_manager.gd`, `construction_component.gd`, `pawn_movement_component.gd`, the job/workspace files in F17 |

## Implementation order

1. **F1**, then **F3**, then **F12**. These are the smallest changes with the largest effect, each with its test. Re-run the leak probe (R6) here: it's the cheapest proof the stage worked.
2. **Stage 2.** F2 before F9, so the new pin covers the component in its final shape.
3. **Stage 4.** Two lines.
4. **Stage 6.** Before stage 5, so F7's census runs on the post-cleanup files and nothing gets fixed twice.
5. **Stage 3.**
6. **F6**, then **F7** last. F7 changes `project.godot` and, once at error level, also judges everything this WI wrote, which is the point of doing it last.

## Edge cases

- **F3:** a save → Quit to Menu → New Game → Load sequence exercises `clear()` twice in one process. Both graphs must come back fully functional in the next scene, and they do, because each manager instance builds a fresh `ModuleGraph.new()`. If a future refactor makes the graph a shared resource, `clear()` becomes destructive, so leave a comment saying so.
- **F2 / old saves:** a save written *by the buggy build* after the duplicate trip was already posted contains two `change_suit` jobs for one pawn. `_load_pawn_jobs` adopts the queued ones first and the current job last, so `_trip` ends up on the current job, which is the right one. The queued duplicate runs once as a redundant trip. That's acceptable for a one-time old-save artefact and not worth a migration.
- **F2 / cheats:** `unsuit` during a live putting-on trip leaves the trip in place, and it re-suits the crew member at the airlock. That matches `unsuit`'s own doc comment ("the rule may put it straight back on").
- **F4 / price 0:** a zero-price buy books nothing, because `record_external_cost` returns early for amounts ≤ 0.
- **F4 / insolvency:** booking changes what the ledger *shows*, not the balance, so `EconomyManager`'s insolvency check, which reads the balance, is unaffected. Confirm no alert copy quotes "Net".
- **F4 / history:** old saves' cycle histories lack the new categories and simply don't show them. `opening_balance` is absent on every old record, so "Balance change" hides for history rows until new cycles roll.
- **F6:** a hit inside a string (for example a tooltip containing `Color(`) would false-positive. The sweep anchors on call syntax rather than bare substrings; if a real case turns up, add a single-line allow comment rather than loosening the pattern.
- **F7:** `as PackedScene` returns null if the load fails, and `.instantiate()` on null crashes. That's the same failure as today, so nothing regresses. Don't add null guards that turn a missing scene into silent nothing.

## Verification

1. **GUT.** The full suite stays green (baseline **1,672**), with the new suites and tests from stages 1–3 and F6's sweep on top. **Prove each new guard fails before its fix:** the `ModuleQueue` weakref test on the old `extends Object`, the F6 sweep on the current tree (it should report roughly 40 hits), and the F9 pins against a temporarily renamed key.
2. **Re-run the audit probes** in a scratch copy with its own `user://`. The method is in [[03_Bugs_and_Improvements]]'s 2026-09-18 section. Targets:
   - **R6 (leak cycle):** per-New-Game object growth ≤ ~10 (was +42).
   - **R4 idempotence:** the save → load → save diff is **empty** (F13).
   - **R4, exit leak after two loads:** about half its pre-fix value (was 1,305; 631 after stage 1). Compare against a fresh boot on the *same* build, since stage 1 moved that baseline too.
   - **R5 (72 sim-hours):** non-Node, non-Resource objects plateau after the first sim-day rather than climbing (pre-fix: +~240 per cycle, monotonic), and the exit leak doesn't grow between 24 h and 72 h. Still zero script errors, reservation drift and overfill.
   - **R7 (suit mid-trip across a reload):** zero job restarts, never two `change_suit` jobs in one pawn's queue, suited within about 7 s (the control is 6.9 s).
   - **Resume after a load (F21):** every pawn's restored current job is the first job it begins after the load, and twelve sim-hours of play afterwards show no reservation drift or overfill.
3. **F4, in a real session:**
   - Tier 2 with costs on, a docked trader, one buy and one sell.
   - Purchases and Sales each show their amounts.
   - Operating net + capital spending = Balance change.
   - A hire made then refunded (deconstruct the bay mid-flight) nets to zero.
   - **Screenshot the tab.** Per the UI rules, a screenshot is part of verification.
4. **F5:** in the editor, F6 still fires an event (debug build). The release gate is `OS.is_debug_build()`, which is only false in a release export. Confirm by code review, or with an export if one is being made anyway (the export rewrites `project.godot`; see CLAUDE.md).
5. **F6:** screenshots at 1080p of every panel the sweep touched (the build menu, the inspector strip and tabs, Finance, the Crew Social and Needs tabs). Spacing should be pixel-identical to before, because tokens replace literals one for one.
6. **F7:** with all three warnings at error, `godot --headless --import`, the full GUT run and a boot to the main menu → load quicksave all produce **zero** parse errors.
7. **Close-out:** update CLAUDE.md's suite and test counts (F20), and the WI-68 line in the Planning docs.

## Appendix — F7's 97 sites

Censused 2026-09-18 with the three warnings at error level. **U** = untyped declaration or return type, **M** = unsafe method access, **P** = unsafe property access. It's a lower bound: re-census after each pass.

| # | File | Kinds |
|---|---|---|
| 7 | `modules/templates/module_base.gd` | M7 |
| 7 | `ui/preview_module.gd` | M1 P6 |
| 4 | `modules/transport/turbolift_cab.gd` | M2 U2 |
| 4 | `tests/unit/test_component_save_contract.gd` | M4 |
| 4 | `ui/dialogue/balloon.gd` | M1 P3 |
| 4 | `ui/pawns/pawn_job_tab.gd` | M1 P3 |
| 4 | `ui/ui_debug.gd` | U4 |
| 4 | `ui/windows/ui_storage_component.gd` | P4 |
| 3 | `scripts/managers/contract_manager.gd` | M3 |
| 3 | `scripts/managers/economy_manager.gd` | M3 |
| 3 | `scripts/utility/module_graph.gd` | M2 P1 |
| 3 | `tools/sample_mod/mods/spikemod/scripts/mod_consumer.gd` | M3 |
| 2 each | `data/resources/resource_pile.gd`, `modules/transport/turbolift_shaft.gd`, `objects/asteroid_base.gd`, `pawns/pawn_movement_component.gd`, `scripts/managers/turbolift_manager.gd`, `scripts/pathing/behavior_linked_doors.gd`, `ui/buttons/module_button.gd`, `ui/pawns/pawn_inventory_tab.gd`, `ui/pawns/pawn_schedule_tab.gd` | mixed |
| 1 each | `data/modules/module_data.gd`, `scripts/managers/camera.gd`, `tests/unit/test_minimap.gd`, `tests/unit/test_transmission_log.gd`, `tools/sample_mod/.../class_name_user.gd`, `ui/windows/component_ui_panels/local_upgrades_tab.gd`, `ui/windows/component_ui_panels/workspace_tab.gd` | mixed |
| 1 each (the `create()` pattern) | `ui/alerts/alert_feed.gd`, `alert_history.gd`, `alert_row.gd`, `raid_readout.gd`; `ui/buttons/build_cursor_hint.gd`; `ui/console/mode_button.gd`, `resource_ledger.gd`, `vitals_chip.gd`; `ui/inspector/inspector_panel.gd`, `inspector_tab_plan.gd`; `ui/theme/console_panel.gd`; `ui/theme/widgets/action_button.gd`, `chip.gd`, `list_row.gd`, `section_label.gd`, `stat_bar.gd`, `stepper.gd`, `tab_strip.gd`; `ui/tutorial/tutorial_coach.gd`; `ui/ui_in_game.gd`; `ui/windows/trade/trade_resource_row.gd`; `ui/windows/unlocks/unlock_panel.gd` | M1 |

The sample mod's scripts are in scope: WI-47's "passed with zero core edits" claim is only worth something if the mod compiles under the same rules a modder's code will.
