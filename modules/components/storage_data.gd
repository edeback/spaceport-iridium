class_name StorageData
extends ResourceStackContainer

@export var desired: int = 0
@export var reserved_withdraw: int = 0
@export var reserved_deposit: int = 0
@export var import_job: Job_GetResource
@export var export_job: Job_GetResource
@export var withdraw_jobs: Array[Job_GetResource] = []
@export var deposit_jobs: Array[Job_GetResource] = []
@export var autodump: bool = false

func end_all_jobs() -> void:
	# Null/erase our references BEFORE cancelling: cancel() re-enters this
	# storage via cancel_withdraw_job/cancel_deposit_job, and the erase-first
	# ordering is what keeps that re-entrancy safe. cancel() implies end_job
	# (lifecycle contract) - no separate end call needed.
	if import_job != null:
		var job: Job_GetResource = import_job
		import_job = null
		job.cancel(true)
		Global.job_manager.remove_job(job)
	if export_job != null:
		var job: Job_GetResource = export_job
		export_job = null
		job.cancel(true)
		Global.job_manager.remove_job(job)
	# Iterate copies: each cancel() re-enters and erases from the live array.
	for job in withdraw_jobs.duplicate():
		job.cancel(true)
	withdraw_jobs.clear()
	for job in deposit_jobs.duplicate():
		job.cancel(true)
	deposit_jobs.clear()

func set_job_priority(new_priority: int) -> void:
	if import_job != null:
		import_job.priority = new_priority
	if export_job != null:
		export_job.priority = new_priority

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

func add_withdraw_job(job: Job_GetResource) -> void:
	withdraw_jobs.append(job)
	reserved_withdraw += job.amount

func cancel_withdraw_job(job: Job_GetResource) -> void:
	if job == export_job:
		export_job = null
	if withdraw_jobs.has(job):
		withdraw_jobs.erase(job)
		reserved_withdraw -= job.amount
		assert(reserved_withdraw >= 0)

## Withdraws the amount reserved for `job` as real stacks (preserving any
## instance_data) instead of just flipping a bool. Returns [] on failure -
## same "nothing happened" meaning the old bool-false used to carry.
func complete_withdraw_job(job: Job_GetResource) -> Array[ResourceStack]:
	if not withdraw_jobs.has(job):
		return []
	var withdrawn: Array[ResourceStack] = _do_withdraw(job.amount, true)
	if not withdrawn.is_empty():
		if job == export_job:
			export_job = null
		withdraw_jobs.erase(job)
	return withdrawn

func add_deposit_job(job: Job_GetResource) -> void:
	deposit_jobs.append(job)
	reserved_deposit += job.amount

func cancel_deposit_job(job: Job_GetResource) -> void:
	if job == import_job:
		import_job = null
	if deposit_jobs.has(job):
		deposit_jobs.erase(job)
		reserved_deposit -= job.amount
		assert(reserved_deposit >= 0)

## Deposits the actual stacks a job is carrying (preserving instance_data)
## instead of just job.amount worth of generic units. incoming_stacks empty
## falls back to a plain generic deposit, for callers that never touched a
## pawn's inventory (shouldn't normally happen via Job_GetResource anymore,
## but keeps this safe to call the old way too).
func complete_deposit_job(job: Job_GetResource, incoming_stacks: Array[ResourceStack] = []) -> bool:
	if not deposit_jobs.has(job):
		return false
	if job == import_job:
		import_job = null
	if incoming_stacks.is_empty():
		deposit(job.amount, true)
	else:
		for stack: ResourceStack in incoming_stacks:
			add_stack(stack)
		reserved_deposit = maxi(reserved_deposit - job.amount, 0)
	deposit_jobs.erase(job)
	return true
