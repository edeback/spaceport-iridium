class_name HeatEmitterComponent
extends ComponentBase

## A module that puts heat into the station (WI-60). Authored into the scene like
## [AdjacencyEmitterComponent] and for the same reason: balance lives in data.
##
## Two knobs, and a module may use either or both:
##   - `idle_heat_per_hour` is constant while the module stands - the starting
##     module's heater, a reactor's standing waste heat.
##   - `heat_per_batch` is billed against work actually done, when `processor` is
##     linked. This is the forge case, and it satisfies both halves of the design
##     brief by construction rather than by two formulas that can disagree:
##
##     "only produce heat while working" - the processor's accumulator does not
##     move when it is unpowered, out of inputs, out of output room, or waiting
##     for a worker.
##
##     "produce heat proportional to how much it produces" - the accumulator
##     counts BATCH FRACTIONS, not seconds. A heat throttle multiplies
##     process_time up, so the same wall-clock second buys a smaller fraction of
##     a batch, so this bills proportionally less heat. The negative feedback
##     loop closes itself and no code anywhere knows it is a loop.
##
##     (Counting seconds instead would silently fail: a throttled processor still
##     burns the same seconds, it just gets less out of them.)

## Energy per game-hour while built, regardless of activity.
@export var idle_heat_per_hour: float = 0.0
## Energy released per completed batch's worth of progress. Needs `processor`.
@export var heat_per_batch: float = 0.0
## The machine whose work this bills against. Null for a pure idle emitter.
@export var processor: ProcessorComponent

## Routed through the module's stat layer so an upgrade (a better-insulated
## forge, a hotter smelter) can tune output without touching the scene.
const STAT_HEAT_OUTPUT := &"heat_output"

func ready_constructed() -> void:
	if Global.heat_manager != null:
		Global.heat_manager.register_emitter(self)

func ready_deconstructing() -> void:
	_unregister()

func _exit_tree() -> void:
	_unregister()

func _unregister() -> void:
	if Global.heat_manager != null:
		Global.heat_manager.unregister_emitter(self)

## Energy produced since the last call, and the reason this is `take_` rather
## than `get_`: the processor's batch-fraction accumulator is DRAINED here, so
## work is billed exactly once however often the pass runs.
func take_energy(hours: float) -> float:
	if owner_module == null or not owner_module.is_complete():
		# A module mid-teardown still has to drain, or the work it did before the
		# order would land as a spike the moment it was cancelled.
		_drain_work()
		return 0.0
	var energy: float = _effective(idle_heat_per_hour) * hours
	if processor != null and heat_per_batch > 0.0:
		energy += _effective(heat_per_batch) * _drain_work()
	return energy

func _drain_work() -> float:
	if processor == null:
		return 0.0
	return processor.take_work_fraction()

func _effective(base: float) -> float:
	if owner_module == null or base == 0.0:
		return base
	return owner_module.get_effective_stat(STAT_HEAT_OUTPUT, base)
