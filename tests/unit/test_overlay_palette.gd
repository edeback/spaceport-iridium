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

# --- the legend (WI-54) -------------------------------------------------------
# The Overlays panel prints the active mode's ramp. Every swatch is produced by
# that mode's own colour function rather than named in the legend table, which is
# the whole point: retuning a gradient cannot leave the legend explaining a
# colour the station no longer paints.

const _MODE_KEYS: Array[StringName] = [
	OverlayPalette.MODE_POWER, OverlayPalette.MODE_O2, OverlayPalette.MODE_INTEGRITY,
	OverlayPalette.MODE_VIBRATION, OverlayPalette.MODE_LOGISTICS,
]

func test_every_mode_has_a_legend() -> void:
	for key: StringName in _MODE_KEYS:
		assert_gt(OverlayPalette.legend_stops(key).size(), 1,
			"%s explains itself with more than one stop" % key)

func test_every_legend_stop_is_labelled() -> void:
	for key: StringName in _MODE_KEYS:
		for stop: OverlayPalette.LegendStop in OverlayPalette.legend_stops(key):
			assert_ne(stop.label, "", "%s has no unlabelled swatch" % key)

## The mode functions return the *tint strength* in alpha. A swatch that
## inherited it would render as a different colour from the module it explains.
func test_legend_swatches_are_opaque() -> void:
	for key: StringName in _MODE_KEYS:
		for stop: OverlayPalette.LegendStop in OverlayPalette.legend_stops(key):
			assert_eq(stop.color.a, 1.0, "%s / %s is a solid swatch" % [key, stop.label])

## The load-bearing property: a stop is the paint, not a lookalike.
func test_the_breathable_swatch_is_the_breathable_tint() -> void:
	var stops := OverlayPalette.legend_stops(OverlayPalette.MODE_O2)
	var breathable: OverlayPalette.LegendStop = stops[stops.size() - 1]
	var painted := OverlayPalette.o2_color(OverlayPalette.O2_GREEN_AT)
	assert_almost_eq(breathable.color.r, painted.r, 0.001)
	assert_almost_eq(breathable.color.g, painted.g, 0.001)
	assert_almost_eq(breathable.color.b, painted.b, 0.001)

func test_the_integrity_legend_distinguishes_wreckage_from_a_damaged_module() -> void:
	var stops := OverlayPalette.legend_stops(OverlayPalette.MODE_INTEGRITY)
	var damaged: Color = stops[1].color
	var wreck: Color = stops[stops.size() - 1].color
	assert_ne(damaged, wreck, "wreckage never reads as a low-HP real module")

## Zero field is untinted, so a "silent" stop would be a black square. The note
## covers it instead - see the comment on the vibration branch.
func test_no_legend_stop_is_a_transparent_tint_rendered_solid() -> void:
	for stop: OverlayPalette.LegendStop in OverlayPalette.legend_stops(OverlayPalette.MODE_VIBRATION):
		assert_gt(stop.color.r + stop.color.g + stop.color.b, 0.1,
			"%s is a real colour, not an untinted black" % stop.label)

func test_an_unknown_mode_key_has_no_legend() -> void:
	assert_eq(OverlayPalette.legend_stops(&"").size(), 0, "NONE explains nothing")
	assert_eq(OverlayPalette.legend_stops(&"nonsense").size(), 0)

## The two modes whose story is not entirely a colour ramp say the rest in a
## note; the ones that are pure ramps must not carry a stray sentence.
func test_only_the_modes_with_something_left_to_say_carry_a_note() -> void:
	assert_ne(OverlayPalette.legend_note(OverlayPalette.MODE_O2), "", "the breach pulse is not a colour")
	assert_ne(OverlayPalette.legend_note(OverlayPalette.MODE_LOGISTICS), "", "the flow arrows are not a colour")
	assert_eq(OverlayPalette.legend_note(OverlayPalette.MODE_POWER), "", "powered/unpowered is the whole story")
	assert_eq(OverlayPalette.legend_note(&""), "")

## The controller maps its enum onto these keys. A mode missing from that table
## renders with no legend at all, which looks like a mode with nothing to explain
## rather than like a bug.
func test_every_painted_overlay_mode_maps_to_a_legend_key() -> void:
	for mode: OverlayController.Mode in OverlayController.Mode.values():
		if mode == OverlayController.Mode.NONE:
			continue
		assert_true(OverlayController.LEGEND_KEYS.has(mode),
			"overlay mode %d names a legend key" % mode)
		assert_gt(OverlayPalette.legend_stops(OverlayController.LEGEND_KEYS[mode]).size(), 0,
			"overlay mode %d resolves to a real legend" % mode)
