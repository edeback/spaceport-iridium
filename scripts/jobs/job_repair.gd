class_name Job_Repair
extends JobBase

## Patching up a damaged module (WI-24). Posted by ModuleBase's slow-tick poll
## whenever a built module needs_repair() - missing HP, a lingering breakdown, or
## an open hull breach - and no repair job is already outstanding. A construction-
## skilled pawn walks to the module (its WORKSTATION anchor if authored, else the
## module center / an EVA approach for exterior wreckage), then works over time:
## HP heals at repair_rate, an open breach seals fast, and a breakdown clears once
## enough work is banked. No resources are consumed (per design; a module reduced
## to rubble is gone - rebuilding it is construction's job, not repair's).

var pawn: PawnBase
var target: ModuleBase
## The module's PathComponent and a claimed WORKSTATION anchor (both may be null:
## exterior modules like truss author neither - the pawn then works at center).
var _path_component: PathComponent = null
var anchor: AnchorDef = null

## HP restored per game-hour at work_rate 1.0.
var repair_rate: float = 60.0
## Breach sealing runs this many times faster than the emergency-bulkhead self-seal.
var breach_seal_multiplier: float = 5.0
## Game-hours of work needed to clear a lingering breakdown modifier.
var breakdown_repair_hours: float = 0.5
## Completion xp granted to the construction skill (paid once, see PawnBase).
var repair_xp_reward: float = 20.0

## Sim-hours of effective work banked so far (already folded with skill/happiness).
var _work_hours: float = 0.0
## Cosmetic: shuffle the pawn around the module while working, like construction.
var shift_spot_interval: float = 3.0
var shift_spot_elapsed: float = 0.0

var state: RepairState = RepairState.Starting:
	set(new_state):
		if new_state != state:
			state = new_state
			subtask_changed.emit()

enum RepairState { Starting, MovingToModule, Repairing, Finished, Failed }

func get_category() -> Category:
	return Category.WORK

## Repair is construction work (WI-22): same skill gates the rate and earns xp.
func get_skill() -> StringName:
	return &"construction"

func xp_reward() -> float:
	return repair_xp_reward

func get_job_description() -> String:
	if is_instance_valid(target) and target.module_data != null:
		return "Repair " + target.module_data.name
	return "Repair module"

func get_subtask_description() -> String:
	match state:
		RepairState.MovingToModule:
			return "Moving to module"
		RepairState.Repairing:
			return "Repairing"
	return ""

func setup(module: ModuleBase) -> void:
	assert(module != null)
	target = module
	SignalBus.module_removed.connect(_module_removed)

## Alive while the module still exists, is built, and has something to fix.
func is_valid() -> bool:
	return is_instance_valid(target) and target.is_complete() and target.needs_repair()

func can_do_job(_pawn: PawnBase) -> bool:
	if not is_valid():
		return false
	# Interior modules are reached normally; exterior wreckage (truss, an
	# ex-module cell) is reached by EVA, matching how construction reaches sites.
	if Global.path_manager.is_reachable(_pawn, target):
		return true
	return Global.path_manager.is_exterior(target) and Global.path_manager.is_space_reachable(_pawn)

func start_job(_pawn: PawnBase) -> void:
	pawn = _pawn
	_path_component = target.get_path_component()
	if _path_component != null:
		# Null just means "no authored workstation" - work at the module then.
		anchor = _path_component.claim_anchor(AnchorDef.AnchorType.WORKSTATION, self)
	_move_to_module()

func _move_to_module() -> void:
	state = RepairState.MovingToModule
	pawn.movement_component.movement_ended.connect(_arrived, CONNECT_ONE_SHOT)
	var in_space: bool = Global.path_manager.is_exterior(target)
	pawn.movement_component.move_to(target, 1.0, in_space, anchor)

func _arrived(success: bool) -> void:
	# _ended: a stale movement one-shot after an external cancel must not revive
	# a dead job (Failed -> Repairing would strand the pawn working a ghost).
	if _ended:
		return
	if not success or not is_valid():
		cancel(true)
		return
	state = RepairState.Repairing
	# Play the workstation animation if we claimed one (no-op at the center).
	if anchor != null:
		pawn.begin_anchor_animation(anchor)

func process_job(delta: float) -> void:
	if state != RepairState.Repairing:
		return
	if not is_valid():
		cancel(true)
		return
	# delta is already sim-seconds (PawnBase feeds process_job the scaled delta).
	shift_spot_elapsed += delta
	if shift_spot_elapsed >= shift_spot_interval and target.get_structure_component() != null:
		pawn.global_position = target.get_random_position_on_module()
		shift_spot_elapsed = 0.0
	# work_rate folds happiness x construction skill, floored (WI-22).
	var work_seconds: float = delta * pawn.work_rate(get_skill())
	var work_hours: float = work_seconds / TimeManager.SECONDS_PER_HOUR
	_work_hours += work_hours
	# Heal HP (no-op once full), seal any breach fast, and clear a lingering
	# breakdown once enough work is banked.
	target.repair(repair_rate * work_hours)
	var atmo: AtmosphereComponent = target.get_atmosphere()
	if atmo != null and atmo.is_breached():
		atmo.advance_seal(work_hours * breach_seal_multiplier)
	if target.has_breakdown() and _work_hours >= breakdown_repair_hours:
		target.clear_breakdown()
	if not target.needs_repair():
		state = RepairState.Finished

func _module_removed(module: ModuleBase) -> void:
	if module == target:
		state = RepairState.Failed

func _on_cancel(as_failed: bool) -> void:
	if as_failed:
		state = RepairState.Failed
	else:
		state = RepairState.Finished

func _on_end() -> void:
	if SignalBus.module_removed.is_connected(_module_removed):
		SignalBus.module_removed.disconnect(_module_removed)
	# Release the workstation claim on EVERY end path (reservation discipline).
	if _path_component != null and is_instance_valid(_path_component):
		_path_component.release_anchor(self)
	# Stop any workstation animation so a pawn that stays put doesn't keep miming
	# repairs on a fixed module.
	if pawn != null and is_instance_valid(pawn):
		pawn.end_anchor_animation()

func is_failed() -> bool:
	return state == RepairState.Failed

func is_finished() -> bool:
	return state == RepairState.Finished

# --- persistence (WI-21) ------------------------------------------------------

## Module refs resolve by layer+cell. If the module was destroyed or fully
## repaired between save and load, restore's resolve returns null / is_valid()
## fails and the job drops cleanly through the pawn's gauntlet.
func get_save_data() -> Dictionary:
	if not is_instance_valid(target):
		return {}
	return {
		"type": "repair",
		"module": SaveManager.module_ref(target),
	}

static func restore(data: Dictionary) -> JobBase:
	var module: ModuleBase = SaveManager.resolve_module_ref(data.get("module", {}))
	if module == null:
		return null
	var job := Job_Repair.new()
	job.setup(module)
	# Claim the module's outstanding-repair slot so its slow-tick poll doesn't
	# post a duplicate before this restored pawn runs the job.
	module.adopt_repair_job(job)
	return job
