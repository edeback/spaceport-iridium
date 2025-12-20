## Shared UI interaction helper for placeable UI components.
##
## Provides consistent pressed/hover/normal state interaction for placeable views and list entries.
## Handles mouse interactions and visual feedback to ensure consistent user experience.
## Uses theme file for style definitions while managing state transitions.
@tool
class_name PlaceableUIInteraction
extends RefCounted

## Style configurations loaded from theme
var _style_normal: StyleBoxFlat
var _style_pressed: StyleBoxFlat
var _style_hover: StyleBoxFlat
var _theme: Theme

## Reference to the control that uses these styles
var _control: Control
var _is_pressed: bool = false

## Initialize the style helper with a control reference
func init(control: Control) -> void:
	_control = control
	_load_theme_styles()
	_connect_signals()
	_apply_normal_style()

## Load style definitions from the theme file
func _load_theme_styles() -> void:
	_theme = load("res://addons/grid_building/ui/placeable/shared/placeable_ui_theme.tres") as Theme
	
	if _theme:
		_style_normal = _theme.get_stylebox("panel", "PanelContainer")
		_style_hover = _theme.get_stylebox("panel_hover", "PanelContainer") 
		_style_pressed = _theme.get_stylebox("panel_pressed", "PanelContainer")
	else:
		# Fallback if theme file is missing
		_create_fallback_styles()

## Create fallback styles if theme file is unavailable
func _create_fallback_styles() -> void:
	# Normal state - subtle background with light border
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = Color(0.1, 0.1, 0.1, 0.6)
	_style_normal.border_color = Color(0, 1, 1, 0.2)
	_style_normal.border_width_left = 1
	_style_normal.border_width_top = 1
	_style_normal.border_width_right = 1
	_style_normal.border_width_bottom = 1
	_style_normal.corner_radius_top_left = 3
	_style_normal.corner_radius_top_right = 3
	_style_normal.corner_radius_bottom_left = 3
	_style_normal.corner_radius_bottom_right = 3
	
	# Hover state - slightly brighter background and border
	_style_hover = _style_normal.duplicate()
	_style_hover.bg_color = Color(0.15, 0.15, 0.15, 0.8)
	_style_hover.border_color = Color(0, 1, 1, 0.6)
	
	# Pressed state - cyan-tinted background with bright border
	_style_pressed = _style_normal.duplicate()
	_style_pressed.bg_color = Color(0, 0.3, 0.45, 0.8)
	_style_pressed.border_color = Color(0, 1, 1, 1.0)

## Connect mouse and input signals to the control
func _connect_signals() -> void:
	if not _control.mouse_entered.is_connected(_on_mouse_entered):
		_control.mouse_entered.connect(_on_mouse_entered)
	if not _control.mouse_exited.is_connected(_on_mouse_exited):
		_control.mouse_exited.connect(_on_mouse_exited)
	if not _control.gui_input.is_connected(_on_gui_input):
		_control.gui_input.connect(_on_gui_input)

## Apply normal style to the control
func _apply_normal_style() -> void:
	_control.add_theme_stylebox_override("panel", _style_normal)

## Apply hover style to the control
func _apply_hover_style() -> void:
	_control.add_theme_stylebox_override("panel", _style_hover)

## Apply pressed style to the control
func _apply_pressed_style() -> void:
	_control.add_theme_stylebox_override("panel", _style_pressed)

## Handle mouse enter events
func _on_mouse_entered() -> void:
	if not _is_pressed:
		_apply_hover_style()

## Handle mouse exit events
func _on_mouse_exited() -> void:
	if not _is_pressed:
		_apply_normal_style()

## Handle GUI input events for press/release detection
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_is_pressed = true
				_apply_pressed_style()
			else:
				_is_pressed = false
				_apply_normal_style()
				# Only emit click if mouse is still over the control
				if _control.get_global_rect().has_point(_control.get_global_mouse_position()):
					_on_click()

## Allow external objects to connect to click events
signal clicked()

## Handle click events by emitting signal
func _on_click() -> void:
	clicked.emit()

## Cleanup method to disconnect signals when no longer needed
func cleanup() -> void:
	if _control and is_instance_valid(_control):
		if _control.mouse_entered.is_connected(_on_mouse_entered):
			_control.mouse_entered.disconnect(_on_mouse_entered)
		if _control.mouse_exited.is_connected(_on_mouse_exited):
			_control.mouse_exited.disconnect(_on_mouse_exited)
		if _control.gui_input.is_connected(_on_gui_input):
			_control.gui_input.disconnect(_on_gui_input)