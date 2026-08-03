extends GutTest

## Unit tests for WI-43's pure build-menu logic (BuildMenuModel): grouping by the
## ModuleData.category_id, rail ordering, name search, and the recently-built MRU.
## All static - constructs ModuleData directly, never touches Global/SignalBus.

func _mod(mod_name: String, category: StringName, hidden: bool = false, id: String = "") -> ModuleData:
	var data := ModuleData.new()
	data.name = mod_name
	data.category_id = category
	data.hidden = hidden
	data.id = StringName(id if id != "" else mod_name)
	return data

# --- group_modules -----------------------------------------------------------

func test_group_buckets_by_category_id() -> void:
	var modules: Array[ModuleData] = [
		_mod("Solar Panel", &"power"),
		_mod("Fusion Reactor", &"power"),
		_mod("Small Storage", &"storage"),
	]
	var groups := BuildMenuModel.group_modules(modules)
	assert_eq((groups[&"power"] as Array).size(), 2, "both power modules bucket together")
	assert_eq((groups[&"storage"] as Array).size(), 1, "storage has its one module")
	assert_false(groups.has(&"industry"), "no bucket for an absent category")

func test_group_skips_hidden() -> void:
	var modules: Array[ModuleData] = [
		_mod("Battery", &"power", true),
		_mod("Solar Panel", &"power"),
	]
	var groups := BuildMenuModel.group_modules(modules)
	assert_eq((groups[&"power"] as Array).size(), 1, "the hidden battery drops out")

func test_group_sorts_bucket_by_name() -> void:
	var modules: Array[ModuleData] = [
		_mod("Zeta", &"crew"),
		_mod("Alpha", &"crew"),
		_mod("Mu", &"crew"),
	]
	var bucket := BuildMenuModel.group_modules(modules)[&"crew"] as Array
	assert_eq((bucket[0] as ModuleData).name, "Alpha", "first is alphabetically lowest")
	assert_eq((bucket[2] as ModuleData).name, "Zeta", "last is alphabetically highest")

func test_group_other_category_buckets() -> void:
	var modules: Array[ModuleData] = [_mod("Mystery", &"other")]
	var groups := BuildMenuModel.group_modules(modules)
	assert_true(groups.has(&"other"), "the default category buckets like any other")

# --- category_order ----------------------------------------------------------

func test_category_order_follows_declared_sort_order() -> void:
	var ordered := BuildMenuModel.category_order([
		&"storage", &"core", &"power",
	] as Array[StringName])
	assert_eq(ordered, [
		&"core", &"power", &"storage",
	] as Array[StringName], "categories follow declared sort_order, not input order")

func test_category_order_puts_other_last() -> void:
	var ordered := BuildMenuModel.category_order([
		&"other", &"logistics", &"core",
	] as Array[StringName])
	assert_eq(ordered[ordered.size() - 1], &"other", "the catch-all category always sorts last")

func test_category_order_dedupes() -> void:
	var ordered := BuildMenuModel.category_order([
		&"core", &"core", &"power",
	] as Array[StringName])
	assert_eq(ordered.size(), 2, "duplicate categories collapse to one rail entry")

# --- category_name -----------------------------------------------------------

func test_category_name_reads_the_declared_label() -> void:
	assert_eq(BuildMenuModel.category_name(&"life_support"), "Life Support", "multi-word label")
	assert_eq(BuildMenuModel.category_name(&"core"), "Core", "single-word label")

# --- undeclared categories (WI-47 M5) ------------------------------------------
# A module can name a category that nothing declares - it came from a mod that
# isn't installed. It must still reach the rail rather than vanishing.

func test_an_undeclared_category_still_renders_under_its_id() -> void:
	assert_eq(BuildMenuModel.category_name(&"coolmod.reactors"), "Coolmod.reactors",
			"an unknown id is its own label rather than blank")

func test_an_undeclared_category_sorts_after_every_declared_one() -> void:
	var ordered := BuildMenuModel.category_order([
		&"coolmod.reactors", &"other", &"core",
	] as Array[StringName])
	assert_eq(ordered[0], &"core")
	assert_eq(ordered[ordered.size() - 1], &"coolmod.reactors",
			"unknown sorts past even the catch-all, so it can never displace vanilla")

func test_two_undeclared_categories_order_reproducibly() -> void:
	# Both sit at UNKNOWN_SORT_ORDER, so the id breaks the tie - dictionary order
	# must never decide what the player sees.
	var ordered := BuildMenuModel.category_order([&"zmod.a", &"amod.b"] as Array[StringName])
	assert_eq(ordered, [&"amod.b", &"zmod.a"] as Array[StringName])

func test_declared_categories_are_in_sort_order() -> void:
	var previous: int = -1
	for category: BuildCategoryData in BuildCategoryData.all():
		assert_true(category.sort_order >= previous,
				"%s (%d) must not sort before the category ahead of it" % [category.id, category.sort_order])
		previous = category.sort_order

func test_every_vanilla_category_declares_a_label() -> void:
	for category: BuildCategoryData in BuildCategoryData.all():
		assert_ne(category.display_name, "", "%s needs a rail label" % category.id)

# --- filter_by_name ----------------------------------------------------------

func test_filter_matches_case_insensitively() -> void:
	var modules: Array[ModuleData] = [
		_mod("Ore Processor", &"industry"),
		_mod("Ice Processor", &"industry"),
		_mod("Solar Panel", &"power"),
	]
	var hits := BuildMenuModel.filter_by_name(modules, "pRoCeSs")
	assert_eq(hits.size(), 2, "case-insensitive substring matches both processors")

func test_filter_empty_query_returns_nothing() -> void:
	var modules: Array[ModuleData] = [_mod("Solar Panel", &"power")]
	assert_eq(BuildMenuModel.filter_by_name(modules, "   ").size(), 0, "a whitespace query returns nothing (flyout closes)")

func test_filter_no_match_returns_empty() -> void:
	var modules: Array[ModuleData] = [_mod("Solar Panel", &"power")]
	assert_eq(BuildMenuModel.filter_by_name(modules, "turbolift").size(), 0, "no match is empty")

func test_filter_skips_hidden() -> void:
	var modules: Array[ModuleData] = [_mod("Debug Panel", &"power", true)]
	assert_eq(BuildMenuModel.filter_by_name(modules, "panel").size(), 0, "hidden modules never surface in search")

# --- push_recent -------------------------------------------------------------

func test_push_recent_prepends() -> void:
	var out := BuildMenuModel.push_recent([&"a", &"b"] as Array[StringName], &"c", 5)
	assert_eq(out[0], &"c", "newest is first")
	assert_eq(out.size(), 3, "grows until capped")

func test_push_recent_dedupes_and_floats_to_front() -> void:
	var out := BuildMenuModel.push_recent([&"a", &"b", &"c"] as Array[StringName], &"c", 5)
	assert_eq(out[0], &"c", "re-built module floats to front")
	assert_eq(out.count(&"c"), 1, "appears exactly once (no duplicate)")

func test_push_recent_caps_length_dropping_oldest() -> void:
	var out := BuildMenuModel.push_recent([&"a", &"b", &"c"] as Array[StringName], &"d", 3)
	assert_eq(out, [&"d", &"a", &"b"] as Array[StringName], "capped at 3; oldest (c) drops off the end")

func test_push_recent_does_not_mutate_input() -> void:
	var original: Array[StringName] = [&"a", &"b"]
	BuildMenuModel.push_recent(original, &"c", 5)
	assert_eq(original.size(), 2, "input array is untouched")
