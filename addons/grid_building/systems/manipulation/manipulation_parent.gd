## ManipulationParent - Transform container for preview objects during manipulation.
##
## Applies rotation, translation, and scale transforms to preview objects during building/manipulation.
## All child nodes automatically inherit these transforms through Godot's scene tree.
##
## ## IndicatorManager Parenting
##
## Indicators are ALWAYS parented to IndicatorManager.
##
## **IMPORTANT**: IndicatorManager should be parented to ManipulationParent (not as a sibling).
## This ensures indicators inherit rotation and transform from ManipulationParent via scene tree.
##
## **Top-Down/Platformer**: IndicatorManager as child of ManipulationParent (indicators rotate with preview)
## **Isometric**: IndicatorManager as child of ManipulationParent (indicators maintain correct orientation)
##
## ## Key Methods
## - `apply_rotation(degrees)` - Rotate this node and all children
## - `apply_horizontal_flip()` - Flip horizontally  
## - `apply_vertical_flip()` - Flip vertically
## - `reset()` - Reset to identity transform
##
## ## Transform Behavior
## - Manipulation start: Resets to identity
## - During manipulation: Accumulates transforms
## - Manipulation end/cancel: Resets to identity
##
## For detailed parenting decisions, isometric considerations, and architectural patterns:
## See [b]docs/v5-0-0/guides/isometric_implementation.mdx[/b]
##
## For system architecture: See [b]docs/systems/parent_node_architecture.md[/b]
class_name ManipulationParent
extends GBNode2D

# Import grid-aware rotation utilities for cardinal direction rotation
const GBGridRotationUtils = preload("res://addons/grid_building/utils/gb_grid_rotation_utils.gd")

#region Dependencies
## The state where this node should set itself as the parent at runtime
var _manipulation_state : ManipulationState:
	set(value):
		if _manipulation_state:
			_manipulation_state.parent = null
			_manipulation_state.started.disconnect(_on_started)
			_manipulation_state.finished.disconnect(_on_finished)
			_manipulation_state.canceled.disconnect(_on_canceled)
		
		_manipulation_state = value
		
		if _manipulation_state:
			_manipulation_state.parent = self
			_manipulation_state.started.connect(_on_started)
			_manipulation_state.finished.connect(_on_finished)
			_manipulation_state.canceled.connect(_on_canceled)

## Manipulation settings - used to check reset_transform_on_manipulation
var _manipulation_settings: ManipulationSettings

## Container for dependency injection
var _container: GBCompositionContainer
#endregion

## Resets the transform of the node to identity.
## This is called at the start, end, and cancellation of manipulation operations
## to ensure consistent positioning and prevent transform accumulation issues.
func reset():
	transform = Transform2D.IDENTITY

## Applies rotation to this ManipulationParent node.
## All child nodes will automatically inherit this rotation through Godot's scene tree.
##
## Architecture Reasoning:
## - ManipulationParent is a Node2D, so transforming it automatically transforms all children
## - Preview objects are typically children of ManipulationParent
## - Indicators are parented to IndicatorManager; IndicatorManager should be child of ManipulationParent
## - IndicatorManager as child of ManipulationParent: indicators inherit rotation/scale/flip transforms
## - No need for complex child-finding logic - Godot handles transform inheritance
## - Cleaner separation of concerns: ManipulationSystem handles logic, ManipulationParent handles transforms
##
## [param degrees] Rotation amount in degrees to apply to this node and all children
func apply_rotation(degrees: float) -> void:
	global_rotation_degrees += degrees

## Apply grid-aware clockwise rotation to this ManipulationParent.
## Uses cardinal direction rotation (90-degree increments) for grid-aligned objects.
##
## IMPORTANT: When ManipulationParent rotates, all child nodes
## inherit the rotation transform. Indicators are always parented to IndicatorManager.
## IndicatorManager should be a child of ManipulationParent so indicators inherit
## the same rotation/scale/flip transforms as the preview object.
##
## See [b]docs/v5-0-0/guides/isometric_implementation.mdx[/b] for parenting strategies.
##
## [param target_map] TileMapLayer for grid alignment calculations
## [param increment_degrees] Rotation increment in degrees (default 90.0 for 4-direction)
## [return] The new rotation angle in degrees (0-360 range)
func apply_grid_rotation_clockwise(target_map: TileMapLayer, increment_degrees: float = 90.0) -> float:
	var new_rotation_deg: float = GBGridRotationUtils.rotate_node_clockwise(self, target_map, increment_degrees)
	return new_rotation_deg

## Apply grid-aware counter-clockwise rotation to this ManipulationParent.
## Uses the rotation increment from parameter (default 90° for 4-direction).
## Supports configurable increments: 45° for 8-direction, 30° for 12-direction, etc.
##
## [param target_map] TileMapLayer for grid alignment calculations
## [param increment_degrees] Rotation increment in degrees (default 90.0 for 4-direction)
## [return] The new rotation angle in degrees (0-360 range)
func apply_grid_rotation_counter_clockwise(target_map: TileMapLayer, increment_degrees: float = 90.0) -> float:
	var new_rotation_deg: float = GBGridRotationUtils.rotate_node_counter_clockwise(self, target_map, increment_degrees)
	return new_rotation_deg

## Applies horizontal flip to this ManipulationParent node.
## All child nodes will automatically inherit this scale change through transform inheritance.
##
## [param] None - applies horizontal flip (scale.x *= -1) to this node and all children
func apply_horizontal_flip() -> void:
	scale.x *= -1

## Applies vertical flip to this ManipulationParent node.
## All child nodes will automatically inherit this scale change through transform inheritance.
##
## [param] None - applies vertical flip (scale.y *= -1) to this node and all children
func apply_vertical_flip() -> void:
	scale.y *= -1

## Handles transformation input events for manipulation operations.
## This method processes rotation and flip inputs, applying transforms to this ManipulationParent
## which automatically coordinate transforms for all child nodes (objects + indicators).
##
## Architecture Reasoning:
## - ManipulationParent owns the transform methods (apply_rotation, apply_*_flip)
## - Input handling should be where transform methods are defined
## - Keeps transform logic centralized in one class
## - ManipulationSystem delegates input to the appropriate transform coordinator
##
## [param event] The input event to process for transformation
## [param manipulation_settings] Global manipulation settings (rotation increments, enable flags)
## [param actions] Input action configuration
## [param manipulatable_settings] Settings specific to the object being manipulated
## [param messages] Message resources for error reporting
## [param states] System states for mode management and failed signal emission
func handle_transform_input(
	event: InputEvent, 
	manipulation_settings: ManipulationSettings,
	actions: GBActions,
	manipulatable_settings: ManipulatableSettings,
	states: GBStates
) -> void:
	# -- ROTATION --
	if manipulation_settings.enable_rotate:
		if InputMap.has_action(actions.rotate_left) && event.is_action_pressed(actions.rotate_left):
			# Check if this object can be rotated (per-object setting)
			if manipulatable_settings && !manipulatable_settings.rotatable:
				var failed = ManipulationData.new(states.manipulation.get_manipulator(), states.manipulation.data.source, null, GBEnums.Action.ROTATE)
				failed.message = manipulation_settings.target_not_rotatable % GBObjectUtils.get_display_name(states.manipulation.data.source.root)
				states.manipulation.failed.emit(failed)
			else:
				# Use grid-aware rotation when target map is available
				var target_map = _get_target_map_from_states(states)
				if target_map:
					# Grid-aware rotation with configurable increment (45° for 8-dir, 90° for 4-dir, etc.)
					apply_grid_rotation_counter_clockwise(target_map, manipulation_settings.rotate_increment_degrees)
				else:
					# Fallback to simple degree-based rotation if no map available
					# Godot 2D uses clockwise negative degrees; left (CCW) is positive
					apply_rotation(manipulation_settings.rotate_increment_degrees)
		# Support rotate right action
		if InputMap.has_action(actions.rotate_right) && event.is_action_pressed(actions.rotate_right):
			# Check if this object can be rotated (per-object setting)
			if manipulatable_settings && !manipulatable_settings.rotatable:
				var failed = ManipulationData.new(states.manipulation.get_manipulator(), states.manipulation.data.source, null, GBEnums.Action.ROTATE)
				failed.message = manipulation_settings.target_not_rotatable % GBObjectUtils.get_display_name(states.manipulation.data.source.root)
				states.manipulation.failed.emit(failed)
			else:
				# Use grid-aware rotation when target map is available
				var target_map = _get_target_map_from_states(states)
				if target_map:
					# Grid-aware rotation with configurable increment (45° for 8-dir, 90° for 4-dir, etc.)
					apply_grid_rotation_clockwise(target_map, manipulation_settings.rotate_increment_degrees)
				else:
					# Fallback to simple degree-based rotation if no map available
					# Right (CW) is negative degrees
					apply_rotation(-manipulation_settings.rotate_increment_degrees)

	## -- FLIP H / V --
	if manipulation_settings.enable_flip_horizontal:
		if InputMap.has_action(actions.flip_horizontal) && event.is_action_pressed(actions.flip_horizontal):
			if manipulatable_settings && manipulatable_settings.flip_horizontal:
				apply_horizontal_flip()
			else:
				var failed = ManipulationData.new(states.manipulation.get_manipulator(), states.manipulation.data.source, null, GBEnums.Action.FLIP_H)
				failed.message = manipulation_settings.target_not_flippable_horizontally % GBObjectUtils.get_display_name(states.manipulation.data.source.root)
				states.manipulation.failed.emit(failed)

	if manipulation_settings.enable_flip_vertical:
		if InputMap.has_action(actions.flip_vertical) && event.is_action_pressed(actions.flip_vertical):
			if manipulatable_settings && manipulatable_settings.flip_vertical:
				apply_vertical_flip()
			else:
				var failed = ManipulationData.new(states.manipulation.get_manipulator(), states.manipulation.data.source, null, GBEnums.Action.FLIP_V)
				failed.message = manipulation_settings.target_not_flippable_vertically % GBObjectUtils.get_display_name(states.manipulation.data.source.root)
				states.manipulation.failed.emit(failed)

## Handles input events for manipulation transform operations.
## Processes transform inputs directly at the point where transform methods are defined.
##
## Architecture Reasoning:
## - ManipulationParent owns transform methods and should handle related input
## - Eliminates delegation chain: Input → ManipulationSystem → ManipulationParent
## - Creates self-contained transform handling in one place
## - ManipulationSystem can focus on higher-level manipulation logic
func _unhandled_input(event: InputEvent) -> void:
	# Only process input if we have an active manipulation and required dependencies
	if not _manipulation_state or not _manipulation_state.data:
		return
		
	var manipulation_data = _manipulation_state.data
	if not manipulation_data.target:
		return
	
	# Get dependencies from the container
	var manipulation_settings = _get_manipulation_settings()
	var actions = _get_actions()
	
	if not manipulation_settings or not actions:
		return  # Missing required dependencies
	
	var manipulatable_settings = manipulation_data.target.settings if manipulation_data.target else null
	
	# Get the complete states container (need access to all states, not just manipulation)
	var states = _container.get_states() if _container else null
	if not states:
		return
	
	# Handle transform input directly
	handle_transform_input(
		event,
		manipulation_settings,
		actions, 
		manipulatable_settings,
		states
	)

## Route standard input to unhandled to support tests or scenes that call _input directly.
func _input(event: InputEvent) -> void:
	# Intentionally no-op to avoid double-processing: Godot will call both _input and _unhandled_input.
	# We handle all logic in _unhandled_input.
	pass

## Gets manipulation settings from dependency context.
func _get_manipulation_settings() -> ManipulationSettings:
	if not _container:
		# Return a default instance if no container
		return ManipulationSettings.new()
	
	var settings = _container.get_settings()
	if not settings or not settings.manipulation:
		# Return a default instance if settings not available
		return ManipulationSettings.new()
	
	return settings.manipulation
	
## Gets actions from dependency context. 
func _get_actions() -> GBActions:
	if not _container:
		return null
	return _container.get_actions()
	


## Gets the target map from the targeting state for grid-aware rotation.
## [param states] The complete states container
## [return] TileMapLayer for grid calculations, or null if not available
func _get_target_map_from_states(states: GBStates) -> TileMapLayer:
	if not states or not states.targeting:
		return null
	return states.targeting.target_map

func resolve_gb_dependencies(p_container : GBCompositionContainer) -> void:
	_container = p_container
	_manipulation_state = p_container.get_states().manipulation
	_manipulation_settings = p_container.get_manipulation_settings()
	
	var validation_issues = get_runtime_issues()
	if not validation_issues.is_empty():
		for issue in validation_issues:
			push_warning("ManipulationParent validation: " + issue)
	
## Validates that manipulation state is properly configured.
## Returns validation issues if state is missing or incorrectly configured.
##
## Ensures that:
## - ManipulationState is properly assigned
## - This node is registered as the parent in ManipulationState
## - Transform operations will function correctly
##
## [code]return[/code]: [i]Array[String][/i] - List of validation issues (empty if valid)
func get_runtime_issues() -> Array[String]:
	var issues: Array[String] = []

	if _manipulation_state == null:
		issues.append("ManipulationState is not set. This node will not function as a transform parent.")
	elif _manipulation_state.parent != self:
		issues.append("ManipulationParent is not registered as the parent in its ManipulationState. Expected: self.")

	return issues

func _on_started(p_data : ManipulationData):
	# Only reset transform if reset_transform_on_manipulation is true
	# This allows the ManipulationSystem to transfer rotation/scale to ManipulationParent
	# without having it immediately reset back to identity
	if _manipulation_settings && _manipulation_settings.reset_transform_on_manipulation:
		reset()

func _on_finished(p_data : ManipulationData):
	# Always reset on finish/cancel to clean up state
	reset()
	
func _on_canceled(p_data : ManipulationData):
	reset()
