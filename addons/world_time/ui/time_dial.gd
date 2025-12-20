class_name TimeDial
extends Control
## Displays the current time of day by pointing to the current HoursTime

@export var time_state : TimeState : 
	set(value):
		if time_state != null:
			time_state.date_time_changed.disconnect(_on_date_time_changed)
			time_state.time_of_day_changed.disconnect(_on_time_of_day_changed)
			
		time_state = value
		
		if time_state != null:
			time_state.date_time_changed.connect(_on_date_time_changed)
			time_state.time_of_day_changed.connect(_on_time_of_day_changed)

## The degree which shows the end of the day
@export var day_degrees = 180.0

## The time that the dial starts moving from
@export var start = HoursTime.new(0,0,0)

## The time that the dial ends at. [br][br]
## You can make this more time than the actual duration of the day to have the end carry over to the next day.
@export var end = HoursTime.new(24,0,0)

## If the time is outside of the start and end range, clamp to the min and max time values for handle display
@export var clamp_to_range = true

## The handle texture control which rotates to point to the current hour
@export var handle : Control

var _start_degrees : float
var _shown_secs : float

func _ready():
	_start_degrees = handle.rotation_degrees
	update_handle(time_state.date_time)
	_shown_secs = end.as_game_seconds(time_state.calendar.time_scale) - start.as_game_seconds(time_state.calendar.time_scale)

func update_handle(p_dt : DateTime):
	var time_scale = time_state.get_scale()
	var seconds_per_day = time_scale.seconds_per_day
	var dial_seconds = p_dt.time.as_game_seconds(time_scale)
	var start_seconds = start.as_game_seconds(time_scale)
	
	if dial_seconds < start_seconds: # If the start time has not occured, add a day as if it were actually still progressing the previous day
		dial_seconds = dial_seconds + seconds_per_day
	
	var time_past_start = dial_seconds - start_seconds
	
	var ratio : float = time_past_start / _shown_secs
	
	if clamp_to_range:
		ratio = clamp(ratio, 0.0, 1.0)
	
	var degrees_offset = _start_degrees + (ratio * day_degrees)
	handle.rotation_degrees = degrees_offset

func _on_date_time_changed(p_new : DateTime, _p_old : DateTime):
	update_handle(p_new)	

func _on_time_of_day_changed(p_new : TimeOfDay, _p_old : TimeOfDay):
	tooltip_text = str(p_new)
