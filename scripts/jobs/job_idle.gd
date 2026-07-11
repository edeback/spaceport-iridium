class_name Job_Idle
extends JobBase

var pawn: PawnBase
var state: JobState = JobState.Starting
var duration: float = 5.0

func get_job_description() -> String:
	return "Idling"

func get_subtask_description() -> String:
	return ""
	
func is_valid() -> bool:
	return true
	
func can_do_job(_pawn: PawnBase) -> bool:
	return true
	
func start_job(_pawn: PawnBase) -> void:
	pawn = _pawn
	if pawn.animated_sprite != null:
		pawn.animated_sprite.play("idle")
	await pawn.get_tree().create_timer(duration, false).timeout
	cancel(false)
		
func cancel(_as_failed: bool) -> void:
	if _as_failed:
		state = JobState.Failed
	else:
		state = JobState.Finished
	
	
func is_failed() -> bool:
	return state == JobState.Failed
	
func is_finished() -> bool:
	return state == JobState.Finished
