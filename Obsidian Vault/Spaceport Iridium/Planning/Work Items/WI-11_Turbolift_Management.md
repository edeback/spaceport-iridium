# WI-11 — Turbolift System Panel & Floor Control

## Goal
One management panel per shaft (selecting any lift module selects the shaft): toggle floors on/off (skip floors), set cab count, choose a dispatch strategy. Plus the movement-cost polish from the notes: per-"terrain" speed multipliers so lift travel is genuinely faster than stairs and stairs genuinely slower than hallways.

## Current state
Shafts (`TurboliftShaft`) already merge/split correctly, group-based pathfinding gives lift traversal a 0.5× cost multiplier, cabs dispatch with a 3-tier heuristic (contains the WI-01 crash fix), and cabs are created on demand (first request). Stairs have no penalty; there's no shaft UI.

## Design
- **Floor disable:** per `ModuleTurbolift` flag `floor_enabled`. Disabled floor: its door stops being a valid group entry/exit — implement via `PathManager.disable_module`? No — that blocks through-traffic in the whole vertex. Instead remove the vertex's group membership benefit: cleanest is a new `ModuleGraphVertex.no_group_stop: bool` checked in the two group-expansion loops in `ModuleGraph.pathfind*` (skip `linked` vertices whose `no_group_stop` is true as *destinations* of the group jump, while still allowing them as physical shaft cells). Cabs additionally skip stopping there (`RideRequest` validation).
- **Cab count:** panel +/− buttons; buying a cab costs credits (data constant); removing returns none (or partial). Cabs added via existing `create_new_cab()`; removal picks an idle cab, `destroy()`s it (exists).
- **Dispatch strategy:** enum on shaft {NEAREST_IDLE (current), COLLECTIVE (elevator-standard: keep direction, serve en-route calls)} — implement COLLECTIVE only if cheap; the panel dropdown can ship with one option and a disabled second. Honest v1: cab count + floor toggles are the value; strategy is stretch.
- **Speed multipliers:** `PathComponent` or module-level `traversal_speed_mult` consumed by `PawnMovementComponent.move()` when computing `dist_to_travel` through that module's sub-path (stairs 0.5×, hallway 1.0×). Pathfinding *cost* should mirror it so route choice prefers lifts for long verticals but stairs for one floor: bake into edge cost at connection time (`make_connections` distance × multiplier) — simpler than dynamic evaluation and matches the existing group multiplier pattern.
- **Panel:** new window opened from lift module info panel (or replaces it): floor list with toggles (sorted by y, labels "Floor −2…+3" relative to lowest), cab count control, live cab positions (text v1).

## Files to touch
- `scripts/utility/module_graph.gd`, `module_graph_vertex.gd` — `no_group_stop` in both group-expansion loops (`pathfind_by_vertex`, `pathfind_to_func`)
- `modules/transport/module_turbolift.gd` — `floor_enabled` + graph flag sync + visual (dimmed door)
- `modules/transport/turbolift_shaft.gd` — cab add/remove API, enabled-floor filtering in `request_ride`/`_best_cab_for`, strategy enum
- `modules/transport/turbolift_cab.gd` — skip disabled floors in stop planning; `recheck_requests` on floor toggle
- **New:** `ui/windows/turbolift_panel.gd/.tscn`; hooked from module info panel (`ui/windows/module_info_ingame_panel.gd`) when the module is a ModuleTurbolift
- `modules/core/stairs.gd` / stairs scene + `modules/components/path_component.gd` — `traversal_speed_mult`; `pawns/pawn_movement_component.gd` — consume it in sub-path movement; `path_component.make_connections` — cost scaling
- WI-03 followup: per-module `floor_enabled` and per-shaft cab count into save (floor flag via module save data; cab count re-derivable? No — save it on… shafts are rebuilt from modules; store `desired_cab_count` on the *lowest* module? Cleaner: TurboliftManager save section mapping shaft group_id is unstable across loads — instead store cab count on each lift module redundantly and shaft takes the max at rebuild)

## Implementation order
1. Speed multipliers (self-contained, immediately felt).
2. `no_group_stop` + floor_enabled mechanics.
3. Shaft panel UI (floors + cab count).
4. Cab purchase/removal.
5. (Stretch) collective dispatch.

## Edge cases
- Disabling the floor a cab is currently at / traveling to → cab finishes current stop, then re-plans (`recheck_requests`).
- Disabling a floor with pawns waiting there → their ride requests must fail/cancel → movement fails → job retries and pathfinding now routes via stairs (or fails reachability honestly).
- Disabling ALL floors of a shaft → shaft contributes nothing; pawns route around; re-enabling restores (subgraph dirty flags must fire — group membership changes already `_mark_dirty`; the new flag must too).
- Splitting a shaft (removing a middle lift) with disabled floors on both halves → flags follow their modules naturally.
- Path already computed through a floor that gets disabled mid-walk → `module_group_changed` re-path hook exists; emit it (or a new signal) on toggle.
- Stairs multiplier interacting with `Job_IdleWander`'s 0.4 speed — multipliers compose; verify no near-zero crawl.
- Save/load: disabled floors persist; cab count restored (see storage note above).

## Verification
1. Two floors linked by both stairs and a lift: time a pawn both ways (toggle lift off/on) — stairs visibly slower per the multiplier; long vertical trips prefer the lift, single-floor hops may take stairs (inspect chosen path via debug path draw — PathManager's selected-modules debug already draws paths).
2. Disable floor 2 of a 4-floor shaft → pawns traveling 1→3 ride through without stopping; pawns targeting floor 2 take stairs.
3. Add a second cab → simultaneous opposite-direction requests get served in parallel; remove it → single-cab behavior returns.
4. Panel reflects live state (toggles, cab count) and survives shaft merge (build a lift connecting two shafts with different settings — panel shows merged floor list).
5. Save/load with disabled floors + 2 cabs → intact.
