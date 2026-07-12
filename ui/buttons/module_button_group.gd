class_name ModuleButtonGroup
extends FoldableContainer

@export var module_button: PackedScene
@export var button_container: VBoxContainer

var button_mapping: Dictionary[ModuleData, ModuleButton] = {}

func setup_group(group_name: String, module_datas: Array[ModuleData]) -> void:
	if group_name != "":
		title = group_name
	
	var current_buttons := button_container.get_children()
	for node in current_buttons:
		button_container.remove_child(node)
		node.queue_free()
	
	var any_visible: bool = false
	for module_data in module_datas:
		var new_button := module_button.instantiate() as ModuleButton
		new_button.set_moduledata(module_data)
		button_container.add_child(new_button)
		button_mapping[module_data] = new_button
		module_data.module_lock_changed.connect(module_lock_changed.bind(module_data))
		new_button.visible = module_data.is_unlocked()
		any_visible = any_visible or new_button.visible
		
	visible = any_visible

func module_lock_changed(unlocked: bool, module: ModuleData) -> void:
	if button_mapping.has(module):
		button_mapping[module].visible = unlocked
		var any_visible: bool = false
		for child: ModuleButton in button_mapping.values():
			if child.visible:
				any_visible = true
				break
		visible = any_visible
