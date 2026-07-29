class_name Action_Work
extends ActionBase

## Stand at a thing and put work seconds into it until it is done (WI-44).
##
## The generic version of the "push a progress bar at the pawn's work rate" loop
## that construction, deconstruction, repair, processor operation and doctoring
## each wrote out by hand. Rate is always `delta * pawn.work_rate(skill)` - which
## folds happiness and the job's skill together, floored (WI-22) - and the target
## decides what that actually means through one duck-typed adapter:
##
##   advance_work(seconds: float) -> bool    # true once the work is finished
##
## ProcessorComponent already had exactly that signature; the others gained it.
## Putting the per-system detail behind the adapter is the point: repair's three
## effects (heal HP, seal a breach, clear a breakdown) are the module's business,
## not the job's.

@export var slot: JobTarget.Slot = JobTarget.Slot.A
## Feed work in negative - deconstruction runs the same counter backwards.
@export var reverse: bool = false
## Reposition the pawn somewhere else on the module every N sim-seconds, so a
## build crew visibly moves around instead of standing in one spot. 0 = never.
@export var shift_spot_interval: float = 0.0

var _done: bool = false
var _shift_elapsed: float = 0.0

func _init(target_slot: JobTarget.Slot = JobTarget.Slot.A, work_backwards: bool = false,
		shift_interval: float = 0.0) -> void:
	slot = target_slot
	reverse = work_backwards
	shift_spot_interval = shift_interval
	complete_mode = CompleteMode.CONDITION

func tick(job: Job, delta: float) -> Status:
	var component: ComponentBase = _component(job)
	if component == null or job.pawn == null:
		return Status.FAILED
	if not component.has_method(&"advance_work"):
		return Status.FAILED
	_shift_spot(job, delta)
	# delta arrives already sim-scaled from the runner.
	var seconds: float = delta * job.pawn.work_rate(job.get_skill())
	if reverse:
		seconds = -seconds
	_done = bool(component.call(&"advance_work", seconds))
	return Status.ONGOING

func check(_job: Job) -> Status:
	return Status.DONE if _done else Status.ONGOING

func _shift_spot(job: Job, delta: float) -> void:
	if shift_spot_interval <= 0.0:
		return
	_shift_elapsed += delta
	if _shift_elapsed < shift_spot_interval:
		return
	_shift_elapsed = 0.0
	var destination: JobTarget = job.target(slot)
	var module: ModuleBase = destination.module() if destination != null else null
	if module != null and is_instance_valid(module):
		job.pawn.global_position = module.get_random_position_on_module()

## Nothing to save: the progress itself lives on the component being worked on
## (construction seconds, the processor's batch), and those already persist. Only
## the cosmetic shift-spot timer is lost, which is worth nothing.
func report(_job: Job) -> String:
	return "Deconstructing" if reverse else "Working"

func _component(job: Job) -> ComponentBase:
	var destination: JobTarget = job.target(slot)
	if destination == null or not destination.is_alive():
		return null
	return destination.component()
