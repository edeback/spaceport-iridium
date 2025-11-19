class_name PowerConsumptionComponent
extends ComponentBase

@export var power_consumption: float = 10.0
@export var capacitator: float = 0.0
@export var animation_player: AnimationPlayer
@export var force_off: bool = false

var powered: bool = true:
	get:
		return powered
	set(new_powered):
		if powered != new_powered:
			powered = new_powered
			powered_changed.emit(powered)
			if powered:
				animation_player.play("RESET")
			else:
				animation_player.play("no_power")

signal powered_changed(new_power: bool)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("power_consumer")
	super()

	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func desired_power(delta: float) -> float:
	if force_off:
		return 0
	return power_consumption

func consume_power(delta: float, input_power: float) -> float:
	if force_off:
		powered = false
		return 0
	var consumption = power_consumption
	if input_power >= consumption:
		powered = true
		return consumption
	powered = false
	return input_power

func has_ui() -> bool:
	return true
	
func get_ui() -> ModuleComponentUI:
	var ui: PowerConsumptionComponentUI = ui_info_panel_element.instantiate() as PowerConsumptionComponentUI
	ui.set_power_consumption_component(self)
	return ui
