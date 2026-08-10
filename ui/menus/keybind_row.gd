class_name KeybindRow
extends HBoxContainer

## One line of the remap list (WI-36): action label, current binding button, and
## a per-action reset. Deliberately dumb - it renders what Global reports and
## asks its owner (SettingsMenu) to run the capture, because capture needs a
## modal overlay with its own cancel button and that belongs to the screen.

signal rebind_requested(action: StringName)

var action: StringName

var _binding_button: Button

func setup(new_action: StringName) -> void:
	action = new_action
	add_theme_constant_override("separation", 8)

	var label := Label.new()
	label.text = Global.action_label(action)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(label)

	_binding_button = Button.new()
	_binding_button.custom_minimum_size = Vector2(150, 0)
	_binding_button.pressed.connect(func() -> void: rebind_requested.emit(action))
	add_child(_binding_button)

	var reset := Button.new()
	reset.text = "Reset"
	reset.tooltip_text = "Restore the default binding for this action"
	reset.pressed.connect(func() -> void:
		Global.reset_action_binding(action)
		refresh())
	add_child(reset)
	refresh()

func refresh() -> void:
	if _binding_button == null:
		return
	_binding_button.text = GameSettings.describe_events(Global.get_effective_events(action))
	# Flag a customised binding so "which of these did I change?" is answerable
	# without opening a diff against the defaults.
	_binding_button.add_theme_color_override("font_color",
		UIPalette.LIVE_BRIGHT if Global.settings.has_binding(action) else UIPalette.TEXT)

## Shown while this row's capture overlay is up.
func set_capturing(capturing: bool) -> void:
	if _binding_button == null:
		return
	if capturing:
		_binding_button.text = "Press any key…"
	else:
		refresh()
