class_name Job_Eat
extends JobBase

var pawn: PawnBase = null
var action: Action_PathToTarget = null

enum JobState { Start, GoToModule, Eat, Finished, Failed }
var job_state: JobState = JobState.Start

func can_do_job(_pawn: PawnBase) -> bool:
	var sus_components := _pawn.get_tree().get_nodes_in_group("sustenance_component")
	if sus_components.size() > 0:
		var test_action: Action_PathToTarget = Action_PathToTarget.new()
		test_action.initialize_action(_pawn, sus_components[0])
		var failed: bool = test_action.is_failed()
		test_action.free()
		return not failed
	return false

func start_job(_pawn: PawnBase) -> void:
	pawn = _pawn
	if job_state != JobState.Failed:
		job_state = JobState.Start

func process_job(delta: float) -> void:
	match job_state:
		JobState.Start:
			job_start()
			pass
		JobState.GoToModule:
			move_to_module(delta)
			pass
		JobState.Eat:
			eat()
			pass
		JobState.Finished:
			pass
		JobState.Failed:
			pass
			
func is_finished() -> bool:
	return job_state == JobState.Finished
	
func is_failed() -> bool:
	return job_state == JobState.Failed
	
func cancel(as_failed: bool) -> void:
	if as_failed:
		job_state = JobState.Failed
	else:
		job_state = JobState.Finished
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
		job_state = JobState.GoToModule
	
func move_to_module(delta: float) -> void:
	if action == null:
		cancel(true)
	action.process_action(delta)
	if action.is_failed():
		cancel(true)
	elif action.is_finished():
		job_state = JobState.Eat
		action.free()
		action = null

func eat() -> void:
	var sus_component: SustenanceComponent = pawn.current_module.get_component_by_type(SustenanceComponent) as SustenanceComponent
	if sus_component != null:
		if sus_component.consume_sustenance(10):
			(pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent).hunger_value += 10
		job_state = JobState.Finished
	else:
		cancel(true)
