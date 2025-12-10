class_name AsteroidBase
extends ObjectBase

@export var sprite: Sprite2D
@export var resource_weighted_values: Dictionary[ResourceData, float] = {}
@export var max_resources: int = 10
var cur_resources: int
var resource_total_weights: float = 0

var speed_pixels_per_sec: float = 15
var direction: Vector2
var rotation_speed_deg_per_sec: float = 30

signal despawning

func _ready() -> void:
	add_to_group("asteroid")
	cur_resources = max_resources
	for weight: float in resource_weighted_values.values():
		resource_total_weights += weight
	
func _exit_tree() -> void:
	despawning.emit()

func _process(delta: float) -> void:
	position += speed_pixels_per_sec * delta * direction
	sprite.rotation_degrees += delta * rotation_speed_deg_per_sec

func mine_resource() -> ResourceData:
	if resource_total_weights == 0 or cur_resources <= 0:
		return null
	var weight_to_hit: float = randf() * resource_total_weights
	var cur_weight: float = 0
	for resource: ResourceData in resource_weighted_values:
		cur_weight += resource_weighted_values[resource]
		if weight_to_hit <= cur_weight:
			cur_resources -= 1
			return resource
	return null

func is_empty() -> bool:
	return cur_resources <= 0
