extends GutTest

## Unit tests for the station name's persistence and its trip into a save slot
## name (WI-59). Both entry points are pure statics on SaveManager, so this suite
## never touches Global.

# --- read_station_name precedence ---------------------------------------------

func test_reads_the_authoritative_sections_field() -> void:
	var data: Dictionary = {
		"sections": {"station": "Iridium Reach"},
		"meta": {"station": "stale"},
	}
	assert_eq(SaveSlots.read_station_name(data), "Iridium Reach")

func test_falls_back_to_the_meta_summary() -> void:
	# meta is written for the slot browser; if the sections field is somehow
	# missing it is still a truthful answer.
	var data: Dictionary = {"sections": {}, "meta": {"station": "Halfway House"}}
	assert_eq(SaveSlots.read_station_name(data), "Halfway House")

func test_a_pre_wi59_save_reads_as_unnamed() -> void:
	# Neither key present: the station has no name, and Global renders the
	# default rather than an empty header.
	assert_eq(SaveSlots.read_station_name({"sections": {}, "meta": {}}), "")

func test_an_empty_sections_field_does_not_mask_meta() -> void:
	# "" in the section is indistinguishable from never-written, so meta wins.
	var data: Dictionary = {"sections": {"station": ""}, "meta": {"station": "Anchorage"}}
	assert_eq(SaveSlots.read_station_name(data), "Anchorage")

func test_a_malformed_envelope_is_not_a_crash() -> void:
	assert_eq(SaveSlots.read_station_name({}), "")

# --- the station name as a save slot name -------------------------------------

func test_a_plain_name_survives_sanitising() -> void:
	assert_eq(SaveSlots.sanitize_slot_name("Iridium Reach"), "Iridium Reach")

func test_path_characters_are_folded_out_of_a_station_name() -> void:
	# The name is player-typed and becomes a file name, so anything that could
	# walk out of user://saves/ has to go.
	assert_eq(SaveSlots.sanitize_slot_name("../Deep Space 9"), "___Deep Space 9")

func test_a_name_of_only_separators_yields_nothing_usable() -> void:
	# The slot field rejects "" rather than writing an unreachable file; the
	# station itself still displays whatever the player typed.
	assert_eq(SaveSlots.sanitize_slot_name("___"), "")

func test_the_default_station_name_is_a_usable_slot_name() -> void:
	# The pre-filled save name has to survive its own sanitiser, or the common
	# case would open the save dialog with an empty field.
	assert_ne(SaveSlots.sanitize_slot_name(Global.DEFAULT_STATION_NAME), "")
