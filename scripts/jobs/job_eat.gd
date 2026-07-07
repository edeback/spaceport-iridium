class_name Job_Eat
extends JobBase

var pawn: PawnBase = null
var job_state: JobBase.JobState = JobBase.JobState.Starting

func can_do_job(_pawn: PawnBase) -> bool:
	var sus_components := _pawn.get_tree().get_nodes_in_group("sustenance_component")
	if sus_components.size() > 0:
		return Global.path_manager.is_reachable(_pawn, sus_components[0])
	return false

func start_job(_pawn: PawnBase) -> void:
	pawn = _pawn
	job_start()

			
func is_finished() -> bool:
	return job_state == JobBase.JobState.Finished
	
func is_failed() -> bool:
	return job_state == JobBase.JobState.Failed
	
func cancel(as_failed: bool) -> void:
	if as_failed:
		job_state = JobBase.JobState.Failed
	else:
		job_state = JobBase.JobState.Finished
		
func job_start() -> void:
	var sus_components := pawn.get_tree().get_nodes_in_group("sustenance_component")
	if sus_components.size() > 0:
		move_to_module(sus_components[0])
	
func move_to_module(module: ModuleBase) -> void:
	job_state = JobBase.JobState.Moving
	pawn.movement_component.movement_ended.connect(eat, CONNECT_ONE_SHOT)
	pawn.movement_component.move_to(module)

func eat(prev_success: bool) -> void:
	if not prev_success:
		cancel(true)
		return
	var sus_component: SustenanceComponent = pawn.current_module.get_component_by_type(SustenanceComponent) as SustenanceComponent
	if sus_component != null:
		if sus_component.consume_sustenance(10):
			(pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent).hunger_value += 10
		job_state = JobBase.JobState.Finished
	else:
		cancel(true)
