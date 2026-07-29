class_name JobDriver_IdleWander
extends JobDriver

## Drifting about with nothing to do (WI-44) - the replacement for
## the wander job. Not saveable: idle is the fallback a pawn lands in anyway, so
## there is nothing worth persisting.
##
## Ambles at 0.4 speed rather than marching, then claims a STAND anchor in the
## destination so idlers spread out inside a module instead of stacking on one
## spot. The old job only spread when it noticed other idlers present; the anchor
## claim gets there structurally, since a spot someone already holds simply is
## not offered to the next pawn.

const FIND: int = 0
const GOTO: int = 1
const SPREAD: int = 2

const AMBLE_SPEED: float = 0.4

func make_actions(_job: Job) -> Array[ActionBase]:
	var spread := Action_GotoAnchor.new(JobTarget.Slot.A, AnchorDef.AnchorType.STAND)
	spread.speed = AMBLE_SPEED
	return [
		Action_FindBestTarget.new(Finder_WanderDestination.new(), JobTarget.Slot.A),
		Action_GotoTarget.new(JobTarget.Slot.A, AMBLE_SPEED),
		spread,
	] as Array[ActionBase]

func can_do(job: Job, pawn: PawnBase) -> bool:
	var existing: JobTarget = job.target_a
	if existing != null and existing.is_alive():
		return true
	return Finder_WanderDestination.new().find(job, pawn) != null

func explain_block(_job: Job, _pawn: PawnBase) -> String:
	return "nowhere reachable to wander to"
