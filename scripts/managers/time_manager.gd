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

## Real seconds per game-hour at 1x speed, so one 24-hour cycle is 4 real minutes.
##
## This was 30 once (a 12-minute cycle) and carried a "temp for testing" note for
## a long time after it had stopped being temporary. Every balance number measured
## since WI-60 - heat rates, the suit hysteresis windows, the soak timings, the job
## durations that feel right at 4x - was taken at 10. Putting 30 back does not
## restore an older tuning, it silently retunes all of those by a factor of three
## (WI-72 §0.2). Change it deliberately, with a re-measure, or not at all.
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

## The **player's own** pause flag - the console's pause button, and the value
## that is saved. A modal that needs the sim stopped must not write this; it
## takes a hold instead (see [method hold_pause]).
var paused: bool = false:
	set(new_paused):
		if paused != new_paused:
			paused = new_paused
			_apply_pause_state()

## Systems currently holding the sim stopped, as a **set** keyed by owner (WI-53).
##
## Before this there were four independent holders - the pause menu, the event
## card, the trader screen and the game-over screen - each of which recorded "was
## it paused before I opened?" and restored that on close. Two of them open at
## once and the pattern breaks: whichever closes second restores a state the
## first one has since changed, and a game the other holder still wants paused
## starts running underneath it. WI-53's critical alerts would have been a fifth.
##
## A set, not a counter: one owner is one hold, so a double `hold_pause` cannot
## leak a hold that never releases. An owner that genuinely needs re-entrancy
## uses two names.
##
## Never saved. It is session state by construction - a scene reload builds a
## fresh manager with no holds, and the player's own [member paused] flag is what
## the save carries.
var _pause_holds: Dictionary[StringName, bool] = {}

## Effective state as last announced, so [signal pause_state_changed] fires on
## changes to the *combined* answer rather than on every write to either half.
var _announced_paused: bool = false

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
	# First: every other system ticks in the loaded calendar, and time's restore
	# announces itself with calendar_restored rather than replaying cycle_changed.
	SaveManager.register_section(&"time", SaveManager.SECTION_ORDER[&"time"], get_save_data, load_save_data)
	# Run before everything that reads sim_delta this frame.
	process_priority = -100
	speed_changed.connect(_resync_sim_animations)
	pause_state_changed.connect(_resync_sim_animations)

## Hands the slot back (WI-71 §7). Godot 4.7 reports a freed object as `== null`,
## so the guards around the game already take their null branch after a Quit to
## Menu - but `is_instance_valid(Global.time_manager)` and the debugger both lie until
## the slot is actually cleared. `== self` because a second scene can register
## before this one leaves.
func _exit_tree() -> void:
	if Global.time_manager == self:
		Global.time_manager = null


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
	return 0.0 if is_paused() else delta * speed

func toggle_paused() -> void:
	paused = not paused

# --- pause holds (WI-53) ------------------------------------------------------

## Whether the sim is stopped, by the player or by anything holding it. This is
## the question every consumer means; [member paused] is only the player's half.
func is_paused() -> bool:
	return paused or not _pause_holds.is_empty()

## Stops the sim on `owner`'s behalf. Idempotent, and composes: the sim runs
## again only when every holder has released and the player is not paused.
##
## The critical-alert latch, the trader screen, the event card, the pause menu
## and the game-over screen are the holders. Use a distinct, greppable name.
func hold_pause(owner: StringName) -> void:
	if _pause_holds.has(owner):
		return
	_pause_holds[owner] = true
	_apply_pause_state()

## Releases `owner`'s hold. Safe to call when it holds nothing, so a close path
## does not have to track whether its open path ran.
func release_pause(owner: StringName) -> void:
	if not _pause_holds.erase(owner):
		return
	_apply_pause_state()

func is_holding_pause(owner: StringName) -> bool:
	return _pause_holds.has(owner)

## Who is currently holding the sim - the probe's assertion, and what a
## "why won't it un-pause" bug report needs.
func pause_holders() -> Array[StringName]:
	var out: Array[StringName] = []
	for owner: StringName in _pause_holds:
		out.append(owner)
	return out

## Announces a change in the *combined* state. Both halves route through here, so
## a hold taken while the player is already paused emits nothing and a player
## un-pause under a live hold emits nothing either - which is what stops the
## console's pause button from flickering between the two sources.
func _apply_pause_state() -> void:
	var effective: bool = is_paused()
	if effective:
		sim_delta = 0.0
	if effective == _announced_paused:
		return
	_announced_paused = effective
	pause_state_changed.emit(effective)

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
	return 0.0 if is_paused() else speed

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
