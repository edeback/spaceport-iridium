class_name PirateShip
extends Sprite2D

## A raider that orbits the station and strafes its exposed modules (WI-32).
## Patterned on ArrivalShuttle's hand-rolled sim-scaled flight (tweens would
## ignore pause and game speed), but persistent: it lives for the whole raid,
## owned and tracked by RaidManager.
##
## Flight has no collision with anything - ships glide between orbit waypoints
## on a ring outside the station's footprint. Targeting ray-marches from the
## ship toward the station centre and fires at the first EXPOSED module on the
## line (never interior-through-hull); shields get first refusal on every hit.

## Pixels per sim-second.
@export var speed: float = 140.0
@export var max_hp: float = 120.0
## Damage per laser hit, before shields.
@export var laser_damage: float = 22.0
## Sim-seconds between shots while a target is in range.
@export var fire_interval: float = 2.5
## Chance a laser hit on an atmosphere module also tears a hull breach.
@export var breach_chance: float = 0.25
@export var breach_duration_hours: float = 2.0
## Retreats and despawns once HP drops below this fraction of max.
@export var flee_hp_fraction: float = 0.25
## A target beyond this world distance is out of range - hold fire.
@export var fire_range: float = 1000.0
## Sprite tint marking the ship as hostile.
@export var hostile_tint: Color = Color(1.0, 0.55, 0.55)

var hp: float = -1.0

var _manager: RaidManager
var _orbit_center: Vector2
var _orbit_radius: float = 600.0
## Angle (radians) of the current orbit waypoint; advances each time one is
## reached, sweeping the ship around the ring.
var _angle: float = 0.0
## +1 / -1 orbit direction, rolled per ship so a wave spreads both ways.
var _spin: float = 1.0
var _angle_step: float = 0.5
var _waypoint: Vector2
var _target: ModuleBase = null
var _fire_cooldown: float = 0.0
var _fleeing: bool = false
## Distance from the orbit centre past which a fleeing ship is gone for good.
var _despawn_radius: float = 2600.0

## Cosmetic beam flash (WI-32): seconds of wall-clock life left on the last
## laser draw. Purely visual, so it fades on real delta and ignores pause.
var _beam_time: float = 0.0
var _beam_from := Vector2.ZERO
var _beam_to := Vector2.ZERO
var _beam_absorbed: bool = false
const BEAM_FLASH_SECONDS: float = 0.14

func _ready() -> void:
	add_to_group("pirate_ship")
	self_modulate = hostile_tint
	if hp < 0.0:
		hp = max_hp

## Spawn-time wiring from RaidManager. `spawn_radius` starts the ship far out so
## it visibly flies in during the raid warning; the first waypoint sits on the
## orbit ring, pulling it toward the station.
func setup(manager: RaidManager, orbit_center: Vector2, orbit_radius: float, spawn_radius: float, start_angle: float, spin: float) -> void:
	_manager = manager
	_orbit_center = orbit_center
	_orbit_radius = orbit_radius
	_angle = start_angle
	_spin = spin
	_despawn_radius = maxf(spawn_radius, orbit_radius) + 400.0
	global_position = orbit_center + Vector2.from_angle(_angle) * spawn_radius
	_waypoint = _orbit_center + Vector2.from_angle(_angle) * _orbit_radius

func _process(delta: float) -> void:
	_tick_beam(delta)
	var sim_delta: float = Global.time_manager.scale(delta)
	if sim_delta <= 0.0:
		return
	_fly(sim_delta)
	if _fleeing:
		return
	_ensure_target()
	_tick_fire(sim_delta)

# --- flight -------------------------------------------------------------------

func _fly(sim_delta: float) -> void:
	global_position = global_position.move_toward(_waypoint, speed * sim_delta)
	flip_h = _waypoint.x < global_position.x
	if _fleeing:
		if global_position.distance_to(_orbit_center) >= _despawn_radius:
			_depart()
		return
	if global_position.distance_to(_waypoint) <= 4.0:
		# Reached the ring point - sweep to the next and re-evaluate the target
		# (a new angle exposes different hull).
		_angle += _angle_step * _spin
		_waypoint = _orbit_center + Vector2.from_angle(_angle) * _orbit_radius
		_target = null

func flee() -> void:
	if _fleeing:
		return
	_fleeing = true
	_target = null
	var outward: Vector2 = (global_position - _orbit_center)
	if outward.length() < 1.0:
		outward = Vector2.from_angle(_angle)
	_waypoint = _orbit_center + outward.normalized() * (_despawn_radius + 200.0)

## Called by RaidManager on payoff: leave peacefully, no parting shots.
func stand_down() -> void:
	flee()

# --- targeting ----------------------------------------------------------------

func _ensure_target() -> void:
	if _target != null and is_instance_valid(_target) and _target.is_complete() and _target.hp > 0.0:
		return
	_target = _pick_target()

## Ray-march from the ship toward the station centre; the first exposed,
## damageable module on the line is the target.
func _pick_target() -> ModuleBase:
	var world: WorldManager = Global.world_manager
	if world == null:
		return null
	var cell: Vector2i = RaidTargeting.first_occupied_cell(
		global_position, _orbit_center, Global.CELL_SIZE,
		func(c: Vector2i) -> bool: return _valid_target_at(c) != null)
	if cell == RaidTargeting.NONE:
		return null
	return _valid_target_at(cell)

## The damageable module occupying `cell` on any structural (non-space) layer, or
## null. Skips wrecked truss (hp 0) so raiders don't waste fire on dead hull.
func _valid_target_at(cell: Vector2i) -> ModuleBase:
	var world: WorldManager = Global.world_manager
	for layer: WorldManager.StructureLayer in [
			WorldManager.StructureLayer.MODULE,
			WorldManager.StructureLayer.CORRIDOR,
			WorldManager.StructureLayer.TURBOLIFT]:
		var module: ModuleBase = world.get_module_by_cell(layer, cell)
		if module != null and module.is_complete() and module.hp > 0.0:
			return module
	return null

# --- firing -------------------------------------------------------------------

func _tick_fire(sim_delta: float) -> void:
	if _fire_cooldown > 0.0:
		_fire_cooldown -= sim_delta
	if _target == null or not is_instance_valid(_target):
		return
	var impact: Vector2 = _target.get_global_center()
	if global_position.distance_to(impact) > fire_range:
		return
	if _fire_cooldown > 0.0:
		return
	_fire_cooldown = fire_interval
	_fire_at(_target, impact)

func _fire_at(target: ModuleBase, impact: Vector2) -> void:
	# Shields get first refusal: an absorbed hit flashes on the bubble and never
	# touches the module.
	var absorbed: bool = _manager != null and _manager.try_shield_absorb(impact, laser_damage)
	_flash_beam(impact, absorbed)
	if absorbed:
		return
	var atmo: AtmosphereComponent = target.get_atmosphere()
	# Roll the breach BEFORE apply_damage: a killing shot frees the module, after
	# which the atmosphere component is gone (matches the WI-24 raid effect order).
	if atmo != null and randf() < breach_chance:
		atmo.start_breach(breach_duration_hours)
	target.apply_damage(laser_damage, &"pirate_laser")

# --- taking damage ------------------------------------------------------------

## Station weapons call this. Crossing the flee threshold turns the ship for
## home; 0 HP destroys it (RaidManager drops salvage and clears it from the wave).
func apply_damage(amount: float) -> void:
	if amount <= 0.0 or hp <= 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	if _manager != null:
		_manager.note_pirate_damage(amount)
	queue_redraw()
	if hp <= 0.0:
		_destroyed()
		return
	if not _fleeing and hp <= max_hp * flee_hp_fraction:
		flee()

func _destroyed() -> void:
	if _manager != null:
		_manager.report_ship_destroyed(self)
	queue_free()

func _depart() -> void:
	if _manager != null:
		_manager.report_ship_departed(self)
	queue_free()

# --- persistence --------------------------------------------------------------

func get_save_data() -> Dictionary:
	return {
		"pos": [global_position.x, global_position.y],
		"hp": hp,
		"angle": _angle,
		"spin": _spin,
		"fleeing": _fleeing,
		"cooldown": _fire_cooldown,
	}

## Restore mid-raid state. Called after setup() has seeded the orbit geometry, so
## only the per-ship dynamic state is overwritten here.
func load_save_data(data: Dictionary) -> void:
	var pos: Array = data.get("pos", [])
	if pos.size() == 2:
		global_position = Vector2(float(pos[0]), float(pos[1]))
	hp = float(data.get("hp", max_hp))
	_angle = float(data.get("angle", _angle))
	_spin = float(data.get("spin", _spin))
	_fire_cooldown = float(data.get("cooldown", 0.0))
	if bool(data.get("fleeing", false)):
		flee()
	else:
		_waypoint = _orbit_center + Vector2.from_angle(_angle) * _orbit_radius

# --- VFX ----------------------------------------------------------------------

func _flash_beam(impact: Vector2, absorbed: bool) -> void:
	_beam_time = BEAM_FLASH_SECONDS
	_beam_from = global_position
	_beam_to = impact
	_beam_absorbed = absorbed
	queue_redraw()

func _tick_beam(real_delta: float) -> void:
	if _beam_time <= 0.0:
		return
	_beam_time = maxf(_beam_time - real_delta, 0.0)
	queue_redraw()

func _draw() -> void:
	if _beam_time > 0.0:
		var alpha: float = _beam_time / BEAM_FLASH_SECONDS
		var beam_color: Color = Color(0.5, 0.9, 1.0, alpha) if _beam_absorbed else Color(1.0, 0.3, 0.25, alpha)
		# Drawn in local space; flip_h flips only the texture, not coordinates.
		draw_line(to_local(_beam_from), to_local(_beam_to), beam_color, 3.0, true)
		draw_circle(to_local(_beam_to), 7.0 * alpha, beam_color)
	# Damage pip: a small bar above the hull once hurt, so kills read at a glance.
	if hp >= 0.0 and hp < max_hp:
		var frac: float = clampf(hp / max_hp, 0.0, 1.0)
		var width: float = 40.0
		var origin := Vector2(-width * 0.5, -46.0)
		draw_rect(Rect2(origin, Vector2(width, 5.0)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(origin, Vector2(width * frac, 5.0)), Color(0.9, 0.3, 0.25, 0.9))
