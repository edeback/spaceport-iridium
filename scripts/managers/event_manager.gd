class_name EventManager
extends Node

## Random events (WI-13, rewritten in WI-62): loads [EventData] definitions from
## `data/events/`, paces natural rolls off the game calendar, and owns the runtime
## state - per-event cooldowns, the pending queue, and station-wide timed
## happiness effects (so late hires get them and durations survive saves).
##
## Pacing runs on calendar signals (cycle_changed / hour_changed), which only
## fire from [TimeManager]'s sim loop - so events can't roll while paused by
## construction (WI-13 edge case: verified, no wall-clock timers here).
##
## **What WI-62 took out of this file:** the `choices.is_empty()` branch, the
## resolve-a-choice entry point, and everything that knew what an event *does*.
## An event now hands its dialogue to [DialogueRunner] and the conversation is the
## whole of its behaviour. A cue with no dialogue lines runs headlessly, which is
## why "notification event" needs no code here at all.
##
## **What WI-62 added:** the scheduled-event drain. `story.queue_event(id, hours)`
## promises a follow-up, and it fires **bypassing the roll, the cooldown and
## `min_cycle`** - it was already decided by a choice the player made.


## Average cycles between natural events. Rolls happen twice per cycle
## (cycle start + one random mid-cycle hour); each roll's chance derives
## from this so the long-run rate matches.
@export var expected_cycles_between_events: float = 1.5
## No natural event fires before this cycle - let a new station breathe.
@export var first_event_cycle: int = 2

var _events: Dictionary[StringName, EventData] = {}
## event id -> cycle it last fired (cooldown bookkeeping).
var _fired_cycle: Dictionary[StringName, int] = {}
## Events waiting to be run as conversations, front = current.
var pending_events: Array[EventData] = []
## Station-wide happiness effects: id -> {"value": float, "remaining": float
## game-hours}. Mirrors the per-pawn modifiers so we can re-apply to new
## hires and rebuild after load.
var _happiness_effects: Dictionary[StringName, Dictionary] = {}
## The hour (this cycle) of the mid-cycle roll, -1 once spent.
var _midcycle_roll_hour: int = -1

func _ready() -> void:
	Global.event_manager = self
	# After pawns: station-wide happiness effects re-apply to the loaded crew.
	# After market: supply shocks re-register without re-snapping stock.
	SaveManager.register_section(&"events", SaveManager.SECTION_ORDER[&"events"], get_save_data, load_save_data)
	_load_events()
	Global.time_manager.cycle_changed.connect(_on_cycle_changed)
	Global.time_manager.hour_changed.connect(_on_hour_changed)
	Global.time_manager.slow_tick.connect(_on_slow_tick)
	SignalBus.crew_hired.connect(_on_crew_hired)
	_roll_midcycle_hour()

## Hands the slot back (WI-71 §7). Godot 4.7 reports a freed object as `== null`,
## so the guards around the game already take their null branch after a Quit to
## Menu - but `is_instance_valid(Global.event_manager)` and the debugger both lie until
## the slot is actually cleared. `== self` because a second scene can register
## before this one leaves.
func _exit_tree() -> void:
	if Global.event_manager == self:
		Global.event_manager = null


## The happiness countdown rides the slow tick rather than the frame (WI-74 §6,
## F37), so it pauses and scales like every other periodic system.
func _on_slow_tick(interval: float) -> void:
	_tick_happiness_effects(interval / TimeManager.SECONDS_PER_HOUR)

func _unhandled_input(event: InputEvent) -> void:
	# A developer key, not a player one (WI-68 F5): false only in a release
	# export, so the editor and debug exports keep it. Panku is already off there.
	if not OS.is_debug_build():
		return
	if event.is_action_pressed("debug_fire_event"):
		get_viewport().set_input_as_handled()
		if not try_fire_random_event(true):
			SignalBus.station_alert.emit("Debug: no eligible event to fire")

func _load_events() -> void:
	for file_path: String in ContentPaths.scan(ContentPaths.EVENTS):
		var res: Resource = ResourceLoader.load(file_path)
		if res is EventData:
			var event := res as EventData
			if not ContentPaths.accept_id(event.id, file_path, "EventData"):
				continue
			# A typo'd cue is an event that fires and does nothing, forever,
			# silently - the worst failure this design can produce. It is the one
			# thing checked eagerly, so it surfaces on startup instead of never.
			var problem: String = event.script_problem()
			if not problem.is_empty():
				push_warning("Event '%s' %s - it will never run" % [event.id, problem])
				continue
			_events[event.id] = event

# --- pacing & selection ---------------------------------------------------------

func _on_cycle_changed(_cycle: int) -> void:
	_roll_midcycle_hour()
	_natural_roll()

func _on_hour_changed(hour: int) -> void:
	_drain_scheduled()
	if hour == _midcycle_roll_hour:
		_midcycle_roll_hour = -1
		_natural_roll()

func _roll_midcycle_hour() -> void:
	_midcycle_roll_hour = randi_range(2, TimeManager.HOURS_PER_CYCLE - 2)

## Two rolls per cycle, each with chance 1/(2 * expected interval) - long-run
## average of one event per expected_cycles_between_events. All-ineligible
## rolls are silent no-ops.
##
## **Not while a load is being applied** (WI-62, fixing a bug WI-38's audit
## logged): [SaveManager] restores sections in order and events are section 130 of
## 17, so a `cycle_changed` fired during restoration used to roll an event against
## a cooldown table that had not come back yet. That was a stray card before; with
## chaining it can drop a chapter-two event into a save that never saw chapter one.
func _natural_roll() -> void:
	if SaveManager.is_loading():
		return
	if Global.time_manager.cycle < first_event_cycle:
		return
	if expected_cycles_between_events <= 0.0:
		return
	if randf() >= 1.0 / (2.0 * expected_cycles_between_events):
		return
	try_fire_random_event(false)

## Weight-based pick among eligible events. ignore_pacing (debug) still
## respects conditions/cooldowns - it only skips the random chance gate.
func try_fire_random_event(_ignore_pacing: bool) -> bool:
	var eligible: Array[EventData] = []
	var total_weight: float = 0.0
	var cycle: int = Global.time_manager.cycle
	for event: EventData in _events.values():
		if not event.is_eligible(cycle):
			continue
		if _fired_cycle.has(event.id) and cycle < _fired_cycle[event.id] + event.cooldown_cycles:
			continue
		if pending_events.has(event):
			continue
		if event.weight <= 0.0:
			continue
		eligible.append(event)
		total_weight += event.weight
	if eligible.is_empty():
		return false
	var roll: float = randf() * total_weight
	var cumulative: float = 0.0
	for event: EventData in eligible:
		cumulative += event.weight
		if roll <= cumulative:
			fire_event(event)
			return true
	fire_event(eligible.back())
	return true

# --- scheduled follow-ups (WI-62) -----------------------------------------------

## Fires whatever a past conversation promised for now.
##
## The roll, the cooldown and `min_cycle` are all skipped: the player already
## chose this, and re-litigating eligibility would drop chapter two on the floor.
## The event's own `conditions` still apply, because those describe a world the
## event needs in order to make sense - and when they fail the player is told the
## moment passed rather than being left waiting for a follow-up that silently
## evaporated.
func _drain_scheduled() -> void:
	if SaveManager.is_loading() or Global.story_state == null:
		return
	var time: TimeManager = Global.time_manager
	var due: Array[StringName] = Global.story_state.schedule.drain_due(time.cycle, time.hour)
	for event_id: StringName in due:
		var event: EventData = _events.get(event_id)
		if event == null:
			# A mod was removed, or the id was a typo. Dropping it is the only
			# option; saying so is the difference between a bug and a mystery.
			push_warning("EventManager: scheduled event '%s' no longer exists" % event_id)
			continue
		if not event.conditions_met():
			AlertManager.raise_alert(StringName("event_missed_%s" % event_id),
				AlertData.Priority.LOW, "The moment passed",
				"%s came to nothing." % event.title)
			continue
		fire_event(event)

# --- firing & resolution ----------------------------------------------------------

## Debug/console entry point: fire a specific event now, ignoring pacing,
## conditions, and cooldowns.
func fire_event_by_id(id: StringName) -> bool:
	var event: EventData = _events.get(id)
	if event == null:
		push_warning("Unknown event id: " + String(id))
		return false
	fire_event(event)
	return true

## Every known event id, for the cheat console's completion and the content sweep.
func event_ids() -> Array[StringName]:
	return _events.keys()

func event_by_id(id: StringName) -> EventData:
	return _events.get(id)

## The sender a logged event is filed under (WI-57). Events have no authored
## issuer field, so this is honest rather than invented - the station's own
## systems noticed something. A conversation that wants a *named* sender posts its
## own transmission with `station.transmit(...)`.
const EVENT_SENDER: String = "Station log"

func fire_event(event: EventData) -> void:
	_fired_cycle[event.id] = Global.time_manager.cycle
	pending_events.append(event)
	# **The conversation is not a transmission** (WI-57 edge case) and must not be
	# routed through the log as one - it is a modal the player answers, not
	# something to read later. The *record* that it happened is worth keeping, so
	# every event logs its title and body the moment it fires.
	_log_event(event)
	SignalBus.event_triggered.emit(event)
	_run_next()

## Both halves of an event's announcement (WI-57).
##
## The alert stays a plain [signal SignalBus.station_alert] - LOW, transient, and
## exactly what fifty other sites use for "something happened, mention it" - and
## the durable half becomes a Comms row, so a player who was mid-placement when a
## micrometeorite hit can still find out what it said.
func _log_event(event: EventData) -> void:
	SignalBus.station_alert.emit(event.body)
	if Global.alert_manager == null:
		return
	var title: String = event.title if not event.title.is_empty() else "Station event"
	Global.alert_manager.post_transmission(&"event", EVENT_SENDER, title, event.body)

func peek_pending() -> EventData:
	return pending_events.front() if not pending_events.is_empty() else null

## Hands the front of the queue to [DialogueRunner], which queues it behind
## anything already talking. The event leaves `pending_events` only when its
## conversation *ends*, so a save taken mid-conversation restores an event that
## still needs answering.
func _run_next() -> void:
	var event: EventData = peek_pending()
	if event == null or Global.dialogue_runner == null:
		return
	if Global.dialogue_runner.is_busy():
		return
	Global.dialogue_runner.run(event.dialogue, event.cue, [],
		_on_conversation_finished.bind(event))

func _on_conversation_finished(event: EventData) -> void:
	pending_events.erase(event)
	_run_next()

# --- station-wide happiness effects ----------------------------------------------

## Applies a timed happiness modifier to every current crew member and
## remembers it so new hires and save/load stay covered. Re-using an id
## refreshes the duration (same semantics as PawnNeedsComponent).
func apply_station_happiness(id: StringName, value: float, duration_hours: float) -> void:
	_happiness_effects[id] = {"value": value, "remaining": duration_hours}
	for pawn: PawnBase in Global.crew_manager.get_crew():
		_apply_to_pawn(pawn, id, value, duration_hours)

func _apply_to_pawn(pawn: PawnBase, id: StringName, value: float, duration_hours: float) -> void:
	var needs: PawnNeedsComponent = pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
	if needs != null:
		needs.add_modifier(id, value, duration_hours)

func _on_crew_hired(pawn: PawnBase) -> void:
	for id: StringName in _happiness_effects:
		var effect: Dictionary = _happiness_effects[id]
		_apply_to_pawn(pawn, id, float(effect["value"]), float(effect["remaining"]))

## Only the manager-side countdown: each pawn's modifier ticks itself down in
## PawnNeedsComponent. Kept in sync because both consume the same sim-hours - the
## pawns' per frame, this one per slow tick, so this record can outlive theirs by
## one tick. The only reader that notices is a crew member hired in that quarter
## sim-second, who gets the effect's last quarter sim-second.
func _tick_happiness_effects(sim_hours: float) -> void:
	for id: StringName in _happiness_effects.keys():
		var effect: Dictionary = _happiness_effects[id]
		effect["remaining"] = float(effect["remaining"]) - sim_hours
		if float(effect["remaining"]) <= 0.0:
			_happiness_effects.erase(id)

# --- persistence ------------------------------------------------------------------

func get_save_data() -> Dictionary:
	var fired: Dictionary = {}
	for id: StringName in _fired_cycle:
		fired[String(id)] = _fired_cycle[id]
	var pending: Array = []
	for event: EventData in pending_events:
		pending.append(String(event.id))
	var happiness: Array = []
	for id: StringName in _happiness_effects:
		happiness.append({
			"id": String(id),
			"value": float(_happiness_effects[id]["value"]),
			"remaining": float(_happiness_effects[id]["remaining"]),
		})
	return {
		"fired_cycle": fired,
		"pending": pending,
		"happiness_effects": happiness,
		# Market shocks live in MarketManager but persist here so the market
		# save section keeps its original flat stock-map shape.
		"supply_modifiers": Global.market_manager.get_supply_modifiers_save(),
		"midcycle_hour": _midcycle_roll_hour,
	}

## Runs after pawns are loaded (SaveManager section order), so station-wide
## happiness effects can be re-applied to the restored crew - their per-pawn
## modifier entries aren't part of the pawn save.
func load_save_data(data: Dictionary) -> void:
	_fired_cycle.clear()
	for id_str: String in data.get("fired_cycle", {}):
		_fired_cycle[StringName(id_str)] = int(data["fired_cycle"][id_str])
	pending_events.clear()
	for id_str: String in data.get("pending", []):
		var event: EventData = _events.get(StringName(id_str))
		if event != null:
			pending_events.append(event)
			SignalBus.event_triggered.emit(event)
	# Deferred: the load is still in flight, and re-opening the conversation the
	# player was in the middle of has to wait until the rest of the station is
	# back - the mutations it runs read live managers.
	_run_next.call_deferred()
	_happiness_effects.clear()
	for entry: Dictionary in data.get("happiness_effects", []):
		apply_station_happiness(StringName(String(entry.get("id", ""))),
			float(entry.get("value", 0.0)), float(entry.get("remaining", 0.0)))
	Global.market_manager.load_supply_modifiers_save(data.get("supply_modifiers", []))
	_midcycle_roll_hour = int(data.get("midcycle_hour", -1))
