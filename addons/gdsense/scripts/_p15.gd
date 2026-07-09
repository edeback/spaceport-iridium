@tool
class_name _a88
extends ConfirmationDialog
signal _u90(function_name: String, original_code: String, file_path: String)
@onready var _i49: Label = %_o26
@onready var _k96: Label = %_y59
@onready var _g57: RichTextLabel = %_t52
@onready var _f78: PanelContainer = $_n68/_z86
@onready var _c21: Button = %_t20
@onready var _w32: Button = %_n33
@onready var _v5: Label = $_n68/_x32
@onready var _l18: Label = $_n68/_u13
var _b61: String = ""
var _y34: String = ""
var _k50: String = ""
var _v32: float = 1.0
var _r15: EditorInterface = null
const _q49 = [
	"if", "elif", "else", "for", "while", "match", "break", "continue", "pass",
	"return", "class", "extends", "is", "as", "self", "super", "func", "signal",
	"const", "var", "static", "enum", "in", "not", "and", "or", "true", "false",
	"null", "export", "onready", "tool", "setget", "breakpoint", "preload", "yield",
	"assert", "remote", "sync", "master", "puppet", "await", "class_name"
]
func _ready():
	if _c21:
		_c21.pressed.connect(_v71)
	if _w32:
		_w32.pressed.connect(_s38)
	canceled.connect(_v71)
	get_ok_button().hide()
	get_cancel_button().hide()
	_k57()
	var _h9 = int(400 * _v32)
	var _u54 = int(200 * _v32)
	min_size = Vector2i(350, 150)
	size = Vector2i(_h9, _u54)
	_j28()
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
func _j28():
	var _u25 = int(18 * _v32)
	var _l38 = int(14 * _v32)
	var _d35 = int(13 * _v32)
	var _b49 = int(14 * _v32)
	var _c3 = int(12 * _v32)
	if _i49:
		_i49.add_theme_font_size_override("font_size", _u25)
	if _k96:
		_k96.add_theme_font_size_override("font_size", _l38)
	if _v5:
		_v5.add_theme_font_size_override("font_size", _l38)
	if _g57:
		_g57.add_theme_font_size_override("normal_font_size", _d35)
		_g57.add_theme_color_override("default_color", Color.WHITE)
	if _l18:
		_l18.add_theme_font_size_override("font_size", _c3)
	if _c21:
		_c21.add_theme_font_size_override("font_size", _b49)
	if _w32:
		_w32.add_theme_font_size_override("font_size", _b49)
	_q17()
func _r95(_z81: EditorInterface) -> void:
	_r15 = _z81
func _q17():
	if not _f78:
		return
	var _v22 = get_theme_color("base_color", "Editor") if has_theme_color("base_color", "Editor") else Color(0.5, 0.5, 0.5)
	var _b21 = _v22.get_luminance() > 0.5
	var bg_color = _v22.darkened(0.08) if _b21 else _v22.lightened(0.08)
	var border_color = _v22.darkened(0.2) if _b21 else _v22.lightened(0.15)
	var _c4 = StyleBoxFlat.new()
	_c4.bg_color = bg_color
	_c4.border_color = border_color
	_c4.corner_radius_top_left = 4
	_c4.corner_radius_top_right = 4
	_c4.corner_radius_bottom_left = 4
	_c4.corner_radius_bottom_right = 4
	var margin = int(8 * _v32)
	_c4.content_margin_left = margin
	_c4.content_margin_right = margin
	_c4.content_margin_top = margin
	_c4.content_margin_bottom = margin
	_c4.border_width_left = 1
	_c4.border_width_right = 1
	_c4.border_width_top = 1
	_c4.border_width_bottom = 1
	_f78.add_theme_stylebox_override("panel", _c4)
func _q60(type: String) -> Color:
	if _r15:
		var _a74 = _r15.get_editor_settings()
		if _a74:
			match type:
				"text": return _a74.get_setting("text_editor/theme/highlighting/text_color")
				"comment": return _a74.get_setting("text_editor/theme/highlighting/comment_color")
				"string": return _a74.get_setting("text_editor/theme/highlighting/string_color")
				"number": return _a74.get_setting("text_editor/theme/highlighting/number_color")
				"keyword": return _a74.get_setting("text_editor/theme/highlighting/keyword_color")
				"class": return _a74.get_setting("text_editor/theme/highlighting/base_type_color")
				"function": return _a74.get_setting("text_editor/theme/highlighting/function_color")
				"symbol": return _a74.get_setting("text_editor/theme/highlighting/symbol_color")
	return get_theme_color("font_color", "Label")
func _d64(code: String) -> String:
	var _p60 = ""
	var _p91 = code.split("\n")
	var _z57 = RegEx.new()
	_z57.compile("\\b(" + "|".join(_q49) + ")\\b")
	var _x86 = RegEx.new()
	_x86.compile("(?<!#)\\b([A-Z][a-zA-Z0-9]*)\\b")
	var _j39 = RegEx.new()
	_j39.compile("\\b([a-z_][a-z0-9_]*)\\s*\\(")
	var _h45 = RegEx.new()
	_h45.compile("(\"[^\"]*\"|'[^']*')")
	var _r59 = RegEx.new()
	_r59.compile("(?<!#)\\b\\d+(\\.\\d+)?\\b")
	for line in _p91:
		if line.strip_edges().is_empty():
			_p60 += "\n"
			continue
		var _m78 = line.find("#")
		var _o10 = line
		var _r66 = ""
		if _m78 != -1:
			_o10 = line.substr(0, _m78)
			_r66 = line.substr(_m78)
			_r66 = "[color=#%s]%s[/color]" % [_q60("comment").to_html(false), _r66]
		_o10 = _h45.sub(_o10, "[color=#%s]$1[/color]" % [_q60("string").to_html(false)], true)
		_o10 = _z57.sub(_o10, "[color=#%s]$1[/color]" % [_q60("keyword").to_html(false)], true)
		_o10 = _x86.sub(_o10, "[color=#%s]$1[/color]" % [_q60("class").to_html(false)], true)
		_o10 = _j39.sub(_o10, "[color=#%s]$1[/color](" % [_q60("function").to_html(false)], true)
		_o10 = _r59.sub(_o10, "[color=#%s]$0[/color]" % [_q60("number").to_html(false)], true)
		_p60 += _o10 + _r66 + "\n"
	return _p60.strip_edges()
func _o33(_q76: _z9._l87, file_path: String, _p18: bool = false):
	if not _q76:
		push_error("UndoConfirmation: No refactor entry provided")
		return
	_b61 = _q76.function_name
	_y34 = _q76.original_code
	_k50 = file_path
	_k57()
	_j28()
	_q17()
	if _i49:
		if _p18:
			_i49.text = "Undo MODIFIED function: %s()" % _q76.function_name
			var _r91 = get_theme_color("warning_color", "Editor") if has_theme_color("warning_color", "Editor") else Color(0.9, 0.7, 0.2)
			_i49.add_theme_color_override("font_color", _r91)
		else:
			_i49.text = "Undo refactor for: %s()" % _q76.function_name
			_i49.remove_theme_color_override("font_color")
	if _k96:
		_k96.text = "Refactored at: %s" % _q76._v7()
	if _g57:
		var _o93 = _q60("text")
		_g57.add_theme_color_override("default_color", _o93)
		var _s62 = _d64(_q76.original_code)
		_g57.text = _s62
		var _t98 = _q76.original_code.count("\n") + 1
		var _h72 = int(16 * _v32)
		var _a37 = int(60 * _v32)
		var _i69 = int(150 * _v32)
		var _a41 = _t98 * _h72
		var _v83 = clamp(_a41, _a37, _i69)
		_g57.custom_minimum_size = Vector2(0, _v83)
	var _h9 = int(450 * _v32)
	var _u54 = int(280 * _v32)
	size = Vector2i(_h9, _u54)
	popup_centered()
func _v71():
	hide()
func _s38():
	_u90.emit(_b61, _y34, _k50)
	hide()
func _e52():
	_v71()
func _n46() -> String:
	return _b61
func _r14() -> String:
	return _y34
func get_file_path() -> String:
	return _k50
