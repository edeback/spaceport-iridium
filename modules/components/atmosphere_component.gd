class_name AtmosphereComponent
extends ComponentBase

## Per-module atmosphere (WI-17): O2 and CO2 in abstract units. Pressure is
## amount / volume, with 100 per cell as the nominal "fully pressurized" level.
## Two gases only: breathing (O2->CO2) and scrubbing (CO2->O2) are 1:1 swaps,
## so they conserve total pressure by construction - only the O2 generator
## raises it and only breaches/expansion lower it. High CO2 is never directly
## toxic; it harms by displacing the O2 partial.
##
## Instances are attached at runtime by AtmosphereManager to every module with
## a PathComponent on a non-SPACE layer (the "pawn-enterable interior" rule
## lives in one place there, not in fifteen scenes). Simulation state only
## exists while Built: registration happens in ready_constructed and the gas
## is destroyed with the module - no back-fill, no leak on delete.

## Pressure units per cell at nominal ("fully pressurized") level.
@export var nominal_pressure: float = 100.0
## Exponential vent rate while breached, per game-hour. 4.0 means the module
## is at ~2% of its gas after one hour - near-vacuum well inside the hour.
@export var breach_vent_rate_per_hour: float = 4.0

var o2: float = 0.0
var co2: float = 0.0
## Game-hours until the emergency bulkheads self-seal; 0 = not breached.
var breach_remaining_hours: float = 0.0

func _ready() -> void:
	# Runtime-attached: AtmosphereManager sets owner_module before add_child
	# (ComponentBase._ready derives it from the scene `owner`, which runtime
	# nodes don't have). Keep the components-array registration either way.
	if owner_module == null:
		owner_module = get_parent_module()
	if owner_module != null and not owner_module.components.has(self):
		owner_module.components.append(self)
	set_process(false)

func ready_preview() -> void:
	_unregister()

func ready_blueprint() -> void:
	_unregister()

func ready_constructed() -> void:
	if Global.atmosphere_manager != null:
		Global.atmosphere_manager.register_component(self)
	set_process(true)

func _exit_tree() -> void:
	_unregister()

func _unregister() -> void:
	set_process(false)
	# Gas (and any open breach) dies with the module - deliberate (WI-17).
	breach_remaining_hours = 0.0
	if Global.atmosphere_manager != null:
		Global.atmosphere_manager.unregister_component(self)

func volume() -> float:
	if owner_module == null:
		return 1.0
	return float(maxi(owner_module.size.x * owner_module.size.y, 1))

func pressure() -> float:
	return (o2 + co2) / volume()

func o2_partial() -> float:
	return o2 / volume()

func co2_partial() -> float:
	return co2 / volume()

## Fill with pure O2 at nominal pressure - new-game seeding for the starting
## station so the player has breathing room before building life support.
func seed_full_o2() -> void:
	o2 = nominal_pressure * volume()
	co2 = 0.0

## Crew respiration: converts up to `amount` O2 into CO2, returns the amount
## actually converted (limited by available O2). Conserves total pressure.
func breathe(amount: float) -> float:
	var actual: float = minf(amount, o2)
	o2 -= actual
	co2 += actual
	return actual

## Scrubber conversion: CO2 back into O2, limited by available CO2. Returns
## the amount converted. Conserves total pressure.
func convert_co2_to_o2(amount: float) -> float:
	var actual: float = minf(amount, co2)
	co2 -= actual
	o2 += actual
	return actual

func add_o2(amount: float) -> void:
	o2 += maxf(amount, 0.0)

func is_breached() -> bool:
	return breach_remaining_hours > 0.0

## Opens (or extends) a hull breach. A second strike on the same module
## refreshes the timer to at least `duration_hours` - leak rates never stack.
func start_breach(duration_hours: float) -> void:
	var was_breached: bool = is_breached()
	breach_remaining_hours = maxf(breach_remaining_hours, duration_hours)
	if not was_breached and is_breached():
		SignalBus.module_breach_started.emit(owner_module)
		# CRITICAL (WI-53): a timer is running toward suffocation and bulkhead
		# loss, and it is running whether or not the player is looking at this
		# part of the station. [AlertManager] drops the alert again when
		# `module_breach_sealed` fires, by either seal path.
		AlertManager.raise_alert(AlertRules.make_id(&"breach", owner_module),
			AlertData.Priority.CRITICAL, "Hull breach",
			"%s · seals in %.1fh" % [_module_name(), breach_remaining_hours], owner_module,
			&"", "%d hull breaches are open")

## Accelerated sealing driven by a repair worker (WI-24). A pawn patching the
## hull closes the breach far faster than the emergency-bulkhead self-seal (the
## WI-17 timer stays the slow fallback). Reuses the same countdown, so it emits
## module_breach_sealed at zero exactly like the self-seal path.
func advance_seal(hours: float) -> void:
	if hours <= 0.0 or not is_breached():
		return
	breach_remaining_hours -= hours
	if breach_remaining_hours <= 0.0:
		breach_remaining_hours = 0.0
		SignalBus.module_breach_sealed.emit(owner_module)
		SignalBus.station_alert.emit("Repairs sealed the breach in %s." % _module_name())

func _process(delta: float) -> void:
	var sim_hours: float = Global.time_manager.scale(delta) / TimeManager.SECONDS_PER_HOUR
	if sim_hours <= 0.0 or not is_breached():
		return
	# Exponential decay toward vacuum; both gases leak at the same rate so
	# composition stays constant while the pressure collapses.
	var keep: float = exp(-breach_vent_rate_per_hour * sim_hours)
	o2 *= keep
	co2 *= keep
	if o2 < 0.01:
		o2 = 0.0
	if co2 < 0.01:
		co2 = 0.0
	breach_remaining_hours -= sim_hours
	if breach_remaining_hours <= 0.0:
		breach_remaining_hours = 0.0
		SignalBus.module_breach_sealed.emit(owner_module)
		SignalBus.station_alert.emit("Emergency bulkheads sealed the breach in %s." % _module_name())

func _module_name() -> String:
	if owner_module != null and owner_module.module_data != null:
		return owner_module.module_data.name
	return "module"

func has_ui() -> bool:
	return ui_info_panel_element != null and owner_module != null and owner_module.is_complete()

func get_ui() -> ModuleComponentUI:
	var ui: AtmosphereComponentUI = ui_info_panel_element.instantiate() as AtmosphereComponentUI
	ui.set_atmosphere_component(self)
	return ui

# --- persistence -------------------------------------------------------------

func save_order() -> int:
	return 60

func save_key() -> StringName:
	return &"atmosphere"

func get_save_data() -> Dictionary:
	var out: Dictionary = {"o2": o2, "co2": co2}
	if is_breached():
		out["breach"] = breach_remaining_hours
	return out

func load_save_data(data: Dictionary) -> void:
	o2 = float(data.get("o2", o2))
	co2 = float(data.get("co2", co2))
	# Restore silently: the alert already fired when the breach opened.
	breach_remaining_hours = float(data.get("breach", 0.0))
