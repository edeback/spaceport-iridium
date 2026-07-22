class_name Job_GetRepaired
extends JobBase

## Personal-queue need job (never on the shared board): a damaged robot walks to
## the nearest reachable powered Repair Bay with a free slot, docks, and restores
## its integrity until full. Near-twin of Job_Recharge - same claim/slot/leak
## discipline - but restores integrity at a RobotRepairComponent and may pause if
## the bay runs out of an optional repair resource. Posted by RobotIntegrityComponent.

var pawn: PawnBase
var repair_bay: RobotRepairComponent

enum RepairState { Starting, MovingToBay, Repairing, Finished, Failed }
var state: RepairState = RepairState.Starting:
	set(new_state):
		if new_state != state:
			state = new_state
			subtask_changed.emit()

func get_category() -> Category:
	return Category.NEEDS

func get_job_description() -> String:
	return "Getting repaired"

func get_subtask_description() -> String:
	match state:
		RepairState.MovingToBay:
			return "Heading to a Repair Bay"
		RepairState.Repairing:
			return "Under repair"
	return ""

func can_do_job(_pawn: PawnBase) -> bool:
	return _find_bay(_pawn) != null

func start_job(_pawn: PawnBase) -> void:
	pawn = _pawn
	repair_bay = _find_bay(pawn)
	if repair_bay == null or not repair_bay.claim_slot(self):
		cancel(true)
		return
	SignalBus.module_removed.connect(_module_removed)
	state = RepairState.MovingToBay
	pawn.movement_component.movement_ended.connect(_arrived, CONNECT_ONE_SHOT)
	pawn.movement_component.move_to(repair_bay.owner_module, 1.0, false)

func _arrived(prev_success: bool) -> void:
	# _ended: a stale movement one-shot after an external cancel must not overwrite
	# the terminal state (WI-04 lifecycle rule).
	if _ended:
		return
	if not prev_success or not is_instance_valid(repair_bay) or not repair_bay.powered():
		cancel(true)
		return
	state = RepairState.Repairing

func process_job(delta: float) -> void:
	if state != RepairState.Repairing:
		return
	var integrity: RobotIntegrityComponent = pawn.get_component_by_type(RobotIntegrityComponent) as RobotIntegrityComponent
	if integrity == null or not is_instance_valid(repair_bay):
		cancel(true)
		return
	var rate: float = repair_bay.repair_per_hour()
	if rate <= 0.0:
		# Power died mid-repair: leave gracefully; the integrity component re-queues
		# on its retry throttle if still low.
		cancel(false)
		return
	# delta arrives sim-scaled from PawnBase._process.
	var sim_hours: float = delta / TimeManager.SECONDS_PER_HOUR
	# Pause (don't consume) if the bay can't pay the optional repair resource.
	if not repair_bay.consume_repair_resource(sim_hours):
		return
	integrity.integrity += rate * sim_hours
	if integrity.integrity >= integrity.integrity_max:
		state = RepairState.Finished

func _module_removed(module: ModuleBase) -> void:
	# Repair Bay deconstructed mid-use: cancel gracefully; the integrity component's
	# retry throttle finds another bay next attempt.
	if repair_bay != null and module == repair_bay.owner_module:
		cancel(true)

func _on_cancel(as_failed: bool) -> void:
	if as_failed:
		state = RepairState.Failed
	else:
		state = RepairState.Finished

func _on_end() -> void:
	if SignalBus.module_removed.is_connected(_module_removed):
		SignalBus.module_removed.disconnect(_module_removed)
	# Slot released on EVERY termination path.
	if is_instance_valid(repair_bay):
		repair_bay.release_slot(self)

func is_failed() -> bool:
	return state == RepairState.Failed

func is_finished() -> bool:
	return state == RepairState.Finished

# --- persistence (WI-21/WI-28) ------------------------------------------------

## No target ref: start_job() re-finds the nearest bay and re-claims a slot on load.
## SaveManager re-links it via RobotIntegrityComponent.adopt_restored_repair_job so
## no duplicate is queued.
func get_save_data() -> Dictionary:
	return {"type": "get_repaired"}

static func restore(_data: Dictionary) -> JobBase:
	return Job_GetRepaired.new()

## Nearest reachable, powered Repair Bay with a free slot. Pure query.
func _find_bay(_pawn: PawnBase) -> RobotRepairComponent:
	var best: RobotRepairComponent = null
	var best_dist: int = 0
	var pawn_cell: Vector2i = Global.world_to_cell(_pawn.global_position)
	for node: Node in _pawn.get_tree().get_nodes_in_group(Groups.ROBOT_REPAIR):
		var candidate: RobotRepairComponent = node as RobotRepairComponent
		if candidate == null or not candidate.is_available():
			continue
		if not _bay_reachable(_pawn, candidate.owner_module):
			continue
		var dist: int = candidate.owner_module.module_cell.distance_squared_to(pawn_cell)
		if best == null or dist < best_dist:
			best = candidate
			best_dist = dist
	return best

func _bay_reachable(_pawn: PawnBase, module: ModuleBase) -> bool:
	if Global.path_manager.is_reachable(_pawn, module):
		return true
	# A drone in space reaches an exterior-facing bay by EVA (mirrors Job_Repair).
	return Global.path_manager.is_exterior(module) and Global.path_manager.is_space_reachable(_pawn)
