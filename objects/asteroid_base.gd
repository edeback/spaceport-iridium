class_name AsteroidBase
extends Node2D

var speed_pixels_per_sec: float = 20
var direction: Vector2
var rotation_speed_deg_per_sec: float = 30

func _process(delta: float) -> void:
	position += speed_pixels_per_sec * delta * direction
	rotation_degrees += delta * rotation_speed_deg_per_sec
