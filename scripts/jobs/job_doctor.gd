class_name Job_Doctor
extends JobBase

## Manning a Medical Bay's workstation (WI-31). Posted by a MedicalComponent while
## patients occupy bunks and no doctor is engaged. The doctor walks to the
## WORKSTATION anchor (playing its authored animation) and, while present,
## multiplies every patient's treatment rate by their medical work-rate - the
## patients drive their own progress, the doctor's presence is the multiplier (see
## MedicalComponent.treatment_per_hour). Workspace-assignable per WI-23, like the
## manned processor. Medical xp trickles in while working (no discrete completion).

var pawn: PawnBase
var medical: MedicalComponent
## The module's PathComponent and the WORKSTATION anchor claimed on it. anchor may
## be null (module authored none) - the doctor then works at the module centre.
var _path_component: PathComponent = null
var anchor: AnchorDef = null

## Medical xp granted per game-hour worked (trickle, like mining).
var xp_per_hour: float = 6.0

var state: WorkState = WorkState.Starting:
	set(new_state):
		if new_state != state:
			state = new_state
			subtask_changed.emit()

enum WorkState { Starting, MovingToStation, Working, Finished, Failed }

func get_category() -> Category:
	return Category.WORK

func get_skill() -> StringName:
	return &"medical"

func get_job_description() -> String:
	if medical != null and is_instance_valid(medical.owner_module) and medical.owner_module.module_data != null:
		return "Treat patients in " + medical.owner_module.module_data.name
	return "Treat patients"

func get_subtask_description() -> String:
	match state:
		WorkState.MovingToStation:
			return "Walking to the ward"
		WorkState.Working:
			return "Treating patients"
	return ""

## Wires the job to its bay and adopts the module's workspace gate (WI-23), so only
## assignees can claim it and assignees get the affinity bump.
func setup(component: MedicalComponent) -> void:
	assert(component != null and component.owner_module != null)
	medical = component
	workspace = component.owner_module.get_component_by_type(WorkspaceComponent) as WorkspaceComponent
	SignalBus.module_removed.connect(_module_removed)

## Alive while there are patients to tend and the bay is powered.
func is_valid() -> bool:
	return is_instance_valid(medical) and is_instance_valid(medical.owner_module) \
		and medical.has_patients() and medical.powered()

func can_do_job(_pawn: PawnBase) -> bool:
	if not is_valid():
		return false
	# The sole doctor can't also be a patient here (WI-31 edge case).
	if medical.is_patient(_pawn):
		return false
	# Workspace gate (WI-23): assignees only when the module has an assignment.
	if workspace != null and not workspace.allows(_pawn):
		return false
	return Global.path_manager.is_reachable(_pawn, medical.owner_module)

func start_job(_pawn: PawnBase) -> void:
	pawn = _pawn
	_path_component = medical.owner_module.get_path_component()
	if _path_component != null:
		# WORKSTATION anchors aren't generated; null just means "work at centre".
		anchor = _path_component.claim_anchor(AnchorDef.AnchorType.WORKSTATION, self)
	_move_to_station()

func _move_to_station() -> void:
	state = WorkState.MovingToStation
	pawn.movement_component.movement_ended.connect(_arrived, CONNECT_ONE_SHOT)
	pawn.movement_component.move_to(medical.owner_module, 1.0, false, anchor)

func _arrived(success: bool) -> void:
	# _ended: a stale movement one-shot after an external cancel must not revive
	# the job.
	if _ended:
		return
	if not success or not is_valid():
		cancel(true)
		return
	state = WorkState.Working
	pawn.begin_anchor_animation(anchor)

func process_job(delta: float) -> void:
	if state != WorkState.Working:
		return
	if not is_valid():
		# All patients discharged (or power lost): the shift here is over. A module
		# removal instead routes through _module_removed -> Failed.
		state = WorkState.Finished
		return
	# Presence is the multiplier: set every tick so treatment_per_hour reads it the
	# moment a patient's process_job runs (node order between us isn't guaranteed).
	medical.current_doctor = pawn
	# Trickle medical xp while tending (no single completion to reward).
	pawn.grant_skill_xp(&"medical", xp_per_hour * delta / TimeManager.SECONDS_PER_HOUR)

func _module_removed(module: ModuleBase) -> void:
	if is_instance_valid(medical) and module == medical.owner_module:
		state = WorkState.Failed

func _on_cancel(as_failed: bool) -> void:
	if as_failed:
		state = WorkState.Failed
	else:
		state = WorkState.Finished

func _on_end() -> void:
	if SignalBus.module_removed.is_connected(_module_removed):
		SignalBus.module_removed.disconnect(_module_removed)
	# Release the workstation claim on EVERY end path (reservation discipline).
	if _path_component != null and is_instance_valid(_path_component):
		_path_component.release_anchor(self)
	# Tell the bay we're gone so it re-posts if patients still wait, and drop our
	# operator link so a stale doctor isn't credited to a later treatment tick.
	if is_instance_valid(medical):
		medical.notify_doctor_job_ended(self)
	# Stop the workstation animation.
	if pawn != null and is_instance_valid(pawn):
		pawn.end_anchor_animation()

func is_failed() -> bool:
	return state == WorkState.Failed

func is_finished() -> bool:
	return state == WorkState.Finished

# --- persistence (WI-21) ------------------------------------------------------

## Records the bay; a restart re-walks to the station and resumes tending. Dropped
## if we can't identify the module (never happens for a live job).
func get_save_data() -> Dictionary:
	if medical == null or not is_instance_valid(medical):
		return {}
	return {
		"type": "doctor",
		"medical": SaveManager.component_ref(medical),
	}

static func restore(data: Dictionary) -> JobBase:
	var component: MedicalComponent = SaveManager.resolve_component_ref(data.get("medical", {})) as MedicalComponent
	if component == null:
		return null
	var job := Job_Doctor.new()
	job.setup(component)
	# Claim the bay's outstanding-job slot immediately so its slow_tick doesn't post
	# a duplicate board job before this restored pawn runs it.
	component.adopt_doctor_job(job)
	return job
