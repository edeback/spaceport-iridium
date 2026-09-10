class_name Action_ReservePile
extends ActionBase

## Work out how much of a pile this trip can actually move, write it to
## job.count, and reserve it (WI-44). Instant.
##
## The sizing is the same three-way cap the old pile-collection job's job_start() did by hand -
## what the pile has spare, what the pawn can carry, what the destination has
## room for - but the reservation itself is now a claim, so it comes back on
## every termination path instead of only through _on_cancel.

@export var slot: JobTarget.Slot = JobTarget.Slot.A
## Optional destination whose free space caps the trip. Leaving it unset sizes
## the trip on the pile and the pawn alone.
@export var sink_slot: JobTarget.Slot = JobTarget.Slot.B
@export var use_sink_cap: bool = true

func _init(pile_slot: JobTarget.Slot = JobTarget.Slot.A,
		destination_slot: JobTarget.Slot = JobTarget.Slot.B,
		cap_by_sink: bool = true) -> void:
	slot = pile_slot
	sink_slot = destination_slot
	use_sink_cap = cap_by_sink
	complete_mode = CompleteMode.INSTANT

func on_start(job: Job) -> Status:
	var pile: ResourcePile = _pile(job)
	if pile == null or job.resource == null or job.pawn == null:
		return Status.FAILED
	var stock: PileStock = pile.claim_target_for(job.resource)
	if stock == null:
		return Status.FAILED
	var trip_cap: int = stock.available()
	if job.pawn.inventory_component != null:
		trip_cap = mini(trip_cap, job.pawn.inventory_component.space_available())
	if use_sink_cap:
		var sink: StorageComponent = _sink(job)
		if sink == null:
			return Status.FAILED
		trip_cap = mini(trip_cap, sink.room_for(job.resource))
	if trip_cap <= 0:
		return Status.FAILED
	job.count = trip_cap
	return Status.DONE if job.claim(stock, ClaimSpec.Kind.PILE, trip_cap) != null else Status.FAILED

## Re-sizing on resume is correct: the pile may have been picked over while the
## save sat on disk, and the claim registry hands back an existing record rather
## than double-reserving if resume_job already re-took it.
func on_resume(job: Job) -> Status:
	return on_start(job)

func report(_job: Job) -> String:
	return "Sizing up the pile"

func _pile(job: Job) -> ResourcePile:
	var slot_target: JobTarget = job.target(slot)
	return slot_target.pile() if slot_target != null else null

func _sink(job: Job) -> StorageComponent:
	var slot_target: JobTarget = job.target(sink_slot)
	if slot_target == null or not slot_target.is_alive():
		return null
	return slot_target.component() as StorageComponent
