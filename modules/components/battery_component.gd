class_name BatteryComponent
extends ComponentBase

@export var max_power_throughput: float = 100.0
@export var charge_efficiency: float = 0.85
@export var can_discharge: bool = true
@export var max_power_stored: float = 10000
var total_power_stored: float = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#assert(resource_consumption_per_second == 0.0 or (input_storage != null and resource_consumed != null), "Processor must either not require resource or have resource storage!")
	add_to_group("battery")
	super()

# Returns power actually generated
func generate_power(delta: float, max_required: float) -> float:
	if not can_discharge:
		return 0
	var power_required: float = minf(max_power_throughput, max_required) * delta
	var power_used: float = minf(power_required, total_power_stored)
	total_power_stored -= power_used
	return power_used / delta

# Returns power actually stored
func store_power(delta: float, input_power: float) -> float:
	if total_power_stored >= max_power_stored:
		return 0
	var power_to_store: float = minf(max_power_throughput, input_power) * delta * charge_efficiency
	var power_stored: float = minf(power_to_store, max_power_stored - total_power_stored)
	total_power_stored += power_stored
	return power_stored
