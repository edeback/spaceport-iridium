class_name DoorMotion
extends RefCounted

## One door, as state (WI-75 §3): how open it is, which way it is going, how long
## it has left to stand open before closing itself, and any request waiting to be
## carried out.
##
## Doors used to be their sprite. A behaviour played the "open" animation, awaited
## `animation_finished`, and an `animation_finished` lambda awaited
## `sim_seconds(hold)` before closing it again. That made the door's position the
## sprite's playback head, which nothing could save or ask about, and made every
## wait on it a coroutine. Now this is the door and the sprite only draws it: the
## owner ticks it in sim time and sets the sprite's frame from [member openness].
##
## Pure - no nodes, no Global - so the timing rules below are unit-tested
## (`test_door_motion.gd`), and because it is plain numbers a save carries a door
## half-open with its auto-close half run down.
##
## The rules are the ones the sprite-driven doors had, kept on purpose (the doc's
## "same open, same hold, same close"):
## - a request for the state the door is already heading to changes nothing, and
##   an open door being held keeps its hold running;
## - a request for the other state reverses it from wherever it is;
## - reaching fully open starts the hold, and the hold running out closes it.

## Seconds for a full swing, closed to open (and the same back).
var travel_seconds: float = 1.0
## How long the door stands fully open before closing itself. Negative: it never
## closes on its own.
var hold_seconds: float = -1.0

## 0 closed .. 1 open.
var openness: float = 0.0
## +1 opening, -1 closing, 0 at rest.
var direction: int = 0
## Hold left before an open door closes itself; 0 when not holding.
var hold_left: float = 0.0
## Requests to be carried out later, soonest first: `{"after": seconds, "open": bool}`.
## A linked airlock opens its next door only once the other has shut.
var _scheduled: Array[Dictionary] = []

static func make(travel: float, hold: float = -1.0) -> DoorMotion:
	var motion := DoorMotion.new()
	motion.travel_seconds = maxf(travel, 0.0)
	motion.hold_seconds = hold
	return motion

## The length of `animation` in `frames` at its authored speed - what a swing took
## when the sprite's own playback was the door. Zero for a missing animation.
static func animation_seconds(frames: SpriteFrames, animation: StringName) -> float:
	if frames == null or not frames.has_animation(animation):
		return 0.0
	var fps: float = frames.get_animation_speed(animation)
	if fps <= 0.0:
		return 0.0
	var total: float = 0.0
	for index: int in frames.get_frame_count(animation):
		total += frames.get_frame_duration(animation, index)
	return total / fps

## The frame of a `frame_count`-frame closed-to-open animation that shows
## `door_openness`. Frame 0 is shut, the last frame is fully open.
static func frame_for(door_openness: float, frame_count: int) -> int:
	if frame_count <= 1:
		return 0
	return clampi(floori(door_openness * frame_count), 0, frame_count - 1)

func is_open() -> bool:
	return openness >= 1.0

## Closed, still and with nothing pending: nothing to tick, nothing to save.
func is_at_rest() -> bool:
	return direction == 0 and hold_left <= 0.0 and _scheduled.is_empty() and openness <= 0.0

## Whether ticking can change anything. An open door with no hold is not at rest
## (a save has to carry it) but has nothing to do.
func needs_tick() -> bool:
	return direction != 0 or hold_left > 0.0 or not _scheduled.is_empty()

## Asks for the door open (`open`) or shut, `after` seconds from now, and returns
## how many seconds from now it will be there. That number is what a pawn waits
## at the door: the owner ticks this with the same sim time the pawn's own wait
## counts down, so the two finish together.
func request(open: bool, after: float = 0.0) -> float:
	if after <= 0.0:
		_apply(open)
		return _time_to(open)
	var entry: Dictionary = {"after": after, "open": open}
	var at: int = _scheduled.size()
	for index: int in _scheduled.size():
		if float(_scheduled[index]["after"]) > after:
			at = index
			break
	_scheduled.insert(at, entry)
	# Where the door will be then, with everything already asked of it in between
	# carried out, plus the swing from there.
	var probe: DoorMotion = _clone()
	probe.tick(after)
	return after + probe._time_to(open)

## Advances the door `delta` sim-seconds. Exact for any split of the same time:
## one long frame at 4x lands where four short ones would.
func tick(delta: float) -> void:
	var left: float = delta
	while left > 0.0:
		var step: float = left
		if not _scheduled.is_empty():
			step = minf(step, float(_scheduled[0]["after"]))
		_advance(step)
		left -= step
		for entry: Dictionary in _scheduled:
			entry["after"] = float(entry["after"]) - step
		while not _scheduled.is_empty() and float(_scheduled[0]["after"]) <= 0.0:
			var due: Dictionary = _scheduled.pop_front()
			_apply(bool(due["open"]))

func _apply(open: bool) -> void:
	if open:
		if direction > 0 or (direction == 0 and openness >= 1.0):
			return  # already opening, or open (and a hold keeps running)
		direction = 1
	else:
		if direction < 0 or (direction == 0 and openness <= 0.0):
			return  # already closing, or shut
		direction = -1
	hold_left = 0.0

## Continuous motion only: the swing, the hold, and the close the hold ends in.
func _advance(delta: float) -> void:
	var left: float = delta
	while left > 0.0:
		if direction > 0:
			var to_open: float = (1.0 - openness) * travel_seconds
			if left < to_open:
				openness += left / travel_seconds
				return
			left -= to_open
			openness = 1.0
			direction = 0
			if hold_seconds < 0.0:
				return
			hold_left = hold_seconds
			if hold_left <= 0.0:
				direction = -1
		elif direction < 0:
			var to_shut: float = openness * travel_seconds
			if left < to_shut:
				openness -= left / travel_seconds
				return
			openness = 0.0
			direction = 0
			return
		elif hold_left > 0.0:
			if left < hold_left:
				hold_left -= left
				return
			left -= hold_left
			hold_left = 0.0
			direction = -1
		else:
			return

## Seconds until the door reaches `open` from where it is now, carrying on as it
## is going. Requests still scheduled after that are not counted: they belong to
## whoever made them.
func _time_to(open: bool) -> float:
	if open:
		if openness >= 1.0:
			return 0.0
		return (1.0 - openness) * travel_seconds
	if openness <= 0.0:
		return 0.0
	if direction < 0:
		return openness * travel_seconds
	if hold_left > 0.0:
		return hold_left + openness * travel_seconds
	if direction > 0 and hold_seconds >= 0.0:
		return (1.0 - openness) * travel_seconds + hold_seconds + travel_seconds
	return openness * travel_seconds

func _clone() -> DoorMotion:
	var copy: DoorMotion = DoorMotion.make(travel_seconds, hold_seconds)
	copy.openness = openness
	copy.direction = direction
	copy.hold_left = hold_left
	for entry: Dictionary in _scheduled:
		copy._scheduled.append(entry.duplicate())
	return copy

# --- persistence ----------------------------------------------------------------

## The door's state, or {} at rest. The swing length and the hold are the scene's,
## not the save's, so a rebalanced door loads with its new timing.
func to_dict() -> Dictionary:
	if is_at_rest():
		return {}
	var out: Dictionary = {"open": openness}
	if direction != 0:
		out["dir"] = direction
	if hold_left > 0.0:
		out["hold"] = hold_left
	if not _scheduled.is_empty():
		var queue: Array = []
		for entry: Dictionary in _scheduled:
			queue.append([float(entry["after"]), bool(entry["open"])])
		out["queue"] = queue
	return out

func load_dict(data: Dictionary) -> void:
	openness = clampf(float(data.get("open", 0.0)), 0.0, 1.0)
	direction = signi(int(data.get("dir", 0)))
	hold_left = maxf(float(data.get("hold", 0.0)), 0.0)
	_scheduled.clear()
	for pair: Variant in data.get("queue", []):
		var entry: Array = pair as Array
		if entry == null or entry.size() != 2:
			continue
		_scheduled.append({"after": float(entry[0]), "open": bool(entry[1])})
