## Holds references to the systems used in grid building operations.
## This context allows for easy access to the systems without needing to
## pass them around manually.
## It is designed to be used with a GBCompositionContainer that resolves
## dependencies and provides the necessary systems.
class_name GBSystemsContext
extends RefCounted

## Signal emitted when a system becomes available or is replaced.
signal building_system_changed(new_system: BuildingSystem)
signal grid_targeting_system_changed(new_system: GridTargetingSystem)
signal manipulation_system_changed(new_system: ManipulationSystem)

# Internal references to the systems
var _building_system: BuildingSystem = null
var _grid_targeting_system: GridTargetingSystem = null
var _manipulation_system: ManipulationSystem = null
var _logger: GBLogger = null


func _init(p_logger: GBLogger) -> void:
	_logger = p_logger


# --- BUILDING SYSTEM ---


func get_building_system() -> BuildingSystem:
	return _building_system


# --- GRID TARGETING SYSTEM ---

func get_grid_targeting_system() -> GridTargetingSystem:
	return _grid_targeting_system


func get_manipulation_system() -> ManipulationSystem:
	return _manipulation_system

## Sets the passed system as an active system within the context's scope.
func set_system(system: GBSystem) -> void:
	if system is BuildingSystem:
		if _building_system != system:
			_building_system = system
			building_system_changed.emit(system)
	elif system is GridTargetingSystem:
		if _grid_targeting_system != system:
			_grid_targeting_system = system
			grid_targeting_system_changed.emit(system)
	elif system is ManipulationSystem:
		if _manipulation_system != system:
			_manipulation_system = system
			manipulation_system_changed.emit(system)
	else:
		_logger.log_warning( "Attempted to set unknown system type: %s" % [system])

func get_editor_issues() -> Array[String]:
	var issues: Array[String] = []
	return issues

## Returns a list of runtime issues found in the context.
## [code]p_checks[/code]: [i]GBRuntimeChecks[/i] - The runtime checks to perform
func get_runtime_issues(p_checks : GBRuntimeChecks) -> Array[String]:
	var issues: Array[String] = []
	
	issues.append_array(get_editor_issues())

	if p_checks == null:
		issues.append("GBRuntimeChecks is null, skipping all extra runtime checks")
		return issues

	if p_checks.building_system:
		if _building_system == null:
			issues.append("Building system is not set")

	# Note: GBRuntimeChecks uses 'targeting_system' as the flag name
	if p_checks.targeting_system:
		if _grid_targeting_system == null:
			issues.append("Grid targeting system is not set")

	if p_checks.manipulation_system:
		if _manipulation_system == null:
			issues.append("Manipulation system is not set")

	if p_checks.camera_2d:
		if not _has_camera_2d_in_viewport():
			issues.append("Camera2D not found in viewport. This utilities class requires Camera2D for proper coordinate conversion.")

	return issues

## Helper method to check if Camera2D is present in the current viewport
func _has_camera_2d_in_viewport() -> bool:
	# Get the current viewport
	var viewport: Viewport = null
	
	# Try to get viewport from one of the systems if available
	if _grid_targeting_system and is_instance_valid(_grid_targeting_system):
		viewport = _grid_targeting_system.get_viewport()
	elif _building_system and is_instance_valid(_building_system):
		viewport = _building_system.get_viewport()
	
	# Fallback to main viewport if systems don't have viewport access
	# Note: In test environments, SceneTree singleton may not be available
	if not viewport:
		if Engine.has_singleton("SceneTree"):
			var scene_tree := Engine.get_singleton("SceneTree") as SceneTree
			if scene_tree and scene_tree.current_scene:
				viewport = scene_tree.current_scene.get_viewport()
	
	if not viewport:
		# In test environments or when no viewport is available, 
		# we can't validate Camera2D presence, so return false
		return false
	
	# Check if viewport has a Camera2D
	return _find_camera_2d_in_node(viewport)

## Recursively search for Camera2D in a node tree
func _find_camera_2d_in_node(node: Node) -> bool:
	if node is Camera2D:
		return true
	
	for child in node.get_children():
		if _find_camera_2d_in_node(child):
			return true
	
	return false
