class_name PowerGenerationComponent
extends ComponentBase

@export var power_output: float = 100.0
@export var resource_consumed: ResourceData
@export var input_storage: MultiStorageComponent
@export var timer: Timer
## 0 for no consumption at all (like a solar panel)
@export var seconds_per_resource_consumed: float = 0:
	set(new):
		seconds_per_resource_consumed = new
		timer.wait_time = seconds_per_resource_consumed

var powered: bool = false
var force_off: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	assert(seconds_per_resource_consumed == 0.0 or (input_storage != null and resource_consumed != null), "Processor must either not require resource or have resource storage!")
	add_to_group("power_generator")
	timer.wait_time = seconds_per_resource_consumed
	timer.timeout.connect(restart_generation)

func get_power_output() -> float:
	return power_output
	
func disable_generation(disable: bool) -> void:
	if disable != force_off:
		force_off = disable
		if force_off:
			powered = false
			timer.paused = true
		else:
			powered = timer.time_left > 0
			timer.paused = false
		
func restart_generation() -> void:
	if force_off:
		powered = false
		return
	if seconds_per_resource_consumed > 0:
		if timer.is_stopped():
			if input_storage.withdraw(resource_consumed, 1):
				powered = true
				timer.start()
			else:
				powered = false
	else:
		powered = true

func generate_power(_delta: float) -> float:
	restart_generation()
	if powered:
		return get_power_output()
	return 0

func has_ui() -> bool:
	return true
	
func get_ui() -> ModuleComponentUI:
	var ui: PowerGenerationComponentUI = ui_info_panel_element.instantiate() as PowerGenerationComponentUI
	ui.set_power_generation_component(self)
	return ui
	
