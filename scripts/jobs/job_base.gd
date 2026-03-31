class_name JobBase
extends Resource

@export var name: String = ""
@export var description: String = ""
var priority: int = 0
var repeat_after_finish: bool = false

enum JobState { Starting, Moving, Working, Finished, Failed }

signal subtask_changed

signal job_end

func get_job_description() -> String:
	return ""

func get_subtask_description() -> String:
	return ""

func is_valid() -> bool:
	return true

func can_do_job(_pawn: PawnBase) -> bool:
	return true

func start_job(_pawn: PawnBase) -> void:
	pass

func process_job(_delta: float) -> void:
	# Override by subclasses
	pass
	
func is_failed() -> bool:
	# Override by subclasses
	return false
	
func is_finished() -> bool:
	# Override by subclasses
	return false

func cancel(_as_failed: bool) -> void:
	# Override by subclasses
	pass
	
func end_job() -> void:
	job_end.emit()
