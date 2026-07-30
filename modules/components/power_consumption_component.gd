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
				last_error = ""
				animation_player.play("RESET")
			else:
				last_error = "No power!"
				animation_player.play("no_power")

signal powered_changed(new_power: bool)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()

func ready_preview() -> void:
	pass
	
func ready_blueprint() -> void:
	pass
	
## See PowerGenerationComponent: registration is idempotent because
## ready_constructed can run more than once (instant build, load ready pass).
func ready_constructed() -> void:
	if Global.power_manager != null:
		Global.power_manager.register_consumer(self)

## A module being torn down stops drawing from the grid. `powered` has to go
## false with it: everything that gates work on this flag (processors, mining
## bays, conveyors, logistics bays) would otherwise keep running on a module that
## no longer pays for the privilege.
func ready_deconstructing() -> void:
	powered = false
	if is_instance_valid(Global.power_manager):
		Global.power_manager.unregister_consumer(self)

## Arrays don't drop freed nodes the way the old group did (WI-39), so leaving
## the tree has to unregister explicitly.
func _exit_tree() -> void:
	if is_instance_valid(Global.power_manager):
		Global.power_manager.unregister_consumer(self)
	
func desired_power(delta: float) -> float:
	if force_off:
		return 0
	return power_consumption

func consume_power(delta: float, input_power: float) -> float:
	if force_off:
		powered = false
		return 0
	var consumption := power_consumption
	if input_power >= consumption:
		powered = true
		return consumption
	powered = false
	return input_power

# --- persistence -------------------------------------------------------------
# `force_off` is the player's manual shutdown switch (the info panel's Force
# Shutdown button), not derived state - without a key every module deliberately
# browned out comes back online on load (WI-45 A3). `powered` is NOT saved: the
# next distribution pass re-decides it, and writing it here would fight the
# setter's animation side effects during the load.
#
# Empty dict = pristine, so an untouched station adds nothing to its save.

func get_save_data() -> Dictionary:
	if not force_off:
		return {}
	return {"force_off": true}

func load_save_data(data: Dictionary) -> void:
	force_off = bool(data.get("force_off", false))

func has_ui() -> bool:
	return true

func get_ui() -> ModuleComponentUI:
	var ui: PowerConsumptionComponentUI = ui_info_panel_element.instantiate() as PowerConsumptionComponentUI
	ui.set_power_consumption_component(self)
	return ui
