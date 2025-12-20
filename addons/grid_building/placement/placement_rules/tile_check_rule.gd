## Base class for rules that check tile properties for placement validation.
class_name TileCheckRule
extends PlacementRule

## Physics layers for collision object detection.
@export_flags_2d_physics() var apply_to_objects_mask : int = 1

## Priority for handling multiple rule failures.
## Rule with the highest priority and a fail display settings set will be used in the indicator's sprite to display.
@export_range(0, 10, 1, "or_greater") var visual_priority : int = 0

## Display settings for an indicator to use with an override priority.
@export var fail_visual_settings : IndicatorVisualSettings

## List of all indicators that are currently using the rule for evaluation.
var indicators : Array[RuleCheckIndicator] = []

## Runs the rule against an array of indicators
## Returns the indicators that fail the test
func get_failing_indicators(p_indicators : Array[RuleCheckIndicator]) -> Array[RuleCheckIndicator]:
	var failing_indicators : Array[RuleCheckIndicator] = []

	for indicator : RuleCheckIndicator in p_indicators:
		if not indicator.valid:
			failing_indicators.append(indicator)

	return failing_indicators

## Returns the tile locations that the indicators are currently positioned over on the tilemap
## You can call this after the rules have been setup for the object being manipulated
func get_tile_positions() -> Array[Vector2i]:
	var positions : Array[Vector2i] = []
	var target_map : TileMapLayer = _grid_targeting_state.target_map
	
	for indicator in indicators:
		positions.append(indicator.get_tile_position(target_map))
		
	return positions

func tear_down():
	indicators = []
	_ready = false

## Returns an array of issues found during editor validation
func get_editor_issues() -> Array[String]:
	var issues: Array[String] = []
	
	issues.append_array(super.get_editor_issues())
	
	if apply_to_objects_mask == 0:
		issues.append("TileCheckRule has no collision layers set in apply_to_objects_mask")
	
	return issues

## Returns an array of issues found during runtime validation
func get_runtime_issues() -> Array[String]:
	var issues: Array[String] = []
	
	issues.append_array(super.get_runtime_issues())
	
	return issues
