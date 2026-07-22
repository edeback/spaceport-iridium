extends GutTest

## Unit tests for WI-35's pure overlay color mapping (OverlayPalette). All
## static, no Global / nodes / live world - just value -> Color.

# --- untinted / strength convention ------------------------------------------

func test_untinted_is_transparent() -> void:
	assert_eq(OverlayPalette.untinted().a, 0.0, "untinted leaves the module rendering normally")

func test_tinted_colors_carry_strength_alpha() -> void:
	# A tint must be visible but not fully opaque (plating shows through).
	assert_almost_eq(OverlayPalette.power_color(true).a, OverlayPalette.TINT, 0.001, "tint uses TINT alpha")
	assert_gt(OverlayPalette.TINT, 0.0, "strength positive")
	assert_lt(OverlayPalette.TINT, 1.0, "strength leaves detail visible")

# --- gradient3 ---------------------------------------------------------------

func test_gradient3_endpoints_and_midpoint() -> void:
	var low := Color(1, 0, 0)
	var mid := Color(0, 1, 0)
	var high := Color(0, 0, 1)
	var g0 := OverlayPalette.gradient3(0.0, low, mid, high)
	var g5 := OverlayPalette.gradient3(0.5, low, mid, high)
	var g1 := OverlayPalette.gradient3(1.0, low, mid, high)
	assert_almost_eq(g0.r, 1.0, 0.001, "t=0 is the low stop")
	assert_almost_eq(g5.g, 1.0, 0.001, "t=0.5 is the mid stop")
	assert_almost_eq(g1.b, 1.0, 0.001, "t=1 is the high stop")

func test_gradient3_clamps_out_of_range() -> void:
	var low := Color(1, 0, 0)
	var high := Color(0, 0, 1)
	var below := OverlayPalette.gradient3(-5.0, low, low, high)
	var above := OverlayPalette.gradient3(5.0, low, high, high)
	assert_almost_eq(below.r, 1.0, 0.001, "t below 0 clamps to low")
	assert_almost_eq(above.b, 1.0, 0.001, "t above 1 clamps to high")

# --- power -------------------------------------------------------------------

func test_power_powered_is_green_unpowered_is_red() -> void:
	var on := OverlayPalette.power_color(true)
	var off := OverlayPalette.power_color(false)
	assert_gt(on.g, on.r, "powered leans green")
	assert_gt(off.r, off.g, "unpowered leans red")

# --- o2 ----------------------------------------------------------------------

func test_o2_low_is_red_high_is_green() -> void:
	var starved := OverlayPalette.o2_color(OverlayPalette.O2_RED_AT - 10.0)
	var rich := OverlayPalette.o2_color(OverlayPalette.O2_GREEN_AT + 20.0)
	assert_gt(starved.r, starved.g, "below the red threshold reads red")
	assert_gt(rich.g, rich.r, "comfortably breathable reads green")

func test_o2_is_monotonic_toward_green() -> void:
	# As O2 climbs from red-at to green-at, the green channel never decreases.
	var prev_g: float = -1.0
	for i in range(0, 11):
		var partial: float = OverlayPalette.O2_RED_AT + (OverlayPalette.O2_GREEN_AT - OverlayPalette.O2_RED_AT) * (float(i) / 10.0)
		var g: float = OverlayPalette.o2_color(partial).g
		assert_gte(g, prev_g - 0.001, "green channel rises with O2")
		prev_g = g

# --- integrity ---------------------------------------------------------------

func test_integrity_full_green_low_red() -> void:
	var full := OverlayPalette.integrity_color(1.0, false)
	var wrecked := OverlayPalette.integrity_color(0.05, false)
	assert_gt(full.g, full.r, "full HP reads green")
	assert_gt(wrecked.r, wrecked.g, "near-zero HP reads red")

func test_integrity_undamaged_truss_untinted() -> void:
	assert_eq(OverlayPalette.integrity_color(1.0, true).a, 0.0, "a pristine truss shows nothing")

func test_integrity_damaged_truss_is_distinct_from_low_hp_module() -> void:
	var truss := OverlayPalette.integrity_color(0.3, true)
	var module := OverlayPalette.integrity_color(0.3, false)
	assert_gt(truss.a, 0.0, "damaged truss is tinted")
	# Distinct hue: the wreck orange has a much higher green channel than the
	# red a low-HP module shows at the same fraction.
	assert_true(not truss.is_equal_approx(module), "truss wreckage is a different color than a hurt module")

# --- vibration ---------------------------------------------------------------

func test_vibration_zero_is_untinted() -> void:
	assert_eq(OverlayPalette.vibration_color(0.0, 3.0).a, 0.0, "no vibration = no tint")
	assert_eq(OverlayPalette.vibration_color(1.0, 0.0).a, 0.0, "a zero reference guards against divide-by-zero")

func test_vibration_high_is_red_low_is_green() -> void:
	var high := OverlayPalette.vibration_color(3.0, 3.0)
	var low := OverlayPalette.vibration_color(0.2, 3.0)
	assert_gt(high.r, high.g, "high vibration reads red")
	assert_gt(low.g, low.r, "faint vibration still reads green (tolerable)")

# --- logistics ---------------------------------------------------------------

func test_logistics_sink_warm_source_cool() -> void:
	var sink := OverlayPalette.logistics_color(99)
	var source := OverlayPalette.logistics_color(-99)
	assert_gt(sink.r, sink.b, "a high-priority sink reads warm")
	assert_gt(source.b, source.r, "a negative-priority source reads cool")

func test_logistics_neutral_is_greyish() -> void:
	var neutral := OverlayPalette.logistics_color(0)
	assert_almost_eq(neutral.r, neutral.b, 0.1, "zero priority is roughly neutral grey (not strongly warm or cool)")
	assert_gt(neutral.a, 0.0, "storage is still tinted at neutral priority")
