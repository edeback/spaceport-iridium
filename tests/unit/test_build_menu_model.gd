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

# --- sort_bucket (WI-54) --------------------------------------------------------
# Locked modules render in the list now (dimmed, with their gating tech) instead
# of being hidden, so the bucket needs an order that keeps the things the player
# can build today at the top without dropping the rest.

## Locks by name, so a test can state its expectation in one readable predicate.
func _locks(names: Array) -> Callable:
	return func(module_data: ModuleData) -> bool:
		return names.has(module_data.name)

func test_sort_bucket_puts_locked_entries_after_unlocked() -> void:
	var modules: Array[ModuleData] = [
		_mod("Assayer", &"mining"),
		_mod("Deep Bore", &"mining"),
		_mod("Ore Silo", &"mining"),
	]
	var sorted := BuildMenuModel.sort_bucket(modules, _locks(["Deep Bore"]))
	assert_eq(sorted[0].name, "Assayer", "buildable modules come first, alphabetically")
	assert_eq(sorted[1].name, "Ore Silo")
	assert_eq(sorted[2].name, "Deep Bore", "the locked one sinks to the bottom")

func test_sort_bucket_never_drops_a_locked_entry() -> void:
	var modules: Array[ModuleData] = [
		_mod("Deep Bore", &"mining"),
		_mod("Fusion Lance", &"mining"),
	]
	var sorted := BuildMenuModel.sort_bucket(modules, _locks(["Deep Bore", "Fusion Lance"]))
	assert_eq(sorted.size(), 2, "an all-locked category still renders both entries")

func test_sort_bucket_orders_locked_entries_among_themselves_by_name() -> void:
	var modules: Array[ModuleData] = [
		_mod("Zeta Bore", &"mining"),
		_mod("Alpha Bore", &"mining"),
	]
	var sorted := BuildMenuModel.sort_bucket(modules, _locks(["Zeta Bore", "Alpha Bore"]))
	assert_eq(sorted[0].name, "Alpha Bore", "the locked half is alphabetical too")

func test_sort_bucket_with_no_predicate_is_a_plain_name_sort() -> void:
	var modules: Array[ModuleData] = [_mod("Zeta", &"mining"), _mod("Alpha", &"mining")]
	var sorted := BuildMenuModel.sort_bucket(modules)
	assert_eq(sorted[0].name, "Alpha", "nothing is locked when nothing says so")

func test_sort_bucket_does_not_mutate_input() -> void:
	var modules: Array[ModuleData] = [_mod("Zeta", &"mining"), _mod("Alpha", &"mining")]
	BuildMenuModel.sort_bucket(modules)
	assert_eq(modules[0].name, "Zeta", "the caller's array is untouched")

# --- gating unlock resolution (WI-54) --------------------------------------------
# A locked row prints the tech that grants it. The edge lives on the unlock (a
# GrantModuleEffect naming the module), so this walks the tree rather than
# reading a back-reference that would be a second source of truth.

func _grant(unlock_name: String, module: ModuleData, id: String = "") -> UnlockData:
	var unlock := UnlockData.new()
	unlock.name = unlock_name
	unlock.id = StringName(id if id != "" else unlock_name)
	var effect := GrantModuleEffect.new()
	effect.module = module
	unlock.effects = [effect] as Array[UnlockEffect]
	return unlock

func test_gating_unlock_finds_the_node_that_grants_the_module() -> void:
	var bore := _mod("Deep Bore", &"mining")
	var silo := _mod("Ore Silo", &"mining")
	var unlocks: Array[UnlockData] = [_grant("Drilling I", silo), _grant("Drilling II", bore)]
	assert_eq(BuildMenuModel.gating_unlock(bore, unlocks).name, "Drilling II")

func test_gating_label_reads_the_unlock_display_name() -> void:
	var bore := _mod("Deep Bore", &"mining")
	assert_eq(BuildMenuModel.gating_label(bore, [_grant("Drilling II", bore)] as Array[UnlockData]),
			"Needs: Drilling II")

func test_gating_label_falls_back_to_the_unlock_id() -> void:
	var bore := _mod("Deep Bore", &"mining")
	var unlock := _grant("", bore, "drilling_ii")
	assert_eq(BuildMenuModel.gating_label(bore, [unlock] as Array[UnlockData]),
			"Needs: drilling_ii", "an unnamed node still identifies itself")

func test_gating_label_for_a_module_nothing_grants() -> void:
	var orphan := _mod("Orphan Bay", &"mining")
	var unlocks: Array[UnlockData] = [_grant("Drilling II", _mod("Deep Bore", &"mining"))]
	assert_eq(BuildMenuModel.gating_label(orphan, unlocks), BuildMenuModel.NO_GATE_LABEL,
			"a module no node reaches says so rather than printing a blank gate")

func test_gating_unlock_skips_effects_that_are_not_grants() -> void:
	var bore := _mod("Deep Bore", &"mining")
	var unrelated := UnlockData.new()
	unrelated.name = "Efficiency I"
	unrelated.effects = [StatModifierEffect.new()] as Array[UnlockEffect]
	var unlocks: Array[UnlockData] = [unrelated, _grant("Drilling II", bore)]
	assert_eq(BuildMenuModel.gating_unlock(bore, unlocks).name, "Drilling II",
			"a stat-modifier node is not a gate")

func test_gating_unlock_tolerates_nulls_in_authored_data() -> void:
	var bore := _mod("Deep Bore", &"mining")
	var holey := UnlockData.new()
	holey.name = "Holey"
	holey.effects = [null] as Array[UnlockEffect]
	var unlocks: Array[UnlockData] = [null, holey, _grant("Drilling II", bore)]
	assert_eq(BuildMenuModel.gating_unlock(bore, unlocks).name, "Drilling II")

func test_gating_unlock_of_null_is_null() -> void:
	assert_null(BuildMenuModel.gating_unlock(null, [] as Array[UnlockData]))

# --- row text (WI-54) -------------------------------------------------------------

func test_format_footprint() -> void:
	assert_eq(BuildMenuModel.format_footprint(Vector2i(2, 2)), "2×2")
	assert_eq(BuildMenuModel.format_footprint(Vector2i(3, 1)), "3×1")

func test_format_footprint_floors_at_one_cell() -> void:
	assert_eq(BuildMenuModel.format_footprint(Vector2i.ZERO), "1×1",
			"a scene that declares no size still occupies a cell")

func _res(res_name: String) -> ResourceData:
	var resource := ResourceData.new()
	resource.name = res_name
	resource.id = StringName(res_name.to_lower())
	return resource

func test_format_cost_leads_with_the_largest_amount() -> void:
	var costs: Dictionary[ResourceData, int] = {}
	costs[_res("Silicon")] = 4
	costs[_res("Steel")] = 12
	assert_eq(BuildMenuModel.format_cost(costs), "12 STEEL · 4 SILICON")

func test_format_cost_breaks_ties_by_name() -> void:
	# Dictionary iteration order must never decide what the player reads.
	var costs: Dictionary[ResourceData, int] = {}
	costs[_res("Steel")] = 5
	costs[_res("Gold")] = 5
	assert_eq(BuildMenuModel.format_cost(costs), "5 GOLD · 5 STEEL")

func test_format_cost_of_a_free_module_is_empty() -> void:
	assert_eq(BuildMenuModel.format_cost({} as Dictionary[ResourceData, int]), "")

func test_format_cost_skips_zero_entries() -> void:
	var costs: Dictionary[ResourceData, int] = {}
	costs[_res("Steel")] = 0
	assert_eq(BuildMenuModel.format_cost(costs), "", "an authored zero is not a cost")

# --- the facts line ---------------------------------------------------------------

func test_format_facts_signs_output_and_draw() -> void:
	var parts := BuildMenuModel.format_facts(14.0, 0.0, 0, 0)
	assert_eq(parts, ["−14 ENERGY"] as Array[String], "a consumer reads as a cost")
	parts = BuildMenuModel.format_facts(0.0, 120.0, 0, 0)
	assert_eq(parts, ["+120 ENERGY"] as Array[String], "a generator reads as a gain")

func test_format_facts_orders_output_before_draw() -> void:
	var parts := BuildMenuModel.format_facts(14.0, 120.0, 0, 0)
	assert_eq(parts[0], "+120 ENERGY", "the same fact always sits in the same place")
	assert_eq(parts[1], "−14 ENERGY")

func test_format_facts_includes_capacity_and_crew() -> void:
	var parts := BuildMenuModel.format_facts(0.0, 0.0, 40, 2)
	assert_eq(parts, ["40 STORAGE", "2 CREW"] as Array[String])

func test_format_facts_omits_what_a_module_does_not_declare() -> void:
	assert_eq(BuildMenuModel.format_facts(0.0, 0.0, 0, 0).size(), 0,
			"a corridor has nothing to say, and an empty line beats a fabricated zero")

func test_format_facts_trims_whole_numbers() -> void:
	assert_eq(BuildMenuModel.format_facts(0.0, 100.0, 0, 0)[0], "+100 ENERGY")
	assert_eq(BuildMenuModel.format_facts(2.5, 0.0, 0, 0)[0], "−2.5 ENERGY",
			"a fractional draw keeps its decimal")

## Amber is a budget (invariant 5), so "which half of the line is amber" is one
## rule rather than a `begins_with` test copied into each panel.
func test_only_the_costs_are_flagged_amber() -> void:
	assert_true(BuildMenuModel.fact_is_a_cost("−14 ENERGY"))
	assert_false(BuildMenuModel.fact_is_a_cost("+120 ENERGY"))
	assert_false(BuildMenuModel.fact_is_a_cost("40 STORAGE"))

## The minus is U+2212, not a hyphen: it is the same width as the plus above it,
## so two stacked facts line up. A hyphen creeping back in is invisible in a
## diff and obvious on screen.
func test_the_cost_sign_is_a_real_minus() -> void:
	assert_eq(BuildMenuModel.format_facts(14.0, 0.0, 0, 0)[0].substr(0, 1), "−")
