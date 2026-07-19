class_name Job_MoveToLocation
extends JobBase

var pawn: PawnBase
var destination_module: ModuleBase
var state: JobState = JobState.Starting

func get_category() -> Category:
	return Category.MOVE

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
		cancel(true)
		
func complete(as_success: bool) -> void:
	cancel(!as_success)

func _on_cancel(as_failed: bool) -> void:
	if as_failed:
		state = JobState.Failed
	else:
		state = JobState.Finished

func move_to_module() -> void:
	state = JobState.Moving
	pawn.movement_component.movement_ended.connect(complete, CONNECT_ONE_SHOT)
	pawn.movement_component.move_to(destination_module)
	
	
func is_failed() -> bool:
	return state == JobState.Failed

func is_finished() -> bool:
	return state == JobState.Finished

# --- persistence (WI-21) ------------------------------------------------------

## Just the destination module. Restore rebuilds a fresh job that re-paths from
## wherever the pawn loaded (WI-20 CONVEYED contract: a pawn saved mid-ride is
## recorded at a floor, so re-pathing starts from there).
func get_save_data() -> Dictionary:
	if not is_instance_valid(destination_module):
		return {}
	return {
		"type": "move_to_location",
		"destination": SaveManager.module_ref(destination_module),
	}

static func restore(data: Dictionary) -> JobBase:
	var destination: ModuleBase = SaveManager.resolve_module_ref(data.get("destination", {}))
	if destination == null:
		return null
	var job := Job_MoveToLocation.new()
	job.destination_module = destination
	return job
