class_name RobotIntegrityComponent
extends PawnComponentBase

## A robot's structural health (WI-28). Unlike energy it never decays and never
## regenerates on its own - it only drops (combat in WI-32, and the small hourly
## "malfunction" roll here) and is only restored at a dedicated Repair Bay. At
## zero the robot is destroyed. Below the repair threshold it queues a
## a repair job non-disruptively (damage isn't the emergency zero-energy is -
## the robot finishes its current job, then goes to get patched up).
##
## Created in code by RobotPawnBase, which forwards the per-robot tuning from its
## exported vars - same arrangement as RobotPowerComponent.

var integrity_max: float = 100.0
## Below this %, queue a repair job. No crawl/emergency equivalent - a damaged
## robot still works at full speed until it's actually destroyed.
var repair_seek_threshold_percent: float = 50.0
## Per-game-hour probability of a malfunction (independent of WI-24 module
## breakdowns). A malfunction deals minor integrity damage.
var malfunction_chance_per_hour: float = 0.02
var malfunction_damage_min: float = 5.0
var malfunction_damage_max: float = 20.0
## Sim-seconds between repair retries when none can be serviced (no reachable
## powered Repair Bay) - throttles pathfinding like the recharge retry.
var retry_cooldown_seconds: float = 30.0

var integrity: float = integrity_max:
	set(new_integrity):
		new_integrity = clampf(new_integrity, 0.0, integrity_max)
		if integrity != new_integrity:
			integrity = new_integrity
			integrity_changed.emit(integrity)
signal integrity_changed(new_integrity: float)

## The pending/active trip to a Repair Bay, so the seek loop never queues two.
var _repair_slot: JobSlot = JobSlot.new(_on_repair_end)
var _retry_cooldown: float = 0.0
var _stranded_alerted: bool = false
## Guards the destruction path against re-entry (a second apply_damage during
## teardown must not fire the alert / bay notification twice).
var _destroyed: bool = false

func _ready() -> void:
	super()
	# Hourly malfunction roll (WI-28), alongside WI-24's module-breakdown roll.
	if Global.time_manager != null:
		Global.time_manager.hour_changed.connect(_on_hour_changed)

func reset_full() -> void:
	integrity = integrity_max

func integrity_percent() -> float:
	return integrity / integrity_max * 100.0 if integrity_max > 0.0 else 100.0

## Informational: below the repair threshold the robot is seeking a Repair Bay.
func wants_repair() -> bool:
	return integrity_percent() < repair_seek_threshold_percent

## Damage entry point (WI-28). `from_malfunction` only tags the alert text; combat
## (WI-32) will call this with its own source. At zero integrity the robot is
## destroyed; otherwise a repair job is queued if we've dropped below threshold.
func apply_damage(amount: float, from_malfunction: bool = false) -> void:
	if amount <= 0.0 or _destroyed:
		return
	integrity -= amount
	if integrity <= 0.0:
		_destroy()
		return
	if from_malfunction:
		SignalBus.station_alert.emit("%s malfunctioned and took damage" % _robot_label())
	_maybe_seek_repair()

func _process(delta: float) -> void:
	if owner_pawn == null or _destroyed:
		return
	var sim_delta: float = Global.time_manager.scale(delta)
	if sim_delta <= 0.0:
		return
	if _retry_cooldown > 0.0:
		_retry_cooldown = maxf(0.0, _retry_cooldown - sim_delta)
	# Cheap early-out at full/high integrity (the common case); only re-queues a
	# repair job when below threshold and the retry throttle allows.
	_maybe_seek_repair()

func _on_hour_changed(_hour: int) -> void:
	if _destroyed or malfunction_chance_per_hour <= 0.0:
		return
	if randf() < malfunction_chance_per_hour:
		apply_damage(randf_range(malfunction_damage_min, malfunction_damage_max), true)

func _maybe_seek_repair() -> void:
	if integrity_percent() >= repair_seek_threshold_percent:
		_stranded_alerted = false
		return
	if _repair_slot.is_live():
		return
	if _retry_cooldown > 0.0:
		return
	var job: Job = Job.of(&"get_repaired")
	_repair_slot.post(job)
	# Non-disruptive: repair runs after the current job finishes (unlike the
	# zero-energy preempt) - damage doesn't stop the robot working.
	owner_pawn.queue_job(job)

func _on_repair_end(_job: Job, _completed: bool) -> void:
	# Still damaged after the attempt (no reachable Repair Bay, or it was deconstructed
	# mid-repair): throttle the next try and alert once if we can't get patched.
	if integrity_percent() < repair_seek_threshold_percent:
		_retry_cooldown = retry_cooldown_seconds
		if not _stranded_alerted:
			AlertManager.raise_alert(AlertRules.make_id(&"robot_unrepaired", owner_pawn),
				AlertData.Priority.HIGH, "Robot cannot be repaired",
				"%s · no reachable Repair Bay" % _robot_label(), owner_pawn, &"",
				"%d robots cannot reach a Repair Bay")
			_stranded_alerted = true
	else:
		_stranded_alerted = false

## Zero integrity: notify the owning bay (so it frees a robot slot / respawns) then
## tear down. Carried cargo drops as a pile via PawnBase's PREDELETE handler.
func _destroy() -> void:
	if _destroyed:
		return
	_destroyed = true
	# CRITICAL (WI-53): already irreversible by the time it fires, and the
	# easiest loss in the game to miss - a robot simply stops existing.
	AlertManager.raise_alert(AlertRules.make_id(&"robot_lost", owner_pawn),
		AlertData.Priority.CRITICAL, "Robot destroyed", _robot_label(), owner_pawn, &"crew",
		"%d robots were destroyed")
	var robot: RobotPawnBase = owner_pawn as RobotPawnBase
	if robot != null:
		robot.notify_destroyed_by_integrity()

func _robot_label() -> String:
	if owner_pawn != null and not owner_pawn.pawn_name.is_empty():
		return owner_pawn.pawn_name
	return "A robot"

# --- persistence (WI-28) -----------------------------------------------------

func save_order() -> int:
	return 80

func save_key() -> StringName:
	return &"robot_integrity"

func get_save_data() -> Dictionary:
	return {"integrity": integrity}

func load_save_data(data: Dictionary) -> void:
	# Pre-WI-28 saves lack the key: robots load at full integrity (migration default).
	integrity = float(data.get("integrity", integrity_max))

## Re-link a repair job restored from a save so the seek loop treats it as the
## already-pending job (WI-70; mirrors RobotPowerComponent.adopt_restored_job).
func adopt_restored_job(job: Job) -> bool:
	return job.is_type(&"get_repaired") and _repair_slot.adopt(job)
