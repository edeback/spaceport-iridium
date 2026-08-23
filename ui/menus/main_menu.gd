class_name MainMenu
extends Control

## The game's entry point (WI-36) and the project's main scene. Nothing of the
## simulation exists here - no managers, no Global.* registrations - so the menu
## is cheap and there's no sim ticking behind it.
##
## New Game opens the setup screen (WI-59: station name, founding crew, and the
## difficulty picker WI-37 put here) and then enters main.tscn: WI-18 made that
## bootstrap deterministic (Main brings the world online once every manager has
## registered), so no timers or readiness polling are needed on either side of the
## swap. Loading stages the save first - including its difficulty and station
## name - and lets main.tscn's fresh SaveManager apply it, exactly as it does
## after an in-game reload.

const MAIN_SCENE: String = "res://main.tscn"

## Set by the in-game pause menu before it swaps back here, so "New Game" from a
## live run lands on the setup screen instead of the menu's root list. Static for
## the same reason SaveManager's pending load is: it has to survive the scene
## swap, and statics live on the script rather than the node.
static var _open_setup_on_ready: bool = false

## Asks the next MainMenu to open straight into the New Game setup screen.
static func request_new_game_setup() -> void:
	_open_setup_on_ready = true

var _panel: Control
var _settings_menu: SettingsMenu
var _load_menu: SaveLoadMenu
var _setup_menu: NewGameSetup
var _button_container: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Entering the menu from a run must not leave a staged load behind, or the
	# next New Game would silently restore the game the player just left. The
	# staged difficulty (WI-37) and the staged station name + founding crew
	# (WI-59) go with it, for the same reason.
	SaveManager.clear_pending_load()
	Global.clear_difficulty()
	Global.clear_staged_start()
	_build_shell()
	_build_submenus()
	# New Game from a live run arrives here (the setup screen only exists in this
	# scene). Consumed on read, so backing out of the setup lands on the root list
	# and a later return to the menu doesn't re-open it.
	if _open_setup_on_ready:
		_open_setup_on_ready = false
		_open_setup()

# --- shell --------------------------------------------------------------------

func _build_shell() -> void:
	var background := ColorRect.new()
	background.color = Color(0.04, 0.05, 0.08)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	_panel = CenterContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.custom_minimum_size = Vector2(300, 0)
	_panel.add_child(vbox)

	var title := Label.new()
	title.text = "SPACEPORT IRIDIUM"
	title.add_theme_font_size_override("font_size", 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(spacer)

	_button_container = VBoxContainer.new()
	_button_container.add_theme_constant_override("separation", 10)
	vbox.add_child(_button_container)

	_add_button(_button_container, "New Game", _open_setup)
	var load_button: Button = _add_button(_button_container, "Load Saved Game", func() -> void:
		_panel.visible = false
		_load_menu.open(SaveLoadMenu.Mode.LOAD))
	# Nothing to load on a first run - say so rather than opening an empty list.
	load_button.disabled = SaveManager.list_slots().is_empty()
	if load_button.disabled:
		load_button.tooltip_text = "No saved games yet."
	_add_button(_button_container, "Settings", func() -> void:
		_panel.visible = false
		_settings_menu.open())
	_add_button(_button_container, "Quit", func() -> void: get_tree().quit())

	var version := Label.new()
	version.text = ProjectSettings.get_setting("application/config/version", "dev build")
	version.add_theme_color_override("font_color", UIPalette.TEXT_META)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(version)

func _add_button(parent: Node, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 40)
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button

func _open_setup() -> void:
	_panel.visible = false
	_setup_menu.open()

func _build_submenus() -> void:
	_settings_menu = SettingsMenu.new()
	_settings_menu.visible = false
	add_child(_settings_menu)
	_settings_menu.closed.connect(func() -> void: _panel.visible = true)

	_load_menu = SaveLoadMenu.new()
	_load_menu.visible = false
	add_child(_load_menu)
	_load_menu.closed.connect(func() -> void: _panel.visible = true)
	_load_menu.slot_chosen.connect(_on_slot_chosen)

	_setup_menu = NewGameSetup.new()
	_setup_menu.visible = false
	add_child(_setup_menu)
	_setup_menu.closed.connect(func() -> void: _panel.visible = true)
	_setup_menu.start_requested.connect(start_new_game)

# --- actions ------------------------------------------------------------------

## Stage everything the run needs before the scene swap (WI-37, WI-59): Global is
## an autoload, so these survive into main.tscn, where managers read them from
## _ready onward. Setting them unconditionally also overwrites whatever a
## previously-loaded save staged, so a Peaceful run followed by New Game can't
## inherit Peaceful - and the same for the old station's name.
##
## All four are staged here rather than by the setup screen, which only reports
## the choices: staging is the menu's job, and keeping it in one function is what
## makes "did this run inherit anything?" answerable by reading one place.
func start_new_game(difficulty_id: StringName = DifficultyData.DEFAULT_ID,
		station_name: String = "", crew: Array[HireCandidate] = [],
		skip_onboarding: bool = false) -> void:
	SaveManager.clear_pending_load()
	Global.set_difficulty(difficulty_id)
	Global.set_station_name(station_name)
	Global.stage_crew(crew)
	Global.set_skip_onboarding(skip_onboarding)
	get_tree().change_scene_to_file(MAIN_SCENE)

## Stage first, then enter the game scene: main.tscn's SaveManager sees the
## pending load in its _ready and applies the sections instead of spawning a
## fresh starting station (Main checks the same flag).
func _on_slot_chosen(slot: String) -> void:
	if not SaveManager.stage_load(slot):
		return
	get_tree().change_scene_to_file(MAIN_SCENE)
