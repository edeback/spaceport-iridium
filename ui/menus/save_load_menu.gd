class_name SaveLoadMenu
extends Control

## The slot browser (WI-36), shared by the main menu (load only) and the pause
## menu (load + save). Built in code like the rest of the management screens.
##
## It only ever *reports* the chosen slot through slot_chosen - staging a load,
## reloading the scene, or writing the save is the owning menu's job, because the
## two callers do very different things with the answer (the main menu stages and
## changes scene; the pause menu reloads in place).

enum Mode { LOAD, SAVE }

signal slot_chosen(slot: String)
signal closed

var mode: Mode = Mode.LOAD

var _list: VBoxContainer
var _title: Label
var _new_slot_row: HBoxContainer
var _new_slot_edit: LineEdit
var _empty_hint: Label
var _confirm: ConfirmationDialog
## What the open confirmation dialog will do if accepted. Rebound per prompt so
## one dialog serves overwrite and delete alike.
var _confirm_action: Callable = Callable()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_shell()
	refresh()

func open(new_mode: Mode) -> void:
	mode = new_mode
	visible = true
	refresh()
	if mode == Mode.SAVE and _new_slot_edit != null:
		# Pre-fill with the station's name (WI-59) so the common case is one
		# keypress. Selected rather than just filled: grab_focus below puts the
		# caret in a field the player may want to replace wholesale, and typing
		# should overwrite the suggestion rather than append to it.
		_new_slot_edit.text = SaveManager.sanitize_slot_name(Global.station_display_name())
		_new_slot_edit.grab_focus()
		_new_slot_edit.select_all()

func close() -> void:
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
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
	panel.custom_minimum_size = Vector2(520, 460)
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
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(_title)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(32, 0)
	close_btn.pressed.connect(close)
	title_bar.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	_empty_hint = Label.new()
	_empty_hint.text = "No saved games yet."
	_empty_hint.add_theme_color_override("font_color", UIPalette.TEXT_SECONDARY)
	vbox.add_child(_empty_hint)

	_new_slot_row = HBoxContainer.new()
	_new_slot_row.add_theme_constant_override("separation", 6)
	var new_label := Label.new()
	new_label.text = "New save:"
	_new_slot_row.add_child(new_label)
	_new_slot_edit = LineEdit.new()
	_new_slot_edit.placeholder_text = "slot name"
	_new_slot_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_new_slot_edit.text_submitted.connect(func(_text: String) -> void: _on_new_slot_pressed())
	_new_slot_row.add_child(_new_slot_edit)
	var new_btn := Button.new()
	new_btn.text = "Save"
	new_btn.pressed.connect(_on_new_slot_pressed)
	_new_slot_row.add_child(new_btn)
	vbox.add_child(_new_slot_row)

	_confirm = ConfirmationDialog.new()
	_confirm.confirmed.connect(_on_confirmed)
	add_child(_confirm)

# --- rows ---------------------------------------------------------------------

func refresh() -> void:
	if _list == null:
		return
	for child: Node in _list.get_children():
		# Unparent before freeing: refresh() can run twice in one frame (build then
		# open), and queue_free alone would leave the stale rows on screen until
		# the end of that frame - a visibly doubled list.
		_list.remove_child(child)
		child.queue_free()
	_title.text = "Save Game" if mode == Mode.SAVE else "Load Game"
	_new_slot_row.visible = mode == Mode.SAVE
	var slots: Array[Dictionary] = SaveManager.list_slots()
	_empty_hint.visible = slots.is_empty()
	for info: Dictionary in slots:
		_list.add_child(_build_row(info))

func _build_row(info: Dictionary) -> Control:
	var slot: String = String(info.get("slot", ""))
	var row_panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row_panel.add_child(row)

	var text_box := VBoxContainer.new()
	text_box.add_theme_constant_override("separation", 0)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := Label.new()
	name_label.text = slot + ("  (quicksave)" if slot == SaveManager.QUICK_SLOT else "")
	name_label.add_theme_font_size_override("font_size", 18)
	text_box.add_child(name_label)
	var detail := Label.new()
	detail.text = SaveManager.describe_slot(info)
	detail.add_theme_color_override("font_color", UIPalette.TEXT_SECONDARY)
	text_box.add_child(detail)
	var stamp := Label.new()
	stamp.text = String(info.get("timestamp", "")).replace("T", "  ")
	stamp.add_theme_color_override("font_color", UIPalette.TEXT_META)
	text_box.add_child(stamp)
	# Mods this save used that aren't loaded now (WI-47 M11). Shown on the row
	# rather than at load time so the player finds out BEFORE committing - the
	# whole reason the mod list lives in the cheap meta block.
	var drift: PackedStringArray = SaveManager.mod_drift(info.get("mods", []))
	if not drift.is_empty():
		var warning := Label.new()
		warning.text = "⚠ " + ", ".join(drift)
		warning.add_theme_color_override("font_color", UIPalette.ATTENTION)
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_box.add_child(warning)
	row.add_child(text_box)

	var action_btn := Button.new()
	if mode == Mode.SAVE:
		action_btn.text = "Overwrite"
		action_btn.pressed.connect(func() -> void:
			_ask("Overwrite '%s'?" % slot, "That save will be replaced by the current game.",
				func() -> void: slot_chosen.emit(slot)))
	else:
		action_btn.text = "Load"
		# A slot written by a newer/unmigratable format still lists (so it can be
		# deleted) but can't be loaded by this build.
		action_btn.disabled = not bool(info.get("loadable", true))
		action_btn.tooltip_text = "" if action_btn.disabled else "Load this save"
		if action_btn.disabled:
			action_btn.tooltip_text = "Saved by a different version of the game."
		action_btn.pressed.connect(func() -> void: slot_chosen.emit(slot))
	row.add_child(action_btn)

	var delete_btn := Button.new()
	delete_btn.text = "Delete"
	delete_btn.pressed.connect(func() -> void:
		_ask("Delete '%s'?" % slot, "This cannot be undone.", func() -> void:
			SaveManager.delete_slot(slot)
			refresh()))
	row.add_child(delete_btn)
	return row_panel

func _on_new_slot_pressed() -> void:
	var slot: String = SaveManager.sanitize_slot_name(_new_slot_edit.text)
	if slot.is_empty():
		return
	_new_slot_edit.text = ""
	if SaveManager.slot_exists(slot):
		_ask("Overwrite '%s'?" % slot, "That save will be replaced by the current game.",
			func() -> void: slot_chosen.emit(slot))
		return
	slot_chosen.emit(slot)

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
