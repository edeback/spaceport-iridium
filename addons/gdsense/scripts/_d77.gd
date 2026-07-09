@tool
class_name _f34
extends PanelContainer

enum _x62 {
	_b49,
	ERROR,
	WARNING,
	INFO
}

const _i3: int = 100
const _u9: int = 500
const _l74: float = 0.5
const _v61: float = 30.0

@onready var _o94: Label = %_a48
@onready var _y98: Label = %_k70
@onready var _c35: Label = %_a35
@onready var _b19: Timer = %_d82
@onready var _w98: AnimationPlayer = %AnimationPlayer

var _s2: bool = false
var _a31: float = 1.0
var _u37: bool = false
var _z76: EditorInterface

func _ready():
	if _b19:
		_b19.timeout.connect(_t22)

	_x92()

	_z66()

	_q25()

	_u100()

	modulate.a = 0.0
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _x92():
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		var mode = config.get_value("font_scale", "mode", "auto")
		if mode == "auto":
			var _u14 = DisplayServer.screen_get_size().y
			if _u14 >= 2160:
				_a31 = 1.5
			elif _u14 >= 1440:
				_a31 = 1.25
			else:
				_a31 = 1.0
		else:
			_a31 = clamp(float(mode), 0.5, 3.0)

func _z66():
	var _m31 = get_theme_color("base_color", "Editor") if has_theme_color("base_color", "Editor") else get_theme_color("panel_container", "PanelContainer")
	var _o90 = _m31.get_luminance() > 0.5
	_u37 = _o90

	var _r20 = StyleBoxFlat.new()

	_r20.bg_color = _m31.darkened(0.05) if _o90 else _m31.lightened(0.08)
	_r20.border_color = _m31.darkened(0.2) if _o90 else _m31.lightened(0.15)

	var _v83 = int(8 * _a31)
	var _j10 = int(4 * _a31)
	var _p21 = int(4 * _a31)

	_r20.corner_radius_top_left = _p21
	_r20.corner_radius_top_right = _p21
	_r20.corner_radius_bottom_left = _p21
	_r20.corner_radius_bottom_right = _p21
	_r20.content_margin_left = _v83
	_r20.content_margin_right = _v83
	_r20.content_margin_top = _j10
	_r20.content_margin_bottom = _j10
	_r20.border_width_left = 1
	_r20.border_width_right = 1
	_r20.border_width_top = 1
	_r20.border_width_bottom = 1
	add_theme_stylebox_override("panel", _r20)

func _a87(_i86: EditorInterface) -> void:
	_z76 = _i86

func _b74() -> int:
	if _z76:
		var theme = _z76.get_editor_theme()
		if theme:
			var _n62 = theme.get_font_size("main_size", "EditorFonts")
			if _n62 > 0:
				return _n62
	return 14  

func _q25():
	var _l9 = _b74()

	var _t96 = _l9
	var _o38 = _l9  
	var _c16 = int(_l9 * 1.1)  

	var font_color = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")

	if _o94:
		_o94.add_theme_font_size_override("font_size", _c16)
	if _y98:
		_y98.add_theme_font_size_override("font_size", _t96)
		_y98.add_theme_color_override("font_color", font_color)
	if _c35:
		_c35.add_theme_font_size_override("font_size", _o38)

		_c35.add_theme_color_override("font_color", font_color.darkened(0.2) if _u37 else font_color.darkened(0.15))

func _t97(title: String, message: String, _w20: _x62 = _x62._b49, _c82: float = 3.0):
	var _r12 = title.substr(0, _i3)
	var _s85 = message.substr(0, _u9)
	var _c96 = clampf(_c82, _l74, _v61)

	_x92()
	_z66()
	_q25()

	if _s2:
		_r1(_r12, _s85, _w20)

		if _b19 and is_inside_tree():
			_b19.stop()
			_b19.wait_time = _c96
			_b19.start()
		return

	_r1(_r12, _s85, _w20)

	if _b19:
		_b19.wait_time = _c96
		if is_inside_tree():
			_b19.start()
		else:
			_c31.call_deferred(_c96)

	_d4()

func _c31(_c82: float):
	if _b19 and is_inside_tree():
		_b19.wait_time = _c82
		_b19.start()

func _r1(title: String, message: String, _w20: _x62):
	if _y98:
		_y98.text = title
	if _c35:
		_c35.text = message
	
	match _w20:
		_x62._b49:
			if _o94:
				_o94.text = "✓"
				var _q33 = get_theme_color("success_color", "Editor") if has_theme_color("success_color", "Editor") else Color(0.3, 0.9, 0.3, 1.0)
				_o94.add_theme_color_override("font_color", _q33)
		_x62.ERROR:
			if _o94:
				_o94.text = "✗"
				var _q77 = get_theme_color("error_color", "Editor") if has_theme_color("error_color", "Editor") else Color(0.9, 0.3, 0.3, 1.0)
				_o94.add_theme_color_override("font_color", _q77)
		_x62.WARNING:
			if _o94:
				_o94.text = "⚠"
				var _r37 = get_theme_color("warning_color", "Editor") if has_theme_color("warning_color", "Editor") else Color(0.9, 0.7, 0.2, 1.0)
				_o94.add_theme_color_override("font_color", _r37)
		_x62.INFO:
			if _o94:
				_o94.text = "ℹ"
				var _g75 = get_theme_color("accent_color", "Editor") if has_theme_color("accent_color", "Editor") else Color(0.4, 0.7, 1.0, 1.0)
				_o94.add_theme_color_override("font_color", _g75)

func _d4():
	visible = true
	_s2 = true

	if _w98 and _w98.has_animation_library("default"):
		var _w78 = _w98.get_animation_library("default")
		if _w78.has_animation("slide_in"):
			_w98.play("default/slide_in")
		else:
			modulate.a = 1.0
	else:
		modulate.a = 1.0

func _b60():
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _w98 and _w98.has_animation_library("default"):
		var _w78 = _w98.get_animation_library("default")
		if _w78.has_animation("slide_out"):
			_w98.play("default/slide_out")
		else:
			modulate.a = 0.0
			visible = false
			_s2 = false
	else:
		modulate.a = 0.0
		visible = false
		_s2 = false

func _u100():
	if not _w98:
		return
	
	if not _w98.has_animation_library("default"):
		var _x76 = AnimationLibrary.new()
		_w98.add_animation_library("default", _x76)
	
	var _x76 = _w98.get_animation_library("default")
	
	if not _x76.has_animation("slide_in"):
		var _y4 = Animation.new()
		_y4.length = 0.2

		var _v11 = _y4.add_track(Animation.TYPE_VALUE)
		_y4.track_set_path(_v11, NodePath(".:modulate:a"))
		_y4.track_insert_key(_v11, 0.0, 0.0)
		_y4.track_insert_key(_v11, 0.2, 1.0)

		_x76.add_animation("slide_in", _y4)

	if not _x76.has_animation("slide_out"):
		var _j91 = Animation.new()
		_j91.length = 0.15

		var _x96 = _j91.add_track(Animation.TYPE_VALUE)
		_j91.track_set_path(_x96, NodePath(".:modulate:a"))
		_j91.track_insert_key(_x96, 0.0, 1.0)
		_j91.track_insert_key(_x96, 0.15, 0.0)
		
		_x76.add_animation("slide_out", _j91)
	
	if not _w98.animation_finished.is_connected(_f60):
		_w98.animation_finished.connect(_f60)

func _t22():
	_b60()

func _f60(_p12: String):
	if _p12 == "slide_out":
		visible = false
		_s2 = false

func _b89():
	if _b19:
		_b19.stop()

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false
	_s2 = false
	
func _m66() -> bool:
	return _s2

func _x15(text: String) -> String:
	var _x57 = text.replace("[", "\\[").replace("]", "\\]")
	return _x57.substr(0, 200)

func _u80(title: String, message: String, _c82: float = 3.0):
	_t97(title, message, _x62._b49, _c82)

func _k66(title: String, message: String, _c82: float = 5.0):
	_t97(title, message, _x62.ERROR, _c82)

func _f59(title: String, message: String, _c82: float = 4.0):
	_t97(title, message, _x62.WARNING, _c82)

func _r28(title: String, message: String, _c82: float = 3.0):
	_t97(title, message, _x62.INFO, _c82)

func _v79(function_name: String):
	var _c100 = _x15(function_name)
	_u80("Refactor Undone", "Function '%s' has been restored to its original state" % _c100, 5.0)

func _p19(function_name: String, _p71: String):
	var _c100 = _x15(function_name)
	var _a76 = _x15(_p71)
	_k66("Undo Failed", "Could not undo refactor for '%s': %s" % [_c100, _a76])

func _d56(function_name: String):
	var _c100 = _x15(function_name)
	_f59("No History", "No refactor history available for function '%s'" % _c100)

