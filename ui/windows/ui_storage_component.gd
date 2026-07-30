class_name UIStorageComponent
extends ModuleComponentUI

@export var resource_container: VBoxContainer
@export var resource_line: PackedScene
@export var priority_value: SpinBox
@export var edit_resources_button: Button

var storage_component: StorageComponent
var storage_lines: Dictionary[ResourceData, StorageResourceLine]
var current_dumped_resource: ResourceData = null
## Resource -> its checkbox in the Edit panel, rebuilt each time the panel opens.
var edit_checkboxes: Dictionary[ResourceData, CheckBox] = {}

func _ready() -> void:
	edit_resources_button.pressed.connect(_on_edit_resources_pressed)
	%ConfirmEditButton.pressed.connect(_on_confirm_edit_button_pressed)
	%CancelEditButton.pressed.connect(_on_cancel_edit_button_pressed)
	%ConfirmDumpButton.pressed.connect(_on_confirm_dump_button_pressed)
	%CancelDumpButton.pressed.connect(_on_cancel_dump_button_pressed)

func set_storage_component(component: StorageComponent) -> void:
	name = component.name
	storage_component = component
	storage_component.storage_changed.connect(_on_storage_changed)
	priority_value.value_changed.connect(_on_priority_value_changed)
	if not storage_component.player_configurable:
		edit_resources_button.visible = false
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
		storage_line.stored_resource_value.text = _format_slot_value(resource)
		storage_line.debug_add_button.pressed.connect(_on_debug_add_button_pressed.bind(resource))
		storage_line.dump_button.pressed.connect(_on_dump_button_pressed.bind(resource))
		# Per-line removal is still nice to have
		if storage_component.player_configurable:
			storage_line.remove_resource_button.pressed.connect(_on_remove_resource_pressed.bind(resource))
		else:
			storage_line.remove_resource_button.visible = false
		# Desired amounts are always configurable
		storage_line.desired_resources_spinbox.value = storage_component.storage_data[resource].desired
		storage_line.desired_resources_spinbox.value_changed.connect(_on_desired_resources_changed.bind(resource))
		storage_line.autodump_indicator.visible = storage_component.storage_data[resource].autodump
		storage_lines[resource] = storage_line
		resource_container.add_child(storage_line)
	%FreeSpaceAvailableLabel.text = _format_resouce_value(storage_component.space_available())
	%FreeSpaceMaxLabel.text = _format_resouce_value(storage_component.max_stored)
	priority_value.value = storage_component.priority
	%DisplayFillMeterCheckbox.button_pressed = storage_component.display_storage_ui
		
		
func _format_resouce_value(value: int) -> String:
	return "%d" % value

## Amount plus, for variance-carrying resources with known instance data, the
## slot's average richness/quality - e.g. "14 (72%)".
func _format_slot_value(resource: ResourceData) -> String:
	var data: StorageData = storage_component.storage_data.get(resource)
	if data == null:
		return _format_resouce_value(0)
	var text: String = _format_resouce_value(data.stored)
	if resource.has_variance:
		var avg: float = data.average_instance_value()
		if avg >= 0.0:
			text += " (%d%%)" % roundi(avg * 100.0)
	return text

func _on_storage_changed(resource: ResourceData, new_value: int) -> void:
	var storage_line: StorageResourceLine = storage_lines.get(resource)
	if storage_line != null:
		storage_line.stored_resource_value.text = _format_slot_value(resource)
	%FreeSpaceAvailableLabel.text = _format_resouce_value(storage_component.space_available())

## update_priority(), not a direct field write: assigning `priority` alone leaves
## any already-posted import/export job at its old priority, and JobManager's
## re-sort can't repair an ordering nothing told it had changed (WI-45 A5).
func _on_priority_value_changed(new_value: float) -> void:
	storage_component.update_priority(roundi(new_value))

# Builds one checkbox per storable resource, pre-checked for whatever the
# component currently stores, then shows the overlay. Rebuilt each open so the
# checked state always reflects the live storage_data.
func _on_edit_resources_pressed() -> void:
	if storage_component == null or not storage_component.player_configurable:
		return
	var checklist: GridContainer = %ResourceChecklistContainer
	for child: Node in checklist.get_children():
		checklist.remove_child(child)
		child.queue_free()
	edit_checkboxes.clear()
	for resource: ResourceData in Global.resource_manager.storable_resources:
		var checkbox := CheckBox.new()
		checkbox.text = resource.name
		checkbox.button_pressed = storage_component.storage_data.has(resource)
		checkbox.icon = resource.icon
		checkbox.add_theme_constant_override("icon_max_width", 30)
		checklist.add_child(checkbox)
		edit_checkboxes[resource] = checkbox
	%EditResourcesPanel.visible = true

# Reconcile the component's stored-resource set with the checkboxes: add newly
# checked resources, remove newly unchecked ones. Removed resources still
# holding stock get dumped to the module's overflow pile first (same behavior
# the per-line remove button used to have).
func _on_confirm_edit_button_pressed() -> void:
	if storage_component != null:
		for resource: ResourceData in edit_checkboxes:
			var checked: bool = edit_checkboxes[resource].button_pressed
			var currently_stored: bool = storage_component.storage_data.has(resource)
			if checked and not currently_stored:
				storage_component.add_stored_resource(resource)
			elif not checked and currently_stored:
				if storage_component.storage_data[resource].stored != 0:
					dump_stacks(resource, storage_component.storage_data[resource].stored)
				storage_component.remove_stored_resource(resource)
	%EditResourcesPanel.visible = false
	refresh_display()
	
func _on_remove_resource_pressed(resource: ResourceData) -> void:
	if storage_component != null and storage_component.storage_data.has(resource):
		# Dump any that are already here
		if storage_component.storage_data[resource].stored != 0:
			dump_stacks(resource, storage_component.storage_data[resource].stored)
		storage_component.remove_stored_resource(resource)
		refresh_display()

func _on_cancel_edit_button_pressed() -> void:
	%EditResourcesPanel.visible = false

func dump_stacks(resource: ResourceData, amount: int) -> void:
	var withdrawn: Array[ResourceStack] = storage_component.withdraw_stacks(resource, amount, true)
	if not withdrawn.is_empty():
		if storage_component.owner_module != null:
			storage_component.owner_module.get_or_create_overflow_pile().add_stacks(resource, withdrawn)
		else:
			# This should never happen as components are always on modules, but here for completeness
			var pile: ResourcePile = ResourcePile.spawn(Global.world_manager.pawn_layer, storage_component.global_position)
			pile.add_stacks(resource, withdrawn)

func _on_desired_resources_changed(new_value: float, resource: ResourceData) -> void:
	var storage_data: StorageData = storage_component.storage_data[resource]
	storage_data.desired = new_value

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
	%ResourceToDumpAmount.value = 0
	(%AutodumpButton as Button).set_pressed_no_signal(storage_data.autodump)
	%DumpResourcePanel.visible = true
	
func _on_confirm_dump_button_pressed() -> void:
	# Gone forever!
	storage_component.withdraw_stacks(current_dumped_resource, %ResourceToDumpAmount.value, true)
	var autodump: bool = (%AutodumpButton as Button).button_pressed
	storage_component.storage_data[current_dumped_resource].autodump = autodump
	storage_lines[current_dumped_resource].autodump_indicator.visible = autodump
	%DumpResourcePanel.visible = false
	
func _on_cancel_dump_button_pressed() -> void:
	current_dumped_resource = null
	%DumpResourcePanel.visible = false

		
