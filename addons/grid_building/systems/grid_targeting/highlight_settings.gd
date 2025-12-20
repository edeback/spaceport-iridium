## Settings for manipulating an object in the game world to indicate it as
## a valid, invalid target, etc
class_name HighlightSettings
extends GBResource

## Adjustment color for any preview sprites to indicate that the
## instance is a preview and not actually a interactable object
## in the game
@export var build_preview_color: Color = Color(.6, .6, 1, 0.8)

## Color to highlight a hover target in info mode
@export var info_hover_color: Color = Color(0.6, 0.7, 0.7, 0.85)

## When move is possible
@export var move_valid_color = Color(.2, 1, 0.2, 1)

## When move is not possible
@export var move_invalid_color = Color(1, 0.2, 0.2, 1)

## For objects being moved
@export var active_manipulation_color = Color(0.2, 0.2, 1.0, 0.7)

## When demolishing is possible
@export var demolish_valid_color = Color(.2, 1, 0.2, 1)

## When demolishing is not possible
@export var demolish_invalid_color = Color(1, 0.2, 0.2, 1)

## Default reset modulate color
@export var reset_color = Color.WHITE

## Returns an array of issues found during editor validation
func get_editor_issues() -> Array[String]:
	var issues: Array[String] = []
	
	# Validate that colors are properly set (not null/empty)
	# Color validation is generally not needed as Godot handles invalid colors gracefully
	
	return issues

## Returns an array of issues found during runtime validation
func get_runtime_issues() -> Array[String]:
	var issues: Array[String] = []
	
	issues.append_array(get_editor_issues())
	
	return issues
