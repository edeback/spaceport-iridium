class_name Action_DepositToStorage
extends ActionBase

## Move what the pawn is carrying into the storage in a slot (WI-44). Instant.
##
## Anything the bin won't take stays on the pawn rather than being destroyed -
## the standing invariant - and gets swept up later.

@export var slot: JobTarget.Slot = JobTarget.Slot.B

func _init(target_slot: JobTarget.Slot = JobTarget.Slot.B) -> void:
	slot = target_slot
	complete_mode = CompleteMode.INSTANT
	carries_cargo = true

func on_start(job: Job) -> Status:
	var storage: StorageComponent = _storage(job)
	if storage == null or job.resource == null or job.pawn == null:
		return Status.FAILED
	if job.pawn.inventory_component == null:
		return Status.FAILED
	var bin: StorageData = storage.claim_target_for(job.resource)
	if bin == null:
		return Status.FAILED
	# No record means no reservation to spend: booking `amount` in its place would
	# eat into whatever another inbound haul has reserved here.
	var spec: ClaimSpec = job.find_claim(bin, ClaimSpec.Kind.STORAGE_DEPOSIT)
	var booked: int = spec.amount if spec != null else 0
	var carried: int = job.pawn.inventory_component.get_carried_amount(job.resource)
	# Never past capacity, whatever filled the bin while the pawn walked over - a
	# belt, a processor, a restored save. What fits is the room nobody else has
	# promised plus this job's own promise; the rest stays on the pawn for the sweep.
	var amount: int = mini(mini(carried, maxi(job.count, 0)),
		storage.room_for_booking(job.resource, booked))
	if amount <= 0:
		return Status.FAILED
	var stacks: Array[ResourceStack] = job.pawn.inventory_component.withdraw_stacks(job.resource, amount)
	if stacks.is_empty():
		return Status.FAILED
	# Spend the WHOLE reservation, not just what actually landed. The trip is over
	# either way, so any space we booked and did not use has to come back here -
	# consume_claim below drops the record without giving anything back, so a
	# short deposit would otherwise strand the difference as reserved forever.
	if not storage.deposit_reserved(job.resource, stacks, booked):
		# Give it back to the pawn rather than losing it; the sweep retries later.
		job.pawn.inventory_component.add_stacks(job.resource, stacks)
		return Status.FAILED
	# Spent, not released - that space is now genuinely occupied.
	job.consume_claim(bin, ClaimSpec.Kind.STORAGE_DEPOSIT)
	return Status.DONE

func report(job: Job) -> String:
	return "Storing " + (job.resource.name if job.resource != null else "resources")

func _storage(job: Job) -> StorageComponent:
	var slot_target: JobTarget = job.target(slot)
	if slot_target == null:
		return null
	return slot_target.component() as StorageComponent
