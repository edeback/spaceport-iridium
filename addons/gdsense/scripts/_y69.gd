@tool
extends Control
func _y60(type: String) -> Color:
	if _i13:
		var _f13 = _i13.get_editor_settings()
		if _f13:
			match type:
				"text_color": return _f13.get_setting("text_editor/theme/highlighting/text_color")
				"comment": return _f13.get_setting("text_editor/theme/highlighting/comment_color")
				"string": return _f13.get_setting("text_editor/theme/highlighting/string_color")
				"number": return _f13.get_setting("text_editor/theme/highlighting/number_color")
				"keyword": return _f13.get_setting("text_editor/theme/highlighting/keyword_color")
				"class": return _f13.get_setting("text_editor/theme/highlighting/base_type_color")
				"function": return _f13.get_setting("text_editor/theme/highlighting/function_color")
				"symbol": return _f13.get_setting("text_editor/theme/highlighting/symbol_color")
	match type:
		"comment": return Color.GRAY
		"string": return Color.ORANGE
		"number": return Color.SKY_BLUE
		"keyword": return Color.PALE_VIOLET_RED
		"class": return Color.LIGHT_GREEN
		"function": return Color.LIGHT_BLUE
		"symbol": return Color.WHITE
	return Color.WHITE
const _e96 = [
	"if", "elif", "else", "for", "while", "match", "break", "continue", "pass",
	"return", "class", "extends", "is", "as", "self", "super", "func", "signal",
	"const", "var", "static", "enum", "in", "not", "and", "or", "true", "false",
	"null", "export", "onready", "tool", "setget", "breakpoint", "preload", "yield",
	"assert", "remote", "sync", "master", "puppet"
]
const _o95 = [
	"public", "private", "protected", "internal", "static", "void", 
	"class", "interface", "namespace", "using", "new", "this", "base",
	"if", "else", "for", "foreach", "while", "do", "switch", "case",
	"return", "throw", "try", "catch", "finally", "async", "await",
	"var", "const", "readonly", "override", "virtual", "abstract",
	"int", "string", "bool", "float", "double", "decimal", "byte", "true", "false", "null"
]
func _x82():
	if not _i13:
		return
	var theme = _i13.get_editor_theme()
	if not theme:
		return
	var _f9 = theme.get_color("base_color", "Editor")
	var _p58 = theme.get_color("dark_color_2", "Editor")
	var _m96 = theme.get_color("contrast_color_1", "Editor")
	var font_color = theme.get_color("font_color", "Editor")
	var _j86 = theme.get_color("accent_color", "Editor")
	if not _w1:
		_x96()
	var _r87 = _f9.lerp(_j86, 0.1)
	if _f9.get_luminance() > 0.5:
		_r87 = _f9.darkened(0.05).lerp(_j86, 0.1)
	_w1.bg_color = _r87
	_w1.border_color = _j86.darkened(0.3)
	if _r87.get_luminance() > 0.5:
		_h70 = Color.BLACK
	else:
		_h70 = Color(0.9, 0.9, 0.9) 
	var _a97 = _p58
	_g50.bg_color = _a97
	_g50.border_color = _a97.lightened(0.05)
	_i35 = font_color
	var _y79 = _q7("normal", "TextEdit")
	if _y79 is StyleBoxFlat:
		_k52.bg_color = _y79.bg_color
		_k52.border_color = _y79.border_color
		_k52.border_width_left = _y79.border_width_left
		_k52.border_width_top = _y79.border_width_top
		_k52.border_width_right = _y79.border_width_right
		_k52.border_width_bottom = _y79.border_width_bottom
		_k52.corner_radius_top_left = _y79.corner_radius_top_left
		_k52.corner_radius_top_right = _y79.corner_radius_top_right
		_k52.corner_radius_bottom_right = _y79.corner_radius_bottom_right
		_k52.corner_radius_bottom_left = _y79.corner_radius_bottom_left
	else:
		_k52.bg_color = _f9
		_k52.border_color = _f9.lightened(0.1)
	_o75.bg_color = _p58
	_o75.border_color = _p58.lightened(0.1)
	_z82 = font_color
	_r33.bg_color = _p58.lightened(0.05)
func _y98(name: String, type: String = "Editor") -> Color:
	if _i13:
		var theme = _i13.get_editor_theme()
		if theme:
			return theme.get_color(name, type)
	return Color.GRAY 
func _q7(name: String, type: String = "Editor") -> StyleBox:
	if _i13:
		var theme = _i13.get_editor_theme()
		if theme:
			return theme.get_stylebox(name, type)
	return null
var _w1: StyleBoxFlat
var _g50: StyleBoxFlat
var _o75: StyleBoxFlat
var _r33: StyleBoxFlat
var _k52: StyleBoxFlat
var _h70: Color
var _i35: Color
var _z82: Color
const _z32 = {
	"message_gap": 16,
	"padding": 12,
	"code_padding": 10
}
func _x96():
	_w1 = StyleBoxFlat.new()
	_w1.corner_radius_top_left = 8
	_w1.corner_radius_top_right = 8
	_w1.corner_radius_bottom_left = 8
	_w1.corner_radius_bottom_right = 8
	_w1.content_margin_left = _z32.padding
	_w1.content_margin_right = _z32.padding
	_w1.content_margin_top = _z32.padding
	_w1.content_margin_bottom = _z32.padding
	_w1.border_width_bottom = 1
	_w1.border_width_top = 1
	_w1.border_width_left = 1
	_w1.border_width_right = 1
	_g50 = StyleBoxFlat.new()
	_g50.corner_radius_top_left = 8
	_g50.corner_radius_top_right = 8
	_g50.corner_radius_bottom_left = 8
	_g50.corner_radius_bottom_right = 8
	_g50.content_margin_left = _z32.padding
	_g50.content_margin_right = _z32.padding
	_g50.content_margin_top = _z32.padding
	_g50.content_margin_bottom = _z32.padding
	_g50.border_width_bottom = 1
	_g50.border_width_top = 1
	_g50.border_width_left = 1
	_g50.border_width_right = 1
	_o75 = StyleBoxFlat.new()
	_o75.corner_radius_top_left = 4
	_o75.corner_radius_top_right = 4
	_o75.corner_radius_bottom_left = 4
	_o75.corner_radius_bottom_right = 4
	_o75.border_width_bottom = 1
	_o75.border_width_top = 1
	_o75.border_width_left = 1
	_o75.border_width_right = 1
	_o75.border_width_left = 1
	_o75.border_width_right = 1
	_r33 = StyleBoxFlat.new()
	_r33.corner_radius_top_left = 6
	_r33.corner_radius_top_right = 6
	_r33.content_margin_left = 12
	_r33.content_margin_right = 12
	_r33.content_margin_top = 4
	_r33.content_margin_bottom = 4
	_k52 = StyleBoxFlat.new()
	_k52.bg_color = Color(0.1, 0.1, 0.1) 
	_k52.border_width_left = 1
	_k52.border_width_top = 1
	_k52.border_width_right = 1
	_k52.border_width_bottom = 1
	_k52.corner_radius_top_left = 4
	_k52.corner_radius_top_right = 4
	_k52.corner_radius_bottom_right = 4
	_k52.corner_radius_bottom_left = 4
const _t93 = {
	"gdscript": "GDScript",
	"csharp": "C#",
	"cs": "C#",
	"": "GDScript"  
}
const _r21 = {
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
const _i54 = {
	"1080p": {"width": 1920, "height": 1080, "scale": 1.0},  
	"1440p": {"width": 2560, "height": 1440, "scale": 1.15}, 
	"4k": {"width": 3840, "height": 2160, "scale": 1.5},     
	"user": {"width": 1800, "height": 1169, "scale": 1.1}    
}
const _u64 = {
	0: "auto",    
	1: 0.8,       
	2: 1.0,       
	3: 1.25,      
	4: 1.5        
}
const _t85 = 16  
var _c44: EditorPlugin
var _i13: EditorInterface
var _t27: ScriptEditor
var _p32: VBoxContainer
var _f74: EditorPlugin  
var _r14: _d21
var _f94: _a79
var _k94: _y58
@onready var _k9: ScrollContainer = %_v64
@onready var _s98: TextEdit = %_q62
@onready var _x16: Button = %_t22
@onready var _y18: LineEdit = %_y10
@onready var _n22: Button = %_d84
@onready var _v22: Label = %_e56
@onready var _l75: CheckButton = %_h37
@onready var _i33: Label = %_b86
@onready var _o100: HBoxContainer = %_r79
@onready var _y37: Label = %_y56
@onready var _j20: Label = %_l38
@onready var _o64: Label = %_k37
@onready var _q27: Button = %_j72
@onready var _v12: Label = %_s72
@onready var _r80: OptionButton = %_a68
@onready var _s47: OptionButton = %_e99
@onready var _f1: OptionButton = %_s81
@onready var _z1: VBoxContainer = $MarginContainer/TabContainer/Settings/_h25/VBoxContainer
@onready var _h17: TabContainer = $MarginContainer/TabContainer
@onready var _c77: ProgressBar = %_b68
@onready var _r84: Label = %_l6
@onready var _p90: Label = %_j26
@onready var _p56: Label = %_i12
@onready var _q80: OptionButton = %_a53
@onready var _v62: Panel = %_i100
@onready var _u2: Label = %_p51
@onready var _w64: TabContainer = %_o74
@onready var _i47: ItemList = %_l22
@onready var _v15: Label = %_p43
@onready var _f67: RichTextLabel = %_d81
@onready var _n90: RichTextLabel = %_y75
@onready var _m61: Button = %_f52
@onready var _g77: Button = %_d68
@onready var _b100: Button = %_y29
@onready var _m73: Button = %_n71
@onready var _e80: ItemList = %_g89
@onready var _q98: Label = %_n57
@onready var _k2: RichTextLabel = %_h13
@onready var _b72: RichTextLabel = %_i90
@onready var _l71: Button = %_f68
@onready var _b69: Button = %_d14
@onready var _u39: Button = %_j96
@onready var _j66: Button = %_y22
@onready var _a65: Button = %_j33
@onready var _r42: Button = %_w58
@onready var _l97: Button = %_i32
@onready var _s8: Button = %_r69
@onready var _m82: AcceptDialog = %_e44
@onready var _c93: LineEdit = %_k63
@onready var _l58: FileDialog = %_b85
@onready var _b84: FileDialog = %_r46
@onready var _h86: OptionButton = %_m76
@onready var _q30: Label = %_e6
var _l98: CheckBox
var _h26: OptionButton
var _g13: SpinBox
var _l21: CheckBox
var _g90: CheckBox
var _j74: Button
var _w86: _r91
var _u48: Array = []
var _h65: bool = false
var _f88: float = 0.0
var _y39: int = 0
var _a75: Dictionary = {}  
var _v60: int = 0
var _y42: int = 30000  
var _a3: Dictionary = {}
var _j42: Array[String] = []
var _n86: int = 0
var _w46: _v64
var _b39: int = -1
var _e13: int = -1
var _p89: String = ""
var _h27: bool = false
var _v79: String = ""  
var _h72: String = ""  
var _a87: bool = false
var _n70: Vector2 = Vector2.ZERO
var _q37: float = 0.0
var _t56: HBoxContainer
var _l55: OptionButton
var _o65: Label
var _g6: OptionButton  
const _y78 = [
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
var _c85: TextEdit
var _f62: Label
var _x33: Label
const _c3 = 3
var _p77: int = 0
var _p25: float = 1.0
var _k81: String = "auto"  
var _p22: int = 128000  
const _a77 = 0.85  
const _x35 = 1.0  
const _s64 = [
	"@file",
	"@selection",
	"@openscript",
	"@scene",
	"@node"
]
const _h24: int = 0
const _g63: int = 1
const _e27 = {
	_h24: "Chat",
	_g63: "Agent"
}
var _m69: _k100
var _i51: _z12
var _e36: ProgressBar
var _d30: Label
var _j99: Button
var _a69: bool = false
var _s27: VBoxContainer
var _g82: HBoxContainer
var _j95: Array = []  
var _j44: bool = false  
var _x2: HBoxContainer  
var _o20: HBoxContainer  
var _e51 = 0
var _o63 = []
var _y63 = {}
var _q78: Timer
var _x40: int = 0
var _t88: PanelContainer
var _g85: bool = false  
func _c6() -> void:
	_a75 = {}
func set_gdsense_manager(_a82: _r91) -> void:
	_w86 = _a82
	if _w86:
		if not _w86._n20.is_connected(_z46):
			_w86._n20.connect(_z46)
		if not _w86._i10.is_connected(_e47):
			_w86._i10.connect(_e47)
		if not _w86._d51.is_connected(_f49):
			_w86._d51.connect(_f49)
func set_plugin(_q48: EditorPlugin) -> void:
	_f74 = _q48
func _notification(_n44):
	if _n44 == NOTIFICATION_THEME_CHANGED:
		_c97()
func _ready() -> void:
	_x96()
	_s91.call_deferred()
	_c44 = EditorPlugin.new()
	_i13 = _c44.get_editor_interface()
	_t27 = _i13.get_script_editor()
	var _i36 = %_g22
	if _i36:
		_i36.add_theme_stylebox_override("panel", _k52)
	_x82()
	_w77()
	_r14 = _d21.new(_i13, _t27)
	_f94 = _a79.new(_r14, _i13)
	_k94 = _y58.new()
	_k94.initialize(_s98, self, _i13)
	_k94._z27.connect(_g24)
	_p32 = %_w17
	_k9.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_p32.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_n22.pressed.connect(_c90)
	_x16.pressed.connect(_g48)
	_l75.toggled.connect(_r64)
	_q27.pressed.connect(_q25)
	_r80.item_selected.connect(_r63)
	_s47.item_selected.connect(_r63)
	_s98.gui_input.connect(_u58)
	_s98.text_changed.connect(_i86)
	_v62.mouse_entered.connect(_v24)
	_v62.mouse_exited.connect(_b80)
	_v62.gui_input.connect(_c2)
	_f77()
	_v77()
	_i60()
	_q78 = Timer.new()
	_q78.wait_time = 0.5  
	_q78.one_shot = true
	_q78.timeout.connect(_e4)
	add_child(_q78)
	if _w86:
		_w86._b48.connect(_v35)
		_w86._s1.connect(_g27)
		_w86._p16.connect(_d80)
		_w86._o11.connect(_r5)
		_w86._v40.connect(_n23)
		_w86._w28.connect(_s70)
		_w86._q53.connect(_b41)
		_w86._l16.connect(_d71)
	var _y40 = _w86._a37() if _w86 else ""
	_y18.text = _y40
	if _y40.is_empty():
		if _w86 and _w86._l46():
			var env = _w86._c8()
			_v22.text = "No API Key (%s)" % env.capitalize()
		else:
			_v22.text = "API Key Not Set"
	else:
		if _w86 and _w86._l46():
			var env = _w86._c8()
			_v22.text = "API Key Loaded (%s)" % env.capitalize()
		else:
			_v22.text = "API Key Loaded"
	_b38()
	_j29()
	_z8()
	_v19()
	_k12()
	_p64()
	_e59()
	_b4.call_deferred()
	_i33.visible = false
	_o100.visible = false
	if not (_w86 and _w86._l46()):
		_v12.visible = false
	_y52()
	_j77()
func _s91():
	if not _w86:
		if _p77 >= _c3:
			return
		_p77 += 1
		if is_inside_tree():
			get_tree().create_timer(1.0).timeout.connect(_i8)
		else:
			_t66.call_deferred()
func _t66():
	if _p77 >= _c3:
		return
	_s91()
func _i8():
	if not _w86:
		if _p77 >= _c3:
			pass
		else:
			pass
	else:
		_p77 = 0
func _process(delta: float):
	if _h65:
		var elapsed_time = (Time.get_ticks_msec() / 1000.0) - _f88
		_i33.text = "Request time: %.1fs" % elapsed_time
func _u58(_x75: InputEvent):
	if _k94 and _k94._x83(_x75):
		get_viewport().set_input_as_handled()
		return
	if _x75 is InputEventKey and _x75.pressed:
		if _x75.keycode == KEY_ENTER:
			if _x75.shift_pressed:
				_s98.text += "\n"
				_s98.set_caret_line(_s98.get_line_count() - 1)
				_s98.set_caret_column(0)
				get_viewport().set_input_as_handled()
			else:
				var text = _s98.text.strip_edges()
				if text.is_empty():
					return
				_s98.text = ""
				_i86() 
				if _f1 and _f1.selected == _g63:
					_v86(text)
				else:
					_l26(text)
				get_viewport().set_input_as_handled()
func _c90():
	if _w86:
		_w86._w5(_y18.text)
func _g48():
	var _c38: String = _s98.text
	if not _c38.is_empty():
		if _f1 and _f1.selected == _g63:
			_v86(_c38)
		else:
			_l26(_c38)
func _v86(_h1: String) -> void:
	if not _m69:
		_i17("Agent mode not available", true)
		return
	var _r29 = _g12(_h1)
	if _r29.is_empty():
		return
	_s98.text = ""
	_k20(_h1)
	_u82()
	_s98.editable = false
	_x16.disabled = true
	var _s45 = {
		"godot_version": Engine.get_version_info().get("string", "4.x"),
		"project_name": ProjectSettings.get_setting("application/config/name", "")
	}
	var _m6 = ""
	if _g6:
		_m6 = _z39()
	_m69._z35(_r29, _s45, _m6)
func _l26(_c38: String):
	_v79 = _c38
	_m52()
	_u48.append({"role": "user", "content": _c38, "original_content": _c38})
	_c6()
	var _w66 = _c38
	if _c38.begins_with("@explain"):
		var _y62 = _c38.find("\n")
		if _y62 != -1:
			_w66 = _c38.substr(0, _y62) + " (code attached)"
	_k20(_w66)
	_s98.text = ""
	_s98.editable = false
	_x16.disabled = true
	_h65 = true
	_f88 = Time.get_ticks_msec() / 1000.0
	_i33.visible = true
	_o100.visible = false
	_i33.text = "Request time: 0.0s"
	_m14.call_deferred()
	var _m65 = _n4(_c38, true)
	var processed_prompt = _m65["processed_prompt"]
	var context_metadata = _m65["context_metadata"]
	if processed_prompt == "":
		_f63()
		if _u48.size() > 0:
			_u48.pop_back()
			_c6()
		return
	if processed_prompt.strip_edges().begins_with("@explain"):
		var _s73 = _m32(processed_prompt)
		if _s73.has("function_context") and not _s73["function_context"].is_empty():
			if _w86:
				_w86._h21(_u48, "@explain", _s73["function_context"], context_metadata if context_metadata else {})
		else:
			_u48[_u48.size() - 1]["content"] = processed_prompt
			if _w86:
				_w86._h21(_u48, "", "", context_metadata if context_metadata else {})
	else:
		_u48[_u48.size() - 1]["content"] = processed_prompt
		if _w86:
			_w86._h21(_u48, "", "", context_metadata if context_metadata else {})
func _v35(_d92: String, _t53: Array, _d96: String = "", _u90: String = ""):
	if not _u90.is_empty() and _u48.size() > 0:
		for i in range(_u48.size() - 1, -1, -1):
			if _u48[i].get("role", "") == "user":
				_u48[i]["content"] = _u90
				break
	var _b21 = {"role": "agent", "content": _d92}
	if not _d96.is_empty():
		_b21["thought_signature"] = _d96
	_u48.append(_b21)
	_h72 = _d96
	_c6()
	_c21(_d92, _t53)
	if _w46 and not _v79.is_empty():
		var session_id = _w86._u23() if _w86 else ""
		var _u69 = _w46._t69()
		var _e43 = (not _u69 or _u69.session_id != session_id)
		if _e43 and _u48.size() > 2:
			for i in range(0, _u48.size() - 2, 2):  
				if i + 1 < _u48.size():
					var _h35 = _u48[i]
					var _d13 = _u48[i + 1]
					if _h35.get("role", "") == "user" and _d13.get("role", "") == "agent":
						var _g7 = _d13.get("thought_signature", "")
						var _d66 = _h35.get("original_content", _h35.get("content", ""))
						var _w14 = _h35.get("content", "")
						_w46._m11(_d66, _d13.get("content", ""), session_id, _g7, _w14, "")
		var _t96 = _v79
		var _d59 = _u90 if not _u90.is_empty() else _v79
		var _s33 = _w86._x46() if _w86 else ""
		_w46._m11(_t96, _d92, session_id, _d96, _d59, _s33)
		_w46._j92()
		_v79 = ""  
		_d55()
	_f63()
	_m14.call_deferred()
	_m52.call_deferred(true)
func _g27():
	_v22.text = "Invalid API Key"
	_x93("Your API key is invalid. Please check your settings.")
	_f63()
	_m14.call_deferred()
func _d80(_j71: int, _e1: String):
	var _d4 = _a86(_e1)
	var _b14: String
	if _d4 != _e1:
		_b14 = _d4
	else:
		_b14 = "API Error %d: %s" % [_j71, _e1]
		if _j71 == 400:
			if "custom_rules" in _e1.to_lower():
				_b14 += "\n\nPlease check your custom rules in the Settings tab."
			elif "godot_version" in _e1.to_lower():
				_b14 += "\n\nGodot version detection failed. Try restarting the editor."
		elif _j71 == 422:
			_b14 += "\n\nPlease verify your custom rules and parameter settings."
	_x93(_b14)
	_f63()
	_m14.call_deferred()
func _r5():
	if _w86 and _w86._l46():
		var env = _w86._c8()
		_v22.text = "API Key Saved (%s)!" % env.capitalize()
	else:
		_v22.text = "API Key Saved!"
func _q25():
	_u48.clear()
	_c6()
	_l37()
	for _o14 in _p32.get_children():
		_o14.queue_free()
	_j77()
	_k15()
	_o100.visible = false
	_y39 = 0
	_v12.text = "Total Token Usage for this chat: 0"
	if _w46:
		_w46._y76()
		_w46._j92()
		_d55()
	if _w86:
		_w86._h76()
	_m14.call_deferred()
func _m14():
	await get_tree().process_frame
	_k9.get_v_scroll_bar().value = _k9.get_v_scroll_bar().max_value
func _n23(_z52: int, _x3: int, _s26: int):
	_y39 += _s26
	if _w86 and _w86._l46():
		_y37.text = "P: %d" % _z52
		_j20.text = "C: %d" % _x3
		_o64.text = "T: %d" % _s26
		_v12.text = "Total Token Usage for this chat: %d" % _y39
		_o100.visible = true
	else:
		_o100.visible = false
		_v12.visible = false
	_m14.call_deferred()
func _s70(success: bool):
	if success:
		pass
	else:
		pass
func _r64(_a25: bool):
	_y18.secret = not _a25
func _v24():
	Input.set_default_cursor_shape(Input.CURSOR_VSIZE)
func _b80():
	if not _a87:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
func _c2(_x75: InputEvent):
	if _x75 is InputEventMouseButton:
		if _x75.button_index == MOUSE_BUTTON_LEFT:
			if _x75.pressed:
				_a87 = true
				_n70 = _v62.get_global_mouse_position()
				_q37 = _s98.custom_minimum_size.y
			else:
				_a87 = false
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	elif _x75 is InputEventMouseMotion and _a87:
		var _t15 = _v62.get_global_mouse_position()
		var _w10 = _t15.y - _n70.y
		var _i28 = clamp(_q37 + _w10, 40.0, 600.0)
		_s98.custom_minimum_size.y = _i28
func _q86(text: String) -> String:
	var _t70: PackedStringArray = text.split("\n")
	for i in range(_t70.size()):
		var line: String = _t70[i]
		var _f5: int = 0
		for _q64 in line:
			if _q64 == ' ':
				_f5 += 1
			else:
				break
		var _t94: int = _f5 / 4
		if _t94 > 0:
			_t70[i] = "\t".repeat(_t94) + line.lstrip(" ")
	return "\n".join(_t70)
func _f63():
	_s98.editable = true
	_x16.disabled = false
	_h65 = false
	_i33.visible = false
func _t73(text: String) -> PackedStringArray:
	var _r9 = RegEx.new()
	_r9.compile("[A-Z][a-zA-Z0-9]+")
	var _a90 = _r9.search_all(text)
	var _v1: PackedStringArray = []
	for _s61 in _a90:
		_v1.append(_s61.get_string())
	return _v1
func _g17(_a61: String) -> String:
	if not ClassDB.class_exists(_a61):
		return ""
	var _l5 := ""
	var _t1 = ClassDB.class_get_method_list(_a61)
	if _t1.size() > 0:
		_l5 = "Class: " + _a61 + "\n"
	return _l5
func _d3(user_prompt: String) -> String:
	if user_prompt.strip_edges().begins_with("@explain"):
		return _y9(user_prompt)
	if not _l8(user_prompt):
		return user_prompt
	var _v1 = _t73(user_prompt)
	if _v1.is_empty():
		return user_prompt
	var _w22 = "Godot Editor Context:\n"
	for _g40 in _v1:
		var _l5 = _g17(_g40)
		if not _l5.is_empty():
			_w22 += _l5 + "\n"
	if _w22 == "Godot Editor Context:\n":
		return user_prompt
	var _o91 = _w22 + "\nUser Question: " + user_prompt
	return _o91
func _m32(user_prompt: String) -> Dictionary:
	var _s61 = {}
	var _t54 = RegEx.new()
	_t54.compile("@explain\\s+([a-zA-Z_][a-zA-Z0-9_]*)")
	var _u87 = _t54.search(user_prompt)
	var function_name = ""
	if _u87:
		function_name = _u87.get_string(1)
		_s61["function_name"] = function_name
	var _c50 = RegEx.new()
	_c50.compile("```(?:gdscript)?\n([^`]+?)```")
	var _p4 = _c50.search(user_prompt)
	if _p4:
		var _j46 = _p4.get_string(1).strip_edges()
		_s61["function_context"] = _j46
	return _s61
func _y9(user_prompt: String) -> String:
	var _t54 = RegEx.new()
	_t54.compile("@explain\\s+([a-zA-Z_][a-zA-Z0-9_]*)")
	var _s61 = _t54.search(user_prompt)
	var function_name = ""
	if _s61:
		function_name = _s61.get_string(1)
	var _x99 = "Please explain this GDScript function"
	if not function_name.is_empty():
		_x99 += " called '%s'" % function_name
	_x99 += ". Focus on:\n"
	_x99 += "- What the function does (purpose and behavior)\n"
	_x99 += "- How to use it (parameters and return value)\n"
	_x99 += "- Any important implementation details\n"
	_x99 += "- Potential improvements or best practices\n\n"
	_x99 += user_prompt.replace("@explain %s" % function_name, "").strip_edges()
	return _x99
func _g12(user_prompt: String) -> String:
	if _r14 == null:
		return user_prompt
	var _v96 = _r14._r93(user_prompt)
	var commands = _v96.get("commands", [])
	var cleaned_prompt = _v96.get("cleaned_prompt", user_prompt)
	for _u54 in commands:
		if _u54.get("type", "") == "error":
			var _x73 = _u54.get("error", "Unknown error")
			if "path traversal" in _x73.to_lower() or "not allowed" in _x73.to_lower() or "blocked" in _x73.to_lower():
				_x93("⚠️ Security: " + _x73)
				return ""
			else:
				_x93("⚠️ " + _x73)
				return ""
	if commands.is_empty():
		return user_prompt
	var _y46: Array[String] = []
	for _u54 in commands:
		var _w95 = _u54.get("type", "")
		match _w95:
			"file":
				var path = _u54.get("path", "")
				if not path.is_empty():
					_y46.append("File: " + path)
			"selection":
				var _w48 = _u54.get("script_path", "")
				var _b36 = _u54.get("line_start", 0)
				var _d11 = _u54.get("line_end", 0)
				if (_w48.is_empty() or not _w48.begins_with("res://")) and _r14:
					var _c60 = _r14._e20()
					if _c60.get("success", false):
						_w48 = _c60.get("path", "")
						_b36 = _c60.get("start_line", 0)
						_d11 = _c60.get("end_line", 0)
				if not _w48.is_empty() and _w48.begins_with("res://"):
					_y46.append("Selection in %s (lines %d-%d)" % [_w48, _b36, _d11])
			"openscript":
				var path = _u54.get("path", "")
				if path.is_empty() or not path.begins_with("res://"):
					if _r14:
						var _p50 = _r14.get_current_script()
						if _p50.get("success", false):
							path = _p50.get("path", "")
				if not path.is_empty() and path.begins_with("res://"):
					_y46.append("Open script: " + path)
			"scene":
				var path = _u54.get("path", "")
				if not path.is_empty():
					_y46.append("Scene: " + path)
			"node":
				var node_path = _u54.get("node_path", "")
				if not node_path.is_empty():
					_y46.append("Node: " + node_path)
	if _y46.is_empty():
		return cleaned_prompt
	var _h14 = "\n\n[Referenced files - use read_file to access]:\n- " + "\n- ".join(_y46)
	return cleaned_prompt + _h14
func _n4(user_prompt: String, _q20: bool = false) -> Dictionary:
	if _r14 == null or _f94 == null:
		return {"processed_prompt": user_prompt, "context_metadata": null}
	var _v96 = _r14._r93(user_prompt)
	var commands = _v96.get("commands", [])
	var cleaned_prompt = _v96.get("cleaned_prompt", user_prompt)
	if _q20:
		_u53(commands)
		for _u54 in commands:
			if _u54.get("type", "") == "openscript":
				var snapshot_id = _u54.get("snapshot_id", "")
				if snapshot_id != "" and _a3.has(snapshot_id):
					_a3[snapshot_id]["sent_in_conversation"] = true
	var _z56 = _y31(commands)
	var _n67 = _x95(_z56)
	if not _n67.is_empty():
		var _t61 = []
		_t61.append_array(_n67)
		_t61.append_array(commands)
		commands = _t61
	var _i7 = []
	for _u54 in commands:
		if _u54.get("type", "") == "error":
			var _x73 = _u54.get("error", "Unknown error")
			if _x73.begins_with("Security:"):
				_i7.append("⚠️ " + _x73)
			elif "path traversal" in _x73.to_lower() or "not allowed" in _x73.to_lower() or "blocked" in _x73.to_lower():
				_i7.append("⚠️ Security: " + _x73)
			else:
				_i7.append("⚠️ " + _x73)
	if not _i7.is_empty():
		var _x80 = "\n".join(_i7)
		_x93(_x80)
		return {"processed_prompt": "", "context_metadata": null}
	if commands.is_empty():
		return {"processed_prompt": user_prompt, "context_metadata": null}
	var _v58 = _f94._m83(cleaned_prompt, commands)
	var _k71 = _f94._l2(_v58)
	if not _k71.get("valid", false):
		var _q11 = _k71.get("message", "Unknown validation error")
		_x93("Context too large: " + _q11)
		return {"processed_prompt": "", "context_metadata": null}
	var context_metadata = _j18(commands, _k71.get("estimated_tokens", 0))
	if OS.is_debug_build() and context_metadata:
		pass
	return {"processed_prompt": _v58, "context_metadata": context_metadata}
func _u53(commands: Array) -> void:
	if commands.is_empty():
		return
	var _b67 = false
	for _u54 in commands:
		if _u54.get("type", "") != "openscript":
			continue
		var snapshot_id = _u54.get("snapshot_id", "")
		if snapshot_id == "":
			snapshot_id = _z93()
			_u54["snapshot_id"] = snapshot_id
		var _w48 = _u54.get("path", "")
		var _r40 = _u54.get("content", "")
		if _r40 == "" and _r14:
			var _p50 = _r14.get_current_script()
			if _p50.get("success", false):
				_r40 = _p50.get("content", "")
				_u54["content"] = _r40
				if _w48 == "":
					_w48 = _p50.get("path", "")
					_u54["path"] = _w48
		if _r40 == "":
			continue
		if _w48 == "":
			_w48 = "current_script.gd"
			_u54["path"] = _w48
		_a3[snapshot_id] = {
			"path": _w48,
			"content": _r40,
			"size_bytes": _r40.length(),
			"created_at": _u54.get("created_at", Time.get_unix_time_from_system()),
			"sent_in_conversation": false  
		}
		if not _j42.has(snapshot_id):
			_j42.append(snapshot_id)
		_b67 = true
	if _b67:
		_b51()
func _y31(commands: Array) -> PackedStringArray:
	var _a78 = PackedStringArray()
	for _u54 in commands:
		if _u54.get("type", "") != "openscript":
			continue
		var snapshot_id = _u54.get("snapshot_id", "")
		if snapshot_id != "":
			_a78.append(snapshot_id)
	return _a78
func _x95(_c61: PackedStringArray = PackedStringArray()) -> Array:
	var commands: Array = []
	for snapshot_id in _j42:
		if _c61.has(snapshot_id):
			continue
		if not _a3.has(snapshot_id):
			continue
		var _y92 = _a3[snapshot_id]
		if _y92.get("sent_in_conversation", false):
			continue
		var _u54 = {
			"type": "openscript",
			"snapshot_id": snapshot_id,
			"path": _y92.get("path", ""),
			"content": _y92.get("content", "")
		}
		commands.append(_u54)
	return commands
func _d48(_u54: Dictionary) -> Dictionary:
	var _w48 = _u54.get("path", "")
	var _r40 = _u54.get("content", "")
	var snapshot_id = _u54.get("snapshot_id", "")
	if snapshot_id != "" and _a3.has(snapshot_id):
		var _w12 = _a3[snapshot_id]
		if _w48 == "":
			_w48 = _w12.get("path", "")
		if _r40 == "":
			_r40 = _w12.get("content", "")
	return {
		"path": _w48,
		"content": _r40,
		"snapshot_id": snapshot_id
	}
func _z93() -> String:
	_n86 += 1
	return "panel_openscript_%d_%d" % [Time.get_ticks_msec(), _n86]
func _l37() -> void:
	_a3.clear()
	_j42.clear()
	_n86 = 0
	_b51()
func _b51() -> void:
	if _w46:
		_w46._f3(_a3, _j42)
func _j18(commands: Array, _g84: int) -> Dictionary:
	var _r51 = []
	var _c13 = 0
	for _u54 in commands:
		var _e81 = {}
		var _w95 = _u54.get("type", "unknown")
		_e81["type"] = _w95
		match _w95:
			"file":
				_e81["path"] = _u54.get("path", "")
				if _u54.get("start_line", -1) > 0:
					_e81["start_line"] = _u54.get("start_line", 0)
				if _u54.get("end_line", -1) > 0:
					_e81["end_line"] = _u54.get("end_line", 0)
				if _u54.get("symbol", "") != "":
					_e81["symbol"] = _u54.get("symbol", "")
				if _r14:
					var _z92 = _r14._g65(_u54)
					if _z92.get("success", false):
						var _x1 = _z92.get("content", "").length()
						_e81["size_bytes"] = _x1
						_c13 += _x1
			"scene":
				_e81["path"] = _u54.get("path", "")
				if _u54.get("node_path", "") != "":
					_e81["node_path"] = _u54.get("node_path", "")
				if _u54.get("include_scripts", false):
					_e81["include_scripts"] = true
				var _g15 = 500  
				if _u54.get("include_scripts", false):
					_g15 += 2000  
				_e81["size_bytes"] = _g15
				_c13 += _g15
			"node":
				_e81["node_path"] = _u54.get("node_path", "")
				var _g15 = 200  
				_e81["size_bytes"] = _g15
				_c13 += _g15
			"selection":
				if _r14:
					var _c60 = _r14._e20()
					if _c60.get("success", false):
						var _x1 = _c60.get("content", "").length()
						_e81["size_bytes"] = _x1
						_c13 += _x1
						var _e32 = _c60.get("path", "")
						if _e32 != "":
							_e81["path"] = _e32
						var _q81 = _c60.get("start_line", 0)
						if _q81 > 0:
							_e81["start_line"] = _q81
						var _w100 = _c60.get("end_line", 0)
						if _w100 > 0:
							_e81["end_line"] = _w100
			"openscript":
				var _w88 = _d48(_u54)
				var _r40 = _w88.get("content", "")
				var _w48 = _w88.get("path", "")
				var snapshot_id = _w88.get("snapshot_id", "")
				if _r40 != "":
					var _x1 = _r40.length()
					_e81["size_bytes"] = _x1
					_c13 += _x1
				if _w48 != "":
					_e81["path"] = _w48
				if snapshot_id != "":
					_e81["snapshot_id"] = snapshot_id
		_r51.append(_e81)
	var _w76 = {
		"commands": _r51,
		"total_context_size": _c13,
		"command_count": commands.size(),
		"estimated_tokens": _g84
	}
	if _w86 and not _w86._u23().is_empty():
		_w76["session_id"] = _w86._u23()
	return _w76
func _l8(user_prompt: String) -> bool:
	var _y73 = [
		"CharacterBody2D", "RigidBody2D", "StaticBody2D", "Area2D",
		"Node2D", "Node3D", "Control", "Panel", "Button", "Label",
		"AnimationPlayer", "AnimationTree", "TileMap", "PackedScene",
		"Resource", "RefCounted", "Object", "Variant",
		"Vector2", "Vector3", "Transform2D", "Transform3D",
		"InputEvent", "Camera2D", "Camera3D", "CollisionShape2D"
	]
	var _a48 = user_prompt.to_lower()
	for _s76 in _y73:
		if _a48.find(_s76.to_lower()) != -1:
			return true
	return false
func _s57(code: String) -> String:
	var _d45 = ""
	var _t70 = code.split("\n")
	var _q10 = RegEx.new()
	_q10.compile("\\b(" + "|".join(_e96) + ")\\b")
	var _n94 = RegEx.new()
	_n94.compile("(?<!#)\\b(Vector2|Input|Node2D|Control|CharacterBody2D|[A-Z][a-zA-Z0-9]*)\\b")
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
func _k20(text: String):
	var _o38 = PanelContainer.new()
	_o38.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_o38.add_theme_constant_override("margin_bottom", _z32.message_gap)
	if not _w1:
		_x82()
	_o38.add_theme_stylebox_override("panel", _w1)
	var _o30 = VBoxContainer.new()
	_o30.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_o30.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var _f93 = Label.new()
	_f93.text = "You:"
	_f93.add_theme_color_override("font_color", _h70)
	var _r49 = get_theme_font_size("font_size", "Label")
	_f93.add_theme_font_size_override("font_size", int(_r49 * 1.15))
	_o30.add_child(_f93)
	var _a39 = Control.new()
	_a39.custom_minimum_size.y = 6
	_o30.add_child(_a39)
	var _t12 = ColorRect.new()
	_t12.custom_minimum_size.y = 1
	_t12.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_t12.color = _h70
	_t12.color.a = 0.5
	_o30.add_child(_t12)
	var _i97 = Control.new()
	_i97.custom_minimum_size.y = 6
	_o30.add_child(_i97)
	var _w45 = RichTextLabel.new()
	_w45.bbcode_enabled = true
	_w45.selection_enabled = true
	_w45.text = _u61(text)
	_w45.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_w45.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_w45.fit_content = true
	_w45.scroll_active = false
	_w45.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_w45.add_theme_color_override("default_color", _h70)
	_o30.add_child(_w45)
	_o38.add_child(_o30)
	_p32.add_child(_o38)
func _c21(text: String, _t53: Array = []):
	var _o38 = PanelContainer.new()
	_o38.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_o38.add_theme_constant_override("margin_bottom", _z32.message_gap)
	if not _g50:
		_x82()
	_o38.add_theme_stylebox_override("panel", _g50)
	var _o30 = VBoxContainer.new()
	_o30.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_o30.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_o30.add_theme_constant_override("separation", 4)
	var _f93 = Label.new()
	_f93.text = "GDSense:"
	_f93.add_theme_color_override("font_color", _i35)
	var _r49 = get_theme_font_size("font_size", "Label")
	_f93.add_theme_font_size_override("font_size", int(_r49 * 1.15))
	_o30.add_child(_f93)
	var _a39 = Control.new()
	_a39.custom_minimum_size.y = 6
	_o30.add_child(_a39)
	var _t12 = ColorRect.new()
	_t12.custom_minimum_size.y = 1
	_t12.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_t12.color = _i35
	_t12.color.a = 0.5
	_o30.add_child(_t12)
	var _i97 = Control.new()
	_i97.custom_minimum_size.y = 6
	_o30.add_child(_i97)
	_m93(text, _o30)
	if _t53.size() > 0:
		_s30(_t53, _o30)
	if _w86:
		var _c19 = _w86._g30()
		if not _c19.is_empty():
			_o62(_o30)
		else:
			pass
	_o38.add_child(_o30)
	_p32.add_child(_o38)
func _m93(text: String, parent: Node):
	var _c50 = RegEx.new()
	_c50.compile("```([a-zA-Z]*)\n([^`]+?)```")
	var _s10 = 0
	var _q83 = _c50.search_all(text)
	for match in _q83:
		var _w50 = text.substr(_s10, match.get_start() - _s10)
		if not _w50.strip_edges().is_empty():
			_f4(_w50.strip_edges(), parent)
		var language = match.get_string(1).to_lower()
		if language.is_empty():
			language = "gdscript"  
		var code = match.get_string(2)
		_w39(code, language, parent)
		_s10 = match.get_end()
	if _s10 < text.length():
		var _v27 = text.substr(_s10)
		if not _v27.strip_edges().is_empty():
			_f4(_v27.strip_edges(), parent)
func _f4(text: String, parent: Node):
	var _e40 = text.strip_edges()
	_e40 = _e40.replace("**", "")
	var _t20 = RegEx.new()
	_t20.compile("`([^`]+)`")
	var _j27 = _t20.search_all(_e40)
	if _j27:
		for i in range(_j27.size() - 1, -1, -1):
			var _x70 = _j27[i]
			var full_match = _x70.get_string(0)
			var content = _x70.get_string(1)
			var _q46 = _u61(content)
			var _i56 = "[i]" + _q46 + "[/i]"
			_e40 = _e40.substr(0, _x70.get_start()) + _i56 + _e40.substr(_x70.get_end())
	var _g98 = RegEx.new()
	_g98.compile("'([A-Za-z0-9_\\-\\.]+)'")
	var _x25 = _g98.search_all(_e40)
	if _x25:
		for i in range(_x25.size() - 1, -1, -1):
			var _x70 = _x25[i]
			var full_match = _x70.get_string(0)
			var content = _x70.get_string(1)
			var _q46 = _u61(content)
			var _i56 = "[i]" + _q46 + "[/i]"
			_e40 = _e40.substr(0, _x70.get_start()) + _i56 + _e40.substr(_x70.get_end())
	var _o37 = "___SAFE_ITALIC_START___"
	var _z72 = "___SAFE_ITALIC_END___"
	_e40 = _e40.replace("[i]", _o37)
	_e40 = _e40.replace("[/i]", _z72)
	if _e40.begins_with("Explanation:") or _e40.begins_with("To use this:") or _e40.begins_with("To make this work:"):
		var _k4 = _e40.split(":", true, 1)
		if _k4.size() > 1:
			_e40 = "[b]" + _u61(_k4[0]) + ":[/b]" + _u61(_k4[1])
	var _t70 = _e40.split("\n")
	var _q72 = []
	var _l79 = RegEx.new()
	_l79.compile("^(#{1,4})\\s+(.+)$")
	var _f20 = RegEx.new()
	_f20.compile("^\\|\\s*[-:]+\\s*(\\|\\s*[-:]+\\s*)+\\|\\s*$")
	var _i70: Array = []  
	var _y12 = false
	var _s77 = func():
		if _q72.is_empty():
			return
		var _i80 = "\n".join(_q72)
		_i80 = _i80.replace(_o37, "[i]")
		_i80 = _i80.replace(_z72, "[/i]")
		if _i80.strip_edges().is_empty():
			_q72.clear()
			return
		var _m77 = RichTextLabel.new()
		_m77.bbcode_enabled = true
		_m77.selection_enabled = true
		_m77.text = _i80
		_m77.add_theme_constant_override("line_separation", 6)
		_m77.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_m77.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_m77.fit_content = true
		_m77.scroll_active = false
		_m77.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		_m77.add_theme_color_override("default_color", _i35)
		parent.add_child(_m77)
		_q72.clear()
	var _k57 = func():
		if _i70.is_empty():
			return
		_s77.call()
		var _m60 = 0
		for _v98 in _i70:
			if _v98.size() > _m60:
				_m60 = _v98.size()
		if _m60 == 0:
			_i70.clear()
			_y12 = false
			return
		var _x26 = MarginContainer.new()
		_x26.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_x26.add_theme_constant_override("margin_top", 8)
		_x26.add_theme_constant_override("margin_bottom", 12)
		var _k72 = PanelContainer.new()
		_k72.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var _d93 = StyleBoxFlat.new()
		_d93.bg_color = Color(0.15, 0.15, 0.18, 1.0)
		_d93.set_corner_radius_all(6)
		_d93.set_content_margin_all(12)
		_k72.add_theme_stylebox_override("panel", _d93)
		var _d44 = VBoxContainer.new()
		_d44.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_d44.add_theme_constant_override("separation", 0)
		var _x49 = GridContainer.new()
		_x49.columns = _m60
		_x49.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_x49.add_theme_constant_override("h_separation", 24)
		var _y50 = GridContainer.new()
		_y50.columns = _m60
		_y50.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_y50.add_theme_constant_override("h_separation", 24)
		_y50.add_theme_constant_override("v_separation", 10)
		var _b66 = int(14 * _p25)
		var _r74 = int(15 * _p25)
		for _f2 in range(_i70.size()):
			var _v98 = _i70[_f2]
			for _w54 in range(_m60):
				var _x28 = _v98[_w54] if _w54 < _v98.size() else ""
				_x28 = _x28.replace(_o37, "[i]")
				_x28 = _x28.replace(_z72, "[/i]")
				var _q43 = RichTextLabel.new()
				_q43.bbcode_enabled = true
				_q43.fit_content = true
				_q43.scroll_active = false
				_q43.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				_q43.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
				_q43.add_theme_color_override("default_color", _i35)
				if _f2 == 0 and _y12:
					_q43.add_theme_font_size_override("normal_font_size", _r74)
					_q43.text = "[b][u]" + _x28 + "[/u][/b]"
					_x49.add_child(_q43)
				else:
					_q43.add_theme_font_size_override("normal_font_size", _b66)
					_q43.text = _x28
					_y50.add_child(_q43)
		if _y12:
			_d44.add_child(_x49)
			var _t12 = HSeparator.new()
			_t12.add_theme_constant_override("separation", 8)
			_d44.add_child(_t12)
		_d44.add_child(_y50)
		_k72.add_child(_d44)
		_x26.add_child(_k72)
		parent.add_child(_x26)
		_i70.clear()
		_y12 = false
	for i in range(_t70.size()):
		var line = _t70[i]
		var _z10 = line.strip_edges()
		var _f25 = _f20.search(_z10) != null
		if _f25:
			if not _i70.is_empty():
				_y12 = true
			continue
		var _y1 = _l79.search(_z10)
		if _y1:
			_k57.call()
			var _u31 = _y1.get_string(1).length()
			var _j22 = _y1.get_string(2)
			var _r49 = 24  
			if _u31 == 2:
				_r49 = 20  
			elif _u31 == 3:
				_r49 = 18  
			elif _u31 == 4:
				_r49 = 16  
			var _b66 = int(_r49 * _p25)
			var _w26 = _u61(_j22)
			_q72.append("\n[b][font_size=" + str(_b66) + "]" + _w26 + "[/font_size][/b]\n")
		elif _z10.begins_with("|") and _z10.ends_with("|"):
			var _r37 = _z10.split("|")
			var _d77: Array = []
			for _z77 in _r37:
				var _w21 = _z77.strip_edges()
				if _w21.is_empty():
					continue
				if _w21.match("^-+$") or _w21.match("^:?-+:?$"):
					continue
				_d77.append(_u61(_w21))
			if not _d77.is_empty():
				_i70.append(_d77)
		elif _z10.begins_with("* "):
			_k57.call()
			var _u93 = _z10.substr(2).replace("*", "")
			_q72.append("• " + _u61(_u93))
			if i < _t70.size() - 1 and not _t70[i + 1].strip_edges().begins_with("* "):
				_q72.append("")
		elif _z10.match("^[0-9]+\\."):
			_k57.call()
			_q72.append(_u61(_z10))
		else:
			_k57.call()
			_q72.append(_u61(line.replace("*", "")))
	_k57.call()
	_s77.call()
func _w39(code: String, language: String, parent: Node):
	var _h36 = MarginContainer.new()
	_h36.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_h36.add_theme_constant_override("margin_left", 16)
	_h36.add_theme_constant_override("margin_right", 16)
	_h36.add_theme_constant_override("margin_top", 12)
	_h36.add_theme_constant_override("margin_bottom", 12)
	var _x54 = PanelContainer.new()
	_x54.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not _o75:
		_x82()
	_x54.add_theme_stylebox_override("panel", _o75)
	var _j45 = VBoxContainer.new()
	_j45.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _j19 = PanelContainer.new()
	_j19.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_j19.add_theme_stylebox_override("panel", _r33)
	var _c42 = HBoxContainer.new()
	_c42.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_c42.layout_mode = 2  
	var _v84 = Label.new()
	_v84.layout_mode = 2
	_v84.text = _t93.get(language, "Code")
	_v84.add_theme_color_override("font_color", _z82)
	_c42.add_child(_v84)
	var _j79 = Control.new()
	_j79.layout_mode = 2
	_j79.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_c42.add_child(_j79)
	var _n55 = Button.new()
	_n55.layout_mode = 2
	_n55.text = "Copy"
	_n55.flat = true
	_n55.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_n55.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	_n55.pressed.connect(func(): _r73(code))
	_c42.add_child(_n55)
	_j19.add_child(_c42)
	_j45.add_child(_j19)
	var _p44 = MarginContainer.new()
	_p44.layout_mode = 2
	_p44.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_p44.add_theme_constant_override("margin_left", _z32.code_padding)
	_p44.add_theme_constant_override("margin_right", _z32.code_padding)
	_p44.add_theme_constant_override("margin_top", _z32.code_padding)
	_p44.add_theme_constant_override("margin_bottom", _z32.code_padding)
	var _y5 = RichTextLabel.new()
	_y5.bbcode_enabled = true
	_y5.selection_enabled = true
	_y5.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_y5.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_y5.fit_content = true
	_y5.scroll_active = false
	_y5.scroll_active = false
	var _w3 = _y60("text_color")
	_y5.add_theme_color_override("default_color", _w3)
	var _d45 = _f11(code, language)
	_y5.text = _d45
	var _c84 = SystemFont.new()
	_c84.font_names = ["Consolas", "Courier New", "Monospace"]
	_y5.add_theme_font_override("normal_font", _c84)
	_y5.add_theme_font_override("mono_font", _c84)
	_p44.add_child(_y5)
	_j45.add_child(_p44)
	_x54.add_child(_j45)
	_h36.add_child(_x54)
	parent.add_child(_h36)
func _f11(code: String, language: String) -> String:
	match language:
		"gdscript", "":
			return _s57(_q86(code))
		"csharp", "cs":
			return _c92(code)
		_:
			return code
func _r73(code: String):
	DisplayServer.clipboard_set(code)
func _c92(code: String) -> String:
	var _d45 = ""
	var _t70 = code.split("\n")
	var _q10 = RegEx.new()
	_q10.compile("\\b(" + "|".join(_o95) + ")\\b")
	var _n94 = RegEx.new()
	_n94.compile("\\b([A-Z][a-zA-Z0-9]*)\\b")
	var _h93 = RegEx.new()
	_h93.compile("\\b([a-z_][a-zA-Z0-9_]*)\\s*\\(")
	var _c51 = RegEx.new()
	_c51.compile("(\"[^\"]*\"|'[^']*')")
	var _g67 = RegEx.new()
	_g67.compile("\\b\\d+(\\.\\d+)?[fFdD]?\\b")
	var _s67 = RegEx.new()
	_s67.compile("(//.*$|/\\*.*?\\*/)")
	for line in _t70:
		if line.strip_edges().is_empty():
			_d45 += "\n"
			continue
		var _j8 = line
		_j8 = _s67.sub(_j8, "[color=#%s]$1[/color]" % [_y60("comment").to_html(false)], true)
		_j8 = _c51.sub(_j8, "[color=#%s]$1[/color]" % [_y60("string").to_html(false)], true)
		_j8 = _q10.sub(_j8, "[color=#%s]$1[/color]" % [_y60("keyword").to_html(false)], true)
		_j8 = _n94.sub(_j8, "[color=#%s]$1[/color]" % [_y60("class").to_html(false)], true)
		_j8 = _h93.sub(_j8, "[color=#%s]$1[/color](" % [_y60("function").to_html(false)], true)
		_j8 = _g67.sub(_j8, "[color=#%s]$0[/color]" % [_y60("number").to_html(false)], true)
		_d45 += _j8 + "\n"
	return _d45.strip_edges()
func _x93(text: String):
	var _o38 = PanelContainer.new()
	_o38.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_o38.add_theme_constant_override("margin_bottom", _z32.message_gap)
	var _t32 = Color("#ff6666")
	if _i13:
		var theme = _i13.get_editor_theme()
		if theme:
			_t32 = theme.get_color("error_color", "Editor")
	var _j16 = StyleBoxFlat.new()
	_j16.bg_color = _t32.darkened(0.8)
	_j16.border_color = _t32
	_j16.border_width_bottom = 1
	_j16.border_width_top = 1
	_j16.border_width_left = 1
	_j16.border_width_right = 1
	_j16.corner_radius_top_left = 8
	_j16.corner_radius_top_right = 8
	_j16.corner_radius_bottom_left = 8
	_j16.corner_radius_bottom_right = 8
	_j16.content_margin_left = _z32.padding
	_j16.content_margin_right = _z32.padding
	_j16.content_margin_top = _z32.padding
	_j16.content_margin_bottom = _z32.padding
	_o38.add_theme_stylebox_override("panel", _j16)
	var _o30 = VBoxContainer.new()
	_o30.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_o30.layout_mode = 2  
	var _p24 = _t32.lightened(0.3)  
	var _q40 = Color(1.0, 0.9, 0.9)  
	var _x17 = Label.new()
	_x17.text = "GDSense Error"
	_x17.add_theme_color_override("font_color", _p24)
	_x17.add_theme_font_size_override("font_size", 16)
	_o30.add_child(_x17)
	var _w45 = Label.new()
	_w45.text = text
	_w45.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_w45.add_theme_color_override("font_color", _q40)
	_o30.add_child(_w45)
	_o38.add_child(_o30)
	_p32.add_child(_o38)
func _j77():
	var _o38 = PanelContainer.new()
	_o38.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_o38.add_theme_constant_override("margin_bottom", _z32.message_gap)
	if not _g50:
		_x82()
	_o38.add_theme_stylebox_override("panel", _g50)
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.selection_enabled = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.fit_content = true
	label.scroll_active = false
	label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	label.add_theme_color_override("default_color", _y98("font_color"))
	label.text = "[b]Welcome to GDSense![/b] Your AI coding partner for Godot."
	_o38.add_child(label)
	_p32.add_child(_o38)
func _h73(text: String):
	if text.strip_edges().is_empty():
		return
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.selection_enabled = true
	label.text = _u61(text)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.fit_content = true
	label.scroll_active = false
	label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	label.add_theme_color_override("default_color", _i35)
	_p32.add_child(label)
func _j29() -> void:
	_g6 = OptionButton.new()
	_g6.name = "AgentModelSelector"
	_a43()
	_g6.visible = false  
	_g6.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _s47:
		var _b57 = _s47.get_parent()
		if _b57:
			var _h43 = _b57.get_children().find(_s47)
			_b57.add_child(_g6)
			_b57.move_child(_g6, _h43)
func _b38():
	_r80.clear()
	_s47.clear()
	var _d34 = []
	if _w86:
		_d34 = _w86._w81()
	else:
		_d34 = [
			"openai/gpt-oss-20b",
			"gemini-2.5-flash-lite",
			"gpt-5-nano"
		]
	for _r44 in _d34:
		var _p87: String
		var _l33: String
		if _r44 is Dictionary and _r44.has("id"):
			_l33 = _r44.get("id", "")
			_p87 = _r44.get("display_name", _l33)
		else:
			_l33 = str(_r44)
			_p87 = _r21.get(_l33, _l33)
		_r80.add_item(_p87)
		_s47.add_item(_p87)
	if _w86:
		var _u19 = _w86._x46()
		if _d1(_u19, _d34):
			_f79(_u19)
		else:
			if _d34.size() > 0:
				var _l89 = _y28(_d34[0])
				_f79(_l89)
				_w86._a35(_l89)
	_e79()
func _y28(_r44) -> String:
	if _r44 is Dictionary and _r44.has("id"):
		return _r44.get("id", "")
	return str(_r44)
func _d1(_l33: String, _d34: Array) -> bool:
	for _r44 in _d34:
		var _k30 = _y28(_r44)
		if _k30 == _l33:
			return true
	return false
func _e79():
	pass
func _f46(index: int) -> String:
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
func _r63(index: int) -> void:
	var _d34 = []
	if _w86:
		_d34 = _w86._w81()
	if index < 0 or index >= _d34.size():
		return
	var _l33 = _y28(_d34[index])
	if _w86:
		_w86._a35(_l33)
	_r80.selected = index
	_s47.selected = index
	_m52(true)
func _f79(model: String) -> void:
	var _d34 = []
	if _w86:
		_d34 = _w86._w81()
	for i in range(_d34.size()):
		var _k30 = _y28(_d34[i])
		if _k30 == model:
			_r80.selected = i
			_s47.selected = i
			return
	_r80.selected = 0
	_s47.selected = 0
func _z8():
	if not _w86 or not _w86._l46():
		return
	_t56 = HBoxContainer.new()
	_t56.add_theme_constant_override("separation", 10)
	_o65 = Label.new()
	_o65.text = "Environment:"
	_t56.add_child(_o65)
	_l55 = OptionButton.new()
	_l55.add_item("Production")
	_l55.add_item("Development (localhost:8080)")
	var _s63 = _w86._c8() if _w86 else "production"
	if _s63 == "development":
		_l55.selected = 1
	else:
		_l55.selected = 0
	_l55.item_selected.connect(_c55)
	_t56.add_child(_l55)
	var _z5 = Label.new()
	_z5.text = "[DEV MODE]"
	_z5.modulate = Color(1, 0.5, 0.5)
	_t56.add_child(_z5)
	var _s14 = _y18.get_parent()
	var parent = _s14.get_parent()
	var index = parent.get_children().find(_s14)
	parent.add_child(_t56)
	parent.move_child(_t56, index + 1)
func _a43() -> void:
	if not _g6:
		return
	_g6.clear()
	var _d34 = []
	if _w86:
		_d34 = _w86._c63()
	if _d34.size() > 0 and _d34[0] is Dictionary and _d34[0].has("id"):
		for _r44 in _d34:
			var _p87 = _r44.get("display_name", _r44.get("id", "Unknown"))
			_g6.add_item(_p87)
	else:
		for _u51 in _y78:
			_g6.add_item(_u51["name"])
	_g6.selected = 0  
func _z39() -> String:
	if not _g6:
		return ""
	var _u62 = _g6.selected
	if _u62 < 0:
		return ""
	var _d34 = []
	if _w86:
		_d34 = _w86._c63()
	if _d34.size() > 0 and _d34[0] is Dictionary and _d34[0].has("id"):
		if _u62 < _d34.size():
			return _d34[_u62].get("id", "")
	else:
		if _u62 < _y78.size():
			return _y78[_u62]["id"]
	return ""
func _c55(index: int):
	var _r38 = ["production", "development"][index]
	var _y40 = ""
	if _w86:
		_w86._z21(_r38)
		_y40 = _w86._a37()
		_y18.text = _y40
	if _y40.is_empty():
		_v22.text = "No API Key (%s)" % _r38.capitalize()
	else:
		_v22.text = "API Key Loaded (%s)" % _r38.capitalize()
func _v19():
	if not _z1:
		return
	var _t12 = HSeparator.new()
	_z1.add_child(_t12)
	var _g100 = VBoxContainer.new()
	_g100.add_theme_constant_override("separation", 5)
	_z1.add_child(_g100)
	var _r89 = Label.new()
	_r89.text = "Ghost Text Autocomplete"
	_r89.add_theme_font_size_override("font_size", int(20 * _p25))
	_g100.add_child(_r89)
	_l98 = CheckBox.new()
	_l98.text = "Enable Autocomplete"
	_l98.button_pressed = true  
	_l98.toggled.connect(_u16)
	_g100.add_child(_l98)
	var _r43 = HBoxContainer.new()
	_r43.layout_mode = 2
	_g100.add_child(_r43)
	var _o3 = Label.new()
	_o3.text = "Trigger Mode:"
	_o3.custom_minimum_size.x = 150
	_r43.add_child(_o3)
	_h26 = OptionButton.new()
	_h26.layout_mode = 2
	_h26.add_item("Automatic")
	_h26.add_item("Manual (Ctrl+Space)")
	_h26.selected = 0
	_h26.item_selected.connect(_y81)
	_r43.add_child(_h26)
	var _d63 = HBoxContainer.new()
	_d63.layout_mode = 2
	_g100.add_child(_d63)
	var _m98 = Label.new()
	_m98.text = "Minimum Characters:"
	_m98.custom_minimum_size.x = 150
	_d63.add_child(_m98)
	_g13 = SpinBox.new()
	_g13.layout_mode = 2
	_g13.min_value = 1
	_g13.max_value = 10
	_g13.value = 3
	_g13.step = 1
	_g13.value_changed.connect(_w82)
	_d63.add_child(_g13)
	var _w52 = Label.new()
	_w52.text = "Smart triggers: After '.', '(', ':', '=', or space following keywords"
	_w52.layout_mode = 2
	var _c26 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_w52.add_theme_color_override("font_color", Color(_c26, 0.6))
	_w52.set_meta("secondary", true)
	_w52.add_theme_font_size_override("font_size", 12)
	_w52.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_g100.add_child(_w52)
	var _m26 = HSeparator.new()
	_g100.add_child(_m26)
	var _i89 = HBoxContainer.new()
	_i89.layout_mode = 2
	_g100.add_child(_i89)
	var _b81 = Label.new()
	_b81.text = "Inline Explain Buttons"
	_b81.add_theme_font_size_override("font_size", int(16 * _p25))
	_i89.add_child(_b81)
	_l21 = CheckBox.new()
	_l21.text = "Show Explain Buttons Above Functions"
	_l21.button_pressed = true  
	_l21.toggled.connect(_e11)
	_g100.add_child(_l21)
	var _u91 = Label.new()
	_u91.text = "Adds clickable help icons above function declarations to explain code"
	_u91.layout_mode = 2
	var _q35 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_u91.add_theme_color_override("font_color", Color(_q35, 0.6))
	_u91.set_meta("secondary", true)
	_u91.add_theme_font_size_override("font_size", 12)
	_u91.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_g100.add_child(_u91)
	var _n56 = HSeparator.new()
	_g100.add_child(_n56)
	var _n95 = Label.new()
	_n95.text = "Inline Refactor Buttons"
	_n95.add_theme_font_size_override("font_size", int(18 * _p25))
	_g100.add_child(_n95)
	_g90 = CheckBox.new()
	_g90.text = "Show Refactor Buttons Above Functions"
	_g90.button_pressed = true  
	_g90.toggled.connect(_l76)
	_g100.add_child(_g90)
	var _e70 = Label.new()
	_e70.text = "Adds clickable ↻ icons above function declarations for AI-powered refactoring"
	_e70.layout_mode = 2
	var _b23 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_e70.add_theme_color_override("font_color", Color(_b23, 0.6))
	_e70.set_meta("secondary", true)
	_e70.add_theme_font_size_override("font_size", 12)
	_e70.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_g100.add_child(_e70)
	var _l72 = HSeparator.new()
	_g100.add_child(_l72)
	_b40(_g100)
	_p46()
func _p46():
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		_l98.button_pressed = config.get_value("autocomplete", "enabled", true)
		var mode = config.get_value("autocomplete", "mode", "automatic")
		_h26.selected = 0 if mode == "automatic" else 1
		_g13.value = config.get_value("autocomplete", "min_chars", 3)
		_l21.button_pressed = config.get_value("explain_button", "enabled", true)
		_g90.button_pressed = config.get_value("refactor_button", "enabled", true)
		var _z28 = find_child("_o68", true)
		var _r17 = find_child("_k19", true)
		var _c32 = find_child("_q54", true)
		if _z28:
			_z28.button_pressed = config.get_value("undo", "enabled", true)
		if _r17:
			_r17.value = config.get_value("undo", "max_history_items", 20)
		if _c32:
			_c32.button_pressed = config.get_value("undo", "show_history_button", true)
func _r95():
	var mode = "automatic" if _h26.selected == 0 else "manual"
	const _r55 = 1000
	const _a73 = 150
	if _f74 and _f74.has_method("save_autocomplete_config"):
		_f74.save_autocomplete_config(
			_l98.button_pressed,
			_r55,
			_a73,
			mode,
			int(_g13.value)
		)
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_api_key.cfg")
		config.set_value("autocomplete", "enabled", _l98.button_pressed)
		config.set_value("autocomplete", "delay_ms", _r55)
		config.set_value("autocomplete", "max_length", _a73)
		config.set_value("autocomplete", "mode", mode)
		config.set_value("autocomplete", "min_chars", int(_g13.value))
		config.save("user://gdsense_api_key.cfg")
func _u16(enabled: bool):
	_r95()
func _y81(index: int):
	_r95()
func _w82(value: float):
	_r95()
func _e11(enabled: bool):
	if _f74 and _f74.has_method("save_explain_button_config"):
		_f74.save_explain_button_config(enabled)
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_api_key.cfg")
		config.set_value("explain_button", "enabled", enabled)
		config.save("user://gdsense_api_key.cfg")
func _l76(enabled: bool):
	if _f74 and _f74.has_method("save_refactor_config"):
		_f74.save_refactor_config(enabled)
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_api_key.cfg")
		config.set_value("refactor_button", "enabled", enabled)
		config.save("user://gdsense_api_key.cfg")
func _b40(_t100: VBoxContainer):
	var _l87 = Label.new()
	_l87.text = "Refactor Undo System"
	_l87.add_theme_font_size_override("font_size", int(18 * _p25))
	_t100.add_child(_l87)
	var _z28 = CheckBox.new()
	_z28.name = "UndoEnabledCheckbox"
	_z28.text = "Enable Undo for Refactored Functions"
	_z28.button_pressed = true  
	_z28.toggled.connect(_o72)
	_t100.add_child(_z28)
	var _i14 = HBoxContainer.new()
	_i14.layout_mode = 2
	_t100.add_child(_i14)
	var _p8 = Label.new()
	_p8.text = "Max History Items:"
	_p8.custom_minimum_size.x = 150
	_i14.add_child(_p8)
	var _r17 = SpinBox.new()
	_r17.name = "MaxHistorySpinbox"
	_r17.layout_mode = 2
	_r17.min_value = 5
	_r17.max_value = 50
	_r17.value = 20
	_r17.step = 1
	_r17.value_changed.connect(_h83)
	_i14.add_child(_r17)
	var _c32 = CheckBox.new()
	_c32.name = "ShowHistoryCheckbox"
	_c32.text = "Show History Button in Panel"
	_c32.button_pressed = true  
	_c32.toggled.connect(_g10)
	_t100.add_child(_c32)
	var _r36 = Label.new()
	_r36.text = "Track refactored functions with visual indicators and one-click undo"
	_r36.layout_mode = 2
	_r36.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_r36.add_theme_font_size_override("font_size", 12)
	_r36.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_t100.add_child(_r36)
func _o72(enabled: bool):
	if _f74 and _f74.has_method("save_undo_config"):
		_f74.save_undo_config(enabled)
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_settings.cfg")
		config.set_value("undo", "enabled", enabled)
		config.save("user://gdsense_settings.cfg")
func _h83(value: float):
	if _f74 and _f74.has_method("save_undo_max_history"):
		_f74.save_undo_max_history(int(value))
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_settings.cfg")
		config.set_value("undo", "max_history_items", int(value))
		config.save("user://gdsense_settings.cfg")
func _g10(enabled: bool):
	if _f74 and _f74.has_method("save_undo_show_history"):
		_f74.save_undo_show_history(enabled)
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_settings.cfg")
		config.set_value("undo", "show_history_button", enabled)
		config.save("user://gdsense_settings.cfg")
func _k12():
	if not _z1:
		return
	var _t12 = HSeparator.new()
	_z1.add_child(_t12)
	var _k7 = VBoxContainer.new()
	_k7.add_theme_constant_override("separation", 10)
	_z1.add_child(_k7)
	var _q13 = Label.new()
	_q13.text = "Custom Instructions"
	_q13.add_theme_font_size_override("font_size", int(20 * _p25))
	_k7.add_child(_q13)
	var _k95 = HBoxContainer.new()
	_k7.add_child(_k95)
	var _z85 = Label.new()
	_z85.text = "Godot Version:"
	_z85.custom_minimum_size.x = 120
	_k95.add_child(_z85)
	var _d38 = Label.new()
	_d38.text = _w86._k25() if _w86 else "Unknown"
	var _j87 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_d38.add_theme_color_override("font_color", Color(_j87, 0.6))
	_d38.set_meta("secondary", true)
	_k95.add_child(_d38)
	var _o47 = HBoxContainer.new()
	_k7.add_child(_o47)
	var _u40 = Label.new()
	_u40.text = "Temperature:"
	_u40.custom_minimum_size.x = 120
	_o47.add_child(_u40)
	var _g35 = SpinBox.new()
	_g35.name = "TemperatureSpinBox"
	_g35.min_value = 0.0
	_g35.max_value = 1.0
	_g35.step = 0.1
	_g35.value = 0.0
	_g35.value_changed.connect(_g52)
	_o47.add_child(_g35)
	var _p20 = Label.new()
	_p20.text = "(0.0 = use default)"
	var _c14 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_p20.add_theme_color_override("font_color", Color(_c14, 0.6))
	_p20.set_meta("secondary", true)
	_p20.add_theme_font_size_override("font_size", 11)
	_o47.add_child(_p20)
	var _f82 = Label.new()
	_f82.text = "Custom Rules (500 char limit):"
	_f82.add_theme_font_size_override("font_size", int(18 * _p25))
	_k7.add_child(_f82)
	_c85 = TextEdit.new()
	_c85.name = "CustomRulesInput"
	_c85.custom_minimum_size = Vector2(0, 100)
	_c85.placeholder_text = "Enter custom rules for AI responses (one per line)..."
	_c85.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_c85.text_changed.connect(_q41)
	_k7.add_child(_c85)
	_f62 = Label.new()
	_f62.name = "CharCounter"
	_f62.text = "0/500"
	_f62.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_f62.add_theme_font_size_override("font_size", 12)
	_f62.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_k7.add_child(_f62)
	_x33 = Label.new()
	_x33.name = "ValidationMessage"
	_x33.text = ""
	_x33.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	_x33.add_theme_font_size_override("font_size", 12)
	_x33.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_x33.visible = false
	_k7.add_child(_x33)
	_m5.call_deferred()
func _p64():
	_w46 = _v64.new()
	_w46._z60()
	if _i47:
		_i47.item_selected.connect(_q36)
	if _e80:
		_e80.item_selected.connect(_w90)
	if _m61:
		_m61.pressed.connect(_w44)
	if _g77:
		_g77.pressed.connect(_b17)
	if _b100:
		_b100.pressed.connect(_u56)
	if _m73:
		_m73.pressed.connect(_k68)
	if _l71:
		_l71.pressed.connect(_s17)
	if _b69:
		_b69.pressed.connect(_x78)
	if _u39:
		_u39.pressed.connect(_n73)
	if _j66:
		_j66.pressed.connect(_v82)
	if _a65:
		_a65.pressed.connect(_m44)
	if _r42:
		_r42.pressed.connect(_e31)
	if _l97:
		_l97.pressed.connect(_x9)
	if _s8:
		_s8.pressed.connect(_r97)
	if _l58:
		_l58.file_selected.connect(_t82)
	if _b84:
		_b84.file_selected.connect(_o22)
	if _m82:
		_m82.confirmed.connect(_d49)
	_w25()
	_d55()
func _e59():
	if _h86:
		_h86.item_selected.connect(_k91)
	_x71()
	var _e21 = _i59()
	var _y14 = _e87()
	_q30.text = "Auto: %.0f%% (%s detected). Your resolution: %dx%d" % [
		_y14 * 100,
		_e21,
		get_viewport().get_visible_rect().size.x,
		get_viewport().get_visible_rect().size.y
	]
	_b45()
func _i59() -> String:
	var _f15 = get_viewport().get_visible_rect().size
	var width = int(_f15.x)
	var height = int(_f15.y)
	if width < 800 or width > 16384 or height < 600 or height > 16384:
		width = 1920
		height = 1080
	var _o7 = 100
	for _r47 in _i54:
		var _s56 = _i54[_r47]
		if abs(width - _s56.width) <= _o7 and abs(height - _s56.height) <= _o7:
			return _r47
	var _m24 = width * height
	var _s79 = "1080p"
	var _w37 = INF
	for _r47 in _i54:
		var _s56 = _i54[_r47]
		var _i43 = _s56.width * _s56.height
		var _f56 = abs(_m24 - _i43)
		if _f56 < _w37:
			_w37 = _f56
			_s79 = _r47
	return _s79
func _e87() -> float:
	var _r47 = _i59()
	return _i54[_r47].scale
func _h94() -> float:
	if _k81 == "auto":
		return _e87()
	else:
		var _z55 = float(_k81)
		_z55 = clamp(_z55, 0.5, 3.0)  
		if is_nan(_z55) or is_inf(_z55):
			_z55 = 1.0  
		return _z55
func _b45():
	_p25 = _h94()
	var _d95 = int(_t85 * _p25)
	var _l25 = get_node_or_null("MarginContainer/TabContainer/History")
	if _l25:
		for label in _i68(_l25):
			if label is Label:
				label.add_theme_font_size_override("font_size", _d95)
			elif label is RichTextLabel:
				label.add_theme_font_size_override("normal_font_size", _d95)
	_s83(_d95)
func _s83(_d95: int):
	var _h50 = get_node_or_null("MarginContainer/TabContainer/Settings/_h25/VBoxContainer")
	if not _h50:
		return
	var _w36 = ["Ghost Text Autocomplete", "Custom Instructions"]
	var _o18 = ["Inline Explain Buttons", "Inline Refactor Buttons", "Refactor Undo System",
					   "Custom Rules", "Parameter Overrides"]
	for _o14 in _i68(_h50):
		if _o14 is Label:
			var _v73 = _o14.text
			var target_size = _d95
			for _i92 in _w36:
				if _v73.begins_with(_i92):
					target_size = int(20 * _p25)
					break
			if target_size == _d95:  
				for _z43 in _o18:
					if _v73.begins_with(_z43):
						target_size = int(18 * _p25)
						break
			_o14.add_theme_font_size_override("font_size", target_size)
		elif _o14 is RichTextLabel:
			_o14.add_theme_font_size_override("normal_font_size", _d95)
func _m71(text: String) -> bool:
	var _r4 = [
		"highest-volume", "smart triggers", "fixed settings", "adds clickable",
		"track refactored", "use default", "auto detects", "char limit",
		"following keywords", "second delay", "token max", "help icons",
		"visual indicators", "one-click undo", "AI-powered"
	]
	for _s76 in _r4:
		if _s76 in text:
			return true
	return false
func _i68(node: Node) -> Array:
	var children = []
	for _o14 in node.get_children():
		children.append(_o14)
		children.append_array(_i68(_o14))
	return children
func _k91(index: int):
	var _p12 = _u64[index]
	if typeof(_p12) == TYPE_STRING and _p12 == "auto":
		_k81 = "auto"
	else:
		_k81 = str(_p12)
	_z6()
	_b45()
	if _k81 == "auto":
		var _e21 = _i59()
		var _y14 = _e87()
		_q30.text = "Auto: %.0f%% (%s detected). Your resolution: %dx%d" % [
			_y14 * 100,
			_e21,
			get_viewport().get_visible_rect().size.x,
			get_viewport().get_visible_rect().size.y
		]
	else:
		_q30.text = "Manual: %.0f%%. Auto detects based on 1080p/1440p/4K presets" % [
			float(_k81) * 100
		]
func _z6():
	var config = ConfigFile.new()
	config.load("user://gdsense_settings.cfg")
	config.set_value("font_scale", "mode", _k81)
	config.save("user://gdsense_settings.cfg")
func _x71():
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		_k81 = config.get_value("font_scale", "mode", "auto")
		if _k81 == "auto":
			_h86.selected = 0
		elif _k81 == "0.8":
			_h86.selected = 1
		elif _k81 == "1.0":
			_h86.selected = 2
		elif _k81 == "1.25":
			_h86.selected = 3
		elif _k81 == "1.5":
			_h86.selected = 4
	else:
		_k81 = "auto"
		_h86.selected = 0
func _o62(parent: Node) -> void:
	var _j47 = HBoxContainer.new()
	_j47.add_theme_constant_override("separation", 10)
	var _j79 = Control.new()
	_j79.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_j47.add_child(_j79)
	var _l85 = Button.new()
	_l85.text = "👍"
	_l85.tooltip_text = "Good response"
	_l85.flat = false  
	_l85.custom_minimum_size = Vector2(36, 36)  
	_l85.add_theme_font_size_override("font_size", 16)
	_l85.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	_l85.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9))
	_l85.add_theme_stylebox_override("normal", _m22())
	_l85.add_theme_stylebox_override("hover", _s41())
	_l85.add_theme_stylebox_override("pressed", _x67())
	_l85.pressed.connect(_a50)
	_n10(_l85)
	_j47.add_child(_l85)
	var _c86 = Button.new()
	_c86.text = "👎"
	_c86.tooltip_text = "Poor response"
	_c86.flat = false  
	_c86.custom_minimum_size = Vector2(36, 36)  
	_c86.add_theme_font_size_override("font_size", 16)
	_c86.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	_c86.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9))
	_c86.add_theme_stylebox_override("normal", _m22())
	_c86.add_theme_stylebox_override("hover", _s41())
	_c86.add_theme_stylebox_override("pressed", _x67())
	_c86.pressed.connect(_z22)
	_n10(_c86)
	_j47.add_child(_c86)
	parent.add_child(_j47)
func _m22() -> StyleBoxFlat:
	var _u49 = StyleBoxFlat.new()
	_u49.bg_color = Color(0, 0, 0, 0)  
	_u49.set_corner_radius_all(4)
	return _u49
func _s41() -> StyleBoxFlat:
	var _u49 = StyleBoxFlat.new()
	_u49.bg_color = Color(0.3, 0.3, 0.3, 0.3)  
	_u49.set_corner_radius_all(6)
	_u49.set_border_width_all(1)
	_u49.border_color = Color(0.5, 0.5, 0.5, 0.5)
	return _u49
func _x67() -> StyleBoxFlat:
	var _u49 = StyleBoxFlat.new()
	_u49.bg_color = Color(0.2, 0.2, 0.2, 0.4)  
	_u49.set_corner_radius_all(6)
	_u49.set_border_width_all(1)
	_u49.border_color = Color(0.4, 0.4, 0.4, 0.6)
	return _u49
func _n10(_l100: Button) -> void:
	_l100.set_meta("original_scale", Vector2.ONE)
	_l100.set_meta("is_hovering", false)
	_l100.modulate.a = 0.7  
	_l100.pivot_offset = _l100.custom_minimum_size / 2  
	_l100.mouse_entered.connect(_m18.bind(_l100))
	_l100.mouse_exited.connect(_w41.bind(_l100))
	_l100.button_down.connect(_z54.bind(_l100))
	_l100.button_up.connect(_n17.bind(_l100))
func _m18(_l100: Button) -> void:
	if _l100.get_meta("is_hovering", false):
		return
	_l100.set_meta("is_hovering", true)
	var _l13 = get_tree().create_tween()
	_l13.set_parallel(true)
	_l13.set_ease(Tween.EASE_OUT)
	_l13.set_trans(Tween.TRANS_CUBIC)
	_l13.tween_property(_l100, "scale", Vector2(1.2, 1.2), 0.2)
	_l13.tween_property(_l100, "modulate:a", 1.0, 0.2)
	_l13.tween_property(_l100, "modulate", Color(1.1, 1.1, 1.1, 1.0), 0.2)
func _w41(_l100: Button) -> void:
	_l100.set_meta("is_hovering", false)
	var _l13 = get_tree().create_tween()
	_l13.set_parallel(true)
	_l13.set_ease(Tween.EASE_OUT)
	_l13.set_trans(Tween.TRANS_CUBIC)
	_l13.tween_property(_l100, "scale", Vector2.ONE, 0.2)
	_l13.tween_property(_l100, "modulate", Color(1.0, 1.0, 1.0, 0.7), 0.2)
func _z54(_l100: Button) -> void:
	var _l13 = get_tree().create_tween()
	_l13.set_ease(Tween.EASE_OUT)
	_l13.set_trans(Tween.TRANS_CUBIC)
	_l13.tween_property(_l100, "scale", Vector2(0.95, 0.95), 0.1)
func _n17(_l100: Button) -> void:
	var _s62 = Vector2(1.2, 1.2) if _l100.get_meta("is_hovering", false) else Vector2.ONE
	var _l13 = get_tree().create_tween()
	_l13.set_ease(Tween.EASE_OUT)
	_l13.set_trans(Tween.TRANS_CUBIC)
	_l13.tween_property(_l100, "scale", _s62, 0.1)
func _a50():
	if _w86:
		_w86._g46("positive", "helpful", "")
func _z22():
	_l70()
func _l70():
	var _w7 = AcceptDialog.new()
	_w7.title = "Help Us Improve"
	_w7.dialog_close_on_escape = true
	_w7.size = Vector2(400, 300)
	var _o30 = VBoxContainer.new()
	_o30.add_theme_constant_override("separation", 10)
	var _j13 = Label.new()
	_j13.text = "What was wrong with this response?"
	_o30.add_child(_j13)
	var _w30 = OptionButton.new()
	_w30.name = "CategoryOptions"
	_w30.add_item("Incorrect information")
	_w30.add_item("Wrong Godot version")
	_w30.add_item("Code doesn't work")
	_w30.add_item("Too complex")
	_w30.add_item("Not helpful")
	_w30.add_item("Other")
	_o30.add_child(_w30)
	var _f48 = Label.new()
	_f48.text = "Additional details (optional):"
	_o30.add_child(_f48)
	var _x22 = TextEdit.new()
	_x22.name = "DetailsText"
	_x22.custom_minimum_size = Vector2(0, 80)
	_x22.placeholder_text = "Describe what went wrong..."
	_o30.add_child(_x22)
	var _m99 = HBoxContainer.new()
	_m99.alignment = BoxContainer.ALIGNMENT_END
	var _f38 = Button.new()
	_f38.text = "Cancel"
	_f38.pressed.connect(_w7.hide)
	_m99.add_child(_f38)
	var _x34 = Button.new()
	_x34.text = "Submit Feedback"
	_x34.pressed.connect(_f87.bind(_w7))
	_m99.add_child(_x34)
	_o30.add_child(_m99)
	_w7.add_child(_o30)
	add_child(_w7)
	_w7.popup_centered()
func _f87(_c41: AcceptDialog):
	var _o30 = _c41.get_child(0)
	var _w30: OptionButton = null
	var _x22: TextEdit = null
	for _o14 in _o30.get_children():
		if _o14 is OptionButton and not _w30:
			_w30 = _o14
		elif _o14 is TextEdit and not _x22:
			_x22 = _o14
	var _w55 = ""
	if _w30.selected >= 0:
		_w55 = _w30.get_item_text(_w30.selected)
	var details = _x22.text.strip_edges()
	if _w86:
		_w86._g46("negative", _w55, details)
	_c41.hide()
	_c41.queue_free()
func _q41():
	if not _c85 or not _f62 or not _x33:
		return
	var _h67 = _c85.text
	var _g25 = _h67.length()
	_f62.text = "%d/500" % _g25
	if _g25 > 500:
		_f62.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	elif _g25 > 400:
		_f62.add_theme_color_override("font_color", Color(1.0, 0.8, 0.5))
	else:
		_f62.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	if _w86:
		var _o92 = _w86._p21(_h67)
		if _o92.get("valid", false):
			_x33.visible = false
			_w86._w32(_h67)
		else:
			var _j59 = _o92.get("errors", ["Unknown error"])
			_x33.text = _j59[0] if not _j59.is_empty() else "Unknown error"
			_x33.visible = true
func _g52(value: float):
	if _w86:
		var _g8 = find_child("_x85", true)
		var max_tokens = _g8.value if _g8 else 0
		_w86._z51(value, int(max_tokens))
func _a52(value: float):
	if _w86:
		var _g35 = find_child("_p92", true)
		var _f47 = _g35.value if _g35 else 0.0
		_w86._z51(_f47, int(value))
func _m5():
	if not _w86:
		return
	var _g35 = find_child("_p92", true)
	var _g8 = find_child("_x85", true)
	if _c85:
		var config = ConfigFile.new()
		if config.load("user://gdsense_settings.cfg") == OK:
			var _h67 = config.get_value("custom_rules", "rules_text", "")
			_c85.text = _h67
			if _f62:
				_f62.text = "%d/500" % _h67.length()
		else:
			pass
	else:
		pass
	if _g35:
		var config = ConfigFile.new()
		if config.load("user://gdsense_settings.cfg") == OK:
			var _f47 = config.get_value("parameters", "temperature_override", 0.0)
			_g35.value = _f47
	if _g8:
		var config = ConfigFile.new()
		if config.load("user://gdsense_settings.cfg") == OK:
			var max_tokens = config.get_value("parameters", "max_tokens_override", 0)
			_g8.value = max_tokens
func _s30(_g42: Array, parent: Node):
	var _t12 = HSeparator.new()
	_t12.add_theme_constant_override("separation", 8)
	parent.add_child(_t12)
	var _v14 = Label.new()
	_v14.text = "📚 Documentation Sources:"
	_v14.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	_v14.add_theme_font_size_override("font_size", 25)
	parent.add_child(_v14)
	var _l65 = VBoxContainer.new()
	_l65.add_theme_constant_override("separation", 1)
	parent.add_child(_l65)
	_g42.sort_custom(func(a, b): return a.get("priority", 0.0) > b.get("priority", 0.0))
	var _t80 = min(_g42.size(), 5)
	for i in range(_t80):
		var source = _g42[i]
		var _w79 = source.get("url", "")
		var title = source.get("title", "Godot Documentation")
		if not _w79.is_empty():
			var _y3 = HBoxContainer.new()
			_y3.add_theme_constant_override("separation", 8)
			_l65.add_child(_y3)
			var _d76 = Label.new()
			_d76.text = "•"
			_d76.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
			_d76.custom_minimum_size.x = 12
			_y3.add_child(_d76)
			var _p34 = Button.new()
			var _w89 = title if title.length() <= 60 else title.substr(0, 57) + "..."
			_p34.text = _w89
			_p34.tooltip_text = title  
			_p34.flat = true
			_p34.clip_text = true  
			_p34.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
			_p34.add_theme_color_override("font_hover_color", Color(0.8, 0.9, 1.0))
			_p34.add_theme_font_size_override("font_size", 20)
			_p34.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_p34.alignment = HORIZONTAL_ALIGNMENT_LEFT
			_p34.pressed.connect(_o21.bind(_w79))
			_y3.add_child(_p34)
func _o21(_w79: String):
	OS.shell_open(_w79)
func send_explain_request(function_name: String, _j46: String):
	if not _w86:
		return
	var _h49 = "@explain %s\n\nFunction source:\n```gdscript\n%s\n```" % [function_name, _j46]
	_l26(_h49)
func _j3(function_name: String, _j46: String):
	if not _s98:
		return
	_s98.text = ""
	var _h49 = "@explain %s\n\nFunction source:\n```gdscript\n%s\n```" % [function_name, _j46]
	_s98.text = _h49
	_s98.grab_focus()
	_s98.set_caret_line(_s98.get_line_count() - 1)
	_s98.set_caret_column(_s98.get_line(_s98.get_line_count() - 1).length())
func _exit_tree() -> void:
	_l37()
	_a59()
	_a8()
	_u77()
	if _m69:
		if _m69._r45.is_connected(_u12):
			_m69._r45.disconnect(_u12)
		if _m69._h96.is_connected(_j4):
			_m69._h96.disconnect(_j4)
		if _m69._l92.is_connected(_n76):
			_m69._l92.disconnect(_n76)
		if _m69._o9.is_connected(_i69):
			_m69._o9.disconnect(_i69)
		if _m69._a44.is_connected(_q74):
			_m69._a44.disconnect(_q74)
		if _m69._i57.is_connected(_h85):
			_m69._i57.disconnect(_h85)
		if _m69._d69.is_connected(_s40):
			_m69._d69.disconnect(_s40)
		if _m69._k43.is_connected(_r98):
			_m69._k43.disconnect(_r98)
		_m69._o36()
		_m69 = null
	_i51 = null
	if is_instance_valid(_j74):
		if _j74.pressed.is_connected(_d65):
			_j74.pressed.disconnect(_d65)
		_j74.queue_free()
		_j74 = null
	if _r14:
		if _r14._m86:
			_r14._m86.clear()
		_r14 = null
	if _f94:
		_f94._r14 = null
		_f94 = null
	if _k94:
		_k94._o36()
		_k94 = null
	if _p32:
		for _o14 in _p32.get_children():
			_o14.queue_free()
		_p32 = null
	_u48.clear()
	if _w86:
		if _w86._b48.is_connected(_v35):
			_w86._b48.disconnect(_v35)
		if _w86._s1.is_connected(_g27):
			_w86._s1.disconnect(_g27)
		if _w86._p16.is_connected(_d80):
			_w86._p16.disconnect(_d80)
		if _w86._o11.is_connected(_r5):
			_w86._o11.disconnect(_r5)
		if _w86._v40.is_connected(_n23):
			_w86._v40.disconnect(_n23)
		if _w86._w28.is_connected(_s70):
			_w86._w28.disconnect(_s70)
		if _w86._l16.is_connected(_d71):
			_w86._l16.disconnect(_d71)
	if _c44:
		_c44.free()
		_c44 = null
	_i13 = null
	_t27 = null
	_w86 = null
	_f74 = null
func _f77() -> void:
	if _c77:
		_c77.custom_minimum_size.y = 8
		_c77.show_percentage = false
		var _j76 = StyleBoxFlat.new()
		_j76.bg_color = Color(0.1, 0.1, 0.1, 0.5)
		_j76.corner_radius_top_left = 4
		_j76.corner_radius_top_right = 4
		_j76.corner_radius_bottom_left = 4
		_j76.corner_radius_bottom_right = 4
		_c77.add_theme_stylebox_override("background", _j76)
		_c77.mouse_entered.connect(_n36)
		_c77.mouse_exited.connect(_l39)
	_q85(0.0)
	if _r84:
		_r84.mouse_entered.connect(_n36)
		_r84.mouse_exited.connect(_l39)
func _v77() -> void:
	if not _q80:
		return
	_q80.clear()
	_q80.add_item("Commands")
	_q80.selected = 0
	_q80.add_separator()
	for _u54 in _s64:
		_q80.add_item(_u54)
	_q80.item_selected.connect(_m17)
func _i60() -> void:
	if not _f1:
		return
	_f1.clear()
	_f1.add_item(_e27[_h24])
	_s28()
	_f1.item_selected.connect(_e89)
	_q89()
func _q89() -> void:
	if not _f1 or not _i13:
		return
func _s28() -> void:
	if not _f1:
		return
	var _v48 = false
	if _w86:
		var _j25 = _w86._f61()
		if _j25 and _j25.has("features"):
			var features = _j25.get("features", {})
			_v48 = features.get("agent", false)
	var _e12 = _f1.item_count > 1
	if _v48:
		if not _e12:
			_f1.add_item(_e27[_g63])
	else:
		if _e12:
			if _f1.selected == _g63:
				_f1.selected = _h24
				_u83()
			_f1.remove_item(_g63)
func _e89(index: int) -> void:
	match index:
		_h24:
			_a69 = false
			if _r80:
				_r80.visible = true
			if _s47:
				_s47.visible = true
			if _g6:
				_g6.visible = false
			_s98.placeholder_text = "Ask me anything about Godot..."
		_g63:
			_s85()
	_s98.grab_focus()
func _i86() -> void:
	_c6()
	var _d86 = _s98.text
	var command_count = 0
	for _q49 in _s64:
		var _r9 = RegEx.new()
		_r9.compile(_q49 + "\\b")  
		var _q83 = _r9.search_all(_d86)
		command_count += _q83.size()
	if command_count != _x40:
		_x40 = command_count
		if _q78:
			_q78.stop()
			_q78.start()
func _e4() -> void:
	_m52(true)
func _g24(_u54: String, path: String) -> void:
	_m52(true)
func _m52(_j80: bool = false) -> void:
	if _h65 and not _j80:
		return
	var _d86 = _s98.text
	var _k67 = not _d86.strip_edges().is_empty()
	var _m12 = _u48.size() > 0
	if not _k67 and not _m12:
		_l91(0, [])
		return
	var _n75 = Time.get_ticks_msec()
	if not _j80 and not _a75.is_empty():
		var _i88 = _n75 - _a75.get("time", 0)
		if _i88 < _y42:
			var _w42 = _a75.get("tokens", 0)
			var _n69 = _a75.get("breakdown", [])
			_l91(_w42, _n69)
			return
	if _r84:
		_r84.text = "Context: Updating..."
	if _w86 and not _w86._a37().is_empty():
		var messages = []
		for message in _u48:
			messages.append(message)
		var context_metadata: Dictionary = {}
		if _k67:
			var _m65 = _n4(_d86, false)
			var processed_prompt = _m65.get("processed_prompt", _d86)
			if not processed_prompt.is_empty():
				messages.append({
					"role": "user",
					"content": processed_prompt
				})
			var _w76 = _m65.get("context_metadata", {})
			if _w76 == null or not _w76 is Dictionary:
				_w76 = {}
			context_metadata = _w76
		else:
			context_metadata = {}
		_w86._d74(messages, context_metadata)
	else:
		_h20()
func _h20() -> void:
	var _d86 = _s98.text
	var _m65 = _n4(_d86, false)
	var estimated_tokens = _m65.get("estimated_tokens", 0)
	var _w75 = _x55()
	var _m19 = estimated_tokens + _w75
	var breakdown = [
		{"name": "current_prompt", "tokens": estimated_tokens},
		{"name": "chat_history", "tokens": _w75}
	]
	_l91(_m19, breakdown)
func _b41(_s26: int, breakdown: Array, _t43: int = 128000) -> void:
	_p22 = _t43
	_a75 = {
		"tokens": _s26,
		"breakdown": breakdown,
		"limit": _t43,
		"time": Time.get_ticks_msec()
	}
	_l91(_s26, breakdown)
func _x55() -> int:
	var _s71 = 0
	for message in _u48:
		if message.has("content"):
			_s71 += message["content"].length()
	return _s71 / 4
func _l91(tokens: int, breakdown: Array) -> void:
	_e51 = tokens
	_o63 = breakdown
	var _n33 = float(tokens) / float(_p22) * 100.0
	if _c77:
		var _b88 = min(_n33, 100.0)
		if _b88 > 0 and _b88 < 0.5:
			_b88 = 0.5  
		_c77.value = _b88
	if _r84:
		if _n33 < 1.0 and _n33 > 0:
			_r84.text = "Context: " + str(snapped(_n33, 0.1)) + "%"
		else:
			_r84.text = "Context: " + str(int(_n33)) + "%"
		if _n33 >= 100.0:
			_r84.modulate = Color.RED
		elif _n33 >= 85.0:
			_r84.modulate = Color.YELLOW
		else:
			_r84.modulate = Color.LIGHT_GREEN
	_q85(_n33 / 100.0)
	if _n33 >= 95.0 and _w86:
		var _w68 = _w86._x46() if _w86 else ""
		_w86._i10.emit("critical", _w68, _n33, "")
	elif _n33 >= 90.0 and _w86:
		var _w68 = _w86._x46() if _w86 else ""
		_w86._i10.emit("high", _w68, _n33, "")
	elif _n33 >= 75.0 and _w86:
		var _w68 = _w86._x46() if _w86 else ""
		_w86._i10.emit("medium", _w68, _n33, "")
	if _n33 >= _a77 * 100.0:
		_p90.show()
		if _n33 >= 100.0:
			_p90.text = "⚠ Context capacity exceeded! Please reduce content."
			_p90.modulate = Color.RED
		else:
			_p90.text = "⚠ Context capacity at " + str(int(_n33)) + "% - consider reducing @ commands"
			_p90.modulate = Color.YELLOW
	else:
		_p90.hide()
func _k15() -> void:
	_l91(0, [])
	if _c77:
		_c77.tooltip_text = ""
	if _r84:
		_r84.tooltip_text = ""
	if _p56:
		_p56.hide()
func _q85(_v5: float) -> void:
	var color: Color
	if _v5 <= 0.6:  
		color = Color.GREEN
	elif _v5 <= 0.85:  
		color = Color.YELLOW
	else:  
		color = Color.RED
	var _z66 = StyleBoxFlat.new()
	_z66.bg_color = color
	_z66.corner_radius_top_left = 4
	_z66.corner_radius_top_right = 4
	_z66.corner_radius_bottom_left = 4
	_z66.corner_radius_bottom_right = 4
	if _c77:
		_c77.add_theme_stylebox_override("fill", _z66)
func _n36() -> void:
	var tooltip_text = "Context Usage Breakdown:\n"
	if _o63.size() > 0:
		for _s38 in _o63:
			if _s38 is Dictionary and _s38.has("name") and _s38.has("tokens"):
				var _f7 = _s38["tokens"]
				var _t2 = float(_f7) / float(_p22) * 100.0
				tooltip_text += str(_s38["name"]) + ": " + str(int(_t2)) + "%\n"
		tooltip_text = tooltip_text.rstrip("\n")
	else:
		tooltip_text += "No breakdown available"
	if _c77:
		_c77.tooltip_text = tooltip_text
	if _r84:
		_r84.tooltip_text = tooltip_text
func _l39() -> void:
	if _c77:
		_c77.tooltip_text = ""
	if _r84:
		_r84.tooltip_text = ""
func _m17(index: int) -> void:
	if index <= 1:
		return
	var _o35 = index - 2
	if _o35 >= 0 and _o35 < _s64.size():
		var _u54 = _s64[_o35]
		var _d86 = _s98.text
		var _p99 = _s98.get_caret_line()
		var caret_column = _s98.get_caret_column()
		if _p99 < _s98.get_line_count():
			var _i71 = _s98.get_line(_p99)
			var _n61 = _i71.substr(0, caret_column)
			var _b73 = _i71.substr(caret_column)
			var _v25 = _n61 + _u54 + " " + _b73
			_s98.set_line(_p99, _v25)
			_s98.set_caret_column(caret_column + _u54.length() + 1)
		else:
			_s98.text += _u54 + " "
			_s98.set_caret_column(_s98.text.length())
		_q80.selected = 0
		_m52()
		_s98.grab_focus()
func _q38(_d92: String) -> bool:
	var _t72 = [
		"truncated",
		"trimmed",
		"shortened",
		"context limit",
		"content limited"
	]
	var _p85 = _d92.to_lower()
	for _p6 in _t72:
		if _p6 in _p85:
			return true
	return false
func _h51(message: String) -> void:
	_p56.text = "ℹ " + message
	_p56.show()
	var _q65 = Timer.new()
	add_child(_q65)
	_q65.timeout.connect(func(): 
		_p56.hide()
		_q65.queue_free()
	)
	_q65.one_shot = true
	_q65.start(10.0)
func _a86(_t96: String) -> String:
	var _l83 = _t96.to_lower()
	if "token" in _l83 and ("limit" in _l83 or "exceed" in _l83):
		return "Your request is too large. Try reducing the amount of context or splitting into smaller requests."
	elif "rate limit" in _l83:
		return "You're sending requests too quickly. Please wait a moment before trying again."
	elif "unauthorized" in _l83 or "invalid api key" in _l83:
		return "Your API key is invalid or has expired. Please check your settings."
	elif "network" in _l83 or "connection" in _l83:
		return "Unable to connect to the AI service. Please check your internet connection."
	elif "timeout" in _l83:
		return "The request took too long to process. Please try again with a smaller request."
	elif "model" in _l83 and "not found" in _l83:
		return "The selected AI model is not available. Please try a different model."
	else:
		return _t96  
func _z46(_e69: Dictionary) -> void:
	_b38()
	_a43()
	_n26()
	_s28()
	_b70(_e69)
func _q9(_v70: String) -> String:
	if _v70.is_empty():
		return ""
	var _l82 = _v70.split("T")[0] if "T" in _v70 else _v70
	var _k4 = _l82.split("-")
	if _k4.size() < 3:
		return _v70  
	var year = _k4[0]
	var month = int(_k4[1]) if _k4[1].is_valid_int() else 0
	var day = int(_k4[2]) if _k4[2].is_valid_int() else 0
	if month < 1 or month > 12 or day < 1 or day > 31:
		return _v70  
	var _a72 = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
					   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%s %d, %s" % [_a72[month - 1], day, year]
func _e47(_h18: String, _y21: String, _n33: float, _d62: String = "") -> void:
	var _l74 = _s32()
	if _l74:
		var title = ""
		var message = ""
		var _r62 = _o85._r1.WARNING
		var _w40 = "credits"
		match _h18:
			"low":  
				title = "Usage Notice"
				message = "You've used %d%% of your %s for this period." % [int(_n33), _w40]
				_r62 = _o85._r1.INFO
			"medium":  
				title = "Usage Alert"
				message = "Heads up: you've used %d%% of your %s this period." % [int(_n33), _w40]
			"high":    
				title = "Usage Warning"
				message = "You've used %d%% of your %s. Consider switching models or upgrading." % [int(_n33), _w40]
				_r62 = _o85._r1.WARNING
			"critical": 
				title = "Critical Usage"
				message = "Critical: only %d%% of your %s remain." % [int(100 - _n33), _w40]
				_r62 = _o85._r1.ERROR
		if not _d62.is_empty():
			var _f55 = _q9(_d62)
			message += " Usage resets on %s." % _f55
		if _w86:
			var _d6 = _w86._x72()
			if _d6 != "ULTRA" and _d6 != "BETA_FREE":
				message += " Upgrade: gdsense.com/pricing"
		_l74._w70(title, message, _r62, 8.0)  
	if _h18 == "critical" and _v22:
		var _g41 = "⚠️ CRITICAL: %d%% of credits used" % [int(_n33)]
		_v22.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))  
		_v22.text = _g41
		await get_tree().create_timer(10.0).timeout
		if is_instance_valid(_v22):
			_v22.remove_theme_color_override("font_color")
			if _w86 and _w86._u76():
				_v22.text = "API Key Loaded"
				var _j25 = _w86._f61()
				if _j25 and _j25.has("tier"):
					_b70(_j25)
			else:
				_v22.text = "No API Key"
func _d71(message: String) -> void:
	var _l74 = _s32()
	if _l74:
		_l74._w70("Context Truncated", message, _o85._r1.WARNING, 5.0)
func _n26() -> void:
	if not _w86:
		return
	var _z79 = _w86._z79()
	if _g90:
		_g90.disabled = not _z79
		if not _z79:
			_g90.button_pressed = false
			_g90.tooltip_text = "Refactor is not available in Free tier"
		else:
			_g90.tooltip_text = "Show Refactor Buttons Above Functions"
	if _f74 and _f74.has_method("update_refactor_button_availability"):
		_f74.update_refactor_button_availability(_z79)
func _y52() -> void:
	if _t88:
		return  
	_t88 = PanelContainer.new()
	_t88.name = "UpdateBanner"
	_t88.visible = false
	var _g43 = StyleBoxFlat.new()
	if _i13:
		var _z80 = _i13.get_editor_settings()
		if _z80:
			var _f9 = _z80.get_setting("interface/theme/base_color")
			var _j86 = _z80.get_setting("interface/theme/accent_color")
			_g43.bg_color = _j86.lerp(_f9, 0.8)  
		else:
			_g43.bg_color = Color(0.2, 0.4, 0.6, 1.0)  
	else:
		_g43.bg_color = Color(0.2, 0.4, 0.6, 1.0)  
	_g43.set_corner_radius_all(4)
	_g43.set_content_margin_all(8)
	_t88.add_theme_stylebox_override("panel", _g43)
	var _o43 = HBoxContainer.new()
	_o43.add_theme_constant_override("separation", 8)
	var _k66 = Label.new()
	_k66.name = "UpdateMessage"
	_k66.text = "Update Available"
	_k66.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_o43.add_child(_k66)
	var _t37 = Label.new()
	_t37.name = "DownloadLink"
	_t37.text = "Download at gdsense.com"
	_t37.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))  
	_o43.add_child(_t37)
	var _t9 = Button.new()
	_t9.name = "DismissButton"
	_t9.text = "X"
	_t9.tooltip_text = "Dismiss update notification"
	_t9.custom_minimum_size = Vector2(24, 24)
	_t9.flat = true
	_t9.pressed.connect(_t68)
	_o43.add_child(_t9)
	_t88.add_child(_o43)
	var _c70 = get_node_or_null("MarginContainer/TabContainer/Chat")
	if _c70:
		var _a22 = _c70.get_child(0) if _c70.get_child_count() > 0 else null
		if _a22 and _a22 is VBoxContainer:
			_a22.add_child(_t88)
			_a22.move_child(_t88, 0)  
		else:
			_c70.add_child(_t88)
	else:
		add_child(_t88)
func _f49(_r24: String, _j37: String) -> void:
	if _g85:
		return
	if not _t88:
		_y52()
	var _k66 = _t88.find_child("_c4", true)
	if _k66:
		_k66.text = "Update Available: v%s (you have v%s)" % [_r24, _j37]
	_t88.visible = true
func _t68() -> void:
	_g85 = true
	if _t88:
		_t88.visible = false
func _b70(_e69: Dictionary) -> void:
	var _d6 = _e69.get("tier", "Unknown")
	if _v22:
		var _d86 = _v22.text
		if "API Key Loaded" in _d86:
			if _w86 and _w86._l46():
				var env = _w86._c8()
				_v22.text = "API Key Loaded (%s) - %s Tier" % [env.capitalize(), _d6]
			else:
				_v22.text = "API Key Loaded - %s Tier" % _d6
	_q94()
func _q94() -> void:
	if _j74:
		return  
	if not _v22 or not _w86:
		return
	_j74 = Button.new()
	_j74.text = "↻"  
	_j74.tooltip_text = "Refresh tier info"
	_j74.flat = true
	_j74.custom_minimum_size = Vector2(24, 24)
	_j74.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_z19(_j74)
	var parent = _v22.get_parent()
	if parent:
		var _v75 = _v22.get_index()
		parent.add_child(_j74)
		parent.move_child(_j74, _v75 + 1)
	_j74.pressed.connect(_d65)
func _d65() -> void:
	if _w86:
		_w86._e67()
func _l19(model: String) -> String:
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
func _s32() -> _o85:
	var _l74 = find_child("_o85", true)
	if _l74 and _l74 is _o85:
		return _l74
	var _j61 = preload("res://addons/gdsense/scenes/_v95.tscn")
	if _j61:
		_l74 = _j61.instantiate()
		if _c44:
			var _i13 = _c44.get_editor_interface()
			if _i13:
				_l74._o81(_i13)
		add_child(_l74)
		_l74.z_index = 1000
		return _l74
	return null
func _d55():
	if not _w46:
		return
	_l88()
	_a95()
	_o76()
func _l88():
	if not _w46 or not _i47:
		return
	var recent_chats = _w46._d27()
	_i47.clear()
	_b39 = -1
	for _y92 in recent_chats:
		var _p87 = _y92._v74()
		var timestamp = _y92._q22()
		var _z94 = "%s - %s" % [_p87, timestamp]
		var index = _i47.add_item(_z94)
		_i47.set_item_metadata(index, _y92.timestamp)
		_i47.set_item_tooltip(index, _y92._i49(80))
	_g38()
	_w25()
func _a95():
	if not _w46 or not _e80:
		return
	var favorite_chats = _w46._b31()
	_e80.clear()
	_e13 = -1
	for _y92 in favorite_chats:
		var _p87 = _y92._v74()
		var timestamp = _y92._q22()
		var _z94 = "★ %s - %s" % [_p87, timestamp]
		var index = _e80.add_item(_z94)
		_e80.set_item_metadata(index, _y92.timestamp)
		_e80.set_item_tooltip(index, _y92._i49(80))
	_y30()
	_w25()
func _o76():
	if not _w46 or not _u2:
		return
	var _w11 = _w46._d27().size()
	var _p29 = _w46._b31().size()
	_u2.text = "Recent: %d | Favorites: %d" % [_w11, _p29]
	var font_color = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_u2.add_theme_color_override("font_color", font_color)
func _q36(index: int):
	if index < 0 or not _w46:
		return
	_b39 = index
	var timestamp = _i47.get_item_metadata(index)
	var _y92 = _w46._n48(timestamp)
	if _y92:
		_v49(_y92)
	_w25()
func _w90(index: int):
	if index < 0 or not _w46:
		return
	_e13 = index
	var timestamp = _e80.get_item_metadata(index)
	var _y92 = _w46._n48(timestamp)
	if _y92:
		_k41(_y92)
	_w25()
func _v49(_y92: _v64._f57):
	if not _y92 or not _v15 or not _f67 or not _n90:
		return
	var _r18 = _y92._r13()
	_v15.text = "%s - %s (%d exchange%s)" % [
		_y92._v74(),
		_y92._q22(),
		_r18,
		"s" if _r18 != 1 else ""
	]
	_f67.bbcode_enabled = true
	_f67.text = _v23(_y92)
	var _g36 = _y92._k82 if not _y92._k82.is_empty() else "Unknown"
	_n90.text = "[Model: %s]\n[Session ID: %s]" % [_g36, _y92.session_id]
func _k41(_y92: _v64._f57):
	if not _y92 or not _q98 or not _k2 or not _b72:
		return
	var _r18 = _y92._r13()
	_q98.text = "%s - %s (%d exchange%s)" % [
		_y92._v74(),
		_y92._q22(),
		_r18,
		"s" if _r18 != 1 else ""
	]
	_k2.bbcode_enabled = true
	_k2.text = _v23(_y92)
	var _g36 = _y92._k82 if not _y92._k82.is_empty() else "Unknown"
	_b72.text = "[Model: %s]\n[Session ID: %s]" % [_g36, _y92.session_id]
func _v23(_y92: _v64._f57) -> String:
	var _e49 = ""
	for _t47 in _y92.exchanges:
		if not _t47 is Dictionary:
			continue
		var _h35 = _t47.get("user_message", "")
		if _h35.begins_with("@explain"):
			var _y62 = _h35.find("\n")
			if _y62 != -1:
				_h35 = _h35.substr(0, _y62) + " (code attached)"
		var _n18 = _h70.to_html()
		_e49 += "[b][color=#%s]You:[/color][/b]\n" % _n18
		_e49 += _u61(_h35) + "\n\n"
		var _d13 = _t47.get("ai_response", "")
		var _j36 = _i35.to_html()
		_e49 += "[b][color=#%s]GDSense:[/color][/b]\n" % _j36
		var _k4 = _d13.split("```")
		var _m72 = get_theme_color("base_color", "Editor")
		var _h34 = _m72.darkened(0.2) if _m72.get_luminance() > 0.5 else _m72.lightened(0.1)
		var _k80 = _h34.to_html()
		for i in range(_k4.size()):
			var _v32 = _k4[i]
			if i % 2 == 0:
				_e49 += _u61(_v32)
			else:
				var _n93 = _v32.find("\n")
				var _i98 = _v32
				if _n93 != -1:
					_i98 = _v32.substr(_n93 + 1)
				var _h79 = _s57(_i98)
				_e49 += "\n[bgcolor=#%s]%s[/bgcolor]\n" % [_k80, _h79]
		_e49 += "\n\n"
		_e49 += "[color=#666666]────────────────────────────────[/color]\n\n"
	return _e49
func _g38():
	if _v15:
		_v15.text = "Select a chat to preview"
	if _f67:
		_f67.text = "Select a chat to view"
	if _n90:
		_n90.text = "Select a chat to view"
func _y30():
	if _q98:
		_q98.text = "Select a favorite to preview"
	if _k2:
		_k2.text = "Select a favorite chat to view"
	if _b72:
		_b72.text = "Select a favorite chat to view"
func _u61(text: String) -> String:
	var _v83 = text
	_v83 = _v83.replace("[", "\\[")
	_v83 = _v83.replace("]", "\\]")
	return _v83
func _w25():
	var _p2 = _b39 >= 0
	if _m61:
		_m61.disabled = not _p2
	if _g77:
		_g77.disabled = not _p2
	if _b100:
		_b100.disabled = not _p2
	if _m73:
		_m73.disabled = not _p2
	var _c82 = _e13 >= 0
	if _l71:
		_l71.disabled = not _c82
	if _b69:
		_b69.disabled = not _c82
	if _u39:
		_u39.disabled = not _c82
	if _j66:
		_j66.disabled = not _c82
func _w44():
	if _b39 < 0 or not _w46:
		return
	var timestamp = _i47.get_item_metadata(_b39)
	var _y92 = _w46._n48(timestamp)
	if _y92:
		_d37(_y92)
func _b17():
	if _b39 < 0 or not _w46:
		return
	var timestamp = _i47.get_item_metadata(_b39)
	if _w46._v51(timestamp):
		_d55()
func _u56():
	if _b39 < 0 or not _w46:
		return
	var timestamp = _i47.get_item_metadata(_b39)
	var _y92 = _w46._n48(timestamp)
	if _y92:
		_p89 = timestamp
		_h27 = false
		_c93.text = _y92.custom_name
		_m82.popup_centered()
func _k68():
	if _b39 < 0 or not _w46:
		return
	var timestamp = _i47.get_item_metadata(_b39)
	if _w46._k3(timestamp):
		_d55()
func _s17():
	if _e13 < 0 or not _w46:
		return
	var timestamp = _e80.get_item_metadata(_e13)
	var _y92 = _w46._n48(timestamp)
	if _y92:
		_d37(_y92)
func _x78():
	if _e13 < 0 or not _w46:
		return
	var timestamp = _e80.get_item_metadata(_e13)
	if _w46._p78(timestamp):
		_d55()
func _n73():
	if _e13 < 0 or not _w46:
		return
	var timestamp = _e80.get_item_metadata(_e13)
	var _y92 = _w46._n48(timestamp)
	if _y92:
		_p89 = timestamp
		_h27 = true
		_c93.text = _y92.custom_name
		_m82.popup_centered()
func _v82():
	if _e13 < 0 or not _w46:
		return
	var timestamp = _e80.get_item_metadata(_e13)
	if _w46._k3(timestamp):
		_d55()
func _d49():
	if not _w46 or _p89.is_empty():
		return
	var _w72 = _c93.text.strip_edges()
	if _w46._t83(_p89, _w72):
		_d55()
	_p89 = ""
	_h27 = false
func _m44():
	if not _w46:
		return
	_w46._u70()
	_w46._j92()
	_d55()
func _e31():
	if not _w46:
		return
	_w46._l81()
	_w46._j92()
	_d55()
func _r97():
	var _l93: _v64._f57 = null
	if _i47 and _i47.get_selected_items().size() > 0:
		var _r52 = _i47.get_selected_items()[0]
		var recent_chats = _w46._d27()
		if _r52 < recent_chats.size():
			_l93 = recent_chats[_r52]
	elif _e80 and _e80.get_selected_items().size() > 0:
		var _r52 = _e80.get_selected_items()[0]
		var favorite_chats = _w46._b31()
		if _r52 < favorite_chats.size():
			_l93 = favorite_chats[_r52]
	if not _l93:
		_e74("Please select a chat session to export", Color(1, 0.7, 0.3))
		return
	var filename = "gdsense_session_%s.json" % _l93.session_id
	_l58.current_file = filename
	_l58.current_path = "user://" + filename
	_l58.popup_centered()
func _t82(path: String):
	var _l93: _v64._f57 = null
	if _i47 and _i47.get_selected_items().size() > 0:
		var _r52 = _i47.get_selected_items()[0]
		var recent_chats = _w46._d27()
		if _r52 < recent_chats.size():
			_l93 = recent_chats[_r52]
	elif _e80 and _e80.get_selected_items().size() > 0:
		var _r52 = _e80.get_selected_items()[0]
		var favorite_chats = _w46._b31()
		if _r52 < favorite_chats.size():
			_l93 = favorite_chats[_r52]
	if not _l93:
		push_error("[GDSense] Failed to export: No session selected")
		return
	var _u60 = {
		"format_version": "1.0",
		"exported_at": Time.get_datetime_string_from_system(),
		"session": _w46._q92(_l93)
	}
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		var _y80 = JSON.stringify(_u60, "\t")
		file.store_string(_y80)
		file.close()
		_e74("Session exported successfully", Color(0.3, 1, 0.5))
	else:
		push_error("[GDSense] Failed to write export file: %s" % path)
		_e74("Export failed: Could not write file", Color(1, 0.3, 0.3))
func _x9():
	_b84.current_path = "user://"
	_b84.popup_centered()
func _o22(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("[GDSense] Failed to open import file: %s" % path)
		_e74("Import failed: Could not open file", Color(1, 0.3, 0.3))
		return
	var _y80 = file.get_as_text()
	file.close()
	var json = JSON.new()
	var _v96 = json.parse(_y80)
	if _v96 != OK:
		push_error("[GDSense] Failed to parse import file: %s" % json.get_error_message())
		_e74("Import failed: Invalid JSON format", Color(1, 0.3, 0.3))
		return
	var _q15 = json.data
	if not _q15 is Dictionary:
		push_error("[GDSense] Import data is not a Dictionary")
		_e74("Import failed: Invalid data structure", Color(1, 0.3, 0.3))
		return
	if not _q15.has("format_version"):
		push_error("[GDSense] Import file missing format_version")
		_e74("Import failed: Missing format version", Color(1, 0.3, 0.3))
		return
	if _q15["format_version"] != "1.0":
		push_error("[GDSense] Unsupported format version: %s" % _q15["format_version"])
		_e74("Import failed: Unsupported format version", Color(1, 0.3, 0.3))
		return
	if not _q15.has("session"):
		push_error("[GDSense] Import file missing session data")
		_e74("Import failed: Missing session data", Color(1, 0.3, 0.3))
		return
	var _h32 = _q15["session"]
	if not _h32 is Dictionary:
		push_error("[GDSense] Session data is not a Dictionary")
		_e74("Import failed: Invalid session format", Color(1, 0.3, 0.3))
		return
	var _j17 = ["exchanges", "timestamp", "session_id"]
	for _m68 in _j17:
		if not _h32.has(_m68):
			push_error("[GDSense] Session missing required field: %s" % _m68)
			_e74("Import failed: Incomplete session data", Color(1, 0.3, 0.3))
			return
	if not _h32["exchanges"] is Array:
		push_error("[GDSense] Session exchanges is not an Array")
		_e74("Import failed: Invalid exchanges format", Color(1, 0.3, 0.3))
		return
	if _h32["exchanges"].is_empty():
		push_error("[GDSense] Session has no exchanges")
		_e74("Import failed: Empty session", Color(1, 0.3, 0.3))
		return
	for _t47 in _h32["exchanges"]:
		if not _t47 is Dictionary:
			push_error("[GDSense] Invalid exchange format")
			_e74("Import failed: Invalid exchange data", Color(1, 0.3, 0.3))
			return
		if not _t47.has("user_message") or not _t47.has("ai_response"):
			push_error("[GDSense] Exchange missing user_message or ai_response")
			_e74("Import failed: Incomplete exchange", Color(1, 0.3, 0.3))
			return
		if _t47["user_message"].length() > 100000 or _t47["ai_response"].length() > 500000:
			push_error("[GDSense] Exchange messages too long (possible attack)")
			_e74("Import failed: Messages exceed size limits", Color(1, 0.3, 0.3))
			return
		if _t47.has("enhanced_user_message") and _t47["enhanced_user_message"].length() > 200000:
			push_error("[GDSense] Enhanced message too long (possible attack)")
			_e74("Import failed: Messages exceed size limits", Color(1, 0.3, 0.3))
			return
	var _p18 = _w46._n48(_h32["timestamp"])
	if _p18:
		_e74("Warning: Session may already exist", Color(1, 0.7, 0.3))
	var _r39 = _w46._s80(_h32)
	if not _r39:
		push_error("[GDSense] Failed to convert imported data to ChatEntry")
		_e74("Import failed: Could not create session", Color(1, 0.3, 0.3))
		return
	_w46._r7.push_front(_r39)
	while _w46._r7.size() > _v64._r27:
		_w46._r7.pop_back()
	_w46._j92()
	_d55()
	_e74("Session imported successfully (%d exchanges)" % _r39._r13(), Color(0.3, 1, 0.5))
func _e74(message: String, color: Color):
	if color.r > color.g and color.r > color.b:
		pass
	else:
		pass
func _u50(message: String) -> String:
	var _b52 = _v64._f57._e88(message)
	if _b52 != message and OS.is_debug_build():
		pass
	return _b52
func _d37(_y92: _v64._f57):
	if not _y92:
		return
	_u48.clear()
	_l37()
	for _o14 in _p32.get_children():
		_o14.queue_free()
	var _a42 = _y92._e98()
	var _c74 = _y92._n78()
	_a3 = _a42 if _a42 else {}
	if _c74 and not _c74.is_empty():
		_j42 = _c74
	else:
		_j42.clear()  
	_b51()
	for _t47 in _y92.exchanges:
		if not _t47 is Dictionary:
			continue
		if not _t47.has("user_message") or not _t47.has("ai_response"):
			continue
		var _w66 = _u50(_t47["user_message"])
		if _w66.begins_with("@explain"):
			var _y62 = _w66.find("\n")
			if _y62 != -1:
				_w66 = _w66.substr(0, _y62) + " (code attached)"
		_k20(_w66)
		_c21(_t47["ai_response"], [])
		var _f23 = _t47.get("enhanced_user_message", _t47["user_message"])
		var _t96 = _u50(_t47["user_message"])
		_u48.append({"role": "user", "content": _f23, "original_content": _t96})
		var _d13 = {"role": "agent", "content": _t47["ai_response"]}
		if _t47.has("thought_signature") and not _t47["thought_signature"].is_empty():
			_d13["thought_signature"] = _t47["thought_signature"]
		_u48.append(_d13)
	if _h17:
		_h17.current_tab = 0
	_m14.call_deferred()
func _w77():
	var _b8 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	var _t36 = func(_a99: Node):
		if not _a99: return
		for _o14 in _a99.get_children():
			if _o14 is Label:
				if "Full Conversation" in _o14.text or "Session Info" in _o14.text:
					_o14.add_theme_color_override("font_color", _b8)
	if _f67:
		_t36.call(_f67.get_parent())
	if _k2:
		_t36.call(_k2.get_parent())
func _c97():
	_x82()
	_w77()
	_u3()
	if _w46:
		if _b39 >= 0:
			_q36(_b39)
		if _e13 >= 0:
			_w90(_e13)
func _u3():
	var _h50 = get_node_or_null("MarginContainer/TabContainer/Settings/_h25/VBoxContainer")
	if not _h50: return
	var _g9 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	var _m25 = Color(_g9, 0.6)
	var _x12 = func(node: Node, _s22: Callable):
		if node is Label:
			if node.has_meta("secondary"):
				node.add_theme_color_override("font_color", _m25)
			else:
				node.add_theme_color_override("font_color", _g9)
		for _o14 in node.get_children():
			_s22.call(_o14, _s22)
	_x12.call(_h50, _x12)
func _b4() -> void:
	_m69 = _k100.new()
	_m69.initialize(self, _w86)
	_m69._r45.connect(_u12)
	_m69._h96.connect(_j4)
	_m69._l92.connect(_n76)
	_m69._o9.connect(_i69)
	_m69._a44.connect(_q74)
	_m69._i57.connect(_h85)
	_m69._d69.connect(_s40)
	_m69._k43.connect(_r98)
	_i51 = _z12.new()
	_i51.initialize(_i13)
	_p61()
func _p61() -> void:
	_s27 = VBoxContainer.new()
	_s27.name = "AgentUIContainer"
	_s27.visible = false
	_s27.add_theme_constant_override("separation", 4)
	_d30 = Label.new()
	_d30.text = "Agent: Initializing..."
	_d30.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_s27.add_child(_d30)
	_e36 = ProgressBar.new()
	_e36.min_value = 0
	_e36.max_value = 100
	_e36.value = 0
	_e36.show_percentage = false
	_e36.custom_minimum_size = Vector2(0, 8)
	_s27.add_child(_e36)
	var _c70 = get_node_or_null("MarginContainer/TabContainer/Chat")
	if _c70:
		var _a22 = _c70.get_child(0) if _c70.get_child_count() > 0 else null
		if _a22 and _a22 is VBoxContainer:
			var _h74 = -1
			for i in range(_a22.get_child_count()):
				var _o14 = _a22.get_child(i)
				if _o14.name == "InputContainer" or (_o14 is HBoxContainer and _o14.get_node_or_null("_q62") != null):
					_h74 = i
					break
			if _h74 >= 0:
				_a22.add_child(_s27)
				_a22.move_child(_s27, _h74)
			else:
				_a22.add_child(_s27)
		else:
			add_child(_s27)
	else:
		add_child(_s27)
func _s85() -> void:
	_a69 = true
	if _f1 and _f1.item_count > _g63 and _f1.selected != _g63:
		_f1.selected = _g63
	if _r80:
		_r80.visible = false
	if _s47:
		_s47.visible = false
	if _g6:
		_g6.visible = true
	_s98.placeholder_text = "[Agent Mode] Describe your task..."
	_i17("Agent mode enabled. Describe your task and press Enter to start.")
func _u83() -> void:
	_a69 = false
	_j95.clear()
	_j44 = false
func _u82() -> void:
	if _s27:
		_s27.visible = true
	if _e36:
		_e36.value = 0
	if _d30:
		_d30.text = "Agent: Starting..."
	_t97()
func _a2() -> void:
	if _s27:
		_s27.visible = false
func _t97() -> void:
	_a8()  
	_x2 = HBoxContainer.new()
	_x2.name = "AgentCancelContainer"
	_x2.alignment = BoxContainer.ALIGNMENT_CENTER
	_j99 = Button.new()
	_j99.text = "Cancel Agent"
	_j99.pressed.connect(_g29)
	_x2.add_child(_j99)
	var _c70 = get_node_or_null("MarginContainer/TabContainer/Chat")
	if _c70:
		var _a22 = _c70.get_child(0) if _c70.get_child_count() > 0 else null
		if _a22 and _a22 is VBoxContainer:
			var _h74 = -1
			for i in range(_a22.get_child_count()):
				var _o14 = _a22.get_child(i)
				if _o14.name == "InputContainer" or (_o14 is HBoxContainer and _o14.get_node_or_null("_q62") != null):
					_h74 = i
					break
			if _h74 >= 0:
				_a22.add_child(_x2)
				_a22.move_child(_x2, _h74)
			else:
				_a22.add_child(_x2)
		else:
			add_child(_x2)
	else:
		add_child(_x2)
func _a8() -> void:
	if _x2 and is_instance_valid(_x2):
		_x2.queue_free()
		_x2 = null
		_j99 = null
func _n46() -> void:
	_u77()  
	_o20 = HBoxContainer.new()
	_o20.name = "AgentForceResetContainer"
	_o20.alignment = BoxContainer.ALIGNMENT_CENTER
	_o20.add_theme_constant_override("separation", 8)
	var _e10 = Button.new()
	_e10.text = "Reset Agent"
	_e10.tooltip_text = "Force reset all agent state and start fresh"
	_e10.pressed.connect(_q28)
	_o20.add_child(_e10)
	var _c70 = get_node_or_null("MarginContainer/TabContainer/Chat")
	if _c70:
		var _a22 = _c70.get_child(0) if _c70.get_child_count() > 0 else null
		if _a22 and _a22 is VBoxContainer:
			var _h74 = -1
			for i in range(_a22.get_child_count()):
				var _o14 = _a22.get_child(i)
				if _o14.name == "InputContainer" or (_o14 is HBoxContainer and _o14.get_node_or_null("_q62") != null):
					_h74 = i
					break
			if _h74 >= 0:
				_a22.add_child(_o20)
				_a22.move_child(_o20, _h74)
			else:
				_a22.add_child(_o20)
		else:
			add_child(_o20)
	else:
		add_child(_o20)
func _u77() -> void:
	if _o20 and is_instance_valid(_o20):
		_o20.queue_free()
		_o20 = null
func _q28() -> void:
	if _m69 and _m69.is_active():
		_m69._x32()
	_a2()
	_a8()
	_a59()
	_u77()
	_u83()
	_f63()
	_j95.clear()
	_j44 = false
	_i17("Agent state reset. You can start a new task.", false)
func _i17(text: String, _s39: bool = false) -> void:
	var _o38 = PanelContainer.new()
	_o38.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_o38.add_theme_constant_override("margin_bottom", _z32.message_gap)
	if not _g50:
		_x82()
	_o38.add_theme_stylebox_override("panel", _g50)
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.selection_enabled = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.fit_content = true
	label.scroll_active = false
	label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var _q40 = Color.RED if _s39 else _i35
	label.add_theme_color_override("default_color", _q40)
	label.text = "[b][Agent][/b] " + _u61(text)
	_o38.add_child(label)
	_p32.add_child(_o38)
	_m14.call_deferred()
func _i37(_v42: String, details: Array, _s39: bool = false) -> void:
	var _o38 = PanelContainer.new()
	_o38.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_o38.add_theme_constant_override("margin_bottom", _z32.message_gap)
	if not _g50:
		_x82()
	_o38.add_theme_stylebox_override("panel", _g50)
	var _a22 = VBoxContainer.new()
	_a22.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _c42 = HBoxContainer.new()
	_c42.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _d94 = Button.new()
	_d94.flat = true
	_d94.text = "▶"  
	_d94.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_d94.tooltip_text = "Click to expand/collapse"
	_z19(_d94)
	_c42.add_child(_d94)
	var _m7 = RichTextLabel.new()
	_m7.bbcode_enabled = true
	_m7.selection_enabled = true
	_m7.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_m7.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_m7.fit_content = true
	_m7.scroll_active = false
	_m7.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var _q40 = Color.RED if _s39 else _i35
	_m7.add_theme_color_override("default_color", _q40)
	_m7.text = "[b][Agent][/b] " + _u61(_v42)
	_c42.add_child(_m7)
	_a22.add_child(_c42)
	var _a29 = VBoxContainer.new()
	_a29.visible = false
	_a29.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_a29.add_theme_constant_override("separation", 4)
	var _h36 = MarginContainer.new()
	var indent_size = _v7() * 2  
	_h36.add_theme_constant_override("margin_left", indent_size)
	_h36.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _g44 = VBoxContainer.new()
	_g44.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for _s38 in details:
		var _t8 = Label.new()
		_t8.text = _s38
		_t8.add_theme_color_override("font_color", _q40.darkened(0.15))
		_z19(_t8)
		_g44.add_child(_t8)
	_h36.add_child(_g44)
	_a29.add_child(_h36)
	_a22.add_child(_a29)
	_d94.pressed.connect(func():
		_a29.visible = not _a29.visible
		_d94.text = "▼" if _a29.visible else "▶"
		_m14.call_deferred()
	)
	_o38.add_child(_a22)
	_p32.add_child(_o38)
	_m14.call_deferred()
func _z19(_e62: Control) -> void:
	if _c44:
		var _i13 = _c44.get_editor_interface()
		if _i13:
			var theme = _i13.get_editor_theme()
			if theme:
				var _h47 = theme.get_font("main", "EditorFonts")
				if _h47:
					_e62.add_theme_font_override("font", _h47)
				var _t34 = theme.get_font_size("main_size", "EditorFonts")
				if _t34 > 0:
					_e62.add_theme_font_size_override("font_size", _t34)
func _v7() -> int:
	if _c44:
		var _i13 = _c44.get_editor_interface()
		if _i13:
			var theme = _i13.get_editor_theme()
			if theme:
				var _t34 = theme.get_font_size("main_size", "EditorFonts")
				if _t34 > 0:
					return _t34
	return 14  
func _u12(session_id: String) -> void:
	_i17("Agent session started. Analyzing your request...")
func _j4(status: Dictionary) -> void:
	var progress = status.get("progress_percent", 0)
	var _x69 = status.get("status_message", "Processing...")
	if _x69 == null:
		_x69 = "Processing..."
	if _e36:
		_e36.value = progress
	if _d30:
		_d30.text = "Agent: " + _x69
	if status.has("tier"):
		var _d6 = status.get("tier", "")
		if _d6 is String and not _d6.is_empty() and _w86:
			_w86._v10(_d6)
func _n76(_i6: Array) -> void:
	if _i6.is_empty():
		return
	var _y64: Array = []
	var _z84: Array = []
	for _b87 in _i6:
		var _h10 = _b87.get("tool_name", "")
		var _o53 = _i51._o53(_h10)
		if _o53:
			_z84.append(_b87)
		else:
			_y64.append(_b87)
	for _b87 in _y64:
		var _h10 = _b87.get("tool_name", "")
		var _t51 = _b87.get("tool_call_id", "")
		var _m4 = _b87.get("parameters", {})
		if _m4 == null:
			_m4 = {}
		var _s61 = _i51._c48(_h10, _m4)
		_m69._r88(_t51, true, _s61)
		_x15(_h10, _m4, _s61)
	for _b87 in _z84:
		_j95.append(_b87)
	if not _j44 and _j95.size() > 0:
		_o70()
func _o70() -> void:
	if _j95.is_empty():
		_j44 = false
		return
	_j44 = true
	var _b87 = _j95.pop_front()
	var _h10 = _b87.get("tool_name", "")
	var _t51 = _b87.get("tool_call_id", "")
	var _c41 = _o88.new()
	_c41._o81(_i13)
	_c41._e35(_b87)
	_c41._w53.connect(_b20.bind(_t51))
	_c41._j69.connect(_n2.bind(_t51))
	add_child(_c41)
	_c41.popup_centered()
func _b20(_b87: Dictionary, _x30: Dictionary, _t51: String) -> void:
	var _h10 = _b87.get("tool_name", "")
	if _h10 == null:
		_h10 = ""
	var _m4 = _b87.get("parameters", {})
	if _m4 == null:
		_m4 = {}
	var _s61 = _i51._c48(_h10, _m4)
	_m69._r88(_t51, true, _s61)
	_x15(_h10, _m4, _s61)
	_o70()
func _n2(_b87: Dictionary, _e1: String, _t51: String) -> void:
	var _h10 = _b87.get("tool_name", "")
	if _h10 == null:
		_h10 = ""
	var _m4 = _b87.get("parameters", {})
	if _m4 == null:
		_m4 = {}
	_m69._r88(_t51, false, {}, _e1)
	var path = _m4.get("path", "")
	if path == null:
		path = ""
	if not path.is_empty():
		_i17("Rejected " + _h10 + ": " + path)
	else:
		_i17("Rejected: " + _h10)
	_o70()
func _i69(message: String) -> void:
	_c21(message, [])
	_i17("Tip: Reopen modified scenes or reload the project to see changes")
	_a2()
	_a8()  
	_a59()
	_u77()  
	_u83()
	_f63()
func _q74(error: String) -> void:
	_i17("Agent failed: " + error, true)
	_a2()
	_n46()
	_a59()
func _h85() -> void:
	_i17("Agent cancelled")
	_a2()
	_a8()  
	_a59()
	_u77()  
	_u83()
	_f63()
func _s40(session_id: String, message: String) -> void:
	var _s100 = message + " You can continue to allow more processing."
	_i17(_s100, true)
	_e63()
	_a2()
	_a8()  
func _r98(message: String, _x58: String) -> void:
	if message.is_empty() and _x58.is_empty():
		return
	if not message.is_empty():
		_c21(message, [])
	if not _x58.is_empty():
		_u74(_x58)
func _u74(_x58: String) -> void:
	var _o38 = PanelContainer.new()
	_o38.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_o38.add_theme_constant_override("margin_bottom", _z32.message_gap)
	if not _g50:
		_x82()
	_o38.add_theme_stylebox_override("panel", _g50)
	var _a22 = VBoxContainer.new()
	_a22.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _c42 = HBoxContainer.new()
	_c42.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _d94 = Button.new()
	_d94.flat = true
	_d94.text = ">"  
	_d94.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_d94.tooltip_text = "Click to expand/collapse reasoning"
	_z19(_d94)
	_c42.add_child(_d94)
	var _m7 = RichTextLabel.new()
	_m7.bbcode_enabled = true
	_m7.selection_enabled = true
	_m7.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_m7.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_m7.fit_content = true
	_m7.scroll_active = false
	_m7.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var _x8 = _i35.darkened(0.2)
	_m7.add_theme_color_override("default_color", _x8)
	_m7.text = "[i]View reasoning[/i]"
	_c42.add_child(_m7)
	_a22.add_child(_c42)
	var _a29 = VBoxContainer.new()
	_a29.visible = false
	_a29.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_a29.add_theme_constant_override("separation", 4)
	var _h36 = MarginContainer.new()
	var indent_size = _v7() * 2  
	_h36.add_theme_constant_override("margin_left", indent_size)
	_h36.add_theme_constant_override("margin_top", 4)
	_h36.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _j34 = RichTextLabel.new()
	_j34.bbcode_enabled = true
	_j34.selection_enabled = true
	_j34.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_j34.fit_content = true
	_j34.scroll_active = false
	_j34.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_j34.add_theme_color_override("default_color", _x8)
	_j34.text = _u61(_x58)
	_h36.add_child(_j34)
	_a29.add_child(_h36)
	_a22.add_child(_a29)
	_d94.pressed.connect(func():
		_a29.visible = not _a29.visible
		_d94.text = "v" if _a29.visible else ">"
		_m14.call_deferred()
	)
	_o38.add_child(_a22)
	_p32.add_child(_o38)
	_m14.call_deferred()
func _e63() -> void:
	_a59()  
	_g82 = HBoxContainer.new()
	_g82.name = "AgentContinueContainer"
	_g82.alignment = BoxContainer.ALIGNMENT_CENTER
	_g82.add_theme_constant_override("separation", 8)
	var _p49 = Button.new()
	_p49.text = "Continue Session"
	_p49.pressed.connect(_b46)
	_g82.add_child(_p49)
	var _t9 = Button.new()
	_t9.text = "Start New Task"
	_t9.pressed.connect(_t86)
	_g82.add_child(_t9)
	var _c70 = get_node_or_null("MarginContainer/TabContainer/Chat")
	if _c70:
		var _a22 = _c70.get_child(0) if _c70.get_child_count() > 0 else null
		if _a22 and _a22 is VBoxContainer:
			var _h74 = -1
			for i in range(_a22.get_child_count()):
				var _o14 = _a22.get_child(i)
				if _o14.name == "InputContainer" or (_o14 is HBoxContainer and _o14.get_node_or_null("_q62") != null):
					_h74 = i
					break
			if _h74 >= 0:
				_a22.add_child(_g82)
				_a22.move_child(_g82, _h74)
			else:
				_a22.add_child(_g82)
		else:
			add_child(_g82)
	else:
		add_child(_g82)
func _b46() -> void:
	_a59()
	_u82()
	if _m69:
		_m69._m87()
func _t86() -> void:
	_a59()
	_u77()  
	if _m69:
		_m69._p91()
	_u83()
	_f63()
func _a59() -> void:
	if _g82 and is_instance_valid(_g82):
		_g82.queue_free()
		_g82 = null
func _g29() -> void:
	if _m69 and _m69.is_active():
		_m69._x32()
func _y32(_h10: String, _m4: Dictionary, _s61: Dictionary) -> Dictionary:
	var success = _s61.get("success", false)
	var _u26 = "✓ " if success else "✗ "
	var details: Array = []
	match _h10:
		"read_file":
			var path = _m4.get("path", "unknown")
			if success:
				var content = _s61.get("content", "")
				var _j12 = content.count("\n") + 1 if not content.is_empty() else 0
				return {"summary": _u26 + "Read file: " + path + " (" + str(_j12) + " lines)", "details": [], "is_error": false}
			else:
				return {"summary": _u26 + "Failed to read: " + path, "details": [], "is_error": true}
		"list_files":
			var path = _m4.get("path", "res://")
			if success:
				var _s82 = _s61.get("files", [])
				var _a41 = _s61.get("directories", [])
				var _x88 = _s82.size() if _s82 is Array else 0
				var _u20 = _a41.size() if _a41 is Array else 0
				for _p60 in _a41:
					details.append("📁 " + str(_p60) + "/")
				for _y38 in _s82:
					details.append("📄 " + str(_y38))
				return {"summary": _u26 + "Listed " + path + " (" + str(_x88) + " files, " + str(_u20) + " dirs)", "details": details, "is_error": false}
			else:
				return {"summary": _u26 + "Failed to list: " + path, "details": [], "is_error": true}
		"get_project_info":
			if success:
				var _g88 = _s61.get("project_name", "Unknown")
				var _k16 = _s61.get("godot_version", "")
				details.append("Project: " + str(_g88))
				details.append("Godot: " + str(_k16))
				if _s61.has("main_scene"):
					details.append("Main Scene: " + str(_s61.get("main_scene")))
				return {"summary": _u26 + "Project: " + _g88 + " (Godot " + _k16 + ")", "details": details, "is_error": false}
			else:
				return {"summary": _u26 + "Failed to get project info", "details": [], "is_error": true}
		"run_project":
			if success:
				return {"summary": _u26 + "Running project in debug mode", "details": [], "is_error": false}
			else:
				return {"summary": _u26 + "Failed to run project", "details": [], "is_error": true}
		"stop_project":
			if success:
				return {"summary": _u26 + "Stopped project", "details": [], "is_error": false}
			else:
				return {"summary": _u26 + "Failed to stop project", "details": [], "is_error": true}
		"create_file":
			var path = _m4.get("path", "unknown")
			if success:
				return {"summary": _u26 + "Created: " + path, "details": [], "is_error": false}
			else:
				var _x73 = _s61.get("error", "Unknown error")
				return {"summary": _u26 + "Failed to create " + path + ": " + _x73, "details": [], "is_error": true}
		"edit_file":
			var path = _m4.get("path", "unknown")
			if success:
				return {"summary": _u26 + "Modified: " + path, "details": [], "is_error": false}
			else:
				var _x73 = _s61.get("error", "Unknown error")
				return {"summary": _u26 + "Failed to edit " + path + ": " + _x73, "details": [], "is_error": true}
		"delete_file":
			var path = _m4.get("path", "unknown")
			if success:
				return {"summary": _u26 + "Deleted: " + path, "details": [], "is_error": false}
			else:
				var _x73 = _s61.get("error", "Unknown error")
				return {"summary": _u26 + "Failed to delete " + path + ": " + _x73, "details": [], "is_error": true}
		_:
			if success:
				return {"summary": _u26 + "Executed: " + _h10, "details": [], "is_error": false}
			else:
				return {"summary": _u26 + "Failed: " + _h10, "details": [], "is_error": true}
func _x15(_h10: String, _m4: Dictionary, _s61: Dictionary) -> void:
	var status = _y32(_h10, _m4, _s61)
	var _v42 = status.get("summary", "")
	var details = status.get("details", [])
	var _s39 = status.get("is_error", false)
	if details.size() > 0:
		_i37(_v42, details, _s39)
	else:
		_i17(_v42, _s39)
