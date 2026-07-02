class_name UIStorageComponent
extends ModuleComponentUI

@export var resource_container: VBoxContainer
@export var resource_line: PackedScene
@export var priority_value: SpinBox
@export var add_resource_menu: MenuButton

var storage_component: StorageComponent
var storage_lines: Dictionary[ResourceData, StorageResourceLine]
var current_dumped_resource: ResourceData = null

func _ready() -> void:
	add_resource_menu.get_popup().id_pressed.connect(_on_id_pressed)
	%ConfirmDumpButton.pressed.connect(_on_confirm_dump_button_pressed)
	%CancelDumpButton.pressed.connect(_on_cancel_dump_button_pressed)

func set_storage_component(component: StorageComponent) -> void:
	name = component.name
	storage_component = component
	storage_component.storage_changed.connect(_on_storage_changed)
	priority_value.value_changed.connect(_on_priority_value_changed)
	if not storage_component.player_configurable:
		add_resource_menu.visible = false
	refresh_display()
	
func refresh_display() -> void:
	var current_resources: Array[Node] = resource_container.get_children()
	for node: Node in current_resources:
		resource_container.remove_child(node)
		node.queue_free()
	storage_lines.clear()
	for resource: ResourceData in storage_component.storage_data:
		var storage_line: StorageResourceLine = resource_line.instantiate() as StorageResourceLine
		storage_line.stored_resource_name.text = resource.name
		storage_line.stored_resource_value.text = _format_resouce_value(storage_component.total_stored_by_resource(resource))
		storage_line.debug_add_button.pressed.connect(_on_debug_add_button_pressed.bind(resource))
		storage_line.dump_button.pressed.connect(_on_dump_button_pressed.bind(resource))
		if storage_component.player_configurable:
			storage_line.remove_resource_button.pressed.connect(_on_remove_resource_pressed.bind(resource))
			if storage_component.storage_data[resource].stored > 0:
				storage_line.remove_resource_button.disabled = true
			storage_line.desired_resources_spinbox.value_changed.connect(_on_desired_resources_changed.bind(resource))
		else:
			storage_line.remove_resource_button.visible = false
			storage_line.desired_resources_spinbox.editable = false
			storage_line.desired_resources_spinbox.value = storage_component.max_stored
		storage_lines[resource] = storage_line
		resource_container.add_child(storage_line)
	%FreeSpaceAvailableLabel.text = _format_resouce_value(storage_component.space_available())
	%FreeSpaceMaxLabel.text = _format_resouce_value(storage_component.max_stored)
	priority_value.value = storage_component.priority
	%DisplayFillMeterCheckbox.button_pressed = storage_component.display_storage_ui
	refresh_add_resource_menu()
		
		
func _format_resouce_value(value: int) -> String:
	return "%d" % value
	
func _on_storage_changed(resource: ResourceData, new_value: int) -> void:
	var storage_line: StorageResourceLine = storage_lines.get(resource)
	if storage_line != null:
		storage_line.stored_resource_value.text = _format_resouce_value(new_value)
		storage_line.remove_resource_button.disabled = new_value > 0
	%FreeSpaceAvailableLabel.text = _format_resouce_value(storage_component.space_available())

func _on_priority_value_changed(new_value: float) -> void:
	storage_component.priority = roundi(new_value)

func refresh_add_resource_menu() -> void:
	if not storage_component.player_configurable:
		return
	add_resource_menu.get_popup().clear()
	for index in range(Global.resource_manager.storable_resources.size()):
		var resource: ResourceData = Global.resource_manager.storable_resources[index]
		if storage_component.storage_data.has(resource):
			continue
		add_resource_menu.get_popup().add_item(resource.name, index)

func _on_id_pressed(id: int) -> void:
	if storage_component != null:
		var resource := Global.resource_manager.storable_resources[id]
		if not storage_component.storage_data.has(resource):
			storage_component.add_stored_resource(resource)
			refresh_display()

func _on_remove_resource_pressed(resource: ResourceData) -> void:
	if storage_component != null:
		if storage_component.storage_data.has(resource) and storage_component.storage_data[resource].stored == 0:
			storage_component.remove_stored_resource(resource)
			refresh_display()

func _on_desired_resources_changed(new_value: float, resource: ResourceData) -> void:
	pass

func _on_display_fill_meter_changed(new_value: bool) -> void:
	storage_component.display_storage_ui = new_value

func _on_debug_add_button_pressed(resource: ResourceData) -> void:
	if storage_component != null:
		storage_component.deposit(resource, 1)

func _on_dump_button_pressed(resource: ResourceData) -> void:
	current_dumped_resource = resource
	%ResourceToDumpLabel.text = resource.name
	var storage_data: StorageData = storage_component.storage_data[resource]
	%ResourceToDumpAmount.max_value = storage_data.stored
	%ResourceToDumpAmount.value = storage_data.stored
	%DumpResourcePanel.visible = true
	
func _on_confirm_dump_button_pressed() -> void:
	storage_component.withdraw(current_dumped_resource, %ResourceToDumpAmount.value, true)
	current_dumped_resource = null
	%DumpResourcePanel.visible = false
	
func _on_cancel_dump_button_pressed() -> void:
	current_dumped_resource = null
	%DumpResourcePanel.visible = false
	
	
