class_name UIStorageComponent
extends ModuleComponentUI

## The inspector's storage tab: one line per stored resource, plus this bin's
## haul priority and its free space.
##
## **WI-56 took its two overlays away.** The accepted-resource checklist and the
## dump-with-amount confirmation used to be hidden sub-panels inside this scene,
## which meant they were reachable only from a module selection - one bin at a
## time, which is the access problem the Stores panel exists to fix. Both now live
## in [StorageOverlays] and both surfaces call in, so there is exactly one
## implementation of "dump destroys resources" and one of "unchecking a stocked
## resource moves it to the overflow pile".
##
## The scene still authors those two sub-panels; they are simply never shown. They
## are left in place rather than deleted because removing `%`-unique-named
## subtrees from a scene is a change nothing here can verify, and a few unreachable
## nodes cost less than a half-edited scene.

@export var resource_container: VBoxContainer
@export var resource_line: PackedScene
@export var priority_value: SpinBox
@export var edit_resources_button: Button

var storage_component: StorageComponent
var storage_lines: Dictionary[ResourceData, StorageResourceLine]

func set_storage_component(component: StorageComponent) -> void:
	name = component.name
	storage_component = component
	storage_component.storage_changed.connect(_on_storage_changed)
	# The range comes from [StoresModel] so this box and the Stores panel's stepper
	# cannot offer different ranges for the same field. Set before the connection:
	# narrowing a range clamps the value, and a clamp would fire `value_changed`
	# and write a priority the player never chose.
	priority_value.min_value = StoresModel.PRIORITY_MIN
	priority_value.max_value = StoresModel.PRIORITY_MAX
	priority_value.value_changed.connect(_on_priority_value_changed)
	if not storage_component.player_configurable:
		edit_resources_button.visible = false
	edit_resources_button.pressed.connect(_on_edit_resources_pressed)
	refresh_display()

func refresh_display() -> void:
	for node: Node in resource_container.get_children():
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

func _on_storage_changed(resource: ResourceData, _new_value: int) -> void:
	var storage_line: StorageResourceLine = storage_lines.get(resource)
	if storage_line != null:
		storage_line.stored_resource_value.text = _format_slot_value(resource)
	%FreeSpaceAvailableLabel.text = _format_resouce_value(storage_component.space_available())

## update_priority(), not a direct field write: assigning `priority` alone leaves
## any already-posted import/export job at its old priority, and JobManager's
## re-sort can't repair an ordering nothing told it had changed (WI-45 A5).
func _on_priority_value_changed(new_value: float) -> void:
	storage_component.update_priority(roundi(new_value))

## Both overlays are opened on the HUD rather than inside this tab: the inspector
## swaps its pages on every selection change and would free a dialog the player
## was halfway through answering.
func _on_edit_resources_pressed() -> void:
	StorageOverlays.open_edit(_dialog_host(), storage_component, refresh_display)

func _on_dump_button_pressed(resource: ResourceData) -> void:
	StorageOverlays.open_resource(_dialog_host(), storage_component, resource, refresh_display)

func _dialog_host() -> Node:
	return Global.ui_main if Global.ui_main != null and is_instance_valid(Global.ui_main) else self

## Drops a resource from this bin's accepted list, moving whatever it still holds
## to the module's overflow pile first - the shared path, so this and the
## checklist cannot disagree about whether the stock survives.
func _on_remove_resource_pressed(resource: ResourceData) -> void:
	if storage_component == null or not storage_component.storage_data.has(resource):
		return
	var amount: int = storage_component.storage_data[resource].stored
	if amount != 0:
		StorageOverlays.dump_to_pile(storage_component, resource, amount)
	storage_component.remove_stored_resource(resource)
	refresh_display()

func _on_desired_resources_changed(new_value: float, resource: ResourceData) -> void:
	var storage_data: StorageData = storage_component.storage_data[resource]
	storage_data.desired = int(new_value)

func _on_display_fill_meter_changed(new_value: bool) -> void:
	storage_component.display_storage_ui = new_value

func _on_debug_add_button_pressed(resource: ResourceData) -> void:
	if storage_component != null:
		storage_component.deposit(resource, 1)
