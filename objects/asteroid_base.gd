class_name AsteroidBase
extends Node2D

var speed_pixels_per_sec: float = 15
var direction: Vector2
var rotation_speed_deg_per_sec: float = 30

signal despawning

func _ready() -> void:
	add_to_group("asteroid")
	
func _exit_tree() -> void:
	despawning.emit()

func _process(delta: float) -> void:
	position += speed_pixels_per_sec * delta * direction
	rotation_degrees += delta * rotation_speed_deg_per_sec
