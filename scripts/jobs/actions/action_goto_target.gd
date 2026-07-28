class_name Action_GotoTarget
extends ActionBase

## Walk the pawn to one of the job's target slots (WI-44).
##
## This one action replaces the twenty-two hand-rolled
## `movement_ended.connect(..., CONNECT_ONE_SHOT)` sites across eighteen job
## files, each with its own `_ended` guard and its own "did we actually arrive"
## branch. The signal plumbing and the stale-callback latch live in Job's runner
## now; all that's left here is picking the node to walk to.

@export var slot: JobTarget.Slot = JobTarget.Slot.A
@export var speed: float = 1.0
## Skip the walk entirely when the pawn is already inside the destination module.
## This is what makes a restored job cheap: a pawn saved standing at the
## workstation resumes without re-pathing to where it already is.
@export var skip_if_present: bool = true

func _init(target_slot: JobTarget.Slot = JobTarget.Slot.A, move_speed: float = 1.0) -> void:
	slot = target_slot
	speed = move_speed
	complete_mode = CompleteMode.MOVEMENT

func on_start(job: Job) -> Status:
	var destination: JobTarget = job.target(slot)
	if destination == null or not destination.is_alive():
		return Status.FAILED
	if skip_if_present and _pawn_is_already_there(job, destination):
		return Status.DONE
	var node: Node2D = destination.move_node()
	if node == null:
		return Status.FAILED
	if not job.begin_movement(node, speed, destination.is_exterior()):
		return Status.FAILED
	return Status.ONGOING

## Deliberately the same as on_start: re-pathing from wherever the pawn actually
## loaded is both correct and cheap, and matches the CONVEYED contract (WI-20),
## which already re-runs pathfinding from the drop-off floor rather than resuming
## a path index. Full path persistence was considered and rejected in the WI.
func on_resume(job: Job) -> Status:
	return on_start(job)

func report(job: Job) -> String:
	var destination: JobTarget = job.target(slot)
	if destination == null or not destination.is_set():
		return "Walking"
	return "Walking to " + destination.describe()

func _pawn_is_already_there(job: Job, destination: JobTarget) -> bool:
	if job.pawn == null:
		return false
	var module: ModuleBase = destination.module()
	# An exterior target (asteroid, free-floating pile) has no module, and a pawn
	# outside has a null current_module - without this guard those two nulls
	# compare equal and every EVA trip would be skipped.
	if module == null:
		return false
	return job.pawn.current_module == module
