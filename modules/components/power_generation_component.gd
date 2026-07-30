class_name PowerGenerationComponent
extends ComponentBase

@export var power_output: float = 100.0
@export var resource_consumed: ResourceData
@export var input_storage: StorageComponent
## 0 for no consumption at all (like a solar panel). Fuel burn is tracked in
## sim-seconds (the delta generate_power receives comes from the sim slow
## tick), so it pauses and fast-forwards with the game.
@export var seconds_per_resource_consumed: float = 0

var powered: bool = false
var force_off: bool = false
## Sim-seconds of burn left on the currently loaded fuel unit.
var _fuel_seconds_left: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	assert(seconds_per_resource_consumed == 0.0 or (input_storage != null and resource_consumed != null), "Processor must either not require resource or have resource storage!")

func ready_preview() -> void:
	pass
	
func ready_blueprint() -> void:
	pass
	
## Registration is idempotent, which matters because ready_constructed is not
## guaranteed to run exactly once: the instant-build path routes ready_blueprint
## straight into it, and the load path runs its own ready pass.
func ready_constructed() -> void:
	if Global.power_manager != null:
		Global.power_manager.register_generator(self)

## A module being torn down stops feeding the grid, rather than generating right
## up until the last plate comes off. `powered` goes with it so the info panel
## doesn't keep claiming an output nothing is collecting.
func ready_deconstructing() -> void:
	powered = false
	if is_instance_valid(Global.power_manager):
		Global.power_manager.unregister_generator(self)

## The registry is a plain array, so unlike the group it replaced it does not
## drop freed nodes on its own (WI-39). WorldManager.remove_module reparents the
## module out before queue_free, so this fires on both the deletion and the
## scene-teardown path.
func _exit_tree() -> void:
	if is_instance_valid(Global.power_manager):
		Global.power_manager.unregister_generator(self)

## Stat key routed through the owner module's modifier layer so damage (WI-24)
## and future upgrades scale generation without touching the base export.
const STAT_POWER_OUTPUT := &"power_output"

func get_power_output() -> float:
	if owner_module != null:
		return owner_module.get_effective_stat(STAT_POWER_OUTPUT, power_output)
	return power_output

func disable_generation(disable: bool) -> void:
	if disable != force_off:
		force_off = disable
		if force_off:
			powered = false
		else:
			# Already-loaded fuel resumes burning; fuel-free generators
			# re-power on the next generate_power call.
			powered = _fuel_seconds_left > 0.0 or seconds_per_resource_consumed == 0.0

func restart_generation() -> void:
	if force_off:
		powered = false
		return
	if seconds_per_resource_consumed > 0:
		if _fuel_seconds_left <= 0.0:
			if input_storage.withdraw(resource_consumed, 1):
				powered = true
				_fuel_seconds_left = seconds_per_resource_consumed
			else:
				powered = false
	else:
		powered = true

func generate_power(delta: float) -> float:
	if seconds_per_resource_consumed > 0 and powered and not force_off:
		_fuel_seconds_left = maxf(_fuel_seconds_left - delta, 0.0)
	restart_generation()
	if powered:
		return get_power_output()
	return 0

# --- persistence -------------------------------------------------------------
# Same reasoning as PowerConsumptionComponent (WI-45 A3): `force_off` is the
# player's manual shutdown switch. `_fuel_seconds_left` rides along because a
# generator restored mid-burn would otherwise withdraw a whole fresh unit on its
# first tick - the partial burn it already paid for is real state, not a cache.
# `powered` is derived and re-decided below from the two restored values.

func get_save_data() -> Dictionary:
	var data: Dictionary = {}
	if force_off:
		data["force_off"] = true
	if _fuel_seconds_left > 0.0:
		data["fuel_seconds"] = _fuel_seconds_left
	return data

func load_save_data(data: Dictionary) -> void:
	# Fuel first: both branches below judge `powered` against it.
	_fuel_seconds_left = maxf(float(data.get("fuel_seconds", 0.0)), 0.0)
	if bool(data.get("force_off", false)):
		disable_generation(true)
	elif _fuel_seconds_left > 0.0:
		# Mirrors disable_generation's resume branch, and is load-bearing rather
		# than cosmetic: restart_generation() only powers up on the tick it has to
		# withdraw a FRESH unit, and generate_power() only burns fuel while
		# powered - so a restored half-burnt generator with powered still false
		# would sit dark forever, never burning and never re-withdrawing.
		powered = true

func has_ui() -> bool:
	return true

func get_ui() -> ModuleComponentUI:
	var ui: PowerGenerationComponentUI = ui_info_panel_element.instantiate() as PowerGenerationComponentUI
	ui.set_power_generation_component(self)
	return ui
	
