class_name RobotPowerComponent
extends PawnComponentBase

## A robot's battery (WI-28). Energy drains while the robot moves and works, and
## is restored only at a charger (its home bay's implicit charger or a standalone
## Recharge Station). This mirrors PawnNeedsComponent's decay-and-queue loop, but
## for a single "need" - energy - with an escalation the organic needs deliberately
## lack: at zero the robot drops into "emergency backup power" (a speed crawl and a
## hard refusal of any job but recharging), so it can always drag itself to a
## charger instead of bricking.
##
## Created in code by RobotPawnBase (which forwards the per-robot tuning from its
## own exported vars), not authored as a scene child - so the two robot scenes tune
## energy through the pawn root like they already tune speed/capacity.

## Tuning (forwarded from RobotPawnBase). Drain is additive: a robot both moving
## and working drains at idle + moving + working.
var energy_max: float = 100.0
var idle_drain_per_hour: float = 0.5
var drain_moving_per_hour: float = 12.0
var drain_working_per_hour: float = 8.0
## Below this %, queue a recharge job (non-disruptive, like a need). At 0 the
## robot preempts whatever it's doing - see _maybe_seek_recharge.
var seek_threshold_percent: float = 30.0
## Movement multiplier while at zero energy (emergency backup power crawl).
var crawl_speed_scale: float = 0.25
## Sim-seconds between recharge retries when none can currently be serviced (no
## reachable powered charger) - throttles pathfinding, mirroring the WI-17 flee cd.
var retry_cooldown_seconds: float = 20.0

var energy: float = energy_max:
	set(new_energy):
		new_energy = clampf(new_energy, 0.0, energy_max)
		if energy != new_energy:
			energy = new_energy
			energy_changed.emit(energy)
signal energy_changed(new_energy: float)

## The pending/active recharge job (null when none). Same single-slot bookkeeping
## PawnNeedsComponent keeps per need, so a second job is never queued for the same
## energy deficit.
var _recharge_job: Job = null
var _retry_cooldown: float = 0.0
## Alert-once latch for the stranded (zero energy, no reachable charger) state, so
## a robot parked far from any working charger doesn't spam the alert strip.
var _stranded_alerted: bool = false

## Push the tuning-derived starting charge. Called by RobotPawnBase after it
## forwards energy_max; a save overwrites energy afterward.
func reset_full() -> void:
	energy = energy_max

func energy_percent() -> float:
	return energy / energy_max * 100.0 if energy_max > 0.0 else 100.0

## Below the seek threshold: the robot wants to recharge and shouldn't pull new
## board work (RobotPawnBase.start_job gates on this).
func wants_recharge() -> bool:
	return energy_percent() < seek_threshold_percent

## Zero energy: emergency backup power. The robot may ONLY take/continue a recharge
## job and crawls; every other job is refused/cancelled.
func must_recharge() -> bool:
	return energy <= 0.0

func _process(delta: float) -> void:
	if owner_pawn == null:
		return
	var sim_delta: float = Global.time_manager.scale(delta)
	if sim_delta <= 0.0:
		return
	if _retry_cooldown > 0.0:
		_retry_cooldown = maxf(0.0, _retry_cooldown - sim_delta)
	_drain(sim_delta / TimeManager.SECONDS_PER_HOUR)
	# Crawl the moment we're empty; back to full speed once we have any charge.
	owner_pawn.move_speed_scale = crawl_speed_scale if energy <= 0.0 else 1.0
	_maybe_seek_recharge()

func _drain(sim_hours: float) -> void:
	# No drain while actively charging - the recharge job restores and must
	# out-rate its own trip's drain (charger charge_rate is sized above this).
	if _is_charging():
		return
	var moving: bool = owner_pawn.movement_component != null and owner_pawn.movement_component.is_traveling()
	energy -= drain_rate(moving, _is_working(), idle_drain_per_hour, drain_moving_per_hour, drain_working_per_hour) * sim_hours

## Pure drain-rate-per-hour arithmetic (WI-28), extracted so the energy budget is
## unit-testable without a live pawn. Additive contributions: idle always, plus
## moving and/or working when active.
static func drain_rate(moving: bool, working: bool, idle_rate: float, moving_rate: float, working_rate: float) -> float:
	var rate: float = idle_rate
	if moving:
		rate += moving_rate
	if working:
		rate += working_rate
	return rate

## "Working" = a current job that isn't an idle pose (WI-28 definition).
func _is_working() -> bool:
	var job: Job = owner_pawn.current_job
	return job != null and not job.is_idle_type()

func _is_charging() -> bool:
	var job: Job = owner_pawn.current_job
	# Charging = past the walk, sitting on the pad. The action index IS the state
	# machine now, so there is no is_charging() flag to keep in sync.
	return job != null and job.is_type(&"recharge") \
		and job.action_index() >= JobDriver_Recharge.CHARGE

## The decay-loop escalation ladder: above threshold do nothing; below, keep
## exactly one recharge job pending; at zero, preempt the current job so the robot
## heads to a charger now instead of crawling through its whole job list.
func _maybe_seek_recharge() -> void:
	if energy_percent() >= seek_threshold_percent:
		_stranded_alerted = false
		return
	if _recharge_job != null and not _recharge_job.is_ended():
		# A recharge job already exists. If we've now hit zero and it's only
		# queued (not the running job), escalate to an immediate preempt.
		if energy <= 0.0 and owner_pawn.current_job != _recharge_job:
			owner_pawn.dequeue_job(_recharge_job)
			owner_pawn.interrupt_with_job(_recharge_job)
		return
	# Need a fresh recharge job, subject to the retry throttle.
	if _retry_cooldown > 0.0:
		return
	_recharge_job = _make_recharge_job()
	_recharge_job.job_end.connect(_on_recharge_end.bind(_recharge_job), CONNECT_ONE_SHOT)
	if energy <= 0.0:
		# Emergency backup power: cancel whatever we're doing (gracefully - cargo
		# kept) and head straight for a charger.
		owner_pawn.interrupt_with_job(_recharge_job)
	else:
		# Non-disruptive: runs after the current job finishes (like a need).
		owner_pawn.queue_job(_recharge_job)

func _make_recharge_job() -> Job:
	var job: Job = Job.of(&"recharge")
	return job

func _on_recharge_end(job: Job) -> void:
	if job == _recharge_job:
		_recharge_job = null
	# The attempt left us still low (couldn't reach/claim a charger, or power died
	# mid-charge): throttle the next try and, if stranded at zero, alert once.
	if energy_percent() < seek_threshold_percent:
		_retry_cooldown = retry_cooldown_seconds
		if energy <= 0.0 and not _stranded_alerted:
			SignalBus.station_alert.emit("%s is out of power with no reachable charger" % _robot_label())
			_stranded_alerted = true
	else:
		_stranded_alerted = false

func _robot_label() -> String:
	if owner_pawn != null and not owner_pawn.pawn_name.is_empty():
		return owner_pawn.pawn_name
	return "A robot"

# --- persistence (WI-28) -----------------------------------------------------

func save_order() -> int:
	return 70

func save_key() -> StringName:
	return &"robot_power"

func get_save_data() -> Dictionary:
	return {"energy": energy}

func load_save_data(data: Dictionary) -> void:
	# Pre-WI-28 saves lack the key: robots load at full energy (migration default).
	energy = float(data.get("energy", energy_max))

## Re-link a recharge job restored from a save so the decay loop treats it as the
## already-pending job instead of queuing a second one (mirrors
## PawnNeedsComponent.adopt_restored_need_job).
func adopt_restored_recharge_job(job: Job) -> void:
	if _recharge_job == null:
		_recharge_job = job
		job.job_end.connect(_on_recharge_end.bind(job), CONNECT_ONE_SHOT)
