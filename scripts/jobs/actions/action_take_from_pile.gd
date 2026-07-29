class_name Action_TakeFromPile
extends ActionBase

## Lift job.count out of the pile in a slot and onto the pawn (WI-44). Instant.
##
## The pile's own withdraw_stacks() already decrements the reservation by what it
## actually handed over, so the claim is SPENT, not released - same accounting as
## Action_TakeFromStorage. Anything reserved but not gathered (the pile shrank
## under us) is given back explicitly, because consuming the whole record would
## strand that remainder as permanently reserved.

@export var slot: JobTarget.Slot = JobTarget.Slot.A

func _init(pile_slot: JobTarget.Slot = JobTarget.Slot.A) -> void:
	slot = pile_slot
	complete_mode = CompleteMode.INSTANT
	carries_cargo = true

func on_start(job: Job) -> Status:
	var slot_target: JobTarget = job.target(slot)
	var pile: ResourcePile = slot_target.pile() if slot_target != null else null
	if pile == null or job.resource == null or job.pawn == null \
			or job.pawn.inventory_component == null:
		return Status.FAILED
	var stock: PileStock = pile.claim_target_for(job.resource)
	var gathered: Array[ResourceStack] = pile.withdraw_stacks(job.resource, job.count)
	if gathered.is_empty():
		return Status.FAILED
	var gathered_total: int = 0
	for stack: ResourceStack in gathered:
		gathered_total += stack.amount
	# Hand back whatever we reserved but did not get, THEN drop the record. The
	# withdraw spent the rest of it.
	if gathered_total < job.count and stock != null:
		pile.cancel_reservation(job.resource, job.count - gathered_total)
	job.consume_claim(stock, ClaimSpec.Kind.PILE)
	job.count = gathered_total
	# The pile despawns itself the moment it empties, and from here on the job
	# does not need it - the goods are physically on the pawn. Marking the target
	# survivable is what stops Job._targets_alive() failing the trip on the walk
	# home, and it round-trips through the save as `soft`.
	slot_target.fail_on_lost = false
	var leftover: Array[ResourceStack] = job.pawn.inventory_component.add_stacks(job.resource, gathered)
	if not leftover.is_empty():
		# Shouldn't happen - the trip was sized against the pawn's free space -
		# but hand it back rather than destroying it.
		pile.add_stacks(job.resource, leftover)
	return Status.DONE

## Already carrying it: re-running on_start would take a second load against a
## reservation that no longer exists.
func on_resume(job: Job) -> Status:
	if job.pawn != null and job.resource != null \
			and job.pawn.inventory_component != null \
			and job.pawn.inventory_component.get_carried_amount(job.resource) > 0:
		return Status.DONE
	return on_start(job)

func report(job: Job) -> String:
	return "Gathering " + (job.resource.name if job.resource != null else "resources")
