# WI-71 — Reference Hygiene

> **Status: DRAFT (2026-09-19), not started. Depends on [[WI-69_Integration_Test_Fixture]]** (verification) **and should follow [[WI-70_Job_Ownership_Contract]]**, which converts several of the same files. Scoped from [[05_Architecture_Review]] §A6–A7 and the audits in [[03_Bugs_and_Improvements]]. It closes the rest of **F24**, **F27**, **F28** and **F8**, and **F29** as hygiene. §0's three decisions are the author's to settle; the recommended default is marked on each.

## Goal

Nine of the last findings came down to one question answered wrongly: *is this thing I'm holding still alive?* That covers F22–F24 and F28 here, plus F25/F26's job-shaped cousins, which WI-70 takes. The codebase has four good answers, each used in some places and not others, and one sentence in CLAUDE.md that covers one of the four. This item writes the rule once, applies it to the 35 sites the census found, fixes the two live defects in the class (F27, F28), and adds source sweeps so the rule can't erode.

**Three Godot 4.7 facts this item rests on, all verified during WI-68:**
- a freed object compares `== null` as **true**, typed or untyped, and is falsy;
- a freed object passed to a **typed** Object parameter errors *at the call*, before the body runs, so an `is_instance_valid(param)` inside is dead code (F24);
- iterating a `Dictionary[SomeNode, …]` with a typed loop variable errors on a freed key before any guard inside the loop runs.

The first fact is why F29 turned out to be hygiene rather than a crash: the 218 `== null` guards do catch a freed `Global` slot. It is also why most F24 sites are safe in practice: a caller that compares to null before calling filters the freed object out.

## 0 — Decisions for the author (not yet settled)

1. **Node-keyed member dictionaries (F8): sanction the pairing, don't convert wholesale.** *Recommended.* A long-lived `Dictionary[SomeNode, …]` is allowed when its keys are removed by an explicit lifecycle hook before the node is freed: unregister in `_exit_tree`, `remove_connections` before `queue_free`, or `remove_vertex` on `module_removed`. The allowlist names each dictionary and its hook, and anything without a real pairing converts to `get_instance_id()` keys. This amends the CLAUDE.md sentence under *Tutorial* ("never key a Dictionary on a node") and moves it to *Invariants*, where it belongs. *Alternative:* convert all nine to instance-id keys; this is safer and churns `ModuleGraph`, the most central class in the game.
2. **Stale alert rows (F27): resolve explicitly *and* sweep.** *Recommended.* Resolve the known families on `module_removed` and `crew_departed`. Also let `AlertManager.sweep()` drop any live row whose object subject is no longer valid; the history log keeps the record, as it does for every resolved alert. The second rule overrides the comment at `_on_module_destroyed` ("never drop an alert because its subject went away"), which already carves out the destroyed-module case for the same reason: a subject that no longer exists has no live condition. *Alternative:* explicit resolves only, extended by hand for each new alert family.
3. **Doors (F28, A7): guards now, then a timed wait state.** *Recommended.* Stage 4 is small and fixes the defect. Stage 5 finishes WI-20's job for doors by replacing the awaits with a movement state, and deletes the dead cancel plumbing. It is separable: if the author stops after stage 4, the defect is still fixed and the doc says so.

## Scope

**In:** the rule (§1), the F24 triage and its sweep (§2), F8 and its sweep (§3), F27 (§4), F28 guards (§5), the door wait state (§6), F29 (§7), and, if WI-70 §6 didn't close it, the residual per-load leak (§8).

**Out:**
- turbolift *boarding* (the walk to the waiting spot and the wait for a cab). It is still an `await` chain, contrary to the review's claim that doors are the last one, but it already checks `request.cancelled` and `is_instance_valid(pawn)` after every await, and its teardown goes through `TurboliftManager.remove_turbolift_module`. Recorded, not changed.
- anything job-shaped (WI-70).

## Design

### 1 — The rule

Replaces the node-keyed-dictionary sentence in CLAUDE.md and goes under *Invariants*:

> **Nothing keeps a reference to a node it doesn't own past the current frame without one of these four disciplines:**
> 1. **a job** holds it as a `JobTarget`;
> 2. **anything saved** holds it as a `*_ref` (`SaveManager`'s helpers);
> 3. **a member `Dictionary`** keys it by `get_instance_id()`, or is on the pairing allowlist (§3);
> 4. **a function that receives it** from a signal payload, a bound `Callable`, a stored field or across an `await` takes it as `Variant` and checks `is_instance_valid`.
>
> A typed Object parameter means "every caller passes a live object or null". **After any `await`, re-check every node you touch.**

### 2 — F24: triage the 35 sites, then sweep

The census (script in the appendix; run on the 2026-09-19 tree) finds **35** functions that take a typed Object parameter and check `is_instance_valid` on it. Each gets one of three outcomes:
- **(a) The check follows an `await`.** It is legitimate: the parameter was live when the call started and may have died since. Keep it. Four sites: `crew_manager._on_shuttle_docked`, `visitor_manager._on_shuttle_docked`, `trader_manager._courier_collect`, `turbolift_shaft.request_ride`.
- **(b) A caller can pass a freed reference without comparing it to null first**, typically a stored field, a bound argument or a signal payload. Change the parameter to `Variant` and cast after the check (the F24 pattern WI-68 used for `module_ref`).
- **(c) Every caller passes a live object or null.** Replace `is_instance_valid(p)` with `p != null`, so the function stops claiming protection it doesn't have. Behaviour is identical.

The triage question per site is the one fact the census can't answer: *what do the callers pass?* Read each call site and record the outcome in the appendix table.

Then add `tests/unit/test_reference_hygiene.gd`, a text sweep in `test_ui_theme`'s shape, porting the census logic to GDScript. It fails on an `is_instance_valid(<typed Object param>)` that appears **before the function's first `await`**, and needs no allowlist once the triage is done. It also has a "found at least N functions" guard so an empty scan can't pass.

### 3 — F8: node-keyed member dictionaries

Nine member (long-lived) dictionaries key on a node. Local dictionaries built and dropped inside one function (`seen`, `registration`, `changed`, the pathfinder's `came_from`) never outlive the frame and are out of scope.

| Dictionary | Pairing that removes a key before its node is freed |
|---|---|
| `AtmosphereManager._components`, `_low_o2_alerted` | `unregister_component`; confirm it runs from the component's exit path |
| `HeatManager._components` | `unregister_component`, as above |
| `ModuleGraph._vertices` | `remove_vertex` on `module_removed` and a pawn's `PREDELETE`; `clear()` since WI-68 F3 |
| `StructureComponent.module_connections` (and its signal's type) | `remove_connections()`, which `remove_module` calls before `queue_free` |
| `PathComponent.module_connections` | the same |
| `CrewPanel._rows` | rebuilt on `crew_departed`; confirm it can't be iterated between the free and the rebuild |
| `StoresPanel._cards` | confirm, or convert |
| `ModuleTabSet._errors` (new since F8) | confirm, or convert |

Confirm each pairing by reading. Convert anything whose pairing doesn't hold, and the two F8 named as crashing the moment a pairing slips: `HeatManager._neighbours` iterating another component's `module_connections` with a typed loop variable, and `CrewPanel`'s typed loop at the old `crew_panel.gd:601`. Then add a sweep: a member `var` declared as `Dictionary[<node class>,` must appear on an allowlist in the test with its pairing named.

### 4 — F27: alerts about things that are gone

- Resolve `breach`, `low_o2`, `breakdown` and `cut_vertex` on `module_removed`, which is a superset of `module_destroyed`: deconstruction removes a module without destroying it (`construction_component.gd`, the `Deconstructed` branch).
- Resolve a departed pawn's `need_*`, `suit_up` and `disease_*` rows on `crew_departed`, not only `resigning` (`alert_manager.gd:451`).
- Per §0.2, `sweep()` drops any live alert whose `subject` is an object that is no longer valid.

`AlertRules.make_id()` already takes its subject as `Variant` and checks validity, so it needs nothing.

### 5 — F28, stage 1: the door hooks stop latching

Two defects, both small:
- **`_busy_in_hook` latches.** `PawnMovementComponent` sets it around `path_exit`/`path_enter` and clears it after the await (`pawn_movement_component.gd:271`, `:292`). If the module is freed mid-hook, an `animation_finished` await never resumes, and `is_traveling()` answers true for the rest of the pawn's life. It is read by `PawnStatus` (the roster sentence) and `RobotPowerComponent` (the moving-drain rate). **Fix:** record the hooking module's instance id and clear the flag in the component's existing `module_removed` handler when it matches.
- **Awaits resume on freed nodes.** `Behavior_SlidingDoor` and `Behavior_LinkedDoors` `await Global.time_manager.sim_seconds(...)` and then touch the door sprite, both in the hooks and in the auto-close lambdas each registers in `create_state`. `ModuleTeleporter.traverse` awaits its lightning sprite. **Fix:** `is_instance_valid(<sprite>)` after every await, returning early.

### 6 — A7, stage 2: doors become a timed movement state

This finishes WI-20 for doors. The constraints:
- **no coroutine that touches a module node is suspended across a frame in the door path.** The door animation is started and forgotten; the pawn waits in a `DoorWait` movement state whose sim-time timer `_process` ticks;
- **door visuals are unchanged:** the same open, hold and close, checked by a before/after capture of a crew member crossing an airlock at 1× and 4×;
- **the turbolift keeps its own `path_exit` override** and its awaitable boarding (§Scope). So `ModuleBase.path_enter`/`path_exit` stay awaitable for it, and only the `PathBehavior` door path changes;
- **afterwards `is_traveling()` is a pure function of `state`**, and `_busy_in_hook`, `PathBehaviorContext.cancelled` and the `cancel_signal` parameters are deleted. They are dead today: nothing reads `cancelled`.

The auto-close timers move with it: a door's close countdown becomes state on its `LinkedDoorsState` or its sliding equivalent, ticked by the owning `PathComponent`, so it dies with the module instead of resuming in a lambda.

The API shape (whether `PathBehavior` returns a wait duration, or the movement component asks the module for one before crossing) is this stage's first design task. Record the choice in the status block.

### 7 — F29 as hygiene

Every manager nulls its own `Global` slot in `_exit_tree`, the pattern `StoryState`, `DialogueRunner` and `TutorialManager` already follow. In Godot 4.7 this changes no behaviour, since a freed slot already compares `== null`. What it buys is that `is_instance_valid(Global.x)` and the debugger both tell the truth after a Quit to Menu. It's one line per manager, about 27 lines in all.

### 8 — The residual per-load leak, if WI-70 left it

If WI-70 §6's measurement shows the ~43-object residual wasn't board jobs, the hunt continues here, with the first audit's recipe: bisect by class, not by `--verbose`, which names only base classes. Record what it was.

## Files to touch

| | Files |
|---|---|
| New | `tests/unit/test_reference_hygiene.gd` (both sweeps) |
| F24 | the 35 files in the appendix, one or two lines each |
| F8 | `heat_manager.gd`, `crew_panel.gd`, and any dictionary whose pairing doesn't hold |
| F27 | `scripts/managers/alert_manager.gd` |
| F28 / A7 | `pawns/pawn_movement_component.gd`, `scripts/pathing/behavior_sliding_door.gd`, `behavior_linked_doors.gd`, `path_behavior.gd`, `path_behavior_context.gd` (deleted in stage 2), `modules/templates/module_base.gd`, `modules/components/path_component.gd`, `modules/transport/module_teleporter.gd` |
| F29 | every manager under `scripts/managers/` that registers into `Global` |
| Docs | `CLAUDE.md` (§1's rule, the moved dictionary sentence), [[01_Technical_Specification]] §1.4 (movement states) |

## Implementation order

1. §5, stage 1. It is small, fixes a live defect, and the other stages don't depend on it.
2. §4 (F27).
3. §2: triage, then the sweep. Write the sweep last, so it goes green on the triaged tree rather than red on the first run.
4. §3.
5. §7.
6. §6, stage 2, its own commit, with the before/after capture.
7. §8 only if needed.

## Edge cases

- **A (b) site whose parameter becomes `Variant`** loses static typing in its body. Cast once to a typed local after the check, so the rest of the function stays typed (warnings are errors since WI-68).
- **The F24 sweep and lambdas.** A lambda's parameters are parameters too, so the sweep must parse `func(` inside bodies. Or exclude lambdas explicitly and say so in the test's header.
- **A door already open when stage 2 lands** (mid-crossing at save time) is cosmetic. Doors aren't saved, so a load starts them closed, as today.
- **An alert whose subject is a Resource** (never freed the way a node is) is left alone by §4's sweep rule. The rule is only for Node subjects.

## Verification

1. **GUT unit:** both sweeps green, and each fails on a seeded violation (a typed-param check added to a scratch file; an unlisted node-keyed member).
2. **GUT integration (WI-69):**
   - destroy a module while a crew member is inside its door hook: no script error, and `is_traveling()` is false once the pawn stops;
   - deconstruct a module with a live breakdown alert: the row is gone and the history keeps it;
   - a crew member departs with a critical need raised: the row is gone;
   - Quit to Menu, then new game: every `Global` manager slot is valid again.
3. **Screenshots:** a crew member crossing an airlock at 1× and 4×, before and after stage 2, frame for frame.
4. The F24 appendix table is filled in, one outcome per site.

## Appendix — F24's 35 sites (census of 2026-09-19)

Found by a script that parses every function header, keeps parameters typed as an Object class, and flags an `is_instance_valid(<param>)` in the body. The logic belongs in §2's sweep. **(a)** marks the four with an `await` before the check. The rest need their callers read (§2).

| Site | Parameter | Outcome |
|---|---|---|
| `modules/components/conveyor_component.gd:238` `_endpoint_alive` | `endpoint: ComponentBase` | |
| `modules/transport/turbolift_shaft.gd:54` `request_ride` | `pawn: PawnBase` | (a) |
| `pawns/pawn_suit_component.gd:176` `_environment_of` | `module: ModuleBase` | |
| `pawns/pawn_suit_component.gd:217` `_is_airlock` | `module: ModuleBase` | |
| `pawns/pawn_suit_component.gd:317` `_raise_alert` | `module: ModuleBase` | |
| `pawns/pawn_suit_component.gd:336` `_reason_for` | `module: ModuleBase` | |
| `pawns/pawn_suit_component.gd:350` `_reading` | `module: ModuleBase` | |
| `scripts/jobs/finders/finder_airlock.gd:47` `is_habitable` | `module: ModuleBase` | |
| `scripts/managers/alert_manager.gd:426` `_pawn_label` | `pawn: PawnBase` | |
| `scripts/managers/claim_registry.gd:206` `_is_claimable` | `target: Object` | |
| `scripts/managers/crew_manager.gd:96` `_spawn_starting_crew` | `home: ModuleBase` | |
| `scripts/managers/crew_manager.gd:289` `_on_shuttle_docked` | `shuttle: ArrivalShuttle` | (a) |
| `scripts/managers/crew_manager.gd:376` `fire_crew` | `pawn: PawnBase` | |
| `scripts/managers/economy_manager.gd:551` `fire_pawn` | `pawn: PawnBase` | |
| `scripts/managers/trader_manager.gd:294` `_courier_collect` | `shuttle: ArrivalShuttle` | (a) |
| `scripts/managers/tutorial_manager.gd:450` `fire` | `subject: Node` | |
| `scripts/managers/visitor_manager.gd:168` `_on_shuttle_docked` | `shuttle: ArrivalShuttle` | (a) |
| `scripts/managers/world_manager.gd:80` `get_canvas_for_module` | `module: ModuleBase` | |
| `scripts/utility/pawn_status.gd:341` `facts_for` | `pawn: PawnBase` | |
| `scripts/utility/pawn_status.gd:380` `location_of` | `pawn: PawnBase` | |
| `scripts/utility/stores_model.gd:182` `lists` | `component: StorageComponent` | |
| `scripts/utility/stores_model.gd:212` `contents_editable` | `component: StorageComponent` | |
| `scripts/utility/stores_model.gd:235` `priority_editable` | `component: StorageComponent` | |
| `scripts/utility/stores_model.gd:250` `priority_locked_reason` | `component: StorageComponent` | |
| `scripts/utility/stores_model.gd:269` `locked_reason` | `component: StorageComponent` | |
| `ui/dialogue/balloon.gd:307` `start` | `with_dialogue_resource: DialogueResource` | |
| `ui/inspector/tabs/robot_vitals_tab.gd:77` `state_text` | `robot: RobotPawnBase` | |
| `ui/overlay_controller.gd:367` `_refresh_one` | `module: ModuleBase` | |
| `ui/overlay_flow_layer.gd:118` `_endpoint_module` | `endpoint: ComponentBase` | |
| `ui/pawns/pawn_social_tab.gd:179` `_display_name` | `target: PawnBase` | |
| `ui/tutorial/tutorial_coach.gd:289` `_control_rect` | `control: Control` | |
| `ui/ui_in_game.gd:64` `set_selected_pawn` | `pawn: PawnBase` | |
| `ui/windows/crew_panel.gd:551` `_apply_action` | `button: ActionButton` | |
| `ui/windows/storage_overlays.gd:78` `open_edit` | `component: StorageComponent` | |
| `ui/windows/storage_overlays.gd:191` `open_resource` | `component: StorageComponent` | |

`ui/dialogue/balloon.gd` sits in the vendored Dialogue Manager balloon the project customised (WI-62). Triage it like the rest; the directory rule excludes `addons/`, not this file.

## Related

- [[WI-68_Audit_Fix_Pass]]: F23 and F24's first fixes, and the three Godot facts above.
- [[WI-20_Movement_and_Animation]]: the `CONVEYED` state §6 extends to doors.
- [[WI-63_Tutorial]]: where the dictionary rule was first written down.
