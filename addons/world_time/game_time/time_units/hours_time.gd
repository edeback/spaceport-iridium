class_name HoursTime
extends Resource
## Time code in human readable format

@export_range(0, 24, 1, "or_greater") var hours : int = 0 :
	set(value):
		hours = max(value, 0)
		
		if value < 0:
			push_warning("Tried setting hours to negative time value, setting to 0")
@export_range(0, 60, 1, "or_greater") var minutes : int = 0 :
	set(value):
		minutes = max(value, 0)
		
		if value < 0:
			push_warning("Tried setting minutes to negative time value, setting to 0")
@export_range(0, 60, 1, "or_greater") var seconds : float = 0 :
	set(value):
		seconds = maxf(value, 0)
		
		if value < 0:
			push_warning("Tried setting seconds to negative time value, setting to 0")
			
const STRING_FORMAT = "%dh : %dm : %ds"

func _init(p_hours : float = 0, p_minutes : int = 0, p_seconds : float = 0):
	seconds = p_seconds
	minutes = p_minutes
	hours = p_hours

## Calculates the total seconds and returns it based off of the time_scale
func as_game_seconds(time_scale : TimeScale) -> float:
	var hours_seconds = time_scale.seconds_per_hour * hours
	var minutes_seconds = time_scale.seconds_per_minute * minutes
	var total = hours_seconds + minutes_seconds + seconds
	return total
	
## Converts a number of seconds to HoursTime using a given time_scale
## to handle calculations
static func from_game_seconds(p_seconds : float, time_scale : TimeScale) -> HoursTime:
	var remainder = p_seconds
	var days = remainder % time_scale.seconds_per_day
	remainder -= days * time_scale.seconds_per_day
	var hours = remainder % time_scale.seconds_per_hour
	remainder -= hours * time_scale.seconds_per_hour
	var minutes = remainder % time_scale.seconds_per_minute
	remainder -= minutes * time_scale.seconds_per_minute
	var seconds = remainder
	var hours_time = HoursTime.new(hours, minutes, seconds)
	return hours_time

## Checks if the hours, minutes, and seconds are the same in the p_time
##
## Returns true if all time values are the same
func is_same_time(p_time : HoursTime) -> bool:
	var same_hours = p_time.hours == hours
	var same_minutes = p_time.minutes == minutes
	var same_seconds = p_time.seconds == seconds
	var same = same_hours && same_minutes && same_seconds
	return same

## Checks if the hours time comes after the second_time in terms of time
##
## (Valid assuming hours > minutes > seconds in time scale)
##
## Returns true if it comes after
func is_after(second_time : HoursTime) -> bool:
	if hours > second_time.hours: return true
	if hours < second_time.hours: return false
	if minutes > second_time.minutes: return true
	if minutes < second_time.minutes: return false
	if seconds > second_time.seconds: return true
	if seconds < second_time.seconds: return false
	
	return false

## Converts an HoursTime object to a state dictionary
func to_dict() -> Dictionary:
	var state = {
		"hours": hours,
		"minutes": minutes,
		"seconds": seconds
	}
	return state

## Loads a state dictionary to the hours_time object
func from_dict(state: Dictionary) -> void:
	if state.has("hours"):
		hours = state["hours"]
	else:
		push_error("Hours state is null on " + str(get_path))
	if state.has("minutes"):
		minutes = state["minutes"]
	else:
		push_error("Minutes state is null on " + str(get_path))
	if state.has("seconds"):
		seconds = state["seconds"]
	else:
		push_error("Seconds state is null on " + str(get_path))

func _to_string() -> String:
	return STRING_FORMAT % [hours, minutes, seconds]
