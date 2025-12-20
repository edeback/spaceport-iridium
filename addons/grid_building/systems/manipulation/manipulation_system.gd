## System for manipulating (move, rotate, flip, demolish, build preview integration) grid building objects.
##
## Responsibilities:
## - Creates and manages a temporary manipulation copy ("move copy") when entering MOVE workflows.
## - Delegates spatial translation to the external targeting/positioner system. (No per-frame movement logic here.)
## - Sets up and tears down placement validation rules for move and build actions.
## - Manages physics layer disabling/enabling during active manipulation.
## - Emits structured status transitions via `ManipulationData.status` (STARTED, FAILED, FINISHED, CANCELED).
##
## Non‑Responsibilities (by design):
## - Calculating or enforcing cursor/keyboard driven position updates (handled by GridTargetingSystem & its positioner node).
## - Determining selection/target acquisition (handled by targeting state & systems).
## - Rendering or UI feedback (delegated to name displayer / external UI nodes).
##
## Design Notes:
## - The move copy is parented under the active positioner when available so that any positioner movement (mouse, keyboard, gamepad) naturally repositions the copy without duplicate logic or tight coupling.
## - If no positioner exists (edge/test fallback), the copy is parented under the manipulation parent as a legacy behavior.
## - Rotation / flip actions operate directly on the target Node2D passed in, typically the move copy's root while an action is active.
class_name ManipulationSystem
extends GBSystem

var _logger: GBLogger

## Creates a ManipulationSystem with dependency injection from container.
static func create_with_injection(p_parent : Node, container: GBCompositionContainer) -> ManipulationSystem:
	var system = ManipulationSystem.new()
	system.name = "ManipulationSystem"
	p_parent.add_child(system)
	
	# Inject dependencies
	system.resolve_gb_dependencies(container)
	
	# Validate dependencies were properly injected
	var issues = system.get_runtime_issues()
	if not issues.is_empty():
		var logger = container.get_logger()
		logger.log_warnings(issues)
	
	return system

## Validates that all required dependencies are properly set.
## Returns list of validation issues (empty if valid).
## Checks if all critical dependencies are ready for operation.
## Returns true if the system can safely process operations.
func _are_dependencies_ready() -> bool:
	return (
		_states != null and 
		_manipulation_settings != null and 
		_actions != null and 
		_indicator_context != null and
		_logger != null
	)

func get_runtime_issues() -> Array[String]:
	var issues: Array[String] = []
	
	if not _systems_context:
		issues.append("GBSystemsContext is not set")
	
	if not _indicator_context:
		issues.append("IndicatorContext is not set")
		
	if not _states:
		issues.append("GBStates is not set")
		
	if _manipulation_settings == null:
		issues.append("ManipulationSettings is not set")
	
	if not _actions:
		issues.append("GBActions is not set")
	
	# Additional validation from original validate() method
	var required_props : Array[String] = ["_states", "_manipulation_settings", "_actions", "_indicator_context"]
	issues.append_array(GBValidation.check_not_null(self, required_props))

	if _manipulation_settings != null:
		if _manipulation_settings.enable_rotate:
			issues.append_array(_actions.validate_action(_actions.rotate_left))
			issues.append_array(_actions.validate_action(_actions.rotate_right))
		
		if _manipulation_settings.enable_flip_horizontal:
			issues.append_array(_actions.validate_action(_actions.flip_horizontal))
		
		if _manipulation_settings.enable_flip_vertical:
			issues.append_array(_actions.validate_action(_actions.flip_vertical))
	else: 
		issues.append("[manipulation] is not set. This is required for manipulation _actions.")

	# Ensure that mode _actions are defined
	issues.append_array(_actions.get_runtime_issues())

	if not is_instance_valid(_manipulation_settings):
		issues.append("[_manipulation_settings] is not a valid resource. Check that it is properly set.")

	if not is_inside_tree():
		issues.append("%s must belong to a scene tree to function properly." % self)
	
	return issues

@export_group("Results")

## Emitted when move indicators have been fully set up after physics frame
## Passes the array of created indicators for debugging and validation
signal move_indicators_ready(indicators: Array[RuleCheckIndicator])

## Objects with physics layers disabled during move operations.
var _physics_disabled_objects : Array[CollisionObject2D] = []

#region Dependencies
## Systems context for plugin integration.
var _systems_context : GBSystemsContext

## Placement context for validation and rules.
var _indicator_context : IndicatorContext

## Shared states for plugin systems.
var _states : GBStates

## Settings for manipulation system behavior (includes messages).
var _manipulation_settings : ManipulationSettings

## Input actions configuration.
var _actions : GBActions
#endregion

func resolve_gb_dependencies(p_container : GBCompositionContainer) -> void:
	_systems_context = p_container.get_systems_context()
	if _systems_context != null:
		_systems_context.set_system(self)
	_states = p_container.get_states()
	_indicator_context = p_container.get_contexts().indicator
	_manipulation_settings = p_container.get_manipulation_settings()
	_actions = p_container.get_actions()
	_logger = p_container.get_logger()
	
	# Guard against duplicate connections when re-initialized across tests
	if _states and _states.targeting and not _states.targeting.target_changed.is_connected(_on_target_changed):
		_states.targeting.target_changed.connect(_on_target_changed)
	if _states and _states.mode and not _states.mode.mode_changed.is_connected(_on_mode_changed):
		_states.mode.mode_changed.connect(_on_mode_changed)
	if _states and _states.building and not _states.building.preview_changed.is_connected(_on_preview_changed):
		_states.building.preview_changed.connect(_on_preview_changed)
	
	var issues := get_runtime_issues()
	for issue in issues:
		push_warning(issue)
	
	if issues.is_empty():
		process_mode = ProcessMode.PROCESS_MODE_INHERIT

## Ensures _manipulation_settings is initialized with a default instance if null.
## This prevents string formatting crashes when dependencies haven't been resolved yet.
## The default will be replaced with the real settings when resolve_gb_dependencies() is called.
func _ensure_manipulation_settings() -> void:
	if _manipulation_settings == null:
		_manipulation_settings = ManipulationSettings.new()
		# Note: This is a temporary default. Real settings will replace this in resolve_gb_dependencies()

## Attempts to move a targeted object.

## Checks if dependencies have been properly resolved.
## Returns false and logs error if not resolved.
func _check_dependencies_resolved() -> bool:
	if _manipulation_settings == null:
		push_error("[ManipulationSystem] Dependencies not resolved: _manipulation_settings is null. Call resolve_gb_dependencies() first.")
		return false
	return true

## Gets the unsupported node type error message.
## [param p_node_class] The class name of the unsupported node
func _get_unsupported_node_type_message(p_node_class: String) -> String:
	if not _check_dependencies_resolved():
		return "Unsupported node type: %s (Dependencies not resolved)" % p_node_class
	return _manipulation_settings.unsupported_node_type % p_node_class

## Attempts to move a targeted object.
## Failed or successful move data available through state signals.[br][br]
## [code]p_root[/code]: [i]Node[/i] - Container node to search for Manipulatable component
func try_move(p_root : Node) -> ManipulationData:
	_ensure_manipulation_settings()
	var failed_reason : String
	var source : Manipulatable = GBSearchUtils.find_first(p_root, Manipulatable)
	var move_data = ManipulationData.new(
		_states.manipulation.get_manipulator(), 
		source,
		null,
		GBEnums.Action.MOVE)
	_states.manipulation.data = move_data
	
	## Validate all possible reasons for failing
	if not _states.manipulation.validate_setup():
		failed_reason = _manipulation_settings.failed_manipulation_state_invalid
	elif p_root == null:
		failed_reason = _manipulation_settings.failed_no_target_object
	elif move_data.source == null:
		failed_reason = _manipulation_settings.failed_object_not_manipulatable % GBObjectUtils.get_display_name(p_root)
	elif move_data.source.root == null:
		failed_reason = _manipulation_settings.failed_no_target_object
		
	if not failed_reason.is_empty():
		move_data.message = failed_reason
		_states.manipulation.data.status = GBEnums.Status.FAILED
		return move_data
	
	# NOTE: _start_move is synchronous - no await needed since we removed physics frame wait
	var started: bool = _start_move(move_data)
	
	if not started:
		failed_reason = _manipulation_settings.failed_to_start_move % GBObjectUtils.get_display_name(p_root)
		move_data.message = failed_reason
	
	return move_data

## Creates a manipulation (move) copy and prepares rule validation.
##
## Flow:
## 1. Clone source manipulatable root via `create_copy`.
## 2. Parent under manipulation parent node.
## 3. Reset transform if configured.
## 4. Align initial global position to the parent root. Parent root is responsible for moving object.
## 5. Initialize placement validation rules using IndicatorManager.
## 6. Disable configured physics layers on the original source.
##
## Returns true if setup succeeded; false if rule setup failed.
func _start_move(p_data : ManipulationData) -> bool:
	_ensure_manipulation_settings()
	
	p_data.target = p_data.source.create_copy(_manipulation_settings.move_suffix)
	
	## Force target to be the moved object
	var root : Node = p_data.target.root
	
	# Mark the copy as a preview so save systems can filter it out
	root.set_meta("gb_preview", true)
	
	if root.get_parent() == null:
		_states.manipulation.parent.add_child(root)
	else:
		root.reparent(_states.manipulation.parent)
		
	set_targeted(root)
	
	# CRITICAL: Set manual targeting to prevent auto-clearing collision_exclusions
	# during target updates within the same manipulation operation
	_states.targeting.set_manual_target(root)

	# CRITICAL: Disable scripts and processing on the move copy to prevent
	# AI movement, physics updates, and other gameplay logic from executing
	# during manipulation. Preserve essential grid building scripts like Manipulatable.
	var kept_script_types: Array[String] = ["Manipulatable"]
	GBManipulationCopyUtils.prepare_manipulation_copy(root, kept_script_types)

	# CRITICAL ROTATION FIX: Normalize copy transform BEFORE indicator generation
	# This ensures indicators are calculated from canonical (unrotated) geometry
	# for consistent indicator counts regardless of source object rotation.
	# After indicators are generated, we transfer rotation/scale to ManipulationParent
	# so the preview visually matches the source object's orientation.
	var source_rotation: float = p_data.source.root.rotation
	var source_scale: Vector2 = p_data.source.root.scale
	
	# Normalize the manipulation copy to identity transform for indicator calculation
	p_data.target.root.rotation = 0.0
	p_data.target.root.scale = Vector2.ONE
	
	# Position at grid-aligned positioner location
	p_data.target.root.global_position = _states.targeting.positioner.global_position

	_states.manipulation.data = p_data

	# NOTE: No need to await physics frame - global_position assignment is synchronous
	# and collision detection works immediately with current transforms.
	# Awaiting here would allow the original enemy's AI to run before we disable physics,
	# causing unintended movement.

	# CRITICAL: Set GridTargetingState.target to the manipulation copy
	# This is required for indicator generation to detect collision shapes
	# on the copy and generate indicators at the correct tile positions.
	_states.targeting.target = root

	# CRITICAL: Exclude the original object from collision detection
	# During move operations, indicators should only detect collisions with OTHER objects,
	# not the object being moved (it won't collide with itself after moving).
	# The original object remains fully functional (AI, physics, etc.) but is ignored
	# by indicator collision checks.
	_states.targeting.collision_exclusions = [p_data.source.root]

	# Cast TileCheckRule array to PlacementRule array
	var move_rules: Array[PlacementRule] = []
	move_rules.assign(p_data.source.get_move_rules())

	var report = _indicator_context.get_manager().try_setup(move_rules, _states.targeting)

	if not report.is_successful():
		_logger.log_issues(report.get_issues())
		return false

	# CRITICAL ROTATION FIX PART 2: Transfer rotation/scale to ManipulationParent AFTER indicator generation
	# Now that indicators are calculated from canonical geometry, apply the source object's
	# rotation and scale to ManipulationParent so the preview visually matches the source.
	# The manipulation copy stays normalized (rotation=0, scale=1.0) and inherits the
	# transform from its parent, making indicators rotate/scale correctly with the preview.
	_states.manipulation.parent.rotation = source_rotation
	_states.manipulation.parent.scale = source_scale

	p_data.message = _manipulation_settings.move_started % GBObjectUtils.get_display_name(p_data.source.root)
	_states.manipulation.data.status = GBEnums.Status.STARTED
	_disable_selected_physics(p_data.source.root)
	
	# Monitor source object for deletion - auto-cancel if it leaves the scene
	if p_data.source.root and not p_data.source.root.tree_exiting.is_connected(_on_source_tree_exiting):
		p_data.source.root.tree_exiting.connect(_on_source_tree_exiting)
	
	# Emit signal with indicators for debugging and validation
	var indicators: Array[RuleCheckIndicator] = _indicator_context.get_manager().get_indicators()
	
	# DIAGNOSTIC: Log indicator count for debugging duplicate indicator issues
	_logger.log_debug(
		"[ManipulationSystem._start_move] Indicators setup complete: %d indicators created for %s" % 
		[indicators.size(), GBObjectUtils.get_display_name(p_data.source.root)]
	)
	
	move_indicators_ready.emit(indicators)
	
	return true

## Attempts to place a manipulated object at the desired location.
## Validates placement rules and commits the move if successful.[br][br]
## [code]p_move[/code]: [i]ManipulationData[/i] - Movement data containing source and target information
func try_placement(p_move : ManipulationData) -> ValidationResults:
	_ensure_manipulation_settings()
	if not p_move.is_valid():
		var bad_move_results = ValidationResults.new(false, "[p_move] is not valid. Cannot move object.", {})
		p_move.message = _manipulation_settings.invalid_data % str(p_move)
		_states.manipulation.data.status = GBEnums.Status.FAILED
		# CRITICAL FIX: Clean up invalid move data - tear down indicators and free target copy
		_indicator_context.get_manager().tear_down()
		p_move.queue_free_manipulation_objects()
		# Clear manual targeting mode when move fails
		_states.targeting.clear_manual_target()
		# Do NOT move the source object - move data is invalid
		return bad_move_results
		
	# Evaluate rules set against indicators that should have all ALREADY been set up
	var target_root = p_move.target.root
	var validation_results = _indicator_context.get_manager().validate_placement()
	p_move.results = validation_results
	
	if not validation_results.is_successful():
		# NEW BEHAVIOR: Keep manipulation active for retry, only emit failure signal
		p_move.message = _manipulation_settings.failed_placement_invalid % GBObjectUtils.get_display_name(p_move.source.root)
		
		# Emit failure signal for audio/UI feedback but DON'T set status to FAILED
		# This keeps the manipulation active so user can try placing elsewhere
		_states.manipulation.failed.emit(p_move)
		
		# Do NOT clean up - keep indicators and target copy active for another placement attempt
		# User must explicitly cancel (Escape key) to end the manipulation
		return validation_results
	else:
		# CRITICAL FIX: Preserve flip semantics when placing manipulated objects
		# The target copy is a child of ManipulationParent, which accumulates user transforms.
		# Problem: Assigning global_transform directly normalizes negative scale to positive scale + rotation,
		# losing the semantic distinction between flips (negative scale) and rotations.
		# Solution: Extract transforms BEFORE ManipulationParent.reset() and apply via Manipulatable helper.
		# Bug: Flip/rotation during move was not persisting to placed object.
		# Root cause: ManipulationParent.reset() called during _finish() clears transforms before we can apply them.
		
		# Set success message for action log display
		p_move.message = _manipulation_settings.move_success % GBObjectUtils.get_display_name(p_move.source.root)
		
		# Capture the OLD transform before manipulation (for signal)
		var old_transform: Transform2D = p_move.source.root.global_transform
		
		# Capture transforms from ManipulationParent BEFORE _finish() resets them
		# ManipulationParent accumulates user transforms (rotation, flip, scale)
		var manipulation_parent: Node2D = _states.manipulation.parent
		var final_position: Vector2 = target_root.global_position
		var accumulated_rotation: float = manipulation_parent.rotation
		var accumulated_scale: Vector2 = manipulation_parent.scale
		
		# SIMPLIFIED API: Single call handles transform application, cleanup, and completion signaling
		# This replaces the complex ordering requirements and multiple method calls
		p_move.source.complete_manipulation(
			final_position, 
			accumulated_rotation, 
			accumulated_scale,
			old_transform,
			p_move
		)
		
		_finish(p_move)
		_enable_selected_physics()
	return validation_results

## Checks if the manipulation system is ready for operations.
func is_ready() -> bool:
	var passing = true
	
	if _states.manipulation.parent == null:
		push_warning("No manipulation node set on the manipulation state %s" % _states.manipulation.resource_path)
		passing = false
		
	return passing

## Cancels the active manipulation action.
func cancel():
	var data : ManipulationData = _states.manipulation.data
	
	if(data):
		_states.manipulation.data.status = GBEnums.Status.CANCELED
		
		match data.action:
			GBEnums.Action.MOVE:
				data.queue_free_manipulation_objects()
	
		# Disconnect source monitoring signal if connected
		_disconnect_source_monitoring(data)
		
		_states.manipulation.data = null
		_enable_selected_physics()
		
		# Clear manual targeting mode and resume automatic targeting
		_states.targeting.clear_manual_target()
		
		# CRITICAL FIX: Clear active_target_node to allow new targeting after manipulation cancellation
		_states.manipulation.active_target_node = null
		
		set_process(false)

## Attempts to demolish the given manipulatable object and returns manipulation data for result inspection.
## Only succeeds if the object is configured as demolishable.[br][br]
## [code]p_manipulatable[/code]: [i]Manipulatable[/i] - Component to demolish
func try_demolish(p_manipulatable: Manipulatable) -> ManipulationData:
	_ensure_manipulation_settings()
	var target: Manipulatable = p_manipulatable if p_manipulatable != null else _states.manipulation.active_manipulatable
	var demolish_data := ManipulationData.new(
		_states.manipulation.get_manipulator(),
		target,
		null,
		GBEnums.Action.DEMOLISH
	)
	_states.manipulation.data = demolish_data

	if not _manipulation_settings.enable_demolish:
		demolish_data.message = _manipulation_settings.failed_not_demolishable % _get_demolish_display_name(target)
		demolish_data.status = GBEnums.Status.FAILED
		return demolish_data

	if target == null:
		demolish_data.message = _manipulation_settings.failed_no_target_object
		demolish_data.status = GBEnums.Status.FAILED
		return demolish_data

	if not target.is_demolishable():
		demolish_data.message = _manipulation_settings.failed_not_demolishable % _get_demolish_display_name(target)
		demolish_data.status = GBEnums.Status.FAILED
		return demolish_data

	var root: Node = target.root
	var display_name: String = _get_demolish_display_name(target)

	if root == null or not is_instance_valid(root):
		demolish_data.message = _manipulation_settings.demolish_already_deleted % display_name
		demolish_data.status = GBEnums.Status.FAILED
		return demolish_data

	demolish_data.status = GBEnums.Status.STARTED
	root.queue_free()
	demolish_data.message = _manipulation_settings.demolish_success % display_name
	demolish_data.status = GBEnums.Status.FINISHED
	_states.manipulation.active_manipulatable = null
	return demolish_data

## Demolishes a manipulatable object and returns true when the object is successfully removed.
## [code]p_manipulatable[/code]: [i]Manipulatable[/i] - Component to demolish; defaults to active manipulatable when null
func demolish(p_manipulatable: Manipulatable) -> bool:
	var demolish_data := try_demolish(p_manipulatable)
	if demolish_data == null:
		return false

	if demolish_data.status == GBEnums.Status.FINISHED:
		var tree := get_tree()
		if tree != null:
			await tree.process_frame
		_clear_manipulation_data(demolish_data)
		return true

	if demolish_data.status == GBEnums.Status.STARTED:
		# Should not persist in started state; ensure cleanup occurs next frame.
		var tree := get_tree()
		if tree != null:
			await tree.process_frame
	_clear_manipulation_data(demolish_data)
	return false

## Rotates the target node by the specified degrees.
## Delegates to ManipulationParent's transform coordination.
func rotate(p_target : Node, degrees: float):
	_ensure_manipulation_settings()
	if p_target is Node2D:
		var manipulation_parent: ManipulationParent = _states.manipulation.parent
		manipulation_parent.apply_rotation(degrees)
		return true
	else:
		push_error(_manipulation_settings.unsupported_node_type % p_target.get_class())
		return false

## Flips the target node horizontally.
## Delegates to ManipulationParent's transform coordination.
func flip_horizontal(p_target : Node):
	_ensure_manipulation_settings()
	if p_target is Node2D:
		var manipulation_parent: ManipulationParent = _states.manipulation.parent
		manipulation_parent.apply_horizontal_flip()
	else:
		push_error(_manipulation_settings.unsupported_node_type % p_target.get_class())

## Flips the target node vertically.
## Delegates to ManipulationParent's transform coordination.
func flip_vertical(p_target : Node):
	_ensure_manipulation_settings()
	if p_target is Node2D:
		var manipulation_parent: ManipulationParent = _states.manipulation.parent
		manipulation_parent.apply_vertical_flip()
	else:
		push_error(_manipulation_settings.unsupported_node_type % p_target.get_class())

## Get the root node of the current targeted object for this manipulation system
func get_targeted() -> Node:
	return _states.manipulation.active_target_node

## Sets the manipulation root to be the obj root
func set_targeted(p_obj_root : Node) -> void:
	_states.manipulation.active_target_node = p_obj_root

## Handles input events for manipulation system controls.
## Responds to demolish, info, moving, and off mode actions.[br][br]
## [code]event[/code]: [i]InputEvent[/i] - Input event to process for manipulation controls
func _unhandled_input(event: InputEvent) -> void:
	_ensure_manipulation_settings()	
	# DEMOLISH
	if _manipulation_settings.enable_demolish and event.is_action_pressed(_actions.demolish_mode) and is_ready():
		_states.mode.current = GBEnums.Mode.OFF if _states.mode.current == GBEnums.Mode.DEMOLISH else GBEnums.Mode.DEMOLISH
		return

	# INFO
	if event.is_action_pressed(_actions.info_mode) and is_ready():
		_states.mode.current = GBEnums.Mode.OFF if _states.mode.current == GBEnums.Mode.INFO else GBEnums.Mode.INFO
		return

	# MOVE
	if event.is_action_pressed(_actions.moving_mode) and is_ready():
		_states.mode.current = GBEnums.Mode.OFF if _states.mode.current == GBEnums.Mode.MOVE else GBEnums.Mode.MOVE
		return

	# OFF
	if event.is_action_pressed(_actions.off_mode):
		_states.mode.current = GBEnums.Mode.OFF
		return

	_perform_manipulation_actions(event)

	# Transform input is now handled by ManipulationParent directly
	# ManipulationParent processes its own input events and coordinates transforms

## Route standard input to unhandled to support tests or scenes that call _input directly.
func _input(event: InputEvent) -> void:
	# Intentionally no-op to avoid double-processing: Godot will call both _input and _unhandled_input.
	# We handle all logic in _unhandled_input.
	pass

func _perform_manipulation_actions(event : InputEvent):
	if not event.is_action_pressed(_actions.confirm_build): return
	
	var active_data = _states.manipulation.data
	
	if _states.mode.current == GBEnums.Mode.MOVE:
		if active_data != null && active_data.action == GBEnums.Action.MOVE:
			try_placement(active_data)
		elif active_data == null && _states.manipulation.active_manipulatable != null:
			try_move(_states.manipulation.active_manipulatable.root)

	if _states.mode.current == GBEnums.Mode.DEMOLISH:
		if active_data == null && _states.manipulation.active_manipulatable != null:
			await demolish(_states.manipulation.active_manipulatable)

## Handles transformation input for manipulatable objects.
## Delegates input processing to ManipulationParent for centralized transform coordination.
# _transform_input method removed - ManipulationParent now handles input directly

## Finishes a manipulation action and cleans up resources.
func _finish(p_data : ManipulationData) -> void:
	p_data.status = GBEnums.Status.FINISHED # Emits finished signal
	_indicator_context.get_manager().tear_down()
	p_data.queue_free_manipulation_objects()
	
	if _states.manipulation.data == p_data:
		_states.manipulation.data = null
		set_process(false)
	
	# Clear manual targeting mode and resume automatic targeting
	_states.targeting.clear_manual_target()
	
	# CRITICAL FIX: Clear active_target_node to allow new targeting after manipulation
	# This fixes the issue where TargetInformer ignores new targets because 
	# active_target_node is still set from previous manipulation
	_states.manipulation.active_target_node = null
	

func _on_mode_changed(p_mode : GBEnums.Mode):
	cancel()
	match p_mode:
		GBEnums.Mode.OFF:
			cancel()
	_logger.log_verbose( "Mode changed -> %s" % [str(p_mode)])
	# Activate process when entering MOVE mode with an active manipulation for dynamic tracking
	if p_mode == GBEnums.Mode.MOVE and _states.manipulation.data and _states.manipulation.data.action == GBEnums.Action.MOVE:
		set_process(true)
	else:
		if not _states.manipulation.data:
			set_process(false)

## While moving, keep the target copy aligned with the positioner so tests detect movement shifts.
func _process(_delta: float) -> void:
	# Guard: Don't process if dependencies not ready
	if not _are_dependencies_ready():
		return
	
	if _states.mode.current == GBEnums.Mode.MOVE:
		var move_data = _states.manipulation.data
		if move_data and move_data.action == GBEnums.Action.MOVE and move_data.target and _states.targeting and _states.targeting.positioner:
			move_data.target.root.global_position = _states.targeting.positioner.global_position

## NOTE: _process removed. Movement visuals are driven by reparenting the move copy under the positioner.
func _on_target_changed(p_new : Node, p_old : Node):
	# Guard: Don't process if dependencies not ready
	if not _are_dependencies_ready():
		return
	
	if _states.manipulation.data:
		return ## Ignore because there is already an active manipulation in play
	
	if p_new != null:
		_logger.log_verbose("target_changed old=%s new=%s" % [_debug_node(p_old), _debug_node(p_new)])
		var manipulatable : Manipulatable = GBSearchUtils.find_first(p_new, Manipulatable)
		if manipulatable == null:
			# Diagnostic: if something under cursor isn't picked up, check for nearby manipulatable roots
			var area2d := p_new if p_new is Area2D else null
			if area2d:
				# If its layer lacks Targetable (12) hint to add it
				var has_targetable: bool = area2d.get_collision_layer_value(12)
				if not has_targetable:
					push_warning("Object '%s' not targetable: missing physics layer 'Targetable' (layer 12)." % area2d.name)
				else:
					_logger.log_verbose_throttled(self, "Non-manipulatable collider under cursor '%s' layers=%s" % [area2d.name, _describe_layers(area2d)])
			return
		_states.manipulation.active_manipulatable = manipulatable
		_logger.log_verbose("Targeted manipulatable root=%s settings=%s" % [_debug_node(manipulatable.root), manipulatable.settings])
	else:
		_states.manipulation.active_manipulatable = null
		if p_old != null:
			_logger.log_verbose("Target cleared old=%s" % _debug_node(p_old))

func _on_preview_changed(p_preview : Node):
	# Guard: Don't process if dependencies not ready
	if not _are_dependencies_ready():
		return
	
	if _states.mode.current != GBEnums.Mode.BUILD:
		return
		
	if p_preview == null: 
		_states.manipulation.data == null 
		return
		
	var manipulatable = GBSearchUtils.find_first(p_preview, Manipulatable)
	_states.manipulation.data = ManipulationData.new(_states.manipulation.get_manipulator(), manipulatable, manipulatable, GBEnums.Action.BUILD)
	_states.manipulation.data.status = GBEnums.Status.STARTED
	# Reparenting causes a temporary tree exit/enter; Manipulatable.root may null during tree_exiting.
	p_preview.reparent(_states.manipulation.parent) ## Move the preview object to the manipulation parent
	# Restore manipulatable.root binding if it was cleared by tree_exiting during reparent.
	if manipulatable and manipulatable.root == null and p_preview is Node2D:
		manipulatable.root = p_preview

## Sends manipulation failed signal for failed operations.
func _send_manipulation_failed(p_manipulated : Manipulatable, p_action : GBEnums.Action):
	var failed = ManipulationData.new(_states.manipulation.get_manipulator(), _states.manipulation.data.source, p_manipulated , p_action)
	_states.manipulation.failed.emit(failed)

## Disables physics layers for objects during manipulation.
func _disable_selected_physics(p_container : Node2D):
	_ensure_manipulation_settings()
	if _manipulation_settings.disable_layer_in_manipulation != true:
		return
		
	var physics_objects = GBSearchUtils.get_collision_object_2ds(p_container)
	
	for obj in physics_objects:
		# Skip freed or null objects
		if not is_instance_valid(obj):
			continue
			
		if obj.get_collision_layer_value(_manipulation_settings.disabled_physics_layer) == true:
			obj.set_collision_layer_value(_manipulation_settings.disabled_physics_layer, false)
			_physics_disabled_objects.append(obj)
	
## Re-enables physics layers that were disabled during manipulation.
func _enable_selected_physics():
	_ensure_manipulation_settings()
	for obj in _physics_disabled_objects:
		# Skip freed or null objects
		if not is_instance_valid(obj):
			continue
			
		obj.set_collision_layer_value(_manipulation_settings.disabled_physics_layer, true)

	_physics_disabled_objects = []

## Handles source object leaving the scene tree during manipulation.
## Automatically cancels manipulation to prevent operating on deleted objects.
func _on_source_tree_exiting() -> void:
	if _states.manipulation.data:
		_logger.log_warning("[ManipulationSystem] Source object deleted during manipulation - auto-canceling")
		cancel()

## Disconnects source object monitoring signal if connected.
func _disconnect_source_monitoring(p_data: ManipulationData) -> void:
	if not p_data or not p_data.source or not p_data.source.root:
		return
	
	if p_data.source.root.tree_exiting.is_connected(_on_source_tree_exiting):
		p_data.source.root.tree_exiting.disconnect(_on_source_tree_exiting)

## Gets a display name appropriate for demolish messaging, preferring the manipulatable root when available.
func _get_demolish_display_name(p_manipulatable: Manipulatable) -> String:
	if p_manipulatable == null:
		return "<none>"

	var node: Node = p_manipulatable.root if p_manipulatable.root != null else p_manipulatable
	return GBObjectUtils.get_display_name(node, "<none>")

## Clears manipulation data reference when the provided data matches the active state.
func _clear_manipulation_data(p_data: ManipulationData) -> void:
	if _states != null and _states.manipulation.data == p_data:
		_states.manipulation.data = null

func _debug_node(n):
	if n is Node:
		return "%s(%s)" % [n.name, n.get_class()]
	return str(n)

func _describe_layers(obj):
	if obj is CollisionObject2D:
		var bits : Array[int] = []
		for i in range(1, 33):
			if obj.get_collision_layer_value(i):
				bits.append(i)
		return bits
	return []
