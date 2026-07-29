class_name Action_Doctor
extends Action_Work

## Tending the patients in a medical bay (WI-44).
##
## Subclasses Action_Work for the workstation anchor animation, but the "work" is
## purely PRESENCE: the bay's own treatment rate multiplies up while a doctor is
## standing in it, so there is no counter to advance and nothing for the generic
## advance_work() adapter to do. The shift ends when the last patient leaves.

## Medical xp trickled per game-hour of tending. There is no single completion to
## reward here, unlike a built module or a finished batch.
@export var xp_per_hour: float = 10.0

func _init(target_slot: JobTarget.Slot = JobTarget.Slot.A) -> void:
	super(target_slot, false, 0.0)
	use_anchor_animation = true

func tick(job: Job, delta: float) -> Status:
	var medical: MedicalComponent = _medical(job)
	if medical == null or job.pawn == null:
		return Status.FAILED
	# Presence is the multiplier - set every tick so treatment_per_hour reads it
	# the moment a patient's own processing runs. Node order between them is not
	# guaranteed, which is exactly why this isn't set once on entry.
	medical.current_doctor = job.pawn
	job.pawn.grant_skill_xp(job.get_skill(), xp_per_hour * delta / TimeManager.SECONDS_PER_HOUR)
	return Status.ONGOING

## The shift is over when the last patient is discharged - or the power dies.
## Ending here is a SUCCESS, not a failure: the doctor did the job.
func check(job: Job) -> Status:
	var medical: MedicalComponent = _medical(job)
	if medical == null:
		return Status.FAILED
	return Status.ONGOING if medical.has_patients() and medical.powered() else Status.DONE

## Drop the operator link so a stale doctor isn't credited to a later treatment
## tick, then let the parent stop the workstation animation.
func on_finish(job: Job, outcome: Job.Outcome) -> void:
	var medical: MedicalComponent = _medical(job)
	if medical != null and medical.current_doctor == job.pawn:
		medical.current_doctor = null
	super(job, outcome)

func report(_job: Job) -> String:
	return "Treating patients"

func _medical(job: Job) -> MedicalComponent:
	var destination: JobTarget = job.target(slot)
	if destination == null or not destination.is_alive():
		return null
	return destination.component() as MedicalComponent
