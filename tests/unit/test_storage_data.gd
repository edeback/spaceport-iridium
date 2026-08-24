extends GutTest

## Unit tests for StorageData (modules/components/storage_data.gd) - the per-
## resource stack container plus reservation bookkeeping that the hauling job
## board routes against. The headline invariant (CLAUDE.md): after any mix of
## complete/cancel, reserved_withdraw and reserved_deposit must reconcile to
## zero. These run against a bare StorageData with no JobManager/board attached.

var storage: StorageData
var resource: ResourceData

func before_each() -> void:
	resource = ResourceData.new()
	resource.id = &"test_ore"
	storage = StorageData.new()
	storage.resource_data = resource

func _stack_total(stacks: Array[ResourceStack]) -> int:
	var total: int = 0
	for stack: ResourceStack in stacks:
		total += stack.amount
	return total

# --- deposit / withdraw basics -----------------------------------------------

func test_generic_deposit_increases_stored() -> void:
	storage.deposit(10, false)
	assert_eq(storage.stored, 10, "deposit adds to the running total")

func test_try_withdraw_all_or_nothing() -> void:
	storage.deposit(5, false)
	assert_false(storage.try_withdraw(6, false), "can't withdraw more than stored")
	assert_eq(storage.stored, 5, "a failed withdraw removes nothing")
	assert_true(storage.try_withdraw(5, false), "exact amount succeeds")
	assert_eq(storage.stored, 0, "and it comes out of the total")

func test_withdraw_up_to_caps_at_available() -> void:
	storage.deposit(10, false)
	assert_eq(storage.withdraw_up_to(15, false), 10, "capped at what's actually there")
	assert_eq(storage.stored, 0)

func test_can_withdraw_respects_reservation() -> void:
	storage.deposit(10, false)
	storage.take_claim(ClaimSpec.Kind.STORAGE_WITHDRAW, 8) # reserves 8 of the 10
	assert_true(storage.can_withdraw(2, false), "2 free after an 8-unit reservation")
	assert_false(storage.can_withdraw(3, false), "the reserved 8 aren't available")
	assert_true(storage.can_withdraw(10, true), "use_reserve ignores the reservation")

# --- autodump clamp (WI-38 A4), against its own threshold (WI-65) -------------
#
# The threshold is `autodump_above`, not `desired`: `desired` is where hauling
# stops filling the bin and this is where the station starts destroying what it
# could not move. With one number the two mechanisms raced over the same units.

func test_autodump_is_off_until_a_threshold_is_set() -> void:
	storage.deposit(10, false)
	storage.desired = 4
	assert_false(storage.autodump_enabled(), "-1 is the disabled default")
	assert_eq(storage.autodump_amount(), 0,
		"venting stock is an explicit action, never something a bin drifts into")

func test_autodump_dumps_only_the_surplus_over_its_threshold() -> void:
	storage.deposit(10, false)
	storage.desired = 4
	storage.autodump_above = 4
	assert_eq(storage.autodump_amount(), 6, "everything above the threshold is surplus")

## The gap between the two numbers is the grace an export job gets to move the
## surplus somewhere useful before the vent opens.
func test_a_threshold_above_desired_leaves_a_band_for_hauling() -> void:
	storage.deposit(10, false)
	storage.desired = 4
	storage.autodump_above = 8
	assert_eq(storage.autodump_amount(), 2,
		"6 units are over target and only 2 of them are past saving")

func test_autodump_never_touches_reserved_stock() -> void:
	storage.deposit(10, false)
	storage.desired = 4
	storage.autodump_above = 4
	storage.take_claim(ClaimSpec.Kind.STORAGE_WITHDRAW, 3) # a hauler is walking here for 3
	assert_eq(storage.autodump_amount(), 3, "the reserved 3 are spoken for and stay put")

func test_autodump_is_zero_when_reservations_cover_the_surplus() -> void:
	storage.deposit(10, false)
	storage.desired = 4
	storage.autodump_above = 4
	storage.take_claim(ClaimSpec.Kind.STORAGE_WITHDRAW, 8)
	assert_eq(storage.autodump_amount(), 0, "no destruction when haulers claim the whole surplus")

func test_autodump_is_zero_below_the_threshold() -> void:
	storage.deposit(2, false)
	storage.desired = 10
	storage.autodump_above = 10
	assert_eq(storage.autodump_amount(), 0, "under-stocked bins never dump")

# --- the deposit claim (WI-65 §13) -------------------------------------------
#
# Only INPUT is capped per slot. GENERAL and OUTPUT are bounded by the
# component's pool, which this class deliberately cannot see - so their
# reservations stay pure bookkeeping and whatever picked the bin checked the room.

func test_an_input_slot_refuses_a_deposit_claim_past_its_cap() -> void:
	storage.role = StorageData.Role.INPUT
	storage.desired = 10
	storage.deposit(8, false)
	assert_true(storage.can_take_claim(ClaimSpec.Kind.STORAGE_DEPOSIT, 2), "2 fit")
	assert_false(storage.can_take_claim(ClaimSpec.Kind.STORAGE_DEPOSIT, 3), "3 do not")

## The bug this exists to stop: five haulers each reserving against the same
## five remaining units, four of them arriving at a full slot.
func test_input_deposit_claims_do_not_overcommit_each_other() -> void:
	storage.role = StorageData.Role.INPUT
	storage.desired = 10
	storage.deposit(5, false)
	assert_true(storage.take_claim(ClaimSpec.Kind.STORAGE_DEPOSIT, 5) != null,
		"the first hauler takes the last five")
	assert_false(storage.can_take_claim(ClaimSpec.Kind.STORAGE_DEPOSIT, 1),
		"and the second is turned away rather than walking there for nothing")

func test_a_general_slot_leaves_deposit_room_to_the_component() -> void:
	storage.role = StorageData.Role.GENERAL
	storage.desired = 4
	storage.deposit(100, false)
	assert_true(storage.can_take_claim(ClaimSpec.Kind.STORAGE_DEPOSIT, 50),
		"a storeroom's bound is max_stored, which this class cannot see")

func test_an_output_slot_leaves_deposit_room_to_the_component() -> void:
	storage.role = StorageData.Role.OUTPUT
	storage.desired = 0
	assert_true(storage.can_take_claim(ClaimSpec.Kind.STORAGE_DEPOSIT, 20),
		"an output slot is bounded by output_capacity, not by desired")

# --- teardown without a board ------------------------------------------------

func test_end_all_jobs_does_not_crash_without_a_job_manager() -> void:
	# import_job/export_job stay null, so end_all_jobs never reaches
	# Global.job_manager. Reservations are claims now and are released by the
	# registry when their job ends, so there is nothing else here to tear down.
	storage.take_claim(ClaimSpec.Kind.STORAGE_WITHDRAW, 2)
	storage.end_all_jobs()
	assert_null(storage.import_job, "no posted import job")
	assert_null(storage.export_job, "no posted export job")
	pass_test("end_all_jobs completed without a board attached")

func _make_stack(amount: int) -> ResourceStack:
	var stack := ResourceStack.new()
	stack.resource_data = resource
	stack.amount = amount
	return stack

# --- WI-44 claimable contract -------------------------------------------------
#
# StorageData is the claim TARGET (not StorageComponent): reservations are
# per-resource and the duck-typed contract has no room for a resource argument.
# Keeping the contract here is also what keeps this class Global-free, which is
# what lets this whole suite construct it directly.
#
# Same headline invariant as above: after any mix of consume/release, both
# reserved counters must reconcile to zero.

func test_claim_contract_is_implemented() -> void:
	for method: String in ["can_take_claim", "take_claim", "release_claim"]:
		assert_true(storage.has_method(method), "StorageData implements " + method)

func test_withdraw_claim_is_refused_beyond_unreserved_stock() -> void:
	storage.add_amount(10)
	assert_true(storage.can_take_claim(ClaimSpec.Kind.STORAGE_WITHDRAW, 10), "all of it is claimable")
	storage.take_claim(ClaimSpec.Kind.STORAGE_WITHDRAW, 7)
	assert_eq(storage.reserved_withdraw, 7, "the reservation landed")
	assert_true(storage.can_take_claim(ClaimSpec.Kind.STORAGE_WITHDRAW, 3), "the remainder is still free")
	assert_false(storage.can_take_claim(ClaimSpec.Kind.STORAGE_WITHDRAW, 4),
		"but stock another job already spoke for is not")

func test_refused_withdraw_claim_reserves_nothing() -> void:
	storage.add_amount(2)
	assert_null(storage.take_claim(ClaimSpec.Kind.STORAGE_WITHDRAW, 5), "over-claim refused")
	assert_eq(storage.reserved_withdraw, 0, "and left no trace")

func test_deposit_claim_is_bookkeeping_only() -> void:
	# Space is a component-level question (max_stored spans every resource), so
	# the per-resource reservation cannot validate it - exactly as the old
	# add_deposit_job() never did. Whatever picked the bin checked the room.
	assert_true(storage.can_take_claim(ClaimSpec.Kind.STORAGE_DEPOSIT, 9999), "always accepted")
	storage.take_claim(ClaimSpec.Kind.STORAGE_DEPOSIT, 4)
	assert_eq(storage.reserved_deposit, 4, "recorded")

func test_release_returns_the_reservation() -> void:
	storage.add_amount(10)
	storage.take_claim(ClaimSpec.Kind.STORAGE_WITHDRAW, 6)
	storage.release_claim(ClaimSpec.Kind.STORAGE_WITHDRAW, 6, null)
	assert_eq(storage.reserved_withdraw, 0, "reconciles to zero")

func test_release_never_drives_a_counter_negative() -> void:
	storage.release_claim(ClaimSpec.Kind.STORAGE_WITHDRAW, 5, null)
	storage.release_claim(ClaimSpec.Kind.STORAGE_DEPOSIT, 5, null)
	assert_eq(storage.reserved_withdraw, 0, "withdraw floors at zero")
	assert_eq(storage.reserved_deposit, 0, "so does deposit")

func test_withdraw_reserved_spends_the_reservation() -> void:
	# The action that calls this must CONSUME its claim record afterwards, not
	# release it - the units are gone from the bin either way.
	storage.add_amount(10)
	storage.take_claim(ClaimSpec.Kind.STORAGE_WITHDRAW, 6)
	var taken: Array[ResourceStack] = storage.withdraw_reserved(6)
	assert_eq(_stack_total(taken), 6, "got the goods")
	assert_eq(storage.stored, 4, "stock dropped")
	assert_eq(storage.reserved_withdraw, 0, "and the reservation went with them")

func test_deposit_reserved_spends_the_reservation() -> void:
	storage.take_claim(ClaimSpec.Kind.STORAGE_DEPOSIT, 3)
	var stack := ResourceStack.new()
	stack.resource_data = resource
	stack.amount = 3
	storage.deposit_reserved([stack], 3)
	assert_eq(storage.stored, 3, "goods landed")
	assert_eq(storage.reserved_deposit, 0, "and the space reservation was spent")

func test_amount_based_claims_are_not_tied_to_one_job_type() -> void:
	# The point of the migration: the old add_withdraw_job() read the amount off a
	# hard-typed job, which is why pile collection could never reserve deposit
	# space. A claim carries its own amount and no job type at all.
	storage.add_amount(10)
	storage.take_claim(ClaimSpec.Kind.STORAGE_WITHDRAW, 3)
	storage.take_claim(ClaimSpec.Kind.STORAGE_WITHDRAW, 4)
	assert_eq(storage.reserved_withdraw, 7, "two independent claimants, no job object anywhere")
