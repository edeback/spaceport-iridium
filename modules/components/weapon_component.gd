class_name WeaponComponent
extends ComponentBase

## Station point-defense (WI-32). Auto-fires at the nearest pirate ship inside a
## firing arc + range while a raid is on. The arc faces "outward" - away from the
## station centroid - so a turret studded on the top of the hull covers the space
## above it and two turrets on different faces get genuinely different coverage,
## with no per-placement authoring (the design's "exterior-facing, derived from
## orientation").
##
## Power: the turret idles at a low draw and jumps to a heavy draw only while it
## actually has a ship to shoot ("actively used"). It never touches the
## PowerConsumptionComponent's force_off flag - that's the player's manual
## on/off. A battery of engaged turrets is a heavy load that drains reserves and
## can brown itself out (the "power death spiral" - firing needs the module
## powered). Per-shot energy is modelled as that active draw (WI-28's "keep the
## power model simple" precedent).

@export var damage: float = 34.0
@export var range_px: float = 820.0
## Sim-seconds between shots.
@export var fire_interval: float = 1.6
## Half-angle of the firing arc, in degrees. >= 180 = omnidirectional.
@export var arc_half_width_deg: float = 105.0
@export var power_consumption_component: PowerConsumptionComponent
## Standby draw with nothing to shoot (low, but not zero - the guns are warm).
@export var idle_power_consumption: float = 8.0
## Draw while actively engaging a target (the heavy load).
@export var active_power_consumption: float = 60.0

## Stretch (WI-23 manned bonus), shipped OFF for v1: a gunner assigned to a
## WorkspaceComponent here would scale damage/rate by their Accuracy skill. Left
## inert until a later pass wires it - the auto-turret is the v1 baseline.
@export var manned_bonus_enabled: bool = false

## Outward aim direction, cached per raid (the station centroid shifts as modules
## are destroyed, but re-deriving once per raid is plenty).
var _outward_dir := Vector2.RIGHT
var _outward_valid: bool = false
var _fire_cooldown: float = 0.0
## True while a target sits in range + arc - the "actively used" power state.
var _engaging: bool = false

## Cosmetic beam flash, faded on wall-clock delta (ignores pause), like the ship.
var _beam_time: float = 0.0
var _beam_to := Vector2.ZERO
const BEAM_FLASH_SECONDS: float = 0.12

func ready_constructed() -> void:
	# Only need the raid signal to re-derive aim against the current station
	# shape; power is driven per-frame off engagement below. Guarded against a
	# double ready pass (matches the durability-tick idiom).
	if not SignalBus.raid_started.is_connected(_on_raid_started):
		SignalBus.raid_started.connect(_on_raid_started)
	# A turret finishing construction mid-raid missed the raid_started emission
	# that normally invalidates aim, so re-derive it against the station shape as
	# it is now.
	_outward_valid = false
	_engaging = false
	_apply_power()

func _on_raid_started(_strength: float) -> void:
	_outward_valid = false # re-derive aim against the current station shape

func _raid_active() -> bool:
	return Global.raid_manager != null and Global.raid_manager.active

## Push the idle/active draw onto the power component. Never touches force_off -
## that stays the player's manual kill switch.
func _apply_power() -> void:
	if power_consumption_component != null:
		power_consumption_component.power_consumption = active_power_consumption if _engaging else idle_power_consumption

func _set_engaging(engaging: bool) -> void:
	if engaging == _engaging:
		return
	_engaging = engaging
	_apply_power()

func _process(delta: float) -> void:
	_tick_beam(delta)
	# Build-state gate (WI-38 A1). Deliberately *after* the beam tick, so a turret
	# that finishes construction mid-flash doesn't leave a frozen beam on screen.
	# Without this a blueprint turret targets, fires and draws active_power, which
	# lets a player drop turret blueprints mid-raid for free defense.
	if owner_module == null or not owner_module.is_complete():
		return
	var sim_delta: float = Global.time_manager.scale(delta)
	if sim_delta <= 0.0:
		return
	if _fire_cooldown > 0.0:
		_fire_cooldown -= sim_delta
	var target: PirateShip = _pick_target() if _raid_active() else null
	_set_engaging(target != null)
	if target == null or not is_powered() or _fire_cooldown > 0.0:
		return
	_fire_cooldown = effective_fire_interval()
	_fire_at(target)

func is_powered() -> bool:
	return power_consumption_component == null or power_consumption_component.powered

# --- computed stats (also read by the info-panel UI) --------------------------

func effective_damage() -> float:
	return _stat(&"weapon_damage", damage)

func effective_fire_interval() -> float:
	return _stat(&"weapon_fire_interval", fire_interval)

func effective_range() -> float:
	return _stat(&"weapon_range", range_px)

func _fire_at(target: PirateShip) -> void:
	target.apply_damage(effective_damage())
	_beam_time = BEAM_FLASH_SECONDS
	_beam_to = target.global_position
	queue_redraw()

## Nearest live ship within range AND inside the firing arc, or null.
func _pick_target() -> PirateShip:
	var origin: Vector2 = _muzzle()
	var reach: float = effective_range()
	var reach2: float = reach * reach
	var best: PirateShip = null
	var best_d2: float = INF
	for node: Node in get_tree().get_nodes_in_group("pirate_ship"):
		var ship: PirateShip = node as PirateShip
		if ship == null or not is_instance_valid(ship):
			continue
		var to_ship: Vector2 = ship.global_position - origin
		var d2: float = to_ship.length_squared()
		if d2 > reach2 or d2 >= best_d2:
			continue
		if not _in_arc(to_ship):
			continue
		best = ship
		best_d2 = d2
	return best

func _in_arc(to_ship: Vector2) -> bool:
	if arc_half_width_deg >= 180.0:
		return true
	_ensure_outward()
	return absf(_outward_dir.angle_to(to_ship)) <= deg_to_rad(arc_half_width_deg)

func _muzzle() -> Vector2:
	return owner_module.get_global_center() if owner_module != null else global_position

## Outward = from the station centroid toward this turret. Falls back to straight
## up if the turret somehow sits exactly on the centroid (single-module station).
func _ensure_outward() -> void:
	if _outward_valid:
		return
	_outward_valid = true
	var centroid := Vector2.ZERO
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group("module"):
		var module: ModuleBase = node as ModuleBase
		if module == null:
			continue
		centroid += module.get_global_center()
		count += 1
	if count > 0:
		centroid /= float(count)
	var dir: Vector2 = _muzzle() - centroid
	_outward_dir = dir.normalized() if dir.length() > 1.0 else Vector2.UP

func _stat(stat: StringName, base: float) -> float:
	return owner_module.get_effective_stat(stat, base) if owner_module != null else base

# --- info-panel UI ------------------------------------------------------------

func has_ui() -> bool:
	return true

func get_ui() -> ModuleComponentUI:
	var ui := WeaponComponentUI.new()
	ui.set_module(owner_module)
	ui.setup(self)
	return ui

# --- VFX ----------------------------------------------------------------------

func _tick_beam(real_delta: float) -> void:
	if _beam_time <= 0.0:
		return
	_beam_time = maxf(_beam_time - real_delta, 0.0)
	queue_redraw()

func _draw() -> void:
	if _beam_time <= 0.0:
		return
	var alpha: float = _beam_time / BEAM_FLASH_SECONDS
	var color := Color(0.5, 1.0, 0.6, alpha)
	draw_line(to_local(_muzzle()), to_local(_beam_to), color, 2.5, true)
	draw_circle(to_local(_beam_to), 6.0 * alpha, color)
