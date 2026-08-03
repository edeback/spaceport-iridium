class_name RaidManager
extends Node

## Pirate raid lifecycle (WI-32). Owns the wave: spawns ships, sizes the threat
## from station value, prices the pay-off hail, drops salvage on kills, and
## resolves the raid when the last ship leaves - by pay-off, flight, or
## destruction. Ships are self-driving Node2Ds (see PirateShip) that call back
## here on damage / death / departure; this manager never ticks their flight.
##
## Raids arrive via the event system (WI-24's pirate_extortion "refuse", or the
## defenses-gated pirate_raid event) calling start_raid(). A save mid-raid
## restores the whole fight from the "raid" section so you can't save-scum out of
## the threat. Difficulty (WI-37) gates raids entirely on Peaceful: raids_enabled
## is seeded from Global.difficulty at ready, and the raid event family carries an
## EventConditionDifficultyAllowsRaids so those cards are never even drawn.

@export var pirate_ship_scene: PackedScene
## Salvage dropped by each destroyed ship (a pile in space, EVA-collectable).
@export var salvage_resource: ResourceData
@export var salvage_amount: Vector2i = Vector2i(4, 10)

## --- threat sizing (station value -> wave) ----------------------------------
## strength = built_modules * value_per_module + credits * value_per_credit.
@export var value_per_module: float = 1.0
@export var value_per_credit: float = 0.004
## One ship per this much strength, clamped to [1, max_ships].
@export var strength_per_ship: float = 6.0
@export var max_ships: int = 6

## --- flight geometry --------------------------------------------------------
## Orbit ring sits this far outside the station's own radius.
@export var orbit_margin: float = 360.0
## Ships spawn this much further out again and fly in - the raid "warning"
## window. Sized so the approach is roughly one sim-hour (~10 sim-seconds at the
## default ship speed), the heads-up the design asks for before ships arrive.
@export var approach_margin: float = 1400.0

## --- pay-off hail -----------------------------------------------------------
@export var payoff_base: float = 250.0
@export var payoff_per_strength: float = 40.0
@export var payoff_min: float = 150.0
## The price falls by up to this fraction as you grind the wave's HP down.
@export var payoff_max_discount: float = 0.85

## Peaceful difficulty (WI-37) flips this off and no raid ever spawns. Seeded from
## the staged difficulty in _ready and never saved - it is re-derived from
## Global.difficulty on every load, which is itself restored from the save.
var raids_enabled: bool = true

var active: bool = false
var _ships: Array[PirateShip] = []
var _strength: float = 0.0
## Sum of the wave's spawn HP, the denominator for the pay-off discount.
var _initial_hp_pool: float = 0.0
## Damage the station has dealt to pirates this raid (drives the discount).
var _damage_to_pirates: float = 0.0
var _paid: bool = false
var _destroyed_count: int = 0
var _departed_count: int = 0
## Cached at spawn so ships share one orbit centre even as modules are destroyed.
var _center := Vector2.ZERO
var _orbit_radius: float = 600.0

func _ready() -> void:
	Global.raid_manager = self
	# After world: an in-progress raid respawns its ships against the restored
	# station geometry. Events don't re-fire effects on load, so there's no risk of
	# a second raid spawning alongside the restored one (WI-32 edge case).
	SaveManager.register_section(&"raid", 150, get_save_data, load_save_data)
	raids_enabled = Global.difficulty_raids_enabled()

# --- lifecycle ----------------------------------------------------------------

## Auto-size a raid from current station value. -1 to compute_strength() callers
## pass their own number; this is the default event/cheat path.
func compute_strength() -> float:
	var world: WorldManager = Global.world_manager
	var modules: int = world.get_built_modules().size() if world != null else 0
	var credits: int = 0
	if Global.resource_manager != null and Global.resource_manager.credit_resource != null:
		credits = maxi(Global.resource_manager.credit_resource.get_total(), 0)
	return modules * value_per_module + credits * value_per_credit

## Begin a raid of `strength` (pass < 0 to auto-size). No-op if a raid is already
## running, raids are disabled, or there's nothing to attack.
func start_raid(strength: float = -1.0) -> bool:
	if not raids_enabled:
		# Logged, not silent: the event conditions mean nothing should reach here on
		# Peaceful, so a hit is either the debug cheat or a raid path that forgot its
		# condition - both worth seeing in the log.
		print("RaidManager: raid suppressed - %s difficulty has raids disabled" %
			SaveManager.difficulty_label(Global.difficulty_id()))
		return false
	if active or pirate_ship_scene == null:
		return false
	if strength < 0.0:
		strength = compute_strength()
	_recompute_geometry()
	var ship_count: int = clampi(roundi(strength / maxf(strength_per_ship, 0.01)), 1, max_ships)
	active = true
	_strength = strength
	_damage_to_pirates = 0.0
	_initial_hp_pool = 0.0
	_paid = false
	_destroyed_count = 0
	_departed_count = 0
	_ships.clear()
	var base_angle: float = randf() * TAU
	for i: int in ship_count:
		var angle: float = base_angle + TAU * float(i) / float(ship_count)
		var ship: PirateShip = _spawn_ship(angle, 1.0 if (i % 2 == 0) else -1.0)
		_initial_hp_pool += ship.max_hp
		_ships.append(ship)
	SignalBus.station_alert.emit("Raiders inbound! %d hostile ship(s) closing on the station." % ship_count)
	SignalBus.raid_started.emit(_strength)
	SignalBus.raid_state_changed.emit()
	return true

func _spawn_ship(angle: float, spin: float) -> PirateShip:
	var ship: PirateShip = pirate_ship_scene.instantiate() as PirateShip
	Global.world_manager.pawn_layer.add_child(ship)
	ship.setup(self, _center, _orbit_radius, _orbit_radius + approach_margin, angle, spin)
	return ship

## Station centroid + a ring radius that clears its footprint. Recomputed at
## spawn; ships keep orbiting this fixed centre even as the station is chewed up.
func _recompute_geometry() -> void:
	var centre := Vector2.ZERO
	var count: int = 0
	var max_extent: float = 0.0
	var modules: Array[Node] = get_tree().get_nodes_in_group(Groups.MODULE)
	for node: Node in modules:
		var module: ModuleBase = node as ModuleBase
		if module == null:
			continue
		centre += module.get_global_center()
		count += 1
	if count > 0:
		centre /= float(count)
	for node: Node in modules:
		var module: ModuleBase = node as ModuleBase
		if module == null:
			continue
		max_extent = maxf(max_extent, centre.distance_to(module.get_global_center()))
	_center = centre
	_orbit_radius = max_extent + orbit_margin

# --- ship callbacks -----------------------------------------------------------

## A station weapon dealt `amount` to a pirate; feeds the pay-off discount.
func note_pirate_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	_damage_to_pirates += amount
	SignalBus.raid_state_changed.emit()

func report_ship_destroyed(ship: PirateShip) -> void:
	_ships.erase(ship)
	_destroyed_count += 1
	_drop_salvage(ship.global_position)
	SignalBus.ship_destroyed.emit(ship)
	SignalBus.raid_state_changed.emit()
	_check_end()

func report_ship_departed(ship: PirateShip) -> void:
	_ships.erase(ship)
	_departed_count += 1
	SignalBus.raid_state_changed.emit()
	_check_end()

## Pulls the salvage pile in toward the station so a kill way out at the ring is
## still a reasonable EVA (never further than the orbit radius from centre).
func _drop_salvage(at: Vector2) -> void:
	if salvage_resource == null:
		return
	var amount: int = randi_range(salvage_amount.x, maxi(salvage_amount.x, salvage_amount.y))
	if amount <= 0:
		return
	var dir: Vector2 = (at - _center)
	var dist: float = minf(dir.length(), _orbit_radius)
	if dir.length() > 1.0:
		dir = dir.normalized()
	else:
		dir = Vector2.RIGHT
	var pile: ResourcePile = ResourcePile.spawn(Global.world_manager.pawn_layer, _center + dir * dist)
	pile.add_amount(salvage_resource, amount)

func _check_end() -> void:
	if not active:
		return
	_ships = _ships.filter(func(s: PirateShip) -> bool: return is_instance_valid(s))
	if not _ships.is_empty():
		return
	var outcome: StringName = &"victory"
	if _paid:
		outcome = &"paid"
	elif _departed_count > 0:
		outcome = &"repelled"
	active = false
	_strength = 0.0
	match outcome:
		&"paid":
			SignalBus.station_alert.emit("The raiders take the payoff and break off.")
		&"repelled":
			SignalBus.station_alert.emit("The raiders have been driven off!")
		_:
			SignalBus.station_alert.emit("The raid is over - every hostile destroyed.")
	SignalBus.raid_ended.emit(outcome)
	SignalBus.raid_state_changed.emit()

# --- shields ------------------------------------------------------------------

## First refusal for shields on an incoming pirate hit. Among online bubbles
## covering the impact, the most-charged absorbs it (ShieldMath's overlap rule).
## Returns the absorbing ShieldComponent (so the beam can terminate on its
## bubble), or null when the hit leaks through to the module.
func try_shield_absorb(impact: Vector2, damage: float) -> ShieldComponent:
	var comps: Array[ShieldComponent] = []
	var bubbles: Array = []
	for node: Node in get_tree().get_nodes_in_group(Groups.SHIELD):
		var shield: ShieldComponent = node as ShieldComponent
		if shield == null or not is_instance_valid(shield):
			continue
		comps.append(shield)
		bubbles.append(shield.bubble())
	var idx: int = ShieldMath.select_absorber(bubbles, impact)
	if idx < 0:
		return null
	comps[idx].absorb(damage)
	SignalBus.raid_state_changed.emit()
	return comps[idx]

# --- pay-off hail -------------------------------------------------------------

## Current ransom, dropping as the wave is ground down. Floored at payoff_min.
func current_payoff() -> int:
	if not active:
		return 0
	var base: float = payoff_base + payoff_per_strength * _strength
	var discount: float = 0.0
	if _initial_hp_pool > 0.0:
		discount = clampf(_damage_to_pirates / _initial_hp_pool, 0.0, payoff_max_discount)
	return maxi(int(round(base * (1.0 - discount))), int(payoff_min))

func can_pay_off() -> bool:
	if not active:
		return false
	var credits: ResourceData = Global.resource_manager.credit_resource
	return credits != null and credits.get_total() >= current_payoff()

## Buy the raiders off: spend the ransom and send every ship home. The raid ends
## once the last one clears the ring (in-flight beams resolve, no new fire).
func pay_off() -> bool:
	if not can_pay_off():
		return false
	Global.resource_manager.credit_resource.force_withdraw(current_payoff())
	_paid = true
	for ship: PirateShip in _ships:
		if is_instance_valid(ship):
			ship.stand_down()
	SignalBus.raid_state_changed.emit()
	return true

func ship_count() -> int:
	var n: int = 0
	for ship: PirateShip in _ships:
		if is_instance_valid(ship):
			n += 1
	return n

# --- persistence --------------------------------------------------------------

func get_save_data() -> Dictionary:
	if not active:
		return {"active": false}
	var ships_out: Array = []
	for ship: PirateShip in _ships:
		if is_instance_valid(ship):
			ships_out.append(ship.get_save_data())
	return {
		"active": true,
		"strength": _strength,
		"initial_hp_pool": _initial_hp_pool,
		"damage_to_pirates": _damage_to_pirates,
		"paid": _paid,
		"destroyed_count": _destroyed_count,
		"departed_count": _departed_count,
		"center": [_center.x, _center.y],
		"orbit_radius": _orbit_radius,
		"ships": ships_out,
	}

func load_save_data(data: Dictionary) -> void:
	# Clear any stray wave the fresh scene may hold (there won't be one - raids
	# only spawn via events - but stay defensive against a double-apply).
	for ship: PirateShip in _ships:
		if is_instance_valid(ship):
			ship.queue_free()
	_ships.clear()
	active = bool(data.get("active", false))
	if not active:
		return
	_strength = float(data.get("strength", 0.0))
	_initial_hp_pool = float(data.get("initial_hp_pool", 0.0))
	_damage_to_pirates = float(data.get("damage_to_pirates", 0.0))
	_paid = bool(data.get("paid", false))
	_destroyed_count = int(data.get("destroyed_count", 0))
	_departed_count = int(data.get("departed_count", 0))
	var centre_arr: Array = data.get("center", [0, 0])
	if centre_arr.size() == 2:
		_center = Vector2(float(centre_arr[0]), float(centre_arr[1]))
	_orbit_radius = float(data.get("orbit_radius", 600.0))
	for entry: Dictionary in data.get("ships", []):
		var ship: PirateShip = pirate_ship_scene.instantiate() as PirateShip
		Global.world_manager.pawn_layer.add_child(ship)
		# Seed the orbit geometry, then overwrite the dynamic state from the save.
		ship.setup(self, _center, _orbit_radius, _orbit_radius + approach_margin, float(entry.get("angle", 0.0)), float(entry.get("spin", 1.0)))
		ship.load_save_data(entry)
		_ships.append(ship)
	SignalBus.raid_started.emit(_strength)
	SignalBus.raid_state_changed.emit()
