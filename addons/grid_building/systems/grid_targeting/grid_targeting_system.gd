## Orchestrates grid targeting dependencies (state, settings, path manager, position mover).
##
## Provides a single injection point for GridTargeting/Settings/PathManager, owns the shared
## AStar grid manager, and exposes runtime APIs for other systems (placement,
## manipulation) to validate targeting readiness or request tile movements. Scene
## nodes such as GridPositioner2D focus on visuals/input, while this system keeps
## configuration, validation, and helper delegation centralized.
class_name GridTargetingSystem
extends GBSystem

var _logger: GBLogger
var _path_manager: GBAStarPathManager

## Creates a GridTargetingSystem with dependency injection from container.
static func create_with_injection(p_parent : Node, container: GBCompositionContainer) -> GridTargetingSystem:
	var system = GridTargetingSystem.new()
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
func get_runtime_issues() -> Array[String]:
	var issues: Array[String] = []
	
	if not _systems_context:
		issues.append("GBSystemsContext is not set")
	
	if not _targeting_state:
		issues.append("GridTargetingState is not set")
		
	if not _targeting_settings:
		issues.append("GridTargetingSettings is not set")
	else:
		var editor_issues : Array[String] = _targeting_settings.get_editor_issues()
		if not editor_issues.is_empty():
			issues.append_array(editor_issues)
			issues.append("GridTargetingSettings are not valid yet")
		
	if not _mode_state:
		issues.append("ModeState is not set")
	
	# Validate AStar grid
	var _active_grid: AStarGrid2D = null
	if _path_manager != null:
		_active_grid = _path_manager.get_grid()
	# Fallback: if an external astar was explicitly adopted, prefer that reference
	if _active_grid == null:
		_active_grid = astar_grid

	if not is_instance_valid(_active_grid):
		issues.append("AStarGrid2D must be set for system to run. Has GridTargetingState.target_map been set yet?")
	else:
		if _active_grid.region.size.x == 0 || _active_grid.region.size.y == 0:
			issues.append("AStarGrid2D region size is unusable " + str(_active_grid.region.size))
		
		if _targeting_settings and _active_grid.default_compute_heuristic != _targeting_settings.default_compute_heuristic:
			issues.append("AStarGrid2D heuristic mismatch with settings")
	
	return issues

## Compatibility accessor for older tests expecting get_state().
## Returns the underlying GridTargetingState used by this system.
func get_state() -> GridTargetingState:
	return _targeting_state

#region Signals
## Emitted when the AStarGrid2D used by the Grid Targeting System is created or changes
signal astar_grid_changed(astar_grid : AStarGrid2D)
#endregion
#region Properties
#region Injected

## The tile location where the mouse is currently hovering over represented as X / Y values of the _targeting_state.target_map
var target_tile : Vector2

## Whether the mouse input was consumed by GUI already or not (renamed from mouse_handled)
var ui_mouse_handled : bool = false

## Contains the current values for targeting _targeting_state related properties
var _systems_context : GBSystemsContext
var _targeting_state : GridTargetingState
var _targeting_settings : GridTargetingSettings
var _mode_state : ModeState
var astar_grid : AStarGrid2D = null
#endregion

#endregion
#region Methods
func _init(p_targeting_state : GridTargetingState = null, 
		p_targeting_settings : GridTargetingSettings = null) -> void:
	if is_instance_valid(p_targeting_state): _targeting_state = p_targeting_state
	if is_instance_valid(p_targeting_settings): _targeting_settings = p_targeting_settings
	
## Move the positioner to the center of the mouse tile over where the mouse is [br][br]
## 
## NOTE: Positioner updates are now handled by GridPositioner2D
func _input(event: InputEvent) -> void:
	if not _are_dependencies_resolved():
		return

	# Mouse movement: only update astar grid if mouse input is enabled
	if event is InputEventMouseMotion and _targeting_settings and _targeting_settings.enable_mouse_input:
		if _path_manager:
			_path_manager.update_if_dirty()
		
func resolve_gb_dependencies(p_container : GBCompositionContainer) -> void:
	_systems_context = p_container.get_systems_context()
	if _systems_context != null:
		_systems_context.set_system(self)
	_targeting_state = p_container.get_states().targeting
	_targeting_settings = p_container.get_settings().targeting
	_mode_state = p_container.get_states().mode
	_logger = p_container.get_logger()

	_path_manager = GBAStarPathManager.new(_targeting_settings, _get_target_map())

	# Add to group for positioner to find utility methods
	add_to_group("grid_targeting_systems")
	if _mode_state and not _mode_state.mode_changed.is_connected(_on_mode_changed):
		_mode_state.mode_changed.connect(_on_mode_changed)
	
	if _targeting_state == null: # Auto disable if _targeting_state is null
		process_mode = Node.PROCESS_MODE_DISABLED
		
	update_astar_grid_2d(astar_grid, _targeting_settings)
	_subscribe_targeting_settings()
		
## Move the positioner to adjust the shown position of any visual _targeting_settings elements.
## If limit_to_adjacent setting is on, the closest valid target will be limited by the p_source position and the max_tiles_distance.[br][br]
## [code]p_target_tile[/code]: [i]Vector2i[/i] - Desired tile location to move to[br]
## [code]p_positioner[/code]: [i]Node2D[/i] - Node to move to the target position[br]
## [code]p_source[/code]: [i]Node2D[/i] - Source node for distance calculations when limit_to_adjacent is enabled
func move_node_to_closest_valid_tile(p_target_tile : Vector2i, p_positioner : Node2D, p_source : Node2D) -> Error:
	if not _are_dependencies_resolved():
		return ERR_UNCONFIGURED
	var map: TileMapLayer = _get_target_map()
	if map == null:
		return ERR_UNCONFIGURED
	# Resolve the correct tile using the central path manager, then instruct mover to apply it.
	var resolved_tile: Vector2i = p_target_tile
	if _path_manager != null:
		resolved_tile = _path_manager.get_closest_valid_tile(p_target_tile, p_source, map, _targeting_settings)
	GBPositioning2DUtils.move_to_tile_center(p_positioner, resolved_tile, map)
	return OK

## Moves a target node to the center snapped position of a p_tile on the _targeting_state.target_map.[br][br]
## [code]p_node[/code]: [i]Node2D[/i] - Node to move to the tile position[br]
## [code]p_tile[/code]: [i]Vector2[/i] - Tile coordinates to move to
func move_to_tile(p_node : Node2D, p_tile : Vector2) -> Error:
	if not _are_dependencies_resolved():
		return ERR_UNCONFIGURED
	var tile := Vector2i(int(round(p_tile.x)), int(round(p_tile.y)))
	var map := _get_target_map()
	if map == null:
		return ERR_UNCONFIGURED
	GBPositioning2DUtils.move_to_tile_center(p_node, tile, map)
	return OK

## Returns the tile on the p_tile_map where the mouse is currently hovering over.[br][br]
## [code]p_global_position[/code]: [i]Vector2[/i] - Global position to convert to tile coordinates[br]
## [code]p_map[/code]: [i]Node2D[/i] - TileMap or TileMapLayer to use for coordinate conversion
func get_tile_from_global_position(p_global_position : Vector2, p_map : Node2D):
	var map_position = p_map.to_local(p_global_position)
	return p_map.local_to_map(map_position)



## Updates an AStarGrid2D according to a set of GridTargetingSettings.[br][br]
## [code]p_astar[/code]: [i]AStarGrid2D[/i] - AStar grid to configure[br]
## [code]p_targeting_settings[/code]: [i]GridTargetingSettings[/i] - Settings to apply to the AStar grid
func update_astar_grid_2d(p_astar : AStarGrid2D, p_targeting_settings : GridTargetingSettings):
	if p_targeting_settings == null:
		push_warning("p_targeting_settings is null. Unable to configure AStarGrid2D.")
		return
	astar_grid = p_astar
	# Adopt the provided astar instance if present
	if astar_grid != null:
		_path_manager.set_grid(astar_grid)

	# Refresh the manager's cached region for the active map, then apply settings
	_path_manager.update_region(_get_target_map())
	_path_manager.configure(p_targeting_settings)
	astar_grid_changed.emit(_path_manager.get_grid())


func _on_validator_valid_changed(is_valid : bool):
	if _targeting_settings.show_debug:
		if _logger:
			if is_valid:
				_logger.log_debug( "[PASSED -- GRID TARGETING SYSTEM] Processing will run.")
			else:
				_logger.log_debug( "[FAILED -- GRID TARGETING SYSTEM] Processing will stop.")
		else:
			if is_valid:
				print("[PASSED -- GRID TARGETING SYSTEM] Processing will run.")
			else:
				print("[FAILED -- GRID TARGETING SYSTEM] Processing will stop.")

func _on_mode_changed(p_mode : GBEnums.Mode):
	_targeting_state.target = null
	
	if p_mode != GBEnums.Mode.OFF:
		var validation_issues = get_runtime_issues()
		if not validation_issues.is_empty():
			for issue in validation_issues:
				push_warning(issue)

## Subscribe to all needed signals
func _subscribe_targeting_settings():
	if _targeting_settings == null:
		return
	if _targeting_settings.changed.is_connected(_on_settings_changed):
		return
	_targeting_settings.changed.connect(_on_settings_changed)

func _on_settings_changed() -> void:
	if _targeting_settings == null:
		return
	# Update the manager region and reconfigure with the new settings
	_path_manager.update_region(_get_target_map())
	_path_manager.configure(_targeting_settings)
	astar_grid_changed.emit(_path_manager.get_grid())

## Public manual validation entry point for host projects.
## Runs get_runtime_issues() and logs issues without relying on timed warnings.
## Returns the list of issues (empty when valid).
func validate_and_log_issues() -> Array[String]:
	var issues := get_runtime_issues()
	if not issues.is_empty():
		if _logger:
			_logger.log_warnings(issues)
		else:
			for issue in issues:
				push_warning(issue)
	return issues

# Disconnect from all needed signals
func _unsubscribe_targeting_settings():
	if _targeting_settings == null:
		return
	if _targeting_settings.changed.is_connected(_on_settings_changed):
		_targeting_settings.changed.disconnect(_on_settings_changed)


func _get_target_map() -> TileMapLayer:
	if _targeting_state == null:
		return null
	var map: TileMapLayer = _targeting_state.target_map
	if map == null:
		return null
	return map if is_instance_valid(map) else null



## Private helper to check if all required dependencies are resolved.[br][br]
## [code]return[/code]: [i]bool[/i] - True if dependencies are available, false otherwise
func _are_dependencies_resolved() -> bool:
	return _targeting_state != null && _targeting_settings != null

func validate_ready() -> bool:
	var issues := get_targeting_issues()
	_logger.log_issues(issues)
	return issues.is_empty()
		
## Gets issues that would prevent the targeting_system from being able to target.
## This should be called after grid targeting state properties have all been defined
func get_targeting_issues() -> Array[String]:
	var issues : Array[String] = get_runtime_issues()
	
	# Check the _targeting_state for any issues
	var state_issues = _targeting_state.get_runtime_issues()
	issues.append_array(state_issues)
	if state_issues.size() > 0:
		issues.append("GridTargetingState is not yet valid. Check above warnings for more information.")
	
	return issues

#endregion
