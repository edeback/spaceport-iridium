@tool
class_name _n28
extends PanelContainer
enum _t78 {
	_x4,
	ERROR,
	WARNING,
	INFO
}
const _n18: int = 100
const _t7: int = 500
const _g70: float = 0.5
const _p22: float = 30.0
@onready var _w29: Label = %_l76
@onready var _t2: Label = %_r20
@onready var _x39: Label = %_o13
@onready var _y91: Timer = %_u20
@onready var _u57: AnimationPlayer = %AnimationPlayer
var _u71: bool = false
var _v32: float = 1.0
var _p33: bool = false
var _r15: EditorInterface
func _ready():
	if _y91:
		_y91.timeout.connect(_r51)
	_k57()
	_o55()
	_j28()
	_a31()
	modulate.a = 0.0
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _k57():
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		var mode = config.get_value("font_scale", "mode", "auto")
		if mode == "auto":
			var _v76 = DisplayServer.screen_get_size().y
			if _v76 >= 2160:
				_v32 = 1.5
			elif _v76 >= 1440:
				_v32 = 1.25
			else:
				_v32 = 1.0
		else:
			_v32 = clamp(float(mode), 0.5, 3.0)
func _o55():
	var _v22 = get_theme_color("base_color", "Editor") if has_theme_color("base_color", "Editor") else get_theme_color("panel_container", "PanelContainer")
	var _b21 = _v22.get_luminance() > 0.5
	_p33 = _b21
	var _c4 = StyleBoxFlat.new()
	_c4.bg_color = _v22.darkened(0.05) if _b21 else _v22.lightened(0.08)
	_c4.border_color = _v22.darkened(0.2) if _b21 else _v22.lightened(0.15)
	var _w55 = int(8 * _v32)
	var _z36 = int(4 * _v32)
	var _n45 = int(4 * _v32)
	_c4.corner_radius_top_left = _n45
	_c4.corner_radius_top_right = _n45
	_c4.corner_radius_bottom_left = _n45
	_c4.corner_radius_bottom_right = _n45
	_c4.content_margin_left = _w55
	_c4.content_margin_right = _w55
	_c4.content_margin_top = _z36
	_c4.content_margin_bottom = _z36
	_c4.border_width_left = 1
	_c4.border_width_right = 1
	_c4.border_width_top = 1
	_c4.border_width_bottom = 1
	add_theme_stylebox_override("panel", _c4)
func _r95(_k71: EditorInterface) -> void:
	_r15 = _k71
func _s98() -> int:
	if _r15:
		var theme = _r15.get_editor_theme()
		if theme:
			var _b87 = theme.get_font_size("main_size", "EditorFonts")
			if _b87 > 0:
				return _b87
	return 14  
func _j28():
	var _w21 = _s98()
	var _u25 = _w21
	var _j70 = _w21  
	var _h90 = int(_w21 * 1.1)  
	var font_color = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	if _w29:
		_w29.add_theme_font_size_override("font_size", _h90)
	if _t2:
		_t2.add_theme_font_size_override("font_size", _u25)
		_t2.add_theme_color_override("font_color", font_color)
	if _x39:
		_x39.add_theme_font_size_override("font_size", _j70)
		_x39.add_theme_color_override("font_color", font_color.darkened(0.2) if _p33 else font_color.darkened(0.15))
func _p99(title: String, message: String, _z4: _t78 = _t78._x4, _b100: float = 3.0):
	var _a53 = title.substr(0, _n18)
	var _s79 = message.substr(0, _t7)
	var _w90 = clampf(_b100, _g70, _p22)
	_k57()
	_o55()
	_j28()
	if _u71:
		_k8(_a53, _s79, _z4)
		if _y91 and is_inside_tree():
			_y91.stop()
			_y91.wait_time = _w90
			_y91.start()
		return
	_k8(_a53, _s79, _z4)
	if _y91:
		_y91.wait_time = _w90
		if is_inside_tree():
			_y91.start()
		else:
			_k62.call_deferred(_w90)
	_w94()
func _k62(_b100: float):
	if _y91 and is_inside_tree():
		_y91.wait_time = _b100
		_y91.start()
func _k8(title: String, message: String, _z4: _t78):
	if _t2:
		_t2.text = title
	if _x39:
		_x39.text = message
	match _z4:
		_t78._x4:
			if _w29:
				_w29.text = "✓"
				var _v27 = get_theme_color("success_color", "Editor") if has_theme_color("success_color", "Editor") else Color(0.3, 0.9, 0.3, 1.0)
				_w29.add_theme_color_override("font_color", _v27)
		_t78.ERROR:
			if _w29:
				_w29.text = "✗"
				var _f41 = get_theme_color("error_color", "Editor") if has_theme_color("error_color", "Editor") else Color(0.9, 0.3, 0.3, 1.0)
				_w29.add_theme_color_override("font_color", _f41)
		_t78.WARNING:
			if _w29:
				_w29.text = "⚠"
				var _r91 = get_theme_color("warning_color", "Editor") if has_theme_color("warning_color", "Editor") else Color(0.9, 0.7, 0.2, 1.0)
				_w29.add_theme_color_override("font_color", _r91)
		_t78.INFO:
			if _w29:
				_w29.text = "ℹ"
				var _g56 = get_theme_color("accent_color", "Editor") if has_theme_color("accent_color", "Editor") else Color(0.4, 0.7, 1.0, 1.0)
				_w29.add_theme_color_override("font_color", _g56)
func _w94():
	visible = true
	_u71 = true
	if _u57 and _u57.has_animation_library("default"):
		var _f99 = _u57.get_animation_library("default")
		if _f99.has_animation("slide_in"):
			_u57.play("default/slide_in")
		else:
			modulate.a = 1.0
	else:
		modulate.a = 1.0
func _l36():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _u57 and _u57.has_animation_library("default"):
		var _f99 = _u57.get_animation_library("default")
		if _f99.has_animation("slide_out"):
			_u57.play("default/slide_out")
		else:
			modulate.a = 0.0
			visible = false
			_u71 = false
	else:
		modulate.a = 0.0
		visible = false
		_u71 = false
func _a31():
	if not _u57:
		return
	if not _u57.has_animation_library("default"):
		var _f65 = AnimationLibrary.new()
		_u57.add_animation_library("default", _f65)
	var _f65 = _u57.get_animation_library("default")
	if not _f65.has_animation("slide_in"):
		var _f64 = Animation.new()
		_f64.length = 0.2
		var _m33 = _f64.add_track(Animation.TYPE_VALUE)
		_f64.track_set_path(_m33, NodePath(".:modulate:a"))
		_f64.track_insert_key(_m33, 0.0, 0.0)
		_f64.track_insert_key(_m33, 0.2, 1.0)
		_f65.add_animation("slide_in", _f64)
	if not _f65.has_animation("slide_out"):
		var _v68 = Animation.new()
		_v68.length = 0.15
		var _t10 = _v68.add_track(Animation.TYPE_VALUE)
		_v68.track_set_path(_t10, NodePath(".:modulate:a"))
		_v68.track_insert_key(_t10, 0.0, 1.0)
		_v68.track_insert_key(_t10, 0.15, 0.0)
		_f65.add_animation("slide_out", _v68)
	if not _u57.animation_finished.is_connected(_t30):
		_u57.animation_finished.connect(_t30)
func _r51():
	_l36()
func _t30(_m43: String):
	if _m43 == "slide_out":
		visible = false
		_u71 = false
func _r61():
	if _y91:
		_y91.stop()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false
	_u71 = false
func _e25() -> bool:
	return _u71
func _o7(text: String) -> String:
	var _r43 = text.replace("[", "\\[").replace("]", "\\]")
	return _r43.substr(0, 200)
func _i83(title: String, message: String, _b100: float = 3.0):
	_p99(title, message, _t78._x4, _b100)
func _u56(title: String, message: String, _b100: float = 5.0):
	_p99(title, message, _t78.ERROR, _b100)
func _p24(title: String, message: String, _b100: float = 4.0):
	_p99(title, message, _t78.WARNING, _b100)
func _b2(title: String, message: String, _b100: float = 3.0):
	_p99(title, message, _t78.INFO, _b100)
func _i39(function_name: String):
	var _p34 = _o7(function_name)
	_i83("Refactor Undone", "Function '%s' has been restored to its original state" % _p34, 5.0)
func _h6(function_name: String, _m16: String):
	var _p34 = _o7(function_name)
	var _g100 = _o7(_m16)
	_u56("Undo Failed", "Could not undo refactor for '%s': %s" % [_p34, _g100])
func _g45(function_name: String):
	var _p34 = _o7(function_name)
	_p24("No History", "No refactor history available for function '%s'" % _p34)
