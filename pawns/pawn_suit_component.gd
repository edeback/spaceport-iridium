class_name PawnSuitComponent
extends PawnComponentBase

## Whether a crew member is wearing a pressure suit, and what they do about it
## (WI-67).
##
## The rule itself is [SuitRules] - pure and tested. This component owns the
## state, gathers the live readings the rule needs, and turns its answer into a
## job, a sprite and a mood modifier.
##
## ## Carried by crew only
##
## Robots and visitors do not have this component, which is the whole of their
## exclusion - WI-48's "carries the component = participates", and there is no
## is_visitor test anywhere in this item. The ARC inspector carries it in
## [member static_suit] mode (WI-67 §11): suited at Tier 1 so an inspection can
## never fail on air the player was never asked to provide, unsuited from Tier 2
## where WI-26's harm-fails-the-run rule is the standard again.
##
## ## The airlock is the point
##
## A suit goes on and comes off AT AN AIRLOCK, as a job, not where the pawn
## stands. That is what makes a breach dangerous: the crew are unsuited when the
## room turns, and they have to cross the station to fix it, taking damage the
## whole way. Airlock placement becomes a layout decision. The two exceptions are
## the two states a pawn is already in rather than something they travel to fix -
## going outside, and Tier 1 - and both suit up in place.

## Sim-hours a suit stays on after the last tick spent in a harmful room.
@export var harm_hold_hours: float = 2.0
## The "Spacesuit on inside" penalty. Mood is 0-1 and the Needs tab prints it
## x100, so -0.10 reads as the brief's -10.
@export var indoor_mood_offset: float = -0.10
## Sim-hours before retrying after a trip that failed or a change that was refused
## at the airlock. Stops a station in a state the rule wants but cannot complete
## from re-posting a job every tick.
@export var trip_retry_hours: float = 0.5
## Frames worn with the suit on and off. Null on either side swaps nothing, so a
## modded crew kind with no helmetless art still gets the rule (WI-47 M10).
@export var suited_frames: SpriteFrames
@export var unsuited_frames: SpriteFrames

## The inspector's mode (WI-67 §11): follow the tier and nothing else. No trips,
## no jobs, no mood, no hold - it is a visitor with a fixed wardrobe.
@export var static_suit: bool = false

## The modifier id the Needs tab shows, declared in MoodCatalog.
const MOOD_SUIT_INDOORS: StringName = &"suit_indoors"
## The job that walks to an airlock and changes.
const CHANGE_SUIT_JOB: StringName = &"change_suit"

signal suit_changed(suited: bool)

var suited: bool = true:
	set(value):
		if suited == value:
			return
		suited = value
		_apply_frames()
		suit_changed.emit(suited)

var _hold_remaining: float = 0.0
var _trip_cooldown: float = 0.0
## Set on the module_changed that brought the pawn in from outside, consumed by
## the next evaluation. A bool rather than a reference to the previous module,
## deliberately: a module can be freed between two ticks, and this is the
## non-Dictionary form of WI-63's dangling-node lesson.
var _came_in_from_outside: bool = false
var _was_outside: bool = false
## The trip this component posted, so it never posts a second one alongside it.
var _trip: JobSlot = JobSlot.new()
var _mood_applied: bool = false
## Edge-detect for the suit-up alert: raised when a trip starts, cleared when the
## suit is on. Not saved (WI-45 A7) - the latch only suppresses a repeat.
var _alerted: bool = false

func _ready() -> void:
	super()
	_apply_frames()
	if owner_pawn != null:
		owner_pawn.module_changed.connect(_on_module_changed)
		_was_outside = owner_pawn.current_module == null
	if Global.time_manager != null:
		Global.time_manager.slow_tick.connect(_on_slow_tick)
	SignalBus.station_tier_changed.connect(_on_tier_changed)

func _exit_tree() -> void:
	_clear_mood()

# --- the question everything else asks ----------------------------------------

## Is this pawn breathing (and warmed) by its own supply rather than by the room?
##
## The one place that question is answered. PawnBreathingComponent and
## PawnTemperatureComponent both route through it, so their existing suit-supply
## branches - no O2 drawn, no suffocation, no flee, no temperature mood, no harm -
## do all the work with no new branch on either side.
static func on_suit_supply(pawn: PawnBase) -> bool:
	if pawn == null:
		return false
	if pawn.current_module == null:
		return true
	var suit: PawnSuitComponent = pawn.get_component_by_type(PawnSuitComponent) as PawnSuitComponent
	return suit != null and suit.suited

# --- evaluation ---------------------------------------------------------------

func _on_slow_tick(interval: float) -> void:
	var sim_hours: float = interval / TimeManager.SECONDS_PER_HOUR
	_trip_cooldown = maxf(0.0, _trip_cooldown - sim_hours)
	_evaluate(sim_hours)

func _on_module_changed() -> void:
	var outside_now: bool = owner_pawn != null and owner_pawn.current_module == null
	# Coming in from outside INTO an airlock is the one case that ends a hold
	# early: they are standing in the airlock, so there is no trip to make.
	if _was_outside and not outside_now and _is_airlock(owner_pawn.current_module):
		_came_in_from_outside = true
	_was_outside = outside_now
	_evaluate(0.0)

func _on_tier_changed(_tier: int) -> void:
	_evaluate(0.0)

func _evaluate(sim_hours: float) -> void:
	if owner_pawn == null or not is_instance_valid(owner_pawn):
		return
	var module: ModuleBase = owner_pawn.current_module
	var outside: bool = module == null
	var conveyed: bool = _is_conveyed()
	var mandatory: bool = _suits_mandatory()
	if static_suit:
		# The inspector: follow the tier, do nothing else. No hold, no mood, no job.
		suited = mandatory
		_came_in_from_outside = false
		return
	var environment: SuitRules.RoomState = _environment_of(module)
	if not conveyed:
		_hold_remaining = SuitRules.next_hold(_hold_remaining, environment, outside,
			harm_hold_hours, sim_hours)
	var situation := SuitRules.Situation.new()
	situation.suited = suited
	situation.outside = outside
	situation.conveyed = conveyed
	situation.suits_mandatory = mandatory
	situation.environment = environment
	situation.hold_remaining = _hold_remaining
	situation.entered_airlock_from_outside = _came_in_from_outside
	situation.entry_airlock_environment = environment if _came_in_from_outside \
		else SuitRules.RoomState.UNKNOWN
	situation.trip_in_progress = _trip_is_live()
	situation.trip_cooldown = _trip_cooldown
	_came_in_from_outside = false
	match SuitRules.decide(situation):
		SuitRules.Action.SUIT_UP_IN_PLACE:
			suited = true
			_alerted = false
		SuitRules.Action.TAKE_OFF_IN_PLACE:
			suited = false
			_hold_remaining = 0.0
		SuitRules.Action.SUIT_UP:
			_start_trip(true, module, environment)
		SuitRules.Action.TAKE_OFF:
			_start_trip(false, module, environment)
		SuitRules.Action.NONE:
			pass
	if suited and not outside:
		_alerted = false
	_sync_mood(outside, mandatory)

## What the room the pawn is standing in reads as.
##
## Reads the RAW room rather than either pawn component's felt value - those
## report ideal conditions while the suit is on, so a suited pawn would never
## learn its room had recovered.
func _environment_of(module: ModuleBase) -> SuitRules.RoomState:
	if module == null or not is_instance_valid(module):
		return SuitRules.RoomState.UNKNOWN
	var atmosphere: AtmosphereComponent = null
	if Global.atmosphere_manager != null:
		atmosphere = Global.atmosphere_manager.get_component(module)
	var heat: HeatComponent = null
	if Global.heat_manager != null:
		heat = Global.heat_manager.get_component(module)
	return SuitRules.classify(
		atmosphere.o2_partial() if atmosphere != null else 0.0,
		heat.temperature_f if heat != null else HeatMath.NEUTRAL_TEMPERATURE_F,
		thresholds(), atmosphere != null, heat != null)

## The thresholds, gathered from the components that own them rather than
## restated here. A pawn missing one of those components has no opinion on that
## axis, which is what `reads_air` / `reads_heat` say.
func thresholds() -> SuitRules.Thresholds:
	var out := SuitRules.Thresholds.new()
	var breathing: PawnBreathingComponent = owner_pawn.get_component_by_type(PawnBreathingComponent) as PawnBreathingComponent
	if breathing != null:
		out.damage_o2_partial = breathing.damage_o2_partial
	else:
		out.reads_air = false
	var temperature: PawnTemperatureComponent = owner_pawn.get_component_by_type(PawnTemperatureComponent) as PawnTemperatureComponent
	if temperature != null:
		out.comfort = temperature.tuning()
	else:
		out.reads_heat = false
	if Global.atmosphere_manager != null:
		out.habitable_o2_partial = Global.atmosphere_manager.alert_o2_partial
	return out

func _suits_mandatory() -> bool:
	return Global.unlock_manager != null and Global.unlock_manager.suits_mandatory()

func _is_conveyed() -> bool:
	if owner_pawn == null or owner_pawn.movement_component == null:
		return false
	return owner_pawn.movement_component.state == PawnMovementComponent.State.Conveyed

static func _is_airlock(module: ModuleBase) -> bool:
	return module != null and is_instance_valid(module) and module.is_in_group(Groups.AIRLOCK)

# --- the trip -----------------------------------------------------------------

func _trip_is_live() -> bool:
	return _trip.is_live()

## Whether a trip to an airlock is under way (or queued). For the cheat dump and
## tests; the rule itself reads _trip_is_live() through the Situation.
func has_live_trip() -> bool:
	return _trip_is_live()

## Sim-hours before a refused or failed trip may be retried.
func trip_cooldown_remaining() -> float:
	return _trip_cooldown

## Re-links a change_suit job restored from a save (WI-68 F2, WI-70).
##
## The trip is not saved, but the job it pointed at is - SaveManager restores it
## into the pawn's queue. Without this the component saw no trip, posted a
## second one, and the orphaned first walked an already-suited pawn to an
## airlock and back. Job.offer_to_owner() asks every component on the pawn, so
## this declines anything that isn't a trip.
func adopt_restored_job(job: Job) -> bool:
	return job.is_type(CHANGE_SUIT_JOB) and _trip.adopt(job)

## Posts the walk to an airlock.
##
## Suiting up INTERRUPTS - this pawn is being harmed right now, and WI-17's
## "flee only preempts idle jobs, working crew finish what they are doing" was
## written when the consequence was a slow health tick rather than dying at your
## post. Taking a suit off is QUEUED, so nobody drops a job to go and change.
## Both go through the pawn's personal queue and never the board.
func _start_trip(putting_on: bool, module: ModuleBase, environment: SuitRules.RoomState) -> void:
	var job: Job = Job.of(CHANGE_SUIT_JOB)
	job.count = 1 if putting_on else 0
	if not job.can_do_job(owner_pawn):
		# No reachable airlock. The alert still fires and says so - that is the
		# layout feedback this whole design exists to give.
		_trip_cooldown = trip_retry_hours
		if putting_on:
			_raise_alert(module, environment, true)
		return
	_trip.post(job)
	if putting_on:
		_raise_alert(module, environment, false)
		owner_pawn.interrupt_with_job(job)
	else:
		owner_pawn.queue_job(job)

## Sim-hours left before a suit put on against harm may come off. For the Needs
## tab, the cheat console's dump, and anything else that wants to explain why a
## crew member is still wearing one in a room that looks fine.
func hold_remaining() -> float:
	return _hold_remaining

## Called by Action_ChangeSuit when the change actually happens, so the flip lives
## with the action that earned it rather than being guessed at from here.
##
## `job` is the trip that made the change. Only that trip may clear the slot
## (WI-68 F2): the cheat console flips a suit with no job at all, and clearing
## then would orphan a trip still walking - the same leak of the pointer the
## save/load bug had. A live trip simply finishes and applies its own change.
func apply_change(putting_on: bool, job: Job = null) -> void:
	suited = putting_on
	if putting_on:
		_hold_remaining = maxf(_hold_remaining, harm_hold_hours)
	else:
		_hold_remaining = 0.0
	_trip.clear_if(job)

## The change was refused at the airlock (it stopped being habitable during the
## walk) or the trip failed. Throttle before deciding again.
##
## Ignored unless `job` IS the current trip (WI-68 F2). _start_trip posts the new
## job *before* interrupt_with_job cancels whatever was running; if that was a
## stale change_suit job, its driver reports the failure here, and clearing
## unconditionally would drop the new trip - letting the next slow tick post yet
## another, which interrupts this one, and so on, with the six-second change at
## the rack never finishing. JobSlot.clear_if is that rule.
func trip_refused(job: Job) -> void:
	if _trip.clear_if(job):
		_trip_cooldown = trip_retry_hours

# --- the alert ----------------------------------------------------------------

## HIGH, because this pawn is being harmed right now and is walking across the
## station to stop it - "look at this now" by WI-53's definition, and the same
## class as the low-O2 alert it usually accompanies. Never CRITICAL: the player's
## only useful response is to watch or to plan an airlock, and a modal in the
## middle of an emergency helps nobody.
func _raise_alert(module: ModuleBase, environment: SuitRules.RoomState, stranded: bool) -> void:
	if _alerted:
		return
	_alerted = true
	var reason: SuitRules.Reason = _reason_for(module)
	var title: String = "Suiting up"
	var words: String = SuitRules.reason_text(reason)
	if not words.is_empty():
		title += " — " + words
	var where: String = module._display_name() if module != null and is_instance_valid(module) else "outside"
	var detail: String = "%s · %s" % [owner_pawn.pawn_name, where]
	if stranded:
		detail += " · no reachable airlock"
	elif environment == SuitRules.RoomState.HARMFUL:
		detail += " · " + _reading(module, reason)
	AlertManager.raise_alert(AlertRules.make_id(&"suit_up", owner_pawn),
		AlertData.Priority.HIGH, title, detail, owner_pawn, &"",
		"%d crew are suiting up")

func _reason_for(module: ModuleBase) -> SuitRules.Reason:
	if module == null or not is_instance_valid(module):
		return SuitRules.Reason.NONE
	var atmosphere: AtmosphereComponent = null
	if Global.atmosphere_manager != null:
		atmosphere = Global.atmosphere_manager.get_component(module)
	var heat: HeatComponent = null
	if Global.heat_manager != null:
		heat = Global.heat_manager.get_component(module)
	return SuitRules.reason_for(
		atmosphere.o2_partial() if atmosphere != null else 0.0,
		heat.temperature_f if heat != null else HeatMath.NEUTRAL_TEMPERATURE_F,
		thresholds(), atmosphere != null, heat != null)

func _reading(module: ModuleBase, reason: SuitRules.Reason) -> String:
	if module == null or not is_instance_valid(module):
		return ""
	if reason == SuitRules.Reason.NO_AIR:
		var atmosphere: AtmosphereComponent = null
		if Global.atmosphere_manager != null:
			atmosphere = Global.atmosphere_manager.get_component(module)
		return "O2 %d%%" % int(round(atmosphere.o2_partial())) if atmosphere != null else ""
	if Global.heat_manager == null:
		return ""
	return HeatMath.format_temperature(Global.heat_manager.temperature_at(module))

# --- the mood -----------------------------------------------------------------

## Derived state, so it is NOT saved - it re-derives on the first tick after a
## load from the saved `suited`, exactly like WI-60's too_cold and WI-48's
## company modifier.
func _sync_mood(outside: bool, mandatory: bool) -> void:
	var wanted: bool = SuitRules.mood_applies(suited, outside, mandatory)
	if wanted == _mood_applied:
		return
	var needs: PawnNeedsComponent = owner_pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
	if needs == null:
		return
	if wanted:
		needs.add_modifier(MOOD_SUIT_INDOORS, indoor_mood_offset, INF)
	else:
		needs.remove_modifier(MOOD_SUIT_INDOORS)
	_mood_applied = wanted

func _clear_mood() -> void:
	if not _mood_applied or owner_pawn == null or not is_instance_valid(owner_pawn):
		return
	var needs: PawnNeedsComponent = owner_pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
	if needs != null:
		needs.remove_modifier(MOOD_SUIT_INDOORS)
	_mood_applied = false

# --- sprite -------------------------------------------------------------------

func _apply_frames() -> void:
	if owner_pawn == null:
		return
	var frames: SpriteFrames = suited_frames if suited else unsuited_frames
	if frames != null:
		owner_pawn.set_sprite_frames(frames)

# --- persistence --------------------------------------------------------------

func save_order() -> int:
	return 65

func save_key() -> StringName:
	return &"suit"

func get_save_data() -> Dictionary:
	# The hold is a clock, so it is real state rather than something re-derivable
	# from the station. The suit itself is too: which side of a change a save
	# landed on is not recoverable from anything else.
	return {"suited": suited, "hold_hours": _hold_remaining}

func load_save_data(data: Dictionary) -> void:
	# A missing block (a pre-WI-67 save) leaves `suited` at its default of true and
	# the hold at zero, and the first tick decides: Tier 1 changes nothing, and at
	# Tier 2+ crew in habitable rooms queue a trip to an airlock.
	suited = bool(data.get("suited", true))
	_hold_remaining = float(data.get("hold_hours", 0.0))
