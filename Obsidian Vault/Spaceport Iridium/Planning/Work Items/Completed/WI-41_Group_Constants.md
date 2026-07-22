# WI-41 — Group Constants

> **STATUS: COMPLETE (2026-07-22).** Shipped as designed. `scripts/utility/groups.gd` holds 22 `StringName` constants; 75 group-API call sites across 52 files converted, plus the two local consts that predated it (`StorageQuery.STORAGE_GROUP`, `TimeManager.SIM_ANIMATION_GROUP`) folded in and deleted. Zero bare group literals remain in `.gd` outside `addons/`. Constant names mirror their string values so a grep for either finds both. 377 GUT tests green (unchanged — the suite is pure-class only, as expected). Verified by a 57-check headless autoload probe.
>
> **Deviations from the design, all from the implementation-time grep the doc asked for:**
> - **`container_required` got no constant.** It isn't in 12 of *our* scenes — it's entirely inside `addons/collapsible_container/`, joined and read by that addon's own `folding_presets.gd`. Not our surface; nothing to enshrine and nothing to delete.
> - **The joined-but-never-scanned list is four, not one:** `processor` (joined by `ProcessorComponent` and `MiningComponent`), `turbolifts`, `teleporters`, `stairs`. All four kept constants, each with a comment saying nothing reads it. Deleting the joins is a separate call — see below.
> - **`teleporters` is two different things.** `ModuleTeleporter` joins the SceneTree group *and* uses the same word as a `ModuleGraph` vertex-group key (`set_group_multiple`, `change_vertex_group`, an edge `_meta`). Only the SceneTree join was converted; the graph-side strings are a different namespace and were left alone, with the collision noted on the constant.
> - **Three `.tscn`-side literals, not three names.** Only `airlock` is actually authored scene-side (both airlock scenes, via `ModuleBase.add_to_groups`). `sim_animation` is joined purely through `TimeManager.sync_animation`; the doc's worry about it being hand-added later is recorded as a comment rather than a live duplication.
>
> **Open question for the player/designer, deliberately not decided here:** delete the four write-only joins, or leave them? They cost nothing and a "which transport modules exist?" scan is a plausible future reader, so they were left in.

## Goal
Replace the bare group-name string literals with a `Groups` constants file, so the group API surface is discoverable and typo-proof. Closes **C9** (promoted from the original design-suggestion list once the surface quadrupled).

Purely mechanical. No behavior change, no new indirection beyond the constants themselves.

**Sequence after [[WI-39_Power_Registry]] and [[WI-40_Storage_Query_Helper]]**, both of which delete call sites this WI would otherwise have to convert: WI-39 removes the `power_generator` / `power_consumer` / `battery` groups outright, and WI-40 collapses four `resource_storage` scans into one.

## Design

24 distinct group names across ~53 code call sites today, all bare string literals, none discoverable without grepping:

`module`, `pawn`, `resource_storage`, `resource_debris`, `sleep_component`, `sustenance_component`, `recreation_provider`, `crew_recruitment`, `shop`, `medical_bay`, `robot_repair`, `recharger`, `processor`, `asteroid`, `airlock`, `pirate_ship`, `shield`, `minimap_tracked`, `sim_animation`, `turbolifts`, `teleporters`, `stairs`, `container_required` — plus the three WI-39 deletes.

- **`scripts/utility/groups.gd`**, `class_name Groups`, one `const NAME := &"name"` per group. StringName literals, not String: `add_to_group`/`get_nodes_in_group` take StringName and the current String literals are being coerced at every call. The codebase already prefers `&""` for ids elsewhere (`ModuleData.id`, stat keys, modifier sources) — this brings groups in line.
- **Group the constants by owner** with a comment per block (world/structure, pawns, storage & logistics, needs providers, combat, UI) rather than one flat alphabetical list. The file is documentation as much as it is constants — it's the first honest answer to "what group-based contracts exist in this game?"

### Groups also authored outside code — the part that actually matters

Three group names are declared in `.tscn` files, not just code, and the editor stores them as plain strings:

- `container_required` — `groups=["container_required"]` in 12 scenes
- `airlock` — via `ModuleBase.add_to_groups` in `module_airlock_left.tscn` / `module_airlock_right.tscn`
- `sim_animation` — joined in code by `TimeManager.sync_animation`, but it's the group most likely to be hand-added to a scene later

A constant can't reach into a `.tscn`, so these stay duplicated by necessity. **Annotate each such constant with a comment naming the scenes that also declare it**, because that duplication is precisely the typo class this WI exists to prevent — a scene-side misspelling is silent, produces an empty group, and looks like a broken feature rather than a typo.

`ModuleBase.add_to_groups: Array[StringName]` (`module_base.gd:24`) is authored data by design and stays that way; this WI doesn't try to make it code.

## Files to touch
- **New:** `scripts/utility/groups.gd`
- Every file with a group literal — ~30 files across `scripts/`, `modules/`, `pawns/`, `ui/`, `data/events/`, `objects/`
- Remember: `filesystem_manage(op="scan")` after the new `class_name`

## Implementation order
1. Write `groups.gd` from a fresh grep of the codebase (do the grep at implementation time, not from this doc's list — WI-39/WI-40 will have moved it).
2. Convert in one mechanical pass, file by file. Grep-driven, not memory-driven.
3. Re-grep for surviving literals — including in `.tscn` — and confirm every remaining one is an authored-in-scene case with a comment on its constant.
4. Spot-check that no constant is unreferenced (an unused one means a group that only exists in a scene, or one that was deleted and the constant outlived it).

## Edge cases
- **Deleted-but-still-joined groups.** Any group that is joined but never scanned is dead weight; the conversion pass surfaces them. `container_required` (12 scenes) is the one to look at hardest — check whether anything actually reads it before minting a constant for it. If nothing does, propose deleting rather than enshrining it.
- **String vs StringName comparison.** Anywhere a group name is compared rather than passed to the group API (e.g. stored in a var, matched in a `match`), `"module" == &"module"` is true in GDScript but the typed-warning settings may flag the mix. Keep both sides StringName.
- **`ResourceScanner`-discovered data** doesn't reference groups, so `.tres` files are out of scope — confirm with a grep rather than assuming.
- **Don't add a `Groups.has(node, ...)` wrapper or any other API.** Constants only. Wrapping the group API is how a typo-proofing change turns into an abstraction nobody asked for.

## Verification
1. `godot --headless --import` clean, then boot the game — most group bugs are silent (an empty `get_nodes_in_group` returns `[]`, no error), so booting is necessary but nowhere near sufficient.
2. **Exercise one feature per converted group.** This is the real verification and it's the bulk of the work:
   - `module` / `pawn` — station loads, crew move
   - `resource_storage` / `resource_debris` — a haul completes, a pile gets collected
   - `sleep_component` / `sustenance_component` / `recreation_provider` — a pawn sleeps, eats, recreates; hiring gate still reads bunk capacity
   - `shop` / `crew_recruitment` — a visitor buys something, a hire arrives
   - `medical_bay` / `robot_repair` / `recharger` — a sick pawn gets treated, a hauler recharges and gets repaired
   - `asteroid` / `airlock` — a mining trip completes end to end
   - `pirate_ship` / `shield` — start a raid via cheat, turrets fire, shields absorb
   - `minimap_tracked` — raid ships appear on the minimap
   - `sim_animation` — change time speed, gameplay animations track it
   - `processor` / `turbolifts` / `teleporters` / `stairs` — whatever reads these still does
3. Full GUT suite green (it won't catch group bugs — tests are pure-class only — but a red suite means the pass broke something else).
4. Final grep: zero bare group literals in `.gd`, and every `.tscn`-side literal accounted for by a commented constant.
