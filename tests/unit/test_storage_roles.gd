extends GutTest

## WI-65: a slot's ROLE decides which directions hauling may move it, replacing
## the component-level accepts_imports/accepts_exports pair.
##
## The whole point of the change is that one bin can pull ore in while pushing
## iron out, so most of what is worth asserting is the routing TABLE - which
## role reports which priority in which direction - plus the one distinction the
## implementation could plausibly get wrong: REFUSED is not an extreme number,
## it is a separate answer, because [StorageQuery]'s ANY_PRIORITY paths skip the
## priority comparison entirely.

const REFUSED: int = StorageComponent.REFUSED

func _resource(id: StringName) -> ResourceData:
	var resource := ResourceData.new()
	resource.id = id
	resource.name = String(id)
	return resource

func _bin(priority: int = 5) -> StorageComponent:
	var component: StorageComponent = autofree(StorageComponent.new())
	component.include_in_stats = false
	component.priority = priority
	component.max_stored = 100
	component.output_capacity = 40
	return component

func _slot(component: StorageComponent, id: StringName, role: StorageData.Role) -> ResourceData:
	var resource: ResourceData = _resource(id)
	component.add_stored_resource(resource, role)
	return resource

# --- the routing table -----------------------------------------------------------

func test_general_moves_both_ways_at_the_bins_priority() -> void:
	var bin: StorageComponent = _bin(5)
	var iron: ResourceData = _slot(bin, &"iron", StorageData.Role.GENERAL)
	assert_eq(bin.import_priority(iron), 5, "a storeroom receives at its own number")
	assert_eq(bin.export_priority(iron), 5, "and ships at the same one")

func test_input_receives_but_never_ships() -> void:
	var bin: StorageComponent = _bin(5)
	var ore: ResourceData = _slot(bin, &"iron_ore", StorageData.Role.INPUT)
	assert_eq(bin.import_priority(ore), 5, "ingredients are hauled in")
	assert_eq(bin.export_priority(ore), REFUSED,
		"and never hauled back out - a forge mid-recipe must not lose its ore")

func test_output_ships_at_the_floor_and_never_receives() -> void:
	var bin: StorageComponent = _bin(5)
	var iron: ResourceData = _slot(bin, &"iron", StorageData.Role.OUTPUT)
	assert_eq(bin.import_priority(iron), REFUSED,
		"a product bay is not somewhere to deliver to")
	assert_eq(bin.export_priority(iron), StoresModel.PRIORITY_MIN,
		"and ships at the floor whatever the component's priority says")

func test_excluded_moves_nothing() -> void:
	var bin: StorageComponent = _bin(5)
	var steel: ResourceData = _slot(bin, &"steel", StorageData.Role.EXCLUDED)
	assert_eq(bin.import_priority(steel), REFUSED, "a frozen bin receives nothing")
	assert_eq(bin.export_priority(steel), REFUSED, "and gives nothing up")

## The reason one component can now do the work of two.
func test_one_bin_pulls_one_resource_in_while_pushing_another_out() -> void:
	var bin: StorageComponent = _bin(1)
	var ore: ResourceData = _slot(bin, &"iron_ore", StorageData.Role.INPUT)
	var iron: ResourceData = _slot(bin, &"iron", StorageData.Role.OUTPUT)
	assert_eq(bin.import_priority(ore), 1, "ore comes in")
	assert_eq(bin.export_priority(iron), StoresModel.PRIORITY_MIN, "iron goes out")
	assert_eq(bin.export_priority(ore), REFUSED, "and neither leaks the other way")
	assert_eq(bin.import_priority(iron), REFUSED)

## OUTPUT's floor is not an offset from the component's number: raising a
## refinery's priority must not make its products harder to get rid of.
func test_the_output_floor_does_not_move_with_the_bins_priority() -> void:
	for priority: int in [-40, 0, 1, 60, StoresModel.PRIORITY_MAX]:
		var bin: StorageComponent = _bin(priority)
		var iron: ResourceData = _slot(bin, &"iron", StorageData.Role.OUTPUT)
		assert_eq(bin.export_priority(iron), StoresModel.PRIORITY_MIN,
			"output ships at the floor with the bin at %d" % priority)

# --- REFUSED is not a number ------------------------------------------------------

## The distinction that would break the pile and cargo-sweep paths if it were
## lost. `find_sink(ANY_PRIORITY)` skips the priority comparison, so a refusal
## folded into an extreme number would be silently ignored there.
func test_refused_is_outside_the_priority_range_entirely() -> void:
	assert_gt(REFUSED, StoresModel.PRIORITY_MAX,
		"REFUSED must not be mistakable for a very high priority")
	assert_ne(REFUSED, StorageQuery.ANY_PRIORITY,
		"nor for the caller-has-no-priority sentinel, which means the opposite")

func test_a_resource_the_bin_does_not_handle_is_refused_both_ways() -> void:
	var bin: StorageComponent = _bin(5)
	var stranger: ResourceData = _resource(&"gold")
	assert_eq(bin.import_priority(stranger), REFUSED)
	assert_eq(bin.export_priority(stranger), REFUSED)

## Unless it is a catch-all bin, which handles anything at its default role.
func test_a_catch_all_bin_handles_an_unknown_resource_at_its_default_role() -> void:
	var bin: StorageComponent = _bin(5)
	bin.allow_any_resource = true
	var stranger: ResourceData = _resource(&"gold")
	assert_eq(bin.import_priority(stranger), 5, "a storeroom takes whatever turns up")
	bin.default_role = StorageData.Role.OUTPUT
	assert_eq(bin.import_priority(stranger), REFUSED,
		"the docking bay's arrivals take nothing in - they only ship onward")
	assert_eq(bin.export_priority(stranger), StoresModel.PRIORITY_MIN)

# --- what a slot asks for ---------------------------------------------------------

func test_only_the_receiving_roles_accept_imports() -> void:
	var expected: Dictionary[StorageData.Role, bool] = {
		StorageData.Role.GENERAL: true,
		StorageData.Role.INPUT: true,
		StorageData.Role.OUTPUT: false,
		StorageData.Role.EXCLUDED: false,
	}
	for role: StorageData.Role in expected:
		var slot := StorageData.new()
		slot.role = role
		assert_eq(slot.accepts_imports(), expected[role], "imports for role %d" % role)

func test_only_the_shipping_roles_accept_exports() -> void:
	var expected: Dictionary[StorageData.Role, bool] = {
		StorageData.Role.GENERAL: true,
		StorageData.Role.INPUT: false,
		StorageData.Role.OUTPUT: true,
		StorageData.Role.EXCLUDED: false,
	}
	for role: StorageData.Role in expected:
		var slot := StorageData.new()
		slot.role = role
		assert_eq(slot.accepts_exports(), expected[role], "exports for role %d" % role)

## A GENERAL bin ships what it holds over its target; an OUTPUT slot ships
## everything, because its whole purpose is to be emptied and `desired = 0` was
## what used to simulate that.
func test_the_role_decides_what_surplus_means() -> void:
	var slot := StorageData.new()
	slot.desired = 10
	slot.add_amount(14)

	slot.role = StorageData.Role.GENERAL
	assert_eq(slot.exportable_surplus(), 4, "a storeroom ships what is over target")
	slot.role = StorageData.Role.OUTPUT
	assert_eq(slot.exportable_surplus(), 14, "a product bay ships the lot")
	slot.role = StorageData.Role.INPUT
	assert_eq(slot.exportable_surplus(), 0, "ingredients stay put")
	slot.role = StorageData.Role.EXCLUDED
	assert_eq(slot.exportable_surplus(), 0, "and a frozen bin gives up nothing")

func test_surplus_never_offers_stock_someone_has_already_claimed() -> void:
	var slot := StorageData.new()
	slot.role = StorageData.Role.OUTPUT
	slot.add_amount(10)
	slot.reserved_withdraw = 4
	assert_eq(slot.exportable_surplus(), 6, "a hauler is already coming for four")
	slot.reserved_withdraw = 20
	assert_eq(slot.exportable_surplus(), 0, "and never goes negative")

# --- capacity pools ----------------------------------------------------------------

## The pools are separate so a backed-up output cannot starve the input side.
func test_the_two_roles_draw_on_separate_pools() -> void:
	var bin: StorageComponent = _bin(1)
	var ore: ResourceData = _slot(bin, &"iron_ore", StorageData.Role.INPUT)
	var iron: ResourceData = _slot(bin, &"iron", StorageData.Role.OUTPUT)
	bin.deposit(iron, 40)
	assert_eq(bin.space_available(false, StorageData.Role.OUTPUT), 0,
		"the output bay is full")
	assert_eq(bin.space_available(false, StorageData.Role.GENERAL), 100,
		"which must not take a single unit off the intake side")
	assert_true(bin.can_deposit(ore, 100), "so ore still fits")
	assert_false(bin.can_deposit(iron, 1), "and iron does not")

func test_pool_for_maps_roles_to_their_capacity() -> void:
	var bin: StorageComponent = _bin(1)
	assert_eq(bin.pool_for(StorageData.Role.OUTPUT), 40)
	assert_eq(bin.pool_for(StorageData.Role.GENERAL), 100)
	assert_eq(bin.pool_for(StorageData.Role.INPUT), 100,
		"GENERAL and INPUT share one pool - they never coexist on a module")

# --- has_intake_slots, and the empty-bin trap ----------------------------------------

## "Has an intake side" is a question about CAPACITY, not about which slots
## happen to exist. A mining bay's whole capacity is its output pool.
func test_a_bin_with_no_intake_pool_has_no_intake_side() -> void:
	var bin: StorageComponent = _bin(1)
	bin.max_stored = 0
	_slot(bin, &"iron_ore", StorageData.Role.OUTPUT)
	assert_false(bin.has_intake_slots(), "a mining bay only ever sends ore out")

## Two bugs this rule replaced, both found by a screenshot rather than a check.
##
## Counting INPUT slots read an EMPTY storeroom as export-only and stripped its
## priority stepper; it also stripped the docking bay's, which grows its staging
## slots only when the player places a sell order - leaving a card that said
## "its priority is still yours" beside no control at all.
func test_a_bin_with_room_but_no_slots_yet_still_takes_deliveries() -> void:
	var bin: StorageComponent = _bin(1)
	assert_true(bin.storage_data.is_empty(), "fixture precondition")
	assert_true(bin.has_intake_slots(), "a fresh storeroom still takes deliveries")
	bin.default_role = StorageData.Role.OUTPUT
	bin.allow_any_resource = true
	assert_true(bin.has_intake_slots(),
		"and so does a trade bay between orders, whatever its arrivals default to")

## An export-only PROCESSOR - a recipe with no ingredients - has declared slots
## and none of them receive, so it is export-only even with an intake pool.
func test_a_configured_bin_with_no_receiving_slots_is_export_only() -> void:
	var bin: StorageComponent = _bin(1)
	_slot(bin, &"iron", StorageData.Role.OUTPUT)
	assert_false(bin.has_intake_slots(),
		"its contents are declared and not one of them is an intake")

## The defect the assert now catches: OUTPUT slots drawing on a pool of zero.
## The bay reads as having capacity (max_stored is non-zero) while the slots that
## actually hold anything can hold nothing.
func test_output_slots_are_useless_without_an_output_pool() -> void:
	var bin: StorageComponent = _bin(1)
	bin.output_capacity = 0
	var iron: ResourceData = _slot(bin, &"iron", StorageData.Role.OUTPUT)
	assert_eq(bin.pool_for(StorageData.Role.OUTPUT), 0)
	assert_false(bin.can_deposit(iron, 1),
		"which is why ready_constructed asserts against this shape")

func test_a_two_role_bin_has_both() -> void:
	var bin: StorageComponent = _bin(1)
	_slot(bin, &"iron_ore", StorageData.Role.INPUT)
	_slot(bin, &"iron", StorageData.Role.OUTPUT)
	assert_true(bin.has_intake_slots())
	assert_true(bin.has_output_slots())

# --- re-roling -----------------------------------------------------------------------

## add_stored_resource must NOT re-role a slot that already exists: the save
## block calls it for every restored resource, and flipping a processor's
## carefully roled slots to `default_role` on every load is a real bug.
func test_adding_an_existing_resource_leaves_its_role_alone() -> void:
	var bin: StorageComponent = _bin(1)
	bin.default_role = StorageData.Role.OUTPUT
	var ore: ResourceData = _slot(bin, &"iron_ore", StorageData.Role.INPUT)
	bin.add_stored_resource(ore)
	assert_eq(bin.storage_data[ore].role, StorageData.Role.INPUT,
		"a load must not turn a refinery's ingredients into products")

func test_set_all_roles_freezes_every_slot_at_once() -> void:
	var bin: StorageComponent = _bin(1)
	_slot(bin, &"iron_ore", StorageData.Role.INPUT)
	_slot(bin, &"iron", StorageData.Role.OUTPUT)
	bin.set_all_roles(StorageData.Role.EXCLUDED)
	for slot: StorageData in bin.storage_data.values():
		assert_eq(slot.role, StorageData.Role.EXCLUDED,
			"a construction site freezes its bin WITH its materials still in it")
