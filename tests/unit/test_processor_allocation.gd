extends GutTest

## WI-65 §6: a recipe's input `desired` is an integral number of RUNS, not a
## rounded ratio.
##
## The old rule was `ceili(qty / total * max_stored)` per ingredient, which
## rounds each share up independently and can therefore sum ABOVE the pool - and
## two shipped recipes already did (Farm Algae and Grow Plants, 8 + 8 into a bay
## of 15). While `desired` was only a haul target that overshoot was harmless.
## Once it becomes a cap it is exactly what lets one ingredient starve another,
## which is the deadlock the whole of stage 2 exists to prevent.
##
## The content sweep at the bottom is the half that keeps this true after the
## item closes: it walks every recipe actually shipped, including a mod's.

const RECIPE_DIR: String = "res://data/recipes"

func _inputs(pairs: Array) -> Dictionary[ResourceData, int]:
	var out: Dictionary[ResourceData, int] = {}
	for pair: Array in pairs:
		var resource := ResourceData.new()
		resource.id = StringName(pair[0])
		resource.name = String(pair[0])
		out[resource] = int(pair[1])
	return out

func _desired(pairs: Array, pool: int) -> Array[int]:
	var inputs: Dictionary[ResourceData, int] = _inputs(pairs)
	var runs: int = ProcessorComponent.runs_for(inputs, pool)
	var out: Array[int] = []
	for resource: ResourceData in inputs:
		out.append(runs * inputs[resource])
	return out

# --- the allocator ------------------------------------------------------------------

func test_every_ingredient_gets_the_same_number_of_runs() -> void:
	# Forge Steel: 1 carbon + 2 iron ore into a 30-unit bay.
	var inputs: Dictionary[ResourceData, int] = _inputs([["carbon", 1], ["iron_ore", 2]])
	assert_eq(ProcessorComponent.runs_for(inputs, 30), 10, "30 / 3 = ten batches")
	var allocated: Array[int] = _desired([["carbon", 1], ["iron_ore", 2]], 30)
	assert_eq(allocated, [10, 20], "and each ingredient holds ten batches' worth")

func test_the_shares_can_never_sum_above_the_pool() -> void:
	# The property the whole rule exists for, over a spread of awkward divisions.
	for pool: int in [1, 7, 10, 15, 16, 20, 30, 31, 100]:
		for recipe: Array in [[["a", 1]], [["a", 1], ["b", 1]], [["a", 2], ["b", 1]],
				[["a", 5], ["b", 1], ["c", 1]], [["a", 3], ["b", 4]]]:
			var inputs: Dictionary[ResourceData, int] = _inputs(recipe)
			var runs: int = ProcessorComponent.runs_for(inputs, pool)
			var total: int = 0
			for resource: ResourceData in inputs:
				total += runs * inputs[resource]
			assert_true(total <= pool,
				"pool %d, recipe %s allocated %d" % [pool, str(recipe), total])

func test_the_shares_stay_in_the_recipes_proportions() -> void:
	var allocated: Array[int] = _desired([["a", 5], ["b", 1], ["c", 1]], 49)
	assert_eq(allocated, [35, 7, 7], "seven runs of a 5:1:1 recipe")

## The two shipped recipes the old rule got wrong. Pinned at their corrected
## values so a future retune of the bay cannot quietly reintroduce the overshoot.
func test_the_growers_no_longer_overshoot_their_bay() -> void:
	# Farm Algae and Grow Plants are both 1 + 1 into a 15-unit bay. The old
	# ceili() rule allocated 8 + 8 = 16.
	var allocated: Array[int] = _desired([["water", 1], ["co2", 1]], 15)
	assert_eq(allocated, [7, 7], "seven runs, not a rounded-up half each")
	assert_eq(allocated[0] + allocated[1], 14, "14 of 15 used, and 16 was the bug")

## Undershoot is the accepted cost, and is bounded by one batch.
func test_the_leftover_is_always_less_than_one_batch() -> void:
	for pool: int in range(1, 60):
		for recipe: Array in [[["a", 1], ["b", 1]], [["a", 2], ["b", 3]], [["a", 7]]]:
			var inputs: Dictionary[ResourceData, int] = _inputs(recipe)
			var batch: int = 0
			for qty: int in inputs.values():
				batch += qty
			if pool < batch:
				continue
			var runs: int = ProcessorComponent.runs_for(inputs, pool)
			assert_true(pool - runs * batch < batch,
				"pool %d, batch %d, runs %d wastes a whole batch" % [pool, batch, runs])

# --- the authoring error ---------------------------------------------------------------

## A bay that cannot hold one batch is an authoring error, not a case to clamp:
## clamping to one run would put the caps' SUM above the pool, which is the very
## state that lets one ingredient starve another - and the module could not
## assemble a batch even if it filled perfectly.
func test_a_recipe_too_big_for_the_bay_reports_zero_runs() -> void:
	var inputs: Dictionary[ResourceData, int] = _inputs([["a", 20], ["b", 20]])
	assert_eq(ProcessorComponent.runs_for(inputs, 30), 0)
	assert_false(ProcessorComponent.recipe_fits(inputs, 30),
		"40 units of ingredients do not fit a 30-unit bay at any allocation")

func test_a_recipe_that_exactly_fills_the_bay_fits() -> void:
	var inputs: Dictionary[ResourceData, int] = _inputs([["a", 20], ["b", 10]])
	assert_eq(ProcessorComponent.runs_for(inputs, 30), 1)
	assert_true(ProcessorComponent.recipe_fits(inputs, 30), "exactly one batch is enough")

func test_a_recipe_with_no_inputs_needs_no_capacity() -> void:
	var inputs: Dictionary[ResourceData, int] = _inputs([])
	assert_eq(ProcessorComponent.runs_for(inputs, 10), 0,
		"nothing to allocate, and no division by zero")

# --- content sweep -----------------------------------------------------------------------

## Every recipe actually shipped must fit the bay of every module that can run
## it. This is the check that survives the item: a designer widening a recipe or
## narrowing a bay six months from now fails here rather than shipping a
## processor that silently never runs.
func test_every_shipped_recipe_fits_every_processor_that_can_run_it() -> void:
	var recipes: Array[RecipeData] = _all_recipes()
	assert_gt(recipes.size(), 0, "the sweep found no recipes, which is itself a failure")
	var bays: Dictionary[String, int] = _processor_bays()
	assert_gt(bays.size(), 0, "the sweep found no processors")
	for recipe: RecipeData in recipes:
		for tag: String in recipe.processor_tags:
			if not bays.has(tag):
				continue
			assert_true(ProcessorComponent.recipe_fits(recipe.inputs, bays[tag]),
				"recipe '%s' needs %d intake capacity; the '%s' bay holds %d"
					% [recipe.name, _batch_size(recipe.inputs), tag, bays[tag]])

## No resource may be both an ingredient and a product of the same recipe - a
## slot has one role, and _sync_storages asserts against it.
func test_no_recipe_names_a_resource_on_both_sides() -> void:
	for recipe: RecipeData in _all_recipes():
		for ingredient: ResourceData in recipe.inputs:
			assert_false(recipe.outputs.has(ingredient),
				"recipe '%s' has %s as both an input and an output"
					% [recipe.name, ingredient.name])

func _batch_size(inputs: Dictionary[ResourceData, int]) -> int:
	var total: int = 0
	for qty: int in inputs.values():
		total += qty
	return total

func _all_recipes() -> Array[RecipeData]:
	var out: Array[RecipeData] = []
	_scan_recipes(RECIPE_DIR, out)
	return out

func _scan_recipes(dir_path: String, out: Array[RecipeData]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			_scan_recipes(full, out)
		elif entry.ends_with(".tres") or entry.ends_with(".tres.remap"):
			var recipe := load(full.trim_suffix(".remap")) as RecipeData
			if recipe != null:
				out.append(recipe)
		entry = dir.get_next()
	dir.list_dir_end()

## processor tag -> the smallest intake pool any module carrying that tag offers.
## Smallest, because a recipe has to fit in every bay that can run it, not just
## the roomiest.
func _processor_bays() -> Dictionary[String, int]:
	var out: Dictionary[String, int] = {}
	for module: ModuleData in _all_modules():
		if module.scene == null:
			continue
		var state: SceneState = module.scene.get_state()
		var pool: int = _intake_pool(state)
		if pool < 0:
			continue
		for tag: String in module.tags:
			if not out.has(tag) or pool < out[tag]:
				out[tag] = pool
	return out

## The `max_stored` of the scene's non-construction storage node, or -1 when the
## scene has no processor in it. Read off the SceneState rather than by
## instantiating, so the sweep stays a pure-data test.
func _intake_pool(state: SceneState) -> int:
	var has_processor: bool = false
	var pool: int = -1
	for index: int in state.get_node_count():
		var script_path: String = ""
		var max_stored: int = 10 # the StorageComponent default
		var construction: bool = false
		var is_storage: bool = false
		for prop: int in state.get_node_property_count(index):
			var prop_name: String = state.get_node_property_name(index, prop)
			var value: Variant = state.get_node_property_value(index, prop)
			match prop_name:
				"max_stored":
					max_stored = int(value)
				"construction_storage":
					construction = bool(value)
				"recipe":
					has_processor = true
		var instance: PackedScene = state.get_node_instance(index)
		if instance != null:
			script_path = instance.resource_path
			is_storage = script_path.ends_with("storage_component.tscn")
		if is_storage and not construction:
			pool = max_stored
	return pool if has_processor else -1

func _all_modules() -> Array[ModuleData]:
	var out: Array[ModuleData] = []
	_scan_modules("res://data/modules", out)
	return out

func _scan_modules(dir_path: String, out: Array[ModuleData]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			_scan_modules(full, out)
		elif entry.ends_with(".tres") or entry.ends_with(".tres.remap"):
			var module := load(full.trim_suffix(".remap")) as ModuleData
			if module != null:
				out.append(module)
		entry = dir.get_next()
	dir.list_dir_end()
