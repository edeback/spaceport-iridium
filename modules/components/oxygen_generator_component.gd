class_name OxygenGeneratorComponent
extends ComponentBase

## O2 generator (WI-17): consumes the stored `oxygen` resource (hauled in by
## the normal pull-job flow - electrolyzer output or trader purchases) and
## releases it into the local atmosphere whenever local pressure sits below
## the target setpoint. The only thing in the game that RAISES pressure -
## counters hull breaches and the dilution from newly built modules.
##
## Hysteresis band below the setpoint prevents flapping: release starts at
## target - hysteresis and runs until target is reached (WI-17 edge case).

## Local total pressure the generator holds the station at.
## Slightly higher than "normal" (100) pressure to keep air flowing
@export var target_pressure: float = 105.0
## Release re-engages only once pressure falls this far below target.
@export var hysteresis: float = 5.0
## Atmosphere units released per game-hour while active - fast enough to
## visibly fight a breach, via get_effective_stat(&"o2_release_rate").
## 100 = enough to fill one cell with o2
@export var release_rate_per_hour: float = 150.0
## Atmosphere units one unit of stored oxygen resource expands into.
@export var units_per_canister: float = 100.0
@export var storage_bay: StorageComponent
@export var oxygen_resource: ResourceData
@export var power_consumption_component: PowerConsumptionComponent

## Gas from an already-consumed canister not yet released (saved with the
## module so cracking a canister never destroys resources across save/load).
var buffer: float = 0.0
var _releasing: bool = false

func _ready() -> void:
	super()
	set_process(false)

func ready_preview() -> void:
	set_process(false)

func ready_blueprint() -> void:
	set_process(false)

func ready_constructed() -> void:
	set_process(true)

func _process(delta: float) -> void:
	var sim_hours: float = Global.time_manager.scale(delta) / TimeManager.SECONDS_PER_HOUR
	if sim_hours <= 0.0:
		return
	if power_consumption_component != null and not power_consumption_component.powered:
		return
	var atmosphere: AtmosphereComponent = owner_module.get_component_by_type(AtmosphereComponent) as AtmosphereComponent
	if atmosphere == null:
		return
	var pressure: float = atmosphere.pressure()
	if _releasing:
		if pressure >= target_pressure:
			_releasing = false
	elif pressure < target_pressure - hysteresis:
		_releasing = true
	if not _releasing:
		last_error = ""
		return
	if buffer <= 0.0 and storage_bay != null and storage_bay.withdraw(oxygen_resource, 1):
		buffer += units_per_canister
	if buffer <= 0.0:
		last_error = "No oxygen supply!"
		return
	last_error = ""
	var rate: float = owner_module.get_effective_stat(&"o2_release_rate", release_rate_per_hour)
	var release: float = minf(buffer, rate * sim_hours)
	atmosphere.add_o2(release)
	buffer -= release

# --- persistence -------------------------------------------------------------

func save_order() -> int:
	return 70

func save_key() -> StringName:
	return &"o2_generator"

func get_save_data() -> Dictionary:
	if buffer <= 0.0:
		return {}
	return {"buffer": buffer}

func load_save_data(data: Dictionary) -> void:
	buffer = float(data.get("buffer", 0.0))
