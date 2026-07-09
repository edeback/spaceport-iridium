@tool
extends Control
func _p24(type: String) -> Color:
	if _o10:
		var _d93 = _o10.get_editor_settings()
		if _d93:
			match type:
				"text_color": return _d93.get_setting("text_editor/theme/highlighting/text_color")
				"comment": return _d93.get_setting("text_editor/theme/highlighting/comment_color")
				"string": return _d93.get_setting("text_editor/theme/highlighting/string_color")
				"number": return _d93.get_setting("text_editor/theme/highlighting/number_color")
				"keyword": return _d93.get_setting("text_editor/theme/highlighting/keyword_color")
				"class": return _d93.get_setting("text_editor/theme/highlighting/base_type_color")
				"function": return _d93.get_setting("text_editor/theme/highlighting/function_color")
				"symbol": return _d93.get_setting("text_editor/theme/highlighting/symbol_color")
	match type:
		"comment": return Color.GRAY
		"string": return Color.ORANGE
		"number": return Color.SKY_BLUE
		"keyword": return Color.PALE_VIOLET_RED
		"class": return Color.LIGHT_GREEN
		"function": return Color.LIGHT_BLUE
		"symbol": return Color.WHITE
	return Color.WHITE
const _u46 = [
	"if", "elif", "else", "for", "while", "match", "break", "continue", "pass",
	"return", "class", "extends", "is", "as", "self", "super", "func", "signal",
	"const", "var", "static", "enum", "in", "not", "and", "or", "true", "false",
	"null", "export", "onready", "tool", "setget", "breakpoint", "preload", "yield",
	"assert", "remote", "sync", "master", "puppet"
]
const _h8 = [
	"public", "private", "protected", "internal", "static", "void", 
	"class", "interface", "namespace", "using", "new", "this", "base",
	"if", "else", "for", "foreach", "while", "do", "switch", "case",
	"return", "throw", "try", "catch", "finally", "async", "await",
	"var", "const", "readonly", "override", "virtual", "abstract",
	"int", "string", "bool", "float", "double", "decimal", "byte", "true", "false", "null"
]
func _c77():
	if not _o10:
		return
	var theme = _o10.get_editor_theme()
	if not theme:
		return
	var _i13 = theme.get_color("base_color", "Editor")
	var _s96 = theme.get_color("dark_color_2", "Editor")
	var _w5 = theme.get_color("contrast_color_1", "Editor")
	var font_color = theme.get_color("font_color", "Editor")
	var _w23 = theme.get_color("accent_color", "Editor")
	if not _m95:
		_c16()
	var _u68 = _i13.lerp(_w23, 0.1)
	if _i13.get_luminance() > 0.5:
		_u68 = _i13.darkened(0.05).lerp(_w23, 0.1)
	_m95.bg_color = _u68
	_m95.border_color = _w23.darkened(0.3)
	if _u68.get_luminance() > 0.5:
		_q74 = Color.BLACK
	else:
		_q74 = Color(0.9, 0.9, 0.9) 
	var _x69 = _s96
	_n95.bg_color = _x69
	_n95.border_color = _x69.lightened(0.05)
	_u85 = font_color
	var _c42 = _o63("normal", "TextEdit")
	if _c42 is StyleBoxFlat:
		_r63.bg_color = _c42.bg_color
		_r63.border_color = _c42.border_color
		_r63.border_width_left = _c42.border_width_left
		_r63.border_width_top = _c42.border_width_top
		_r63.border_width_right = _c42.border_width_right
		_r63.border_width_bottom = _c42.border_width_bottom
		_r63.corner_radius_top_left = _c42.corner_radius_top_left
		_r63.corner_radius_top_right = _c42.corner_radius_top_right
		_r63.corner_radius_bottom_right = _c42.corner_radius_bottom_right
		_r63.corner_radius_bottom_left = _c42.corner_radius_bottom_left
	else:
		_r63.bg_color = _i13
		_r63.border_color = _i13.lightened(0.1)
	_y33.bg_color = _s96
	_y33.border_color = _s96.lightened(0.1)
	_e27 = font_color
	_b75.bg_color = _s96.lightened(0.05)
func _f87(name: String, type: String = "Editor") -> Color:
	if _o10:
		var theme = _o10.get_editor_theme()
		if theme:
			return theme.get_color(name, type)
	return Color.GRAY 
func _o63(name: String, type: String = "Editor") -> StyleBox:
	if _o10:
		var theme = _o10.get_editor_theme()
		if theme:
			return theme.get_stylebox(name, type)
	return null
var _m95: StyleBoxFlat
var _n95: StyleBoxFlat
var _y33: StyleBoxFlat
var _b75: StyleBoxFlat
var _r63: StyleBoxFlat
var _q74: Color
var _u85: Color
var _e27: Color
const _i12 = {
	"message_gap": 16,
	"padding": 12,
	"code_padding": 10
}
func _c16():
	_m95 = StyleBoxFlat.new()
	_m95.corner_radius_top_left = 8
	_m95.corner_radius_top_right = 8
	_m95.corner_radius_bottom_left = 8
	_m95.corner_radius_bottom_right = 8
	_m95.content_margin_left = _i12.padding
	_m95.content_margin_right = _i12.padding
	_m95.content_margin_top = _i12.padding
	_m95.content_margin_bottom = _i12.padding
	_m95.border_width_bottom = 1
	_m95.border_width_top = 1
	_m95.border_width_left = 1
	_m95.border_width_right = 1
	_n95 = StyleBoxFlat.new()
	_n95.corner_radius_top_left = 8
	_n95.corner_radius_top_right = 8
	_n95.corner_radius_bottom_left = 8
	_n95.corner_radius_bottom_right = 8
	_n95.content_margin_left = _i12.padding
	_n95.content_margin_right = _i12.padding
	_n95.content_margin_top = _i12.padding
	_n95.content_margin_bottom = _i12.padding
	_n95.border_width_bottom = 1
	_n95.border_width_top = 1
	_n95.border_width_left = 1
	_n95.border_width_right = 1
	_y33 = StyleBoxFlat.new()
	_y33.corner_radius_top_left = 4
	_y33.corner_radius_top_right = 4
	_y33.corner_radius_bottom_left = 4
	_y33.corner_radius_bottom_right = 4
	_y33.border_width_bottom = 1
	_y33.border_width_top = 1
	_y33.border_width_left = 1
	_y33.border_width_right = 1
	_y33.border_width_left = 1
	_y33.border_width_right = 1
	_b75 = StyleBoxFlat.new()
	_b75.corner_radius_top_left = 6
	_b75.corner_radius_top_right = 6
	_b75.content_margin_left = 12
	_b75.content_margin_right = 12
	_b75.content_margin_top = 4
	_b75.content_margin_bottom = 4
	_r63 = StyleBoxFlat.new()
	_r63.bg_color = Color(0.1, 0.1, 0.1) 
	_r63.border_width_left = 1
	_r63.border_width_top = 1
	_r63.border_width_right = 1
	_r63.border_width_bottom = 1
	_r63.corner_radius_top_left = 4
	_r63.corner_radius_top_right = 4
	_r63.corner_radius_bottom_right = 4
	_r63.corner_radius_bottom_left = 4
const _f15 = {
	"gdscript": "GDScript",
	"csharp": "C#",
	"cs": "C#",
	"": "GDScript"  
}
const _t42 = {
	"openai/gpt-oss-20b": "GPT OSS-20B (0.5x)",
	"gemini-2.5-flash-lite": "Flash-Lite (0.75x)",
	"gpt-5-nano": "GPT-5 Nano (0.75x)",
	"openai/gpt-oss-120b": "GPT OSS-120b (1x)",
	"gemini-2.5-flash": "Gemini Flash (2.5x)",
	"gpt-5.1-codex-mini": "GPT-5.1 Codex Mini (2.5x)",
	"moonshotai/kimi-k2-instruct-0905": "Kimi K2 (5x)",
	"moonshotai/kimi-k2-thinking-maas": "Kimi K2 Thinking (5x)",
	"gemini-3-flash-preview": "Flash 3 (5x)",
	"gemini-3-pro-preview": "Gemini Pro 3 (12x)",
	"gemini-2.5-pro": "Gemini Pro (10x)",
	"gpt-5.1-codex": "GPT-5.1 Codex (10x)"
}
const _t35 = {
	"1080p": {"width": 1920, "height": 1080, "scale": 1.0},  
	"1440p": {"width": 2560, "height": 1440, "scale": 1.15}, 
	"4k": {"width": 3840, "height": 2160, "scale": 1.5},     
	"user": {"width": 1800, "height": 1169, "scale": 1.1}    
}
const _j68 = {
	0: "auto",    
	1: 0.8,       
	2: 1.0,       
	3: 1.25,      
	4: 1.5        
}
const _e33 = 16  
var _c9: EditorPlugin
var _o10: EditorInterface
var _x62: ScriptEditor
var _k19: VBoxContainer
var _r16: EditorPlugin  
var _n78: _m33
var _w54: _s40
var _o24: _w4
@onready var _f1: ScrollContainer = %_b86
@onready var _g79: TextEdit = %_d41
@onready var _x96: Button = %_o27
@onready var _x13: LineEdit = %_k51
@onready var _z88: Button = %_q48
@onready var _n5: Label = %_j77
@onready var _x76: CheckButton = %_m84
@onready var _d85: Label = %_j45
@onready var _j85: HBoxContainer = %_x15
@onready var _f44: Label = %_h56
@onready var _h94: Label = %_s44
@onready var _x73: Label = %_x12
@onready var _r33: Button = %_g19
@onready var _g24: Label = %_u79
@onready var _l4: OptionButton = %_n9
@onready var _h34: OptionButton = %_n80
@onready var _m64: OptionButton = %_r39
@onready var _r57: VBoxContainer = $MarginContainer/TabContainer/Settings/_l13/VBoxContainer
@onready var _v82: TabContainer = $MarginContainer/TabContainer
@onready var _u13: ProgressBar = %_h28
@onready var _x33: Label = %_b34
@onready var _n32: Label = %_o98
@onready var _w27: Label = %_g40
@onready var _e66: OptionButton = %_j47
@onready var _z28: Panel = %_l31
@onready var _t45: Label = %_q27
@onready var _s1: TabContainer = %_g29
@onready var _t11: ItemList = %_z56
@onready var _s45: Label = %_z100
@onready var _s20: RichTextLabel = %_v24
@onready var _o58: RichTextLabel = %_a37
@onready var _d68: Button = %_g88
@onready var _v2: Button = %_n50
@onready var _d53: Button = %_c53
@onready var _y52: Button = %_g12
@onready var _n30: ItemList = %_x7
@onready var _i37: Label = %_b94
@onready var _s92: RichTextLabel = %_g97
@onready var _v50: RichTextLabel = %_u89
@onready var _i16: Button = %_k65
@onready var _q85: Button = %_n92
@onready var _r99: Button = %_t85
@onready var _v49: Button = %_h40
@onready var _l39: Button = %_t87
@onready var _o37: Button = %_n25
@onready var _n49: Button = %_k59
@onready var _x50: Button = %_s78
@onready var _d62: AcceptDialog = %_s48
@onready var _i81: LineEdit = %_u2
@onready var _r96: FileDialog = %_y47
@onready var _w26: FileDialog = %_o97
@onready var _c99: OptionButton = %_y100
@onready var _e92: Label = %_m43
var _p44: CheckBox
var _x100: OptionButton
var _v17: SpinBox
var _r80: CheckBox
var _c21: CheckBox
var _k3: Button
var _w18: _a99
var _q81: Array = []
var _g59: bool = false
var _h46: float = 0.0
var _f11: int = 0
var _z81: Dictionary = {}  
var _s26: int = 0
var _z67: int = 30000  
var _y6: Dictionary = {}
var _a54: Array[String] = []
var _k41: int = 0
var _d16: _b86
var _j87: int = -1
var _h10: int = -1
var _y29: String = ""
var _h5: bool = false
var _i99: String = ""  
var _c83: String = ""  
var _t29: bool = false
var _e17: Vector2 = Vector2.ZERO
var _u12: float = 0.0
var _p70: HBoxContainer
var _b29: OptionButton
var _v23: Label
var _q66: OptionButton  
const _j51 = [
	{"id": "openai/gpt-oss-20b", "name": "GPT OSS-20B (0.5x) [Default]"},
	{"id": "openai/gpt-oss-120b", "name": "GPT OSS-120b (1x)"},
	{"id": "gemini-2.5-flash-lite", "name": "Flash-Lite (0.75x)"},
	{"id": "gemini-2.5-flash", "name": "Gemini Flash (2.5x)"},
	{"id": "gpt-5.1-codex-mini", "name": "GPT-5.1 Codex Mini (2.5x)"},
	{"id": "moonshotai/kimi-k2-instruct-0905", "name": "Kimi K2 (5x)"},
	{"id": "moonshotai/kimi-k2-thinking-maas", "name": "Kimi K2 Thinking (5x)"},
	{"id": "gemini-3-flash-preview", "name": "Flash 3 (5x)"},
	{"id": "gemini-3-pro-preview", "name": "Gemini Pro 3 (12x)"},
	{"id": "gemini-2.5-pro", "name": "Gemini Pro (10x)"},
	{"id": "gpt-5.1-codex", "name": "GPT-5.1 Codex (10x)"}
]
var _q80: TextEdit
var _u24: Label
var _i6: Label
const _b52 = 3
var _z65: int = 0
var _a17: float = 1.0
var _e5: String = "auto"  
var _p76: int = 128000  
const _u16 = 0.85  
const _g81 = 1.0  
const _q54 = [
	"@file",
	"@selection",
	"@openscript",
	"@scene",
	"@node"
]
const _z89: int = 0
const _v30: int = 1
const _r59 = {
	_z89: "Chat",
	_v30: "Agent"
}
var _v75: _p75
var _w100: _a98
var _i78: ProgressBar
var _g37: Label
var _y87: Button
var _i69: bool = false
var _i57: VBoxContainer
var _y65: HBoxContainer
var _w53: Array = []  
var _d72: bool = false  
var _o60: HBoxContainer  
var _n94: HBoxContainer  
var _i52 = 0
var _b16 = []
var _k50 = {}
var _j20: Timer
var _j18: int = 0
var _i7: PanelContainer
var _q37: bool = false  
func _c96() -> void:
	_z81 = {}
func set_gdsense_manager(_d19: _a99) -> void:
	_w18 = _d19
	if _w18:
		if not _w18._d6.is_connected(_q16):
			_w18._d6.connect(_q16)
		if not _w18._f67.is_connected(_l73):
			_w18._f67.connect(_l73)
		if not _w18._z97.is_connected(_h23):
			_w18._z97.connect(_h23)
func set_plugin(_z23: EditorPlugin) -> void:
	_r16 = _z23
func _notification(_h4):
	if _h4 == NOTIFICATION_THEME_CHANGED:
		_l57()
func _ready() -> void:
	_c16()
	_n53.call_deferred()
	_c9 = EditorPlugin.new()
	_o10 = _c9.get_editor_interface()
	_x62 = _o10.get_script_editor()
	var _s63 = %_c80
	if _s63:
		_s63.add_theme_stylebox_override("panel", _r63)
	_c77()
	_b42()
	_n78 = _m33.new(_o10, _x62)
	_w54 = _s40.new(_n78, _o10)
	_o24 = _w4.new()
	_o24.initialize(_g79, self, _o10)
	_o24._l75.connect(_y55)
	_k19 = %_f63
	_f1.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_k19.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_z88.pressed.connect(_h88)
	_x96.pressed.connect(_s25)
	_x76.toggled.connect(_r93)
	_r33.pressed.connect(_g73)
	_l4.item_selected.connect(_n76)
	_h34.item_selected.connect(_n76)
	_g79.gui_input.connect(_z1)
	_g79.text_changed.connect(_w87)
	_z28.mouse_entered.connect(_k13)
	_z28.mouse_exited.connect(_o6)
	_z28.gui_input.connect(_f8)
	_m74()
	_x56()
	_s6()
	_j20 = Timer.new()
	_j20.wait_time = 0.5  
	_j20.one_shot = true
	_j20.timeout.connect(_o14)
	add_child(_j20)
	if _w18:
		_w18._k16.connect(_q65)
		_w18._y58.connect(_b1)
		_w18._t37.connect(_x99)
		_w18._p86.connect(_k55)
		_w18._z29.connect(_r89)
		_w18._t38.connect(_g69)
		_w18._s39.connect(_a84)
		_w18._c79.connect(_p69)
	var _b22 = _w18._a82() if _w18 else ""
	_x13.text = _b22
	if _b22.is_empty():
		if _w18 and _w18._k71():
			var env = _w18._q98()
			_n5.text = "No API Key (%s)" % env.capitalize()
		else:
			_n5.text = "API Key Not Set"
	else:
		if _w18 and _w18._k71():
			var env = _w18._q98()
			_n5.text = "API Key Loaded (%s)" % env.capitalize()
		else:
			_n5.text = "API Key Loaded"
	_u7()
	_q62()
	_m9()
	_u11()
	_j99()
	_r86()
	_r58()
	_a83.call_deferred()
	_d85.visible = false
	_j85.visible = false
	if not (_w18 and _w18._k71()):
		_g24.visible = false
	_u48()
	_e7()
func _n53():
	if not _w18:
		if _z65 >= _b52:
			return
		_z65 += 1
		if is_inside_tree():
			get_tree().create_timer(1.0).timeout.connect(_r19)
		else:
			_x70.call_deferred()
func _x70():
	if _z65 >= _b52:
		return
	_n53()
func _r19():
	if not _w18:
		if _z65 >= _b52:
			pass
		else:
			pass
	else:
		_z65 = 0
func _process(delta: float):
	if _g59:
		var elapsed_time = (Time.get_ticks_msec() / 1000.0) - _h46
		_d85.text = "Request time: %.1fs" % elapsed_time
func _z1(_v53: InputEvent):
	if _o24 and _o24._z16(_v53):
		get_viewport().set_input_as_handled()
		return
	if _v53 is InputEventKey and _v53.pressed:
		if _v53.keycode == KEY_ENTER:
			if _v53.shift_pressed:
				_g79.text += "\n"
				_g79.set_caret_line(_g79.get_line_count() - 1)
				_g79.set_caret_column(0)
				get_viewport().set_input_as_handled()
			else:
				var text = _g79.text.strip_edges()
				if text.is_empty():
					return
				_g79.text = ""
				_w87() 
				if _m64 and _m64.selected == _v30:
					_r26(text)
				else:
					_f100(text)
				get_viewport().set_input_as_handled()
func _h88():
	if _w18:
		_w18._l34(_x13.text)
func _s25():
	var _m12: String = _g79.text
	if not _m12.is_empty():
		if _m64 and _m64.selected == _v30:
			_r26(_m12)
		else:
			_f100(_m12)
func _r26(_y88: String) -> void:
	if not _v75:
		_t99("Agent mode not available", true)
		return
	var _m10 = _i71(_y88)
	if _m10.is_empty():
		return
	_g79.text = ""
	_r64(_y88)
	_e48()
	_g79.editable = false
	_x96.disabled = true
	var _r97 = {
		"godot_version": Engine.get_version_info().get("string", "4.x"),
		"project_name": ProjectSettings.get_setting("application/config/name", "")
	}
	var _c65 = ""
	if _q66:
		_c65 = _e29()
	_v75._h22(_m10, _r97, _c65)
func _f100(_m12: String):
	_i99 = _m12
	_y54()
	_q81.append({"role": "user", "content": _m12, "original_content": _m12})
	_c96()
	var _y67 = _m12
	if _m12.begins_with("@explain"):
		var _q60 = _m12.find("\n")
		if _q60 != -1:
			_y67 = _m12.substr(0, _q60) + " (code attached)"
	_r64(_y67)
	_g79.text = ""
	_g79.editable = false
	_x96.disabled = true
	_g59 = true
	_h46 = Time.get_ticks_msec() / 1000.0
	_d85.visible = true
	_j85.visible = false
	_d85.text = "Request time: 0.0s"
	_t89.call_deferred()
	var _b17 = _w20(_m12, true)
	var processed_prompt = _b17["processed_prompt"]
	var context_metadata = _b17["context_metadata"]
	if processed_prompt == "":
		_k82()
		if _q81.size() > 0:
			_q81.pop_back()
			_c96()
		return
	if processed_prompt.strip_edges().begins_with("@explain"):
		var _s83 = _p14(processed_prompt)
		if _s83.has("function_context") and not _s83["function_context"].is_empty():
			if _w18:
				_w18._r28(_q81, "@explain", _s83["function_context"], context_metadata if context_metadata else {})
		else:
			_q81[_q81.size() - 1]["content"] = processed_prompt
			if _w18:
				_w18._r28(_q81, "", "", context_metadata if context_metadata else {})
	else:
		_q81[_q81.size() - 1]["content"] = processed_prompt
		if _w18:
			_w18._r28(_q81, "", "", context_metadata if context_metadata else {})
func _q65(_d40: String, _a79: Array, _u17: String = "", _e53: String = ""):
	if not _e53.is_empty() and _q81.size() > 0:
		for i in range(_q81.size() - 1, -1, -1):
			if _q81[i].get("role", "") == "user":
				_q81[i]["content"] = _e53
				break
	var _e64 = {"role": "agent", "content": _d40}
	if not _u17.is_empty():
		_e64["thought_signature"] = _u17
	_q81.append(_e64)
	_c83 = _u17
	_c96()
	_h21(_d40, _a79)
	if _d16 and not _i99.is_empty():
		var session_id = _w18._s22() if _w18 else ""
		var _i23 = _d16._a29()
		var _a1 = (not _i23 or _i23.session_id != session_id)
		if _a1 and _q81.size() > 2:
			for i in range(0, _q81.size() - 2, 2):  
				if i + 1 < _q81.size():
					var _u18 = _q81[i]
					var _u14 = _q81[i + 1]
					if _u18.get("role", "") == "user" and _u14.get("role", "") == "agent":
						var _s28 = _u14.get("thought_signature", "")
						var _j62 = _u18.get("original_content", _u18.get("content", ""))
						var _h77 = _u18.get("content", "")
						_d16._u73(_j62, _u14.get("content", ""), session_id, _s28, _h77, "")
		var _f22 = _i99
		var _z18 = _e53 if not _e53.is_empty() else _i99
		var _s29 = _w18._o26() if _w18 else ""
		_d16._u73(_f22, _d40, session_id, _u17, _z18, _s29)
		_d16._t72()
		_i99 = ""  
		_s11()
	_k82()
	_t89.call_deferred()
	_y54.call_deferred(true)
func _b1():
	_n5.text = "Invalid API Key"
	_p33("Your API key is invalid. Please check your settings.")
	_k82()
	_t89.call_deferred()
func _x99(_a6: int, _e13: String):
	var _g22 = _g21(_e13)
	var _p7: String
	if _g22 != _e13:
		_p7 = _g22
	else:
		_p7 = "API Error %d: %s" % [_a6, _e13]
		if _a6 == 400:
			if "custom_rules" in _e13.to_lower():
				_p7 += "\n\nPlease check your custom rules in the Settings tab."
			elif "godot_version" in _e13.to_lower():
				_p7 += "\n\nGodot version detection failed. Try restarting the editor."
		elif _a6 == 422:
			_p7 += "\n\nPlease verify your custom rules and parameter settings."
	_p33(_p7)
	_k82()
	_t89.call_deferred()
func _k55():
	if _w18 and _w18._k71():
		var env = _w18._q98()
		_n5.text = "API Key Saved (%s)!" % env.capitalize()
	else:
		_n5.text = "API Key Saved!"
func _g73():
	_q81.clear()
	_c96()
	_x91()
	for _i64 in _k19.get_children():
		_i64.queue_free()
	_e7()
	_d47()
	_j85.visible = false
	_f11 = 0
	_g24.text = "Total Token Usage for this chat: 0"
	if _d16:
		_d16._f20()
		_d16._t72()
		_s11()
	if _w18:
		_w18._m1()
	_t89.call_deferred()
func _t89():
	await get_tree().process_frame
	_f1.get_v_scroll_bar().value = _f1.get_v_scroll_bar().max_value
func _r89(_h35: int, _o76: int, _r52: int):
	_f11 += _r52
	if _w18 and _w18._k71():
		_f44.text = "P: %d" % _h35
		_h94.text = "C: %d" % _o76
		_x73.text = "T: %d" % _r52
		_g24.text = "Total Token Usage for this chat: %d" % _f11
		_j85.visible = true
	else:
		_j85.visible = false
		_g24.visible = false
	_t89.call_deferred()
func _g69(success: bool):
	if success:
		pass
	else:
		pass
func _r93(_c25: bool):
	_x13.secret = not _c25
func _k13():
	Input.set_default_cursor_shape(Input.CURSOR_VSIZE)
func _o6():
	if not _t29:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
func _f8(_v53: InputEvent):
	if _v53 is InputEventMouseButton:
		if _v53.button_index == MOUSE_BUTTON_LEFT:
			if _v53.pressed:
				_t29 = true
				_e17 = _z28.get_global_mouse_position()
				_u12 = _g79.custom_minimum_size.y
			else:
				_t29 = false
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	elif _v53 is InputEventMouseMotion and _t29:
		var _i82 = _z28.get_global_mouse_position()
		var _x92 = _i82.y - _e17.y
		var _t1 = clamp(_u12 + _x92, 40.0, 600.0)
		_g79.custom_minimum_size.y = _t1
func _n62(text: String) -> String:
	var _a62: PackedStringArray = text.split("\n")
	for i in range(_a62.size()):
		var line: String = _a62[i]
		var _l35: int = 0
		for _c28 in line:
			if _c28 == ' ':
				_l35 += 1
			else:
				break
		var _z37: int = _l35 / 4
		if _z37 > 0:
			_a62[i] = "\t".repeat(_z37) + line.lstrip(" ")
	return "\n".join(_a62)
func _k82():
	_g79.editable = true
	_x96.disabled = false
	_g59 = false
	_d85.visible = false
func _z73(text: String) -> PackedStringArray:
	var _s2 = RegEx.new()
	_s2.compile("[A-Z][a-zA-Z0-9]+")
	var _e14 = _s2.search_all(text)
	var _u8: PackedStringArray = []
	for _n37 in _e14:
		_u8.append(_n37.get_string())
	return _u8
func _f48(_z47: String) -> String:
	if not ClassDB.class_exists(_z47):
		return ""
	var _q35 := ""
	var _n2 = ClassDB.class_get_method_list(_z47)
	if _n2.size() > 0:
		_q35 = "Class: " + _z47 + "\n"
	return _q35
func _y68(user_prompt: String) -> String:
	if user_prompt.strip_edges().begins_with("@explain"):
		return _c37(user_prompt)
	if not _x93(user_prompt):
		return user_prompt
	var _u8 = _z73(user_prompt)
	if _u8.is_empty():
		return user_prompt
	var _v25 = "Godot Editor Context:\n"
	for _r65 in _u8:
		var _q35 = _f48(_r65)
		if not _q35.is_empty():
			_v25 += _q35 + "\n"
	if _v25 == "Godot Editor Context:\n":
		return user_prompt
	var _g28 = _v25 + "\nUser Question: " + user_prompt
	return _g28
func _p14(user_prompt: String) -> Dictionary:
	var _n37 = {}
	var _t23 = RegEx.new()
	_t23.compile("@explain\\s+([a-zA-Z_][a-zA-Z0-9_]*)")
	var _u20 = _t23.search(user_prompt)
	var function_name = ""
	if _u20:
		function_name = _u20.get_string(1)
		_n37["function_name"] = function_name
	var _i68 = RegEx.new()
	_i68.compile("```(?:gdscript)?\n([^`]+?)```")
	var _n18 = _i68.search(user_prompt)
	if _n18:
		var _w94 = _n18.get_string(1).strip_edges()
		_n37["function_context"] = _w94
	return _n37
func _c37(user_prompt: String) -> String:
	var _t23 = RegEx.new()
	_t23.compile("@explain\\s+([a-zA-Z_][a-zA-Z0-9_]*)")
	var _n37 = _t23.search(user_prompt)
	var function_name = ""
	if _n37:
		function_name = _n37.get_string(1)
	var _a30 = "Please explain this GDScript function"
	if not function_name.is_empty():
		_a30 += " called '%s'" % function_name
	_a30 += ". Focus on:\n"
	_a30 += "- What the function does (purpose and behavior)\n"
	_a30 += "- How to use it (parameters and return value)\n"
	_a30 += "- Any important implementation details\n"
	_a30 += "- Potential improvements or best practices\n\n"
	_a30 += user_prompt.replace("@explain %s" % function_name, "").strip_edges()
	return _a30
func _i71(user_prompt: String) -> String:
	if _n78 == null:
		return user_prompt
	var _a50 = _n78._w35(user_prompt)
	var commands = _a50.get("commands", [])
	var cleaned_prompt = _a50.get("cleaned_prompt", user_prompt)
	for _y59 in commands:
		if _y59.get("type", "") == "error":
			var _w11 = _y59.get("error", "Unknown error")
			if "path traversal" in _w11.to_lower() or "not allowed" in _w11.to_lower() or "blocked" in _w11.to_lower():
				_p33("⚠️ Security: " + _w11)
				return ""
			else:
				_p33("⚠️ " + _w11)
				return ""
	if commands.is_empty():
		return user_prompt
	var _x88: Array[String] = []
	for _y59 in commands:
		var _g82 = _y59.get("type", "")
		match _g82:
			"file":
				var path = _y59.get("path", "")
				if not path.is_empty():
					_x88.append("File: " + path)
			"selection":
				var _s100 = _y59.get("script_path", "")
				var _t56 = _y59.get("line_start", 0)
				var _i92 = _y59.get("line_end", 0)
				if (_s100.is_empty() or not _s100.begins_with("res://")) and _n78:
					var _x60 = _n78._m29()
					if _x60.get("success", false):
						_s100 = _x60.get("path", "")
						_t56 = _x60.get("start_line", 0)
						_i92 = _x60.get("end_line", 0)
				if not _s100.is_empty() and _s100.begins_with("res://"):
					_x88.append("Selection in %s (lines %d-%d)" % [_s100, _t56, _i92])
			"openscript":
				var path = _y59.get("path", "")
				if path.is_empty() or not path.begins_with("res://"):
					if _n78:
						var _o73 = _n78.get_current_script()
						if _o73.get("success", false):
							path = _o73.get("path", "")
				if not path.is_empty() and path.begins_with("res://"):
					_x88.append("Open script: " + path)
			"scene":
				var path = _y59.get("path", "")
				if not path.is_empty():
					_x88.append("Scene: " + path)
			"node":
				var node_path = _y59.get("node_path", "")
				if not node_path.is_empty():
					_x88.append("Node: " + node_path)
	if _x88.is_empty():
		return cleaned_prompt
	var _h9 = "\n\n[Referenced files - use read_file to access]:\n- " + "\n- ".join(_x88)
	return cleaned_prompt + _h9
func _w20(user_prompt: String, _k39: bool = false) -> Dictionary:
	if _n78 == null or _w54 == null:
		return {"processed_prompt": user_prompt, "context_metadata": null}
	var _a50 = _n78._w35(user_prompt)
	var commands = _a50.get("commands", [])
	var cleaned_prompt = _a50.get("cleaned_prompt", user_prompt)
	if _k39:
		_c95(commands)
		for _y59 in commands:
			if _y59.get("type", "") == "openscript":
				var snapshot_id = _y59.get("snapshot_id", "")
				if snapshot_id != "" and _y6.has(snapshot_id):
					_y6[snapshot_id]["sent_in_conversation"] = true
	var _a15 = _g74(commands)
	var _b41 = _a11(_a15)
	if not _b41.is_empty():
		var _h26 = []
		_h26.append_array(_b41)
		_h26.append_array(commands)
		commands = _h26
	var _y77 = []
	for _y59 in commands:
		if _y59.get("type", "") == "error":
			var _w11 = _y59.get("error", "Unknown error")
			if _w11.begins_with("Security:"):
				_y77.append("⚠️ " + _w11)
			elif "path traversal" in _w11.to_lower() or "not allowed" in _w11.to_lower() or "blocked" in _w11.to_lower():
				_y77.append("⚠️ Security: " + _w11)
			else:
				_y77.append("⚠️ " + _w11)
	if not _y77.is_empty():
		var _x89 = "\n".join(_y77)
		_p33(_x89)
		return {"processed_prompt": "", "context_metadata": null}
	if commands.is_empty():
		return {"processed_prompt": user_prompt, "context_metadata": null}
	var _l58 = _w54._e86(cleaned_prompt, commands)
	var _h42 = _w54._g39(_l58)
	if not _h42.get("valid", false):
		var _k48 = _h42.get("message", "Unknown validation error")
		_p33("Context too large: " + _k48)
		return {"processed_prompt": "", "context_metadata": null}
	var context_metadata = _r51(commands, _h42.get("estimated_tokens", 0))
	if OS.is_debug_build() and context_metadata:
		pass
	return {"processed_prompt": _l58, "context_metadata": context_metadata}
func _c95(commands: Array) -> void:
	if commands.is_empty():
		return
	var _a47 = false
	for _y59 in commands:
		if _y59.get("type", "") != "openscript":
			continue
		var snapshot_id = _y59.get("snapshot_id", "")
		if snapshot_id == "":
			snapshot_id = _a57()
			_y59["snapshot_id"] = snapshot_id
		var _s100 = _y59.get("path", "")
		var _y92 = _y59.get("content", "")
		if _y92 == "" and _n78:
			var _o73 = _n78.get_current_script()
			if _o73.get("success", false):
				_y92 = _o73.get("content", "")
				_y59["content"] = _y92
				if _s100 == "":
					_s100 = _o73.get("path", "")
					_y59["path"] = _s100
		if _y92 == "":
			continue
		if _s100 == "":
			_s100 = "current_script.gd"
			_y59["path"] = _s100
		_y6[snapshot_id] = {
			"path": _s100,
			"content": _y92,
			"size_bytes": _y92.length(),
			"created_at": _y59.get("created_at", Time.get_unix_time_from_system()),
			"sent_in_conversation": false  
		}
		if not _a54.has(snapshot_id):
			_a54.append(snapshot_id)
		_a47 = true
	if _a47:
		_n23()
func _g74(commands: Array) -> PackedStringArray:
	var _q69 = PackedStringArray()
	for _y59 in commands:
		if _y59.get("type", "") != "openscript":
			continue
		var snapshot_id = _y59.get("snapshot_id", "")
		if snapshot_id != "":
			_q69.append(snapshot_id)
	return _q69
func _a11(_w98: PackedStringArray = PackedStringArray()) -> Array:
	var commands: Array = []
	for snapshot_id in _a54:
		if _w98.has(snapshot_id):
			continue
		if not _y6.has(snapshot_id):
			continue
		var _x74 = _y6[snapshot_id]
		if _x74.get("sent_in_conversation", false):
			continue
		var _y59 = {
			"type": "openscript",
			"snapshot_id": snapshot_id,
			"path": _x74.get("path", ""),
			"content": _x74.get("content", "")
		}
		commands.append(_y59)
	return commands
func _c84(_y59: Dictionary) -> Dictionary:
	var _s100 = _y59.get("path", "")
	var _y92 = _y59.get("content", "")
	var snapshot_id = _y59.get("snapshot_id", "")
	if snapshot_id != "" and _y6.has(snapshot_id):
		var _w55 = _y6[snapshot_id]
		if _s100 == "":
			_s100 = _w55.get("path", "")
		if _y92 == "":
			_y92 = _w55.get("content", "")
	return {
		"path": _s100,
		"content": _y92,
		"snapshot_id": snapshot_id
	}
func _a57() -> String:
	_k41 += 1
	return "panel_openscript_%d_%d" % [Time.get_ticks_msec(), _k41]
func _x91() -> void:
	_y6.clear()
	_a54.clear()
	_k41 = 0
	_n23()
func _n23() -> void:
	if _d16:
		_d16._g1(_y6, _a54)
func _r51(commands: Array, _x64: int) -> Dictionary:
	var _n52 = []
	var _j83 = 0
	for _y59 in commands:
		var _j19 = {}
		var _g82 = _y59.get("type", "unknown")
		_j19["type"] = _g82
		match _g82:
			"file":
				_j19["path"] = _y59.get("path", "")
				if _y59.get("start_line", -1) > 0:
					_j19["start_line"] = _y59.get("start_line", 0)
				if _y59.get("end_line", -1) > 0:
					_j19["end_line"] = _y59.get("end_line", 0)
				if _y59.get("symbol", "") != "":
					_j19["symbol"] = _y59.get("symbol", "")
				if _n78:
					var _b7 = _n78._s65(_y59)
					if _b7.get("success", false):
						var _a12 = _b7.get("content", "").length()
						_j19["size_bytes"] = _a12
						_j83 += _a12
			"scene":
				_j19["path"] = _y59.get("path", "")
				if _y59.get("node_path", "") != "":
					_j19["node_path"] = _y59.get("node_path", "")
				if _y59.get("include_scripts", false):
					_j19["include_scripts"] = true
				var _e15 = 500  
				if _y59.get("include_scripts", false):
					_e15 += 2000  
				_j19["size_bytes"] = _e15
				_j83 += _e15
			"node":
				_j19["node_path"] = _y59.get("node_path", "")
				var _e15 = 200  
				_j19["size_bytes"] = _e15
				_j83 += _e15
			"selection":
				if _n78:
					var _x60 = _n78._m29()
					if _x60.get("success", false):
						var _a12 = _x60.get("content", "").length()
						_j19["size_bytes"] = _a12
						_j83 += _a12
						var _e100 = _x60.get("path", "")
						if _e100 != "":
							_j19["path"] = _e100
						var _b31 = _x60.get("start_line", 0)
						if _b31 > 0:
							_j19["start_line"] = _b31
						var _a78 = _x60.get("end_line", 0)
						if _a78 > 0:
							_j19["end_line"] = _a78
			"openscript":
				var _c8 = _c84(_y59)
				var _y92 = _c8.get("content", "")
				var _s100 = _c8.get("path", "")
				var snapshot_id = _c8.get("snapshot_id", "")
				if _y92 != "":
					var _a12 = _y92.length()
					_j19["size_bytes"] = _a12
					_j83 += _a12
				if _s100 != "":
					_j19["path"] = _s100
				if snapshot_id != "":
					_j19["snapshot_id"] = snapshot_id
		_n52.append(_j19)
	var _e71 = {
		"commands": _n52,
		"total_context_size": _j83,
		"command_count": commands.size(),
		"estimated_tokens": _x64
	}
	if _w18 and not _w18._s22().is_empty():
		_e71["session_id"] = _w18._s22()
	return _e71
func _x93(user_prompt: String) -> bool:
	var _f91 = [
		"CharacterBody2D", "RigidBody2D", "StaticBody2D", "Area2D",
		"Node2D", "Node3D", "Control", "Panel", "Button", "Label",
		"AnimationPlayer", "AnimationTree", "TileMap", "PackedScene",
		"Resource", "RefCounted", "Object", "Variant",
		"Vector2", "Vector3", "Transform2D", "Transform3D",
		"InputEvent", "Camera2D", "Camera3D", "CollisionShape2D"
	]
	var _n73 = user_prompt.to_lower()
	for _a45 in _f91:
		if _n73.find(_a45.to_lower()) != -1:
			return true
	return false
func _k22(code: String) -> String:
	var _s97 = ""
	var _a62 = code.split("\n")
	var _o38 = RegEx.new()
	_o38.compile("\\b(" + "|".join(_u46) + ")\\b")
	var _m62 = RegEx.new()
	_m62.compile("(?<!#)\\b(Vector2|Input|Node2D|Control|CharacterBody2D|[A-Z][a-zA-Z0-9]*)\\b")
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
func _r64(text: String):
	var _q63 = PanelContainer.new()
	_q63.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_q63.add_theme_constant_override("margin_bottom", _i12.message_gap)
	if not _m95:
		_c77()
	_q63.add_theme_stylebox_override("panel", _m95)
	var _n70 = VBoxContainer.new()
	_n70.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_n70.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var _q10 = Label.new()
	_q10.text = "You:"
	_q10.add_theme_color_override("font_color", _q74)
	var _p77 = get_theme_font_size("font_size", "Label")
	_q10.add_theme_font_size_override("font_size", int(_p77 * 1.15))
	_n70.add_child(_q10)
	var _h64 = Control.new()
	_h64.custom_minimum_size.y = 6
	_n70.add_child(_h64)
	var _i90 = ColorRect.new()
	_i90.custom_minimum_size.y = 1
	_i90.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_i90.color = _q74
	_i90.color.a = 0.5
	_n70.add_child(_i90)
	var _s17 = Control.new()
	_s17.custom_minimum_size.y = 6
	_n70.add_child(_s17)
	var _l42 = RichTextLabel.new()
	_l42.bbcode_enabled = true
	_l42.selection_enabled = true
	_l42.text = _g43(text)
	_l42.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_l42.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_l42.fit_content = true
	_l42.scroll_active = false
	_l42.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_l42.add_theme_color_override("default_color", _q74)
	_n70.add_child(_l42)
	_q63.add_child(_n70)
	_k19.add_child(_q63)
func _h21(text: String, _a79: Array = []):
	var _q63 = PanelContainer.new()
	_q63.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_q63.add_theme_constant_override("margin_bottom", _i12.message_gap)
	if not _n95:
		_c77()
	_q63.add_theme_stylebox_override("panel", _n95)
	var _n70 = VBoxContainer.new()
	_n70.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_n70.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_n70.add_theme_constant_override("separation", 4)
	var _q10 = Label.new()
	_q10.text = "GDSense:"
	_q10.add_theme_color_override("font_color", _u85)
	var _p77 = get_theme_font_size("font_size", "Label")
	_q10.add_theme_font_size_override("font_size", int(_p77 * 1.15))
	_n70.add_child(_q10)
	var _h64 = Control.new()
	_h64.custom_minimum_size.y = 6
	_n70.add_child(_h64)
	var _i90 = ColorRect.new()
	_i90.custom_minimum_size.y = 1
	_i90.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_i90.color = _u85
	_i90.color.a = 0.5
	_n70.add_child(_i90)
	var _s17 = Control.new()
	_s17.custom_minimum_size.y = 6
	_n70.add_child(_s17)
	_c74(text, _n70)
	if _a79.size() > 0:
		_h17(_a79, _n70)
	if _w18:
		var _l1 = _w18._q56()
		if not _l1.is_empty():
			_s19(_n70)
		else:
			pass
	_q63.add_child(_n70)
	_k19.add_child(_q63)
func _c74(text: String, parent: Node):
	var _i68 = RegEx.new()
	_i68.compile("```([a-zA-Z]*)\n([^`]+?)```")
	var _r53 = 0
	var _i38 = _i68.search_all(text)
	for match in _i38:
		var _e65 = text.substr(_r53, match.get_start() - _r53)
		if not _e65.strip_edges().is_empty():
			_g93(_e65.strip_edges(), parent)
		var language = match.get_string(1).to_lower()
		if language.is_empty():
			language = "gdscript"  
		var code = match.get_string(2)
		_t94(code, language, parent)
		_r53 = match.get_end()
	if _r53 < text.length():
		var _h96 = text.substr(_r53)
		if not _h96.strip_edges().is_empty():
			_g93(_h96.strip_edges(), parent)
func _g93(text: String, parent: Node):
	var _e63 = text.strip_edges()
	_e63 = _e63.replace("**", "")
	var _s91 = RegEx.new()
	_s91.compile("`([^`]+)`")
	var _e87 = _s91.search_all(_e63)
	if _e87:
		for i in range(_e87.size() - 1, -1, -1):
			var _m30 = _e87[i]
			var full_match = _m30.get_string(0)
			var content = _m30.get_string(1)
			var _i31 = _g43(content)
			var _r2 = "[i]" + _i31 + "[/i]"
			_e63 = _e63.substr(0, _m30.get_start()) + _r2 + _e63.substr(_m30.get_end())
	var _h14 = RegEx.new()
	_h14.compile("'([A-Za-z0-9_\\-\\.]+)'")
	var _h51 = _h14.search_all(_e63)
	if _h51:
		for i in range(_h51.size() - 1, -1, -1):
			var _m30 = _h51[i]
			var full_match = _m30.get_string(0)
			var content = _m30.get_string(1)
			var _i31 = _g43(content)
			var _r2 = "[i]" + _i31 + "[/i]"
			_e63 = _e63.substr(0, _m30.get_start()) + _r2 + _e63.substr(_m30.get_end())
	var _n51 = "___SAFE_ITALIC_START___"
	var _u91 = "___SAFE_ITALIC_END___"
	_e63 = _e63.replace("[i]", _n51)
	_e63 = _e63.replace("[/i]", _u91)
	if _e63.begins_with("Explanation:") or _e63.begins_with("To use this:") or _e63.begins_with("To make this work:"):
		var _c93 = _e63.split(":", true, 1)
		if _c93.size() > 1:
			_e63 = "[b]" + _g43(_c93[0]) + ":[/b]" + _g43(_c93[1])
	var _a62 = _e63.split("\n")
	var _m91 = []
	var _h72 = RegEx.new()
	_h72.compile("^(#{1,4})\\s+(.+)$")
	var _t96 = RegEx.new()
	_t96.compile("^\\|\\s*[-:]+\\s*(\\|\\s*[-:]+\\s*)+\\|\\s*$")
	var _q20: Array = []  
	var _s4 = false
	var _v33 = func():
		if _m91.is_empty():
			return
		var _i86 = "\n".join(_m91)
		_i86 = _i86.replace(_n51, "[i]")
		_i86 = _i86.replace(_u91, "[/i]")
		if _i86.strip_edges().is_empty():
			_m91.clear()
			return
		var _a87 = RichTextLabel.new()
		_a87.bbcode_enabled = true
		_a87.selection_enabled = true
		_a87.text = _i86
		_a87.add_theme_constant_override("line_separation", 6)
		_a87.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_a87.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_a87.fit_content = true
		_a87.scroll_active = false
		_a87.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		_a87.add_theme_color_override("default_color", _u85)
		parent.add_child(_a87)
		_m91.clear()
	var _x11 = func():
		if _q20.is_empty():
			return
		_v33.call()
		var _d4 = 0
		for _p52 in _q20:
			if _p52.size() > _d4:
				_d4 = _p52.size()
		if _d4 == 0:
			_q20.clear()
			_s4 = false
			return
		var _j16 = MarginContainer.new()
		_j16.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_j16.add_theme_constant_override("margin_top", 8)
		_j16.add_theme_constant_override("margin_bottom", 12)
		var _a9 = PanelContainer.new()
		_a9.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var _x28 = StyleBoxFlat.new()
		_x28.bg_color = Color(0.15, 0.15, 0.18, 1.0)
		_x28.set_corner_radius_all(6)
		_x28.set_content_margin_all(12)
		_a9.add_theme_stylebox_override("panel", _x28)
		var _h55 = VBoxContainer.new()
		_h55.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_h55.add_theme_constant_override("separation", 0)
		var _v92 = GridContainer.new()
		_v92.columns = _d4
		_v92.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_v92.add_theme_constant_override("h_separation", 24)
		var _a22 = GridContainer.new()
		_a22.columns = _d4
		_a22.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_a22.add_theme_constant_override("h_separation", 24)
		_a22.add_theme_constant_override("v_separation", 10)
		var _r55 = int(14 * _a17)
		var _c58 = int(15 * _a17)
		for _t17 in range(_q20.size()):
			var _p52 = _q20[_t17]
			for _r14 in range(_d4):
				var _y61 = _p52[_r14] if _r14 < _p52.size() else ""
				_y61 = _y61.replace(_n51, "[i]")
				_y61 = _y61.replace(_u91, "[/i]")
				var _f96 = RichTextLabel.new()
				_f96.bbcode_enabled = true
				_f96.fit_content = true
				_f96.scroll_active = false
				_f96.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				_f96.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
				_f96.add_theme_color_override("default_color", _u85)
				if _t17 == 0 and _s4:
					_f96.add_theme_font_size_override("normal_font_size", _c58)
					_f96.text = "[b][u]" + _y61 + "[/u][/b]"
					_v92.add_child(_f96)
				else:
					_f96.add_theme_font_size_override("normal_font_size", _r55)
					_f96.text = _y61
					_a22.add_child(_f96)
		if _s4:
			_h55.add_child(_v92)
			var _i90 = HSeparator.new()
			_i90.add_theme_constant_override("separation", 8)
			_h55.add_child(_i90)
		_h55.add_child(_a22)
		_a9.add_child(_h55)
		_j16.add_child(_a9)
		parent.add_child(_j16)
		_q20.clear()
		_s4 = false
	for i in range(_a62.size()):
		var line = _a62[i]
		var _o40 = line.strip_edges()
		var _w37 = _t96.search(_o40) != null
		if _w37:
			if not _q20.is_empty():
				_s4 = true
			continue
		var _z85 = _h72.search(_o40)
		if _z85:
			_x11.call()
			var _b15 = _z85.get_string(1).length()
			var _c81 = _z85.get_string(2)
			var _p77 = 24  
			if _b15 == 2:
				_p77 = 20  
			elif _b15 == 3:
				_p77 = 18  
			elif _b15 == 4:
				_p77 = 16  
			var _r55 = int(_p77 * _a17)
			var _b81 = _g43(_c81)
			_m91.append("\n[b][font_size=" + str(_r55) + "]" + _b81 + "[/font_size][/b]\n")
		elif _o40.begins_with("|") and _o40.ends_with("|"):
			var _c49 = _o40.split("|")
			var _e81: Array = []
			for _i45 in _c49:
				var _r67 = _i45.strip_edges()
				if _r67.is_empty():
					continue
				if _r67.match("^-+$") or _r67.match("^:?-+:?$"):
					continue
				_e81.append(_g43(_r67))
			if not _e81.is_empty():
				_q20.append(_e81)
		elif _o40.begins_with("* "):
			_x11.call()
			var _g46 = _o40.substr(2).replace("*", "")
			_m91.append("• " + _g43(_g46))
			if i < _a62.size() - 1 and not _a62[i + 1].strip_edges().begins_with("* "):
				_m91.append("")
		elif _o40.match("^[0-9]+\\."):
			_x11.call()
			_m91.append(_g43(_o40))
		else:
			_x11.call()
			_m91.append(_g43(line.replace("*", "")))
	_x11.call()
	_v33.call()
func _t94(code: String, language: String, parent: Node):
	var _q70 = MarginContainer.new()
	_q70.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_q70.add_theme_constant_override("margin_left", 16)
	_q70.add_theme_constant_override("margin_right", 16)
	_q70.add_theme_constant_override("margin_top", 12)
	_q70.add_theme_constant_override("margin_bottom", 12)
	var _u25 = PanelContainer.new()
	_u25.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not _y33:
		_c77()
	_u25.add_theme_stylebox_override("panel", _y33)
	var _r43 = VBoxContainer.new()
	_r43.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _l48 = PanelContainer.new()
	_l48.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_l48.add_theme_stylebox_override("panel", _b75)
	var _o45 = HBoxContainer.new()
	_o45.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_o45.layout_mode = 2  
	var _f36 = Label.new()
	_f36.layout_mode = 2
	_f36.text = _f15.get(language, "Code")
	_f36.add_theme_color_override("font_color", _e27)
	_o45.add_child(_f36)
	var _p35 = Control.new()
	_p35.layout_mode = 2
	_p35.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_o45.add_child(_p35)
	var _e19 = Button.new()
	_e19.layout_mode = 2
	_e19.text = "Copy"
	_e19.flat = true
	_e19.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_e19.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	_e19.pressed.connect(func(): _b59(code))
	_o45.add_child(_e19)
	_l48.add_child(_o45)
	_r43.add_child(_l48)
	var _u88 = MarginContainer.new()
	_u88.layout_mode = 2
	_u88.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_u88.add_theme_constant_override("margin_left", _i12.code_padding)
	_u88.add_theme_constant_override("margin_right", _i12.code_padding)
	_u88.add_theme_constant_override("margin_top", _i12.code_padding)
	_u88.add_theme_constant_override("margin_bottom", _i12.code_padding)
	var _d25 = RichTextLabel.new()
	_d25.bbcode_enabled = true
	_d25.selection_enabled = true
	_d25.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_d25.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_d25.fit_content = true
	_d25.scroll_active = false
	_d25.scroll_active = false
	var _a10 = _p24("text_color")
	_d25.add_theme_color_override("default_color", _a10)
	var _s97 = _b33(code, language)
	_d25.text = _s97
	var _k31 = SystemFont.new()
	_k31.font_names = ["Consolas", "Courier New", "Monospace"]
	_d25.add_theme_font_override("normal_font", _k31)
	_d25.add_theme_font_override("mono_font", _k31)
	_u88.add_child(_d25)
	_r43.add_child(_u88)
	_u25.add_child(_r43)
	_q70.add_child(_u25)
	parent.add_child(_q70)
func _b33(code: String, language: String) -> String:
	match language:
		"gdscript", "":
			return _k22(_n62(code))
		"csharp", "cs":
			return _s74(code)
		_:
			return code
func _b59(code: String):
	DisplayServer.clipboard_set(code)
func _s74(code: String) -> String:
	var _s97 = ""
	var _a62 = code.split("\n")
	var _o38 = RegEx.new()
	_o38.compile("\\b(" + "|".join(_h8) + ")\\b")
	var _m62 = RegEx.new()
	_m62.compile("\\b([A-Z][a-zA-Z0-9]*)\\b")
	var _v97 = RegEx.new()
	_v97.compile("\\b([a-z_][a-zA-Z0-9_]*)\\s*\\(")
	var _e57 = RegEx.new()
	_e57.compile("(\"[^\"]*\"|'[^']*')")
	var _y41 = RegEx.new()
	_y41.compile("\\b\\d+(\\.\\d+)?[fFdD]?\\b")
	var _l98 = RegEx.new()
	_l98.compile("(//.*$|/\\*.*?\\*/)")
	for line in _a62:
		if line.strip_edges().is_empty():
			_s97 += "\n"
			continue
		var _r98 = line
		_r98 = _l98.sub(_r98, "[color=#%s]$1[/color]" % [_p24("comment").to_html(false)], true)
		_r98 = _e57.sub(_r98, "[color=#%s]$1[/color]" % [_p24("string").to_html(false)], true)
		_r98 = _o38.sub(_r98, "[color=#%s]$1[/color]" % [_p24("keyword").to_html(false)], true)
		_r98 = _m62.sub(_r98, "[color=#%s]$1[/color]" % [_p24("class").to_html(false)], true)
		_r98 = _v97.sub(_r98, "[color=#%s]$1[/color](" % [_p24("function").to_html(false)], true)
		_r98 = _y41.sub(_r98, "[color=#%s]$0[/color]" % [_p24("number").to_html(false)], true)
		_s97 += _r98 + "\n"
	return _s97.strip_edges()
func _p33(text: String):
	var _q63 = PanelContainer.new()
	_q63.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_q63.add_theme_constant_override("margin_bottom", _i12.message_gap)
	var _b46 = Color("#ff6666")
	if _o10:
		var theme = _o10.get_editor_theme()
		if theme:
			_b46 = theme.get_color("error_color", "Editor")
	var _j80 = StyleBoxFlat.new()
	_j80.bg_color = _b46.darkened(0.8)
	_j80.border_color = _b46
	_j80.border_width_bottom = 1
	_j80.border_width_top = 1
	_j80.border_width_left = 1
	_j80.border_width_right = 1
	_j80.corner_radius_top_left = 8
	_j80.corner_radius_top_right = 8
	_j80.corner_radius_bottom_left = 8
	_j80.corner_radius_bottom_right = 8
	_j80.content_margin_left = _i12.padding
	_j80.content_margin_right = _i12.padding
	_j80.content_margin_top = _i12.padding
	_j80.content_margin_bottom = _i12.padding
	_q63.add_theme_stylebox_override("panel", _j80)
	var _n70 = VBoxContainer.new()
	_n70.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_n70.layout_mode = 2  
	var _u26 = _b46.lightened(0.3)  
	var _m44 = Color(1.0, 0.9, 0.9)  
	var _t65 = Label.new()
	_t65.text = "GDSense Error"
	_t65.add_theme_color_override("font_color", _u26)
	_t65.add_theme_font_size_override("font_size", 16)
	_n70.add_child(_t65)
	var _l42 = Label.new()
	_l42.text = text
	_l42.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_l42.add_theme_color_override("font_color", _m44)
	_n70.add_child(_l42)
	_q63.add_child(_n70)
	_k19.add_child(_q63)
func _e7():
	var _q63 = PanelContainer.new()
	_q63.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_q63.add_theme_constant_override("margin_bottom", _i12.message_gap)
	if not _n95:
		_c77()
	_q63.add_theme_stylebox_override("panel", _n95)
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.selection_enabled = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.fit_content = true
	label.scroll_active = false
	label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	label.add_theme_color_override("default_color", _f87("font_color"))
	label.text = "[b]Welcome to GDSense![/b] Your AI coding partner for Godot."
	_q63.add_child(label)
	_k19.add_child(_q63)
func _o3(text: String):
	if text.strip_edges().is_empty():
		return
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.selection_enabled = true
	label.text = _g43(text)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.fit_content = true
	label.scroll_active = false
	label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	label.add_theme_color_override("default_color", _u85)
	_k19.add_child(label)
func _q62() -> void:
	_q66 = OptionButton.new()
	_q66.name = "AgentModelSelector"
	_o20()
	_q66.visible = false  
	_q66.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _h34:
		var _p4 = _h34.get_parent()
		if _p4:
			var _z33 = _p4.get_children().find(_h34)
			_p4.add_child(_q66)
			_p4.move_child(_q66, _z33)
func _u7():
	_l4.clear()
	_h34.clear()
	var _o90 = []
	if _w18:
		_o90 = _w18._i20()
	else:
		_o90 = [
			"openai/gpt-oss-20b",
			"gemini-2.5-flash-lite",
			"gpt-5-nano"
		]
	for _c32 in _o90:
		var _m86: String
		var _t16: String
		if _c32 is Dictionary and _c32.has("id"):
			_t16 = _c32.get("id", "")
			_m86 = _c32.get("display_name", _t16)
		else:
			_t16 = str(_c32)
			_m86 = _t42.get(_t16, _t16)
		_l4.add_item(_m86)
		_h34.add_item(_m86)
	if _w18:
		var _d64 = _w18._o26()
		if _k4(_d64, _o90):
			_n74(_d64)
		else:
			if _o90.size() > 0:
				var _c72 = _b21(_o90[0])
				_n74(_c72)
				_w18._j66(_c72)
	_r41()
func _b21(_c32) -> String:
	if _c32 is Dictionary and _c32.has("id"):
		return _c32.get("id", "")
	return str(_c32)
func _k4(_t16: String, _o90: Array) -> bool:
	for _c32 in _o90:
		var _m38 = _b21(_c32)
		if _m38 == _t16:
			return true
	return false
func _r41():
	pass
func _g11(index: int) -> String:
	match index:
		0: 
			return "Fast open source model (1000 tps) optimized for quick tasks."
		1: 
			return "Optimized for speed and simple tasks."
		2: 
			return "Lightning-fast GPT-5 for quick tasks."
		3: 
			return "Powerful open source model for detailed tasks."
		4: 
			return "Advanced reasoning for complex problems."
		5: 
			return "Compact codex model optimized for code generation."
		6: 
			return "Fast Kimi K2 model for coding assistance."
		7: 
			return "Kimi K2 with extended thinking for complex tasks."
		8: 
			return "High-capability Gemini model for complex reasoning."
		9: 
			return "Full GPT-5.1 Codex for advanced code generation."
		_:
			return "AI model for Godot development assistance."
func _n76(index: int) -> void:
	var _o90 = []
	if _w18:
		_o90 = _w18._i20()
	if index < 0 or index >= _o90.size():
		return
	var _t16 = _b21(_o90[index])
	if _w18:
		_w18._j66(_t16)
	_l4.selected = index
	_h34.selected = index
	_y54(true)
func _n74(model: String) -> void:
	var _o90 = []
	if _w18:
		_o90 = _w18._i20()
	for i in range(_o90.size()):
		var _m38 = _b21(_o90[i])
		if _m38 == model:
			_l4.selected = i
			_h34.selected = i
			return
	_l4.selected = 0
	_h34.selected = 0
func _m9():
	if not _w18 or not _w18._k71():
		return
	_p70 = HBoxContainer.new()
	_p70.add_theme_constant_override("separation", 10)
	_v23 = Label.new()
	_v23.text = "Environment:"
	_p70.add_child(_v23)
	_b29 = OptionButton.new()
	_b29.add_item("Production")
	_b29.add_item("Development (localhost:8080)")
	var _d18 = _w18._q98() if _w18 else "production"
	if _d18 == "development":
		_b29.selected = 1
	else:
		_b29.selected = 0
	_b29.item_selected.connect(_x79)
	_p70.add_child(_b29)
	var _z77 = Label.new()
	_z77.text = "[DEV MODE]"
	_z77.modulate = Color(1, 0.5, 0.5)
	_p70.add_child(_z77)
	var _c23 = _x13.get_parent()
	var parent = _c23.get_parent()
	var index = parent.get_children().find(_c23)
	parent.add_child(_p70)
	parent.move_child(_p70, index + 1)
func _o20() -> void:
	if not _q66:
		return
	_q66.clear()
	var _o90 = []
	if _w18:
		_o90 = _w18._w9()
	if _o90.size() > 0 and _o90[0] is Dictionary and _o90[0].has("id"):
		for _c32 in _o90:
			var _m86 = _c32.get("display_name", _c32.get("id", "Unknown"))
			_q66.add_item(_m86)
	else:
		for _t81 in _j51:
			_q66.add_item(_t81["name"])
	_q66.selected = 0  
func _e29() -> String:
	if not _q66:
		return ""
	var _k17 = _q66.selected
	if _k17 < 0:
		return ""
	var _o90 = []
	if _w18:
		_o90 = _w18._w9()
	if _o90.size() > 0 and _o90[0] is Dictionary and _o90[0].has("id"):
		if _k17 < _o90.size():
			return _o90[_k17].get("id", "")
	else:
		if _k17 < _j51.size():
			return _j51[_k17]["id"]
	return ""
func _x79(index: int):
	var _a4 = ["production", "development"][index]
	var _b22 = ""
	if _w18:
		_w18._o30(_a4)
		_b22 = _w18._a82()
		_x13.text = _b22
	if _b22.is_empty():
		_n5.text = "No API Key (%s)" % _a4.capitalize()
	else:
		_n5.text = "API Key Loaded (%s)" % _a4.capitalize()
func _u11():
	if not _r57:
		return
	var _i90 = HSeparator.new()
	_r57.add_child(_i90)
	var _d59 = VBoxContainer.new()
	_d59.add_theme_constant_override("separation", 5)
	_r57.add_child(_d59)
	var _v28 = Label.new()
	_v28.text = "Ghost Text Autocomplete"
	_v28.add_theme_font_size_override("font_size", int(20 * _a17))
	_d59.add_child(_v28)
	_p44 = CheckBox.new()
	_p44.text = "Enable Autocomplete"
	_p44.button_pressed = true  
	_p44.toggled.connect(_e97)
	_d59.add_child(_p44)
	var _g83 = HBoxContainer.new()
	_g83.layout_mode = 2
	_d59.add_child(_g83)
	var _r29 = Label.new()
	_r29.text = "Trigger Mode:"
	_r29.custom_minimum_size.x = 150
	_g83.add_child(_r29)
	_x100 = OptionButton.new()
	_x100.layout_mode = 2
	_x100.add_item("Automatic")
	_x100.add_item("Manual (Ctrl+Space)")
	_x100.selected = 0
	_x100.item_selected.connect(_m56)
	_g83.add_child(_x100)
	var _r38 = HBoxContainer.new()
	_r38.layout_mode = 2
	_d59.add_child(_r38)
	var _z48 = Label.new()
	_z48.text = "Minimum Characters:"
	_z48.custom_minimum_size.x = 150
	_r38.add_child(_z48)
	_v17 = SpinBox.new()
	_v17.layout_mode = 2
	_v17.min_value = 1
	_v17.max_value = 10
	_v17.value = 3
	_v17.step = 1
	_v17.value_changed.connect(_z50)
	_r38.add_child(_v17)
	var _h37 = Label.new()
	_h37.text = "Smart triggers: After '.', '(', ':', '=', or space following keywords"
	_h37.layout_mode = 2
	var _m83 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_h37.add_theme_color_override("font_color", Color(_m83, 0.6))
	_h37.set_meta("secondary", true)
	_h37.add_theme_font_size_override("font_size", 12)
	_h37.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d59.add_child(_h37)
	var _p83 = HSeparator.new()
	_d59.add_child(_p83)
	var _d73 = HBoxContainer.new()
	_d73.layout_mode = 2
	_d59.add_child(_d73)
	var _n59 = Label.new()
	_n59.text = "Inline Explain Buttons"
	_n59.add_theme_font_size_override("font_size", int(16 * _a17))
	_d73.add_child(_n59)
	_r80 = CheckBox.new()
	_r80.text = "Show Explain Buttons Above Functions"
	_r80.button_pressed = true  
	_r80.toggled.connect(_z61)
	_d59.add_child(_r80)
	var _s32 = Label.new()
	_s32.text = "Adds clickable help icons above function declarations to explain code"
	_s32.layout_mode = 2
	var _g86 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_s32.add_theme_color_override("font_color", Color(_g86, 0.6))
	_s32.set_meta("secondary", true)
	_s32.add_theme_font_size_override("font_size", 12)
	_s32.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d59.add_child(_s32)
	var _c22 = HSeparator.new()
	_d59.add_child(_c22)
	var _x2 = Label.new()
	_x2.text = "Inline Refactor Buttons"
	_x2.add_theme_font_size_override("font_size", int(18 * _a17))
	_d59.add_child(_x2)
	_c21 = CheckBox.new()
	_c21.text = "Show Refactor Buttons Above Functions"
	_c21.button_pressed = true  
	_c21.toggled.connect(_t39)
	_d59.add_child(_c21)
	var _t93 = Label.new()
	_t93.text = "Adds clickable ↻ icons above function declarations for AI-powered refactoring"
	_t93.layout_mode = 2
	var _b28 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_t93.add_theme_color_override("font_color", Color(_b28, 0.6))
	_t93.set_meta("secondary", true)
	_t93.add_theme_font_size_override("font_size", 12)
	_t93.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d59.add_child(_t93)
	var _x77 = HSeparator.new()
	_d59.add_child(_x77)
	_y2(_d59)
	_p12()
func _p12():
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		_p44.button_pressed = config.get_value("autocomplete", "enabled", true)
		var mode = config.get_value("autocomplete", "mode", "automatic")
		_x100.selected = 0 if mode == "automatic" else 1
		_v17.value = config.get_value("autocomplete", "min_chars", 3)
		_r80.button_pressed = config.get_value("explain_button", "enabled", true)
		_c21.button_pressed = config.get_value("refactor_button", "enabled", true)
		var _g70 = find_child("_w33", true)
		var _e40 = find_child("_y97", true)
		var _g6 = find_child("_r69", true)
		if _g70:
			_g70.button_pressed = config.get_value("undo", "enabled", true)
		if _e40:
			_e40.value = config.get_value("undo", "max_history_items", 20)
		if _g6:
			_g6.button_pressed = config.get_value("undo", "show_history_button", true)
func _e47():
	var mode = "automatic" if _x100.selected == 0 else "manual"
	const _r79 = 1000
	const _g33 = 150
	if _r16 and _r16.has_method("save_autocomplete_config"):
		_r16.save_autocomplete_config(
			_p44.button_pressed,
			_r79,
			_g33,
			mode,
			int(_v17.value)
		)
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_api_key.cfg")
		config.set_value("autocomplete", "enabled", _p44.button_pressed)
		config.set_value("autocomplete", "delay_ms", _r79)
		config.set_value("autocomplete", "max_length", _g33)
		config.set_value("autocomplete", "mode", mode)
		config.set_value("autocomplete", "min_chars", int(_v17.value))
		config.save("user://gdsense_api_key.cfg")
func _e97(enabled: bool):
	_e47()
func _m56(index: int):
	_e47()
func _z50(value: float):
	_e47()
func _z61(enabled: bool):
	if _r16 and _r16.has_method("save_explain_button_config"):
		_r16.save_explain_button_config(enabled)
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_api_key.cfg")
		config.set_value("explain_button", "enabled", enabled)
		config.save("user://gdsense_api_key.cfg")
func _t39(enabled: bool):
	if _r16 and _r16.has_method("save_refactor_config"):
		_r16.save_refactor_config(enabled)
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_api_key.cfg")
		config.set_value("refactor_button", "enabled", enabled)
		config.save("user://gdsense_api_key.cfg")
func _y2(_g67: VBoxContainer):
	var _f29 = Label.new()
	_f29.text = "Refactor Undo System"
	_f29.add_theme_font_size_override("font_size", int(18 * _a17))
	_g67.add_child(_f29)
	var _g70 = CheckBox.new()
	_g70.name = "UndoEnabledCheckbox"
	_g70.text = "Enable Undo for Refactored Functions"
	_g70.button_pressed = true  
	_g70.toggled.connect(_m98)
	_g67.add_child(_g70)
	var _t52 = HBoxContainer.new()
	_t52.layout_mode = 2
	_g67.add_child(_t52)
	var _g54 = Label.new()
	_g54.text = "Max History Items:"
	_g54.custom_minimum_size.x = 150
	_t52.add_child(_g54)
	var _e40 = SpinBox.new()
	_e40.name = "MaxHistorySpinbox"
	_e40.layout_mode = 2
	_e40.min_value = 5
	_e40.max_value = 50
	_e40.value = 20
	_e40.step = 1
	_e40.value_changed.connect(_n91)
	_t52.add_child(_e40)
	var _g6 = CheckBox.new()
	_g6.name = "ShowHistoryCheckbox"
	_g6.text = "Show History Button in Panel"
	_g6.button_pressed = true  
	_g6.toggled.connect(_w60)
	_g67.add_child(_g6)
	var _t9 = Label.new()
	_t9.text = "Track refactored functions with visual indicators and one-click undo"
	_t9.layout_mode = 2
	_t9.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_t9.add_theme_font_size_override("font_size", 12)
	_t9.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_g67.add_child(_t9)
func _m98(enabled: bool):
	if _r16 and _r16.has_method("save_undo_config"):
		_r16.save_undo_config(enabled)
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_settings.cfg")
		config.set_value("undo", "enabled", enabled)
		config.save("user://gdsense_settings.cfg")
func _n91(value: float):
	if _r16 and _r16.has_method("save_undo_max_history"):
		_r16.save_undo_max_history(int(value))
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_settings.cfg")
		config.set_value("undo", "max_history_items", int(value))
		config.save("user://gdsense_settings.cfg")
func _w60(enabled: bool):
	if _r16 and _r16.has_method("save_undo_show_history"):
		_r16.save_undo_show_history(enabled)
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_settings.cfg")
		config.set_value("undo", "show_history_button", enabled)
		config.save("user://gdsense_settings.cfg")
func _j99():
	if not _r57:
		return
	var _i90 = HSeparator.new()
	_r57.add_child(_i90)
	var _o50 = VBoxContainer.new()
	_o50.add_theme_constant_override("separation", 10)
	_r57.add_child(_o50)
	var _v64 = Label.new()
	_v64.text = "Custom Instructions"
	_v64.add_theme_font_size_override("font_size", int(20 * _a17))
	_o50.add_child(_v64)
	var _g31 = HBoxContainer.new()
	_o50.add_child(_g31)
	var _v1 = Label.new()
	_v1.text = "Godot Version:"
	_v1.custom_minimum_size.x = 120
	_g31.add_child(_v1)
	var _a76 = Label.new()
	_a76.text = _w18._e35() if _w18 else "Unknown"
	var _q5 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_a76.add_theme_color_override("font_color", Color(_q5, 0.6))
	_a76.set_meta("secondary", true)
	_g31.add_child(_a76)
	var _u3 = HBoxContainer.new()
	_o50.add_child(_u3)
	var _l7 = Label.new()
	_l7.text = "Temperature:"
	_l7.custom_minimum_size.x = 120
	_u3.add_child(_l7)
	var _t25 = SpinBox.new()
	_t25.name = "TemperatureSpinBox"
	_t25.min_value = 0.0
	_t25.max_value = 1.0
	_t25.step = 0.1
	_t25.value = 0.0
	_t25.value_changed.connect(_q84)
	_u3.add_child(_t25)
	var _p98 = Label.new()
	_p98.text = "(0.0 = use default)"
	var _o22 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_p98.add_theme_color_override("font_color", Color(_o22, 0.6))
	_p98.set_meta("secondary", true)
	_p98.add_theme_font_size_override("font_size", 11)
	_u3.add_child(_p98)
	var _v89 = Label.new()
	_v89.text = "Custom Rules (500 char limit):"
	_v89.add_theme_font_size_override("font_size", int(18 * _a17))
	_o50.add_child(_v89)
	_q80 = TextEdit.new()
	_q80.name = "CustomRulesInput"
	_q80.custom_minimum_size = Vector2(0, 100)
	_q80.placeholder_text = "Enter custom rules for AI responses (one per line)..."
	_q80.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_q80.text_changed.connect(_o94)
	_o50.add_child(_q80)
	_u24 = Label.new()
	_u24.name = "CharCounter"
	_u24.text = "0/500"
	_u24.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_u24.add_theme_font_size_override("font_size", 12)
	_u24.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_o50.add_child(_u24)
	_i6 = Label.new()
	_i6.name = "ValidationMessage"
	_i6.text = ""
	_i6.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	_i6.add_theme_font_size_override("font_size", 12)
	_i6.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_i6.visible = false
	_o50.add_child(_i6)
	_f52.call_deferred()
func _r86():
	_d16 = _b86.new()
	_d16._j55()
	if _t11:
		_t11.item_selected.connect(_b71)
	if _n30:
		_n30.item_selected.connect(_d78)
	if _d68:
		_d68.pressed.connect(_s72)
	if _v2:
		_v2.pressed.connect(_f71)
	if _d53:
		_d53.pressed.connect(_v19)
	if _y52:
		_y52.pressed.connect(_a68)
	if _i16:
		_i16.pressed.connect(_v38)
	if _q85:
		_q85.pressed.connect(_u29)
	if _r99:
		_r99.pressed.connect(_l46)
	if _v49:
		_v49.pressed.connect(_o85)
	if _l39:
		_l39.pressed.connect(_t78)
	if _o37:
		_o37.pressed.connect(_p8)
	if _n49:
		_n49.pressed.connect(_k36)
	if _x50:
		_x50.pressed.connect(_r4)
	if _r96:
		_r96.file_selected.connect(_u58)
	if _w26:
		_w26.file_selected.connect(_q31)
	if _d62:
		_d62.confirmed.connect(_v11)
	_r46()
	_s11()
func _r58():
	if _c99:
		_c99.item_selected.connect(_u94)
	_m61()
	var _q30 = _f12()
	var _j28 = _j5()
	_e92.text = "Auto: %.0f%% (%s detected). Your resolution: %dx%d" % [
		_j28 * 100,
		_q30,
		get_viewport().get_visible_rect().size.x,
		get_viewport().get_visible_rect().size.y
	]
	_m20()
func _f12() -> String:
	var _h25 = get_viewport().get_visible_rect().size
	var width = int(_h25.x)
	var height = int(_h25.y)
	if width < 800 or width > 16384 or height < 600 or height > 16384:
		width = 1920
		height = 1080
	var _y24 = 100
	for _z17 in _t35:
		var _o32 = _t35[_z17]
		if abs(width - _o32.width) <= _y24 and abs(height - _o32.height) <= _y24:
			return _z17
	var _d5 = width * height
	var _a56 = "1080p"
	var _p39 = INF
	for _z17 in _t35:
		var _o32 = _t35[_z17]
		var _i76 = _o32.width * _o32.height
		var _e45 = abs(_d5 - _i76)
		if _e45 < _p39:
			_p39 = _e45
			_a56 = _z17
	return _a56
func _j5() -> float:
	var _z17 = _f12()
	return _t35[_z17].scale
func _e76() -> float:
	if _e5 == "auto":
		return _j5()
	else:
		var _i8 = float(_e5)
		_i8 = clamp(_i8, 0.5, 3.0)  
		if is_nan(_i8) or is_inf(_i8):
			_i8 = 1.0  
		return _i8
func _m20():
	_a17 = _e76()
	var _e37 = int(_e33 * _a17)
	var _t77 = get_node_or_null("MarginContainer/TabContainer/History")
	if _t77:
		for label in _y83(_t77):
			if label is Label:
				label.add_theme_font_size_override("font_size", _e37)
			elif label is RichTextLabel:
				label.add_theme_font_size_override("normal_font_size", _e37)
	_o12(_e37)
func _o12(_e37: int):
	var _p26 = get_node_or_null("MarginContainer/TabContainer/Settings/_l13/VBoxContainer")
	if not _p26:
		return
	var _m39 = ["Ghost Text Autocomplete", "Custom Instructions"]
	var _a94 = ["Inline Explain Buttons", "Inline Refactor Buttons", "Refactor Undo System",
					   "Custom Rules", "Parameter Overrides"]
	for _i64 in _y83(_p26):
		if _i64 is Label:
			var _f33 = _i64.text
			var target_size = _e37
			for _l95 in _m39:
				if _f33.begins_with(_l95):
					target_size = int(20 * _a17)
					break
			if target_size == _e37:  
				for _h75 in _a94:
					if _f33.begins_with(_h75):
						target_size = int(18 * _a17)
						break
			_i64.add_theme_font_size_override("font_size", target_size)
		elif _i64 is RichTextLabel:
			_i64.add_theme_font_size_override("normal_font_size", _e37)
func _v83(text: String) -> bool:
	var _o75 = [
		"highest-volume", "smart triggers", "fixed settings", "adds clickable",
		"track refactored", "use default", "auto detects", "char limit",
		"following keywords", "second delay", "token max", "help icons",
		"visual indicators", "one-click undo", "AI-powered"
	]
	for _a45 in _o75:
		if _a45 in text:
			return true
	return false
func _y83(node: Node) -> Array:
	var children = []
	for _i64 in node.get_children():
		children.append(_i64)
		children.append_array(_y83(_i64))
	return children
func _u94(index: int):
	var _i75 = _j68[index]
	if typeof(_i75) == TYPE_STRING and _i75 == "auto":
		_e5 = "auto"
	else:
		_e5 = str(_i75)
	_s68()
	_m20()
	if _e5 == "auto":
		var _q30 = _f12()
		var _j28 = _j5()
		_e92.text = "Auto: %.0f%% (%s detected). Your resolution: %dx%d" % [
			_j28 * 100,
			_q30,
			get_viewport().get_visible_rect().size.x,
			get_viewport().get_visible_rect().size.y
		]
	else:
		_e92.text = "Manual: %.0f%%. Auto detects based on 1080p/1440p/4K presets" % [
			float(_e5) * 100
		]
func _s68():
	var config = ConfigFile.new()
	config.load("user://gdsense_settings.cfg")
	config.set_value("font_scale", "mode", _e5)
	config.save("user://gdsense_settings.cfg")
func _m61():
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		_e5 = config.get_value("font_scale", "mode", "auto")
		if _e5 == "auto":
			_c99.selected = 0
		elif _e5 == "0.8":
			_c99.selected = 1
		elif _e5 == "1.0":
			_c99.selected = 2
		elif _e5 == "1.25":
			_c99.selected = 3
		elif _e5 == "1.5":
			_c99.selected = 4
	else:
		_e5 = "auto"
		_c99.selected = 0
func _s19(parent: Node) -> void:
	var _r50 = HBoxContainer.new()
	_r50.add_theme_constant_override("separation", 10)
	var _p35 = Control.new()
	_p35.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_r50.add_child(_p35)
	var _v14 = Button.new()
	_v14.text = "👍"
	_v14.tooltip_text = "Good response"
	_v14.flat = false  
	_v14.custom_minimum_size = Vector2(36, 36)  
	_v14.add_theme_font_size_override("font_size", 16)
	_v14.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	_v14.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9))
	_v14.add_theme_stylebox_override("normal", _y11())
	_v14.add_theme_stylebox_override("hover", _x9())
	_v14.add_theme_stylebox_override("pressed", _r56())
	_v14.pressed.connect(_g30)
	_m50(_v14)
	_r50.add_child(_v14)
	var _x42 = Button.new()
	_x42.text = "👎"
	_x42.tooltip_text = "Poor response"
	_x42.flat = false  
	_x42.custom_minimum_size = Vector2(36, 36)  
	_x42.add_theme_font_size_override("font_size", 16)
	_x42.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	_x42.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9))
	_x42.add_theme_stylebox_override("normal", _y11())
	_x42.add_theme_stylebox_override("hover", _x9())
	_x42.add_theme_stylebox_override("pressed", _r56())
	_x42.pressed.connect(_f88)
	_m50(_x42)
	_r50.add_child(_x42)
	parent.add_child(_r50)
func _y11() -> StyleBoxFlat:
	var _p1 = StyleBoxFlat.new()
	_p1.bg_color = Color(0, 0, 0, 0)  
	_p1.set_corner_radius_all(4)
	return _p1
func _x9() -> StyleBoxFlat:
	var _p1 = StyleBoxFlat.new()
	_p1.bg_color = Color(0.3, 0.3, 0.3, 0.3)  
	_p1.set_corner_radius_all(6)
	_p1.set_border_width_all(1)
	_p1.border_color = Color(0.5, 0.5, 0.5, 0.5)
	return _p1
func _r56() -> StyleBoxFlat:
	var _p1 = StyleBoxFlat.new()
	_p1.bg_color = Color(0.2, 0.2, 0.2, 0.4)  
	_p1.set_corner_radius_all(6)
	_p1.set_border_width_all(1)
	_p1.border_color = Color(0.4, 0.4, 0.4, 0.6)
	return _p1
func _m50(_j75: Button) -> void:
	_j75.set_meta("original_scale", Vector2.ONE)
	_j75.set_meta("is_hovering", false)
	_j75.modulate.a = 0.7  
	_j75.pivot_offset = _j75.custom_minimum_size / 2  
	_j75.mouse_entered.connect(_m6.bind(_j75))
	_j75.mouse_exited.connect(_a100.bind(_j75))
	_j75.button_down.connect(_h11.bind(_j75))
	_j75.button_up.connect(_r75.bind(_j75))
func _m6(_j75: Button) -> void:
	if _j75.get_meta("is_hovering", false):
		return
	_j75.set_meta("is_hovering", true)
	var _j31 = get_tree().create_tween()
	_j31.set_parallel(true)
	_j31.set_ease(Tween.EASE_OUT)
	_j31.set_trans(Tween.TRANS_CUBIC)
	_j31.tween_property(_j75, "scale", Vector2(1.2, 1.2), 0.2)
	_j31.tween_property(_j75, "modulate:a", 1.0, 0.2)
	_j31.tween_property(_j75, "modulate", Color(1.1, 1.1, 1.1, 1.0), 0.2)
func _a100(_j75: Button) -> void:
	_j75.set_meta("is_hovering", false)
	var _j31 = get_tree().create_tween()
	_j31.set_parallel(true)
	_j31.set_ease(Tween.EASE_OUT)
	_j31.set_trans(Tween.TRANS_CUBIC)
	_j31.tween_property(_j75, "scale", Vector2.ONE, 0.2)
	_j31.tween_property(_j75, "modulate", Color(1.0, 1.0, 1.0, 0.7), 0.2)
func _h11(_j75: Button) -> void:
	var _j31 = get_tree().create_tween()
	_j31.set_ease(Tween.EASE_OUT)
	_j31.set_trans(Tween.TRANS_CUBIC)
	_j31.tween_property(_j75, "scale", Vector2(0.95, 0.95), 0.1)
func _r75(_j75: Button) -> void:
	var _w42 = Vector2(1.2, 1.2) if _j75.get_meta("is_hovering", false) else Vector2.ONE
	var _j31 = get_tree().create_tween()
	_j31.set_ease(Tween.EASE_OUT)
	_j31.set_trans(Tween.TRANS_CUBIC)
	_j31.tween_property(_j75, "scale", _w42, 0.1)
func _g30():
	if _w18:
		_w18._j94("positive", "helpful", "")
func _f88():
	_l55()
func _l55():
	var _z51 = AcceptDialog.new()
	_z51.title = "Help Us Improve"
	_z51.dialog_close_on_escape = true
	_z51.size = Vector2(400, 300)
	var _n70 = VBoxContainer.new()
	_n70.add_theme_constant_override("separation", 10)
	var _i42 = Label.new()
	_i42.text = "What was wrong with this response?"
	_n70.add_child(_i42)
	var _l3 = OptionButton.new()
	_l3.name = "CategoryOptions"
	_l3.add_item("Incorrect information")
	_l3.add_item("Wrong Godot version")
	_l3.add_item("Code doesn't work")
	_l3.add_item("Too complex")
	_l3.add_item("Not helpful")
	_l3.add_item("Other")
	_n70.add_child(_l3)
	var _n44 = Label.new()
	_n44.text = "Additional details (optional):"
	_n70.add_child(_n44)
	var _w21 = TextEdit.new()
	_w21.name = "DetailsText"
	_w21.custom_minimum_size = Vector2(0, 80)
	_w21.placeholder_text = "Describe what went wrong..."
	_n70.add_child(_w21)
	var _e32 = HBoxContainer.new()
	_e32.alignment = BoxContainer.ALIGNMENT_END
	var _y34 = Button.new()
	_y34.text = "Cancel"
	_y34.pressed.connect(_z51.hide)
	_e32.add_child(_y34)
	var _o7 = Button.new()
	_o7.text = "Submit Feedback"
	_o7.pressed.connect(_p92.bind(_z51))
	_e32.add_child(_o7)
	_n70.add_child(_e32)
	_z51.add_child(_n70)
	add_child(_z51)
	_z51.popup_centered()
func _p92(_r35: AcceptDialog):
	var _n70 = _r35.get_child(0)
	var _l3: OptionButton = null
	var _w21: TextEdit = null
	for _i64 in _n70.get_children():
		if _i64 is OptionButton and not _l3:
			_l3 = _i64
		elif _i64 is TextEdit and not _w21:
			_w21 = _i64
	var _k52 = ""
	if _l3.selected >= 0:
		_k52 = _l3.get_item_text(_l3.selected)
	var details = _w21.text.strip_edges()
	if _w18:
		_w18._j94("negative", _k52, details)
	_r35.hide()
	_r35.queue_free()
func _o94():
	if not _q80 or not _u24 or not _i6:
		return
	var _a70 = _q80.text
	var _h86 = _a70.length()
	_u24.text = "%d/500" % _h86
	if _h86 > 500:
		_u24.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	elif _h86 > 400:
		_u24.add_theme_color_override("font_color", Color(1.0, 0.8, 0.5))
	else:
		_u24.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	if _w18:
		var _w84 = _w18._z19(_a70)
		if _w84.get("valid", false):
			_i6.visible = false
			_w18._z32(_a70)
		else:
			var _b53 = _w84.get("errors", ["Unknown error"])
			_i6.text = _b53[0] if not _b53.is_empty() else "Unknown error"
			_i6.visible = true
func _q84(value: float):
	if _w18:
		var _n7 = find_child("_q38", true)
		var max_tokens = _n7.value if _n7 else 0
		_w18._y30(value, int(max_tokens))
func _y44(value: float):
	if _w18:
		var _t25 = find_child("_u4", true)
		var _b30 = _t25.value if _t25 else 0.0
		_w18._y30(_b30, int(value))
func _f52():
	if not _w18:
		return
	var _t25 = find_child("_u4", true)
	var _n7 = find_child("_q38", true)
	if _q80:
		var config = ConfigFile.new()
		if config.load("user://gdsense_settings.cfg") == OK:
			var _a70 = config.get_value("custom_rules", "rules_text", "")
			_q80.text = _a70
			if _u24:
				_u24.text = "%d/500" % _a70.length()
		else:
			pass
	else:
		pass
	if _t25:
		var config = ConfigFile.new()
		if config.load("user://gdsense_settings.cfg") == OK:
			var _b30 = config.get_value("parameters", "temperature_override", 0.0)
			_t25.value = _b30
	if _n7:
		var config = ConfigFile.new()
		if config.load("user://gdsense_settings.cfg") == OK:
			var max_tokens = config.get_value("parameters", "max_tokens_override", 0)
			_n7.value = max_tokens
func _h17(_s70: Array, parent: Node):
	var _i90 = HSeparator.new()
	_i90.add_theme_constant_override("separation", 8)
	parent.add_child(_i90)
	var _u52 = Label.new()
	_u52.text = "📚 Documentation Sources:"
	_u52.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	_u52.add_theme_font_size_override("font_size", 25)
	parent.add_child(_u52)
	var _e84 = VBoxContainer.new()
	_e84.add_theme_constant_override("separation", 1)
	parent.add_child(_e84)
	_s70.sort_custom(func(a, b): return a.get("priority", 0.0) > b.get("priority", 0.0))
	var _f37 = min(_s70.size(), 5)
	for i in range(_f37):
		var source = _s70[i]
		var _f56 = source.get("url", "")
		var title = source.get("title", "Godot Documentation")
		if not _f56.is_empty():
			var _f79 = HBoxContainer.new()
			_f79.add_theme_constant_override("separation", 8)
			_e84.add_child(_f79)
			var _a2 = Label.new()
			_a2.text = "•"
			_a2.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
			_a2.custom_minimum_size.x = 12
			_f79.add_child(_a2)
			var _f90 = Button.new()
			var _y45 = title if title.length() <= 60 else title.substr(0, 57) + "..."
			_f90.text = _y45
			_f90.tooltip_text = title  
			_f90.flat = true
			_f90.clip_text = true  
			_f90.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
			_f90.add_theme_color_override("font_hover_color", Color(0.8, 0.9, 1.0))
			_f90.add_theme_font_size_override("font_size", 20)
			_f90.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_f90.alignment = HORIZONTAL_ALIGNMENT_LEFT
			_f90.pressed.connect(_f23.bind(_f56))
			_f79.add_child(_f90)
func _f23(_f56: String):
	OS.shell_open(_f56)
func send_explain_request(function_name: String, _w94: String):
	if not _w18:
		return
	var _w8 = "@explain %s\n\nFunction source:\n```gdscript\n%s\n```" % [function_name, _w94]
	_f100(_w8)
func _d86(function_name: String, _w94: String):
	if not _g79:
		return
	_g79.text = ""
	var _w8 = "@explain %s\n\nFunction source:\n```gdscript\n%s\n```" % [function_name, _w94]
	_g79.text = _w8
	_g79.grab_focus()
	_g79.set_caret_line(_g79.get_line_count() - 1)
	_g79.set_caret_column(_g79.get_line(_g79.get_line_count() - 1).length())
func _exit_tree() -> void:
	_x91()
	_b37()
	_t82()
	_p95()
	if _v75:
		if _v75._c27.is_connected(_i49):
			_v75._c27.disconnect(_i49)
		if _v75._o43.is_connected(_s16):
			_v75._o43.disconnect(_s16)
		if _v75._y48.is_connected(_e56):
			_v75._y48.disconnect(_e56)
		if _v75._u69.is_connected(_e9):
			_v75._u69.disconnect(_e9)
		if _v75._f97.is_connected(_t41):
			_v75._f97.disconnect(_t41)
		if _v75._k49.is_connected(_d89):
			_v75._k49.disconnect(_d89)
		if _v75._f50.is_connected(_g47):
			_v75._f50.disconnect(_g47)
		if _v75._d90.is_connected(_c50):
			_v75._d90.disconnect(_c50)
		_v75._h41()
		_v75 = null
	_w100 = null
	if is_instance_valid(_k3):
		if _k3.pressed.is_connected(_b10):
			_k3.pressed.disconnect(_b10)
		_k3.queue_free()
		_k3 = null
	if _n78:
		if _n78._g80:
			_n78._g80.clear()
		_n78 = null
	if _w54:
		_w54._n78 = null
		_w54 = null
	if _o24:
		_o24._h41()
		_o24 = null
	if _k19:
		for _i64 in _k19.get_children():
			_i64.queue_free()
		_k19 = null
	_q81.clear()
	if _w18:
		if _w18._k16.is_connected(_q65):
			_w18._k16.disconnect(_q65)
		if _w18._y58.is_connected(_b1):
			_w18._y58.disconnect(_b1)
		if _w18._t37.is_connected(_x99):
			_w18._t37.disconnect(_x99)
		if _w18._p86.is_connected(_k55):
			_w18._p86.disconnect(_k55)
		if _w18._z29.is_connected(_r89):
			_w18._z29.disconnect(_r89)
		if _w18._t38.is_connected(_g69):
			_w18._t38.disconnect(_g69)
		if _w18._c79.is_connected(_p69):
			_w18._c79.disconnect(_p69)
	if _c9:
		_c9.free()
		_c9 = null
	_o10 = null
	_x62 = null
	_w18 = null
	_r16 = null
func _m74() -> void:
	if _u13:
		_u13.custom_minimum_size.y = 8
		_u13.show_percentage = false
		var _k18 = StyleBoxFlat.new()
		_k18.bg_color = Color(0.1, 0.1, 0.1, 0.5)
		_k18.corner_radius_top_left = 4
		_k18.corner_radius_top_right = 4
		_k18.corner_radius_bottom_left = 4
		_k18.corner_radius_bottom_right = 4
		_u13.add_theme_stylebox_override("background", _k18)
		_u13.mouse_entered.connect(_n39)
		_u13.mouse_exited.connect(_b66)
	_v6(0.0)
	if _x33:
		_x33.mouse_entered.connect(_n39)
		_x33.mouse_exited.connect(_b66)
func _x56() -> void:
	if not _e66:
		return
	_e66.clear()
	_e66.add_item("Commands")
	_e66.selected = 0
	_e66.add_separator()
	for _y59 in _q54:
		_e66.add_item(_y59)
	_e66.item_selected.connect(_o56)
func _s6() -> void:
	if not _m64:
		return
	_m64.clear()
	_m64.add_item(_r59[_z89])
	_w71()
	_m64.item_selected.connect(_a16)
	_d9()
func _d9() -> void:
	if not _m64 or not _o10:
		return
func _w71() -> void:
	if not _m64:
		return
	var _p5 = false
	if _w18:
		var _l50 = _w18._p94()
		if _l50 and _l50.has("features"):
			var features = _l50.get("features", {})
			_p5 = features.get("agent", false)
	var _k8 = _m64.item_count > 1
	if _p5:
		if not _k8:
			_m64.add_item(_r59[_v30])
	else:
		if _k8:
			if _m64.selected == _v30:
				_m64.selected = _z89
				_t54()
			_m64.remove_item(_v30)
func _a16(index: int) -> void:
	match index:
		_z89:
			_i69 = false
			if _l4:
				_l4.visible = true
			if _h34:
				_h34.visible = true
			if _q66:
				_q66.visible = false
			_g79.placeholder_text = "Ask me anything about Godot..."
		_v30:
			_c66()
	_g79.grab_focus()
func _w87() -> void:
	_c96()
	var _r34 = _g79.text
	var command_count = 0
	for _j88 in _q54:
		var _s2 = RegEx.new()
		_s2.compile(_j88 + "\\b")  
		var _i38 = _s2.search_all(_r34)
		command_count += _i38.size()
	if command_count != _j18:
		_j18 = command_count
		if _j20:
			_j20.stop()
			_j20.start()
func _o14() -> void:
	_y54(true)
func _y55(_y59: String, path: String) -> void:
	_y54(true)
func _y54(_y18: bool = false) -> void:
	if _g59 and not _y18:
		return
	var _r34 = _g79.text
	var _y90 = not _r34.strip_edges().is_empty()
	var _c56 = _q81.size() > 0
	if not _y90 and not _c56:
		_x75(0, [])
		return
	var _j33 = Time.get_ticks_msec()
	if not _y18 and not _z81.is_empty():
		var _j59 = _j33 - _z81.get("time", 0)
		if _j59 < _z67:
			var _r91 = _z81.get("tokens", 0)
			var _l65 = _z81.get("breakdown", [])
			_x75(_r91, _l65)
			return
	if _x33:
		_x33.text = "Context: Updating..."
	if _w18 and not _w18._a82().is_empty():
		var messages = []
		for message in _q81:
			messages.append(message)
		var context_metadata: Dictionary = {}
		if _y90:
			var _b17 = _w20(_r34, false)
			var processed_prompt = _b17.get("processed_prompt", _r34)
			if not processed_prompt.is_empty():
				messages.append({
					"role": "user",
					"content": processed_prompt
				})
			var _e71 = _b17.get("context_metadata", {})
			if _e71 == null or not _e71 is Dictionary:
				_e71 = {}
			context_metadata = _e71
		else:
			context_metadata = {}
		_w18._q8(messages, context_metadata)
	else:
		_g4()
func _g4() -> void:
	var _r34 = _g79.text
	var _b17 = _w20(_r34, false)
	var estimated_tokens = _b17.get("estimated_tokens", 0)
	var _n15 = _a32()
	var _x5 = estimated_tokens + _n15
	var breakdown = [
		{"name": "current_prompt", "tokens": estimated_tokens},
		{"name": "chat_history", "tokens": _n15}
	]
	_x75(_x5, breakdown)
func _a84(_r52: int, breakdown: Array, _y25: int = 128000) -> void:
	_p76 = _y25
	_z81 = {
		"tokens": _r52,
		"breakdown": breakdown,
		"limit": _y25,
		"time": Time.get_ticks_msec()
	}
	_x75(_r52, breakdown)
func _a32() -> int:
	var _n82 = 0
	for message in _q81:
		if message.has("content"):
			_n82 += message["content"].length()
	return _n82 / 4
func _x75(tokens: int, breakdown: Array) -> void:
	_i52 = tokens
	_b16 = breakdown
	var _p85 = float(tokens) / float(_p76) * 100.0
	if _u13:
		var _g78 = min(_p85, 100.0)
		if _g78 > 0 and _g78 < 0.5:
			_g78 = 0.5  
		_u13.value = _g78
	if _x33:
		if _p85 < 1.0 and _p85 > 0:
			_x33.text = "Context: " + str(snapped(_p85, 0.1)) + "%"
		else:
			_x33.text = "Context: " + str(int(_p85)) + "%"
		if _p85 >= 100.0:
			_x33.modulate = Color.RED
		elif _p85 >= 85.0:
			_x33.modulate = Color.YELLOW
		else:
			_x33.modulate = Color.LIGHT_GREEN
	_v6(_p85 / 100.0)
	if _p85 >= 95.0 and _w18:
		var _m16 = _w18._o26() if _w18 else ""
		_w18._f67.emit("critical", _m16, _p85, "")
	elif _p85 >= 90.0 and _w18:
		var _m16 = _w18._o26() if _w18 else ""
		_w18._f67.emit("high", _m16, _p85, "")
	elif _p85 >= 75.0 and _w18:
		var _m16 = _w18._o26() if _w18 else ""
		_w18._f67.emit("medium", _m16, _p85, "")
	if _p85 >= _u16 * 100.0:
		_n32.show()
		if _p85 >= 100.0:
			_n32.text = "⚠ Context capacity exceeded! Please reduce content."
			_n32.modulate = Color.RED
		else:
			_n32.text = "⚠ Context capacity at " + str(int(_p85)) + "% - consider reducing @ commands"
			_n32.modulate = Color.YELLOW
	else:
		_n32.hide()
func _d47() -> void:
	_x75(0, [])
	if _u13:
		_u13.tooltip_text = ""
	if _x33:
		_x33.tooltip_text = ""
	if _w27:
		_w27.hide()
func _v6(_w77: float) -> void:
	var color: Color
	if _w77 <= 0.6:  
		color = Color.GREEN
	elif _w77 <= 0.85:  
		color = Color.YELLOW
	else:  
		color = Color.RED
	var _k20 = StyleBoxFlat.new()
	_k20.bg_color = color
	_k20.corner_radius_top_left = 4
	_k20.corner_radius_top_right = 4
	_k20.corner_radius_bottom_left = 4
	_k20.corner_radius_bottom_right = 4
	if _u13:
		_u13.add_theme_stylebox_override("fill", _k20)
func _n39() -> void:
	var tooltip_text = "Context Usage Breakdown:\n"
	if _b16.size() > 0:
		for _o18 in _b16:
			if _o18 is Dictionary and _o18.has("name") and _o18.has("tokens"):
				var _b13 = _o18["tokens"]
				var _e93 = float(_b13) / float(_p76) * 100.0
				tooltip_text += str(_o18["name"]) + ": " + str(int(_e93)) + "%\n"
		tooltip_text = tooltip_text.rstrip("\n")
	else:
		tooltip_text += "No breakdown available"
	if _u13:
		_u13.tooltip_text = tooltip_text
	if _x33:
		_x33.tooltip_text = tooltip_text
func _b66() -> void:
	if _u13:
		_u13.tooltip_text = ""
	if _x33:
		_x33.tooltip_text = ""
func _o56(index: int) -> void:
	if index <= 1:
		return
	var _w30 = index - 2
	if _w30 >= 0 and _w30 < _q54.size():
		var _y59 = _q54[_w30]
		var _r34 = _g79.text
		var _e26 = _g79.get_caret_line()
		var caret_column = _g79.get_caret_column()
		if _e26 < _g79.get_line_count():
			var _n45 = _g79.get_line(_e26)
			var _e91 = _n45.substr(0, caret_column)
			var _s35 = _n45.substr(caret_column)
			var _i80 = _e91 + _y59 + " " + _s35
			_g79.set_line(_e26, _i80)
			_g79.set_caret_column(caret_column + _y59.length() + 1)
		else:
			_g79.text += _y59 + " "
			_g79.set_caret_column(_g79.text.length())
		_e66.selected = 0
		_y54()
		_g79.grab_focus()
func _u5(_d40: String) -> bool:
	var _t13 = [
		"truncated",
		"trimmed",
		"shortened",
		"context limit",
		"content limited"
	]
	var _d56 = _d40.to_lower()
	for _c29 in _t13:
		if _c29 in _d56:
			return true
	return false
func _l18(message: String) -> void:
	_w27.text = "ℹ " + message
	_w27.show()
	var _h63 = Timer.new()
	add_child(_h63)
	_h63.timeout.connect(func(): 
		_w27.hide()
		_h63.queue_free()
	)
	_h63.one_shot = true
	_h63.start(10.0)
func _g21(_f22: String) -> String:
	var _f5 = _f22.to_lower()
	if "token" in _f5 and ("limit" in _f5 or "exceed" in _f5):
		return "Your request is too large. Try reducing the amount of context or splitting into smaller requests."
	elif "rate limit" in _f5:
		return "You're sending requests too quickly. Please wait a moment before trying again."
	elif "unauthorized" in _f5 or "invalid api key" in _f5:
		return "Your API key is invalid or has expired. Please check your settings."
	elif "network" in _f5 or "connection" in _f5:
		return "Unable to connect to the AI service. Please check your internet connection."
	elif "timeout" in _f5:
		return "The request took too long to process. Please try again with a smaller request."
	elif "model" in _f5 and "not found" in _f5:
		return "The selected AI model is not available. Please try a different model."
	else:
		return _f22  
func _q16(_f58: Dictionary) -> void:
	_u7()
	_o20()
	_f35()
	_w71()
	_b32(_f58)
func _c33(_n33: String) -> String:
	if _n33.is_empty():
		return ""
	var _w68 = _n33.split("T")[0] if "T" in _n33 else _n33
	var _c93 = _w68.split("-")
	if _c93.size() < 3:
		return _n33  
	var year = _c93[0]
	var month = int(_c93[1]) if _c93[1].is_valid_int() else 0
	var day = int(_c93[2]) if _c93[2].is_valid_int() else 0
	if month < 1 or month > 12 or day < 1 or day > 31:
		return _n33  
	var _r95 = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
					   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%s %d, %s" % [_r95[month - 1], day, year]
func _l73(_l66: String, _r94: String, _p85: float, _w95: String = "") -> void:
	var _m40 = _g34()
	if _m40:
		var title = ""
		var message = ""
		var _c87 = _y20._h13.WARNING
		var _f30 = "credits"
		match _l66:
			"low":  
				title = "Usage Notice"
				message = "You've used %d%% of your %s for this period." % [int(_p85), _f30]
				_c87 = _y20._h13.INFO
			"medium":  
				title = "Usage Alert"
				message = "Heads up: you've used %d%% of your %s this period." % [int(_p85), _f30]
			"high":    
				title = "Usage Warning"
				message = "You've used %d%% of your %s. Consider switching models or upgrading." % [int(_p85), _f30]
				_c87 = _y20._h13.WARNING
			"critical": 
				title = "Critical Usage"
				message = "Critical: only %d%% of your %s remain." % [int(100 - _p85), _f30]
				_c87 = _y20._h13.ERROR
		if not _w95.is_empty():
			var _t64 = _c33(_w95)
			message += " Usage resets on %s." % _t64
		if _w18:
			var _d29 = _w18._r88()
			if _d29 != "ULTRA" and _d29 != "BETA_FREE":
				message += " Upgrade: gdsense.com/pricing"
		_m40._o66(title, message, _c87, 8.0)  
	if _l66 == "critical" and _n5:
		var _m53 = "⚠️ CRITICAL: %d%% of credits used" % [int(_p85)]
		_n5.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))  
		_n5.text = _m53
		await get_tree().create_timer(10.0).timeout
		if is_instance_valid(_n5):
			_n5.remove_theme_color_override("font_color")
			if _w18 and _w18._x57():
				_n5.text = "API Key Loaded"
				var _l50 = _w18._p94()
				if _l50 and _l50.has("tier"):
					_b32(_l50)
			else:
				_n5.text = "No API Key"
func _p69(message: String) -> void:
	var _m40 = _g34()
	if _m40:
		_m40._o66("Context Truncated", message, _y20._h13.WARNING, 5.0)
func _f35() -> void:
	if not _w18:
		return
	var _e3 = _w18._e3()
	if _c21:
		_c21.disabled = not _e3
		if not _e3:
			_c21.button_pressed = false
			_c21.tooltip_text = "Refactor is not available in Free tier"
		else:
			_c21.tooltip_text = "Show Refactor Buttons Above Functions"
	if _r16 and _r16.has_method("update_refactor_button_availability"):
		_r16.update_refactor_button_availability(_e3)
func _u48() -> void:
	if _i7:
		return  
	_i7 = PanelContainer.new()
	_i7.name = "UpdateBanner"
	_i7.visible = false
	var _d97 = StyleBoxFlat.new()
	if _o10:
		var _p43 = _o10.get_editor_settings()
		if _p43:
			var _i13 = _p43.get_setting("interface/theme/base_color")
			var _w23 = _p43.get_setting("interface/theme/accent_color")
			_d97.bg_color = _w23.lerp(_i13, 0.8)  
		else:
			_d97.bg_color = Color(0.2, 0.4, 0.6, 1.0)  
	else:
		_d97.bg_color = Color(0.2, 0.4, 0.6, 1.0)  
	_d97.set_corner_radius_all(4)
	_d97.set_content_margin_all(8)
	_i7.add_theme_stylebox_override("panel", _d97)
	var _j78 = HBoxContainer.new()
	_j78.add_theme_constant_override("separation", 8)
	var _c91 = Label.new()
	_c91.name = "UpdateMessage"
	_c91.text = "Update Available"
	_c91.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_j78.add_child(_c91)
	var _c67 = Label.new()
	_c67.name = "DownloadLink"
	_c67.text = "Download at gdsense.com"
	_c67.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))  
	_j78.add_child(_c67)
	var _g84 = Button.new()
	_g84.name = "DismissButton"
	_g84.text = "X"
	_g84.tooltip_text = "Dismiss update notification"
	_g84.custom_minimum_size = Vector2(24, 24)
	_g84.flat = true
	_g84.pressed.connect(_d2)
	_j78.add_child(_g84)
	_i7.add_child(_j78)
	var _g75 = get_node_or_null("MarginContainer/TabContainer/Chat")
	if _g75:
		var _t20 = _g75.get_child(0) if _g75.get_child_count() > 0 else null
		if _t20 and _t20 is VBoxContainer:
			_t20.add_child(_i7)
			_t20.move_child(_i7, 0)  
		else:
			_g75.add_child(_i7)
	else:
		add_child(_i7)
func _h23(_p60: String, _e8: String) -> void:
	if _q37:
		return
	if not _i7:
		_u48()
	var _c91 = _i7.find_child("_a8", true)
	if _c91:
		_c91.text = "Update Available: v%s (you have v%s)" % [_p60, _e8]
	_i7.visible = true
func _d2() -> void:
	_q37 = true
	if _i7:
		_i7.visible = false
func _b32(_f58: Dictionary) -> void:
	var _d29 = _f58.get("tier", "Unknown")
	if _n5:
		var _r34 = _n5.text
		if "API Key Loaded" in _r34:
			if _w18 and _w18._k71():
				var env = _w18._q98()
				_n5.text = "API Key Loaded (%s) - %s Tier" % [env.capitalize(), _d29]
			else:
				_n5.text = "API Key Loaded - %s Tier" % _d29
	_f86()
func _f86() -> void:
	if _k3:
		return  
	if not _n5 or not _w18:
		return
	_k3 = Button.new()
	_k3.text = "↻"  
	_k3.tooltip_text = "Refresh tier info"
	_k3.flat = true
	_k3.custom_minimum_size = Vector2(24, 24)
	_k3.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_m77(_k3)
	var parent = _n5.get_parent()
	if parent:
		var _t80 = _n5.get_index()
		parent.add_child(_k3)
		parent.move_child(_k3, _t80 + 1)
	_k3.pressed.connect(_b10)
func _b10() -> void:
	if _w18:
		_w18._f84()
func _j12(model: String) -> String:
	match model:
		"openai/gpt-oss-20b":
			return "Fast open source model (1000 tps) optimized for quick tasks."
		"openai/gpt-oss-120b":
			return "Larger open source model for more complex tasks."
		"gemini-2.5-flash-lite":
			return "Fast Gemini model for quick responses."
		"gemini-2.5-flash":
			return "Standard Gemini model for reasoning tasks."
		"gemini-2.5-pro":
			return "High-capability Gemini model for complex reasoning."
		"gpt-5-nano":
			return "Fast GPT-5 model for quick responses."
		"gpt-5.1-codex-mini":
			return "Compact GPT-5.1 Codex optimized for code generation."
		"gpt-5.1-codex":
			return "Full GPT-5.1 Codex for advanced code generation."
		_:
			return "AI model for Godot development assistance."
func _g34() -> _y20:
	var _m40 = find_child("_y20", true)
	if _m40 and _m40 is _y20:
		return _m40
	var _k90 = preload("res://addons/gdsense/scenes/_a42.tscn")
	if _k90:
		_m40 = _k90.instantiate()
		if _c9:
			var _o10 = _c9.get_editor_interface()
			if _o10:
				_m40._f94(_o10)
		add_child(_m40)
		_m40.z_index = 1000
		return _m40
	return null
func _s11():
	if not _d16:
		return
	_l44()
	_k32()
	_b68()
func _l44():
	if not _d16 or not _t11:
		return
	var recent_chats = _d16._z34()
	_t11.clear()
	_j87 = -1
	for _x74 in recent_chats:
		var _m86 = _x74._e39()
		var timestamp = _x74._s37()
		var _g7 = "%s - %s" % [_m86, timestamp]
		var index = _t11.add_item(_g7)
		_t11.set_item_metadata(index, _x74.timestamp)
		_t11.set_item_tooltip(index, _x74._v80(80))
	_n69()
	_r46()
func _k32():
	if not _d16 or not _n30:
		return
	var favorite_chats = _d16._t49()
	_n30.clear()
	_h10 = -1
	for _x74 in favorite_chats:
		var _m86 = _x74._e39()
		var timestamp = _x74._s37()
		var _g7 = "★ %s - %s" % [_m86, timestamp]
		var index = _n30.add_item(_g7)
		_n30.set_item_metadata(index, _x74.timestamp)
		_n30.set_item_tooltip(index, _x74._v80(80))
	_t95()
	_r46()
func _b68():
	if not _d16 or not _t45:
		return
	var _p49 = _d16._z34().size()
	var _l21 = _d16._t49().size()
	_t45.text = "Recent: %d | Favorites: %d" % [_p49, _l21]
	var font_color = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_t45.add_theme_color_override("font_color", font_color)
func _b71(index: int):
	if index < 0 or not _d16:
		return
	_j87 = index
	var timestamp = _t11.get_item_metadata(index)
	var _x74 = _d16._y35(timestamp)
	if _x74:
		_p81(_x74)
	_r46()
func _d78(index: int):
	if index < 0 or not _d16:
		return
	_h10 = index
	var timestamp = _n30.get_item_metadata(index)
	var _x74 = _d16._y35(timestamp)
	if _x74:
		_m75(_x74)
	_r46()
func _p81(_x74: _b86._x51):
	if not _x74 or not _s45 or not _s20 or not _o58:
		return
	var _f40 = _x74._l80()
	_s45.text = "%s - %s (%d exchange%s)" % [
		_x74._e39(),
		_x74._s37(),
		_f40,
		"s" if _f40 != 1 else ""
	]
	_s20.bbcode_enabled = true
	_s20.text = _d88(_x74)
	var _k57 = _x74._d81 if not _x74._d81.is_empty() else "Unknown"
	_o58.text = "[Model: %s]\n[Session ID: %s]" % [_k57, _x74.session_id]
func _m75(_x74: _b86._x51):
	if not _x74 or not _i37 or not _s92 or not _v50:
		return
	var _f40 = _x74._l80()
	_i37.text = "%s - %s (%d exchange%s)" % [
		_x74._e39(),
		_x74._s37(),
		_f40,
		"s" if _f40 != 1 else ""
	]
	_s92.bbcode_enabled = true
	_s92.text = _d88(_x74)
	var _k57 = _x74._d81 if not _x74._d81.is_empty() else "Unknown"
	_v50.text = "[Model: %s]\n[Session ID: %s]" % [_k57, _x74.session_id]
func _d88(_x74: _b86._x51) -> String:
	var _m96 = ""
	for _p25 in _x74.exchanges:
		if not _p25 is Dictionary:
			continue
		var _u18 = _p25.get("user_message", "")
		if _u18.begins_with("@explain"):
			var _q60 = _u18.find("\n")
			if _q60 != -1:
				_u18 = _u18.substr(0, _q60) + " (code attached)"
		var _q73 = _q74.to_html()
		_m96 += "[b][color=#%s]You:[/color][/b]\n" % _q73
		_m96 += _g43(_u18) + "\n\n"
		var _u14 = _p25.get("ai_response", "")
		var _i34 = _u85.to_html()
		_m96 += "[b][color=#%s]GDSense:[/color][/b]\n" % _i34
		var _c93 = _u14.split("```")
		var _d95 = get_theme_color("base_color", "Editor")
		var _c78 = _d95.darkened(0.2) if _d95.get_luminance() > 0.5 else _d95.lightened(0.1)
		var _v98 = _c78.to_html()
		for i in range(_c93.size()):
			var _l72 = _c93[i]
			if i % 2 == 0:
				_m96 += _g43(_l72)
			else:
				var _j63 = _l72.find("\n")
				var _x66 = _l72
				if _j63 != -1:
					_x66 = _l72.substr(_j63 + 1)
				var _q71 = _k22(_x66)
				_m96 += "\n[bgcolor=#%s]%s[/bgcolor]\n" % [_v98, _q71]
		_m96 += "\n\n"
		_m96 += "[color=#666666]────────────────────────────────[/color]\n\n"
	return _m96
func _n69():
	if _s45:
		_s45.text = "Select a chat to preview"
	if _s20:
		_s20.text = "Select a chat to view"
	if _o58:
		_o58.text = "Select a chat to view"
func _t95():
	if _i37:
		_i37.text = "Select a favorite to preview"
	if _s92:
		_s92.text = "Select a favorite chat to view"
	if _v50:
		_v50.text = "Select a favorite chat to view"
func _g43(text: String) -> String:
	var _l82 = text
	_l82 = _l82.replace("[", "\\[")
	_l82 = _l82.replace("]", "\\]")
	return _l82
func _r46():
	var _v16 = _j87 >= 0
	if _d68:
		_d68.disabled = not _v16
	if _v2:
		_v2.disabled = not _v16
	if _d53:
		_d53.disabled = not _v16
	if _y52:
		_y52.disabled = not _v16
	var _p32 = _h10 >= 0
	if _i16:
		_i16.disabled = not _p32
	if _q85:
		_q85.disabled = not _p32
	if _r99:
		_r99.disabled = not _p32
	if _v49:
		_v49.disabled = not _p32
func _s72():
	if _j87 < 0 or not _d16:
		return
	var timestamp = _t11.get_item_metadata(_j87)
	var _x74 = _d16._y35(timestamp)
	if _x74:
		_k69(_x74)
func _f71():
	if _j87 < 0 or not _d16:
		return
	var timestamp = _t11.get_item_metadata(_j87)
	if _d16._b92(timestamp):
		_s11()
func _v19():
	if _j87 < 0 or not _d16:
		return
	var timestamp = _t11.get_item_metadata(_j87)
	var _x74 = _d16._y35(timestamp)
	if _x74:
		_y29 = timestamp
		_h5 = false
		_i81.text = _x74.custom_name
		_d62.popup_centered()
func _a68():
	if _j87 < 0 or not _d16:
		return
	var timestamp = _t11.get_item_metadata(_j87)
	if _d16._d39(timestamp):
		_s11()
func _v38():
	if _h10 < 0 or not _d16:
		return
	var timestamp = _n30.get_item_metadata(_h10)
	var _x74 = _d16._y35(timestamp)
	if _x74:
		_k69(_x74)
func _u29():
	if _h10 < 0 or not _d16:
		return
	var timestamp = _n30.get_item_metadata(_h10)
	if _d16._o49(timestamp):
		_s11()
func _l46():
	if _h10 < 0 or not _d16:
		return
	var timestamp = _n30.get_item_metadata(_h10)
	var _x74 = _d16._y35(timestamp)
	if _x74:
		_y29 = timestamp
		_h5 = true
		_i81.text = _x74.custom_name
		_d62.popup_centered()
func _o85():
	if _h10 < 0 or not _d16:
		return
	var timestamp = _n30.get_item_metadata(_h10)
	if _d16._d39(timestamp):
		_s11()
func _v11():
	if not _d16 or _y29.is_empty():
		return
	var _x19 = _i81.text.strip_edges()
	if _d16._d75(_y29, _x19):
		_s11()
	_y29 = ""
	_h5 = false
func _t78():
	if not _d16:
		return
	_d16._l79()
	_d16._t72()
	_s11()
func _p8():
	if not _d16:
		return
	_d16._s8()
	_d16._t72()
	_s11()
func _r4():
	var _q47: _b86._x51 = null
	if _t11 and _t11.get_selected_items().size() > 0:
		var _r5 = _t11.get_selected_items()[0]
		var recent_chats = _d16._z34()
		if _r5 < recent_chats.size():
			_q47 = recent_chats[_r5]
	elif _n30 and _n30.get_selected_items().size() > 0:
		var _r5 = _n30.get_selected_items()[0]
		var favorite_chats = _d16._t49()
		if _r5 < favorite_chats.size():
			_q47 = favorite_chats[_r5]
	if not _q47:
		_h32("Please select a chat session to export", Color(1, 0.7, 0.3))
		return
	var filename = "gdsense_session_%s.json" % _q47.session_id
	_r96.current_file = filename
	_r96.current_path = "user://" + filename
	_r96.popup_centered()
func _u58(path: String):
	var _q47: _b86._x51 = null
	if _t11 and _t11.get_selected_items().size() > 0:
		var _r5 = _t11.get_selected_items()[0]
		var recent_chats = _d16._z34()
		if _r5 < recent_chats.size():
			_q47 = recent_chats[_r5]
	elif _n30 and _n30.get_selected_items().size() > 0:
		var _r5 = _n30.get_selected_items()[0]
		var favorite_chats = _d16._t49()
		if _r5 < favorite_chats.size():
			_q47 = favorite_chats[_r5]
	if not _q47:
		push_error("[GDSense] Failed to export: No session selected")
		return
	var _g96 = {
		"format_version": "1.0",
		"exported_at": Time.get_datetime_string_from_system(),
		"session": _d16._s24(_q47)
	}
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		var _g5 = JSON.stringify(_g96, "\t")
		file.store_string(_g5)
		file.close()
		_h32("Session exported successfully", Color(0.3, 1, 0.5))
	else:
		push_error("[GDSense] Failed to write export file: %s" % path)
		_h32("Export failed: Could not write file", Color(1, 0.3, 0.3))
func _k36():
	_w26.current_path = "user://"
	_w26.popup_centered()
func _q31(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("[GDSense] Failed to open import file: %s" % path)
		_h32("Import failed: Could not open file", Color(1, 0.3, 0.3))
		return
	var _g5 = file.get_as_text()
	file.close()
	var json = JSON.new()
	var _a50 = json.parse(_g5)
	if _a50 != OK:
		push_error("[GDSense] Failed to parse import file: %s" % json.get_error_message())
		_h32("Import failed: Invalid JSON format", Color(1, 0.3, 0.3))
		return
	var _t61 = json.data
	if not _t61 is Dictionary:
		push_error("[GDSense] Import data is not a Dictionary")
		_h32("Import failed: Invalid data structure", Color(1, 0.3, 0.3))
		return
	if not _t61.has("format_version"):
		push_error("[GDSense] Import file missing format_version")
		_h32("Import failed: Missing format version", Color(1, 0.3, 0.3))
		return
	if _t61["format_version"] != "1.0":
		push_error("[GDSense] Unsupported format version: %s" % _t61["format_version"])
		_h32("Import failed: Unsupported format version", Color(1, 0.3, 0.3))
		return
	if not _t61.has("session"):
		push_error("[GDSense] Import file missing session data")
		_h32("Import failed: Missing session data", Color(1, 0.3, 0.3))
		return
	var _n47 = _t61["session"]
	if not _n47 is Dictionary:
		push_error("[GDSense] Session data is not a Dictionary")
		_h32("Import failed: Invalid session format", Color(1, 0.3, 0.3))
		return
	var _f17 = ["exchanges", "timestamp", "session_id"]
	for _y1 in _f17:
		if not _n47.has(_y1):
			push_error("[GDSense] Session missing required field: %s" % _y1)
			_h32("Import failed: Incomplete session data", Color(1, 0.3, 0.3))
			return
	if not _n47["exchanges"] is Array:
		push_error("[GDSense] Session exchanges is not an Array")
		_h32("Import failed: Invalid exchanges format", Color(1, 0.3, 0.3))
		return
	if _n47["exchanges"].is_empty():
		push_error("[GDSense] Session has no exchanges")
		_h32("Import failed: Empty session", Color(1, 0.3, 0.3))
		return
	for _p25 in _n47["exchanges"]:
		if not _p25 is Dictionary:
			push_error("[GDSense] Invalid exchange format")
			_h32("Import failed: Invalid exchange data", Color(1, 0.3, 0.3))
			return
		if not _p25.has("user_message") or not _p25.has("ai_response"):
			push_error("[GDSense] Exchange missing user_message or ai_response")
			_h32("Import failed: Incomplete exchange", Color(1, 0.3, 0.3))
			return
		if _p25["user_message"].length() > 100000 or _p25["ai_response"].length() > 500000:
			push_error("[GDSense] Exchange messages too long (possible attack)")
			_h32("Import failed: Messages exceed size limits", Color(1, 0.3, 0.3))
			return
		if _p25.has("enhanced_user_message") and _p25["enhanced_user_message"].length() > 200000:
			push_error("[GDSense] Enhanced message too long (possible attack)")
			_h32("Import failed: Messages exceed size limits", Color(1, 0.3, 0.3))
			return
	var _w91 = _d16._y35(_n47["timestamp"])
	if _w91:
		_h32("Warning: Session may already exist", Color(1, 0.7, 0.3))
	var _y5 = _d16._a31(_n47)
	if not _y5:
		push_error("[GDSense] Failed to convert imported data to ChatEntry")
		_h32("Import failed: Could not create session", Color(1, 0.3, 0.3))
		return
	_d16._c61.push_front(_y5)
	while _d16._c61.size() > _b86._p73:
		_d16._c61.pop_back()
	_d16._t72()
	_s11()
	_h32("Session imported successfully (%d exchanges)" % _y5._l80(), Color(0.3, 1, 0.5))
func _h32(message: String, color: Color):
	if color.r > color.g and color.r > color.b:
		pass
	else:
		pass
func _e74(message: String) -> String:
	var _i93 = _b86._x51._l85(message)
	if _i93 != message and OS.is_debug_build():
		pass
	return _i93
func _k69(_x74: _b86._x51):
	if not _x74:
		return
	_q81.clear()
	_x91()
	for _i64 in _k19.get_children():
		_i64.queue_free()
	var _q100 = _x74._n87()
	var _c90 = _x74._r82()
	_y6 = _q100 if _q100 else {}
	if _c90 and not _c90.is_empty():
		_a54 = _c90
	else:
		_a54.clear()  
	_n23()
	for _p25 in _x74.exchanges:
		if not _p25 is Dictionary:
			continue
		if not _p25.has("user_message") or not _p25.has("ai_response"):
			continue
		var _y67 = _e74(_p25["user_message"])
		if _y67.begins_with("@explain"):
			var _q60 = _y67.find("\n")
			if _q60 != -1:
				_y67 = _y67.substr(0, _q60) + " (code attached)"
		_r64(_y67)
		_h21(_p25["ai_response"], [])
		var _f43 = _p25.get("enhanced_user_message", _p25["user_message"])
		var _f22 = _e74(_p25["user_message"])
		_q81.append({"role": "user", "content": _f43, "original_content": _f22})
		var _u14 = {"role": "agent", "content": _p25["ai_response"]}
		if _p25.has("thought_signature") and not _p25["thought_signature"].is_empty():
			_u14["thought_signature"] = _p25["thought_signature"]
		_q81.append(_u14)
	if _v82:
		_v82.current_tab = 0
	_t89.call_deferred()
func _b42():
	var _l17 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	var _w2 = func(_m46: Node):
		if not _m46: return
		for _i64 in _m46.get_children():
			if _i64 is Label:
				if "Full Conversation" in _i64.text or "Session Info" in _i64.text:
					_i64.add_theme_color_override("font_color", _l17)
	if _s20:
		_w2.call(_s20.get_parent())
	if _s92:
		_w2.call(_s92.get_parent())
func _l57():
	_c77()
	_b42()
	_e55()
	if _d16:
		if _j87 >= 0:
			_b71(_j87)
		if _h10 >= 0:
			_d78(_h10)
func _e55():
	var _p26 = get_node_or_null("MarginContainer/TabContainer/Settings/_l13/VBoxContainer")
	if not _p26: return
	var _s94 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	var _b6 = Color(_s94, 0.6)
	var _p13 = func(node: Node, _s15: Callable):
		if node is Label:
			if node.has_meta("secondary"):
				node.add_theme_color_override("font_color", _b6)
			else:
				node.add_theme_color_override("font_color", _s94)
		for _i64 in node.get_children():
			_s15.call(_i64, _s15)
	_p13.call(_p26, _p13)
func _a83() -> void:
	_v75 = _p75.new()
	_v75.initialize(self, _w18)
	_v75._c27.connect(_i49)
	_v75._o43.connect(_s16)
	_v75._y48.connect(_e56)
	_v75._u69.connect(_e9)
	_v75._f97.connect(_t41)
	_v75._k49.connect(_d89)
	_v75._f50.connect(_g47)
	_v75._d90.connect(_c50)
	_w100 = _a98.new()
	_w100.initialize(_o10)
	_c2()
func _c2() -> void:
	_i57 = VBoxContainer.new()
	_i57.name = "AgentUIContainer"
	_i57.visible = false
	_i57.add_theme_constant_override("separation", 4)
	_g37 = Label.new()
	_g37.text = "Agent: Initializing..."
	_g37.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_i57.add_child(_g37)
	_i78 = ProgressBar.new()
	_i78.min_value = 0
	_i78.max_value = 100
	_i78.value = 0
	_i78.show_percentage = false
	_i78.custom_minimum_size = Vector2(0, 8)
	_i57.add_child(_i78)
	var _g75 = get_node_or_null("MarginContainer/TabContainer/Chat")
	if _g75:
		var _t20 = _g75.get_child(0) if _g75.get_child_count() > 0 else null
		if _t20 and _t20 is VBoxContainer:
			var _b39 = -1
			for i in range(_t20.get_child_count()):
				var _i64 = _t20.get_child(i)
				if _i64.name == "InputContainer" or (_i64 is HBoxContainer and _i64.get_node_or_null("_d41") != null):
					_b39 = i
					break
			if _b39 >= 0:
				_t20.add_child(_i57)
				_t20.move_child(_i57, _b39)
			else:
				_t20.add_child(_i57)
		else:
			add_child(_i57)
	else:
		add_child(_i57)
func _c66() -> void:
	_i69 = true
	if _m64 and _m64.item_count > _v30 and _m64.selected != _v30:
		_m64.selected = _v30
	if _l4:
		_l4.visible = false
	if _h34:
		_h34.visible = false
	if _q66:
		_q66.visible = true
	_g79.placeholder_text = "[Agent Mode] Describe your task..."
	_t99("Agent mode enabled. Describe your task and press Enter to start.")
func _t54() -> void:
	_i69 = false
	_w53.clear()
	_d72 = false
func _e48() -> void:
	if _i57:
		_i57.visible = true
	if _i78:
		_i78.value = 0
	if _g37:
		_g37.text = "Agent: Starting..."
	_n26()
func _q18() -> void:
	if _i57:
		_i57.visible = false
func _n26() -> void:
	_t82()  
	_o60 = HBoxContainer.new()
	_o60.name = "AgentCancelContainer"
	_o60.alignment = BoxContainer.ALIGNMENT_CENTER
	_y87 = Button.new()
	_y87.text = "Cancel Agent"
	_y87.pressed.connect(_w1)
	_o60.add_child(_y87)
	var _g75 = get_node_or_null("MarginContainer/TabContainer/Chat")
	if _g75:
		var _t20 = _g75.get_child(0) if _g75.get_child_count() > 0 else null
		if _t20 and _t20 is VBoxContainer:
			var _b39 = -1
			for i in range(_t20.get_child_count()):
				var _i64 = _t20.get_child(i)
				if _i64.name == "InputContainer" or (_i64 is HBoxContainer and _i64.get_node_or_null("_d41") != null):
					_b39 = i
					break
			if _b39 >= 0:
				_t20.add_child(_o60)
				_t20.move_child(_o60, _b39)
			else:
				_t20.add_child(_o60)
		else:
			add_child(_o60)
	else:
		add_child(_o60)
func _t82() -> void:
	if _o60 and is_instance_valid(_o60):
		_o60.queue_free()
		_o60 = null
		_y87 = null
func _y12() -> void:
	_p95()  
	_n94 = HBoxContainer.new()
	_n94.name = "AgentForceResetContainer"
	_n94.alignment = BoxContainer.ALIGNMENT_CENTER
	_n94.add_theme_constant_override("separation", 8)
	var _s58 = Button.new()
	_s58.text = "Reset Agent"
	_s58.tooltip_text = "Force reset all agent state and start fresh"
	_s58.pressed.connect(_l84)
	_n94.add_child(_s58)
	var _g75 = get_node_or_null("MarginContainer/TabContainer/Chat")
	if _g75:
		var _t20 = _g75.get_child(0) if _g75.get_child_count() > 0 else null
		if _t20 and _t20 is VBoxContainer:
			var _b39 = -1
			for i in range(_t20.get_child_count()):
				var _i64 = _t20.get_child(i)
				if _i64.name == "InputContainer" or (_i64 is HBoxContainer and _i64.get_node_or_null("_d41") != null):
					_b39 = i
					break
			if _b39 >= 0:
				_t20.add_child(_n94)
				_t20.move_child(_n94, _b39)
			else:
				_t20.add_child(_n94)
		else:
			add_child(_n94)
	else:
		add_child(_n94)
func _p95() -> void:
	if _n94 and is_instance_valid(_n94):
		_n94.queue_free()
		_n94 = null
func _l84() -> void:
	if _v75 and _v75.is_active():
		_v75._k45()
	_q18()
	_t82()
	_b37()
	_p95()
	_t54()
	_k82()
	_w53.clear()
	_d72 = false
	_t99("Agent state reset. You can start a new task.", false)
func _t99(text: String, _y93: bool = false) -> void:
	var _q63 = PanelContainer.new()
	_q63.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_q63.add_theme_constant_override("margin_bottom", _i12.message_gap)
	if not _n95:
		_c77()
	_q63.add_theme_stylebox_override("panel", _n95)
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.selection_enabled = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.fit_content = true
	label.scroll_active = false
	label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var _m44 = Color.RED if _y93 else _u85
	label.add_theme_color_override("default_color", _m44)
	label.text = "[b][Agent][/b] " + _g43(text)
	_q63.add_child(label)
	_k19.add_child(_q63)
	_t89.call_deferred()
func _g61(_v79: String, details: Array, _y93: bool = false) -> void:
	var _q63 = PanelContainer.new()
	_q63.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_q63.add_theme_constant_override("margin_bottom", _i12.message_gap)
	if not _n95:
		_c77()
	_q63.add_theme_stylebox_override("panel", _n95)
	var _t20 = VBoxContainer.new()
	_t20.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _o45 = HBoxContainer.new()
	_o45.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _f51 = Button.new()
	_f51.flat = true
	_f51.text = "▶"  
	_f51.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_f51.tooltip_text = "Click to expand/collapse"
	_m77(_f51)
	_o45.add_child(_f51)
	var _d8 = RichTextLabel.new()
	_d8.bbcode_enabled = true
	_d8.selection_enabled = true
	_d8.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_d8.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_d8.fit_content = true
	_d8.scroll_active = false
	_d8.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var _m44 = Color.RED if _y93 else _u85
	_d8.add_theme_color_override("default_color", _m44)
	_d8.text = "[b][Agent][/b] " + _g43(_v79)
	_o45.add_child(_d8)
	_t20.add_child(_o45)
	var _b91 = VBoxContainer.new()
	_b91.visible = false
	_b91.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_b91.add_theme_constant_override("separation", 4)
	var _q70 = MarginContainer.new()
	var indent_size = _k97() * 2  
	_q70.add_theme_constant_override("margin_left", indent_size)
	_q70.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _n72 = VBoxContainer.new()
	_n72.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for _o18 in details:
		var _z40 = Label.new()
		_z40.text = _o18
		_z40.add_theme_color_override("font_color", _m44.darkened(0.15))
		_m77(_z40)
		_n72.add_child(_z40)
	_q70.add_child(_n72)
	_b91.add_child(_q70)
	_t20.add_child(_b91)
	_f51.pressed.connect(func():
		_b91.visible = not _b91.visible
		_f51.text = "▼" if _b91.visible else "▶"
		_t89.call_deferred()
	)
	_q63.add_child(_t20)
	_k19.add_child(_q63)
	_t89.call_deferred()
func _m77(_c35: Control) -> void:
	if _c9:
		var _o10 = _c9.get_editor_interface()
		if _o10:
			var theme = _o10.get_editor_theme()
			if theme:
				var _a43 = theme.get_font("main", "EditorFonts")
				if _a43:
					_c35.add_theme_font_override("font", _a43)
				var _a72 = theme.get_font_size("main_size", "EditorFonts")
				if _a72 > 0:
					_c35.add_theme_font_size_override("font_size", _a72)
func _k97() -> int:
	if _c9:
		var _o10 = _c9.get_editor_interface()
		if _o10:
			var theme = _o10.get_editor_theme()
			if theme:
				var _a72 = theme.get_font_size("main_size", "EditorFonts")
				if _a72 > 0:
					return _a72
	return 14  
func _i49(session_id: String) -> void:
	_t99("Agent session started. Analyzing your request...")
func _s16(status: Dictionary) -> void:
	var progress = status.get("progress_percent", 0)
	var _y94 = status.get("status_message", "Processing...")
	if _y94 == null:
		_y94 = "Processing..."
	if _i78:
		_i78.value = progress
	if _g37:
		_g37.text = "Agent: " + _y94
	if status.has("tier"):
		var _d29 = status.get("tier", "")
		if _d29 is String and not _d29.is_empty() and _w18:
			_w18._j40(_d29)
func _e56(_t12: Array) -> void:
	if _t12.is_empty():
		return
	var _p36: Array = []
	var _k56: Array = []
	for _k44 in _t12:
		var _s46 = _k44.get("tool_name", "")
		var _u28 = _w100._u28(_s46)
		if _u28:
			_k56.append(_k44)
		else:
			_p36.append(_k44)
	for _k44 in _p36:
		var _s46 = _k44.get("tool_name", "")
		var _k66 = _k44.get("tool_call_id", "")
		var _m19 = _k44.get("parameters", {})
		if _m19 == null:
			_m19 = {}
		var _n37 = _w100._a91(_s46, _m19)
		_v75._g26(_k66, true, _n37)
		_f85(_s46, _m19, _n37)
	for _k44 in _k56:
		_w53.append(_k44)
	if not _d72 and _w53.size() > 0:
		_h12()
func _h12() -> void:
	if _w53.is_empty():
		_d72 = false
		return
	_d72 = true
	var _k44 = _w53.pop_front()
	var _s46 = _k44.get("tool_name", "")
	var _k66 = _k44.get("tool_call_id", "")
	var _r35 = _d10.new()
	_r35._f94(_o10)
	_r35._x68(_k44)
	_r35._l43.connect(_o72.bind(_k66))
	_r35._c26.connect(_s43.bind(_k66))
	add_child(_r35)
	_r35.popup_centered()
func _o72(_k44: Dictionary, _c41: Dictionary, _k66: String) -> void:
	var _s46 = _k44.get("tool_name", "")
	if _s46 == null:
		_s46 = ""
	var _m19 = _k44.get("parameters", {})
	if _m19 == null:
		_m19 = {}
	var _n37 = _w100._a91(_s46, _m19)
	_v75._g26(_k66, true, _n37)
	_f85(_s46, _m19, _n37)
	_h12()
func _s43(_k44: Dictionary, _e13: String, _k66: String) -> void:
	var _s46 = _k44.get("tool_name", "")
	if _s46 == null:
		_s46 = ""
	var _m19 = _k44.get("parameters", {})
	if _m19 == null:
		_m19 = {}
	_v75._g26(_k66, false, {}, _e13)
	var path = _m19.get("path", "")
	if path == null:
		path = ""
	if not path.is_empty():
		_t99("Rejected " + _s46 + ": " + path)
	else:
		_t99("Rejected: " + _s46)
	_h12()
func _e9(message: String) -> void:
	_h21(message, [])
	_t99("Tip: Reopen modified scenes or reload the project to see changes")
	_q18()
	_t82()  
	_b37()
	_p95()  
	_t54()
	_k82()
func _t41(error: String) -> void:
	_t99("Agent failed: " + error, true)
	_q18()
	_y12()
	_b37()
func _d89() -> void:
	_t99("Agent cancelled")
	_q18()
	_t82()  
	_b37()
	_p95()  
	_t54()
	_k82()
func _g47(session_id: String, message: String) -> void:
	var _c3 = message + " You can continue to allow more processing."
	_t99(_c3, true)
	_i88()
	_q18()
	_t82()  
func _c50(message: String, _g2: String) -> void:
	if message.is_empty() and _g2.is_empty():
		return
	if not message.is_empty():
		_h21(message, [])
	if not _g2.is_empty():
		_f39(_g2)
func _f39(_g2: String) -> void:
	var _q63 = PanelContainer.new()
	_q63.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_q63.add_theme_constant_override("margin_bottom", _i12.message_gap)
	if not _n95:
		_c77()
	_q63.add_theme_stylebox_override("panel", _n95)
	var _t20 = VBoxContainer.new()
	_t20.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _o45 = HBoxContainer.new()
	_o45.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _f51 = Button.new()
	_f51.flat = true
	_f51.text = ">"  
	_f51.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_f51.tooltip_text = "Click to expand/collapse reasoning"
	_m77(_f51)
	_o45.add_child(_f51)
	var _d8 = RichTextLabel.new()
	_d8.bbcode_enabled = true
	_d8.selection_enabled = true
	_d8.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_d8.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_d8.fit_content = true
	_d8.scroll_active = false
	_d8.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var _j44 = _u85.darkened(0.2)
	_d8.add_theme_color_override("default_color", _j44)
	_d8.text = "[i]View reasoning[/i]"
	_o45.add_child(_d8)
	_t20.add_child(_o45)
	var _b91 = VBoxContainer.new()
	_b91.visible = false
	_b91.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_b91.add_theme_constant_override("separation", 4)
	var _q70 = MarginContainer.new()
	var indent_size = _k97() * 2  
	_q70.add_theme_constant_override("margin_left", indent_size)
	_q70.add_theme_constant_override("margin_top", 4)
	_q70.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _q99 = RichTextLabel.new()
	_q99.bbcode_enabled = true
	_q99.selection_enabled = true
	_q99.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_q99.fit_content = true
	_q99.scroll_active = false
	_q99.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_q99.add_theme_color_override("default_color", _j44)
	_q99.text = _g43(_g2)
	_q70.add_child(_q99)
	_b91.add_child(_q70)
	_t20.add_child(_b91)
	_f51.pressed.connect(func():
		_b91.visible = not _b91.visible
		_f51.text = "v" if _b91.visible else ">"
		_t89.call_deferred()
	)
	_q63.add_child(_t20)
	_k19.add_child(_q63)
	_t89.call_deferred()
func _i88() -> void:
	_b37()  
	_y65 = HBoxContainer.new()
	_y65.name = "AgentContinueContainer"
	_y65.alignment = BoxContainer.ALIGNMENT_CENTER
	_y65.add_theme_constant_override("separation", 8)
	var _c38 = Button.new()
	_c38.text = "Continue Session"
	_c38.pressed.connect(_h1)
	_y65.add_child(_c38)
	var _g84 = Button.new()
	_g84.text = "Start New Task"
	_g84.pressed.connect(_w62)
	_y65.add_child(_g84)
	var _g75 = get_node_or_null("MarginContainer/TabContainer/Chat")
	if _g75:
		var _t20 = _g75.get_child(0) if _g75.get_child_count() > 0 else null
		if _t20 and _t20 is VBoxContainer:
			var _b39 = -1
			for i in range(_t20.get_child_count()):
				var _i64 = _t20.get_child(i)
				if _i64.name == "InputContainer" or (_i64 is HBoxContainer and _i64.get_node_or_null("_d41") != null):
					_b39 = i
					break
			if _b39 >= 0:
				_t20.add_child(_y65)
				_t20.move_child(_y65, _b39)
			else:
				_t20.add_child(_y65)
		else:
			add_child(_y65)
	else:
		add_child(_y65)
func _h1() -> void:
	_b37()
	_e48()
	if _v75:
		_v75._v8()
func _w62() -> void:
	_b37()
	_p95()  
	if _v75:
		_v75._i96()
	_t54()
	_k82()
func _b37() -> void:
	if _y65 and is_instance_valid(_y65):
		_y65.queue_free()
		_y65 = null
func _w1() -> void:
	if _v75 and _v75.is_active():
		_v75._k45()
func _i10(_s46: String, _m19: Dictionary, _n37: Dictionary) -> Dictionary:
	var success = _n37.get("success", false)
	var _j46 = "✓ " if success else "✗ "
	var details: Array = []
	match _s46:
		"read_file":
			var path = _m19.get("path", "unknown")
			if success:
				var content = _n37.get("content", "")
				var _d99 = content.count("\n") + 1 if not content.is_empty() else 0
				return {"summary": _j46 + "Read file: " + path + " (" + str(_d99) + " lines)", "details": [], "is_error": false}
			else:
				return {"summary": _j46 + "Failed to read: " + path, "details": [], "is_error": true}
		"list_files":
			var path = _m19.get("path", "res://")
			if success:
				var _u72 = _n37.get("files", [])
				var _p78 = _n37.get("directories", [])
				var _e59 = _u72.size() if _u72 is Array else 0
				var _a80 = _p78.size() if _p78 is Array else 0
				for _o81 in _p78:
					details.append("📁 " + str(_o81) + "/")
				for _s80 in _u72:
					details.append("📄 " + str(_s80))
				return {"summary": _j46 + "Listed " + path + " (" + str(_e59) + " files, " + str(_a80) + " dirs)", "details": details, "is_error": false}
			else:
				return {"summary": _j46 + "Failed to list: " + path, "details": [], "is_error": true}
		"get_project_info":
			if success:
				var _c14 = _n37.get("project_name", "Unknown")
				var _y80 = _n37.get("godot_version", "")
				details.append("Project: " + str(_c14))
				details.append("Godot: " + str(_y80))
				if _n37.has("main_scene"):
					details.append("Main Scene: " + str(_n37.get("main_scene")))
				return {"summary": _j46 + "Project: " + _c14 + " (Godot " + _y80 + ")", "details": details, "is_error": false}
			else:
				return {"summary": _j46 + "Failed to get project info", "details": [], "is_error": true}
		"run_project":
			if success:
				return {"summary": _j46 + "Running project in debug mode", "details": [], "is_error": false}
			else:
				return {"summary": _j46 + "Failed to run project", "details": [], "is_error": true}
		"stop_project":
			if success:
				return {"summary": _j46 + "Stopped project", "details": [], "is_error": false}
			else:
				return {"summary": _j46 + "Failed to stop project", "details": [], "is_error": true}
		"create_file":
			var path = _m19.get("path", "unknown")
			if success:
				return {"summary": _j46 + "Created: " + path, "details": [], "is_error": false}
			else:
				var _w11 = _n37.get("error", "Unknown error")
				return {"summary": _j46 + "Failed to create " + path + ": " + _w11, "details": [], "is_error": true}
		"edit_file":
			var path = _m19.get("path", "unknown")
			if success:
				return {"summary": _j46 + "Modified: " + path, "details": [], "is_error": false}
			else:
				var _w11 = _n37.get("error", "Unknown error")
				return {"summary": _j46 + "Failed to edit " + path + ": " + _w11, "details": [], "is_error": true}
		"delete_file":
			var path = _m19.get("path", "unknown")
			if success:
				return {"summary": _j46 + "Deleted: " + path, "details": [], "is_error": false}
			else:
				var _w11 = _n37.get("error", "Unknown error")
				return {"summary": _j46 + "Failed to delete " + path + ": " + _w11, "details": [], "is_error": true}
		_:
			if success:
				return {"summary": _j46 + "Executed: " + _s46, "details": [], "is_error": false}
			else:
				return {"summary": _j46 + "Failed: " + _s46, "details": [], "is_error": true}
func _f85(_s46: String, _m19: Dictionary, _n37: Dictionary) -> void:
	var status = _i10(_s46, _m19, _n37)
	var _v79 = status.get("summary", "")
	var details = status.get("details", [])
	var _y93 = status.get("is_error", false)
	if details.size() > 0:
		_g61(_v79, details, _y93)
	else:
		_t99(_v79, _y93)
