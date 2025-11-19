class_name ResourceManager
extends Node

var resource_totals: Dictionary[ResourceData, float] = {}

# Dictionary[ResourceData, Array[MultiStorageComponent]]
var resource_storage_components: Dictionary = {}

var resources_changed: Array[ResourceData] = []

signal resource_changed(resource: ResourceData, new_value: float)

func _ready() -> void:
	Global.resource_manager = self
	
func _process(delta: float) -> void:
	for resource: ResourceData in resources_changed:
		_recalc_resource(resource)
	resources_changed.clear()
	
	
func register_component(resource: ResourceData, component: MultiStorageComponent) -> void:
	var components = resource_storage_components.get_or_add(resource, [])
	if not components.has(component):
		components.append(component)
	queue_recalc_resource(resource)

func unregister_component(resource: ResourceData, component: MultiStorageComponent) -> void:
	var components = resource_storage_components.get_or_add(resource, [])
	components.erase(component)
	queue_recalc_resource(resource)
	
func queue_recalc_resource(resource: ResourceData) -> void:
	if resource.base_resource != null:
		resource = resource.base_resource
	if not resources_changed.has(resource):
		resources_changed.append(resource)
		
func _recalc_resource(resource: ResourceData) -> void:
	var total: float = 0
	var components_array = resource_storage_components.get_or_add(resource, [])
	for storage_component: MultiStorageComponent in components_array:
		total += storage_component.total_stored_by_resource(resource)
	resource_totals.set(resource, total)
	resource_changed.emit(resource, total)
