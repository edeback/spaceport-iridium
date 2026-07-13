# WI-10 — Placement & Selection UX

## Goal
Make building feel trustworthy: show *why* a placement is invalid (per-cell blocked overlay on the active layer), re-validate on flip, let clicks cycle through stacked nodes on a cell (corridor + stairs + module all occupy the same cell), and blink a "no path" indicator on modules disconnected from the station. All items come from the developer's QoL/engineering notes.

## Files to touch
- `ui/preview_module.gd` / `.tscn` — per-cell validity: read the module's footprint (size + StructureComponent `must_be_clear_points`/`internal_points`) and query `WorldManager.is_blocked`/`has_overlaps` per cell; tint per-cell quads (draw in `_draw()` over the preview) red/green instead of whole-sprite only
- `ui/ui_in_game.gd` — flip re-validation: `flip_module` action currently only toggles `preview_module.flipped`; force `update_module_placement(true)` after flip. Also click-cycling (below)
- `scripts/managers/world_manager.gd` — helper `get_stack_at_cell(cell) -> Array[ModuleBase]` scanning all layers at a cell (module, corridor, turbolift)
- `modules/templates/module_base.gd` — `_on_footprint_input_event` currently opens the info panel directly; route through a click-arbiter so overlapping footprints don't all fire (`set_physics_object_picking_sort(true)` is already on — top-most fires first; cycling = repeated clicks at same cell step down the stack)
- **New:** `ui/click_cycler.gd` (or logic inside ui_main): remembers last-clicked cell + index; same-cell click advances index through `get_stack_at_cell`
- `ui/ui_main.gd` — info panel opens for cycled selection
- No-path indicator: `scripts/managers/path_manager.gd` already tracks subgraphs; **new** small overlay — on `graph_changed`/recheck, any MODULE-layer module whose vertex subgraph ≠ the largest inhabited subgraph gets a blinking icon (`modules/templates/module_base.gd` add `set_disconnected_indicator(bool)`; a simple `AnimationPlayer`/tween on an exclamation sprite child)
- `ui/buttons/module_button_tooltip.gd` — while here: show resource costs colored by affordability (check current state; likely exists via module_resource_cost_ui)

## Implementation order
1. Flip re-validation (one line + test) — quick win.
2. Per-cell placement overlay.
3. Stack click-cycling.
4. Disconnected-module indicator.

## Edge cases
- Flipped multi-cell modules: footprint cells mirror — validity must test the flipped scene's structure points (flipped_scene may differ; PreviewModule must use the right variant's points).
- Multiplacement drag: per-cell tint on every preview instance (they call `update_placeable` already — extend uniformly).
- Click-cycling with the info panel already open on that stack → advance selection; clicking a different cell resets the cycle index.
- Cycling must skip layers hidden by the current layer-visibility toggle (corridor dimmed ≠ unclickable? decide: cycle everything, clearest).
- Disconnected indicator during construction: blueprints sit in the `"space"` group deliberately (ConstructionComponent does this) — exempt Blueprint-state modules or every construction site blinks.
- Space-group modules (airlock outer nodes) — exempt group `"space"` vertices.
- Indicator on the starting module alone at game start (subgraph of 1 = the largest) → no blink.

## Verification
1. Hover a 2×2 module over a partially blocked area → blocked cells tint red individually, free cells green; placement refused; move one cell → all green → placement succeeds.
2. Flip an airlock against a wall it can't attach to when flipped → validity updates the instant F is pressed.
3. Build hallway + stairs + module on one cell; click cycles hallway → stairs → module info panels; click elsewhere resets.
4. Delete the hallway linking a wing → all modules in the orphaned wing blink; rebuild the hallway → blinking stops within a recheck.
5. Regression: multiplacement drag rows still place and charge correctly.
