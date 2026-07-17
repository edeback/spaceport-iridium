class_name AsteroidManager
extends Node

@export var asteroid_scene: PackedScene
@export var ore_types_available: Array[ResourceData]
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

func _ready() -> void:
	Global.asteroid_manager = self


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
		if asteroid.position.distance_squared_to(start_point.position) > 4000000:
			asteroids_to_remove.append(asteroid)
			asteroid.queue_free()
	for asteroid: AsteroidBase in asteroids_to_remove:
		asteroids.erase(asteroid)


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
	asteroids.append(asteroid)
	asteroid_layer.add_child(asteroid)

## Picks 1-3 distinct ore types (weighted without replacement, so rare ores
## stay rare) and gives each a random share of the asteroid's contents.
## Empty result (no ore types configured) leaves the scene's authored mix.
func _roll_ore_mix() -> Dictionary[ResourceData, float]:
	var mix: Dictionary[ResourceData, float] = {}
	if ore_types_available.is_empty():
		return mix
	var candidates: Array[ResourceData] = ore_types_available.duplicate()
	var type_count: int = randi_range(min_ore_types, maxi(min_ore_types, max_ore_types))
	type_count = mini(type_count, candidates.size())
	for i: int in type_count:
		var total_weight: float = 0.0
		for candidate: ResourceData in candidates:
			total_weight += ore_spawn_weights.get(candidate, 1.0)
		if total_weight <= 0.0:
			break
		var roll: float = randf() * total_weight
		var cumulative: float = 0.0
		for candidate: ResourceData in candidates:
			cumulative += ore_spawn_weights.get(candidate, 1.0)
			if roll <= cumulative:
				mix[candidate] = randf_range(0.5, 1.5)
				candidates.erase(candidate)
				break
	return mix

func _roll_richness_range() -> Vector2:
	var center: float = lerpf(richness_band.x, richness_band.y, pow(randf(), richness_skew))
	return Vector2(clampf(center - richness_spread, 0.0, 1.0), clampf(center + richness_spread, 0.0, 1.0))
