class_name AsteroidManager
extends Node

## Spawns, moves and retires every mineable body in the world - the belt's
## asteroids and WI-61's comets alike.
##
## Since WI-61 the per-kind knobs (population, cadence, speed, trajectory, ore
## mix, richness) live in scanned [SpaceBodyProfile] .tres files rather than as
## @exports here, so a second kind of body is data instead of a second copy of
## this file. What stays on the node is what is genuinely global: the belt's ore
## pool, the belt markers, the canvas layer and the fallback scene.
##
## One flat [member asteroids] array holds every kind. Population and spawn
## cadence are tracked per profile with a filter; two arrays would be two places
## every future reader has to remember, and get_asteroid_by_id, the save section
## and the minimap all iterate this one.

## Fallback body scene, used for a profile that declares none. Also what a
## pre-WI-61 save's bodies restore as, since none of them carry a profile id.
@export var asteroid_scene: PackedScene
## The base game's mineable ores. A mod's ore joins by setting
## ResourceData.asteroid_spawn_weight rather than by reaching into this - see
## _spawnable_ores(). Feeds the WEIGHTED_PICK mix mode only; a FIXED_LIST
## profile names its own resources.
@export var ore_types_available: Array[ResourceData]
## Built once from ore_types_available + everything declaring a spawn weight.
var _ore_pool_cache: Array[ResourceData] = []
## Relative chance for each ore in ore_types_available to appear on a spawned
## asteroid; ores missing from this dictionary count as 1.0. Small weights =
## rare ores.
@export var ore_spawn_weights: Dictionary[ResourceData, float] = {}
@export var start_point: Marker2D
@export var end_point: Marker2D
## Every body draws here. WI-61 moved this layer to -1 in main.tscn so crossing
## bodies pass *behind* the station; asteroids came along for the ride, which is
## invisible unless the player builds out over the belt.
@export var asteroid_layer: CanvasLayer

var asteroids: Array[AsteroidBase] = []

## profile id -> sim-seconds accumulated toward the next spawn, and the gap that
## accumulation is racing. Both saved. The timer deliberately does **not**
## advance while a profile is at its population cap, which is exactly what the
## belt's old `if asteroids.size() < 15` gate did.
var _spawn_timers: Dictionary[StringName, float] = {}
var _spawn_gaps: Dictionary[StringName, float] = {}

## Monotonic id source for asteroid save refs (WI-21). Instance-scoped so a
## fresh scene starts clean; load_save_data restores it past every saved id so
## post-load spawns never collide with restored asteroids. One id space across
## every kind of body, which is why SaveRefs.asteroid_ref needed no edit.
var _next_asteroid_id: int = 0

## Scanned profiles, id-ordered. See _profiles().
var _profile_cache: Array[SpaceBodyProfile] = []
var _profiles_scanned: bool = false

## What a body restores as when its save entry predates profiles.
const LEGACY_PROFILE_ID: StringName = &"asteroid"

func _ready() -> void:
	Global.asteroid_manager = self
	# Before pawns: restored mining jobs resolve their asteroid by id. Its place
	# after world is not a constraint - nothing in this load reads a module, and
	# nothing in the world's load reads a body.
	SaveManager.register_section(&"asteroids", SaveManager.SECTION_ORDER[&"asteroids"], get_save_data, load_save_data)

## Hands the slot back (WI-71 §7). Godot 4.7 reports a freed object as `== null`,
## so the guards around the game already take their null branch after a Quit to
## Menu - but `is_instance_valid(Global.asteroid_manager)` and the debugger both lie until
## the slot is actually cleared. `== self` because a second scene can register
## before this one leaves.
func _exit_tree() -> void:
	if Global.asteroid_manager == self:
		Global.asteroid_manager = null



func _process(delta: float) -> void:
	var sim_delta: float = Global.time_manager.scale(delta)
	if sim_delta <= 0.0:
		return
	_advance_spawning(sim_delta)
	_sweep()

## One spawn clock per profile. A profile at its cap is skipped entirely rather
## than having its timer run down against a spawn it cannot make - so a kind that
## has been full for a cycle still waits its full gap after one leaves.
func _advance_spawning(sim_delta: float) -> void:
	for profile: SpaceBodyProfile in _profiles():
		if profile.max_population <= 0 or population_of(profile.id) >= profile.max_population:
			continue
		var elapsed: float = float(_spawn_timers.get(profile.id, 0.0)) + sim_delta
		var gap: float = _gap_for(profile)
		if elapsed <= gap:
			_spawn_timers[profile.id] = elapsed
			continue
		_spawn_timers[profile.id] = 0.0
		# Roll the next gap whatever happened: a crossing spawn can decline (no
		# station to cross yet), and re-rolling means it retries on its own
		# cadence rather than every frame.
		_spawn_gaps[profile.id] = profile.roll_spawn_gap_seconds()
		spawn_body(profile)

## Retires everything that is finished, in one place: mined dry (which breaks
## up) or travelled its whole route (which does not).
func _sweep() -> void:
	var to_remove: Array[AsteroidBase] = []
	for asteroid: AsteroidBase in asteroids:
		if not is_instance_valid(asteroid):
			to_remove.append(asteroid)
			continue
		# Mined dry: break it up, so a worked-out belt doesn't silently fill with
		# spent rocks that every finder has to skip past. Swept here rather than
		# fired from mine_resource() so that a rock restored empty from an older
		# save is cleaned up the same way, and so a body is only ever freed from
		# this one place.
		if asteroid.is_empty():
			_disperse(asteroid)
			to_remove.append(asteroid)
		elif asteroid.should_despawn():
			# Route finished - gone off-screen unwatched, so no debris for it.
			asteroid.queue_free()
			to_remove.append(asteroid)
	for asteroid: AsteroidBase in to_remove:
		asteroids.erase(asteroid)

## Replaces a spent body with its debris puff. It leaves the field (and therefore
## the save) immediately; the effect is transient, unsaved, and frees itself once
## it has played out.
func _disperse(asteroid: AsteroidBase) -> void:
	var effect := AsteroidDispersal.new()
	effect.position = asteroid.position
	var profile: SpaceBodyProfile = profile_by_id(asteroid.profile_id)
	# A fully transparent authored colour means "whatever the effect already
	# uses", so the default grey-brown is written down in exactly one place.
	if profile != null and profile.dispersal_dust.a > 0.0:
		effect.dust_color = profile.dispersal_dust
	effect.setup(asteroid.sprite, asteroid.direction * asteroid.speed_pixels_per_sec)
	asteroid_layer.add_child(effect)
	asteroid.queue_free()

# --- spawning -----------------------------------------------------------------

## Spawns one body of `profile`, or null if its trajectory declined (a crossing
## with no station to cross). Public so the cheats can force one.
func spawn_body(profile: SpaceBodyProfile) -> AsteroidBase:
	if profile == null:
		return null
	if profile.trajectory == SpaceBodyProfile.Trajectory.CROSSING:
		return _spawn_crossing(profile)
	return _spawn_belt(profile)

## The original belt: a jittered line between the two authored markers, retiring
## a fixed distance from the start marker. The despawn anchor is the marker
## rather than this body's own jittered start, which is what the pre-WI-61 rule
## measured from - so the belt's lifetimes are unchanged to the pixel.
func _spawn_belt(profile: SpaceBodyProfile) -> AsteroidBase:
	var jitter: float = profile.belt_jitter
	var start: Vector2 = start_point.position \
			+ Vector2(randf_range(-jitter, jitter), randf_range(-jitter, jitter))
	var end: Vector2 = end_point.position \
			+ Vector2(randf_range(-jitter, jitter), randf_range(-jitter, jitter))
	var body: AsteroidBase = _make_body(profile)
	body.position = start
	body.speed_pixels_per_sec = profile.roll_speed()
	body.despawn_anchor = start_point.position
	body.despawn_distance = profile.belt_despawn_distance
	_place_body(body, profile, (end - start).normalized())
	return body

## Straight across the play area, from well outside the station to well outside
## on the far side. Declines when nothing is built: there is no centre to aim at,
## and a body crossing the origin of an empty world is not a feature.
func _spawn_crossing(profile: SpaceBodyProfile) -> AsteroidBase:
	var positions: Array[Vector2] = _station_positions()
	if positions.is_empty():
		return null
	var bounds: Rect2 = SpaceGeometry.station_bounds(positions)
	var crossing: SpaceGeometry.Crossing = SpaceGeometry.crossing(
			bounds,
			randf() * TAU,
			randf_range(-profile.lateral_spread, profile.lateral_spread),
			randf_range(profile.entry_margin.x, profile.entry_margin.y),
			profile.exit_margin)
	var body: AsteroidBase = _make_body(profile)
	body.position = crossing.entry
	body.speed_pixels_per_sec = profile.roll_speed()
	body.despawn_anchor = crossing.entry
	body.despawn_distance = crossing.distance
	_place_body(body, profile, crossing.direction)
	_announce_arrival(profile)
	return body

## Instantiates the scene and stamps on everything that comes from the profile
## rather than from the trajectory.
func _make_body(profile: SpaceBodyProfile) -> AsteroidBase:
	var packed: PackedScene = profile.scene if profile.scene != null else asteroid_scene
	var body: AsteroidBase = packed.instantiate() as AsteroidBase
	body.profile_id = profile.id
	if profile.display_name != "":
		body.body_name = profile.display_name
	body.map_edge_contact = profile.trajectory == SpaceBodyProfile.Trajectory.CROSSING
	return body

## The shared tail of both trajectories. Ordering here is load-bearing:
## resource_weighted_values must be set BEFORE add_child (_ready sums the
## weights), and direction is set AFTER so the sprite it orients has certainly
## resolved.
func _place_body(body: AsteroidBase, profile: SpaceBodyProfile, direction: Vector2) -> void:
	var mix: Dictionary[ResourceData, float] = _roll_ore_mix(profile)
	if not mix.is_empty():
		body.resource_weighted_values = mix
	body.richness_range = profile.roll_richness_range()
	body.asteroid_id = _next_asteroid_id
	_next_asteroid_id += 1
	asteroids.append(body)
	asteroid_layer.add_child(body)
	body.direction = direction

## A LOW alert, so a transient body is noticeable without being an interruption.
## Not a transmission: it is worthless an hour later, which is the line WI-57
## draws between the two. Keyed on the profile rather than the body, so two
## comets arriving refresh one row instead of stacking.
func _announce_arrival(profile: SpaceBodyProfile) -> void:
	# Both halves (WI-63). The signal is emitted first and unconditionally: a
	# listener that wants to react to a comet must not depend on whether the
	# alert manager happens to exist, and the alert is the optional half here.
	SignalBus.space_body_arrived.emit(profile)
	if Global.alert_manager == null:
		return
	var noun: String = profile.display_name
	Global.alert_manager.raise(
			StringName("body_arrived_%s" % profile.id),
			AlertData.Priority.LOW,
			"%s inbound" % noun,
			"A %s has entered the mining envelope." % noun.to_lower())

## Every built module's world centre. The gather that feeds SpaceGeometry, kept
## out of it because that file is pure - EventEffectSpawnSalvage has the twin.
func _station_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for node: Node in get_tree().get_nodes_in_group(Groups.MODULE):
		var module: ModuleBase = node as ModuleBase
		if module == null:
			continue
		out.append(Global.cell_to_world(module.module_cell, true))
	return out

# --- contents -----------------------------------------------------------------

func _roll_ore_mix(profile: SpaceBodyProfile) -> Dictionary[ResourceData, float]:
	if profile.mix_mode == SpaceBodyProfile.MixMode.FIXED_LIST:
		return profile.roll_fixed_mix()
	return _roll_weighted_mix(profile)

## Picks N distinct ore types (weighted without replacement, so rare ores stay
## rare) and gives each a random share of the body's contents. Empty result (no
## ore types configured) leaves the scene's authored mix.
func _roll_weighted_mix(profile: SpaceBodyProfile) -> Dictionary[ResourceData, float]:
	var mix: Dictionary[ResourceData, float] = {}
	var candidates: Array[ResourceData] = _spawnable_ores()
	if candidates.is_empty():
		return mix
	var min_types: int = profile.weighted_type_count.x
	var type_count: int = randi_range(min_types, maxi(min_types, profile.weighted_type_count.y))
	type_count = mini(type_count, candidates.size())
	for i: int in type_count:
		var total_weight: float = 0.0
		for candidate: ResourceData in candidates:
			total_weight += _spawn_weight(candidate)
		if total_weight <= 0.0:
			break
		var roll: float = randf() * total_weight
		var cumulative: float = 0.0
		for candidate: ResourceData in candidates:
			cumulative += _spawn_weight(candidate)
			if roll <= cumulative:
				mix[candidate] = randf_range(0.5, 1.5)
				candidates.erase(candidate)
				break
	return mix

## The authored ore list, plus every scanned resource declaring an
## asteroid_spawn_weight (WI-47 audit sweep). ore_types_available is an @export on
## a node in main.tscn, so without this a mod's ore could never appear in the belt
## - which is where a mining-chain mod has to start.
##
## Cached and sorted by id: the pool feeds a weighted roll, so its order has to be
## reproducible however the directory scanned.
func _spawnable_ores() -> Array[ResourceData]:
	if _ore_pool_cache.is_empty():
		_ore_pool_cache = ore_types_available.duplicate()
		var modded: Array[ResourceData] = []
		for path: String in ContentPaths.scan(ContentPaths.RESOURCES):
			var resource: ResourceData = ResourceLoader.load(path) as ResourceData
			if resource != null and resource.asteroid_spawn_weight > 0.0 and not _ore_pool_cache.has(resource):
				modded.append(resource)
		modded.sort_custom(func(a: ResourceData, b: ResourceData) -> bool: return String(a.id) < String(b.id))
		_ore_pool_cache.append_array(modded)
	return _ore_pool_cache.duplicate()

## The manager's authored dictionary wins where it has an entry, so vanilla
## weights are untouched; otherwise the resource's own declared weight, and 1.0
## for an ore that is in the authored list but weighted nowhere.
func _spawn_weight(resource: ResourceData) -> float:
	if ore_spawn_weights.has(resource):
		return ore_spawn_weights[resource]
	return resource.asteroid_spawn_weight if resource.asteroid_spawn_weight > 0.0 else 1.0

## Every resource any kind of body could ever yield, id-ordered (WI-61).
##
## The belt pool plus every FIXED_LIST profile's declared rows. This is what the
## mining bay's priority-ore dropdown offers, in place of the raw
## ore_types_available it used to read - which silently omitted both a
## comet-only resource and (a latent WI-47 gap) any mod ore that had joined the
## belt through asteroid_spawn_weight.
func spawnable_yields() -> Array[ResourceData]:
	var out: Array[ResourceData] = _spawnable_ores()
	for profile: SpaceBodyProfile in _profiles():
		for resource: ResourceData in profile.declared_yields():
			if not out.has(resource):
				out.append(resource)
	out.sort_custom(func(a: ResourceData, b: ResourceData) -> bool: return String(a.id) < String(b.id))
	return out

# --- profiles -----------------------------------------------------------------

## Every body kind, id-ordered so the spawn loop and spawnable_yields() are
## reproducible however the directory enumerated. Scanned once.
func _profiles() -> Array[SpaceBodyProfile]:
	if _profiles_scanned:
		return _profile_cache
	_profiles_scanned = true
	for path: String in ContentPaths.scan(ContentPaths.SPACE_BODIES):
		var res: Resource = ResourceLoader.load(path)
		if res is SpaceBodyProfile:
			var profile := res as SpaceBodyProfile
			if not ContentPaths.accept_id(profile.id, path, "SpaceBodyProfile"):
				continue
			_profile_cache.append(profile)
	_profile_cache.sort_custom(func(a: SpaceBodyProfile, b: SpaceBodyProfile) -> bool:
		return String(a.id) < String(b.id))
	if _profile_cache.is_empty():
		push_error("AsteroidManager: no SpaceBodyProfile found - nothing will spawn. "
				+ "Expected .tres files under data/space_bodies/.")
	return _profile_cache

func profile_by_id(id: StringName) -> SpaceBodyProfile:
	for profile: SpaceBodyProfile in _profiles():
		if profile.id == id:
			return profile
	return null

## Live count of one kind.
func population_of(profile_id: StringName) -> int:
	var count: int = 0
	for asteroid: AsteroidBase in asteroids:
		if is_instance_valid(asteroid) and asteroid.profile_id == profile_id:
			count += 1
	return count

func _gap_for(profile: SpaceBodyProfile) -> float:
	if not _spawn_gaps.has(profile.id):
		_spawn_gaps[profile.id] = profile.roll_spawn_gap_seconds()
	return _spawn_gaps[profile.id]

## Live asteroid with this save id, or null (mined dry / despawned / bad ref).
## Backs SaveRefs.resolve_asteroid_ref for mining-job restore.
func get_asteroid_by_id(id: int) -> AsteroidBase:
	if id < 0:
		return null
	for asteroid: AsteroidBase in asteroids:
		if is_instance_valid(asteroid) and asteroid.asteroid_id == id:
			return asteroid
	return null

# --- persistence (WI-21) ------------------------------------------------------

## The whole field plus the per-profile spawn clocks and next-id source, so a
## load reconstructs the same bodies (kind, contents, richness, drift, remaining
## route) rather than regenerating a fresh random field.
func get_save_data() -> Dictionary:
	var out: Array = []
	for asteroid: AsteroidBase in asteroids:
		if not is_instance_valid(asteroid):
			continue
		out.append(asteroid.get_save_data())
	var timers: Dictionary = {}
	for id: StringName in _spawn_timers:
		timers[String(id)] = _spawn_timers[id]
	var gaps: Dictionary = {}
	for id: StringName in _spawn_gaps:
		gaps[String(id)] = _spawn_gaps[id]
	return {
		"next_id": _next_asteroid_id,
		"spawn_timers": timers,
		"spawn_gaps": gaps,
		"asteroids": out,
	}

func load_save_data(data: Dictionary) -> void:
	# Drop anything the fresh scene may have spawned before the load applied
	# (_process runs between _ready and the deferred apply); the save is the
	# full truth for the field.
	for asteroid: AsteroidBase in asteroids:
		if is_instance_valid(asteroid):
			asteroid.queue_free()
	asteroids.clear()
	_next_asteroid_id = int(data.get("next_id", 0))
	_spawn_timers.clear()
	_spawn_gaps.clear()
	for id_str: String in data.get("spawn_timers", {}):
		_spawn_timers[StringName(id_str)] = float(data["spawn_timers"][id_str])
	for id_str: String in data.get("spawn_gaps", {}):
		_spawn_gaps[StringName(id_str)] = float(data["spawn_gaps"][id_str])
	# Pre-WI-61: one scalar clock, which belonged to the belt.
	if data.has("last_spawn"):
		_spawn_timers[LEGACY_PROFILE_ID] = float(data["last_spawn"])
	for entry: Dictionary in data.get("asteroids", []):
		_spawn_asteroid_from_save(entry)

## Rebuilds one body from its saved dict. Three ordering constraints, all
## load-bearing: resource_weighted_values must be set before add_child (_ready
## sums the weights), cur_resources restored after it (_ready resets it to
## max_resources), and direction set last, since for a body that points along its
## heading the direction setter is what writes the sprite's rotation.
func _spawn_asteroid_from_save(entry: Dictionary) -> void:
	# A pre-WI-61 entry has no profile, and everything in one is an asteroid.
	var profile: SpaceBodyProfile = profile_by_id(
			StringName(entry.get("profile", String(LEGACY_PROFILE_ID))))
	var asteroid: AsteroidBase
	if profile != null:
		asteroid = _make_body(profile)
	else:
		asteroid = asteroid_scene.instantiate() as AsteroidBase
	var pos_arr: Array = entry.get("position", [0, 0])
	asteroid.position = Vector2(float(pos_arr[0]), float(pos_arr[1]))
	asteroid.speed_pixels_per_sec = float(entry.get("speed", 15.0))
	asteroid.max_resources = int(entry.get("max_resources", asteroid.max_resources))
	var richness_arr: Array = entry.get("richness_range", [0.3, 0.7])
	asteroid.richness_range = Vector2(float(richness_arr[0]), float(richness_arr[1]))
	# Pre-WI-61 saves measured every despawn from the belt marker at 2000px.
	var anchor_arr: Array = entry.get("despawn_anchor",
			[start_point.position.x, start_point.position.y])
	asteroid.despawn_anchor = Vector2(float(anchor_arr[0]), float(anchor_arr[1]))
	asteroid.despawn_distance = float(entry.get("despawn_distance", 2000.0))
	var mix: Dictionary[ResourceData, float] = {}
	var ore_mix: Dictionary = entry.get("ore_mix", {})
	for id_str: String in ore_mix:
		var resource: ResourceData = Global.save_manager.get_resource_by_id(StringName(id_str))
		if resource != null:
			mix[resource] = float(ore_mix[id_str])
	# Before add_child: _ready() sums the ore weights into resource_total_weights.
	if not mix.is_empty():
		asteroid.resource_weighted_values = mix
	asteroids.append(asteroid)
	asteroid_layer.add_child(asteroid)
	# After _ready: it reset cur_resources to max and summed the weights.
	asteroid.asteroid_id = int(entry.get("id", -1))
	asteroid.cur_resources = int(entry.get("cur_resources", asteroid.max_resources))
	asteroid.designated = bool(entry.get("designated", false))
	if asteroid.sprite != null:
		asteroid.sprite.rotation_degrees = float(entry.get("rotation", 0.0))
	# Last: for a comet this re-derives the sprite rotation from the heading,
	# which is where it came from in the first place.
	var dir_arr: Array = entry.get("direction", [0, 0])
	asteroid.direction = Vector2(float(dir_arr[0]), float(dir_arr[1]))
