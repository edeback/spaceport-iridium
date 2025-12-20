class_name TimeOfDayToggle
extends Node
## Toggle action that occurs when time of day is entered

## Defaults to global if left unset
@export var time_state : TimeState :
	set(value):
		if time_state != null:
			time_state.time_of_day_changed.disconnect(_on_time_of_day_changed)
	
		time_state = value
		
		if time_state != null:
			time_state.time_of_day_changed.connect(_on_time_of_day_changed)

## The times of day when the property will be set on
@export var on_times : Array[TimeOfDay]

## The node that has a property you want to toggle with this script when in the appropriate
## time of day
@export var target : Node

## The property you want to toggle off when TimeState is in one of the on_times and off
## at other times
@export var property : StringName

func _ready():
	if time_state == null:
		push_warning("There is no time state set at %s" % get_path())
	
	if target.get(property) == null:
		push_warning("Property '%s' does not exist on target node %s. Correct name at %s" % [property, target.name, get_path()])
		

func _on_time_of_day_changed(p_new : TimeOfDay, p_old : TimeOfDay):
	var is_on = p_new in on_times
	target.set(property, is_on)
