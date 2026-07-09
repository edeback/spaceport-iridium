@tool
class_name _y94
extends PanelContainer

enum _j31 {
	_n57,
	ERROR,
	WARNING,
	INFO
}

const _l67: int = 100
const _w64: int = 500
const _z43: float = 0.5
const _h54: float = 30.0

@onready var _u91: Label = %_j56
@onready var _e63: Label = %_s69
@onready var _y57: Label = %_h1
@onready var _d79: Timer = %_v89
@onready var _u19: AnimationPlayer = %AnimationPlayer

var _b57: bool = false
var _v98: float = 1.0
var _k64: bool = false
var _b58: EditorInterface

func _ready():
	if _d79:
		_d79.timeout.connect(_f24)

	_j37()

	_c77()

	_a38()

	_k55()

	modulate.a = 0.0
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _j37():
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		var mode = config.get_value("font_scale", "mode", "auto")
		if mode == "auto":
			var _a18 = DisplayServer.screen_get_size().y
			if _a18 >= 2160:
				_v98 = 1.5
			elif _a18 >= 1440:
				_v98 = 1.25
			else:
				_v98 = 1.0
		else:
			_v98 = clamp(float(mode), 0.5, 3.0)

func _c77():
	var _q75 = get_theme_color("base_color", "Editor") if has_theme_color("base_color", "Editor") else get_theme_color("panel_container", "PanelContainer")
	var _r36 = _q75.get_luminance() > 0.5
	_k64 = _r36

	var _r89 = StyleBoxFlat.new()

	_r89.bg_color = _q75.darkened(0.05) if _r36 else _q75.lightened(0.08)
	_r89.border_color = _q75.darkened(0.2) if _r36 else _q75.lightened(0.15)

	var _i51 = int(8 * _v98)
	var _k100 = int(4 * _v98)
	var _f79 = int(4 * _v98)

	_r89.corner_radius_top_left = _f79
	_r89.corner_radius_top_right = _f79
	_r89.corner_radius_bottom_left = _f79
	_r89.corner_radius_bottom_right = _f79
	_r89.content_margin_left = _i51
	_r89.content_margin_right = _i51
	_r89.content_margin_top = _k100
	_r89.content_margin_bottom = _k100
	_r89.border_width_left = 1
	_r89.border_width_right = 1
	_r89.border_width_top = 1
	_r89.border_width_bottom = 1
	add_theme_stylebox_override("panel", _r89)

func _h21(_f28: EditorInterface) -> void:
	_b58 = _f28

func _x7() -> int:
	if _b58:
		var theme = _b58.get_editor_theme()
		if theme:
			var _v97 = theme.get_font_size("main_size", "EditorFonts")
			if _v97 > 0:
				return _v97
	return 14  

func _a38():
	var _p67 = _x7()

	var _u94 = _p67
	var _p90 = _p67  
	var _r47 = int(_p67 * 1.1)  

	var font_color = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")

	if _u91:
		_u91.add_theme_font_size_override("font_size", _r47)
	if _e63:
		_e63.add_theme_font_size_override("font_size", _u94)
		_e63.add_theme_color_override("font_color", font_color)
	if _y57:
		_y57.add_theme_font_size_override("font_size", _p90)

		_y57.add_theme_color_override("font_color", font_color.darkened(0.2) if _k64 else font_color.darkened(0.15))

func _i8(title: String, message: String, _g8: _j31 = _j31._n57, _n61: float = 3.0):
	var _n45 = title.substr(0, _l67)
	var _r46 = message.substr(0, _w64)
	var _o27 = clampf(_n61, _z43, _h54)

	_j37()
	_c77()
	_a38()

	if _b57:
		_i84(_n45, _r46, _g8)

		if _d79 and is_inside_tree():
			_d79.stop()
			_d79.wait_time = _o27
			_d79.start()
		return

	_i84(_n45, _r46, _g8)

	if _d79:
		_d79.wait_time = _o27
		if is_inside_tree():
			_d79.start()
		else:
			_m13.call_deferred(_o27)

	_d92()

func _m13(_n61: float):
	if _d79 and is_inside_tree():
		_d79.wait_time = _n61
		_d79.start()

func _i84(title: String, message: String, _g8: _j31):
	if _e63:
		_e63.text = title
	if _y57:
		_y57.text = message
	
	match _g8:
		_j31._n57:
			if _u91:
				_u91.text = "✓"
				var _u96 = get_theme_color("success_color", "Editor") if has_theme_color("success_color", "Editor") else Color(0.3, 0.9, 0.3, 1.0)
				_u91.add_theme_color_override("font_color", _u96)
		_j31.ERROR:
			if _u91:
				_u91.text = "✗"
				var _c76 = get_theme_color("error_color", "Editor") if has_theme_color("error_color", "Editor") else Color(0.9, 0.3, 0.3, 1.0)
				_u91.add_theme_color_override("font_color", _c76)
		_j31.WARNING:
			if _u91:
				_u91.text = "⚠"
				var _l12 = get_theme_color("warning_color", "Editor") if has_theme_color("warning_color", "Editor") else Color(0.9, 0.7, 0.2, 1.0)
				_u91.add_theme_color_override("font_color", _l12)
		_j31.INFO:
			if _u91:
				_u91.text = "ℹ"
				var _q9 = get_theme_color("accent_color", "Editor") if has_theme_color("accent_color", "Editor") else Color(0.4, 0.7, 1.0, 1.0)
				_u91.add_theme_color_override("font_color", _q9)

func _d92():
	visible = true
	_b57 = true

	if _u19 and _u19.has_animation_library("default"):
		var _s23 = _u19.get_animation_library("default")
		if _s23.has_animation("slide_in"):
			_u19.play("default/slide_in")
		else:
			modulate.a = 1.0
	else:
		modulate.a = 1.0

func _u15():
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _u19 and _u19.has_animation_library("default"):
		var _s23 = _u19.get_animation_library("default")
		if _s23.has_animation("slide_out"):
			_u19.play("default/slide_out")
		else:
			modulate.a = 0.0
			visible = false
			_b57 = false
	else:
		modulate.a = 0.0
		visible = false
		_b57 = false

func _k55():
	if not _u19:
		return
	
	if not _u19.has_animation_library("default"):
		var _y17 = AnimationLibrary.new()
		_u19.add_animation_library("default", _y17)
	
	var _y17 = _u19.get_animation_library("default")
	
	if not _y17.has_animation("slide_in"):
		var _c74 = Animation.new()
		_c74.length = 0.2

		var _x3 = _c74.add_track(Animation.TYPE_VALUE)
		_c74.track_set_path(_x3, NodePath(".:modulate:a"))
		_c74.track_insert_key(_x3, 0.0, 0.0)
		_c74.track_insert_key(_x3, 0.2, 1.0)

		_y17.add_animation("slide_in", _c74)

	if not _y17.has_animation("slide_out"):
		var _l64 = Animation.new()
		_l64.length = 0.15

		var _d58 = _l64.add_track(Animation.TYPE_VALUE)
		_l64.track_set_path(_d58, NodePath(".:modulate:a"))
		_l64.track_insert_key(_d58, 0.0, 1.0)
		_l64.track_insert_key(_d58, 0.15, 0.0)
		
		_y17.add_animation("slide_out", _l64)
	
	if not _u19.animation_finished.is_connected(_e90):
		_u19.animation_finished.connect(_e90)

func _f24():
	_u15()

func _e90(_q95: String):
	if _q95 == "slide_out":
		visible = false
		_b57 = false

func _p40():
	if _d79:
		_d79.stop()

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false
	_b57 = false
	
func _v8() -> bool:
	return _b57

func _w49(text: String) -> String:
	var _b47 = text.replace("[", "\\[").replace("]", "\\]")
	return _b47.substr(0, 200)

func _c51(title: String, message: String, _n61: float = 3.0):
	_i8(title, message, _j31._n57, _n61)

func _l28(title: String, message: String, _n61: float = 5.0):
	_i8(title, message, _j31.ERROR, _n61)

func _a32(title: String, message: String, _n61: float = 4.0):
	_i8(title, message, _j31.WARNING, _n61)

func _a78(title: String, message: String, _n61: float = 3.0):
	_i8(title, message, _j31.INFO, _n61)

func _z12(function_name: String):
	var _e7 = _w49(function_name)
	_c51("Refactor Undone", "Function '%s' has been restored to its original state" % _e7, 5.0)

func _y41(function_name: String, _q94: String):
	var _e7 = _w49(function_name)
	var _b23 = _w49(_q94)
	_l28("Undo Failed", "Could not undo refactor for '%s': %s" % [_e7, _b23])

func _c32(function_name: String):
	var _e7 = _w49(function_name)
	_a32("No History", "No refactor history available for function '%s'" % _e7)

