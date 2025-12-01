extends EditorInspectorPlugin

var grid_panel = preload("res://addons/module_editor/grid_panel.tscn")

func _can_handle(object: Object) -> bool:
	return object is ModuleBase or object is StructureComponent
	
func _parse_begin(object: Object) -> void:
	pass
	#var custom_control = grid_panel.instantiate()
	#add_custom_control(custom_control)
	
func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
	var test: Array[Vector2i] = []
	if type == typeof(test) and test.get_typed_builtin() == object.get(name).get_typed_builtin():
		add_property_editor(name, GridArrayEditor.new())
		print(name)
	return false
	
