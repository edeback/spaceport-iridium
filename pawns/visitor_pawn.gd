class_name VisitorPawn
extends PawnBase

## A paying guest (WI-33). Reuses the crew scene's needs / health / breathing /
## disease, but has no schedule, skills, or traits, and is excluded from the crew
## roster (is_visitor). Its needs drive it through the same job system crew use -
## shopping (paid recreation), sleeping (a hotel room, billed on wake), eating
## (a paid meal) - so the whole behavior loop is need-driven with money gates.
##
## It never pulls station work off the board (start_job below, like the inspector /
## mining drone), and it leaves when its stay timer runs out, its wallet empties,
## or it turns miserable - walking out via the docking bay (no escape pod: a guest
## needs a real exit, and lingers stranded, alerting, if none is reachable).

## Warm gold so a guest reads as an outsider, distinct from crew and the ARC
## inspector's steel-blue.
const GUEST_TINT: Color = Color(0.98, 0.85, 0.55)

## Game-hours left in the visit before the guest heads home regardless of mood.
## Set by VisitorManager at spawn; ticked down in _process; saved.
var stay_hours_remaining: float = 24.0
## Happiness at/below which the guest cuts the visit short (miserable).
@export var leave_happiness_threshold: float = 0.35
## Wallet at/below which the guest considers itself spent out and leaves - it has
## nothing left worth spending, so it goes home (going broke is not a mood hit).
@export var broke_threshold: int = 10
## Sim-seconds between re-attempts to reach an exit while stranded.
@export var stranded_retry_seconds: float = 20.0

## Latched once the guest has decided to leave, so the decision doesn't flip-flop.
var _leaving: bool = false
## Reputation is reported to VisitorManager exactly once, when a real walk-out
## starts (a reachable exit) - never on teardown/load, and never twice.
var _departure_reported: bool = false
## Alert-suppression latch only; not saved (WI-45 A7), unlike _departure_reported
## above, which prevents a double reputation count. A guest still stranded on
## load re-alerts once.
var _stranded_alerted: bool = false
var _retry_cooldown: float = 0.0

func _ready() -> void:
	super()
	tint = GUEST_TINT

## Configure a freshly-spawned guest (VisitorManager): starting wallet + stay length.
func setup(wallet: int, stay_hours: float) -> void:
	personal_credits = maxi(wallet, 0)
	stay_hours_remaining = maxf(stay_hours, 0.0)

func _process(delta: float) -> void:
	super(delta)  # needs decay, animation, and current-job processing (PawnBase)
	var sim_delta: float = Global.time_manager.scale(delta)
	if sim_delta <= 0.0:
		return
	if _retry_cooldown > 0.0:
		_retry_cooldown = maxf(0.0, _retry_cooldown - sim_delta)
	if not _leaving:
		stay_hours_remaining -= sim_delta / TimeManager.SECONDS_PER_HOUR
		if _should_leave():
			_leaving = true
			_go_to_exit()
	else:
		# Keep re-trying to reach an exit while stranded, on a throttle, without
		# preempting a walk-out that's already in progress.
		if _retry_cooldown <= 0.0 and _needs_exit_attempt():
			_retry_cooldown = stranded_retry_seconds
			_go_to_exit()

## Reasons a guest ends its visit (WI-33): the clock runs out, the wallet empties,
## or morale collapses.
func _should_leave() -> bool:
	if stay_hours_remaining <= 0.0:
		return true
	if personal_credits <= broke_threshold:
		return true
	var needs: PawnNeedsComponent = get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
	return needs != null and needs.happiness <= leave_happiness_threshold

## True when there's no active walk-out job to ride (it failed, ended, or the guest
## is idling), so another exit attempt is due.
func _needs_exit_attempt() -> bool:
	if current_job == null:
		return true
	return current_job.is_type(&"idle_wander") \
		or (current_job.is_type(&"leave_station") and current_job.is_ended())

## Sends the guest to the nearest reachable exit and books its departure mood for
## reputation. If nothing is reachable, alerts once and leaves the guest to wander
## (stranded) until an exit is rebuilt - the retry loop keeps checking.
func _go_to_exit() -> void:
	if _exit_reachable():
		_report_departure()
		# No escape-pod flag to set any more: the driver reads is_visitor off the
		# pawn, which is what that flag was always derived from.
		interrupt_with_job(Job.of(&"leave_station"))
		_stranded_alerted = false
	elif not _stranded_alerted:
		_stranded_alerted = true
		AlertManager.raise_alert(AlertRules.make_id(&"visitor_stuck", self),
			AlertData.Priority.HIGH, "Visitor cannot leave",
			"%s has no route out of the station" % _label(), self, &"",
			"%d visitors cannot leave")

func _exit_reachable() -> bool:
	for node: Node in get_tree().get_nodes_in_group(Groups.CREW_RECRUITMENT):
		var bay: CrewRecruitmentComponent = node as CrewRecruitmentComponent
		if bay != null and bay.owner_module != null and Global.path_manager.is_reachable(self, bay.owner_module):
			return true
	return false

## Books this guest's departure mood with VisitorManager once (happy departures
## lift reputation, unhappy ones sink it). Mood is read at report time so a long
## stranded wait reflects the guest's actual state when it finally leaves.
func _report_departure() -> void:
	if _departure_reported:
		return
	_departure_reported = true
	var needs: PawnNeedsComponent = get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
	var happy: bool = needs == null or needs.happiness > leave_happiness_threshold
	if Global.visitor_manager != null:
		Global.visitor_manager.on_visitor_departed(self, happy)

func _label() -> String:
	return pawn_name if pawn_name != "" else "A visitor"

# --- persistence (WI-33) ------------------------------------------------------
# Guests are saved in the pawn section (unlike the ARC inspector). Wallet, name,
# tint, needs, health, disease all ride the generic pawn entry; only the visit
# state is guest-specific. On load a mid-walk-out guest resumes leaving, and the
# reputation-reported latch prevents a double count.

func get_visitor_save_data() -> Dictionary:
	return {
		"stay": stay_hours_remaining,
		"leaving": _leaving,
		"reported": _departure_reported,
	}

func load_visitor_save_data(data: Dictionary) -> void:
	stay_hours_remaining = float(data.get("stay", stay_hours_remaining))
	_leaving = bool(data.get("leaving", false))
	_departure_reported = bool(data.get("reported", false))

## Guests never pull station work off the board (mirrors InspectorPawn /
## MiningDronePawn): run only queued need jobs, otherwise wander. Leaving is driven
## by _process, not the board.
func start_job() -> void:
	# A restored in-flight job first, as for crew (WI-68 F21).
	if _resume_restored_job():
		return
	if inventory_component != null and not inventory_component.is_empty():
		var return_job: Job = _make_store_inventory_job()
		if return_job.can_do_job(self):
			_begin_job(return_job)
			return
	while not job_queue.is_empty():
		var queued_job: Job = job_queue.pop_front()
		if queued_job.is_valid() and queued_job.can_do_job(self):
			_begin_job(queued_job)
			return
		queued_job.cancel(true)
	var idle_job: Job = Job.of(&"idle_wander")
	if idle_job.can_do_job(self):
		_begin_job(idle_job)
	elif animated_sprite != null:
		animated_sprite.play("idle")
