class_name ShieldComponent
extends ComponentBase

## A shield generator's projected bubble (WI-32). Radiates a circular zone that
## soaks pirate laser hits landing inside it, draining a capacitor by the hit's
## damage. The capacitor recharges through the host module's power draw; when it
## empties the bubble goes offline (hysteresis) until it recharges past a
## re-engage fraction, so a trickle of charge can't flicker the shield on for one
## shot and collapse again.
##
## RaidManager owns hit routing: on every pirate hit it asks the "shield" group
## which online bubble covers the impact (most-charge wins) via ShieldMath, then
## calls absorb() on the winner. The bubble even protects its own emitter - the
## generator sits inside its own radius by construction.

## Bubble radius in pixels. Sized per variant / raised by local upgrades through
## get_effective_stat, so upgrades read non-destructively.
@export var radius_px: float = 260.0
## Max stored charge (one charge unit soaks one damage point).
@export var capacity: float = 220.0
## Charge restored per game-hour while powered.
@export var charge_rate_per_hour: float = 90.0
## Offline until charge climbs back to this fraction of capacity (hysteresis).
@export var reengage_fraction: float = 0.25
## The bubble emitter starts a fresh generator this full (0..1), so a shield
## built before a raid isn't dead weight on its first fight.
@export var initial_charge_fraction: float = 1.0
@export var power_consumption_component: PowerConsumptionComponent

var _charge: float = 0.0
var _online: bool = true
## Wall-clock seconds left on the absorb flash (cosmetic, so it ignores pause).
var _flash_time: float = 0.0
const FLASH_SECONDS: float = 0.18

func ready_constructed() -> void:
	add_to_group(Groups.SHIELD)
	_charge = capacity * clampf(initial_charge_fraction, 0.0, 1.0)
	_online = _charge > 0.0
	# Capacitor integrates on the sim slow tick (interval = elapsed sim-seconds),
	# so charge survives pause / fast-forward exactly like power and batteries.
	if Global.time_manager != null and not Global.time_manager.slow_tick.is_connected(_on_slow_tick):
		Global.time_manager.slow_tick.connect(_on_slow_tick)
	queue_redraw()

func powered() -> bool:
	return power_consumption_component == null or power_consumption_component.powered

## World-space centre of the bubble - the module's own centre.
func center() -> Vector2:
	return owner_module.get_global_center() if owner_module != null else global_position

func radius() -> float:
	return owner_module.get_effective_stat(&"shield_radius", radius_px) if owner_module != null else radius_px

func effective_capacity() -> float:
	return owner_module.get_effective_stat(&"shield_capacity", capacity) if owner_module != null else capacity

func charge() -> float:
	return _charge

func is_online() -> bool:
	return _online

func charge_fraction() -> float:
	var cap: float = effective_capacity()
	return clampf(_charge / cap, 0.0, 1.0) if cap > 0.0 else 0.0

## Snapshot for ShieldMath.select_absorber.
func bubble() -> ShieldMath.Bubble:
	return ShieldMath.Bubble.new(center(), radius(), _charge, _online)

## Soak one hit: consume charge equal to the damage (may empty the bank), then
## re-evaluate the online/offline hysteresis. Called only after selection already
## confirmed this bubble covers the impact and is online.
func absorb(damage: float) -> void:
	_charge = maxf(_charge - damage, 0.0)
	_online = ShieldMath.next_online(_online, _charge, effective_capacity(), reengage_fraction)
	_flash_time = FLASH_SECONDS
	queue_redraw()

func _on_slow_tick(sim_seconds: float) -> void:
	if not powered():
		return
	var cap: float = effective_capacity()
	if _charge >= cap:
		return
	var per_hour: float = owner_module.get_effective_stat(&"shield_charge_rate", charge_rate_per_hour) if owner_module != null else charge_rate_per_hour
	_charge = minf(_charge + per_hour * (sim_seconds / TimeManager.SECONDS_PER_HOUR), cap)
	_online = ShieldMath.next_online(_online, _charge, cap, reengage_fraction)
	queue_redraw()

# --- VFX ----------------------------------------------------------------------

func _process(delta: float) -> void:
	if _flash_time <= 0.0:
		return
	_flash_time = maxf(_flash_time - delta, 0.0)
	queue_redraw()

## Faint bubble while charged, brightening on an absorb flash. Drawn in local
## space around the module centre; a depleted (offline) shield shows nothing.
func _draw() -> void:
	if owner_module == null:
		return
	var frac: float = charge_fraction()
	if frac <= 0.0 and _flash_time <= 0.0:
		return
	var here: Vector2 = to_local(center())
	var r: float = radius()
	var flash: float = _flash_time / FLASH_SECONDS
	var base_alpha: float = (0.10 + 0.14 * frac) if _online else 0.05
	var alpha: float = clampf(base_alpha + 0.5 * flash, 0.0, 0.8)
	var tint := Color(0.45, 0.75, 1.0, alpha)
	draw_arc(here, r, 0.0, TAU, 48, tint, 2.0 + 3.0 * flash, true)
	draw_circle(here, r, Color(0.4, 0.7, 1.0, alpha * 0.18))

# --- info-panel UI ------------------------------------------------------------

func has_ui() -> bool:
	return true

func get_ui() -> ModuleComponentUI:
	var ui := ShieldComponentUI.new()
	ui.set_module(owner_module)
	ui.setup(self)
	return ui

# --- persistence --------------------------------------------------------------

## AFTER the upgrades block (WI-38 A2): effective_capacity() reads the
## upgrade-modified stat, and the restored charge is clamped against it. This is
## the one vanilla component whose position in the chain is a correctness
## requirement rather than a convention.
func save_order() -> int:
	return UPGRADE_SAVE_ORDER + 10

func save_key() -> StringName:
	return &"shield"

func get_save_data() -> Dictionary:
	return {"charge": _charge, "online": _online}

## Absent key = pristine, i.e. whatever ready_constructed's initial_charge_fraction
## left behind (the sustenance/shop convention).
func load_save_data(data: Dictionary) -> void:
	# Clamp to the *upgraded* capacity. ModuleBase restores this after the upgrades
	# block for exactly that reason: a save written with a capacity upgrade whose id
	# no longer resolves (load_upgrade_save_data warns and skips it) would otherwise
	# restore more charge than the bank it now has.
	_charge = clampf(float(data.get("charge", _charge)), 0.0, effective_capacity())
	# Restore the saved hysteresis state rather than re-deriving it - a bubble that
	# was knocked offline has to stay offline until it recharges past
	# reengage_fraction, or a mid-raid save/load hands the player a free shield.
	_online = bool(data.get("online", _charge > 0.0))
	queue_redraw()
