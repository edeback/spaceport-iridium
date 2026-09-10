class_name Action_DumpInventory
extends ActionBase

## Put down everything the bin in a slot will accept (WI-44). Instant.
##
## Unlike Action_DepositToStorage this holds no reservation and is not about one
## resource: it is the cargo sweep, so it offers the bin every stack the pawn is
## carrying and keeps whatever is refused. Nothing is ever destroyed - leftovers
## stay on the pawn and the sweep runs again.

@export var slot: JobTarget.Slot = JobTarget.Slot.A

func _init(target_slot: JobTarget.Slot = JobTarget.Slot.A) -> void:
	slot = target_slot
	complete_mode = CompleteMode.INSTANT
	carries_cargo = true

func on_start(job: Job) -> Status:
	var storage: StorageComponent = _storage(job)
	if storage == null or job.pawn == null or job.pawn.inventory_component == null:
		return Status.FAILED
	var deposited_any: bool = false
	for resource: ResourceData in job.pawn.inventory_component.get_carried_resources():
		if not storage.can_store_resource(resource):
			continue
		var carried: int = job.pawn.inventory_component.get_carried_amount(resource)
		# Per resource: the bin's pools are role-qualified (WI-65), so a mining bay's
		# ore goes against its output pool, not the empty general one.
		var amount: int = mini(carried, storage.room_for(resource))
		if amount <= 0:
			continue
		var stacks: Array[ResourceStack] = job.pawn.inventory_component.withdraw_stacks(resource, amount)
		if stacks.is_empty():
			continue
		if storage.deposit_stacks(resource, stacks):
			deposited_any = true
		else:
			# Something went wrong after it came off the pawn - hand it back
			# rather than losing it.
			job.pawn.inventory_component.add_stacks(resource, stacks)
	# Nothing landed: the bin filled up while the pawn walked over. Failing sends
	# it round again rather than looping on a bin that cannot help.
	return Status.DONE if deposited_any else Status.FAILED

func report(_job: Job) -> String:
	return "Putting things away"

func _storage(job: Job) -> StorageComponent:
	var destination: JobTarget = job.target(slot)
	if destination == null or not destination.is_alive():
		return null
	return destination.component() as StorageComponent
