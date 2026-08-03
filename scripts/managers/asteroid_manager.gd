class_name AsteroidManager
extends Node

@export var asteroid_scene: PackedScene
## The base game's mineable ores. A mod's ore joins by setting
## ResourceData.asteroid_spawn_weight rather than by reaching into this - see
## _spawnable_ores().
@export var ore_types_available: Array[ResourceData]
## Built once from ore_types_available + everything declaring a spawn weight.
var _ore_pool_cache: Array[ResourceData] = []
## Relative chance for each ore in ore_types_available to appear on a spawned
## asteroid; ores missing from this dictionary count as 1.0. Small weights =
## rare ores.
@export var ore_spawn_weights: Dictionary[ResourceData, float] = {}
## How many distinct ore types one asteroid carries (clamped to the number of
## available ore types).
@export var min_ore_types: int = 1
@export var max_ore_types: int = 3
## Global band that per-asteroid richness ranges are drawn from.
@export var richness_band: Vector2 = Vector2(0.15, 1.0)
## Half-width of a single asteroid's richness range around its rolled center.
@export var richness_spread: float = 0.1
## Exponent skewing rolled richness centers toward the poor end; > 1 makes
## rich asteroids rarer.
@export var richness_skew: float = 1.6
@export var start_point: Marker2D
@export var end_point: Marker2D
@export var asteroid_layer: CanvasLayer

var asteroids: Array[AsteroidBase] = []

var last_spawn: float = 0

## Monotonic id source for asteroid save refs (WI-21). Instance-scoped so a
## fresh scene starts clean; load_save_data restores it past every saved id so
## post-load spawns never collide with restored asteroids.
var _next_asteroid_id: int = 0

func _ready() -> void:
	Global.asteroid_manager = self
	# After world, before pawns: mining jobs resolve their asteroid by id.
	SaveManager.register_section(&"asteroids", 70, get_save_data, load_save_data)


func _process(delta: float) -> void:
	var sim_delta: float = Global.time_manager.scale(delta)
	if sim_delta <= 0.0:
		return
	if asteroids.size() < 15:
		last_spawn += sim_delta
		if last_spawn > 5:
			last_spawn = 0
			spawn_asteroid()
	var asteroids_to_remove: Array[AsteroidBase] = []
	for asteroid: AsteroidBase in asteroids:
		# Mined dry: break it up, so a worked-out belt doesn't silently fill with
		# spent rocks that every finder has to skip past. Swept here rather than
		# fired from mine_resource() so that a rock restored empty from an older
		# save is cleaned up the same way, and so an asteroid is only ever freed
		# from this one place.
		if asteroid.is_empty():
			_disperse(asteroid)
			asteroids_to_remove.append(asteroid)
		elif asteroid.position.distance_squared_to(start_point.position) > 4000000:
			# Drifted out of the belt entirely - gone off-screen unwatched, so no
			# debris for it.
			asteroid.queue_free()
			asteroids_to_remove.append(asteroid)
	for asteroid: AsteroidBase in asteroids_to_remove:
		asteroids.erase(asteroid)

## Replaces a spent asteroid with its debris puff. The rock leaves the field (and
## therefore the save) immediately; the effect is transient, unsaved, and frees
## itself once it has played out.
func _disperse(asteroid: AsteroidBase) -> void:
	var effect := AsteroidDispersal.new()
	effect.position = asteroid.position
	effect.setup(asteroid.sprite, asteroid.direction * asteroid.speed_pixels_per_sec)
	asteroid_layer.add_child(effect)
	asteroid.queue_free()


func spawn_asteroid() -> void:
	var start: Vector2 = start_point.position + Vector2(randf_range(-200, 200), randf_range(-200, 200))
	var end: Vector2 = end_point.position + Vector2(randf_range(-200, 200), randf_range(-200, 200))
	var direction: Vector2 = end - start
	direction = direction.normalized()
	var asteroid: AsteroidBase = asteroid_scene.instantiate() as AsteroidBase
	asteroid.position = start
	asteroid.direction = direction
	asteroid.speed_pixels_per_sec = randf_range(10, 30)
	# Must be set before add_child: _ready() sums the ore weights.
	var mix: Dictionary[ResourceData, float] = _roll_ore_mix()
	if not mix.is_empty():
		asteroid.resource_weighted_values = mix
	asteroid.richness_range = _roll_richness_range()
	asteroid.asteroid_id = _next_asteroid_id
	_next_asteroid_id += 1
	asteroids.append(asteroid)
	asteroid_layer.add_child(asteroid)

## Picks 1-3 distinct ore types (weighted without replacement, so rare ores
## stay rare) and gives each a random share of the asteroid's contents.
## Empty result (no ore types configured) leaves the scene's authored mix.
func _roll_ore_mix() -> Dictionary[ResourceData, float]:
	var mix: Dictionary[ResourceData, float] = {}
	var candidates: Array[ResourceData] = _spawnable_ores()
	if candidates.is_empty():
		return mix
	var type_count: int = randi_range(min_ore_types, maxi(min_ore_types, max_ore_types))
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

func _roll_richness_range() -> Vector2:
	var center: float = lerpf(richness_band.x, richness_band.y, pow(randf(), richness_skew))
	return Vector2(clampf(center - richness_spread, 0.0, 1.0), clampf(center + richness_spread, 0.0, 1.0))

## Live asteroid with this save id, or null (mined dry / despawned / bad ref).
## Backs SaveManager.resolve_asteroid_ref for mining-job restore.
func get_asteroid_by_id(id: int) -> AsteroidBase:
	if id < 0:
		return null
	for asteroid: AsteroidBase in asteroids:
		if is_instance_valid(asteroid) and asteroid.asteroid_id == id:
			return asteroid
	return null

# --- persistence (WI-21) ------------------------------------------------------

## The whole asteroid field plus the spawn-cadence counter and next-id source,
## so a load reconstructs the same rocks (contents, richness, drift) rather than
## regenerating a fresh random field.
func get_save_data() -> Dictionary:
	var out: Array = []
	for asteroid: AsteroidBase in asteroids:
		if not is_instance_valid(asteroid):
			continue
		out.append(asteroid.get_save_data())
	return {
		"next_id": _next_asteroid_id,
		"last_spawn": last_spawn,
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
	last_spawn = float(data.get("last_spawn", 0.0))
	for entry: Dictionary in data.get("asteroids", []):
		_spawn_asteroid_from_save(entry)

## Rebuilds one asteroid from its saved dict. Mirrors spawn_asteroid's ordering
## constraint: resource_weighted_values must be set before add_child (_ready sums
## the weights), and cur_resources is restored AFTER add_child because _ready
## resets it to max_resources.
func _spawn_asteroid_from_save(entry: Dictionary) -> void:
	var asteroid: AsteroidBase = asteroid_scene.instantiate() as AsteroidBase
	var pos_arr: Array = entry.get("position", [0, 0])
	asteroid.position = Vector2(float(pos_arr[0]), float(pos_arr[1]))
	var dir_arr: Array = entry.get("direction", [0, 0])
	asteroid.direction = Vector2(float(dir_arr[0]), float(dir_arr[1]))
	asteroid.speed_pixels_per_sec = float(entry.get("speed", 15.0))
	asteroid.max_resources = int(entry.get("max_resources", asteroid.max_resources))
	var richness_arr: Array = entry.get("richness_range", [0.3, 0.7])
	asteroid.richness_range = Vector2(float(richness_arr[0]), float(richness_arr[1]))
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
