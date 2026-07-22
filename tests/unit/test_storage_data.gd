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

## A Job_GetResource carrying just an amount - the only field StorageData's
## reservation math reads off it. Not wired to any storage component, so its
## cancel() path is a no-op that never reaches Global/the board.
func _job(amount: int) -> Job_GetResource:
	var job := Job_GetResource.new()
	job.amount = amount
	job.resource_data = resource
	return job

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
	storage.add_withdraw_job(_job(8)) # reserves 8 of the 10
	assert_true(storage.can_withdraw(2, false), "2 free after an 8-unit reservation")
	assert_false(storage.can_withdraw(3, false), "the reserved 8 aren't available")
	assert_true(storage.can_withdraw(10, true), "use_reserve ignores the reservation")

# --- reservation reconciliation (the invariant) ------------------------------

func test_add_then_cancel_withdraw_reconciles_to_zero() -> void:
	var job := _job(5)
	storage.add_withdraw_job(job)
	assert_eq(storage.reserved_withdraw, 5, "reservation registered")
	assert_true(storage.withdraw_jobs.has(job))
	storage.cancel_withdraw_job(job)
	assert_eq(storage.reserved_withdraw, 0, "cancel releases the reservation")
	assert_false(storage.withdraw_jobs.has(job), "and drops the job")

func test_complete_withdraw_job_pulls_stacks_and_releases_reserve() -> void:
	storage.deposit(10, false)
	var job := _job(4)
	storage.add_withdraw_job(job)
	var withdrawn: Array[ResourceStack] = storage.complete_withdraw_job(job)
	assert_eq(_stack_total(withdrawn), 4, "the reserved amount comes off as stacks")
	assert_eq(storage.stored, 6, "stored drops by the withdrawn amount")
	assert_eq(storage.reserved_withdraw, 0, "reservation reconciled after completion")
	assert_false(storage.withdraw_jobs.has(job))

func test_add_then_cancel_deposit_reconciles_to_zero() -> void:
	var job := _job(7)
	storage.add_deposit_job(job)
	assert_eq(storage.reserved_deposit, 7, "incoming reservation registered")
	storage.cancel_deposit_job(job)
	assert_eq(storage.reserved_deposit, 0, "cancel releases the incoming reservation")

func test_complete_deposit_job_generic_path() -> void:
	var job := _job(6)
	storage.add_deposit_job(job)
	assert_true(storage.complete_deposit_job(job), "generic (no stacks) deposit succeeds")
	assert_eq(storage.stored, 6, "the units land in storage")
	assert_eq(storage.reserved_deposit, 0, "and the reservation reconciles")

func test_complete_deposit_job_preserves_incoming_stacks() -> void:
	var job := _job(3)
	storage.add_deposit_job(job)
	var incoming: Array[ResourceStack] = [_make_stack(3)]
	assert_true(storage.complete_deposit_job(job, incoming))
	assert_eq(storage.stored, 3)
	assert_eq(storage.reserved_deposit, 0)

func test_mixed_completion_and_cancel_reconciles_both_sides() -> void:
	storage.deposit(20, false)
	var w1 := _job(5)
	var w2 := _job(3)
	var d1 := _job(4)
	storage.add_withdraw_job(w1)
	storage.add_withdraw_job(w2)
	storage.add_deposit_job(d1)
	assert_eq(storage.reserved_withdraw, 8, "5 + 3 reserved out")
	assert_eq(storage.reserved_deposit, 4, "4 reserved in")
	# Resolve each job by a different terminal path.
	storage.complete_withdraw_job(w1)
	storage.cancel_withdraw_job(w2)
	storage.cancel_deposit_job(d1)
	assert_eq(storage.reserved_withdraw, 0, "both withdraw reservations reconciled to zero")
	assert_eq(storage.reserved_deposit, 0, "the deposit reservation reconciled to zero")

# --- autodump clamp (WI-38 A4) -----------------------------------------------

func test_autodump_dumps_only_the_surplus_over_desired() -> void:
	storage.deposit(10, false)
	storage.desired = 4
	assert_eq(storage.autodump_amount(), 6, "everything above desired is surplus")

func test_autodump_never_touches_reserved_stock() -> void:
	storage.deposit(10, false)
	storage.desired = 4
	storage.add_withdraw_job(_job(3)) # a hauler is already walking here for 3
	assert_eq(storage.autodump_amount(), 3, "the reserved 3 are spoken for and stay put")

func test_autodump_is_zero_when_reservations_cover_the_surplus() -> void:
	storage.deposit(10, false)
	storage.desired = 4
	storage.add_withdraw_job(_job(8))
	assert_eq(storage.autodump_amount(), 0, "no destruction when haulers claim the whole surplus")

func test_autodump_is_zero_below_desired() -> void:
	storage.deposit(2, false)
	storage.desired = 10
	assert_eq(storage.autodump_amount(), 0, "under-stocked bins never dump")

# --- teardown without a board ------------------------------------------------

func test_end_all_jobs_does_not_crash_without_a_job_manager() -> void:
	# import_job/export_job stay null so end_all_jobs never reaches
	# Global.job_manager; only the withdraw/deposit arrays are exercised.
	storage.add_withdraw_job(_job(2))
	storage.add_deposit_job(_job(3))
	storage.end_all_jobs()
	assert_eq(storage.withdraw_jobs.size(), 0, "withdraw jobs cleared")
	assert_eq(storage.deposit_jobs.size(), 0, "deposit jobs cleared")
	pass_test("end_all_jobs completed without a board attached")

func _make_stack(amount: int) -> ResourceStack:
	var stack := ResourceStack.new()
	stack.resource_data = resource
	stack.amount = amount
	return stack
