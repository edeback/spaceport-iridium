# WI-09 — Ore Richness Through Refining

> **Status: implemented & verified in-game (2026-07-16).** Deviations from plan:
> - "Forge Steel" stayed on the ore processor as a sixth selectable recipe (the scene was already mid-transition and non-functional; no separate forge module exists yet).
> - Recipe-switch leftovers drain via the module's overflow pile (refinery input has `accepts_exports = false`, so surplus-export posting can't move them), with incoming haul jobs cancelled first.
> - Found & fixed in verification: `mining_bay.tscn` output storage and `asteroid_base.tscn` fallback contents were still authored with *refined* metals — drones couldn't deposit the new `*_ore` resources; both now use the ore variants.
> - Asteroid state (mix/richness/designation) and `priority_ore` not persisted (asteroids aren't saved at all) — noted in 03_Bugs. Selected recipe **is** persisted and verified across save/load.

## Goal
Make the existing ore variance system matter: asteroids carry a richness profile, asteroids spawn with different types of ores available, mined ore stacks inherit it (already true), and the ore refinery's yield scales with the richness of the batch it consumes. Ore refineries can select which ore-type they should refine, with input storage updating accordingly. Add a surface-level readout so players can see asteroid/batch quality (the "show asteroid contents" QoL note). Add the ability to select asteroids that are then prioritized in Job_MineAsteroid. Create a UI for MiningComponent and allow selection of which type of ore is prioritized (used as next in line after explicitly designated asteroids - after that, random).

## Current state (verified in code)
- `OreInstanceData.richness` is set in `Job_MineAsteroid.mine_asteroid()` from a placeholder `randf_range(0.3, 1.0)` (`ORE_RICHNESS_RANGE`) with an explicit comment to source it from the asteroid — but only when `mined_resource.has_variance` is true, and **no ore `.tres` currently sets `has_variance = true`**, so richness isn't actually attached with shipped data. Flip it on for the five ores as part of this WI.
- `AsteroidManager.spawn_asteroid()` instantiates one standard `asteroid_scene` whose `resource_weighted_values` are pre-set in the scene — every asteroid has identical ore contents.
- `AsteroidManager.ore_types_available` is exported and populated in `main.tscn` with the five ores (iron/carbon/silicon/gold/iridium) but never read.
- `Job_MineAsteroid.get_asteroid()` shuffles the `"asteroid"` group and takes the first non-empty one — pure random, no designation or ore preference.
- `AsteroidBase` has no input handling (no Area2D); `ResourcePile` has the pattern to copy: a `ClickArea` Area2D whose `input_event` emits a clicked signal and calls into `Global.ui_main`.
- `MiningComponent.has_ui()` returns `false` — no UI exists.
- The ore processor scene (`modules/industrial_processors/ore_processor.tscn`) points at `steel_recipe.tres` (iron + carbon → steel). **There are no ore→metal refining recipes yet**; `data/recipes/` holds steel, electrolysis, ice, algae, hydroponics only. The five refined counterparts (`iron.tres`, `carbon.tres`, `silicon.tres`, `gold.tres`, `iridium.tres`) already exist.
- `ProcessorComponent` has a single fixed `@export var recipe: RecipeData` and withdraws inputs via count-based `withdraw()` — instance data is discarded at the refinery door. This is the gap.
- `StorageComponent` already supports runtime reconfiguration: `add_stored_resource()` / `remove_stored_resource()` (the latter ends that resource's jobs), with a player-facing precedent in `ui_storage_component.gd` (`player_configurable`).
- Stacks preserve `instance_data` through inventory → storage → piles; merge tolerance works (`ResourceData.merge_tolerance`). `StorageComponent.withdraw_stacks()` exists and returns real stacks.

## Design

### Asteroid variety & richness
- `AsteroidManager.spawn_asteroid()` generates each asteroid's `resource_weighted_values` from `ore_types_available` instead of using the scene's pre-set dictionary: pick 1–3 ore types per asteroid with random weights (rarer ores — gold, iridium — get lower selection probability; keep the selection weights as exported data on AsteroidManager, not constants).
- `AsteroidBase` gets `richness_range: Vector2` (per-asteroid, randomized at spawn within a band; richer asteroids rarer). Mined stacks sample within the asteroid's range — replaces the `ORE_RICHNESS_RANGE` placeholder in `Job_MineAsteroid`.
- Set `has_variance = true` (and a sensible `merge_tolerance`) on the five ore `.tres` files so the existing instance-data plumbing actually engages.

### Asteroid designation
- `AsteroidBase` gets a `ClickArea` Area2D (ResourcePile pattern) and a `designated: bool` toggled by click, with a visual marker (outline/icon) while designated. Emits through SignalBus if UI elsewhere needs it.
- `Job_MineAsteroid.get_asteroid()` picks in priority order: (1) non-empty designated asteroids, (2) non-empty asteroids carrying the requesting `MiningComponent`'s priority ore type, (3) random non-empty (current shuffle behavior). Designation is global (any mining bay's drones honor it), priority ore is per-component.

### Refinery ore-type selection
- New `.tres` refining recipes, one per ore: `iron_ore → iron`, `carbon_ore → carbon`, `silicon_ore → silicon`, `gold_ore → gold`, `iridium_ore → iridium` (`data/recipes/refining/`). Ore processor's fixed steel recipe moves off the refinery or stays as one selectable option — decide when touching the scene; the steel chain must keep working somewhere.
- `ProcessorComponent` gains `@export var available_recipes: Array[RecipeData]` and a `selected_recipe` (defaulting to the existing single `recipe` for backward compatibility with the other processor scenes — leave them single-recipe). Selecting a recipe: cancel/complete guard (don't swap mid-batch; queue the switch until the current batch finishes), then update `input_storage` via `remove_stored_resource()` for old inputs and `add_stored_resource()` for new ones so hauling jobs retarget automatically (desired amounts refresh through the existing posting scan).
- `RecipeData` gets `min_yield_mult` / `max_yield_mult` (default 1.0/1.0 = no change for non-variant recipes).
- `ProcessorComponent` withdraws input **stacks** (`withdraw_stacks`), averages richness weighted by amount, and scales outputs: `output_amount = round(recipe_output × lerp(min_yield_mult, max_yield_mult, avg_richness))`.
- Fractional-yield fairness: accumulate remainders per output resource so long-run averages are exact (banker's residue, a float accumulator on the component).

### MiningComponent UI
- `MiningComponent.has_ui()` → true; new `MiningComponentUI` (mirror `ProcessorComponentUI` structure) showing drone count/status and an ore-priority selector (OptionButton over `AsteroidManager.ore_types_available` + "None"). Stores `priority_ore: ResourceData` on the component; consumed by `Job_MineAsteroid.get_asteroid()` step 2.

### Readouts
- Asteroid tooltip/click shows remaining resources + richness descriptor ("Rich (82%)") and designation state; storage rows and pile UI show average richness for variant resources; processor UI shows current batch richness and the recipe selector.

## Files to touch
- `data/resources/iron_ore.tres`, `carbon_ore.tres`, `silicon_ore.tres`, `gold_ore.tres`, `iridium_ore.tres` — `has_variance = true`, `merge_tolerance`
- `scripts/managers/asteroid_manager.gd` — generate per-asteroid ore mix from `ore_types_available`; exported rarity weights; richness band
- `objects/asteroid_base.gd` — `richness_range`, `designated` + ClickArea input (ResourcePile pattern) + designation visual, descriptor accessor, tooltip readout
- `scripts/jobs/job_mine_asteroid.gd` — remove `ORE_RICHNESS_RANGE`, sample from asteroid; `get_asteroid()` designated → priority-ore → random selection
- `modules/components/mining_component.gd` — `priority_ore`, `has_ui()`/`get_ui()`
- `ui/windows/mining_component_ui.gd` (+ scene) — new: drone status + ore priority selector
- `modules/components/processor_component.gd` — `available_recipes`/`selected_recipe` + deferred switch + input-storage reconfiguration; stack-aware input withdrawal + yield scaling + residue accumulator
- `data/recipes/recipe_data.gd` — `min_yield_mult`, `max_yield_mult` (default 1.0/1.0)
- `data/recipes/refining/*.tres` — new: five ore→metal recipes with yield multipliers (e.g. 0.5–1.5)
- `modules/industrial_processors/ore_processor.tscn` — point at the refining recipe set; resolve where steel forging lives
- `ui/windows/processor_component_ui.gd` — recipe selector + batch richness display
- `ui/windows/storage_resource_line.gd`, `ui/windows/component_ui_panels/resource_pile_inventory_tab.gd` — show avg richness where instance data exists
- `data/resources/ore_instance_data.gd` — display helpers (`get_primary_value` exists; add descriptor string)

## Implementation order
1. Ore data flags (`has_variance`) + refining recipes + RecipeData multipliers + ProcessorComponent stack-aware consumption/yield (core mechanic, still single-recipe).
2. Recipe selection on ProcessorComponent + input storage reconfiguration + processor UI selector.
3. Asteroid ore-mix generation + richness ranges + mining sampling.
4. Asteroid designation (click + visual) and `get_asteroid()` priority order.
5. MiningComponent UI + priority ore wiring.
6. Residue accumulator + assert conservation over many batches.
7. Remaining UI readouts (asteroid tooltip, storage, batch richness).

## Edge cases
- Mixed-richness input batch (two stacks merged across tolerance) — weighted average is what the container reports; verify `ResourceStackContainer.withdraw_stacks` returns actual stacks with their data (it does).
- Recipe needing 2+ input units when storage holds 1 rich + 1 poor stack → both consumed, average used.
- Non-variant recipes (steel, electrolysis) — multipliers 1.0, zero behavioral change; regression-check.
- Yield rounds to 0 on a tiny recipe with poor ore → clamp minimum output to ≥1? No — allow 0 with residue accumulation carrying it forward; verify no "recipe consumed, nothing produced, no residue" leak.
- Recipe switch while a batch is mid-process → finish the batch at the old recipe, then swap; residue accumulator resets per output resource that leaves the recipe.
- Recipe switch with old-ore stock still in input storage → `remove_stored_resource()` ends its jobs; leftover stock must not strand (existing surplus export posting should push it out — verify, since sinks must out-priority sources).
- Ore mined before this change (old saves) — instance_data null on variant resource → treat as richness 0.5 default (define `DEFAULT_RICHNESS` constant).
- Designated asteroid despawns or is mined dry → designation dies with the node (it's a flag on the instance); `get_asteroid()` re-picks via existing despawn/empty handling. Richness readout must not be queried on freed asteroid (tooltip guards).
- Priority ore set on one mining bay must not affect another bay's drones (per-component, passed through the job's `requesting_component`).
- Asteroid click must not fight module/pile selection — same input-consumption discipline as ResourcePile's ClickArea.
- Save/load: `designated`, per-asteroid ore mix and richness_range, `selected_recipe`, `priority_ore`, and residue accumulators all need persistence (asteroids may not be saved at all today — if not, designation/mix loss on load is acceptable this WI; note it in 03_Bugs if punted).

## Verification
1. Spawn (debug) two asteroids at richness extremes; mine each into separate storerooms; refine separately → rich batch yields visibly more refined output per ore. Log totals across ≥20 batches: average yield within 2% of expected multiplier.
2. Steel/electrolysis chains produce identical outputs to pre-change (regression).
3. Watch ~10 spawns: asteroids show differing ore mixes drawn from `ore_types_available`; rare ores appear less often.
4. Designate a distant asteroid while a nearer one is available → drones fly to the designated one until it's dry, then fall back to the priority ore, then random.
5. Set priority ore on bay A only → bay A's drones seek that ore's asteroids; bay B unaffected.
6. Switch refinery from iron to gold refining mid-stock → current batch completes at iron recipe, input storage retargets to gold ore (haul jobs appear), leftover iron ore exports out rather than stranding.
7. Storage UI shows differing richness for the two ore stockpiles; stacks within merge tolerance combine, outside stay separate (set tolerance low and verify two stacks visible).
8. Save/load: richness survives (WI-03 already covers instance data round-trip; re-verify with the refinery mid-batch and a selected non-default recipe).
9. Asteroid readout matches actual mined richness distribution and shows designation state.
