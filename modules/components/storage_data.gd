class_name StorageData
extends ResourceStackContainer

@export var desired: int = 0
@export var reserved_withdraw: int = 0
@export var reserved_deposit: int = 0
## The outstanding board jobs this bin has posted, so it doesn't post a second
## one for the same deficit/surplus. Reservations are NOT tracked here any more -
## they are claims, and reserved_withdraw/reserved_deposit above are maintained
## by the claimable contract below (WI-44).
var import_job: Job = null
var export_job: Job = null
@export var autodump: bool = false

func end_all_jobs() -> void:
	# Null our reference BEFORE cancelling: ending a job releases its claims,
	# which re-enters this storage, and clearing first is what keeps that
	# re-entrancy safe.
	if import_job != null:
		var job: Job = import_job
		import_job = null
		job.cancel(true)
		Global.job_manager.remove_job(job)
	if export_job != null:
		var job: Job = export_job
		export_job = null
		job.cancel(true)
		Global.job_manager.remove_job(job)

func set_job_priority(new_priority: int) -> void:
	if import_job != null:
		import_job.priority = new_priority
	if export_job != null:
		export_job.priority = new_priority

## How much autodump is allowed to destroy: surplus over `desired`, minus
## anything a hauler has already reserved a withdrawal against. Without the
## reserved term a pawn walking to this bin arrives to find its stock deleted
## and the trip is wasted (WI-38 A4). Kept here, and out of
## StorageComponent.destroy_resource, because that is also the module-destruction
## and eject path, where ignoring reservations is the correct behavior.
func autodump_amount() -> int:
	return maxi(stored - desired - reserved_withdraw, 0)

func can_withdraw(quantity: int, use_reserve: bool) -> bool:
	var available: int = stored
	if not use_reserve:
		available -= reserved_withdraw
	return available >= quantity

## Core withdraw shared by the generic (bool) and stack-aware APIs below.
func _do_withdraw(quantity: int, use_reserve: bool) -> Array[ResourceStack]:
	if not can_withdraw(quantity, use_reserve):
		return []
	var withdrawn: Array[ResourceStack] = withdraw_stacks(quantity)
	if use_reserve:
		reserved_withdraw = maxi(reserved_withdraw - quantity, 0)
	return withdrawn

## Generic (no-variant) withdraw, kept for existing call sites that only deal
## in plain counts (debug buttons, ResourceData.force_withdraw, etc).
## Internally this still withdraws real stacks, it just discards whichever
## instance_data came off them.
func try_withdraw(quantity: int, use_reserve: bool) -> bool:
	return not _do_withdraw(quantity, use_reserve).is_empty()

func withdraw_up_to(quantity: int, use_reserve: bool) -> int:
	var available: int = stored
	if not use_reserve:
		available -= reserved_withdraw
	var withdrawable: int = mini(quantity, available)
	if withdrawable <= 0:
		return 0
	_do_withdraw(withdrawable, use_reserve)
	return withdrawable

## Generic (no-variant) deposit, kept for existing call sites.
func deposit(quantity: int, use_reserve: bool) -> int:
	add_amount(quantity)
	if use_reserve:
		reserved_deposit -= quantity
		assert(reserved_deposit >= 0)
	return stored

# --- claimable contract (WI-44) -----------------------------------------------
#
# StorageData is the claim target, NOT StorageComponent: reservations are
# per-resource and the duck-typed contract has no room for a resource argument.
# It also keeps the claim path free of Global, which is what preserves this
# class's pure GUT suite.
#
# The amount-based replacement for the add/cancel/complete_*_job pairs this class
# used to carry, whose hard the haul job type was the reason pile collection
# could never reserve deposit space. A claim carries its own amount and does not
# care who is asking, so any job can now reserve either direction.

func can_take_claim(kind: int, amount: int) -> bool:
	if kind == ClaimSpec.Kind.STORAGE_WITHDRAW:
		# use_reserve = false: must be stock nobody else has already spoken for.
		return can_withdraw(amount, false)
	# Deposit space is a component-level question (max_stored spans every
	# resource), so the reservation itself is pure bookkeeping - exactly as
	# add_deposit_job() has always been. Whatever picked this bin is what checked
	# there was room.
	return kind == ClaimSpec.Kind.STORAGE_DEPOSIT

func take_claim(kind: int, amount: int) -> Variant:
	if not can_take_claim(kind, amount):
		return null
	if kind == ClaimSpec.Kind.STORAGE_WITHDRAW:
		reserved_withdraw += amount
	else:
		reserved_deposit += amount
	return true

func release_claim(kind: int, amount: int, _payload: Variant) -> void:
	if kind == ClaimSpec.Kind.STORAGE_WITHDRAW:
		reserved_withdraw = maxi(reserved_withdraw - amount, 0)
	else:
		reserved_deposit = maxi(reserved_deposit - amount, 0)

## Takes `amount` out against a reservation this job already holds, as real
## stacks. The reservation is spent by the withdraw itself, so the caller must
## CONSUME its claim record rather than releasing it - releasing would credit the
## same units back a second time. See ClaimRegistry.consume().
func withdraw_reserved(amount: int) -> Array[ResourceStack]:
	return _do_withdraw(amount, true)

## Mirror of the above for the deposit side: the stacks are added and the
## reservation they were holding is spent.
func deposit_reserved(stacks: Array[ResourceStack], amount: int) -> void:
	for stack: ResourceStack in stacks:
		add_stack(stack)
	reserved_deposit = maxi(reserved_deposit - amount, 0)

