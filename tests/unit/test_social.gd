extends GutTest

## Unit tests for WI-48's pure social rules (SocialMath). Static calls only -
## no Global, no SignalBus, no pawns.

const MAX := SocialMath.OPINION_MAX

func _tuning(base: float = 0.75, opinion: float = 0.35, affinity: float = 0.2, skill: float = 0.1) -> SocialMath.ChatTuning:
	var tuning := SocialMath.ChatTuning.new()
	tuning.base_chance = base
	tuning.opinion_weight = opinion
	tuning.affinity_weight = affinity
	tuning.skill_weight = skill
	return tuning

func _axes(values: Dictionary) -> Dictionary[StringName, float]:
	var out: Dictionary[StringName, float] = {}
	for key: Variant in values:
		out[StringName(key)] = float(values[key])
	return out

# --- positive_chance ----------------------------------------------------------

func test_neutral_strangers_use_the_base_chance() -> void:
	# The "people who work together usually like each other" trend is this number
	# and nothing else, so it must survive an unmodified pair untouched.
	assert_almost_eq(SocialMath.positive_chance(0.0, 0.0, 0.0, _tuning()), 0.75, 0.0001)

func test_chance_rises_with_opinion() -> void:
	var tuning := _tuning()
	var disliked: float = SocialMath.positive_chance(-80.0, 0.0, 0.0, tuning)
	var neutral: float = SocialMath.positive_chance(0.0, 0.0, 0.0, tuning)
	var liked: float = SocialMath.positive_chance(80.0, 0.0, 0.0, tuning)
	assert_lt(disliked, neutral, "an existing dislike makes another bad chat likelier")
	assert_lt(neutral, liked, "friends have better conversations")

func test_chance_rises_with_affinity() -> void:
	var tuning := _tuning()
	assert_lt(SocialMath.positive_chance(0.0, -1.0, 0.0, tuning),
			SocialMath.positive_chance(0.0, 1.0, 0.0, tuning),
			"conflicting traits are worse company than aligned ones")

func test_skill_moves_the_odds_both_ways() -> void:
	var tuning := _tuning()
	var average: float = SocialMath.positive_chance(0.0, 0.0, 0.0, tuning)
	assert_almost_eq(average, tuning.base_chance, 0.0001, "average company = no change")
	assert_gt(SocialMath.positive_chance(0.0, 0.0, 1.0, tuning), average, "a good talker helps")
	assert_lt(SocialMath.positive_chance(0.0, 0.0, -0.1, tuning), average, "a pair of bores hurts")

func test_the_bore_penalty_is_far_smaller_than_the_talker_bonus() -> void:
	# The asymmetry is the point: no social skill is a mild drag, lots of it is
	# worth real odds.
	var tuning := _tuning()
	var average: float = SocialMath.positive_chance(0.0, 0.0, 0.0, tuning)
	var bore_cost: float = average - SocialMath.positive_chance(0.0, 0.0, -0.1, tuning)
	var talker_gain: float = SocialMath.positive_chance(0.0, 0.0, 1.0, tuning) - average
	assert_gt(talker_gain, bore_cost * 5.0, "the bonus side dwarfs the penalty side")

func test_zero_skill_weight_unhooks_the_skill_entirely() -> void:
	# The escape hatch promised in the WI: one number turns the skill hook off.
	var tuning := _tuning(0.75, 0.35, 0.2, 0.0)
	assert_almost_eq(SocialMath.positive_chance(0.0, 0.0, 1.0, tuning), 0.75, 0.0001)

func test_chance_is_clamped_at_both_ends() -> void:
	var tuning := _tuning()
	# Neither spiral may latch - a feud that can never produce a good chat is a
	# dead end, not a grudge.
	var worst: float = SocialMath.positive_chance(-MAX, -1.0, 0.0, _tuning(0.05, 2.0, 2.0, 0.0))
	assert_almost_eq(worst, tuning.min_chance, 0.0001, "floored, so feuds stay recoverable")
	var best: float = SocialMath.positive_chance(MAX, 1.0, 1.0, _tuning(0.99, 2.0, 2.0, 2.0))
	assert_almost_eq(best, tuning.max_chance, 0.0001, "capped, so friendships can still misfire")

# --- opinion_delta ------------------------------------------------------------

func test_a_step_from_neutral_is_the_nominal_magnitude() -> void:
	assert_almost_eq(SocialMath.opinion_delta(0.0, true, 6.0), 6.0, 0.0001)
	assert_almost_eq(SocialMath.opinion_delta(0.0, false, 6.0), -6.0, 0.0001)

func test_opinion_never_crosses_the_extremes() -> void:
	# Walk a pair all the way up with big steps and assert the asymptote holds.
	var opinion: float = 0.0
	for _i: int in 200:
		opinion += SocialMath.opinion_delta(opinion, true, 20.0)
	assert_lt(opinion, MAX + 0.0001, "positive chats approach +100 without passing it")
	assert_gt(opinion, 90.0, "and they do get most of the way there")
	opinion = 0.0
	for _i: int in 200:
		opinion += SocialMath.opinion_delta(opinion, false, 20.0)
	assert_gt(opinion, -MAX - 0.0001, "negative chats approach -100 without passing it")

func test_the_step_shrinks_toward_the_extreme_it_heads_for() -> void:
	assert_gt(SocialMath.opinion_delta(0.0, true, 6.0), SocialMath.opinion_delta(80.0, true, 6.0),
			"a settled friendship stops inflating")
	assert_almost_eq(SocialMath.opinion_delta(MAX, true, 6.0), 0.0, 0.0001, "pinned at the top, no movement")

func test_recovering_from_a_feud_moves_faster_than_from_neutral() -> void:
	# Deliberate asymmetry: the first good chats after a bad run should land.
	assert_gt(SocialMath.opinion_delta(-90.0, true, 6.0), SocialMath.opinion_delta(0.0, true, 6.0))

func test_a_zero_magnitude_moves_nothing() -> void:
	assert_almost_eq(SocialMath.opinion_delta(30.0, true, 0.0), 0.0, 0.0001)

# --- mood_offset ---------------------------------------------------------------

func test_the_neutral_band_is_completely_flat() -> void:
	# Ordinary colleagues must not move mood at all, in either direction.
	for opinion: float in [-25.0, -24.0, -10.0, 0.0, 10.0, 24.0, 25.0]:
		assert_almost_eq(SocialMath.mood_offset(opinion, 25.0, 0.06), 0.0, 0.0001,
				"opinion %.0f is inside the band" % opinion)

func test_mood_ramps_outside_the_band_and_caps_at_the_extremes() -> void:
	assert_gt(SocialMath.mood_offset(26.0, 25.0, 0.06), 0.0, "just past the band is a small lift")
	assert_almost_eq(SocialMath.mood_offset(MAX, 25.0, 0.06), 0.06, 0.0001, "full offset at +100")
	assert_almost_eq(SocialMath.mood_offset(-MAX, 25.0, 0.06), -0.06, 0.0001, "mirrored at -100")

func test_mood_is_continuous_at_the_band_edge() -> void:
	# A step at the boundary would read as a bug in the happiness readout.
	assert_almost_eq(SocialMath.mood_offset(25.001, 25.0, 0.06), 0.0, 0.001)

func test_mood_is_monotonic_across_the_ramp() -> void:
	var previous: float = -1.0
	for opinion: int in range(25, 101, 5):
		var offset: float = SocialMath.mood_offset(float(opinion), 25.0, 0.06)
		assert_gte(offset, previous, "offset never dips as opinion climbs")
		previous = offset

func test_a_band_covering_the_whole_range_disables_the_effect() -> void:
	assert_almost_eq(SocialMath.mood_offset(MAX, MAX, 0.06), 0.0, 0.0001)

# --- chat_interval --------------------------------------------------------------

func test_trait_multipliers_scale_the_interval() -> void:
	assert_almost_eq(SocialMath.chat_interval(1.0, 1.0), 1.0, 0.0001, "no relevant trait")
	assert_almost_eq(SocialMath.chat_interval(1.0, 0.5), 0.5, 0.0001, "Extrovert chats twice as often")
	assert_almost_eq(SocialMath.chat_interval(1.0, 2.0), 2.0, 0.0001, "Introvert half as often")

func test_the_interval_has_a_floor() -> void:
	# A 0.0 multiplier from stacked mod traits would otherwise mean every tick.
	assert_almost_eq(SocialMath.chat_interval(1.0, 0.0), SocialMath.MIN_CHAT_INTERVAL_HOURS, 0.0001)

# --- trait_affinity --------------------------------------------------------------

func test_aligned_traits_read_positive_and_conflicting_negative() -> void:
	var optimist := _axes({"mood": 1.0})
	var pessimist := _axes({"mood": -1.0})
	assert_almost_eq(SocialMath.trait_affinity(optimist, optimist), 1.0, 0.0001, "two optimists agree")
	assert_almost_eq(SocialMath.trait_affinity(optimist, pessimist), -1.0, 0.0001, "optimist vs pessimist clash")
	assert_almost_eq(SocialMath.trait_affinity(pessimist, pessimist), 1.0, 0.0001, "two pessimists also agree")

func test_unshared_axes_contribute_nothing() -> void:
	# Not having a trait on someone's axis is not a disagreement.
	assert_almost_eq(SocialMath.trait_affinity(_axes({"mood": 1.0}), _axes({"sociability": -1.0})), 0.0, 0.0001)
	assert_almost_eq(SocialMath.trait_affinity(_axes({}), _axes({"mood": 1.0})), 0.0, 0.0001)

func test_neutral_polarity_traits_opt_out() -> void:
	# Hardy/Weak share an exclusive group but are not personality - polarity 0.
	assert_almost_eq(SocialMath.trait_affinity(_axes({"constitution": 0.0}), _axes({"constitution": 0.0})), 0.0, 0.0001)
	assert_almost_eq(SocialMath.trait_affinity(_axes({"constitution": 0.0}), _axes({"constitution": 1.0})), 0.0, 0.0001)

func test_affinity_is_averaged_not_summed() -> void:
	# Otherwise a pawn with more traits would dominate the roll.
	var both_aligned: float = SocialMath.trait_affinity(
			_axes({"mood": 1.0, "sociability": 1.0}), _axes({"mood": 1.0, "sociability": 1.0}))
	assert_almost_eq(both_aligned, 1.0, 0.0001, "two aligned axes still read as 1.0")
	var mixed: float = SocialMath.trait_affinity(
			_axes({"mood": 1.0, "sociability": 1.0}), _axes({"mood": 1.0, "sociability": -1.0}))
	assert_almost_eq(mixed, 0.0, 0.0001, "one aligned, one opposed cancels out")

func test_partial_polarities_scale_the_result() -> void:
	assert_almost_eq(SocialMath.trait_affinity(_axes({"mood": 0.5}), _axes({"mood": 1.0})), 0.5, 0.0001)

# --- skill_term -------------------------------------------------------------------

func _skill(level_a: int, level_b: int) -> float:
	return SocialMath.skill_term(level_a, level_b, 10, 3, -0.1)

func test_skill_term_hits_its_three_anchor_points() -> void:
	# 0 is a bore, 3 is average company, 10 is a genuinely good conversationalist.
	assert_almost_eq(_skill(0, 0), -0.1, 0.0001, "no social skill at all is a small penalty")
	assert_almost_eq(_skill(3, 3), 0.0, 0.0001, "level 3 is exactly average - no effect")
	assert_almost_eq(_skill(10, 10), 1.0, 0.0001, "maxed out is the full bonus")

func test_skill_term_is_the_pairs_mean() -> void:
	assert_almost_eq(_skill(10, 0), _skill(5, 5), 0.0001, "only the mean matters, not the spread")
	assert_almost_eq(_skill(6, 0), 0.0, 0.0001, "a maxed talker carries a bore up to average")

func test_skill_term_is_linear_on_each_side_of_neutral() -> void:
	assert_almost_eq(_skill(0, 3), -0.05, 0.0001, "halfway down the shallow penalty slope")
	assert_almost_eq(_skill(10, 3), 0.5, 0.0001, "halfway up the steep bonus slope")

func test_skill_term_is_monotonic_across_its_whole_range() -> void:
	var previous: float = -INF
	for level: int in range(0, 21):
		# Sweep the mean in half-steps by moving one side at a time.
		var term: float = _skill(level / 2, level - level / 2)
		assert_gte(term, previous, "term never dips as the pair gets more skilled")
		previous = term

func test_skill_term_clamps_outside_the_level_range() -> void:
	assert_almost_eq(_skill(-5, -5), -0.1, 0.0001, "below 0 is still just a bore")
	assert_almost_eq(_skill(99, 99), 1.0, 0.0001, "past the cap is still just the full bonus")

func test_skill_term_survives_degenerate_configuration() -> void:
	assert_almost_eq(SocialMath.skill_term(5, 5, 0, 3, -0.1), 0.0, 0.0001, "no max level")
	assert_almost_eq(SocialMath.skill_term(5, 5, 10, 10, -0.1), -0.05, 0.0001,
			"neutral at the cap makes the whole range the penalty side")
	assert_almost_eq(SocialMath.skill_term(10, 10, 10, 10, -0.1), 0.0, 0.0001,
			"and only a maxed pair gets all the way up to average")
	assert_almost_eq(SocialMath.skill_term(0, 0, 10, 0, -0.1), 0.0, 0.0001,
			"neutral at zero leaves no penalty side to fall down")

# --- partner_weight ----------------------------------------------------------------

func test_unmet_crew_outrank_everyone() -> void:
	# New hires must get talked to rather than waiting out an established pair.
	assert_gt(SocialMath.partner_weight(INF, 0, 24.0), SocialMath.partner_weight(24.0, 5, 24.0))

func test_the_last_partner_becomes_unlikely_but_never_impossible() -> void:
	var just_spoke: float = SocialMath.partner_weight(0.0, 3, 24.0)
	assert_almost_eq(just_spoke, SocialMath.MIN_PARTNER_WEIGHT, 0.0001)
	assert_gt(just_spoke, 0.0, "two crew alone on a station must keep talking")

func test_weight_recovers_with_time_and_then_holds() -> void:
	assert_lt(SocialMath.partner_weight(6.0, 3, 24.0), SocialMath.partner_weight(18.0, 3, 24.0))
	assert_almost_eq(SocialMath.partner_weight(24.0, 3, 24.0), 1.0, 0.0001, "back to parity after a cycle")
	assert_almost_eq(SocialMath.partner_weight(400.0, 3, 24.0), 1.0, 0.0001, "and does not keep climbing")

func test_a_zero_refresh_window_flattens_the_weighting() -> void:
	assert_almost_eq(SocialMath.partner_weight(3.0, 3, 0.0), 1.0, 0.0001)

# --- opinion_label -------------------------------------------------------------------

func test_labels_band_symmetrically_around_neutral() -> void:
	assert_eq(SocialMath.opinion_label(-100.0), "Hostile")
	assert_eq(SocialMath.opinion_label(-60.0), "Hostile", "the boundary belongs to the stronger word")
	assert_eq(SocialMath.opinion_label(-59.0), "Cold")
	assert_eq(SocialMath.opinion_label(-20.0), "Cold")
	assert_eq(SocialMath.opinion_label(-19.0), "Neutral")
	assert_eq(SocialMath.opinion_label(0.0), "Neutral")
	assert_eq(SocialMath.opinion_label(19.0), "Neutral")
	assert_eq(SocialMath.opinion_label(20.0), "Friendly")
	assert_eq(SocialMath.opinion_label(59.0), "Friendly")
	assert_eq(SocialMath.opinion_label(60.0), "Close")
	assert_eq(SocialMath.opinion_label(100.0), "Close")

# --- the trend the whole design rests on ------------------------------------------

func test_a_positively_biased_pair_drifts_toward_liking_each_other() -> void:
	# Deterministic stand-in for the probe's random walk: with base 0.75, three
	# chats in four go well, and that has to be enough to climb.
	var opinion: float = 0.0
	for i: int in 100:
		var positive: bool = i % 4 != 0
		opinion += SocialMath.opinion_delta(opinion, positive, 6.0)
	assert_gt(opinion, 40.0, "colleagues who talk end up friends")

func test_a_negatively_biased_pair_settles_into_a_stable_feud() -> void:
	var opinion: float = 0.0
	for i: int in 100:
		var positive: bool = i % 4 == 0
		opinion += SocialMath.opinion_delta(opinion, positive, 6.0)
	assert_lt(opinion, -40.0, "a bad run lands them in a feud")
	assert_gt(opinion, -MAX, "which stays an equilibrium rather than bottoming out")
