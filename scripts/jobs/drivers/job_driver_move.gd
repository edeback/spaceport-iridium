class_name JobDriver_Move
extends JobDriver

## "Walk over there" (WI-44) - the replacement for the move job.
##
## Target A is the destination module. The whole job is one action, which is the
## point: the seventy-two-line class this replaces was two thirds movement
## plumbing and serialization, all of which is now shared.

func make_actions(_job: Job) -> Array[ActionBase]:
	return [Action_GotoTarget.new(JobTarget.Slot.A)] as Array[ActionBase]

func is_valid(job: Job) -> bool:
	return job.target_a != null and job.target_a.is_alive()

func can_do(job: Job, pawn: PawnBase) -> bool:
	var destination: ModuleBase = job.target_a.module() if job.target_a != null else null
	if destination == null:
		return false
	return Global.path_manager.is_reachable(pawn, destination)

func explain_block(job: Job, pawn: PawnBase) -> String:
	if job.target_a == null or not job.target_a.is_alive():
		return "destination is gone"
	if job.target_a.module() == null:
		return "destination has no module"
	if not Global.path_manager.is_reachable(pawn, job.target_a.module()):
		return "no route from %s" % pawn.pawn_name
	return ""
