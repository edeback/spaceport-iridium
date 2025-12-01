class_name JobBase
extends Resource

@export var name: String = ""
@export var description: String = ""
var priority: int = 0

signal job_end

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
