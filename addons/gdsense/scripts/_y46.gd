@tool
class_name _l84
extends PanelContainer
enum _y31 {
	_g9,
	ERROR,
	WARNING,
	INFO
}
const _a6: int = 100
const _i20: int = 500
const _b75: float = 0.5
const _r67: float = 30.0
@onready var _w57: Label = %_t72
@onready var _g25: Label = %_v63
@onready var _r64: Label = %_j86
@onready var _b53: Timer = %_o76
@onready var _m58: AnimationPlayer = %AnimationPlayer
var _t45: bool = false
var _p78: float = 1.0
var _w28: bool = false
var _w27: EditorInterface
func _ready():
	if _b53:
		_b53.timeout.connect(_x10)
	_b20()
	_j72()
	_v20()
	_j35()
	modulate.a = 0.0
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _b20():
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		var mode = config.get_value("font_scale", "mode", "auto")
		if mode == "auto":
			var _n100 = DisplayServer.screen_get_size().y
			if _n100 >= 2160:
				_p78 = 1.5
			elif _n100 >= 1440:
				_p78 = 1.25
			else:
				_p78 = 1.0
		else:
			_p78 = clamp(float(mode), 0.5, 3.0)
func _j72():
	var _z13 = get_theme_color("base_color", "Editor") if has_theme_color("base_color", "Editor") else get_theme_color("panel_container", "PanelContainer")
	var _q53 = _z13.get_luminance() > 0.5
	_w28 = _q53
	var _p10 = StyleBoxFlat.new()
	_p10.bg_color = _z13.darkened(0.05) if _q53 else _z13.lightened(0.08)
	_p10.border_color = _z13.darkened(0.2) if _q53 else _z13.lightened(0.15)
	var _e78 = int(8 * _p78)
	var _f61 = int(4 * _p78)
	var _a70 = int(4 * _p78)
	_p10.corner_radius_top_left = _a70
	_p10.corner_radius_top_right = _a70
	_p10.corner_radius_bottom_left = _a70
	_p10.corner_radius_bottom_right = _a70
	_p10.content_margin_left = _e78
	_p10.content_margin_right = _e78
	_p10.content_margin_top = _f61
	_p10.content_margin_bottom = _f61
	_p10.border_width_left = 1
	_p10.border_width_right = 1
	_p10.border_width_top = 1
	_p10.border_width_bottom = 1
	add_theme_stylebox_override("panel", _p10)
func _i71(_d84: EditorInterface) -> void:
	_w27 = _d84
func _b8() -> int:
	if _w27:
		var theme = _w27.get_editor_theme()
		if theme:
			var _e31 = theme.get_font_size("main_size", "EditorFonts")
			if _e31 > 0:
				return _e31
	return 14  
func _v20():
	var _e80 = _b8()
	var _q93 = _e80
	var _w54 = _e80  
	var _p69 = int(_e80 * 1.1)  
	var font_color = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	if _w57:
		_w57.add_theme_font_size_override("font_size", _p69)
	if _g25:
		_g25.add_theme_font_size_override("font_size", _q93)
		_g25.add_theme_color_override("font_color", font_color)
	if _r64:
		_r64.add_theme_font_size_override("font_size", _w54)
		_r64.add_theme_color_override("font_color", font_color.darkened(0.2) if _w28 else font_color.darkened(0.15))
func _o72(title: String, message: String, _b26: _y31 = _y31._g9, _l21: float = 3.0):
	var _n7 = title.substr(0, _a6)
	var _v90 = message.substr(0, _i20)
	var _a14 = clampf(_l21, _b75, _r67)
	_b20()
	_j72()
	_v20()
	if _t45:
		_w19(_n7, _v90, _b26)
		if _b53 and is_inside_tree():
			_b53.stop()
			_b53.wait_time = _a14
			_b53.start()
		return
	_w19(_n7, _v90, _b26)
	if _b53:
		_b53.wait_time = _a14
		if is_inside_tree():
			_b53.start()
		else:
			_r28.call_deferred(_a14)
	_l3()
func _r28(_l21: float):
	if _b53 and is_inside_tree():
		_b53.wait_time = _l21
		_b53.start()
func _w19(title: String, message: String, _b26: _y31):
	if _g25:
		_g25.text = title
	if _r64:
		_r64.text = message
	match _b26:
		_y31._g9:
			if _w57:
				_w57.text = "✓"
				var _j4 = get_theme_color("success_color", "Editor") if has_theme_color("success_color", "Editor") else Color(0.3, 0.9, 0.3, 1.0)
				_w57.add_theme_color_override("font_color", _j4)
		_y31.ERROR:
			if _w57:
				_w57.text = "✗"
				var _r42 = get_theme_color("error_color", "Editor") if has_theme_color("error_color", "Editor") else Color(0.9, 0.3, 0.3, 1.0)
				_w57.add_theme_color_override("font_color", _r42)
		_y31.WARNING:
			if _w57:
				_w57.text = "⚠"
				var _x44 = get_theme_color("warning_color", "Editor") if has_theme_color("warning_color", "Editor") else Color(0.9, 0.7, 0.2, 1.0)
				_w57.add_theme_color_override("font_color", _x44)
		_y31.INFO:
			if _w57:
				_w57.text = "ℹ"
				var _d43 = get_theme_color("accent_color", "Editor") if has_theme_color("accent_color", "Editor") else Color(0.4, 0.7, 1.0, 1.0)
				_w57.add_theme_color_override("font_color", _d43)
func _l3():
	visible = true
	_t45 = true
	if _m58 and _m58.has_animation_library("default"):
		var _w24 = _m58.get_animation_library("default")
		if _w24.has_animation("slide_in"):
			_m58.play("default/slide_in")
		else:
			modulate.a = 1.0
	else:
		modulate.a = 1.0
func _e13():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _m58 and _m58.has_animation_library("default"):
		var _w24 = _m58.get_animation_library("default")
		if _w24.has_animation("slide_out"):
			_m58.play("default/slide_out")
		else:
			modulate.a = 0.0
			visible = false
			_t45 = false
	else:
		modulate.a = 0.0
		visible = false
		_t45 = false
func _j35():
	if not _m58:
		return
	if not _m58.has_animation_library("default"):
		var _j44 = AnimationLibrary.new()
		_m58.add_animation_library("default", _j44)
	var _j44 = _m58.get_animation_library("default")
	if not _j44.has_animation("slide_in"):
		var _r62 = Animation.new()
		_r62.length = 0.2
		var _o32 = _r62.add_track(Animation.TYPE_VALUE)
		_r62.track_set_path(_o32, NodePath(".:modulate:a"))
		_r62.track_insert_key(_o32, 0.0, 0.0)
		_r62.track_insert_key(_o32, 0.2, 1.0)
		_j44.add_animation("slide_in", _r62)
	if not _j44.has_animation("slide_out"):
		var _o73 = Animation.new()
		_o73.length = 0.15
		var _m86 = _o73.add_track(Animation.TYPE_VALUE)
		_o73.track_set_path(_m86, NodePath(".:modulate:a"))
		_o73.track_insert_key(_m86, 0.0, 1.0)
		_o73.track_insert_key(_m86, 0.15, 0.0)
		_j44.add_animation("slide_out", _o73)
	if not _m58.animation_finished.is_connected(_y76):
		_m58.animation_finished.connect(_y76)
func _x10():
	_e13()
func _y76(_p46: String):
	if _p46 == "slide_out":
		visible = false
		_t45 = false
func _b91():
	if _b53:
		_b53.stop()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false
	_t45 = false
func _n30() -> bool:
	return _t45
func _t46(text: String) -> String:
	var _w37 = text.replace("[", "\\[").replace("]", "\\]")
	return _w37.substr(0, 200)
func _k41(title: String, message: String, _l21: float = 3.0):
	_o72(title, message, _y31._g9, _l21)
func _x13(title: String, message: String, _l21: float = 5.0):
	_o72(title, message, _y31.ERROR, _l21)
func _j82(title: String, message: String, _l21: float = 4.0):
	_o72(title, message, _y31.WARNING, _l21)
func _k77(title: String, message: String, _l21: float = 3.0):
	_o72(title, message, _y31.INFO, _l21)
func _g73(function_name: String):
	var _z50 = _t46(function_name)
	_k41("Refactor Undone", "Function '%s' has been restored to its original state" % _z50, 5.0)
func _h95(function_name: String, _u85: String):
	var _z50 = _t46(function_name)
	var _z49 = _t46(_u85)
	_x13("Undo Failed", "Could not undo refactor for '%s': %s" % [_z50, _z49])
func _g47(function_name: String):
	var _z50 = _t46(function_name)
	_j82("No History", "No refactor history available for function '%s'" % _z50)
