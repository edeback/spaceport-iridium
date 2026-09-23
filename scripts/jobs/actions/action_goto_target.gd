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
## Route through space regardless of what the target says. Construction and
## exterior repair are EVA jobs - the pawn goes OUTSIDE to work on the module,
## even though a module target is normally an interior destination.
@export var force_exterior: bool = false
## Report a broken route as DONE rather than failing the job, leaving the driver
## to read job.movement_state() in next_index_after() and branch. Only the
## departure job wants this (a walk that breaks mid-route falls back to the escape
## pod); for everything else a failed walk genuinely is a failed job.
@export var tolerate_failure: bool = false:
	set(value):
		tolerate_failure = value
		# CONDITION hands the arrival test to check(); MOVEMENT keeps it in the
		# runner, where a broken route is unconditionally fatal.
		complete_mode = CompleteMode.CONDITION if value else CompleteMode.MOVEMENT

func _init(target_slot: JobTarget.Slot = JobTarget.Slot.A, move_speed: float = 1.0) -> void:
	slot = target_slot
	speed = move_speed
	complete_mode = CompleteMode.MOVEMENT

func on_start(job: Job) -> Status:
	var destination: JobTarget = job.target(slot)
	if destination == null or not destination.is_alive():
		return Status.DONE if _lost_but_survivable(destination) else Status.FAILED
	# An exterior job means going outside to the module, so "already inside it"
	# is not the same place and must not short-circuit the walk.
	if skip_if_present and not force_exterior and _pawn_is_already_there(job, destination):
		return Status.DONE
	var node: Node2D = destination.move_node()
	if node == null:
		return Status.FAILED
	if not job.begin_movement(node, speed, force_exterior or destination.is_exterior()):
		return Status.FAILED
	return Status.ONGOING

## A walk saved with the pawn is picked up where it stood (WI-75) - part way along
## its path, waiting at an airlock door, in a turbolift queue or aboard a cab -
## so a reload changes nothing. Asked before on_start's "already there" check on
## purpose: a pawn saved crossing the module it is bound for is not there yet.
## With no walk to pick up (a save from before WI-75, or one written the frame the
## pawn arrived), this is on_start, which re-paths from wherever the pawn loaded.
func on_resume(job: Job) -> Status:
	var destination: JobTarget = job.target(slot)
	if destination != null and destination.is_alive():
		var in_space: bool = force_exterior or destination.is_exterior()
		if job.resume_movement(destination.move_node(), speed, in_space):
			return Status.ONGOING
	return on_start(job)

## A destination the job declared survivable can be freed mid-walk - an asteroid
## another drone mined dry is the routine case. The walk is simply over at that
## point: the driver reads the emptied slot in next_index_after() and picks the
## next thing, exactly as it does when a rock runs out underfoot. Watched every
## frame here rather than left to the movement watch, because that reports a
## freed destination as a failed route, which for a hard target it genuinely is.
func tick(job: Job, _delta: float) -> Status:
	return Status.DONE if _lost_but_survivable(job.target(slot)) else Status.ONGOING

## True for a target that was set, is flagged fail_on_lost = false, and has since
## been freed. A target the job DOES depend on is left alone - Job's own
## aliveness check fails the trip for those.
func _lost_but_survivable(destination: JobTarget) -> bool:
	if destination == null or not destination.is_set() or destination.fail_on_lost:
		return false
	return not destination.is_alive()

## Only consulted when tolerate_failure put this action in CONDITION mode; it
## mirrors the runner's MOVEMENT handling except that a broken route reads as
## finished rather than failed.
func check(job: Job) -> Status:
	match job.movement_state():
		Job.MoveState.ARRIVED, Job.MoveState.FAILED:
			return Status.DONE
	return Status.ONGOING

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
