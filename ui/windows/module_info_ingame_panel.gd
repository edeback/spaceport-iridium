class_name  ModuleInfoIngamePanel
extends Control

@export var module_name_label: Label
@export var data_tabs: TabContainer

var module_viewed: ModuleBase

func _ready() -> void:
	pass
	
func set_module(module: ModuleBase) -> void:
	module_viewed = module
	for child_node: Node in data_tabs.get_children():
		data_tabs.remove_child(child_node)
		child_node.queue_free()
	module_name_label.text = module.in_game_name
	for component: ComponentBase in module.components:
		if component.has_ui():
			data_tabs.add_child(component.get_ui())


func _on_exit_button_pressed() -> void:
	queue_free()
