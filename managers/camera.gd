extends Camera2D

var zoom_speed: float = 0.05
var zoom_min: float = 0.2
var zoom_max: float = 2.0
var drag_sensitivity: float = 1.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_action_pressed("camera_drag"):
		position -= event.relative * drag_sensitivity / zoom
	if event is InputEventMouseButton:
		if Input.is_action_pressed("camera_zoom_in"):
			zoom += Vector2(zoom_speed, zoom_speed)
		elif Input.is_action_pressed("camera_zoom_out"):
			zoom -= Vector2(zoom_speed, zoom_speed)
		zoom = clamp(zoom, Vector2(zoom_min, zoom_min), Vector2(zoom_max, zoom_max))
