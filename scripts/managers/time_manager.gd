class_name TimeManager
extends Node

## Owns game time (cycles + hours), pause, and speed. Gameplay systems consume
## time exclusively through this manager so pause/fast-forward affect the whole
## simulation coherently:
##   - per-frame movement/progress: multiply _process deltas by scale(delta)
##   - periodic scans (power balance, storage job posting): subscribe to
##     slow_tick and treat the passed interval as elapsed sim-seconds
##   - calendar events (market drift, shifts): hour_changed / cycle_changed
##   - one-shot waits: `await Global.time_manager.sim_seconds(x)` instead of
##     get_tree().create_timer(x)
## Engine.time_scale and get_tree().paused are deliberately NOT used - they
## distort UI animation and input feel. UI keeps running at real time.

## Real seconds per game-hour at 1x speed. One cycle = 4 real minutes. (temp for testing, was 30 sec per hour/12 real min)
const SECONDS_PER_HOUR: float = 10.0
const HOURS_PER_CYCLE: int = 24
## Hour the game starts at (cycle 1). 06:00 lines up with the future
## shift-A work schedule so a new station wakes at start of day.
const START_HOUR: int = 6
## Sim-seconds between slow_tick emissions (4 Hz sim-time - at higher speeds
## the tick fires proportionally more often in real time).
const SLOW_TICK_INTERVAL: float = 0.25
const SPEED_PRESETS: Array[float] = [0.5, 1.0, 2.0, 4.0]

## Fires once per frame with that frame's scaled delta. Not emitted while
## paused (no zero-delta spam) - awaiting sim_seconds() simply stretches.
signal sim_tick(sim_delta: float)
## Fires every SLOW_TICK_INTERVAL sim-seconds; `interval` is that sim duration.
signal slow_tick(interval: float)
signal hour_changed(hour: int)
signal cycle_changed(cycle: int)
## The calendar was rewritten wholesale by a load - NOT a boundary being crossed.
## Display-only listeners (the clock readout) subscribe to this; anything that does
## calendar *work* must stay on hour_changed/cycle_changed, which a load no longer
## replays (WI-38 A3).
signal calendar_restored(cycle: int, hour: int)
signal pause_state_changed(paused: bool)
signal speed_changed(new_speed: float)

var paused: bool = false:
	set(new_paused):
		if paused != new_paused:
			paused = new_paused
			if paused:
				sim_delta = 0.0
			pause_state_changed.emit(paused)

var speed: float = 1.0:
	set(new_speed):
		new_speed = maxf(new_speed, 0.0)
		if speed != new_speed:
			speed = new_speed
			speed_changed.emit(speed)

## This frame's scaled delta (0 while paused). Prefer scale(delta) in
## _process handlers - it's stateless and immune to process ordering.
var sim_delta: float = 0.0
var total_sim_seconds: float = 0.0
## Hour within the current cycle, 0..HOURS_PER_CYCLE-1.
var hour: int = START_HOUR
## Current cycle ("day"), starting at 1.
var cycle: int = 1

var _hour_progress: float = 0.0
var _slow_tick_progress: float = 0.0

func _ready() -> void:
	Global.time_manager = self
	# Run before everything that reads sim_delta this frame.
	process_priority = -100
	speed_changed.connect(_resync_sim_animations)
	pause_state_changed.connect(_resync_sim_animations)

func _process(delta: float) -> void:
	sim_delta = scale(delta)
	if sim_delta <= 0.0:
		return
	total_sim_seconds += sim_delta
	sim_tick.emit(sim_delta)
	_slow_tick_progress += sim_delta
	while _slow_tick_progress >= SLOW_TICK_INTERVAL:
		_slow_tick_progress -= SLOW_TICK_INTERVAL
		slow_tick.emit(SLOW_TICK_INTERVAL)
	_hour_progress += sim_delta
	# Loop, not if: a huge frame at high speed must not swallow hours.
	while _hour_progress >= SECONDS_PER_HOUR:
		_hour_progress -= SECONDS_PER_HOUR
		hour += 1
		if hour >= HOURS_PER_CYCLE:
			hour = 0
			cycle += 1
			cycle_changed.emit(cycle)
		hour_changed.emit(hour)

## Convert a real _process delta into sim-seconds (0 while paused).
func scale(delta: float) -> float:
	return 0.0 if paused else delta * speed

func toggle_paused() -> void:
	paused = not paused

## Await helper: suspends for `duration` sim-seconds. While paused, no
## sim_ticks fire, so the wait stretches automatically.
func sim_seconds(duration: float) -> void:
	var remaining: float = duration
	while remaining > 0.0:
		remaining -= await sim_tick

## Playback rate for gameplay-blocking animations (doors, walk cycles): the
## sim speed, 0 while paused - so no animation finishes "for free" during a
## pause, and door time scales with fast-forward like everything else (WI-20).
func animation_speed() -> float:
	return 0.0 if paused else speed

## Register a gameplay AnimatedSprite2D whose playback must track sim speed.
## Group-based so freed sprites drop out automatically. Sprites that reparent
## at runtime (pawns) must instead re-apply animation_speed() per-frame -
## group resyncs can't reach a node that's momentarily out of the tree.
func sync_animation(sprite: AnimatedSprite2D) -> void:
	sprite.add_to_group(Groups.SIM_ANIMATION)
	sprite.speed_scale = animation_speed()

## Single Variant-typed handler so both speed_changed(float) and
## pause_state_changed(bool) can share it.
func _resync_sim_animations(_changed: Variant) -> void:
	for node: Node in get_tree().get_nodes_in_group(Groups.SIM_ANIMATION):
		var sprite: AnimatedSprite2D = node as AnimatedSprite2D
		if sprite != null:
			sprite.speed_scale = animation_speed()

## "Cycle 3, 14:00" - shared by the clock UI and any log output.
func format_time() -> String:
	return "Cycle %d, %02d:00" % [cycle, hour]

## Debug/cheat (WI-19): jump the calendar forward `hours` game-hours, firing
## hour_changed/cycle_changed for each step so calendar-driven systems (market
## drift, event rolls, contract deadlines, shifts) advance as if time passed.
## This is a calendar skip, not a replay of the elapsed sim - per-frame progress
## (movement, processing, needs) is NOT ticked for the skipped span.
func advance_hours(hours: int) -> void:
	for _i: int in maxi(hours, 0):
		hour += 1
		if hour >= HOURS_PER_CYCLE:
			hour = 0
			cycle += 1
			cycle_changed.emit(cycle)
		hour_changed.emit(hour)

# --- persistence -------------------------------------------------------------

func get_save_data() -> Dictionary:
	return {
		"cycle": cycle,
		"hour": hour,
		"hour_progress": _hour_progress,
		"total_sim_seconds": total_sim_seconds,
		"speed": speed,
		"paused": paused,
	}

func load_save_data(data: Dictionary) -> void:
	cycle = int(data.get("cycle", 1))
	hour = int(data.get("hour", START_HOUR))
	_hour_progress = float(data.get("hour_progress", 0.0))
	total_sim_seconds = float(data.get("total_sim_seconds", 0.0))
	speed = float(data.get("speed", 1.0))
	paused = bool(data.get("paused", false))
	# Direct field writes above don't pass through the tick loop, so listeners have
	# to be told where the calendar now stands. Deliberately NOT via cycle_changed/
	# hour_changed while a save is being applied (WI-38 A3): those mean "a calendar
	# boundary was just crossed" and three managers do real work on them - the replay
	# let EventManager fire a random event on load, *before* its own section had
	# restored, and left MarketManager/ContractManager correct only by accident of
	# section ordering. advance_hours() still emits both; that path is a real skip.
	calendar_restored.emit(cycle, hour)
	if not SaveManager.is_loading():
		cycle_changed.emit(cycle)
		hour_changed.emit(hour)
