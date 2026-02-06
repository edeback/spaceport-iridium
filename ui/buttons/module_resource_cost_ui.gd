class_name ModuleResourceCostUI
extends PanelContainer

@export var icon_texture: TextureRect
@export var resource_cost_label: Label
var resource_data: ResourceData
var resource_cost: int

func set_resource(resource: ResourceData, cost: int) -> void:
	resource_data = resource
	resource_cost = cost
	resource_cost_label.text = "%d" % cost
	icon_texture.texture = resource.icon
	if resource.get_total() >= resource_cost:
		modulate = Color.WHITE
	else:
		modulate = Color.RED
	resource.total_changed.connect(_on_resource_changed)

func _on_resource_changed(value: int) -> void:
	if value >= resource_cost:
		modulate = Color.WHITE
	else:
		modulate = Color.RED
