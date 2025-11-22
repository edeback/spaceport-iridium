class_name AsteroidManager
extends Node

@export var asteroid_scene: PackedScene
@export var start_point: Marker2D
@export var end_point: Marker2D
@export var asteroid_layer: CanvasLayer

var asteroids: Array[AsteroidBase] = []

var last_spawn: float = 0

func _ready() -> void:
	Global.asteroid_manager = self
	
	
func _process(delta: float) -> void:
	if asteroids.size() < 15:
		last_spawn += delta
		if last_spawn > 5:
			last_spawn = 0
			spawn_asteroid()
	var asteroids_to_remove: Array[AsteroidBase] = []
	for asteroid: AsteroidBase in asteroids:
		if asteroid.position.distance_squared_to(end_point.position) < 45000:
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
	asteroids.append(asteroid)
	asteroid_layer.add_child(asteroid)
