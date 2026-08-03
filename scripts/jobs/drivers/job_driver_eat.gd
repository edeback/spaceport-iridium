class_name JobDriver_Eat
extends JobDriver

## Go and eat something (WI-44) - the replacement for the eat job.
##
## Target A is the sustenance pool. Three actions, no claim: a pool has no slots,
## so nothing is booked and nothing needs releasing - which is also why the meal
## can take an hour without anyone queueing behind it. The re-validation that
## the eat job did by hand on arrival ("eat from the component we chose and walked
## to, not whatever module we happen to be standing in") is structural now - the
## action reads the slot, and a pool that died on the way fails the job through
## the target's own liveness check.
##
## The last step is the long one: Action_Eat serves the whole portion at once and
## then holds the pawn at the table for the serving module's meal_duration_hours.
## Nothing else needs to know that - the runner owns the clock, and a meal cut
## short is handled inside the action.

const FIND: int = 0
const GOTO: int = 1
const EAT: int = 2

## Portion a pawn tries to take, shared by the finder (which prefers a pool that
## can serve a whole one) and the action.
const PORTION: int = 70

func make_actions(_job: Job) -> Array[ActionBase]:
	return [
		Action_FindBestTarget.new(Finder_Sustenance.new(PORTION), JobTarget.Slot.A),
		Action_GotoTarget.new(JobTarget.Slot.A),
		Action_Eat.new(JobTarget.Slot.A, PORTION),
	] as Array[ActionBase]

## A needs job goes straight onto the pawn's personal queue with no target, so
## validity is "is there anywhere with food" - answered by the finder.
func can_do(job: Job, pawn: PawnBase) -> bool:
	var existing: JobTarget = job.target_a
	if existing != null and existing.is_alive():
		return true
	return Finder_Sustenance.new(PORTION).find(job, pawn) != null

func explain_block(_job: Job, pawn: PawnBase) -> String:
	if pawn != null and pawn.is_visitor:
		# can_serve holds visitors back until the pool is above the crew reserve.
		return "no food to spare for guests"
	return "nowhere reachable has any food"
