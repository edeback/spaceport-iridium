extends GutTest

## Unit tests for WI-56's [StoresModel]: the ordering, the membership rule and
## the priority vocabulary behind the Stores panel.
##
## The ordering is the part that must not regress. A station-wide panel is only
## useful if the same station produces the same list twice, and Godot's
## `sort_custom` is free to do anything at all with a comparator that is not a
## total order - including crash - so antisymmetry is asserted exhaustively rather
## than spot-checked.
##
## The priority vocabulary is tested because it is the panel's whole reason for
## existing: storage priority is the routing language of the hauling system, and
## `−100 REFUSE … +100 URGENT` is the first time the game says so out loud.

func _entry(title: String, priority: int, stored: int, capacity: int = 100) -> StoresModel.Entry:
	var entry := StoresModel.Entry.new()
	entry.title = title
	entry.priority = priority
	entry.stored = stored
	entry.capacity = capacity
	entry.contents_configurable = true
	return entry

func _titles(entries: Array) -> Array[String]:
	var out: Array[String] = []
	for item: Variant in entries:
		out.append((item as StoresModel.Entry).title)
	return out

# --- fill --------------------------------------------------------------------------

func test_fill_is_stored_over_capacity() -> void:
	assert_almost_eq(_entry("Bin", 0, 25, 100).fill(), 0.25, 0.001)

func test_a_zero_capacity_bin_reads_as_full_not_empty() -> void:
	# There is no room in it, which is what the meter is asking about.
	assert_almost_eq(_entry("Bin", 0, 0, 0).fill(), 1.0, 0.001)

func test_fill_never_overruns() -> void:
	assert_almost_eq(_entry("Bin", 0, 500, 100).fill(), 1.0, 0.001)

func test_is_empty_is_about_stock_not_about_capacity() -> void:
	assert_true(_entry("Bin", 80, 0).is_empty(),
		"a store set to +80 and empty is exactly the interesting case")
	assert_false(_entry("Bin", 0, 1).is_empty())

# --- sorting -------------------------------------------------------------------------

func test_priority_sorts_highest_first() -> void:
	var sorted: Array = StoresModel.sort_entries([
		_entry("Low", -40, 10), _entry("High", 90, 10), _entry("Mid", 0, 10),
	], StoresModel.Sort.PRIORITY)
	assert_eq(_titles(sorted), ["High", "Mid", "Low"] as Array[String],
		"the bins pulling stock hardest are what the player came here to find")

func test_fill_sorts_fullest_first() -> void:
	var sorted: Array = StoresModel.sort_entries([
		_entry("Half", 0, 50), _entry("Full", 0, 100), _entry("Empty", 0, 0),
	], StoresModel.Sort.FILL)
	assert_eq(_titles(sorted), ["Full", "Half", "Empty"] as Array[String])

func test_name_sorts_alphabetically_and_ignores_the_rest() -> void:
	var sorted: Array = StoresModel.sort_entries([
		_entry("Zulu", 99, 100), _entry("Alpha", -99, 0),
	], StoresModel.Sort.NAME)
	assert_eq(_titles(sorted), ["Alpha", "Zulu"] as Array[String])

func test_every_sort_breaks_ties_on_the_title() -> void:
	for sort: StoresModel.Sort in [StoresModel.Sort.PRIORITY, StoresModel.Sort.NAME,
			StoresModel.Sort.FILL]:
		var sorted: Array = StoresModel.sort_entries([
			_entry("Beta", 10, 30), _entry("Alpha", 10, 30),
		], sort)
		assert_eq(_titles(sorted), ["Alpha", "Beta"] as Array[String],
			"sort %d must not leave two identical bins swapping places" % sort)

func test_sorting_does_not_mutate_the_input() -> void:
	var entries: Array = [_entry("Low", -40, 10), _entry("High", 90, 10)]
	StoresModel.sort_entries(entries, StoresModel.Sort.PRIORITY)
	assert_eq(_titles(entries), ["Low", "High"] as Array[String],
		"the panel re-sorts the same array on every refresh")

## A comparator that says "before" in both directions produces a non-total order,
## and `sort_custom` may then do anything with it.
func test_the_comparator_is_antisymmetric_in_every_order() -> void:
	var entries: Array = [
		_entry("Alpha", 99, 100), _entry("Beta", 0, 50), _entry("Gamma", 0, 50),
		_entry("Delta", -99, 0),
	]
	for sort: StoresModel.Sort in [StoresModel.Sort.PRIORITY, StoresModel.Sort.NAME,
			StoresModel.Sort.FILL]:
		for a: Variant in entries:
			for b: Variant in entries:
				var first: StoresModel.Entry = a as StoresModel.Entry
				var second: StoresModel.Entry = b as StoresModel.Entry
				var forward: bool = StoresModel.compares_before(first, second, sort)
				var backward: bool = StoresModel.compares_before(second, first, sort)
				if first == second:
					assert_false(forward, "no bin precedes itself")
				else:
					assert_ne(forward, backward,
						"sort %d must order %s and %s exactly one way"
							% [sort, first.title, second.title])

func test_a_null_entry_never_crashes_the_comparator() -> void:
	var entry: StoresModel.Entry = _entry("Bin", 0, 0)
	assert_true(StoresModel.compares_before(entry, null, StoresModel.Sort.PRIORITY),
		"a bin outranks a hole")
	assert_false(StoresModel.compares_before(null, entry, StoresModel.Sort.PRIORITY))
	assert_false(StoresModel.compares_before(null, null, StoresModel.Sort.PRIORITY))

# --- the count under the header ---------------------------------------------------------

func test_modules_holding_stock_counts_modules_not_bins() -> void:
	# A refinery with a stocked input bay and a stocked output bay is one module.
	var module: ModuleBase = autofree(ModuleBase.new())
	var input: StoresModel.Entry = _entry("Refinery · Input", 0, 40)
	input.component = _component(module)
	var output: StoresModel.Entry = _entry("Refinery · Output", 0, 12)
	output.component = _component(module)
	assert_eq(StoresModel.modules_holding_stock([input, output]), 1)

func test_empty_bins_are_listed_but_not_counted_as_holding_stock() -> void:
	var stocked: StoresModel.Entry = _entry("Storeroom", 0, 40)
	stocked.component = _component(autofree(ModuleBase.new()))
	var empty: StoresModel.Entry = _entry("Silo", 80, 0)
	empty.component = _component(autofree(ModuleBase.new()))
	var entries: Array = [stocked, empty]
	assert_eq(StoresModel.modules_holding_stock(entries), 1)
	assert_string_contains(StoresModel.subtitle_text(entries), "1 holding stock")
	assert_string_contains(StoresModel.subtitle_text(entries), "2 bins")

func _component(module: ModuleBase) -> StorageComponent:
	var component: StorageComponent = autofree(StorageComponent.new())
	component.owner_module = module
	return component

## A bare resource to hang a slot off. include_in_stats is switched off on the
## components that use these so add_stored_resource() does not register them into
## a ResourceData that outlives the test.
func _resource(id: StringName) -> ResourceData:
	var resource := ResourceData.new()
	resource.id = id
	resource.name = String(id)
	return resource

# --- membership --------------------------------------------------------------------------

func test_a_preview_module_is_not_listed() -> void:
	var module: ModuleBase = autofree(ModuleBase.new())
	module.build_state = ModuleBase.BuildState.Preview
	assert_false(StoresModel.lists(_component(module)),
		"a ghost following the cursor is not station storage")

func test_a_blueprint_is_listed() -> void:
	# A construction site's import bin is not editable, but "why is nothing being
	# delivered to my blueprint" is precisely a question this panel answers.
	var module: ModuleBase = autofree(ModuleBase.new())
	module.build_state = ModuleBase.BuildState.Blueprint
	assert_true(StoresModel.lists(_component(module)))

func test_a_built_module_is_listed() -> void:
	var module: ModuleBase = autofree(ModuleBase.new())
	module.build_state = ModuleBase.BuildState.Built
	assert_true(StoresModel.lists(_component(module)))

## `ready_constructed` drops a construction bin out of the storage group, stops
## its posting scan and hides its UI - it is dead. There is one on every corridor
## and airlock, and listing them put six inert `+100` cards at the top of the
## first station's list.
func test_a_construction_bin_on_a_finished_module_is_not_listed() -> void:
	var module: ModuleBase = autofree(ModuleBase.new())
	module.build_state = ModuleBase.BuildState.Built
	var component: StorageComponent = _component(module)
	component.construction_storage = true
	assert_false(StoresModel.lists(component))

func test_a_construction_bin_on_a_blueprint_is_still_listed() -> void:
	# That one is a live construction site, which is exactly the case the WI keeps.
	var module: ModuleBase = autofree(ModuleBase.new())
	module.build_state = ModuleBase.BuildState.Blueprint
	var component: StorageComponent = _component(module)
	component.construction_storage = true
	assert_true(StoresModel.lists(component))

func test_a_component_with_no_module_is_not_listed() -> void:
	assert_false(StoresModel.lists(autofree(StorageComponent.new())))
	assert_false(StoresModel.lists(null))

# --- editability (WI-58) --------------------------------------------------------------------

## `player_configurable` gates the bin's **contents** and nothing else: what it
## accepts, how much of each it wants, and whether the player may dump it. The
## Stores card, the inspector's storage tab and the dump dialog all read this;
## three surfaces used to answer it three ways for the same field.
func test_a_player_configurable_bin_has_editable_contents() -> void:
	var module: ModuleBase = autofree(ModuleBase.new())
	module.build_state = ModuleBase.BuildState.Built
	var component: StorageComponent = _component(module)
	component.player_configurable = true
	assert_true(StoresModel.contents_editable(component),
		"a multipurpose bin holds what the player says")

func test_a_module_owned_bin_does_not() -> void:
	var module: ModuleBase = autofree(ModuleBase.new())
	module.build_state = ModuleBase.BuildState.Built
	var component: StorageComponent = _component(module)
	component.player_configurable = false
	assert_false(StoresModel.contents_editable(component),
		"a forge always takes iron and carbon and always emits steel")

## The asymmetry, and the point of having two functions: priority is the routing
## language of the whole hauling system, so it is the player's on every bin that
## takes deliveries, including the ones whose contents the module owns.
func test_priority_is_editable_whatever_the_contents_rule_says() -> void:
	var module: ModuleBase = autofree(ModuleBase.new())
	module.build_state = ModuleBase.BuildState.Built
	var component: StorageComponent = _component(module)
	for configurable: bool in [true, false]:
		component.player_configurable = configurable
		assert_true(StoresModel.priority_editable(component),
			"priority stays the player's with player_configurable = %s" % configurable)

## Even on a live construction site, whose contents are the build's.
func test_priority_is_editable_on_a_construction_site() -> void:
	var module: ModuleBase = autofree(ModuleBase.new())
	module.build_state = ModuleBase.BuildState.Blueprint
	var component: StorageComponent = _component(module)
	component.construction_storage = true
	assert_true(StoresModel.priority_editable(component),
		"a blueprint's import bin can still be out-bid or prioritised")

## The case with teeth: `lists()` deliberately keeps a live construction site, and
## the chip dialog used to let the player rewrite its build requirements and vent
## the materials already delivered to it.
func test_a_live_construction_bin_is_listed_but_its_contents_are_not_editable() -> void:
	var module: ModuleBase = autofree(ModuleBase.new())
	module.build_state = ModuleBase.BuildState.Blueprint
	var component: StorageComponent = _component(module)
	component.construction_storage = true
	assert_true(StoresModel.lists(component), "still listed - it answers a real question")
	assert_false(StoresModel.contents_editable(component),
		"but the build decides what it imports, and nothing may vent it")

func test_a_missing_component_is_editable_in_neither_sense() -> void:
	assert_false(StoresModel.contents_editable(null), "null holds nothing")
	assert_false(StoresModel.priority_editable(null), "and routes nothing")

# --- the one exception to "priority is always the player's" (WI-65) --------------

## An export-only bin has no priority of its own: OUTPUT resolves to the floor
## whatever the component's number says, so a stepper there would be a control
## that does nothing. Before WI-65 this case could not arise, because a module's
## export side was a separate component with its own settable number.
func test_an_export_only_bin_has_no_priority_to_set() -> void:
	var module: ModuleBase = autofree(ModuleBase.new())
	module.build_state = ModuleBase.BuildState.Built
	var component: StorageComponent = _component(module)
	component.include_in_stats = false
	component.default_role = StorageData.Role.OUTPUT
	component.add_stored_resource(_resource(&"iron_ore"), StorageData.Role.OUTPUT)
	assert_false(StoresModel.priority_editable(component),
		"a mining bay always pushes its ore out and cannot be told otherwise")
	assert_ne(StoresModel.priority_locked_reason(component), "",
		"and the card says so where the stepper used to be")

## The bug this rule nearly shipped with: an EMPTY bin has no slots either, and
## "no intake slots" must not be read as "export only". A fresh storeroom holds
## nothing until the player puts something in it.
func test_an_empty_storeroom_keeps_its_stepper() -> void:
	var module: ModuleBase = autofree(ModuleBase.new())
	module.build_state = ModuleBase.BuildState.Built
	var component: StorageComponent = _component(module)
	assert_true(component.storage_data.is_empty(), "fixture precondition")
	assert_true(StoresModel.priority_editable(component),
		"an empty storeroom is not an export-only bin")
	assert_eq(StoresModel.priority_locked_reason(component), "",
		"and has nothing to explain")

## A bin holding both roles - a refinery - is priced by its intake side.
func test_a_two_role_bin_is_still_the_players() -> void:
	var module: ModuleBase = autofree(ModuleBase.new())
	module.build_state = ModuleBase.BuildState.Built
	var component: StorageComponent = _component(module)
	component.add_stored_resource(_resource(&"iron_ore"), StorageData.Role.INPUT)
	component.add_stored_resource(_resource(&"iron"), StorageData.Role.OUTPUT)
	assert_true(StoresModel.priority_editable(component),
		"whether the refinery out-bids the smelter for ore is the player's call")

## Both reasons are sentences, and neither claims more than it should: the
## priority one must not say the contents are locked, and vice versa.
func test_the_two_locked_reasons_stay_in_their_lanes() -> void:
	var module: ModuleBase = autofree(ModuleBase.new())
	module.build_state = ModuleBase.BuildState.Built
	var component: StorageComponent = _component(module)
	component.include_in_stats = false
	component.default_role = StorageData.Role.OUTPUT
	component.add_stored_resource(_resource(&"iron"), StorageData.Role.OUTPUT)
	var reason: String = StoresModel.priority_locked_reason(component)
	assert_false(reason.to_lower().contains("contents"),
		"the priority's reason is about the priority")
	assert_true(reason.to_lower().contains("export"),
		"and names why: the bin only sends goods out")

## Locked is a state, not an absence - so a bin whose contents the module owns
## owes the player a sentence, and a configurable one must not print a reason that
## does not exist.
func test_every_locked_bin_names_its_reason_and_no_editable_one_does() -> void:
	var module: ModuleBase = autofree(ModuleBase.new())
	module.build_state = ModuleBase.BuildState.Built
	var component: StorageComponent = _component(module)
	component.player_configurable = true
	assert_eq(StoresModel.locked_reason(component), "", "an editable bin says nothing")
	component.player_configurable = false
	assert_ne(StoresModel.locked_reason(component), "", "a locked bin says why")

## A construction site and a processor bay are locked for different reasons, and
## the player can act on one of those and not the other.
func test_a_construction_site_and_a_module_bin_give_different_reasons() -> void:
	var site: ModuleBase = autofree(ModuleBase.new())
	site.build_state = ModuleBase.BuildState.Blueprint
	var built: ModuleBase = autofree(ModuleBase.new())
	built.build_state = ModuleBase.BuildState.Built
	assert_ne(StoresModel.locked_reason(_component(site)),
		StoresModel.locked_reason(_component(built)),
		"a half-built module and a finished one are locked for different reasons")

## Neither sentence may claim the *whole* bin is locked, because its priority is
## not - the reason the two questions are separate in the first place.
func test_no_locked_reason_claims_the_priority_is_locked() -> void:
	var site: ModuleBase = autofree(ModuleBase.new())
	site.build_state = ModuleBase.BuildState.Blueprint
	var built: ModuleBase = autofree(ModuleBase.new())
	built.build_state = ModuleBase.BuildState.Built
	for component: StorageComponent in [_component(site), _component(built)]:
		var reason: String = StoresModel.locked_reason(component)
		assert_false(reason.to_lower().contains("readable here"),
			"\"%s\" no longer describes a bin the player can still route" % reason)

# --- the priority vocabulary ----------------------------------------------------------------

func test_the_extremes_say_what_the_legend_says() -> void:
	assert_string_contains(StoresModel.priority_label(StoresModel.PRIORITY_MIN).to_lower(),
		"last choice")
	assert_string_contains(StoresModel.priority_label(StoresModel.PRIORITY_MAX).to_lower(),
		"urgent")

func test_the_sign_splits_pushing_from_pulling() -> void:
	assert_string_contains(StoresModel.priority_label(-20).to_lower(), "push")
	assert_string_contains(StoresModel.priority_label(20).to_lower(), "pull")
	assert_eq(StoresModel.priority_label(0), "Neutral")

## The captions sit in a fixed column under the stepper, and the first draft
## ellipsed to `URGENT — PULLS STO…` on every card - a caption that explains
## nothing. The long form of the explanation is the legend line.
func test_every_caption_is_short_enough_to_fit_its_column() -> void:
	for priority: int in [-100, -60, -1, 0, 1, 60, 100]:
		assert_lt(StoresModel.priority_label(priority).length(), 14,
			"caption for %d is too long for the column" % priority)
	assert_gt(StoresModel.LEGEND.length(), 40, "the legend carries the long form instead")

## Cyan pulls stock in, amber pushes it away - and it is the same rule the ledger
## and the trade table sign their numbers with, not a second table.
func test_priority_colour_follows_the_shared_sign_rule() -> void:
	assert_eq(StoresModel.priority_color(60), UIPalette.LIVE)
	assert_eq(StoresModel.priority_color(-60), UIPalette.ATTENTION)
	assert_eq(StoresModel.priority_color(0), UIPalette.TEXT_META)
	for priority: int in [-100, -99, -1, 0, 1, 99, 100]:
		assert_eq(StoresModel.priority_color(priority), UIPalette.sign_color(float(priority)),
			"priority %d must not invent its own sign colour" % priority)

## The system's own reserved extremes have to fit inside the range the player can
## dial, or a hand-tuned bin could never out-bid a construction site.
func test_the_player_range_contains_the_systems_reserved_priorities() -> void:
	assert_lt(StoresModel.PRIORITY_MIN, -99)
	assert_gt(StoresModel.PRIORITY_MAX, 99)
