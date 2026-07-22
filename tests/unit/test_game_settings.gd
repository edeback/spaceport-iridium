extends GutTest

## Unit tests for WI-36's settings model (GameSettings). Pure: a ConfigFile in
## memory, plain InputEvent objects, no AudioServer / window / InputMap and no
## Global. Applying any of this to the engine is Global's job and isn't tested
## here.

func _key(physical: Key, ctrl: bool = false, shift: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = physical
	event.ctrl_pressed = ctrl
	event.shift_pressed = shift
	return event

func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event

# --- audio -------------------------------------------------------------------

func test_full_volume_is_unattenuated() -> void:
	assert_almost_eq(GameSettings.volume_to_db(1.0), 0.0, 0.001, "a slider at max leaves the bus alone")

func test_zero_volume_is_silence_not_negative_infinity() -> void:
	# linear_to_db(0) is -inf, which AudioServer refuses; the floor stands in.
	assert_eq(GameSettings.volume_to_db(0.0), GameSettings.SILENT_DB, "zero maps to the silence floor")

func test_volume_is_monotonic_and_clamped() -> void:
	assert_lt(GameSettings.volume_to_db(0.25), GameSettings.volume_to_db(0.75), "louder slider, louder bus")
	assert_almost_eq(GameSettings.volume_to_db(5.0), 0.0, 0.001, "over-range clamps to 0 dB")
	assert_eq(GameSettings.volume_to_db(-1.0), GameSettings.SILENT_DB, "negative clamps to silence")

func test_volume_round_trips_through_db() -> void:
	assert_almost_eq(GameSettings.db_to_volume(GameSettings.volume_to_db(0.4)), 0.4, 0.001, "db_to_volume inverts")
	assert_eq(GameSettings.db_to_volume(GameSettings.SILENT_DB), 0.0, "the floor reads back as zero")

# --- display -----------------------------------------------------------------

func test_resolution_clamps_to_screen() -> void:
	var clamped := GameSettings.clamp_resolution(Vector2i(3840, 2160), Vector2i(1920, 1080))
	assert_eq(clamped, Vector2i(1920, 1080), "a 4K window won't open on a 1080p screen")

func test_resolution_smaller_than_screen_is_untouched() -> void:
	assert_eq(GameSettings.clamp_resolution(Vector2i(1280, 720), Vector2i(1920, 1080)), Vector2i(1280, 720))

func test_unknown_screen_size_leaves_resolution_alone() -> void:
	# Headless/dummy display servers report a zero rect; don't "clamp" to nothing.
	assert_eq(GameSettings.clamp_resolution(Vector2i(1600, 900), Vector2i.ZERO), Vector2i(1600, 900))

func test_available_resolutions_filter_by_screen() -> void:
	var options := GameSettings.available_resolutions(Vector2i(1920, 1080))
	assert_has(options, Vector2i(1920, 1080), "the exact screen size is offered")
	assert_does_not_have(options, Vector2i(2560, 1440), "bigger-than-screen presets are dropped")

func test_available_resolutions_never_empty() -> void:
	var options := GameSettings.available_resolutions(Vector2i(640, 480))
	assert_eq(options.size(), 1, "a tiny screen still gets one fallback option")

# --- event serialization ------------------------------------------------------

func test_key_event_round_trips() -> void:
	var original := _key(KEY_F, true, true)
	var restored := GameSettings.event_from_dict(GameSettings.event_to_dict(original)) as InputEventKey
	assert_not_null(restored, "a key event survives the round trip")
	assert_eq(restored.physical_keycode, KEY_F, "physical keycode preserved")
	assert_true(restored.ctrl_pressed, "ctrl preserved")
	assert_true(restored.shift_pressed, "shift preserved")
	assert_false(restored.alt_pressed, "alt stays off")

func test_mouse_event_round_trips() -> void:
	var restored := GameSettings.event_from_dict(GameSettings.event_to_dict(_mouse(MOUSE_BUTTON_MIDDLE))) as InputEventMouseButton
	assert_not_null(restored, "a mouse event survives the round trip")
	assert_eq(restored.button_index, MOUSE_BUTTON_MIDDLE, "button index preserved")

func test_gamepad_events_are_not_remappable_in_v1() -> void:
	var joy := InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_A
	assert_eq(GameSettings.event_to_dict(joy), {}, "joypad events serialize to nothing")
	assert_false(GameSettings.is_remappable(joy), "so the remap screen refuses them")

func test_corrupt_event_dicts_parse_to_null() -> void:
	assert_null(GameSettings.event_from_dict({}), "empty dict is not an event")
	assert_null(GameSettings.event_from_dict({"type": "telepathy"}), "unknown type is not an event")
	assert_null(GameSettings.event_from_dict({"type": "key"}), "a key event with no key is not an event")
	assert_null(GameSettings.event_from_dict({"type": "mouse", "button_index": 0}), "button 0 is no button")

# --- conflicts ----------------------------------------------------------------

func test_same_key_conflicts() -> void:
	assert_true(GameSettings.events_conflict(_key(KEY_G), _key(KEY_G)), "same key, same binding")

func test_different_keys_do_not_conflict() -> void:
	assert_false(GameSettings.events_conflict(_key(KEY_G), _key(KEY_H)))

func test_modifiers_distinguish_bindings() -> void:
	assert_false(GameSettings.events_conflict(_key(KEY_S), _key(KEY_S, true)), "Ctrl+S is not S")
	assert_true(GameSettings.events_conflict(_key(KEY_S, true), _key(KEY_S, true)), "Ctrl+S is Ctrl+S")

func test_key_and_mouse_never_conflict() -> void:
	assert_false(GameSettings.events_conflict(_key(KEY_A), _mouse(MOUSE_BUTTON_LEFT)))

func test_mouse_buttons_conflict_by_index() -> void:
	assert_true(GameSettings.events_conflict(_mouse(MOUSE_BUTTON_RIGHT), _mouse(MOUSE_BUTTON_RIGHT)))
	assert_false(GameSettings.events_conflict(_mouse(MOUSE_BUTTON_RIGHT), _mouse(MOUSE_BUTTON_LEFT)))

# --- bindings -----------------------------------------------------------------

func test_setting_and_reading_a_binding() -> void:
	var settings := GameSettings.new()
	settings.set_binding(&"build", [_key(KEY_B)] as Array[InputEvent])
	assert_true(settings.has_binding(&"build"), "the override is recorded")
	var events := settings.get_binding(&"build")
	assert_eq(events.size(), 1, "one event stored")
	assert_true(GameSettings.events_conflict(events[0], _key(KEY_B)), "and it's the one we set")

func test_unset_action_reports_no_binding() -> void:
	var settings := GameSettings.new()
	assert_false(settings.has_binding(&"build"), "an untouched action falls back to the project default")
	assert_eq(settings.get_binding(&"build").size(), 0)

func test_empty_binding_clears_rather_than_unbinding() -> void:
	# No action may end up with zero events, so an empty list is a reset.
	var settings := GameSettings.new()
	settings.set_binding(&"build", [_key(KEY_B)] as Array[InputEvent])
	settings.set_binding(&"build", [] as Array[InputEvent])
	assert_false(settings.keybinds.has(&"build"), "the override is dropped, not stored empty")

func test_unremappable_events_are_never_stored() -> void:
	var settings := GameSettings.new()
	var joy := InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_A
	settings.set_binding(&"build", [joy] as Array[InputEvent])
	assert_false(settings.has_binding(&"build"), "a joypad binding leaves the action on its default")

func test_clear_all_bindings() -> void:
	var settings := GameSettings.new()
	settings.set_binding(&"build", [_key(KEY_B)] as Array[InputEvent])
	settings.set_binding(&"remove", [_key(KEY_R)] as Array[InputEvent])
	settings.clear_all_bindings()
	assert_eq(settings.keybinds.size(), 0, "reset-to-defaults drops every override")

# --- persistence --------------------------------------------------------------

func test_config_round_trip_preserves_everything() -> void:
	var settings := GameSettings.new()
	settings.music_volume = 0.33
	settings.effects_volume = 0.66
	settings.window_mode = GameSettings.WindowMode.FULLSCREEN
	settings.resolution = Vector2i(1600, 900)
	settings.set_binding(&"build", [_key(KEY_B, true)] as Array[InputEvent])

	var restored := GameSettings.from_config(settings.to_config())
	assert_almost_eq(restored.music_volume, 0.33, 0.001)
	assert_almost_eq(restored.effects_volume, 0.66, 0.001)
	assert_eq(restored.window_mode, GameSettings.WindowMode.FULLSCREEN)
	assert_eq(restored.resolution, Vector2i(1600, 900))
	assert_true(restored.has_binding(&"build"), "the keybind override survives a save/load")
	assert_true(GameSettings.events_conflict(restored.get_binding(&"build")[0], _key(KEY_B, true)))

func test_empty_config_yields_defaults() -> void:
	var restored := GameSettings.from_config(ConfigFile.new())
	var defaults := GameSettings.new()
	assert_almost_eq(restored.music_volume, defaults.music_volume, 0.001)
	assert_eq(restored.window_mode, GameSettings.WindowMode.WINDOWED)
	assert_eq(restored.resolution, GameSettings.DEFAULT_RESOLUTION)
	assert_eq(restored.keybinds.size(), 0)

func test_corrupt_config_falls_back_silently() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music", "loud")
	config.set_value("display", "resolution", "1920x1080")
	config.set_value("display", "window_mode", 99)
	config.set_value("keybinds", "build", ["not an event dict", {"type": "nonsense"}])
	var restored := GameSettings.from_config(config)
	assert_between(restored.music_volume, 0.0, 1.0, "a junk volume still lands in range")
	assert_eq(restored.resolution, GameSettings.DEFAULT_RESOLUTION, "a junk resolution falls back")
	assert_eq(restored.window_mode, GameSettings.WindowMode.WINDOWED, "an unknown window mode falls back")
	assert_false(restored.keybinds.has(&"build"), "a binding with no parseable events is dropped entirely")

func test_out_of_range_volumes_are_clamped_on_load() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music", 4.0)
	config.set_value("audio", "effects", -2.0)
	var restored := GameSettings.from_config(config)
	assert_eq(restored.music_volume, 1.0)
	assert_eq(restored.effects_volume, 0.0)

# --- labels -------------------------------------------------------------------

func test_describe_event_lists_modifiers_before_the_key() -> void:
	var text := GameSettings.describe_event(_key(KEY_A, true, true))
	assert_string_contains(text, "Ctrl")
	assert_string_contains(text, "Shift")

func test_describe_event_names_mouse_buttons() -> void:
	assert_eq(GameSettings.describe_event(_mouse(MOUSE_BUTTON_RIGHT)), "Right Click")

func test_describe_events_reports_unbound_for_an_empty_list() -> void:
	assert_eq(GameSettings.describe_events([]), "Unbound")
