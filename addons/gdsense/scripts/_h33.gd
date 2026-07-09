@tool
extends Control

func _z45(type: String) -> Color:
	if _t15:
		var _e45 = _t15.get_editor_settings()
		if _e45:
			match type:
				"text_color": return _e45.get_setting("text_editor/theme/highlighting/text_color")
				"comment": return _e45.get_setting("text_editor/theme/highlighting/comment_color")
				"string": return _e45.get_setting("text_editor/theme/highlighting/string_color")
				"number": return _e45.get_setting("text_editor/theme/highlighting/number_color")
				"keyword": return _e45.get_setting("text_editor/theme/highlighting/keyword_color")
				"class": return _e45.get_setting("text_editor/theme/highlighting/base_type_color")
				"function": return _e45.get_setting("text_editor/theme/highlighting/function_color")
				"symbol": return _e45.get_setting("text_editor/theme/highlighting/symbol_color")
	
	match type:
		"comment": return Color.GRAY
		"string": return Color.ORANGE
		"number": return Color.SKY_BLUE
		"keyword": return Color.PALE_VIOLET_RED
		"class": return Color.LIGHT_GREEN
		"function": return Color.LIGHT_BLUE
		"symbol": return Color.WHITE
	return Color.WHITE

const _y51 = [
	"if", "elif", "else", "for", "while", "match", "break", "continue", "pass",
	"return", "class", "extends", "is", "as", "self", "super", "func", "signal",
	"const", "var", "static", "enum", "in", "not", "and", "or", "true", "false",
	"null", "export", "onready", "tool", "setget", "breakpoint", "preload", "yield",
	"assert", "remote", "sync", "master", "puppet"
]

const _d10 = [
	"public", "private", "protected", "internal", "static", "void", 
	"class", "interface", "namespace", "using", "new", "this", "base",
	"if", "else", "for", "foreach", "while", "do", "switch", "case",
	"return", "throw", "try", "catch", "finally", "async", "await",
	"var", "const", "readonly", "override", "virtual", "abstract",
	"int", "string", "bool", "float", "double", "decimal", "byte", "true", "false", "null"
]

func _c91():
	if not _t15:
		return
		
	var theme = _t15.get_editor_theme()
	if not theme:
		return

	var _t29 = theme.get_color("base_color", "Editor")
	var _d18 = theme.get_color("dark_color_2", "Editor")
	var _s35 = theme.get_color("contrast_color_1", "Editor")
	var font_color = theme.get_color("font_color", "Editor")
	var _p38 = theme.get_color("accent_color", "Editor")
	
	if not _a37:
		_v27()
	
	var _x93 = _t29.lerp(_p38, 0.1)

	if _t29.get_luminance() > 0.5:
		_x93 = _t29.darkened(0.05).lerp(_p38, 0.1)
		
	_a37.bg_color = _x93
	_a37.border_color = _p38.darkened(0.3)
	
	if _x93.get_luminance() > 0.5:
		_c85 = Color.BLACK
	else:
		_c85 = Color(0.9, 0.9, 0.9) 
	
	var _b62 = _d18
	
	_e91.bg_color = _b62
	_e91.border_color = _b62.lightened(0.05)
	
	_k9 = font_color
	
	var _o75 = _d73("normal", "TextEdit")
	if _o75 is StyleBoxFlat:
		_i65.bg_color = _o75.bg_color
		_i65.border_color = _o75.border_color
		_i65.border_width_left = _o75.border_width_left
		_i65.border_width_top = _o75.border_width_top
		_i65.border_width_right = _o75.border_width_right
		_i65.border_width_bottom = _o75.border_width_bottom
		_i65.corner_radius_top_left = _o75.corner_radius_top_left
		_i65.corner_radius_top_right = _o75.corner_radius_top_right
		_i65.corner_radius_bottom_right = _o75.corner_radius_bottom_right
		_i65.corner_radius_bottom_left = _o75.corner_radius_bottom_left
	else:
		_i65.bg_color = _t29
		_i65.border_color = _t29.lightened(0.1)
	
	_a84.bg_color = _d18
	_a84.border_color = _d18.lightened(0.1)
	
	_s82 = font_color
	
	_f30.bg_color = _d18.lightened(0.05)

func _y67(name: String, type: String = "Editor") -> Color:
	if _t15:
		var theme = _t15.get_editor_theme()
		if theme:
			return theme.get_color(name, type)
	return Color.GRAY 

func _d73(name: String, type: String = "Editor") -> StyleBox:
	if _t15:
		var theme = _t15.get_editor_theme()
		if theme:
			return theme.get_stylebox(name, type)
	return null

var _a37: StyleBoxFlat
var _e91: StyleBoxFlat
var _a84: StyleBoxFlat
var _f30: StyleBoxFlat
var _i65: StyleBoxFlat

var _c85: Color
var _k9: Color
var _s82: Color

const _r5 = {
	"message_gap": 16,
	"padding": 12,
	"code_padding": 10
}

func _v27():
	_a37 = StyleBoxFlat.new()
	_a37.corner_radius_top_left = 8
	_a37.corner_radius_top_right = 8
	_a37.corner_radius_bottom_left = 8
	_a37.corner_radius_bottom_right = 8
	_a37.content_margin_left = _r5.padding
	_a37.content_margin_right = _r5.padding
	_a37.content_margin_top = _r5.padding
	_a37.content_margin_bottom = _r5.padding
	_a37.border_width_bottom = 1
	_a37.border_width_top = 1
	_a37.border_width_left = 1
	_a37.border_width_right = 1

	_e91 = StyleBoxFlat.new()
	_e91.corner_radius_top_left = 8
	_e91.corner_radius_top_right = 8
	_e91.corner_radius_bottom_left = 8
	_e91.corner_radius_bottom_right = 8
	_e91.content_margin_left = _r5.padding
	_e91.content_margin_right = _r5.padding
	_e91.content_margin_top = _r5.padding
	_e91.content_margin_bottom = _r5.padding
	_e91.border_width_bottom = 1
	_e91.border_width_top = 1
	_e91.border_width_left = 1
	_e91.border_width_right = 1

	_a84 = StyleBoxFlat.new()
	_a84.corner_radius_top_left = 4
	_a84.corner_radius_top_right = 4
	_a84.corner_radius_bottom_left = 4
	_a84.corner_radius_bottom_right = 4
	_a84.border_width_bottom = 1
	_a84.border_width_top = 1
	_a84.border_width_left = 1
	_a84.border_width_right = 1
	_a84.border_width_left = 1
	_a84.border_width_right = 1

	_f30 = StyleBoxFlat.new()
	_f30.corner_radius_top_left = 6
	_f30.corner_radius_top_right = 6
	_f30.content_margin_left = 12
	_f30.content_margin_right = 12
	_f30.content_margin_top = 4
	_f30.content_margin_bottom = 4
	
	_i65 = StyleBoxFlat.new()
	_i65.bg_color = Color(0.1, 0.1, 0.1) 
	_i65.border_width_left = 1
	_i65.border_width_top = 1
	_i65.border_width_right = 1
	_i65.border_width_bottom = 1
	_i65.corner_radius_top_left = 4
	_i65.corner_radius_top_right = 4
	_i65.corner_radius_bottom_right = 4
	_i65.corner_radius_bottom_left = 4

const _z3 = {
	"gdscript": "GDScript",
	"csharp": "C#",
	"cs": "C#",
	"": "GDScript"  
}

const _a6 = {
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

const _t38 = {
	"1080p": {"width": 1920, "height": 1080, "scale": 1.0},  
	"1440p": {"width": 2560, "height": 1440, "scale": 1.15}, 
	"4k": {"width": 3840, "height": 2160, "scale": 1.5},     
	"user": {"width": 1800, "height": 1169, "scale": 1.1}    
}

const _v45 = {
	0: "auto",    
	1: 0.8,       
	2: 1.0,       
	3: 1.25,      
	4: 1.5        
}

const _o65 = 16  

var _i89: EditorPlugin
var _t15: EditorInterface
var _c37: ScriptEditor
var _w88: VBoxContainer
var _l33: EditorPlugin  

var _g78: _b70
var _o10: _b54
var _z24: _j50

@onready var _e8: ScrollContainer = %_f28
@onready var _z72: TextEdit = %_e36
@onready var _s28: Button = %_t14
@onready var _p70: LineEdit = %_d16
@onready var _a25: Button = %_e40
@onready var _d12: Label = %_w7
@onready var _o50: CheckButton = %_e38
@onready var _m89: Label = %_n44
@onready var _a10: HBoxContainer = %_c89
@onready var _o57: Label = %_r44
@onready var _q91: Label = %_z10
@onready var _e68: Label = %_r24
@onready var _x57: Button = %_h28
@onready var _o1: Label = %_q42
@onready var _b77: OptionButton = %_a22
@onready var _m94: OptionButton = %_f42
@onready var _p14: OptionButton = %_v16

@onready var _p50: VBoxContainer = $MarginContainer/TabContainer/Settings/_q8/VBoxContainer
@onready var _n32: TabContainer = $MarginContainer/TabContainer

@onready var _f4: ProgressBar = %_z63
@onready var _m50: Label = %_c19
@onready var _t46: Label = %_q1
@onready var _f82: Label = %_c75
@onready var _z47: OptionButton = %_q82
@onready var _l2: Panel = %_g71

@onready var _n100: Label = %_k74
@onready var _i5: TabContainer = %_f18
@onready var _c70: ItemList = %_c99
@onready var _w32: Label = %_i15
@onready var _d87: RichTextLabel = %_p97
@onready var _a93: RichTextLabel = %_e70
@onready var _u84: Button = %_y27
@onready var _n64: Button = %_z37
@onready var _p19: Button = %_z11
@onready var _q66: Button = %_d28
@onready var _r26: ItemList = %_w76
@onready var _v74: Label = %_t86
@onready var _w52: RichTextLabel = %_h1
@onready var _g36: RichTextLabel = %_q61
@onready var _a83: Button = %_a3
@onready var _d74: Button = %_q4
@onready var _b47: Button = %_y70
@onready var _q62: Button = %_x59
@onready var _y87: Button = %_b44
@onready var _y76: Button = %_q63
@onready var _i56: Button = %_d85
@onready var _p35: Button = %_b45
@onready var _y45: AcceptDialog = %_a89
@onready var _r69: LineEdit = %_c88
@onready var _s44: FileDialog = %_r34
@onready var _o54: FileDialog = %_y37

@onready var _b65: OptionButton = %_q25
@onready var _t49: Label = %_c54

var _j86: CheckBox
var _e56: OptionButton
var _m62: SpinBox

var _f93: CheckBox

var _q35: CheckBox

var _y58: Button

var _a8: _w70
var _q41: Array = []
var _b85: bool = false
var _n52: float = 0.0
var _w65: int = 0

var _t90: Dictionary = {}  
var _l53: int = 0
var _w21: int = 30000  
var _c65: Dictionary = {}
var _s2: Array[String] = []
var _a29: int = 0

var _r40: _f28
var _a18: int = -1
var _l55: int = -1
var _w6: String = ""
var _e96: bool = false
var _h51: String = ""  
var _a99: String = ""  

var _j67: bool = false
var _u37: Vector2 = Vector2.ZERO
var _w53: float = 0.0

var _d2: HBoxContainer
var _p34: OptionButton
var _s99: Label
var _v86: OptionButton  

const _p17 = [
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

var _b20: TextEdit
var _x77: Label
var _n26: Label

const _i16 = 3
var _o88: int = 0

var _p33: float = 1.0
var _s31: String = "auto"  

var _z96: int = 128000  
const _h95 = 0.85  
const _n89 = 1.0  

const _m96 = [
	"@file",
	"@selection",
	"@openscript",
	"@scene",
	"@node"
]

const _v100: int = 0
const _r45: int = 1
const _l42 = {
	_v100: "Chat",
	_r45: "Agent"
}

var _n65: _r100
var _h42: _i95
var _k36: ProgressBar
var _y65: Label
var _l74: Button
var _x32: bool = false
var _c8: VBoxContainer
var _r20: HBoxContainer
var _j45: Array = []  
var _r17: bool = false  
var _c72: HBoxContainer  
var _y30: HBoxContainer  

var _y25 = 0
var _p65 = []
var _x78 = {}
var _w27: Timer
var _u71: int = 0

var _b32: PanelContainer
var _p95: bool = false  
func _s84() -> void:
	_t90 = {}

func set_gdsense_manager(_b4: _w70) -> void:
	_a8 = _b4

	if _a8:
		if not _a8._w60.is_connected(_h15):
			_a8._w60.connect(_h15)
		if not _a8._n43.is_connected(_i30):
			_a8._n43.connect(_i30)
		if not _a8._g27.is_connected(_f32):
			_a8._g27.connect(_f32)

func set_plugin(_u63: EditorPlugin) -> void:
	_l33 = _u63

func _notification(_f44):
	if _f44 == NOTIFICATION_THEME_CHANGED:
		_q13()

func _ready() -> void:
	_v27()

	_p48.call_deferred()
	_i89 = EditorPlugin.new()
	_t15 = _i89.get_editor_interface()
	_c37 = _t15.get_script_editor()
	
	var _k71 = %_y21
	if _k71:
		_k71.add_theme_stylebox_override("panel", _i65)
	
	_c91()
	_a58()
	
	_g78 = _b70.new(_t15, _c37)
	_o10 = _b54.new(_g78, _t15)

	_z24 = _j50.new()
	_z24.initialize(_z72, self, _t15)
	_z24._v71.connect(_l91)

	_w88 = %_y55
	
	_e8.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_w88.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	_a25.pressed.connect(_e13)
	_s28.pressed.connect(_p51)
	_o50.toggled.connect(_h14)
	_x57.pressed.connect(_p88)
	_b77.item_selected.connect(_n12)
	_m94.item_selected.connect(_n12)
	_z72.gui_input.connect(_g52)
	_z72.text_changed.connect(_v63)

	_l2.mouse_entered.connect(_y71)
	_l2.mouse_exited.connect(_g73)
	_l2.gui_input.connect(_l38)
	
	_q10()
	
	_e44()

	_u93()

	_w27 = Timer.new()
	_w27.wait_time = 0.5  
	_w27.one_shot = true
	_w27.timeout.connect(_h65)
	add_child(_w27)
	
	if _a8:
		_a8._w22.connect(_k80)
		_a8._t4.connect(_h77)
		_a8._i53.connect(_a70)
		_a8._r78.connect(_c25)
		_a8._b48.connect(_h48)
		_a8._u23.connect(_o66)
		_a8._y98.connect(_t45)
		_a8._f5.connect(_v81)

	var _y48 = _a8._m83() if _a8 else ""
	_p70.text = _y48
	if _y48.is_empty():
		if _a8 and _a8._e2():
			var env = _a8._f35()
			_d12.text = "No API Key (%s)" % env.capitalize()
		else:
			_d12.text = "API Key Not Set"
	else:
		if _a8 and _a8._e2():
			var env = _a8._f35()
			_d12.text = "API Key Loaded (%s)" % env.capitalize()
		else:
			_d12.text = "API Key Loaded"
	
	_m2()

	_s19()

	_c17()
	
	_l59()
	
	_z15()

	_d52()

	_x86()

	_t87.call_deferred()

	_m89.visible = false
	_a10.visible = false

	if not (_a8 and _a8._e2()):
		_o1.visible = false

	_h25()

	_o4()

func _p48():
	if not _a8:
		if _o88 >= _i16:
			return
		
		_o88 += 1

		if is_inside_tree():
			get_tree().create_timer(1.0).timeout.connect(_n23)
		else:
			_q98.call_deferred()

func _q98():
	if _o88 >= _i16:
		return
	_p48()

func _n23():
	if not _a8:
		if _o88 >= _i16:
			pass

		else:
			pass

	else:
		_o88 = 0

func _process(delta: float):
	if _b85:
		var elapsed_time = (Time.get_ticks_msec() / 1000.0) - _n52
		_m89.text = "Request time: %.1fs" % elapsed_time

func _g52(_n74: InputEvent):
	if _z24 and _z24._y20(_n74):
		get_viewport().set_input_as_handled()
		return

	if _n74 is InputEventKey and _n74.pressed:
		if _n74.keycode == KEY_ENTER:
			if _n74.shift_pressed:
				_z72.text += "\n"
				_z72.set_caret_line(_z72.get_line_count() - 1)
				_z72.set_caret_column(0)
				get_viewport().set_input_as_handled()
			else:
				var text = _z72.text.strip_edges()
				if text.is_empty():
					return

				_z72.text = ""
				_v63() 

				if _p14 and _p14.selected == _r45:
					_d47(text)
				else:
					_b94(text)
				get_viewport().set_input_as_handled()

func _e13():
	if _a8:
		_a8._t66(_p70.text)

func _p51():
	var _a88: String = _z72.text
	if not _a88.is_empty():
		if _p14 and _p14.selected == _r45:
			_d47(_a88)
		else:
			_b94(_a88)

func _d47(_r74: String) -> void:
	if not _n65:
		_k78("Agent mode not available", true)
		return

	var _f87 = _j85(_r74)
	if _f87.is_empty():
		return

	_z72.text = ""
	_h55(_r74)

	_g39()

	_z72.editable = false
	_s28.disabled = true

	var _e76 = {
		"godot_version": Engine.get_version_info().get("string", "4.x"),
		"project_name": ProjectSettings.get_setting("application/config/name", "")
	}

	var _o27 = ""
	if _v86:
		_o27 = _w8()

	_n65._b100(_f87, _e76, _o27)

func _b94(_a88: String):
	_h51 = _a88

	_j92()

	_q41.append({"role": "user", "content": _a88, "original_content": _a88})
	_s84()
	
	var _h63 = _a88
	
	if _a88.begins_with("@explain"):
		var _j11 = _a88.find("\n")
		if _j11 != -1:
			_h63 = _a88.substr(0, _j11) + " (code attached)"
	
	_h55(_h63)
	
	_z72.text = ""
	_z72.editable = false
	_s28.disabled = true
	
	_b85 = true
	_n52 = Time.get_ticks_msec() / 1000.0
	_m89.visible = true
	_a10.visible = false
	_m89.text = "Request time: 0.0s"
	_k35.call_deferred()

	var _b14 = _p23(_a88, true)
	var processed_prompt = _b14["processed_prompt"]
	var context_metadata = _b14["context_metadata"]
	
	if processed_prompt == "":
		_m47()

		if _q41.size() > 0:
			_q41.pop_back()
			_s84()
		return
	
	if processed_prompt.strip_edges().begins_with("@explain"):
		var _j18 = _l27(processed_prompt)
		if _j18.has("function_context") and not _j18["function_context"].is_empty():
			if _a8:
				_a8._u25(_q41, "@explain", _j18["function_context"], context_metadata if context_metadata else {})
		else:
			_q41[_q41.size() - 1]["content"] = processed_prompt
			if _a8:
				_a8._u25(_q41, "", "", context_metadata if context_metadata else {})
	else:
		_q41[_q41.size() - 1]["content"] = processed_prompt

		if _a8:
			_a8._u25(_q41, "", "", context_metadata if context_metadata else {})

func _k80(_r73: String, _i76: Array, _y8: String = "", _f1: String = ""):
	if not _f1.is_empty() and _q41.size() > 0:
		for i in range(_q41.size() - 1, -1, -1):
			if _q41[i].get("role", "") == "user":
				_q41[i]["content"] = _f1
				break

	var _o44 = {"role": "agent", "content": _r73}
	if not _y8.is_empty():
		_o44["thought_signature"] = _y8
	_q41.append(_o44)

	_a99 = _y8
	_s84()
	_n28(_r73, _i76)

	if _r40 and not _h51.is_empty():
		var session_id = _a8._w96() if _a8 else ""

		var _j26 = _r40._i50()
		var _o3 = (not _j26 or _j26.session_id != session_id)

		if _o3 and _q41.size() > 2:
			for i in range(0, _q41.size() - 2, 2):  
				if i + 1 < _q41.size():
					var _u49 = _q41[i]
					var _o91 = _q41[i + 1]

					if _u49.get("role", "") == "user" and _o91.get("role", "") == "agent":
						var _b16 = _o91.get("thought_signature", "")

						var _e86 = _u49.get("original_content", _u49.get("content", ""))
						var _k42 = _u49.get("content", "")

						_r40._r94(_e86, _o91.get("content", ""), session_id, _b16, _k42, "")

		var _n56 = _h51
		var _f34 = _f1 if not _f1.is_empty() else _h51

		var _n36 = _a8._s21() if _a8 else ""

		_r40._r94(_n56, _r73, session_id, _y8, _f34, _n36)

		_r40._p31()
		_h51 = ""  

		_t51()

	_m47()
	_k35.call_deferred()
	_j92.call_deferred(true)

func _h77():
	_d12.text = "Invalid API Key"
	_t83("Your API key is invalid. Please check your settings.")
	_m47()
	_k35.call_deferred()

func _a70(_s65: int, _o23: String):
	var _g25 = _y15(_o23)
	var _y100: String
	
	if _g25 != _o23:
		_y100 = _g25
	else:
		_y100 = "API Error %d: %s" % [_s65, _o23]
		
		if _s65 == 400:
			if "custom_rules" in _o23.to_lower():
				_y100 += "\n\nPlease check your custom rules in the Settings tab."
			elif "godot_version" in _o23.to_lower():
				_y100 += "\n\nGodot version detection failed. Try restarting the editor."
		elif _s65 == 422:
			_y100 += "\n\nPlease verify your custom rules and parameter settings."
	
	_t83(_y100)
	_m47()
	_k35.call_deferred()

func _c25():
	if _a8 and _a8._e2():
		var env = _a8._f35()
		_d12.text = "API Key Saved (%s)!" % env.capitalize()
	else:
		_d12.text = "API Key Saved!"

func _p88():
	_q41.clear()
	_s84()
	_c93()
	for _w15 in _w88.get_children():
		_w15.queue_free()
	_o4()
	_b89()
	_a10.visible = false
	_w65 = 0
	_o1.text = "Total Token Usage for this chat: 0"

	if _r40:
		_r40._v94()
		_r40._p31()
		_t51()

	if _a8:
		_a8._l94()
	_k35.call_deferred()

func _k35():
	await get_tree().process_frame
	_e8.get_v_scroll_bar().value = _e8.get_v_scroll_bar().max_value

func _h48(_j51: int, _e34: int, _u3: int):
	_w65 += _u3

	if _a8 and _a8._e2():
		_o57.text = "P: %d" % _j51
		_q91.text = "C: %d" % _e34
		_e68.text = "T: %d" % _u3
		_o1.text = "Total Token Usage for this chat: %d" % _w65
		_a10.visible = true
	else:
		_a10.visible = false
		_o1.visible = false

	_k35.call_deferred()

func _o66(success: bool):
	if success:
		pass

	else:
		pass

func _h14(_e27: bool):
	_p70.secret = not _e27

func _y71():
	Input.set_default_cursor_shape(Input.CURSOR_VSIZE)

func _g73():
	if not _j67:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _l38(_n74: InputEvent):
	if _n74 is InputEventMouseButton:
		if _n74.button_index == MOUSE_BUTTON_LEFT:
			if _n74.pressed:
				_j67 = true
				_u37 = _l2.get_global_mouse_position()
				_w53 = _z72.custom_minimum_size.y
			else:
				_j67 = false
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)

	elif _n74 is InputEventMouseMotion and _j67:
		var _h62 = _l2.get_global_mouse_position()
		var _g59 = _h62.y - _u37.y
		var _v25 = clamp(_w53 + _g59, 40.0, 600.0)
		_z72.custom_minimum_size.y = _v25

func _a80(text: String) -> String:
	var _m12: PackedStringArray = text.split("\n")
	for i in range(_m12.size()):
		var line: String = _m12[i]
		var _k47: int = 0
		for char in line:
			if char == ' ':
				_k47 += 1
			else:
				break
		
		var _l44: int = _k47 / 4
		if _l44 > 0:
			_m12[i] = "\t".repeat(_l44) + line.lstrip(" ")
			
	return "\n".join(_m12)

func _m47():
	_z72.editable = true
	_s28.disabled = false
	_b85 = false
	_m89.visible = false

func _e79(text: String) -> PackedStringArray:
	var _p69 = RegEx.new()
	_p69.compile("[A-Z][a-zA-Z0-9]+")
	var _x71 = _p69.search_all(text)
	var _p55: PackedStringArray = []
	for _k3 in _x71:
		_p55.append(_k3.get_string())
	return _p55

func _b13(_n60: String) -> String:
	if not ClassDB.class_exists(_n60):
		return ""
		
	var _w72 := ""
	var _f48 = ClassDB.class_get_method_list(_n60)
	if _f48.size() > 0:
		_w72 = "Class: " + _n60 + "\n"

	return _w72

func _i75(user_prompt: String) -> String:
	if user_prompt.strip_edges().begins_with("@explain"):
		return _j36(user_prompt)
	
	if not _n55(user_prompt):
		return user_prompt
	
	var _p55 = _e79(user_prompt)
	if _p55.is_empty():
		return user_prompt
	
	var _f36 = "Godot Editor Context:\n"
	for _f45 in _p55:
		var _w72 = _b13(_f45)
		if not _w72.is_empty():
			_f36 += _w72 + "\n"
	
	if _f36 == "Godot Editor Context:\n":
		return user_prompt
	
	var _t100 = _f36 + "\nUser Question: " + user_prompt
	return _t100

func _l27(user_prompt: String) -> Dictionary:
	var _k3 = {}
	
	var _f96 = RegEx.new()
	_f96.compile("@explain\\s+([a-zA-Z_][a-zA-Z0-9_]*)")
	var _l66 = _f96.search(user_prompt)
	
	var function_name = ""
	if _l66:
		function_name = _l66.get_string(1)
		_k3["function_name"] = function_name
	
	var _x60 = RegEx.new()
	_x60.compile("```(?:gdscript)?\n([^`]+?)```")
	var _a7 = _x60.search(user_prompt)
	
	if _a7:
		var _g33 = _a7.get_string(1).strip_edges()
		_k3["function_context"] = _g33
	
	return _k3

func _j36(user_prompt: String) -> String:
	var _f96 = RegEx.new()
	_f96.compile("@explain\\s+([a-zA-Z_][a-zA-Z0-9_]*)")
	var _k3 = _f96.search(user_prompt)
	
	var function_name = ""
	if _k3:
		function_name = _k3.get_string(1)
	
	var _v35 = "Please explain this GDScript function"
	if not function_name.is_empty():
		_v35 += " called '%s'" % function_name
	
	_v35 += ". Focus on:\n"
	_v35 += "- What the function does (purpose and behavior)\n"
	_v35 += "- How to use it (parameters and return value)\n"
	_v35 += "- Any important implementation details\n"
	_v35 += "- Potential improvements or best practices\n\n"
	
	_v35 += user_prompt.replace("@explain %s" % function_name, "").strip_edges()
	
	return _v35

func _j85(user_prompt: String) -> String:
	if _g78 == null:
		return user_prompt

	var _d58 = _g78._j31(user_prompt)
	var commands = _d58.get("commands", [])
	var cleaned_prompt = _d58.get("cleaned_prompt", user_prompt)

	for _r33 in commands:
		if _r33.get("type", "") == "error":
			var _p59 = _r33.get("error", "Unknown error")
			if "path traversal" in _p59.to_lower() or "not allowed" in _p59.to_lower() or "blocked" in _p59.to_lower():
				_t83("⚠️ Security: " + _p59)
				return ""
			else:
				_t83("⚠️ " + _p59)
				return ""

	if commands.is_empty():
		return user_prompt

	var _l69: Array[String] = []
	for _r33 in commands:
		var _m93 = _r33.get("type", "")
		match _m93:
			"file":
				var path = _r33.get("path", "")
				if not path.is_empty():
					_l69.append("File: " + path)
			"selection":
				var _d36 = _r33.get("script_path", "")
				var _y77 = _r33.get("line_start", 0)
				var _e61 = _r33.get("line_end", 0)

				if (_d36.is_empty() or not _d36.begins_with("res://")) and _g78:
					var _c90 = _g78._z46()
					if _c90.get("success", false):
						_d36 = _c90.get("path", "")
						_y77 = _c90.get("start_line", 0)
						_e61 = _c90.get("end_line", 0)
				if not _d36.is_empty() and _d36.begins_with("res://"):
					_l69.append("Selection in %s (lines %d-%d)" % [_d36, _y77, _e61])
			"openscript":
				var path = _r33.get("path", "")

				if path.is_empty() or not path.begins_with("res://"):
					if _g78:
						var _f75 = _g78.get_current_script()
						if _f75.get("success", false):
							path = _f75.get("path", "")
				if not path.is_empty() and path.begins_with("res://"):
					_l69.append("Open script: " + path)
			"scene":
				var path = _r33.get("path", "")
				if not path.is_empty():
					_l69.append("Scene: " + path)
			"node":
				var node_path = _r33.get("node_path", "")
				if not node_path.is_empty():
					_l69.append("Node: " + node_path)

	if _l69.is_empty():
		return cleaned_prompt

	var _s51 = "\n\n[Referenced files - use read_file to access]:\n- " + "\n- ".join(_l69)
	return cleaned_prompt + _s51

func _p23(user_prompt: String, _i40: bool = false) -> Dictionary:
	if _g78 == null or _o10 == null:
		return {"processed_prompt": user_prompt, "context_metadata": null}
	
	var _d58 = _g78._j31(user_prompt)
	var commands = _d58.get("commands", [])
	var cleaned_prompt = _d58.get("cleaned_prompt", user_prompt)
	
	if _i40:
		_v80(commands)

		for _r33 in commands:
			if _r33.get("type", "") == "openscript":
				var snapshot_id = _r33.get("snapshot_id", "")
				if snapshot_id != "" and _c65.has(snapshot_id):
					_c65[snapshot_id]["sent_in_conversation"] = true

	var _e22 = _h3(commands)
	var _i64 = _n35(_e22)
	if not _i64.is_empty():
		var _u67 = []
		_u67.append_array(_i64)
		_u67.append_array(commands)
		commands = _u67
	
	var _i14 = []
	for _r33 in commands:
		if _r33.get("type", "") == "error":
			var _p59 = _r33.get("error", "Unknown error")

			if _p59.begins_with("Security:"):
				_i14.append("⚠️ " + _p59)
			elif "path traversal" in _p59.to_lower() or "not allowed" in _p59.to_lower() or "blocked" in _p59.to_lower():
				_i14.append("⚠️ Security: " + _p59)
			else:
				_i14.append("⚠️ " + _p59)
	
	if not _i14.is_empty():
		var _e94 = "\n".join(_i14)
		_t83(_e94)

		return {"processed_prompt": "", "context_metadata": null}
	
	if commands.is_empty():
		return {"processed_prompt": user_prompt, "context_metadata": null}
	
	var _e17 = _o10._s56(cleaned_prompt, commands)
	
	var _x73 = _o10._c78(_e17)
	if not _x73.get("valid", false):
		var _d93 = _x73.get("message", "Unknown validation error")
		_t83("Context too large: " + _d93)

		return {"processed_prompt": "", "context_metadata": null}
	
	var context_metadata = _f85(commands, _x73.get("estimated_tokens", 0))

	if OS.is_debug_build() and context_metadata:
		pass

	return {"processed_prompt": _e17, "context_metadata": context_metadata}

func _v80(commands: Array) -> void:
	if commands.is_empty():
		return
	
	var _o71 = false
	
	for _r33 in commands:
		if _r33.get("type", "") != "openscript":
			continue
		
		var snapshot_id = _r33.get("snapshot_id", "")
		if snapshot_id == "":
			snapshot_id = _a49()
			_r33["snapshot_id"] = snapshot_id
		
		var _d36 = _r33.get("path", "")
		var _l72 = _r33.get("content", "")
		
		if _l72 == "" and _g78:
			var _f75 = _g78.get_current_script()
			if _f75.get("success", false):
				_l72 = _f75.get("content", "")
				_r33["content"] = _l72
				if _d36 == "":
					_d36 = _f75.get("path", "")
					_r33["path"] = _d36
		
		if _l72 == "":
			continue
		
		if _d36 == "":
			_d36 = "current_script.gd"
			_r33["path"] = _d36
		
		_c65[snapshot_id] = {
			"path": _d36,
			"content": _l72,
			"size_bytes": _l72.length(),
			"created_at": _r33.get("created_at", Time.get_unix_time_from_system()),
			"sent_in_conversation": false  
		}
		
		if not _s2.has(snapshot_id):
			_s2.append(snapshot_id)
		
		_o71 = true
	
	if _o71:
		_y68()

func _h3(commands: Array) -> PackedStringArray:
	var _u59 = PackedStringArray()
	for _r33 in commands:
		if _r33.get("type", "") != "openscript":
			continue
		var snapshot_id = _r33.get("snapshot_id", "")
		if snapshot_id != "":
			_u59.append(snapshot_id)
	return _u59

func _n35(_z43: PackedStringArray = PackedStringArray()) -> Array:
	var commands: Array = []
	for snapshot_id in _s2:
		if _z43.has(snapshot_id):
			continue
		if not _c65.has(snapshot_id):
			continue

		var _j91 = _c65[snapshot_id]

		if _j91.get("sent_in_conversation", false):
			continue

		var _r33 = {
			"type": "openscript",
			"snapshot_id": snapshot_id,
			"path": _j91.get("path", ""),
			"content": _j91.get("content", "")
		}
		commands.append(_r33)
	return commands

func _r43(_r33: Dictionary) -> Dictionary:
	var _d36 = _r33.get("path", "")
	var _l72 = _r33.get("content", "")
	var snapshot_id = _r33.get("snapshot_id", "")
	
	if snapshot_id != "" and _c65.has(snapshot_id):
		var _h18 = _c65[snapshot_id]
		if _d36 == "":
			_d36 = _h18.get("path", "")
		if _l72 == "":
			_l72 = _h18.get("content", "")
	
	return {
		"path": _d36,
		"content": _l72,
		"snapshot_id": snapshot_id
	}

func _a49() -> String:
	_a29 += 1
	return "panel_openscript_%d_%d" % [Time.get_ticks_msec(), _a29]

func _c93() -> void:
	_c65.clear()
	_s2.clear()
	_a29 = 0
	_y68()

func _y68() -> void:
	if _r40:
		_r40._s63(_c65, _s2)

func _f85(commands: Array, _v17: int) -> Dictionary:
	var _h91 = []
	var _y41 = 0
	
	for _r33 in commands:
		var _r60 = {}
		var _m93 = _r33.get("type", "unknown")
		_r60["type"] = _m93

		match _m93:
			"file":
				_r60["path"] = _r33.get("path", "")
				if _r33.get("start_line", -1) > 0:
					_r60["start_line"] = _r33.get("start_line", 0)
				if _r33.get("end_line", -1) > 0:
					_r60["end_line"] = _r33.get("end_line", 0)
				if _r33.get("symbol", "") != "":
					_r60["symbol"] = _r33.get("symbol", "")
				
				if _g78:
					var _d29 = _g78._l8(_r33)
					if _d29.get("success", false):
						var _q27 = _d29.get("content", "").length()
						_r60["size_bytes"] = _q27
						_y41 += _q27
			
			"scene":
				_r60["path"] = _r33.get("path", "")
				if _r33.get("node_path", "") != "":
					_r60["node_path"] = _r33.get("node_path", "")
				if _r33.get("include_scripts", false):
					_r60["include_scripts"] = true
				
				var _z64 = 500  
				if _r33.get("include_scripts", false):
					_z64 += 2000  
				_r60["size_bytes"] = _z64
				_y41 += _z64
			
			"node":
				_r60["node_path"] = _r33.get("node_path", "")

				var _z64 = 200  
				_r60["size_bytes"] = _z64
				_y41 += _z64
			
			"selection":
				if _g78:
					var _c90 = _g78._z46()
					if _c90.get("success", false):
						var _q27 = _c90.get("content", "").length()
						_r60["size_bytes"] = _q27
						_y41 += _q27
						var _g28 = _c90.get("path", "")
						if _g28 != "":
							_r60["path"] = _g28
						var _b18 = _c90.get("start_line", 0)
						if _b18 > 0:
							_r60["start_line"] = _b18
						var _x80 = _c90.get("end_line", 0)
						if _x80 > 0:
							_r60["end_line"] = _x80
			
			"openscript":
				var _f80 = _r43(_r33)
				var _l72 = _f80.get("content", "")
				var _d36 = _f80.get("path", "")
				var snapshot_id = _f80.get("snapshot_id", "")
				
				if _l72 != "":
					var _q27 = _l72.length()
					_r60["size_bytes"] = _q27
					_y41 += _q27
				
				if _d36 != "":
					_r60["path"] = _d36
				
				if snapshot_id != "":
					_r60["snapshot_id"] = snapshot_id
		
		_h91.append(_r60)
	
	var _j3 = {
		"commands": _h91,
		"total_context_size": _y41,
		"command_count": commands.size(),
		"estimated_tokens": _v17
	}
	
	if _a8 and not _a8._w96().is_empty():
		_j3["session_id"] = _a8._w96()
	
	return _j3

func _n55(user_prompt: String) -> bool:
	var _o79 = [
		"CharacterBody2D", "RigidBody2D", "StaticBody2D", "Area2D",
		"Node2D", "Node3D", "Control", "Panel", "Button", "Label",
		"AnimationPlayer", "AnimationTree", "TileMap", "PackedScene",
		"Resource", "RefCounted", "Object", "Variant",
		"Vector2", "Vector3", "Transform2D", "Transform3D",
		"InputEvent", "Camera2D", "Camera3D", "CollisionShape2D"
	]
	
	var _l18 = user_prompt.to_lower()
	for _c84 in _o79:
		if _l18.find(_c84.to_lower()) != -1:
			return true
	
	return false

func _r67(code: String) -> String:
	var _b83 = ""
	var _m12 = code.split("\n")
	
	var _n3 = RegEx.new()
	_n3.compile("\\b(" + "|".join(_y51) + ")\\b")
	
	var _h73 = RegEx.new()

	_h73.compile("(?<!#)\\b(Vector2|Input|Node2D|Control|CharacterBody2D|[A-Z][a-zA-Z0-9]*)\\b")
	
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

func _h55(text: String):
	var _j5 = PanelContainer.new()
	_j5.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_j5.add_theme_constant_override("margin_bottom", _r5.message_gap)
	
	if not _a37:
		_c91()
	_j5.add_theme_stylebox_override("panel", _a37)
	
	var _m49 = VBoxContainer.new()
	_m49.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_m49.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var _p71 = Label.new()
	_p71.text = "You:"
	_p71.add_theme_color_override("font_color", _c85)
	var _c94 = get_theme_font_size("font_size", "Label")
	_p71.add_theme_font_size_override("font_size", int(_c94 * 1.15))
	_m49.add_child(_p71)
	
	var _g31 = Control.new()
	_g31.custom_minimum_size.y = 6
	_m49.add_child(_g31)
	
	var _q79 = ColorRect.new()
	_q79.custom_minimum_size.y = 1
	_q79.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_q79.color = _c85
	_q79.color.a = 0.5
	_m49.add_child(_q79)
	
	var _r22 = Control.new()
	_r22.custom_minimum_size.y = 6
	_m49.add_child(_r22)
	
	var _y99 = RichTextLabel.new()
	_y99.bbcode_enabled = true
	_y99.selection_enabled = true
	_y99.text = _u1(text)
	_y99.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_y99.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_y99.fit_content = true
	_y99.scroll_active = false
	_y99.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_y99.add_theme_color_override("default_color", _c85)
	_m49.add_child(_y99)
	
	_j5.add_child(_m49)
	_w88.add_child(_j5)

func _n28(text: String, _i76: Array = []):
	var _j5 = PanelContainer.new()
	_j5.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_j5.add_theme_constant_override("margin_bottom", _r5.message_gap)
	
	if not _e91:
		_c91()
	_j5.add_theme_stylebox_override("panel", _e91)
	
	var _m49 = VBoxContainer.new()
	_m49.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_m49.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	_m49.add_theme_constant_override("separation", 4)
	
	var _p71 = Label.new()
	_p71.text = "GDSense:"
	_p71.add_theme_color_override("font_color", _k9)
	var _c94 = get_theme_font_size("font_size", "Label")
	_p71.add_theme_font_size_override("font_size", int(_c94 * 1.15))
	_m49.add_child(_p71)
	
	var _g31 = Control.new()
	_g31.custom_minimum_size.y = 6
	_m49.add_child(_g31)
	
	var _q79 = ColorRect.new()
	_q79.custom_minimum_size.y = 1
	_q79.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_q79.color = _k9
	_q79.color.a = 0.5
	_m49.add_child(_q79)
	
	var _r22 = Control.new()
	_r22.custom_minimum_size.y = 6
	_m49.add_child(_r22)
	
	_e81(text, _m49)
	
	if _i76.size() > 0:
		_d88(_i76, _m49)
	
	if _a8:
		var _i23 = _a8._b6()

		if not _i23.is_empty():
			_e66(_m49)
		else:
			pass

	_j5.add_child(_m49)
	_w88.add_child(_j5)

func _e81(text: String, parent: Node):
	var _x60 = RegEx.new()
	_x60.compile("```([a-zA-Z]*)\n([^`]+?)```")
	
	var _c27 = 0
	var _c95 = _x60.search_all(text)
	
	for match in _c95:
		var _y64 = text.substr(_c27, match.get_start() - _c27)
		if not _y64.strip_edges().is_empty():
			_q7(_y64.strip_edges(), parent)
		
		var language = match.get_string(1).to_lower()
		if language.is_empty():
			language = "gdscript"  
		var code = match.get_string(2)
		_h2(code, language, parent)
		
		_c27 = match.get_end()
	
	if _c27 < text.length():
		var _n77 = text.substr(_c27)
		if not _n77.strip_edges().is_empty():
			_q7(_n77.strip_edges(), parent)

func _q7(text: String, parent: Node):
	var _h87 = text.strip_edges()
	
	_h87 = _h87.replace("**", "")
	
	var _i81 = RegEx.new()
	_i81.compile("`([^`]+)`")
	var _y23 = _i81.search_all(_h87)
	if _y23:
		for i in range(_y23.size() - 1, -1, -1):
			var _o25 = _y23[i]
			var full_match = _o25.get_string(0)
			var content = _o25.get_string(1)
			var _o70 = _u1(content)
			var _w63 = "[i]" + _o70 + "[/i]"
			_h87 = _h87.substr(0, _o25.get_start()) + _w63 + _h87.substr(_o25.get_end())

	var _e71 = RegEx.new()
	_e71.compile("'([A-Za-z0-9_\\-\\.]+)'")
	var _d1 = _e71.search_all(_h87)
	if _d1:
		for i in range(_d1.size() - 1, -1, -1):
			var _o25 = _d1[i]
			var full_match = _o25.get_string(0)
			var content = _o25.get_string(1)
			var _o70 = _u1(content)
			var _w63 = "[i]" + _o70 + "[/i]"
			_h87 = _h87.substr(0, _o25.get_start()) + _w63 + _h87.substr(_o25.get_end())
	
	var _k31 = "___SAFE_ITALIC_START___"
	var _x82 = "___SAFE_ITALIC_END___"
	_h87 = _h87.replace("[i]", _k31)
	_h87 = _h87.replace("[/i]", _x82)

	if _h87.begins_with("Explanation:") or _h87.begins_with("To use this:") or _h87.begins_with("To make this work:"):
		var _b75 = _h87.split(":", true, 1)
		if _b75.size() > 1:
			_h87 = "[b]" + _u1(_b75[0]) + ":[/b]" + _u1(_b75[1])

	var _m12 = _h87.split("\n")
	var _u29 = []

	var _s5 = RegEx.new()
	_s5.compile("^(#{1,4})\\s+(.+)$")

	var _u45 = RegEx.new()
	_u45.compile("^\\|\\s*[-:]+\\s*(\\|\\s*[-:]+\\s*)+\\|\\s*$")

	var _a92: Array = []  
	var _v18 = false

	var _q6 = func():
		if _u29.is_empty():
			return
		var _u24 = "\n".join(_u29)
		_u24 = _u24.replace(_k31, "[i]")
		_u24 = _u24.replace(_x82, "[/i]")
		if _u24.strip_edges().is_empty():
			_u29.clear()
			return
		var _d43 = RichTextLabel.new()
		_d43.bbcode_enabled = true
		_d43.selection_enabled = true
		_d43.text = _u24
		_d43.add_theme_constant_override("line_separation", 6)
		_d43.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_d43.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_d43.fit_content = true
		_d43.scroll_active = false
		_d43.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		_d43.add_theme_color_override("default_color", _k9)
		parent.add_child(_d43)
		_u29.clear()

	var _o78 = func():
		if _a92.is_empty():
			return

		_q6.call()

		var _b41 = 0
		for _u55 in _a92:
			if _u55.size() > _b41:
				_b41 = _u55.size()
		if _b41 == 0:
			_a92.clear()
			_v18 = false
			return

		var _g40 = MarginContainer.new()
		_g40.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_g40.add_theme_constant_override("margin_top", 8)
		_g40.add_theme_constant_override("margin_bottom", 12)

		var _i84 = PanelContainer.new()
		_i84.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var _w12 = StyleBoxFlat.new()
		_w12.bg_color = Color(0.15, 0.15, 0.18, 1.0)
		_w12.set_corner_radius_all(6)
		_w12.set_content_margin_all(12)
		_i84.add_theme_stylebox_override("panel", _w12)

		var _f97 = VBoxContainer.new()
		_f97.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_f97.add_theme_constant_override("separation", 0)

		var _a5 = GridContainer.new()
		_a5.columns = _b41
		_a5.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_a5.add_theme_constant_override("h_separation", 24)

		var _x90 = GridContainer.new()
		_x90.columns = _b41
		_x90.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_x90.add_theme_constant_override("h_separation", 24)
		_x90.add_theme_constant_override("v_separation", 10)

		var _a87 = int(14 * _p33)
		var _c86 = int(15 * _p33)
		for _m9 in range(_a92.size()):
			var _u55 = _a92[_m9]
			for _k86 in range(_b41):
				var _x63 = _u55[_k86] if _k86 < _u55.size() else ""

				_x63 = _x63.replace(_k31, "[i]")
				_x63 = _x63.replace(_x82, "[/i]")
				var _a47 = RichTextLabel.new()
				_a47.bbcode_enabled = true
				_a47.fit_content = true
				_a47.scroll_active = false
				_a47.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				_a47.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
				_a47.add_theme_color_override("default_color", _k9)
				if _m9 == 0 and _v18:
					_a47.add_theme_font_size_override("normal_font_size", _c86)
					_a47.text = "[b][u]" + _x63 + "[/u][/b]"
					_a5.add_child(_a47)
				else:
					_a47.add_theme_font_size_override("normal_font_size", _a87)
					_a47.text = _x63
					_x90.add_child(_a47)

		if _v18:
			_f97.add_child(_a5)

			var _q79 = HSeparator.new()
			_q79.add_theme_constant_override("separation", 8)
			_f97.add_child(_q79)
		_f97.add_child(_x90)
		_i84.add_child(_f97)
		_g40.add_child(_i84)
		parent.add_child(_g40)

		_a92.clear()
		_v18 = false

	for i in range(_m12.size()):
		var line = _m12[i]
		var _e54 = line.strip_edges()

		var _f79 = _u45.search(_e54) != null
		if _f79:
			if not _a92.is_empty():
				_v18 = true
			continue

		var _m56 = _s5.search(_e54)
		if _m56:
			_o78.call()
			var _j44 = _m56.get_string(1).length()
			var _h97 = _m56.get_string(2)

			var _c94 = 24  
			if _j44 == 2:
				_c94 = 20  
			elif _j44 == 3:
				_c94 = 18  
			elif _j44 == 4:
				_c94 = 16  

			var _a87 = int(_c94 * _p33)

			var _g69 = _u1(_h97)
			_u29.append("\n[b][font_size=" + str(_a87) + "]" + _g69 + "[/font_size][/b]\n")
		elif _e54.begins_with("|") and _e54.ends_with("|"):
			var _x29 = _e54.split("|")
			var _x83: Array = []

			for _s11 in _x29:
				var _j19 = _s11.strip_edges()

				if _j19.is_empty():
					continue

				if _j19.match("^-+$") or _j19.match("^:?-+:?$"):
					continue
				_x83.append(_u1(_j19))

			if not _x83.is_empty():
				_a92.append(_x83)
		elif _e54.begins_with("* "):
			_o78.call()

			var _z93 = _e54.substr(2).replace("*", "")
			_u29.append("• " + _u1(_z93))

			if i < _m12.size() - 1 and not _m12[i + 1].strip_edges().begins_with("* "):
				_u29.append("")
		elif _e54.match("^[0-9]+\\."):
			_o78.call()

			_u29.append(_u1(_e54))
		else:
			_o78.call()

			_u29.append(_u1(line.replace("*", "")))

	_o78.call()

	_q6.call()

func _h2(code: String, language: String, parent: Node):
	var _t95 = MarginContainer.new()
	_t95.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_t95.add_theme_constant_override("margin_left", 16)
	_t95.add_theme_constant_override("margin_right", 16)
	_t95.add_theme_constant_override("margin_top", 12)
	_t95.add_theme_constant_override("margin_bottom", 12)
	
	var _r79 = PanelContainer.new()
	_r79.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if not _a84:
		_c91()
	_r79.add_theme_stylebox_override("panel", _a84)
	
	var _k10 = VBoxContainer.new()
	_k10.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var _f92 = PanelContainer.new()
	_f92.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	_f92.add_theme_stylebox_override("panel", _f30)
	
	var _l89 = HBoxContainer.new()
	_l89.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_l89.layout_mode = 2  
	
	var _l77 = Label.new()
	_l77.layout_mode = 2
	_l77.text = _z3.get(language, "Code")

	_l77.add_theme_color_override("font_color", _s82)
	_l89.add_child(_l77)
	
	var _w73 = Control.new()
	_w73.layout_mode = 2
	_w73.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_l89.add_child(_w73)
	
	var _g43 = Button.new()
	_g43.layout_mode = 2
	_g43.text = "Copy"
	_g43.flat = true
	_g43.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_g43.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	_g43.pressed.connect(func(): _d57(code))
	_l89.add_child(_g43)
	
	_f92.add_child(_l89)
	_k10.add_child(_f92)
	
	var _s76 = MarginContainer.new()
	_s76.layout_mode = 2
	_s76.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_s76.add_theme_constant_override("margin_left", _r5.code_padding)
	_s76.add_theme_constant_override("margin_right", _r5.code_padding)
	_s76.add_theme_constant_override("margin_top", _r5.code_padding)
	_s76.add_theme_constant_override("margin_bottom", _r5.code_padding)
	
	var _w41 = RichTextLabel.new()
	_w41.bbcode_enabled = true
	_w41.selection_enabled = true
	_w41.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_w41.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_w41.fit_content = true
	_w41.scroll_active = false
	_w41.scroll_active = false
	
	var _j39 = _z45("text_color")
	_w41.add_theme_color_override("default_color", _j39)
	
	var _b83 = _c96(code, language)
	_w41.text = _b83
	
	var _i72 = SystemFont.new()
	_i72.font_names = ["Consolas", "Courier New", "Monospace"]
	_w41.add_theme_font_override("normal_font", _i72)
	_w41.add_theme_font_override("mono_font", _i72)
	
	_s76.add_child(_w41)
	_k10.add_child(_s76)
	
	_r79.add_child(_k10)
	_t95.add_child(_r79)
	parent.add_child(_t95)

func _c96(code: String, language: String) -> String:
	match language:
		"gdscript", "":
			return _r67(_a80(code))
		"csharp", "cs":
			return _z88(code)
		_:
			return code

func _d57(code: String):
	DisplayServer.clipboard_set(code)

func _z88(code: String) -> String:
	var _b83 = ""
	var _m12 = code.split("\n")
	
	var _n3 = RegEx.new()
	_n3.compile("\\b(" + "|".join(_d10) + ")\\b")
	
	var _h73 = RegEx.new()
	_h73.compile("\\b([A-Z][a-zA-Z0-9]*)\\b")
	
	var _v51 = RegEx.new()
	_v51.compile("\\b([a-z_][a-zA-Z0-9_]*)\\s*\\(")
	
	var _h75 = RegEx.new()
	_h75.compile("(\"[^\"]*\"|'[^']*')")
	
	var _d64 = RegEx.new()
	_d64.compile("\\b\\d+(\\.\\d+)?[fFdD]?\\b")
	
	var _j96 = RegEx.new()
	_j96.compile("(//.*$|/\\*.*?\\*/)")
	
	for line in _m12:
		if line.strip_edges().is_empty():
			_b83 += "\n"
			continue
		
		var _m45 = line
		
		_m45 = _j96.sub(_m45, "[color=#%s]$1[/color]" % [_z45("comment").to_html(false)], true)
		
		_m45 = _h75.sub(_m45, "[color=#%s]$1[/color]" % [_z45("string").to_html(false)], true)
		
		_m45 = _n3.sub(_m45, "[color=#%s]$1[/color]" % [_z45("keyword").to_html(false)], true)
		
		_m45 = _h73.sub(_m45, "[color=#%s]$1[/color]" % [_z45("class").to_html(false)], true)
		
		_m45 = _v51.sub(_m45, "[color=#%s]$1[/color](" % [_z45("function").to_html(false)], true)
		
		_m45 = _d64.sub(_m45, "[color=#%s]$0[/color]" % [_z45("number").to_html(false)], true)
		
		_b83 += _m45 + "\n"
	
	return _b83.strip_edges()

func _t83(text: String):
	var _j5 = PanelContainer.new()
	_j5.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_j5.add_theme_constant_override("margin_bottom", _r5.message_gap)

	var _p52 = Color("#ff6666")
	if _t15:
		var theme = _t15.get_editor_theme()
		if theme:
			_p52 = theme.get_color("error_color", "Editor")

	var _h76 = StyleBoxFlat.new()
	_h76.bg_color = _p52.darkened(0.8)
	_h76.border_color = _p52
	_h76.border_width_bottom = 1
	_h76.border_width_top = 1
	_h76.border_width_left = 1
	_h76.border_width_right = 1
	_h76.corner_radius_top_left = 8
	_h76.corner_radius_top_right = 8
	_h76.corner_radius_bottom_left = 8
	_h76.corner_radius_bottom_right = 8
	_h76.content_margin_left = _r5.padding
	_h76.content_margin_right = _r5.padding
	_h76.content_margin_top = _r5.padding
	_h76.content_margin_bottom = _r5.padding
	_j5.add_theme_stylebox_override("panel", _h76)

	var _m49 = VBoxContainer.new()
	_m49.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_m49.layout_mode = 2  

	var _r91 = _p52.lightened(0.3)  
	var _m44 = Color(1.0, 0.9, 0.9)  

	var _p75 = Label.new()
	_p75.text = "GDSense Error"
	_p75.add_theme_color_override("font_color", _r91)
	_p75.add_theme_font_size_override("font_size", 16)
	_m49.add_child(_p75)

	var _y99 = Label.new()
	_y99.text = text
	_y99.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_y99.add_theme_color_override("font_color", _m44)
	_m49.add_child(_y99)

	_j5.add_child(_m49)
	_w88.add_child(_j5)

func _o4():
	var _j5 = PanelContainer.new()
	_j5.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_j5.add_theme_constant_override("margin_bottom", _r5.message_gap)
	
	if not _e91:
		_c91()
	_j5.add_theme_stylebox_override("panel", _e91)
	
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.selection_enabled = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.fit_content = true
	label.scroll_active = false
	label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	label.add_theme_color_override("default_color", _y67("font_color"))
	label.text = "[b]Welcome to GDSense![/b] Your AI coding partner for Godot."
	
	_j5.add_child(label)
	_w88.add_child(_j5)

func _z30(text: String):
	if text.strip_edges().is_empty():
		return
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.selection_enabled = true
	label.text = _u1(text)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.fit_content = true
	label.scroll_active = false
	label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	label.add_theme_color_override("default_color", _k9)
	_w88.add_child(label)

func _s19() -> void:
	_v86 = OptionButton.new()
	_v86.name = "AgentModelSelector"
	_q90()
	_v86.visible = false  

	_v86.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if _m94:
		var _d46 = _m94.get_parent()
		if _d46:
			var _m98 = _d46.get_children().find(_m94)
			_d46.add_child(_v86)

			_d46.move_child(_v86, _m98)

func _m2():
	_b77.clear()
	_m94.clear()

	var _m76 = []
	if _a8:
		_m76 = _a8._n25()
	else:
		_m76 = [
			"openai/gpt-oss-20b",
			"gemini-2.5-flash-lite",
			"gpt-5-nano"
		]

	for _i12 in _m76:
		var _j4: String
		var _t50: String

		if _i12 is Dictionary and _i12.has("id"):
			_t50 = _i12.get("id", "")
			_j4 = _i12.get("display_name", _t50)
		else:
			_t50 = str(_i12)
			_j4 = _a6.get(_t50, _t50)

		_b77.add_item(_j4)
		_m94.add_item(_j4)

	if _a8:
		var _o59 = _a8._s21()
		if _r29(_o59, _m76):
			_b5(_o59)
		else:
			if _m76.size() > 0:
				var _s36 = _u52(_m76[0])
				_b5(_s36)
				_a8._k51(_s36)

	_x76()

func _u52(_i12) -> String:
	if _i12 is Dictionary and _i12.has("id"):
		return _i12.get("id", "")
	return str(_i12)

func _r29(_t50: String, _m76: Array) -> bool:
	for _i12 in _m76:
		var _q32 = _u52(_i12)
		if _q32 == _t50:
			return true
	return false

func _x76():
	pass

func _x13(index: int) -> String:
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

func _n12(index: int) -> void:
	var _m76 = []
	if _a8:
		_m76 = _a8._n25()

	if index < 0 or index >= _m76.size():
		return

	var _t50 = _u52(_m76[index])
	if _a8:
		_a8._k51(_t50)

	_b77.selected = index
	_m94.selected = index

	_j92(true)

func _b5(model: String) -> void:
	var _m76 = []
	if _a8:
		_m76 = _a8._n25()

	for i in range(_m76.size()):
		var _q32 = _u52(_m76[i])
		if _q32 == model:
			_b77.selected = i
			_m94.selected = i
			return

	_b77.selected = 0
	_m94.selected = 0

func _c17():
	if not _a8 or not _a8._e2():
		return
	
	_d2 = HBoxContainer.new()
	_d2.add_theme_constant_override("separation", 10)
	
	_s99 = Label.new()
	_s99.text = "Environment:"
	_d2.add_child(_s99)
	
	_p34 = OptionButton.new()
	_p34.add_item("Production")
	_p34.add_item("Development (localhost:8080)")
	
	var _j74 = _a8._f35() if _a8 else "production"
	if _j74 == "development":
		_p34.selected = 1
	else:
		_p34.selected = 0
	
	_p34.item_selected.connect(_l71)
	_d2.add_child(_p34)
	
	var _y3 = Label.new()
	_y3.text = "[DEV MODE]"
	_y3.modulate = Color(1, 0.5, 0.5)
	_d2.add_child(_y3)

	var _v95 = _p70.get_parent()
	var parent = _v95.get_parent()
	var index = parent.get_children().find(_v95)
	parent.add_child(_d2)
	parent.move_child(_d2, index + 1)

func _q90() -> void:
	if not _v86:
		return

	_v86.clear()

	var _m76 = []
	if _a8:
		_m76 = _a8._p10()

	if _m76.size() > 0 and _m76[0] is Dictionary and _m76[0].has("id"):
		for _i12 in _m76:
			var _j4 = _i12.get("display_name", _i12.get("id", "Unknown"))
			_v86.add_item(_j4)
	else:
		for _j72 in _p17:
			_v86.add_item(_j72["name"])
	_v86.selected = 0  

func _w8() -> String:
	if not _v86:
		return ""

	var _j35 = _v86.selected
	if _j35 < 0:
		return ""

	var _m76 = []
	if _a8:
		_m76 = _a8._p10()

	if _m76.size() > 0 and _m76[0] is Dictionary and _m76[0].has("id"):
		if _j35 < _m76.size():
			return _m76[_j35].get("id", "")
	else:
		if _j35 < _p17.size():
			return _p17[_j35]["id"]

	return ""

func _l71(index: int):
	var _o62 = ["production", "development"][index]
	var _y48 = ""
	
	if _a8:
		_a8._a11(_o62)

		_y48 = _a8._m83()
		_p70.text = _y48
	
	if _y48.is_empty():
		_d12.text = "No API Key (%s)" % _o62.capitalize()
	else:
		_d12.text = "API Key Loaded (%s)" % _o62.capitalize()
	
func _l59():
	if not _p50:
		return
	
	var _q79 = HSeparator.new()
	_p50.add_child(_q79)

	var _s32 = VBoxContainer.new()
	_s32.add_theme_constant_override("separation", 5)
	_p50.add_child(_s32)
	
	var _g96 = Label.new()
	_g96.text = "Ghost Text Autocomplete"
	_g96.add_theme_font_size_override("font_size", int(20 * _p33))
	_s32.add_child(_g96)
	
	_j86 = CheckBox.new()
	_j86.text = "Enable Autocomplete"
	_j86.button_pressed = true  
	_j86.toggled.connect(_a39)
	_s32.add_child(_j86)
	
	var _q52 = HBoxContainer.new()
	_q52.layout_mode = 2
	_s32.add_child(_q52)
	
	var _x4 = Label.new()
	_x4.text = "Trigger Mode:"
	_x4.custom_minimum_size.x = 150
	_q52.add_child(_x4)
	
	_e56 = OptionButton.new()
	_e56.layout_mode = 2
	_e56.add_item("Automatic")
	_e56.add_item("Manual (Ctrl+Space)")
	_e56.selected = 0
	_e56.item_selected.connect(_n83)
	_q52.add_child(_e56)
	
	var _o89 = HBoxContainer.new()
	_o89.layout_mode = 2
	_s32.add_child(_o89)
	
	var _d94 = Label.new()
	_d94.text = "Minimum Characters:"
	_d94.custom_minimum_size.x = 150
	_o89.add_child(_d94)
	
	_m62 = SpinBox.new()
	_m62.layout_mode = 2
	_m62.min_value = 1
	_m62.max_value = 10
	_m62.value = 3
	_m62.step = 1
	_m62.value_changed.connect(_a19)
	_o89.add_child(_m62)
	
	var _m73 = Label.new()
	_m73.text = "Smart triggers: After '.', '(', ':', '=', or space following keywords"
	_m73.layout_mode = 2
	var _e83 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_m73.add_theme_color_override("font_color", Color(_e83, 0.6))
	_m73.set_meta("secondary", true)
	_m73.add_theme_font_size_override("font_size", 12)
	_m73.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_s32.add_child(_m73)
	
	var _a64 = HSeparator.new()
	_s32.add_child(_a64)
	
	var _g46 = HBoxContainer.new()
	_g46.layout_mode = 2
	_s32.add_child(_g46)
	
	var _m88 = Label.new()
	_m88.text = "Inline Explain Buttons"
	_m88.add_theme_font_size_override("font_size", int(16 * _p33))
	_g46.add_child(_m88)

	_f93 = CheckBox.new()
	_f93.text = "Show Explain Buttons Above Functions"
	_f93.button_pressed = true  
	_f93.toggled.connect(_z31)
	_s32.add_child(_f93)
	
	var _t18 = Label.new()
	_t18.text = "Adds clickable help icons above function declarations to explain code"
	_t18.layout_mode = 2
	var _m35 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_t18.add_theme_color_override("font_color", Color(_m35, 0.6))
	_t18.set_meta("secondary", true)
	_t18.add_theme_font_size_override("font_size", 12)
	_t18.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_s32.add_child(_t18)
	
	var _s53 = HSeparator.new()
	_s32.add_child(_s53)
	
	var _a38 = Label.new()
	_a38.text = "Inline Refactor Buttons"
	_a38.add_theme_font_size_override("font_size", int(18 * _p33))
	_s32.add_child(_a38)
	
	_q35 = CheckBox.new()
	_q35.text = "Show Refactor Buttons Above Functions"
	_q35.button_pressed = true  
	_q35.toggled.connect(_i17)
	_s32.add_child(_q35)
	
	var _i35 = Label.new()
	_i35.text = "Adds clickable ↻ icons above function declarations for AI-powered refactoring"
	_i35.layout_mode = 2
	var _e74 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_i35.add_theme_color_override("font_color", Color(_e74, 0.6))
	_i35.set_meta("secondary", true)
	_i35.add_theme_font_size_override("font_size", 12)
	_i35.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_s32.add_child(_i35)
	
	var _h56 = HSeparator.new()
	_s32.add_child(_h56)
	
	_i93(_s32)
	
	_t82()

func _t82():
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		_j86.button_pressed = config.get_value("autocomplete", "enabled", true)
		
		var mode = config.get_value("autocomplete", "mode", "automatic")
		_e56.selected = 0 if mode == "automatic" else 1
		
		_m62.value = config.get_value("autocomplete", "min_chars", 3)
		
		_f93.button_pressed = config.get_value("explain_button", "enabled", true)
		
		_q35.button_pressed = config.get_value("refactor_button", "enabled", true)
		
		var _g44 = find_child("_w42", true)
		var _b57 = find_child("_w62", true)
		var _g91 = find_child("_k26", true)
		
		if _g44:
			_g44.button_pressed = config.get_value("undo", "enabled", true)
		if _b57:
			_b57.value = config.get_value("undo", "max_history_items", 20)
		if _g91:
			_g91.button_pressed = config.get_value("undo", "show_history_button", true)

func _o14():
	var mode = "automatic" if _e56.selected == 0 else "manual"
	
	const _d51 = 1000
	const _w84 = 150
	
	if _l33 and _l33.has_method("save_autocomplete_config"):
		_l33.save_autocomplete_config(
			_j86.button_pressed,
			_d51,
			_w84,
			mode,
			int(_m62.value)
		)
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_api_key.cfg")
		config.set_value("autocomplete", "enabled", _j86.button_pressed)
		config.set_value("autocomplete", "delay_ms", _d51)
		config.set_value("autocomplete", "max_length", _w84)
		config.set_value("autocomplete", "mode", mode)
		config.set_value("autocomplete", "min_chars", int(_m62.value))
		config.save("user://gdsense_api_key.cfg")

func _a39(enabled: bool):
	_o14()

func _n83(index: int):
	_o14()

func _a19(value: float):
	_o14()

func _z31(enabled: bool):
	if _l33 and _l33.has_method("save_explain_button_config"):
		_l33.save_explain_button_config(enabled)
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_api_key.cfg")
		config.set_value("explain_button", "enabled", enabled)
		config.save("user://gdsense_api_key.cfg")

func _i17(enabled: bool):
	if _l33 and _l33.has_method("save_refactor_config"):
		_l33.save_refactor_config(enabled)
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_api_key.cfg")
		config.set_value("refactor_button", "enabled", enabled)
		config.save("user://gdsense_api_key.cfg")

func _i93(_n62: VBoxContainer):
	var _h74 = Label.new()
	_h74.text = "Refactor Undo System"
	_h74.add_theme_font_size_override("font_size", int(18 * _p33))
	_n62.add_child(_h74)
	
	var _g44 = CheckBox.new()
	_g44.name = "UndoEnabledCheckbox"
	_g44.text = "Enable Undo for Refactored Functions"
	_g44.button_pressed = true  
	_g44.toggled.connect(_j8)
	_n62.add_child(_g44)
	
	var _d50 = HBoxContainer.new()
	_d50.layout_mode = 2
	_n62.add_child(_d50)
	
	var _y72 = Label.new()
	_y72.text = "Max History Items:"
	_y72.custom_minimum_size.x = 150
	_d50.add_child(_y72)
	
	var _b57 = SpinBox.new()
	_b57.name = "MaxHistorySpinbox"
	_b57.layout_mode = 2
	_b57.min_value = 5
	_b57.max_value = 50
	_b57.value = 20
	_b57.step = 1
	_b57.value_changed.connect(_d75)
	_d50.add_child(_b57)
	
	var _g91 = CheckBox.new()
	_g91.name = "ShowHistoryCheckbox"
	_g91.text = "Show History Button in Panel"
	_g91.button_pressed = true  
	_g91.toggled.connect(_l60)
	_n62.add_child(_g91)
	
	var _f61 = Label.new()
	_f61.text = "Track refactored functions with visual indicators and one-click undo"
	_f61.layout_mode = 2
	_f61.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_f61.add_theme_font_size_override("font_size", 12)
	_f61.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_n62.add_child(_f61)

func _j8(enabled: bool):
	if _l33 and _l33.has_method("save_undo_config"):
		_l33.save_undo_config(enabled)
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_settings.cfg")
		config.set_value("undo", "enabled", enabled)
		config.save("user://gdsense_settings.cfg")

func _d75(value: float):
	if _l33 and _l33.has_method("save_undo_max_history"):
		_l33.save_undo_max_history(int(value))
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_settings.cfg")
		config.set_value("undo", "max_history_items", int(value))
		config.save("user://gdsense_settings.cfg")

func _l60(enabled: bool):
	if _l33 and _l33.has_method("save_undo_show_history"):
		_l33.save_undo_show_history(enabled)
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_settings.cfg")
		config.set_value("undo", "show_history_button", enabled)
		config.save("user://gdsense_settings.cfg")

func _z15():
	if not _p50:
		return
	
	var _q79 = HSeparator.new()
	_p50.add_child(_q79)

	var _a73 = VBoxContainer.new()
	_a73.add_theme_constant_override("separation", 10)
	_p50.add_child(_a73)
	
	var _z91 = Label.new()
	_z91.text = "Custom Instructions"
	_z91.add_theme_font_size_override("font_size", int(20 * _p33))
	_a73.add_child(_z91)
	
	var _q89 = HBoxContainer.new()
	_a73.add_child(_q89)
	
	var _w30 = Label.new()
	_w30.text = "Godot Version:"
	_w30.custom_minimum_size.x = 120
	_q89.add_child(_w30)
	
	var _h32 = Label.new()
	_h32.text = _a8._s50() if _a8 else "Unknown"
	var _o24 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_h32.add_theme_color_override("font_color", Color(_o24, 0.6))
	_h32.set_meta("secondary", true)
	_q89.add_child(_h32)
	
	var _y75 = HBoxContainer.new()
	_a73.add_child(_y75)
	
	var _n31 = Label.new()
	_n31.text = "Temperature:"
	_n31.custom_minimum_size.x = 120
	_y75.add_child(_n31)
	
	var _u57 = SpinBox.new()
	_u57.name = "TemperatureSpinBox"
	_u57.min_value = 0.0
	_u57.max_value = 1.0
	_u57.step = 0.1
	_u57.value = 0.0
	_u57.value_changed.connect(_u56)
	_y75.add_child(_u57)
	
	var _y61 = Label.new()
	_y61.text = "(0.0 = use default)"
	var _i74 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_y61.add_theme_color_override("font_color", Color(_i74, 0.6))
	_y61.set_meta("secondary", true)
	_y61.add_theme_font_size_override("font_size", 11)
	_y75.add_child(_y61)
	
	var _m5 = Label.new()
	_m5.text = "Custom Rules (500 char limit):"
	_m5.add_theme_font_size_override("font_size", int(18 * _p33))
	_a73.add_child(_m5)

	_b20 = TextEdit.new()
	_b20.name = "CustomRulesInput"
	_b20.custom_minimum_size = Vector2(0, 100)
	_b20.placeholder_text = "Enter custom rules for AI responses (one per line)..."
	_b20.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_b20.text_changed.connect(_g19)
	_a73.add_child(_b20)

	_x77 = Label.new()
	_x77.name = "CharCounter"
	_x77.text = "0/500"
	_x77.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_x77.add_theme_font_size_override("font_size", 12)
	_x77.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_a73.add_child(_x77)

	_n26 = Label.new()
	_n26.name = "ValidationMessage"
	_n26.text = ""
	_n26.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	_n26.add_theme_font_size_override("font_size", 12)
	_n26.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_n26.visible = false
	_a73.add_child(_n26)
	
	_y36.call_deferred()

func _d52():
	_r40 = _f28.new()

	_r40._z100()

	if _c70:
		_c70.item_selected.connect(_s98)
	if _r26:
		_r26.item_selected.connect(_k95)

	if _u84:
		_u84.pressed.connect(_k28)
	if _n64:
		_n64.pressed.connect(_t55)
	if _p19:
		_p19.pressed.connect(_i37)
	if _q66:
		_q66.pressed.connect(_y49)

	if _a83:
		_a83.pressed.connect(_t6)
	if _d74:
		_d74.pressed.connect(_z19)
	if _b47:
		_b47.pressed.connect(_c73)
	if _q62:
		_q62.pressed.connect(_d69)

	if _y87:
		_y87.pressed.connect(_k62)
	if _y76:
		_y76.pressed.connect(_z33)
	if _i56:
		_i56.pressed.connect(_z99)
	if _p35:
		_p35.pressed.connect(_f52)

	if _s44:
		_s44.file_selected.connect(_y13)
	if _o54:
		_o54.file_selected.connect(_b93)

	if _y45:
		_y45.confirmed.connect(_l28)

	_j17()

	_t51()

func _x86():
	if _b65:
		_b65.item_selected.connect(_i91)

	_m8()

	var _p41 = _t60()
	var _i55 = _o85()
	_t49.text = "Auto: %.0f%% (%s detected). Your resolution: %dx%d" % [
		_i55 * 100,
		_p41,
		get_viewport().get_visible_rect().size.x,
		get_viewport().get_visible_rect().size.y
	]

	_v88()

func _t60() -> String:
	var _f50 = get_viewport().get_visible_rect().size
	var width = int(_f50.x)
	var height = int(_f50.y)

	if width < 800 or width > 16384 or height < 600 or height > 16384:
		width = 1920
		height = 1080

	var _u34 = 100
	for _p39 in _t38:
		var _f95 = _t38[_p39]
		if abs(width - _f95.width) <= _u34 and abs(height - _f95.height) <= _u34:
			return _p39

	var _a56 = width * height
	var _y95 = "1080p"
	var _l92 = INF

	for _p39 in _t38:
		var _f95 = _t38[_p39]
		var _b8 = _f95.width * _f95.height
		var _e6 = abs(_a56 - _b8)
		if _e6 < _l92:
			_l92 = _e6
			_y95 = _p39

	return _y95

func _o85() -> float:
	var _p39 = _t60()
	return _t38[_p39].scale

func _m51() -> float:
	if _s31 == "auto":
		return _o85()
	else:
		var _i28 = float(_s31)
		_i28 = clamp(_i28, 0.5, 3.0)  
		if is_nan(_i28) or is_inf(_i28):
			_i28 = 1.0  
		return _i28

func _v88():
	_p33 = _m51()
	var _y84 = int(_o65 * _p33)

	var _f57 = get_node_or_null("MarginContainer/TabContainer/History")
	if _f57:
		for label in _l26(_f57):
			if label is Label:
				label.add_theme_font_size_override("font_size", _y84)
			elif label is RichTextLabel:
				label.add_theme_font_size_override("normal_font_size", _y84)

	_q69(_y84)

func _q69(_y84: int):
	var _f71 = get_node_or_null("MarginContainer/TabContainer/Settings/_q8/VBoxContainer")
	if not _f71:
		return

	var _p68 = ["Ghost Text Autocomplete", "Custom Instructions"]
	var _s16 = ["Inline Explain Buttons", "Inline Refactor Buttons", "Refactor Undo System",
					   "Custom Rules", "Parameter Overrides"]

	for _w15 in _l26(_f71):
		if _w15 is Label:
			var _r28 = _w15.text
			var target_size = _y84

			for _l100 in _p68:
				if _r28.begins_with(_l100):
					target_size = int(20 * _p33)
					break

			if target_size == _y84:  
				for _o17 in _s16:
					if _r28.begins_with(_o17):
						target_size = int(18 * _p33)
						break

			_w15.add_theme_font_size_override("font_size", target_size)
		elif _w15 is RichTextLabel:
			_w15.add_theme_font_size_override("normal_font_size", _y84)
func _u44(text: String) -> bool:
	var _d82 = [
		"highest-volume", "smart triggers", "fixed settings", "adds clickable",
		"track refactored", "use default", "auto detects", "char limit",
		"following keywords", "second delay", "token max", "help icons",
		"visual indicators", "one-click undo", "AI-powered"
	]
	for _c84 in _d82:
		if _c84 in text:
			return true
	return false

func _l26(node: Node) -> Array:
	var children = []
	for _w15 in node.get_children():
		children.append(_w15)
		children.append_array(_l26(_w15))
	return children

func _i91(index: int):
	var _q18 = _v45[index]

	if typeof(_q18) == TYPE_STRING and _q18 == "auto":
		_s31 = "auto"
	else:
		_s31 = str(_q18)

	_b55()

	_v88()

	if _s31 == "auto":
		var _p41 = _t60()
		var _i55 = _o85()
		_t49.text = "Auto: %.0f%% (%s detected). Your resolution: %dx%d" % [
			_i55 * 100,
			_p41,
			get_viewport().get_visible_rect().size.x,
			get_viewport().get_visible_rect().size.y
		]
	else:
		_t49.text = "Manual: %.0f%%. Auto detects based on 1080p/1440p/4K presets" % [
			float(_s31) * 100
		]

func _b55():
	var config = ConfigFile.new()
	config.load("user://gdsense_settings.cfg")
	config.set_value("font_scale", "mode", _s31)
	config.save("user://gdsense_settings.cfg")

func _m8():
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		_s31 = config.get_value("font_scale", "mode", "auto")

		if _s31 == "auto":
			_b65.selected = 0
		elif _s31 == "0.8":
			_b65.selected = 1
		elif _s31 == "1.0":
			_b65.selected = 2
		elif _s31 == "1.25":
			_b65.selected = 3
		elif _s31 == "1.5":
			_b65.selected = 4

	else:
		_s31 = "auto"
		_b65.selected = 0

func _e66(parent: Node) -> void:
	var _v23 = HBoxContainer.new()
	_v23.add_theme_constant_override("separation", 10)
	
	var _w73 = Control.new()
	_w73.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_v23.add_child(_w73)
	
	var _f25 = Button.new()
	_f25.text = "👍"
	_f25.tooltip_text = "Good response"
	_f25.flat = false  
	_f25.custom_minimum_size = Vector2(36, 36)  
	_f25.add_theme_font_size_override("font_size", 16)
	_f25.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	_f25.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9))
	_f25.add_theme_stylebox_override("normal", _r72())
	_f25.add_theme_stylebox_override("hover", _l4())
	_f25.add_theme_stylebox_override("pressed", _q100())
	_f25.pressed.connect(_u21)
	_z71(_f25)
	_v23.add_child(_f25)
	
	var _b24 = Button.new()
	_b24.text = "👎"
	_b24.tooltip_text = "Poor response"
	_b24.flat = false  
	_b24.custom_minimum_size = Vector2(36, 36)  
	_b24.add_theme_font_size_override("font_size", 16)
	_b24.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	_b24.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9))
	_b24.add_theme_stylebox_override("normal", _r72())
	_b24.add_theme_stylebox_override("hover", _l4())
	_b24.add_theme_stylebox_override("pressed", _q100())
	_b24.pressed.connect(_z68)
	_z71(_b24)
	_v23.add_child(_b24)
	
	parent.add_child(_v23)

func _r72() -> StyleBoxFlat:
	var _x67 = StyleBoxFlat.new()
	_x67.bg_color = Color(0, 0, 0, 0)  
	_x67.set_corner_radius_all(4)
	return _x67

func _l4() -> StyleBoxFlat:
	var _x67 = StyleBoxFlat.new()
	_x67.bg_color = Color(0.3, 0.3, 0.3, 0.3)  
	_x67.set_corner_radius_all(6)
	_x67.set_border_width_all(1)
	_x67.border_color = Color(0.5, 0.5, 0.5, 0.5)
	return _x67

func _q100() -> StyleBoxFlat:
	var _x67 = StyleBoxFlat.new()
	_x67.bg_color = Color(0.2, 0.2, 0.2, 0.4)  
	_x67.set_corner_radius_all(6)
	_x67.set_border_width_all(1)
	_x67.border_color = Color(0.4, 0.4, 0.4, 0.6)
	return _x67

func _z71(_i32: Button) -> void:
	_i32.set_meta("original_scale", Vector2.ONE)
	_i32.set_meta("is_hovering", false)
	
	_i32.modulate.a = 0.7  
	_i32.pivot_offset = _i32.custom_minimum_size / 2  
	
	_i32.mouse_entered.connect(_q40.bind(_i32))
	_i32.mouse_exited.connect(_k24.bind(_i32))
	_i32.button_down.connect(_a42.bind(_i32))
	_i32.button_up.connect(_n47.bind(_i32))

func _q40(_i32: Button) -> void:
	if _i32.get_meta("is_hovering", false):
		return
	_i32.set_meta("is_hovering", true)
	
	var _v70 = get_tree().create_tween()
	_v70.set_parallel(true)
	_v70.set_ease(Tween.EASE_OUT)
	_v70.set_trans(Tween.TRANS_CUBIC)
	
	_v70.tween_property(_i32, "scale", Vector2(1.2, 1.2), 0.2)

	_v70.tween_property(_i32, "modulate:a", 1.0, 0.2)

	_v70.tween_property(_i32, "modulate", Color(1.1, 1.1, 1.1, 1.0), 0.2)

func _k24(_i32: Button) -> void:
	_i32.set_meta("is_hovering", false)
	
	var _v70 = get_tree().create_tween()
	_v70.set_parallel(true)
	_v70.set_ease(Tween.EASE_OUT)
	_v70.set_trans(Tween.TRANS_CUBIC)
	
	_v70.tween_property(_i32, "scale", Vector2.ONE, 0.2)

	_v70.tween_property(_i32, "modulate", Color(1.0, 1.0, 1.0, 0.7), 0.2)

func _a42(_i32: Button) -> void:
	var _v70 = get_tree().create_tween()
	_v70.set_ease(Tween.EASE_OUT)
	_v70.set_trans(Tween.TRANS_CUBIC)
	_v70.tween_property(_i32, "scale", Vector2(0.95, 0.95), 0.1)

func _n47(_i32: Button) -> void:
	var _i39 = Vector2(1.2, 1.2) if _i32.get_meta("is_hovering", false) else Vector2.ONE
	var _v70 = get_tree().create_tween()
	_v70.set_ease(Tween.EASE_OUT)
	_v70.set_trans(Tween.TRANS_CUBIC)
	_v70.tween_property(_i32, "scale", _i39, 0.1)

func _u21():
	if _a8:
		_a8._t1("positive", "helpful", "")

func _z68():
	_g62()

func _g62():
	var _n5 = AcceptDialog.new()
	_n5.title = "Help Us Improve"
	_n5.dialog_close_on_escape = true
	
	_n5.size = Vector2(400, 300)
	
	var _m49 = VBoxContainer.new()
	_m49.add_theme_constant_override("separation", 10)
	
	var _g98 = Label.new()
	_g98.text = "What was wrong with this response?"
	_m49.add_child(_g98)
	
	var _y93 = OptionButton.new()
	_y93.name = "CategoryOptions"
	_y93.add_item("Incorrect information")
	_y93.add_item("Wrong Godot version")
	_y93.add_item("Code doesn't work")
	_y93.add_item("Too complex")
	_y93.add_item("Not helpful")
	_y93.add_item("Other")
	_m49.add_child(_y93)
	
	var _c2 = Label.new()
	_c2.text = "Additional details (optional):"
	_m49.add_child(_c2)
	
	var _h41 = TextEdit.new()
	_h41.name = "DetailsText"
	_h41.custom_minimum_size = Vector2(0, 80)
	_h41.placeholder_text = "Describe what went wrong..."
	_m49.add_child(_h41)
	
	var _n72 = HBoxContainer.new()
	_n72.alignment = BoxContainer.ALIGNMENT_END
	
	var _s94 = Button.new()
	_s94.text = "Cancel"
	_s94.pressed.connect(_n5.hide)
	_n72.add_child(_s94)
	
	var _g37 = Button.new()
	_g37.text = "Submit Feedback"
	_g37.pressed.connect(_s41.bind(_n5))
	_n72.add_child(_g37)
	
	_m49.add_child(_n72)
	
	_n5.add_child(_m49)
	add_child(_n5)
	_n5.popup_centered()

func _s41(_i52: AcceptDialog):
	var _m49 = _i52.get_child(0)

	var _y93: OptionButton = null
	var _h41: TextEdit = null
	for _w15 in _m49.get_children():
		if _w15 is OptionButton and not _y93:
			_y93 = _w15
		elif _w15 is TextEdit and not _h41:
			_h41 = _w15
	
	var _y62 = ""
	if _y93.selected >= 0:
		_y62 = _y93.get_item_text(_y93.selected)
	
	var details = _h41.text.strip_edges()
	
	if _a8:
		_a8._t1("negative", _y62, details)

	_i52.hide()
	_i52.queue_free()

func _g19():
	if not _b20 or not _x77 or not _n26:
		return

	var _r39 = _b20.text
	var _g81 = _r39.length()
	_x77.text = "%d/500" % _g81
	
	if _g81 > 500:
		_x77.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	elif _g81 > 400:
		_x77.add_theme_color_override("font_color", Color(1.0, 0.8, 0.5))
	else:
		_x77.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	
	if _a8:
		var _i8 = _a8._z94(_r39)
		if _i8.get("valid", false):
			_n26.visible = false
			_a8._t41(_r39)
		else:
			var _l20 = _i8.get("errors", ["Unknown error"])
			_n26.text = _l20[0] if not _l20.is_empty() else "Unknown error"
			_n26.visible = true

func _u56(value: float):
	if _a8:
		var _k12 = find_child("_u30", true)
		var max_tokens = _k12.value if _k12 else 0
		_a8._a34(value, int(max_tokens))

func _i58(value: float):
	if _a8:
		var _u57 = find_child("_w91", true)
		var _w75 = _u57.value if _u57 else 0.0
		_a8._a34(_w75, int(value))

func _y36():
	if not _a8:
		return

	var _u57 = find_child("_w91", true)
	var _k12 = find_child("_u30", true)

	if _b20:
		var config = ConfigFile.new()
		if config.load("user://gdsense_settings.cfg") == OK:
			var _r39 = config.get_value("custom_rules", "rules_text", "")
			_b20.text = _r39
			if _x77:
				_x77.text = "%d/500" % _r39.length()
		else:
			pass
	else:
		pass
	if _u57:
		var config = ConfigFile.new()
		if config.load("user://gdsense_settings.cfg") == OK:
			var _w75 = config.get_value("parameters", "temperature_override", 0.0)
			_u57.value = _w75
	
	if _k12:
		var config = ConfigFile.new()
		if config.load("user://gdsense_settings.cfg") == OK:
			var max_tokens = config.get_value("parameters", "max_tokens_override", 0)
			_k12.value = max_tokens

func _d88(_e26: Array, parent: Node):
	var _q79 = HSeparator.new()
	_q79.add_theme_constant_override("separation", 8)
	parent.add_child(_q79)
	
	var _v33 = Label.new()
	_v33.text = "📚 Documentation Sources:"
	_v33.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	_v33.add_theme_font_size_override("font_size", 25)
	parent.add_child(_v33)
	
	var _b15 = VBoxContainer.new()
	_b15.add_theme_constant_override("separation", 1)
	parent.add_child(_b15)
	
	_e26.sort_custom(func(a, b): return a.get("priority", 0.0) > b.get("priority", 0.0))
	var _a71 = min(_e26.size(), 5)
	
	for i in range(_a71):
		var source = _e26[i]
		var _p12 = source.get("url", "")
		var title = source.get("title", "Godot Documentation")
		
		if not _p12.is_empty():
			var _h39 = HBoxContainer.new()
			_h39.add_theme_constant_override("separation", 8)
			_b15.add_child(_h39)
			
			var _z77 = Label.new()
			_z77.text = "•"
			_z77.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
			_z77.custom_minimum_size.x = 12
			_h39.add_child(_z77)
			
			var _k91 = Button.new()

			var _f55 = title if title.length() <= 60 else title.substr(0, 57) + "..."
			_k91.text = _f55
			_k91.tooltip_text = title  
			_k91.flat = true
			_k91.clip_text = true  
			_k91.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
			_k91.add_theme_color_override("font_hover_color", Color(0.8, 0.9, 1.0))
			_k91.add_theme_font_size_override("font_size", 20)
			_k91.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_k91.alignment = HORIZONTAL_ALIGNMENT_LEFT
			_k91.pressed.connect(_h79.bind(_p12))
			_h39.add_child(_k91)

func _h79(_p12: String):
	OS.shell_open(_p12)

func send_explain_request(function_name: String, _g33: String):
	if not _a8:
		return
	
	var _z84 = "@explain %s\n\nFunction source:\n```gdscript\n%s\n```" % [function_name, _g33]
	
	_b94(_z84)

func _z66(function_name: String, _g33: String):
	if not _z72:
		return
	
	_z72.text = ""
	
	var _z84 = "@explain %s\n\nFunction source:\n```gdscript\n%s\n```" % [function_name, _g33]
	
	_z72.text = _z84
	
	_z72.grab_focus()
	_z72.set_caret_line(_z72.get_line_count() - 1)
	_z72.set_caret_column(_z72.get_line(_z72.get_line_count() - 1).length())
	
func _exit_tree() -> void:
	_c93()

	_x22()
	_y12()
	_o56()

	if _n65:
		if _n65._z89.is_connected(_b73):
			_n65._z89.disconnect(_b73)
		if _n65._t76.is_connected(_k50):
			_n65._t76.disconnect(_k50)
		if _n65._p61.is_connected(_s80):
			_n65._p61.disconnect(_s80)
		if _n65._x69.is_connected(_g99):
			_n65._x69.disconnect(_g99)
		if _n65._l88.is_connected(_i26):
			_n65._l88.disconnect(_i26)
		if _n65._r83.is_connected(_j23):
			_n65._r83.disconnect(_j23)
		if _n65._s92.is_connected(_e92):
			_n65._s92.disconnect(_e92)
		if _n65._h40.is_connected(_f41):
			_n65._h40.disconnect(_f41)
		_n65._k63()
		_n65 = null
	_h42 = null

	if is_instance_valid(_y58):
		if _y58.pressed.is_connected(_y56):
			_y58.pressed.disconnect(_y56)
		_y58.queue_free()
		_y58 = null

	if _g78:
		if _g78._f8:
			_g78._f8.clear()
		_g78 = null

	if _o10:
		_o10._g78 = null
		_o10 = null

	if _z24:
		_z24._k63()
		_z24 = null

	if _w88:
		for _w15 in _w88.get_children():
			_w15.queue_free()
		_w88 = null

	_q41.clear()

	if _a8:
		if _a8._w22.is_connected(_k80):
			_a8._w22.disconnect(_k80)
		if _a8._t4.is_connected(_h77):
			_a8._t4.disconnect(_h77)
		if _a8._i53.is_connected(_a70):
			_a8._i53.disconnect(_a70)
		if _a8._r78.is_connected(_c25):
			_a8._r78.disconnect(_c25)
		if _a8._b48.is_connected(_h48):
			_a8._b48.disconnect(_h48)
		if _a8._u23.is_connected(_o66):
			_a8._u23.disconnect(_o66)
		if _a8._f5.is_connected(_v81):
			_a8._f5.disconnect(_v81)

	if _i89:
		_i89.free()
		_i89 = null
	
	_t15 = null
	_c37 = null
	_a8 = null
	_l33 = null

func _q10() -> void:
	if _f4:
		_f4.custom_minimum_size.y = 8
		_f4.show_percentage = false
		
		var _t28 = StyleBoxFlat.new()
		_t28.bg_color = Color(0.1, 0.1, 0.1, 0.5)
		_t28.corner_radius_top_left = 4
		_t28.corner_radius_top_right = 4
		_t28.corner_radius_bottom_left = 4
		_t28.corner_radius_bottom_right = 4
		_f4.add_theme_stylebox_override("background", _t28)
		
		_f4.mouse_entered.connect(_v69)
		_f4.mouse_exited.connect(_s49)
	
	_q56(0.0)
	
	if _m50:
		_m50.mouse_entered.connect(_v69)
		_m50.mouse_exited.connect(_s49)

func _e44() -> void:
	if not _z47:
		return

	_z47.clear()

	_z47.add_item("Commands")
	_z47.selected = 0

	_z47.add_separator()

	for _r33 in _m96:
		_z47.add_item(_r33)

	_z47.item_selected.connect(_l79)

func _u93() -> void:
	if not _p14:
		return

	_p14.clear()

	_p14.add_item(_l42[_v100])

	_w23()

	_p14.item_selected.connect(_i38)

	_b37()

func _b37() -> void:
	if not _p14 or not _t15:
		return

func _w23() -> void:
	if not _p14:
		return

	var _p54 = false
	if _a8:
		var _d41 = _a8._r47()
		if _d41 and _d41.has("features"):
			var features = _d41.get("features", {})
			_p54 = features.get("agent", false)

	var _b96 = _p14.item_count > 1

	if _p54:
		if not _b96:
			_p14.add_item(_l42[_r45])
	else:
		if _b96:
			if _p14.selected == _r45:
				_p14.selected = _v100
				_w78()
			_p14.remove_item(_r45)
func _i38(index: int) -> void:
	match index:
		_v100:
			_x32 = false

			if _b77:
				_b77.visible = true
			if _m94:
				_m94.visible = true

			if _v86:
				_v86.visible = false

			_z72.placeholder_text = "Ask me anything about Godot..."
		_r45:
			_k98()
	_z72.grab_focus()

func _v63() -> void:
	_s84()

	var _n98 = _z72.text
	
	var command_count = 0
	for _p56 in _m96:
		var _p69 = RegEx.new()
		_p69.compile(_p56 + "\\b")  
		var _c95 = _p69.search_all(_n98)
		command_count += _c95.size()
	
	if command_count != _u71:
		_u71 = command_count

		if _w27:
			_w27.stop()
			_w27.start()

func _h65() -> void:
	_j92(true)

func _l91(_r33: String, path: String) -> void:
	_j92(true)

func _j92(_a69: bool = false) -> void:
	if _b85 and not _a69:
		return

	var _n98 = _z72.text
	var _r65 = not _n98.strip_edges().is_empty()
	var _c24 = _q41.size() > 0
	
	if not _r65 and not _c24:
		_a100(0, [])
		return

	var _t19 = Time.get_ticks_msec()
	if not _a69 and not _t90.is_empty():
		var _i13 = _t19 - _t90.get("time", 0)
		if _i13 < _w21:
			var _n71 = _t90.get("tokens", 0)
			var _u20 = _t90.get("breakdown", [])
			_a100(_n71, _u20)
			return

	if _m50:
		_m50.text = "Context: Updating..."

	if _a8 and not _a8._m83().is_empty():
		var messages = []
		
		for message in _q41:
			messages.append(message)
		
		var context_metadata: Dictionary = {}
		
		if _r65:
			var _b14 = _p23(_n98, false)
			var processed_prompt = _b14.get("processed_prompt", _n98)
			
			if not processed_prompt.is_empty():
				messages.append({
					"role": "user",
					"content": processed_prompt
				})
			
			var _j3 = _b14.get("context_metadata", {})
			if _j3 == null or not _j3 is Dictionary:
				_j3 = {}
			context_metadata = _j3
		else:
			context_metadata = {}
		
		_a8._h57(messages, context_metadata)
	else:
		_x35()

func _x35() -> void:
	var _n98 = _z72.text
	var _b14 = _p23(_n98, false)
	var estimated_tokens = _b14.get("estimated_tokens", 0)
	
	var _v2 = _e62()
	var _g14 = estimated_tokens + _v2
	
	var breakdown = [
		{"name": "current_prompt", "tokens": estimated_tokens},
		{"name": "chat_history", "tokens": _v2}
	]
	
	_a100(_g14, breakdown)

func _t45(_u3: int, breakdown: Array, _y86: int = 128000) -> void:
	_z96 = _y86

	_t90 = {
		"tokens": _u3,
		"breakdown": breakdown,
		"limit": _y86,
		"time": Time.get_ticks_msec()
	}

	_a100(_u3, breakdown)

func _e62() -> int:
	var _n8 = 0
	for message in _q41:
		if message.has("content"):
			_n8 += message["content"].length()
	return _n8 / 4

func _a100(tokens: int, breakdown: Array) -> void:
	_y25 = tokens
	_p65 = breakdown

	var _i73 = float(tokens) / float(_z96) * 100.0
	if _f4:
		var _z20 = min(_i73, 100.0)
		if _z20 > 0 and _z20 < 0.5:
			_z20 = 0.5  
		_f4.value = _z20

	if _m50:
		if _i73 < 1.0 and _i73 > 0:
			_m50.text = "Context: " + str(snapped(_i73, 0.1)) + "%"
		else:
			_m50.text = "Context: " + str(int(_i73)) + "%"

		if _i73 >= 100.0:
			_m50.modulate = Color.RED
		elif _i73 >= 85.0:
			_m50.modulate = Color.YELLOW
		else:
			_m50.modulate = Color.LIGHT_GREEN
	
	_q56(_i73 / 100.0)

	if _i73 >= 95.0 and _a8:
		var _o72 = _a8._s21() if _a8 else ""
		_a8._n43.emit("critical", _o72, _i73, "")
	elif _i73 >= 90.0 and _a8:
		var _o72 = _a8._s21() if _a8 else ""
		_a8._n43.emit("high", _o72, _i73, "")
	elif _i73 >= 75.0 and _a8:
		var _o72 = _a8._s21() if _a8 else ""
		_a8._n43.emit("medium", _o72, _i73, "")

	if _i73 >= _h95 * 100.0:
		_t46.show()
		if _i73 >= 100.0:
			_t46.text = "⚠ Context capacity exceeded! Please reduce content."
			_t46.modulate = Color.RED
		else:
			_t46.text = "⚠ Context capacity at " + str(int(_i73)) + "% - consider reducing @ commands"
			_t46.modulate = Color.YELLOW
	else:
		_t46.hide()

func _b89() -> void:
	_a100(0, [])
	if _f4:
		_f4.tooltip_text = ""
	if _m50:
		_m50.tooltip_text = ""
	if _f82:
		_f82.hide()

func _q56(_i79: float) -> void:
	var color: Color
	if _i79 <= 0.6:  
		color = Color.GREEN
	elif _i79 <= 0.85:  
		color = Color.YELLOW
	else:  
		color = Color.RED
	
	var _o5 = StyleBoxFlat.new()
	_o5.bg_color = color
	_o5.corner_radius_top_left = 4
	_o5.corner_radius_top_right = 4
	_o5.corner_radius_bottom_left = 4
	_o5.corner_radius_bottom_right = 4
	
	if _f4:
		_f4.add_theme_stylebox_override("fill", _o5)

func _v69() -> void:
	var tooltip_text = "Context Usage Breakdown:\n"
	
	if _p65.size() > 0:
		for _c53 in _p65:
			if _c53 is Dictionary and _c53.has("name") and _c53.has("tokens"):
				var _v85 = _c53["tokens"]
				var _h82 = float(_v85) / float(_z96) * 100.0
				tooltip_text += str(_c53["name"]) + ": " + str(int(_h82)) + "%\n"

		tooltip_text = tooltip_text.rstrip("\n")
	else:
		tooltip_text += "No breakdown available"
	
	if _f4:
		_f4.tooltip_text = tooltip_text
	if _m50:
		_m50.tooltip_text = tooltip_text

func _s49() -> void:
	if _f4:
		_f4.tooltip_text = ""
	if _m50:
		_m50.tooltip_text = ""

func _l79(index: int) -> void:
	if index <= 1:
		return

	var _i80 = index - 2
	if _i80 >= 0 and _i80 < _m96.size():
		var _r33 = _m96[_i80]

		var _n98 = _z72.text
		var _i77 = _z72.get_caret_line()
		var caret_column = _z72.get_caret_column()

		if _i77 < _z72.get_line_count():
			var _c71 = _z72.get_line(_i77)
			var _a24 = _c71.substr(0, caret_column)
			var _h71 = _c71.substr(caret_column)

			var _b79 = _a24 + _r33 + " " + _h71
			_z72.set_line(_i77, _b79)

			_z72.set_caret_column(caret_column + _r33.length() + 1)
		else:
			_z72.text += _r33 + " "
			_z72.set_caret_column(_z72.text.length())

		_z47.selected = 0

		_j92()

		_z72.grab_focus()

func _u32(_r73: String) -> bool:
	var _k40 = [
		"truncated",
		"trimmed",
		"shortened",
		"context limit",
		"content limited"
	]
	
	var _z62 = _r73.to_lower()
	for _o9 in _k40:
		if _o9 in _z62:
			return true
	
	return false

func _t31(message: String) -> void:
	_f82.text = "ℹ " + message
	_f82.show()
	
	var _x64 = Timer.new()
	add_child(_x64)
	_x64.timeout.connect(func(): 
		_f82.hide()
		_x64.queue_free()
	)
	_x64.one_shot = true
	_x64.start(10.0)

func _y15(_n56: String) -> String:
	var _i46 = _n56.to_lower()
	
	if "token" in _i46 and ("limit" in _i46 or "exceed" in _i46):
		return "Your request is too large. Try reducing the amount of context or splitting into smaller requests."
	elif "rate limit" in _i46:
		return "You're sending requests too quickly. Please wait a moment before trying again."
	elif "unauthorized" in _i46 or "invalid api key" in _i46:
		return "Your API key is invalid or has expired. Please check your settings."
	elif "network" in _i46 or "connection" in _i46:
		return "Unable to connect to the AI service. Please check your internet connection."
	elif "timeout" in _i46:
		return "The request took too long to process. Please try again with a smaller request."
	elif "model" in _i46 and "not found" in _i46:
		return "The selected AI model is not available. Please try a different model."
	else:
		return _n56  

func _h15(_v57: Dictionary) -> void:
	_m2()

	_q90()

	_w87()

	_w23()

	_c74(_v57)

func _o15(_q67: String) -> String:
	if _q67.is_empty():
		return ""

	var _j22 = _q67.split("T")[0] if "T" in _q67 else _q67
	var _b75 = _j22.split("-")

	if _b75.size() < 3:
		return _q67  

	var year = _b75[0]
	var month = int(_b75[1]) if _b75[1].is_valid_int() else 0
	var day = int(_b75[2]) if _b75[2].is_valid_int() else 0

	if month < 1 or month > 12 or day < 1 or day > 31:
		return _q67  

	var _p76 = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
					   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

	return "%s %d, %s" % [_p76[month - 1], day, year]

func _i30(_i90: String, _n75: String, _i73: float, _f91: String = "") -> void:
	var _z55 = _i100()
	if _z55:
		var title = ""
		var message = ""
		var _j48 = _e46._h54.WARNING

		var _m28 = "credits"

		match _i90:
			"low":  
				title = "Usage Notice"
				message = "You've used %d%% of your %s for this period." % [int(_i73), _m28]
				_j48 = _e46._h54.INFO
			"medium":  
				title = "Usage Alert"
				message = "Heads up: you've used %d%% of your %s this period." % [int(_i73), _m28]
			"high":    
				title = "Usage Warning"
				message = "You've used %d%% of your %s. Consider switching models or upgrading." % [int(_i73), _m28]
				_j48 = _e46._h54.WARNING
			"critical": 
				title = "Critical Usage"
				message = "Critical: only %d%% of your %s remain." % [int(100 - _i73), _m28]
				_j48 = _e46._h54.ERROR

		if not _f91.is_empty():
			var _y69 = _o15(_f91)
			message += " Usage resets on %s." % _y69

		if _a8:
			var _m37 = _a8._j7()
			if _m37 != "ULTRA" and _m37 != "BETA_FREE":
				message += " Upgrade: gdsense.com/pricing"

		_z55._y35(title, message, _j48, 8.0)  

	if _i90 == "critical" and _d12:
		var _x25 = "⚠️ CRITICAL: %d%% of credits used" % [int(_i73)]
		_d12.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))  
		_d12.text = _x25

		await get_tree().create_timer(10.0).timeout
		if is_instance_valid(_d12):
			_d12.remove_theme_color_override("font_color")

			if _a8 and _a8._l7():
				_d12.text = "API Key Loaded"

				var _d41 = _a8._r47()
				if _d41 and _d41.has("tier"):
					_c74(_d41)
			else:
				_d12.text = "No API Key"

func _v81(message: String) -> void:
	var _z55 = _i100()
	if _z55:
		_z55._y35("Context Truncated", message, _e46._h54.WARNING, 5.0)

func _w87() -> void:
	if not _a8:
		return

	var _u2 = _a8._u2()

	if _q35:
		_q35.disabled = not _u2
		if not _u2:
			_q35.button_pressed = false
			_q35.tooltip_text = "Refactor is not available in Free tier"
		else:
			_q35.tooltip_text = "Show Refactor Buttons Above Functions"

	if _l33 and _l33.has_method("update_refactor_button_availability"):
		_l33.update_refactor_button_availability(_u2)

func _h25() -> void:
	if _b32:
		return  

	_b32 = PanelContainer.new()
	_b32.name = "UpdateBanner"
	_b32.visible = false

	var _b28 = StyleBoxFlat.new()
	if _t15:
		var _x16 = _t15.get_editor_settings()
		if _x16:
			var _t29 = _x16.get_setting("interface/theme/base_color")
			var _p38 = _x16.get_setting("interface/theme/accent_color")
			_b28.bg_color = _p38.lerp(_t29, 0.8)  
		else:
			_b28.bg_color = Color(0.2, 0.4, 0.6, 1.0)  
	else:
		_b28.bg_color = Color(0.2, 0.4, 0.6, 1.0)  

	_b28.set_corner_radius_all(4)
	_b28.set_content_margin_all(8)
	_b32.add_theme_stylebox_override("panel", _b28)

	var _z5 = HBoxContainer.new()
	_z5.add_theme_constant_override("separation", 8)

	var _c29 = Label.new()
	_c29.name = "UpdateMessage"
	_c29.text = "Update Available"
	_c29.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_z5.add_child(_c29)

	var _j47 = Label.new()
	_j47.name = "DownloadLink"
	_j47.text = "Download at gdsense.com"
	_j47.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))  
	_z5.add_child(_j47)

	var _q60 = Button.new()
	_q60.name = "DismissButton"
	_q60.text = "X"
	_q60.tooltip_text = "Dismiss update notification"
	_q60.custom_minimum_size = Vector2(24, 24)
	_q60.flat = true
	_q60.pressed.connect(_u12)
	_z5.add_child(_q60)

	_b32.add_child(_z5)

	var _u9 = get_node_or_null("MarginContainer/TabContainer/Chat")
	if _u9:
		var _u54 = _u9.get_child(0) if _u9.get_child_count() > 0 else null
		if _u54 and _u54 is VBoxContainer:
			_u54.add_child(_b32)
			_u54.move_child(_b32, 0)  
		else:
			_u9.add_child(_b32)
	else:
		add_child(_b32)

func _f32(_r35: String, _d38: String) -> void:
	if _p95:
		return

	if not _b32:
		_h25()

	var _c29 = _b32.find_child("_m21", true)
	if _c29:
		_c29.text = "Update Available: v%s (you have v%s)" % [_r35, _d38]

	_b32.visible = true

func _u12() -> void:
	_p95 = true
	if _b32:
		_b32.visible = false

func _c74(_v57: Dictionary) -> void:
	var _m37 = _v57.get("tier", "Unknown")

	if _d12:
		var _n98 = _d12.text
		if "API Key Loaded" in _n98:
			if _a8 and _a8._e2():
				var env = _a8._f35()
				_d12.text = "API Key Loaded (%s) - %s Tier" % [env.capitalize(), _m37]
			else:
				_d12.text = "API Key Loaded - %s Tier" % _m37

	_c38()

func _c38() -> void:
	if _y58:
		return  

	if not _d12 or not _a8:
		return

	_y58 = Button.new()
	_y58.text = "↻"  
	_y58.tooltip_text = "Refresh tier info"
	_y58.flat = true
	_y58.custom_minimum_size = Vector2(24, 24)
	_y58.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	_a79(_y58)

	var parent = _d12.get_parent()
	if parent:
		var _k90 = _d12.get_index()
		parent.add_child(_y58)
		parent.move_child(_y58, _k90 + 1)

	_y58.pressed.connect(_y56)

func _y56() -> void:
	if _a8:
		_a8._q38()
func _j78(model: String) -> String:
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

func _i100() -> _e46:
	var _z55 = find_child("_e46", true)
	if _z55 and _z55 is _e46:
		return _z55

	var _s74 = preload("res://addons/gdsense/scenes/_q55.tscn")
	if _s74:
		_z55 = _s74.instantiate()

		if _i89:
			var _t15 = _i89.get_editor_interface()
			if _t15:
				_z55._k94(_t15)
		add_child(_z55)

		_z55.z_index = 1000
		return _z55

	return null

func _t51():
	if not _r40:
		return

	_s59()
	_e7()
	_w43()

func _s59():
	if not _r40 or not _c70:
		return

	var recent_chats = _r40._v10()

	_c70.clear()
	_a18 = -1

	for _j91 in recent_chats:
		var _j4 = _j91._s72()
		var timestamp = _j91._s57()
		var _k13 = "%s - %s" % [_j4, timestamp]

		var index = _c70.add_item(_k13)
		_c70.set_item_metadata(index, _j91.timestamp)
		_c70.set_item_tooltip(index, _j91._d86(80))

	_h37()
	_j17()

func _e7():
	if not _r40 or not _r26:
		return

	var favorite_chats = _r40._p80()

	_r26.clear()
	_l55 = -1

	for _j91 in favorite_chats:
		var _j4 = _j91._s72()
		var timestamp = _j91._s57()
		var _k13 = "★ %s - %s" % [_j4, timestamp]

		var index = _r26.add_item(_k13)
		_r26.set_item_metadata(index, _j91.timestamp)
		_r26.set_item_tooltip(index, _j91._d86(80))

	_i19()
	_j17()

func _w43():
	if not _r40 or not _n100:
		return

	var _n7 = _r40._v10().size()
	var _f69 = _r40._p80().size()

	_n100.text = "Recent: %d | Favorites: %d" % [_n7, _f69]

	var font_color = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_n100.add_theme_color_override("font_color", font_color)

func _s98(index: int):
	if index < 0 or not _r40:
		return

	_a18 = index
	var timestamp = _c70.get_item_metadata(index)
	var _j91 = _r40._d25(timestamp)

	if _j91:
		_v13(_j91)

	_j17()

func _k95(index: int):
	if index < 0 or not _r40:
		return

	_l55 = index
	var timestamp = _r26.get_item_metadata(index)
	var _j91 = _r40._d25(timestamp)

	if _j91:
		_h44(_j91)

	_j17()

func _v13(_j91: _f28._x51):
	if not _j91 or not _w32 or not _d87 or not _a93:
		return

	var _l15 = _j91._p47()
	_w32.text = "%s - %s (%d exchange%s)" % [
		_j91._s72(),
		_j91._s57(),
		_l15,
		"s" if _l15 != 1 else ""
	]

	_d87.bbcode_enabled = true
	_d87.text = _z27(_j91)

	var _u62 = _j91._q17 if not _j91._q17.is_empty() else "Unknown"
	_a93.text = "[Model: %s]\n[Session ID: %s]" % [_u62, _j91.session_id]

func _h44(_j91: _f28._x51):
	if not _j91 or not _v74 or not _w52 or not _g36:
		return

	var _l15 = _j91._p47()
	_v74.text = "%s - %s (%d exchange%s)" % [
		_j91._s72(),
		_j91._s57(),
		_l15,
		"s" if _l15 != 1 else ""
	]

	_w52.bbcode_enabled = true
	_w52.text = _z27(_j91)

	var _u62 = _j91._q17 if not _j91._q17.is_empty() else "Unknown"
	_g36.text = "[Model: %s]\n[Session ID: %s]" % [_u62, _j91.session_id]

func _z27(_j91: _f28._x51) -> String:
	var _d67 = ""
	
	for _b29 in _j91.exchanges:
		if not _b29 is Dictionary:
			continue
			
		var _u49 = _b29.get("user_message", "")
		
		if _u49.begins_with("@explain"):
			var _j11 = _u49.find("\n")
			if _j11 != -1:
				_u49 = _u49.substr(0, _j11) + " (code attached)"
		
		var _o95 = _c85.to_html()
		_d67 += "[b][color=#%s]You:[/color][/b]\n" % _o95
		_d67 += _u1(_u49) + "\n\n"
		
		var _o91 = _b29.get("ai_response", "")
		var _n6 = _k9.to_html()
		_d67 += "[b][color=#%s]GDSense:[/color][/b]\n" % _n6
		
		var _b75 = _o91.split("```")

		var _b86 = get_theme_color("base_color", "Editor")
		var _u39 = _b86.darkened(0.2) if _b86.get_luminance() > 0.5 else _b86.lightened(0.1)
		var _w24 = _u39.to_html()
		
		for i in range(_b75.size()):
			var _n80 = _b75[i]
			if i % 2 == 0:
				_d67 += _u1(_n80)
			else:
				var _y82 = _n80.find("\n")
				var _k41 = _n80
				if _y82 != -1:
					_k41 = _n80.substr(_y82 + 1)
				
				var _x87 = _r67(_k41)

				_d67 += "\n[bgcolor=#%s]%s[/bgcolor]\n" % [_w24, _x87]
		
		_d67 += "\n\n"
		
		_d67 += "[color=#666666]────────────────────────────────[/color]\n\n"
		
	return _d67

func _h37():
	if _w32:
		_w32.text = "Select a chat to preview"
	if _d87:
		_d87.text = "Select a chat to view"
	if _a93:
		_a93.text = "Select a chat to view"

func _i19():
	if _v74:
		_v74.text = "Select a favorite to preview"
	if _w52:
		_w52.text = "Select a favorite chat to view"
	if _g36:
		_g36.text = "Select a favorite chat to view"

func _u1(text: String) -> String:
	var _q95 = text
	_q95 = _q95.replace("[", "\\[")
	_q95 = _q95.replace("]", "\\]")
	return _q95

func _j17():
	var _g17 = _a18 >= 0
	if _u84:
		_u84.disabled = not _g17
	if _n64:
		_n64.disabled = not _g17
	if _p19:
		_p19.disabled = not _g17
	if _q66:
		_q66.disabled = not _g17

	var _f10 = _l55 >= 0
	if _a83:
		_a83.disabled = not _f10
	if _d74:
		_d74.disabled = not _f10
	if _b47:
		_b47.disabled = not _f10
	if _q62:
		_q62.disabled = not _f10

func _k28():
	if _a18 < 0 or not _r40:
		return

	var timestamp = _c70.get_item_metadata(_a18)
	var _j91 = _r40._d25(timestamp)

	if _j91:
		_o84(_j91)

func _t55():
	if _a18 < 0 or not _r40:
		return

	var timestamp = _c70.get_item_metadata(_a18)

	if _r40._b34(timestamp):
		_t51()

func _i37():
	if _a18 < 0 or not _r40:
		return

	var timestamp = _c70.get_item_metadata(_a18)
	var _j91 = _r40._d25(timestamp)

	if _j91:
		_w6 = timestamp
		_e96 = false
		_r69.text = _j91.custom_name
		_y45.popup_centered()

func _y49():
	if _a18 < 0 or not _r40:
		return

	var timestamp = _c70.get_item_metadata(_a18)

	if _r40._s48(timestamp):
		_t51()

func _t6():
	if _l55 < 0 or not _r40:
		return

	var timestamp = _r26.get_item_metadata(_l55)
	var _j91 = _r40._d25(timestamp)

	if _j91:
		_o84(_j91)

func _z19():
	if _l55 < 0 or not _r40:
		return

	var timestamp = _r26.get_item_metadata(_l55)

	if _r40._o39(timestamp):
		_t51()

func _c73():
	if _l55 < 0 or not _r40:
		return

	var timestamp = _r26.get_item_metadata(_l55)
	var _j91 = _r40._d25(timestamp)

	if _j91:
		_w6 = timestamp
		_e96 = true
		_r69.text = _j91.custom_name
		_y45.popup_centered()

func _d69():
	if _l55 < 0 or not _r40:
		return

	var timestamp = _r26.get_item_metadata(_l55)

	if _r40._s48(timestamp):
		_t51()

func _l28():
	if not _r40 or _w6.is_empty():
		return

	var _q21 = _r69.text.strip_edges()

	if _r40._u72(_w6, _q21):
		_t51()

	_w6 = ""
	_e96 = false

func _k62():
	if not _r40:
		return

	_r40._x26()
	_r40._p31()
	_t51()

func _z33():
	if not _r40:
		return

	_r40._l86()
	_r40._p31()
	_t51()

func _f52():
	var _f6: _f28._x51 = null

	if _c70 and _c70.get_selected_items().size() > 0:
		var _f78 = _c70.get_selected_items()[0]
		var recent_chats = _r40._v10()
		if _f78 < recent_chats.size():
			_f6 = recent_chats[_f78]

	elif _r26 and _r26.get_selected_items().size() > 0:
		var _f78 = _r26.get_selected_items()[0]
		var favorite_chats = _r40._p80()
		if _f78 < favorite_chats.size():
			_f6 = favorite_chats[_f78]

	if not _f6:
		_q92("Please select a chat session to export", Color(1, 0.7, 0.3))
		return

	var filename = "gdsense_session_%s.json" % _f6.session_id
	_s44.current_file = filename
	_s44.current_path = "user://" + filename
	_s44.popup_centered()

func _y13(path: String):
	var _f6: _f28._x51 = null

	if _c70 and _c70.get_selected_items().size() > 0:
		var _f78 = _c70.get_selected_items()[0]
		var recent_chats = _r40._v10()
		if _f78 < recent_chats.size():
			_f6 = recent_chats[_f78]
	elif _r26 and _r26.get_selected_items().size() > 0:
		var _f78 = _r26.get_selected_items()[0]
		var favorite_chats = _r40._p80()
		if _f78 < favorite_chats.size():
			_f6 = favorite_chats[_f78]

	if not _f6:
		push_error("[GDSense] Failed to export: No session selected")
		return

	var _p82 = {
		"format_version": "1.0",
		"exported_at": Time.get_datetime_string_from_system(),
		"session": _r40._z4(_f6)
	}

	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		var _r87 = JSON.stringify(_p82, "\t")
		file.store_string(_r87)
		file.close()

		_q92("Session exported successfully", Color(0.3, 1, 0.5))

	else:
		push_error("[GDSense] Failed to write export file: %s" % path)
		_q92("Export failed: Could not write file", Color(1, 0.3, 0.3))

func _z99():
	_o54.current_path = "user://"
	_o54.popup_centered()

func _b93(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("[GDSense] Failed to open import file: %s" % path)
		_q92("Import failed: Could not open file", Color(1, 0.3, 0.3))
		return

	var _r87 = file.get_as_text()
	file.close()

	var json = JSON.new()
	var _d58 = json.parse(_r87)

	if _d58 != OK:
		push_error("[GDSense] Failed to parse import file: %s" % json.get_error_message())
		_q92("Import failed: Invalid JSON format", Color(1, 0.3, 0.3))
		return

	var _o86 = json.data

	if not _o86 is Dictionary:
		push_error("[GDSense] Import data is not a Dictionary")
		_q92("Import failed: Invalid data structure", Color(1, 0.3, 0.3))
		return

	if not _o86.has("format_version"):
		push_error("[GDSense] Import file missing format_version")
		_q92("Import failed: Missing format version", Color(1, 0.3, 0.3))
		return

	if _o86["format_version"] != "1.0":
		push_error("[GDSense] Unsupported format version: %s" % _o86["format_version"])
		_q92("Import failed: Unsupported format version", Color(1, 0.3, 0.3))
		return

	if not _o86.has("session"):
		push_error("[GDSense] Import file missing session data")
		_q92("Import failed: Missing session data", Color(1, 0.3, 0.3))
		return

	var _c15 = _o86["session"]
	if not _c15 is Dictionary:
		push_error("[GDSense] Session data is not a Dictionary")
		_q92("Import failed: Invalid session format", Color(1, 0.3, 0.3))
		return

	var _o41 = ["exchanges", "timestamp", "session_id"]
	for _b56 in _o41:
		if not _c15.has(_b56):
			push_error("[GDSense] Session missing required field: %s" % _b56)
			_q92("Import failed: Incomplete session data", Color(1, 0.3, 0.3))
			return

	if not _c15["exchanges"] is Array:
		push_error("[GDSense] Session exchanges is not an Array")
		_q92("Import failed: Invalid exchanges format", Color(1, 0.3, 0.3))
		return

	if _c15["exchanges"].is_empty():
		push_error("[GDSense] Session has no exchanges")
		_q92("Import failed: Empty session", Color(1, 0.3, 0.3))
		return

	for _b29 in _c15["exchanges"]:
		if not _b29 is Dictionary:
			push_error("[GDSense] Invalid exchange format")
			_q92("Import failed: Invalid exchange data", Color(1, 0.3, 0.3))
			return

		if not _b29.has("user_message") or not _b29.has("ai_response"):
			push_error("[GDSense] Exchange missing user_message or ai_response")
			_q92("Import failed: Incomplete exchange", Color(1, 0.3, 0.3))
			return

		if _b29["user_message"].length() > 100000 or _b29["ai_response"].length() > 500000:
			push_error("[GDSense] Exchange messages too long (possible attack)")
			_q92("Import failed: Messages exceed size limits", Color(1, 0.3, 0.3))
			return

		if _b29.has("enhanced_user_message") and _b29["enhanced_user_message"].length() > 200000:
			push_error("[GDSense] Enhanced message too long (possible attack)")
			_q92("Import failed: Messages exceed size limits", Color(1, 0.3, 0.3))
			return

	var _e64 = _r40._d25(_c15["timestamp"])
	if _e64:
		_q92("Warning: Session may already exist", Color(1, 0.7, 0.3))

	var _s79 = _r40._r53(_c15)
	if not _s79:
		push_error("[GDSense] Failed to convert imported data to ChatEntry")
		_q92("Import failed: Could not create session", Color(1, 0.3, 0.3))
		return

	_r40._x85.push_front(_s79)

	while _r40._x85.size() > _f28._e88:
		_r40._x85.pop_back()

	_r40._p31()

	_t51()

	_q92("Session imported successfully (%d exchanges)" % _s79._p47(), Color(0.3, 1, 0.5))

func _q92(message: String, color: Color):
	if color.r > color.g and color.r > color.b:
		pass

	else:
		pass

func _u7(message: String) -> String:
	var _g34 = _f28._x51._h52(message)
	if _g34 != message and OS.is_debug_build():
		pass

	return _g34

func _o84(_j91: _f28._x51):
	if not _j91:
		return

	_q41.clear()
	_c93()
	for _w15 in _w88.get_children():
		_w15.queue_free()
	
	var _e5 = _j91._q74()
	var _z38 = _j91._s88()
	_c65 = _e5 if _e5 else {}

	if _z38 and not _z38.is_empty():
		_s2 = _z38
	else:
		_s2.clear()  
	_y68()

	for _b29 in _j91.exchanges:
		if not _b29 is Dictionary:
			continue
		if not _b29.has("user_message") or not _b29.has("ai_response"):
			continue

		var _h63 = _u7(_b29["user_message"])

		if _h63.begins_with("@explain"):
			var _j11 = _h63.find("\n")
			if _j11 != -1:
				_h63 = _h63.substr(0, _j11) + " (code attached)"

		_h55(_h63)
		_n28(_b29["ai_response"], [])

		var _n40 = _b29.get("enhanced_user_message", _b29["user_message"])

		var _n56 = _u7(_b29["user_message"])

		_q41.append({"role": "user", "content": _n40, "original_content": _n56})
		var _o91 = {"role": "agent", "content": _b29["ai_response"]}

		if _b29.has("thought_signature") and not _b29["thought_signature"].is_empty():
			_o91["thought_signature"] = _b29["thought_signature"]
		_q41.append(_o91)

	if _n32:
		_n32.current_tab = 0

	_k35.call_deferred()

func _a58():
	var _h36 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	
	var _m84 = func(_u58: Node):
		if not _u58: return
		for _w15 in _u58.get_children():
			if _w15 is Label:
				if "Full Conversation" in _w15.text or "Session Info" in _w15.text:
					_w15.add_theme_color_override("font_color", _h36)
	
	if _d87:
		_m84.call(_d87.get_parent())
		
	if _w52:
		_m84.call(_w52.get_parent())

func _q13():
	_c91()
	_a58()
	_r55()
	
	if _r40:
		if _a18 >= 0:
			_s98(_a18)
		if _l55 >= 0:
			_k95(_l55)

func _r55():
	var _f71 = get_node_or_null("MarginContainer/TabContainer/Settings/_q8/VBoxContainer")
	if not _f71: return

	var _p96 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	var _n22 = Color(_p96, 0.6)

	var _n29 = func(node: Node, _y47: Callable):
		if node is Label:
			if node.has_meta("secondary"):
				node.add_theme_color_override("font_color", _n22)
			else:
				node.add_theme_color_override("font_color", _p96)

		for _w15 in node.get_children():
			_y47.call(_w15, _y47)

	_n29.call(_f71, _n29)

func _t87() -> void:
	_n65 = _r100.new()
	_n65.initialize(self, _a8)
	_n65._z89.connect(_b73)
	_n65._t76.connect(_k50)
	_n65._p61.connect(_s80)
	_n65._x69.connect(_g99)
	_n65._l88.connect(_i26)
	_n65._r83.connect(_j23)
	_n65._s92.connect(_e92)
	_n65._h40.connect(_f41)

	_h42 = _i95.new()
	_h42.initialize(_t15)

	_j20()

func _j20() -> void:
	_c8 = VBoxContainer.new()
	_c8.name = "AgentUIContainer"
	_c8.visible = false
	_c8.add_theme_constant_override("separation", 4)

	_y65 = Label.new()
	_y65.text = "Agent: Initializing..."
	_y65.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_c8.add_child(_y65)

	_k36 = ProgressBar.new()
	_k36.min_value = 0
	_k36.max_value = 100
	_k36.value = 0
	_k36.show_percentage = false
	_k36.custom_minimum_size = Vector2(0, 8)
	_c8.add_child(_k36)

	var _u9 = get_node_or_null("MarginContainer/TabContainer/Chat")
	if _u9:
		var _u54 = _u9.get_child(0) if _u9.get_child_count() > 0 else null
		if _u54 and _u54 is VBoxContainer:
			var _r88 = -1
			for i in range(_u54.get_child_count()):
				var _w15 = _u54.get_child(i)
				if _w15.name == "InputContainer" or (_w15 is HBoxContainer and _w15.get_node_or_null("_e36") != null):
					_r88 = i
					break

			if _r88 >= 0:
				_u54.add_child(_c8)
				_u54.move_child(_c8, _r88)
			else:
				_u54.add_child(_c8)
		else:
			add_child(_c8)
	else:
		add_child(_c8)

func _k98() -> void:
	_x32 = true

	if _p14 and _p14.item_count > _r45 and _p14.selected != _r45:
		_p14.selected = _r45

	if _b77:
		_b77.visible = false
	if _m94:
		_m94.visible = false

	if _v86:
		_v86.visible = true

	_z72.placeholder_text = "[Agent Mode] Describe your task..."

	_k78("Agent mode enabled. Describe your task and press Enter to start.")

func _w78() -> void:
	_x32 = false

	_j45.clear()
	_r17 = false

func _g39() -> void:
	if _c8:
		_c8.visible = true
	if _k36:
		_k36.value = 0
	if _y65:
		_y65.text = "Agent: Starting..."

	_n2()

func _f2() -> void:
	if _c8:
		_c8.visible = false

func _n2() -> void:
	_y12()  

	_c72 = HBoxContainer.new()
	_c72.name = "AgentCancelContainer"
	_c72.alignment = BoxContainer.ALIGNMENT_CENTER

	_l74 = Button.new()
	_l74.text = "Cancel Agent"
	_l74.pressed.connect(_r93)
	_c72.add_child(_l74)

	var _u9 = get_node_or_null("MarginContainer/TabContainer/Chat")
	if _u9:
		var _u54 = _u9.get_child(0) if _u9.get_child_count() > 0 else null
		if _u54 and _u54 is VBoxContainer:
			var _r88 = -1
			for i in range(_u54.get_child_count()):
				var _w15 = _u54.get_child(i)
				if _w15.name == "InputContainer" or (_w15 is HBoxContainer and _w15.get_node_or_null("_e36") != null):
					_r88 = i
					break

			if _r88 >= 0:
				_u54.add_child(_c72)
				_u54.move_child(_c72, _r88)
			else:
				_u54.add_child(_c72)
		else:
			add_child(_c72)
	else:
		add_child(_c72)

func _y12() -> void:
	if _c72 and is_instance_valid(_c72):
		_c72.queue_free()
		_c72 = null
		_l74 = null

func _i99() -> void:
	_o56()  

	_y30 = HBoxContainer.new()
	_y30.name = "AgentForceResetContainer"
	_y30.alignment = BoxContainer.ALIGNMENT_CENTER
	_y30.add_theme_constant_override("separation", 8)

	var _a45 = Button.new()
	_a45.text = "Reset Agent"
	_a45.tooltip_text = "Force reset all agent state and start fresh"
	_a45.pressed.connect(_h13)
	_y30.add_child(_a45)

	var _u9 = get_node_or_null("MarginContainer/TabContainer/Chat")
	if _u9:
		var _u54 = _u9.get_child(0) if _u9.get_child_count() > 0 else null
		if _u54 and _u54 is VBoxContainer:
			var _r88 = -1
			for i in range(_u54.get_child_count()):
				var _w15 = _u54.get_child(i)
				if _w15.name == "InputContainer" or (_w15 is HBoxContainer and _w15.get_node_or_null("_e36") != null):
					_r88 = i
					break

			if _r88 >= 0:
				_u54.add_child(_y30)
				_u54.move_child(_y30, _r88)
			else:
				_u54.add_child(_y30)
		else:
			add_child(_y30)
	else:
		add_child(_y30)

func _o56() -> void:
	if _y30 and is_instance_valid(_y30):
		_y30.queue_free()
		_y30 = null

func _h13() -> void:
	if _n65 and _n65.is_active():
		_n65._h68()

	_f2()
	_y12()
	_x22()
	_o56()
	_w78()
	_m47()

	_j45.clear()
	_r17 = false

	_k78("Agent state reset. You can start a new task.", false)

func _k78(text: String, _v44: bool = false) -> void:
	var _j5 = PanelContainer.new()
	_j5.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_j5.add_theme_constant_override("margin_bottom", _r5.message_gap)

	if not _e91:
		_c91()
	_j5.add_theme_stylebox_override("panel", _e91)

	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.selection_enabled = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.fit_content = true
	label.scroll_active = false
	label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())

	var _m44 = Color.RED if _v44 else _k9
	label.add_theme_color_override("default_color", _m44)
	label.text = "[b][Agent][/b] " + _u1(text)

	_j5.add_child(label)
	_w88.add_child(_j5)
	_k35.call_deferred()

func _n92(_o96: String, details: Array, _v44: bool = false) -> void:
	var _j5 = PanelContainer.new()
	_j5.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_j5.add_theme_constant_override("margin_bottom", _r5.message_gap)

	if not _e91:
		_c91()
	_j5.add_theme_stylebox_override("panel", _e91)

	var _u54 = VBoxContainer.new()
	_u54.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var _l89 = HBoxContainer.new()
	_l89.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var _w37 = Button.new()
	_w37.flat = true
	_w37.text = "▶"  
	_w37.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_w37.tooltip_text = "Click to expand/collapse"

	_a79(_w37)
	_l89.add_child(_w37)

	var _x34 = RichTextLabel.new()
	_x34.bbcode_enabled = true
	_x34.selection_enabled = true
	_x34.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_x34.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_x34.fit_content = true
	_x34.scroll_active = false
	_x34.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var _m44 = Color.RED if _v44 else _k9
	_x34.add_theme_color_override("default_color", _m44)
	_x34.text = "[b][Agent][/b] " + _u1(_o96)
	_l89.add_child(_x34)

	_u54.add_child(_l89)

	var _e51 = VBoxContainer.new()
	_e51.visible = false
	_e51.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_e51.add_theme_constant_override("separation", 4)

	var _t95 = MarginContainer.new()
	var indent_size = _c77() * 2  
	_t95.add_theme_constant_override("margin_left", indent_size)
	_t95.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var _z90 = VBoxContainer.new()
	_z90.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	for _c53 in details:
		var _p91 = Label.new()
		_p91.text = _c53
		_p91.add_theme_color_override("font_color", _m44.darkened(0.15))

		_a79(_p91)
		_z90.add_child(_p91)

	_t95.add_child(_z90)
	_e51.add_child(_t95)
	_u54.add_child(_e51)

	_w37.pressed.connect(func():
		_e51.visible = not _e51.visible
		_w37.text = "▼" if _e51.visible else "▶"
		_k35.call_deferred()
	)

	_j5.add_child(_u54)
	_w88.add_child(_j5)
	_k35.call_deferred()

func _a79(_i43: Control) -> void:
	if _i89:
		var _t15 = _i89.get_editor_interface()
		if _t15:
			var theme = _t15.get_editor_theme()
			if theme:
				var _o31 = theme.get_font("main", "EditorFonts")
				if _o31:
					_i43.add_theme_font_override("font", _o31)
				var _z95 = theme.get_font_size("main_size", "EditorFonts")
				if _z95 > 0:
					_i43.add_theme_font_size_override("font_size", _z95)

func _c77() -> int:
	if _i89:
		var _t15 = _i89.get_editor_interface()
		if _t15:
			var theme = _t15.get_editor_theme()
			if theme:
				var _z95 = theme.get_font_size("main_size", "EditorFonts")
				if _z95 > 0:
					return _z95
	return 14  

func _b73(session_id: String) -> void:
	_k78("Agent session started. Analyzing your request...")
func _k50(status: Dictionary) -> void:
	var progress = status.get("progress_percent", 0)
	var _d100 = status.get("status_message", "Processing...")

	if _d100 == null:
		_d100 = "Processing..."

	if _k36:
		_k36.value = progress
	if _y65:
		_y65.text = "Agent: " + _d100

	if status.has("tier"):
		var _m37 = status.get("tier", "")
		if _m37 is String and not _m37.is_empty() and _a8:
			_a8._c41(_m37)

func _s80(_n46: Array) -> void:
	if _n46.is_empty():
		return

	var _r66: Array = []
	var _j68: Array = []

	for _n33 in _n46:
		var _d89 = _n33.get("tool_name", "")
		var _c87 = _h42._c87(_d89)
		if _c87:
			_j68.append(_n33)
		else:
			_r66.append(_n33)

	for _n33 in _r66:
		var _d89 = _n33.get("tool_name", "")
		var _x7 = _n33.get("tool_call_id", "")
		var _z42 = _n33.get("parameters", {})
		if _z42 == null:
			_z42 = {}

		var _k3 = _h42._o81(_d89, _z42)
		_n65._p7(_x7, true, _k3)
		_i10(_d89, _z42, _k3)

	for _n33 in _j68:
		_j45.append(_n33)

	if not _r17 and _j45.size() > 0:
		_t57()

func _t57() -> void:
	if _j45.is_empty():
		_r17 = false
		return

	_r17 = true
	var _n33 = _j45.pop_front()
	var _d89 = _n33.get("tool_name", "")
	var _x7 = _n33.get("tool_call_id", "")

	var _i52 = _c43.new()
	_i52._k94(_t15)
	_i52._j38(_n33)
	_i52._a66.connect(_v66.bind(_x7))
	_i52._e21.connect(_j66.bind(_x7))
	add_child(_i52)
	_i52.popup_centered()

func _v66(_n33: Dictionary, _r96: Dictionary, _x7: String) -> void:
	var _d89 = _n33.get("tool_name", "")
	if _d89 == null:
		_d89 = ""
	var _z42 = _n33.get("parameters", {})
	if _z42 == null:
		_z42 = {}
	var _k3 = _h42._o81(_d89, _z42)
	_n65._p7(_x7, true, _k3)
	_i10(_d89, _z42, _k3)

	_t57()

func _j66(_n33: Dictionary, _o23: String, _x7: String) -> void:
	var _d89 = _n33.get("tool_name", "")
	if _d89 == null:
		_d89 = ""
	var _z42 = _n33.get("parameters", {})
	if _z42 == null:
		_z42 = {}
	_n65._p7(_x7, false, {}, _o23)

	var path = _z42.get("path", "")
	if path == null:
		path = ""
	if not path.is_empty():
		_k78("Rejected " + _d89 + ": " + path)
	else:
		_k78("Rejected: " + _d89)

	_t57()

func _g99(message: String) -> void:
	_n28(message, [])

	_k78("Tip: Reopen modified scenes or reload the project to see changes")
	_f2()
	_y12()  
	_x22()
	_o56()  
	_w78()
	_m47()

func _i26(error: String) -> void:
	_k78("Agent failed: " + error, true)
	_f2()

	_i99()
	_x22()

func _j23() -> void:
	_k78("Agent cancelled")
	_f2()
	_y12()  
	_x22()
	_o56()  
	_w78()
	_m47()

func _e92(session_id: String, message: String) -> void:
	var _f98 = message + " You can continue to allow more processing."
	_k78(_f98, true)
	_e55()
	_f2()
	_y12()  

func _f41(message: String, _k49: String) -> void:
	if message.is_empty() and _k49.is_empty():
		return

	if not message.is_empty():
		_n28(message, [])

	if not _k49.is_empty():
		_b27(_k49)

func _b27(_k49: String) -> void:
	var _j5 = PanelContainer.new()
	_j5.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_j5.add_theme_constant_override("margin_bottom", _r5.message_gap)

	if not _e91:
		_c91()
	_j5.add_theme_stylebox_override("panel", _e91)

	var _u54 = VBoxContainer.new()
	_u54.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var _l89 = HBoxContainer.new()
	_l89.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var _w37 = Button.new()
	_w37.flat = true
	_w37.text = ">"  
	_w37.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_w37.tooltip_text = "Click to expand/collapse reasoning"

	_a79(_w37)
	_l89.add_child(_w37)

	var _x34 = RichTextLabel.new()
	_x34.bbcode_enabled = true
	_x34.selection_enabled = true
	_x34.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_x34.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_x34.fit_content = true
	_x34.scroll_active = false
	_x34.add_theme_stylebox_override("normal", StyleBoxEmpty.new())

	var _b59 = _k9.darkened(0.2)
	_x34.add_theme_color_override("default_color", _b59)
	_x34.text = "[i]View reasoning[/i]"
	_l89.add_child(_x34)

	_u54.add_child(_l89)

	var _e51 = VBoxContainer.new()
	_e51.visible = false
	_e51.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_e51.add_theme_constant_override("separation", 4)

	var _t95 = MarginContainer.new()
	var indent_size = _c77() * 2  
	_t95.add_theme_constant_override("margin_left", indent_size)
	_t95.add_theme_constant_override("margin_top", 4)
	_t95.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var _m31 = RichTextLabel.new()
	_m31.bbcode_enabled = true
	_m31.selection_enabled = true
	_m31.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_m31.fit_content = true
	_m31.scroll_active = false
	_m31.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_m31.add_theme_color_override("default_color", _b59)

	_m31.text = _u1(_k49)

	_t95.add_child(_m31)
	_e51.add_child(_t95)
	_u54.add_child(_e51)

	_w37.pressed.connect(func():
		_e51.visible = not _e51.visible
		_w37.text = "v" if _e51.visible else ">"
		_k35.call_deferred()
	)

	_j5.add_child(_u54)
	_w88.add_child(_j5)
	_k35.call_deferred()

func _e55() -> void:
	_x22()  

	_r20 = HBoxContainer.new()
	_r20.name = "AgentContinueContainer"
	_r20.alignment = BoxContainer.ALIGNMENT_CENTER
	_r20.add_theme_constant_override("separation", 8)

	var _y10 = Button.new()
	_y10.text = "Continue Session"
	_y10.pressed.connect(_d21)
	_r20.add_child(_y10)

	var _q60 = Button.new()
	_q60.text = "Start New Task"
	_q60.pressed.connect(_f22)
	_r20.add_child(_q60)

	var _u9 = get_node_or_null("MarginContainer/TabContainer/Chat")
	if _u9:
		var _u54 = _u9.get_child(0) if _u9.get_child_count() > 0 else null
		if _u54 and _u54 is VBoxContainer:
			var _r88 = -1
			for i in range(_u54.get_child_count()):
				var _w15 = _u54.get_child(i)
				if _w15.name == "InputContainer" or (_w15 is HBoxContainer and _w15.get_node_or_null("_e36") != null):
					_r88 = i
					break

			if _r88 >= 0:
				_u54.add_child(_r20)
				_u54.move_child(_r20, _r88)
			else:
				_u54.add_child(_r20)
		else:
			add_child(_r20)
	else:
		add_child(_r20)

func _d21() -> void:
	_x22()
	_g39()
	if _n65:
		_n65._b46()

func _f22() -> void:
	_x22()
	_o56()  
	if _n65:
		_n65._u88()
	_w78()
	_m47()

func _x22() -> void:
	if _r20 and is_instance_valid(_r20):
		_r20.queue_free()
		_r20 = null

func _r93() -> void:
	if _n65 and _n65.is_active():
		_n65._h68()

func _u86(_d89: String, _z42: Dictionary, _k3: Dictionary) -> Dictionary:
	var success = _k3.get("success", false)
	var _m90 = "✓ " if success else "✗ "
	var details: Array = []

	match _d89:
		"read_file":
			var path = _z42.get("path", "unknown")
			if success:
				var content = _k3.get("content", "")
				var _e63 = content.count("\n") + 1 if not content.is_empty() else 0
				return {"summary": _m90 + "Read file: " + path + " (" + str(_e63) + " lines)", "details": [], "is_error": false}
			else:
				return {"summary": _m90 + "Failed to read: " + path, "details": [], "is_error": true}

		"list_files":
			var path = _z42.get("path", "res://")
			if success:
				var _i67 = _k3.get("files", [])
				var _i98 = _k3.get("directories", [])
				var _v73 = _i67.size() if _i67 is Array else 0
				var _j90 = _i98.size() if _i98 is Array else 0

				for _s45 in _i98:
					details.append("📁 " + str(_s45) + "/")
				for _m48 in _i67:
					details.append("📄 " + str(_m48))
				return {"summary": _m90 + "Listed " + path + " (" + str(_v73) + " files, " + str(_j90) + " dirs)", "details": details, "is_error": false}
			else:
				return {"summary": _m90 + "Failed to list: " + path, "details": [], "is_error": true}

		"get_project_info":
			if success:
				var _d34 = _k3.get("project_name", "Unknown")
				var _y92 = _k3.get("godot_version", "")

				details.append("Project: " + str(_d34))
				details.append("Godot: " + str(_y92))
				if _k3.has("main_scene"):
					details.append("Main Scene: " + str(_k3.get("main_scene")))
				return {"summary": _m90 + "Project: " + _d34 + " (Godot " + _y92 + ")", "details": details, "is_error": false}
			else:
				return {"summary": _m90 + "Failed to get project info", "details": [], "is_error": true}

		"run_project":
			if success:
				return {"summary": _m90 + "Running project in debug mode", "details": [], "is_error": false}
			else:
				return {"summary": _m90 + "Failed to run project", "details": [], "is_error": true}

		"stop_project":
			if success:
				return {"summary": _m90 + "Stopped project", "details": [], "is_error": false}
			else:
				return {"summary": _m90 + "Failed to stop project", "details": [], "is_error": true}

		"create_file":
			var path = _z42.get("path", "unknown")
			if success:
				return {"summary": _m90 + "Created: " + path, "details": [], "is_error": false}
			else:
				var _p59 = _k3.get("error", "Unknown error")
				return {"summary": _m90 + "Failed to create " + path + ": " + _p59, "details": [], "is_error": true}

		"edit_file":
			var path = _z42.get("path", "unknown")
			if success:
				return {"summary": _m90 + "Modified: " + path, "details": [], "is_error": false}
			else:
				var _p59 = _k3.get("error", "Unknown error")
				return {"summary": _m90 + "Failed to edit " + path + ": " + _p59, "details": [], "is_error": true}

		"delete_file":
			var path = _z42.get("path", "unknown")
			if success:
				return {"summary": _m90 + "Deleted: " + path, "details": [], "is_error": false}
			else:
				var _p59 = _k3.get("error", "Unknown error")
				return {"summary": _m90 + "Failed to delete " + path + ": " + _p59, "details": [], "is_error": true}

		_:
			if success:
				return {"summary": _m90 + "Executed: " + _d89, "details": [], "is_error": false}
			else:
				return {"summary": _m90 + "Failed: " + _d89, "details": [], "is_error": true}

func _i10(_d89: String, _z42: Dictionary, _k3: Dictionary) -> void:
	var status = _u86(_d89, _z42, _k3)
	var _o96 = status.get("summary", "")
	var details = status.get("details", [])
	var _v44 = status.get("is_error", false)

	if details.size() > 0:
		_n92(_o96, details, _v44)
	else:
		_k78(_o96, _v44)

