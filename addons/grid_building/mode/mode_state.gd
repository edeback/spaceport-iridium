## Maintains the state of the Grid Builder mode and emits signals when it changes.
class_name ModeState
extends GBResource

## Emitted whenever the building mode on the building state changes.
signal mode_changed(building_current: GBEnums.Mode)

## The active mode that the system is in for modifying the game world.
@export var current = GBEnums.Mode.OFF:
	set(value):
		if current == value:
			return

		current = value
		mode_changed.emit(current)

## Returns an array of issues found during editor validation
func get_editor_issues() -> Array[String]:
	var issues: Array[String] = []
	
	# ModeState doesn't have specific validation requirements beyond the basic Resource validation
	
	return issues

## Returns an array of issues found during runtime validation
func get_runtime_issues() -> Array[String]:
	var issues: Array[String] = []
	
	issues.append_array(get_editor_issues())
	
	return issues
