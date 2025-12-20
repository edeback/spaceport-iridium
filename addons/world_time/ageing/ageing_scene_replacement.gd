class_name AgeingSceneReplacement
extends Node
## Settings and execution for replacing a target node with an instance of a PackedScene

signal replacement_created(replacement: Node, target_being_freed: Node)

## The context for the AgeState. Can be manually set or automatically defaults to parent node.
@export var ageing_component : AgeingComponent
		
@export_file var replacement_scene_path: String:
	set(value):
		if replacement_scene_path == value:
			return
		replacement_scene_path = value
		replacement_scene = load(replacement_scene_path)

@export var target_path: NodePath
@export var age_threshold: float = 10.0

var replacement_scene: PackedScene
var _replaced := false

var _pending_target: Node = null
var _pending_replacement: Node = null

func _ready():
	if ageing_component == null:
		ageing_component = get_parent()
	
	assert(ageing_component != null, "AgeingComponent must be set in inspector or the parent of this node.")
	
	ageing_component.age_state_changed.connect(_on_age_state_changed)
	
	if ageing_component.age_state:
		_connect_signals(ageing_component.age_state)

## Checks if the scene replacement is ready to occur when thhe p_current_age reaches the threshold.
func is_ready_to_replace(p_caller: Node, p_current_age: float) -> bool:
	if _replaced:
		return false
	if p_current_age < age_threshold:
		return false
	return validate(p_caller)

## Starts the replacement process but does not add the replacement to the scene yet.
## Returns the instantiated replacement node.
func start(p_caller: Node) -> Node:
	var target: Node = p_caller.get_node(target_path)
	if not is_instance_valid(target):
		push_error("Invalid target for replacement.")
		return null

	var instance := replacement_scene.instantiate()
	assert(instance != null, "Failed to instantiate replacement scene from: %s" % replacement_scene_path)

	_pending_target = target
	_pending_replacement = instance
	return instance

## Completes the replacement by adding the replacement to the scene and freeing the target.
func finish():
	if not is_instance_valid(_pending_target) or not is_instance_valid(_pending_replacement):
		push_error("Cannot finish replacement; one or both nodes are invalid.")
		return

	var target := _pending_target
	var replacement := _pending_replacement
	var parent := target.get_parent()

	parent.add_child(replacement)
	replacement.owner = target.get_owner()
	replacement.name = target.name

	_copy_transform_values(target, replacement)

	replacement_created.emit(replacement, target)
	target.queue_free()

	_replaced = true
	_pending_target = null
	_pending_replacement = null

## Validates whether this resource is ready to replace a target from the caller context.
func validate(p_caller: Node) -> bool:
	var issues: Array[String] = []

	if not is_instance_valid(replacement_scene):
		issues.append("Replacement scene is not loaded or invalid. Check 'replacement_scene_path' or ensure 'replacement_scene' is set.")

	var target: Node = p_caller.get_node(target_path)
	if not target:
		issues.append("Target node not found at path '%s' relative to caller '%s'." % [str(target_path), p_caller.name])
	elif not is_instance_valid(target):
		issues.append("Target node at path '%s' is invalid (possibly freed)." % str(target_path))

	for issue in issues:
		push_error(issue)

	return issues.is_empty()

func transfer_age_data(p_target_root: Node, p_minus_to_current: float):
	var ageing_components = p_target_root.find_children("", "AgeingComponent", true, false)
	
	if ageing_components.size() > 0:
		var target : AgeingComponent = ageing_components[0]
		var new_current_age := ageing_component.age_state.current - age_threshold
		ageing_component.transfer_state(target, new_current_age)
	else:
		push_warning("Trying to transfer age target to %s but found no AgeingComponents" % p_target_root)

## Copies transform values (position, rotation, scale) from source to target if compatible.
## Returns true if values were copied.
func _copy_transform_values(p_source: Node, p_target: Node) -> bool:
	if p_source is Node2D or p_source is Node3D or p_source is Control:
		if p_source.get_class() == p_target.get_class():
			p_target.position = p_source.position
			p_target.rotation = p_source.rotation
			p_target.scale = p_source.scale
			return true
	return false

func _on_state_age_changed(p_current: float, _p_change: float):
	if is_ready_to_replace(self, p_current):
		var new_scene_root: Node = start(self)
		var minus_current_to_target = max(0, age_threshold)
		transfer_age_data(new_scene_root, minus_current_to_target)
		finish()

func _on_age_state_changed(new : AgeState, old : AgeState):
	if new == old:
		return
	
	if old && old.age_changed.is_connected(_on_state_age_changed):
		old.age_changed.disconnect(_on_state_age_changed)
	
	if new:
		_connect_signals(new)

func _connect_signals(p_state : AgeState):
	if not p_state.age_changed.is_connected(_on_state_age_changed):
		p_state.age_changed.connect(_on_state_age_changed)
