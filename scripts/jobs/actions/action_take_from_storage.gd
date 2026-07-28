class_name Action_TakeFromStorage
extends ActionBase

## Move job.count of job.resource out of the storage in a slot and onto the pawn
## (WI-44). Instant.

@export var slot: JobTarget.Slot = JobTarget.Slot.A

func _init(target_slot: JobTarget.Slot = JobTarget.Slot.A) -> void:
	slot = target_slot
	complete_mode = CompleteMode.INSTANT
	carries_cargo = true

func on_start(job: Job) -> Status:
	var storage: StorageComponent = _storage(job)
	if storage == null or job.resource == null or job.pawn == null:
		return Status.FAILED
	var bin: StorageData = storage.claim_target_for(job.resource)
	if bin == null:
		return Status.FAILED
	var withdrawn: Array[ResourceStack] = storage.withdraw_reserved(job.resource, job.count)
	if withdrawn.is_empty():
		return Status.FAILED
	# The reservation is SPENT, not released: those units are physically on the
	# pawn now, and releasing would credit them back to the bin a second time.
	job.consume_claim(bin, ClaimSpec.Kind.STORAGE_WITHDRAW)
	var leftover: Array[ResourceStack] = job.pawn.inventory_component.add_stacks(job.resource, withdrawn)
	if not leftover.is_empty():
		# Shouldn't happen - can_do() already checked the pawn had room - but hand
		# it straight back rather than destroying it. Jobs never destroy carried
		# resources.
		storage.deposit_stacks(job.resource, leftover, false)
	return Status.DONE

## Already carrying it. Re-running on_start would withdraw a SECOND load against
## a reservation that no longer exists - this is the exact case on_resume exists
## for, and the reason it is a separate hook rather than an alias.
func on_resume(job: Job) -> Status:
	if job.pawn != null and job.resource != null \
			and job.pawn.inventory_component != null \
			and job.pawn.inventory_component.get_carried_amount(job.resource) > 0:
		return Status.DONE
	return on_start(job)

func report(job: Job) -> String:
	return "Picking up " + (job.resource.name if job.resource != null else "resources")

func _storage(job: Job) -> StorageComponent:
	var slot_target: JobTarget = job.target(slot)
	if slot_target == null:
		return null
	return slot_target.component() as StorageComponent
