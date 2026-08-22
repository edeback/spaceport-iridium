extends GutTest

## [FactionStanding] (WI-62 §5): the number, its clamp, and the five bands that
## turn it into a sentence.
##
## Pure: constructed directly, no [Global], no nodes.

var standing: FactionStanding

func before_each() -> void:
	standing = FactionStanding.new()

# --- values ---------------------------------------------------------------------

func test_an_unmentioned_faction_is_neutral() -> void:
	assert_eq(standing.standing(&"nobody"), FactionStanding.NEUTRAL,
		"adding a faction needs no migration precisely because absent means neutral")

func test_shift_accumulates() -> void:
	standing.shift(&"authority", 0.15)
	standing.shift(&"authority", 0.1)
	assert_almost_eq(standing.standing(&"authority"), 0.25, 0.0001)

## The clamp lives here so a `.dialogue` file can say `shift_standing(x, -0.2)`
## four times without having to know where the floor is.
func test_shift_clamps_at_both_ends() -> void:
	for index: int in 20:
		standing.shift(&"pirates", -0.2)
	assert_eq(standing.standing(&"pirates"), FactionStanding.MINIMUM)
	for index: int in 40:
		standing.shift(&"pirates", 0.2)
	assert_eq(standing.standing(&"pirates"), FactionStanding.MAXIMUM)

func test_set_standing_clamps_and_reports_where_it_landed() -> void:
	assert_eq(standing.set_standing(&"traders", 5.0), FactionStanding.MAXIMUM)
	assert_eq(standing.set_standing(&"traders", -5.0), FactionStanding.MINIMUM)

func test_an_empty_faction_id_is_refused() -> void:
	assert_eq(standing.set_standing(&"", 0.5), FactionStanding.NEUTRAL)
	assert_push_error("no faction id")
	assert_eq(standing.moved_factions().size(), 0)

func test_returning_to_neutral_stops_being_stored() -> void:
	standing.shift(&"authority", 0.3)
	assert_eq(standing.moved_factions().size(), 1)
	standing.set_standing(&"authority", 0.0)
	assert_eq(standing.moved_factions().size(), 0,
		"the save carries relationships that moved, not every faction that exists")

# --- bands -----------------------------------------------------------------------

func test_the_five_bands_in_order() -> void:
	assert_eq(FactionStanding.band_for(-1.0), FactionStanding.Band.HOSTILE)
	assert_eq(FactionStanding.band_for(-0.4), FactionStanding.Band.COLD)
	assert_eq(FactionStanding.band_for(0.0), FactionStanding.Band.NEUTRAL_BAND)
	assert_eq(FactionStanding.band_for(0.4), FactionStanding.Band.WARM)
	assert_eq(FactionStanding.band_for(1.0), FactionStanding.Band.ALLIED)

## The boundaries belong to the outer bands, which leaves NEUTRAL as the open
## interval between them. A station that has done equal harm and equal good to
## two factions must read the same distance from neutral in both directions.
func test_the_boundaries_are_symmetric_about_zero() -> void:
	assert_eq(FactionStanding.band_for(FactionStanding.COLD_CEILING),
		FactionStanding.Band.COLD, "-0.2 is cold, not neutral")
	assert_eq(FactionStanding.band_for(FactionStanding.WARM_FLOOR),
		FactionStanding.Band.WARM, "+0.2 is warm, not neutral")
	assert_eq(FactionStanding.band_for(FactionStanding.HOSTILE_CEILING),
		FactionStanding.Band.HOSTILE)
	assert_eq(FactionStanding.band_for(FactionStanding.ALLIED_FLOOR),
		FactionStanding.Band.ALLIED)

func test_the_ladder_never_goes_backwards() -> void:
	# A sweep, because a hand-written if-ladder is exactly the shape that gets one
	# comparison inverted and still passes five spot checks.
	var previous: int = -1
	var value: float = FactionStanding.MINIMUM
	while value <= FactionStanding.MAXIMUM:
		var band: int = int(FactionStanding.band_for(value))
		assert_gte(band, previous, "the band at %.2f is not below the one before it" % value)
		previous = band
		value += 0.01

func test_every_band_has_a_name_and_a_detail() -> void:
	for band: FactionStanding.Band in FactionStanding.BAND_NAMES:
		assert_false(FactionStanding.band_name(band).is_empty())
		assert_false(FactionStanding.band_detail(band).is_empty(),
			"%s owes the player a sentence, not just a word" % band)

func test_no_two_bands_share_a_name() -> void:
	var seen: Array[String] = []
	for band: FactionStanding.Band in FactionStanding.BAND_NAMES:
		var name_text: String = FactionStanding.band_name(band)
		assert_false(seen.has(name_text), "%s is used twice" % name_text)
		seen.append(name_text)

func test_the_bar_fraction_spans_the_whole_range() -> void:
	assert_eq(FactionStanding.fraction(FactionStanding.MINIMUM), 0.0)
	assert_almost_eq(FactionStanding.fraction(FactionStanding.NEUTRAL), 0.5, 0.0001)
	assert_eq(FactionStanding.fraction(FactionStanding.MAXIMUM), 1.0)

# --- persistence ------------------------------------------------------------------

func test_round_trip() -> void:
	standing.shift(&"authority", -0.35)
	standing.shift(&"traders", 0.5)
	var restored := FactionStanding.new()
	restored.from_save(standing.to_save())
	assert_almost_eq(restored.standing(&"authority"), -0.35, 0.0001)
	assert_almost_eq(restored.standing(&"traders"), 0.5, 0.0001)

## Unlike [StoryFlags], an unknown faction is **kept**. A standing is a
## relationship, and losing it because a definition was briefly absent would be
## worse than carrying a value nothing currently reads.
func test_an_unknown_saved_faction_is_kept() -> void:
	var restored := FactionStanding.new()
	restored.from_save({"somebody_elses_faction": -0.5})
	assert_almost_eq(restored.standing(&"somebody_elses_faction"), -0.5, 0.0001)
