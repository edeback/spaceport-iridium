extends GutTest

## Unit tests for WI-36's slot-list plumbing on SaveManager. Only the pure,
## static parts are exercised - summarize()/describe_slot()/sanitize_slot_name()
## take a parsed envelope or a string and return a value. Nothing here touches
## the filesystem, Global, or a live manager.

func _envelope(meta: Dictionary, sections: Dictionary = {}) -> Dictionary:
	var data: Dictionary = {
		"version": SaveManager.SAVE_VERSION,
		"timestamp": "2026-07-22T10:11:12",
		"sections": sections,
	}
	if not meta.is_empty():
		data["meta"] = meta
	return data

# --- summarize ----------------------------------------------------------------

func test_summary_reads_the_meta_block() -> void:
	var info := SaveManager.summarize(_envelope({
		"cycle": 12, "hour": 7, "credits": 4200, "crew": 9, "tier": 3,
	}), "alpha")
	assert_eq(info["slot"], "alpha")
	assert_eq(info["cycle"], 12)
	assert_eq(info["hour"], 7)
	assert_eq(info["credits"], 4200)
	assert_eq(info["crew"], 9)
	assert_eq(info["tier"], 3)
	assert_eq(info["timestamp"], "2026-07-22T10:11:12")

func test_summary_falls_back_to_sections_on_pre_meta_saves() -> void:
	# Saves written before WI-36 have no meta block; the same numbers are
	# recoverable from the sections, so old saves still list properly.
	var info := SaveManager.summarize(_envelope({}, {
		"time": {"cycle": 5, "hour": 18},
		"resources": {"credits": 777},
		"pawns": [{}, {}, {}],
	}), "legacy")
	assert_eq(info["cycle"], 5, "cycle recovered from the time section")
	assert_eq(info["hour"], 18, "hour recovered from the time section")
	assert_eq(info["credits"], 777, "credits recovered from the resources section")
	assert_eq(info["crew"], 3, "crew recovered from the pawn list length")
	assert_eq(info["tier"], 1, "tier has no pre-meta source, so it defaults")

func test_summary_of_an_empty_envelope_does_not_crash() -> void:
	var info := SaveManager.summarize({}, "broken")
	assert_eq(info["slot"], "broken")
	assert_eq(info["cycle"], 0)
	assert_eq(info["crew"], 0)
	assert_eq(info["timestamp"], "")

func test_current_version_is_loadable() -> void:
	var info := SaveManager.summarize(_envelope({"cycle": 1}), "current")
	assert_true(info["loadable"], "a save at the current version loads")

func test_unmigratable_version_lists_but_is_not_loadable() -> void:
	# It still appears in the list so the player can delete it - it just can't
	# be loaded by this build.
	var data := _envelope({"cycle": 1})
	data["version"] = SaveManager.SAVE_VERSION + 99
	var info := SaveManager.summarize(data, "future")
	assert_false(info["loadable"], "a version this build can't migrate is greyed out")

# --- describe_slot ------------------------------------------------------------

func test_describe_slot_reads_as_a_one_line_summary() -> void:
	var text := SaveManager.describe_slot({
		"cycle": 4, "hour": 14, "credits": 12340, "crew": 6, "tier": 2,
	})
	assert_string_contains(text, "Cycle 4")
	assert_string_contains(text, "14:00")
	assert_string_contains(text, "12340 cr")
	assert_string_contains(text, "6 crew")
	assert_string_contains(text, "Tier 2")

func test_describe_slot_pads_the_hour() -> void:
	assert_string_contains(SaveManager.describe_slot({"hour": 6}), "06:00")

# --- slot name sanitizing -----------------------------------------------------

func test_ordinary_names_pass_through() -> void:
	assert_eq(SaveManager.sanitize_slot_name("My Station 2"), "My Station 2")
	assert_eq(SaveManager.sanitize_slot_name("save-01"), "save-01")

func test_names_are_trimmed() -> void:
	assert_eq(SaveManager.sanitize_slot_name("  tidy  "), "tidy")

func test_path_separators_cannot_escape_the_save_directory() -> void:
	assert_eq(SaveManager.sanitize_slot_name("../../etc/passwd"), "______etc_passwd")
	assert_false(SaveManager.sanitize_slot_name("a/b").contains("/"), "forward slashes are folded")
	assert_false(SaveManager.sanitize_slot_name("a\\b").contains("\\"), "backslashes are folded")
	assert_false(SaveManager.sanitize_slot_name("C:name").contains(":"), "drive colons are folded")

func test_names_with_nothing_usable_are_rejected() -> void:
	assert_eq(SaveManager.sanitize_slot_name(""), "", "an empty name is rejected")
	assert_eq(SaveManager.sanitize_slot_name("   "), "", "whitespace only is rejected")
	assert_eq(SaveManager.sanitize_slot_name("///"), "", "punctuation only leaves nothing to name a file")

func test_slot_path_stays_under_the_save_directory() -> void:
	assert_eq(SaveManager.slot_path("alpha"), SaveManager.SAVE_DIR + "alpha.json")
