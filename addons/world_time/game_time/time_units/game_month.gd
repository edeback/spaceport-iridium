class_name GameMonth
extends Resource

@export var display_name = ""
@export_range(0,9999) var days := 30

## Defines special days during the month that events can occur
##
## Event days will be emitted on TimeStateLogic when entered
@export var event_days : Dictionary[int, EventDay]

func _init(p_days : int = 30, p_name : String = ""):
	days = p_days
	display_name = p_name
