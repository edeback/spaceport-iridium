class_name Action_Eat
extends ActionBase

## Take a meal from the sustenance pool in a slot (WI-44). Instant.
##
## Deliberately NOT an Action_RestoreNeed: eating is a single consumption whose
## SIZE and QUALITY are decided at the moment it happens, not a rate ticking a
## value upward while the pawn sits there. The quality read is why it has to be
## one atomic step - consume_sustenance() returns the amount and the quality of
## the portion together, captured before an emptied pool resets, and re-reading
## pool_quality afterwards would grade the meal against whatever came next.

## Portion size to ask for. Matches Job_Eat's desired_sustenance.
@export var slot: JobTarget.Slot = JobTarget.Slot.A
@export var desired: int = 70

func _init(target_slot: JobTarget.Slot = JobTarget.Slot.A, portion: int = 70) -> void:
	slot = target_slot
	desired = portion
	complete_mode = CompleteMode.INSTANT

func on_start(job: Job) -> Status:
	var sustenance: SustenanceComponent = _sustenance(job)
	if sustenance == null or job.pawn == null:
		return Status.FAILED
	# Re-validated rather than trusted: the walk took time and someone else may
	# have emptied the pool in the meantime.
	if sustenance.sustenance_available <= 0:
		return Status.FAILED
	var meal: Dictionary = sustenance.consume_sustenance(desired)
	var eaten: int = int(meal["amount"])
	var quality: float = float(meal["quality"])
	if eaten <= 0:
		return Status.FAILED
	var needs: PawnNeedsComponent = job.pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
	if needs != null:
		# Nourishment scales with quality (WI-29): a good meal fills hunger further
		# per unit eaten, a poor one less.
		var mult: float = FoodInstanceData.nourishment_mult(quality,
			sustenance.min_nourish_mult, sustenance.max_nourish_mult)
		needs.hunger_value += eaten * mult
		_apply_meal_mood(needs, sustenance, quality)
	# Visitors pay for the meal (WI-33); crew eat free. Charged AFTER serving, so
	# a paying guest always gets what they ate.
	sustenance.charge_meal(job.pawn)
	# Records that this step is done, so a save taken between the meal and the end
	# of the job does not serve a second one.
	job.count = eaten
	return Status.DONE

## Already eaten. Without this a job saved after the meal would consume a second
## portion on load - the same hazard Action_TakeFromStorage guards against.
func on_resume(job: Job) -> Status:
	return Status.DONE if job.count > 0 else on_start(job)

## Timed happiness nudge from the meal's quality band (WI-29). good_meal and
## bad_meal are mutually exclusive: the latest meal clears the other id so "last
## meal wins" (a good meal after a bad one lifts you, not both at once); a neutral
## meal clears both.
func _apply_meal_mood(needs: PawnNeedsComponent, sustenance: SustenanceComponent,
		quality: float) -> void:
	var band: int = FoodInstanceData.meal_mood_band(quality,
		sustenance.bad_meal_band, sustenance.good_meal_band)
	if band > 0:
		needs.remove_modifier(&"bad_meal")
		needs.add_modifier(&"good_meal", sustenance.good_meal_mood,
			sustenance.meal_mood_duration_hours)
	elif band < 0:
		needs.remove_modifier(&"good_meal")
		needs.add_modifier(&"bad_meal", sustenance.bad_meal_mood,
			sustenance.meal_mood_duration_hours)
	else:
		needs.remove_modifier(&"good_meal")
		needs.remove_modifier(&"bad_meal")

func report(_job: Job) -> String:
	return "Eating"

func _sustenance(job: Job) -> SustenanceComponent:
	var slot_target: JobTarget = job.target(slot)
	if slot_target == null or not slot_target.is_alive():
		return null
	return slot_target.component() as SustenanceComponent
