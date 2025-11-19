class_name ResourceDisplayUI
extends PanelContainer

@export var icon_texture: TextureRect
@export var resource_name_label: Label
@export var resource_available_label: Label
var resource_data: ResourceData

func set_resource(resource: ResourceData) -> void:
	resource_data = resource
	icon_texture.texture = resource.icon
	resource_name_label.text = resource.name
	resource_available_label.text = "%.1f" % Global.resource_manager.resource_totals.get_or_add(resource, 0)
	Global.resource_manager.resource_changed.connect(_on_resource_changed)

func _on_resource_changed(resource: ResourceData, value: float) -> void:
	if resource_data == resource:
		resource_available_label.text = "%.1f" % value
