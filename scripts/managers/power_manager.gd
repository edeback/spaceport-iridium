class_name PowerManager
extends Node

## The power-balance participants (WI-39). Maintained by explicit registration
## from the components themselves rather than rebuilt from three
## get_nodes_in_group scans every slow tick.
##
## ORDER IS NOT MEANINGFUL YET. power_modules hands out generation in iteration
## order, so under a deficit whoever comes first stays powered - but that used to
## be scene-tree order and is now registration order, and both are equally
## incidental. Deliberate brownout priority (life support last) is the feature
## these arrays exist to make possible; until it lands, don't read anything into
## the ordering or start relying on it.
var power_generators: Array[PowerGenerationComponent] = []
var power_consumers: Array[PowerConsumptionComponent] = []
var batteries: Array[BatteryComponent] = []

signal power_updated(desired: float, generated: float)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.power_manager = self
	# Power balance runs on the sim slow tick (4 Hz sim-time) instead of every
	# frame; the interval passed is elapsed sim-seconds, so batteries and fuel
	# integrate correctly across pause/fast-forward.
	Global.time_manager.slow_tick.connect(power_modules)

# --- registration -------------------------------------------------------------
# Components register as they go live and unregister as they leave. Everything
# here is idempotent on purpose: BatteryComponent's registration rides
# component_enabled, which the preview -> blueprint -> built transitions toggle,
# and a component that never registered must still be safe to unregister.
#
# Registration goes through these methods rather than exposing the arrays so that
# priority-ordered insertion has exactly one place to land later.

func register_generator(generator: PowerGenerationComponent) -> void:
	if generator != null and not power_generators.has(generator):
		power_generators.append(generator)

func unregister_generator(generator: PowerGenerationComponent) -> void:
	power_generators.erase(generator)

func register_consumer(consumer: PowerConsumptionComponent) -> void:
	if consumer != null and not power_consumers.has(consumer):
		power_consumers.append(consumer)

func unregister_consumer(consumer: PowerConsumptionComponent) -> void:
	power_consumers.erase(consumer)

func register_battery(battery: BatteryComponent) -> void:
	if battery != null and not batteries.has(battery):
		batteries.append(battery)

func unregister_battery(battery: BatteryComponent) -> void:
	batteries.erase(battery)

## Groups dropped freed nodes for free; arrays don't. Every component
## unregisters in _exit_tree, so this should never find anything - but a stale
## entry here is a hard crash rather than a slightly wrong number, so the balance
## pass doesn't trust the arrays it was handed.
func _prune_freed() -> void:
	for i: int in range(power_generators.size() - 1, -1, -1):
		if not is_instance_valid(power_generators[i]):
			power_generators.remove_at(i)
	for i: int in range(power_consumers.size() - 1, -1, -1):
		if not is_instance_valid(power_consumers[i]):
			power_consumers.remove_at(i)
	for i: int in range(batteries.size() - 1, -1, -1):
		if not is_instance_valid(batteries[i]):
			batteries.remove_at(i)

# --- balance ------------------------------------------------------------------

func power_modules(delta: float) -> void:
	_prune_freed()
	var desired_power: float = 0
	for consumer: PowerConsumptionComponent in power_consumers:
		desired_power += consumer.desired_power(delta)

	var power_generated: float = 0
	for generator: PowerGenerationComponent in power_generators:
		power_generated += generator.generate_power(delta)

	power_updated.emit(desired_power, power_generated)

	var power_needed: float = desired_power - power_generated
	if power_needed > 0:
		for battery: BatteryComponent in batteries:
			var battery_generated: float = battery.generate_power(delta, power_needed)
			power_needed -= battery_generated
			power_generated += battery_generated
			if power_needed < 0.000001:
				break

	# Fudge factor that is apparently needed after all this float math
	power_generated += 0.000001
	for consumer: PowerConsumptionComponent in power_consumers:
		power_generated -= consumer.consume_power(delta, power_generated)

	if power_generated > 0:
		for battery: BatteryComponent in batteries:
			power_generated -= battery.store_power(delta, power_generated)
			if power_generated < 0.000001:
				break
