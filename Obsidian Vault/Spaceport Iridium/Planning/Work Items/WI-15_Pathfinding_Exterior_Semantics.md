# WI-15 — Pathfinding: Exterior Semantics (`is_exterior`)

*Outcome of the 2026-07-14 pathfinding discussion. Companion to [[WI-16_Micro_Anchors_and_Pawn_Positioning]]; overlaps mechanically with [[WI-11_Turbolift_Management]] (same group-expansion loops) — consider implementing them together.*

## Goal
Stop overloading the vertex `group` field. Today it means three things at once: "which implicit network am I in" (turboshaft cliques), "am I exterior/unfinished" (construction swaps modules into the `"space"` group), and via `group_door`, "which door serves the network." Give exteriorness its own orthogonal flag — `ModuleGraphVertex.is_exterior: bool` — and demote "space" from being a group at all. After this, `group` means exactly one thing (implicit network clique: turboshafts, future teleporter nets), and a teleporter can be under construction (exterior) while keeping its group free for its network.

Explicitly **not** in scope: multi-group membership (generalizes the wrong axis and complicates subgraph merging), hull vertices / EVA topology (a later evolution this change doesn't preclude).

## Design
- `ModuleGraphVertex.is_exterior: bool = false`. The "space clique" = all exterior vertices, mutually connected implicitly, with the current space cost multiplier becoming a constant (`ModuleGraph.EXTERIOR_COST_MULT`).
- The two group-expansion loops in `pathfind_by_vertex` / `pathfind_to_func` gain a parallel exterior-expansion branch (iterate an `_exterior_vertices` list maintained like `_linked_groups` entries are today).
- Subgraph bookkeeping treats exteriorness like group membership: flipping the flag marks dirty; `_assign_subgraph_from` floods across exterior vertices the same way it floods group members; `is_space_reachable` checks the exterior subgraph (keep the method name).
- `group_door` keeps serving networks; exterior connections get a parallel `exterior_door: int` (airlock outer hatch index) defaulting to the same value — check current `"space"` users: `change_vertex_group(module, &"space")` callers pass no door, pawn space transitions pass `-1`. Most exterior flips need no door at all.
- **Callers to convert** (grep `&"space"` / `"space"`):
  - `ConstructionComponent.ready_blueprint` / `ready_constructed` / `setup_storage_post_deconstruction` / `_setup_deconstructed_for_load` → `set_exterior(module, true/false)`
  - `PawnBase._on_module_changed` (pawn enters/leaves space) → pawn vertex `is_exterior`
  - `PathComponent.connect_doors` space-door nodes → created as exterior vertices
  - `AsteroidBase` / `ResourcePile` / `ModuleGraph.pathfind_to_node_in_space` temp vertices → exterior
  - `TurboliftManager` untouched (real groups)
- `ModuleBase.enter_module_from` currently peeks at the private `graph._vertices[self].group != "space"` — replace with a public `PathManager.is_exterior(node) -> bool` query. Same logic, honest API, kills the "TODO hack for space things" from the dev notes.
- `PathPoint.in_space` (set from `group == &"space"` during path reconstruction) → set from `is_exterior`.
- New PathManager API: `set_exterior(node, exterior: bool)` (marks dirty, emits `module_group_changed` — or a dedicated `module_exterior_changed` — so in-flight paths re-check, mirroring the existing group-change repath hook).

## Bundled small fix: graceful turbolift-cab save
Pawns saved mid-ride currently pop out at their raw position on load (WI-03's documented v1 rule). Make the degradation deliberate: in `SaveManager._get_pawns_save()`, a pawn with `path_position_override` set to a `TurboliftCab` serializes with `current_module = cab.current_turbolift` (or nearest shaft floor) and position at that floor module. They "arrive early" on load instead of popping into a shaft wall. (Full ride serialization waits for the CONVEYED movement-state refactor — see the note in [[WI-11_Turbolift_Management]].)

## Files to touch
- `scripts/utility/module_graph_vertex.gd` — `is_exterior`, `exterior_door`
- `scripts/utility/module_graph.gd` — `_exterior_vertices` list, exterior expansion in both pathfind loops, subgraph flooding, `is_space_reachable` via exterior subgraph, `EXTERIOR_COST_MULT`, `pathfind_to_node_in_space` temp vertex
- `scripts/managers/path_manager.gd` — `set_exterior()`, `is_exterior()` query, repath signal
- `modules/components/construction_component.gd` — all four `change_vertex_group(..., &"space")` sites
- `pawns/pawn_base.gd` — `_on_module_changed` space transitions; `_ready` initial vertex
- `modules/components/path_component.gd` — space-door vertices
- `objects/asteroid_base.gd`, `data/resources/resource_pile.gd` — exterior temp/spawn vertices (verify: asteroids only enter the graph via temp splice)
- `modules/templates/module_base.gd` — `enter_module_from` via public query
- `scripts/managers/save_manager.gd` — cab-save degradation
- `scripts/managers/turbolift_manager.gd` — no change expected (verify group multiplier still applies)

## Implementation order
1. Vertex flag + graph plumbing (exterior list, expansion branches, subgraph flooding) with `"space"` group still working in parallel.
2. `set_exterior`/`is_exterior` API + repath signal.
3. Convert callers one system at a time: pawns → construction → path-component space doors → temp vertices. After each, run the game and confirm EVA construction still works.
4. Delete the `"space"` group entirely (grep proves no users remain); `_group_multiple` keeps only turboshaft entries.
5. Cab-save degradation in SaveManager.
6. Regression sweep (below).

## Edge cases
- Blueprint placed, then deconstructed, then re-placed — exterior flag flips correctly through every construction state transition (including the WI-03 load path `_setup_deconstructed_for_load`).
- Pawn EVA mid-flight when a module completes construction (exterior→interior flip) — the repath hook must fire exactly as `module_group_changed` does today (pawns watching that module re-path).
- `is_space_reachable` with zero exterior vertices (no airlocks, no blueprints) — returns false cleanly, no empty-list crash.
- Mixed reachability: pawn inside, target = blueprint (exterior) — reachable only if an airlock/space door bridges interior and exterior subgraphs, exactly as the space group behaves today. Write this as an explicit test case: it is the core behavior being preserved.
- Save/load: exteriorness is derived state (from build state / pawn position), NOT saved — verify a loaded save with a mid-construction module re-derives `is_exterior = true` via `ready_blueprint`.
- Turbolift group + exterior simultaneously: a lift module can never be exterior today (no construction step) — assert or document rather than support.

## Verification
1. Full construction loop: place blueprint → pawns EVA to it, deliver, build → module completes → pawns walk inside normally. Deconstruct → EVA again. (This is the exact flow the group hack served; it must be indistinguishable.)
2. Debug-check (temporary print or console): no vertex ever has `group == "space"`; turboshaft groups unaffected — lift rides still work.
3. Mining drones still reach asteroids (`is_space_reachable` path).
4. Airlock removal/re-add: space doors reconnect; `PathPoint.in_space` positions unchanged (pawns still fly cell-center paths in space).
5. Save mid-ride in a turbolift → load → pawn stands at the cab's floor module, resumes work; no popping into shaft geometry.
6. Save/load a station with a blueprint under construction → construction resumes with correct exterior routing.
