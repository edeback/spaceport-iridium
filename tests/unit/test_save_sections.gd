extends GutTest

## WI-47 M3 + M11: the save-section registry that replaced the 17-entry dictionary
## literal, and the mod-drift rule the slot browser and the load path share.
##
## The registry is static, so every test clears it first - a leaked test section
## would otherwise be called during a real save.

class Recorder extends Node:
	var collected: int = 0
	var applied: Variant = null
	var payload: Dictionary = {"v": 1}

	func collect() -> Dictionary:
		collected += 1
		return payload

	func apply(data: Dictionary) -> void:
		applied = data

var _recorders: Array[Recorder] = []

func before_each() -> void:
	SaveManager.clear_sections_for_test()

func after_each() -> void:
	SaveManager.clear_sections_for_test()
	for recorder: Recorder in _recorders:
		if is_instance_valid(recorder):
			recorder.free()
	_recorders.clear()

func _recorder() -> Recorder:
	var recorder := Recorder.new()
	_recorders.append(recorder)
	return recorder

func _register(id: StringName, order: int) -> Recorder:
	var recorder: Recorder = _recorder()
	SaveManager.register_section(id, order, recorder.collect, recorder.apply)
	return recorder

func _ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for section: SaveSection in SaveManager.sections_in_order():
		out.append(section.id)
	return out

# --- registration ---------------------------------------------------------------

func test_sections_come_back_in_order_not_registration_order() -> void:
	_register(&"late", 300)
	_register(&"early", 100)
	_register(&"middle", 200)
	assert_eq(_ids(), [&"early", &"middle", &"late"] as Array[StringName])

func test_equal_orders_break_on_id_for_reproducibility() -> void:
	_register(&"zebra", 100)
	_register(&"apple", 100)
	assert_eq(_ids(), [&"apple", &"zebra"] as Array[StringName])

func test_registering_an_id_twice_replaces_rather_than_duplicates() -> void:
	# This is what makes the registry survive the scene reload a load performs:
	# every manager re-registers on the way back up.
	_register(&"world", 100)
	_register(&"world", 100)
	assert_eq(_ids(), [&"world"] as Array[StringName])

func test_re_registering_can_move_a_section() -> void:
	_register(&"a", 100)
	_register(&"b", 200)
	var replacement: Recorder = _recorder()
	SaveManager.register_section(&"a", 300, replacement.collect, replacement.apply)
	assert_eq(_ids(), [&"b", &"a"] as Array[StringName])

func test_a_section_with_no_id_is_refused() -> void:
	_register(&"", 100)
	assert_eq(_ids(), [] as Array[StringName])

func test_a_section_whose_owner_was_freed_is_pruned() -> void:
	# A mod manager that no longer exists must stop being called into, rather than
	# taking the next save down with it.
	_register(&"survivor", 100)
	var doomed := Recorder.new()
	SaveManager.register_section(&"doomed", 200, doomed.collect, doomed.apply)
	doomed.free()
	assert_eq(_ids(), [&"survivor"] as Array[StringName])

# --- mod drift (M11) ------------------------------------------------------------
# No mods are loaded in a test run, so every saved record reads as missing.

func test_a_save_with_no_mods_never_drifts() -> void:
	assert_eq(SaveSlots.mod_drift([]), PackedStringArray())

func test_a_pre_wi47_save_reads_as_no_mods() -> void:
	# The key is absent entirely on legacy saves; summarize() defaults it to [].
	# If that read as "mods missing", every legacy save would warn.
	var info: Dictionary = SaveSlots.summarize({"version": SaveSlots.SAVE_VERSION}, "legacy")
	assert_eq(info.get("mods", null), [], "absent means no mods, not unknown mods")
	assert_eq(SaveSlots.mod_drift(info.get("mods", [])), PackedStringArray())

func test_a_missing_mod_is_named_with_its_version() -> void:
	var drift: PackedStringArray = SaveSlots.mod_drift([{"id": "coolmod", "version": "1.2.0"}])
	assert_eq(drift.size(), 1)
	assert_string_contains(drift[0], "coolmod")
	assert_string_contains(drift[0], "1.2.0")

func test_every_missing_mod_is_listed_not_counted() -> void:
	# "2 mods missing" is not actionable; the player needs the names.
	var drift: PackedStringArray = SaveSlots.mod_drift([
		{"id": "one", "version": "1"}, {"id": "two", "version": "2"}])
	assert_eq(drift.size(), 2)

func test_a_malformed_record_is_skipped_not_crashed_on() -> void:
	# Hand-edited and truncated saves reach this too. A junk entry is dropped
	# rather than reported as a missing mod the player can't possibly install.
	assert_eq(SaveSlots.mod_drift([null, "nonsense", {}, {"id": ""}]), PackedStringArray())
