class_name Job_Eat
extends JobBase

var pawn: PawnBase = null
var job_state: JobState = JobState.Starting
var desired_sustenance: int = 70
var target_component: SustenanceComponent = null

func get_category() -> Category:
	return Category.NEEDS

func get_job_description() -> String:
	return "Finding something to eat"

func get_subtask_description() -> String:
	match job_state:
		JobState.Moving:
			return "Moving to place with food"
		JobState.Working:
			return "Eating"
	return ""

func can_do_job(_pawn: PawnBase) -> bool:
	var sus_components := _pawn.get_tree().get_nodes_in_group("sustenance_component")
	for component in sus_components:
		if Global.path_manager.is_reachable(_pawn, (component as SustenanceComponent).owner_module) and (component as SustenanceComponent).sustenance_available > 0:
			return true
	return false

func start_job(_pawn: PawnBase) -> void:
	pawn = _pawn
	job_start()

			
func is_finished() -> bool:
	return job_state == JobBase.JobState.Finished
	
func is_failed() -> bool:
	return job_state == JobBase.JobState.Failed
	
func _on_cancel(as_failed: bool) -> void:
	if as_failed:
		job_state = JobBase.JobState.Failed
	else:
		job_state = JobBase.JobState.Finished
		
func job_start() -> void:
	target_component = find_best_sustenance()
	if target_component == null:
		cancel(true)
		return
	move_to_module(target_component.owner_module)
	
func find_best_sustenance() -> SustenanceComponent:
	var best_full: SustenanceComponent = null
	var best_full_dist: int = -1
	var best_partial: SustenanceComponent = null
	var best_partial_amount: float = -1
	var best_partial_dist: int = 0
	for node in pawn.get_tree().get_nodes_in_group("sustenance_component"):
		var sustenance: SustenanceComponent = node as SustenanceComponent
		if sustenance == null or sustenance.sustenance_available <= 0 or not Global.path_manager.is_reachable(pawn, sustenance.owner_module):
			continue
		var dist: int = sustenance.owner_module.module_cell.distance_squared_to(Global.world_to_cell(pawn.global_position))
		if sustenance.sustenance_available >= desired_sustenance:
			if best_full == null or dist < best_full_dist:
				best_full = sustenance
				best_full_dist = dist
		elif sustenance.sustenance_available > best_partial_amount or (sustenance.sustenance_available == best_partial_amount and (best_partial == null or dist < best_partial_dist)):
			best_partial = sustenance
			best_partial_amount = sustenance.sustenance_available
			best_partial_dist = dist
	return best_full if best_full != null else best_partial
	
func move_to_module(module: ModuleBase) -> void:
	job_state = JobBase.JobState.Moving
	pawn.movement_component.movement_ended.connect(eat, CONNECT_ONE_SHOT)
	pawn.movement_component.move_to(module)

func eat(prev_success: bool) -> void:
	# _ended: a stale movement one-shot firing after an external cancel must
	# not consume sustenance or overwrite the terminal state on a dead job.
	if not prev_success or _ended:
		cancel(true)
		return
	# Eat from the component we chose and walked to, not whatever module we
	# happen to be standing in - re-validated since the walk took time.
	if is_instance_valid(target_component) and target_component.sustenance_available > 0:
		var amount_consumed: int = target_component.consume_sustenance(desired_sustenance)
		(pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent).hunger_value += amount_consumed
		job_state = JobBase.JobState.Finished
	else:
		cancel(true)
