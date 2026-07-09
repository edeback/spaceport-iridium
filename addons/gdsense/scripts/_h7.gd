@tool
class_name _b39
extends ConfirmationDialog

signal _f83(function_name: String, original_code: String, file_path: String)

@onready var _w12: Label = %_g13
@onready var _b87: Label = %_v91
@onready var _b35: RichTextLabel = %_d20
@onready var _j28: PanelContainer = $_l21/_g59
@onready var _a90: Button = %_r99
@onready var _m77: Button = %_y37
@onready var _u2: Label = $_l21/_h55
@onready var _c85: Label = $_l21/_w13

var _s63: String = ""
var _f86: String = ""
var _x36: String = ""
var _a31: float = 1.0
var _z76: EditorInterface = null

const _b45 = [
	"if", "elif", "else", "for", "while", "match", "break", "continue", "pass",
	"return", "class", "extends", "is", "as", "self", "super", "func", "signal",
	"const", "var", "static", "enum", "in", "not", "and", "or", "true", "false",
	"null", "export", "onready", "tool", "setget", "breakpoint", "preload", "yield",
	"assert", "remote", "sync", "master", "puppet", "await", "class_name"
]

func _ready():
	if _a90:
		_a90.pressed.connect(_l47)
	if _m77:
		_m77.pressed.connect(_k95)

	canceled.connect(_l47)

	get_ok_button().hide()
	get_cancel_button().hide()

	_x92()
	var _l37 = int(400 * _a31)
	var _z56 = int(200 * _a31)
	min_size = Vector2i(350, 150)
	size = Vector2i(_l37, _z56)

	_q25()

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

func _q25():
	var _t96 = int(18 * _a31)
	var _z79 = int(14 * _a31)
	var _s82 = int(13 * _a31)
	var _a78 = int(14 * _a31)
	var _w16 = int(12 * _a31)

	if _w12:
		_w12.add_theme_font_size_override("font_size", _t96)
	if _b87:
		_b87.add_theme_font_size_override("font_size", _z79)
	if _u2:
		_u2.add_theme_font_size_override("font_size", _z79)
	if _b35:
		_b35.add_theme_font_size_override("normal_font_size", _s82)

		_b35.add_theme_color_override("default_color", Color.WHITE)
	if _c85:
		_c85.add_theme_font_size_override("font_size", _w16)
	if _a90:
		_a90.add_theme_font_size_override("font_size", _a78)
	if _m77:
		_m77.add_theme_font_size_override("font_size", _a78)

	_l29()

func _a87(_r48: EditorInterface) -> void:
	_z76 = _r48

func _l29():
	if not _j28:
		return

	var _m31 = get_theme_color("base_color", "Editor") if has_theme_color("base_color", "Editor") else Color(0.5, 0.5, 0.5)
	var _o90 = _m31.get_luminance() > 0.5

	var bg_color = _m31.darkened(0.08) if _o90 else _m31.lightened(0.08)
	var border_color = _m31.darkened(0.2) if _o90 else _m31.lightened(0.15)

	var _r20 = StyleBoxFlat.new()
	_r20.bg_color = bg_color
	_r20.border_color = border_color
	_r20.corner_radius_top_left = 4
	_r20.corner_radius_top_right = 4
	_r20.corner_radius_bottom_left = 4
	_r20.corner_radius_bottom_right = 4

	var margin = int(8 * _a31)
	_r20.content_margin_left = margin
	_r20.content_margin_right = margin
	_r20.content_margin_top = margin
	_r20.content_margin_bottom = margin

	_r20.border_width_left = 1
	_r20.border_width_right = 1
	_r20.border_width_top = 1
	_r20.border_width_bottom = 1

	_j28.add_theme_stylebox_override("panel", _r20)

func _x34(type: String) -> Color:
	if _z76:
		var _f80 = _z76.get_editor_settings()
		if _f80:
			match type:
				"text": return _f80.get_setting("text_editor/theme/highlighting/text_color")
				"comment": return _f80.get_setting("text_editor/theme/highlighting/comment_color")
				"string": return _f80.get_setting("text_editor/theme/highlighting/string_color")
				"number": return _f80.get_setting("text_editor/theme/highlighting/number_color")
				"keyword": return _f80.get_setting("text_editor/theme/highlighting/keyword_color")
				"class": return _f80.get_setting("text_editor/theme/highlighting/base_type_color")
				"function": return _f80.get_setting("text_editor/theme/highlighting/function_color")
				"symbol": return _f80.get_setting("text_editor/theme/highlighting/symbol_color")

	return get_theme_color("font_color", "Label")

func _q95(code: String) -> String:
	var _t90 = ""
	var _b26 = code.split("\n")

	var _g65 = RegEx.new()
	_g65.compile("\\b(" + "|".join(_b45) + ")\\b")

	var _c87 = RegEx.new()
	_c87.compile("(?<!#)\\b([A-Z][a-zA-Z0-9]*)\\b")

	var _f3 = RegEx.new()
	_f3.compile("\\b([a-z_][a-z0-9_]*)\\s*\\(")

	var _o8 = RegEx.new()
	_o8.compile("(\"[^\"]*\"|'[^']*')")

	var _o15 = RegEx.new()
	_o15.compile("(?<!#)\\b\\d+(\\.\\d+)?\\b")

	for line in _b26:
		if line.strip_edges().is_empty():
			_t90 += "\n"
			continue

		var _s79 = line.find("#")
		var _d34 = line
		var _l70 = ""
		if _s79 != -1:
			_d34 = line.substr(0, _s79)
			_l70 = line.substr(_s79)
			_l70 = "[color=#%s]%s[/color]" % [_x34("comment").to_html(false), _l70]

		_d34 = _o8.sub(_d34, "[color=#%s]$1[/color]" % [_x34("string").to_html(false)], true)

		_d34 = _g65.sub(_d34, "[color=#%s]$1[/color]" % [_x34("keyword").to_html(false)], true)

		_d34 = _c87.sub(_d34, "[color=#%s]$1[/color]" % [_x34("class").to_html(false)], true)

		_d34 = _f3.sub(_d34, "[color=#%s]$1[/color](" % [_x34("function").to_html(false)], true)

		_d34 = _o15.sub(_d34, "[color=#%s]$0[/color]" % [_x34("number").to_html(false)], true)

		_t90 += _d34 + _l70 + "\n"

	return _t90.strip_edges()

func _k60(_y17: _o9._c71, file_path: String, _y58: bool = false):
	if not _y17:
		push_error("UndoConfirmation: No refactor entry provided")
		return

	_s63 = _y17.function_name
	_f86 = _y17.original_code
	_x36 = file_path

	_x92()
	_q25()
	_l29()

	if _w12:
		if _y58:
			_w12.text = "Undo MODIFIED function: %s()" % _y17.function_name
			var _r37 = get_theme_color("warning_color", "Editor") if has_theme_color("warning_color", "Editor") else Color(0.9, 0.7, 0.2)
			_w12.add_theme_color_override("font_color", _r37)
		else:
			_w12.text = "Undo refactor for: %s()" % _y17.function_name
			_w12.remove_theme_color_override("font_color")

	if _b87:
		_b87.text = "Refactored at: %s" % _y17._c45()

	if _b35:
		var _u18 = _x34("text")
		_b35.add_theme_color_override("default_color", _u18)

		var _b68 = _q95(_y17.original_code)
		_b35.text = _b68

		var _s40 = _y17.original_code.count("\n") + 1
		var _i40 = int(16 * _a31)
		var _r4 = int(60 * _a31)
		var _d7 = int(150 * _a31)
		var _r2 = _s40 * _i40
		var _h5 = clamp(_r2, _r4, _d7)
		_b35.custom_minimum_size = Vector2(0, _h5)

	var _l37 = int(450 * _a31)
	var _z56 = int(280 * _a31)
	size = Vector2i(_l37, _z56)

	popup_centered()

func _l47():
	hide()

func _k95():
	_f83.emit(_s63, _f86, _x36)
	hide()

func _b57():
	_l47()

func _b22() -> String:
	return _s63

func _j25() -> String:
	return _f86

func get_file_path() -> String:
	return _x36

