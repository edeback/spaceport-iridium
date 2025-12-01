class_name AsteroidBase
extends ObjectBase

@export var sprite: Sprite2D
@export var storage: MultiStorageComponent
@export var base_output_resource: ResourceData
@export var sub_resources: Array[ResourceData]

var output_resource: ResourceData

var speed_pixels_per_sec: float = 15
var direction: Vector2
var rotation_speed_deg_per_sec: float = 30

signal despawning

func _ready() -> void:
	add_to_group("asteroid")
	output_resource = base_output_resource.duplicate()
	output_resource.base_resource = base_output_resource
	output_resource.sub_resources[sub_resources.pick_random()] = 0.5
	output_resource.sub_resources[sub_resources.pick_random()] = 0.5
	storage.deposit(output_resource, 10)
	
func _exit_tree() -> void:
	despawning.emit()

func _process(delta: float) -> void:
	position += speed_pixels_per_sec * delta * direction
	sprite.rotation_degrees += delta * rotation_speed_deg_per_sec

func mine_resource(amount_wanted: float) -> float:
	return storage.withdraw_up_to(output_resource, amount_wanted)

func is_empty() -> bool:
	return storage.total_stored_by_resource(output_resource) <= 0.00001
