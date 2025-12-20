## Base class for placement validation conditions.
@icon("res://addons/grid_building/icons/kenney/checkmark.png")
class_name PlacementRule
extends GBResource

var _grid_targeting_state : GridTargetingState

## Whether the rule is ready for use.
var _ready : bool = false

const REASON_VIRTUAL : String = "This is a virtual condition function and should be implemented in a class that inherits from PlacementRule"

## Checks a set of shape casts for building validity and
## returns whether the condition has been met or not
func validate_placement() -> RuleResult:
	return RuleResult.build(self, [REASON_VIRTUAL])

## The base function sets the grid targeting state for context which sources the target object being placed and the placer.
## Returns any issues found in the setup as an Array[String].[br][br]
## [code]p_gts[/code]: [i]GridTargetingState[/i] - Holds contextual state information for what is being targeted for placement and who is doing the placing
func setup(p_gts : GridTargetingState) -> Array[String]:
	if _ready:
		tear_down()

	_grid_targeting_state = p_gts
	var issues : Array[String] = []
	_ready = issues.is_empty()
	issues.append_array(get_runtime_issues())
	return issues
	
## Optional code to be executed if this and all other tested rules validate successfully
func apply() -> Array[String]:
	return []

## Any cleanup code to run after the system changes preview instances or stops building
## Runs before the building system changes placeable preview
func tear_down() -> void:
	_ready = false

func _to_string() -> String:
	return "PlacementRule: %s" % resource_path

## Returns an array of issues found during editor validation
func get_editor_issues() -> Array[String]:
	var issues: Array[String] = []
	
	return issues

## Returns an array of issues found during runtime validation
func get_runtime_issues() -> Array[String]:
	var issues: Array[String] = []
	
	issues.append_array(get_editor_issues())
	
	if not _grid_targeting_state:
		issues.append("[grid_targeting_state] is null")
	else:
		issues.append_array(_grid_targeting_state.get_runtime_issues())

	if not _ready:
		issues.append("PlacementRule is not ready - setup() must be called before use")
	
	return issues
