class_name BuildingState
extends RefCounted
## Manages communication between the building system and connected objects during gameplay. 
## Emits signals for build actions, previews, and state changes to coordinate placement. 
## Validates readiness when the tile map is set, requiring all properties to be assigned in the same frame.

## Emitted when an object is successfully placed into the game world.
signal success(build_action_data: BuildActionData)

## Emitted when a build action fails.
signal failed(build_action_data: BuildActionData)

## Emitted when the build preview instance changes.
signal preview_changed(preview: Node)

## Emitted when the parent node for placed objects changes.
signal placed_parent_changed(placed_parent: Node)

## Emitted when the connected building system changes (currently unused).
signal system_changed(system: BuildingSystem)


## Shared reference to the user controlling the building system.
var _owner_context: GBOwnerContext

## The parent node where objects are placed during build mode.
var placed_parent: Node:
	set(value):
		if placed_parent == value:
			return
		if placed_parent:
			placed_parent.tree_exited.disconnect(_on_placed_parent_tree_exited)
		placed_parent = value
		placed_parent_changed.emit(placed_parent)
		if placed_parent:
			placed_parent.tree_exited.connect(_on_placed_parent_tree_exited)

## The current preview object in build mode, moving with the mouse until placed.
var preview: Node:
	set(value):
		if preview == value:
			return
		if preview:
			preview.tree_exited.disconnect(_on_preview_tree_exited)
		preview = value
		preview_changed.emit(preview)
		if preview:
			preview.tree_exited.connect(_on_preview_tree_exited)

func _init(p_owner_context : GBOwnerContext) -> void:
	_owner_context = p_owner_context

## Returns the placer node from the _owner_context, or null if unset.
func get_owner() -> GBOwner:
	return _owner_context.get_owner()

## Validates the state’s runtime properties, skipping checks in the editor or when build mode is off.
func get_editor_issues() -> Array[String]:
	return []

## Checks properties that should be set at runtime before building system operations
func get_runtime_issues() -> Array[String]:
	var issues: Array[String] = []
	issues.append_array(GBValidation.check_not_null(self, ["_owner_context"]))

	if not get_owner():
		issues.append("No placer set in _owner_context. Cannot identify object placer.")

	if placed_parent == null:
		issues.append("No placed parent set. There is no parent for built objects. It should generally be set by a GBLevelContext node under your game level.")

	return issues

## Resets placed_parent when it exits the scene tree.
func _on_placed_parent_tree_exited() -> void:
	placed_parent = null

## Resets preview when it exits the scene tree.
func _on_preview_tree_exited() -> void:
	preview = null
