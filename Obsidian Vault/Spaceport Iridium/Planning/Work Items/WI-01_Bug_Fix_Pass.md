# WI-01 — Bug-Fix Pass

## Goal
Fix the confirmed bugs from [[03_Bugs_and_Improvements]] section A (and the cheap items from section B) so subsequent play-testing produces trustworthy results. No behavior redesign — smallest correct fix per bug.

## Files to touch
- `scripts/managers/world_manager.gd` — A1
- `modules/transport/turbolift_shaft.gd` — A2
- `modules/transport/module_turbolift.gd` — A3
- `modules/components/path_component.gd` — A4
- `ui/ui_main.gd`, `scripts/managers/unlock_manager.gd` (+ new `scripts/utility/resource_scanner.gd`) — A5
- `scripts/jobs/job_mine_asteroid.gd` — A7
- `pawns/pawn_base.gd` — A8
- `scripts/utility/module_graph.gd`, `scripts/utility/module_graph_vertex.gd` — A9
- `modules/components/sustenance_component.gd` — A10
- `scripts/jobs/job_eat.gd` — A11
- `scripts/managers/job_manager.gd`, `scripts/jobs/job_base.gd` — B: cancel/end unification (only the minimal version; full refactor is WI-04)
- `modules/templates/module_base.gd` — B: `get_node_or_null` for component getters

## Implementation order
1. **A1 placement charging** — in `purchase_and_add_module()`: perform the `is_blocked` / overlap validation *before* withdrawing (extract a `can_place_module(module_data, cell, size…) -> bool` used by both this and `add_module`), or capture `add_module()`'s return and refund `resource_costs` on null. Prefer validate-first: no refund path to get wrong. Also add an explicit `return null` at failure points in `add_module` and null-checks at call sites (`ui_in_game.gd` build actions, `connect_doors()` auto-hallway).
2. **A2 cab selection** — rewrite the third fallback with parentheses and a null-safe comparison:
   ```gdscript
   if cab.is_available() and (best_cab == null or cab.get_available_capacity() > best_cab.get_available_capacity()):
   ```
   Note the comparison should prefer *more* available capacity (existing `<` picks the fullest cab — decide and comment; the shaft comment says "shortest current stop queue," which is a different metric again). Fix the parenthesization in `split_at()` line 109 too.
3. **A3 collision** — else-branch should be `collision_upper.disabled = true`.
4. **A4 typed signal** — in `remove_connections()`, only emit `module_path_connection_removed` when `node is ModuleBase`; space nodes already get cleaned via `space_connections` loop (verify their graph edges are removed by `remove_vertex` — they are, vertex removal erases edges both ways).
5. **A5 resource scanning** — new static helper `ResourceScanner.scan(path: String, type_hint: String) -> Array[Resource]` handling: `.tres`, `.tres.remap` (strip `.remap`), recursion, `DirAccess` fallback to `ResourceLoader.list_directory`. Replace bodies of `UIMain.get_all_file_paths*` and `UnlockManager._tres_paths`. Keep behavior identical in-editor.
6. **A7 null mined resource** — early-`return`/`continue` when `mine_resource()` returns null; don't increment the count.
7. **A8 teardown pile spawn** — guard PREDELETE body: `if inventory_component == null or inventory_component.is_empty(): return`, and `is_instance_valid(Global.world_manager)`.
8. **A9 vertex leak** — change `ModuleGraphVertex` to `extends RefCounted`; delete the `old_vertex.free()` call. In `pathfind_to_node_in_space`, wrap the group-append/erase so the temp vertex is always erased (it is now collected automatically once dereferenced).
9. **A10 sustenance process states** — add `ready_preview/ready_blueprint` → `set_process(false)`, `ready_constructed` → `set_process(true)`.
10. **A11 eat target** — store and use `target_component`; on arrival re-validate `is_instance_valid(target_component)` and `sustenance_available > 0`, else `cancel(true)` (the retry loop already handles it).
11. **A12** — removed, working as intended
12. **B minimal lifecycle fix** — in `JobManager.find_job`, replace `job_to_do.end_job()` with `job_to_do.cancel(true); job_to_do.end_job()`. In each `cancel()` override, nothing else changes yet (full unification in WI-04). This makes storage `import_job/export_job` slots clear correctly when a board job goes invalid.
13. **B component getters** — `get_path_component`/`get_structure_component` use `get_node_or_null`.

## Edge cases to check
- A1: multiplacement (`finalize_multiplacement`) calls purchase per-cell — partial placement rows must charge only for placed cells.
- A1: `connect_doors()` auto-places hallways via `add_module` (no purchase) — must still work when placement fails (returns null).
- A4: removing an airlock that never connected to space (door_connections without space entries) — no regression.
- A9: removing a module mid-pawn-route — `PawnMovementComponent.module_removed` re-paths; confirm no freed-object access with RefCounted vertices (should only get safer).
- Turbolift fixes: shaft with 1 cab, 3+ requests from both directions; shaft split while a cab is mid-ride.

## Verification
1. Editor: run game. Attempt to place a module on an occupied cell → credits/resources unchanged (watch resource display).
2. Build a 4-floor turbolift shaft, send several pawns up/down simultaneously (build storage + processors on different floors to force traffic) → no script errors, cabs serve all requests.
3. Delete an airlock connected to space → no signal-type error in output.
4. Export a Windows build (`godot --headless --export-release`) and confirm the build menu and research panel populate.
5. Let a mining drone fully empty an asteroid alongside another drone → no null stacks in bay storage UI (inspect storage tab).
6. Quit the game with pawns carrying cargo → no PREDELETE error spam in log.
7. Delete a storage module that had pending import jobs → job board (add a temporary debug print of board size) shrinks; no orphaned jobs repeatedly failing.
8. Regression sweep: construct a non-instant module end-to-end (deliver + build), deconstruct it, collect the pile — all still work.
