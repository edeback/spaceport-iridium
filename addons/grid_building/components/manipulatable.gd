class_name Manipulatable
extends GBGameNode
## Component node that makes a object movable, demolishable, or other
## system actions to be performed on the object

## Special marker that tells building system to keep this script during preview
const keep_during_preview = true

## Emitted when this object's manipulation is finished (placed/moved)
## This allows the root object to respond to being manipulated
## Parameters:
## - old_transform: Transform2D - The transform before manipulation
## - new_transform: Transform2D - The transform after manipulation
signal manipulation_finished(old_transform: Transform2D, new_transform: Transform2D)

## Rule settings for replacing this object in move mode, etc
@export var settings : ManipulatableSettings

## The root of the object that should be manipulated
## by any actions. This manipulatable component is usually a child of the root.
@export var root : Node :
	set(value):
		if root != null:
			root.tree_exiting.disconnect(_on_root_exiting)
		
		root = value
		
		if root != null:
			root.tree_exiting.connect(_on_root_exiting)

var _logger : GBLogger

func resolve_gb_dependencies(p_container : GBCompositionContainer):
	_logger = p_container.get_logger()

## Returns true if the configured root is an ancestor (direct or indirect) of this Manipulatable node.
func is_root_hierarchy_valid() -> bool:
	if root == null:
		return false
	var current: Node = self
	while current != null:
		if current == root:
			return true
		current = current.get_parent()
	return false

## Creates a copy of the manipulatable root with the specified name postfix.
## This does NOT set the parent of the root and returns the copied manipulatable.[br][br]
## [code]p_name_postfix[/code]: [i]String[/i] - Name postfix to append to the duplicated root's name
func create_copy(p_name_postfix : String) -> Manipulatable:
	var copy = root.duplicate()
	copy.name = "%s%s" % [root.name, p_name_postfix]
	var copy_manipulatable : Manipulatable = GBSearchUtils.find_first(copy, Manipulatable)
	copy_manipulatable.root = copy
	return copy_manipulatable
	
## Returns the tile check rules that apply when moving this object.
## Gets move rules from the manipulatable settings, or empty array if no settings.
func get_move_rules() -> Array[TileCheckRule]:
	if settings:
		return settings.move_rules
	else:
		return []

## Returns true if this object can be demolished based on its settings.
## Checks the demolishable flag in the manipulatable settings.
func is_demolishable() -> bool:
	if settings && settings.demolishable:
		return true
	else:
		return false

## Returns true if this object can be moved based on its settings.
## Checks the movable flag in the manipulatable settings.
func is_movable() -> bool:
	if settings && settings.movable:
		return true
	else:
		return false

## Validates that the manipulatable component is properly configured.
## Returns true if setup is valid, false if required properties are missing.
func validate_setup() -> bool:
	var issues := get_issues()
	_logger.log_issues(issues)
	return issues.size() == 0

func get_issues() -> Array[String]:
	var issues : Array[String] = []
	var null_issues : Array[String] = GBValidation.check_not_null(self, ["root"])
	issues.append_array(null_issues)
	
	if null_issues.is_empty() && not is_root_hierarchy_valid():
		issues.append("Root '%s' is not an ancestor of '%s'." % [root, self])
		
	return issues

## SIMPLIFIED API: Completes a manipulation in a single call with proper ordering.
## This method handles transform application, calculates before/after states, and emits completion signals.
## Replaces the complex multi-step process with proper ordering guarantees.
##
## [param p_position] Final world position for the root object
## [param p_rotation] Accumulated rotation in radians from ManipulationParent
## [param p_scale] Accumulated scale (may include negative values for flips)
## [param p_old_transform] Transform2D before manipulation (for signal)
## [param p_move_data] ManipulationData for context (optional, for future extensibility)
func complete_manipulation(
	p_position: Vector2, 
	p_rotation: float, 
	p_scale: Vector2,
	p_old_transform: Transform2D,
	p_move_data: ManipulationData = null
) -> void:
	# Step 1: Apply transforms (preserves flip semantics)
	_apply_manipulation_transforms(p_position, p_rotation, p_scale)
	
	# Step 2: Calculate new transform AFTER applying changes
	var new_transform: Transform2D = root.global_transform if root else Transform2D.IDENTITY
	
	# Step 3: Emit completion signal with before/after transforms
	manipulation_finished.emit(p_old_transform, new_transform)

func _on_root_exiting():
	root = null

## Applies manipulation transforms (position, rotation, scale) to the root object.
## This method preserves flip semantics by applying rotation and scale separately,
## preventing Godot's Transform2D normalization from converting negative scale to rotation.
##
## CRITICAL: This must be called BEFORE ManipulationParent.reset() is called,
## because reset() clears the accumulated transforms.
##
## [param p_position] Final world position for the root object
## [param p_rotation] Accumulated rotation in radians from ManipulationParent
## [param p_scale] Accumulated scale (may include negative values for flips)
func _apply_manipulation_transforms(p_position: Vector2, p_rotation: float, p_scale: Vector2) -> void:
	if root == null or not is_instance_valid(root):
		push_error("[Manipulatable.apply_manipulation_transforms] Cannot apply transforms: root is null or invalid")
		return
	
	if not root is Node2D:
		push_error("[Manipulatable.apply_manipulation_transforms] Root must be Node2D, got: %s" % root.get_class())
		return
	
	var root_2d := root as Node2D
	
	# Apply transforms in specific order to preserve flip semantics:
	# 1. Position (world space)
	# 2. Rotation (local)
	# 3. Scale (local, preserves negative values for flips)
	root_2d.global_position = p_position
	root_2d.rotation = p_rotation
	root_2d.scale = p_scale