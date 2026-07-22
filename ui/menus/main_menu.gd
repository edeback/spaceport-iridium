class_name MainMenu
extends Control

## The game's entry point (WI-36) and the project's main scene. Nothing of the
## simulation exists here - no managers, no Global.* registrations - so the menu
## is cheap and there's no sim ticking behind it.
##
## New Game just enters main.tscn: WI-18 made that bootstrap deterministic (Main
## brings the world online once every manager has registered), so no timers or
## readiness polling are needed on either side of the swap. Loading stages the
## save first and lets main.tscn's fresh SaveManager apply it, exactly as it does
## after an in-game reload.

const MAIN_SCENE: String = "res://main.tscn"

var _panel: Control
var _settings_menu: SettingsMenu
var _load_menu: SaveLoadMenu
## WI-37 hook: the difficulty selector drops in here on the New Game path.
## Hidden (and empty) until that work item lands.
var _difficulty_container: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Entering the menu from a run must not leave a staged load behind, or the
	# next New Game would silently restore the game the player just left.
	SaveManager.clear_pending_load()
	_build_shell()
	_build_submenus()

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

	_difficulty_container = VBoxContainer.new()
	_difficulty_container.visible = false
	vbox.add_child(_difficulty_container)

	_add_button(vbox, "New Game", start_new_game)
	var load_button: Button = _add_button(vbox, "Load Saved Game", func() -> void:
		_panel.visible = false
		_load_menu.open(SaveLoadMenu.Mode.LOAD))
	# Nothing to load on a first run - say so rather than opening an empty list.
	load_button.disabled = SaveManager.list_slots().is_empty()
	if load_button.disabled:
		load_button.tooltip_text = "No saved games yet."
	_add_button(vbox, "Settings", func() -> void:
		_panel.visible = false
		_settings_menu.open())
	_add_button(vbox, "Quit", func() -> void: get_tree().quit())

	var version := Label.new()
	version.text = ProjectSettings.get_setting("application/config/version", "dev build")
	version.self_modulate = Color(1, 1, 1, 0.4)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(version)

func _add_button(parent: Node, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 40)
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button

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

# --- actions ------------------------------------------------------------------

func start_new_game() -> void:
	SaveManager.clear_pending_load()
	get_tree().change_scene_to_file(MAIN_SCENE)

## Stage first, then enter the game scene: main.tscn's SaveManager sees the
## pending load in its _ready and applies the sections instead of spawning a
## fresh starting station (Main checks the same flag).
func _on_slot_chosen(slot: String) -> void:
	if not SaveManager.stage_load(slot):
		return
	get_tree().change_scene_to_file(MAIN_SCENE)
