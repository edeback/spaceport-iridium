class_name PowerGenerationComponent
extends ComponentBase

@export var power_output: float = 100.0
@export var resource_consumption_per_second: float = 0.0
@export var resource_consumed: ResourceData
@export var input_storage: MultiStorageComponent

var powered: bool = false
var force_off: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	assert(resource_consumption_per_second == 0.0 or (input_storage != null and resource_consumed != null), "Processor must either not require resource or have resource storage!")
	add_to_group("power_generator")

func get_power_output() -> float:
	return power_output

func generate_power(delta: float) -> float:
	if force_off:
		powered = false
		return 0
	if resource_consumption_per_second > 0:
		if input_storage == null or resource_consumed == null:
			powered = false
			return 0
		var consumption_amount: float = delta * resource_consumption_per_second
		if input_storage.can_withdraw(resource_consumed, consumption_amount):
			input_storage.withdraw(resource_consumed, consumption_amount)
			powered = true
			return get_power_output()
	else:
		powered = true
		return get_power_output()
	powered = false
	return 0

func has_ui() -> bool:
	return true
	
func get_ui() -> ModuleComponentUI:
	var ui: PowerGenerationComponentUI = ui_info_panel_element.instantiate() as PowerGenerationComponentUI
	ui.set_power_generation_component(self)
	return ui
	
