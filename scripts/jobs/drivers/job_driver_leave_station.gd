class_name JobDriver_LeaveStation
extends JobDriver

## Walk out (WI-44) - the replacement for the departure job. Terminal: every path
## through it ends in the pawn despawning.
##
## Target A is the docking bay, and it is the one target in the system that is
## allowed to come back UNSET: crew with no reachable bay get the escape pod
## instead, which is a wait and then the same departure. That is why
## Action_FindBestTarget grew an `optional` flag - the branch belongs in
## next_index_after(), where the driver can see whether the finder found anything.
##
## The crew/visitor split is read off the pawn rather than carried as a job flag.
## the departure job had an exported allow_escape_pod that VisitorManager set to
## false; `is_visitor` is what it was always derived from, so there is one fewer
## knob to set correctly at the post site.

const FIND_BAY: int = 0
const WAIT_POD: int = 1
const GOTO_BAY: int = 2
const DEPART: int = 3

## Sim-hours to wait for the "escape pod" when no bay is reachable.
const ESCAPE_POD_WAIT_HOURS: float = 1.0

func make_actions(_job: Job) -> Array[ActionBase]:
	var find := Action_FindBestTarget.new(Finder_DockingBay.new(), JobTarget.Slot.A)
	find.optional = true
	var walk := Action_GotoTarget.new(JobTarget.Slot.A)
	walk.tolerate_failure = true
	return [
		find,
		Action_Wait.new(ESCAPE_POD_WAIT_HOURS * TimeManager.SECONDS_PER_HOUR),
		walk,
		Action_Depart.new(),
	] as Array[ActionBase]

## A guest needs a real exit - no escape pod (WI-33). Failing here rather than
## despawning them in place is what leaves a stranded visitor on the station to
## re-try once an exit is rebuilt.
func is_valid(job: Job) -> bool:
	if job.pawn == null or not job.pawn.is_visitor:
		return true
	if job.action_index() <= FIND_BAY:
		return true
	return job.target_a != null and job.target_a.is_alive()

func can_do(job: Job, pawn: PawnBase) -> bool:
	if not pawn.is_visitor:
		return true
	return Finder_DockingBay.new().find(job, pawn) != null

func explain_block(_job: Job, _pawn: PawnBase) -> String:
	return "no reachable docking bay to leave from"

## The branch: a bay was found, walk to it; nothing was found, wait for the pod.
## A walk that breaks mid-route falls back to the pod too - the departure job did
## the same, and without it a resigned crew member whose path is cut is stranded
## on the station forever with no job source. That is what the tolerant goto
## buys: the runner would otherwise fail the whole job on a failed move.
func next_index_after(job: Job, finished: int) -> int:
	if finished == FIND_BAY:
		var bay: JobTarget = job.target_a
		return GOTO_BAY if bay != null and bay.is_alive() else WAIT_POD
	if finished == WAIT_POD:
		return DEPART
	if finished == GOTO_BAY and job.movement_state() == Job.MoveState.FAILED:
		return WAIT_POD
	return finished + 1
