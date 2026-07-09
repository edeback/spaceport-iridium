@tool
class_name _o85
extends PanelContainer
enum _r1 {
	_m35,
	ERROR,
	WARNING,
	INFO
}
const _q71: int = 100
const _h41: int = 500
const _q26: float = 0.5
const _c94: float = 30.0
@onready var _n42: Label = %_p19
@onready var _q21: Label = %_c23
@onready var _k66: Label = %_c66
@onready var _u72: Timer = %_t98
@onready var _q55: AnimationPlayer = %AnimationPlayer
var _z75: bool = false
var _t35: float = 1.0
var _q50: bool = false
var _f21: EditorInterface
func _ready():
	if _u72:
		_u72.timeout.connect(_r71)
	_q6()
	_o66()
	_o19()
	_o24()
	modulate.a = 0.0
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _q6():
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		var mode = config.get_value("font_scale", "mode", "auto")
		if mode == "auto":
			var _h33 = DisplayServer.screen_get_size().y
			if _h33 >= 2160:
				_t35 = 1.5
			elif _h33 >= 1440:
				_t35 = 1.25
			else:
				_t35 = 1.0
		else:
			_t35 = clamp(float(mode), 0.5, 3.0)
func _o66():
	var _f9 = get_theme_color("base_color", "Editor") if has_theme_color("base_color", "Editor") else get_theme_color("panel_container", "PanelContainer")
	var _b35 = _f9.get_luminance() > 0.5
	_q50 = _b35
	var _u49 = StyleBoxFlat.new()
	_u49.bg_color = _f9.darkened(0.05) if _b35 else _f9.lightened(0.08)
	_u49.border_color = _f9.darkened(0.2) if _b35 else _f9.lightened(0.15)
	var _j78 = int(8 * _t35)
	var _w85 = int(4 * _t35)
	var _v56 = int(4 * _t35)
	_u49.corner_radius_top_left = _v56
	_u49.corner_radius_top_right = _v56
	_u49.corner_radius_bottom_left = _v56
	_u49.corner_radius_bottom_right = _v56
	_u49.content_margin_left = _j78
	_u49.content_margin_right = _j78
	_u49.content_margin_top = _w85
	_u49.content_margin_bottom = _w85
	_u49.border_width_left = 1
	_u49.border_width_right = 1
	_u49.border_width_top = 1
	_u49.border_width_bottom = 1
	add_theme_stylebox_override("panel", _u49)
func _o81(_i13: EditorInterface) -> void:
	_f21 = _i13
func _v7() -> int:
	if _f21:
		var theme = _f21.get_editor_theme()
		if theme:
			var _t34 = theme.get_font_size("main_size", "EditorFonts")
			if _t34 > 0:
				return _t34
	return 14  
func _o19():
	var _f96 = _v7()
	var _x29 = _f96
	var _i41 = _f96  
	var _t33 = int(_f96 * 1.1)  
	var font_color = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	if _n42:
		_n42.add_theme_font_size_override("font_size", _t33)
	if _q21:
		_q21.add_theme_font_size_override("font_size", _x29)
		_q21.add_theme_color_override("font_color", font_color)
	if _k66:
		_k66.add_theme_font_size_override("font_size", _i41)
		_k66.add_theme_color_override("font_color", font_color.darkened(0.2) if _q50 else font_color.darkened(0.15))
func _w70(title: String, message: String, _r62: _r1 = _r1._m35, _k8: float = 3.0):
	var _p9 = title.substr(0, _q71)
	var _g59 = message.substr(0, _h41)
	var _g78 = clampf(_k8, _q26, _c94)
	_q6()
	_o66()
	_o19()
	if _z75:
		_t16(_p9, _g59, _r62)
		if _u72 and is_inside_tree():
			_u72.stop()
			_u72.wait_time = _g78
			_u72.start()
		return
	_t16(_p9, _g59, _r62)
	if _u72:
		_u72.wait_time = _g78
		if is_inside_tree():
			_u72.start()
		else:
			_n68.call_deferred(_g78)
	_m41()
func _n68(_k8: float):
	if _u72 and is_inside_tree():
		_u72.wait_time = _k8
		_u72.start()
func _t16(title: String, message: String, _r62: _r1):
	if _q21:
		_q21.text = title
	if _k66:
		_k66.text = message
	match _r62:
		_r1._m35:
			if _n42:
				_n42.text = "✓"
				var _p35 = get_theme_color("success_color", "Editor") if has_theme_color("success_color", "Editor") else Color(0.3, 0.9, 0.3, 1.0)
				_n42.add_theme_color_override("font_color", _p35)
		_r1.ERROR:
			if _n42:
				_n42.text = "✗"
				var _t32 = get_theme_color("error_color", "Editor") if has_theme_color("error_color", "Editor") else Color(0.9, 0.3, 0.3, 1.0)
				_n42.add_theme_color_override("font_color", _t32)
		_r1.WARNING:
			if _n42:
				_n42.text = "⚠"
				var _z36 = get_theme_color("warning_color", "Editor") if has_theme_color("warning_color", "Editor") else Color(0.9, 0.7, 0.2, 1.0)
				_n42.add_theme_color_override("font_color", _z36)
		_r1.INFO:
			if _n42:
				_n42.text = "ℹ"
				var _j86 = get_theme_color("accent_color", "Editor") if has_theme_color("accent_color", "Editor") else Color(0.4, 0.7, 1.0, 1.0)
				_n42.add_theme_color_override("font_color", _j86)
func _m41():
	visible = true
	_z75 = true
	if _q55 and _q55.has_animation_library("default"):
		var _y96 = _q55.get_animation_library("default")
		if _y96.has_animation("slide_in"):
			_q55.play("default/slide_in")
		else:
			modulate.a = 1.0
	else:
		modulate.a = 1.0
func _d2():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _q55 and _q55.has_animation_library("default"):
		var _y96 = _q55.get_animation_library("default")
		if _y96.has_animation("slide_out"):
			_q55.play("default/slide_out")
		else:
			modulate.a = 0.0
			visible = false
			_z75 = false
	else:
		modulate.a = 0.0
		visible = false
		_z75 = false
func _o24():
	if not _q55:
		return
	if not _q55.has_animation_library("default"):
		var _h12 = AnimationLibrary.new()
		_q55.add_animation_library("default", _h12)
	var _h12 = _q55.get_animation_library("default")
	if not _h12.has_animation("slide_in"):
		var _x68 = Animation.new()
		_x68.length = 0.2
		var _n37 = _x68.add_track(Animation.TYPE_VALUE)
		_x68.track_set_path(_n37, NodePath(".:modulate:a"))
		_x68.track_insert_key(_n37, 0.0, 0.0)
		_x68.track_insert_key(_n37, 0.2, 1.0)
		_h12.add_animation("slide_in", _x68)
	if not _h12.has_animation("slide_out"):
		var _h45 = Animation.new()
		_h45.length = 0.15
		var _w34 = _h45.add_track(Animation.TYPE_VALUE)
		_h45.track_set_path(_w34, NodePath(".:modulate:a"))
		_h45.track_insert_key(_w34, 0.0, 1.0)
		_h45.track_insert_key(_w34, 0.15, 0.0)
		_h12.add_animation("slide_out", _h45)
	if not _q55.animation_finished.is_connected(_p31):
		_q55.animation_finished.connect(_p31)
func _r71():
	_d2()
func _p31(_s86: String):
	if _s86 == "slide_out":
		visible = false
		_z75 = false
func _c83():
	if _u72:
		_u72.stop()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false
	_z75 = false
func _l11() -> bool:
	return _z75
func _u22(text: String) -> String:
	var _s49 = text.replace("[", "\\[").replace("]", "\\]")
	return _s49.substr(0, 200)
func _e68(title: String, message: String, _k8: float = 3.0):
	_w70(title, message, _r1._m35, _k8)
func _b13(title: String, message: String, _k8: float = 5.0):
	_w70(title, message, _r1.ERROR, _k8)
func _t11(title: String, message: String, _k8: float = 4.0):
	_w70(title, message, _r1.WARNING, _k8)
func _j21(title: String, message: String, _k8: float = 3.0):
	_w70(title, message, _r1.INFO, _k8)
func _s2(function_name: String):
	var _v50 = _u22(function_name)
	_e68("Refactor Undone", "Function '%s' has been restored to its original state" % _v50, 5.0)
func _z100(function_name: String, _b14: String):
	var _v50 = _u22(function_name)
	var _c16 = _u22(_b14)
	_b13("Undo Failed", "Could not undo refactor for '%s': %s" % [_v50, _c16])
func _u47(function_name: String):
	var _v50 = _u22(function_name)
	_t11("No History", "No refactor history available for function '%s'" % _v50)
