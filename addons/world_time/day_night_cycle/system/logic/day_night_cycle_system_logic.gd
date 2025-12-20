class_name DayNightCycleLogic extends RefCounted

var times_of_day : Array[TimeOfDay]
var time_state : TimeState

func _init(p_times_of_day : Array[TimeOfDay], p_time_state : TimeState):
	times_of_day = p_times_of_day
	times_of_day.sort_custom(TimeOfDay.sort_ascending_enter_time)
	time_state = p_time_state

## Returns the time of day in the times_of_day array that comes just before the
## parameter p_tod
func get_previous_time_of_day(p_tod : TimeOfDay) -> TimeOfDay:
	var current_index : int = times_of_day.find(p_tod)

	if current_index == 0:
		# Return last in array
		return times_of_day.back()

	return times_of_day[current_index - 1]

## Get the time of day that starts on or after the current p_date_time
## that comes before the next one that hasn't started yet
func calculate_time_of_day(p_date_time : DateTime) -> TimeOfDay:
	var matching_tod : TimeOfDay
	var closest_before : int = -1
	var closest_seconds_in_past = INF
	var num_tods = times_of_day.size()

	var current_dt_secs = time_state.calendar.get_seconds_from_date_time(p_date_time)

	for i in range(num_tods):
		var tod = times_of_day[i]
		if tod == null || not tod.validate():
			continue
		
		var last_occurance_secs = time_state.calendar.get_last_hours_time_as_secs(tod.enter_time, p_date_time)
		var seconds_in_past = current_dt_secs - last_occurance_secs

		if seconds_in_past >= 0 and seconds_in_past < closest_seconds_in_past:
			closest_seconds_in_past = seconds_in_past
			closest_before = i
		elif closest_before == -1 and seconds_in_past < 0:
			# If no TOD has started yet today, track the latest TOD from yesterday
			var seconds_until_today = -seconds_in_past
			if seconds_until_today < closest_seconds_in_past:
				closest_seconds_in_past = seconds_until_today
				closest_before = i

	if closest_before != -1:
		return times_of_day[closest_before]
	elif num_tods > 0:
		return times_of_day[0]
	else:
		return null

## Using hours time, find the appropriate time of day that matches by
## enter time in the times_of_day array
func calculate_time_of_day_with_hours_time(p_hours_time: HoursTime) -> TimeOfDay:
	var current_seconds = p_hours_time.as_game_seconds(time_state.get_scale())
	var previous_tod: TimeOfDay = null

	for i in range(times_of_day.size()):
		var tod = times_of_day[i]
		if tod == null or not tod.validate():
			continue

		var enter_seconds = tod.enter_time.as_game_seconds(time_state.get_scale())

		if enter_seconds == current_seconds:
			return tod

		if enter_seconds < current_seconds:
			previous_tod = tod
			continue

		if i == 0 and previous_tod == null:
			return times_of_day.back()

		break

	return previous_tod

## Gets the last game DateTime when a valid TimeOfDay was entered
func get_last_enter_time(p_tod : TimeOfDay) -> DateTime:
	if not times_of_day.has(p_tod):
		push_error("Logic does not have %s so it has never occured. Use Times of Day set on the Day Night Cycle System." % p_tod)
		return DateTime.new()
	
	var current_dt : DateTime = time_state.date_time
	var already_occurred = p_tod.enter_time.is_after(current_dt.time)
	var last_enter : DateTime

	if already_occurred:
		var previous_date = time_state.calendar.get_previous_date(current_dt.date)
		last_enter = DateTime.new(previous_date, p_tod.enter_time)
	else:
		last_enter = DateTime.new(current_dt.date, p_tod.enter_time)

	return last_enter
