class_name ActionProgress
extends Control
## UI for showing and updating the progress_bar of an action
## works through game time instead of regular time so
## all updates are multiplied by the game speed

## Emit when the gather has finished the timer duration successfully
signal finished()

## How often to update progress_bar visuals. If 0, it will update on every process frame
@export_range(0.0, 1.0, 0.001, "or_greater") var update_frequency : float = 0.0

@export var progress_bar : ProgressBar

var finish_time : float
var progress_time : float = 0.0
var time_since_update : float = 0.0
		
func _process(delta: float) -> void:
	var game_delta = delta
	time_since_update += game_delta
	progress_time += game_delta
	
	if time_since_update >= update_frequency:
		update()
		
	if is_finished():
		finished.emit()
		progress_time = 0.0

## Starts the progress_bar timer with the p_duration time measured in game time seconds until completion
func start(p_duration : float):
	progress_time = 0.0
	finish_time = p_duration
	progress_bar.max_value = finish_time
	progress_bar.value = progress_time
	process_mode = PROCESS_MODE_INHERIT

func pause():
	process_mode = PROCESS_MODE_DISABLED
	
func cancel():
	queue_free()
	process_mode = PROCESS_MODE_DISABLED
	
func update():
	progress_bar.value = progress_time
	time_since_update = 0
	
func is_finished():
	return progress_time >= finish_time
