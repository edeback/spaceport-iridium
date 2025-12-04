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


func _on_pressed() -> void:
	Global.ui_in_game.change_input_mode(UIInGame.InputMode.Module, module_data)
	#Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	pass # Replace with function body.

func _make_custom_tooltip(for_text: String) -> Object:
	var new_tooltip: ModuleButtonTooltip = preload("res://ui/buttons/module_button_tooltip.tscn").instantiate()
	new_tooltip.set_module_data(module_data)
	return new_tooltip
