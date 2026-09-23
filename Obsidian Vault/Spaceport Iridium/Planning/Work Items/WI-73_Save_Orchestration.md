# WI-73 — Save Orchestration

> **Status: DONE (2026-09-22).** §0's three decisions were all taken as recommended: section orders stay integers, gathered into one table (§0.1); `SaveManager` split into three files with no forwarding shims (§0.2); only the kind-specific pawn fields moved onto the pawn classes (§0.3). Verified by **1845 unit tests (102 suites)** and **47 integration tests (12 suites)**, both green; by eight seeded faults, each failing the test meant to catch it (SaveManager dragged above TutorialManager, an undocumented manager node, `world` renumbered above `pawns`, a registrant passing its own literal, a pawn-kind key renamed, an `is VisitorPawn` branch put back in the pawn section, a hauler that doesn't re-register on load, a guest's block renamed), with every file restored byte-for-byte after; and by the real quicksave, loaded and re-saved in a scratch copy of the tree before and after this item: **identical JSON apart from the timestamp**, and each tree identical to itself run to run. `save_manager.gd` is 721 lines, down from 1,173; `save_slots.gd` 334; `save_refs.gd` 194.
>
> **What shipped that the plan did not say:**
> - **Two stated constraints were not real.** Asteroids "after world" (neither load reads the other's objects - the only reader of a body's ref is a restored job, in the pawn section) and raid "after world" (ships respawn around the centre and radius the raid saved, and a turret restored after it re-derives its aim in `ready_constructed`). Both comments now say "no constraint", and neither is pinned. Tutorial's "above every vanilla section" had been false since vitals, alerts and transmissions landed above it, and never mattered: the load restores only the ledger, and the watchers arm on `game_bootstrapped`, after every section. Two that the plan listed are real but soft, and kept with their true reason: crew and contracts after world (and crew after pawns) because each load ends on a signal whose UI answer re-reads the bunks, the crew count or the bay.
> - **`SAVE_VERSION` and `SAVE_DIR` moved to `SaveSlots`**, beside the migration table they belong to; a `SaveSlots` that read `SaveManager.SAVE_VERSION` would be a `class_name` cycle, the WI-64 trap. `QUICK_SLOT` stayed on `SaveManager` with the hotkeys that use it. `_migrate` became the public `SaveSlots.migrate`, since `stage_load` calls it across classes, and **`SaveSlots.write_slot`** was added so the file write sits with the file read. The `SaveRefs` freed-reference warning now says `SaveRefs:`. 111 call sites in 21 files were renamed, none by hand.
> - **The manager-order test holds CLAUDE.md's list equal to the scene's, in order**, not just "no manager missing" - the paragraph says "in tree order", so the order is part of what it claims. The tech spec's copy had drifted by four (AlertManager, HeatManager, DialogueRunner and TutorialManager), CLAUDE.md's by two.
> - **The `module_added` / `module_removed` question (§1) came back empty.** No subscriber reads anything another one does - path and structure each add or drop their own vertex, atmosphere and heat attach their own component, adjacency defers its rebuild, alerts resolve their rows, the starting crew spawns deferred - so nothing was pinned. "SaveManager last" is pinned as the plan asks, though its only concrete effect today is that the pending load is queued behind anything another manager defers from its `_ready`, and none currently does.
> - **F41, a preload cycle §3 unmasked, found and fixed.** Deleting the `is HaulerRobotPawn` branch stopped `SaveManager` from loading `LogisticsBayComponent` ahead of the hauler's script, and the bay *preloaded* the hauler scene, whose script names the bay. The Dialogue Manager plugin loads every global class in name order at import, and `--import` failed twice with `Busy` on `hauler_robot.tscn`. Both bays now leave the robot-scene export empty and load the vanilla scene by path on first use; a mod's scene on the export still wins. `MiningComponent` had the same shape and survived only by sorting first.
> - **F42, recorded, not fixed.** The v1→v2 migration step reads `data["pawns"]` rather than `data["sections"]["pawns"]` and has never done anything; a v1 job is dropped anyway, by `Job.from_dict`. §4 was a pure move, so it moved unchanged. See [[03_Bugs_and_Improvements]].
> - **A latent limit, commented rather than changed:** jobs restore per pawn, right after that pawn, so a job whose target is *another* pawn would resolve only if that pawn loaded first. `JobTarget.of_pawn` has no caller, so no job type is affected; `SaveRefs.pawn_ref` and the pawn section both say so now.
> - **The integration check is its own suite**, `test_wi73_save_orchestration.gd`, rather than an extension of R4: it adds that a booted game registers exactly the table, that each robot is back on its bay's **roster** (a ref alone would pass while the bay forgot it), and that the ARC inspector leaves no entry.
> - **Mods:** a mod script calling `SaveManager.module_ref` and friends must use `SaveRefs.*` / `SaveSlots.*` now; the sample mod calls none. Mods still pass their own section integer, and a modded pawn kind persists its own fields by overriding the four hooks.
>
> The doc is left in `Work Items/` for the author to file.
>
> *Original status: DRAFT (2026-09-19), not started. Follows [[WI-70_Job_Ownership_Contract]], which deletes the job-adoption half of `SaveManager`'s pawn path. This item takes the rest. Scoped from [[05_Architecture_Review]] §A5 and §A8. No finding id of its own: it closes structural debt the audits kept walking past, and it corrects four stale statements in CLAUDE.md and the tech spec.*

## Goal

The boot and the load are held together by three hand-numbered orderings, and only one of them is pinned by a test:
- **Manager ready order** is the child order under `Managers/` in `main.tscn`. CLAUDE.md calls it load-bearing, and its list is already wrong: it omits `HeatManager` and `DialogueRunner`. Nothing checks the scene, and the scene is the thing an editor drag changes.
- **Save-section order** is an integer each of 21 registrants passes to `register_section`. The constraints between them live in comments in eleven files. `test_save_sections.gd` pins the registry's *sort*, not the vanilla *order*.
- **Component restore order** is `save_order()`, and it *is* pinned, by `test_component_save_contract.gd` (WI-47 M2, extended in WI-68 F9). It is the model for the other two.

Separately, `SaveManager` (1,171 lines) is three things: slot I/O and migration, the reference helpers everything else uses, and the pawn and pile sections. Its pawn section still names four pawn kinds in an `if pawn is X` chain (`save_manager.gd:639`, `:696–706` on save; `:1062`, `:1102–1110` on load). A modded pawn kind with a field of its own cannot persist it. That is exactly the hole WI-47 M2 closed for components, left open one level up.

## 0 — Decisions for the author (not yet settled)

1. **Section orders stay integers, gathered into one table.** *Recommended.* Every vanilla order moves into `SaveManager.SECTION_ORDER: Dictionary[StringName, int]`, registrants read their number from it, and a pure test asserts the constraints as pairs. Mods keep passing integers, as WI-47 M3 promised them. *Deferred:* named dependencies (`after: [&"world"]`, topologically sorted). They read better, but they change the mod API, and nothing needs them yet.
2. **`SaveManager` splits into three files, with no forwarding shims.** *Recommended.* `SaveSlots` takes slot I/O, listing, summaries and migration; `SaveRefs` takes the `*_ref` helpers and stack serialization; `SaveManager` keeps orchestration and the pile and pawn sections. That is about 70 call sites, most of them in tests and the menus, all mechanical. *Alternative:* leave the file whole; it is long but coherent, and this is the least urgent part of the item.
3. **Only the kind-specific pawn fields move onto the pawn classes.** *Recommended.* The fields every pawn has (name, id, tint, wallet, position, schedule, carried stacks) stay where they are, because several must be set before `add_child`, and that ordering is easier to read in one place. *Alternative:* move everything onto `PawnBase`, which makes the pawn section a pure walk and puts `add_child` ordering inside each class.

## Scope

**In:** the manager-order test (§1), the section-order table and test (§2), the pawn-kind hooks (§3), the split (§4), and the stale docs (§5).

**Out:**
- the component restore order (already pinned);
- `SAVE_VERSION` (no key moves, so no bump);
- the named-dependency sections (§0.1).

## Design

### 1 — Manager ready order, pinned

`tests/unit/test_manager_order.gd` reads `main.tscn` as a `PackedScene` and walks `get_state()`, so nothing is instantiated. It lists the children of `Managers/` and asserts the constraints that actually exist.

Reading every manager's `_ready` on 2026-09-19 found exactly two:
- **`TimeManager` is first.** Twelve managers connect to its signals in `_ready`: Atmosphere, Contract, Economy, Event, Heat, Job, Market, Power, Resource, Trader, Unlock and Visitor.
- **`SaveManager` is last.** It applies a pending load deferred, once every section has registered.

`RaidManager` and `TutorialManager` read `Global`'s staging (difficulty, skip onboarding), which is an autoload, so they impose no order.

The test also checks that **no manager is missing from the list in CLAUDE.md**, parsing the list out of the file, so the doc can't drift again. One more thing to confirm by reading, and pin if it turns out to be real: whether any of the 13 `SignalBus.module_added` subscribers or the 13 `module_removed` ones depends on being called before another. Connection order is ready order.

### 2 — Save-section order, pinned

`SaveManager.SECTION_ORDER` holds all 21 vanilla sections and every registrant reads from it:

| Section | Order | Section | Order |
|---|---|---|---|
| `time` | 10 | `traders` | 120 |
| `unlocks` | 20 | `events` | 130 |
| `resources` | 30 | `story` | 135 |
| `market` | 40 | `contracts` | 140 |
| `economy` | 50 | `raid` | 150 |
| `world` | 60 | `visitors` | 160 |
| `asteroids` | 70 | `tutorial` | 170 |
| `turbolifts` | 80 | `vitals` | 200 |
| `piles` | 90 | `alerts` | 210 |
| `pawns` | 100 | `transmissions` | 215 |
| `crew` | 110 | | |

`tests/unit/test_save_section_order.gd` asserts the constraints each registrant's comment states, one per pair:
- `time` before everything;
- `unlocks` before `world` (ready_constructed applies global modifiers);
- `resources` before `economy`;
- `world` before `asteroids`, `turbolifts`, `piles`, `pawns`, `crew`, `traders`, `contracts`, `raid`;
- `asteroids` and `piles` before `pawns` (restored jobs resolve their targets);
- `market` before `traders` and `events`;
- `pawns` before `crew` and `events`.

`visitors` says it is independent. `story`, `tutorial`, `vitals`, `alerts` and `transmissions` carry no stated constraint: read each one's load, and either add its constraint to the test or add a comment at the registration saying it has none.

### 3 — Pawn kinds persist themselves

Four virtuals on `PawnBase`, with defaults that do nothing:

| Hook | Called | Overridden by |
|---|---|---|
| `is_saved() -> bool` | on save, before anything | `InspectorPawn` (false) |
| `save_kind_data(entry)` | on save, after the component blocks | `RobotPawnBase` (`robot_index`), `MiningDronePawn` (`mining_comp`), `HaulerRobotPawn` (`logistics_bay`), `VisitorPawn` (`visitor`) |
| `load_kind_data_before_tree(entry)` | on load, before `add_child` | `RobotPawnBase` (`robot_index`: `_ready` numbers a robot only when it arrives unset) |
| `load_kind_data(entry)` | on load, after the component blocks | `MiningDronePawn`, `HaulerRobotPawn` (re-register with their bay), `VisitorPawn` |

The keys don't change, so every existing save loads as before. The four `is` branches on each side of `SaveManager` are deleted, and the pawn section calls the hooks. Each hook's doc comment states why it runs where it does; those reasons are currently inline comments in `SaveManager`.

A pure test pins the keys, in `test_component_save_contract`'s style: construct each pawn class bare, set its fields, call `save_kind_data`, and assert the keys and values. Old saves are covered by WI-69's idempotence test, plus a one-off check below.

### 4 — The split (§0.2)

| File | Takes |
|---|---|
| `scripts/managers/save_slots.gd` (`SaveSlots`, static) | `slot_path`, the save-dir seam WI-69 adds, `read_slot`, `list_slots`, `summarize`, `describe_slot`, `difficulty_label`, `sanitize_slot_name`, `slot_exists`, `delete_slot`, `mod_drift`, the `read_*` envelope readers, `_migrate` and the migration table |
| `scripts/managers/save_refs.gd` (`SaveRefs`, static) | `_live` and the five `*_ref`/`resolve_*_ref` pairs, `stacks_to_dicts`, `stack_from_dict`, `instance_from_dict` |
| `scripts/managers/save_manager.gd` | registration, `save_slot`/`load_slot`/`stage_load`, apply, the resource, pile and pawn sections |

The call sites are listed by a grep for `SaveManager.<name>(`: roughly 30 in game code and 40 in tests, the largest being `sanitize_slot_name` (16, nearly all tests) and `summarize` (8). Update them in place. A forwarding shim on `SaveManager` would be a second name for every helper forever.

### 5 — Stale docs this item owns

- **CLAUDE.md, Managers:** the list gains `HeatManager` and `DialogueRunner`, in scene order, and §1's test keeps it honest from now on.
- **CLAUDE.md, Persistence:** still says per-component blocks "are enumerated by hand" and that "WI-46 stage 2 replaces the chains". Both are false since WI-47 M2 made components own their blocks (WI-46 was structure connectivity). It also says "17 sections"; there are 21 registered, plus three envelope fields.
- **[[01_Technical_Specification]] §1.17:** "A `_migrations` version-step table exists, still empty" (it has two, v1→v2 and v2→v3), and the same "enumerated by hand" paragraph. §2.2 still lists WI-47's already-shipped work as the fix to come.

## Files to touch

| | Files |
|---|---|
| New | `scripts/managers/save_slots.gd`, `save_refs.gd`, `tests/unit/test_manager_order.gd`, `test_save_section_order.gd`, and a pawn-kind key test (or a block in `test_component_save_contract.gd`) |
| Changed | `save_manager.gd`, the 21 registrants' `_ready`s (one number each), `pawns/pawn_base.gd`, `robot_pawn_base.gd`, `mining_drone_pawn.gd`, `hauler_robot.gd`, `visitor_pawn.gd`, `inspector_pawn.gd`, the ~70 helper call sites |
| Docs | `CLAUDE.md`, `01_Technical_Specification.md` |

## Implementation order

1. §1 and §2's tests, against the tree as it is. Both should pass on day one; they pin, they don't fix.
2. §2's table, one registrant at a time.
3. §3, then delete the `is` chains.
4. §4, as its own commit. It is a pure move, and the full unit and integration suites are its whole test.
5. §5.

## Edge cases

- **A mod section registered with an integer** that collides with a vanilla one still ties on id, exactly as today. The table changes nothing for mods.
- **A robot loaded from a save written before robots had numbers** has no `robot_index`. `load_kind_data_before_tree` leaves it unset, and `_ready` numbers it, as today.
- **A drone whose bay no longer resolves** gets `set_owner_component(null)`, as today.
- **`summarize()` is used by the main menu before any `SaveManager` exists.** That is why the slot functions are static, and `SaveSlots` keeps them static.

## Verification

1. **GUT unit:** the new tests green. Each fails on a seeded violation: `SaveManager` dragged above `TutorialManager` in a scratch copy of `main.tscn`; `world`'s order raised above `pawns` in the table; a new manager node that CLAUDE.md doesn't list.
2. **GUT integration (WI-69):** save → reload → save is still byte-identical in `sections`, for a station with a mining drone, a hauler robot and a visitor aboard.
3. **Old saves:** in a scratch copy, the real quicksave loaded and re-saved before and after this item gives the same JSON, apart from the timestamp.

## Related

- [[WI-47_Modding_Support]]: M2 (component-owned blocks, the pattern §3 extends to pawn kinds) and M3 (the section registry §2 pins).
- [[WI-45_Save_System_Audit]]: the field-by-field sweep that §3's key test protects.
- [[WI-69_Integration_Test_Fixture]]: the idempotence test that verifies §3 and §4.
