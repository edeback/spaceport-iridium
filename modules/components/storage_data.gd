class_name StorageData
extends Resource


@export var stored: int = 0
@export var desired: int = 0
@export var reserved_withdraw: int = 0
@export var reserved_deposit: int = 0
@export var import_job: Job_GetResource
@export var withdraw_jobs: Array[Job_GetResource] = []
@export var deposit_jobs: Array[Job_GetResource] = []


func end_all_jobs() -> void:
	if import_job != null:
		import_job.cancel(true)
		import_job = null
		Global.job_manager.remove_job(import_job)
	for job in withdraw_jobs:
		job.cancel(true)
	withdraw_jobs.clear()
	for job in deposit_jobs:
		job.cancel(true)
	deposit_jobs.clear()

func set_job_priority(new_priority: int) -> void:
	if import_job != null:
		import_job.priority = new_priority

func can_withdraw(quantity: int, use_reserve: bool) -> bool:
	var available := stored
	if not use_reserve:
		available -= reserved_withdraw
	return available >= quantity

func try_withdraw(quantity: int, use_reserve: bool) -> bool:
	var available := stored
	if not use_reserve:
		available -= reserved_withdraw
	if quantity <= available:
		stored -= quantity
		if use_reserve:
			reserved_withdraw = maxi(reserved_withdraw - quantity, 0)
		return true
	return false

func withdraw_up_to(quantity: int, use_reserve: bool) -> int:
	var available := stored
	if not use_reserve:
		available -= reserved_withdraw
	var withdrawable := mini(quantity, available)
	if withdrawable > 0:
		stored -= withdrawable
		if use_reserve:
			reserved_withdraw = maxi(reserved_withdraw - withdrawable, 0)
	return withdrawable
	
func deposit(quantity: int, use_reserve: bool) -> int:
	stored += quantity
	if use_reserve:
		reserved_deposit -= quantity
		assert(reserved_deposit >= 0)
	return stored

func add_withdraw_job(job: Job_GetResource) -> void:
	withdraw_jobs.append(job)
	reserved_withdraw += job.amount
	
func cancel_withdraw_job(job: Job_GetResource) -> void:
	if withdraw_jobs.has(job):
		withdraw_jobs.erase(job)
		reserved_withdraw -= job.amount
		assert(reserved_withdraw >= 0)
		
func complete_withdraw_job(job: Job_GetResource) -> bool:
	if withdraw_jobs.has(job):
		try_withdraw(job.amount, true)
		withdraw_jobs.erase(job)
		return true
	return false

func add_deposit_job(job: Job_GetResource) -> void:
	deposit_jobs.append(job)
	reserved_deposit += job.amount

func cancel_deposit_job(job: Job_GetResource) -> void:
	if deposit_jobs.has(job):
		if job == import_job:
			import_job = null
		deposit_jobs.erase(job)
		reserved_deposit -= job.amount
		assert(reserved_deposit >= 0)
		
func complete_deposit_job(job: Job_GetResource) -> bool:
	if deposit_jobs.has(job):
		if job == import_job:
			import_job = null
		deposit(job.amount, true)
		deposit_jobs.erase(job)
		return true
	return false
