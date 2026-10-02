extends GutTest

## WI-47 M8: recipe eligibility inverted onto RecipeData.processor_tags, and the
## reverse index a processor asks "which recipes claim my module's tags".
##
## The index is static and shared by every suite in a run, so each test rebuilds
## it from scratch. Pure - no Global, no scene, no processor.

func before_each() -> void:
	RecipeData.clear_for_test()

func after_each() -> void:
	# Puts the shipped content back in every cache at once (WI-74 §2).
	ContentPaths.invalidate()

func _recipe(recipe_name: String, tags: Array[String], sort_order: int = 0) -> RecipeData:
	var recipe := RecipeData.new()
	recipe.name = recipe_name
	recipe.processor_tags = tags
	recipe.sort_order = sort_order
	RecipeData.register_for_test(recipe)
	return recipe

func _names(recipes: Array[RecipeData]) -> Array[String]:
	var out: Array[String] = []
	for recipe: RecipeData in recipes:
		out.append(recipe.name)
	return out

# --- matching -------------------------------------------------------------------

func test_a_recipe_reaches_every_processor_claiming_its_tag() -> void:
	_recipe("Smelt Iron", ["Refinery"])
	assert_eq(_names(RecipeData.for_tags(["Refinery"])), ["Smelt Iron"] as Array[String])

func test_a_processor_sees_nothing_it_has_no_tag_for() -> void:
	_recipe("Smelt Iron", ["Refinery"])
	assert_eq(RecipeData.for_tags(["Forge"]).size(), 0)

func test_a_module_with_no_tags_matches_nothing() -> void:
	_recipe("Smelt Iron", ["Refinery"])
	assert_eq(RecipeData.for_tags([] as Array[String]).size(), 0)

func test_one_recipe_can_claim_several_processors() -> void:
	# The reason eligibility is by tag and not by module id: one declaration
	# reaches the vanilla refinery AND a mod's advanced refinery.
	_recipe("Smelt Iron", ["Refinery", "AdvancedRefinery"])
	assert_eq(_names(RecipeData.for_tags(["AdvancedRefinery"])), ["Smelt Iron"] as Array[String])

func test_a_recipe_matching_two_of_a_modules_tags_appears_once() -> void:
	_recipe("Smelt Iron", ["Refinery", "Industrial"])
	assert_eq(RecipeData.for_tags(["Refinery", "Industrial"]).size(), 1, "no duplicate in the selector")

func test_a_mod_recipe_joins_a_vanilla_processor() -> void:
	# The whole point of M8: adding a recipe to an existing processor without
	# shipping a replacement module scene.
	_recipe("Smelt Iron", ["Refinery"], 10)
	_recipe("Smelt Glimmerite", ["Refinery"], 15)
	assert_eq(_names(RecipeData.for_tags(["Refinery"])),
			["Smelt Iron", "Smelt Glimmerite"] as Array[String])

# --- ordering -------------------------------------------------------------------

func test_selector_order_follows_sort_order() -> void:
	_recipe("Third", ["Refinery"], 30)
	_recipe("First", ["Refinery"], 10)
	_recipe("Second", ["Refinery"], 20)
	assert_eq(_names(RecipeData.for_tags(["Refinery"])),
			["First", "Second", "Third"] as Array[String])

func test_equal_sort_orders_break_on_name() -> void:
	# Reproducible run to run: scan order must never decide what the player sees.
	_recipe("Zeta", ["Refinery"], 10)
	_recipe("Alpha", ["Refinery"], 10)
	assert_eq(_names(RecipeData.for_tags(["Refinery"])), ["Alpha", "Zeta"] as Array[String])

func test_a_mod_can_slot_a_recipe_between_two_vanilla_ones() -> void:
	# Vanilla leaves gaps of 10 precisely so this is possible.
	_recipe("Iron", ["Refinery"], 10)
	_recipe("Carbon", ["Refinery"], 20)
	_recipe("Glimmerite", ["Refinery"], 15)
	assert_eq(_names(RecipeData.for_tags(["Refinery"])),
			["Iron", "Glimmerite", "Carbon"] as Array[String])

# --- the shipped data -----------------------------------------------------------

func test_every_vanilla_recipe_declares_a_processor() -> void:
	# A recipe with no processor_tags is unreachable from the index and would only
	# still work by being some scene's authored default.
	RecipeData.clear_for_test()
	var untagged: Array[String] = []
	for path: String in ContentPaths.scan(ContentPaths.RECIPES):
		var recipe: RecipeData = ResourceLoader.load(path) as RecipeData
		if recipe != null and recipe.processor_tags.is_empty():
			untagged.append(path.get_file())
	assert_eq(untagged, [] as Array[String], "untagged recipes: %s" % str(untagged))

## A slot has ONE role (WI-65), so a recipe that names a resource on both sides
## cannot be given a bin: whichever of INPUT and OUTPUT `_sync_storages` assigned
## last would win and the other half of the recipe would stop working. This was an
## `assert` inside `_sync_storages` until WI-72 §2, which means a release export
## had no check at all - and it only ever saw the recipe a processor happened to
## be running, never the one sitting in `data/recipes/` waiting to be selected.
func test_no_recipe_names_a_resource_as_both_an_input_and_an_output() -> void:
	RecipeData.clear_for_test()
	var swept: int = 0
	for path: String in ContentPaths.scan(ContentPaths.RECIPES):
		var recipe: RecipeData = ResourceLoader.load(path) as RecipeData
		if recipe == null:
			continue
		swept += 1
		assert_eq(ProcessorComponent.recipe_role_conflict(recipe), "",
			"%s: %s" % [path.get_file(), ProcessorComponent.recipe_role_conflict(recipe)])
	assert_gt(swept, 5, "the scan sees data/recipes/")

func test_the_foundry_offers_steel_then_the_precious_metals() -> void:
	# Steel feeds straight on iron ore since there stopped being an iron step
	# (2026-10-02), and gold and iridium moved here from the retired ore processor.
	RecipeData.clear_for_test()
	var names: Array[String] = _names(RecipeData.for_tags(["Industrial", "Forge"]))
	assert_eq(names, ["Forge Steel", "Refine Gold", "Refine Iridium"] as Array[String],
		"the Foundry's selector, in its authored order")

func test_the_silicon_furnace_has_one_recipe() -> void:
	# One recipe is what keeps the furnace's selector off the panel
	# (ProcessorComponent.can_select_recipes), so a second "Refinery" recipe is a
	# UI change as well as a content one.
	RecipeData.clear_for_test()
	var names: Array[String] = _names(RecipeData.for_tags(["Industrial", "Refinery"]))
	assert_eq(names, ["Refine Silicon"] as Array[String], "silicon and nothing else")
