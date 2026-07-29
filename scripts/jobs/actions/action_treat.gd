class_name Action_Treat
extends ActionBase

## Lie in a medical bunk and get better (WI-44).
##
## Two channels at once, which is why this is not an Action_RestoreNeed: HP
## regenerates AND treatment progress accrues on the worst active disease. The
## job is done only when both are settled - nothing left to treat and health
## topped up.
##
## HP is applied directly rather than through the health component's passive
## regen, because a disease suppresses that regen (the WI-31 medical-bay
## override) and a patient in a bay is exactly the case that has to heal anyway.
## Treatment progress lives on the disease state, so an interrupted session
## resumes where it left off and this action needs no saved state of its own.

@export var slot: JobTarget.Slot = JobTarget.Slot.A

func _init(bay_slot: JobTarget.Slot = JobTarget.Slot.A) -> void:
	slot = bay_slot
	complete_mode = CompleteMode.CONDITION
	# Held for the whole session and restored by the runner on any exit, which is
	# what stands a patient back up however the job ended.
	animation = &"lay_down"

func tick(job: Job, delta: float) -> Status:
	var medical: MedicalComponent = _medical(job)
	if medical == null or job.pawn == null:
		return Status.FAILED
	if not medical.powered():
		# Power died mid-treatment. Leave gracefully rather than failing - the
		# disease component's retry throttle finds another bay next attempt.
		job.end(Job.Outcome.INTERRUPTED)
		return Status.ONGOING
	# delta arrives already sim-scaled from the runner.
	var sim_hours: float = delta / TimeManager.SECONDS_PER_HOUR
	var health: PawnHealthComponent = _health(job)
	if health != null:
		health.health_value += medical.heal_rate_per_hour() * sim_hours
	var disease: PawnDiseaseComponent = _disease(job)
	# Worst-first, one at a time - apply_treatment picks which.
	if disease != null and disease.has_active_disease():
		disease.apply_treatment(medical.treatment_per_hour() * sim_hours)
	return Status.ONGOING

func check(job: Job) -> Status:
	var disease: PawnDiseaseComponent = _disease(job)
	if disease != null and disease.has_active_disease():
		return Status.ONGOING
	var health: PawnHealthComponent = _health(job)
	if health != null and health.health_value < health.health_max:
		return Status.ONGOING
	return Status.DONE

func report(_job: Job) -> String:
	return "Under treatment"

func _medical(job: Job) -> MedicalComponent:
	var slot_target: JobTarget = job.target(slot)
	if slot_target == null or not slot_target.is_alive():
		return null
	return slot_target.component() as MedicalComponent

func _health(job: Job) -> PawnHealthComponent:
	if job.pawn == null:
		return null
	return job.pawn.get_component_by_type(PawnHealthComponent) as PawnHealthComponent

func _disease(job: Job) -> PawnDiseaseComponent:
	if job.pawn == null:
		return null
	return job.pawn.get_component_by_type(PawnDiseaseComponent) as PawnDiseaseComponent
