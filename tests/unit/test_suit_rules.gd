extends GutTest

## Unit tests for WI-67's pure suit logic (SuitRules). All static, no Global /
## nodes / live world - a room's readings and a pawn's situation in, a decision
## out.
##
## Three claims this suite exists to pin:
##   - HARMFUL agrees with the systems that actually do the harming, to the
##     degree. WI-60 deviation 7 is the precedent: two functions answering the
##     same question drifted apart at the boundary and only a sweep caught it.
##   - The TOLERABLE band is genuinely sticky in both directions. That hysteresis
##     is the only thing between the player and a crew member oscillating between
##     a workshop and an airlock forever.
##   - Tier 1 adds NO behaviour at all - no trips, ever, whatever the room says.

func _thresholds() -> SuitRules.Thresholds:
	return SuitRules.Thresholds.new()

## A situation that decides nothing on its own, so each test states only the
## field it is about.
func _situation() -> SuitRules.Situation:
	var out := SuitRules.Situation.new()
	out.suited = false
	out.environment = SuitRules.RoomState.TOLERABLE
	return out

func _classify(o2: float, temp_f: float) -> SuitRules.RoomState:
	return SuitRules.classify(o2, temp_f, _thresholds(), true, true)

# --- classification: boundaries -----------------------------------------------

func test_air_boundaries() -> void:
	# 25 is the suffocation partial: below it harms, exactly on it does not.
	assert_eq(_classify(24.9, 70.0), SuitRules.RoomState.HARMFUL, "below the damage partial")
	assert_eq(_classify(25.0, 70.0), SuitRules.RoomState.TOLERABLE, "exactly on it is survivable")
	assert_eq(_classify(39.9, 70.0), SuitRules.RoomState.TOLERABLE, "thin but not harmful")
	assert_eq(_classify(40.0, 70.0), SuitRules.RoomState.HABITABLE, "the alert threshold is fit")

func test_temperature_boundaries() -> void:
	assert_eq(_classify(100.0, 19.0), SuitRules.RoomState.HARMFUL, "below the dangerous low")
	assert_eq(_classify(100.0, 20.0), SuitRules.RoomState.TOLERABLE, "exactly on it is survivable")
	assert_eq(_classify(100.0, 39.0), SuitRules.RoomState.TOLERABLE, "cold but not harmful")
	assert_eq(_classify(100.0, 40.0), SuitRules.RoomState.HABITABLE, "the habitable band is fit")
	assert_eq(_classify(100.0, 90.0), SuitRules.RoomState.HABITABLE, "top of the habitable band")
	assert_eq(_classify(100.0, 91.0), SuitRules.RoomState.TOLERABLE, "warm but not harmful")
	assert_eq(_classify(100.0, 110.0), SuitRules.RoomState.TOLERABLE, "exactly on the dangerous high")
	assert_eq(_classify(100.0, 111.0), SuitRules.RoomState.HARMFUL, "past it harms")

## The agreement sweep. HARMFUL must hold EXACTLY where something is actually
## doing damage - HeatMath.harm_per_hour for heat, the damage partial for air.
## A threshold comparison written out a second time in SuitRules is how that
## agreement rots, so this sweeps rather than spot-checks.
func test_harmful_agrees_with_the_systems_that_do_the_harming() -> void:
	var thresholds: SuitRules.Thresholds = _thresholds()
	var temp: float = -100.0
	while temp <= 400.0:
		var harms: bool = HeatMath.harm_per_hour(temp, thresholds.comfort) > 0.0
		var says: bool = SuitRules.classify(100.0, temp, thresholds, true, true) == SuitRules.RoomState.HARMFUL
		assert_eq(says, harms, "%.1f F: HARMFUL matches harm_per_hour > 0" % temp)
		temp += 0.5
	var o2: float = 0.0
	while o2 <= 100.0:
		var suffocates: bool = o2 < thresholds.damage_o2_partial
		var air_says: bool = SuitRules.classify(o2, 70.0, thresholds, true, true) == SuitRules.RoomState.HARMFUL
		assert_eq(air_says, suffocates, "O2 %.1f: HARMFUL matches the damage partial" % o2)
		o2 += 0.5

func test_the_worse_axis_wins() -> void:
	assert_eq(_classify(100.0, -40.0), SuitRules.RoomState.HARMFUL, "breathable but freezing")
	assert_eq(_classify(5.0, 70.0), SuitRules.RoomState.HARMFUL, "warm but airless")
	assert_eq(_classify(30.0, 70.0), SuitRules.RoomState.TOLERABLE, "one tolerable axis caps the pair")

func test_unknown_when_a_room_has_no_body_yet() -> void:
	var thresholds: SuitRules.Thresholds = _thresholds()
	assert_eq(SuitRules.classify(0.0, -200.0, thresholds, false, false), SuitRules.RoomState.UNKNOWN,
		"a module mid-registration reads UNKNOWN, never HARMFUL")
	# One axis present still answers: truss has no atmosphere but does have a
	# thermal body, and a pawn should not read a warm truss as unknowable.
	assert_eq(SuitRules.classify(0.0, 70.0, thresholds, false, true), SuitRules.RoomState.HABITABLE,
		"the axis that exists decides")

func test_a_pawn_with_no_breathing_component_has_no_opinion_on_air() -> void:
	var thresholds: SuitRules.Thresholds = _thresholds()
	thresholds.reads_air = false
	assert_eq(SuitRules.classify(0.0, 70.0, thresholds, true, true), SuitRules.RoomState.HABITABLE,
		"vacuum is not harmful to something that does not breathe")

# --- the decision table -------------------------------------------------------

func test_outside_is_always_suited_and_never_a_trip() -> void:
	var situation: SuitRules.Situation = _situation()
	situation.outside = true
	assert_eq(SuitRules.decide(situation), SuitRules.Action.SUIT_UP_IN_PLACE,
		"EVA suits up where it stands - no walk to an airlock in vacuum")
	situation.suited = true
	assert_eq(SuitRules.decide(situation), SuitRules.Action.NONE, "already suited outside")

func test_tier_one_is_always_suited_and_never_a_trip() -> void:
	var situation: SuitRules.Situation = _situation()
	situation.suits_mandatory = true
	situation.environment = SuitRules.RoomState.HABITABLE
	assert_eq(SuitRules.decide(situation), SuitRules.Action.SUIT_UP_IN_PLACE,
		"Tier 1 crew are suited even in a perfectly fit room")
	situation.suited = true
	assert_eq(SuitRules.decide(situation), SuitRules.Action.NONE,
		"and never take it off, so Tier 1 posts no jobs at all")

func test_a_harmful_room_sends_an_unsuited_pawn_to_an_airlock() -> void:
	var situation: SuitRules.Situation = _situation()
	situation.environment = SuitRules.RoomState.HARMFUL
	assert_eq(SuitRules.decide(situation), SuitRules.Action.SUIT_UP, "a trip, not an instant suit")

func test_a_habitable_room_sends_a_suited_pawn_to_an_airlock() -> void:
	var situation: SuitRules.Situation = _situation()
	situation.suited = true
	situation.environment = SuitRules.RoomState.HABITABLE
	assert_eq(SuitRules.decide(situation), SuitRules.Action.TAKE_OFF)

func test_taking_it_off_needs_the_pawns_own_room_to_be_fit() -> void:
	# The anti-oscillation rule: a suited pawn in a merely tolerable room keeps the
	# suit (and the -10) rather than walking to an airlock and straight back.
	var situation: SuitRules.Situation = _situation()
	situation.suited = true
	situation.environment = SuitRules.RoomState.TOLERABLE
	assert_eq(SuitRules.decide(situation), SuitRules.Action.NONE)

func test_tolerable_is_sticky_in_both_directions() -> void:
	var situation: SuitRules.Situation = _situation()
	situation.environment = SuitRules.RoomState.TOLERABLE
	assert_eq(SuitRules.decide(situation), SuitRules.Action.NONE, "unsuited stays unsuited")
	situation.suited = true
	assert_eq(SuitRules.decide(situation), SuitRules.Action.NONE, "suited stays suited")

func test_unknown_changes_nothing_either_way() -> void:
	var situation: SuitRules.Situation = _situation()
	situation.environment = SuitRules.RoomState.UNKNOWN
	assert_eq(SuitRules.decide(situation), SuitRules.Action.NONE)
	situation.suited = true
	assert_eq(SuitRules.decide(situation), SuitRules.Action.NONE)

func test_a_conveyed_pawn_decides_nothing() -> void:
	# A turbolift ride nulls current_module. Without this branch every ride would
	# flip a helmet on and off.
	var situation: SuitRules.Situation = _situation()
	situation.conveyed = true
	situation.outside = true
	situation.environment = SuitRules.RoomState.HARMFUL
	assert_eq(SuitRules.decide(situation), SuitRules.Action.NONE)

func test_the_hold_keeps_a_suit_on_in_a_room_that_has_recovered() -> void:
	var situation: SuitRules.Situation = _situation()
	situation.suited = true
	situation.environment = SuitRules.RoomState.HABITABLE
	situation.hold_remaining = 1.5
	assert_eq(SuitRules.decide(situation), SuitRules.Action.NONE)
	situation.hold_remaining = 0.0
	assert_eq(SuitRules.decide(situation), SuitRules.Action.TAKE_OFF, "and releases when it expires")

func test_the_cooldown_throttles_a_refused_trip() -> void:
	var situation: SuitRules.Situation = _situation()
	situation.suited = true
	situation.environment = SuitRules.RoomState.HABITABLE
	situation.trip_cooldown = 0.5
	assert_eq(SuitRules.decide(situation), SuitRules.Action.NONE)

func test_a_trip_already_running_is_not_posted_twice() -> void:
	var situation: SuitRules.Situation = _situation()
	situation.environment = SuitRules.RoomState.HARMFUL
	situation.trip_in_progress = true
	assert_eq(SuitRules.decide(situation), SuitRules.Action.NONE)
	situation.trip_in_progress = false
	assert_eq(SuitRules.decide(situation), SuitRules.Action.SUIT_UP)

func test_harm_outranks_the_cooldown() -> void:
	# A cooldown from a refused take-off must never stop somebody suiting up.
	var situation: SuitRules.Situation = _situation()
	situation.environment = SuitRules.RoomState.HARMFUL
	situation.trip_cooldown = 5.0
	assert_eq(SuitRules.decide(situation), SuitRules.Action.SUIT_UP)

# --- the airlock entry case ---------------------------------------------------

func test_coming_in_through_a_habitable_airlock_strips_on_the_spot() -> void:
	# They are standing IN the airlock, so there is no trip to make - and this is
	# the one thing that ends a hold early.
	var situation: SuitRules.Situation = _situation()
	situation.suited = true
	situation.environment = SuitRules.RoomState.HABITABLE
	situation.entered_airlock_from_outside = true
	situation.entry_airlock_environment = SuitRules.RoomState.HABITABLE
	situation.hold_remaining = 1.9
	assert_eq(SuitRules.decide(situation), SuitRules.Action.TAKE_OFF_IN_PLACE)

func test_coming_in_through_an_unfit_airlock_keeps_the_suit() -> void:
	var situation: SuitRules.Situation = _situation()
	situation.suited = true
	situation.entered_airlock_from_outside = true
	situation.entry_airlock_environment = SuitRules.RoomState.TOLERABLE
	situation.hold_remaining = 1.9
	assert_eq(SuitRules.decide(situation), SuitRules.Action.NONE)

func test_tier_one_ignores_the_airlock_entry_case() -> void:
	var situation: SuitRules.Situation = _situation()
	situation.suited = true
	situation.suits_mandatory = true
	situation.entered_airlock_from_outside = true
	situation.entry_airlock_environment = SuitRules.RoomState.HABITABLE
	assert_eq(SuitRules.decide(situation), SuitRules.Action.NONE, "no helmet comes off at Tier 1")

# --- the hold clock -----------------------------------------------------------

func test_the_hold_refreshes_every_tick_in_a_harmful_room() -> void:
	var hold: float = SuitRules.next_hold(0.2, SuitRules.RoomState.HARMFUL, false, 2.0, 0.1)
	assert_eq(hold, 2.0, "'two hours past the LAST time' means refresh, not start")

func test_the_hold_counts_down_elsewhere() -> void:
	assert_almost_eq(SuitRules.next_hold(2.0, SuitRules.RoomState.HABITABLE, false, 2.0, 0.5),
		1.5, 0.0001)
	assert_eq(SuitRules.next_hold(0.1, SuitRules.RoomState.TOLERABLE, false, 2.0, 5.0), 0.0,
		"and never goes negative")

func test_space_does_not_refresh_the_hold() -> void:
	# Space is not a hostile INTERIOR. Without this an EVA worker could never take
	# a suit off, because the hold would top up for as long as they were outside.
	assert_almost_eq(SuitRules.next_hold(2.0, SuitRules.RoomState.HARMFUL, true, 2.0, 0.5),
		1.5, 0.0001)

# --- the mood -----------------------------------------------------------------

func test_the_mood_applies_only_to_a_suit_worn_indoors_past_tier_one() -> void:
	assert_true(SuitRules.mood_applies(true, false, false), "suited, inside, Tier 2+")
	assert_false(SuitRules.mood_applies(false, false, false), "not while unsuited")
	assert_false(SuitRules.mood_applies(true, true, false), "not while outside")
	assert_false(SuitRules.mood_applies(true, false, true), "not at Tier 1")

# --- the alert's reason -------------------------------------------------------

func test_the_reason_names_air_before_temperature() -> void:
	var thresholds: SuitRules.Thresholds = _thresholds()
	assert_eq(SuitRules.reason_for(5.0, -40.0, thresholds, true, true), SuitRules.Reason.NO_AIR,
		"suffocation is faster than freezing, so it is the one worth naming")
	assert_eq(SuitRules.reason_for(100.0, -40.0, thresholds, true, true), SuitRules.Reason.TOO_COLD)
	assert_eq(SuitRules.reason_for(100.0, 200.0, thresholds, true, true), SuitRules.Reason.TOO_HOT)
	assert_eq(SuitRules.reason_for(100.0, 70.0, thresholds, true, true), SuitRules.Reason.NONE)

func test_every_reason_has_words() -> void:
	for reason: SuitRules.Reason in [SuitRules.Reason.NO_AIR, SuitRules.Reason.TOO_COLD,
			SuitRules.Reason.TOO_HOT]:
		assert_false(SuitRules.reason_text(reason).is_empty(), "reason %d prints" % reason)
