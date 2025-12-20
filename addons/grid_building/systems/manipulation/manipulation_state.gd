class_name ManipulationState
extends GBResource
## The manipulation state holds reference
## to the object being manipulated and its temporary
## manipulated copy. It also is the source of signals regarding
## object manipulation like when moving or demolishing an object
## is started, canceled, or stopped.

## Emitted when the active manipulation on an object changes
## Null means there is no manipulation currently active on the state.
signal data_changed(manipulation: ManipulationData)

## The manipulatable that is being hovered over
signal active_manipulatable_changed(active: Manipulatable)

## Signal for when the currently active target node changes
signal active_target_node_changed(active: Node)

## When the node for performing transform adjustments to (rotate, flip, etc)
## during a manipulation changes
signal parent_changed(parent: ManipulationParent)

## Emitted when a manipulation action is started
signal started(data: ManipulationData)

## Emitted when a manipulation action is confirmed
signal confirmed(data: ManipulationData)

## Emitted when a manipulation action is finished
signal finished(data: ManipulationData)

## Emitted when a manipulation action is canceled
signal canceled(data: ManipulationData)

## Emitted when a manipulation action fails
signal failed(data: ManipulationData)

var _owner_context: GBOwnerContext

func _init(p_owner_context: GBOwnerContext) -> void:
	_owner_context = p_owner_context

## Data of the active manipulation
var data: ManipulationData:
	set(value):
		if data == value:
			return

		if data != null:
			data.status_changed.disconnect(_on_data_status_changed)

		data = value
		data_changed.emit(data)

		if data != null:
			data.status_changed.connect(_on_data_status_changed)

## The current targeted (hovered, etc) manipulatable component, if any
var active_manipulatable : Manipulatable:
	set(value):
		if active_manipulatable == value:
			return

		active_manipulatable = value
		active_manipulatable_changed.emit(active_manipulatable)

## Internal backing field for active_target_node property
var _active_target_node: Node

## Compatibility alias required by older tests referencing 'current_target'.
## Accepts either a Manipulatable directly or a Node/Node2D whose descendant has a Manipulatable.
var active_target_node: Node:
	set(value):
		if value == _active_target_node:
			return
		
		if value == null:
			_active_target_node = null
			active_manipulatable = null
			active_target_node_changed.emit(null)
			return
		if value is Manipulatable:
			_active_target_node = value.root if value.root else value
			active_manipulatable = value
			active_target_node_changed.emit(value)
			return
		# Try to resolve a Manipulatable from a Node/Node2D container
		if value is Node:
			var m: Manipulatable = GBSearchUtils.find_first(value, Manipulatable)
			if m:
				_active_target_node = value
				active_manipulatable = m
				active_target_node_changed.emit(m)
				return
		push_warning("Assigned active_target_node without a Manipulatable component. Ignoring.")
	get:
		return _active_target_node

## Node which is actually manipulated to effect all children including the active target node
## and any other nodes that need to move to be updated with the base
## The ManipulationParent node responsible for coordinating transforms during manipulation.
## Enforces ManipulationParent class to ensure proper transform coordination methods are available.
## This ensures indicators rotate/flip with manipulated objects via transform inheritance.
var parent: ManipulationParent:
	set(value):
		if parent == value:
			return

		parent = value
		parent_changed.emit(parent)

## Gets the active manipulator from the _owner_context GBOwnerContext.
func get_manipulator() -> GBOwner:
	if _owner_context:
		return _owner_context.get_owner()
	else:
		return null

## Sets the target node. Either takes a regular node or a manipulatable.
## Will set both the active_target_node and the active_manipulatable if possible
func set_targeted(p_node : Node) -> void:
	if p_node is Manipulatable:
		active_manipulatable = p_node
		active_target_node = active_manipulatable.root
		return
	
	active_target_node = p_node
	active_manipulatable = GBSearchUtils.find_first(active_target_node, "Manipulatable")

## Checks if the currently targeted manipulatable is movable.[br][br]
## [code]return[/code]: [i]bool[/i] - True if targeted object can be moved, false otherwise
func is_targeted_movable() -> bool:
	if active_manipulatable == null || active_manipulatable.settings == null:
		return false
	else:
		return active_manipulatable.settings.movable

## Checks if the state is ready for manipulation.
func validate_setup() -> bool:
	var passing = true

	if parent == null:
		push_warning(
			(
				"[parent] There is no manipulation parent target set in the manipulation_state %s"
				% resource_path
			)
		)
		passing = false

	return passing


## Private handler for status changes in manipulation data.
## Emits specific signals for each status so other nodes like UI can respond.[br][br]
## [code]p_status[/code]: [i]GBEnums.Status[/i] - New status of the manipulation data
func _on_data_status_changed(p_status: GBEnums.Status):
	match p_status:
		GBEnums.Status.STARTED:
			started.emit(data)
		GBEnums.Status.FAILED:
			failed.emit(data)
		GBEnums.Status.FINISHED:
			finished.emit(data)
		GBEnums.Status.CANCELED:
			canceled.emit(data)


## Returns an array of editor-time validation issues for this resource
func get_editor_issues() -> Array[String]:
	var issues: Array[String] = []
	
	if _owner_context == null:
		issues.append("ManipulationState: No owner context provided")
	
	return issues


## Returns an array of runtime validation issues for this resource
func get_runtime_issues() -> Array[String]:
	var issues: Array[String] = []
	
	if parent == null:
		issues.append("ManipulationState: No parent node set for manipulation operations")
	
	if active_manipulatable != null and active_manipulatable.settings == null:
		issues.append("ManipulationState: Active manipulatable has no settings configured")
	
	return issues
