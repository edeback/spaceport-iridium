class_name Job_IdleWander
extends JobBase

var pawn: PawnBase
var destination_module: ModuleBase
var action: Action_PathToTarget = null
var state: JobBase.JobState = JobBase.JobState.Starting

func get_job_description() -> String:
	return "Wandering idly"

func get_subtask_description() -> String:
	return ""
	
func is_valid() -> bool:
	return true
	
func can_do_job(_pawn: PawnBase) -> bool:
	if _pawn.current_module:
		return _pawn.current_module.get_path_component().module_connections.size() > 0
	else:
		var airlocks: Array[Node] = _pawn.get_tree().get_nodes_in_group("airlock")
		return airlocks.size() > 0
	
func start_job(_pawn: PawnBase) -> void:
	pawn = _pawn
	var destination: ModuleBase = null
	if _pawn.current_module:
		var connections: Array[Node2D] = _pawn.current_module.get_path_component().module_connections.keys()
		connections.shuffle()
		for node in connections:
			if node is ModuleBase and node is not ModuleTurbolift:
				destination = node as ModuleBase
				break
	else:
		var airlocks: Array[Node] = _pawn.get_tree().get_nodes_in_group("airlock")
		var distance: float = -1
		for node in airlocks:
			if node is ModuleBase:
				var dist_sq: float = node.global_position.distance_squared_to(_pawn.global_position)
				if distance < 0 or dist_sq < distance:
					distance = dist_sq
					destination = node as ModuleBase
	if destination != null:
		destination_module = destination
		SignalBus.module_removed.connect(_module_removed)
		
func end_job() -> void:
	super()
	SignalBus.module_removed.disconnect(_module_removed)
		
func cancel(_as_failed: bool) -> void:
	if _as_failed:
		state = JobBase.JobState.Failed
	else:
		state = JobBase.JobState.Finished
	if action:
		action.cancel()
		action = null
	
func process_job(delta: float) -> void:
	match state:
		JobBase.JobState.Starting:
			state = JobBase.JobState.Working
		JobBase.JobState.Working:
			move_to_module(delta)
		JobBase.JobState.Finished:
			pass
		JobBase.JobState.Failed:
			pass
			
func _module_removed(module: ModuleBase) -> void:
	if module == destination_module:
		destination_module = null
		state = JobBase.JobState.Failed
		if action != null:
			action.free()
			action = null

func move_to_module(delta: float) -> void:
	if action == null:
		action = Action_PathToTarget.new()
		action.initialize_action(pawn, destination_module, 0.4)
	action.process_action(delta)
	if action.is_failed():
		state = JobBase.JobState.Failed
		action.free()
		action = null
	elif action.is_finished():
		state = JobBase.JobState.Finished
		action.free()
		action = null
	
	
func is_failed() -> bool:
	return state == JobBase.JobState.Failed
	
func is_finished() -> bool:
	return state == JobBase.JobState.Finished
