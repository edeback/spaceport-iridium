extends Node

const CELL_SIZE: Vector2i = Vector2i(64, 64)

var time_manager: TimeManager
var save_manager: SaveManager
var world_manager: WorldManager
var path_manager: PathManager
var structure_manager: StructureManager
var adjacency_manager: AdjacencyManager
var power_manager: PowerManager
var job_manager: JobManager
var claim_registry: ClaimRegistry
var turbolift_manager: TurboliftManager
var resource_manager: ResourceManager
var market_manager: MarketManager
var economy_manager: EconomyManager
var asteroid_manager: AsteroidManager
var unlock_manager: UnlockManager
var crew_manager: CrewManager
var trader_manager: TraderManager
var event_manager: EventManager
var contract_manager: ContractManager
var raid_manager: RaidManager
var visitor_manager: VisitorManager
var atmosphere_manager: AtmosphereManager
var alert_manager: AlertManager
var ui_in_game: UIInGame
var ui_main: UIMain
var tilemap: TileMapLayer
## Debug/cheat helper (WI-19), installed by Main. Callable from the Panku REPL
## as Global.cheats.<method>(...). Null in builds where Main hasn't run yet.
var cheats: Cheats

## Player options (WI-36). The model is a pure GameSettings; this autoload is the
## only place that pushes it into the engine (AudioServer, the window, InputMap),
## so settings survive every scene swap between the menus and main.tscn.
var settings: GameSettings

## The difficulty this run is being played at (WI-37). Staged here before
## main.tscn loads - by the New Game picker, or by SaveManager.stage_load from the
## save - because managers read it from _ready onward and there is no manager to
## hang it on before the scene exists. Never changes mid-run.
##
## Null only until something stages a value; every read goes through the helpers
## below, which fall back to Normal (and then to neutral values) so a game booted
## straight into main.tscn from the editor still runs.
var difficulty: DifficultyData

## Action -> the project's own bindings, snapshotted before any override is
## applied. Reset-to-defaults and the "what would this be unbound to" checks read
## from here rather than re-parsing project.godot.
var _default_keybinds: Dictionary[StringName, Array] = {}

## The actions the remap screen offers, in display order. Curated on purpose:
## the InputMap also holds Godot's ui_* actions and the debug hotkeys, and
## neither belongs in a player-facing list.
const REMAPPABLE_ACTIONS: Array[StringName] = [
	&"build",
	&"remove",
	&"flip_module",
	&"show_details",
	&"camera_up",
	&"camera_down",
	&"camera_left",
	&"camera_right",
	&"camera_drag",
	&"camera_zoom_in",
	&"camera_zoom_out",
	# Console modes (WI-50). Every mode hotkey is a real action precisely so it
	# shows up here - a hotkey the player cannot rebind is one the console can
	# only teach, never adapt to.
	&"mode_build",
	&"mode_crew",
	&"mode_stores",
	&"mode_trade",
	&"mode_research",
	&"mode_comms",
	&"mode_overlays",
	&"toggle_map",
	&"overlay_power",
	&"overlay_o2",
	&"overlay_integrity",
	&"overlay_vibration",
	&"overlay_logistics",
	&"overlay_clear",
	&"toggle_ledger",
	&"quick_save",
	&"quick_load",
	&"toggle_pause_menu",
	&"toggle_console",
]

## Friendly labels for the remap list; an action missing here falls back to its
## id with underscores stripped.
const ACTION_LABELS: Dictionary[StringName, String] = {
	&"build": "Place module",
	&"remove": "Cancel / remove",
	&"flip_module": "Flip module",
	&"show_details": "Show module labels",
	&"camera_up": "Pan up",
	&"camera_down": "Pan down",
	&"camera_left": "Pan left",
	&"camera_right": "Pan right",
	&"camera_drag": "Drag camera",
	&"camera_zoom_in": "Zoom in",
	&"camera_zoom_out": "Zoom out",
	&"mode_build": "Build panel",
	&"mode_crew": "Crew panel",
	&"mode_stores": "Stores panel",
	&"mode_trade": "Trade panel",
	&"mode_research": "R&D panel",
	&"mode_comms": "Comms panel",
	&"mode_overlays": "Overlays panel",
	&"toggle_map": "Collapse station map",
	&"toggle_ledger": "Resource ledger",
	&"overlay_power": "Power overlay",
	&"overlay_o2": "Oxygen overlay",
	&"overlay_integrity": "Integrity overlay",
	&"overlay_vibration": "Vibration overlay",
	&"overlay_logistics": "Logistics overlay",
	&"overlay_clear": "Clear overlay",
	&"quick_save": "Quicksave",
	&"quick_load": "Quickload",
	&"toggle_pause_menu": "Pause menu",
	&"toggle_console": "Debug console",
}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_ensure_audio_buses()
	_capture_default_keybinds()
	settings = GameSettings.load_from_file()
	apply_settings()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# --- settings (WI-36) ---------------------------------------------------------

## Music/Effects buses are created here rather than shipped in a bus layout so
## the project keeps working if the layout resource is ever replaced; future
## audio work just routes players at these names.
func _ensure_audio_buses() -> void:
	for bus_name: String in [GameSettings.MUSIC_BUS, GameSettings.EFFECTS_BUS]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var index: int = AudioServer.bus_count
			AudioServer.add_bus(index)
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")

func _capture_default_keybinds() -> void:
	for action: StringName in REMAPPABLE_ACTIONS:
		if InputMap.has_action(action):
			_default_keybinds[action] = InputMap.action_get_events(action).duplicate()

func apply_settings() -> void:
	apply_audio()
	apply_display()
	apply_keybinds()

func apply_audio() -> void:
	_set_bus_volume(GameSettings.MUSIC_BUS, settings.music_volume)
	_set_bus_volume(GameSettings.EFFECTS_BUS, settings.effects_volume)

func _set_bus_volume(bus_name: String, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	AudioServer.set_bus_volume_db(index, GameSettings.volume_to_db(linear))
	# A slider dragged to zero is a mute, not a -60 dB whisper.
	AudioServer.set_bus_mute(index, linear <= 0.0)

func apply_display() -> void:
	# Headless (the GUT suite) has no real window server; sizing a dummy window
	# achieves nothing and the usable-rect query is meaningless there.
	if DisplayServer.get_name() == "headless":
		return
	var window: Window = get_window()
	if window == null:
		return
	if settings.window_mode == GameSettings.WindowMode.FULLSCREEN:
		window.mode = Window.MODE_FULLSCREEN
		return
	window.mode = Window.MODE_WINDOWED
	# Clamp before sizing: a resolution carried over from a bigger monitor would
	# otherwise open a window taller than the screen with no way to reach its bar.
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var size: Vector2i = GameSettings.clamp_resolution(settings.resolution, usable.size)
	window.size = size
	window.position = usable.position + (usable.size - size) / 2

## Re-applies every remappable action from scratch: project default, then the
## saved override on top. Idempotent, so the settings screen can call it after
## each change without accumulating bindings.
func apply_keybinds() -> void:
	for action: StringName in REMAPPABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for event: InputEvent in get_effective_events(action):
			InputMap.action_add_event(action, event)

## What `action` is bound to once the override (if any) is taken into account.
## Never empty for a known action - an override that parsed to nothing falls
## back to the default, so no action can be left unbound.
func get_effective_events(action: StringName) -> Array[InputEvent]:
	var overridden: Array[InputEvent] = settings.get_binding(action)
	if not overridden.is_empty():
		return overridden
	return get_default_events(action)

func get_default_events(action: StringName) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	var stored: Array = _default_keybinds.get(action, [])
	for event: InputEvent in stored:
		out.append(event)
	return out

## Remappable actions (other than `exclude_action`) that `event` would collide
## with. The remap screen uses this to offer a swap instead of silently creating
## two actions on one key.
func find_binding_conflicts(event: InputEvent, exclude_action: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for action: StringName in REMAPPABLE_ACTIONS:
		if action == exclude_action or not InputMap.has_action(action):
			continue
		for bound: InputEvent in get_effective_events(action):
			if GameSettings.events_conflict(event, bound):
				out.append(action)
				break
	return out

## Binds `action` to a single event, applies it, and persists. Returns false if
## the event isn't something v1 accepts (gamepad, joystick axis).
func rebind_action(action: StringName, event: InputEvent) -> bool:
	if not GameSettings.is_remappable(event):
		return false
	settings.set_binding(action, [event] as Array[InputEvent])
	apply_keybinds()
	save_settings()
	return true

func reset_action_binding(action: StringName) -> void:
	settings.clear_binding(action)
	apply_keybinds()
	save_settings()

func reset_all_keybinds() -> void:
	settings.clear_all_bindings()
	apply_keybinds()
	save_settings()

func action_label(action: StringName) -> String:
	return ACTION_LABELS.get(action, String(action).capitalize())

func save_settings() -> void:
	var error: Error = settings.save_to_file()
	if error != OK:
		push_warning("Could not write settings to %s (error %d)" % [GameSettings.SETTINGS_PATH, error])

# --- difficulty (WI-37) -------------------------------------------------------

## Stages `difficulty_id` for the run that is about to start. Called by the New
## Game picker and by SaveManager.stage_load; an unknown id resolves to Normal.
## Always call this before entering main.tscn, never during a run - difficulty is
## fixed for the life of a game.
func set_difficulty(difficulty_id: StringName) -> void:
	difficulty = DifficultyData.resolve(difficulty_id)

## Drops the staged level when a run ends. The main menu calls this alongside
## SaveManager.clear_pending_load() for the same reason: nothing about the run the
## player just left should linger into the next one, and the settings readout
## would otherwise still be reporting a game that is over.
func clear_difficulty() -> void:
	difficulty = null

## The current level, resolving a never-staged run (booting main.tscn directly
## from the editor) to Normal on first read rather than leaving it null.
func get_difficulty() -> DifficultyData:
	if difficulty == null:
		difficulty = DifficultyData.resolve(DifficultyData.DEFAULT_ID)
	return difficulty

func difficulty_id() -> StringName:
	var current: DifficultyData = get_difficulty()
	return current.id if current != null else DifficultyData.DEFAULT_ID

## The three consumption points read through these rather than poking at the
## resource, so a missing data/difficulty/ directory degrades to a Normal game
## instead of a crash.
func difficulty_upkeep_multiplier() -> float:
	var current: DifficultyData = get_difficulty()
	return current.upkeep_multiplier if current != null else 1.0

func difficulty_raids_enabled() -> bool:
	var current: DifficultyData = get_difficulty()
	return current.raids_enabled if current != null else true

func difficulty_mood_offset() -> float:
	var current: DifficultyData = get_difficulty()
	return current.mood_offset if current != null else 0.0

func world_to_cell(position: Vector2) -> Vector2i:
	return Vector2i(floor((position.x) / CELL_SIZE.x), floor((position.y) / CELL_SIZE.y))
	
func cell_to_world(cell: Vector2i, use_half_offset: bool = false) -> Vector2:
	return cell * CELL_SIZE + (Vector2i.ONE * CELL_SIZE / 2 if use_half_offset else Vector2i.ZERO)

func world_to_tilemap_cell(position: Vector2) -> Vector2i:
	if tilemap != null:
		return tilemap.local_to_map(position)
	return Vector2i()

func node_path_to_point_path(path: Array[Node2D], use_global_position: bool = false) -> PackedVector2Array:
	var point_path: PackedVector2Array = []
	for node: Node2D in path:
		if node is ModuleBase:
			var module := node as ModuleBase
			if use_global_position:
				point_path.append(cell_to_world(module.module_cell))
			else:
				point_path.append(module.module_cell)
		else:
			if use_global_position:
				point_path.append(node.global_position)
			else:
				point_path.append(world_to_cell(node.global_position))
	return point_path
