# WI-71 — Reference Hygiene

> **Status: DONE (2026-09-19).** §0's three decisions were taken as recommended: the pairing
> allowlist (§0.1), explicit resolves *and* a sweep (§0.2), guards-only for doors with the
> coroutines left to [[WI-75_Movement_Without_Coroutines]] (§0.3, already settled). Closes the
> rest of **F24** (36 sites triaged, not 35 — WI-70 added one), **F27**, **F28**'s two defects,
> **F8** and **F29**. Verified by 1782 unit tests (96 suites) and 41 integration tests (10
> suites), both green, plus each new test re-run against the un-fixed code to prove it fails.
>
> **What shipped that the plan did not say:**
> - **Two more Godot 4.7 facts, both measured** (probe in the scratchpad, not kept). **`as` on a
>   freed object is a script error** — `"Trying to cast a freed object"` — which aborts the
>   calling function, so every cast belongs *after* its validity check, never before. And the
>   typed-dictionary error is about the **dictionary's key type**, not the loop variable's: an
>   untyped `for k in d` errors too, `d[freed_key]` and `d.duplicate()` error, while `keys()`,
>   `values()`, `size()`, `has()`, `get()` and `erase()` are all safe. That last fact is what
>   makes `for k in d.keys(): if not is_instance_valid(k): continue` the one safe way to walk a
>   node-keyed dictionary you do not own, and it is how `HeatManager._neighbours` now reads.
> - **The lambda carve-out runs the other way.** §"Edge cases" worried that a lambda's own
>   parameters would be missed. The real case is the reverse: `StorageOverlays.open_edit` and
>   `open_resource` check `is_instance_valid(component)` *inside* a `dialog.confirmed` lambda,
>   where `component` is a **captured local**, not a parameter crossing a typed boundary — that
>   is discipline 4, so the sweep skips lambda bodies and says so in its header.
> - **§2's triage found one more live defect than the plan expected.** Three (b) sites, not the
>   "typically" of the design: `CrewManager._spawn_starting_crew` (bound into a `call_deferred`),
>   `OverlayFlowLayer._endpoint_module` (reads another component's stored `ConveyorLane`
>   endpoints, so the whole overlay pass aborted if one had been deconstructed), and
>   `ConveyorComponent._endpoint_alive`, which was **inert**: `lane.source != null and not
>   _endpoint_alive(lane.source)` is false for a freed endpoint, because a freed object compares
>   equal to null — so the one function written to notice a dead endpoint never did, and the
>   lane kept its dangling reference with no status line. It is now `_endpoint_dead(Variant)`
>   asked without a pre-guard. `TraderManager._courier_collect` checked its shuttle *before* a
>   one-hour `await` and touched it *after*; the hire and visitor shuttles had always had that
>   guard on the correct side.
> - **§3 found eleven node-keyed member dictionaries, not nine.** `TurboliftCab.assigned_locations`
>   (allowlisted: the keys are the cab's own child markers) and `TurboshaftFloorsTab._rows`, which
>   turned out to be **write-only** — assigned and cleared, never read — so it was deleted rather
>   than allowlisted. `CrewPanel._rows` was the one with no real pairing and is now keyed on
>   `get_instance_id()`: `refresh()` early-returns while the roster is off screen, so a crew
>   member who dies with the HIRE tab open leaves a dangling key that `_paint_selection` iterates
>   on the next click.
> - **§4 resolves by subject rather than by family.** The design listed four module families and
>   three pawn ones; a list of eleven strings in a third file is a list that goes stale, so
>   `AlertManager.resolve_for_subject(subject)` drops every live row about the thing instead. The
>   sweep half is `AlertRules.orphaned()`, pure and unit-tested. `module_destroyed` now has **no
>   listener at all** — it joins F11's dead-signal list for [[WI-72_Declared_Vocabularies_And_Content_Guards]].
> - **§7 covers 27 slots, not 27 lines of managers only.** `Global.ui_main`, `Global.ui_in_game`
>   and `Global.stellar_background` self-register the same way and get the same treatment; three
>   managers already had an `_exit_tree` and had the two lines appended to it.
> - **§8 was dropped**, as its own note said it should be: WI-70 §6 measured that there is no
>   per-load leak to hunt.
> - **In-game check of the one visible surface.** `CrewPanel._rows` is the only change a screenshot could speak to, so the game was driven through the menu into a new game, `C` opened Crew, and a roster row was clicked: the panel headers, filters, sort, both rows, the summary line and the footer all render, and the click raised the inspector with the crew rail - so `_paint_selection` walks the id-keyed dictionary correctly. The game log was clean through the whole session. (A trap worth knowing: the roster rebuilds its rows on every slow tick, so a synthesised press and release seconds apart land on two different Buttons and nothing fires. Pause the sim first.) `TurboshaftFloorsTab._rows` needed none: nothing read it.
>
> Scoped from [[05_Architecture_Review]] §A6–A7 and the audits in [[03_Bugs_and_Improvements]].
> Depends on [[WI-69_Integration_Test_Fixture]] (verification) and follows
> [[WI-70_Job_Ownership_Contract]].


## Goal

Nine of the last findings came down to one question answered wrongly: *is this thing I'm holding still alive?* That covers F22–F24 and F28 here, plus F25/F26's job-shaped cousins, which WI-70 takes. The codebase has four good answers, each used in some places and not others, and one sentence in CLAUDE.md that covers one of the four. This item writes the rule once, applies it to the 36 sites the census found, fixes the live defects in the class (F27, F28, and three more the triage turned up), and adds source sweeps so the rule can't erode.

**Five Godot 4.7 facts this item rests on.** The first three were verified during WI-68; the last two, and the correction to the third, were measured during this item:
- a freed object compares `== null` as **true**, typed or untyped, and is falsy — and it can be held in a typed local, read out of a typed `Dictionary`'s **values**, and passed to a `Variant` parameter, all without complaint;
- a freed object passed to a **typed** Object parameter errors *at the call*, before the body runs, so an `is_instance_valid(param)` inside is dead code (F24);
- iterating a `Dictionary[SomeNode, …]` errors on a freed key inside `Dictionary.next()`. **Corrected:** the check is on the *dictionary's* key type, not the loop variable's, so an untyped loop variable errors too. `d[freed_key]` and `d.duplicate()` error as well; `keys()`, `values()`, `size()`, `has()`, `get()` and `erase()` do not — which makes `for k in d.keys(): if not is_instance_valid(k): continue` the one safe walk;
- **`as` on a freed object is a script error** (`"Trying to cast a freed object"`) that aborts the calling function, so a cast always goes *after* its validity check — which is why every `Variant` parameter in §2 checks first and casts second;
- a freed object still reports `typeof(...) == TYPE_OBJECT`, which is how `_endpoint_dead` and `AlertRules.orphaned` tell "was set and has died" from "was never set".

The first fact is why F29 turned out to be hygiene rather than a crash: the 218 `== null` guards do catch a freed `Global` slot. It is also why most F24 sites are safe in practice: a caller that compares to null before calling filters the freed object out.

## 0 — Decisions for the author (all settled 2026-09-19, each taken as recommended)

1. **Node-keyed member dictionaries (F8): sanction the pairing, don't convert wholesale.** *Recommended.* A long-lived `Dictionary[SomeNode, …]` is allowed when its keys are removed by an explicit lifecycle hook before the node is freed: unregister in `_exit_tree`, `remove_connections` before `queue_free`, or `remove_vertex` on `module_removed`. The allowlist names each dictionary and its hook, and anything without a real pairing converts to `get_instance_id()` keys. This amends the CLAUDE.md sentence under *Tutorial* ("never key a Dictionary on a node") and moves it to *Invariants*, where it belongs. *Alternative:* convert all nine to instance-id keys; this is safer and churns `ModuleGraph`, the most central class in the game.
2. **Stale alert rows (F27): resolve explicitly *and* sweep.** *Recommended.* Resolve the known families on `module_removed` and `crew_departed`. Also let `AlertManager.sweep()` drop any live row whose object subject is no longer valid; the history log keeps the record, as it does for every resolved alert. The second rule overrides the comment at `_on_module_destroyed` ("never drop an alert because its subject went away"), which already carves out the destroyed-module case for the same reason: a subject that no longer exists has no live condition. *Alternative:* explicit resolves only, extended by hand for each new alert family.
3. **Doors (F28, A7): guards here, and the coroutines go in [[WI-75_Movement_Without_Coroutines]].** *Settled 2026-09-19, on the author's question.* §5's guards fix the defect and are correct on their own terms. Removing the awaits is **not** a door-sized change: `ModuleBase.path_exit` is awaited for turbolift boarding as well, so `_busy_in_hook` cannot be deleted while any hook still awaits, and a door-only rework buys less than it claims. The whole movement await surface (37 awaits across nine files, one entry point) moves to its own item. *Alternative:* do doors alone anyway, and keep the latch.

## Scope

**In:** the rule (§1), the F24 triage and its sweep (§2), F8 and its sweep (§3), F27 (§4), F28 guards (§5), F29 (§7).

**Out:**
- **every await in the movement pipeline** - doors, the teleporter, turbolift boarding and the movement component's own chain. That is [[WI-75_Movement_Without_Coroutines]] (§6 below), and this item only stops the current ones from resuming on a freed node.
- the residual per-load leak: WI-70 §6 measured it and it does not exist, so the old §8 has nothing to do.
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

The census (now `tests/unit/test_reference_hygiene.gd`, which re-derives it on every run) finds **36** functions that take a typed Object parameter and check `is_instance_valid` on it. Each gets one of three outcomes:
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

### 6 — The awaits themselves: [[WI-75_Movement_Without_Coroutines]]

Not this item, per §0.3. §5 leaves every await in place and guarded, which is a complete fix for F28's two defects. What it cannot do is delete `_busy_in_hook` or make `is_traveling()` a pure function of `state`: `PawnMovementComponent` awaits `path_exit`, and the turbolift's override of it awaits all the way through boarding, so the latch is still load-bearing for rides. Doing doors alone would leave the same latch, the same dead `PathBehaviorContext.cancelled`, and a second half-measure in the same code.

WI-75 takes the whole surface at once, including the auto-close timers and the teleporter.

### 7 — F29 as hygiene

Every manager nulls its own `Global` slot in `_exit_tree`, the pattern `StoryState`, `DialogueRunner` and `TutorialManager` already follow. In Godot 4.7 this changes no behaviour, since a freed slot already compares `== null`. What it buys is that `is_instance_valid(Global.x)` and the debugger both tell the truth after a Quit to Menu. It's one line per manager, about 27 lines in all.

### 8 — The residual per-load leak, if WI-70 left it

If WI-70 §6's measurement shows the ~43-object residual wasn't board jobs, the hunt continues here, with the first audit's recipe: bisect by class, not by `--verbose`, which names only base classes. Record what it was.

> *(2026-09-19, WI-70 §6 measured it: **there is nothing to hunt.** The exit-time leak count doesn't grow with the number of loads, before WI-70 or after: on the real quicksave it was 635 / 634 / 630 after 1 / 3 / 5 loads on the old code and 635 / 631 / 631 on the new. A fresh new game with no load leaks 597-602. WI-68's "two loads: 631 against a fresh boot's 544" compared a loaded game against a new game, so the ~40 is a one-time difference in what a loaded station has resolved and cached, not a per-load leak. The board-job cycles WI-70 removed were real, but they broke themselves: freeing an owner disconnects it as a signal target, which drops the bound job. Drop this section unless something else shows a per-load growth.)*

## Files to touch

| | Files |
|---|---|
| New | `tests/unit/test_reference_hygiene.gd` (both sweeps) |
| F24 | the 35 files in the appendix, one or two lines each |
| F8 | `heat_manager.gd`, `crew_panel.gd`, and any dictionary whose pairing doesn't hold |
| F27 | `scripts/managers/alert_manager.gd` |
| F28 (§5) | `pawns/pawn_movement_component.gd`, `scripts/pathing/behavior_sliding_door.gd`, `behavior_linked_doors.gd`, `modules/transport/module_teleporter.gd` |
| F29 | every manager under `scripts/managers/` that registers into `Global` |
| Docs | `CLAUDE.md` (§1's rule, the moved dictionary sentence), [[01_Technical_Specification]] §1.4 (movement states) |

## Implementation order

1. §5, stage 1. It is small, fixes a live defect, and the other stages don't depend on it.
2. §4 (F27).
3. §2: triage, then the sweep. Write the sweep last, so it goes green on the triaged tree rather than red on the first run.
4. §3.
5. §7.
6. Nothing else: §6 is [[WI-75_Movement_Without_Coroutines]].

## Edge cases

- **A (b) site whose parameter becomes `Variant`** loses static typing in its body. Cast once to a typed local after the check, so the rest of the function stays typed (warnings are errors since WI-68).
- **The F24 sweep and lambdas.** A lambda's parameters are parameters too, so the sweep must parse `func(` inside bodies. Or exclude lambdas explicitly and say so in the test's header.
- **An alert whose subject is a Resource** (never freed the way a node is) is left alone by §4's sweep rule. The rule is only for Node subjects.

## Verification

1. **GUT unit:** both sweeps green, and each fails on a seeded violation (a typed-param check added to a scratch file; an unlisted node-keyed member).
2. **GUT integration (WI-69):**
   - destroy a module while a crew member is inside its door hook: no script error, and `is_traveling()` is false once the pawn stops;
   - deconstruct a module with a live breakdown alert: the row is gone and the history keeps it;
   - a crew member departs with a critical need raised: the row is gone;
   - Quit to Menu, then new game: every `Global` manager slot is valid again.
3. The F24 appendix table is filled in, one outcome per site.

## Appendix — F24's sites (census of 2026-09-19, triaged 2026-09-19)

Found by a script that parses every function header, keeps parameters typed as an Object class, and flags an `is_instance_valid(<param>)` in the body. The logic is now §2's sweep, `tests/unit/test_reference_hygiene.gd`, which re-derives this list on every run.

**36 sites, not 35:** WI-70 added `Job._offer` between the census and this pass. Outcomes: **4 (a)**, **2 (lambda)**, **3 (b)**, **27 (c)**.

| Site | Parameter | Outcome |
|---|---|---|
| `modules/components/conveyor_component.gd` `_endpoint_alive` | `endpoint: ComponentBase` | **(b)** — now `_endpoint_dead(Variant)`, asked with no `!= null` pre-guard: the old form was false for exactly the freed endpoint it existed to catch |
| `modules/transport/turbolift_shaft.gd` `request_ride` | `pawn: PawnBase` | (a) |
| `pawns/pawn_suit_component.gd` `_environment_of` | `module: ModuleBase` | (c) — `owner_pawn.current_module`, nulled by `PawnBase._on_module_removed` before the free |
| `pawns/pawn_suit_component.gd` `_is_airlock` | `module: ModuleBase` | (c) — same source |
| `pawns/pawn_suit_component.gd` `_raise_alert` | `module: ModuleBase` | (c) — same source |
| `pawns/pawn_suit_component.gd` `_reason_for` | `module: ModuleBase` | (c) — same source |
| `pawns/pawn_suit_component.gd` `_reading` | `module: ModuleBase` | (c) — same source |
| `scripts/jobs/finders/finder_airlock.gd` `is_habitable` | `module: ModuleBase` | (c) — a group scan, and `JobTarget.module()`, which answers null for a dead target |
| `scripts/jobs/job.gd` `_offer` *(new since the census)* | `candidate: Object` | (c) — the pawn's own component list, and `JobTarget.object()` |
| `scripts/managers/alert_manager.gd` `_pawn_label` | `pawn: PawnBase` | (c) — live signal payloads only |
| `scripts/managers/claim_registry.gd` `_is_claimable` | `target: Object` | (c) — a driver's action, or a `ClaimSpec` already asked `is_alive()` |
| `scripts/managers/crew_manager.gd` `_spawn_starting_crew` | `home: ModuleBase` | **(b)** — `call_deferred`, so the module can be gone a frame later |
| `scripts/managers/crew_manager.gd` `_on_shuttle_docked` | `shuttle: ArrivalShuttle` | (a) |
| `scripts/managers/crew_manager.gd` `fire_crew` | `pawn: PawnBase` | (c) — via `fire_pawn`, whose caller checks its captured pawn |
| `scripts/managers/economy_manager.gd` `fire_pawn` | `pawn: PawnBase` | (c) — the inspector's FIRE confirmation checks first |
| `scripts/managers/trader_manager.gd` `_courier_collect` | `shuttle: ArrivalShuttle` | (a) — **after** moving the check to the far side of the one-hour await, where the hire and visitor shuttles already had it |
| `scripts/managers/tutorial_manager.gd` `fire` | `subject: Node` | (c) — signal payloads, a group scan, the cheat console's nearest-crew lookup |
| `scripts/managers/visitor_manager.gd` `_on_shuttle_docked` | `shuttle: ArrivalShuttle` | (a) |
| `scripts/managers/world_manager.gd` `get_canvas_for_module` | `module: ModuleBase` | (c) — an `owner_module`, a `current_module` or a lookup |
| `scripts/utility/pawn_status.gd` `facts_for` | `pawn: PawnBase` | (c) — every surface holding a pawn checks it first; the rest read a fresh roster |
| `scripts/utility/pawn_status.gd` `location_of` | `pawn: PawnBase` | (c) — reached only through a guarded `refresh()` |
| `scripts/utility/stores_model.gd` `lists` | `component: StorageComponent` | (c) — the entry points all walk a live set |
| `scripts/utility/stores_model.gd` `contents_editable` | `component: StorageComponent` | (c) — same |
| `scripts/utility/stores_model.gd` `priority_editable` | `component: StorageComponent` | (c) — same |
| `scripts/utility/stores_model.gd` `priority_locked_reason` | `component: StorageComponent` | (c) — same; its "This bin is gone" branch now answers for null, which is what it can honestly answer for |
| `scripts/utility/stores_model.gd` `locked_reason` | `component: StorageComponent` | (c) — same |
| `ui/dialogue/balloon.gd` `start` | `with_dialogue_resource: DialogueResource` | (c) — a Resource is refcounted and cannot be freed under a live reference |
| `ui/inspector/tabs/robot_vitals_tab.gd` `state_text` | `robot: RobotPawnBase` | (c) — both callers check their stored robot first |
| `ui/overlay_controller.gd` `_refresh_one` | `module: ModuleBase` | (c) — three signal handlers |
| `ui/overlay_flow_layer.gd` `_endpoint_module` | `endpoint: ComponentBase` | **(b)** — reads another component's stored `ConveyorLane` endpoints, which keep their reference until that conveyor's next validation tick |
| `ui/pawns/pawn_social_tab.gd` `_display_name` | `target: PawnBase` | (c) — a fresh `get_crew()` roster, and this tab's own guarded pawn |
| `ui/tutorial/tutorial_coach.gd` `_control_rect` | `control: Control` | (c) — the target is re-resolved from the live HUD every frame |
| `ui/ui_in_game.gd` `set_selected_pawn` | `pawn: PawnBase` | (c) — the inspector clears itself the frame its subject dies |
| `ui/windows/crew_panel.gd` `_apply_action` | `button: ActionButton` | (c) — the panel's own child |
| `ui/windows/storage_overlays.gd` `open_edit` | `component: StorageComponent` | **(lambda)** — checked inside `dialog.confirmed`, where it is a captured local |
| `ui/windows/storage_overlays.gd` `open_resource` | `component: StorageComponent` | **(lambda)** — same |

`ui/dialogue/balloon.gd` sits in the vendored Dialogue Manager balloon the project customised (WI-62); the directory rule excludes `addons/`, not this file, and it was triaged like the rest.

### §3's eleven, and their pairings

Nine are allowlisted in `test_reference_hygiene.gd`'s `PAIRED` with the hook named; the sweep fails on a tenth that is not, and on a listed one whose field has gone (a pairing for a dictionary that no longer exists allows nothing, and would hide the same field under a new name).

| Dictionary | Outcome |
|---|---|
| `PathComponent.module_connections` | paired — `remove_connections()` / `disconnect_from()`, from `WorldManager.remove_module` before the `queue_free` |
| `StructureComponent.module_connections` | paired — the same path |
| `TurboliftCab.assigned_locations` *(not on the plan's list)* | paired — the keys are the cab's own `standing_locations` markers |
| `AtmosphereManager._components`, `._low_o2_alerted` | paired — `unregister_component()` from the component's `_exit_tree`, which runs at the `remove_child` inside `remove_module` |
| `HeatManager._components` | paired — the same |
| `ModuleGraph._vertices` | paired — `remove_vertex()` on `module_removed`, on a pawn's `PREDELETE`, on an asteroid's or cab's teardown, plus `clear()` (WI-68 F3). Never iterated as keys, only through `.values()` |
| `ModuleTabSet._errors` | paired — the keys are the bound module's own components, and `InspectorPanel` clears the set the frame `is_alive()` turns false |
| `StoresPanel._cards` | paired — `_rebuild()` clears it, and every lookup uses a component taken fresh from `_collect_entries()` in the same call |
| `CrewPanel._rows` | **converted** to `Dictionary[int, CrewRosterRow]` — `refresh()` early-returns while the roster is off screen, so the pairing does not hold |
| `TurboshaftFloorsTab._rows` *(not on the plan's list)* | **deleted** — written and cleared, never read |

`HeatManager._neighbours` iterates a dictionary it does **not** own, which is where a slip becomes a crash; it now walks `structure.module_connections.keys()` with the guard outside the indexing.

## Related

- [[WI-68_Audit_Fix_Pass]]: F23 and F24's first fixes, and the three Godot facts above.
- [[WI-20_Movement_and_Animation]]: the `CONVEYED` state, and the rule [[WI-75_Movement_Without_Coroutines]] finishes.
- [[WI-63_Tutorial]]: where the dictionary rule was first written down.
