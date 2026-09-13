class_name Action_ReserveStorage
extends ActionBase

## Reserve stock to take out of, or space to put into, the storage in a slot
## (WI-44). Instant.
##
## The claim is taken against the per-resource StorageData rather than the
## component - see StorageData's claimable contract for why - and it is released
## automatically when the job ends, whatever ends it. That is the whole of the
## reservation discipline that used to be hand-written into every job's
## _on_cancel and _on_end.
##
## The deposit side is where a trip learns how big it may be. A GENERAL or OUTPUT
## deposit claim is bookkeeping only - its bound is the component's pool, which
## StorageData cannot see - so nothing downstream refuses a reservation bigger
## than the room behind it. find_sink() only needs one free unit to pick a bin,
## so every haul into a nearly-full storeroom used to book a whole trip against
## its last few units and deliver the lot (a start module at 87/80). The trip is
## now cut to the room first, and the pickup end's reservation, already taken, is
## cut with it.

@export var slot: JobTarget.Slot = JobTarget.Slot.A
@export var kind: ClaimSpec.Kind = ClaimSpec.Kind.STORAGE_WITHDRAW
## Narrow job.count to what this trip can carry and what the source holds before
## reserving. Only the withdraw side does this; the deposit side narrows to the
## sink's room instead, and the two narrowings together are the trip.
@export var narrow_to_trip: bool = false
## Where the goods are picked up - the end reserved BEFORE this one. Read only on
## the deposit side, when the sink's room cuts the trip short and that earlier
## reservation has to shrink to match. A storage (a haul) or a pile (a collection).
@export var pickup_slot: JobTarget.Slot = JobTarget.Slot.A

func _init(target_slot: JobTarget.Slot = JobTarget.Slot.A,
		claim_kind: ClaimSpec.Kind = ClaimSpec.Kind.STORAGE_WITHDRAW,
		narrow: bool = false,
		pickup: JobTarget.Slot = JobTarget.Slot.A) -> void:
	slot = target_slot
	kind = claim_kind
	narrow_to_trip = narrow
	pickup_slot = pickup
	complete_mode = CompleteMode.INSTANT

func on_start(job: Job) -> Status:
	var storage: StorageComponent = _storage(job)
	if storage == null or job.resource == null:
		return Status.FAILED
	if narrow_to_trip:
		# What this specific trip can actually move: capped by what the pawn can
		# carry and by what the source has right now. A later trip picks up any
		# remainder - this just stops a job failing outright because nowhere
		# reachable happens to hold the ENTIRE original request.
		var trip_cap: int = StorageQuery.trip_cap(job.pawn, job.count)
		job.count = mini(trip_cap, storage.total_stored_by_resource(job.resource))
	if kind == ClaimSpec.Kind.STORAGE_DEPOSIT:
		# Room nobody else has promised, plus whatever this job already booked here.
		# Measured before the slot is grown below, so a bin with no room fails
		# without being littered with an empty slot for the resource.
		var room: int = storage.room_for_booking(job.resource, _booked(job, storage))
		if room <= 0:
			return Status.FAILED
		_shorten_trip(job, room)
	if job.count <= 0:
		return Status.FAILED
	# A deposit into a catch-all bin may be its first unit of this resource, so the
	# slot is grown here rather than found missing (see claim_target_for).
	var bin: StorageData = storage.claim_target_for(job.resource,
		kind == ClaimSpec.Kind.STORAGE_DEPOSIT)
	if bin == null:
		return Status.FAILED
	if job.claim(bin, kind, job.count) == null:
		return Status.FAILED
	# Re-claiming hands back an existing record at the size it was first taken;
	# it must not outlast a trip that has since been cut shorter.
	job.shrink_claim(bin, kind, job.count)
	return Status.DONE

## Re-claiming is idempotent (the registry hands back the existing record), and a
## resume has usually already re-taken this through required_claims - but routing
## through on_start again keeps the narrowing consistent if it hasn't.
func on_resume(job: Job) -> Status:
	return on_start(job)

func report(_job: Job) -> String:
	return "Reserving space" if kind == ClaimSpec.Kind.STORAGE_DEPOSIT else "Reserving stock"

## Deposit this job already holds on `storage` - room for this job, not against it.
func _booked(job: Job, storage: StorageComponent) -> int:
	var bin: StorageData = storage.claim_target_for(job.resource)
	if bin == null:
		return 0
	var spec: ClaimSpec = job.find_claim(bin, ClaimSpec.Kind.STORAGE_DEPOSIT)
	return spec.amount if spec != null else 0

## Cuts this trip down to `amount` and gives back the part of the pickup
## reservation it no longer needs. The two halves must never disagree: the pickup
## step takes job.count and then consumes (or, for a pile, settles against
## job.count) the whole record, so a reservation sized for the longer trip would
## strand the difference as reserved forever.
func _shorten_trip(job: Job, amount: int) -> void:
	if amount >= job.count:
		return
	job.count = amount
	var pickup: JobTarget = job.target(pickup_slot)
	if pickup == null or not pickup.is_alive():
		return
	var source: StorageComponent = pickup.component() as StorageComponent
	if source != null:
		var source_bin: StorageData = source.claim_target_for(job.resource)
		if source_bin != null:
			job.shrink_claim(source_bin, ClaimSpec.Kind.STORAGE_WITHDRAW, amount)
		return
	var pile: ResourcePile = pickup.pile()
	if pile != null:
		job.shrink_claim(pile.claim_target_for(job.resource), ClaimSpec.Kind.PILE, amount)

func _storage(job: Job) -> StorageComponent:
	var slot_target: JobTarget = job.target(slot)
	if slot_target == null:
		return null
	return slot_target.component() as StorageComponent
