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

@export var slot: JobTarget.Slot = JobTarget.Slot.A
@export var kind: ClaimSpec.Kind = ClaimSpec.Kind.STORAGE_WITHDRAW
## Narrow job.count to what this trip can actually move before reserving. Only
## the withdraw side does this; the deposit side then reserves whatever the
## withdraw settled on, so the two halves cannot disagree about the amount.
@export var narrow_to_trip: bool = false

func _init(target_slot: JobTarget.Slot = JobTarget.Slot.A,
		claim_kind: ClaimSpec.Kind = ClaimSpec.Kind.STORAGE_WITHDRAW,
		narrow: bool = false) -> void:
	slot = target_slot
	kind = claim_kind
	narrow_to_trip = narrow
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
	if job.count <= 0:
		return Status.FAILED
	# A deposit into a catch-all bin may be its first unit of this resource, so the
	# slot is grown here rather than found missing (see claim_target_for).
	var bin: StorageData = storage.claim_target_for(job.resource,
		kind == ClaimSpec.Kind.STORAGE_DEPOSIT)
	if bin == null:
		return Status.FAILED
	return Status.DONE if job.claim(bin, kind, job.count) != null else Status.FAILED

## Re-claiming is idempotent (the registry hands back the existing record), and a
## resume has usually already re-taken this through required_claims - but routing
## through on_start again keeps the narrowing consistent if it hasn't.
func on_resume(job: Job) -> Status:
	return on_start(job)

func report(_job: Job) -> String:
	return "Reserving space" if kind == ClaimSpec.Kind.STORAGE_DEPOSIT else "Reserving stock"

func _storage(job: Job) -> StorageComponent:
	var slot_target: JobTarget = job.target(slot)
	if slot_target == null:
		return null
	return slot_target.component() as StorageComponent
