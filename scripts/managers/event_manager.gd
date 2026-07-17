class_name EventManager
extends Node

## Random events (WI-13): loads EventData definitions from data/events/,
## paces natural rolls off the game calendar, and owns the runtime state -
## per-event cooldowns, the pending-card queue, and station-wide timed
## happiness effects (so late hires get them and durations survive saves).
##
## Pacing runs on calendar signals (cycle_changed / hour_changed), which only
## fire from TimeManager's sim loop - so events can't roll while paused by
## construction (WI-13 edge case: verified, no wall-clock timers here).

const EVENT_PATH: String = "res://data/events/"

## Average cycles between natural events. Rolls happen twice per cycle
## (cycle start + one random mid-cycle hour); each roll's chance derives
## from this so the long-run rate matches.
@export var expected_cycles_between_events: float = 1.5
## No natural event fires before this cycle - let a new station breathe.
@export var first_event_cycle: int = 2

var _events: Dictionary[StringName, EventData] = {}
## event id -> cycle it last fired (cooldown bookkeeping).
var _fired_cycle: Dictionary[StringName, int] = {}
## Events waiting to be shown as cards, front = current. Notification-only
## events never enter this queue.
var pending_events: Array[EventData] = []
## Station-wide happiness effects: id -> {"value": float, "remaining": float
## game-hours}. Mirrors the per-pawn modifiers so we can re-apply to new
## hires and rebuild after load.
var _happiness_effects: Dictionary[StringName, Dictionary] = {}
## The hour (this cycle) of the mid-cycle roll, -1 once spent.
var _midcycle_roll_hour: int = -1

func _ready() -> void:
	Global.event_manager = self
	_load_events()
	Global.time_manager.cycle_changed.connect(_on_cycle_changed)
	Global.time_manager.hour_changed.connect(_on_hour_changed)
	SignalBus.crew_hired.connect(_on_crew_hired)
	_roll_midcycle_hour()

func _process(delta: float) -> void:
	var sim_hours: float = Global.time_manager.scale(delta) / TimeManager.SECONDS_PER_HOUR
	if sim_hours <= 0.0:
		return
	_tick_happiness_effects(sim_hours)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_fire_event"):
		get_viewport().set_input_as_handled()
		if not try_fire_random_event(true):
			SignalBus.station_alert.emit("Debug: no eligible event to fire")

func _load_events() -> void:
	for file_path: String in ResourceScanner.scan_paths(EVENT_PATH):
		var res: Resource = ResourceLoader.load(file_path)
		if res is EventData:
			var event := res as EventData
			if event.id == &"":
				push_warning("EventData with empty id, skipping: " + file_path)
				continue
			if not event.has_free_choice():
				push_warning("Event '%s' has no always-available choice - its card can soft-lock" % event.id)
			_events[event.id] = event

# --- pacing & selection ---------------------------------------------------------

func _on_cycle_changed(_cycle: int) -> void:
	_roll_midcycle_hour()
	_natural_roll()

func _on_hour_changed(hour: int) -> void:
	if hour == _midcycle_roll_hour:
		_midcycle_roll_hour = -1
		_natural_roll()

func _roll_midcycle_hour() -> void:
	_midcycle_roll_hour = randi_range(2, TimeManager.HOURS_PER_CYCLE - 2)

## Two rolls per cycle, each with chance 1/(2 * expected interval) - long-run
## average of one event per expected_cycles_between_events. All-ineligible
## rolls are silent no-ops.
func _natural_roll() -> void:
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

func fire_event(event: EventData) -> void:
	_fired_cycle[event.id] = Global.time_manager.cycle
	if event.choices.is_empty():
		# Notification-only: apply immediately, no card, alert strip only.
		for effect: EventEffect in event.auto_effects:
			if effect != null:
				effect.apply(event)
		SignalBus.station_alert.emit(event.body)
		SignalBus.event_triggered.emit(event)
		return
	# Card events queue - two simultaneous fires show sequentially (edge case).
	pending_events.append(event)
	SignalBus.event_triggered.emit(event)

func peek_pending() -> EventData:
	return pending_events.front() if not pending_events.is_empty() else null

## The event card calls this with the picked choice; returns false if the
## cost can't be paid (button should have been disabled, but re-check - the
## sim may have spent credits while the card sat open unpaused... it can't,
## the card pauses, but cheap insurance).
func resolve_choice(event: EventData, choice: EventChoice) -> bool:
	if choice == null or not choice.can_afford():
		return false
	choice.withdraw_cost()
	for effect: EventEffect in choice.effects:
		if effect != null:
			effect.apply(event)
	pending_events.erase(event)
	return true

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
## PawnNeedsComponent. Kept in sync because both consume the same sim-hours.
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
	_happiness_effects.clear()
	for entry: Dictionary in data.get("happiness_effects", []):
		apply_station_happiness(StringName(String(entry.get("id", ""))),
			float(entry.get("value", 0.0)), float(entry.get("remaining", 0.0)))
	Global.market_manager.load_supply_modifiers_save(data.get("supply_modifiers", []))
	_midcycle_roll_hour = int(data.get("midcycle_hour", -1))
