@tool
class_name _a28
extends ConfirmationDialog
signal _s93(function_name: String, original_code: String, file_path: String)
@onready var _w52: Label = %_p51
@onready var _d73: Label = %_x90
@onready var _i62: RichTextLabel = %_r54
@onready var _p75: PanelContainer = $_m63/_i4
@onready var _f38: Button = %_g71
@onready var _j39: Button = %_d31
@onready var _q95: Label = $_m63/_k59
@onready var _z5: Label = $_m63/_g64
var _p38: String = ""
var _p26: String = ""
var _c53: String = ""
var _t35: float = 1.0
var _f21: EditorInterface = null
const _e96 = [
	"if", "elif", "else", "for", "while", "match", "break", "continue", "pass",
	"return", "class", "extends", "is", "as", "self", "super", "func", "signal",
	"const", "var", "static", "enum", "in", "not", "and", "or", "true", "false",
	"null", "export", "onready", "tool", "setget", "breakpoint", "preload", "yield",
	"assert", "remote", "sync", "master", "puppet", "await", "class_name"
]
func _ready():
	if _f38:
		_f38.pressed.connect(_b50)
	if _j39:
		_j39.pressed.connect(_s92)
	canceled.connect(_b50)
	get_ok_button().hide()
	get_cancel_button().hide()
	_q6()
	var _q16 = int(400 * _t35)
	var _s20 = int(200 * _t35)
	min_size = Vector2i(350, 150)
	size = Vector2i(_q16, _s20)
	_o19()
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
func _o19():
	var _x29 = int(18 * _t35)
	var _c72 = int(14 * _t35)
	var _e25 = int(13 * _t35)
	var _s55 = int(14 * _t35)
	var _w20 = int(12 * _t35)
	if _w52:
		_w52.add_theme_font_size_override("font_size", _x29)
	if _d73:
		_d73.add_theme_font_size_override("font_size", _c72)
	if _q95:
		_q95.add_theme_font_size_override("font_size", _c72)
	if _i62:
		_i62.add_theme_font_size_override("normal_font_size", _e25)
		_i62.add_theme_color_override("default_color", Color.WHITE)
	if _z5:
		_z5.add_theme_font_size_override("font_size", _w20)
	if _f38:
		_f38.add_theme_font_size_override("font_size", _s55)
	if _j39:
		_j39.add_theme_font_size_override("font_size", _s55)
	_i87()
func _o81(_c27: EditorInterface) -> void:
	_f21 = _c27
func _i87():
	if not _p75:
		return
	var _f9 = get_theme_color("base_color", "Editor") if has_theme_color("base_color", "Editor") else Color(0.5, 0.5, 0.5)
	var _b35 = _f9.get_luminance() > 0.5
	var bg_color = _f9.darkened(0.08) if _b35 else _f9.lightened(0.08)
	var border_color = _f9.darkened(0.2) if _b35 else _f9.lightened(0.15)
	var _u49 = StyleBoxFlat.new()
	_u49.bg_color = bg_color
	_u49.border_color = border_color
	_u49.corner_radius_top_left = 4
	_u49.corner_radius_top_right = 4
	_u49.corner_radius_bottom_left = 4
	_u49.corner_radius_bottom_right = 4
	var margin = int(8 * _t35)
	_u49.content_margin_left = margin
	_u49.content_margin_right = margin
	_u49.content_margin_top = margin
	_u49.content_margin_bottom = margin
	_u49.border_width_left = 1
	_u49.border_width_right = 1
	_u49.border_width_top = 1
	_u49.border_width_bottom = 1
	_p75.add_theme_stylebox_override("panel", _u49)
func _y60(type: String) -> Color:
	if _f21:
		var _f13 = _f21.get_editor_settings()
		if _f13:
			match type:
				"text": return _f13.get_setting("text_editor/theme/highlighting/text_color")
				"comment": return _f13.get_setting("text_editor/theme/highlighting/comment_color")
				"string": return _f13.get_setting("text_editor/theme/highlighting/string_color")
				"number": return _f13.get_setting("text_editor/theme/highlighting/number_color")
				"keyword": return _f13.get_setting("text_editor/theme/highlighting/keyword_color")
				"class": return _f13.get_setting("text_editor/theme/highlighting/base_type_color")
				"function": return _f13.get_setting("text_editor/theme/highlighting/function_color")
				"symbol": return _f13.get_setting("text_editor/theme/highlighting/symbol_color")
	return get_theme_color("font_color", "Label")
func _s57(code: String) -> String:
	var _d45 = ""
	var _t70 = code.split("\n")
	var _q10 = RegEx.new()
	_q10.compile("\\b(" + "|".join(_e96) + ")\\b")
	var _n94 = RegEx.new()
	_n94.compile("(?<!#)\\b([A-Z][a-zA-Z0-9]*)\\b")
	var _q3 = RegEx.new()
	_q3.compile("\\b([a-z_][a-z0-9_]*)\\s*\\(")
	var _c51 = RegEx.new()
	_c51.compile("(\"[^\"]*\"|'[^']*')")
	var _g67 = RegEx.new()
	_g67.compile("(?<!#)\\b\\d+(\\.\\d+)?\\b")
	for line in _t70:
		if line.strip_edges().is_empty():
			_d45 += "\n"
			continue
		var _h23 = line.find("#")
		var _j8 = line
		var _y19 = ""
		if _h23 != -1:
			_j8 = line.substr(0, _h23)
			_y19 = line.substr(_h23)
			_y19 = "[color=#%s]%s[/color]" % [_y60("comment").to_html(false), _y19]
		_j8 = _c51.sub(_j8, "[color=#%s]$1[/color]" % [_y60("string").to_html(false)], true)
		_j8 = _q10.sub(_j8, "[color=#%s]$1[/color]" % [_y60("keyword").to_html(false)], true)
		_j8 = _n94.sub(_j8, "[color=#%s]$1[/color]" % [_y60("class").to_html(false)], true)
		_j8 = _q3.sub(_j8, "[color=#%s]$1[/color](" % [_y60("function").to_html(false)], true)
		_j8 = _g67.sub(_j8, "[color=#%s]$0[/color]" % [_y60("number").to_html(false)], true)
		_d45 += _j8 + _y19 + "\n"
	return _d45.strip_edges()
func _c20(_a56: _z98._c40, file_path: String, _i75: bool = false):
	if not _a56:
		push_error("UndoConfirmation: No refactor entry provided")
		return
	_p38 = _a56.function_name
	_p26 = _a56.original_code
	_c53 = file_path
	_q6()
	_o19()
	_i87()
	if _w52:
		if _i75:
			_w52.text = "Undo MODIFIED function: %s()" % _a56.function_name
			var _z36 = get_theme_color("warning_color", "Editor") if has_theme_color("warning_color", "Editor") else Color(0.9, 0.7, 0.2)
			_w52.add_theme_color_override("font_color", _z36)
		else:
			_w52.text = "Undo refactor for: %s()" % _a56.function_name
			_w52.remove_theme_color_override("font_color")
	if _d73:
		_d73.text = "Refactored at: %s" % _a56._q22()
	if _i62:
		var _q40 = _y60("text")
		_i62.add_theme_color_override("default_color", _q40)
		var _h79 = _s57(_a56.original_code)
		_i62.text = _h79
		var _j12 = _a56.original_code.count("\n") + 1
		var _s88 = int(16 * _t35)
		var _y48 = int(60 * _t35)
		var _i23 = int(150 * _t35)
		var _r96 = _j12 * _s88
		var _q91 = clamp(_r96, _y48, _i23)
		_i62.custom_minimum_size = Vector2(0, _q91)
	var _q16 = int(450 * _t35)
	var _s20 = int(280 * _t35)
	size = Vector2i(_q16, _s20)
	popup_centered()
func _b50():
	hide()
func _s92():
	_s93.emit(_p38, _p26, _c53)
	hide()
func _j55():
	_b50()
func _q73() -> String:
	return _p38
func _l54() -> String:
	return _p26
func get_file_path() -> String:
	return _c53
