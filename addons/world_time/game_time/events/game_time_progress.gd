class_name GameTimeProgress
extends RefCounted
# Timed progress that updates with the game_seconds on the TimeStateLogic

signal finished()
signal updated(progress : float)

## Ratio towards being finished between 0.0 and 1.0
@export var progress : float :
	set(value):
		if progress == value:
			return
		
		progress = value
		updated.emit(progress)
		is_finished = progress >= 1.0

## Defaults to global, can be set to a custom value if you want it to
## run off of a different time system.
var time_state : TimeState :
	set(value):
		if time_state != null:
			time_state.time_elapsed.disconnect(_on_time_elapsed)
		
		time_state = value
		
		if time_state != null:
			time_state.time_elapsed.connect(_on_time_elapsed)
		
## When the expected amount of game time has occured, is_finished is true
var is_finished : bool :
	set(value):
		if value != is_finished:
			is_finished = value
			
			if is_finished && time_state != null && time_state.time_elapsed.is_connected(_on_time_elapsed):
				time_state.time_elapsed.disconnect(_on_time_elapsed)

			finished.emit()

## Start time in total game seconds
@export var start_seconds : float

## End time in total game seconds
@export var end_seconds : float

func _init(p_start_time_secs : float,
			p_end_time_secs : float,
			p_time_state : TimeState):
	start_seconds = p_start_time_secs
	end_seconds = p_end_time_secs
	time_state = p_time_state
	update_progress(time_state.game_seconds)

## Updates the progress by calculating the ratio of time elapsed to total duration in seconds
## and sets the progress property
## Returns the updated progress value
func update_progress(p_game_time : float) -> float:
	var time_after_start = p_game_time - start_seconds
	var duration = get_duration()
	progress = clampf(time_after_start / duration, 0.0, 1.0)
	
	return progress

func get_duration() -> float:
	return end_seconds - start_seconds

func _on_time_elapsed(_p_change : float, p_total : float):
	update_progress(p_total)
