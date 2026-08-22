extends GutTest

## Unit tests for WI-52's ledger rules (LedgerModel): which resources appear in
## which column, what a saved pin list resolves to, and how a rate prints.
##
## The category pass over the real `.tres` files is asserted here too, because
## "every resource lands in exactly one column" is a claim about the data, not
## just about the grouping function - a new resource that forgets its category
## should fail a test rather than quietly appear under GOODS.

const RESOURCE_DIR: String = "res://data/resources/"

func _resource(id: StringName, resource_name: String,
		category: ResourceData.Category = ResourceData.Category.GOODS,
		visible: bool = true) -> ResourceData:
	var resource := ResourceData.new()
	resource.id = id
	resource.name = resource_name
	resource.ledger_category = category
	resource.show_in_ledger = visible
	return resource

## Every ResourceData the base game ships, loaded straight off disk.
func _real_resources() -> Array[ResourceData]:
	var out: Array[ResourceData] = []
	for file: String in DirAccess.get_files_at(RESOURCE_DIR):
		if not file.ends_with(".tres"):
			continue
		var resource: ResourceData = ResourceLoader.load(RESOURCE_DIR + file) as ResourceData
		if resource != null:
			out.append(resource)
	return out

## The subset of the above the ledger would actually list. Written out rather
## than via Array.filter so the element type stays Array[ResourceData].
func _listed_resources() -> Array[ResourceData]:
	var out: Array[ResourceData] = []
	for resource: ResourceData in _real_resources():
		if LedgerModel.in_ledger(resource):
			out.append(resource)
	return out

func _ids_in(resources: Array[ResourceData]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for resource: ResourceData in resources:
		ids.append(resource.id)
	return ids

# --- grouping ----------------------------------------------------------------

func test_every_category_column_is_empty_for_an_empty_station() -> void:
	for category: ResourceData.Category in LedgerModel.CATEGORY_ORDER:
		assert_eq(LedgerModel.in_category([] as Array[ResourceData], category).size(), 0,
			"column %d is empty rather than missing" % category)

func test_a_resource_lands_in_its_declared_column() -> void:
	var only: Array[ResourceData] = [_resource(&"ore", "Ore", ResourceData.Category.BASIC)]
	assert_eq(LedgerModel.in_category(only, ResourceData.Category.BASIC).size(), 1, "in BASIC")
	assert_eq(LedgerModel.in_category(only, ResourceData.Category.REFINED).size(), 0,
		"and nowhere else")

func test_an_unset_category_defaults_to_goods_rather_than_vanishing() -> void:
	var plain := ResourceData.new()
	plain.id = &"plain"
	plain.name = "Plain"
	assert_eq(LedgerModel.category_of(plain), ResourceData.Category.GOODS,
		"an unset category is GOODS, not a dropped row")
	assert_eq(LedgerModel.in_category([plain] as Array[ResourceData],
		ResourceData.Category.GOODS).size(), 1, "and it does appear there")

func test_columns_are_sorted_by_display_name() -> void:
	var column := LedgerModel.in_category([
		_resource(&"c", "Carbon", ResourceData.Category.REFINED),
		_resource(&"a", "Aluminium", ResourceData.Category.REFINED),
		_resource(&"b", "Beryllium", ResourceData.Category.REFINED),
	] as Array[ResourceData], ResourceData.Category.REFINED)
	var names: Array[String] = []
	for resource: ResourceData in column:
		names.append(resource.name)
	assert_eq(names, ["Aluminium", "Beryllium", "Carbon"], "sorted by name")

func test_hidden_resources_are_excluded() -> void:
	var column := LedgerModel.in_category([
		_resource(&"real", "Real"),
		_resource(&"fixture", "Fixture", ResourceData.Category.GOODS, false),
	] as Array[ResourceData], ResourceData.Category.GOODS)
	assert_eq(column.size(), 1, "only the visible one")
	assert_eq(column[0].id, &"real", "and it is the right one")

func test_a_resource_with_no_id_is_excluded() -> void:
	var anonymous := ResourceData.new()
	anonymous.name = "No Id"
	assert_false(LedgerModel.in_ledger(anonymous),
		"an id-less resource cannot be pinned or saved, so it cannot be listed")

# --- the real data pass ------------------------------------------------------

func test_the_two_non_player_facing_resources_are_excluded() -> void:
	var listed: Array[StringName] = _ids_in(_listed_resources())
	assert_false(listed.has(&"test_resource"), "the test fixture never reaches a player-facing list")
	assert_false(listed.has(&"stored_energy"), "nor does the battery accounting unit")

func test_every_real_resource_lands_in_exactly_one_column() -> void:
	var all: Array[ResourceData] = _real_resources()
	var placed: int = 0
	var seen: Array[StringName] = []
	for category: ResourceData.Category in LedgerModel.CATEGORY_ORDER:
		for resource: ResourceData in LedgerModel.in_category(all, category):
			assert_false(seen.has(resource.id), "'%s' appears once" % resource.id)
			seen.append(resource.id)
			placed += 1
	var expected: int = _listed_resources().size()
	assert_eq(placed, expected, "every ledger-visible resource is in a column")
	assert_eq(expected, 17, "the base game ships 17 player-facing resources")

func test_the_basic_and_goods_columns_are_authored() -> void:
	var all: Array[ResourceData] = _real_resources()
	# Carbon sits here rather than under REFINED because nothing refines it - it
	# comes out of a rock as itself, which is the whole point of the column.
	assert_eq(_ids_in(LedgerModel.in_category(all, ResourceData.Category.BASIC)),
		[&"carbon", &"gold_ore", &"iridium_ore", &"iron_ore", &"silicon_ore"] as Array[StringName],
		"the four mined ores plus carbon, by display name")
	assert_eq(_ids_in(LedgerModel.in_category(all, ResourceData.Category.GOODS)),
		[&"credits"] as Array[StringName],
		"credits is the only good, and it takes the GOODS default")

func test_every_column_has_a_label_and_the_first_one_is_not_about_ore() -> void:
	for category: ResourceData.Category in LedgerModel.CATEGORY_ORDER:
		assert_false(LedgerModel.category_label(category).is_empty(),
			"column %d prints a header" % category)
	assert_eq(LedgerModel.category_label(ResourceData.Category.BASIC), "Basic",
		"the column stopped being called Raw Ore when carbon joined it")

func test_the_default_pins_all_resolve_against_the_real_data() -> void:
	# The strip's designed six must actually exist, or a new game boots with a
	# short strip that silently refills from whatever is left.
	var known: Array[StringName] = _ids_in(_listed_resources())
	for id: StringName in LedgerModel.DEFAULT_PINS:
		assert_true(LedgerModel.can_pin(id, known), "default pin '%s' resolves" % id)

# --- pins --------------------------------------------------------------------

const KNOWN: Array[StringName] = [&"credits", &"steel", &"biomass", &"iron", &"iron_ore"]

func test_an_empty_save_resolves_to_the_default_six() -> void:
	var pins := LedgerModel.resolve_pins([], KNOWN)
	assert_eq(pins, LedgerModel.DEFAULT_PINS, "absent key = the designed default, in order")

func test_an_empty_list_and_an_absent_key_are_the_same_thing() -> void:
	assert_eq(LedgerModel.resolve_pins([], KNOWN), LedgerModel.DEFAULT_PINS,
		"an unpinned-to-nothing strip has no expressed intent to preserve")

func test_a_saved_list_keeps_its_order() -> void:
	var pins := LedgerModel.resolve_pins(
		["steel", "credits", "iron", LedgerModel.DERIVED_CREW, "biomass", "iron_ore"], KNOWN)
	assert_eq(pins, [&"steel", &"credits", &"iron", LedgerModel.DERIVED_CREW, &"biomass",
		&"iron_ore"] as Array[StringName], "order is part of what the player chose")

func test_a_deliberately_short_strip_is_restored_as_it_was() -> void:
	# The player unpinned two chips and saved. Refilling to the cap here would
	# quietly undo that, which is what makes the refill target the saved length
	# rather than PIN_CAP.
	var pins := LedgerModel.resolve_pins(["steel", "iron", "credits"], KNOWN)
	assert_eq(pins, [&"steel", &"iron", &"credits"] as Array[StringName],
		"three saved pins restore as three")

func test_an_unresolvable_id_is_dropped_and_the_gap_is_refilled() -> void:
	var pins := LedgerModel.resolve_pins(["steel", "amod.unobtainium", "iron"], KNOWN)
	assert_false(pins.has(&"amod.unobtainium"), "the removed mod's resource is dropped")
	assert_eq(pins.size(), 3, "and the gap is refilled to the count the save asked for")
	assert_eq(pins[0], &"steel", "the surviving pins keep their positions")
	assert_eq(pins[1], &"iron", "including the one that followed the dropped id")

func test_duplicates_are_dropped_and_the_gap_refilled() -> void:
	var pins := LedgerModel.resolve_pins(["steel", "steel", "iron"], KNOWN)
	assert_eq(pins.count(&"steel"), 1, "a duplicated pin is one chip, not two")
	assert_eq(pins.size(), 3, "and the freed slot refills like any other gap")

func test_the_list_is_capped() -> void:
	var pins := LedgerModel.resolve_pins(
		["credits", "steel", "biomass", "iron", "iron_ore",
		LedgerModel.DERIVED_ENERGY, LedgerModel.DERIVED_OXYGEN, LedgerModel.DERIVED_CREW], KNOWN)
	assert_eq(pins.size(), LedgerModel.PIN_CAP, "a save that grew past the cap is trimmed")
	assert_eq(pins[0], &"credits", "trimmed from the end, so the first six survive")

func test_derived_ids_are_pinnable_without_being_resources() -> void:
	for id: StringName in LedgerModel.DERIVED_IDS:
		assert_true(LedgerModel.is_derived(id), "'%s' is a derived id" % id)
		assert_true(LedgerModel.can_pin(id, [] as Array[StringName]),
			"'%s' pins with no resources at all" % id)

func test_an_unknown_derived_id_is_not_pinnable() -> void:
	assert_false(LedgerModel.can_pin(&"derived:morale", [] as Array[StringName]),
		"the derived namespace is a closed list, not a free-for-all")

func test_the_derived_namespace_cannot_collide_with_a_resource_id() -> void:
	# A mod's resource id must begin with its own `modid.` prefix, and base-game
	# ids are hand-authored - so nothing can legitimately be named `derived:...`.
	for resource: ResourceData in _real_resources():
		assert_false(LedgerModel.is_derived(resource.id),
			"'%s' does not sit in the derived namespace" % resource.id)

# --- formatting --------------------------------------------------------------

func test_no_data_prints_a_dash_not_a_zero() -> void:
	assert_eq(LedgerModel.format_per_cycle(ResourceRateTracker.NO_RATE), "—",
		"'no measurement yet' and 'not moving' are different claims")

func test_a_rate_carries_its_sign() -> void:
	assert_eq(LedgerModel.format_per_cycle(2.14), "+2.1", "rising")
	assert_eq(LedgerModel.format_per_cycle(-2.14), "-2.1", "falling")

func test_a_rate_that_rounds_to_zero_prints_without_a_sign() -> void:
	assert_eq(LedgerModel.format_per_cycle(0.0), "0.0", "flat")
	assert_eq(LedgerModel.format_per_cycle(0.01), "0.0", "and so does a rate that rounds to flat")

func test_rate_colours() -> void:
	assert_eq(LedgerModel.rate_color(5.0), UIPalette.LIVE, "rising is cyan")
	assert_eq(LedgerModel.rate_color(-5.0), UIPalette.ATTENTION, "falling is amber")
	assert_eq(LedgerModel.rate_color(0.0), UIPalette.TEXT_META, "flat is meta grey")
	assert_eq(LedgerModel.rate_color(ResourceRateTracker.NO_RATE), UIPalette.TEXT_META,
		"and a dash must never read as a fall")

func test_compact_amounts_stay_inside_a_fixed_chip() -> void:
	assert_eq(LedgerModel.format_compact(0), "0", "small numbers are printed as they are")
	assert_eq(LedgerModel.format_compact(9999), "9999", "up to four digits")
	assert_eq(LedgerModel.format_compact(12400), "12.4K", "then thousands")
	assert_eq(LedgerModel.format_compact(2500000), "2.5M", "then millions")
	assert_eq(LedgerModel.format_compact(-12400), "-12.4K", "negatives compact too (debt)")
