## Controls the on-grid cursor used by building/interaction systems.
##
## Responsibilities:
## - Recenter according to GridTargetingSettings policy when input/mode is enabled
## - Follow mouse/keyboard input to update on-grid position
## - STRICTLY for tile center targeting - does NOT handle rotation or manipulation
##
## Targeting separation:
## Target acquisition/collision detection is handled by dedicated components (e.g., TargetingShapeCast2D).
## GridPositioner2D no longer depends on or manages any shapecast component.
##
## Manipulation separation:
## Object rotation, flipping, and manipulation are handled by ManipulationParent.
## GridPositioner2D focuses solely on positioning the targeting cursor at tile centers.
##
## Dependency Injection:
## `resolve_gb_dependencies(container)` is the standard method called by GBInjectorSystem
## to inject dependencies. This is the primary integration pattern for runtime use.
## `set_dependencies(...)` is an internal helper for testing and advanced use cases.
class_name GridPositioner2D
extends Node2D

# Enums are defined in logic/utils
const LOG_PREFIX : String = "[GridPositioner2D]"

#region Member variables
var _debug_settings: GBDebugSettings = null

# Explicitly injected dependencies (no service locator usage inside this class)
var _logger: GBLogger = null
var _actions: GBActions = null

## The state of the building/targeting system holding a reference to this positioner.
var _targeting_state : GridTargetingState :
	set(value):
		if(_targeting_state == value):
			return
			
		remove_self_as_positioner()
		_targeting_state = value
		
		if is_instance_valid(_targeting_state):
			_targeting_state.positioner = self

var _targeting_settings : GridTargetingSettings
#endregion

#region Constants & Labels

#endregion

## Fail fast design. Defaults should be explicitly set by scenes or tests.
func _init() -> void:
	pass

func _ready() -> void:
	# Start invisible until proper dependencies are injected
	visible = false

var _mode_state : ModeState :
	set(value):
		if is_instance_valid(_mode_state):
			_mode_state.mode_changed.disconnect(_on_mode_changed)
		
		_mode_state = value

		if is_instance_valid(_mode_state):
			_on_mode_changed(_mode_state.current)
			_mode_state.mode_changed.connect(_on_mode_changed)

# Cache last known mouse world position from events/projection for safe per-frame follow
var _last_mouse_world: Vector2 = Vector2.ZERO
var _has_mouse_world: bool = false

## Public flag & API for enabling/disabling input processing (used by tests)
var input_processing_enabled: bool = false

# Backwards-compatible property expected by older tests and scenes.
# Assigning to `enabled` will toggle input processing and also propagate
# the value to any child TargetingShapeCast2D component (so tests that
# set `positioner.enabled = true` behave as before).
## Backwards-compatible dynamic 'enabled' property
# Internal storage for assignments performed directly on the property
var _enabled_internal: bool = false

#region INPUT_STATE
# Last evaluation of mouse input gate and projection snapshot for diagnostics
var _last_mouse_input_status := GBMouseInputStatus.new()

# Track last mouse gate state to throttle logs
var _last_gate_allowed: bool = false

# Track last manual recenter mode (for diagnostics/tests)
var _last_manual_recenter_mode: int = GBEnums.CenteringMode.CENTER_ON_SCREEN

#endregion

#region VISIBILITY_DIAGNOSTICS
# Capture the most recent visibility toggle reason to enhance diagnostics when turned off
var _last_visibility_event_reason: String = ""
#endregion

#region PROCESS
func _physics_process(delta: float) -> void:
	# Positioner no longer depends on shapecast; physics tick retained only for optional diagnostics.
	# Diagnostics when enabled (guarded by debug mode)
	_log_state_flow(to_diagnostic_string())
#endregion

func _process(delta: float) -> void:
	# Optional debug: detect external visibility changes vs expected computation
	if _targeting_settings != null and _mode_state != null:
		var expected_vis := should_be_visible()
		if visible != expected_vis:
			_log_visibility("visibility mismatch: current=%s expected=%s (mode=%s)" % [str(visible), str(expected_vis), str(_mode_state.current)])

	var mode_now: GBEnums.Mode = _mode_state.current if _mode_state else GBEnums.Mode.OFF

	# First, reconcile to computed visibility so scene-load frames reach the intended state
	var reconcile := GridPositionerLogic.visibility_reconcile(mode_now, _targeting_settings, visible, _last_mouse_input_status, _has_mouse_world)
	_apply_visibility_result(reconcile)

	# Then apply per-tick retention decisions for hide_on_handled behavior
	var tick_res: MouseEventVisibilityResult = GridPositionerLogic.visibility_on_process_tick(
		mode_now,
		_targeting_settings,
		is_input_ready(),
		_last_mouse_input_status,
		_has_mouse_world
	)
	_apply_visibility_result(tick_res)

## Public API used by tests to enable input handling on this node.
func set_input_processing_enabled(p_enabled: bool) -> void:
	var was_enabled := input_processing_enabled
	input_processing_enabled = p_enabled
	set_process_input(p_enabled)
	_log_state_flow("set_input_processing_enabled -> %s (was=%s)" % [str(p_enabled), str(was_enabled)])
	if p_enabled and not was_enabled:
		_apply_recenter_on_enable()

func is_input_processing_enabled() -> bool:
	return input_processing_enabled

## Public helper: returns true when dependencies are injected and a target map is assigned
func is_input_ready() -> bool:
	return _targeting_state != null and _targeting_state.target_map != null

## Helper: returns true when all critical dependencies are injected (logger, settings, mode state)
## Use this to guard input methods that need to log or access settings
func are_dependencies_ready() -> bool:
	return _logger != null and _targeting_settings != null and _mode_state != null

## Standard dependency injection method called by GBInjectorSystem.
## This is the primary integration pattern - implement this method to participate in DI.
## Internally delegates to set_dependencies() for actual wiring.
func resolve_gb_dependencies(p_config : GBCompositionContainer) -> void:
	## Forward to explicit dependency injection helper to avoid service locator usage.
	set_dependencies(
		p_config.get_states(),
		p_config.config,
		p_config.get_logger(),
		p_config.get_actions(),
		true
	)
	# Always apply positioning after dependency resolution (user requirement)
	# Use Callable.call_deferred to ensure Camera2D and viewport are fully initialized
	_apply_positioning_and_visibility_sequence.call_deferred()
	# Diagnostics: log resolved state once after injection
	_log_state_flow("resolve_gb_dependencies -> %s" % to_diagnostic_string())

## Handles all input for the positioner including mouse movement, keyboard movement, and visibility
## INPUT: All mouse movement is handled here in response to events; not in physics.
func _input(event : InputEvent):
	# Guard: Return early if critical dependencies are not yet injected
	if not are_dependencies_ready():
		return
	
	# TRACE: Log every input event received
	_logger.log_trace("GridPositioner2D._input() called with event: %s" % str(event))
	
	# Gate input handling until dependencies and target map are ready
	if not is_input_ready():
		_logger.log_trace("GridPositioner2D._input() gated - input not ready")
		return
	
	# Handle mouse movement for positioning
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		var current_mode: GBEnums.Mode = _mode_state.current if _mode_state else GBEnums.Mode.OFF

		_handle_mouse_motion_event(motion, current_mode)

	# Handle keyboard movement
	if _actions != null and _targeting_settings.enable_keyboard_input:
		# Respect active when off setting for keyboard input
		if _is_disabled_in_off_mode():
			return
			
		if event is InputEventKey and event.pressed and not event.echo:
			var key_event := event as InputEventKey
			_logger.log_trace("GridPositioner2D received key event: %s" % str(key_event.keycode))

			var tile_change: Vector2i = GridPositionerLogic.get_tile_delta_from_key_event(key_event, _actions)
			
			if tile_change != Vector2i.ZERO and _targeting_state and _targeting_state.positioner:
				_move_positioner_by_tile(tile_change)

			# Recenter action (snap to camera/viewport center)
			if key_event.is_action_pressed(_actions.positioner_center):
				_logger.log_trace("Recenter action detected, calling _apply_recenter()")
				_apply_recenter()
			else:
				_logger.log_trace("Key %s is not positioner_center action (%s)" % [str(key_event.keycode), str(_actions.positioner_center)])
			
			# Note: Rotation input is handled by ManipulationParent, not GridPositioner2D

## Extracted helper: handle an InputEventMouseMotion event (snapped move + visibility)
func _handle_mouse_motion_event(motion: InputEventMouseMotion, current_mode: GBEnums.Mode) -> void:
	# Apply mouse input gate (always check, regardless of mode)
	var input_allowed: bool = _mouse_input_gate()
	
	# Update mouse input status for visibility decisions
	_last_mouse_input_status.allowed = input_allowed
	_last_mouse_input_status.method_name = "mouse_motion"
	# Only update world position if input is allowed (respect enable_mouse_input setting)
	if input_allowed:
		_last_mouse_input_status.world = _convert_screen_to_world(motion.position)
	
	# Apply event-driven visibility decision
	var vis_result: MouseEventVisibilityResult = GridPositionerLogic.visibility_on_mouse_event(current_mode, _targeting_settings, input_allowed)
	_log_mouse("_handle_mouse_motion_event: input_allowed=%s vis_result.apply=%s vis_result.visible=%s vis_result.reason=%s" % [str(input_allowed), str(vis_result.apply), str(vis_result.visible), str(vis_result.reason)])
	_apply_visibility_result(vis_result)
	
	# Return early if input is blocked
	if not input_allowed:
		return

	# Get world position using centralized conversion logic
	var world_pos: Vector2 = _convert_screen_to_world(motion.position)
	
	# Get tile coordinate from world position and move to tile center using utilities
	var target_tile: Vector2i = GBPositioning2DUtils.get_tile_from_global_position(world_pos, _targeting_state.target_map)
	GBPositioning2DUtils.move_to_tile_center(self, target_tile, _targeting_state.target_map)
	
	# Cache mouse world position for visibility retention
	_last_mouse_world = world_pos
	_has_mouse_world = true

## Deprecated: Use GBPositioning2DUtils.get_tile_from_global_position() and move_to_tile_center() instead.
## This function has been removed to maintain DRY principles and single source of truth.

## Single source of truth: centralized screen-to-world coordinate conversion
## Delegates to GBPositioning2DUtils for DRY compliance and maintainability
func _convert_screen_to_world(screen_pos: Vector2) -> Vector2:
	# Get viewport using fail-fast approach
	var viewport: Viewport = _targeting_state.target_map.get_viewport()
	
	# Delegate to utility function for proper coordinate conversion
	return GBPositioning2DUtils.convert_screen_to_world_position(screen_pos, viewport)

## Deprecated: Use GBPositioning2DUtils.get_tile_from_global_position() and move_to_tile_center() instead.
## This function has been removed to maintain DRY principles and single source of truth.

## Move the positioner back to its cached mouse world location when available.
func _move_to_cached_mouse_world() -> Vector2i:
	if not _has_mouse_world or not is_input_ready():
		_log_positioning("move_to_cached_mouse_world -> fallback (has_cache=%s input_ready=%s)" % [str(_has_mouse_world), str(is_input_ready())])
		return move_to_viewport_center_tile()

	var map := _targeting_state.target_map
	var cached_tile: Vector2i = GBPositioning2DUtils.get_tile_from_global_position(_last_mouse_world, map)
	GBPositioning2DUtils.move_to_tile_center(self, cached_tile, map)
	_log_positioning("moved to cached mouse world -> tile %s pos %s" % [str(cached_tile), str(global_position)])
	return cached_tile

## Cache the current global position as the latest mouse world reference.
func _cache_current_world_position() -> void:
	_last_mouse_world = global_position
	_has_mouse_world = true

## Helper: retrieve active Viewport for the current target map (may be null)
func _get_active_viewport() -> Viewport:
	return _targeting_state.target_map.get_viewport() if is_input_ready() else null

## Helper: retrieve active Camera2D from a viewport (may be null)
func _get_active_camera(p_vp: Viewport) -> Camera2D:
	return p_vp.get_camera_2d() if p_vp != null else null

## Helper: check if positioner should be disabled when in OFF mode
## Returns true if positioner should be blocked from input/positioning in OFF mode
func _is_disabled_in_off_mode() -> bool:
	return _mode_state.current == GBEnums.Mode.OFF and not _targeting_settings.remain_active_in_off_mode

## Helper: check if mouse cursor is within viewport bounds
## Returns true if mouse cursor is within the visible viewport area
func _is_mouse_cursor_on_screen() -> bool:
	var vp := _get_active_viewport()
	if vp == null:
		return false
	var mouse_screen_pos := vp.get_mouse_position()
	var vp_rect := vp.get_visible_rect()
	return vp_rect.has_point(mouse_screen_pos)

## Helper: decide whether mouse-follow behavior should run this frame
func _is_mouse_follow_allowed() -> bool:
	return GridPositionerLogic.is_mouse_follow_allowed(
		_mode_state.current if _mode_state else GBEnums.Mode.OFF,
		_targeting_settings,
		is_input_ready()
	)

## Returns a gate result for handling mouse input with an explicit reason when blocked
func _mouse_input_gate() -> bool:
	if not is_input_ready():
		return false

	var mouse_allowed : bool = _targeting_settings.enable_mouse_input if _targeting_settings != null else false

	if not mouse_allowed:
		return false

	# Use DRY helper for active when off check
	if _is_disabled_in_off_mode():
		return false

	return true

## Centralizes caching + movement application and diagnostics
func _apply_mouse_world(world: Vector2, method: int, screen: Vector2) -> void:
	# Cache
	_last_mouse_world = world
	_has_mouse_world = true
	# Diagnostics
	_log_mouse_motion(method, screen, world)
	# Capture visibility context at the time movement is applied
	_log_mouse("_apply_mouse_world vis=%s has_mouse=%s last_mouse_allowed=%s world=%s" % [str(visible), str(_has_mouse_world), str(_last_mouse_input_status != null and _last_mouse_input_status.allowed), str(world)])
	# Apply movement
	_handle_mouse_movement(world)

## Helper: structured mouse motion log
func _log_mouse_motion(p_method: int, p_screen: Vector2, p_world: Vector2) -> void:
	_log_mouse("mouse_motion proj=%s screen=%s -> world=%s" % [GridPositionerLogic.proj_method_to_string(p_method as GBEnums.ProjectionMethod), str(p_screen), str(p_world)])

## Helper: structured mouse gate log
func _log_mouse_gate(p_allowed: bool) -> void:
	# Only log when state changes to reduce spam
	if p_allowed != _last_gate_allowed:
		_last_gate_allowed = p_allowed
		_log_mouse("mouse_gate allowed=%s" % str(p_allowed))

## Recenter behavior when movement/input becomes enabled again
## User-specified logic: move to mouse cursor if mouse enabled and cursor on screen, otherwise move to center tile position
## Respects the active when off setting - no positioning changes when disabled in OFF mode
func _apply_recenter_on_enable() -> void:
	if not is_input_ready():
		return
	if _targeting_settings == null:
		return

	# Respect active when off setting - don't recenter if disabled in OFF mode
	var disabled_in_off_mode := _is_disabled_in_off_mode()

	if disabled_in_off_mode:
		_log_positioning("recenter_on_enable -> skipped (disabled_in_off_mode=true)")
		return

	var viewport_available := _get_active_viewport() != null
	var decision := GridPositionerLogic.recenter_on_enable_decision(
		_targeting_settings.position_on_enable_policy,
		_has_mouse_world,
		_targeting_settings.enable_mouse_input,
		viewport_available
	)
	_log_positioning("recenter_on_enable -> decision=%s policy=%d cached=%s mouse_enabled=%s viewport=%s" % [
		_recenter_decision_to_string(decision),
		_targeting_settings.position_on_enable_policy,
		str(_has_mouse_world),
		str(_targeting_settings.enable_mouse_input),
		str(viewport_available)
	])

	match decision:
		GridPositionerLogic.RecenterDecision.NONE:
			return
		GridPositionerLogic.RecenterDecision.LAST_SHOWN:
			_move_to_cached_mouse_world()
		GridPositionerLogic.RecenterDecision.MOUSE_CURSOR:
			move_to_cursor_center_tile()
		GridPositionerLogic.RecenterDecision.VIEW_CENTER:
			move_to_viewport_center_tile()
		_:
			move_to_viewport_center_tile()

	_cache_current_world_position()

## Apply positioning and then visibility in proper sequence after dependency injection
## This ensures Camera2D is available for positioning and visibility is updated based on final position
func _apply_positioning_and_visibility_sequence() -> void:
	# First apply positioning (requires Camera2D to be ready)
	_apply_recenter_on_enable()
	# Then apply visibility based on current state (respect hide_on_handled)
	update_visibility()

func _recenter_decision_to_string(p_decision: int) -> String:
	match p_decision:
		GridPositionerLogic.RecenterDecision.NONE:
			return "NONE"
		GridPositionerLogic.RecenterDecision.LAST_SHOWN:
			return "LAST_SHOWN"
		GridPositionerLogic.RecenterDecision.MOUSE_CURSOR:
			return "MOUSE_CURSOR"
		GridPositionerLogic.RecenterDecision.VIEW_CENTER:
			return "VIEW_CENTER"
		_:
			return "UNKNOWN"

## Handle mouse movement to update positioner position.
## If a `mouse_global_override` is provided (e.g., from InputEventMouseMotion),
## it will be used instead of querying the viewport/cursor state. This enables
## compatibility with tests (SceneRunner) and hidden cursor scenarios.
func _handle_mouse_movement(mouse_global_override: Variant = null) -> void:
	var input_ready := is_input_ready()
	
	# Diagnostics: log guard state for mouse movement handling
	_log_mouse("handle_mouse_movement guard: input_ready=%s, override_provided=%s" % [str(input_ready), str(mouse_global_override != null)])
	
	if not input_ready:
		return

	# Log entry into movement handler
	_log_mouse("_handle_mouse_movement start vis=%s has_mouse=%s last_mouse_allowed=%s override=%s" % [str(visible), str(_has_mouse_world), str(_last_mouse_input_status != null and _last_mouse_input_status.allowed), str(mouse_global_override != null)])
	
	# Get mouse position using centralized conversion or provided override
	var mouse_global: Vector2
	if mouse_global_override != null:
		mouse_global = mouse_global_override
	else:
		# Use centralized screen-to-world conversion
		var vp := _get_active_viewport()
		if vp != null:
			var screen_pos := vp.get_mouse_position()
			mouse_global = _convert_screen_to_world(screen_pos)
		else:
			# In test environments without viewport, use current position as fallback
			mouse_global = self.global_position
			return  # Don't update position in test environments

	# Use GBPositioning2DUtils for consistent tile coordinate conversion
	var target_tile: Vector2i = GBPositioning2DUtils.get_tile_from_global_position(mouse_global, _targeting_state.target_map)

	# Diagnostics: chosen tile + restrictions
	_log_positioning("handle_mouse tile=%s restrict_to_map=%s limit_adjacent=%s" % [str(target_tile), str(_targeting_settings.restrict_to_map_area), str(_targeting_settings.limit_to_adjacent)])
	
	if _targeting_settings.restrict_to_map_area:
		GBPositioning2DUtils.move_to_closest_valid_tile_center(self, target_tile, _targeting_state.get_origin(), _targeting_state.target_map, _targeting_settings)
	else:
		GBPositioning2DUtils.move_to_tile_center(self, target_tile, _targeting_state.target_map)

	# Cache world position for manual recenter logic and visibility retention
	_last_mouse_world = mouse_global
	_has_mouse_world = true

	# Log after applying movement
	_log_mouse("_handle_mouse_movement end pos=%s tile=%s vis=%s" % [str(self.global_position), str(target_tile), str(visible)])

## Moves the positioner by a specified number of tiles in a given direction.[br][br]
## [code]p_direction[/code]: [i]Vector2[/i] - Direction vector (e.g., Vector2(1,0) for right, Vector2(0,1) for down)
func _move_positioner_by_tile(p_tile_delta: Vector2i) -> void:
	if not is_input_ready():
		return
	# Use GBPositioning2DUtils for consistent current tile calculation
	var map = _targeting_state.target_map
	var current_tile: Vector2i = GBPositioning2DUtils.get_tile_from_global_position(global_position, map)
	var target_tile: Vector2i = current_tile + p_tile_delta
	GBPositioning2DUtils.move_to_tile_center(self, target_tile, map)
	
	# Make positioner visible when moving via keyboard
	_set_visibility_reason("keyboard_movement")
	_set_visible_state(true)
	
	# Update cached position for visibility retention
	_last_mouse_world = global_position
	_has_mouse_world = true

# Rotation functionality has been moved to ManipulationParent.
# GridPositioner2D is now strictly responsible for tile center targeting.

## Move positioner to the center tile of the viewport/camera view.
## Returns the tile coordinate where the positioner was positioned, or Vector2i.ZERO if failed.
func move_to_viewport_center_tile() -> Vector2i:
	if not is_input_ready():
		return Vector2i.ZERO
	
	# Use positioning utility to move to viewport center tile
	var vp := _get_active_viewport()
	if vp != null:
		var result_tile: Vector2i = GBPositioning2DUtils.move_node_to_tile_at_viewport_center(self, _targeting_state.target_map, vp)
		_log_positioning("moved to viewport center -> tile %s pos %s" % [str(result_tile), str(self.global_position)])
		return result_tile
	else:
		_log_positioning("Failed to move to viewport center: no viewport available", false)
		return Vector2i.ZERO

## Move positioner to the center tile at the cursor location when available.
## Falls back to viewport mouse, then TileMap global, then view center.
## Returns the tile coordinate where the positioner was positioned.
func move_to_cursor_center_tile() -> Vector2i:
	if not is_input_ready():
		return Vector2i.ZERO

	var world_position: Vector2
	
	# Try last known mouse world position first
	if _has_mouse_world:
		world_position = _last_mouse_world
	else:
		# Try viewport mouse position using centralized conversion
		var vp := _get_active_viewport()
		if vp != null:
			# Always use actual mouse position, not camera center
			var screen_pos := vp.get_mouse_position()
			world_position = _convert_screen_to_world(screen_pos)
		else:
			# Final fallback to view center
			return move_to_viewport_center_tile()

	# Use positioning utility to convert world position to tile and move there
	var target_tile: Vector2i = GBPositioning2DUtils.get_tile_from_global_position(world_position, _targeting_state.target_map)
	var result_tile: Vector2i = GBPositioning2DUtils.move_to_tile_center(self, target_tile, _targeting_state.target_map)
	assert(target_tile == result_tile, "The target tile should always match the result tile after moving.")
	_log_positioning("moved to cursor tile -> tile %s pos %s" % [str(result_tile), str(self.global_position)])
	return result_tile

## Apply manual recenter logic based on settings.
func _apply_recenter() -> void:
	var mode := _targeting_settings.manual_recenter_mode if _targeting_settings != null else GBEnums.CenteringMode.CENTER_ON_SCREEN
	_last_manual_recenter_mode = mode
	_logger.log_trace("_apply_recenter() called with mode: %d" % mode)
	match mode:
		GBEnums.CenteringMode.CENTER_ON_MOUSE:
			_logger.log_trace("Executing CENTER_ON_MOUSE recenter")
			move_to_cursor_center_tile()
			return
		_:
			_logger.log_trace("Executing viewport center recenter")
			move_to_viewport_center_tile()

## Retrieve the last manual recenter mode applied.
func get_last_manual_recenter_mode() -> int:
	return _last_manual_recenter_mode

func _exit_tree() -> void:
	remove_self_as_positioner()

## Removes this object from being set to the _targeting_state.positioner property
func remove_self_as_positioner():
	if is_instance_valid(_targeting_state):
		## Remove self from being the state positioner
		if(_targeting_state.positioner == self):
			_targeting_state.positioner = null

## Uses whether the mouse movement was consumed by UI
## to determine if the positioner and child objects should
## be visible or invisible. Only called when hide_on_handled is true
func update_visibility() -> void:
	# Recalculate desired visibility based on current mode and settings
	_set_visibility_reason("update_visibility")
	_set_visible_state(should_be_visible())

## Returns whether the positioner should be visible given current mode/settings.
## Mouse handled gating remains event-driven and is not applied here.
func should_be_visible() -> bool:
	# If mode/state not ready, keep current visibility to avoid flicker
	if _mode_state == null:
		return visible
	# Use Dictionary snapshot of last mouse input status to match GridPositionerLogic signature
	return GridPositionerLogic.should_be_visible(_mode_state.current, _targeting_settings, _last_mouse_input_status, _has_mouse_world)

## Internal dependency injection helper method.
## For runtime use, prefer implementing resolve_gb_dependencies() which is called by GBInjectorSystem.
## This method is primarily for testing and advanced use cases where you need explicit control.
## [param p_states] GBStates providing .targeting and .mode
## [param p_config] GBConfig for settings (expects settings.targeting)
## [param p_logger] Optional GBLogger for diagnostics
## [param p_actions] Optional GBActions for keyboard bindings
## [param enable_input] When true, enable input processing immediately (default true)
func set_dependencies(p_states : GBStates, p_config : GBConfig, p_logger: GBLogger = null, p_actions: GBActions = null, enable_input: bool = true) -> void:
	_targeting_state = p_states.targeting
	_mode_state = p_states.mode
	# Access targeting settings through GBConfig.settings
	_targeting_settings = p_config.settings.targeting if p_config != null and p_config.settings != null else null
	_debug_settings = p_config.settings.debug if p_config != null and p_config.settings != null else null
	if _debug_settings == null:
		_debug_settings = GBDebugSettings.new()
	_logger = p_logger
	# Prefer explicitly provided actions; fall back to config.actions if not provided
	_actions = p_actions if p_actions != null else (p_config.actions if p_config != null else null)
	_last_manual_recenter_mode = _targeting_settings.manual_recenter_mode if _targeting_settings != null else GBEnums.CenteringMode.CENTER_ON_SCREEN
	if is_instance_valid(_targeting_state):
		_targeting_state.positioner = self
	# Initialize visibility based on current mode/settings
	update_visibility()
	# Enable input processing by default so tests/runtime can inject InputEvents
	var was_input_enabled := input_processing_enabled
	if enable_input:
		input_processing_enabled = true
		set_process_input(true)
		# Note: _apply_recenter_on_enable() is called by resolve_gb_dependencies() 
		# after all setup is complete to ensure viewport is ready
	validate_dependencies()
	
## Checks if the properties of the GridPositioner2D are set properly during gameplay.
## Returns validation issues if dependencies are missing, empty array if valid.[br][br]
## [code]return[/code]: [i]Array[String][/i] - List of validation issues (empty if valid)
func get_runtime_issues() -> Array[String]:
	var issues : Array[String] = []
	# Validate required injected states
	issues.append_array(GBValidation.check_not_null(self, ["_targeting_state", "_targeting_settings", "_mode_state"]))
	return issues

## Runtime validation logs all issues that should be resolved at runtime [br]
## Call after all dependencies are expected to be resolved.
func validate_dependencies() -> bool:
	var issues := get_runtime_issues()
	
	if not issues.is_empty():
		issues.append("GridPositioner2D at %s has runtime issues and will not run correctly." % self.get_path())
		_logger.log_issues(issues)
	
	return issues.is_empty()

func _on_mode_changed(p_mode : GBEnums.Mode):
	# Apply positioning when entering build mode (to ensure positioner is visible on screen)
	if p_mode == GBEnums.Mode.BUILD:
		_apply_recenter_on_enable()
	
	# Apply computed visibility for the new mode using the provided mode
	_set_visibility_reason("mode_changed:" + str(p_mode))
	_set_visible_state(_should_be_visible_for_mode(p_mode))
	# Diagnostics: mode changes
	_log_state_flow("mode_changed -> %s, visible=%s, remain_active_in_off_mode=%s" % [str(p_mode), str(visible), str(_targeting_settings.remain_active_in_off_mode if _targeting_settings else "<n/a>")])

## Helper to compute visibility given an explicit mode value
func _should_be_visible_for_mode(p_mode: GBEnums.Mode) -> bool:
	return GridPositionerLogic.should_be_visible_for_mode(p_mode, _targeting_settings)

#region Movement Utility Methods
# Movement methods removed - using GBPositioning2DUtils directly
#endregion

## Visual helpers are provided by GBSearchUtils universally
func get_visual_node() -> Node:
	return GBSearchUtils.find_visual_node_direct(self)

func is_visual_visible() -> bool:
	return GBSearchUtils.is_visual_visible(self, false)

## Helper to keep this node and its visual in sync for visibility
func _set_visible_state(p_visible: bool) -> void:
	
	var old_self: bool = visible
	var visual := get_visual_node()
	var had_visual: bool = visual != null and visual is CanvasItem
	var old_visual_visible_str: String = "n/a"
	if had_visual:
		old_visual_visible_str = str((visual as CanvasItem).visible)

	visible = p_visible
	if had_visual:
		(visual as CanvasItem).visible = p_visible

	# If we are turning visibility OFF, capture a stack trace for diagnosis and include decision context
	if _is_visibility_logging_enabled() and not p_visible:
		var stack := get_stack()
		var stack_summary := GBDiagnostics.format_stack_summary(stack, 6)
		var trace := _visibility_decision_trace()
		# Include last mouse input status and cached mouse world presence for diagnosis
		var last_mouse := _last_mouse_input_status
		var mouse_info := "<n/a>"
		if last_mouse != null:
			mouse_info = "allowed=%s method=%s pos=%s" % [str(last_mouse.allowed), str(last_mouse.method_name), str(last_mouse.world)]
		var has_mouse := str(_has_mouse_world)
		_log_visibility("visibility_off reason=%s trace=[%s] last_mouse=[%s] has_mouse_world=%s stack=%s" % [_last_visibility_event_reason, trace, mouse_info, has_mouse, stack_summary], false)

	if _is_visibility_logging_enabled():
		var ctx := _visibility_context(visual if had_visual else null)
		var new_visual_visible_str: String = "n/a"
		if had_visual:
			new_visual_visible_str = str((visual as CanvasItem).visible)
		_log_visibility("set_visible_state(%s) self:%s->%s visual:%s->%s %s" % [str(p_visible), str(old_self), str(visible), old_visual_visible_str, new_visual_visible_str, ctx])
		if had_visual and _is_visibility_logging_enabled():
			_log_visibility("visual_state %s" % GBDiagnostics.format_canvas_item_state(visual))
	if _is_mouse_input_logging_enabled():
		_log_screen_and_mouse_state()

	# Schedule end-of-frame state logging if enabled (deferred to catch final state after other systems)
	if _is_visibility_logging_enabled():
		_schedule_end_of_frame_state_log()

## Helper: explicit render state log for manual triggering if needed
func log_current_visual_state():
	if not _is_visibility_logging_enabled():
		return
	var visual := get_visual_node()
	if visual and visual is CanvasItem:
		_log_visibility("visual_state %s" % GBDiagnostics.format_canvas_item_state(visual))

## Schedule end-of-frame state logging (deferred to next frame to catch final state)
func _schedule_end_of_frame_state_log() -> void:
	if not is_inside_tree():
		return
	# Use call_deferred to schedule for end of current frame
	call_deferred("_log_end_of_frame_state_async")

## Async log of end-of-frame state (called deferred)
func _log_end_of_frame_state_async() -> void:
	if not _logger or not _is_visibility_logging_enabled():
		return
	var visual := get_visual_node()
	var ctx := _visibility_context(visual if visual and visual is CanvasItem else null)
	var state := "visible=%s" % str(visible)
	if visual and visual is CanvasItem:
		state += " visual_visible=%s" % str((visual as CanvasItem).visible)
	state += " %s" % ctx
	# End-of-frame diagnostics should always emit when requested; avoid throttling suppression
	_log_visibility("end_of_frame_state %s" % state, false)

## Diagnostic: log screen/camera bounds, positioner screen relation, mouse world, and tile info
func _log_screen_and_mouse_state():
	if not _logger or not _is_mouse_input_logging_enabled():
		return
	var vp := _get_active_viewport()
	var cam := _get_active_camera(vp)
	var map_ref: Variant = null
	if is_input_ready():
		map_ref = _targeting_state.target_map
	var msg := GBDiagnostics.format_screen_state(cam, vp, global_position, _has_mouse_world, _last_mouse_world, map_ref)
	_log_mouse(msg)

## Build a visibility context string: first hidden ancestor, alpha, z-index, and position
func _visibility_context(visual: CanvasItem) -> String:
	var vp := _get_active_viewport()
	var cam := _get_active_camera(vp)
	return GBDiagnostics.format_visibility_context(self, visual, vp, cam)

## (Stack summary moved to GBDiagnostics.format_stack_summary)

## Whether the positioner is active and should update each frame
func is_positioner_active() -> bool:
	if _mode_state == null:
		return false
	# When mode is OFF, positioner may still be active if settings allow it
	return GridPositionerLogic.is_positioner_active(_mode_state.current, _targeting_settings)
	
## Whether the positioner should hide when the mouse events are handled by UI
func should_hide_under_handled_ui() -> bool:
	return _targeting_settings.hide_on_handled if _targeting_settings else false

## Check if all critical dependencies have been resolved
func are_dependencies_resolved() -> bool:
	return _mode_state != null and _targeting_settings != null and _targeting_state != null

## Diagnostics: concise state summary for tests and debug logging
## Safe to call even before dependency injection - provides fallback values
func to_diagnostic_string() -> String:
	# Defensive: provide diagnostic info even if dependencies aren't fully resolved
	var dependencies_resolved := are_dependencies_resolved()
	var has_mode_state := _mode_state != null
	var has_targeting_settings := _targeting_settings != null
	var has_targeting_state := _targeting_state != null
	var has_logger := _logger != null
	var input_ready := is_input_ready()

	var mode_label := "<no_mode_state>"
	if has_mode_state:
		mode_label = str(_mode_state.current)

	var mouse_input_enabled := false
	var keyboard_input_enabled := false
	var restrict_to_map_area := false
	var limit_to_adjacent := false
	if has_targeting_settings:
		mouse_input_enabled = _targeting_settings.enable_mouse_input
		keyboard_input_enabled = _targeting_settings.enable_keyboard_input
		restrict_to_map_area = _targeting_settings.restrict_to_map_area
		limit_to_adjacent = _targeting_settings.limit_to_adjacent

	var active_viewport: Viewport = null
	var active_camera: Camera2D = null
	if input_ready and has_targeting_state:
		var target_map := _targeting_state.target_map
		if target_map != null:
			active_viewport = target_map.get_viewport()
			if active_viewport != null:
				active_camera = active_viewport.get_camera_2d()

	var is_camera_current := false
	var camera_zoom := Vector2.ONE
	var camera_position := Vector2.ZERO
	if active_camera != null:
		is_camera_current = active_camera.is_current()
		camera_zoom = active_camera.zoom
		camera_position = active_camera.global_position

	var visual_node := get_visual_node()
	var visual_label := "<none>"
	var visual_visible := "<n/a>"
	if visual_node != null:
		visual_label = "%s(%s)" % [visual_node.name, visual_node.get_class()]
		visual_visible = str(visual_node.visible)

	var descriptor_parts: Array[String] = []
	descriptor_parts.append("dependencies_resolved=%s" % str(dependencies_resolved))
	descriptor_parts.append("has_logger=%s" % str(has_logger))
	descriptor_parts.append("has_mode_state=%s" % str(has_mode_state))
	descriptor_parts.append("has_targeting_settings=%s" % str(has_targeting_settings))
	descriptor_parts.append("has_targeting_state=%s" % str(has_targeting_state))
	descriptor_parts.append("mode=%s" % mode_label)
	descriptor_parts.append("visible=%s" % str(visible))
	descriptor_parts.append("physics_process=%s" % str(is_physics_processing()))
	descriptor_parts.append("process_input=%s" % str(is_processing_input()))
	descriptor_parts.append("process_unhandled=%s" % str(is_processing_unhandled_input()))
	descriptor_parts.append("position=%s" % str(global_position))
	descriptor_parts.append("input_ready=%s" % str(input_ready))
	descriptor_parts.append("mouse_input_enabled=%s" % str(mouse_input_enabled))
	descriptor_parts.append("keyboard_input_enabled=%s" % str(keyboard_input_enabled))
	descriptor_parts.append("restrict_to_map_area=%s" % str(restrict_to_map_area))
	descriptor_parts.append("limit_to_adjacent=%s" % str(limit_to_adjacent))
	descriptor_parts.append("visual=%s" % visual_label)
	descriptor_parts.append("visual_visible=%s" % visual_visible)
	descriptor_parts.append("viewport_ready=%s" % str(active_viewport != null))
	descriptor_parts.append("camera_ready=%s" % str(active_camera != null))
	descriptor_parts.append("camera_current=%s" % str(is_camera_current))
	descriptor_parts.append("camera_zoom=%s" % str(camera_zoom))
	descriptor_parts.append("camera_position=%s" % str(camera_position))

	var descriptor_text := ", ".join(PackedStringArray(descriptor_parts))
	return descriptor_text

func _set_visibility_reason(p_reason: String) -> void:
	_last_visibility_event_reason = p_reason

func _visibility_decision_trace() -> String:
	# Pass a Dictionary snapshot (public API) to the logic helper to satisfy its typed signature
	return GridPositionerLogic.visibility_decision_trace(_mode_state, _targeting_settings, _last_mouse_input_status, _has_mouse_world)
#endregion


#region Debug diagnostics (driven by GBSettings.debug.grid_positioner_log_mode)


func _get_debug_log_mode() -> GBDebugSettings.GridPositionerLogMode:
	if _debug_settings != null:
		return _debug_settings.grid_positioner_log_mode
	return GBDebugSettings.GridPositionerLogMode.VISIBILITY

func _is_logging_mode(p_mode: GBDebugSettings.GridPositionerLogMode) -> bool:
	return _get_debug_log_mode() == p_mode

func _is_visibility_logging_enabled() -> bool:
	return _is_logging_mode(GBDebugSettings.GridPositionerLogMode.VISIBILITY)

func _is_mouse_input_logging_enabled() -> bool:
	return _is_logging_mode(GBDebugSettings.GridPositionerLogMode.MOUSE_INPUT)

func _is_positioning_logging_enabled() -> bool:
	return _is_logging_mode(GBDebugSettings.GridPositionerLogMode.POSITIONING)

func _is_state_flow_logging_enabled() -> bool:
	return _is_logging_mode(GBDebugSettings.GridPositionerLogMode.STATE_FLOW)

#endregion

#region Logging helpers

func _log_debug(p_mode: GBDebugSettings.GridPositionerLogMode, p_message: String, p_throttled: bool = true) -> void:
	if _logger == null or not _is_logging_mode(p_mode):
		return
	var formatted := GBDiagnostics.format_debug("%s %s" % [LOG_PREFIX, p_message], "GridPositioner2D", get_script().resource_path)
	if p_throttled:
		_logger.log_verbose_throttled(self, formatted)
		return
	_logger.log_verbose(formatted)

func _log_visibility(p_message: String, p_throttled: bool = true) -> void:
	_log_debug(GBDebugSettings.GridPositionerLogMode.VISIBILITY, p_message, p_throttled)

func _log_mouse(p_message: String, p_throttled: bool = true) -> void:
	_log_debug(GBDebugSettings.GridPositionerLogMode.MOUSE_INPUT, p_message, p_throttled)

func _log_positioning(p_message: String, p_throttled: bool = true) -> void:
	_log_debug(GBDebugSettings.GridPositionerLogMode.POSITIONING, p_message, p_throttled)

func _log_state_flow(p_message: String, p_throttled: bool = true) -> void:
	_log_debug(GBDebugSettings.GridPositionerLogMode.STATE_FLOW, p_message, p_throttled)

#endregion

## Unit test helper: verify screen-to-world coordinate conversion
## Returns the converted world position for testing purposes
func _test_convert_screen_to_world(screen_pos: Vector2) -> Vector2:
	return _convert_screen_to_world(screen_pos)

## Unit test helper: verify tile center calculation
## Returns the tile coordinate and world position for testing
func _test_get_tile_center_from_screen(screen_pos: Vector2) -> Dictionary:
	if not is_input_ready():
		return {"tile": Vector2i.ZERO, "world_pos": Vector2.ZERO, "tile_center": Vector2.ZERO}
	
	var world_pos: Vector2 = _convert_screen_to_world(screen_pos)
	var tile_coord: Vector2i = GBPositioning2DUtils.get_tile_from_global_position(world_pos, _targeting_state.target_map)
	
	# Calculate tile center position using TileMapLayer methods
	var map: TileMapLayer = _targeting_state.target_map
	var tile_local: Vector2 = map.map_to_local(tile_coord)
	var tile_size: Vector2 = map.tile_set.tile_size
	var tile_center_local: Vector2 = tile_local + tile_size * 0.5
	var tile_center: Vector2 = map.to_global(tile_center_local)
	
	return {
		"tile": tile_coord,
		"world_pos": world_pos,
		"tile_center": tile_center
	}

func _apply_visibility_result(p_result: MouseEventVisibilityResult) -> void:
	if p_result != null and p_result.apply:
		_set_visibility_reason(p_result.reason)
		_set_visible_state(p_result.visible)
