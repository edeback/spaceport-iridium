class_name BatteryComponent
extends ComponentBase

# MW or kW
@export var max_power_throughput: float = 100.0
@export var charge_efficiency: float = 0.85
@export var can_discharge: bool = true
# MWh or kWh
@export var max_power_stored: float = 10000
var total_power_stored: float = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()

func ready_preview() -> void:
	component_enabled = false
	
func ready_blueprint() -> void:
	component_enabled = false
	
func ready_constructed() -> void:
	component_enabled = true

## The battery is the one power component whose participation rides
## component_enabled, which the preview/blueprint/built transitions toggle - so
## both directions can fire more than once and both are no-ops when they do.
func _on_enabled() -> void:
	if Global.power_manager != null:
		Global.power_manager.register_battery(self)

func _on_disabled() -> void:
	if is_instance_valid(Global.power_manager):
		Global.power_manager.unregister_battery(self)

## A bank in a module being torn down stops charging and discharging. Expressed
## as component_enabled rather than a bare unregister so the "participation ==
## component_enabled" invariant above keeps holding; the charge itself just
## freezes where it was, and dies with the module.
func ready_deconstructing() -> void:
	component_enabled = false

## component_enabled stays true through deletion, so _on_disabled never runs on
## the way out; the registry array (unlike the group it replaced) needs telling.
func _exit_tree() -> void:
	if is_instance_valid(Global.power_manager):
		Global.power_manager.unregister_battery(self)


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

# --- persistence (WI-39) ------------------------------------------------------

## The charge bank is mutable runtime state with nowhere else to live: without
## this every battery reloads empty, and a station running its night cycle off
## reserve silently comes back with none. Same shape as the shield capacitor
## (WI-38 A2) so the two read identically.
## Sits beside the shield for symmetry, but unlike the shield it has NO ordering
## requirement: max_power_stored is a plain @export, so load_save_data clamps
## against a constant. If battery capacity ever becomes upgradeable, this has to
## stay after UPGRADE_SAVE_ORDER for real, exactly as the shield does.
func save_order() -> int:
	return UPGRADE_SAVE_ORDER + 20

func save_key() -> StringName:
	return &"battery"

func get_save_data() -> Dictionary:
	return {"stored": total_power_stored}

## Absent key = pristine (the sustenance/shop/shield convention), so pre-WI-39
## saves load with empty banks exactly as they do today.
##
## Unlike the shield, max_power_stored is a plain @export and is NOT routed
## through get_effective_stat, so this clamps against a constant and load order
## relative to ModuleBase's upgrades block doesn't matter. If battery capacity
## ever becomes upgradeable, this has to move behind get_effective_stat and be
## restored after upgrades, exactly as ShieldComponent's is.
func load_save_data(data: Dictionary) -> void:
	total_power_stored = clampf(float(data.get("stored", total_power_stored)), 0.0, max_power_stored)
