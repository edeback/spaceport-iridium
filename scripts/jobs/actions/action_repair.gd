class_name Action_Repair
extends Action_Work

## Patching up a damaged module (WI-44) - the work half of Job_Repair.
##
## Subclasses Action_Work for the anchor animation and the shift-spot shuffle,
## but replaces the tick: repair is the one work loop that genuinely isn't a
## single counter. It heals HP, seals an open breach much faster than the
## emergency bulkhead would on its own, and clears a lingering breakdown once
## enough work is banked - three effects with three different completion terms,
## which is why this didn't collapse into the generic advance_work() adapter.
##
## The banked hours ARE saved: a breakdown that is half worked off must not reset
## to zero because the player saved mid-repair.

## HP restored per game-hour at work_rate 1.0.
@export var repair_rate: float = 60.0
## Breach sealing runs this many times faster than the emergency self-seal.
@export var breach_seal_multiplier: float = 5.0
## Game-hours of work needed to clear a lingering breakdown modifier.
@export var breakdown_repair_hours: float = 0.5

## Sim-hours of effective work banked so far, already folded with skill/happiness.
var _work_hours: float = 0.0

func _init(target_slot: JobTarget.Slot = JobTarget.Slot.A) -> void:
	super(target_slot, false, 3.0)
	use_anchor_animation = true

func tick(job: Job, delta: float) -> Status:
	var module: ModuleBase = _module(job)
	if module == null or job.pawn == null:
		return Status.FAILED
	_shift_spot(job, delta)
	# delta arrives already sim-scaled; work_rate folds happiness x skill (WI-22).
	var work_hours: float = (delta * job.pawn.work_rate(job.get_skill())) / TimeManager.SECONDS_PER_HOUR
	_work_hours += work_hours
	module.repair(repair_rate * work_hours)
	var atmosphere: AtmosphereComponent = module.get_atmosphere()
	if atmosphere != null and atmosphere.is_breached():
		atmosphere.advance_seal(work_hours * breach_seal_multiplier)
	if module.has_breakdown() and _work_hours >= breakdown_repair_hours:
		module.clear_breakdown()
	return Status.ONGOING

func check(job: Job) -> Status:
	var module: ModuleBase = _module(job)
	if module == null:
		return Status.FAILED
	return Status.DONE if not module.needs_repair() else Status.ONGOING

func save_state() -> Dictionary:
	return {"hours": _work_hours} if _work_hours > 0.0 else {}

func load_state(data: Dictionary) -> void:
	_work_hours = float(data.get("hours", 0.0))

func report(_job: Job) -> String:
	return "Repairing"

func _module(job: Job) -> ModuleBase:
	var destination: JobTarget = job.target(slot)
	if destination == null or not destination.is_alive():
		return null
	return destination.module()
