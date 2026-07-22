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
		# can_serve gates visitors behind the crew-priority reserve (WI-33); crew
		# are served whenever there's any food.
		if (component as SustenanceComponent).can_serve(_pawn) and Global.path_manager.is_reachable(_pawn, (component as SustenanceComponent).owner_module):
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
		if sustenance == null or not sustenance.can_serve(pawn) or not Global.path_manager.is_reachable(pawn, sustenance.owner_module):
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
		# consume_sustenance returns the amount AND the quality of the portion eaten
		# (captured before any empty-pool reset), so we don't re-read pool_quality.
		var meal: Dictionary = target_component.consume_sustenance(desired_sustenance)
		var amount_consumed: int = int(meal["amount"])
		var meal_quality: float = float(meal["quality"])
		var needs: PawnNeedsComponent = pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
		if needs != null:
			# Nourishment scales with quality (WI-29): a good meal fills hunger
			# further per unit eaten, a poor one less.
			var mult: float = FoodInstanceData.nourishment_mult(meal_quality, target_component.min_nourish_mult, target_component.max_nourish_mult)
			needs.hunger_value += amount_consumed * mult
			_apply_meal_mood(needs, meal_quality)
		# Visitors pay for the meal (WI-33); crew eat free (no-op). Booked income
		# "dining". Charged after serving so a paid guest always gets what they ate.
		target_component.charge_meal(pawn)
		job_state = JobBase.JobState.Finished
	else:
		cancel(true)

## Timed happiness nudge from the meal's quality band (WI-29). good_meal and
## bad_meal are mutually exclusive: the latest meal clears the other id so "last
## meal wins" (a good meal after a bad one lifts you, not both at once); a
## neutral meal clears both.
func _apply_meal_mood(needs: PawnNeedsComponent, meal_quality: float) -> void:
	var band: int = FoodInstanceData.meal_mood_band(meal_quality, target_component.bad_meal_band, target_component.good_meal_band)
	if band > 0:
		needs.remove_modifier(&"bad_meal")
		needs.add_modifier(&"good_meal", target_component.good_meal_mood, target_component.meal_mood_duration_hours)
	elif band < 0:
		needs.remove_modifier(&"good_meal")
		needs.add_modifier(&"bad_meal", target_component.bad_meal_mood, target_component.meal_mood_duration_hours)
	else:
		needs.remove_modifier(&"good_meal")
		needs.remove_modifier(&"bad_meal")

# --- persistence (WI-21) ------------------------------------------------------

## No target ref: start_job() re-picks the best reachable sustenance on load
## (find_best_sustenance), so the provider is re-derived, not stored. SaveManager
## re-links the restored job to the hunger need via adopt_restored_need_job so
## the decay loop doesn't queue a duplicate.
func get_save_data() -> Dictionary:
	return {"type": "eat"}

static func restore(_data: Dictionary) -> JobBase:
	return Job_Eat.new()
