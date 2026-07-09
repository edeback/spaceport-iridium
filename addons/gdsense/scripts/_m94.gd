@tool
class_name _b8
extends ConfirmationDialog

signal _v67(function_name: String, original_code: String, file_path: String)

@onready var _z87: Label = %_s100
@onready var _z54: Label = %_v64
@onready var _h14: RichTextLabel = %_h71
@onready var _q85: PanelContainer = $_k8/_d40
@onready var _e59: Button = %_o13
@onready var _q82: Button = %_r5
@onready var _n84: Label = $_k8/_p14
@onready var _d3: Label = $_k8/_d47

var _d28: String = ""
var _x82: String = ""
var _q20: String = ""
var _v98: float = 1.0
var _b58: EditorInterface = null

const _k70 = [
	"if", "elif", "else", "for", "while", "match", "break", "continue", "pass",
	"return", "class", "extends", "is", "as", "self", "super", "func", "signal",
	"const", "var", "static", "enum", "in", "not", "and", "or", "true", "false",
	"null", "export", "onready", "tool", "setget", "breakpoint", "preload", "yield",
	"assert", "remote", "sync", "master", "puppet", "await", "class_name"
]

func _ready():
	if _e59:
		_e59.pressed.connect(_j50)
	if _q82:
		_q82.pressed.connect(_c90)

	canceled.connect(_j50)

	get_ok_button().hide()
	get_cancel_button().hide()

	_j37()
	var _e55 = int(400 * _v98)
	var _a24 = int(200 * _v98)
	min_size = Vector2i(350, 150)
	size = Vector2i(_e55, _a24)

	_a38()

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

func _a38():
	var _u94 = int(18 * _v98)
	var _f80 = int(14 * _v98)
	var _r39 = int(13 * _v98)
	var _h24 = int(14 * _v98)
	var _v63 = int(12 * _v98)

	if _z87:
		_z87.add_theme_font_size_override("font_size", _u94)
	if _z54:
		_z54.add_theme_font_size_override("font_size", _f80)
	if _n84:
		_n84.add_theme_font_size_override("font_size", _f80)
	if _h14:
		_h14.add_theme_font_size_override("normal_font_size", _r39)

		_h14.add_theme_color_override("default_color", Color.WHITE)
	if _d3:
		_d3.add_theme_font_size_override("font_size", _v63)
	if _e59:
		_e59.add_theme_font_size_override("font_size", _h24)
	if _q82:
		_q82.add_theme_font_size_override("font_size", _h24)

	_d90()

func _h21(_l32: EditorInterface) -> void:
	_b58 = _l32

func _d90():
	if not _q85:
		return

	var _q75 = get_theme_color("base_color", "Editor") if has_theme_color("base_color", "Editor") else Color(0.5, 0.5, 0.5)
	var _r36 = _q75.get_luminance() > 0.5

	var bg_color = _q75.darkened(0.08) if _r36 else _q75.lightened(0.08)
	var border_color = _q75.darkened(0.2) if _r36 else _q75.lightened(0.15)

	var _r89 = StyleBoxFlat.new()
	_r89.bg_color = bg_color
	_r89.border_color = border_color
	_r89.corner_radius_top_left = 4
	_r89.corner_radius_top_right = 4
	_r89.corner_radius_bottom_left = 4
	_r89.corner_radius_bottom_right = 4

	var margin = int(8 * _v98)
	_r89.content_margin_left = margin
	_r89.content_margin_right = margin
	_r89.content_margin_top = margin
	_r89.content_margin_bottom = margin

	_r89.border_width_left = 1
	_r89.border_width_right = 1
	_r89.border_width_top = 1
	_r89.border_width_bottom = 1

	_q85.add_theme_stylebox_override("panel", _r89)

func _k29(type: String) -> Color:
	if _b58:
		var _x61 = _b58.get_editor_settings()
		if _x61:
			match type:
				"text": return _x61.get_setting("text_editor/theme/highlighting/text_color")
				"comment": return _x61.get_setting("text_editor/theme/highlighting/comment_color")
				"string": return _x61.get_setting("text_editor/theme/highlighting/string_color")
				"number": return _x61.get_setting("text_editor/theme/highlighting/number_color")
				"keyword": return _x61.get_setting("text_editor/theme/highlighting/keyword_color")
				"class": return _x61.get_setting("text_editor/theme/highlighting/base_type_color")
				"function": return _x61.get_setting("text_editor/theme/highlighting/function_color")
				"symbol": return _x61.get_setting("text_editor/theme/highlighting/symbol_color")

	return get_theme_color("font_color", "Label")

func _m92(code: String) -> String:
	var _d70 = ""
	var _d41 = code.split("\n")

	var _b85 = RegEx.new()
	_b85.compile("\\b(" + "|".join(_k70) + ")\\b")

	var _g4 = RegEx.new()
	_g4.compile("(?<!#)\\b([A-Z][a-zA-Z0-9]*)\\b")

	var _i45 = RegEx.new()
	_i45.compile("\\b([a-z_][a-z0-9_]*)\\s*\\(")

	var _q64 = RegEx.new()
	_q64.compile("(\"[^\"]*\"|'[^']*')")

	var _p15 = RegEx.new()
	_p15.compile("(?<!#)\\b\\d+(\\.\\d+)?\\b")

	for line in _d41:
		if line.strip_edges().is_empty():
			_d70 += "\n"
			continue

		var _y37 = line.find("#")
		var _p72 = line
		var _l13 = ""
		if _y37 != -1:
			_p72 = line.substr(0, _y37)
			_l13 = line.substr(_y37)
			_l13 = "[color=#%s]%s[/color]" % [_k29("comment").to_html(false), _l13]

		_p72 = _q64.sub(_p72, "[color=#%s]$1[/color]" % [_k29("string").to_html(false)], true)

		_p72 = _b85.sub(_p72, "[color=#%s]$1[/color]" % [_k29("keyword").to_html(false)], true)

		_p72 = _g4.sub(_p72, "[color=#%s]$1[/color]" % [_k29("class").to_html(false)], true)

		_p72 = _i45.sub(_p72, "[color=#%s]$1[/color](" % [_k29("function").to_html(false)], true)

		_p72 = _p15.sub(_p72, "[color=#%s]$0[/color]" % [_k29("number").to_html(false)], true)

		_d70 += _p72 + _l13 + "\n"

	return _d70.strip_edges()

func _m14(_i42: _b26._n2, file_path: String, _i46: bool = false):
	if not _i42:
		push_error("UndoConfirmation: No refactor entry provided")
		return

	_d28 = _i42.function_name
	_x82 = _i42.original_code
	_q20 = file_path

	_j37()
	_a38()
	_d90()

	if _z87:
		if _i46:
			_z87.text = "Undo MODIFIED function: %s()" % _i42.function_name
			var _l12 = get_theme_color("warning_color", "Editor") if has_theme_color("warning_color", "Editor") else Color(0.9, 0.7, 0.2)
			_z87.add_theme_color_override("font_color", _l12)
		else:
			_z87.text = "Undo refactor for: %s()" % _i42.function_name
			_z87.remove_theme_color_override("font_color")

	if _z54:
		_z54.text = "Refactored at: %s" % _i42._l34()

	if _h14:
		var _v16 = _k29("text")
		_h14.add_theme_color_override("default_color", _v16)

		var _j9 = _m92(_i42.original_code)
		_h14.text = _j9

		var _q62 = _i42.original_code.count("\n") + 1
		var _w41 = int(16 * _v98)
		var _e86 = int(60 * _v98)
		var _q34 = int(150 * _v98)
		var _t59 = _q62 * _w41
		var _b87 = clamp(_t59, _e86, _q34)
		_h14.custom_minimum_size = Vector2(0, _b87)

	var _e55 = int(450 * _v98)
	var _a24 = int(280 * _v98)
	size = Vector2i(_e55, _a24)

	popup_centered()

func _j50():
	hide()

func _c90():
	_v67.emit(_d28, _x82, _q20)
	hide()

func _c88():
	_j50()

func _a83() -> String:
	return _d28

func _c9() -> String:
	return _x82

func get_file_path() -> String:
	return _q20

