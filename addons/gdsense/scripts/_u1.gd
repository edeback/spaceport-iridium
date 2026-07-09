@tool
class_name _l45
extends ConfirmationDialog
signal _w67(function_name: String, original_code: String, file_path: String)
@onready var _g69: Label = %_m30
@onready var _d41: Label = %_a25
@onready var _b39: RichTextLabel = %_i80
@onready var _h55: PanelContainer = $_s36/_n41
@onready var _m56: Button = %_m44
@onready var _h32: Button = %_f35
@onready var _w26: Label = $_s36/_a19
@onready var _u71: Label = $_s36/_b5
var _k7: String = ""
var _f42: String = ""
var _f19: String = ""
var _p78: float = 1.0
var _w27: EditorInterface = null
const _g18 = [
	"if", "elif", "else", "for", "while", "match", "break", "continue", "pass",
	"return", "class", "extends", "is", "as", "self", "super", "func", "signal",
	"const", "var", "static", "enum", "in", "not", "and", "or", "true", "false",
	"null", "export", "onready", "tool", "setget", "breakpoint", "preload", "yield",
	"assert", "remote", "sync", "master", "puppet", "await", "class_name"
]
func _ready():
	if _m56:
		_m56.pressed.connect(_m8)
	if _h32:
		_h32.pressed.connect(_c100)
	canceled.connect(_m8)
	get_ok_button().hide()
	get_cancel_button().hide()
	_b20()
	var _g88 = int(400 * _p78)
	var _k34 = int(200 * _p78)
	min_size = Vector2i(350, 150)
	size = Vector2i(_g88, _k34)
	_v20()
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
func _v20():
	var _q93 = int(18 * _p78)
	var _g3 = int(14 * _p78)
	var _q48 = int(13 * _p78)
	var _d12 = int(14 * _p78)
	var _f99 = int(12 * _p78)
	if _g69:
		_g69.add_theme_font_size_override("font_size", _q93)
	if _d41:
		_d41.add_theme_font_size_override("font_size", _g3)
	if _w26:
		_w26.add_theme_font_size_override("font_size", _g3)
	if _b39:
		_b39.add_theme_font_size_override("normal_font_size", _q48)
		_b39.add_theme_color_override("default_color", Color.WHITE)
	if _u71:
		_u71.add_theme_font_size_override("font_size", _f99)
	if _m56:
		_m56.add_theme_font_size_override("font_size", _d12)
	if _h32:
		_h32.add_theme_font_size_override("font_size", _d12)
	_c46()
func _i71(_l77: EditorInterface) -> void:
	_w27 = _l77
func _c46():
	if not _h55:
		return
	var _z13 = get_theme_color("base_color", "Editor") if has_theme_color("base_color", "Editor") else Color(0.5, 0.5, 0.5)
	var _q53 = _z13.get_luminance() > 0.5
	var bg_color = _z13.darkened(0.08) if _q53 else _z13.lightened(0.08)
	var border_color = _z13.darkened(0.2) if _q53 else _z13.lightened(0.15)
	var _p10 = StyleBoxFlat.new()
	_p10.bg_color = bg_color
	_p10.border_color = border_color
	_p10.corner_radius_top_left = 4
	_p10.corner_radius_top_right = 4
	_p10.corner_radius_bottom_left = 4
	_p10.corner_radius_bottom_right = 4
	var margin = int(8 * _p78)
	_p10.content_margin_left = margin
	_p10.content_margin_right = margin
	_p10.content_margin_top = margin
	_p10.content_margin_bottom = margin
	_p10.border_width_left = 1
	_p10.border_width_right = 1
	_p10.border_width_top = 1
	_p10.border_width_bottom = 1
	_h55.add_theme_stylebox_override("panel", _p10)
func _q27(type: String) -> Color:
	if _w27:
		var _r43 = _w27.get_editor_settings()
		if _r43:
			match type:
				"text": return _r43.get_setting("text_editor/theme/highlighting/text_color")
				"comment": return _r43.get_setting("text_editor/theme/highlighting/comment_color")
				"string": return _r43.get_setting("text_editor/theme/highlighting/string_color")
				"number": return _r43.get_setting("text_editor/theme/highlighting/number_color")
				"keyword": return _r43.get_setting("text_editor/theme/highlighting/keyword_color")
				"class": return _r43.get_setting("text_editor/theme/highlighting/base_type_color")
				"function": return _r43.get_setting("text_editor/theme/highlighting/function_color")
				"symbol": return _r43.get_setting("text_editor/theme/highlighting/symbol_color")
	return get_theme_color("font_color", "Label")
func _c22(code: String) -> String:
	var _k83 = ""
	var _j90 = code.split("\n")
	var _t51 = RegEx.new()
	_t51.compile("\\b(" + "|".join(_g18) + ")\\b")
	var _c61 = RegEx.new()
	_c61.compile("(?<!#)\\b([A-Z][a-zA-Z0-9]*)\\b")
	var _s22 = RegEx.new()
	_s22.compile("\\b([a-z_][a-z0-9_]*)\\s*\\(")
	var _l34 = RegEx.new()
	_l34.compile("(\"[^\"]*\"|'[^']*')")
	var _n93 = RegEx.new()
	_n93.compile("(?<!#)\\b\\d+(\\.\\d+)?\\b")
	for line in _j90:
		if line.strip_edges().is_empty():
			_k83 += "\n"
			continue
		var _y75 = line.find("#")
		var _q3 = line
		var _o15 = ""
		if _y75 != -1:
			_q3 = line.substr(0, _y75)
			_o15 = line.substr(_y75)
			_o15 = "[color=#%s]%s[/color]" % [_q27("comment").to_html(false), _o15]
		_q3 = _l34.sub(_q3, "[color=#%s]$1[/color]" % [_q27("string").to_html(false)], true)
		_q3 = _t51.sub(_q3, "[color=#%s]$1[/color]" % [_q27("keyword").to_html(false)], true)
		_q3 = _c61.sub(_q3, "[color=#%s]$1[/color]" % [_q27("class").to_html(false)], true)
		_q3 = _s22.sub(_q3, "[color=#%s]$1[/color](" % [_q27("function").to_html(false)], true)
		_q3 = _n93.sub(_q3, "[color=#%s]$0[/color]" % [_q27("number").to_html(false)], true)
		_k83 += _q3 + _o15 + "\n"
	return _k83.strip_edges()
func _s56(_t6: _n17._f84, file_path: String, _q73: bool = false):
	if not _t6:
		push_error("UndoConfirmation: No refactor entry provided")
		return
	_k7 = _t6.function_name
	_f42 = _t6.original_code
	_f19 = file_path
	_b20()
	_v20()
	_c46()
	if _g69:
		if _q73:
			_g69.text = "Undo MODIFIED function: %s()" % _t6.function_name
			var _x44 = get_theme_color("warning_color", "Editor") if has_theme_color("warning_color", "Editor") else Color(0.9, 0.7, 0.2)
			_g69.add_theme_color_override("font_color", _x44)
		else:
			_g69.text = "Undo refactor for: %s()" % _t6.function_name
			_g69.remove_theme_color_override("font_color")
	if _d41:
		_d41.text = "Refactored at: %s" % _t6._s30()
	if _b39:
		var _x4 = _q27("text")
		_b39.add_theme_color_override("default_color", _x4)
		var _h81 = _c22(_t6.original_code)
		_b39.text = _h81
		var _k66 = _t6.original_code.count("\n") + 1
		var _q34 = int(16 * _p78)
		var _m23 = int(60 * _p78)
		var _w70 = int(150 * _p78)
		var _o50 = _k66 * _q34
		var _s77 = clamp(_o50, _m23, _w70)
		_b39.custom_minimum_size = Vector2(0, _s77)
	var _g88 = int(450 * _p78)
	var _k34 = int(280 * _p78)
	size = Vector2i(_g88, _k34)
	popup_centered()
func _m8():
	hide()
func _c100():
	_w67.emit(_k7, _f42, _f19)
	hide()
func _f17():
	_m8()
func _h6() -> String:
	return _k7
func _r81() -> String:
	return _f42
func get_file_path() -> String:
	return _f19
