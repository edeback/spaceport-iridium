class_name Job_Sleep
extends JobBase

## Personal-queue need job (never on the shared board): walk to the nearest
## reachable pod with a free slot, lie down, restore sleep until full. The
## slot is claimed up front and released in _on_end, which runs on every
## termination path - slots can't leak.

var pawn: PawnBase
var sleep_component: SleepComponent
## Authored BUNK anchor (WI-16): the pawn sleeps on the bunk, not at module
## center. Null when the pod has none - movement falls back to the old target.
var bunk_anchor: AnchorDef = null
var _bunk_path: PathComponent = null
## Pods within this many cells of the nearest free pod are treated as equally
## close, so adjacency desirability (greenery/quiet, WI-30) can pick between
## them without sending the pawn on a station-crossing trek for a nicer bunk.
@export var desirability_distance_tolerance: float = 3.0

enum SleepState { Starting, MovingToPod, Sleeping, Finished, Failed }
var state: SleepState = SleepState.Starting:
	set(new_state):
		if new_state != state:
			state = new_state
			subtask_changed.emit()

func get_category() -> Category:
	return Category.NEEDS

func get_job_description() -> String:
	return "Getting some sleep"

func get_subtask_description() -> String:
	match state:
		SleepState.MovingToPod:
			return "Heading to a sleeping pod"
		SleepState.Sleeping:
			return "Sleeping"
	return ""

func can_do_job(_pawn: PawnBase) -> bool:
	return _find_pod(_pawn) != null

func start_job(_pawn: PawnBase) -> void:
	pawn = _pawn
	sleep_component = _find_pod(pawn)
	if sleep_component == null or not sleep_component.claim_slot(self):
		cancel(true)
		return
	SignalBus.module_removed.connect(_module_removed)
	_bunk_path = sleep_component.owner_module.get_path_component()
	if _bunk_path != null:
		bunk_anchor = _bunk_path.claim_anchor(AnchorDef.AnchorType.BUNK, self)
	state = SleepState.MovingToPod
	pawn.movement_component.movement_ended.connect(_arrived, CONNECT_ONE_SHOT)
	pawn.movement_component.move_to(sleep_component.owner_module, 1.0, false, bunk_anchor)

func _arrived(prev_success: bool) -> void:
	# _ended: a stale movement one-shot firing after an external cancel must
	# not overwrite the terminal state (WI-04 lifecycle rule).
	if not prev_success or _ended:
		cancel(true)
		return
	state = SleepState.Sleeping
	if pawn.animated_sprite != null:
		pawn.animated_sprite.play("lay_down")

func process_job(delta: float) -> void:
	if state != SleepState.Sleeping:
		return
	var needs: PawnNeedsComponent = pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
	if needs == null or not is_instance_valid(sleep_component):
		cancel(true)
		return
	# delta arrives sim-scaled from PawnBase._process; needs' own decay keeps
	# ticking in parallel, so this must out-rate it (see base_hours_to_full).
	var sim_hours: float = delta / TimeManager.SECONDS_PER_HOUR
	needs.sleep_value += sleep_component.sleep_restored_per_hour(needs.sleep_max) * sim_hours
	if needs.sleep_value >= needs.sleep_max:
		state = SleepState.Finished

func _module_removed(module: ModuleBase) -> void:
	# Pod deconstructed/deleted mid-sleep: cancel gracefully; the pawn is
	# ejected by the existing current_module null-safety.
	if sleep_component != null and module == sleep_component.owner_module:
		cancel(true)

func _on_cancel(as_failed: bool) -> void:
	if as_failed:
		state = SleepState.Failed
	else:
		state = SleepState.Finished

func _on_end() -> void:
	if SignalBus.module_removed.is_connected(_module_removed):
		SignalBus.module_removed.disconnect(_module_removed)
	if is_instance_valid(sleep_component):
		sleep_component.release_slot(self)
	# Anchor claims release on EVERY termination path, like the slot above.
	if _bunk_path != null and is_instance_valid(_bunk_path):
		_bunk_path.release_anchor(self)
	# Stand back up however the job ended - lay_down isn't a looping walk/idle
	# state the movement code would naturally replace.
	if pawn != null and is_instance_valid(pawn) and pawn.animated_sprite != null \
			and pawn.animated_sprite.animation == &"lay_down":
		pawn.animated_sprite.play("idle")

func is_failed() -> bool:
	return state == SleepState.Failed

func is_finished() -> bool:
	return state == SleepState.Finished

# --- persistence (WI-21) ------------------------------------------------------

## No target ref: start_job() re-finds the nearest pod and re-claims a slot on
## load (the slot claim itself is never saved). Persisting the job lets a pawn
## resume a sleep session that had already risen above the "look for needs"
## threshold, which the decay loop wouldn't re-queue. SaveManager re-links it to
## the sleep need via adopt_restored_need_job so no duplicate is queued.
func get_save_data() -> Dictionary:
	return {"type": "sleep"}

static func restore(_data: Dictionary) -> JobBase:
	return Job_Sleep.new()

## Nearest reachable free pod, with adjacency desirability (WI-30) as a tie-break
## among comparably-close pods. Pure query - safe from can_do_job.
func _find_pod(_pawn: PawnBase) -> SleepComponent:
	var origin: Vector2i = Global.world_to_cell(_pawn.global_position)
	# First pass: every reachable free pod with its (unsquared) cell distance,
	# tracking the closest so the second pass can define the "comparably close" band.
	var pods: Array[SleepComponent] = []
	var dists: PackedFloat32Array = []
	var nearest: float = -1.0
	for node: Node in _pawn.get_tree().get_nodes_in_group("sleep_component"):
		var pod: SleepComponent = node as SleepComponent
		if pod == null or not pod.has_free_slot():
			continue
		if not Global.path_manager.is_reachable(_pawn, pod.owner_module):
			continue
		var dist: float = Vector2(pod.owner_module.module_cell - origin).length()
		pods.append(pod)
		dists.append(dist)
		if nearest < 0.0 or dist < nearest:
			nearest = dist
	# Second pass: within the band, prefer the most desirable pod; break remaining
	# ties by distance.
	var best: SleepComponent = null
	var best_desire: float = 0.0
	var best_dist: float = 0.0
	for i: int in pods.size():
		if dists[i] > nearest + desirability_distance_tolerance:
			continue
		var desire: float = pods[i].desirability()
		if best == null or desire > best_desire or (is_equal_approx(desire, best_desire) and dists[i] < best_dist):
			best = pods[i]
			best_desire = desire
			best_dist = dists[i]
	return best
