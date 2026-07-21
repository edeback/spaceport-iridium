# WI-29 — Food Quality

## Goal
What the crew eats matters: food carries a quality level set by the producing module and the worker who made it; eating better food nourishes more and nudges mood, worse food the reverse.

**Representation decision (user-confirmed):** continuous 0–1 quality on one food resource via the existing `has_variance` / `ItemInstanceData` machinery — exactly the ore-richness pattern. An optional type tag (meat/vegetables/slime/…) rides the same instance data.

## Design
- **Data.** New `FoodInstanceData` (`data/resources/food_instance_data.gd`) extending ItemInstanceData: `quality: float` (primary value), `food_type: StringName` (optional, cosmetic v1). `SaveManager.instance_from_dict` gains a `"food"` branch. The existing food resource .tres flips `has_variance = true` with a sensible `merge_tolerance` (~0.1 — coarser than ore; kitchens shouldn't fragment storage). Stacks without instance data read as `DEFAULT_QUALITY = 0.5` (the established ore precedent), which grandfathers every existing save and recipe.
- **Production.** Producer modules set output quality: `RecipeData` gains `output_quality_base: float` (-1 = non-food/no variance, keeps current behavior) and food-producing recipes get values expressing the module ladder (algae tank < hydroponics < greenhouse — numbers in .tres). `ProcessorComponent._try_deposit_outputs` attaches `FoodInstanceData` to outputs whose recipe says so: `quality = clamp(output_quality_base + worker_quality_shift, 0, 1)` where `worker_quality_shift` comes from the batch worker's Growing/Crafting skill (WI-23 manned processors know their worker; unmanned producers use base quality). The deposit path must call the stack-merge logic with instance data (already how ore refining outputs would work — verify `deposit` supports instanced stacks; extend if it only handles plain).
- **Consumption.** `SustenanceComponent` currently melts food into an int pool — that discards quality. Change: track `sustenance_available` alongside a running quality average: when withdrawing a food unit, blend its quality into `pool_quality` (amount-weighted). `consume_sustenance` returns (amount, quality). `Job_Eat` applies: nourishment = amount × `lerp(min_nourish_mult, max_nourish_mult, quality)`; mood: quality ≥ good-band → timed positive happiness modifier (`PawnNeedsComponent.add_modifier`, id `&"good_meal"`), ≤ bad-band → negative (`&"bad_meal"`); middle band neutral. Band edges + mult range exported on the sustenance/eating side.
- **Trade/market:** traders sell generic quality-0.5 food (no instance data) — automatic via the default. Contract/market flows are untouched (variance already flows through storage, hauling, piles, save).
- **UI:** storage lines and the sustenance panel show quality (reuse however ore richness renders in storage rows; sustenance panel shows pool quality as stars/percent).

## Files to touch
- **New:** `data/resources/food_instance_data.gd`
- `data/resources/*.tres` (food) — `has_variance`, merge tolerance
- `data/recipes/recipe_data.gd` — `output_quality_base`; food recipe .tres sweep
- `modules/components/processor_component.gd` — instanced output deposit + worker quality shift (builds on WI-23's worker link)
- `modules/components/storage_component.gd` / `storage_data.gd` — only if instanced-deposit gaps surface (ore paths suggest most of this exists)
- `modules/components/sustenance_component.gd` — pool quality; `scripts/jobs/job_eat.gd` — nourishment/mood application
- `scripts/managers/save_manager.gd` — food branch in `instance_from_dict`; sustenance pool quality in module save data
- `ui/windows/ui_sustenance_component.gd`, `storage_resource_line.gd` — quality display
- WI-19 followup: quality-blend math + band-mapping unit tests

## Implementation order
1. FoodInstanceData + resource flip + save branch; verify existing food flows (produce, haul, store, trade, save) unchanged at default quality.
2. Recipe quality + processor attachment (unmanned base quality first, worker shift once WI-23's worker link is confirmed in place).
3. Sustenance pool quality + Job_Eat effects.
4. UI + tests.

## Edge cases
- Mixed-quality stock in one storage: merge tolerance buckets stacks; the sustenance pool blend makes meal-to-meal quality smooth rather than lurchy — intended.
- Sustenance pool at zero with quality NaN risk: pool_quality only defined while `sustenance_available > 0`; reset to neutral on empty.
- Pre-WI-29 saves: stored food has no instance data → 0.5 everywhere; pool quality missing from module save → default. No migration needed beyond defaults.
- Worker quality shift when a batch has multiple workers over its life (pawn swapped mid-batch, WI-23): use the worker who *completes* the batch (simple, documented) — not worth blending v1.
- Richness-style batch averaging on *inputs* (ore) vs quality on *outputs* (food): a recipe could someday do both (process raw meat → meals); the processor already averages input variance — output quality may optionally read it (`inherit_input_quality` flag, default off; note as future).
- Trait interactions (WI-22 Conceited is deferred) — bands are the only mood source here.
- Two mood modifiers stacking (good meal then bad meal): ids overwrite per `add_modifier` semantics — last meal wins; verify that's the modifier system's actual behavior and document.

## Verification
1. Algae tank vs greenhouse output: storage rows show distinct qualities matching .tres bases; a skilled grower (cheat skill 10) raises hydroponics output measurably vs skill 0.
2. Crew fed 0.9-quality food: hunger refills further per meal + good-meal mood modifier appears in the pawn panel; 0.1-quality food shows the malus; watch happiness diverge between two stations (cheat-stock each).
3. Trader-bought food behaves as 0.5 neutral.
4. Save/load: stack qualities, sustenance pool quality, and mood modifiers round-trip.
5. Full chain regression: grow → haul → sustenance stock → eat, with a pre-WI-29 save loaded mid-chain, zero errors.
6. GUT: blend math, band mapping, default-quality fallbacks green.
