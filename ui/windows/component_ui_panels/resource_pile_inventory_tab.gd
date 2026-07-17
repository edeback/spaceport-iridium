class_name ResourcePileInventoryTab
extends PanelContainer

@export var simple_inventory_row: PackedScene
@export var resource_container: VBoxContainer

var resource_pile: ResourcePile = null
var resource_rows: Dictionary[ResourceData, SimpleInventoryRow]

func set_resource_pile(pile: ResourcePile) -> void:
	if resource_pile != null:
		resource_pile.pile_changed.disconnect(_on_pile_changed)
	
	resource_pile = pile
	resource_pile.pile_changed.connect(_on_pile_changed)
	resource_pile.despawning.connect(_on_exit_button_pressed)
	set_position(resource_pile.get_global_transform_with_canvas().get_origin())
	
	# Clear existing rows
	for child in resource_container.get_children():
		child.queue_free()
	resource_rows.clear()

	# Populate initial display
	for resource_data in resource_pile.get_contained_resources():
		_on_pile_changed(resource_data, resource_pile.get_total(resource_data))

func _on_pile_changed(resource: ResourceData, new_amount: int) -> void:
	if new_amount == 0:
		if resource_rows.has(resource):
			resource_container.remove_child(resource_rows[resource])
			resource_rows.erase(resource)
		return
	
	if not resource_rows.has(resource):
		var inventory_row: SimpleInventoryRow = simple_inventory_row.instantiate()
		resource_container.add_child(inventory_row)
		resource_rows[resource] = inventory_row
		resource_rows[resource].stored_name.text = resource.name
	var value_text: String = str(new_amount)
	if resource.has_variance:
		var container: ResourceStackContainer = resource_pile.contents.get(resource)
		if container != null:
			var avg: float = container.average_instance_value()
			if avg >= 0.0:
				value_text += " (%d%%)" % roundi(avg * 100.0)
	resource_rows[resource].stored_value.text = value_text

func _process(_delta: float) -> void:
	# Turns out this is necessary to keep the panel in the correct position if you move your screen around
	if is_instance_valid(resource_pile):
		set_position(resource_pile.get_global_transform_with_canvas().get_origin())
	else:
		resource_pile = null
		_on_exit_button_pressed()
		
func _on_exit_button_pressed() -> void:
	queue_free()
