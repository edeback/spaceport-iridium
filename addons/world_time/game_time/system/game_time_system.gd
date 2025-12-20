class_name GameTimeSystem
extends Node
##  Tracks the time and date as real world time progresses by converting
## it to game time changes and then emitting signals on the TimeStateLogic

## Changes the day to the next day when the time reaches the end of the current day
@export var auto_change_day = true

## Automatically progresses game time as real world time passes
@export var auto_increment_time = true

## Makes the time state the main global time state on load.
## It becomes the automatic fallback for all other TimeStateLogic requiring scripts
@export var set_time_state_as_main = true

## The calendar that the TimeState will use after
## the system initializes the TimeState.
@export var calendar : GameCalendar

## If unset, will default to global on load
@export var time_state : TimeState

var _logic : GameTimeSystemLogic

func _init(p_time_state : TimeState = null) -> void:
	if p_time_state != null:
		time_state = p_time_state
		calendar = time_state.calendar

func _ready():
	time_state.initialize(calendar)
	var starting_seconds = time_state.calendar.get_seconds_from_date_time(time_state.date_time)
	_logic = GameTimeSystemLogic.new(time_state)

func _process(delta : float):
	if auto_increment_time:
		var game_delta : float = delta * time_state.get_scale().delta_multiplier
		progress_time(game_delta)

## Moves the game time a number of seconds forward. 
## Returns the new total game time in seconds.
func progress_time(p_seconds : float) -> float:
	return _logic.progress_time(p_seconds)

## Increments the date by one. Optionally set an HoursTime value for the next DateTime.
func go_to_next_day(p_desired_time : HoursTime = null) -> void:
	_logic.go_to_next_day(p_desired_time)
