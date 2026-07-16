# WI-10 — Placement & Selection UX

## Goal
Make building feel trustworthy: show *why* a placement is invalid (per-cell blocked overlay on the active layer), re-validate on flip, let clicks cycle through stacked nodes on a cell (corridor + stairs + module all occupy the same cell), and blink a "no path" indicator on modules disconnected from the station. Additionally, module and pawn selection should use selection brackets (around the entire selected module) in addition to the current shader parameter. All items come from the developer's QoL/engineering notes.

## Files to touch
- `ui/preview_module.gd` / `.tscn` — per-cell validity: read the module's footprint (size + StructureComponent `must_be_clear_points`/`internal_points`) and query `WorldManager.is_blocked`/`has_overlaps` per cell; tint per-cell quads (draw in `_draw()` over the preview) red/green instead of whole-sprite only
- `ui/ui_in_game.gd` — flip re-validation: `flip_module` action currently only toggles `preview_module.flipped`; force `update_module_placement(true)` after flip. Also click-cycling (below)
- `scripts/managers/world_manager.gd` — helper `get_stack_at_cell(cell) -> Array[ModuleBase]` scanning all layers at a cell (module, corridor, turbolift)
- `modules/templates/module_base.gd` — `_on_footprint_input_event` currently opens the info panel directly; route through a click-arbiter so overlapping footprints don't all fire (`set_physics_object_picking_sort(true)` is already on — top-most fires first; cycling = repeated clicks at same cell step down the stack)
- **New:** `ui/click_cycler.gd` (or logic inside ui_main): remembers last-clicked cell + index; same-cell click advances index through `get_stack_at_cell`
- `ui/ui_main.gd` — info panel opens for cycled selection
- No-path indicator: `scripts/managers/path_manager.gd` already tracks subgraphs; **new** small overlay — on `graph_changed`/recheck, any MODULE-layer module whose vertex subgraph ≠ the largest inhabited subgraph gets a blinking icon (`modules/templates/module_base.gd` add `set_disconnected_indicator(bool)`; a simple `AnimationPlayer`/tween on an exclamation sprite child)
- `ui/buttons/module_button_tooltip.gd` — while here: show resource costs colored by affordability (**checked: already exists** — `module_resource_cost_ui.gd` tints red when `resource.get_total() < cost`; no work needed)
- Selection brackets (new goal): **new** `ui/selection_brackets.gd` — reusable Node2D that `_draw()`s four corner brackets around a target rect and follows its target's `global_position` in `_process` (needed for moving pawns; also survives the pawn's canvas-layer reparents). Two instances created in code under `UIInGame` (its layer already shares world coordinates — the debug-path overlay draws there with raw cell coords):
	- Module brackets: `ModuleBase.selected` already emits `SignalBus.module_selected` on every change — subscribe in `ui/ui_in_game.gd`; rect = full footprint `Rect2(Vector2.ZERO, size * CELL_SIZE)` at the module origin. The existing SELECTED shader tint stays; brackets are additive.
	- Pawn brackets: no pawn selection state exists — "selected" = pawn info panel open. Hook `ui/ui_main.gd` `pawn_clicked()`: show brackets when opening, clear via the panel's `tree_exiting` (covers both close paths — the exit button *and* `pawn_clicked`'s direct `queue_free`). Rect from the pawn's current animated-sprite frame size (with padding), fixed fallback if absent.

## Implementation order
1. Flip re-validation (one line + test) — quick win.
2. Per-cell placement overlay.
3. Stack click-cycling.
4. Disconnected-module indicator.
5. Selection brackets (module + pawn).

## Edge cases
- Flipped multi-cell modules: footprint cells mirror — validity must test the flipped scene's structure points (flipped_scene may differ; PreviewModule must use the right variant's points).
- Multiplacement drag: per-cell tint on every preview instance (they call `update_placeable` already — extend uniformly).
- Click-cycling with the info panel already open on that stack → advance selection; clicking a different cell resets the cycle index.
- Cycling must skip layers hidden by the current layer-visibility toggle (corridor dimmed ≠ unclickable? decide: cycle everything, clearest).
- Disconnected indicator during construction: blueprints sit in the `"space"` group deliberately (ConstructionComponent does this) — exempt Blueprint-state modules or every construction site blinks.
- Space-group modules (airlock outer nodes) — exempt group `"space"` vertices.
- Indicator on the starting module alone at game start (subgraph of 1 = the largest) → no blink.
- Per-cell overlay only reads on a grid-snapped preview: `update_module_placement` currently lets the selector follow the raw mouse when placement is invalid — change it to always snap to the hovered cell.
- Brackets vs. dimmed layers: corridor/turbolift canvases are dimmed by the layer toggle, but brackets draw on the `UIInGame` layer → always full opacity (intended — the selection must stay readable).
- Selected module deleted (or selected pawn despawns/departs) → brackets must clear: guard with `is_instance_valid(target)` per frame, don't rely only on deselect signals.
- Click-cycling reassigns `ModuleInfoIngamePanel.module_viewed`, which flips `selected` on the old and new module — brackets must follow the *latest* `module_selected` with `selected == true`, and only clear on a deselect of the module they're currently on.
- Module info panel and pawn info panel can be open simultaneously → two independent bracket instances, not one shared.

## Verification
1. Hover a 2×2 module over a partially blocked area → blocked cells tint red individually, free cells green; placement refused; move one cell → all green → placement succeeds.
2. Flip an airlock against a wall it can't attach to when flipped → validity updates the instant F is pressed.
3. Build hallway + stairs + module on one cell; click cycles hallway → stairs → module info panels; click elsewhere resets.
4. Delete the hallway linking a wing → all modules in the orphaned wing blink; rebuild the hallway → blinking stops within a recheck.
5. Regression: multiplacement drag rows still place and charge correctly.
6. Click a module → corner brackets around its full footprint (green shader tint unchanged); cycle a stacked cell → brackets jump to each cycled module; close the panel → brackets gone.
7. Click a pawn → brackets appear around the pawn and follow it while it walks (including through doors/turbolifts); close the pawn panel (either via exit button or clicking the pawn again) → brackets gone. Both panels open at once → both bracket sets visible independently.
