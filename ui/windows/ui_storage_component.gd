class_name UIStorageComponent
extends ModuleComponentUI

@export var resource_container: VBoxContainer
@export var resource_line: PackedScene
var storage_component: MultiStorageComponent
var storage_lines: Dictionary[ResourceData, StorageResourceLine]
var free_space_line: StorageResourceLine


func set_storage_component(component: MultiStorageComponent) -> void:
	name = component.name
	storage_component = component
	storage_component.storage_changed.connect(_on_storage_changed)
	var current_resources: Array[Node] = resource_container.get_children()
	for node: Node in current_resources:
		resource_container.remove_child(node)
		node.queue_free()
	storage_lines.clear()
	free_space_line = null
	for resource: ResourceData in storage_component.stored_resources:
		var storage_line: StorageResourceLine = resource_line.instantiate() as StorageResourceLine
		storage_line.stored_resource_name.text = resource.name
		storage_line.stored_resource_value.text = _format_resouce_value(storage_component.cur_stored.get_or_add(resource, 0))
		storage_lines[resource] = storage_line
		resource_container.add_child(storage_line)
	free_space_line = resource_line.instantiate() as StorageResourceLine
	free_space_line.stored_resource_name.text = "Free Space"
	free_space_line.stored_resource_value.text = _format_resouce_value(storage_component.space_available(true))
	resource_container.add_child(free_space_line)
		
		
func _format_resouce_value(value: float) -> String:
	return "%5.1f" % value
	
func _on_storage_changed(resource: ResourceData, new_value: float) -> void:
	var storage_line: StorageResourceLine = storage_lines[resource]
	if storage_line != null:
		storage_line.stored_resource_value.text = _format_resouce_value(new_value)
	free_space_line.stored_resource_value.text = _format_resouce_value(storage_component.space_available(true))
