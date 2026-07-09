@tool
class_name _t34
extends ConfirmationDialog

signal _s40(function_name: String, original_code: String, file_path: String)

@onready var _m73: Label = %_k74
@onready var _i1: Label = %_f90
@onready var _c12: RichTextLabel = %_y38
@onready var _f3: PanelContainer = $_v61/_x49
@onready var _s94: Button = %_f33
@onready var _q16: Button = %_a27
@onready var _j98: Label = $_v61/_t12
@onready var _y3: Label = $_v61/_o92

var _n78: String = ""
var _n68: String = ""
var _f54: String = ""
var _g83: float = 1.0
var _q86: EditorInterface = null

const _y51 = [
	"if", "elif", "else", "for", "while", "match", "break", "continue", "pass",
	"return", "class", "extends", "is", "as", "self", "super", "func", "signal",
	"const", "var", "static", "enum", "in", "not", "and", "or", "true", "false",
	"null", "export", "onready", "tool", "setget", "breakpoint", "preload", "yield",
	"assert", "remote", "sync", "master", "puppet", "await", "class_name"
]

func _ready():
	if _s94:
		_s94.pressed.connect(_s47)
	if _q16:
		_q16.pressed.connect(_y90)

	canceled.connect(_s47)

	get_ok_button().hide()
	get_cancel_button().hide()

	_p74()
	var _y34 = int(400 * _g83)
	var _g64 = int(200 * _g83)
	min_size = Vector2i(350, 150)
	size = Vector2i(_y34, _g64)

	_h45()

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

func _h45():
	var _v91 = int(18 * _g83)
	var _c13 = int(14 * _g83)
	var _e48 = int(13 * _g83)
	var _b3 = int(14 * _g83)
	var _t94 = int(12 * _g83)

	if _m73:
		_m73.add_theme_font_size_override("font_size", _v91)
	if _i1:
		_i1.add_theme_font_size_override("font_size", _c13)
	if _j98:
		_j98.add_theme_font_size_override("font_size", _c13)
	if _c12:
		_c12.add_theme_font_size_override("normal_font_size", _e48)

		_c12.add_theme_color_override("default_color", Color.WHITE)
	if _y3:
		_y3.add_theme_font_size_override("font_size", _t94)
	if _s94:
		_s94.add_theme_font_size_override("font_size", _b3)
	if _q16:
		_q16.add_theme_font_size_override("font_size", _b3)

	_x41()

func _k94(_p32: EditorInterface) -> void:
	_q86 = _p32

func _x41():
	if not _f3:
		return

	var _t29 = get_theme_color("base_color", "Editor") if has_theme_color("base_color", "Editor") else Color(0.5, 0.5, 0.5)
	var _r46 = _t29.get_luminance() > 0.5

	var bg_color = _t29.darkened(0.08) if _r46 else _t29.lightened(0.08)
	var border_color = _t29.darkened(0.2) if _r46 else _t29.lightened(0.15)

	var _x67 = StyleBoxFlat.new()
	_x67.bg_color = bg_color
	_x67.border_color = border_color
	_x67.corner_radius_top_left = 4
	_x67.corner_radius_top_right = 4
	_x67.corner_radius_bottom_left = 4
	_x67.corner_radius_bottom_right = 4

	var margin = int(8 * _g83)
	_x67.content_margin_left = margin
	_x67.content_margin_right = margin
	_x67.content_margin_top = margin
	_x67.content_margin_bottom = margin

	_x67.border_width_left = 1
	_x67.border_width_right = 1
	_x67.border_width_top = 1
	_x67.border_width_bottom = 1

	_f3.add_theme_stylebox_override("panel", _x67)

func _z45(type: String) -> Color:
	if _q86:
		var _e45 = _q86.get_editor_settings()
		if _e45:
			match type:
				"text": return _e45.get_setting("text_editor/theme/highlighting/text_color")
				"comment": return _e45.get_setting("text_editor/theme/highlighting/comment_color")
				"string": return _e45.get_setting("text_editor/theme/highlighting/string_color")
				"number": return _e45.get_setting("text_editor/theme/highlighting/number_color")
				"keyword": return _e45.get_setting("text_editor/theme/highlighting/keyword_color")
				"class": return _e45.get_setting("text_editor/theme/highlighting/base_type_color")
				"function": return _e45.get_setting("text_editor/theme/highlighting/function_color")
				"symbol": return _e45.get_setting("text_editor/theme/highlighting/symbol_color")

	return get_theme_color("font_color", "Label")

func _r67(code: String) -> String:
	var _b83 = ""
	var _m12 = code.split("\n")

	var _n3 = RegEx.new()
	_n3.compile("\\b(" + "|".join(_y51) + ")\\b")

	var _h73 = RegEx.new()
	_h73.compile("(?<!#)\\b([A-Z][a-zA-Z0-9]*)\\b")

	var _n84 = RegEx.new()
	_n84.compile("\\b([a-z_][a-z0-9_]*)\\s*\\(")

	var _h75 = RegEx.new()
	_h75.compile("(\"[^\"]*\"|'[^']*')")

	var _d64 = RegEx.new()
	_d64.compile("(?<!#)\\b\\d+(\\.\\d+)?\\b")

	for line in _m12:
		if line.strip_edges().is_empty():
			_b83 += "\n"
			continue

		var _f27 = line.find("#")
		var _m45 = line
		var _q43 = ""
		if _f27 != -1:
			_m45 = line.substr(0, _f27)
			_q43 = line.substr(_f27)
			_q43 = "[color=#%s]%s[/color]" % [_z45("comment").to_html(false), _q43]

		_m45 = _h75.sub(_m45, "[color=#%s]$1[/color]" % [_z45("string").to_html(false)], true)

		_m45 = _n3.sub(_m45, "[color=#%s]$1[/color]" % [_z45("keyword").to_html(false)], true)

		_m45 = _h73.sub(_m45, "[color=#%s]$1[/color]" % [_z45("class").to_html(false)], true)

		_m45 = _n84.sub(_m45, "[color=#%s]$1[/color](" % [_z45("function").to_html(false)], true)

		_m45 = _d64.sub(_m45, "[color=#%s]$0[/color]" % [_z45("number").to_html(false)], true)

		_b83 += _m45 + _q43 + "\n"

	return _b83.strip_edges()

func _m52(_d79: _w99._u22, file_path: String, _t91: bool = false):
	if not _d79:
		push_error("UndoConfirmation: No refactor entry provided")
		return

	_n78 = _d79.function_name
	_n68 = _d79.original_code
	_f54 = file_path

	_p74()
	_h45()
	_x41()

	if _m73:
		if _t91:
			_m73.text = "Undo MODIFIED function: %s()" % _d79.function_name
			var _q36 = get_theme_color("warning_color", "Editor") if has_theme_color("warning_color", "Editor") else Color(0.9, 0.7, 0.2)
			_m73.add_theme_color_override("font_color", _q36)
		else:
			_m73.text = "Undo refactor for: %s()" % _d79.function_name
			_m73.remove_theme_color_override("font_color")

	if _i1:
		_i1.text = "Refactored at: %s" % _d79._s57()

	if _c12:
		var _m44 = _z45("text")
		_c12.add_theme_color_override("default_color", _m44)

		var _x87 = _r67(_d79.original_code)
		_c12.text = _x87

		var _e63 = _d79.original_code.count("\n") + 1
		var _e18 = int(16 * _g83)
		var _z36 = int(60 * _g83)
		var _z59 = int(150 * _g83)
		var _v67 = _e63 * _e18
		var _z86 = clamp(_v67, _z36, _z59)
		_c12.custom_minimum_size = Vector2(0, _z86)

	var _y34 = int(450 * _g83)
	var _g64 = int(280 * _g83)
	size = Vector2i(_y34, _g64)

	popup_centered()

func _s47():
	hide()

func _y90():
	_s40.emit(_n78, _n68, _f54)
	hide()

func _d39():
	_s47()

func _f73() -> String:
	return _n78

func _z39() -> String:
	return _n68

func get_file_path() -> String:
	return _f54

