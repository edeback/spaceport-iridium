class_name EventDay
extends Resource
## Defines events and notifications that can occur on a specific day of time

@export var display_name : StringName

## Icon you want to represent the day
@export var icon : Texture

## Describes what events happen on the day
@export var description : String

## Color that can be used to represent the day
@export var color = Color.WHITE

## Returns a tooltip text for an event day
func get_tooltip() -> String:
	var tooltip = display_name
	
	if not description.is_empty():
		tooltip += "\n\n" + description
	
	return tooltip
