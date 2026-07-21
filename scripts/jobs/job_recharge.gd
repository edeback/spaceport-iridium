class_name Job_Recharge
extends JobBase

## Personal-queue need job (never on the shared board): a robot walks to the
## nearest reachable powered charger with a free slot, docks, and refills its
## battery until full. Patterned on Job_Sleep - the slot is claimed up front and
## released in _on_end (every termination path), so charger slots can't leak.
## Posted and escalated by RobotPowerComponent, which owns the decision of WHEN a
## robot recharges; this job only handles the trip and the charging.

var pawn: PawnBase
var charger: RechargeComponent

enum RechargeState { Starting, MovingToCharger, Charging, Finished, Failed }
var state: RechargeState = RechargeState.Starting:
	set(new_state):
		if new_state != state:
			state = new_state
			subtask_changed.emit()

func get_category() -> Category:
	return Category.NEEDS

func get_job_description() -> String:
	return "Recharging"

func get_subtask_description() -> String:
	match state:
		RechargeState.MovingToCharger:
			return "Heading to a charger"
		RechargeState.Charging:
			return "Recharging"
	return ""

## The power component drains during the trip but not while docked - see
## RobotPowerComponent._is_charging(), which reads this.
func is_charging() -> bool:
	return state == RechargeState.Charging

func can_do_job(_pawn: PawnBase) -> bool:
	return _find_charger(_pawn) != null

func start_job(_pawn: PawnBase) -> void:
	pawn = _pawn
	charger = _find_charger(pawn)
	if charger == null or not charger.claim_slot(self):
		cancel(true)
		return
	SignalBus.module_removed.connect(_module_removed)
	state = RechargeState.MovingToCharger
	pawn.movement_component.movement_ended.connect(_arrived, CONNECT_ONE_SHOT)
	pawn.movement_component.move_to(charger.owner_module, 1.0, false)

func _arrived(prev_success: bool) -> void:
	# _ended: a stale movement one-shot after an external cancel must not overwrite
	# the terminal state (WI-04 lifecycle rule).
	if _ended:
		return
	if not prev_success or not is_instance_valid(charger) or not charger.powered():
		cancel(true)
		return
	state = RechargeState.Charging

func process_job(delta: float) -> void:
	if state != RechargeState.Charging:
		return
	var power: RobotPowerComponent = pawn.get_component_by_type(RobotPowerComponent) as RobotPowerComponent
	if power == null or not is_instance_valid(charger):
		cancel(true)
		return
	var rate: float = charger.charge_per_hour()
	if rate <= 0.0:
		# Power died mid-charge: leave gracefully. RobotPowerComponent re-queues
		# on its retry throttle if still low (no pathfinding spam).
		cancel(false)
		return
	# delta arrives sim-scaled from PawnBase._process.
	var sim_hours: float = delta / TimeManager.SECONDS_PER_HOUR
	power.energy += rate * sim_hours
	if power.energy >= power.energy_max:
		state = RechargeState.Finished

func _module_removed(module: ModuleBase) -> void:
	# Charger deconstructed mid-use: cancel gracefully; the power component's
	# retry throttle finds another charger next attempt.
	if charger != null and module == charger.owner_module:
		cancel(true)

func _on_cancel(as_failed: bool) -> void:
	if as_failed:
		state = RechargeState.Failed
	else:
		state = RechargeState.Finished

func _on_end() -> void:
	if SignalBus.module_removed.is_connected(_module_removed):
		SignalBus.module_removed.disconnect(_module_removed)
	# Slot released on EVERY termination path, like Job_Sleep's pod slot.
	if is_instance_valid(charger):
		charger.release_slot(self)

func is_failed() -> bool:
	return state == RechargeState.Failed

func is_finished() -> bool:
	return state == RechargeState.Finished

# --- persistence (WI-21/WI-28) ------------------------------------------------

## No target ref: start_job() re-finds the nearest charger and re-claims a slot on
## load (the claim itself is never saved). Persisting lets a robot resume a charge
## session that had already risen above the seek threshold, which the power
## component wouldn't re-queue. SaveManager re-links it via
## RobotPowerComponent.adopt_restored_recharge_job so no duplicate is queued.
func get_save_data() -> Dictionary:
	return {"type": "recharge"}

static func restore(_data: Dictionary) -> JobBase:
	return Job_Recharge.new()

## Nearest reachable, powered, un-full charger. Pure query - safe from can_do_job.
## Interior robots (haulers) reach chargers normally; a drone in space reaches its
## home bay's charger the same way it returns there to deposit ore.
func _find_charger(_pawn: PawnBase) -> RechargeComponent:
	var best: RechargeComponent = null
	var best_dist: int = 0
	var pawn_cell: Vector2i = Global.world_to_cell(_pawn.global_position)
	for node: Node in _pawn.get_tree().get_nodes_in_group("recharger"):
		var candidate: RechargeComponent = node as RechargeComponent
		if candidate == null or not candidate.is_available():
			continue
		if not _charger_reachable(_pawn, candidate.owner_module):
			continue
		var dist: int = candidate.owner_module.module_cell.distance_squared_to(pawn_cell)
		if best == null or dist < best_dist:
			best = candidate
			best_dist = dist
	return best

func _charger_reachable(_pawn: PawnBase, module: ModuleBase) -> bool:
	if Global.path_manager.is_reachable(_pawn, module):
		return true
	# A drone in space reaches an exterior-facing charger by EVA (mirrors how
	# Job_Repair reaches exterior wreckage).
	return Global.path_manager.is_exterior(module) and Global.path_manager.is_space_reachable(_pawn)
