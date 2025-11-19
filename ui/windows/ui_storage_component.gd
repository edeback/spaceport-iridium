class_name UIStorageComponent
extends ModuleComponentUI

@export var resource_container: VBoxContainer
@export var resource_line: PackedScene
@export var priority_value: SpinBox
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
		storage_line.stored_resource_value.text = _format_resouce_value(storage_component.total_stored_by_resource(resource))
		storage_lines[resource] = storage_line
		resource_container.add_child(storage_line)
	free_space_line = resource_line.instantiate() as StorageResourceLine
	free_space_line.stored_resource_name.text = "Free Space"
	free_space_line.stored_resource_value.text = _format_resouce_value(storage_component.space_available(true))
	priority_value.value = component.priority
	priority_value.value_changed.connect(_on_priority_value_changed)
	resource_container.add_child(free_space_line)
		
		
func _format_resouce_value(value: float) -> String:
	return "%5.1f" % value
	
func _on_storage_changed(resource: ResourceData, new_value: float) -> void:
	var storage_line: StorageResourceLine = storage_lines.get(resource)
	if storage_line == null and resource.base_resource != null:
		storage_line = storage_lines.get(resource.base_resource)
	if storage_line != null:
		if resource.base_resource != null:
			new_value = storage_component.total_stored_by_resource(resource.base_resource)
		storage_line.stored_resource_value.text = _format_resouce_value(new_value)
	free_space_line.stored_resource_value.text = _format_resouce_value(storage_component.space_available(true))

func _on_priority_value_changed(new_value: float) -> void:
	storage_component.priority = roundi(new_value)
