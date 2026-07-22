class_name Job_LeaveStation
extends JobBase

## Terminal job for resigned crew (WI-07): walk to the nearest reachable
## docking bay and despawn there. No reachable bay - or the walk failing
## mid-route - means the escape pod: despawn in place after a short wait.
## Every path ends in despawn; carried resources dump to a pile via the
## pawn's PREDELETE handler, so nothing is lost.

var pawn: PawnBase
var bay_component: CrewRecruitmentComponent
## Sim-hours to wait for the "escape pod" when no bay is reachable.
@export var escape_pod_wait_hours: float = 1.0
## Crew get an escape pod when no bay is reachable; visitors (WI-33) do NOT - a
## guest needs a real exit, so with this false the job fails instead of despawning
## in place, and the visitor stays (stranded, alerted) until an exit is rebuilt.
@export var allow_escape_pod: bool = true
var _waited_hours: float = 0.0

enum LeaveState { Starting, Walking, WaitingForPod, Finished, Failed }
var state: LeaveState = LeaveState.Starting:
	set(new_state):
		if new_state != state:
			state = new_state
			subtask_changed.emit()

func get_category() -> Category:
	return Category.MOVE

func get_job_description() -> String:
	return "Leaving the station"

func get_subtask_description() -> String:
	match state:
		LeaveState.Walking:
			return "Heading to the docking bay"
		LeaveState.WaitingForPod:
			return "Waiting for an escape pod"
	return ""
	
func player_cancelable() -> bool:
	return false

func start_job(_pawn: PawnBase) -> void:
	pawn = _pawn
	bay_component = _find_bay(pawn)
	if bay_component == null:
		if allow_escape_pod:
			state = LeaveState.WaitingForPod
		else:
			# No exit and no escape pod (a visitor): fail so the pawn returns to
			# normal behavior and re-tries leaving later once an exit exists.
			cancel(true)
		return
	state = LeaveState.Walking
	pawn.movement_component.movement_ended.connect(_arrived, CONNECT_ONE_SHOT)
	pawn.movement_component.move_to(bay_component.owner_module)

func _arrived(prev_success: bool) -> void:
	# _ended: a stale movement one-shot firing after an external cancel must
	# not overwrite the terminal state (WI-04 lifecycle rule).
	if _ended:
		return
	if not prev_success:
		# Path broke mid-walk - take the pod from where they stand (crew), or fail
		# so a visitor re-tries for a real exit (WI-33).
		if allow_escape_pod:
			state = LeaveState.WaitingForPod
		else:
			cancel(true)
		return
	_depart()

func process_job(delta: float) -> void:
	if state != LeaveState.WaitingForPod:
		return
	_waited_hours += delta / TimeManager.SECONDS_PER_HOUR
	if _waited_hours >= escape_pod_wait_hours:
		_depart()

func _depart() -> void:
	state = LeaveState.Finished
	SignalBus.crew_departed.emit(pawn)
	# PREDELETE dumps carried resources to a pile and re-cancels this job
	# (harmless - the lifecycle guard makes it a no-op by then).
	pawn.queue_free()

func _on_cancel(as_failed: bool) -> void:
	if as_failed:
		state = LeaveState.Failed
	else:
		state = LeaveState.Finished

func is_failed() -> bool:
	return state == LeaveState.Failed

func is_finished() -> bool:
	return state == LeaveState.Finished

## Nearest reachable constructed docking bay, by its recruitment component.
func _find_bay(_pawn: PawnBase) -> CrewRecruitmentComponent:
	var best: CrewRecruitmentComponent = null
	var best_dist: int = 0
	for node: Node in _pawn.get_tree().get_nodes_in_group(Groups.CREW_RECRUITMENT):
		var bay: CrewRecruitmentComponent = node as CrewRecruitmentComponent
		if bay == null or not Global.path_manager.is_reachable(_pawn, bay.owner_module):
			continue
		var dist: int = bay.owner_module.module_cell.distance_squared_to(Global.world_to_cell(_pawn.global_position))
		if best == null or dist < best_dist:
			best = bay
			best_dist = dist
	return best
