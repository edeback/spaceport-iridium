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
## **WI-58 finished the job.** The two dead sub-panels are gone (thirty nodes,
## nine `unique_name_in_owner`s and a `font_color` at 1.3:1 contrast, none of it
## reachable since WI-56), and both [SpinBox]es are [Stepper]s.
##
## The tab asks [StoresModel] two separate questions rather than answering "can I
## edit this bin?" for itself. **Contents** - the accepted list, each desired
## amount, dumping - are the module's decision on all but the multipurpose bins,
## and it used to comment *"desired amounts are always configurable"* while the
## Stores panel disabled them on the same bins. **Priority** is the player's on
## every bin, always, because it is how the whole hauling system is steered.

@export var resource_container: VBoxContainer
@export var resource_line: PackedScene
@export var priority_stepper: Stepper
@export var priority_caption: Label
@export var edit_resources_button: ActionButton
@export var locked_note: Label

var storage_component: StorageComponent
var storage_lines: Dictionary[ResourceData, StorageResourceLine]

func set_storage_component(component: StorageComponent) -> void:
	name = component.name
	storage_component = component
	storage_component.storage_changed.connect(_on_storage_changed)
	# The range comes from [StoresModel] so this control and the Stores panel's
	# stepper cannot offer different ranges for the same field.
	priority_stepper.configure(component.priority,
		StoresModel.PRIORITY_MIN, StoresModel.PRIORITY_MAX, 1, true)
	priority_stepper.value_changed.connect(_on_priority_committed)
	priority_stepper.value_previewed.connect(_apply_priority_caption)
	# Priority and contents are **different questions** and this tab asks both.
	# Priority is the player's routing lever on every bin; the contents are the
	# module's decision on all but the multipurpose ones.
	priority_stepper.editable = StoresModel.priority_editable(component)
	edit_resources_button.visible = StoresModel.contents_editable(component)
	locked_note.text = StoresModel.locked_reason(component).to_upper()
	locked_note.visible = not locked_note.text.is_empty()
	edit_resources_button.pressed.connect(_on_edit_resources_pressed)
	refresh_display()

func refresh_display() -> void:
	for node: Node in resource_container.get_children():
		resource_container.remove_child(node)
		node.queue_free()
	storage_lines.clear()
	var editable: bool = StoresModel.contents_editable(storage_component)
	for resource: ResourceData in storage_component.storage_data:
		var storage_line: StorageResourceLine = resource_line.instantiate() as StorageResourceLine
		storage_line.stored_resource_name.text = resource.name
		storage_line.stored_resource_value.text = _format_slot_value(resource)
		storage_line.debug_add_button.pressed.connect(_on_debug_add_button_pressed.bind(resource))
		storage_line.dump_button.pressed.connect(_on_dump_button_pressed.bind(resource))
		storage_line.remove_resource_button.pressed.connect(
			_on_remove_resource_pressed.bind(resource))
		# The desired amount is as much a module decision as the accepted list is,
		# and so is dumping: a processor bay whose input target the player could
		# rewrite was the inspector disagreeing with the Stores card about the same
		# field. Priority is the exception and is set above, per bin, always live.
		storage_line.set_editable(editable)
		storage_line.desired_stepper.configure(storage_component.storage_data[resource].desired,
			0, storage_component.max_stored, 1, false)
		storage_line.desired_stepper.value_changed.connect(
			_on_desired_resources_changed.bind(resource))
		storage_line.autodump_indicator.visible = storage_component.storage_data[resource].autodump
		storage_lines[resource] = storage_line
		resource_container.add_child(storage_line)
	%FreeSpaceAvailableLabel.text = _format_resouce_value(storage_component.space_available())
	%FreeSpaceMaxLabel.text = _format_resouce_value(storage_component.max_stored)
	# Guarded for the same reason the Stores card guards its own: a refresh landing
	# mid-drag would snatch the number back, and the commit a moment later would
	# write that value out as if the player had chosen it.
	if not priority_stepper.is_editing():
		priority_stepper.value = storage_component.priority
		_apply_priority_caption(storage_component.priority)
	# Never gated on the bin's editability: the fill meter is a **display**
	# preference about the player's own screen, not a property of the bin. A
	# processor bay whose contents the module decides is still a bay the player may
	# want a meter on.
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

## The **committed** value only. [Stepper] fires this on release or after a quiet
## period, which is what keeps a drag across the 201-value range to one re-sort;
## the [SpinBox] this replaces fired on every step, so holding the arrow re-sorted
## the job board about two hundred times (WI-58).
##
## update_priority(), not a direct field write: assigning `priority` alone leaves
## any already-posted import/export job at its old priority, and JobManager's
## re-sort can't repair an ordering nothing told it had changed (WI-45 A5).
func _on_priority_committed(new_value: int) -> void:
	storage_component.update_priority(new_value)
	_apply_priority_caption(new_value)

## The words under the number, from the same table the Stores card reads - one
## place per vocabulary.
func _apply_priority_caption(value: int) -> void:
	priority_caption.text = StoresModel.priority_label(value).to_upper()
	priority_caption.add_theme_color_override("font_color", StoresModel.priority_color(value))

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

func _on_desired_resources_changed(new_value: int, resource: ResourceData) -> void:
	var storage_data: StorageData = storage_component.storage_data.get(resource)
	if storage_data != null:
		storage_data.desired = new_value

func _on_display_fill_meter_changed(new_value: bool) -> void:
	storage_component.display_storage_ui = new_value

func _on_debug_add_button_pressed(resource: ResourceData) -> void:
	if storage_component != null:
		storage_component.deposit(resource, 1)
