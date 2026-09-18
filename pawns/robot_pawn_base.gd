class_name RobotPawnBase
extends PawnBase

## Shared base for autonomous robots (WI-28): mining drones, WI-27 hauler robots,
## and future combat bots. Robots have none of the organic-crew nature - no needs,
## no schedule (always on duty), no skills/traits - and are owned and torn down by
## a home module (a Mining Bay or Logistics Bay). CrewManager and the save's pawn
## section identify robots by this base rather than a concrete subclass, so both
## drones and haulers are excluded from the wage roster / lose condition.
##
## WI-28 gives every robot a battery: it carries a RobotPowerComponent (energy)
## created in code here, forwarding the per-robot tuning from the exported vars
## below so the two robot scenes tune energy through the pawn root the same way
## they already tune speed/capacity. Robots no longer freeze when their home bay
## loses power - they run on their own battery and recharge at a charger; a dead
## bay just means its implicit charger is unavailable.
##
## Subclasses differ only in how they source work (_claim_work_job) and which
## component owns them (set_owner_component). Everything shared lives here.

## Set by the owning bay each tick to reflect whether the home bay has power. No
## longer a freeze gate (WI-28) - it feeds the home charger's availability only.
## Kept exported so both robot scenes' authored `powered = true` still binds.
@export var powered: bool = true

## --- identity -----------------------------------------------------------------

## Display designation for this robot kind ("Mining Droid"), the front half of the
## numbered name every pawn-listing UI shows. Empty = fall back to the subclass's
## default_designation(); exported anyway so a mod's robot scene can label itself,
## since a mod can't declare a class_name to override that hook (WI-47 M6).
@export var robot_designation: String = ""

## Station-wide number within this designation ("Mining Droid 2" -> 2). Allocated
## in _ready and round-tripped through the save so a loaded robot keeps the name
## the player learned and a robot built afterwards can't collide with it.
## 0 = unallocated.
@export var robot_index: int = 0

## --- energy tuning (WI-28), forwarded to RobotPowerComponent ------------------
@export var energy_max: float = 100.0
@export var energy_idle_drain_per_hour: float = 0.5
@export var energy_drain_moving_per_hour: float = 12.0
@export var energy_drain_working_per_hour: float = 8.0
@export var energy_seek_threshold_percent: float = 30.0
@export var energy_crawl_speed_scale: float = 0.25

## --- integrity tuning (WI-28), forwarded to RobotIntegrityComponent -----------
@export var integrity_max: float = 100.0
@export var integrity_repair_threshold_percent: float = 50.0
@export var integrity_malfunction_chance_per_hour: float = 0.02
@export var integrity_malfunction_damage_min: float = 5.0
@export var integrity_malfunction_damage_max: float = 20.0

var power_component: RobotPowerComponent
var integrity_component: RobotIntegrityComponent

func _ready() -> void:
	super()
	# Identity: nothing else names a robot, and an unnamed pawn shows up as an
	# anonymous "Crew member" everywhere. A loaded robot arrives with both fields
	# already set (SaveManager writes them before add_child) and skips this; a
	# save from before robots were named has neither, so its robots get numbered
	# here, in load order, exactly like freshly built ones.
	if robot_index <= 0:
		robot_index = _allocate_robot_index()
	if pawn_name.is_empty():
		pawn_name = RobotDesignation.format_name(get_designation(), robot_index)
	# Battery + integrity (WI-28). Created in code - not scene children - so tuning
	# stays on the pawn root (overridable per robot scene) and both robot scenes get
	# them without editing their subtrees. Appended to `components` so
	# get_component_by_type and the save's pawn section find them, exactly like the
	# scene-authored crew components.
	power_component = RobotPowerComponent.new()
	power_component.owner_pawn = self
	power_component.energy_max = energy_max
	power_component.idle_drain_per_hour = energy_idle_drain_per_hour
	power_component.drain_moving_per_hour = energy_drain_moving_per_hour
	power_component.drain_working_per_hour = energy_drain_working_per_hour
	power_component.seek_threshold_percent = energy_seek_threshold_percent
	power_component.crawl_speed_scale = energy_crawl_speed_scale
	power_component.reset_full()
	components.append(power_component)
	add_child(power_component)
	integrity_component = RobotIntegrityComponent.new()
	integrity_component.owner_pawn = self
	integrity_component.integrity_max = integrity_max
	integrity_component.repair_seek_threshold_percent = integrity_repair_threshold_percent
	integrity_component.malfunction_chance_per_hour = integrity_malfunction_chance_per_hour
	integrity_component.malfunction_damage_min = integrity_malfunction_damage_min
	integrity_component.malfunction_damage_max = integrity_malfunction_damage_max
	integrity_component.reset_full()
	components.append(integrity_component)
	add_child(integrity_component)

## Designation shown in UI: the scene's override first, then the per-class default.
func get_designation() -> String:
	return robot_designation if not robot_designation.is_empty() else default_designation()

## Per-class fallback designation, overridden by each robot subclass. Only reached
## when the robot's scene leaves robot_designation empty.
func default_designation() -> String:
	return "Droid"

## Lowest free number among the live robots sharing this designation. Scanned
## rather than counted off a manager: a destroyed robot puts its number back in
## circulation just by leaving the tree, there's no counter to reset between runs
## or restore on load, and spawns are rare enough (one drone per bay per respawn
## timer) that the scan cost never shows up.
func _allocate_robot_index() -> int:
	var designation: String = get_designation()
	var used: PackedInt32Array = []
	for node: Node in get_tree().get_nodes_in_group(Groups.PAWN):
		var robot: RobotPawnBase = node as RobotPawnBase
		# Skips self - super() already joined the group, still holding index 0 -
		# and anything mid-teardown, whose number is free again.
		if robot == null or robot == self or robot.is_queued_for_deletion():
			continue
		if robot.robot_index >= 1 and robot.get_designation() == designation:
			used.append(robot.robot_index)
	return RobotDesignation.next_index(used)

## Tears the robot down (bay removed, or robot destroyed). Carried cargo is dumped
## as a pile by PawnBase's PREDELETE handler, satisfying the resource invariant.
func self_destruct() -> void:
	if current_job != null:
		current_job.cancel(true)
		current_job = null
	queue_free()

## Integrity hit zero (WI-28): let the owning bay free its slot / respawn, then
## tear the robot down. Cargo drops as a pile via PawnBase's PREDELETE handler.
func notify_destroyed_by_integrity() -> void:
	_notify_owner_removed()
	self_destruct()

## Hook for subclasses to detach from their owning bay when destroyed (drone:
## MiningComponent; hauler: LogisticsBayComponent). Base does nothing.
func _notify_owner_removed() -> void:
	pass

## Shared claim ordering (WI-28). Layered on top of the WI-27 pattern with the
## energy gates: a drained robot heads straight for a charger and takes nothing
## else; a low-but-not-empty robot delivers its cargo and recharges before pulling
## any new board work. Subclasses supply only the normal-work branch.
func start_job() -> void:
	# Zero energy = emergency backup power: recharge and nothing else. Skip the
	# cargo sweep and the work board entirely.
	if power_component != null and power_component.must_recharge():
		_start_recharge_only()
		return
	# Then the job this robot was doing when the save was written (WI-68 F21):
	# the cargo it carries is that job's, not leftovers for the sweep below. After
	# the emergency gate deliberately - a drained robot still recharges first.
	if _resume_restored_job():
		return
	# Return carried cargo first so a robot never sits on stock it could deposit.
	if inventory_component != null and not inventory_component.is_empty():
		var return_job: Job = _make_store_inventory_job()
		if return_job.can_do_job(self):
			_begin_job(return_job)
			return
		# Nowhere takes it right now - fall through rather than stalling the robot.
	# Personal queue next: chained followups, queued needs (recharge/repair).
	while not job_queue.is_empty():
		var queued_job: Job = job_queue.pop_front()
		if queued_job.is_valid() and queued_job.can_do_job(self):
			_begin_job(queued_job)
			return
		queued_job.cancel(true) # cancel implies end_job (lifecycle contract)
	# Below the recharge threshold: don't pull new board work - wait for the queued
	# recharge to become runnable (no board jobs below threshold until charged).
	if power_component != null and power_component.wants_recharge():
		if animated_sprite != null:
			animated_sprite.play("idle")
		return
	_claim_work_job()

## Zero-energy state: run a recharge job and nothing else. Prefer one already
## queued; RobotPowerComponent's escalation otherwise preempts us with a fresh one,
## so if none is runnable here we just hold an idle pose and let it retry (throttled).
func _start_recharge_only() -> void:
	for i: int in range(job_queue.size()):
		if job_queue[i].data != null and job_queue[i].data.id == &"recharge":
			var job: Job = job_queue[i]
			job_queue.remove_at(i)
			if job.is_valid() and job.can_do_job(self):
				_begin_job(job)
				return
			job.cancel(true)
			break
	if animated_sprite != null:
		animated_sprite.play("idle")

## Normal-work claim, overridden per robot (drone: parent bay; hauler: HAUL board).
## Base idles.
func _claim_work_job() -> void:
	if animated_sprite != null:
		animated_sprite.play("idle")
