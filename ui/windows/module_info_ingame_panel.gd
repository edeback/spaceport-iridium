class_name  ModuleInfoIngamePanel
extends Control

@export var module_name_label: Label
@export var data_tabs: TabContainer
@export var alert_label: Label

var module_viewed: ModuleBase

var component_alerts: Dictionary[ComponentBase, String]

func _ready() -> void:
	pass
	
func set_module(module: ModuleBase) -> void:
	module_viewed = module
	for child_node: Node in data_tabs.get_children():
		data_tabs.remove_child(child_node)
		child_node.queue_free()
	module_name_label.text = module.module_data.name
	component_alerts.clear()
	for component: ComponentBase in module.components:
		component_alerts.set(component, component.last_error)
		component.new_error.connect(_on_component_error)
		if component.has_ui():
			data_tabs.add_child(component.get_ui())
	_refresh_alerts()
	module_viewed.tree_exiting.connect(_on_exit_button_pressed)

func _on_component_error(component: ComponentBase, error: String) -> void:
	component_alerts.set(component, error)
	_refresh_alerts()
	
func _refresh_alerts() -> void:
	var concat_alerts: String = ""
	for component: ComponentBase in component_alerts:
		var alert: String = component_alerts[component]
		if alert != "":
			if concat_alerts != "":
				concat_alerts += "\n"
			concat_alerts += alert
	if concat_alerts != "":
		alert_label.visible = true
		alert_label.text = concat_alerts
	else:
		alert_label.visible = false
			


func _on_exit_button_pressed() -> void:
	queue_free()
