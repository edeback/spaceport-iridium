extends GutTest

## WI-75 §3: [DoorMotion], the door as state rather than as its sprite's playback
## head, and [PathHookResult], the verdict a path hook returns instead of
## awaiting.
##
## The door's timing rules are the ones the sprite-driven doors had ("same open,
## same hold, same close"), so each is pinned here: a full swing takes the
## animation's length, an open door holds and then closes itself, a request for
## the way it is already going changes nothing, and one for the other way turns it
## round where it stands. The number [method DoorMotion.request] returns is how
## long a pawn waits at the door, so it is checked against the door actually
## getting there - including at 4x, where one long frame must land exactly where
## many short ones would.

const TRAVEL: float = 1.0
const HOLD: float = 0.4

func _door(hold: float = HOLD) -> DoorMotion:
	return DoorMotion.make(TRAVEL, hold)

## Ticks `seconds` in `frames` equal slices.
func _run(door: DoorMotion, seconds: float, frames: int = 60) -> void:
	for index: int in frames:
		door.tick(seconds / frames)

# --- the hook verdict -----------------------------------------------------------

func test_a_wait_of_nothing_is_no_wait() -> void:
	assert_eq(PathHookResult.wait(0.0).kind, PathHookResult.Kind.CONTINUE,
		"an already-open door must not park the pawn for a frame")
	assert_eq(PathHookResult.wait(-1.0).kind, PathHookResult.Kind.CONTINUE)
	var result: PathHookResult = PathHookResult.wait(0.75)
	assert_eq(result.kind, PathHookResult.Kind.WAIT)
	assert_almost_eq(result.seconds, 0.75, 0.0001)

func test_the_other_verdicts_carry_no_time() -> void:
	assert_eq(PathHookResult.proceed().kind, PathHookResult.Kind.CONTINUE)
	assert_eq(PathHookResult.taken_over().kind, PathHookResult.Kind.TAKEN_OVER)
	assert_eq(PathHookResult.fail().kind, PathHookResult.Kind.FAIL)

# --- a swing --------------------------------------------------------------------

func test_a_shut_door_opens_in_one_swing() -> void:
	var door: DoorMotion = _door()
	assert_true(door.is_at_rest(), "a new door is shut and still")
	assert_almost_eq(door.request(true), TRAVEL, 0.0001, "the wait is the swing")
	_run(door, TRAVEL * 0.5, 30)
	assert_almost_eq(door.openness, 0.5, 0.001, "half way at half time")
	_run(door, TRAVEL * 0.5, 30)
	assert_true(door.is_open(), "open on time")

func test_an_open_door_holds_and_then_closes_itself() -> void:
	var door: DoorMotion = _door()
	door.request(true)
	door.tick(TRAVEL)
	assert_true(door.is_open())
	assert_almost_eq(door.hold_left, HOLD, 0.0001, "the hold starts the moment it is fully open")
	door.tick(HOLD * 0.5)
	assert_true(door.is_open(), "still held")
	door.tick(HOLD * 0.5 + TRAVEL)
	assert_true(door.is_at_rest(), "then it shuts itself, one swing later")

func test_a_door_with_no_hold_stays_open() -> void:
	var door: DoorMotion = _door(-1.0)
	door.request(true)
	door.tick(TRAVEL * 10.0)
	assert_true(door.is_open())
	assert_false(door.is_at_rest(), "open is not at rest - a save has to carry it")
	assert_false(door.needs_tick(), "but nothing is left to run")

# --- requests while it moves ----------------------------------------------------

func test_asking_an_opening_door_to_open_waits_out_the_rest() -> void:
	var door: DoorMotion = _door()
	door.request(true)
	door.tick(0.3)
	assert_almost_eq(door.request(true), 0.7, 0.0001, "the remainder, not a fresh swing")
	assert_eq(door.direction, 1)

func test_asking_an_open_held_door_to_open_leaves_the_hold_running() -> void:
	var door: DoorMotion = _door()
	door.request(true)
	door.tick(TRAVEL + 0.1)
	assert_almost_eq(door.request(true), 0.0, 0.0001, "no wait at an open door")
	assert_almost_eq(door.hold_left, HOLD - 0.1, 0.0001,
		"and the hold is not restarted - the door closes when it always would have")

func test_a_closing_door_turns_round_where_it_is() -> void:
	var door: DoorMotion = _door()
	door.request(true)
	door.tick(TRAVEL + HOLD + 0.25)
	assert_eq(door.direction, -1, "closing")
	assert_almost_eq(door.openness, 0.75, 0.0001)
	assert_almost_eq(door.request(true), 0.25, 0.0001,
		"reopening from three-quarters open takes a quarter swing")
	assert_eq(door.direction, 1)

func test_asking_a_door_to_close_cancels_its_hold() -> void:
	var door: DoorMotion = _door()
	door.request(true)
	door.tick(TRAVEL)
	assert_almost_eq(door.request(false), TRAVEL, 0.0001, "a full swing shut")
	assert_eq(door.hold_left, 0.0)
	door.tick(TRAVEL)
	assert_true(door.is_at_rest())

# --- scheduled requests (the linked airlock) ------------------------------------

func test_a_scheduled_open_waits_for_its_turn() -> void:
	var door: DoorMotion = _door()
	assert_almost_eq(door.request(true, 0.6), 0.6 + TRAVEL, 0.0001,
		"shut now, and it only starts to swing at 0.6")
	door.tick(0.5)
	assert_eq(door.openness, 0.0, "nothing moves before its time")
	door.tick(0.1 + TRAVEL)
	assert_true(door.is_open(), "open when the wait said it would be")

func test_a_scheduled_request_sees_the_door_as_it_will_be() -> void:
	# The door is open and will close itself at 1.4; an open asked for at 1.9
	# finds it half shut and needs only half a swing.
	var door: DoorMotion = _door()
	door.request(true)
	door.tick(TRAVEL)
	assert_almost_eq(door.request(true, 0.9), 0.9 + 0.5, 0.0001)

func test_the_wait_a_request_returns_is_when_the_door_gets_there() -> void:
	var door: DoorMotion = _door()
	var wait: float = door.request(true, 0.37)
	assert_almost_eq(wait, 0.37 + TRAVEL, 0.0001)
	# A hair past the wait, since 97 float slices need not sum to it exactly; the
	# hold that follows keeps the door open well past the hair.
	_run(door, wait + 0.0001, 97)
	assert_true(door.is_open(), "the pawn's wait and the door end together")

# --- time splits ----------------------------------------------------------------

func test_one_long_frame_lands_where_many_short_ones_do() -> void:
	var fast: DoorMotion = _door()
	var slow: DoorMotion = _door()
	fast.request(true)
	slow.request(true)
	fast.request(false, 1.7)
	slow.request(false, 1.7)
	fast.tick(1.23)
	_run(slow, 1.23, 200)
	assert_almost_eq(fast.openness, slow.openness, 0.0001)
	assert_eq(fast.direction, slow.direction)
	assert_almost_eq(fast.hold_left, slow.hold_left, 0.0001)
	fast.tick(2.0)
	_run(slow, 2.0, 50)
	assert_true(fast.is_at_rest())
	assert_true(slow.is_at_rest())

# --- drawing it -----------------------------------------------------------------

func test_the_frame_follows_openness() -> void:
	assert_eq(DoorMotion.frame_for(0.0, 5), 0, "shut is the first frame")
	assert_eq(DoorMotion.frame_for(0.19, 5), 0)
	assert_eq(DoorMotion.frame_for(0.2, 5), 1)
	assert_eq(DoorMotion.frame_for(0.99, 5), 4)
	assert_eq(DoorMotion.frame_for(1.0, 5), 4, "open is the last frame")
	assert_eq(DoorMotion.frame_for(0.5, 1), 0, "a one-frame door never errors")

func test_a_swing_lasts_as_long_as_its_animation() -> void:
	var frames := SpriteFrames.new()
	var texture := PlaceholderTexture2D.new()
	frames.add_animation(&"open")
	frames.set_animation_speed(&"open", 5.0)
	for index: int in 5:
		frames.add_frame(&"open", texture)
	assert_almost_eq(DoorMotion.animation_seconds(frames, &"open"), 1.0, 0.0001,
		"the airlock's five frames at five a second")
	frames.set_frame(&"open", 2, texture, 3.0)
	assert_almost_eq(DoorMotion.animation_seconds(frames, &"open"), 1.4, 0.0001,
		"a longer frame counts for its duration")
	assert_eq(DoorMotion.animation_seconds(frames, &"missing"), 0.0)

# --- persistence ----------------------------------------------------------------

func test_a_door_at_rest_saves_nothing() -> void:
	assert_eq(_door().to_dict(), {})

func test_a_door_round_trips_mid_swing_through_json() -> void:
	var door: DoorMotion = _door()
	door.request(true)
	door.tick(TRAVEL + 0.15)
	door.request(false, 0.05)
	door.request(true, 0.3)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(door.to_dict()))
	var loaded: DoorMotion = _door()
	loaded.load_dict(saved)
	assert_almost_eq(loaded.openness, door.openness, 0.0001, "as open")
	assert_eq(loaded.direction, door.direction, "going the same way")
	assert_almost_eq(loaded.hold_left, door.hold_left, 0.0001, "with the same hold left")
	var queue: Array = loaded.to_dict().get("queue", [])
	assert_eq(queue.size(), 2, "and both requests still pending")
	door.tick(0.8)
	loaded.tick(0.8)
	assert_almost_eq(loaded.openness, door.openness, 0.0001, "and it carries on the same way")
	assert_eq(loaded.direction, door.direction)
