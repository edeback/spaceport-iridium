## Input action name definitions for plugin systems and UI.
class_name GBActions
extends GBResource

@export_group("Mode")
## Action to exit build mode.
@export var off_mode: StringName = &"off_mode"

## Action for entering info mode.
@export var info_mode : StringName = &"info_mode"

## Action for entering build mode.
@export var build_mode : StringName = &"build_mode"

## Action for entering move mode.
@export var moving_mode : StringName = &"moving_mode"

## Action to enter demolish mode.
@export var demolish_mode : StringName = &"demolish_mode"

@export_group("Building")
## Confirm a build.
@export var confirm_build : StringName = &"confirm"

@export_group("Manipulation")
## Action for confirming an action to be taken within manipulation mode.
## Grid building plugin. What the confirmation does is context sensitive whether building with a preview instance, moving an existing object, or demolishing an object already within the scene.
@export var confirm_manipulation: StringName = &"confirm"

## The preview instance to the right when triggered.
@export var rotate_right: StringName = &"rotate_right":
	set(value):
		rotate_right = value
		property_list_changed.emit()
		
## Names of actions that the building system will rotate the preview instance to the left when triggered.
@export var rotate_left: StringName = &"rotate_left":
	set(value):
		rotate_left = value
		property_list_changed.emit()

## Actions that flip the preview instance horizontally during build mode.
@export var flip_horizontal: StringName = &"flip_horizontal" :
	set(value):
		flip_horizontal = value
		property_list_changed.emit()

## Actions that flip the preview instance vertically during build mode
@export var flip_vertical: StringName = &"flip_vertical" :
	set(value):
		flip_vertical = value
		property_list_changed.emit()

@export_group("Movement")
## Movement actions when using keyboard input for positioner movement
@export var positioner_up: StringName = &"positioner_up" :
	set(value):
		positioner_up = value
		property_list_changed.emit()

@export var positioner_down: StringName = &"positioner_down" :
	set(value):
		positioner_down = value
		property_list_changed.emit()

@export var positioner_left: StringName = &"positioner_left" :
	set(value):
		positioner_left = value
		property_list_changed.emit()

@export var positioner_right: StringName = &"positioner_right" :
	set(value):
		positioner_right = value
		property_list_changed.emit()

## Recenter the positioner to the viewport/camera center (snapped to tile)
@export var positioner_center: StringName = &"positioner_center" :
	set(value):
		positioner_center = value
		property_list_changed.emit()

func validate_action(p_action_name : StringName) -> Array[String]:
	var issues : Array[String] = []

	if not InputMap.has_action(p_action_name):
		issues.append("[%s] action undefined in Project -> Project Settings -> Input Map" % p_action_name)
	
	return issues

## Make sure each action is set in the input map
func get_editor_issues() -> Array[String]:
	var issues : Array[String] = []

	for action in [off_mode, info_mode, build_mode, moving_mode, demolish_mode, confirm_build, confirm_manipulation, rotate_right, rotate_left, flip_horizontal, flip_vertical]:
		issues.append_array(validate_action(action))

	return issues

func get_runtime_issues() -> Array[String]:
	return get_editor_issues()
