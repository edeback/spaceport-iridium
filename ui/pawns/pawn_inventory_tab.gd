class_name PawnInventoryTab
extends PanelContainer

@export var simple_inventory_row: PackedScene
@export var resource_container: VBoxContainer

var pawn_inventory: PawnInventoryComponent = null
var resource_rows: Dictionary[ResourceData, SimpleInventoryRow]

func set_pawn(_pawn: PawnBase) -> void:
	pawn_inventory = _pawn.inventory_component
	pawn_inventory.inventory_changed.connect(_inventory_changed)
	%FreeSpaceMaxLabel.text = str(_pawn.carrying_capacity)
	for resource in pawn_inventory.carried:
		_inventory_changed(resource, pawn_inventory.get_carried_amount(resource))
	_refresh_total()
	
func _inventory_changed(resource: ResourceData, new_value: int) -> void:
	if new_value == 0:
		if resource_rows.has(resource):
			resource_container.remove_child(resource_rows[resource])
			resource_rows.erase(resource)
			_refresh_total()
		return
		
	if not resource_rows.has(resource):
		var inventory_row: SimpleInventoryRow = simple_inventory_row.instantiate()
		resource_container.add_child(inventory_row)
		resource_rows[resource] = inventory_row
		resource_rows[resource].stored_name.text = resource.name
	resource_rows[resource].stored_value.text = str(new_value)
	_refresh_total()
	
func _refresh_total() -> void:
	%FreeSpaceAvailableLabel.text = str(pawn_inventory.space_available())
