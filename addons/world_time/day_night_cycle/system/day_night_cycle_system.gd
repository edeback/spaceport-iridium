class_name DayNightCycleSystem
extends Node
## Controls what time of the day the scene is in based
## on the passage of time

## The sequential times of day during a day of playtime.
## Auto sorts on load and unchangeable after game starts
@export var times_of_day : Array[TimeOfDay] :
	set(value):
		_logic.times_of_day = value
		_logic.times_of_day.sort_custom(TimeOfDay.sort_ascending_enter_time)
	get:
		return _logic.times_of_day

## Leave empty to default to TimeStateLogic.main
@export var time_state : TimeState :
	set(value):
		if time_state != null:
			time_state.date_time_changed.disconnect(_on_date_time_changed)
			time_state.state_loaded.disconnect(_on_state_loaded)

		time_state = value

		if time_state != null:
			time_state.date_time_changed.connect(_on_date_time_changed)
			time_state.state_loaded.connect(_on_state_loaded)
			
		_update_logic_time_state()
	get:
		return time_state

var _logic : DayNightCycleLogic

func _init(p_times_of_day : Array[TimeOfDay] = [], p_time_state : TimeState = null):
	_logic = DayNightCycleLogic.new(p_times_of_day, p_time_state)
	time_state = p_time_state

func _ready():
	if not validate():
		return
		
	if is_instance_valid(time_state):
		var start_tod = _logic.calculate_time_of_day(time_state.date_time)
		time_state.set_time_of_day(start_tod, _logic.get_previous_time_of_day(start_tod))

## Returns the time of day in the times_of_day array that comes just before the
## parameter p_tod
func get_previous_time_of_day(p_tod : TimeOfDay) -> TimeOfDay:
	return _logic.get_previous_time_of_day(p_tod)

## Get the time of day that starts on or after the current p_date_time
## that comes before the next one that hasn't started yet
func calculate_time_of_day(p_date_time : DateTime) -> TimeOfDay:
	return _logic.calculate_time_of_day(p_date_time)

## Using hours time, find the appropriate time of day that matches by
## enter time in the times_of_day array
func calculate_time_of_day_with_hours_time(p_hours_time : HoursTime) -> TimeOfDay:
	return _logic.calculate_time_of_day_with_hours_time(p_hours_time)

## Gets the last game DateTime when the time of day was entered
func get_last_enter_time(p_tod : TimeOfDay) -> DateTime:
	return _logic.get_last_enter_time(p_tod)

## Checks if the system is properly setup.
## Pushes any issues found as errors
##
## Returns false if there are any issues, true if validation passed
func validate() -> bool:
	var issues : Array[String] = []
	
	if not is_instance_valid(time_state):
		issues.append("Requires a valid TimeState to be set.")
	elif not is_instance_valid(time_state.calendar):
		issues.append("Requires a valid calendar to be set on the time state.")
	
	if times_of_day.is_empty():
		issues.append("No times of day set on DayNightCycleSystem " + str(get_path()))

	for issue in issues:
		push_error(issue)

	return issues.size() == 0

func _on_date_time_changed(new : DateTime, old : DateTime):
	if is_instance_valid(time_state):
		var new_tod = _logic.calculate_time_of_day(new)
		if time_state.time_of_day != new_tod:
			time_state.set_time_of_day(new_tod, _logic.get_previous_time_of_day(new_tod))

func _update_logic_time_state():
	_logic.time_state = time_state

## Recalculates the TimeOfDay after the TimeState loads it's stateful data
func _on_state_loaded():
	var new_tod = _logic.calculate_time_of_day(time_state.date_time)
	if time_state.time_of_day != new_tod:
			time_state.set_time_of_day(new_tod, _logic.get_previous_time_of_day(new_tod))
