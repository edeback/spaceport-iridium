class_name MedicalComponent
extends ComponentBase

## The Medical Bay's business end (WI-31): treatment slots where sick/injured crew
## lie down to heal, plus a doctor's workstation. A patient's Job_GetTreatment
## claims a slot (a BUNK anchor), lies down, and drives its own disease treatment
## and HP regen forward each tick; a doctor's Job_Doctor mans the workstation and,
## while present, multiplies the treatment rate by their medical work-rate.
## Untended patients still treat at a slow auto-med baseline, so a solo-crew
## station still recovers - just slowly.
##
## Slot discipline mirrors SleepComponent/RobotRepairComponent (claim up front,
## release in the job's _on_end, rebuilt empty on load). Doctor-job posting mirrors
## ProcessorComponent (one outstanding job, re-posted on slow_tick while patients
## wait); an unclaimed doctor job simply goes unworked when no eligible pawn exists.

@export var power_consumption_component: PowerConsumptionComponent
## Treatment bunks (match the BUNK anchor count authored in the scene).
@export var capacity: int = 2
## Auto-med treatment progress-hours per game-hour with no doctor present.
@export var baseline_treat_per_hour: float = 1.0
## Extra treatment progress-hours a doctor adds, scaled by their medical work-rate
## (happiness x skill, floored). A skilled doctor makes treatment several times
## faster than the untended baseline.
@export var doctor_treat_bonus_per_hour: float = 4.0
## Health points restored per game-hour to a patient in a bunk (auto-med). Applied
## directly by the treatment job, so it heals even while a disease drains.
@export var heal_per_hour: float = 12.0

## The doctor currently manning the workstation (set by Job_Doctor each working
## tick, cleared when it ends), or null when untended.
var current_doctor: PawnBase = null

var _claims: Array[JobBase] = []
## The outstanding Job_Doctor, so slow_tick doesn't post a duplicate.
var _doctor_job: Job_Doctor = null

func ready_constructed() -> void:
	add_to_group(Groups.MEDICAL_BAY)
	# Doctor-job posting rides slow_tick (rare, coarse) - a patient occupying a bunk
	# is a slow-changing condition, no need for a per-frame poll.
	Global.time_manager.slow_tick.connect(_on_slow_tick)

func powered() -> bool:
	return power_consumption_component == null or power_consumption_component.powered

## Claimable right now: powered and with a free bunk.
func is_available() -> bool:
	return powered() and has_free_slot()

func has_free_slot() -> bool:
	return _claims.size() < capacity

func claim_slot(job: JobBase) -> bool:
	if not has_free_slot() or _claims.has(job):
		return false
	_claims.append(job)
	return true

func release_slot(job: JobBase) -> void:
	_claims.erase(job)

func has_patients() -> bool:
	return not _claims.is_empty()

## Is `pawn` currently occupying a treatment bunk here? Job_Doctor consults this so
## the sole doctor can't also be one of the patients (WI-31 edge case).
func is_patient(pawn: PawnBase) -> bool:
	for job: JobBase in _claims:
		var treatment: Job_GetTreatment = job as Job_GetTreatment
		if treatment != null and treatment.pawn == pawn:
			return true
	return false

## Treatment progress-hours per game-hour right now: 0 unpowered, else the auto-med
## baseline plus a present doctor's skill-scaled bonus.
func treatment_per_hour() -> float:
	if not powered():
		return 0.0
	var rate: float = baseline_treat_per_hour
	if current_doctor != null and is_instance_valid(current_doctor):
		rate += doctor_treat_bonus_per_hour * current_doctor.work_rate(&"medical")
	return rate

## HP restored per game-hour to a docked patient; 0 unpowered.
func heal_rate_per_hour() -> float:
	return heal_per_hour if powered() else 0.0

# --- doctor job posting (mirrors ProcessorComponent) --------------------------

func _on_slow_tick(_interval: float) -> void:
	if not has_patients() or not powered():
		return
	if _doctor_job != null and not _doctor_job.is_ended():
		return
	if Global.job_manager == null:
		return
	_doctor_job = Job_Doctor.new()
	_doctor_job.setup(self)
	Global.job_manager.add_job(_doctor_job)

## Called by Job_Doctor when it ends: drop the outstanding-job slot and clear our
## operator link (if it was this doctor) so the slow-tick poll re-posts while
## patients still wait.
func notify_doctor_job_ended(job: Job_Doctor) -> void:
	if _doctor_job == job:
		_doctor_job = null
	if current_doctor != null and job.pawn == current_doctor:
		current_doctor = null

## Claim the outstanding-doctor-job slot for a restored job (WI-21), so slow_tick
## doesn't post a duplicate before the loaded pawn runs it.
func adopt_doctor_job(job: Job_Doctor) -> void:
	_doctor_job = job
