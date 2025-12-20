## Visual settings for displaying grid building information and UI elements
## to the player.
class_name GBVisualSettings
extends GBResource

## Cursor graphics for different grid building modes
@export var cursor: CursorSettings

## Settings for highlighting targets in the game world during building, move, demolish, etc.
## This includes colors for valid and invalid moves, as well as reset colors
@export var highlight: HighlightSettings

@export var target_info: TargetInfoSettings

func get_editor_issues() -> Array[String]:
	var issues : Array[String] = []

	if cursor == null:
		issues.append("GBVisualSettings.cursor is null")
	if highlight == null:
		issues.append("GBVisualSettings.highlight is null")
	if target_info == null:
		issues.append("GBVisualSettings.target_info is null")

	return issues

func get_runtime_issues() -> Array[String]:
	var issues : Array[String] = []
	issues.append_array(get_editor_issues())
	return issues