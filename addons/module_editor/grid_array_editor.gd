class_name GridArrayEditor
extends EditorProperty

var custom_control = preload("res://addons/module_editor/grid_panel.tscn")
var control = null

func _ready() -> void:
	control = custom_control.instantiate()
	control.init_from_editor(self)
	add_child(control)
	
	
func _update_property() -> void:
	if control:
		control.refresh()
