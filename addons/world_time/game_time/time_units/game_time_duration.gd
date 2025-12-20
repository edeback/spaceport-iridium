## Period of game time. Defines a period of game time in terms of game days, hours, minutes, and seconds.
## Convertable to game seconds by calling as_game_seconds
class_name GameTimeDuration
extends Resource

@export_range(0, 10, 1, "or_greater") var days : int = 0
@export_range(0, 24, 1, "or_greater") var hours : int = 0
@export_range(0, 60, 1, "or_greater") var minutes : int = 0
@export_range(0, 60, 1, "or_greater") var seconds : float = 0

func _init(p_days: int = 0, p_hours : int = 0, p_minutes : int = 0, p_seconds : float = 0.0):
	days = p_days
	hours = p_hours
	minutes = p_minutes
	seconds = p_seconds

## Calculates the total number of seconds for the duration
## based on a time scale
##
## Returns the total calculated seconds
func as_game_seconds(time_scale : TimeScale) -> float:
	var days_seconds = time_scale.seconds_per_day * days
	var hours_seconds = time_scale.seconds_per_hour * hours
	var minutes_seconds = time_scale.seconds_per_minute * minutes
	var total = days_seconds + hours_seconds + minutes_seconds + seconds
	return total
