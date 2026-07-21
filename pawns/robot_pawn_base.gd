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
	# Return carried cargo first so a robot never sits on stock it could deposit.
	if inventory_component != null and not inventory_component.is_empty():
		var return_job: Job_StoreInventory = _make_store_inventory_job()
		if return_job.can_do_job(self):
			_begin_job(return_job)
			return
		# Nowhere takes it right now - fall through rather than stalling the robot.
	# Personal queue next: chained followups, queued needs (recharge/repair).
	while not job_queue.is_empty():
		var queued_job: JobBase = job_queue.pop_front()
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
		if job_queue[i] is Job_Recharge:
			var job: JobBase = job_queue[i]
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

## Store-inventory sweep target, overridable (the drone restricts deposits to its
## own bay). Base: an open sweep to any storage that will take the cargo.
func _make_store_inventory_job() -> Job_StoreInventory:
	return Job_StoreInventory.new()
