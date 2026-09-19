class_name JobDriver_ChangeSuit
extends JobDriver

## Walk to an airlock and change in or out of a pressure suit (WI-67).
##
## Three steps, and the middle one is the whole feature: the WALK is what makes a
## breach dangerous. A crew member whose room has turned harmful is unsuited for
## as long as it takes them to cross the station, taking damage the whole way, so
## how far away the nearest airlock is - a thing the player built - decides
## whether they make it.
##
## `job.count` carries the direction (1 = putting a suit on, 0 = taking it off),
## because make_actions() must be deterministic and a saved action index has to
## mean the same thing after a load. Reading it off the pawn's current state
## instead would rebuild a different sequence for a pawn whose suit changed while
## the save was closed.
##
## No claims: an airlock has no occupancy to book (see Finder_Airlock).

const FIND: int = 0
const GOTO: int = 1
const CHANGE: int = 2

## Sim-seconds at the rack. A constant rather than the component's export, because
## make_actions() runs on unclaimed jobs too (JobManager validates them without a
## pawn) - and because PawnComponentBase is a Node2D, so reaching for a default by
## instantiating one would allocate a node per call and never free it.
const CHANGE_SECONDS: float = 6.0

static func is_putting_on(job: Job) -> bool:
	return job.count != 0

func make_actions(job: Job) -> Array[ActionBase]:
	var putting_on: bool = is_putting_on(job)
	return [
		Action_FindBestTarget.new(Finder_Airlock.new(not putting_on), JobTarget.Slot.A),
		Action_GotoTarget.new(JobTarget.Slot.A),
		Action_ChangeSuit.new(putting_on, JobTarget.Slot.A, CHANGE_SECONDS),
	] as Array[ActionBase]

func can_do(job: Job, pawn: PawnBase) -> bool:
	if pawn.get_component_by_type(PawnSuitComponent) == null:
		return false
	var existing: JobTarget = job.target_a
	if existing != null and existing.is_alive():
		return true
	return Finder_Airlock.new(not is_putting_on(job)).find(job, pawn) != null

func explain_block(job: Job, _pawn: PawnBase) -> String:
	return "no reachable %s" % ("airlock" if is_putting_on(job) else "habitable airlock")

## A refused or broken trip has to tell the component, or it would re-post the
## same job every tick. The action reports the refusals it can see; this catches
## everything else - no airlock found, the route broke, the airlock was
## deconstructed mid-walk.
func on_job_end(job: Job, outcome: Job.Outcome) -> void:
	if outcome == Job.Outcome.SUCCEEDED or job.pawn == null:
		return
	var suit: PawnSuitComponent = job.pawn.get_component_by_type(PawnSuitComponent) as PawnSuitComponent
	if suit != null:
		suit.trip_refused(job)
