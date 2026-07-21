extends GutTest

## Unit tests for WI-29 food quality: the pure FoodInstanceData class (quality
## primary value, weighted merge, display, dict round-trip, and the static
## nourishment/mood mappings Job_Eat uses) plus the ResourceStackContainer blend
## that pools mixed-quality food. All constructed directly - no Global/SignalBus.

func _food(quality: float, type: StringName = &"") -> FoodInstanceData:
	var f := FoodInstanceData.new()
	f.quality = quality
	f.food_type = type
	return f

# --- FoodInstanceData basics --------------------------------------------------

func test_primary_value_is_quality() -> void:
	assert_almost_eq(_food(0.72).get_primary_value(), 0.72, 0.0001, "primary value = quality")

func test_default_quality_is_neutral() -> void:
	assert_almost_eq(FoodInstanceData.new().get_primary_value(), FoodInstanceData.DEFAULT_QUALITY, 0.0001, "a fresh FoodInstanceData reads as neutral 0.5")

func test_display_suffix_is_percent() -> void:
	assert_eq(_food(0.5).get_display_suffix(), "50%", "quality renders as a percentage")

# --- weighted merge (pool/stack blending) ------------------------------------

func test_merged_with_is_amount_weighted() -> void:
	# 3 units @ 0.8 merged with 1 unit @ 0.4 -> (0.8*3 + 0.4*1)/4 = 0.7
	var merged := _food(0.8).merged_with(_food(0.4), 3, 1) as FoodInstanceData
	assert_almost_eq(merged.quality, 0.7, 0.0001, "merge blends quality by unit weight")

func test_merged_with_zero_weight_keeps_self() -> void:
	var merged := _food(0.9).merged_with(_food(0.1), 0, 0) as FoodInstanceData
	assert_almost_eq(merged.quality, 0.9, 0.0001, "zero total weight falls back to self's quality")

func test_merged_with_keeps_own_food_type() -> void:
	var merged := _food(0.5, &"vegetables").merged_with(_food(0.5, &"slime"), 1, 1) as FoodInstanceData
	assert_eq(merged.food_type, &"vegetables", "merge keeps self's cosmetic food_type")

func test_merged_with_foreign_instance_returns_self() -> void:
	var ore := OreInstanceData.new()
	ore.richness = 0.2
	var result := _food(0.9).merged_with(ore, 1, 1)
	assert_almost_eq(result.get_primary_value(), 0.9, 0.0001, "merging with a non-food instance is a no-op")

# --- save round-trip ----------------------------------------------------------

func test_to_dict_round_trips_through_save_manager() -> void:
	var dict := _food(0.63, &"meat").to_dict()
	assert_eq(String(dict.get("type", "")), "food", "tagged as food for the factory")
	var restored := SaveManager.instance_from_dict(dict) as FoodInstanceData
	assert_not_null(restored, "instance_from_dict rebuilds a FoodInstanceData")
	assert_almost_eq(restored.quality, 0.63, 0.0001, "quality survives the round-trip")
	assert_eq(restored.food_type, &"meat", "food_type survives the round-trip")

# --- static effect mappings (Job_Eat) ----------------------------------------

func test_nourishment_mult_endpoints_and_midpoint() -> void:
	assert_almost_eq(FoodInstanceData.nourishment_mult(0.0, 0.7, 1.3), 0.7, 0.0001, "quality 0 -> min mult")
	assert_almost_eq(FoodInstanceData.nourishment_mult(1.0, 0.7, 1.3), 1.3, 0.0001, "quality 1 -> max mult")
	assert_almost_eq(FoodInstanceData.nourishment_mult(0.5, 0.7, 1.3), 1.0, 0.0001, "quality 0.5 -> midpoint")

func test_nourishment_mult_clamps_out_of_range_quality() -> void:
	assert_almost_eq(FoodInstanceData.nourishment_mult(1.5, 0.7, 1.3), 1.3, 0.0001, "quality clamps to 1")
	assert_almost_eq(FoodInstanceData.nourishment_mult(-0.5, 0.7, 1.3), 0.7, 0.0001, "quality clamps to 0")

func test_meal_mood_band_edges() -> void:
	# bad_band 0.3, good_band 0.7
	assert_eq(FoodInstanceData.meal_mood_band(0.9, 0.3, 0.7), 1, "well above good_band -> good")
	assert_eq(FoodInstanceData.meal_mood_band(0.7, 0.3, 0.7), 1, "exactly good_band -> good (inclusive)")
	assert_eq(FoodInstanceData.meal_mood_band(0.5, 0.3, 0.7), 0, "between bands -> neutral")
	assert_eq(FoodInstanceData.meal_mood_band(0.3, 0.3, 0.7), -1, "exactly bad_band -> bad (inclusive)")
	assert_eq(FoodInstanceData.meal_mood_band(0.1, 0.3, 0.7), -1, "well below bad_band -> bad")

# --- container blend (mixed-quality storage/pool) ----------------------------

func _food_container(tolerance: float) -> ResourceStackContainer:
	var res := ResourceData.new()
	res.id = &"test_food"
	res.has_variance = true
	res.merge_tolerance = tolerance
	var container := ResourceStackContainer.new()
	container.resource_data = res
	return container

func _food_stack(container: ResourceStackContainer, amount: int, quality: float) -> ResourceStack:
	var stack := ResourceStack.new()
	stack.resource_data = container.resource_data
	stack.amount = amount
	stack.instance_data = _food(quality)
	return stack

func test_close_quality_stacks_merge_and_blend() -> void:
	var c := _food_container(0.1)
	c.add_stack(_food_stack(c, 3, 0.80))
	c.add_stack(_food_stack(c, 1, 0.74)) # within 0.1 tolerance -> merges
	assert_eq(c.stacks.size(), 1, "close-quality stacks merge into one")
	assert_eq(c.stored, 4, "total tracks both")
	# (0.80*3 + 0.74*1)/4 = 0.785
	assert_almost_eq(c.stacks[0].instance_data.get_primary_value(), 0.785, 0.0001, "merged quality is amount-weighted")

func test_distant_quality_stacks_stay_separate() -> void:
	var c := _food_container(0.1)
	c.add_stack(_food_stack(c, 2, 0.9))
	c.add_stack(_food_stack(c, 2, 0.2)) # outside tolerance -> own stack
	assert_eq(c.stacks.size(), 2, "far-apart qualities bucket separately")
	# average_instance_value is the amount-weighted mean across stacks
	assert_almost_eq(c.average_instance_value(), 0.55, 0.0001, "average blends both buckets by amount")
