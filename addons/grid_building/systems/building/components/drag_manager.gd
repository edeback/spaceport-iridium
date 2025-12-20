## Self-contained drag manager for tile-based drag operations.
##
## Reads confirm_build input action directly and monitors GridTargetingState for tile changes.
## When both conditions are met (physics frame + new tile), calls BuildingSystem.try_build().
##
## Architecture (v5.0.0):
## - One-way dependency: DragManager → BuildingSystem (calls try_build API)
## - BuildingSystem has NO knowledge of DragManager
## - Reads input directly via _input() to monitor confirm_build action state
## - Monitors GridTargetingState tile changes in _physics_process()
## - Physics-gated to prevent multiple builds per frame
## - Calls BuildingSystem.try_build() when conditions met
##
## Usage:
## - Add DragManager as a child of your World/Systems node in the scene
## - Call resolve_gb_dependencies(container) to inject dependencies
## - DragManager automatically handles input, drag lifecycle, and building
class_name DragManager
extends GBSystemsComponent

var _targeting_state: GridTargetingState
var _building_system: BuildingSystem
var _logger: GBLogger
var _actions: GBActions
var drag_data: DragPathData = null

## Prevents multiple signal emissions in same physics frame.
## Tracks the last physics frame where targeting_new_tile was emitted to gate rapid signals.
## See: CHANGES/2025-10-02-drag-building-race-condition.md
var _last_signal_physics_frame: int = -1

const DEFAULT_NAME = "DragManager"

func _init(p_name: String = DEFAULT_NAME) -> void:
	name = p_name

func _ready():
	if _logger:
		_logger.log_trace("[DragManager] _ready() called - in_tree=%s" % [is_inside_tree()])
	# Note: Dependency assertions moved to resolve_gb_dependencies() where injection happens
	# Enable physics processing to handle drag updates and tile change detection
	set_physics_process(true)
	# Enable input processing to read confirm_build action state
	set_process_input(true)
	if _logger:
		_logger.log_trace("[DragManager] _ready() completed - physics_process=%s, input_process=%s, in_tree=%s" % [is_physics_processing(), is_processing_input(), is_inside_tree()])

## Public API for tests to manually control drag lifecycle.
## Disables input processing and allows manual drag control.
func set_test_mode(enabled: bool) -> void:
	set_process_input(not enabled)
	if _logger:
		_logger.log_debug("[DragManager] Test mode %s - input_processing=%s" % ["enabled" if enabled else "disabled", is_processing_input()])

## Public API for tests: Reset the physics frame gate to allow next build.
## This simulates advancing to a new physics frame without actually waiting.
## Tests can call this between movements to clear the per-frame gate.
func reset_physics_frame_gate() -> void:
	_last_signal_physics_frame = -1
	if _logger:
		_logger.log_trace("[DragManager] Physics frame gate reset for testing")

## Public API: Start drag operation and return drag data.
## [return] DragPathData instance, or null if drag cannot start
func start_drag() -> DragPathData:
	return _start_drag()

## Public API: Stop drag operation.
func stop_drag() -> void:
	_stop_drag()

## DRY diagnostic helper: Format drag state for debugging
## [param drag_data] The DragPathData instance to format
## [return] Formatted string with drag state information
static func format_drag_state(drag_data: DragPathData) -> String:
	if drag_data == null:
		return "[DragState: null]"
	var tile: Vector2i = drag_data.target_tile if drag_data else Vector2i.ZERO
	var pos: Vector2 = drag_data.positioner.global_position if drag_data and drag_data.positioner else Vector2.ZERO
	var dragging: bool = drag_data.is_dragging if drag_data else false
	return "[DragState: tile=%s, pos=%s, is_dragging=%s]" % [str(tile), str(pos), str(dragging)]

## Reads confirm_build input action to start/stop drag operations.
## Uses _input() instead of _unhandled_input() to read raw input state regardless of handling.
func _input(event: InputEvent) -> void:
	if not InputMap.has_action(_actions.confirm_build):
		return
	
	if event.is_action_pressed(_actions.confirm_build):
		if not is_dragging():
			_start_drag()
	elif event.is_action_released(_actions.confirm_build):
		if is_dragging():
			_stop_drag()

## Public API: Update drag state and check for tile changes.
## Core drag update logic extracted for testability.
## Called automatically by _physics_process() during normal gameplay.
## Tests can call this directly to simulate drag updates without physics timing.
## [param delta] Time elapsed since last update in seconds
func update_drag_state(delta: float) -> void:
	if not is_dragging() or drag_data == null:
		if _logger:
			_logger.log_trace("[DragManager] update_drag_state: exiting early - is_dragging=%s, drag_data=%s" % [is_dragging(), "null" if drag_data == null else "exists"])
		return

	var old_tile = drag_data.target_tile
	var positioner_pos = drag_data.positioner.global_position if drag_data.positioner else Vector2.ZERO
	if _logger:
		_logger.log_trace("[DragManager] Before update: old_tile=%s, positioner_pos=%s" % [old_tile, positioner_pos])
	
	if not _can_continue_dragging():
		if _logger:
			_logger.log_warning("[DragManager] Cannot continue dragging - stopping")
		drag_data.stop()
		return
	
	drag_data.update(delta)
	
	if _logger:
		_logger.log_trace("[DragManager] After update - new_tile=%s, old_tile=%s, changed=%s" % [
			drag_data.target_tile, old_tile, drag_data.target_tile != old_tile
		])
	
	# Trace: Log tile changes for debugging
	if drag_data.target_tile != old_tile:
		if _logger:
			_logger.log_trace("[DragManager] Tile changed: %s -> %s (frame: %d)" % [old_tile, drag_data.target_tile, Engine.get_physics_frames()])
	
	if drag_data.target_tile != old_tile:
		# GATE: Only attempt build once per physics frame
		# This prevents multiple rapid tile changes from triggering
		# multiple builds before physics updates
		var current_physics_frame := Engine.get_physics_frames()
		if current_physics_frame == _last_signal_physics_frame:
			if _logger:
				_logger.log_trace("[DragManager] GATE: Blocked duplicate build in frame %d" % current_physics_frame)
			return  # Already built this frame, skip
		
		_last_signal_physics_frame = current_physics_frame
		if _logger:
			_logger.log_trace("[DragManager] Tile changed: %s -> %s (frame: %d) - calling try_build()" % [
				old_tile, drag_data.target_tile, current_physics_frame
			])
		
		# Prevent consecutive attempts on the same tile
		if drag_data.target_tile == drag_data.last_attempted_tile:
			if _logger:
				_logger.log_trace("[DragManager] Skipping duplicate tile %s" % drag_data.target_tile)
			return
		
		drag_data.last_attempted_tile = drag_data.target_tile
		
		# Check if BuildingSystem is in BUILD mode with active preview
		if not _building_system:
			if _logger:
				_logger.log_warning("[DragManager] No BuildingSystem reference - cannot trigger build")
			return
		
		# Check if in BUILD mode
		var mode_state = _building_system._states.mode if _building_system._states else null
		if not mode_state or mode_state.current != GBEnums.Mode.BUILD:
			if _logger:
				_logger.log_trace("[DragManager] Not in BUILD mode - skipping build attempt")
			return
		
		# Check if preview exists
		var building_state = _building_system._states.building if _building_system._states else null
		if not building_state or not building_state.preview:
			if _logger:
				_logger.log_trace("[DragManager] No active preview - skipping build attempt")
			return
		
		# Count build request (useful for debugging and testing)
		if _logger:
			_logger.log_trace("[DragManager] About to increment build_requests from %d to %d (drag_data instance_id=%d)" % [drag_data.build_requests, drag_data.build_requests + 1, drag_data.get_instance_id()])
		drag_data.build_requests += 1
		if _logger:
			_logger.log_trace("[DragManager] After increment, build_requests = %d (drag_data instance_id=%d)" % [drag_data.build_requests, drag_data.get_instance_id()])
		
		# All conditions met - call BuildingSystem API with DRAG build type
		_building_system.try_build(GBEnums.BuildType.DRAG)

## Synchronizes drag detection with physics frame updates to prevent race conditions.
## Changed from _process() to _physics_process() to ensure drag events align with
## collision detection updates, preventing multiple builds in same physics frame.
## See: CHANGES/2025-10-02-drag-building-race-condition.md
func _physics_process(delta: float) -> void:
	if _logger:
		var drag_data_id = drag_data.get_instance_id() if drag_data else 0
		var drag_data_is_dragging = drag_data.is_dragging if drag_data else false
		_logger.log_trace("[DragManager._physics_process] Called - frame=%d, is_dragging=%s, drag_data=%s, drag_data.is_dragging=%s, drag_data_id=%d, self=%d" % [
			Engine.get_physics_frames(),
			is_dragging(),
			"exists" if drag_data != null else "null",
			drag_data_is_dragging,
			drag_data_id,
			get_instance_id()
		])
	
	# Delegate to public update method
	update_drag_state(delta)

func resolve_gb_dependencies(p_container: GBCompositionContainer) -> void:
	_targeting_state = p_container.get_states().targeting
	_building_system = p_container.get_systems_context().get_building_system()
	_logger = p_container.get_logger()
	_actions = p_container.get_actions()
	
	# Assert dependencies are properly injected after dependency resolution
	assert(
		_targeting_state != null,
		"DragManager requires a reference to the [_targeting_state] to be set before operation."
	)
	assert(
		_actions != null,
		"DragManager requires a reference to [_actions] to read input action state."
	)
	
	if _logger:
		_logger.log_debug("[DragManager] Dependencies resolved - targeting_state=%s, actions=%s" % [_targeting_state != null, _actions != null])

func is_dragging() -> bool:
	return drag_data != null and drag_data.is_dragging

## Internal: Start drag operation and return drag data.
## [return] DragPathData instance, or null if drag cannot start
func _start_drag() -> DragPathData:
	if _logger:
		_logger.log_trace("[DragManager] _start_drag() called - in_tree=%s, physics_enabled=%s" % [is_inside_tree(), is_physics_processing()])
	
	if is_dragging():
		push_warning("Drag already in progress. Cannot start another drag.")
		if _logger:
			_logger.log_warning("[DragManager] _start_drag() aborted - already dragging")
		return null

	if _targeting_state == null or _targeting_state.positioner == null:
		push_error("_targeting_state and positioner must be set before starting drag")
		if _logger:
			_logger.log_error("[DragManager] _start_drag() failed - targeting_state=%s, positioner=%s" % [
				_targeting_state != null, 
				_targeting_state.positioner != null if _targeting_state else "N/A"
			])
		return null

	drag_data = DragPathData.new(_targeting_state.positioner, _targeting_state)
	drag_data.last_attempted_tile = Vector2i(999999, 999999)
	# Reset physics frame gate for new drag session
	_last_signal_physics_frame = -1
	var start_tile = drag_data.target_tile
	var start_pos = drag_data.positioner.global_position
	if _logger:
		_logger.log_trace("[DragManager._start_drag] drag_data=%s, is_dragging=%s, drag_data_id=%d, self=%d, in_tree=%s, physics_processing=%s" % [
			drag_data, 
			drag_data.is_dragging if drag_data else "N/A",
			drag_data.get_instance_id() if drag_data else 0,
			get_instance_id(),
			is_inside_tree(),
			is_physics_processing()
		])
		_logger.log_trace("[DragManager] _start_drag() SUCCESS - drag_data created at tile=%s, pos=%s, physics_enabled=%s, instance_id=%d" % [
			start_tile, start_pos, is_physics_processing(), drag_data.get_instance_id()
		])
	
	return drag_data

func _stop_drag() -> void:
	if _logger and _logger.is_trace_enabled():
		_logger.log_trace("[DragManager] _stop_drag() called - drag_data=%s" % ["exists" if drag_data != null else "null"])
	if drag_data != null and drag_data.is_dragging:
		drag_data.is_dragging = false
		drag_data = null
		# Reset physics frame gate
		_last_signal_physics_frame = -1
		if _logger and _logger.is_trace_enabled():
			_logger.log_trace("[DragManager] _stop_drag() completed - drag_data cleared")

func _can_continue_dragging() -> bool:
	if drag_data == null:
		return false
	
	if drag_data.positioner == null:
		return false
	
	return true
