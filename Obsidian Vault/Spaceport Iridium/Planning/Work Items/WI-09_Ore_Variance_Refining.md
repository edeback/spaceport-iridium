# WI-09 — Ore Richness Through Refining

## Goal
Make the existing ore variance system matter: asteroids carry a richness profile, asteroids spawn with different types of ores available, mined ore stacks inherit it (already true), and the ore refinery's yield scales with the richness of the batch it consumes. Ore refineries can select which ore-type they should refine, with input storage updating accordingly. Add a surface-level readout so players can see asteroid/batch quality (the "show asteroid contents" QoL note). Add the ability to select asteroids that are then prioritized in Job_MineAsteroid. Create a UI for MiningComponent and allow selection of which type of ore is prioritized (used as next in line after explicitly designated asteroids - after that, random).

## Current state (verified in code)
- `OreInstanceData.richness` is set in `Job_MineAsteroid.mine_asteroid()` from a placeholder `randf_range(0.3, 1.0)` with an explicit TODO to source it from the asteroid.
- AsteroidManager uses one standard asteroid_scene with pre-set ores and does not vary them
- AsteroidManager has ore_types_available but not currently used
- Stacks preserve `instance_data` through inventory → storage → piles; merge tolerance works (`ResourceData.merge_tolerance`).
- `ProcessorComponent` withdraws inputs via count-based `withdraw()` — instance data is discarded at the refinery door. This is the gap.

## Design
- `AsteroidBase` gets `richness_range: Vector2` (per-asteroid, randomized at spawn within a band; richer asteroids rarer). Mined stacks sample within the asteroid's range.
- `RefineryComponent` withdraws input **stacks** (`withdraw_stacks`), averages richness weighted by amount, and scales outputs: `output_amount = round(recipe_output × lerp(min_yield_mult, max_yield_mult, avg_richness))` with data-driven multipliers on `RecipeData` (e.g. 0.5–1.5).
- Fractional-yield fairness: accumulate remainders per output resource so long-run averages are exact (banker's residue, a float accumulator on the component).
- UI: asteroid tooltip/click shows remaining resources + richness descriptor ("Rich (82%)"); storage rows and pile UI show average richness for variant resources; processor UI shows current batch richness.

## Files to touch
- `objects/asteroid_base.gd` — richness_range, descriptor accessor; click/hover readout (has no input handling today — add an Area2D input like ResourcePile's, or surface via mining bay UI; simplest: `ui/` tooltip on hover using existing footprint pattern)
- `scripts/jobs/job_mine_asteroid.gd` — sample from asteroid instead of the placeholder constant range
- `modules/components/processor_component.gd` — stack-aware input withdrawal + yield scaling + residue accumulator
- `data/recipes/recipe_data.gd` — `min_yield_mult`, `max_yield_mult` (default 1.0/1.0 = no change for non-variant recipes)
- `data/recipes/*.tres` — set multipliers on ore-refining recipe(s) (`ore_processor` recipe; check which recipe resource the ore processor scene points at)
- `ui/windows/processor_component_ui.gd` — batch richness display
- `ui/windows/storage_resource_line.gd`, `ui/windows/component_ui_panels/resource_pile_inventory_tab.gd` — show avg richness where instance data exists
- `data/resources/ore_instance_data.gd` — display helpers (`get_primary_value` exists; add descriptor string)

## Implementation order
1. RecipeData multipliers + ProcessorComponent stack-aware consumption/yield (core mechanic).
2. Asteroid richness ranges + mining sampling.
3. Residue accumulator + assert conservation over many batches.
4. UI readouts (asteroid, storage, processor).

## Edge cases
- Mixed-richness input batch (two stacks merged across tolerance) — weighted average is what the container reports; verify `ResourceStackContainer.withdraw_stacks` returns actual stacks with their data (it does).
- Recipe needing 2+ input units when storage holds 1 rich + 1 poor stack → both consumed, average used.
- Non-variant recipes (steel, electrolysis) — multipliers 1.0, zero behavioral change; regression-check.
- Yield rounds to 0 on a tiny recipe with poor ore → clamp minimum output to ≥1? No — allow 0 with residue accumulation carrying it forward; verify no "recipe consumed, nothing produced, no residue" leak.
- Ore mined before this change (old saves) — instance_data null on variant resource → treat as richness 0.5 default (define `DEFAULT_RICHNESS` constant).
- Asteroid despawns mid-mining — existing handling; richness readout must not be queried on freed asteroid (tooltip guards).

## Verification
1. Spawn (debug) two asteroids at richness extremes; mine each into separate storerooms; refine separately → rich batch yields visibly more refined output per ore. Log totals across ≥20 batches: average yield within 2% of expected multiplier.
2. Steel/electrolysis chains produce identical outputs to pre-change (regression).
3. Storage UI shows differing richness for the two ore stockpiles; stacks within merge tolerance combine, outside stay separate (set tolerance low and verify two stacks visible).
4. Save/load: richness survives (WI-03 already covers instance data round-trip; re-verify with the refinery mid-batch).
5. Asteroid readout matches actual mined richness distribution.
