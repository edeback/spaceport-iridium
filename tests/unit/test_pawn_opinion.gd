extends GutTest

## [PawnOpinion] (WI-48): one pawn's standing with another. F19 (the first
## audit) listed it as one of three classes with no suite; WI-69 §5 adds it.
##
## Pure: nothing here touches Global. What matters is that a record means the
## same thing after a save as before it - including after a JSON pass, which
## hands every number back as a float - and that "never spoken" stays
## distinguishable from "indifferent".

func test_a_new_record_is_indifferent_and_unmet() -> void:
	var record := PawnOpinion.new()
	assert_eq(record.value, 0.0)
	assert_eq(record.chats, 0)
	assert_true(record.last_positive, "an unmet pair has no bad chat on record")

func test_an_unmet_pair_has_no_stamp() -> void:
	# -INF, so "hours since" comes out INF and partner weighting reads them as
	# strangers rather than as a pair who spoke at hour zero.
	var record := PawnOpinion.new()
	record.last_cycle = 3
	record.last_hour = 5
	assert_eq(record.stamp_hours(), -INF, "no chats means no stamp, whatever the calendar fields say")

func test_the_stamp_counts_hours_from_the_start_of_cycle_one() -> void:
	var record := PawnOpinion.new()
	record.chats = 1
	record.last_cycle = 1
	record.last_hour = 6
	assert_eq(record.stamp_hours(), 6.0, "cycle 1 is hour zero of the calendar")
	record.last_cycle = 3
	record.last_hour = 2
	assert_eq(record.stamp_hours(), float(2 * TimeManager.HOURS_PER_CYCLE + 2))

func test_a_record_round_trips() -> void:
	var record := PawnOpinion.new()
	record.value = -37.5
	record.chats = 4
	record.last_cycle = 7
	record.last_hour = 19
	record.last_positive = false
	var restored: PawnOpinion = PawnOpinion.from_dict(record.to_dict())
	assert_eq(restored.value, -37.5)
	assert_eq(restored.chats, 4)
	assert_eq(restored.last_cycle, 7)
	assert_eq(restored.last_hour, 19)
	assert_false(restored.last_positive)
	assert_eq(restored.stamp_hours(), record.stamp_hours())

func test_a_json_pass_restores_integer_fields_as_integers() -> void:
	# JSON has one number type, so a save hands back 4.0 for 4 - the F10 class.
	var record := PawnOpinion.new()
	record.value = 12.0
	record.chats = 4
	record.last_cycle = 2
	record.last_hour = 9
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(record.to_dict()))
	var restored: PawnOpinion = PawnOpinion.from_dict(parsed)
	assert_eq(typeof(restored.chats), TYPE_INT)
	assert_eq(typeof(restored.last_cycle), TYPE_INT)
	assert_eq(typeof(restored.last_hour), TYPE_INT)
	assert_eq(typeof(restored.value), TYPE_FLOAT)
	assert_eq(typeof(restored.last_positive), TYPE_BOOL)
	assert_eq(restored.stamp_hours(), record.stamp_hours())

func test_loading_clamps_a_value_out_of_range() -> void:
	# A hand-edited save, or a tuning change that narrowed the range.
	assert_eq(PawnOpinion.from_dict({"value": 250.0}).value, SocialMath.OPINION_MAX)
	assert_eq(PawnOpinion.from_dict({"value": -250.0}).value, -SocialMath.OPINION_MAX)

func test_loading_never_yields_a_negative_chat_count() -> void:
	assert_eq(PawnOpinion.from_dict({"chats": -3}).chats, 0)

func test_missing_keys_load_as_a_new_record() -> void:
	var restored: PawnOpinion = PawnOpinion.from_dict({})
	assert_eq(restored.value, 0.0)
	assert_eq(restored.chats, 0)
	assert_eq(restored.last_cycle, 0)
	assert_eq(restored.last_hour, 0)
	assert_true(restored.last_positive)
	assert_eq(restored.stamp_hours(), -INF)

func test_the_save_keys_are_stable() -> void:
	# Renaming one of these orphans every opinion in every existing save.
	var keys: Array = PawnOpinion.new().to_dict().keys()
	keys.sort()
	assert_eq(keys, ["chats", "cycle", "hour", "positive", "value"])
