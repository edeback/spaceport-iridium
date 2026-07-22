class_name SettingsMenu
extends Control

## The options screen (WI-36), shared by the main menu and the pause menu. Four
## tabs: Game, Audio, Display, Controls. Every change writes through Global (which
## owns the live GameSettings and is the only thing that touches AudioServer / the
## window / the InputMap), so a change made from the pause menu is already in
## effect when the player returns to the main menu, and vice versa.
##
## Audio applies live as the slider moves; display waits for Apply, because a
## half-dragged resolution has no meaning. The Game tab is read-only: difficulty
## (WI-37) is fixed at New Game, so this screen reports it rather than offers it.

signal closed

var _tabs: TabContainer
var _keybind_rows: Array[KeybindRow] = []
var _resolution_option: OptionButton
var _window_option: OptionButton
var _difficulty_value: Label
var _difficulty_detail: Label

## Capture state: the row waiting for a key, plus the overlay that eats input
## while it waits.
var _capturing_row: KeybindRow = null
var _capture_overlay: Control
var _capture_label: Label

## Conflict prompt state: the pending (action, event) plus the action it would
## collide with, held until the player picks swap or cancel.
var _conflict_dialog: ConfirmationDialog
var _pending_action: StringName = &""
var _pending_event: InputEvent = null
var _pending_conflict: StringName = &""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_shell()

func open() -> void:
	visible = true
	_refresh_all()

func close() -> void:
	_cancel_capture()
	visible = false
	Global.save_settings()
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	# While capturing, _input has already eaten the event; this only fires for a
	# normal Esc on the screen itself.
	if visible and _capturing_row == null and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

# --- shell --------------------------------------------------------------------

func _build_shell() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 520)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title_bar := HBoxContainer.new()
	vbox.add_child(title_bar)
	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(32, 0)
	close_btn.pressed.connect(close)
	title_bar.add_child(close_btn)

	_tabs = TabContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_tabs)
	_tabs.add_child(_build_game_tab())
	_tabs.add_child(_build_audio_tab())
	_tabs.add_child(_build_display_tab())
	_tabs.add_child(_build_controls_tab())

	_build_capture_overlay()

	_conflict_dialog = ConfirmationDialog.new()
	_conflict_dialog.ok_button_text = "Swap"
	_conflict_dialog.confirmed.connect(_on_conflict_swap)
	_conflict_dialog.canceled.connect(_on_conflict_cancel)
	add_child(_conflict_dialog)

# --- game ---------------------------------------------------------------------

## Read-only by design (WI-37): difficulty is chosen at New Game and holds for the
## life of the run, so offering a control here would be a lie. Opened from the
## pause menu this is the running game's level; opened from the main menu the
## staged level has been cleared, so it reads as the Normal default.
func _build_game_tab() -> Control:
	var box := VBoxContainer.new()
	box.name = "Game"
	box.add_theme_constant_override("separation", 8)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = "Difficulty"
	label.custom_minimum_size = Vector2(90, 0)
	row.add_child(label)
	_difficulty_value = Label.new()
	_difficulty_value.add_theme_font_size_override("font_size", 18)
	row.add_child(_difficulty_value)
	box.add_child(row)

	_difficulty_detail = Label.new()
	_difficulty_detail.self_modulate = Color(1, 1, 1, 0.7)
	_difficulty_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_difficulty_detail)

	var hint := Label.new()
	hint.text = "Difficulty is chosen when you start a new game and cannot be changed afterwards."
	hint.self_modulate = Color(1, 1, 1, 0.55)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	return box

func _refresh_game_tab() -> void:
	if _difficulty_value == null:
		return
	var difficulty: DifficultyData = Global.get_difficulty()
	if difficulty == null:
		_difficulty_value.text = "Normal"
		_difficulty_detail.text = ""
		return
	_difficulty_value.text = difficulty.display_name
	_difficulty_detail.text = difficulty.effect_summary()

# --- audio --------------------------------------------------------------------

func _build_audio_tab() -> Control:
	var box := VBoxContainer.new()
	box.name = "Audio"
	box.add_theme_constant_override("separation", 12)
	box.add_child(_volume_row("Music", func() -> float: return Global.settings.music_volume,
		func(value: float) -> void: Global.settings.music_volume = value))
	box.add_child(_volume_row("Effects", func() -> float: return Global.settings.effects_volume,
		func(value: float) -> void: Global.settings.effects_volume = value))
	var hint := Label.new()
	hint.text = "Volumes apply immediately and are saved when you close this screen."
	hint.self_modulate = Color(1, 1, 1, 0.55)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	return box

func _volume_row(label_text: String, getter: Callable, setter: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(90, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = float(getter.call())
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(280, 0)
	row.add_child(slider)
	var readout := Label.new()
	readout.custom_minimum_size = Vector2(48, 0)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.text = "%d%%" % roundi(slider.value * 100.0)
	row.add_child(readout)
	slider.value_changed.connect(func(value: float) -> void:
		setter.call(value)
		readout.text = "%d%%" % roundi(value * 100.0)
		Global.apply_audio())
	return row

# --- display ------------------------------------------------------------------

func _build_display_tab() -> Control:
	var box := VBoxContainer.new()
	box.name = "Display"
	box.add_theme_constant_override("separation", 12)

	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	var mode_label := Label.new()
	mode_label.text = "Window"
	mode_label.custom_minimum_size = Vector2(90, 0)
	mode_row.add_child(mode_label)
	_window_option = OptionButton.new()
	_window_option.add_item("Windowed", int(GameSettings.WindowMode.WINDOWED))
	_window_option.add_item("Fullscreen", int(GameSettings.WindowMode.FULLSCREEN))
	_window_option.item_selected.connect(func(_index: int) -> void: _refresh_display_controls())
	mode_row.add_child(_window_option)
	box.add_child(mode_row)

	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 8)
	var res_label := Label.new()
	res_label.text = "Resolution"
	res_label.custom_minimum_size = Vector2(90, 0)
	res_row.add_child(res_label)
	_resolution_option = OptionButton.new()
	res_row.add_child(_resolution_option)
	box.add_child(res_row)

	var apply := Button.new()
	apply.text = "Apply"
	apply.pressed.connect(_on_display_apply)
	box.add_child(apply)

	var hint := Label.new()
	hint.text = "Resolution only applies in windowed mode, and is clamped to your screen."
	hint.self_modulate = Color(1, 1, 1, 0.55)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	return box

func _refresh_display_controls() -> void:
	if _window_option == null or _resolution_option == null:
		return
	var screen: Vector2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()).size
	var options: Array[Vector2i] = GameSettings.available_resolutions(screen)
	_resolution_option.clear()
	var selected: int = 0
	for index: int in options.size():
		var option: Vector2i = options[index]
		_resolution_option.add_item("%d × %d" % [option.x, option.y], index)
		_resolution_option.set_item_metadata(index, option)
		if option == Global.settings.resolution:
			selected = index
	_resolution_option.selected = selected
	_resolution_option.disabled = _window_option.get_selected_id() == int(GameSettings.WindowMode.FULLSCREEN)

func _on_display_apply() -> void:
	Global.settings.window_mode = _window_option.get_selected_id() as GameSettings.WindowMode
	var chosen: Variant = _resolution_option.get_selected_metadata()
	if chosen is Vector2i:
		Global.settings.resolution = chosen as Vector2i
	Global.apply_display()
	Global.save_settings()
	_refresh_display_controls()

# --- controls -----------------------------------------------------------------

func _build_controls_tab() -> Control:
	var box := VBoxContainer.new()
	box.name = "Controls"
	box.add_theme_constant_override("separation", 8)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	for action: StringName in Global.REMAPPABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var row := KeybindRow.new()
		rows.add_child(row)
		row.setup(action)
		row.rebind_requested.connect(_begin_capture)
		_keybind_rows.append(row)

	var reset := Button.new()
	reset.text = "Reset all to defaults"
	reset.pressed.connect(func() -> void:
		Global.reset_all_keybinds()
		_refresh_keybind_rows())
	box.add_child(reset)
	return box

func _refresh_keybind_rows() -> void:
	for row: KeybindRow in _keybind_rows:
		row.refresh()

# --- capture ------------------------------------------------------------------

## A full-rect modal with its own Cancel button. The button matters: rebinding
## the pause key means the capture must swallow Esc, so Esc cannot also be the
## way out of the capture.
func _build_capture_overlay() -> void:
	_capture_overlay = Control.new()
	_capture_overlay.visible = false
	_capture_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_capture_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_capture_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_capture_overlay.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	_capture_label = Label.new()
	_capture_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_capture_label)
	var hint := Label.new()
	hint.text = "Keyboard and mouse only."
	hint.self_modulate = Color(1, 1, 1, 0.55)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(_cancel_capture)
	vbox.add_child(cancel)

func _begin_capture(action: StringName) -> void:
	_cancel_capture()
	for row: KeybindRow in _keybind_rows:
		if row.action == action:
			_capturing_row = row
			break
	if _capturing_row == null:
		return
	_capturing_row.set_capturing(true)
	_capture_label.text = "Press a new key for “%s”" % Global.action_label(action)
	_capture_overlay.visible = true
	set_process_input(true)

func _cancel_capture() -> void:
	if _capturing_row != null:
		_capturing_row.set_capturing(false)
		_capturing_row = null
	if _capture_overlay != null:
		_capture_overlay.visible = false
	set_process_input(false)

## Capture runs in _input (not _unhandled_input) so it wins against every panel,
## hotkey and focused control underneath while the overlay is up.
func _input(event: InputEvent) -> void:
	if _capturing_row == null:
		return
	# Releases and echoes would end the capture on the same press that started it.
	if not event.is_pressed() or event.is_echo():
		return
	# A mouse press on the Cancel button must still reach the button.
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		return
	if not GameSettings.is_remappable(event):
		return
	get_viewport().set_input_as_handled()
	var action: StringName = _capturing_row.action
	_cancel_capture()
	_try_bind(action, event)

func _try_bind(action: StringName, event: InputEvent) -> void:
	var conflicts: Array[StringName] = Global.find_binding_conflicts(event, action)
	if conflicts.is_empty():
		Global.rebind_action(action, event)
		_refresh_keybind_rows()
		return
	_pending_action = action
	_pending_event = event
	_pending_conflict = conflicts[0]
	_conflict_dialog.title = "Already bound"
	_conflict_dialog.dialog_text = "%s is already bound to “%s”.\nSwap the two bindings?" % [
		GameSettings.describe_event(event), Global.action_label(_pending_conflict)]
	_conflict_dialog.popup_centered()

## Swap, never steal: the conflicting action inherits whatever the rebound action
## was using, so no action is ever left with zero bindings.
func _on_conflict_swap() -> void:
	if _pending_event == null:
		return
	var displaced: Array[InputEvent] = Global.get_effective_events(_pending_action)
	Global.settings.set_binding(_pending_conflict, displaced)
	Global.rebind_action(_pending_action, _pending_event)
	_clear_pending_conflict()
	_refresh_keybind_rows()

func _on_conflict_cancel() -> void:
	_clear_pending_conflict()

func _clear_pending_conflict() -> void:
	_pending_action = &""
	_pending_event = null
	_pending_conflict = &""

# --- refresh ------------------------------------------------------------------

func _refresh_all() -> void:
	_refresh_game_tab()
	_window_option.select(_window_option.get_item_index(int(Global.settings.window_mode)))
	_refresh_display_controls()
	_refresh_keybind_rows()
