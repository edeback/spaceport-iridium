class_name PauseMenu
extends Control

## The in-game Esc menu (WI-36). Mounted by UIMain, so it lives on the HUD
## CanvasLayer and keeps working while the sim is paused (UI is real-time by
## design - see TimeManager).
##
## Pause semantics: opening pauses the sim, closing restores the pause state the
## player had *before* opening. A game the player had manually paused stays
## paused when they close the menu; a running game resumes at its old speed.

signal opened
signal closed

const MAIN_MENU_SCENE: String = "res://ui/menus/main_menu.tscn"
const MAIN_SCENE: String = "res://main.tscn"

var _was_paused: bool = false
var _settings_menu: SettingsMenu
var _save_load_menu: SaveLoadMenu
var _confirm: ConfirmationDialog
var _confirm_action: Callable = Callable()
var _panel: Control

func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_shell()
	_build_submenus()

# --- open / close -------------------------------------------------------------

func open() -> void:
	if visible:
		return
	_was_paused = Global.time_manager.paused
	Global.time_manager.paused = true
	visible = true
	_panel.visible = true
	opened.emit()

func close() -> void:
	if not visible:
		return
	if _settings_menu != null and _settings_menu.visible:
		_settings_menu.close()
	if _save_load_menu != null and _save_load_menu.visible:
		_save_load_menu.close()
	visible = false
	# Restore, don't unpause: the player may have paused the game themselves
	# before pressing Esc.
	Global.time_manager.paused = _was_paused
	closed.emit()

func toggle() -> void:
	if visible:
		close()
	else:
		open()

## Esc arbitration (WI-36): the menu only claims Esc when nothing else in the UI
## wants it - an open build preview, info panel, trade screen or overlay mode all
## outrank it. Those panels close themselves on the same press; asking UIMain
## first means the answer doesn't depend on input-propagation order between
## sibling controls.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("toggle_pause_menu"):
		return
	if visible:
		# A submenu owns Esc while it's up (it closes back to this panel); only
		# the root list closes the whole menu. Both actions ride the same key, so
		# this guard - not propagation order - is what keeps them from racing.
		if _settings_menu.visible or _save_load_menu.visible:
			return
		get_viewport().set_input_as_handled()
		close()
		return
	if Global.ui_main != null and Global.ui_main.esc_claimed():
		return
	get_viewport().set_input_as_handled()
	open()

# --- shell --------------------------------------------------------------------

func _build_shell() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_panel = CenterContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	_panel.add_child(panel)

	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_add_button(vbox, "Resume", close)
	_add_button(vbox, "Save Game", func() -> void: _open_slots(SaveLoadMenu.Mode.SAVE))
	_add_button(vbox, "Load Game", func() -> void: _open_slots(SaveLoadMenu.Mode.LOAD))
	_add_button(vbox, "Settings", _open_settings)
	_add_button(vbox, "New Game", func() -> void:
		_ask("Start a new game?", "Unsaved progress on this station will be lost.", _start_new_game))
	_add_button(vbox, "Quit to Menu", func() -> void:
		_ask("Quit to the main menu?", "Unsaved progress on this station will be lost.", quit_to_menu))
	_add_button(vbox, "Quit to Desktop", func() -> void:
		_ask("Quit to desktop?", "Unsaved progress on this station will be lost.", func() -> void: get_tree().quit()))

	_confirm = ConfirmationDialog.new()
	_confirm.confirmed.connect(_on_confirmed)
	add_child(_confirm)

func _add_button(parent: Node, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 34)
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button

func _build_submenus() -> void:
	_settings_menu = SettingsMenu.new()
	_settings_menu.visible = false
	add_child(_settings_menu)
	_settings_menu.closed.connect(func() -> void: _panel.visible = true)

	_save_load_menu = SaveLoadMenu.new()
	_save_load_menu.visible = false
	add_child(_save_load_menu)
	_save_load_menu.closed.connect(func() -> void: _panel.visible = true)
	_save_load_menu.slot_chosen.connect(_on_slot_chosen)

func _open_settings() -> void:
	_panel.visible = false
	_settings_menu.open()

func _open_slots(mode: SaveLoadMenu.Mode) -> void:
	_panel.visible = false
	_save_load_menu.open(mode)

# --- actions ------------------------------------------------------------------

func _on_slot_chosen(slot: String) -> void:
	if _save_load_menu.mode == SaveLoadMenu.Mode.SAVE:
		_save_with_players_pause_state(slot)
		_save_load_menu.close()
		return
	# Loading a different slot drops the current run, so confirm before the
	# scene reload takes it away.
	_ask("Load '%s'?" % slot, "Unsaved progress on this station will be lost.", func() -> void:
		# Unpause first: the reloaded scene keeps whatever pause state the save
		# carries, and leaving the menu's forced pause set would stick.
		Global.time_manager.paused = false
		Global.save_manager.load_slot(slot))

## TimeManager serializes `paused`, and this menu forces a pause while it's open -
## so a save written from here would reload every game frozen. Record the pause
## state the player actually had, then put the menu's pause straight back.
func _save_with_players_pause_state(slot: String) -> void:
	var menu_pause: bool = Global.time_manager.paused
	Global.time_manager.paused = _was_paused
	Global.save_manager.save_slot(slot)
	Global.time_manager.paused = menu_pause

## New Game from a live run: clear any staged load (otherwise the fresh scene
## would restore the very game we're leaving) and re-enter main.tscn.
func _start_new_game() -> void:
	SaveManager.clear_pending_load()
	Global.time_manager.paused = false
	get_tree().change_scene_to_file(MAIN_SCENE)

func quit_to_menu() -> void:
	SaveManager.clear_pending_load()
	Global.time_manager.paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

# --- confirmation -------------------------------------------------------------

func _ask(title: String, body: String, on_confirm: Callable) -> void:
	_confirm_action = on_confirm
	_confirm.title = title
	_confirm.dialog_text = body
	_confirm.popup_centered()

func _on_confirmed() -> void:
	if _confirm_action.is_valid():
		_confirm_action.call()
	_confirm_action = Callable()
