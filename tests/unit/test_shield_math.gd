extends GutTest

## Unit tests for WI-32 shield math: the pure ShieldMath selection + hysteresis.
## Covers the overlap rule (most-charged online bubble covering the impact wins),
## coverage/online gating, and the capacitor re-engage hysteresis. No live nodes.

func _bubble(center: Vector2, radius: float, charge: float, online: bool = true) -> ShieldMath.Bubble:
	return ShieldMath.Bubble.new(center, radius, charge, online)

# --- select_absorber ----------------------------------------------------------

func test_no_bubbles_no_absorber() -> void:
	assert_eq(ShieldMath.select_absorber([], Vector2(10, 10)), -1, "empty -> no absorber")

func test_covering_online_bubble_absorbs() -> void:
	var bubbles := [_bubble(Vector2.ZERO, 100.0, 50.0)]
	assert_eq(ShieldMath.select_absorber(bubbles, Vector2(30, 0)), 0, "hit inside radius is absorbed")

func test_impact_outside_radius_leaks_through() -> void:
	var bubbles := [_bubble(Vector2.ZERO, 100.0, 50.0)]
	assert_eq(ShieldMath.select_absorber(bubbles, Vector2(150, 0)), -1, "hit outside radius -> module takes it")

func test_offline_bubble_does_not_absorb() -> void:
	var bubbles := [_bubble(Vector2.ZERO, 100.0, 50.0, false)]
	assert_eq(ShieldMath.select_absorber(bubbles, Vector2(10, 0)), -1, "offline bubble leaks the hit")

func test_empty_bubble_does_not_absorb() -> void:
	var bubbles := [_bubble(Vector2.ZERO, 100.0, 0.0, true)]
	assert_eq(ShieldMath.select_absorber(bubbles, Vector2(10, 0)), -1, "zero-charge bubble leaks the hit")

func test_overlap_most_charged_wins() -> void:
	# Both cover the impact; the fuller capacitor eats it (deterministic rule).
	var bubbles := [
		_bubble(Vector2.ZERO, 200.0, 30.0),
		_bubble(Vector2(50, 0), 200.0, 120.0),
	]
	assert_eq(ShieldMath.select_absorber(bubbles, Vector2(40, 0)), 1, "most-charged covering bubble absorbs")

func test_overlap_only_one_covers() -> void:
	# The fuller bubble does NOT cover the impact; the covering one still absorbs.
	var bubbles := [
		_bubble(Vector2.ZERO, 60.0, 20.0),
		_bubble(Vector2(500, 0), 60.0, 200.0),
	]
	assert_eq(ShieldMath.select_absorber(bubbles, Vector2(10, 0)), 0, "coverage gates before charge")

func test_charge_tie_resolves_to_earliest() -> void:
	var bubbles := [
		_bubble(Vector2.ZERO, 200.0, 80.0),
		_bubble(Vector2(20, 0), 200.0, 80.0),
	]
	assert_eq(ShieldMath.select_absorber(bubbles, Vector2(10, 0)), 0, "ties pick the earliest index")

# --- segment_circle_entry (beam terminates on the bubble) ---------------------

func test_beam_enters_bubble_at_surface() -> void:
	# From (-200,0) to the centre (0,0), radius 100: crosses the surface at x=-100,
	# i.e. halfway along the 200px segment.
	var t: float = ShieldMath.segment_circle_entry(Vector2(-200, 0), Vector2.ZERO, Vector2.ZERO, 100.0)
	assert_almost_eq(t, 0.5, 0.001, "entry crossing is the bubble surface")
	var hit: Vector2 = Vector2(-200, 0).lerp(Vector2.ZERO, t)
	assert_almost_eq(hit.x, -100.0, 0.001, "beam ends on the near edge of the bubble")

func test_beam_missing_bubble_returns_negative() -> void:
	# A segment that never comes within the radius.
	var t: float = ShieldMath.segment_circle_entry(Vector2(-200, -200), Vector2(200, -200), Vector2.ZERO, 100.0)
	assert_eq(t, -1.0, "a segment that misses the bubble has no entry")

# --- next_online (hysteresis) -------------------------------------------------

func test_empty_capacitor_goes_offline() -> void:
	assert_false(ShieldMath.next_online(true, 0.0, 200.0, 0.25), "0 charge always offline")

func test_online_stays_online_with_any_charge() -> void:
	assert_true(ShieldMath.next_online(true, 5.0, 200.0, 0.25), "a live shield keeps absorbing")

func test_offline_waits_for_reengage_threshold() -> void:
	# 40/200 = 0.2 < 0.25 re-engage fraction: still offline.
	assert_false(ShieldMath.next_online(false, 40.0, 200.0, 0.25), "below re-engage stays offline")
	# 60/200 = 0.3 >= 0.25: comes back online.
	assert_true(ShieldMath.next_online(false, 60.0, 200.0, 0.25), "past re-engage comes back online")
