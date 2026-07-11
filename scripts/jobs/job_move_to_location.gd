class_name Job_MoveToLocation
extends JobBase

var pawn: PawnBase
var destination_module: ModuleBase
var state: JobState = JobState.Starting

func get_job_description() -> String:
	return "Moving to location"

func get_subtask_description() -> String:
	return ""
	
func is_valid() -> bool:
	return destination_module != null
	
func can_do_job(_pawn: PawnBase) -> bool:
	if destination_module:
		return Global.path_manager.is_reachable(_pawn, destination_module)
	return false
	
func start_job(_pawn: PawnBase) -> void:
	pawn = _pawn
	if destination_module != null:
		move_to_module()
	else:
		complete(false)
		
func end_job() -> void:
	super()
		
func complete(as_success: bool) -> void:
	if as_success:
		state = JobState.Finished
	else:
		state = JobState.Failed
	

func move_to_module() -> void:
	state = JobState.Moving
	pawn.movement_component.movement_ended.connect(complete, CONNECT_ONE_SHOT)
	pawn.movement_component.move_to(destination_module)
	
	
func is_failed() -> bool:
	return state == JobState.Failed
	
func is_finished() -> bool:
	return state == JobState.Finished
