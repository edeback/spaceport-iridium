## Settings concerning moving objects within the game world
class_name ManipulationSettings
extends GBResource

## Amount to rotate objects with every step of call to left or right rotation
@export_range(0.0, 360.0, 0.01) var rotate_increment_degrees = 90.0:
	set(value):
		rotate_increment_degrees = value

## Allows objects which that have a Manipulatable component
## with demolish enabled to be removed by the demolish manipulation function
@export var enable_demolish: bool

## Whether an object that is selected for moving can be demolished
## while is it being moved in move mode
@export var demolish_while_moving: bool

## Allows the building system to rotate objects left and right during build mode
@export var enable_rotate = true:
	set(value):
		enable_rotate = value

## Allows the building system to flip objects horizontally during build mode
@export var enable_flip_horizontal = true:
	set(value):
		enable_flip_horizontal = value

## Allows the building system to flip objects vertically during build mode
@export var enable_flip_vertical = true:
	set(value):
		enable_flip_vertical = value

## Whether the transform of the manipulation target object
## should be reset to Transform2D.IDENTITY when starting a manipulation
## [br][br]
## This may be most useful when moving RigidBody2Ds or other objects
## that rotate during gameplay to make placing to a new location clean
## as the original scene designates.
@export var reset_transform_on_manipulation = false

## Whether you want to disable a layer when a manipulation like a move
## starts until it is canceled or finished
@export var disable_layer_in_manipulation = false

## Layer that you want disabled in source object during manipulation
## until the manipulation is finished or canceled.
## [br][br]
## Recommended to use a placement only layer and not to disable
## the layer that effects physics of objects currently moving around in the scene
## [br][br]
## Alternatively, you could put game into a pause state on started signal from ManipulationState
@export_range(0, 32, 1) var disabled_physics_layer: int

## String to append to an object's move copy node name to differentiate it from the original source object
@export var move_suffix: String = ""

#region Action Messages

@export_group("Messages - Demolish")
## Message displayed when demolish succeeds
@export var demolish_success := "%s was demolished successfully."
## Message when target cannot be demolished
@export var failed_not_demolishable := "%s is not demolishable"
## Message when demolish target was already deleted
@export var demolish_already_deleted := "Target of demolish_data %s was already deleted."

@export_group("Messages - Move")
## Message when move action starts
@export var move_started := "Moving %s"
## Message displayed when move succeeds
@export var move_success := "%s moved to new location successfully."
## Message when move fails to start
@export var failed_to_start_move := "%s was unable to start move successfully."
## Message when there is no move target
@export var no_move_target := "There is no target to move."
## Message when placement at target location is invalid
@export var failed_placement_invalid := "Cannot place %s here."

@export_group("Messages - Validation")
## Message when all placement rules succeed
@export var all_succeeded := "All placement rules succeeded validation."
## Message when rule setup fails
@export var failed_to_setup_rules := "One or more rules failed to setup correctly."

@export_group("Messages - Rotate")
## Message when target cannot be rotated
@export var target_not_rotatable := "%s cannot be rotated."

@export_group("Messages - Flip")
## Message when target cannot be flipped horizontally
@export var target_not_flippable_horizontally := "%s target cannot be flipped horizontally."
## Message when target cannot be flipped vertically
@export var target_not_flippable_vertically := "%s target cannot be flipped vertically."

@export_group("Messages - General Failures")
## Message when manipulation data is invalid
@export var invalid_data := "%s is not valid. Cannot move object"
## Message when manipulation state validation fails
@export var failed_manipulation_state_invalid := "Manipulation state failed to validate. Check warnings for possible missing properties."
## Message when object is not manipulatable
@export var failed_object_not_manipulatable := "%s is not manipulatable."
## Message when root node is not assigned
@export var failed_root_not_assigned := "%s's root has not been assigned"
## Message when root is not a Node2D
@export var failed_root_not_node2D := "%s's root is not a Node2D"
## Message when there is no target object
@export var failed_no_target_object := "There is no target object."
## Message when target is not manipulatable
@export var target_not_manipulatable := "Target is not manipulatable."
## Message for unsupported node types
@export var unsupported_node_type := "Unsupported node type %s"

#endregion

func get_editor_issues() -> Array[String]:
	var issues : Array[String] = []
	
	# Validate all messages are non-empty
	if demolish_success.is_empty():
		issues.append("ManipulationSettings: Demolish success message is empty.")
	if failed_not_demolishable.is_empty():
		issues.append("ManipulationSettings: Failed not demolishable message is empty.")
	if demolish_already_deleted.is_empty():
		issues.append("ManipulationSettings: Demolish already deleted message is empty.")
	if move_started.is_empty():
		issues.append("ManipulationSettings: Move started message is empty.")
	if move_success.is_empty():
		issues.append("ManipulationSettings: Move success message is empty.")
	if failed_to_start_move.is_empty():
		issues.append("ManipulationSettings: Failed to start move message is empty.")
	if no_move_target.is_empty():
		issues.append("ManipulationSettings: No move target message is empty.")
	if failed_placement_invalid.is_empty():
		issues.append("ManipulationSettings: Failed placement invalid message is empty.")
	if target_not_rotatable.is_empty():
		issues.append("ManipulationSettings: Target not rotatable message is empty.")
	if target_not_flippable_horizontally.is_empty():
		issues.append("ManipulationSettings: Target not flippable horizontally message is empty.")
	if target_not_flippable_vertically.is_empty():
		issues.append("ManipulationSettings: Target not flippable vertically message is empty.")
	if invalid_data.is_empty():
		issues.append("ManipulationSettings: Invalid data message is empty.")
	if failed_manipulation_state_invalid.is_empty():
		issues.append("ManipulationSettings: Failed manipulation state invalid message is empty.")
	if failed_object_not_manipulatable.is_empty():
		issues.append("ManipulationSettings: Failed object not manipulatable message is empty.")
	if failed_root_not_assigned.is_empty():
		issues.append("ManipulationSettings: Failed root not assigned message is empty.")
	if failed_root_not_node2D.is_empty():
		issues.append("ManipulationSettings: Failed root not Node2D message is empty.")
	if failed_no_target_object.is_empty():
		issues.append("ManipulationSettings: Failed no target object message is empty.")
	if target_not_manipulatable.is_empty():
		issues.append("ManipulationSettings: Target not manipulatable message is empty.")
	if unsupported_node_type.is_empty():
		issues.append("ManipulationSettings: Unsupported node type message is empty.")
	
	return issues

func get_runtime_issues() -> Array[String]:
	var issues : Array[String] = []
	issues.append_array(get_editor_issues())
	return issues
