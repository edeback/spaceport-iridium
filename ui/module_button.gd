class_name ModuleButton
extends Button

var module_data: ModuleData

func set_moduledata(data: ModuleData) -> void:
	module_data = data
	icon = module_data.icon
	text = module_data.name
	pass

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_pressed() -> void:
	Global.current_module = module_data
	#Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	pass # Replace with function body.
