extends GutTest

## Unit tests for WI-43's pure build-menu logic (BuildMenuModel): grouping by the
## ModuleData.UICategory enum, rail ordering, name search, and the recently-built MRU.
## All static - constructs ModuleData directly, never touches Global/SignalBus.

func _mod(mod_name: String, category: ModuleData.UICategory, hidden: bool = false, id: String = "") -> ModuleData:
	var data := ModuleData.new()
	data.name = mod_name
	data.ui_category = category
	data.hidden = hidden
	data.id = StringName(id if id != "" else mod_name)
	return data

# --- group_modules -----------------------------------------------------------

func test_group_buckets_by_ui_category() -> void:
	var modules: Array[ModuleData] = [
		_mod("Solar Panel", ModuleData.UICategory.POWER),
		_mod("Fusion Reactor", ModuleData.UICategory.POWER),
		_mod("Small Storage", ModuleData.UICategory.STORAGE),
	]
	var groups := BuildMenuModel.group_modules(modules)
	assert_eq((groups[ModuleData.UICategory.POWER] as Array).size(), 2, "both power modules bucket together")
	assert_eq((groups[ModuleData.UICategory.STORAGE] as Array).size(), 1, "storage has its one module")
	assert_false(groups.has(ModuleData.UICategory.INDUSTRY), "no bucket for an absent category")

func test_group_skips_hidden() -> void:
	var modules: Array[ModuleData] = [
		_mod("Battery", ModuleData.UICategory.POWER, true),
		_mod("Solar Panel", ModuleData.UICategory.POWER),
	]
	var groups := BuildMenuModel.group_modules(modules)
	assert_eq((groups[ModuleData.UICategory.POWER] as Array).size(), 1, "the hidden battery drops out")

func test_group_sorts_bucket_by_name() -> void:
	var modules: Array[ModuleData] = [
		_mod("Zeta", ModuleData.UICategory.CREW),
		_mod("Alpha", ModuleData.UICategory.CREW),
		_mod("Mu", ModuleData.UICategory.CREW),
	]
	var bucket := BuildMenuModel.group_modules(modules)[ModuleData.UICategory.CREW] as Array
	assert_eq((bucket[0] as ModuleData).name, "Alpha", "first is alphabetically lowest")
	assert_eq((bucket[2] as ModuleData).name, "Zeta", "last is alphabetically highest")

func test_group_other_category_buckets() -> void:
	var modules: Array[ModuleData] = [_mod("Mystery", ModuleData.UICategory.OTHER)]
	var groups := BuildMenuModel.group_modules(modules)
	assert_true(groups.has(ModuleData.UICategory.OTHER), "the default OTHER category buckets like any other")

# --- category_order ----------------------------------------------------------

func test_category_order_follows_enum_sequence() -> void:
	var ordered := BuildMenuModel.category_order([
		ModuleData.UICategory.STORAGE, ModuleData.UICategory.CORE, ModuleData.UICategory.POWER,
	] as Array[int])
	assert_eq(ordered, [
		ModuleData.UICategory.CORE, ModuleData.UICategory.POWER, ModuleData.UICategory.STORAGE,
	] as Array[int], "categories follow enum declaration order, not input order")

func test_category_order_puts_other_last() -> void:
	var ordered := BuildMenuModel.category_order([
		ModuleData.UICategory.OTHER, ModuleData.UICategory.LOGISTICS, ModuleData.UICategory.CORE,
	] as Array[int])
	assert_eq(ordered[ordered.size() - 1], ModuleData.UICategory.OTHER, "OTHER (the enum max) always sorts last")

func test_category_order_dedupes() -> void:
	var ordered := BuildMenuModel.category_order([
		ModuleData.UICategory.CORE, ModuleData.UICategory.CORE, ModuleData.UICategory.POWER,
	] as Array[int])
	assert_eq(ordered.size(), 2, "duplicate categories collapse to one rail entry")

# --- category_name -----------------------------------------------------------

func test_category_name_maps_enum_to_label() -> void:
	assert_eq(BuildMenuModel.category_name(ModuleData.UICategory.LIFE_SUPPORT), "Life Support", "multi-word label")
	assert_eq(BuildMenuModel.category_name(ModuleData.UICategory.CORE), "Core", "single-word label")

# --- filter_by_name ----------------------------------------------------------

func test_filter_matches_case_insensitively() -> void:
	var modules: Array[ModuleData] = [
		_mod("Ore Processor", ModuleData.UICategory.INDUSTRY),
		_mod("Ice Processor", ModuleData.UICategory.INDUSTRY),
		_mod("Solar Panel", ModuleData.UICategory.POWER),
	]
	var hits := BuildMenuModel.filter_by_name(modules, "pRoCeSs")
	assert_eq(hits.size(), 2, "case-insensitive substring matches both processors")

func test_filter_empty_query_returns_nothing() -> void:
	var modules: Array[ModuleData] = [_mod("Solar Panel", ModuleData.UICategory.POWER)]
	assert_eq(BuildMenuModel.filter_by_name(modules, "   ").size(), 0, "a whitespace query returns nothing (flyout closes)")

func test_filter_no_match_returns_empty() -> void:
	var modules: Array[ModuleData] = [_mod("Solar Panel", ModuleData.UICategory.POWER)]
	assert_eq(BuildMenuModel.filter_by_name(modules, "turbolift").size(), 0, "no match is empty")

func test_filter_skips_hidden() -> void:
	var modules: Array[ModuleData] = [_mod("Debug Panel", ModuleData.UICategory.POWER, true)]
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
