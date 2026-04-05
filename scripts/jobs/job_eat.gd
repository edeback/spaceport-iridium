class_name Job_Eat
extends JobBase

var pawn: PawnBase = null
var action: Action_PathToTarget = null
var job_state: JobBase.JobState = JobBase.JobState.Starting

func can_do_job(_pawn: PawnBase) -> bool:
	var sus_components := _pawn.get_tree().get_nodes_in_group("sustenance_component")
	if sus_components.size() > 0:
		return Global.path_manager.is_reachable(_pawn, sus_components[0])
	return false

func start_job(_pawn: PawnBase) -> void:
	pawn = _pawn
	if job_state != JobState.Failed:
		job_state = JobState.Starting

func process_job(delta: float) -> void:
	match job_state:
		JobBase.JobState.Starting:
			job_start()
			pass
		JobBase.JobState.Moving:
			move_to_module(delta)
			pass
		JobBase.JobState.Working:
			eat()
			pass
		JobBase.JobState.Finished:
			pass
		JobBase.JobState.Failed:
			pass
			
func is_finished() -> bool:
	return job_state == JobBase.JobState.Finished
	
func is_failed() -> bool:
	return job_state == JobBase.JobState.Failed
	
func cancel(as_failed: bool) -> void:
	if as_failed:
		job_state = JobBase.JobState.Failed
	else:
		job_state = JobBase.JobState.Finished
	if action != null:
		action.free()
		action = null
		
func job_start() -> void:
	var sus_components := pawn.get_tree().get_nodes_in_group("sustenance_component")
	if sus_components.size() > 0:
		action = Action_PathToTarget.new()
		action.initialize_action(pawn, sus_components[0])
	if action.is_failed():
		cancel(true)
	else:
		job_state = JobBase.JobState.Moving
	
func move_to_module(delta: float) -> void:
	if action == null:
		cancel(true)
	action.process_action(delta)
	if action.is_failed():
		cancel(true)
	elif action.is_finished():
		job_state = JobBase.JobState.Working
		action.free()
		action = null

func eat() -> void:
	var sus_component: SustenanceComponent = pawn.current_module.get_component_by_type(SustenanceComponent) as SustenanceComponent
	if sus_component != null:
		if sus_component.consume_sustenance(10):
			(pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent).hunger_value += 10
		job_state = JobBase.JobState.Finished
	else:
		cancel(true)
