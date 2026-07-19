class_name Job_Recreate
extends JobBase

## Personal-queue need job: restore recreation at any provider - dedicated
## entertainment (holodeck) or a social space (mess hall) - picked randomly
## from the combined reachable pool (WI-05: socializing IS recreation, so
## there is no separate Job_Socialize). If the chosen provider fills up or
## becomes unreachable before the pawn commits, fall back to the remaining
## pool before failing outright.

var pawn: PawnBase
var provider: RecreationProviderComponent
var stay_hours: float = 0.0
## Leave even if not fully restored - keeps pawns from parking in the
## holodeck all cycle when the restore rate barely beats decay.
@export var max_stay_hours: float = 3.0

var _tried: Array[RecreationProviderComponent] = []

enum RecreateState { Starting, Moving, Recreating, Finished, Failed }
var state: RecreateState = RecreateState.Starting:
	set(new_state):
		if new_state != state:
			state = new_state
			subtask_changed.emit()

func get_category() -> Category:
	return Category.NEEDS

func get_job_description() -> String:
	return "Taking a break"

func get_subtask_description() -> String:
	match state:
		RecreateState.Moving:
			return "Heading to recreation"
		RecreateState.Recreating:
			return "Socializing" if provider is SocialComponent else "Recreating"
	return ""

func can_do_job(_pawn: PawnBase) -> bool:
	return not _gather_candidates(_pawn).is_empty()

func start_job(_pawn: PawnBase) -> void:
	pawn = _pawn
	SignalBus.module_removed.connect(_module_removed)
	_try_next_provider()

func _try_next_provider() -> void:
	var candidates: Array[RecreationProviderComponent] = _gather_candidates(pawn)
	for tried: RecreationProviderComponent in _tried:
		candidates.erase(tried)
	if candidates.is_empty():
		cancel(true)
		return
	provider = candidates.pick_random()
	_tried.append(provider)
	if not provider.claim_slot(self):
		_try_next_provider()
		return
	state = RecreateState.Moving
	pawn.movement_component.movement_ended.connect(_arrived, CONNECT_ONE_SHOT)
	pawn.movement_component.move_to(provider.owner_module)

func _arrived(prev_success: bool) -> void:
	# _ended: a stale movement one-shot firing after an external cancel must
	# not overwrite the terminal state (WI-04 lifecycle rule).
	if _ended:
		return
	if not prev_success:
		# Couldn't get there - hand the slot back and try elsewhere.
		if is_instance_valid(provider):
			provider.release_slot(self)
		_try_next_provider()
		return
	state = RecreateState.Recreating

func process_job(delta: float) -> void:
	if state != RecreateState.Recreating:
		return
	var needs: PawnNeedsComponent = pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
	if needs == null or not is_instance_valid(provider):
		cancel(true)
		return
	var rate: float = provider.recreation_per_hour(pawn)
	if rate <= 0.0:
		# Power died mid-visit or similar - leave gracefully; the need
		# re-queues on its own if still low.
		cancel(false)
		return
	# delta arrives sim-scaled from PawnBase._process.
	var sim_hours: float = delta / TimeManager.SECONDS_PER_HOUR
	stay_hours += sim_hours
	needs.recreation_value += rate * sim_hours
	if needs.recreation_value >= needs.recreation_max or stay_hours >= max_stay_hours:
		state = RecreateState.Finished

func _module_removed(module: ModuleBase) -> void:
	if provider != null and module == provider.owner_module:
		cancel(true)

func _on_cancel(as_failed: bool) -> void:
	if as_failed:
		state = RecreateState.Failed
	else:
		state = RecreateState.Finished

func _on_end() -> void:
	if SignalBus.module_removed.is_connected(_module_removed):
		SignalBus.module_removed.disconnect(_module_removed)
	if is_instance_valid(provider):
		provider.release_slot(self)

func is_failed() -> bool:
	return state == RecreateState.Failed

func is_finished() -> bool:
	return state == RecreateState.Finished

# --- persistence (WI-21) ------------------------------------------------------

## No target ref: start_job() re-gathers reachable providers and re-claims a
## slot on load. Persisting lets a pawn resume a recreation session already
## above the need threshold (which the decay loop wouldn't re-queue). SaveManager
## re-links it to the recreation need via adopt_restored_need_job so no
## duplicate is queued.
func get_save_data() -> Dictionary:
	return {"type": "recreate"}

static func restore(_data: Dictionary) -> JobBase:
	return Job_Recreate.new()

## All reachable providers (either kind) with a free slot and a nonzero rate.
## Pure query - safe from can_do_job.
func _gather_candidates(_pawn: PawnBase) -> Array[RecreationProviderComponent]:
	var out: Array[RecreationProviderComponent] = []
	for node: Node in _pawn.get_tree().get_nodes_in_group("recreation_provider"):
		var candidate: RecreationProviderComponent = node as RecreationProviderComponent
		if candidate == null or not candidate.has_free_slot():
			continue
		if candidate.recreation_per_hour(_pawn) <= 0.0:
			continue
		if not Global.path_manager.is_reachable(_pawn, candidate.owner_module):
			continue
		out.append(candidate)
	return out
