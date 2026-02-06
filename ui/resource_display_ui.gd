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
	resource_available_label.text = "%d" % resource.get_total()
	resource.total_changed.connect(_on_resource_changed)

func _on_resource_changed(value: int) -> void:
	resource_available_label.text = "%d" % value

func _on_resource_clicked() -> void:
	if resource_data.has_global_store:
		resource_data.change_global_total(1000)
