class_name GameCamera
extends Camera2D

var zoom_speed: float = 0.05
var zoom_min: float = 0.2
var zoom_max: float = 2.0
var drag_sensitivity: float = 1.0
var pan_speed: float = 10.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_action_pressed("camera_drag"):
		position -= (event as InputEventMouseMotion).relative * drag_sensitivity / zoom
	if Input.is_action_pressed("camera_down"):
		position.y += pan_speed
	elif Input.is_action_pressed("camera_up"):
		position.y -= pan_speed
	if Input.is_action_pressed("camera_left"):
		position.x -= pan_speed
	elif Input.is_action_pressed("camera_right"):
		position.x += pan_speed

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if Input.is_action_pressed("camera_zoom_in"):
			zoom += Vector2(zoom_speed, zoom_speed)
		elif Input.is_action_pressed("camera_zoom_out"):
			zoom -= Vector2(zoom_speed, zoom_speed)
		zoom = clamp(zoom, Vector2(zoom_min, zoom_min), Vector2(zoom_max, zoom_max))

## Recenter the camera on a world point (WI-34 minimap click-to-jump). Clamped to
## the configured limits, which default to ±10000000 so this is a no-op until
## limits are actually set.
func jump_to(world_pos: Vector2) -> void:
	global_position = Vector2(
		clampf(world_pos.x, float(limit_left), float(limit_right)),
		clampf(world_pos.y, float(limit_top), float(limit_bottom)))
