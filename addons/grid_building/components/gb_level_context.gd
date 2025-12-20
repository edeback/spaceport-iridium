## Organizes object requirements for building onto a game level for GBCompositeContainers 
class_name GBLevelContext
extends GBGameNode

## The TileMapLayer to use as the tile selection target for the grid targeting_state
@export var target_map : TileMapLayer

## All maps in the game level.[br][br]
## Sets this data on the targeting_state.maps during gameplay
@export var maps : Array[TileMapLayer]
	
## Where objects should be placed into the scene under in the scene hierarchy
@export var objects_parent: Node2D

var _targeting_state : GridTargetingState
var _building_state : BuildingState
var _logger : GBLogger
	
func resolve_gb_dependencies(p_container : GBCompositionContainer) -> void:
	_targeting_state = p_container.get_states().targeting
	_building_state = p_container.get_building_state()
	_logger = p_container.get_logger()
	
	var issues : Array[String] = get_runtime_issues()
	_logger.log_issues(issues)
	
	apply_to(_targeting_state, _building_state)

## Applies level configuration to targeting and building states.
## Assigns target map, maps array, and objects parent to the appropriate states.[br][br]
## [code]p_targeting[/code]: [i]GridTargetingState[/i] - Targeting state to configure with level maps[br]
## [code]p_building[/code]: [i]BuildingState[/i] - Building state to configure with placement parent
func apply_to(p_targeting: GridTargetingState, p_building : BuildingState):
	if target_map == null or maps.is_empty() or objects_parent == null:
		_logger.log_warning( "LevelBuildingContext is not fully configured.")
	
	p_targeting.target_map = target_map
	p_targeting.maps = maps
	p_building.placed_parent = objects_parent

## Validate setup and return a list of issues with the current object
func get_editor_issues() -> Array[String]:
	var issues : Array[String] = []
	
	if target_map == null:
		issues.append("No target map set for LevelBuildingContext")
	
	if objects_parent == null:
		issues.append("No objects parent set for LevelBuildingContext")
		
	if maps.size() == 0:
		issues.append("No maps set for LevelBuildingContext")
		
	return issues

func get_runtime_issues() -> Array[String]:
	return get_editor_issues()
