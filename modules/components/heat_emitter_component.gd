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

## The grid connection that has to be live for `idle_heat_per_hour` to flow
## (WI-67). Null means unconditional, which is what keeps the starting module's
## trickle and a reactor's standing waste heat exactly as they were - both are
## byproducts of something already running, not machines on a switch.
##
## `heat_per_batch` needs no such link: the processor's accumulator already stops
## when it is unpowered.
@export var power_consumption_component: PowerConsumptionComponent

## Stop heating once the room is warm enough (WI-67). Off for every emitter that
## is a byproduct; on for the Heater, which is the one the player aims.
@export var thermostat_enabled: bool = false
## What the player asked for, in F. Saved, because it is a player decision rather
## than derived state.
@export var target_temperature_f: float = HeatMath.NEUTRAL_TEMPERATURE_F
## How far past the target it coasts before heating again.
##
## NOT optional, and not a nicety. This closes a feedback loop with a heater at
## one end, and a bare threshold in a loop is an oscillator - the same argument
## WI-60 makes for ramping the throttle rather than stepping it. Without the gap a
## heater flickers on and off every pass and the room's temperature buzzes.
@export var thermostat_hysteresis_f: float = 4.0

## Bounds the Status tab's stepper offers. The habitable band, because a heater
## aimed outside it is a heater aimed at hurting the crew.
const TARGET_MIN_F: float = HeatMath.DEFAULT_HABITABLE_LOW_F
const TARGET_MAX_F: float = HeatMath.DEFAULT_HABITABLE_HIGH_F
const TARGET_STEP_F: int = 5

## True while the thermostat is holding the heat off - what the Status tab reads
## to say "idle" rather than leaving the player wondering why nothing is warming.
var _thermostat_satisfied: bool = false

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
	var energy: float = 0.0
	if _idle_heat_flows():
		energy = _effective(idle_heat_per_hour) * hours
	if processor != null and heat_per_batch > 0.0:
		energy += _effective(heat_per_batch) * _drain_work()
	return energy

## Whether the constant half of this emitter is putting anything out right now:
## powered (if it is on the grid at all), and not holding off at temperature.
func _idle_heat_flows() -> bool:
	if power_consumption_component != null and not power_consumption_component.powered:
		return false
	if not thermostat_enabled:
		return true
	if Global.heat_manager == null or owner_module == null:
		return true
	var here: float = Global.heat_manager.temperature_at(owner_module)
	# Hysteresis, read off the LAST answer rather than recomputed from scratch:
	# heating until the target then coasting until it falls a few degrees below is
	# what stops the pass toggling this every quarter hour.
	if _thermostat_satisfied:
		_thermostat_satisfied = here > target_temperature_f - thermostat_hysteresis_f
	else:
		_thermostat_satisfied = here >= target_temperature_f
	return not _thermostat_satisfied

## For the Status tab: is this emitter idle because the room is warm enough?
func thermostat_holding() -> bool:
	return thermostat_enabled and _thermostat_satisfied

## For the Status tab's stepper, which writes on `value_changed` only.
func set_target_temperature(degrees_f: float) -> void:
	target_temperature_f = clampf(degrees_f, TARGET_MIN_F, TARGET_MAX_F)

func _drain_work() -> float:
	if processor == null:
		return 0.0
	return processor.take_work_fraction()

func _effective(base: float) -> float:
	if owner_module == null or base == 0.0:
		return base
	return owner_module.get_effective_stat(Stats.HEAT_OUTPUT, base)

# --- persistence (WI-67) -------------------------------------------------------
#
# The setpoint is a player decision, so it saves - the storage-priority rule. Only
# a thermostatted emitter writes anything, so no other module's save block moves.

func save_order() -> int:
	return 66

func save_key() -> StringName:
	return &"heat_emitter"

func get_save_data() -> Dictionary:
	if not thermostat_enabled:
		return {}
	return {"target_f": target_temperature_f}

func load_save_data(data: Dictionary) -> void:
	if data.has("target_f"):
		set_target_temperature(float(data["target_f"]))
