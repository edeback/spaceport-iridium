extends GutTest

## Unit tests for WI-51's MoodCatalog: the id -> label/blurb/cause table behind
## the Needs tab's mood breakdown, its three dynamic id families (disease, trait,
## event), the duration/cause column, and the happiness arithmetic the breakdown
## has to reproduce - clamp included.
##
## Pure: the catalogue is static and reads the same shared data registries the
## sim does. Nothing here touches Global or SignalBus.

# --- the static table ---------------------------------------------------------

## Every id a fixed code path can hand PawnNeedsComponent.add_modifier. Kept as
## the test's own list rather than read off STATIC_ENTRIES, so deleting an entry
## is a failure instead of a silently shorter loop.
const FIXED_IDS: Array[StringName] = [
	&"good_shopping", &"good_lodging", &"difficulty", &"exhausted", &"trait_exterior",
	&"bad_chat", &"company", &"interrupted_meal", &"good_meal", &"bad_meal",
]

func test_every_fixed_id_resolves_to_a_label() -> void:
	for id: StringName in FIXED_IDS:
		assert_true(MoodCatalog.STATIC_ENTRIES.has(id), "%s is in the table" % id)
		assert_false(MoodCatalog.label_of(id).is_empty(), "%s has a label" % id)

func test_every_fixed_id_has_a_blurb() -> void:
	for id: StringName in FIXED_IDS:
		assert_false(MoodCatalog.blurb_of(id).is_empty(), "%s explains itself" % id)

func test_permanent_ids_name_their_cause() -> void:
	# The INF-duration ones, where "how much longer" is the wrong question.
	assert_eq(MoodCatalog.cause_of(&"difficulty"), MoodCatalog.CAUSE_DIFFICULTY)
	assert_eq(MoodCatalog.cause_of(&"exhausted"), MoodCatalog.CAUSE_EXHAUSTED)
	assert_eq(MoodCatalog.cause_of(&"trait_exterior"), MoodCatalog.CAUSE_OUTSIDE)
	assert_eq(MoodCatalog.cause_of(&"company"), MoodCatalog.CAUSE_COMPANY)

func test_finite_ids_have_no_cause() -> void:
	# They print a countdown instead, so a cause here would be a second answer to
	# the same question.
	for id: StringName in [&"good_meal", &"bad_meal", &"interrupted_meal",
			&"good_shopping", &"good_lodging", &"bad_chat"]:
		assert_eq(MoodCatalog.cause_of(id), "", "%s ticks down rather than being caused" % id)

# --- unknown ids --------------------------------------------------------------

func test_unknown_id_falls_back_to_a_capitalised_form() -> void:
	assert_eq(MoodCatalog.label_of(&"some_modded_thing"), "Some Modded Thing")

func test_unknown_id_is_never_blank() -> void:
	# Hiding an unrecognised modifier would leave the happiness number unable to
	# add up with no way for the player to find out why.
	assert_false(MoodCatalog.label_of(&"zzz_unheard_of").is_empty())
	assert_false(MoodCatalog.describe(&"zzz_unheard_of").is_empty())

func test_unknown_id_has_no_cause_and_no_blurb() -> void:
	assert_eq(MoodCatalog.cause_of(&"zzz_unheard_of"), "")
	assert_eq(MoodCatalog.blurb_of(&"zzz_unheard_of"), "")

# --- disease family -----------------------------------------------------------

func test_disease_modifier_resolves_through_disease_data() -> void:
	var disease: DiseaseData = DiseaseData.by_id(&"void_sickness")
	assert_not_null(disease, "the fixture disease still exists")
	var id: StringName = StringName(MoodCatalog.DISEASE_PREFIX + "void_sickness")
	assert_eq(MoodCatalog.label_of(id), disease.display_name)
	assert_eq(MoodCatalog.blurb_of(id), disease.description)

func test_disease_modifier_cause_is_while_sick() -> void:
	var id: StringName = StringName(MoodCatalog.DISEASE_PREFIX + "station_flu")
	assert_eq(MoodCatalog.cause_of(id), MoodCatalog.CAUSE_SICK)

func test_missing_disease_degrades_to_the_fallback() -> void:
	# A save or a mod referring to a disease that is no longer installed.
	var id: StringName = StringName(MoodCatalog.DISEASE_PREFIX + "not_a_disease")
	assert_eq(MoodCatalog.label_of(id), MoodCatalog.fallback_label(id))
	assert_eq(MoodCatalog.cause_of(id), "", "an unresolved id claims no cause")

# --- trait family -------------------------------------------------------------

func test_trait_modifier_resolves_through_trait_data() -> void:
	var traits: Array[TraitData] = TraitData.all()
	assert_gt(traits.size(), 0, "there is at least one authored trait to check")
	var with_offset: TraitData = null
	for trait_data: TraitData in traits:
		if not is_zero_approx(trait_data.happiness_offset):
			with_offset = trait_data
			break
	assert_not_null(with_offset, "at least one trait carries a happiness offset")
	assert_eq(MoodCatalog.label_of(with_offset.id), with_offset.display_name)
	assert_eq(MoodCatalog.cause_of(with_offset.id), MoodCatalog.CAUSE_TRAIT)

# --- event family -------------------------------------------------------------

func test_event_modifier_resolves_through_its_authored_effect_id() -> void:
	# morale_lightshow's effect declares `meteor_lightshow`, which resembles the
	# event id but is not equal to it - the scan is what closes that gap.
	var described: Dictionary = MoodCatalog.describe(&"meteor_lightshow")
	assert_eq(String(described.get("label", "")), "Meteor Shower Light Show")
	assert_eq(String(described.get("cause", "")), MoodCatalog.CAUSE_EVENT)

func test_event_prefix_form_resolves_to_the_same_event() -> void:
	# The fallback id EventEffectHappinessModifier builds when it has none of its
	# own: "event_" + the event's id.
	var id: StringName = StringName(MoodCatalog.EVENT_PREFIX + "morale_lightshow")
	assert_eq(MoodCatalog.label_of(id), "Meteor Shower Light Show")

func test_event_lookup_survives_a_cache_reset() -> void:
	MoodCatalog.reset_event_cache()
	assert_eq(MoodCatalog.label_of(&"meteor_lightshow"), "Meteor Shower Light Show")

func test_unknown_event_prefixed_id_falls_back() -> void:
	var id: StringName = StringName(MoodCatalog.EVENT_PREFIX + "no_such_event")
	assert_eq(MoodCatalog.label_of(id), MoodCatalog.fallback_label(id))

# --- the duration / cause column ----------------------------------------------

func test_finite_duration_reads_as_hours() -> void:
	assert_eq(MoodCatalog.duration_text(&"good_meal", 3.0), "3h")
	assert_eq(MoodCatalog.duration_text(&"good_meal", 2.6), "3h", "rounds to the nearest hour")

func test_sub_hour_duration_does_not_round_to_zero() -> void:
	# "0h" would read as expired on a modifier that is still applying.
	assert_eq(MoodCatalog.duration_text(&"good_meal", 0.2), "<1h")

func test_permanent_duration_reads_as_its_cause() -> void:
	assert_eq(MoodCatalog.duration_text(&"trait_exterior", INF), MoodCatalog.CAUSE_OUTSIDE)
	assert_eq(MoodCatalog.duration_text(
		StringName(MoodCatalog.DISEASE_PREFIX + "station_flu"), INF), MoodCatalog.CAUSE_SICK)

func test_permanent_unknown_prints_nothing_rather_than_infinity() -> void:
	assert_eq(MoodCatalog.duration_text(&"zzz_unheard_of", INF), "")

# --- sorting ------------------------------------------------------------------

func _row(id: StringName, value: float, hours: float = INF) -> Dictionary:
	return {"id": id, "value": value, "hours_remaining": hours}

func test_sort_is_by_absolute_value_descending() -> void:
	var rows: Array[Dictionary] = [
		_row(&"a", 0.02), _row(&"b", -0.09), _row(&"c", 0.05),
	]
	var sorted: Array[Dictionary] = MoodCatalog.sort_by_magnitude(rows)
	assert_eq(String(sorted[0]["id"]), "b", "the biggest mover leads, sign irrelevant")
	assert_eq(String(sorted[1]["id"]), "c")
	assert_eq(String(sorted[2]["id"]), "a")

func test_sort_breaks_ties_on_id_so_the_list_does_not_reshuffle() -> void:
	var first: Array[Dictionary] = MoodCatalog.sort_by_magnitude(
		[_row(&"zebra", 0.05), _row(&"apple", -0.05)])
	var second: Array[Dictionary] = MoodCatalog.sort_by_magnitude(
		[_row(&"apple", -0.05), _row(&"zebra", 0.05)])
	assert_eq(String(first[0]["id"]), "apple")
	assert_eq(String(second[0]["id"]), "apple", "input order does not change the result")

func test_sort_does_not_mutate_the_input() -> void:
	var rows: Array[Dictionary] = [_row(&"a", 0.01), _row(&"b", -0.5)]
	MoodCatalog.sort_by_magnitude(rows)
	assert_eq(String(rows[0]["id"]), "a", "the caller's array is untouched")

func test_modifier_sum_adds_signed_values() -> void:
	assert_almost_eq(MoodCatalog.modifier_sum(
		[_row(&"a", 0.05), _row(&"b", -0.09), _row(&"c", 0.04)]), 0.0, 0.0001)

func test_modifier_sum_of_nothing_is_zero() -> void:
	var empty: Array[Dictionary] = []
	assert_eq(MoodCatalog.modifier_sum(empty), 0.0)

# --- the happiness formula ----------------------------------------------------

func test_combine_is_the_needs_mean_plus_the_modifiers() -> void:
	assert_almost_eq(MoodCatalog.combine(0.71, 0.05 + 0.04 - 0.06), 0.74, 0.0001)

func test_combine_clamps_at_the_top() -> void:
	# The case the breakdown must not misreport: 0.98 + 0.05 reads 100%, not 103%.
	assert_eq(MoodCatalog.combine(0.98, 0.05), 1.0)

func test_combine_clamps_at_the_bottom() -> void:
	assert_eq(MoodCatalog.combine(0.1, -0.4), 0.0)

func test_combine_with_no_modifiers_is_the_needs_mean() -> void:
	assert_almost_eq(MoodCatalog.combine(0.42, 0.0), 0.42, 0.0001)

func test_breakdown_rows_reproduce_the_displayed_happiness() -> void:
	# The end-to-end shape the tab renders: the needs-average line plus every
	# listed row equals the number in the header.
	var rows: Array[Dictionary] = [
		_row(&"good_meal", 0.05, 3.0),
		_row(&"optimist", 0.04),
		_row(&"cramped", -0.06),
		_row(StringName(MoodCatalog.DISEASE_PREFIX + "void_sickness"), -0.09),
	]
	assert_almost_eq(MoodCatalog.combine(0.71, MoodCatalog.modifier_sum(rows)), 0.65, 0.0001)

func test_breakdown_rows_reproduce_a_clamped_happiness() -> void:
	var rows: Array[Dictionary] = [_row(&"good_meal", 0.05, 3.0), _row(&"good_shopping", 0.05, 2.0)]
	assert_eq(MoodCatalog.combine(0.98, MoodCatalog.modifier_sum(rows)), 1.0,
		"the sum overshoots but the reading does not")
