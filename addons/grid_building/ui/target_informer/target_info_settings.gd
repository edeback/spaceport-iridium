class_name TargetInfoSettings
extends GBResource
## Settings that define what properties and display formats should be used
## for showing information of a TargetInformer object

## How many decimals to show in position strings
@export var position_decimals: int = 0

## String for displaying the X, Y position of the object
@export var position_format = "(%s, %s)"

## Returns an array of issues found during editor validation
func get_editor_issues() -> Array[String]:
	var issues: Array[String] = []
	
	if position_decimals < 0:
		issues.append("TargetInfoSettings position_decimals cannot be negative")
	
	if not position_format.contains("%s"):
		issues.append("TargetInfoSettings position_format must contain at least one %s placeholder")
	
	return issues

## Returns an array of issues found during runtime validation
func get_runtime_issues() -> Array[String]:
	var issues: Array[String] = []
	
	issues.append_array(get_editor_issues())
	
	return issues
