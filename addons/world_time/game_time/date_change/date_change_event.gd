class_name DateChangeEvent
extends Object

## The new game date set
var new : GameDate

## The old game date that was previously set
var old : GameDate

## The amount of days difference between the new and old game dates
var change : int

## Calendar that the date was changed for
var calendar : GameCalendar

func _init(p_new : GameDate, p_old : GameDate, p_days_change : int):
	new = p_new
	old = p_old
	change = p_days_change
