class_name GameSettings
extends RefCounted

## Player-facing options (WI-36): audio bus volumes, window mode / resolution,
## and keybind overrides. Deliberately a plain RefCounted with no engine calls -
## it is the *model* only, so it can be unit-tested without a window, an
## AudioServer, or an InputMap. Global owns the single live instance and is the
## only thing that applies these values to the engine.
##
## Persistence is a ConfigFile at user://settings.cfg. Keybinds are stored as
## plain dictionaries rather than serialized InputEvent objects so a hand-edited
## or truncated settings file can never instantiate something unexpected -
## anything that doesn't parse back into a keyboard/mouse event is dropped and
## that action falls back to its project default.

const SETTINGS_PATH: String = "user://settings.cfg"

## Bus names Global creates on the fly if the project's layout lacks them.
const MUSIC_BUS: String = "Music"
const EFFECTS_BUS: String = "Effects"

## Linear volume below which a bus is treated as silent. linear_to_db(0) is
## -inf, which AudioServer rejects, so the slider bottom maps to this instead.
const SILENT_DB: float = -60.0

enum WindowMode { WINDOWED, FULLSCREEN }

## Offered in the resolution dropdown (windowed only). Anything larger than the
## player's screen is filtered out at display time, not here.
const RESOLUTION_PRESETS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

const DEFAULT_RESOLUTION: Vector2i = Vector2i(1920, 1080)

var music_volume: float = 0.8
var effects_volume: float = 0.8
var window_mode: WindowMode = WindowMode.WINDOWED
var resolution: Vector2i = DEFAULT_RESOLUTION
## action -> Array of event dictionaries. Only *remapped* actions appear here;
## an absent action means "use the project default", so adding or retuning a
## default binding later reaches players who never touched that key.
var keybinds: Dictionary[StringName, Array] = {}

# --- audio helpers ------------------------------------------------------------

## Slider position (0..1) -> bus decibels. 1.0 is 0 dB (unattenuated).
static func volume_to_db(linear: float) -> float:
	var clamped: float = clampf(linear, 0.0, 1.0)
	if clamped <= 0.0:
		return SILENT_DB
	return maxf(linear_to_db(clamped), SILENT_DB)

## Inverse of volume_to_db, for seeding a slider from an already-configured bus.
static func db_to_volume(db: float) -> float:
	if db <= SILENT_DB:
		return 0.0
	return clampf(db_to_linear(db), 0.0, 1.0)

# --- display helpers ----------------------------------------------------------

## Keep a windowed size inside the usable screen area. A settings file written on
## a 4K monitor must not open an off-screen window on a 1080p laptop.
static func clamp_resolution(size: Vector2i, screen: Vector2i) -> Vector2i:
	if screen.x <= 0 or screen.y <= 0:
		return size
	return Vector2i(mini(size.x, screen.x), mini(size.y, screen.y))

## Presets that actually fit `screen`, always including at least the smallest
## one so the dropdown is never empty on a tiny display.
static func available_resolutions(screen: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for preset: Vector2i in RESOLUTION_PRESETS:
		if screen.x <= 0 or screen.y <= 0 or (preset.x <= screen.x and preset.y <= screen.y):
			out.append(preset)
	if out.is_empty():
		out.append(RESOLUTION_PRESETS[0])
	return out

# --- input event (de)serialization --------------------------------------------

## v1 is keyboard + mouse only (per WI-36); a gamepad event returns {} and is
## therefore never captured or written.
static func event_to_dict(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key := event as InputEventKey
		var out: Dictionary = {
			"type": "key",
			# Physical is what the InputMap defaults use - it keeps WASD in the
			# same place on an AZERTY keyboard.
			"physical_keycode": int(key.physical_keycode),
			"keycode": int(key.keycode),
		}
		_write_modifiers(out, key)
		return out
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		var out: Dictionary = {
			"type": "mouse",
			"button_index": int(mouse.button_index),
		}
		_write_modifiers(out, mouse)
		return out
	return {}

static func _write_modifiers(out: Dictionary, event: InputEventWithModifiers) -> void:
	out["alt"] = event.alt_pressed
	out["shift"] = event.shift_pressed
	out["ctrl"] = event.ctrl_pressed
	out["meta"] = event.meta_pressed

## Rebuilds an event from event_to_dict's form. Returns null for anything
## unrecognised (corrupt file, a format from a future version) so the caller can
## fall back to the project default instead of binding garbage.
static func event_from_dict(data: Dictionary) -> InputEvent:
	match String(data.get("type", "")):
		"key":
			var key := InputEventKey.new()
			key.physical_keycode = int(data.get("physical_keycode", 0)) as Key
			key.keycode = int(data.get("keycode", 0)) as Key
			if key.physical_keycode == KEY_NONE and key.keycode == KEY_NONE:
				return null
			_read_modifiers(data, key)
			return key
		"mouse":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = int(data.get("button_index", 0)) as MouseButton
			if mouse.button_index == MOUSE_BUTTON_NONE:
				return null
			_read_modifiers(data, mouse)
			return mouse
	return null

static func _read_modifiers(data: Dictionary, event: InputEventWithModifiers) -> void:
	event.alt_pressed = bool(data.get("alt", false))
	event.shift_pressed = bool(data.get("shift", false))
	event.ctrl_pressed = bool(data.get("ctrl", false))
	event.meta_pressed = bool(data.get("meta", false))

## True for the event kinds the remap screen is willing to capture.
static func is_remappable(event: InputEvent) -> bool:
	return not event_to_dict(event).is_empty()

## The keys that are held *for* another key rather than pressed for their own sake.
const MODIFIER_KEYS: Array[Key] = [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]

## True for Shift, Ctrl, Alt or Meta on its own. The remap screen must not
## capture one on its press: Shift arrives before the 1 in Shift+1, so doing that
## made every chord unbindable - the overlays' own defaults included.
static func is_modifier_key(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key == null:
		return false
	return MODIFIER_KEYS.has(key.physical_keycode) or MODIFIER_KEYS.has(key.keycode)

## A modifier bound on its own (Ctrl shows module labels), as a binding. The event
## that delivers it carries its own flag - holding Ctrl reports `ctrl_pressed` -
## which would otherwise be stored and described as "Ctrl + Ctrl".
static func bare_modifier(event: InputEventKey) -> InputEventKey:
	var out := InputEventKey.new()
	out.physical_keycode = event.physical_keycode
	out.keycode = event.keycode
	return out

## Two bindings collide when they'd both fire on the same physical input.
## Compared through the dictionary form so only the fields we actually persist
## take part - device ids, positions and echo flags are irrelevant.
static func events_conflict(a: InputEvent, b: InputEvent) -> bool:
	var da: Dictionary = event_to_dict(a)
	var db: Dictionary = event_to_dict(b)
	if da.is_empty() or db.is_empty() or da["type"] != db["type"]:
		return false
	for field: String in ["alt", "shift", "ctrl", "meta"]:
		if da.get(field, false) != db.get(field, false):
			return false
	if String(da["type"]) == "mouse":
		return da["button_index"] == db["button_index"]
	# Keys match on physical first (that's what the defaults use); fall back to
	# the logical keycode for bindings captured from a layout-mapped event.
	if int(da["physical_keycode"]) != 0 and int(db["physical_keycode"]) != 0:
		return da["physical_keycode"] == db["physical_keycode"]
	return da["keycode"] == db["keycode"]

## Human-readable binding label for the remap list ("Shift + A", "Mouse 3").
static func describe_event(event: InputEvent) -> String:
	var data: Dictionary = event_to_dict(event)
	if data.is_empty():
		return "Unbound"
	var parts: Array[String] = []
	if bool(data.get("ctrl", false)):
		parts.append("Ctrl")
	if bool(data.get("alt", false)):
		parts.append("Alt")
	if bool(data.get("shift", false)):
		parts.append("Shift")
	if bool(data.get("meta", false)):
		parts.append("Meta")
	if String(data["type"]) == "mouse":
		parts.append(_mouse_button_name(int(data["button_index"])))
	else:
		parts.append(_key_name(int(data["physical_keycode"]), int(data["keycode"])))
	return " + ".join(parts)

static func _key_name(physical: int, logical: int) -> String:
	# Physical keycodes are reported in the US layout; show the label the player's
	# own layout puts there so the list matches their keycaps. The headless display
	# server has no layout to consult and only pushes an error if asked, so the
	# US label stands in there (the GUT suite runs headless).
	if physical != 0:
		var localized: Key = physical as Key
		if DisplayServer.get_name() != "headless":
			localized = DisplayServer.keyboard_get_keycode_from_physical(physical as Key)
		return OS.get_keycode_string(localized if localized != KEY_NONE else physical as Key)
	if logical != 0:
		return OS.get_keycode_string(logical as Key)
	return "Unbound"

static func _mouse_button_name(index: int) -> String:
	match index:
		MOUSE_BUTTON_LEFT:
			return "Left Click"
		MOUSE_BUTTON_RIGHT:
			return "Right Click"
		MOUSE_BUTTON_MIDDLE:
			return "Middle Click"
		MOUSE_BUTTON_WHEEL_UP:
			return "Wheel Up"
		MOUSE_BUTTON_WHEEL_DOWN:
			return "Wheel Down"
	return "Mouse %d" % index

## Convenience for a whole action's saved binding list.
static func describe_events(events: Array) -> String:
	var parts: Array[String] = []
	for event: InputEvent in events:
		if event != null:
			parts.append(describe_event(event))
	return ", ".join(parts) if not parts.is_empty() else "Unbound"

# --- keybind overrides --------------------------------------------------------

## Records `events` as the override for `action`. An empty list clears the
## override entirely (back to the project default) rather than storing a binding
## with zero events - no action may end up unbound.
func set_binding(action: StringName, events: Array[InputEvent]) -> void:
	var dicts: Array = []
	for event: InputEvent in events:
		var data: Dictionary = event_to_dict(event)
		if not data.is_empty():
			dicts.append(data)
	if dicts.is_empty():
		keybinds.erase(action)
	else:
		keybinds[action] = dicts

func clear_binding(action: StringName) -> void:
	keybinds.erase(action)

func clear_all_bindings() -> void:
	keybinds.clear()

## The override for `action`, or an empty array when it isn't remapped (or every
## stored entry failed to parse).
func get_binding(action: StringName) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	var stored: Array = keybinds.get(action, [])
	for entry: Variant in stored:
		if entry is Dictionary:
			var event: InputEvent = event_from_dict(entry as Dictionary)
			if event != null:
				out.append(event)
	return out

func has_binding(action: StringName) -> bool:
	return not get_binding(action).is_empty()

# --- persistence --------------------------------------------------------------

func to_config() -> ConfigFile:
	var config := ConfigFile.new()
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "effects", effects_volume)
	config.set_value("display", "window_mode", int(window_mode))
	config.set_value("display", "resolution", resolution)
	for action: StringName in keybinds:
		config.set_value("keybinds", String(action), keybinds[action])
	return config

static func from_config(config: ConfigFile) -> GameSettings:
	var settings := GameSettings.new()
	settings.music_volume = clampf(float(config.get_value("audio", "music", settings.music_volume)), 0.0, 1.0)
	settings.effects_volume = clampf(float(config.get_value("audio", "effects", settings.effects_volume)), 0.0, 1.0)
	var mode: int = int(config.get_value("display", "window_mode", int(WindowMode.WINDOWED)))
	settings.window_mode = (mode if mode == int(WindowMode.FULLSCREEN) else int(WindowMode.WINDOWED)) as WindowMode
	var res: Variant = config.get_value("display", "resolution", DEFAULT_RESOLUTION)
	if res is Vector2i and (res as Vector2i).x > 0 and (res as Vector2i).y > 0:
		settings.resolution = res as Vector2i
	if config.has_section("keybinds"):
		for action_key: String in config.get_section_keys("keybinds"):
			var stored: Variant = config.get_value("keybinds", action_key, [])
			if stored is Array:
				settings.keybinds[StringName(action_key)] = _sanitize_binding(stored as Array)
	# A section full of unparseable entries leaves empty arrays behind; drop them
	# so has_binding()/apply never sees an action with zero events.
	for action: StringName in settings.keybinds.keys():
		if (settings.keybinds[action] as Array).is_empty():
			settings.keybinds.erase(action)
	return settings

## Keeps only entries that round-trip back into a real keyboard/mouse event.
static func _sanitize_binding(stored: Array) -> Array:
	var out: Array = []
	for entry: Variant in stored:
		if entry is Dictionary and event_from_dict(entry as Dictionary) != null:
			out.append(entry)
	return out

func save_to_file(path: String = SETTINGS_PATH) -> Error:
	return to_config().save(path)

## Missing or corrupt file -> defaults, silently. The next save rewrites it.
static func load_from_file(path: String = SETTINGS_PATH) -> GameSettings:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return GameSettings.new()
	return from_config(config)
