@tool
class_name _e46
extends PanelContainer

enum _h54 {
	_p84,
	ERROR,
	WARNING,
	INFO
}

const _y52: int = 100
const _q46: int = 500
const _k93: float = 0.5
const _y79: float = 30.0

@onready var _m72: Label = %_v9
@onready var _n13: Label = %_x43
@onready var _c29: Label = %_q53
@onready var _c34: Timer = %_q68
@onready var _j81: AnimationPlayer = %AnimationPlayer

var _c56: bool = false
var _g83: float = 1.0
var _n10: bool = false
var _q86: EditorInterface

func _ready():
	if _c34:
		_c34.timeout.connect(_n48)

	_p74()

	_d77()

	_h45()

	_i3()

	modulate.a = 0.0
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _p74():
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		var mode = config.get_value("font_scale", "mode", "auto")
		if mode == "auto":
			var _d40 = DisplayServer.screen_get_size().y
			if _d40 >= 2160:
				_g83 = 1.5
			elif _d40 >= 1440:
				_g83 = 1.25
			else:
				_g83 = 1.0
		else:
			_g83 = clamp(float(mode), 0.5, 3.0)

func _d77():
	var _t29 = get_theme_color("base_color", "Editor") if has_theme_color("base_color", "Editor") else get_theme_color("panel_container", "PanelContainer")
	var _r46 = _t29.get_luminance() > 0.5
	_n10 = _r46

	var _x67 = StyleBoxFlat.new()

	_x67.bg_color = _t29.darkened(0.05) if _r46 else _t29.lightened(0.08)
	_x67.border_color = _t29.darkened(0.2) if _r46 else _t29.lightened(0.15)

	var _u31 = int(8 * _g83)
	var _g30 = int(4 * _g83)
	var _i7 = int(4 * _g83)

	_x67.corner_radius_top_left = _i7
	_x67.corner_radius_top_right = _i7
	_x67.corner_radius_bottom_left = _i7
	_x67.corner_radius_bottom_right = _i7
	_x67.content_margin_left = _u31
	_x67.content_margin_right = _u31
	_x67.content_margin_top = _g30
	_x67.content_margin_bottom = _g30
	_x67.border_width_left = 1
	_x67.border_width_right = 1
	_x67.border_width_top = 1
	_x67.border_width_bottom = 1
	add_theme_stylebox_override("panel", _x67)

func _k94(_t15: EditorInterface) -> void:
	_q86 = _t15

func _c77() -> int:
	if _q86:
		var theme = _q86.get_editor_theme()
		if theme:
			var _z95 = theme.get_font_size("main_size", "EditorFonts")
			if _z95 > 0:
				return _z95
	return 14  

func _h45():
	var _r90 = _c77()

	var _v91 = _r90
	var _l24 = _r90  
	var _d33 = int(_r90 * 1.1)  

	var font_color = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")

	if _m72:
		_m72.add_theme_font_size_override("font_size", _d33)
	if _n13:
		_n13.add_theme_font_size_override("font_size", _v91)
		_n13.add_theme_color_override("font_color", font_color)
	if _c29:
		_c29.add_theme_font_size_override("font_size", _l24)

		_c29.add_theme_color_override("font_color", font_color.darkened(0.2) if _n10 else font_color.darkened(0.15))

func _y35(title: String, message: String, _j48: _h54 = _h54._p84, _z52: float = 3.0):
	var _h83 = title.substr(0, _y52)
	var _y9 = message.substr(0, _q46)
	var _c4 = clampf(_z52, _k93, _y79)

	_p74()
	_d77()
	_h45()

	if _c56:
		_s55(_h83, _y9, _j48)

		if _c34 and is_inside_tree():
			_c34.stop()
			_c34.wait_time = _c4
			_c34.start()
		return

	_s55(_h83, _y9, _j48)

	if _c34:
		_c34.wait_time = _c4
		if is_inside_tree():
			_c34.start()
		else:
			_d22.call_deferred(_c4)

	_k72()

func _d22(_z52: float):
	if _c34 and is_inside_tree():
		_c34.wait_time = _z52
		_c34.start()

func _s55(title: String, message: String, _j48: _h54):
	if _n13:
		_n13.text = title
	if _c29:
		_c29.text = message
	
	match _j48:
		_h54._p84:
			if _m72:
				_m72.text = "✓"
				var _p11 = get_theme_color("success_color", "Editor") if has_theme_color("success_color", "Editor") else Color(0.3, 0.9, 0.3, 1.0)
				_m72.add_theme_color_override("font_color", _p11)
		_h54.ERROR:
			if _m72:
				_m72.text = "✗"
				var _p52 = get_theme_color("error_color", "Editor") if has_theme_color("error_color", "Editor") else Color(0.9, 0.3, 0.3, 1.0)
				_m72.add_theme_color_override("font_color", _p52)
		_h54.WARNING:
			if _m72:
				_m72.text = "⚠"
				var _q36 = get_theme_color("warning_color", "Editor") if has_theme_color("warning_color", "Editor") else Color(0.9, 0.7, 0.2, 1.0)
				_m72.add_theme_color_override("font_color", _q36)
		_h54.INFO:
			if _m72:
				_m72.text = "ℹ"
				var _p38 = get_theme_color("accent_color", "Editor") if has_theme_color("accent_color", "Editor") else Color(0.4, 0.7, 1.0, 1.0)
				_m72.add_theme_color_override("font_color", _p38)

func _k72():
	visible = true
	_c56 = true

	if _j81 and _j81.has_animation_library("default"):
		var _d63 = _j81.get_animation_library("default")
		if _d63.has_animation("slide_in"):
			_j81.play("default/slide_in")
		else:
			modulate.a = 1.0
	else:
		modulate.a = 1.0

func _a98():
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _j81 and _j81.has_animation_library("default"):
		var _d63 = _j81.get_animation_library("default")
		if _d63.has_animation("slide_out"):
			_j81.play("default/slide_out")
		else:
			modulate.a = 0.0
			visible = false
			_c56 = false
	else:
		modulate.a = 0.0
		visible = false
		_c56 = false

func _i3():
	if not _j81:
		return
	
	if not _j81.has_animation_library("default"):
		var _d17 = AnimationLibrary.new()
		_j81.add_animation_library("default", _d17)
	
	var _d17 = _j81.get_animation_library("default")
	
	if not _d17.has_animation("slide_in"):
		var _t36 = Animation.new()
		_t36.length = 0.2

		var _k84 = _t36.add_track(Animation.TYPE_VALUE)
		_t36.track_set_path(_k84, NodePath(".:modulate:a"))
		_t36.track_insert_key(_k84, 0.0, 0.0)
		_t36.track_insert_key(_k84, 0.2, 1.0)

		_d17.add_animation("slide_in", _t36)

	if not _d17.has_animation("slide_out"):
		var _w17 = Animation.new()
		_w17.length = 0.15

		var _v5 = _w17.add_track(Animation.TYPE_VALUE)
		_w17.track_set_path(_v5, NodePath(".:modulate:a"))
		_w17.track_insert_key(_v5, 0.0, 1.0)
		_w17.track_insert_key(_v5, 0.15, 0.0)
		
		_d17.add_animation("slide_out", _w17)
	
	if not _j81.animation_finished.is_connected(_m58):
		_j81.animation_finished.connect(_m58)

func _n48():
	_a98()

func _m58(_p6: String):
	if _p6 == "slide_out":
		visible = false
		_c56 = false

func _f46():
	if _c34:
		_c34.stop()

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false
	_c56 = false
	
func _t35() -> bool:
	return _c56

func _g18(text: String) -> String:
	var _h85 = text.replace("[", "\\[").replace("]", "\\]")
	return _h85.substr(0, 200)

func _f49(title: String, message: String, _z52: float = 3.0):
	_y35(title, message, _h54._p84, _z52)

func _d31(title: String, message: String, _z52: float = 5.0):
	_y35(title, message, _h54.ERROR, _z52)

func _x95(title: String, message: String, _z52: float = 4.0):
	_y35(title, message, _h54.WARNING, _z52)

func _p72(title: String, message: String, _z52: float = 3.0):
	_y35(title, message, _h54.INFO, _z52)

func _i22(function_name: String):
	var _p66 = _g18(function_name)
	_f49("Refactor Undone", "Function '%s' has been restored to its original state" % _p66, 5.0)

func _v37(function_name: String, _y100: String):
	var _p66 = _g18(function_name)
	var _w64 = _g18(_y100)
	_d31("Undo Failed", "Could not undo refactor for '%s': %s" % [_p66, _w64])

func _k83(function_name: String):
	var _p66 = _g18(function_name)
	_x95("No History", "No refactor history available for function '%s'" % _p66)

