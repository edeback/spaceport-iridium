class_name TimeOfDay
extends Resource
## Marks a period of a day by an enter time

## Text representation of the time of day in game
@export var display_name : StringName = ""

## The time when the time of day period starts
@export var enter_time : HoursTime

## The length of time it takes for a time of day to be considered fully entered
## after the enter_time occurs
@export var transition_duration : GameTimeDuration

## Color that represents the time of day in the game
@export var color : Color = Color.DARK_SLATE_BLUE

func _init(p_display_name = "Unnamed Time of Day",
	p_enter_time = HoursTime.new(), 
	p_transition_duration = GameTimeDuration.new(), 
		p_color = Color.DARK_SLATE_BLUE):
		display_name = p_display_name
		enter_time = p_enter_time
		transition_duration = p_transition_duration
		color = p_color

## Creates a transition progress for entering the time of day based off of the current date_time
## [br][br]
## TimeStateLogic DateTime must be current for this to create properly
func create_transition_progress(p_time_state : TimeState) -> GameTimeProgress:
	var last_occurance_date_time = p_time_state.calendar.get_last_hours_time_as_date_time(enter_time, p_time_state.date_time)
	var start_seconds = p_time_state.calendar.get_seconds_from_date_time(last_occurance_date_time)
	var end_seconds = start_seconds + transition_duration.as_game_seconds(p_time_state.calendar.time_scale)
	var transition_progress = GameTimeProgress.new(start_seconds, end_seconds, p_time_state)
	return transition_progress

## Sorts two time of days based on their enter times, handling for null cases
static func sort_ascending_enter_time(time_of_day_1: TimeOfDay, time_of_day_2: TimeOfDay) -> bool:
	var t1 = time_of_day_1.enter_time
	var t2 = time_of_day_2.enter_time

	# Treat nulls as greater (they go to the end of the sorted list)
	if t1 == null and t2 == null:
		return false # stable sort: preserve original order
	if t1 == null:
		return false
	if t2 == null:
		return true

	return t2.is_after(t1)

func validate() -> bool:
	var no_problems = true
	
	if enter_time == null:
		push_error("Null enter time in %s. Be sure to set the enter_time before using the resource." % resource_path)
		no_problems = false
		
	if transition_duration == null:
		push_error("Null transition duration in %s. Be sure to set the transition duration before using the resource." % resource_path)
		no_problems = false
	
	return no_problems

## Represent object as display_name
func _to_string() -> String:
	return display_name
