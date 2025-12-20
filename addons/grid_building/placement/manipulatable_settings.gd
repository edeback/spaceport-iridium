## Settings for object manipulation rules and placement requirements.
class_name ManipulatableSettings
extends GBResource

## Rules required for completing move actions.
## If [member ignore_base_rules] is [code]false[/code], these rules are combined with
## base rules from [member GBSettings.placement_rules].
@export var move_rules : Array[TileCheckRule] = []

## When [code]true[/code], skips base placement rules from [member GBSettings.placement_rules]
## and uses ONLY the rules defined in [member move_rules].
##
## Use cases:
## - [code]false[/code] (default): Inherit common rules + add movement-specific rules
## - [code]true[/code]: Completely custom move validation (e.g., flying units ignore terrain)
@export var ignore_base_rules : bool = false

## Marks whether the placeable preview should be allowed to be rotated left and right
@export var rotatable : bool = false

## Marks whether the placeable preview should be allowed to be flipped horizontally
@export var flip_horizontal : bool = false

## Marks whether the placeable preview should be allowed to be flipped vertically
@export var flip_vertical : bool = false

## Whether the full object and all children is to be movable
@export var movable = true

## Whether the full object and all children is to be demolishable (intentionally destroyed)
@export var demolishable = true

## Returns an array of issues found during editor validation
func get_editor_issues() -> Array[String]:
	var issues: Array[String] = []
	
	for i in range(move_rules.size()):
		if move_rules[i] == null:
			issues.append("Move rule at index %d is null" % i)
	
	return issues

## Returns an array of issues found during runtime validation
func get_runtime_issues() -> Array[String]:
	var issues: Array[String] = []
	
	issues.append_array(get_editor_issues())
	
	return issues
