class_name JobDriver_Construct
extends JobDriver

## Build a module (WI-44) - the replacement for Job_ConstructModule's build half.
## `JobDriver_Deconstruct` is the same two steps with the work running backwards.
##
## Target A is the site's ConstructionComponent. Construction is EVA work: the
## pawn goes OUTSIDE to the module, which is why the walk forces an exterior
## route rather than trusting the target's own interior/exterior answer.
##
## The old job listened for construction_finished / deconstruction_finished and
## carried a module_removed handler. Neither is needed now: completion comes back
## through advance_work(), and a target that stops existing fails the job through
## JobTarget.fail_on_lost.

## Matches Job_ConstructModule.shift_spot_interval - builders visibly move around
## the site instead of standing in one spot.
const SHIFT_SPOT_INTERVAL: float = 3.0

const GOTO: int = 0
const WORK: int = 1

## Whether this driver runs the work backwards. Overridden by the deconstruct
## variant rather than read off job state, so make_actions() stays deterministic.
func reversed() -> bool:
	return false

func make_actions(_job: Job) -> Array[ActionBase]:
	var travel := Action_GotoTarget.new(JobTarget.Slot.A)
	travel.force_exterior = true
	return [
		travel,
		Action_Work.new(JobTarget.Slot.A, reversed(), SHIFT_SPOT_INTERVAL),
	] as Array[ActionBase]

func is_valid(job: Job) -> bool:
	return _construction(job) != null

func can_do(job: Job, pawn: PawnBase) -> bool:
	var construction: ConstructionComponent = _construction(job)
	if construction == null:
		return false
	# Building needs its materials delivered first; deconstruction never does.
	if not reversed() and not construction.ready_for_construction():
		return false
	return Global.path_manager.is_space_reachable(pawn)

func explain_block(job: Job, pawn: PawnBase) -> String:
	var construction: ConstructionComponent = _construction(job)
	if construction == null:
		return "the construction site is gone"
	if not reversed() and not construction.ready_for_construction():
		return "materials haven't been delivered yet"
	if not Global.path_manager.is_space_reachable(pawn):
		return "%s can't get outside (no airlock route)" % pawn.pawn_name
	return ""

func _construction(job: Job) -> ConstructionComponent:
	if job.target_a == null or not job.target_a.is_alive():
		return null
	return job.target_a.component() as ConstructionComponent
