class_name MainMenu
extends Control

## The game's entry point (WI-36) and the project's main scene. Nothing of the
## simulation exists here - no managers, no Global.* registrations - so the menu
## is cheap and there's no sim ticking behind it.
##
## New Game picks a difficulty (WI-37) and then enters main.tscn: WI-18 made that
## bootstrap deterministic (Main brings the world online once every manager has
## registered), so no timers or readiness polling are needed on either side of the
## swap. Loading stages the save first - including its difficulty - and lets
## main.tscn's fresh SaveManager apply it, exactly as it does after an in-game
## reload.

const MAIN_SCENE: String = "res://main.tscn"

var _panel: Control
var _settings_menu: SettingsMenu
var _load_menu: SaveLoadMenu
## The two faces of the root panel: the top-level buttons, and the difficulty
## cards New Game swaps to. Exactly one is visible at a time.
var _button_container: VBoxContainer
var _difficulty_container: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Entering the menu from a run must not leave a staged load behind, or the
	# next New Game would silently restore the game the player just left. The
	# staged difficulty (WI-37) goes with it, for the same reason.
	SaveManager.clear_pending_load()
	Global.clear_difficulty()
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
	_difficulty_container.add_theme_constant_override("separation", 8)
	vbox.add_child(_difficulty_container)
	_build_difficulty_cards()

	_button_container = VBoxContainer.new()
	_button_container.add_theme_constant_override("separation", 10)
	vbox.add_child(_button_container)

	_add_button(_button_container, "New Game", _show_difficulty_picker)
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

# --- difficulty picker (WI-37) ------------------------------------------------

## One card per DifficultyData .tres, easiest first. Built once at _ready: the set
## is fixed data, and building it up front means the picker has nothing to do but
## flip visibility.
func _build_difficulty_cards() -> void:
	var heading := Label.new()
	heading.text = "Choose a difficulty"
	heading.add_theme_font_size_override("font_size", 20)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_difficulty_container.add_child(heading)

	var note := Label.new()
	note.text = "This is fixed for the whole game and can't be changed later."
	note.add_theme_color_override("font_color", UIPalette.TEXT_SECONDARY)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_difficulty_container.add_child(note)

	var levels: Array[DifficultyData] = DifficultyData.all()
	if levels.is_empty():
		# No data/difficulty/ at all: keep New Game working (Global falls back to
		# neutral values) rather than stranding the player on an empty picker.
		var searched := PackedStringArray(ContentPaths.roots_for(ContentPaths.DIFFICULTY))
		push_warning("No DifficultyData found in " + ", ".join(searched)
				+ " - New Game will run at default settings")
		_difficulty_container.add_child(_start_button("Start", DifficultyData.DEFAULT_ID))
	for difficulty: DifficultyData in levels:
		_difficulty_container.add_child(_difficulty_card(difficulty))

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(0, 32)
	back.pressed.connect(_show_main_buttons)
	_difficulty_container.add_child(back)

func _difficulty_card(difficulty: DifficultyData) -> Control:
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	margin.add_child(box)

	var body := Label.new()
	body.text = difficulty.description
	body.add_theme_color_override("font_color", UIPalette.TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)

	# Derived from the .tres, never authored alongside it - so a balance tweak can
	# never leave the card describing the old numbers.
	var effects := Label.new()
	effects.text = difficulty.effect_summary()
	effects.add_theme_color_override("font_color", UIPalette.LIVE_BRIGHT)
	effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(effects)

	box.add_child(_start_button(difficulty.display_name, difficulty.id))
	return panel

func _start_button(label: String, difficulty_id: StringName) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, 36)
	button.pressed.connect(func() -> void: start_new_game(difficulty_id))
	return button

func _show_difficulty_picker() -> void:
	_button_container.visible = false
	_difficulty_container.visible = true

func _show_main_buttons() -> void:
	_difficulty_container.visible = false
	_button_container.visible = true

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

## Stage the difficulty before the scene swap (WI-37): Global is an autoload, so
## the value survives into main.tscn, where managers read it from _ready onward.
## Setting it unconditionally also overwrites whatever a previously-loaded save
## staged, so a Peaceful run followed by New Game can't inherit Peaceful.
func start_new_game(difficulty_id: StringName = DifficultyData.DEFAULT_ID) -> void:
	SaveManager.clear_pending_load()
	Global.set_difficulty(difficulty_id)
	get_tree().change_scene_to_file(MAIN_SCENE)

## Stage first, then enter the game scene: main.tscn's SaveManager sees the
## pending load in its _ready and applies the sections instead of spawning a
## fresh starting station (Main checks the same flag).
func _on_slot_chosen(slot: String) -> void:
	if not SaveManager.stage_load(slot):
		return
	get_tree().change_scene_to_file(MAIN_SCENE)
