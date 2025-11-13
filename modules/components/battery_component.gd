class_name BatteryComponent
extends ComponentBase

@export var max_power_throughput: float = 100.0
@export var power_per_resource: float = 100.0
@export var power_resource: ResourceData
@export var energy_storage: MultiStorageComponent
@export var charge_efficiency: float = 0.85
@export var can_discharge: bool = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#assert(resource_consumption_per_second == 0.0 or (input_storage != null and resource_consumed != null), "Processor must either not require resource or have resource storage!")
	add_to_group("battery")
	super()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# Returns power actually generated
func generate_power(delta: float, max_required: float) -> float:
	if not can_discharge:
		return 0
	var power_required: float = min(max_power_throughput, max_required)
	var resources_to_use: float = min(power_required/power_per_resource * delta, energy_storage.cur_stored.get_or_add(power_resource, 0))
	var power_generated: float = resources_to_use * power_per_resource / delta
	energy_storage.withdraw(power_resource, resources_to_use)
	return power_generated

# Returns power actually stored
func store_power(delta: float, input_power: float) -> float:
	var space_available: float = energy_storage.space_available()
	if space_available < 0.000001:
		return 0
	var power_to_store: float = min(max_power_throughput, input_power)
	var resources_to_store: float = min(power_to_store / power_per_resource * delta * charge_efficiency, space_available)
	var power_stored: float = resources_to_store * power_per_resource / delta / charge_efficiency
	energy_storage.deposit(power_resource, resources_to_store)
	return power_stored
