@tool
class_name _l32
extends ConfirmationDialog
signal _k28(function_name: String, original_code: String, file_path: String)
@onready var _h37: Label = %_q27
@onready var _m15: Label = %_j15
@onready var _v62: RichTextLabel = %_x45
@onready var _v40: PanelContainer = $_p53/_k94
@onready var _y34: Button = %_t98
@onready var _s21: Button = %_s89
@onready var _w17: Label = $_p53/_g62
@onready var _z77: Label = $_p53/_o36
var _x97: String = ""
var _i98: String = ""
var _o13: String = ""
var _x27: float = 1.0
var _b72: EditorInterface = null
const _u46 = [
	"if", "elif", "else", "for", "while", "match", "break", "continue", "pass",
	"return", "class", "extends", "is", "as", "self", "super", "func", "signal",
	"const", "var", "static", "enum", "in", "not", "and", "or", "true", "false",
	"null", "export", "onready", "tool", "setget", "breakpoint", "preload", "yield",
	"assert", "remote", "sync", "master", "puppet", "await", "class_name"
]
func _ready():
	if _y34:
		_y34.pressed.connect(_a85)
	if _s21:
		_s21.pressed.connect(_z44)
	canceled.connect(_a85)
	get_ok_button().hide()
	get_cancel_button().hide()
	_n1()
	var _p96 = int(400 * _x27)
	var _g15 = int(200 * _x27)
	min_size = Vector2i(350, 150)
	size = Vector2i(_p96, _g15)
	_x81()
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
func _x81():
	var _w24 = int(18 * _x27)
	var _y31 = int(14 * _x27)
	var _p88 = int(13 * _x27)
	var _o29 = int(14 * _x27)
	var _k25 = int(12 * _x27)
	if _h37:
		_h37.add_theme_font_size_override("font_size", _w24)
	if _m15:
		_m15.add_theme_font_size_override("font_size", _y31)
	if _w17:
		_w17.add_theme_font_size_override("font_size", _y31)
	if _v62:
		_v62.add_theme_font_size_override("normal_font_size", _p88)
		_v62.add_theme_color_override("default_color", Color.WHITE)
	if _z77:
		_z77.add_theme_font_size_override("font_size", _k25)
	if _y34:
		_y34.add_theme_font_size_override("font_size", _o29)
	if _s21:
		_s21.add_theme_font_size_override("font_size", _o29)
	_l86()
func _f94(_j50: EditorInterface) -> void:
	_b72 = _j50
func _l86():
	if not _v40:
		return
	var _i13 = get_theme_color("base_color", "Editor") if has_theme_color("base_color", "Editor") else Color(0.5, 0.5, 0.5)
	var _m32 = _i13.get_luminance() > 0.5
	var bg_color = _i13.darkened(0.08) if _m32 else _i13.lightened(0.08)
	var border_color = _i13.darkened(0.2) if _m32 else _i13.lightened(0.15)
	var _p1 = StyleBoxFlat.new()
	_p1.bg_color = bg_color
	_p1.border_color = border_color
	_p1.corner_radius_top_left = 4
	_p1.corner_radius_top_right = 4
	_p1.corner_radius_bottom_left = 4
	_p1.corner_radius_bottom_right = 4
	var margin = int(8 * _x27)
	_p1.content_margin_left = margin
	_p1.content_margin_right = margin
	_p1.content_margin_top = margin
	_p1.content_margin_bottom = margin
	_p1.border_width_left = 1
	_p1.border_width_right = 1
	_p1.border_width_top = 1
	_p1.border_width_bottom = 1
	_v40.add_theme_stylebox_override("panel", _p1)
func _p24(type: String) -> Color:
	if _b72:
		var _d93 = _b72.get_editor_settings()
		if _d93:
			match type:
				"text": return _d93.get_setting("text_editor/theme/highlighting/text_color")
				"comment": return _d93.get_setting("text_editor/theme/highlighting/comment_color")
				"string": return _d93.get_setting("text_editor/theme/highlighting/string_color")
				"number": return _d93.get_setting("text_editor/theme/highlighting/number_color")
				"keyword": return _d93.get_setting("text_editor/theme/highlighting/keyword_color")
				"class": return _d93.get_setting("text_editor/theme/highlighting/base_type_color")
				"function": return _d93.get_setting("text_editor/theme/highlighting/function_color")
				"symbol": return _d93.get_setting("text_editor/theme/highlighting/symbol_color")
	return get_theme_color("font_color", "Label")
func _k22(code: String) -> String:
	var _s97 = ""
	var _a62 = code.split("\n")
	var _o38 = RegEx.new()
	_o38.compile("\\b(" + "|".join(_u46) + ")\\b")
	var _m62 = RegEx.new()
	_m62.compile("(?<!#)\\b([A-Z][a-zA-Z0-9]*)\\b")
	var _j70 = RegEx.new()
	_j70.compile("\\b([a-z_][a-z0-9_]*)\\s*\\(")
	var _e57 = RegEx.new()
	_e57.compile("(\"[^\"]*\"|'[^']*')")
	var _y41 = RegEx.new()
	_y41.compile("(?<!#)\\b\\d+(\\.\\d+)?\\b")
	for line in _a62:
		if line.strip_edges().is_empty():
			_s97 += "\n"
			continue
		var _e18 = line.find("#")
		var _r98 = line
		var _c20 = ""
		if _e18 != -1:
			_r98 = line.substr(0, _e18)
			_c20 = line.substr(_e18)
			_c20 = "[color=#%s]%s[/color]" % [_p24("comment").to_html(false), _c20]
		_r98 = _e57.sub(_r98, "[color=#%s]$1[/color]" % [_p24("string").to_html(false)], true)
		_r98 = _o38.sub(_r98, "[color=#%s]$1[/color]" % [_p24("keyword").to_html(false)], true)
		_r98 = _m62.sub(_r98, "[color=#%s]$1[/color]" % [_p24("class").to_html(false)], true)
		_r98 = _j70.sub(_r98, "[color=#%s]$1[/color](" % [_p24("function").to_html(false)], true)
		_r98 = _y41.sub(_r98, "[color=#%s]$0[/color]" % [_p24("number").to_html(false)], true)
		_s97 += _r98 + _c20 + "\n"
	return _s97.strip_edges()
func _t47(_l83: _z30._n40, file_path: String, _w36: bool = false):
	if not _l83:
		push_error("UndoConfirmation: No refactor entry provided")
		return
	_x97 = _l83.function_name
	_i98 = _l83.original_code
	_o13 = file_path
	_n1()
	_x81()
	_l86()
	if _h37:
		if _w36:
			_h37.text = "Undo MODIFIED function: %s()" % _l83.function_name
			var _e49 = get_theme_color("warning_color", "Editor") if has_theme_color("warning_color", "Editor") else Color(0.9, 0.7, 0.2)
			_h37.add_theme_color_override("font_color", _e49)
		else:
			_h37.text = "Undo refactor for: %s()" % _l83.function_name
			_h37.remove_theme_color_override("font_color")
	if _m15:
		_m15.text = "Refactored at: %s" % _l83._s37()
	if _v62:
		var _m44 = _p24("text")
		_v62.add_theme_color_override("default_color", _m44)
		var _q71 = _k22(_l83.original_code)
		_v62.text = _q71
		var _d99 = _l83.original_code.count("\n") + 1
		var _g71 = int(16 * _x27)
		var _q79 = int(60 * _x27)
		var _f47 = int(150 * _x27)
		var _x59 = _d99 * _g71
		var _k43 = clamp(_x59, _q79, _f47)
		_v62.custom_minimum_size = Vector2(0, _k43)
	var _p96 = int(450 * _x27)
	var _g15 = int(280 * _x27)
	size = Vector2i(_p96, _g15)
	popup_centered()
func _a85():
	hide()
func _z44():
	_k28.emit(_x97, _i98, _o13)
	hide()
func _q45():
	_a85()
func _v65() -> String:
	return _x97
func _w81() -> String:
	return _i98
func get_file_path() -> String:
	return _o13
