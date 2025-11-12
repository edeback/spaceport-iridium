class_name ModuleButtonGroup
extends FoldableContainer

@export var module_button: PackedScene
@export var button_container: VBoxContainer

func setup_group(group_name: String, module_datas) -> void:
	if group_name != "":
		title = group_name
	
	var current_buttons = button_container.get_children()
	for node in current_buttons:
		button_container.remove_child(node)
		node.queue_free()
	
	for module_data in module_datas:
		var new_button = module_button.instantiate() as ModuleButton
		new_button.set_moduledata(module_data)
		button_container.add_child(new_button)
