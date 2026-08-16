extends GutTest

## Unit tests for WI-60's pure thermal math (HeatMath). All static, no Global /
## nodes / live world - temperatures and masses in, numbers out.
##
## The two claims this suite exists to pin are the ones the whole system rests
## on: conduction conserves energy exactly and cannot overshoot at any mass
## ratio, and exposure never reaches zero (which is what stops a sealed forge
## heating forever).

func _tuning() -> HeatMath.ComfortTuning:
	return HeatMath.ComfortTuning.new()

# --- conduction ---------------------------------------------------------------

func test_flow_runs_from_hot_to_cold() -> void:
	assert_gt(HeatMath.exchange_flow(200.0, 10.0, 50.0, 10.0, 0.5), 0.0, "hot side loses energy")
	assert_lt(HeatMath.exchange_flow(50.0, 10.0, 200.0, 10.0, 0.5), 0.0, "cold side gains it")

func test_equal_temperatures_move_nothing() -> void:
	assert_almost_eq(HeatMath.exchange_flow(70.0, 3.0, 70.0, 12.0, 1.0), 0.0, 0.0001,
		"a pair already at equilibrium exchanges nothing")

func test_a_full_step_lands_exactly_on_equal_temperatures() -> void:
	# The property that makes clamping step at 1.0 sufficient: after a full step
	# both sides read the same temperature, for any mass ratio.
	for masses: Array in [[1.0, 1.0], [1.0, 9.0], [37.0, 2.0], [100.0, 0.5]]:
		var mass_a: float = masses[0]
		var mass_b: float = masses[1]
		var t_a: float = 300.0
		var t_b: float = -40.0
		var flow: float = HeatMath.exchange_flow(t_a, mass_a, t_b, mass_b, 1.0)
		var new_a: float = t_a - flow / mass_a
		var new_b: float = t_b + flow / mass_b
		assert_almost_eq(new_a, new_b, 0.0001,
			"masses %s land on one temperature after a full step" % [masses])

func test_energy_is_conserved_exactly() -> void:
	var mass_a: float = 4.0
	var mass_b: float = 11.0
	var t_a: float = 180.0
	var t_b: float = 20.0
	var before: float = t_a * mass_a + t_b * mass_b
	var flow: float = HeatMath.exchange_flow(t_a, mass_a, t_b, mass_b, 0.3)
	var after: float = (t_a - flow / mass_a) * mass_a + (t_b + flow / mass_b) * mass_b
	assert_almost_eq(after, before, 0.0001, "one side loses precisely what the other gains")

func test_no_overshoot_when_the_step_is_oversized() -> void:
	# A caller that failed to clamp (or a huge interval) must still not send the
	# cold side past the hot one.
	var flow: float = HeatMath.exchange_flow(200.0, 5.0, 0.0, 5.0, 12.0)
	var new_a: float = 200.0 - flow / 5.0
	var new_b: float = 0.0 + flow / 5.0
	assert_almost_eq(new_a, new_b, 0.0001, "an oversized step is clamped to a full step")

func test_massless_bodies_exchange_nothing() -> void:
	assert_eq(HeatMath.exchange_flow(200.0, 0.0, 0.0, 5.0, 1.0), 0.0, "no divide by zero")

# --- radiation ----------------------------------------------------------------

func test_a_hot_module_loses_energy_to_space() -> void:
	assert_gt(HeatMath.space_loss(200.0, -60.0, 1.0, 0.5, 4.0, 0.25), 0.0, "hot modules radiate")

func test_a_module_at_space_temperature_loses_nothing() -> void:
	assert_eq(HeatMath.space_loss(-60.0, -60.0, 1.0, 0.5, 4.0, 1.0), 0.0, "already at equilibrium")
	assert_eq(HeatMath.space_loss(-100.0, -60.0, 1.0, 0.5, 4.0, 1.0), 0.0,
		"and space never warms a module that is somehow colder")

func test_radiation_never_carries_a_module_below_space_temperature() -> void:
	# The clamp, at absurd rate and interval - the guarantee a pass relies on.
	var mass: float = 6.0
	var temp: float = 500.0
	var space: float = -60.0
	var loss: float = HeatMath.space_loss(temp, space, 1.0, 99.0, mass, 100.0)
	var after: float = temp - loss / mass
	assert_almost_eq(after, space, 0.0001, "the most it can shed is the gap to space")
	assert_true(after >= space - 0.0001, "and never crosses it")

func test_radiation_scales_with_exposure() -> void:
	var open: float = HeatMath.space_loss(200.0, -60.0, 1.0, 0.5, 4.0, 0.25)
	var boxed: float = HeatMath.space_loss(200.0, -60.0, 0.2, 0.5, 4.0, 0.25)
	assert_almost_eq(boxed, open * 0.2, 0.0001, "a fifth of the exposure sheds a fifth of the heat")

func test_a_heavier_module_cools_more_slowly() -> void:
	var light_loss: float = HeatMath.space_loss(200.0, -60.0, 1.0, 0.5, 2.0, 0.25)
	var heavy_loss: float = HeatMath.space_loss(200.0, -60.0, 1.0, 0.5, 20.0, 0.25)
	# Same energy leaves, but it is a tenth of the temperature drop.
	assert_almost_eq(heavy_loss, light_loss, 0.0001, "mass does not change the energy shed")
	assert_almost_eq(heavy_loss / 20.0, (light_loss / 2.0) / 10.0, 0.0001,
		"but it does change the temperature drop")

# --- exposure -----------------------------------------------------------------

func test_a_module_touching_nothing_is_fully_exposed() -> void:
	assert_almost_eq(HeatMath.exposure_fraction(4, 0), 1.0, 0.0001, "no neighbours, all faces open")

func test_exposure_falls_with_each_neighbour() -> void:
	assert_almost_eq(HeatMath.exposure_fraction(4, 1), 0.8, 0.0001, "one of five faces covered")
	assert_almost_eq(HeatMath.exposure_fraction(4, 2), 0.6, 0.0001, "two of five")
	assert_almost_eq(HeatMath.exposure_fraction(4, 3), 0.4, 0.0001, "three of five")

func test_the_back_face_floor_survives_full_enclosure() -> void:
	# THE test for the `+ 1`. A module boxed in on every connection point still
	# radiates its back-face share - which is what makes a sealed forge settle at
	# a finite temperature instead of climbing forever. Asserted as the exact
	# floor, not merely as "greater than zero", so a refactor that keeps the
	# formula positive but loses the magnitude still fails here.
	assert_almost_eq(HeatMath.exposure_fraction(4, 4), 0.2, 0.0001, "1/(4+1) with every face covered")
	assert_almost_eq(HeatMath.exposure_fraction(1, 1), 0.5, 0.0001, "1/(1+1) for a single-face module")
	assert_almost_eq(HeatMath.exposure_fraction(9, 9), 0.1, 0.0001, "1/(9+1) for a big one")

func test_a_module_with_no_connection_points_is_fully_exposed() -> void:
	assert_almost_eq(HeatMath.exposure_fraction(0, 0), 1.0, 0.0001, "the +1 also dodges a divide by zero")

func test_solar_scaling_is_unchanged_by_the_extraction() -> void:
	# WI-60 moved this arithmetic out of SolarPowerComponent so the heat system
	# could share it. These are the values a four-connection-point solar panel
	# produced before the move, restated here so the shared function can never
	# quietly retune a system that was not part of that item.
	var expected: Array[float] = [1.0, 0.8, 0.6, 0.4, 0.2]
	for neighbours: int in expected.size():
		assert_almost_eq(HeatMath.exposure_fraction(4, neighbours), expected[neighbours], 0.0001,
			"a solar panel with %d neighbours scales to %s" % [neighbours, expected[neighbours]])

func test_exposure_never_leaves_its_bounds() -> void:
	assert_almost_eq(HeatMath.exposure_fraction(4, 99), 0.2, 0.0001, "clamped to the floor, not negative")
	assert_almost_eq(HeatMath.exposure_fraction(4, -3), 1.0, 0.0001, "and never above 1")

# --- throttle -----------------------------------------------------------------

func test_a_cool_module_is_not_throttled_at_all() -> void:
	assert_eq(HeatMath.throttle_multiplier(70.0, 250.0, 450.0, 4.0), 1.0,
		"an ordinary module's process time is byte-for-byte its base")
	assert_eq(HeatMath.throttle_multiplier(250.0, 250.0, 450.0, 4.0), 1.0, "and exactly at the threshold")

func test_the_throttle_ramps_smoothly_and_caps() -> void:
	var mid: float = HeatMath.throttle_multiplier(350.0, 250.0, 450.0, 4.0)
	assert_almost_eq(mid, 2.5, 0.0001, "halfway is halfway to the cap")
	assert_almost_eq(HeatMath.throttle_multiplier(450.0, 250.0, 450.0, 4.0), 4.0, 0.0001, "capped at full")
	assert_almost_eq(HeatMath.throttle_multiplier(9000.0, 250.0, 450.0, 4.0), 4.0, 0.0001,
		"and never past it - a machine that stops dead has no gradient to read")

func test_the_throttle_is_monotone() -> void:
	var previous: float = 0.0
	for temp: int in range(200, 500, 10):
		var value: float = HeatMath.throttle_multiplier(float(temp), 250.0, 450.0, 4.0)
		assert_true(value >= previous, "never dips at %d F" % temp)
		previous = value

func test_a_degenerate_throttle_band_still_answers() -> void:
	assert_eq(HeatMath.throttle_multiplier(300.0, 250.0, 250.0, 4.0), 4.0, "zero-width band snaps to the cap")
	assert_eq(HeatMath.throttle_multiplier(300.0, 250.0, 450.0, 1.0), 1.0, "a cap of 1 disables the hook")

# --- comfort ------------------------------------------------------------------

func test_comfort_is_untouched_across_the_whole_habitable_band() -> void:
	for temp: int in range(40, 91):
		assert_eq(HeatMath.comfort_multiplier(float(temp), 40.0, 90.0, 1.0), 1.0,
			"%d F is exactly 1.0, not approximately" % temp)

func test_comfort_falls_off_outside_the_band_on_both_sides() -> void:
	var cold: float = HeatMath.comfort_multiplier(30.0, 40.0, 90.0, 1.0)
	var hot: float = HeatMath.comfort_multiplier(100.0, 40.0, 90.0, 1.0)
	assert_almost_eq(cold, 0.5, 0.0001, "ten degrees under halves it at k=1")
	assert_almost_eq(hot, 0.5, 0.0001, "and ten degrees over does the same")

func test_comfort_is_continuous_at_the_band_edges() -> void:
	assert_almost_eq(HeatMath.comfort_multiplier(39.99, 40.0, 90.0, 1.0), 1.0, 0.001, "no step at the low edge")
	assert_almost_eq(HeatMath.comfort_multiplier(90.01, 40.0, 90.0, 1.0), 1.0, 0.001, "nor at the high one")

func test_comfort_never_reaches_zero() -> void:
	assert_gt(HeatMath.comfort_multiplier(-400.0, 40.0, 90.0, 1.0), 0.0, "asymptotic, never zero")

func test_a_zero_k_unhooks_comfort() -> void:
	assert_eq(HeatMath.comfort_multiplier(-100.0, 40.0, 90.0, 0.0), 1.0, "one number disables it")

# --- crew bands ---------------------------------------------------------------

func test_band_boundaries() -> void:
	var tuning: HeatMath.ComfortTuning = _tuning()
	assert_eq(HeatMath.band(19.0, tuning), HeatMath.Band.FREEZING, "19 F is dangerous")
	assert_eq(HeatMath.band(20.0, tuning), HeatMath.Band.COLD, "20 F is merely miserable")
	assert_eq(HeatMath.band(39.0, tuning), HeatMath.Band.COLD, "39 F still cold")
	assert_eq(HeatMath.band(40.0, tuning), HeatMath.Band.COMFORTABLE, "40 F is habitable")
	assert_eq(HeatMath.band(90.0, tuning), HeatMath.Band.COMFORTABLE, "and so is 90 F")
	assert_eq(HeatMath.band(91.0, tuning), HeatMath.Band.WARM, "91 F is uncomfortable")
	assert_eq(HeatMath.band(110.0, tuning), HeatMath.Band.WARM, "110 F still only uncomfortable")
	assert_eq(HeatMath.band(111.0, tuning), HeatMath.Band.SCORCHING, "111 F is dangerous")

func test_mood_is_untouched_across_the_habitable_band() -> void:
	var tuning: HeatMath.ComfortTuning = _tuning()
	for temp: int in range(40, 91):
		assert_eq(HeatMath.mood_offset(float(temp), tuning), 0.0, "%d F moves mood not at all" % temp)

func test_mood_ramps_to_its_maximum_at_the_dangerous_thresholds() -> void:
	var tuning: HeatMath.ComfortTuning = _tuning()
	assert_almost_eq(HeatMath.mood_offset(30.0, tuning), -tuning.max_mood_penalty * 0.5, 0.0001,
		"halfway through the cold band is half the penalty")
	assert_almost_eq(HeatMath.mood_offset(20.0, tuning), -tuning.max_mood_penalty, 0.0001,
		"the cold threshold is the full penalty")
	assert_almost_eq(HeatMath.mood_offset(110.0, tuning), -tuning.max_mood_penalty, 0.0001,
		"and so is the hot one")

func test_mood_holds_rather_than_growing_past_the_thresholds() -> void:
	var tuning: HeatMath.ComfortTuning = _tuning()
	assert_almost_eq(HeatMath.mood_offset(-200.0, tuning), -tuning.max_mood_penalty, 0.0001,
		"past the threshold the health drain carries the message, not the mood")
	assert_almost_eq(HeatMath.mood_offset(600.0, tuning), -tuning.max_mood_penalty, 0.0001, "both ways")

func test_mood_is_never_positive() -> void:
	var tuning: HeatMath.ComfortTuning = _tuning()
	for temp: int in range(-200, 600, 7):
		assert_true(HeatMath.mood_offset(float(temp), tuning) <= 0.0, "no temperature is a treat")

func test_only_one_mood_id_is_ever_live() -> void:
	var tuning: HeatMath.ComfortTuning = _tuning()
	assert_eq(HeatMath.mood_id(10.0, tuning), HeatMath.MOOD_TOO_COLD, "freezing reads cold")
	assert_eq(HeatMath.mood_id(35.0, tuning), HeatMath.MOOD_TOO_COLD, "so does merely chilly")
	assert_eq(HeatMath.mood_id(65.0, tuning), &"", "a comfortable room carries no modifier at all")
	assert_eq(HeatMath.mood_id(95.0, tuning), HeatMath.MOOD_TOO_HOT, "warm reads hot")
	assert_eq(HeatMath.mood_id(400.0, tuning), HeatMath.MOOD_TOO_HOT, "and so does scorching")

func test_harm_is_zero_anywhere_inside_the_dangerous_thresholds() -> void:
	var tuning: HeatMath.ComfortTuning = _tuning()
	for temp: int in range(20, 111):
		assert_eq(HeatMath.harm_per_hour(float(temp), tuning), 0.0,
			"%d F is unpleasant at worst" % temp)

func test_harm_starts_immediately_at_the_threshold() -> void:
	var tuning: HeatMath.ComfortTuning = _tuning()
	# No dead zone: the band changed, so something has to happen.
	assert_almost_eq(HeatMath.harm_per_hour(20.0 - 0.001, tuning), tuning.harm_per_hour_at_edge, 0.01,
		"crossing into freezing hurts at once")
	assert_almost_eq(HeatMath.harm_per_hour(110.0 + 0.001, tuning), tuning.harm_per_hour_at_edge, 0.01,
		"and so does crossing into scorching")

func test_the_bands_and_the_harm_curve_agree_about_where_danger_starts() -> void:
	# Two functions naming the same threshold is exactly the kind of thing that
	# drifts. Harm must be nonzero for precisely the two dangerous bands - the
	# first draft of this file had harm biting at 20 F while band() still called
	# it merely cold.
	var tuning: HeatMath.ComfortTuning = _tuning()
	for temp: int in range(-100, 400):
		var dangerous: bool = HeatMath.band(float(temp), tuning) == HeatMath.Band.FREEZING \
			or HeatMath.band(float(temp), tuning) == HeatMath.Band.SCORCHING
		var hurts: bool = HeatMath.harm_per_hour(float(temp), tuning) > 0.0
		assert_eq(hurts, dangerous, "%d F: band and harm curve must agree" % temp)

func test_harm_ramps_with_distance_past_the_threshold() -> void:
	var tuning: HeatMath.ComfortTuning = _tuning()
	assert_almost_eq(HeatMath.harm_per_hour(150.0, tuning), tuning.harm_per_hour_at_edge * 2.0, 0.0001,
		"one full ramp past 110 F is double")
	assert_almost_eq(HeatMath.harm_per_hour(-20.0, tuning), tuning.harm_per_hour_at_edge * 2.0, 0.0001,
		"symmetric on the cold side")
	assert_gt(HeatMath.harm_per_hour(300.0, tuning), HeatMath.harm_per_hour(150.0, tuning),
		"300 F is an emergency where 111 F is a nuisance")

# --- vocabulary ---------------------------------------------------------------

func test_every_band_has_a_word() -> void:
	for value: int in [HeatMath.Band.FREEZING, HeatMath.Band.COLD, HeatMath.Band.COMFORTABLE,
			HeatMath.Band.WARM, HeatMath.Band.SCORCHING]:
		var label: String = HeatMath.band_label(value as HeatMath.Band)
		assert_ne(label, "", "band %d has a label" % value)
		assert_ne(label, "Unknown", "and it is a real one")

func test_temperature_formats_as_whole_degrees() -> void:
	assert_eq(HeatMath.format_temperature(72.4), "72°F", "rounded, with the unit")
	assert_eq(HeatMath.format_temperature(-59.6), "-60°F", "negatives round the same way")

# --- the tuning defaults match the design ------------------------------------

func test_the_habitable_band_is_the_one_the_design_specifies() -> void:
	# These four numbers are the item's whole player-facing contract; a silent
	# retune should have to walk past this test.
	var tuning: HeatMath.ComfortTuning = _tuning()
	assert_eq(tuning.habitable_low_f, 40.0, "habitable from 40 F")
	assert_eq(tuning.habitable_high_f, 90.0, "to 90 F")
	assert_eq(tuning.dangerous_low_f, 20.0, "harmful below 20 F")
	assert_eq(tuning.dangerous_high_f, 110.0, "and above 110 F")

func test_the_neutral_seed_is_inside_the_habitable_band() -> void:
	# What a pre-WI-60 save loads at. If this ever drifts outside the band, every
	# existing save starts harming its crew on load.
	assert_true(HeatMath.NEUTRAL_TEMPERATURE_F >= HeatMath.DEFAULT_HABITABLE_LOW_F
			and HeatMath.NEUTRAL_TEMPERATURE_F <= HeatMath.DEFAULT_HABITABLE_HIGH_F,
		"an old save must not load into a station that is hurting people")

func test_the_heat_ramp_spends_its_range_on_the_habitable_band() -> void:
	# The defect a screenshot caught and a headless check never would: with the
	# ramp calibrated to the station's physical range instead of the band the
	# player manages, every legend stop came out the same shade of green. These
	# assert the five stops are actually distinguishable from each other.
	var freezing: Color = OverlayPalette.heat_color(HeatMath.DEFAULT_DANGEROUS_LOW_F)
	var habitable: Color = OverlayPalette.heat_color(HeatMath.NEUTRAL_TEMPERATURE_F)
	var scorching: Color = OverlayPalette.heat_color(HeatMath.DEFAULT_DANGEROUS_HIGH_F)
	assert_gt(freezing.b, habitable.b + 0.3, "freezing is unmistakably bluer than habitable")
	assert_gt(scorching.r, habitable.r + 0.3, "scorching is unmistakably redder")
	assert_gt(habitable.g, freezing.g, "and habitable is the greenest of the three")
	assert_gt(habitable.g, scorching.g, "on both sides")

func test_the_heat_ramp_saturates_outside_the_dangerous_thresholds() -> void:
	# Past the thresholds the answer is just "no", so the tint stops changing
	# rather than wasting gradient on how much worse it got.
	var edge: Color = OverlayPalette.heat_color(HeatMath.DEFAULT_DANGEROUS_LOW_F)
	var far: Color = OverlayPalette.heat_color(-300.0)
	assert_almost_eq(far.b, edge.b, 0.001, "colder than dangerous reads the same as dangerous")
	var hot_edge: Color = OverlayPalette.heat_color(HeatMath.DEFAULT_DANGEROUS_HIGH_F)
	var far_hot: Color = OverlayPalette.heat_color(900.0)
	assert_almost_eq(far_hot.r, hot_edge.r, 0.001, "and the same at the other end")

func test_space_is_cold_enough_to_matter() -> void:
	assert_lt(HeatMath.DEFAULT_SPACE_TEMPERATURE_F, HeatMath.DEFAULT_DANGEROUS_LOW_F,
		"an unheated station has to freeze, or the whole system is decorative")
