@tool
class_name _y20
extends PanelContainer
enum _h13 {
	_t63,
	ERROR,
	WARNING,
	INFO
}
const _i9: int = 100
const _l87: int = 500
const _y57: float = 0.5
const _q49: float = 30.0
@onready var _t31: Label = %_p11
@onready var _n14: Label = %_y53
@onready var _c91: Label = %_e90
@onready var _z38: Timer = %_s59
@onready var _f26: AnimationPlayer = %AnimationPlayer
var _j91: bool = false
var _x27: float = 1.0
var _u80: bool = false
var _b72: EditorInterface
func _ready():
	if _z38:
		_z38.timeout.connect(_f3)
	_n1()
	_v12()
	_x81()
	_f62()
	modulate.a = 0.0
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _n1():
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		var mode = config.get_value("font_scale", "mode", "auto")
		if mode == "auto":
			var _j97 = DisplayServer.screen_get_size().y
			if _j97 >= 2160:
				_x27 = 1.5
			elif _j97 >= 1440:
				_x27 = 1.25
			else:
				_x27 = 1.0
		else:
			_x27 = clamp(float(mode), 0.5, 3.0)
func _v12():
	var _i13 = get_theme_color("base_color", "Editor") if has_theme_color("base_color", "Editor") else get_theme_color("panel_container", "PanelContainer")
	var _m32 = _i13.get_luminance() > 0.5
	_u80 = _m32
	var _p1 = StyleBoxFlat.new()
	_p1.bg_color = _i13.darkened(0.05) if _m32 else _i13.lightened(0.08)
	_p1.border_color = _i13.darkened(0.2) if _m32 else _i13.lightened(0.15)
	var _t3 = int(8 * _x27)
	var _n35 = int(4 * _x27)
	var _q11 = int(4 * _x27)
	_p1.corner_radius_top_left = _q11
	_p1.corner_radius_top_right = _q11
	_p1.corner_radius_bottom_left = _q11
	_p1.corner_radius_bottom_right = _q11
	_p1.content_margin_left = _t3
	_p1.content_margin_right = _t3
	_p1.content_margin_top = _n35
	_p1.content_margin_bottom = _n35
	_p1.border_width_left = 1
	_p1.border_width_right = 1
	_p1.border_width_top = 1
	_p1.border_width_bottom = 1
	add_theme_stylebox_override("panel", _p1)
func _f94(_o10: EditorInterface) -> void:
	_b72 = _o10
func _k97() -> int:
	if _b72:
		var theme = _b72.get_editor_theme()
		if theme:
			var _a72 = theme.get_font_size("main_size", "EditorFonts")
			if _a72 > 0:
				return _a72
	return 14  
func _x81():
	var _q44 = _k97()
	var _w24 = _q44
	var _a23 = _q44  
	var _r74 = int(_q44 * 1.1)  
	var font_color = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	if _t31:
		_t31.add_theme_font_size_override("font_size", _r74)
	if _n14:
		_n14.add_theme_font_size_override("font_size", _w24)
		_n14.add_theme_color_override("font_color", font_color)
	if _c91:
		_c91.add_theme_font_size_override("font_size", _a23)
		_c91.add_theme_color_override("font_color", font_color.darkened(0.2) if _u80 else font_color.darkened(0.15))
func _o66(title: String, message: String, _c87: _h13 = _h13._t63, _l27: float = 3.0):
	var _f72 = title.substr(0, _i9)
	var _f78 = message.substr(0, _l87)
	var _r20 = clampf(_l27, _y57, _q49)
	_n1()
	_v12()
	_x81()
	if _j91:
		_p80(_f72, _f78, _c87)
		if _z38 and is_inside_tree():
			_z38.stop()
			_z38.wait_time = _r20
			_z38.start()
		return
	_p80(_f72, _f78, _c87)
	if _z38:
		_z38.wait_time = _r20
		if is_inside_tree():
			_z38.start()
		else:
			_q26.call_deferred(_r20)
	_f31()
func _q26(_l27: float):
	if _z38 and is_inside_tree():
		_z38.wait_time = _l27
		_z38.start()
func _p80(title: String, message: String, _c87: _h13):
	if _n14:
		_n14.text = title
	if _c91:
		_c91.text = message
	match _c87:
		_h13._t63:
			if _t31:
				_t31.text = "✓"
				var _f80 = get_theme_color("success_color", "Editor") if has_theme_color("success_color", "Editor") else Color(0.3, 0.9, 0.3, 1.0)
				_t31.add_theme_color_override("font_color", _f80)
		_h13.ERROR:
			if _t31:
				_t31.text = "✗"
				var _b46 = get_theme_color("error_color", "Editor") if has_theme_color("error_color", "Editor") else Color(0.9, 0.3, 0.3, 1.0)
				_t31.add_theme_color_override("font_color", _b46)
		_h13.WARNING:
			if _t31:
				_t31.text = "⚠"
				var _e49 = get_theme_color("warning_color", "Editor") if has_theme_color("warning_color", "Editor") else Color(0.9, 0.7, 0.2, 1.0)
				_t31.add_theme_color_override("font_color", _e49)
		_h13.INFO:
			if _t31:
				_t31.text = "ℹ"
				var _w23 = get_theme_color("accent_color", "Editor") if has_theme_color("accent_color", "Editor") else Color(0.4, 0.7, 1.0, 1.0)
				_t31.add_theme_color_override("font_color", _w23)
func _f31():
	visible = true
	_j91 = true
	if _f26 and _f26.has_animation_library("default"):
		var _x58 = _f26.get_animation_library("default")
		if _x58.has_animation("slide_in"):
			_f26.play("default/slide_in")
		else:
			modulate.a = 1.0
	else:
		modulate.a = 1.0
func _d38():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _f26 and _f26.has_animation_library("default"):
		var _x58 = _f26.get_animation_library("default")
		if _x58.has_animation("slide_out"):
			_f26.play("default/slide_out")
		else:
			modulate.a = 0.0
			visible = false
			_j91 = false
	else:
		modulate.a = 0.0
		visible = false
		_j91 = false
func _f62():
	if not _f26:
		return
	if not _f26.has_animation_library("default"):
		var _b43 = AnimationLibrary.new()
		_f26.add_animation_library("default", _b43)
	var _b43 = _f26.get_animation_library("default")
	if not _b43.has_animation("slide_in"):
		var _m70 = Animation.new()
		_m70.length = 0.2
		var _k86 = _m70.add_track(Animation.TYPE_VALUE)
		_m70.track_set_path(_k86, NodePath(".:modulate:a"))
		_m70.track_insert_key(_k86, 0.0, 0.0)
		_m70.track_insert_key(_k86, 0.2, 1.0)
		_b43.add_animation("slide_in", _m70)
	if not _b43.has_animation("slide_out"):
		var _h53 = Animation.new()
		_h53.length = 0.15
		var _j10 = _h53.add_track(Animation.TYPE_VALUE)
		_h53.track_set_path(_j10, NodePath(".:modulate:a"))
		_h53.track_insert_key(_j10, 0.0, 1.0)
		_h53.track_insert_key(_j10, 0.15, 0.0)
		_b43.add_animation("slide_out", _h53)
	if not _f26.animation_finished.is_connected(_c55):
		_f26.animation_finished.connect(_c55)
func _f3():
	_d38()
func _c55(_b97: String):
	if _b97 == "slide_out":
		visible = false
		_j91 = false
func _o44():
	if _z38:
		_z38.stop()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false
	_j91 = false
func _s71() -> bool:
	return _j91
func _m18(text: String) -> String:
	var _j8 = text.replace("[", "\\[").replace("]", "\\]")
	return _j8.substr(0, 200)
func _d20(title: String, message: String, _l27: float = 3.0):
	_o66(title, message, _h13._t63, _l27)
func _t88(title: String, message: String, _l27: float = 5.0):
	_o66(title, message, _h13.ERROR, _l27)
func _a14(title: String, message: String, _l27: float = 4.0):
	_o66(title, message, _h13.WARNING, _l27)
func _z82(title: String, message: String, _l27: float = 3.0):
	_o66(title, message, _h13.INFO, _l27)
func _b70(function_name: String):
	var _d55 = _m18(function_name)
	_d20("Refactor Undone", "Function '%s' has been restored to its original state" % _d55, 5.0)
func _f38(function_name: String, _p7: String):
	var _d55 = _m18(function_name)
	var _v35 = _m18(_p7)
	_t88("Undo Failed", "Could not undo refactor for '%s': %s" % [_d55, _v35])
func _d34(function_name: String):
	var _d55 = _m18(function_name)
	_a14("No History", "No refactor history available for function '%s'" % _d55)
