@tool
extends Control

func _x34(type: String) -> Color:
	if _i86:
		var _f80 = _i86.get_editor_settings()
		if _f80:
			match type:
				"text_color": return _f80.get_setting("text_editor/theme/highlighting/text_color")
				"comment": return _f80.get_setting("text_editor/theme/highlighting/comment_color")
				"string": return _f80.get_setting("text_editor/theme/highlighting/string_color")
				"number": return _f80.get_setting("text_editor/theme/highlighting/number_color")
				"keyword": return _f80.get_setting("text_editor/theme/highlighting/keyword_color")
				"class": return _f80.get_setting("text_editor/theme/highlighting/base_type_color")
				"function": return _f80.get_setting("text_editor/theme/highlighting/function_color")
				"symbol": return _f80.get_setting("text_editor/theme/highlighting/symbol_color")
	
	match type:
		"comment": return Color.GRAY
		"string": return Color.ORANGE
		"number": return Color.SKY_BLUE
		"keyword": return Color.PALE_VIOLET_RED
		"class": return Color.LIGHT_GREEN
		"function": return Color.LIGHT_BLUE
		"symbol": return Color.WHITE
	return Color.WHITE

const _b45 = [
	"if", "elif", "else", "for", "while", "match", "break", "continue", "pass",
	"return", "class", "extends", "is", "as", "self", "super", "func", "signal",
	"const", "var", "static", "enum", "in", "not", "and", "or", "true", "false",
	"null", "export", "onready", "tool", "setget", "breakpoint", "preload", "yield",
	"assert", "remote", "sync", "master", "puppet"
]

const _l18 = [
	"public", "private", "protected", "internal", "static", "void", 
	"class", "interface", "namespace", "using", "new", "this", "base",
	"if", "else", "for", "foreach", "while", "do", "switch", "case",
	"return", "throw", "try", "catch", "finally", "async", "await",
	"var", "const", "readonly", "override", "virtual", "abstract",
	"int", "string", "bool", "float", "double", "decimal", "byte", "true", "false", "null"
]

func _u84():
	if not _i86:
		return
		
	var theme = _i86.get_editor_theme()
	if not theme:
		return

	var _m31 = theme.get_color("base_color", "Editor")
	var _h56 = theme.get_color("dark_color_2", "Editor")
	var _j73 = theme.get_color("contrast_color_1", "Editor")
	var font_color = theme.get_color("font_color", "Editor")
	var _g75 = theme.get_color("accent_color", "Editor")
	
	if not _w43:
		_q75()
	
	var _b73 = _m31.lerp(_g75, 0.1)

	if _m31.get_luminance() > 0.5:
		_b73 = _m31.darkened(0.05).lerp(_g75, 0.1)
		
	_w43.bg_color = _b73
	_w43.border_color = _g75.darkened(0.3)
	
	if _b73.get_luminance() > 0.5:
		_y16 = Color.BLACK
	else:
		_y16 = Color(0.9, 0.9, 0.9) 
	
	var _g98 = _h56
	
	_h2.bg_color = _g98
	_h2.border_color = _g98.lightened(0.05)
	
	_h73 = font_color
	
	var _i49 = _q42("normal", "TextEdit")
	if _i49 is StyleBoxFlat:
		_x93.bg_color = _i49.bg_color
		_x93.border_color = _i49.border_color
		_x93.border_width_left = _i49.border_width_left
		_x93.border_width_top = _i49.border_width_top
		_x93.border_width_right = _i49.border_width_right
		_x93.border_width_bottom = _i49.border_width_bottom
		_x93.corner_radius_top_left = _i49.corner_radius_top_left
		_x93.corner_radius_top_right = _i49.corner_radius_top_right
		_x93.corner_radius_bottom_right = _i49.corner_radius_bottom_right
		_x93.corner_radius_bottom_left = _i49.corner_radius_bottom_left
	else:
		_x93.bg_color = _m31
		_x93.border_color = _m31.lightened(0.1)
	
	_o67.bg_color = _h56
	_o67.border_color = _h56.lightened(0.1)
	
	_g100 = font_color
	
	_j72.bg_color = _h56.lightened(0.05)

func _s83(name: String, type: String = "Editor") -> Color:
	if _i86:
		var theme = _i86.get_editor_theme()
		if theme:
			return theme.get_color(name, type)
	return Color.GRAY 

func _q42(name: String, type: String = "Editor") -> StyleBox:
	if _i86:
		var theme = _i86.get_editor_theme()
		if theme:
			return theme.get_stylebox(name, type)
	return null

var _w43: StyleBoxFlat
var _h2: StyleBoxFlat
var _o67: StyleBoxFlat
var _j72: StyleBoxFlat
var _x93: StyleBoxFlat

var _y16: Color
var _h73: Color
var _g100: Color

const _t45 = {
	"message_gap": 16,
	"padding": 12,
	"code_padding": 10
}

func _q75():
	_w43 = StyleBoxFlat.new()
	_w43.corner_radius_top_left = 8
	_w43.corner_radius_top_right = 8
	_w43.corner_radius_bottom_left = 8
	_w43.corner_radius_bottom_right = 8
	_w43.content_margin_left = _t45.padding
	_w43.content_margin_right = _t45.padding
	_w43.content_margin_top = _t45.padding
	_w43.content_margin_bottom = _t45.padding
	_w43.border_width_bottom = 1
	_w43.border_width_top = 1
	_w43.border_width_left = 1
	_w43.border_width_right = 1

	_h2 = StyleBoxFlat.new()
	_h2.corner_radius_top_left = 8
	_h2.corner_radius_top_right = 8
	_h2.corner_radius_bottom_left = 8
	_h2.corner_radius_bottom_right = 8
	_h2.content_margin_left = _t45.padding
	_h2.content_margin_right = _t45.padding
	_h2.content_margin_top = _t45.padding
	_h2.content_margin_bottom = _t45.padding
	_h2.border_width_bottom = 1
	_h2.border_width_top = 1
	_h2.border_width_left = 1
	_h2.border_width_right = 1

	_o67 = StyleBoxFlat.new()
	_o67.corner_radius_top_left = 4
	_o67.corner_radius_top_right = 4
	_o67.corner_radius_bottom_left = 4
	_o67.corner_radius_bottom_right = 4
	_o67.border_width_bottom = 1
	_o67.border_width_top = 1
	_o67.border_width_left = 1
	_o67.border_width_right = 1
	_o67.border_width_left = 1
	_o67.border_width_right = 1

	_j72 = StyleBoxFlat.new()
	_j72.corner_radius_top_left = 6
	_j72.corner_radius_top_right = 6
	_j72.content_margin_left = 12
	_j72.content_margin_right = 12
	_j72.content_margin_top = 4
	_j72.content_margin_bottom = 4
	
	_x93 = StyleBoxFlat.new()
	_x93.bg_color = Color(0.1, 0.1, 0.1) 
	_x93.border_width_left = 1
	_x93.border_width_top = 1
	_x93.border_width_right = 1
	_x93.border_width_bottom = 1
	_x93.corner_radius_top_left = 4
	_x93.corner_radius_top_right = 4
	_x93.corner_radius_bottom_right = 4
	_x93.corner_radius_bottom_left = 4

const _h34 = {
	"gdscript": "GDScript",
	"csharp": "C#",
	"cs": "C#",
	"": "GDScript"  
}

const _h65 = {
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

const _o53 = {
	"1080p": {"width": 1920, "height": 1080, "scale": 1.0},  
	"1440p": {"width": 2560, "height": 1440, "scale": 1.15}, 
	"4k": {"width": 3840, "height": 2160, "scale": 1.5},     
	"user": {"width": 1800, "height": 1169, "scale": 1.1}    
}

const _n52 = {
	0: "auto",    
	1: 0.8,       
	2: 1.0,       
	3: 1.25,      
	4: 1.5        
}

const _d8 = 16  

var _a97: EditorPlugin
var _i86: EditorInterface
var _w75: ScriptEditor
var _m29: VBoxContainer
var _h41: EditorPlugin  

var _a58: _x28
var _y84: _c15
var _e14: _z51

@onready var _k76: ScrollContainer = %_g31
@onready var _i85: TextEdit = %_h22
@onready var _q11: Button = %_w80
@onready var _c46: LineEdit = %_a11
@onready var _q41: Button = %_d86
@onready var _i12: Label = %_j22
@onready var _t7: CheckButton = %_u55
@onready var _q22: Label = %_f25
@onready var _t44: HBoxContainer = %_d26
@onready var _d31: Label = %_b77
@onready var _j64: Label = %_m19
@onready var _s64: Label = %_n87
@onready var _a26: Button = %_a91
@onready var _l59: Label = %_c56
@onready var _n8: OptionButton = %_p95
@onready var _y15: OptionButton = %_m3
@onready var _t82: OptionButton = %_k98

@onready var _p5: VBoxContainer = $MarginContainer/TabContainer/Settings/_k1/VBoxContainer
@onready var _q61: TabContainer = $MarginContainer/TabContainer

@onready var _b10: ProgressBar = %_z89
@onready var _y83: Label = %_z82
@onready var _r53: Label = %_n91
@onready var _d45: Label = %_v87
@onready var _i45: OptionButton = %_a8
@onready var _p77: Panel = %_z60

@onready var _k20: Label = %_g13
@onready var _a98: TabContainer = %_s32
@onready var _h58: ItemList = %_l57
@onready var _f61: Label = %_n95
@onready var _f65: RichTextLabel = %_u28
@onready var _v30: RichTextLabel = %_b38
@onready var _h99: Button = %_f24
@onready var _o95: Button = %_z84
@onready var _o17: Button = %_u67
@onready var _c91: Button = %_c41
@onready var _x70: ItemList = %_d68
@onready var _g7: Label = %_a30
@onready var _l61: RichTextLabel = %_t48
@onready var _g52: RichTextLabel = %_g77
@onready var _q52: Button = %_j47
@onready var _k43: Button = %_c29
@onready var _b82: Button = %_y66
@onready var _z78: Button = %_b47
@onready var _c21: Button = %_a13
@onready var _r58: Button = %_h9
@onready var _d18: Button = %_w83
@onready var _x78: Button = %_n89
@onready var _r96: AcceptDialog = %_n16
@onready var _y21: LineEdit = %_m32
@onready var _l44: FileDialog = %_u82
@onready var _o20: FileDialog = %_o52

@onready var _u90: OptionButton = %_n68
@onready var _r67: Label = %_y64

var _u58: CheckBox
var _r98: OptionButton
var _h75: SpinBox

var _i57: CheckBox

var _e5: CheckBox

var _p27: Button

var _t46: _b92
var _u17: Array = []
var _v73: bool = false
var _y82: float = 0.0
var _t69: int = 0

var _j60: Dictionary = {}  
var _z97: int = 0
var _z73: int = 30000  
var _x60: Dictionary = {}
var _v94: Array[String] = []
var _g43: int = 0

var _t86: _g31
var _s18: int = -1
var _i61: int = -1
var _w9: String = ""
var _j40: bool = false
var _u65: String = ""  
var _a42: String = ""  

var _m36: bool = false
var _k26: Vector2 = Vector2.ZERO
var _b20: float = 0.0

var _m24: HBoxContainer
var _k55: OptionButton
var _u79: Label
var _a52: OptionButton  

const _f4 = [
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

var _b9: TextEdit
var _m1: Label
var _l27: Label

const _s89 = 3
var _q10: int = 0

var _y67: float = 1.0
var _l42: String = "auto"  

var _s22: int = 128000  
const _q44 = 0.85  
const _g1 = 1.0  

const _k59 = [
	"@file",
	"@selection",
	"@openscript",
	"@scene",
	"@node"
]

const _p39: int = 0
const _i21: int = 1
const _z26 = {
	_p39: "Chat",
	_i21: "Agent"
}

var _x14: _c24
var _z2: _h17
var _t5: ProgressBar
var _p30: Label
var _w27: Button
var _b93: bool = false
var _a37: VBoxContainer
var _z87: HBoxContainer
var _x4: Array = []  
var _x88: bool = false  
var _t55: HBoxContainer  
var _o7: HBoxContainer  

var _d43 = 0
var _f62 = []
var _z12 = {}
var _h27: Timer
var _e25: int = 0

var _b40: PanelContainer
var _j34: bool = false  
func _k82() -> void:
	_j60 = {}

func set_gdsense_manager(_r18: _b92) -> void:
	_t46 = _r18

	if _t46:
		if not _t46._p47.is_connected(_n37):
			_t46._p47.connect(_n37)
		if not _t46._c79.is_connected(_r66):
			_t46._c79.connect(_r66)
		if not _t46._d57.is_connected(_w35):
			_t46._d57.connect(_w35)

func set_plugin(_u86: EditorPlugin) -> void:
	_h41 = _u86

func _notification(_s100):
	if _s100 == NOTIFICATION_THEME_CHANGED:
		_k71()

func _ready() -> void:
	_q75()

	_t87.call_deferred()
	_a97 = EditorPlugin.new()
	_i86 = _a97.get_editor_interface()
	_w75 = _i86.get_script_editor()
	
	var _f27 = %_x10
	if _f27:
		_f27.add_theme_stylebox_override("panel", _x93)
	
	_u84()
	_v41()
	
	_a58 = _x28.new(_i86, _w75)
	_y84 = _c15.new(_a58, _i86)

	_e14 = _z51.new()
	_e14.initialize(_i85, self, _i86)
	_e14._z1.connect(_j33)

	_m29 = %_d51
	
	_k76.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_m29.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	_q41.pressed.connect(_d60)
	_q11.pressed.connect(_z91)
	_t7.toggled.connect(_m93)
	_a26.pressed.connect(_g74)
	_n8.item_selected.connect(_b59)
	_y15.item_selected.connect(_b59)
	_i85.gui_input.connect(_f73)
	_i85.text_changed.connect(_n93)

	_p77.mouse_entered.connect(_z44)
	_p77.mouse_exited.connect(_n3)
	_p77.gui_input.connect(_a80)
	
	_l20()
	
	_n99()

	_n98()

	_h27 = Timer.new()
	_h27.wait_time = 0.5  
	_h27.one_shot = true
	_h27.timeout.connect(_i23)
	add_child(_h27)
	
	if _t46:
		_t46._l54.connect(_o87)
		_t46._k42.connect(_d80)
		_t46._f93.connect(_d13)
		_t46._y20.connect(_q92)
		_t46._c11.connect(_l23)
		_t46._s7.connect(_t75)
		_t46._e32.connect(_b63)
		_t46._d52.connect(_a45)

	var _m15 = _t46._o19() if _t46 else ""
	_c46.text = _m15
	if _m15.is_empty():
		if _t46 and _t46._t60():
			var env = _t46._o50()
			_i12.text = "No API Key (%s)" % env.capitalize()
		else:
			_i12.text = "API Key Not Set"
	else:
		if _t46 and _t46._t60():
			var env = _t46._o50()
			_i12.text = "API Key Loaded (%s)" % env.capitalize()
		else:
			_i12.text = "API Key Loaded"
	
	_z70()

	_g33()

	_f16()
	
	_q62()
	
	_a33()

	_t17()

	_w87()

	_w77.call_deferred()

	_q22.visible = false
	_t44.visible = false

	if not (_t46 and _t46._t60()):
		_l59.visible = false

	_a94()

	_q48()

func _t87():
	if not _t46:
		if _q10 >= _s89:
			return
		
		_q10 += 1

		if is_inside_tree():
			get_tree().create_timer(1.0).timeout.connect(_g71)
		else:
			_b25.call_deferred()

func _b25():
	if _q10 >= _s89:
		return
	_t87()

func _g71():
	if not _t46:
		if _q10 >= _s89:
			pass

		else:
			pass

	else:
		_q10 = 0

func _process(delta: float):
	if _v73:
		var elapsed_time = (Time.get_ticks_msec() / 1000.0) - _y82
		_q22.text = "Request time: %.1fs" % elapsed_time

func _f73(_p91: InputEvent):
	if _e14 and _e14._k49(_p91):
		get_viewport().set_input_as_handled()
		return

	if _p91 is InputEventKey and _p91.pressed:
		if _p91.keycode == KEY_ENTER:
			if _p91.shift_pressed:
				_i85.text += "\n"
				_i85.set_caret_line(_i85.get_line_count() - 1)
				_i85.set_caret_column(0)
				get_viewport().set_input_as_handled()
			else:
				var text = _i85.text.strip_edges()
				if text.is_empty():
					return

				_i85.text = ""
				_n93() 

				if _t82 and _t82.selected == _i21:
					_r9(text)
				else:
					_l80(text)
				get_viewport().set_input_as_handled()

func _d60():
	if _t46:
		_t46._a82(_c46.text)

func _z91():
	var _e44: String = _i85.text
	if not _e44.is_empty():
		if _t82 and _t82.selected == _i21:
			_r9(_e44)
		else:
			_l80(_e44)

func _r9(_q74: String) -> void:
	if not _x14:
		_e16("Agent mode not available", true)
		return

	var _z65 = _k8(_q74)
	if _z65.is_empty():
		return

	_i85.text = ""
	_y72(_q74)

	_b69()

	_i85.editable = false
	_q11.disabled = true

	var _g68 = {
		"godot_version": Engine.get_version_info().get("string", "4.x"),
		"project_name": ProjectSettings.get_setting("application/config/name", "")
	}

	var _k23 = ""
	if _a52:
		_k23 = _f52()

	_x14._j59(_z65, _g68, _k23)

func _l80(_e44: String):
	_u65 = _e44

	_x26()

	_u17.append({"role": "user", "content": _e44, "original_content": _e44})
	_k82()
	
	var _d81 = _e44
	
	if _e44.begins_with("@explain"):
		var _o70 = _e44.find("\n")
		if _o70 != -1:
			_d81 = _e44.substr(0, _o70) + " (code attached)"
	
	_y72(_d81)
	
	_i85.text = ""
	_i85.editable = false
	_q11.disabled = true
	
	_v73 = true
	_y82 = Time.get_ticks_msec() / 1000.0
	_q22.visible = true
	_t44.visible = false
	_q22.text = "Request time: 0.0s"
	_u44.call_deferred()

	var _i96 = _e36(_e44, true)
	var processed_prompt = _i96["processed_prompt"]
	var context_metadata = _i96["context_metadata"]
	
	if processed_prompt == "":
		_u51()

		if _u17.size() > 0:
			_u17.pop_back()
			_k82()
		return
	
	if processed_prompt.strip_edges().begins_with("@explain"):
		var _u89 = _v28(processed_prompt)
		if _u89.has("function_context") and not _u89["function_context"].is_empty():
			if _t46:
				_t46._e58(_u17, "@explain", _u89["function_context"], context_metadata if context_metadata else {})
		else:
			_u17[_u17.size() - 1]["content"] = processed_prompt
			if _t46:
				_t46._e58(_u17, "", "", context_metadata if context_metadata else {})
	else:
		_u17[_u17.size() - 1]["content"] = processed_prompt

		if _t46:
			_t46._e58(_u17, "", "", context_metadata if context_metadata else {})

func _o87(_m54: String, _k15: Array, _n80: String = "", _v96: String = ""):
	if not _v96.is_empty() and _u17.size() > 0:
		for i in range(_u17.size() - 1, -1, -1):
			if _u17[i].get("role", "") == "user":
				_u17[i]["content"] = _v96
				break

	var _l99 = {"role": "agent", "content": _m54}
	if not _n80.is_empty():
		_l99["thought_signature"] = _n80
	_u17.append(_l99)

	_a42 = _n80
	_k82()
	_e88(_m54, _k15)

	if _t86 and not _u65.is_empty():
		var session_id = _t46._t62() if _t46 else ""

		var _z92 = _t86._p84()
		var _w22 = (not _z92 or _z92.session_id != session_id)

		if _w22 and _u17.size() > 2:
			for i in range(0, _u17.size() - 2, 2):  
				if i + 1 < _u17.size():
					var _o62 = _u17[i]
					var _a14 = _u17[i + 1]

					if _o62.get("role", "") == "user" and _a14.get("role", "") == "agent":
						var _n20 = _a14.get("thought_signature", "")

						var _h15 = _o62.get("original_content", _o62.get("content", ""))
						var _f47 = _o62.get("content", "")

						_t86._j12(_h15, _a14.get("content", ""), session_id, _n20, _f47, "")

		var _y43 = _u65
		var _s50 = _v96 if not _v96.is_empty() else _u65

		var _x18 = _t46._r22() if _t46 else ""

		_t86._j12(_y43, _m54, session_id, _n80, _s50, _x18)

		_t86._g15()
		_u65 = ""  

		_l97()

	_u51()
	_u44.call_deferred()
	_x26.call_deferred(true)

func _d80():
	_i12.text = "Invalid API Key"
	_v84("Your API key is invalid. Please check your settings.")
	_u51()
	_u44.call_deferred()

func _d13(_k63: int, _g45: String):
	var _o43 = _a3(_g45)
	var _p71: String
	
	if _o43 != _g45:
		_p71 = _o43
	else:
		_p71 = "API Error %d: %s" % [_k63, _g45]
		
		if _k63 == 400:
			if "custom_rules" in _g45.to_lower():
				_p71 += "\n\nPlease check your custom rules in the Settings tab."
			elif "godot_version" in _g45.to_lower():
				_p71 += "\n\nGodot version detection failed. Try restarting the editor."
		elif _k63 == 422:
			_p71 += "\n\nPlease verify your custom rules and parameter settings."
	
	_v84(_p71)
	_u51()
	_u44.call_deferred()

func _q92():
	if _t46 and _t46._t60():
		var env = _t46._o50()
		_i12.text = "API Key Saved (%s)!" % env.capitalize()
	else:
		_i12.text = "API Key Saved!"

func _g74():
	_u17.clear()
	_k82()
	_g3()
	for _j75 in _m29.get_children():
		_j75.queue_free()
	_q48()
	_a5()
	_t44.visible = false
	_t69 = 0
	_l59.text = "Total Token Usage for this chat: 0"

	if _t86:
		_t86._x48()
		_t86._g15()
		_l97()

	if _t46:
		_t46._k41()
	_u44.call_deferred()

func _u44():
	await get_tree().process_frame
	_k76.get_v_scroll_bar().value = _k76.get_v_scroll_bar().max_value

func _l23(_l90: int, _o33: int, _e26: int):
	_t69 += _e26

	if _t46 and _t46._t60():
		_d31.text = "P: %d" % _l90
		_j64.text = "C: %d" % _o33
		_s64.text = "T: %d" % _e26
		_l59.text = "Total Token Usage for this chat: %d" % _t69
		_t44.visible = true
	else:
		_t44.visible = false
		_l59.visible = false

	_u44.call_deferred()

func _t75(success: bool):
	if success:
		pass

	else:
		pass

func _m93(_b52: bool):
	_c46.secret = not _b52

func _z44():
	Input.set_default_cursor_shape(Input.CURSOR_VSIZE)

func _n3():
	if not _m36:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _a80(_p91: InputEvent):
	if _p91 is InputEventMouseButton:
		if _p91.button_index == MOUSE_BUTTON_LEFT:
			if _p91.pressed:
				_m36 = true
				_k26 = _p77.get_global_mouse_position()
				_b20 = _i85.custom_minimum_size.y
			else:
				_m36 = false
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)

	elif _p91 is InputEventMouseMotion and _m36:
		var _r6 = _p77.get_global_mouse_position()
		var _c42 = _r6.y - _k26.y
		var _f32 = clamp(_b20 + _c42, 40.0, 600.0)
		_i85.custom_minimum_size.y = _f32

func _t68(text: String) -> String:
	var _b26: PackedStringArray = text.split("\n")
	for i in range(_b26.size()):
		var line: String = _b26[i]
		var _l72: int = 0
		for char in line:
			if char == ' ':
				_l72 += 1
			else:
				break
		
		var _n10: int = _l72 / 4
		if _n10 > 0:
			_b26[i] = "\t".repeat(_n10) + line.lstrip(" ")
			
	return "\n".join(_b26)

func _u51():
	_i85.editable = true
	_q11.disabled = false
	_v73 = false
	_q22.visible = false

func _t95(text: String) -> PackedStringArray:
	var _t20 = RegEx.new()
	_t20.compile("[A-Z][a-zA-Z0-9]+")
	var _u10 = _t20.search_all(text)
	var _q18: PackedStringArray = []
	for _v42 in _u10:
		_q18.append(_v42.get_string())
	return _q18

func _u35(_t41: String) -> String:
	if not ClassDB.class_exists(_t41):
		return ""
		
	var _l78 := ""
	var _b71 = ClassDB.class_get_method_list(_t41)
	if _b71.size() > 0:
		_l78 = "Class: " + _t41 + "\n"

	return _l78

func _l2(user_prompt: String) -> String:
	if user_prompt.strip_edges().begins_with("@explain"):
		return _z52(user_prompt)
	
	if not _y99(user_prompt):
		return user_prompt
	
	var _q18 = _t95(user_prompt)
	if _q18.is_empty():
		return user_prompt
	
	var _s9 = "Godot Editor Context:\n"
	for _q96 in _q18:
		var _l78 = _u35(_q96)
		if not _l78.is_empty():
			_s9 += _l78 + "\n"
	
	if _s9 == "Godot Editor Context:\n":
		return user_prompt
	
	var _x64 = _s9 + "\nUser Question: " + user_prompt
	return _x64

func _v28(user_prompt: String) -> Dictionary:
	var _v42 = {}
	
	var _f17 = RegEx.new()
	_f17.compile("@explain\\s+([a-zA-Z_][a-zA-Z0-9_]*)")
	var _c43 = _f17.search(user_prompt)
	
	var function_name = ""
	if _c43:
		function_name = _c43.get_string(1)
		_v42["function_name"] = function_name
	
	var _q54 = RegEx.new()
	_q54.compile("```(?:gdscript)?\n([^`]+?)```")
	var _x95 = _q54.search(user_prompt)
	
	if _x95:
		var _z29 = _x95.get_string(1).strip_edges()
		_v42["function_context"] = _z29
	
	return _v42

func _z52(user_prompt: String) -> String:
	var _f17 = RegEx.new()
	_f17.compile("@explain\\s+([a-zA-Z_][a-zA-Z0-9_]*)")
	var _v42 = _f17.search(user_prompt)
	
	var function_name = ""
	if _v42:
		function_name = _v42.get_string(1)
	
	var _p58 = "Please explain this GDScript function"
	if not function_name.is_empty():
		_p58 += " called '%s'" % function_name
	
	_p58 += ". Focus on:\n"
	_p58 += "- What the function does (purpose and behavior)\n"
	_p58 += "- How to use it (parameters and return value)\n"
	_p58 += "- Any important implementation details\n"
	_p58 += "- Potential improvements or best practices\n\n"
	
	_p58 += user_prompt.replace("@explain %s" % function_name, "").strip_edges()
	
	return _p58

func _k8(user_prompt: String) -> String:
	if _a58 == null:
		return user_prompt

	var _q58 = _a58._m78(user_prompt)
	var commands = _q58.get("commands", [])
	var cleaned_prompt = _q58.get("cleaned_prompt", user_prompt)

	for _c38 in commands:
		if _c38.get("type", "") == "error":
			var _s52 = _c38.get("error", "Unknown error")
			if "path traversal" in _s52.to_lower() or "not allowed" in _s52.to_lower() or "blocked" in _s52.to_lower():
				_v84("⚠️ Security: " + _s52)
				return ""
			else:
				_v84("⚠️ " + _s52)
				return ""

	if commands.is_empty():
		return user_prompt

	var _j15: Array[String] = []
	for _c38 in commands:
		var _t28 = _c38.get("type", "")
		match _t28:
			"file":
				var path = _c38.get("path", "")
				if not path.is_empty():
					_j15.append("File: " + path)
			"selection":
				var _r21 = _c38.get("script_path", "")
				var _r32 = _c38.get("line_start", 0)
				var _a47 = _c38.get("line_end", 0)

				if (_r21.is_empty() or not _r21.begins_with("res://")) and _a58:
					var _p22 = _a58._t100()
					if _p22.get("success", false):
						_r21 = _p22.get("path", "")
						_r32 = _p22.get("start_line", 0)
						_a47 = _p22.get("end_line", 0)
				if not _r21.is_empty() and _r21.begins_with("res://"):
					_j15.append("Selection in %s (lines %d-%d)" % [_r21, _r32, _a47])
			"openscript":
				var path = _c38.get("path", "")

				if path.is_empty() or not path.begins_with("res://"):
					if _a58:
						var _d98 = _a58.get_current_script()
						if _d98.get("success", false):
							path = _d98.get("path", "")
				if not path.is_empty() and path.begins_with("res://"):
					_j15.append("Open script: " + path)
			"scene":
				var path = _c38.get("path", "")
				if not path.is_empty():
					_j15.append("Scene: " + path)
			"node":
				var node_path = _c38.get("node_path", "")
				if not node_path.is_empty():
					_j15.append("Node: " + node_path)

	if _j15.is_empty():
		return cleaned_prompt

	var _e46 = "\n\n[Referenced files - use read_file to access]:\n- " + "\n- ".join(_j15)
	return cleaned_prompt + _e46

func _e36(user_prompt: String, _k83: bool = false) -> Dictionary:
	if _a58 == null or _y84 == null:
		return {"processed_prompt": user_prompt, "context_metadata": null}
	
	var _q58 = _a58._m78(user_prompt)
	var commands = _q58.get("commands", [])
	var cleaned_prompt = _q58.get("cleaned_prompt", user_prompt)
	
	if _k83:
		_y69(commands)

		for _c38 in commands:
			if _c38.get("type", "") == "openscript":
				var snapshot_id = _c38.get("snapshot_id", "")
				if snapshot_id != "" and _x60.has(snapshot_id):
					_x60[snapshot_id]["sent_in_conversation"] = true

	var _j3 = _a75(commands)
	var _g2 = _z83(_j3)
	if not _g2.is_empty():
		var _u69 = []
		_u69.append_array(_g2)
		_u69.append_array(commands)
		commands = _u69
	
	var _s77 = []
	for _c38 in commands:
		if _c38.get("type", "") == "error":
			var _s52 = _c38.get("error", "Unknown error")

			if _s52.begins_with("Security:"):
				_s77.append("⚠️ " + _s52)
			elif "path traversal" in _s52.to_lower() or "not allowed" in _s52.to_lower() or "blocked" in _s52.to_lower():
				_s77.append("⚠️ Security: " + _s52)
			else:
				_s77.append("⚠️ " + _s52)
	
	if not _s77.is_empty():
		var _t14 = "\n".join(_s77)
		_v84(_t14)

		return {"processed_prompt": "", "context_metadata": null}
	
	if commands.is_empty():
		return {"processed_prompt": user_prompt, "context_metadata": null}
	
	var _s84 = _y84._l75(cleaned_prompt, commands)
	
	var _w58 = _y84._h24(_s84)
	if not _w58.get("valid", false):
		var _z50 = _w58.get("message", "Unknown validation error")
		_v84("Context too large: " + _z50)

		return {"processed_prompt": "", "context_metadata": null}
	
	var context_metadata = _l17(commands, _w58.get("estimated_tokens", 0))

	if OS.is_debug_build() and context_metadata:
		pass

	return {"processed_prompt": _s84, "context_metadata": context_metadata}

func _y69(commands: Array) -> void:
	if commands.is_empty():
		return
	
	var _n13 = false
	
	for _c38 in commands:
		if _c38.get("type", "") != "openscript":
			continue
		
		var snapshot_id = _c38.get("snapshot_id", "")
		if snapshot_id == "":
			snapshot_id = _g96()
			_c38["snapshot_id"] = snapshot_id
		
		var _r21 = _c38.get("path", "")
		var _j57 = _c38.get("content", "")
		
		if _j57 == "" and _a58:
			var _d98 = _a58.get_current_script()
			if _d98.get("success", false):
				_j57 = _d98.get("content", "")
				_c38["content"] = _j57
				if _r21 == "":
					_r21 = _d98.get("path", "")
					_c38["path"] = _r21
		
		if _j57 == "":
			continue
		
		if _r21 == "":
			_r21 = "current_script.gd"
			_c38["path"] = _r21
		
		_x60[snapshot_id] = {
			"path": _r21,
			"content": _j57,
			"size_bytes": _j57.length(),
			"created_at": _c38.get("created_at", Time.get_unix_time_from_system()),
			"sent_in_conversation": false  
		}
		
		if not _v94.has(snapshot_id):
			_v94.append(snapshot_id)
		
		_n13 = true
	
	if _n13:
		_e94()

func _a75(commands: Array) -> PackedStringArray:
	var _n59 = PackedStringArray()
	for _c38 in commands:
		if _c38.get("type", "") != "openscript":
			continue
		var snapshot_id = _c38.get("snapshot_id", "")
		if snapshot_id != "":
			_n59.append(snapshot_id)
	return _n59

func _z83(_g55: PackedStringArray = PackedStringArray()) -> Array:
	var commands: Array = []
	for snapshot_id in _v94:
		if _g55.has(snapshot_id):
			continue
		if not _x60.has(snapshot_id):
			continue

		var _w90 = _x60[snapshot_id]

		if _w90.get("sent_in_conversation", false):
			continue

		var _c38 = {
			"type": "openscript",
			"snapshot_id": snapshot_id,
			"path": _w90.get("path", ""),
			"content": _w90.get("content", "")
		}
		commands.append(_c38)
	return commands

func _p18(_c38: Dictionary) -> Dictionary:
	var _r21 = _c38.get("path", "")
	var _j57 = _c38.get("content", "")
	var snapshot_id = _c38.get("snapshot_id", "")
	
	if snapshot_id != "" and _x60.has(snapshot_id):
		var _w6 = _x60[snapshot_id]
		if _r21 == "":
			_r21 = _w6.get("path", "")
		if _j57 == "":
			_j57 = _w6.get("content", "")
	
	return {
		"path": _r21,
		"content": _j57,
		"snapshot_id": snapshot_id
	}

func _g96() -> String:
	_g43 += 1
	return "panel_openscript_%d_%d" % [Time.get_ticks_msec(), _g43]

func _g3() -> void:
	_x60.clear()
	_v94.clear()
	_g43 = 0
	_e94()

func _e94() -> void:
	if _t86:
		_t86._t63(_x60, _v94)

func _l17(commands: Array, _e87: int) -> Dictionary:
	var _p83 = []
	var _n72 = 0
	
	for _c38 in commands:
		var _v58 = {}
		var _t28 = _c38.get("type", "unknown")
		_v58["type"] = _t28

		match _t28:
			"file":
				_v58["path"] = _c38.get("path", "")
				if _c38.get("start_line", -1) > 0:
					_v58["start_line"] = _c38.get("start_line", 0)
				if _c38.get("end_line", -1) > 0:
					_v58["end_line"] = _c38.get("end_line", 0)
				if _c38.get("symbol", "") != "":
					_v58["symbol"] = _c38.get("symbol", "")
				
				if _a58:
					var _j44 = _a58._l19(_c38)
					if _j44.get("success", false):
						var _f8 = _j44.get("content", "").length()
						_v58["size_bytes"] = _f8
						_n72 += _f8
			
			"scene":
				_v58["path"] = _c38.get("path", "")
				if _c38.get("node_path", "") != "":
					_v58["node_path"] = _c38.get("node_path", "")
				if _c38.get("include_scripts", false):
					_v58["include_scripts"] = true
				
				var _s1 = 500  
				if _c38.get("include_scripts", false):
					_s1 += 2000  
				_v58["size_bytes"] = _s1
				_n72 += _s1
			
			"node":
				_v58["node_path"] = _c38.get("node_path", "")

				var _s1 = 200  
				_v58["size_bytes"] = _s1
				_n72 += _s1
			
			"selection":
				if _a58:
					var _p22 = _a58._t100()
					if _p22.get("success", false):
						var _f8 = _p22.get("content", "").length()
						_v58["size_bytes"] = _f8
						_n72 += _f8
						var _e84 = _p22.get("path", "")
						if _e84 != "":
							_v58["path"] = _e84
						var _v53 = _p22.get("start_line", 0)
						if _v53 > 0:
							_v58["start_line"] = _v53
						var _x1 = _p22.get("end_line", 0)
						if _x1 > 0:
							_v58["end_line"] = _x1
			
			"openscript":
				var _a34 = _p18(_c38)
				var _j57 = _a34.get("content", "")
				var _r21 = _a34.get("path", "")
				var snapshot_id = _a34.get("snapshot_id", "")
				
				if _j57 != "":
					var _f8 = _j57.length()
					_v58["size_bytes"] = _f8
					_n72 += _f8
				
				if _r21 != "":
					_v58["path"] = _r21
				
				if snapshot_id != "":
					_v58["snapshot_id"] = snapshot_id
		
		_p83.append(_v58)
	
	var _s56 = {
		"commands": _p83,
		"total_context_size": _n72,
		"command_count": commands.size(),
		"estimated_tokens": _e87
	}
	
	if _t46 and not _t46._t62().is_empty():
		_s56["session_id"] = _t46._t62()
	
	return _s56

func _y99(user_prompt: String) -> bool:
	var _i38 = [
		"CharacterBody2D", "RigidBody2D", "StaticBody2D", "Area2D",
		"Node2D", "Node3D", "Control", "Panel", "Button", "Label",
		"AnimationPlayer", "AnimationTree", "TileMap", "PackedScene",
		"Resource", "RefCounted", "Object", "Variant",
		"Vector2", "Vector3", "Transform2D", "Transform3D",
		"InputEvent", "Camera2D", "Camera3D", "CollisionShape2D"
	]
	
	var _s72 = user_prompt.to_lower()
	for _v48 in _i38:
		if _s72.find(_v48.to_lower()) != -1:
			return true
	
	return false

func _q95(code: String) -> String:
	var _t90 = ""
	var _b26 = code.split("\n")
	
	var _g65 = RegEx.new()
	_g65.compile("\\b(" + "|".join(_b45) + ")\\b")
	
	var _c87 = RegEx.new()

	_c87.compile("(?<!#)\\b(Vector2|Input|Node2D|Control|CharacterBody2D|[A-Z][a-zA-Z0-9]*)\\b")
	
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

func _y72(text: String):
	var _w53 = PanelContainer.new()
	_w53.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_w53.add_theme_constant_override("margin_bottom", _t45.message_gap)
	
	if not _w43:
		_u84()
	_w53.add_theme_stylebox_override("panel", _w43)
	
	var _i69 = VBoxContainer.new()
	_i69.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_i69.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var _i25 = Label.new()
	_i25.text = "You:"
	_i25.add_theme_color_override("font_color", _y16)
	var _s17 = get_theme_font_size("font_size", "Label")
	_i25.add_theme_font_size_override("font_size", int(_s17 * 1.15))
	_i69.add_child(_i25)
	
	var _p26 = Control.new()
	_p26.custom_minimum_size.y = 6
	_i69.add_child(_p26)
	
	var _g64 = ColorRect.new()
	_g64.custom_minimum_size.y = 1
	_g64.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_g64.color = _y16
	_g64.color.a = 0.5
	_i69.add_child(_g64)
	
	var _k67 = Control.new()
	_k67.custom_minimum_size.y = 6
	_i69.add_child(_k67)
	
	var _c68 = RichTextLabel.new()
	_c68.bbcode_enabled = true
	_c68.selection_enabled = true
	_c68.text = _a53(text)
	_c68.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_c68.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_c68.fit_content = true
	_c68.scroll_active = false
	_c68.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_c68.add_theme_color_override("default_color", _y16)
	_i69.add_child(_c68)
	
	_w53.add_child(_i69)
	_m29.add_child(_w53)

func _e88(text: String, _k15: Array = []):
	var _w53 = PanelContainer.new()
	_w53.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_w53.add_theme_constant_override("margin_bottom", _t45.message_gap)
	
	if not _h2:
		_u84()
	_w53.add_theme_stylebox_override("panel", _h2)
	
	var _i69 = VBoxContainer.new()
	_i69.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_i69.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	_i69.add_theme_constant_override("separation", 4)
	
	var _i25 = Label.new()
	_i25.text = "GDSense:"
	_i25.add_theme_color_override("font_color", _h73)
	var _s17 = get_theme_font_size("font_size", "Label")
	_i25.add_theme_font_size_override("font_size", int(_s17 * 1.15))
	_i69.add_child(_i25)
	
	var _p26 = Control.new()
	_p26.custom_minimum_size.y = 6
	_i69.add_child(_p26)
	
	var _g64 = ColorRect.new()
	_g64.custom_minimum_size.y = 1
	_g64.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_g64.color = _h73
	_g64.color.a = 0.5
	_i69.add_child(_g64)
	
	var _k67 = Control.new()
	_k67.custom_minimum_size.y = 6
	_i69.add_child(_k67)
	
	_m16(text, _i69)
	
	if _k15.size() > 0:
		_h94(_k15, _i69)
	
	if _t46:
		var _z41 = _t46._v70()

		if not _z41.is_empty():
			_y7(_i69)
		else:
			pass

	_w53.add_child(_i69)
	_m29.add_child(_w53)

func _m16(text: String, parent: Node):
	var _q54 = RegEx.new()
	_q54.compile("```([a-zA-Z]*)\n([^`]+?)```")
	
	var _w42 = 0
	var _f79 = _q54.search_all(text)
	
	for match in _f79:
		var _m21 = text.substr(_w42, match.get_start() - _w42)
		if not _m21.strip_edges().is_empty():
			_v13(_m21.strip_edges(), parent)
		
		var language = match.get_string(1).to_lower()
		if language.is_empty():
			language = "gdscript"  
		var code = match.get_string(2)
		_c13(code, language, parent)
		
		_w42 = match.get_end()
	
	if _w42 < text.length():
		var _k27 = text.substr(_w42)
		if not _k27.strip_edges().is_empty():
			_v13(_k27.strip_edges(), parent)

func _v13(text: String, parent: Node):
	var _o18 = text.strip_edges()
	
	_o18 = _o18.replace("**", "")
	
	var _r34 = RegEx.new()
	_r34.compile("`([^`]+)`")
	var _f21 = _r34.search_all(_o18)
	if _f21:
		for i in range(_f21.size() - 1, -1, -1):
			var _w91 = _f21[i]
			var full_match = _w91.get_string(0)
			var content = _w91.get_string(1)
			var _b54 = _a53(content)
			var _g89 = "[i]" + _b54 + "[/i]"
			_o18 = _o18.substr(0, _w91.get_start()) + _g89 + _o18.substr(_w91.get_end())

	var _s80 = RegEx.new()
	_s80.compile("'([A-Za-z0-9_\\-\\.]+)'")
	var _y60 = _s80.search_all(_o18)
	if _y60:
		for i in range(_y60.size() - 1, -1, -1):
			var _w91 = _y60[i]
			var full_match = _w91.get_string(0)
			var content = _w91.get_string(1)
			var _b54 = _a53(content)
			var _g89 = "[i]" + _b54 + "[/i]"
			_o18 = _o18.substr(0, _w91.get_start()) + _g89 + _o18.substr(_w91.get_end())
	
	var _s10 = "___SAFE_ITALIC_START___"
	var _y38 = "___SAFE_ITALIC_END___"
	_o18 = _o18.replace("[i]", _s10)
	_o18 = _o18.replace("[/i]", _y38)

	if _o18.begins_with("Explanation:") or _o18.begins_with("To use this:") or _o18.begins_with("To make this work:"):
		var _m27 = _o18.split(":", true, 1)
		if _m27.size() > 1:
			_o18 = "[b]" + _a53(_m27[0]) + ":[/b]" + _a53(_m27[1])

	var _b26 = _o18.split("\n")
	var _i7 = []

	var _o42 = RegEx.new()
	_o42.compile("^(#{1,4})\\s+(.+)$")

	var _w51 = RegEx.new()
	_w51.compile("^\\|\\s*[-:]+\\s*(\\|\\s*[-:]+\\s*)+\\|\\s*$")

	var _x8: Array = []  
	var _y28 = false

	var _x31 = func():
		if _i7.is_empty():
			return
		var _y70 = "\n".join(_i7)
		_y70 = _y70.replace(_s10, "[i]")
		_y70 = _y70.replace(_y38, "[/i]")
		if _y70.strip_edges().is_empty():
			_i7.clear()
			return
		var _h95 = RichTextLabel.new()
		_h95.bbcode_enabled = true
		_h95.selection_enabled = true
		_h95.text = _y70
		_h95.add_theme_constant_override("line_separation", 6)
		_h95.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_h95.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_h95.fit_content = true
		_h95.scroll_active = false
		_h95.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		_h95.add_theme_color_override("default_color", _h73)
		parent.add_child(_h95)
		_i7.clear()

	var _c27 = func():
		if _x8.is_empty():
			return

		_x31.call()

		var _s51 = 0
		for _z68 in _x8:
			if _z68.size() > _s51:
				_s51 = _z68.size()
		if _s51 == 0:
			_x8.clear()
			_y28 = false
			return

		var _u6 = MarginContainer.new()
		_u6.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_u6.add_theme_constant_override("margin_top", 8)
		_u6.add_theme_constant_override("margin_bottom", 12)

		var _t56 = PanelContainer.new()
		_t56.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var _a99 = StyleBoxFlat.new()
		_a99.bg_color = Color(0.15, 0.15, 0.18, 1.0)
		_a99.set_corner_radius_all(6)
		_a99.set_content_margin_all(12)
		_t56.add_theme_stylebox_override("panel", _a99)

		var _x71 = VBoxContainer.new()
		_x71.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_x71.add_theme_constant_override("separation", 0)

		var _c14 = GridContainer.new()
		_c14.columns = _s51
		_c14.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_c14.add_theme_constant_override("h_separation", 24)

		var _w88 = GridContainer.new()
		_w88.columns = _s51
		_w88.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_w88.add_theme_constant_override("h_separation", 24)
		_w88.add_theme_constant_override("v_separation", 10)

		var _t64 = int(14 * _y67)
		var _f33 = int(15 * _y67)
		for _v6 in range(_x8.size()):
			var _z68 = _x8[_v6]
			for _y45 in range(_s51):
				var _d25 = _z68[_y45] if _y45 < _z68.size() else ""

				_d25 = _d25.replace(_s10, "[i]")
				_d25 = _d25.replace(_y38, "[/i]")
				var _o48 = RichTextLabel.new()
				_o48.bbcode_enabled = true
				_o48.fit_content = true
				_o48.scroll_active = false
				_o48.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				_o48.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
				_o48.add_theme_color_override("default_color", _h73)
				if _v6 == 0 and _y28:
					_o48.add_theme_font_size_override("normal_font_size", _f33)
					_o48.text = "[b][u]" + _d25 + "[/u][/b]"
					_c14.add_child(_o48)
				else:
					_o48.add_theme_font_size_override("normal_font_size", _t64)
					_o48.text = _d25
					_w88.add_child(_o48)

		if _y28:
			_x71.add_child(_c14)

			var _g64 = HSeparator.new()
			_g64.add_theme_constant_override("separation", 8)
			_x71.add_child(_g64)
		_x71.add_child(_w88)
		_t56.add_child(_x71)
		_u6.add_child(_t56)
		parent.add_child(_u6)

		_x8.clear()
		_y28 = false

	for i in range(_b26.size()):
		var line = _b26[i]
		var _x6 = line.strip_edges()

		var _b17 = _w51.search(_x6) != null
		if _b17:
			if not _x8.is_empty():
				_y28 = true
			continue

		var _v14 = _o42.search(_x6)
		if _v14:
			_c27.call()
			var _j88 = _v14.get_string(1).length()
			var _s59 = _v14.get_string(2)

			var _s17 = 24  
			if _j88 == 2:
				_s17 = 20  
			elif _j88 == 3:
				_s17 = 18  
			elif _j88 == 4:
				_s17 = 16  

			var _t64 = int(_s17 * _y67)

			var _z71 = _a53(_s59)
			_i7.append("\n[b][font_size=" + str(_t64) + "]" + _z71 + "[/font_size][/b]\n")
		elif _x6.begins_with("|") and _x6.ends_with("|"):
			var _f2 = _x6.split("|")
			var _o88: Array = []

			for _y31 in _f2:
				var _v32 = _y31.strip_edges()

				if _v32.is_empty():
					continue

				if _v32.match("^-+$") or _v32.match("^:?-+:?$"):
					continue
				_o88.append(_a53(_v32))

			if not _o88.is_empty():
				_x8.append(_o88)
		elif _x6.begins_with("* "):
			_c27.call()

			var _b42 = _x6.substr(2).replace("*", "")
			_i7.append("• " + _a53(_b42))

			if i < _b26.size() - 1 and not _b26[i + 1].strip_edges().begins_with("* "):
				_i7.append("")
		elif _x6.match("^[0-9]+\\."):
			_c27.call()

			_i7.append(_a53(_x6))
		else:
			_c27.call()

			_i7.append(_a53(line.replace("*", "")))

	_c27.call()

	_x31.call()

func _c13(code: String, language: String, parent: Node):
	var _p59 = MarginContainer.new()
	_p59.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_p59.add_theme_constant_override("margin_left", 16)
	_p59.add_theme_constant_override("margin_right", 16)
	_p59.add_theme_constant_override("margin_top", 12)
	_p59.add_theme_constant_override("margin_bottom", 12)
	
	var _p62 = PanelContainer.new()
	_p62.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if not _o67:
		_u84()
	_p62.add_theme_stylebox_override("panel", _o67)
	
	var _p10 = VBoxContainer.new()
	_p10.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var _w62 = PanelContainer.new()
	_w62.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	_w62.add_theme_stylebox_override("panel", _j72)
	
	var _u92 = HBoxContainer.new()
	_u92.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_u92.layout_mode = 2  
	
	var _w69 = Label.new()
	_w69.layout_mode = 2
	_w69.text = _h34.get(language, "Code")

	_w69.add_theme_color_override("font_color", _g100)
	_u92.add_child(_w69)
	
	var _f90 = Control.new()
	_f90.layout_mode = 2
	_f90.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_u92.add_child(_f90)
	
	var _q98 = Button.new()
	_q98.layout_mode = 2
	_q98.text = "Copy"
	_q98.flat = true
	_q98.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_q98.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	_q98.pressed.connect(func(): _k86(code))
	_u92.add_child(_q98)
	
	_w62.add_child(_u92)
	_p10.add_child(_w62)
	
	var _u64 = MarginContainer.new()
	_u64.layout_mode = 2
	_u64.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_u64.add_theme_constant_override("margin_left", _t45.code_padding)
	_u64.add_theme_constant_override("margin_right", _t45.code_padding)
	_u64.add_theme_constant_override("margin_top", _t45.code_padding)
	_u64.add_theme_constant_override("margin_bottom", _t45.code_padding)
	
	var _k25 = RichTextLabel.new()
	_k25.bbcode_enabled = true
	_k25.selection_enabled = true
	_k25.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_k25.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_k25.fit_content = true
	_k25.scroll_active = false
	_k25.scroll_active = false
	
	var _w3 = _x34("text_color")
	_k25.add_theme_color_override("default_color", _w3)
	
	var _t90 = _m46(code, language)
	_k25.text = _t90
	
	var _o61 = SystemFont.new()
	_o61.font_names = ["Consolas", "Courier New", "Monospace"]
	_k25.add_theme_font_override("normal_font", _o61)
	_k25.add_theme_font_override("mono_font", _o61)
	
	_u64.add_child(_k25)
	_p10.add_child(_u64)
	
	_p62.add_child(_p10)
	_p59.add_child(_p62)
	parent.add_child(_p59)

func _m46(code: String, language: String) -> String:
	match language:
		"gdscript", "":
			return _q95(_t68(code))
		"csharp", "cs":
			return _k19(code)
		_:
			return code

func _k86(code: String):
	DisplayServer.clipboard_set(code)

func _k19(code: String) -> String:
	var _t90 = ""
	var _b26 = code.split("\n")
	
	var _g65 = RegEx.new()
	_g65.compile("\\b(" + "|".join(_l18) + ")\\b")
	
	var _c87 = RegEx.new()
	_c87.compile("\\b([A-Z][a-zA-Z0-9]*)\\b")
	
	var _i2 = RegEx.new()
	_i2.compile("\\b([a-z_][a-zA-Z0-9_]*)\\s*\\(")
	
	var _o8 = RegEx.new()
	_o8.compile("(\"[^\"]*\"|'[^']*')")
	
	var _o15 = RegEx.new()
	_o15.compile("\\b\\d+(\\.\\d+)?[fFdD]?\\b")
	
	var _v20 = RegEx.new()
	_v20.compile("(//.*$|/\\*.*?\\*/)")
	
	for line in _b26:
		if line.strip_edges().is_empty():
			_t90 += "\n"
			continue
		
		var _d34 = line
		
		_d34 = _v20.sub(_d34, "[color=#%s]$1[/color]" % [_x34("comment").to_html(false)], true)
		
		_d34 = _o8.sub(_d34, "[color=#%s]$1[/color]" % [_x34("string").to_html(false)], true)
		
		_d34 = _g65.sub(_d34, "[color=#%s]$1[/color]" % [_x34("keyword").to_html(false)], true)
		
		_d34 = _c87.sub(_d34, "[color=#%s]$1[/color]" % [_x34("class").to_html(false)], true)
		
		_d34 = _i2.sub(_d34, "[color=#%s]$1[/color](" % [_x34("function").to_html(false)], true)
		
		_d34 = _o15.sub(_d34, "[color=#%s]$0[/color]" % [_x34("number").to_html(false)], true)
		
		_t90 += _d34 + "\n"
	
	return _t90.strip_edges()

func _v84(text: String):
	var _w53 = PanelContainer.new()
	_w53.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_w53.add_theme_constant_override("margin_bottom", _t45.message_gap)

	var _q77 = Color("#ff6666")
	if _i86:
		var theme = _i86.get_editor_theme()
		if theme:
			_q77 = theme.get_color("error_color", "Editor")

	var _z9 = StyleBoxFlat.new()
	_z9.bg_color = _q77.darkened(0.8)
	_z9.border_color = _q77
	_z9.border_width_bottom = 1
	_z9.border_width_top = 1
	_z9.border_width_left = 1
	_z9.border_width_right = 1
	_z9.corner_radius_top_left = 8
	_z9.corner_radius_top_right = 8
	_z9.corner_radius_bottom_left = 8
	_z9.corner_radius_bottom_right = 8
	_z9.content_margin_left = _t45.padding
	_z9.content_margin_right = _t45.padding
	_z9.content_margin_top = _t45.padding
	_z9.content_margin_bottom = _t45.padding
	_w53.add_theme_stylebox_override("panel", _z9)

	var _i69 = VBoxContainer.new()
	_i69.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_i69.layout_mode = 2  

	var _s93 = _q77.lightened(0.3)  
	var _u18 = Color(1.0, 0.9, 0.9)  

	var _n53 = Label.new()
	_n53.text = "GDSense Error"
	_n53.add_theme_color_override("font_color", _s93)
	_n53.add_theme_font_size_override("font_size", 16)
	_i69.add_child(_n53)

	var _c68 = Label.new()
	_c68.text = text
	_c68.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_c68.add_theme_color_override("font_color", _u18)
	_i69.add_child(_c68)

	_w53.add_child(_i69)
	_m29.add_child(_w53)

func _q48():
	var _w53 = PanelContainer.new()
	_w53.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_w53.add_theme_constant_override("margin_bottom", _t45.message_gap)
	
	if not _h2:
		_u84()
	_w53.add_theme_stylebox_override("panel", _h2)
	
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.selection_enabled = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.fit_content = true
	label.scroll_active = false
	label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	label.add_theme_color_override("default_color", _s83("font_color"))
	label.text = "[b]Welcome to GDSense![/b] Your AI coding partner for Godot."
	
	_w53.add_child(label)
	_m29.add_child(_w53)

func _n22(text: String):
	if text.strip_edges().is_empty():
		return
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.selection_enabled = true
	label.text = _a53(text)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.fit_content = true
	label.scroll_active = false
	label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	label.add_theme_color_override("default_color", _h73)
	_m29.add_child(label)

func _g33() -> void:
	_a52 = OptionButton.new()
	_a52.name = "AgentModelSelector"
	_q38()
	_a52.visible = false  

	_a52.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if _y15:
		var _b67 = _y15.get_parent()
		if _b67:
			var _r86 = _b67.get_children().find(_y15)
			_b67.add_child(_a52)

			_b67.move_child(_a52, _r86)

func _z70():
	_n8.clear()
	_y15.clear()

	var _v29 = []
	if _t46:
		_v29 = _t46._s69()
	else:
		_v29 = [
			"openai/gpt-oss-20b",
			"gemini-2.5-flash-lite",
			"gpt-5-nano"
		]

	for _t88 in _v29:
		var _l15: String
		var _z3: String

		if _t88 is Dictionary and _t88.has("id"):
			_z3 = _t88.get("id", "")
			_l15 = _t88.get("display_name", _z3)
		else:
			_z3 = str(_t88)
			_l15 = _h65.get(_z3, _z3)

		_n8.add_item(_l15)
		_y15.add_item(_l15)

	if _t46:
		var _o66 = _t46._r22()
		if _l34(_o66, _v29):
			_p76(_o66)
		else:
			if _v29.size() > 0:
				var _l28 = _m99(_v29[0])
				_p76(_l28)
				_t46._e91(_l28)

	_f22()

func _m99(_t88) -> String:
	if _t88 is Dictionary and _t88.has("id"):
		return _t88.get("id", "")
	return str(_t88)

func _l34(_z3: String, _v29: Array) -> bool:
	for _t88 in _v29:
		var _w31 = _m99(_t88)
		if _w31 == _z3:
			return true
	return false

func _f22():
	pass

func _p89(index: int) -> String:
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

func _b59(index: int) -> void:
	var _v29 = []
	if _t46:
		_v29 = _t46._s69()

	if index < 0 or index >= _v29.size():
		return

	var _z3 = _m99(_v29[index])
	if _t46:
		_t46._e91(_z3)

	_n8.selected = index
	_y15.selected = index

	_x26(true)

func _p76(model: String) -> void:
	var _v29 = []
	if _t46:
		_v29 = _t46._s69()

	for i in range(_v29.size()):
		var _w31 = _m99(_v29[i])
		if _w31 == model:
			_n8.selected = i
			_y15.selected = i
			return

	_n8.selected = 0
	_y15.selected = 0

func _f16():
	if not _t46 or not _t46._t60():
		return
	
	_m24 = HBoxContainer.new()
	_m24.add_theme_constant_override("separation", 10)
	
	_u79 = Label.new()
	_u79.text = "Environment:"
	_m24.add_child(_u79)
	
	_k55 = OptionButton.new()
	_k55.add_item("Production")
	_k55.add_item("Development (localhost:8080)")
	
	var _r35 = _t46._o50() if _t46 else "production"
	if _r35 == "development":
		_k55.selected = 1
	else:
		_k55.selected = 0
	
	_k55.item_selected.connect(_s55)
	_m24.add_child(_k55)
	
	var _c85 = Label.new()
	_c85.text = "[DEV MODE]"
	_c85.modulate = Color(1, 0.5, 0.5)
	_m24.add_child(_c85)

	var _i37 = _c46.get_parent()
	var parent = _i37.get_parent()
	var index = parent.get_children().find(_i37)
	parent.add_child(_m24)
	parent.move_child(_m24, index + 1)

func _q38() -> void:
	if not _a52:
		return

	_a52.clear()

	var _v29 = []
	if _t46:
		_v29 = _t46._j19()

	if _v29.size() > 0 and _v29[0] is Dictionary and _v29[0].has("id"):
		for _t88 in _v29:
			var _l15 = _t88.get("display_name", _t88.get("id", "Unknown"))
			_a52.add_item(_l15)
	else:
		for _l60 in _f4:
			_a52.add_item(_l60["name"])
	_a52.selected = 0  

func _f52() -> String:
	if not _a52:
		return ""

	var _n43 = _a52.selected
	if _n43 < 0:
		return ""

	var _v29 = []
	if _t46:
		_v29 = _t46._j19()

	if _v29.size() > 0 and _v29[0] is Dictionary and _v29[0].has("id"):
		if _n43 < _v29.size():
			return _v29[_n43].get("id", "")
	else:
		if _n43 < _f4.size():
			return _f4[_n43]["id"]

	return ""

func _s55(index: int):
	var _r19 = ["production", "development"][index]
	var _m15 = ""
	
	if _t46:
		_t46._y74(_r19)

		_m15 = _t46._o19()
		_c46.text = _m15
	
	if _m15.is_empty():
		_i12.text = "No API Key (%s)" % _r19.capitalize()
	else:
		_i12.text = "API Key Loaded (%s)" % _r19.capitalize()
	
func _q62():
	if not _p5:
		return
	
	var _g64 = HSeparator.new()
	_p5.add_child(_g64)

	var _e12 = VBoxContainer.new()
	_e12.add_theme_constant_override("separation", 5)
	_p5.add_child(_e12)
	
	var _s71 = Label.new()
	_s71.text = "Ghost Text Autocomplete"
	_s71.add_theme_font_size_override("font_size", int(20 * _y67))
	_e12.add_child(_s71)
	
	_u58 = CheckBox.new()
	_u58.text = "Enable Autocomplete"
	_u58.button_pressed = true  
	_u58.toggled.connect(_w55)
	_e12.add_child(_u58)
	
	var _d69 = HBoxContainer.new()
	_d69.layout_mode = 2
	_e12.add_child(_d69)
	
	var _x40 = Label.new()
	_x40.text = "Trigger Mode:"
	_x40.custom_minimum_size.x = 150
	_d69.add_child(_x40)
	
	_r98 = OptionButton.new()
	_r98.layout_mode = 2
	_r98.add_item("Automatic")
	_r98.add_item("Manual (Ctrl+Space)")
	_r98.selected = 0
	_r98.item_selected.connect(_k69)
	_d69.add_child(_r98)
	
	var _n83 = HBoxContainer.new()
	_n83.layout_mode = 2
	_e12.add_child(_n83)
	
	var _t13 = Label.new()
	_t13.text = "Minimum Characters:"
	_t13.custom_minimum_size.x = 150
	_n83.add_child(_t13)
	
	_h75 = SpinBox.new()
	_h75.layout_mode = 2
	_h75.min_value = 1
	_h75.max_value = 10
	_h75.value = 3
	_h75.step = 1
	_h75.value_changed.connect(_f87)
	_n83.add_child(_h75)
	
	var _w12 = Label.new()
	_w12.text = "Smart triggers: After '.', '(', ':', '=', or space following keywords"
	_w12.layout_mode = 2
	var _o47 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_w12.add_theme_color_override("font_color", Color(_o47, 0.6))
	_w12.set_meta("secondary", true)
	_w12.add_theme_font_size_override("font_size", 12)
	_w12.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_e12.add_child(_w12)
	
	var _k31 = HSeparator.new()
	_e12.add_child(_k31)
	
	var _d44 = HBoxContainer.new()
	_d44.layout_mode = 2
	_e12.add_child(_d44)
	
	var _u85 = Label.new()
	_u85.text = "Inline Explain Buttons"
	_u85.add_theme_font_size_override("font_size", int(16 * _y67))
	_d44.add_child(_u85)

	_i57 = CheckBox.new()
	_i57.text = "Show Explain Buttons Above Functions"
	_i57.button_pressed = true  
	_i57.toggled.connect(_r52)
	_e12.add_child(_i57)
	
	var _q72 = Label.new()
	_q72.text = "Adds clickable help icons above function declarations to explain code"
	_q72.layout_mode = 2
	var _c25 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_q72.add_theme_color_override("font_color", Color(_c25, 0.6))
	_q72.set_meta("secondary", true)
	_q72.add_theme_font_size_override("font_size", 12)
	_q72.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_e12.add_child(_q72)
	
	var _h57 = HSeparator.new()
	_e12.add_child(_h57)
	
	var _p14 = Label.new()
	_p14.text = "Inline Refactor Buttons"
	_p14.add_theme_font_size_override("font_size", int(18 * _y67))
	_e12.add_child(_p14)
	
	_e5 = CheckBox.new()
	_e5.text = "Show Refactor Buttons Above Functions"
	_e5.button_pressed = true  
	_e5.toggled.connect(_t89)
	_e12.add_child(_e5)
	
	var _m97 = Label.new()
	_m97.text = "Adds clickable ↻ icons above function declarations for AI-powered refactoring"
	_m97.layout_mode = 2
	var _g44 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_m97.add_theme_color_override("font_color", Color(_g44, 0.6))
	_m97.set_meta("secondary", true)
	_m97.add_theme_font_size_override("font_size", 12)
	_m97.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_e12.add_child(_m97)
	
	var _l56 = HSeparator.new()
	_e12.add_child(_l56)
	
	_b14(_e12)
	
	_j53()

func _j53():
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		_u58.button_pressed = config.get_value("autocomplete", "enabled", true)
		
		var mode = config.get_value("autocomplete", "mode", "automatic")
		_r98.selected = 0 if mode == "automatic" else 1
		
		_h75.value = config.get_value("autocomplete", "min_chars", 3)
		
		_i57.button_pressed = config.get_value("explain_button", "enabled", true)
		
		_e5.button_pressed = config.get_value("refactor_button", "enabled", true)
		
		var _f38 = find_child("_s8", true)
		var _t50 = find_child("_z27", true)
		var _w50 = find_child("_s29", true)
		
		if _f38:
			_f38.button_pressed = config.get_value("undo", "enabled", true)
		if _t50:
			_t50.value = config.get_value("undo", "max_history_items", 20)
		if _w50:
			_w50.button_pressed = config.get_value("undo", "show_history_button", true)

func _q90():
	var mode = "automatic" if _r98.selected == 0 else "manual"
	
	const _w1 = 1000
	const _t35 = 150
	
	if _h41 and _h41.has_method("save_autocomplete_config"):
		_h41.save_autocomplete_config(
			_u58.button_pressed,
			_w1,
			_t35,
			mode,
			int(_h75.value)
		)
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_api_key.cfg")
		config.set_value("autocomplete", "enabled", _u58.button_pressed)
		config.set_value("autocomplete", "delay_ms", _w1)
		config.set_value("autocomplete", "max_length", _t35)
		config.set_value("autocomplete", "mode", mode)
		config.set_value("autocomplete", "min_chars", int(_h75.value))
		config.save("user://gdsense_api_key.cfg")

func _w55(enabled: bool):
	_q90()

func _k69(index: int):
	_q90()

func _f87(value: float):
	_q90()

func _r52(enabled: bool):
	if _h41 and _h41.has_method("save_explain_button_config"):
		_h41.save_explain_button_config(enabled)
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_api_key.cfg")
		config.set_value("explain_button", "enabled", enabled)
		config.save("user://gdsense_api_key.cfg")

func _t89(enabled: bool):
	if _h41 and _h41.has_method("save_refactor_config"):
		_h41.save_refactor_config(enabled)
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_api_key.cfg")
		config.set_value("refactor_button", "enabled", enabled)
		config.save("user://gdsense_api_key.cfg")

func _b14(_g38: VBoxContainer):
	var _z93 = Label.new()
	_z93.text = "Refactor Undo System"
	_z93.add_theme_font_size_override("font_size", int(18 * _y67))
	_g38.add_child(_z93)
	
	var _f38 = CheckBox.new()
	_f38.name = "UndoEnabledCheckbox"
	_f38.text = "Enable Undo for Refactored Functions"
	_f38.button_pressed = true  
	_f38.toggled.connect(_c70)
	_g38.add_child(_f38)
	
	var _n90 = HBoxContainer.new()
	_n90.layout_mode = 2
	_g38.add_child(_n90)
	
	var _q46 = Label.new()
	_q46.text = "Max History Items:"
	_q46.custom_minimum_size.x = 150
	_n90.add_child(_q46)
	
	var _t50 = SpinBox.new()
	_t50.name = "MaxHistorySpinbox"
	_t50.layout_mode = 2
	_t50.min_value = 5
	_t50.max_value = 50
	_t50.value = 20
	_t50.step = 1
	_t50.value_changed.connect(_v3)
	_n90.add_child(_t50)
	
	var _w50 = CheckBox.new()
	_w50.name = "ShowHistoryCheckbox"
	_w50.text = "Show History Button in Panel"
	_w50.button_pressed = true  
	_w50.toggled.connect(_h28)
	_g38.add_child(_w50)
	
	var _e20 = Label.new()
	_e20.text = "Track refactored functions with visual indicators and one-click undo"
	_e20.layout_mode = 2
	_e20.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_e20.add_theme_font_size_override("font_size", 12)
	_e20.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_g38.add_child(_e20)

func _c70(enabled: bool):
	if _h41 and _h41.has_method("save_undo_config"):
		_h41.save_undo_config(enabled)
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_settings.cfg")
		config.set_value("undo", "enabled", enabled)
		config.save("user://gdsense_settings.cfg")

func _v3(value: float):
	if _h41 and _h41.has_method("save_undo_max_history"):
		_h41.save_undo_max_history(int(value))
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_settings.cfg")
		config.set_value("undo", "max_history_items", int(value))
		config.save("user://gdsense_settings.cfg")

func _h28(enabled: bool):
	if _h41 and _h41.has_method("save_undo_show_history"):
		_h41.save_undo_show_history(enabled)
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_settings.cfg")
		config.set_value("undo", "show_history_button", enabled)
		config.save("user://gdsense_settings.cfg")

func _a33():
	if not _p5:
		return
	
	var _g64 = HSeparator.new()
	_p5.add_child(_g64)

	var _m56 = VBoxContainer.new()
	_m56.add_theme_constant_override("separation", 10)
	_p5.add_child(_m56)
	
	var _l49 = Label.new()
	_l49.text = "Custom Instructions"
	_l49.add_theme_font_size_override("font_size", int(20 * _y67))
	_m56.add_child(_l49)
	
	var _e93 = HBoxContainer.new()
	_m56.add_child(_e93)
	
	var _b84 = Label.new()
	_b84.text = "Godot Version:"
	_b84.custom_minimum_size.x = 120
	_e93.add_child(_b84)
	
	var _r41 = Label.new()
	_r41.text = _t46._b61() if _t46 else "Unknown"
	var _o97 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_r41.add_theme_color_override("font_color", Color(_o97, 0.6))
	_r41.set_meta("secondary", true)
	_e93.add_child(_r41)
	
	var _h37 = HBoxContainer.new()
	_m56.add_child(_h37)
	
	var _l43 = Label.new()
	_l43.text = "Temperature:"
	_l43.custom_minimum_size.x = 120
	_h37.add_child(_l43)
	
	var _e3 = SpinBox.new()
	_e3.name = "TemperatureSpinBox"
	_e3.min_value = 0.0
	_e3.max_value = 1.0
	_e3.step = 0.1
	_e3.value = 0.0
	_e3.value_changed.connect(_s16)
	_h37.add_child(_e3)
	
	var _k74 = Label.new()
	_k74.text = "(0.0 = use default)"
	var _b13 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_k74.add_theme_color_override("font_color", Color(_b13, 0.6))
	_k74.set_meta("secondary", true)
	_k74.add_theme_font_size_override("font_size", 11)
	_h37.add_child(_k74)
	
	var _w4 = Label.new()
	_w4.text = "Custom Rules (500 char limit):"
	_w4.add_theme_font_size_override("font_size", int(18 * _y67))
	_m56.add_child(_w4)

	_b9 = TextEdit.new()
	_b9.name = "CustomRulesInput"
	_b9.custom_minimum_size = Vector2(0, 100)
	_b9.placeholder_text = "Enter custom rules for AI responses (one per line)..."
	_b9.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_b9.text_changed.connect(_v21)
	_m56.add_child(_b9)

	_m1 = Label.new()
	_m1.name = "CharCounter"
	_m1.text = "0/500"
	_m1.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_m1.add_theme_font_size_override("font_size", 12)
	_m1.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_m56.add_child(_m1)

	_l27 = Label.new()
	_l27.name = "ValidationMessage"
	_l27.text = ""
	_l27.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	_l27.add_theme_font_size_override("font_size", 12)
	_l27.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_l27.visible = false
	_m56.add_child(_l27)
	
	_j56.call_deferred()

func _t17():
	_t86 = _g31.new()

	_t86._x5()

	if _h58:
		_h58.item_selected.connect(_s65)
	if _x70:
		_x70.item_selected.connect(_p81)

	if _h99:
		_h99.pressed.connect(_n33)
	if _o95:
		_o95.pressed.connect(_e98)
	if _o17:
		_o17.pressed.connect(_b2)
	if _c91:
		_c91.pressed.connect(_g67)

	if _q52:
		_q52.pressed.connect(_j23)
	if _k43:
		_k43.pressed.connect(_u8)
	if _b82:
		_b82.pressed.connect(_m87)
	if _z78:
		_z78.pressed.connect(_i17)

	if _c21:
		_c21.pressed.connect(_l36)
	if _r58:
		_r58.pressed.connect(_t2)
	if _d18:
		_d18.pressed.connect(_t85)
	if _x78:
		_x78.pressed.connect(_r49)

	if _l44:
		_l44.file_selected.connect(_f7)
	if _o20:
		_o20.file_selected.connect(_n61)

	if _r96:
		_r96.confirmed.connect(_b28)

	_v17()

	_l97()

func _w87():
	if _u90:
		_u90.item_selected.connect(_e80)

	_s54()

	var _g50 = _z5()
	var _d72 = _t83()
	_r67.text = "Auto: %.0f%% (%s detected). Your resolution: %dx%d" % [
		_d72 * 100,
		_g50,
		get_viewport().get_visible_rect().size.x,
		get_viewport().get_visible_rect().size.y
	]

	_l92()

func _z5() -> String:
	var _h21 = get_viewport().get_visible_rect().size
	var width = int(_h21.x)
	var height = int(_h21.y)

	if width < 800 or width > 16384 or height < 600 or height > 16384:
		width = 1920
		height = 1080

	var _q86 = 100
	for _l88 in _o53:
		var _z72 = _o53[_l88]
		if abs(width - _z72.width) <= _q86 and abs(height - _z72.height) <= _q86:
			return _l88

	var _a72 = width * height
	var _x86 = "1080p"
	var _n7 = INF

	for _l88 in _o53:
		var _z72 = _o53[_l88]
		var _r60 = _z72.width * _z72.height
		var _n78 = abs(_a72 - _r60)
		if _n78 < _n7:
			_n7 = _n78
			_x86 = _l88

	return _x86

func _t83() -> float:
	var _l88 = _z5()
	return _o53[_l88].scale

func _u91() -> float:
	if _l42 == "auto":
		return _t83()
	else:
		var _g25 = float(_l42)
		_g25 = clamp(_g25, 0.5, 3.0)  
		if is_nan(_g25) or is_inf(_g25):
			_g25 = 1.0  
		return _g25

func _l92():
	_y67 = _u91()
	var _u13 = int(_d8 * _y67)

	var _h85 = get_node_or_null("MarginContainer/TabContainer/History")
	if _h85:
		for label in _a15(_h85):
			if label is Label:
				label.add_theme_font_size_override("font_size", _u13)
			elif label is RichTextLabel:
				label.add_theme_font_size_override("normal_font_size", _u13)

	_h77(_u13)

func _h77(_u13: int):
	var _x99 = get_node_or_null("MarginContainer/TabContainer/Settings/_k1/VBoxContainer")
	if not _x99:
		return

	var _c26 = ["Ghost Text Autocomplete", "Custom Instructions"]
	var _o65 = ["Inline Explain Buttons", "Inline Refactor Buttons", "Refactor Undo System",
					   "Custom Rules", "Parameter Overrides"]

	for _j75 in _a15(_x99):
		if _j75 is Label:
			var _o60 = _j75.text
			var target_size = _u13

			for _o44 in _c26:
				if _o60.begins_with(_o44):
					target_size = int(20 * _y67)
					break

			if target_size == _u13:  
				for _r38 in _o65:
					if _o60.begins_with(_r38):
						target_size = int(18 * _y67)
						break

			_j75.add_theme_font_size_override("font_size", target_size)
		elif _j75 is RichTextLabel:
			_j75.add_theme_font_size_override("normal_font_size", _u13)
func _p52(text: String) -> bool:
	var _m14 = [
		"highest-volume", "smart triggers", "fixed settings", "adds clickable",
		"track refactored", "use default", "auto detects", "char limit",
		"following keywords", "second delay", "token max", "help icons",
		"visual indicators", "one-click undo", "AI-powered"
	]
	for _v48 in _m14:
		if _v48 in text:
			return true
	return false

func _a15(node: Node) -> Array:
	var children = []
	for _j75 in node.get_children():
		children.append(_j75)
		children.append_array(_a15(_j75))
	return children

func _e80(index: int):
	var _y23 = _n52[index]

	if typeof(_y23) == TYPE_STRING and _y23 == "auto":
		_l42 = "auto"
	else:
		_l42 = str(_y23)

	_b36()

	_l92()

	if _l42 == "auto":
		var _g50 = _z5()
		var _d72 = _t83()
		_r67.text = "Auto: %.0f%% (%s detected). Your resolution: %dx%d" % [
			_d72 * 100,
			_g50,
			get_viewport().get_visible_rect().size.x,
			get_viewport().get_visible_rect().size.y
		]
	else:
		_r67.text = "Manual: %.0f%%. Auto detects based on 1080p/1440p/4K presets" % [
			float(_l42) * 100
		]

func _b36():
	var config = ConfigFile.new()
	config.load("user://gdsense_settings.cfg")
	config.set_value("font_scale", "mode", _l42)
	config.save("user://gdsense_settings.cfg")

func _s54():
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		_l42 = config.get_value("font_scale", "mode", "auto")

		if _l42 == "auto":
			_u90.selected = 0
		elif _l42 == "0.8":
			_u90.selected = 1
		elif _l42 == "1.0":
			_u90.selected = 2
		elif _l42 == "1.25":
			_u90.selected = 3
		elif _l42 == "1.5":
			_u90.selected = 4

	else:
		_l42 = "auto"
		_u90.selected = 0

func _y7(parent: Node) -> void:
	var _x91 = HBoxContainer.new()
	_x91.add_theme_constant_override("separation", 10)
	
	var _f90 = Control.new()
	_f90.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_x91.add_child(_f90)
	
	var _s14 = Button.new()
	_s14.text = "👍"
	_s14.tooltip_text = "Good response"
	_s14.flat = false  
	_s14.custom_minimum_size = Vector2(36, 36)  
	_s14.add_theme_font_size_override("font_size", 16)
	_s14.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	_s14.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9))
	_s14.add_theme_stylebox_override("normal", _p80())
	_s14.add_theme_stylebox_override("hover", _b15())
	_s14.add_theme_stylebox_override("pressed", _k45())
	_s14.pressed.connect(_t12)
	_d76(_s14)
	_x91.add_child(_s14)
	
	var _m63 = Button.new()
	_m63.text = "👎"
	_m63.tooltip_text = "Poor response"
	_m63.flat = false  
	_m63.custom_minimum_size = Vector2(36, 36)  
	_m63.add_theme_font_size_override("font_size", 16)
	_m63.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	_m63.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9))
	_m63.add_theme_stylebox_override("normal", _p80())
	_m63.add_theme_stylebox_override("hover", _b15())
	_m63.add_theme_stylebox_override("pressed", _k45())
	_m63.pressed.connect(_d47)
	_d76(_m63)
	_x91.add_child(_m63)
	
	parent.add_child(_x91)

func _p80() -> StyleBoxFlat:
	var _r20 = StyleBoxFlat.new()
	_r20.bg_color = Color(0, 0, 0, 0)  
	_r20.set_corner_radius_all(4)
	return _r20

func _b15() -> StyleBoxFlat:
	var _r20 = StyleBoxFlat.new()
	_r20.bg_color = Color(0.3, 0.3, 0.3, 0.3)  
	_r20.set_corner_radius_all(6)
	_r20.set_border_width_all(1)
	_r20.border_color = Color(0.5, 0.5, 0.5, 0.5)
	return _r20

func _k45() -> StyleBoxFlat:
	var _r20 = StyleBoxFlat.new()
	_r20.bg_color = Color(0.2, 0.2, 0.2, 0.4)  
	_r20.set_corner_radius_all(6)
	_r20.set_border_width_all(1)
	_r20.border_color = Color(0.4, 0.4, 0.4, 0.6)
	return _r20

func _d76(_c65: Button) -> void:
	_c65.set_meta("original_scale", Vector2.ONE)
	_c65.set_meta("is_hovering", false)
	
	_c65.modulate.a = 0.7  
	_c65.pivot_offset = _c65.custom_minimum_size / 2  
	
	_c65.mouse_entered.connect(_p67.bind(_c65))
	_c65.mouse_exited.connect(_g94.bind(_c65))
	_c65.button_down.connect(_j76.bind(_c65))
	_c65.button_up.connect(_k3.bind(_c65))

func _p67(_c65: Button) -> void:
	if _c65.get_meta("is_hovering", false):
		return
	_c65.set_meta("is_hovering", true)
	
	var _l76 = get_tree().create_tween()
	_l76.set_parallel(true)
	_l76.set_ease(Tween.EASE_OUT)
	_l76.set_trans(Tween.TRANS_CUBIC)
	
	_l76.tween_property(_c65, "scale", Vector2(1.2, 1.2), 0.2)

	_l76.tween_property(_c65, "modulate:a", 1.0, 0.2)

	_l76.tween_property(_c65, "modulate", Color(1.1, 1.1, 1.1, 1.0), 0.2)

func _g94(_c65: Button) -> void:
	_c65.set_meta("is_hovering", false)
	
	var _l76 = get_tree().create_tween()
	_l76.set_parallel(true)
	_l76.set_ease(Tween.EASE_OUT)
	_l76.set_trans(Tween.TRANS_CUBIC)
	
	_l76.tween_property(_c65, "scale", Vector2.ONE, 0.2)

	_l76.tween_property(_c65, "modulate", Color(1.0, 1.0, 1.0, 0.7), 0.2)

func _j76(_c65: Button) -> void:
	var _l76 = get_tree().create_tween()
	_l76.set_ease(Tween.EASE_OUT)
	_l76.set_trans(Tween.TRANS_CUBIC)
	_l76.tween_property(_c65, "scale", Vector2(0.95, 0.95), 0.1)

func _k3(_c65: Button) -> void:
	var _k87 = Vector2(1.2, 1.2) if _c65.get_meta("is_hovering", false) else Vector2.ONE
	var _l76 = get_tree().create_tween()
	_l76.set_ease(Tween.EASE_OUT)
	_l76.set_trans(Tween.TRANS_CUBIC)
	_l76.tween_property(_c65, "scale", _k87, 0.1)

func _t12():
	if _t46:
		_t46._i35("positive", "helpful", "")

func _d47():
	_r40()

func _r40():
	var _y1 = AcceptDialog.new()
	_y1.title = "Help Us Improve"
	_y1.dialog_close_on_escape = true
	
	_y1.size = Vector2(400, 300)
	
	var _i69 = VBoxContainer.new()
	_i69.add_theme_constant_override("separation", 10)
	
	var _y24 = Label.new()
	_y24.text = "What was wrong with this response?"
	_i69.add_child(_y24)
	
	var _d62 = OptionButton.new()
	_d62.name = "CategoryOptions"
	_d62.add_item("Incorrect information")
	_d62.add_item("Wrong Godot version")
	_d62.add_item("Code doesn't work")
	_d62.add_item("Too complex")
	_d62.add_item("Not helpful")
	_d62.add_item("Other")
	_i69.add_child(_d62)
	
	var _t24 = Label.new()
	_t24.text = "Additional details (optional):"
	_i69.add_child(_t24)
	
	var _l1 = TextEdit.new()
	_l1.name = "DetailsText"
	_l1.custom_minimum_size = Vector2(0, 80)
	_l1.placeholder_text = "Describe what went wrong..."
	_i69.add_child(_l1)
	
	var _b86 = HBoxContainer.new()
	_b86.alignment = BoxContainer.ALIGNMENT_END
	
	var _a90 = Button.new()
	_a90.text = "Cancel"
	_a90.pressed.connect(_y1.hide)
	_b86.add_child(_a90)
	
	var _j42 = Button.new()
	_j42.text = "Submit Feedback"
	_j42.pressed.connect(_y41.bind(_y1))
	_b86.add_child(_j42)
	
	_i69.add_child(_b86)
	
	_y1.add_child(_i69)
	add_child(_y1)
	_y1.popup_centered()

func _y41(_k94: AcceptDialog):
	var _i69 = _k94.get_child(0)

	var _d62: OptionButton = null
	var _l1: TextEdit = null
	for _j75 in _i69.get_children():
		if _j75 is OptionButton and not _d62:
			_d62 = _j75
		elif _j75 is TextEdit and not _l1:
			_l1 = _j75
	
	var _k28 = ""
	if _d62.selected >= 0:
		_k28 = _d62.get_item_text(_d62.selected)
	
	var details = _l1.text.strip_edges()
	
	if _t46:
		_t46._i35("negative", _k28, details)

	_k94.hide()
	_k94.queue_free()

func _v21():
	if not _b9 or not _m1 or not _l27:
		return

	var _r27 = _b9.text
	var _a68 = _r27.length()
	_m1.text = "%d/500" % _a68
	
	if _a68 > 500:
		_m1.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	elif _a68 > 400:
		_m1.add_theme_color_override("font_color", Color(1.0, 0.8, 0.5))
	else:
		_m1.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	
	if _t46:
		var _i33 = _t46._g63(_r27)
		if _i33.get("valid", false):
			_l27.visible = false
			_t46._q84(_r27)
		else:
			var _x35 = _i33.get("errors", ["Unknown error"])
			_l27.text = _x35[0] if not _x35.is_empty() else "Unknown error"
			_l27.visible = true

func _s16(value: float):
	if _t46:
		var _h35 = find_child("_u50", true)
		var max_tokens = _h35.value if _h35 else 0
		_t46._a65(value, int(max_tokens))

func _o21(value: float):
	if _t46:
		var _e3 = find_child("_t16", true)
		var _h62 = _e3.value if _e3 else 0.0
		_t46._a65(_h62, int(value))

func _j56():
	if not _t46:
		return

	var _e3 = find_child("_t16", true)
	var _h35 = find_child("_u50", true)

	if _b9:
		var config = ConfigFile.new()
		if config.load("user://gdsense_settings.cfg") == OK:
			var _r27 = config.get_value("custom_rules", "rules_text", "")
			_b9.text = _r27
			if _m1:
				_m1.text = "%d/500" % _r27.length()
		else:
			pass
	else:
		pass
	if _e3:
		var config = ConfigFile.new()
		if config.load("user://gdsense_settings.cfg") == OK:
			var _h62 = config.get_value("parameters", "temperature_override", 0.0)
			_e3.value = _h62
	
	if _h35:
		var config = ConfigFile.new()
		if config.load("user://gdsense_settings.cfg") == OK:
			var max_tokens = config.get_value("parameters", "max_tokens_override", 0)
			_h35.value = max_tokens

func _h94(_k65: Array, parent: Node):
	var _g64 = HSeparator.new()
	_g64.add_theme_constant_override("separation", 8)
	parent.add_child(_g64)
	
	var _h90 = Label.new()
	_h90.text = "📚 Documentation Sources:"
	_h90.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	_h90.add_theme_font_size_override("font_size", 25)
	parent.add_child(_h90)
	
	var _s97 = VBoxContainer.new()
	_s97.add_theme_constant_override("separation", 1)
	parent.add_child(_s97)
	
	_k65.sort_custom(func(a, b): return a.get("priority", 0.0) > b.get("priority", 0.0))
	var _g82 = min(_k65.size(), 5)
	
	for i in range(_g82):
		var source = _k65[i]
		var _p33 = source.get("url", "")
		var title = source.get("title", "Godot Documentation")
		
		if not _p33.is_empty():
			var _a89 = HBoxContainer.new()
			_a89.add_theme_constant_override("separation", 8)
			_s97.add_child(_a89)
			
			var _g35 = Label.new()
			_g35.text = "•"
			_g35.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
			_g35.custom_minimum_size.x = 12
			_a89.add_child(_g35)
			
			var _y22 = Button.new()

			var _f40 = title if title.length() <= 60 else title.substr(0, 57) + "..."
			_y22.text = _f40
			_y22.tooltip_text = title  
			_y22.flat = true
			_y22.clip_text = true  
			_y22.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
			_y22.add_theme_color_override("font_hover_color", Color(0.8, 0.9, 1.0))
			_y22.add_theme_font_size_override("font_size", 20)
			_y22.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_y22.alignment = HORIZONTAL_ALIGNMENT_LEFT
			_y22.pressed.connect(_h49.bind(_p33))
			_a89.add_child(_y22)

func _h49(_p33: String):
	OS.shell_open(_p33)

func send_explain_request(function_name: String, _z29: String):
	if not _t46:
		return
	
	var _j43 = "@explain %s\n\nFunction source:\n```gdscript\n%s\n```" % [function_name, _z29]
	
	_l80(_j43)

func _k14(function_name: String, _z29: String):
	if not _i85:
		return
	
	_i85.text = ""
	
	var _j43 = "@explain %s\n\nFunction source:\n```gdscript\n%s\n```" % [function_name, _z29]
	
	_i85.text = _j43
	
	_i85.grab_focus()
	_i85.set_caret_line(_i85.get_line_count() - 1)
	_i85.set_caret_column(_i85.get_line(_i85.get_line_count() - 1).length())
	
func _exit_tree() -> void:
	_g3()

	_h59()
	_y39()
	_d36()

	if _x14:
		if _x14._q3.is_connected(_c48):
			_x14._q3.disconnect(_c48)
		if _x14._o23.is_connected(_t51):
			_x14._o23.disconnect(_t51)
		if _x14._h92.is_connected(_m6):
			_x14._h92.disconnect(_m6)
		if _x14._c58.is_connected(_u34):
			_x14._c58.disconnect(_u34)
		if _x14._p86.is_connected(_o49):
			_x14._p86.disconnect(_o49)
		if _x14._a36.is_connected(_u93):
			_x14._a36.disconnect(_u93)
		if _x14._i79.is_connected(_y89):
			_x14._i79.disconnect(_y89)
		if _x14._v1.is_connected(_c97):
			_x14._v1.disconnect(_c97)
		_x14._o76()
		_x14 = null
	_z2 = null

	if is_instance_valid(_p27):
		if _p27.pressed.is_connected(_k100):
			_p27.pressed.disconnect(_k100)
		_p27.queue_free()
		_p27 = null

	if _a58:
		if _a58._d15:
			_a58._d15.clear()
		_a58 = null

	if _y84:
		_y84._a58 = null
		_y84 = null

	if _e14:
		_e14._o76()
		_e14 = null

	if _m29:
		for _j75 in _m29.get_children():
			_j75.queue_free()
		_m29 = null

	_u17.clear()

	if _t46:
		if _t46._l54.is_connected(_o87):
			_t46._l54.disconnect(_o87)
		if _t46._k42.is_connected(_d80):
			_t46._k42.disconnect(_d80)
		if _t46._f93.is_connected(_d13):
			_t46._f93.disconnect(_d13)
		if _t46._y20.is_connected(_q92):
			_t46._y20.disconnect(_q92)
		if _t46._c11.is_connected(_l23):
			_t46._c11.disconnect(_l23)
		if _t46._s7.is_connected(_t75):
			_t46._s7.disconnect(_t75)
		if _t46._d52.is_connected(_a45):
			_t46._d52.disconnect(_a45)

	if _a97:
		_a97.free()
		_a97 = null
	
	_i86 = null
	_w75 = null
	_t46 = null
	_h41 = null

func _l20() -> void:
	if _b10:
		_b10.custom_minimum_size.y = 8
		_b10.show_percentage = false
		
		var _b37 = StyleBoxFlat.new()
		_b37.bg_color = Color(0.1, 0.1, 0.1, 0.5)
		_b37.corner_radius_top_left = 4
		_b37.corner_radius_top_right = 4
		_b37.corner_radius_bottom_left = 4
		_b37.corner_radius_bottom_right = 4
		_b10.add_theme_stylebox_override("background", _b37)
		
		_b10.mouse_entered.connect(_p90)
		_b10.mouse_exited.connect(_y79)
	
	_j31(0.0)
	
	if _y83:
		_y83.mouse_entered.connect(_p90)
		_y83.mouse_exited.connect(_y79)

func _n99() -> void:
	if not _i45:
		return

	_i45.clear()

	_i45.add_item("Commands")
	_i45.selected = 0

	_i45.add_separator()

	for _c38 in _k59:
		_i45.add_item(_c38)

	_i45.item_selected.connect(_i72)

func _n98() -> void:
	if not _t82:
		return

	_t82.clear()

	_t82.add_item(_z26[_p39])

	_r85()

	_t82.item_selected.connect(_c67)

	_s27()

func _s27() -> void:
	if not _t82 or not _i86:
		return

func _r85() -> void:
	if not _t82:
		return

	var _c61 = false
	if _t46:
		var _e61 = _t46._b18()
		if _e61 and _e61.has("features"):
			var features = _e61.get("features", {})
			_c61 = features.get("agent", false)

	var _w19 = _t82.item_count > 1

	if _c61:
		if not _w19:
			_t82.add_item(_z26[_i21])
	else:
		if _w19:
			if _t82.selected == _i21:
				_t82.selected = _p39
				_t91()
			_t82.remove_item(_i21)
func _c67(index: int) -> void:
	match index:
		_p39:
			_b93 = false

			if _n8:
				_n8.visible = true
			if _y15:
				_y15.visible = true

			if _a52:
				_a52.visible = false

			_i85.placeholder_text = "Ask me anything about Godot..."
		_i21:
			_p54()
	_i85.grab_focus()

func _n93() -> void:
	_k82()

	var _u33 = _i85.text
	
	var command_count = 0
	for _d73 in _k59:
		var _t20 = RegEx.new()
		_t20.compile(_d73 + "\\b")  
		var _f79 = _t20.search_all(_u33)
		command_count += _f79.size()
	
	if command_count != _e25:
		_e25 = command_count

		if _h27:
			_h27.stop()
			_h27.start()

func _i23() -> void:
	_x26(true)

func _j33(_c38: String, path: String) -> void:
	_x26(true)

func _x26(_p16: bool = false) -> void:
	if _v73 and not _p16:
		return

	var _u33 = _i85.text
	var _y55 = not _u33.strip_edges().is_empty()
	var _z77 = _u17.size() > 0
	
	if not _y55 and not _z77:
		_b1(0, [])
		return

	var _y68 = Time.get_ticks_msec()
	if not _p16 and not _j60.is_empty():
		var _d6 = _y68 - _j60.get("time", 0)
		if _d6 < _z73:
			var _a100 = _j60.get("tokens", 0)
			var _y30 = _j60.get("breakdown", [])
			_b1(_a100, _y30)
			return

	if _y83:
		_y83.text = "Context: Updating..."

	if _t46 and not _t46._o19().is_empty():
		var messages = []
		
		for message in _u17:
			messages.append(message)
		
		var context_metadata: Dictionary = {}
		
		if _y55:
			var _i96 = _e36(_u33, false)
			var processed_prompt = _i96.get("processed_prompt", _u33)
			
			if not processed_prompt.is_empty():
				messages.append({
					"role": "user",
					"content": processed_prompt
				})
			
			var _s56 = _i96.get("context_metadata", {})
			if _s56 == null or not _s56 is Dictionary:
				_s56 = {}
			context_metadata = _s56
		else:
			context_metadata = {}
		
		_t46._p57(messages, context_metadata)
	else:
		_z42()

func _z42() -> void:
	var _u33 = _i85.text
	var _i96 = _e36(_u33, false)
	var estimated_tokens = _i96.get("estimated_tokens", 0)
	
	var _f49 = _y8()
	var _w26 = estimated_tokens + _f49
	
	var breakdown = [
		{"name": "current_prompt", "tokens": estimated_tokens},
		{"name": "chat_history", "tokens": _f49}
	]
	
	_b1(_w26, breakdown)

func _b63(_e26: int, breakdown: Array, _m81: int = 128000) -> void:
	_s22 = _m81

	_j60 = {
		"tokens": _e26,
		"breakdown": breakdown,
		"limit": _m81,
		"time": Time.get_ticks_msec()
	}

	_b1(_e26, breakdown)

func _y8() -> int:
	var _e34 = 0
	for message in _u17:
		if message.has("content"):
			_e34 += message["content"].length()
	return _e34 / 4

func _b1(tokens: int, breakdown: Array) -> void:
	_d43 = tokens
	_f62 = breakdown

	var _d75 = float(tokens) / float(_s22) * 100.0
	if _b10:
		var _t66 = min(_d75, 100.0)
		if _t66 > 0 and _t66 < 0.5:
			_t66 = 0.5  
		_b10.value = _t66

	if _y83:
		if _d75 < 1.0 and _d75 > 0:
			_y83.text = "Context: " + str(snapped(_d75, 0.1)) + "%"
		else:
			_y83.text = "Context: " + str(int(_d75)) + "%"

		if _d75 >= 100.0:
			_y83.modulate = Color.RED
		elif _d75 >= 85.0:
			_y83.modulate = Color.YELLOW
		else:
			_y83.modulate = Color.LIGHT_GREEN
	
	_j31(_d75 / 100.0)

	if _d75 >= 95.0 and _t46:
		var _i27 = _t46._r22() if _t46 else ""
		_t46._c79.emit("critical", _i27, _d75, "")
	elif _d75 >= 90.0 and _t46:
		var _i27 = _t46._r22() if _t46 else ""
		_t46._c79.emit("high", _i27, _d75, "")
	elif _d75 >= 75.0 and _t46:
		var _i27 = _t46._r22() if _t46 else ""
		_t46._c79.emit("medium", _i27, _d75, "")

	if _d75 >= _q44 * 100.0:
		_r53.show()
		if _d75 >= 100.0:
			_r53.text = "⚠ Context capacity exceeded! Please reduce content."
			_r53.modulate = Color.RED
		else:
			_r53.text = "⚠ Context capacity at " + str(int(_d75)) + "% - consider reducing @ commands"
			_r53.modulate = Color.YELLOW
	else:
		_r53.hide()

func _a5() -> void:
	_b1(0, [])
	if _b10:
		_b10.tooltip_text = ""
	if _y83:
		_y83.tooltip_text = ""
	if _d45:
		_d45.hide()

func _j31(_l16: float) -> void:
	var color: Color
	if _l16 <= 0.6:  
		color = Color.GREEN
	elif _l16 <= 0.85:  
		color = Color.YELLOW
	else:  
		color = Color.RED
	
	var _x19 = StyleBoxFlat.new()
	_x19.bg_color = color
	_x19.corner_radius_top_left = 4
	_x19.corner_radius_top_right = 4
	_x19.corner_radius_bottom_left = 4
	_x19.corner_radius_bottom_right = 4
	
	if _b10:
		_b10.add_theme_stylebox_override("fill", _x19)

func _p90() -> void:
	var tooltip_text = "Context Usage Breakdown:\n"
	
	if _f62.size() > 0:
		for _o32 in _f62:
			if _o32 is Dictionary and _o32.has("name") and _o32.has("tokens"):
				var _p68 = _o32["tokens"]
				var _j46 = float(_p68) / float(_s22) * 100.0
				tooltip_text += str(_o32["name"]) + ": " + str(int(_j46)) + "%\n"

		tooltip_text = tooltip_text.rstrip("\n")
	else:
		tooltip_text += "No breakdown available"
	
	if _b10:
		_b10.tooltip_text = tooltip_text
	if _y83:
		_y83.tooltip_text = tooltip_text

func _y79() -> void:
	if _b10:
		_b10.tooltip_text = ""
	if _y83:
		_y83.tooltip_text = ""

func _i72(index: int) -> void:
	if index <= 1:
		return

	var _m92 = index - 2
	if _m92 >= 0 and _m92 < _k59.size():
		var _c38 = _k59[_m92]

		var _u33 = _i85.text
		var _n63 = _i85.get_caret_line()
		var caret_column = _i85.get_caret_column()

		if _n63 < _i85.get_line_count():
			var _h60 = _i85.get_line(_n63)
			var _f5 = _h60.substr(0, caret_column)
			var _u42 = _h60.substr(caret_column)

			var _w10 = _f5 + _c38 + " " + _u42
			_i85.set_line(_n63, _w10)

			_i85.set_caret_column(caret_column + _c38.length() + 1)
		else:
			_i85.text += _c38 + " "
			_i85.set_caret_column(_i85.text.length())

		_i45.selected = 0

		_x26()

		_i85.grab_focus()

func _m85(_m54: String) -> bool:
	var _p78 = [
		"truncated",
		"trimmed",
		"shortened",
		"context limit",
		"content limited"
	]
	
	var _w37 = _m54.to_lower()
	for _c84 in _p78:
		if _c84 in _w37:
			return true
	
	return false

func _b8(message: String) -> void:
	_d45.text = "ℹ " + message
	_d45.show()
	
	var _v72 = Timer.new()
	add_child(_v72)
	_v72.timeout.connect(func(): 
		_d45.hide()
		_v72.queue_free()
	)
	_v72.one_shot = true
	_v72.start(10.0)

func _a3(_y43: String) -> String:
	var _i62 = _y43.to_lower()
	
	if "token" in _i62 and ("limit" in _i62 or "exceed" in _i62):
		return "Your request is too large. Try reducing the amount of context or splitting into smaller requests."
	elif "rate limit" in _i62:
		return "You're sending requests too quickly. Please wait a moment before trying again."
	elif "unauthorized" in _i62 or "invalid api key" in _i62:
		return "Your API key is invalid or has expired. Please check your settings."
	elif "network" in _i62 or "connection" in _i62:
		return "Unable to connect to the AI service. Please check your internet connection."
	elif "timeout" in _i62:
		return "The request took too long to process. Please try again with a smaller request."
	elif "model" in _i62 and "not found" in _i62:
		return "The selected AI model is not available. Please try a different model."
	else:
		return _y43  

func _n37(_y90: Dictionary) -> void:
	_z70()

	_q38()

	_s33()

	_r85()

	_h54(_y90)

func _u48(_c51: String) -> String:
	if _c51.is_empty():
		return ""

	var _y11 = _c51.split("T")[0] if "T" in _c51 else _c51
	var _m27 = _y11.split("-")

	if _m27.size() < 3:
		return _c51  

	var year = _m27[0]
	var month = int(_m27[1]) if _m27[1].is_valid_int() else 0
	var day = int(_m27[2]) if _m27[2].is_valid_int() else 0

	if month < 1 or month > 12 or day < 1 or day > 31:
		return _c51  

	var _y87 = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
					   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

	return "%s %d, %s" % [_y87[month - 1], day, year]

func _r66(_h18: String, _e47: String, _d75: float, _y91: String = "") -> void:
	var _o12 = _a32()
	if _o12:
		var title = ""
		var message = ""
		var _w20 = _f34._x62.WARNING

		var _m38 = "credits"

		match _h18:
			"low":  
				title = "Usage Notice"
				message = "You've used %d%% of your %s for this period." % [int(_d75), _m38]
				_w20 = _f34._x62.INFO
			"medium":  
				title = "Usage Alert"
				message = "Heads up: you've used %d%% of your %s this period." % [int(_d75), _m38]
			"high":    
				title = "Usage Warning"
				message = "You've used %d%% of your %s. Consider switching models or upgrading." % [int(_d75), _m38]
				_w20 = _f34._x62.WARNING
			"critical": 
				title = "Critical Usage"
				message = "Critical: only %d%% of your %s remain." % [int(100 - _d75), _m38]
				_w20 = _f34._x62.ERROR

		if not _y91.is_empty():
			var _k93 = _u48(_y91)
			message += " Usage resets on %s." % _k93

		if _t46:
			var _s76 = _t46._h26()
			if _s76 != "ULTRA" and _s76 != "BETA_FREE":
				message += " Upgrade: gdsense.com/pricing"

		_o12._t97(title, message, _w20, 8.0)  

	if _h18 == "critical" and _i12:
		var _c20 = "⚠️ CRITICAL: %d%% of credits used" % [int(_d75)]
		_i12.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))  
		_i12.text = _c20

		await get_tree().create_timer(10.0).timeout
		if is_instance_valid(_i12):
			_i12.remove_theme_color_override("font_color")

			if _t46 and _t46._d32():
				_i12.text = "API Key Loaded"

				var _e61 = _t46._b18()
				if _e61 and _e61.has("tier"):
					_h54(_e61)
			else:
				_i12.text = "No API Key"

func _a45(message: String) -> void:
	var _o12 = _a32()
	if _o12:
		_o12._t97("Context Truncated", message, _f34._x62.WARNING, 5.0)

func _s33() -> void:
	if not _t46:
		return

	var _p20 = _t46._p20()

	if _e5:
		_e5.disabled = not _p20
		if not _p20:
			_e5.button_pressed = false
			_e5.tooltip_text = "Refactor is not available in Free tier"
		else:
			_e5.tooltip_text = "Show Refactor Buttons Above Functions"

	if _h41 and _h41.has_method("update_refactor_button_availability"):
		_h41.update_refactor_button_availability(_p20)

func _a94() -> void:
	if _b40:
		return  

	_b40 = PanelContainer.new()
	_b40.name = "UpdateBanner"
	_b40.visible = false

	var _f54 = StyleBoxFlat.new()
	if _i86:
		var _c92 = _i86.get_editor_settings()
		if _c92:
			var _m31 = _c92.get_setting("interface/theme/base_color")
			var _g75 = _c92.get_setting("interface/theme/accent_color")
			_f54.bg_color = _g75.lerp(_m31, 0.8)  
		else:
			_f54.bg_color = Color(0.2, 0.4, 0.6, 1.0)  
	else:
		_f54.bg_color = Color(0.2, 0.4, 0.6, 1.0)  

	_f54.set_corner_radius_all(4)
	_f54.set_content_margin_all(8)
	_b40.add_theme_stylebox_override("panel", _f54)

	var _j84 = HBoxContainer.new()
	_j84.add_theme_constant_override("separation", 8)

	var _c35 = Label.new()
	_c35.name = "UpdateMessage"
	_c35.text = "Update Available"
	_c35.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_j84.add_child(_c35)

	var _r23 = Label.new()
	_r23.name = "DownloadLink"
	_r23.text = "Download at gdsense.com"
	_r23.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))  
	_j84.add_child(_r23)

	var _s6 = Button.new()
	_s6.name = "DismissButton"
	_s6.text = "X"
	_s6.tooltip_text = "Dismiss update notification"
	_s6.custom_minimum_size = Vector2(24, 24)
	_s6.flat = true
	_s6.pressed.connect(_t42)
	_j84.add_child(_s6)

	_b40.add_child(_j84)

	var _g87 = get_node_or_null("MarginContainer/TabContainer/Chat")
	if _g87:
		var _v100 = _g87.get_child(0) if _g87.get_child_count() > 0 else null
		if _v100 and _v100 is VBoxContainer:
			_v100.add_child(_b40)
			_v100.move_child(_b40, 0)  
		else:
			_g87.add_child(_b40)
	else:
		add_child(_b40)

func _w35(_d59: String, _z80: String) -> void:
	if _j34:
		return

	if not _b40:
		_a94()

	var _c35 = _b40.find_child("_e78", true)
	if _c35:
		_c35.text = "Update Available: v%s (you have v%s)" % [_d59, _z80]

	_b40.visible = true

func _t42() -> void:
	_j34 = true
	if _b40:
		_b40.visible = false

func _h54(_y90: Dictionary) -> void:
	var _s76 = _y90.get("tier", "Unknown")

	if _i12:
		var _u33 = _i12.text
		if "API Key Loaded" in _u33:
			if _t46 and _t46._t60():
				var env = _t46._o50()
				_i12.text = "API Key Loaded (%s) - %s Tier" % [env.capitalize(), _s76]
			else:
				_i12.text = "API Key Loaded - %s Tier" % _s76

	_d87()

func _d87() -> void:
	if _p27:
		return  

	if not _i12 or not _t46:
		return

	_p27 = Button.new()
	_p27.text = "↻"  
	_p27.tooltip_text = "Refresh tier info"
	_p27.flat = true
	_p27.custom_minimum_size = Vector2(24, 24)
	_p27.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	_y10(_p27)

	var parent = _i12.get_parent()
	if parent:
		var _u49 = _i12.get_index()
		parent.add_child(_p27)
		parent.move_child(_p27, _u49 + 1)

	_p27.pressed.connect(_k100)

func _k100() -> void:
	if _t46:
		_t46._m73()
func _g56(model: String) -> String:
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

func _a32() -> _f34:
	var _o12 = find_child("_f34", true)
	if _o12 and _o12 is _f34:
		return _o12

	var _a57 = preload("res://addons/gdsense/scenes/_d77.tscn")
	if _a57:
		_o12 = _a57.instantiate()

		if _a97:
			var _i86 = _a97.get_editor_interface()
			if _i86:
				_o12._a87(_i86)
		add_child(_o12)

		_o12.z_index = 1000
		return _o12

	return null

func _l97():
	if not _t86:
		return

	_o1()
	_l86()
	_s38()

func _o1():
	if not _t86 or not _h58:
		return

	var recent_chats = _t86._s28()

	_h58.clear()
	_s18 = -1

	for _w90 in recent_chats:
		var _l15 = _w90._e86()
		var timestamp = _w90._c45()
		var _p36 = "%s - %s" % [_l15, timestamp]

		var index = _h58.add_item(_p36)
		_h58.set_item_metadata(index, _w90.timestamp)
		_h58.set_item_tooltip(index, _w90._k12(80))

	_e21()
	_v17()

func _l86():
	if not _t86 or not _x70:
		return

	var favorite_chats = _t86._l96()

	_x70.clear()
	_i61 = -1

	for _w90 in favorite_chats:
		var _l15 = _w90._e86()
		var timestamp = _w90._c45()
		var _p36 = "★ %s - %s" % [_l15, timestamp]

		var index = _x70.add_item(_p36)
		_x70.set_item_metadata(index, _w90.timestamp)
		_x70.set_item_tooltip(index, _w90._k12(80))

	_a74()
	_v17()

func _s38():
	if not _t86 or not _k20:
		return

	var _v68 = _t86._s28().size()
	var _w76 = _t86._l96().size()

	_k20.text = "Recent: %d | Favorites: %d" % [_v68, _w76]

	var font_color = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_k20.add_theme_color_override("font_color", font_color)

func _s65(index: int):
	if index < 0 or not _t86:
		return

	_s18 = index
	var timestamp = _h58.get_item_metadata(index)
	var _w90 = _t86._c32(timestamp)

	if _w90:
		_b56(_w90)

	_v17()

func _p81(index: int):
	if index < 0 or not _t86:
		return

	_i61 = index
	var timestamp = _x70.get_item_metadata(index)
	var _w90 = _t86._c32(timestamp)

	if _w90:
		_v63(_w90)

	_v17()

func _b56(_w90: _g31._x82):
	if not _w90 or not _f61 or not _f65 or not _v30:
		return

	var _i63 = _w90._u22()
	_f61.text = "%s - %s (%d exchange%s)" % [
		_w90._e86(),
		_w90._c45(),
		_i63,
		"s" if _i63 != 1 else ""
	]

	_f65.bbcode_enabled = true
	_f65.text = _l64(_w90)

	var _z98 = _w90._o96 if not _w90._o96.is_empty() else "Unknown"
	_v30.text = "[Model: %s]\n[Session ID: %s]" % [_z98, _w90.session_id]

func _v63(_w90: _g31._x82):
	if not _w90 or not _g7 or not _l61 or not _g52:
		return

	var _i63 = _w90._u22()
	_g7.text = "%s - %s (%d exchange%s)" % [
		_w90._e86(),
		_w90._c45(),
		_i63,
		"s" if _i63 != 1 else ""
	]

	_l61.bbcode_enabled = true
	_l61.text = _l64(_w90)

	var _z98 = _w90._o96 if not _w90._o96.is_empty() else "Unknown"
	_g52.text = "[Model: %s]\n[Session ID: %s]" % [_z98, _w90.session_id]

func _l64(_w90: _g31._x82) -> String:
	var _o55 = ""
	
	for _k17 in _w90.exchanges:
		if not _k17 is Dictionary:
			continue
			
		var _o62 = _k17.get("user_message", "")
		
		if _o62.begins_with("@explain"):
			var _o70 = _o62.find("\n")
			if _o70 != -1:
				_o62 = _o62.substr(0, _o70) + " (code attached)"
		
		var _j71 = _y16.to_html()
		_o55 += "[b][color=#%s]You:[/color][/b]\n" % _j71
		_o55 += _a53(_o62) + "\n\n"
		
		var _a14 = _k17.get("ai_response", "")
		var _i5 = _h73.to_html()
		_o55 += "[b][color=#%s]GDSense:[/color][/b]\n" % _i5
		
		var _m27 = _a14.split("```")

		var _w66 = get_theme_color("base_color", "Editor")
		var _q40 = _w66.darkened(0.2) if _w66.get_luminance() > 0.5 else _w66.lightened(0.1)
		var _c57 = _q40.to_html()
		
		for i in range(_m27.size()):
			var _j95 = _m27[i]
			if i % 2 == 0:
				_o55 += _a53(_j95)
			else:
				var _n26 = _j95.find("\n")
				var _l66 = _j95
				if _n26 != -1:
					_l66 = _j95.substr(_n26 + 1)
				
				var _b68 = _q95(_l66)

				_o55 += "\n[bgcolor=#%s]%s[/bgcolor]\n" % [_c57, _b68]
		
		_o55 += "\n\n"
		
		_o55 += "[color=#666666]────────────────────────────────[/color]\n\n"
		
	return _o55

func _e21():
	if _f61:
		_f61.text = "Select a chat to preview"
	if _f65:
		_f65.text = "Select a chat to view"
	if _v30:
		_v30.text = "Select a chat to view"

func _a74():
	if _g7:
		_g7.text = "Select a favorite to preview"
	if _l61:
		_l61.text = "Select a favorite chat to view"
	if _g52:
		_g52.text = "Select a favorite chat to view"

func _a53(text: String) -> String:
	var _w30 = text
	_w30 = _w30.replace("[", "\\[")
	_w30 = _w30.replace("]", "\\]")
	return _w30

func _v17():
	var _j86 = _s18 >= 0
	if _h99:
		_h99.disabled = not _j86
	if _o95:
		_o95.disabled = not _j86
	if _o17:
		_o17.disabled = not _j86
	if _c91:
		_c91.disabled = not _j86

	var _e79 = _i61 >= 0
	if _q52:
		_q52.disabled = not _e79
	if _k43:
		_k43.disabled = not _e79
	if _b82:
		_b82.disabled = not _e79
	if _z78:
		_z78.disabled = not _e79

func _n33():
	if _s18 < 0 or not _t86:
		return

	var timestamp = _h58.get_item_metadata(_s18)
	var _w90 = _t86._c32(timestamp)

	if _w90:
		_w8(_w90)

func _e98():
	if _s18 < 0 or not _t86:
		return

	var timestamp = _h58.get_item_metadata(_s18)

	if _t86._t25(timestamp):
		_l97()

func _b2():
	if _s18 < 0 or not _t86:
		return

	var timestamp = _h58.get_item_metadata(_s18)
	var _w90 = _t86._c32(timestamp)

	if _w90:
		_w9 = timestamp
		_j40 = false
		_y21.text = _w90.custom_name
		_r96.popup_centered()

func _g67():
	if _s18 < 0 or not _t86:
		return

	var timestamp = _h58.get_item_metadata(_s18)

	if _t86._j20(timestamp):
		_l97()

func _j23():
	if _i61 < 0 or not _t86:
		return

	var timestamp = _x70.get_item_metadata(_i61)
	var _w90 = _t86._c32(timestamp)

	if _w90:
		_w8(_w90)

func _u8():
	if _i61 < 0 or not _t86:
		return

	var timestamp = _x70.get_item_metadata(_i61)

	if _t86._z90(timestamp):
		_l97()

func _m87():
	if _i61 < 0 or not _t86:
		return

	var timestamp = _x70.get_item_metadata(_i61)
	var _w90 = _t86._c32(timestamp)

	if _w90:
		_w9 = timestamp
		_j40 = true
		_y21.text = _w90.custom_name
		_r96.popup_centered()

func _i17():
	if _i61 < 0 or not _t86:
		return

	var timestamp = _x70.get_item_metadata(_i61)

	if _t86._j20(timestamp):
		_l97()

func _b28():
	if not _t86 or _w9.is_empty():
		return

	var _x55 = _y21.text.strip_edges()

	if _t86._i58(_w9, _x55):
		_l97()

	_w9 = ""
	_j40 = false

func _l36():
	if not _t86:
		return

	_t86._o59()
	_t86._g15()
	_l97()

func _t2():
	if not _t86:
		return

	_t86._m11()
	_t86._g15()
	_l97()

func _r49():
	var _p92: _g31._x82 = null

	if _h58 and _h58.get_selected_items().size() > 0:
		var _c74 = _h58.get_selected_items()[0]
		var recent_chats = _t86._s28()
		if _c74 < recent_chats.size():
			_p92 = recent_chats[_c74]

	elif _x70 and _x70.get_selected_items().size() > 0:
		var _c74 = _x70.get_selected_items()[0]
		var favorite_chats = _t86._l96()
		if _c74 < favorite_chats.size():
			_p92 = favorite_chats[_c74]

	if not _p92:
		_d23("Please select a chat session to export", Color(1, 0.7, 0.3))
		return

	var filename = "gdsense_session_%s.json" % _p92.session_id
	_l44.current_file = filename
	_l44.current_path = "user://" + filename
	_l44.popup_centered()

func _f7(path: String):
	var _p92: _g31._x82 = null

	if _h58 and _h58.get_selected_items().size() > 0:
		var _c74 = _h58.get_selected_items()[0]
		var recent_chats = _t86._s28()
		if _c74 < recent_chats.size():
			_p92 = recent_chats[_c74]
	elif _x70 and _x70.get_selected_items().size() > 0:
		var _c74 = _x70.get_selected_items()[0]
		var favorite_chats = _t86._l96()
		if _c74 < favorite_chats.size():
			_p92 = favorite_chats[_c74]

	if not _p92:
		push_error("[GDSense] Failed to export: No session selected")
		return

	var _x90 = {
		"format_version": "1.0",
		"exported_at": Time.get_datetime_string_from_system(),
		"session": _t86._d22(_p92)
	}

	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		var _w7 = JSON.stringify(_x90, "\t")
		file.store_string(_w7)
		file.close()

		_d23("Session exported successfully", Color(0.3, 1, 0.5))

	else:
		push_error("[GDSense] Failed to write export file: %s" % path)
		_d23("Export failed: Could not write file", Color(1, 0.3, 0.3))

func _t85():
	_o20.current_path = "user://"
	_o20.popup_centered()

func _n61(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("[GDSense] Failed to open import file: %s" % path)
		_d23("Import failed: Could not open file", Color(1, 0.3, 0.3))
		return

	var _w7 = file.get_as_text()
	file.close()

	var json = JSON.new()
	var _q58 = json.parse(_w7)

	if _q58 != OK:
		push_error("[GDSense] Failed to parse import file: %s" % json.get_error_message())
		_d23("Import failed: Invalid JSON format", Color(1, 0.3, 0.3))
		return

	var _h61 = json.data

	if not _h61 is Dictionary:
		push_error("[GDSense] Import data is not a Dictionary")
		_d23("Import failed: Invalid data structure", Color(1, 0.3, 0.3))
		return

	if not _h61.has("format_version"):
		push_error("[GDSense] Import file missing format_version")
		_d23("Import failed: Missing format version", Color(1, 0.3, 0.3))
		return

	if _h61["format_version"] != "1.0":
		push_error("[GDSense] Unsupported format version: %s" % _h61["format_version"])
		_d23("Import failed: Unsupported format version", Color(1, 0.3, 0.3))
		return

	if not _h61.has("session"):
		push_error("[GDSense] Import file missing session data")
		_d23("Import failed: Missing session data", Color(1, 0.3, 0.3))
		return

	var _a93 = _h61["session"]
	if not _a93 is Dictionary:
		push_error("[GDSense] Session data is not a Dictionary")
		_d23("Import failed: Invalid session format", Color(1, 0.3, 0.3))
		return

	var _f71 = ["exchanges", "timestamp", "session_id"]
	for _w86 in _f71:
		if not _a93.has(_w86):
			push_error("[GDSense] Session missing required field: %s" % _w86)
			_d23("Import failed: Incomplete session data", Color(1, 0.3, 0.3))
			return

	if not _a93["exchanges"] is Array:
		push_error("[GDSense] Session exchanges is not an Array")
		_d23("Import failed: Invalid exchanges format", Color(1, 0.3, 0.3))
		return

	if _a93["exchanges"].is_empty():
		push_error("[GDSense] Session has no exchanges")
		_d23("Import failed: Empty session", Color(1, 0.3, 0.3))
		return

	for _k17 in _a93["exchanges"]:
		if not _k17 is Dictionary:
			push_error("[GDSense] Invalid exchange format")
			_d23("Import failed: Invalid exchange data", Color(1, 0.3, 0.3))
			return

		if not _k17.has("user_message") or not _k17.has("ai_response"):
			push_error("[GDSense] Exchange missing user_message or ai_response")
			_d23("Import failed: Incomplete exchange", Color(1, 0.3, 0.3))
			return

		if _k17["user_message"].length() > 100000 or _k17["ai_response"].length() > 500000:
			push_error("[GDSense] Exchange messages too long (possible attack)")
			_d23("Import failed: Messages exceed size limits", Color(1, 0.3, 0.3))
			return

		if _k17.has("enhanced_user_message") and _k17["enhanced_user_message"].length() > 200000:
			push_error("[GDSense] Enhanced message too long (possible attack)")
			_d23("Import failed: Messages exceed size limits", Color(1, 0.3, 0.3))
			return

	var _h78 = _t86._c32(_a93["timestamp"])
	if _h78:
		_d23("Warning: Session may already exist", Color(1, 0.7, 0.3))

	var _e31 = _t86._m100(_a93)
	if not _e31:
		push_error("[GDSense] Failed to convert imported data to ChatEntry")
		_d23("Import failed: Could not create session", Color(1, 0.3, 0.3))
		return

	_t86._b79.push_front(_e31)

	while _t86._b79.size() > _g31._p82:
		_t86._b79.pop_back()

	_t86._g15()

	_l97()

	_d23("Session imported successfully (%d exchanges)" % _e31._u22(), Color(0.3, 1, 0.5))

func _d23(message: String, color: Color):
	if color.r > color.g and color.r > color.b:
		pass

	else:
		pass

func _m48(message: String) -> String:
	var _r5 = _g31._x82._h30(message)
	if _r5 != message and OS.is_debug_build():
		pass

	return _r5

func _w8(_w90: _g31._x82):
	if not _w90:
		return

	_u17.clear()
	_g3()
	for _j75 in _m29.get_children():
		_j75.queue_free()
	
	var _z13 = _w90._x46()
	var _k51 = _w90._d17()
	_x60 = _z13 if _z13 else {}

	if _k51 and not _k51.is_empty():
		_v94 = _k51
	else:
		_v94.clear()  
	_e94()

	for _k17 in _w90.exchanges:
		if not _k17 is Dictionary:
			continue
		if not _k17.has("user_message") or not _k17.has("ai_response"):
			continue

		var _d81 = _m48(_k17["user_message"])

		if _d81.begins_with("@explain"):
			var _o70 = _d81.find("\n")
			if _o70 != -1:
				_d81 = _d81.substr(0, _o70) + " (code attached)"

		_y72(_d81)
		_e88(_k17["ai_response"], [])

		var _k29 = _k17.get("enhanced_user_message", _k17["user_message"])

		var _y43 = _m48(_k17["user_message"])

		_u17.append({"role": "user", "content": _k29, "original_content": _y43})
		var _a14 = {"role": "agent", "content": _k17["ai_response"]}

		if _k17.has("thought_signature") and not _k17["thought_signature"].is_empty():
			_a14["thought_signature"] = _k17["thought_signature"]
		_u17.append(_a14)

	if _q61:
		_q61.current_tab = 0

	_u44.call_deferred()

func _v41():
	var _e9 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	
	var _z16 = func(_m88: Node):
		if not _m88: return
		for _j75 in _m88.get_children():
			if _j75 is Label:
				if "Full Conversation" in _j75.text or "Session Info" in _j75.text:
					_j75.add_theme_color_override("font_color", _e9)
	
	if _f65:
		_z16.call(_f65.get_parent())
		
	if _l61:
		_z16.call(_l61.get_parent())

func _k71():
	_u84()
	_v41()
	_v12()
	
	if _t86:
		if _s18 >= 0:
			_s65(_s18)
		if _i61 >= 0:
			_p81(_i61)

func _v12():
	var _x99 = get_node_or_null("MarginContainer/TabContainer/Settings/_k1/VBoxContainer")
	if not _x99: return

	var _g41 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	var _m49 = Color(_g41, 0.6)

	var _l24 = func(node: Node, _v67: Callable):
		if node is Label:
			if node.has_meta("secondary"):
				node.add_theme_color_override("font_color", _m49)
			else:
				node.add_theme_color_override("font_color", _g41)

		for _j75 in node.get_children():
			_v67.call(_j75, _v67)

	_l24.call(_x99, _l24)

func _w77() -> void:
	_x14 = _c24.new()
	_x14.initialize(self, _t46)
	_x14._q3.connect(_c48)
	_x14._o23.connect(_t51)
	_x14._h92.connect(_m6)
	_x14._c58.connect(_u34)
	_x14._p86.connect(_o49)
	_x14._a36.connect(_u93)
	_x14._i79.connect(_y89)
	_x14._v1.connect(_c97)

	_z2 = _h17.new()
	_z2.initialize(_i86)

	_y32()

func _y32() -> void:
	_a37 = VBoxContainer.new()
	_a37.name = "AgentUIContainer"
	_a37.visible = false
	_a37.add_theme_constant_override("separation", 4)

	_p30 = Label.new()
	_p30.text = "Agent: Initializing..."
	_p30.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_a37.add_child(_p30)

	_t5 = ProgressBar.new()
	_t5.min_value = 0
	_t5.max_value = 100
	_t5.value = 0
	_t5.show_percentage = false
	_t5.custom_minimum_size = Vector2(0, 8)
	_a37.add_child(_t5)

	var _g87 = get_node_or_null("MarginContainer/TabContainer/Chat")
	if _g87:
		var _v100 = _g87.get_child(0) if _g87.get_child_count() > 0 else null
		if _v100 and _v100 is VBoxContainer:
			var _i36 = -1
			for i in range(_v100.get_child_count()):
				var _j75 = _v100.get_child(i)
				if _j75.name == "InputContainer" or (_j75 is HBoxContainer and _j75.get_node_or_null("_h22") != null):
					_i36 = i
					break

			if _i36 >= 0:
				_v100.add_child(_a37)
				_v100.move_child(_a37, _i36)
			else:
				_v100.add_child(_a37)
		else:
			add_child(_a37)
	else:
		add_child(_a37)

func _p54() -> void:
	_b93 = true

	if _t82 and _t82.item_count > _i21 and _t82.selected != _i21:
		_t82.selected = _i21

	if _n8:
		_n8.visible = false
	if _y15:
		_y15.visible = false

	if _a52:
		_a52.visible = true

	_i85.placeholder_text = "[Agent Mode] Describe your task..."

	_e16("Agent mode enabled. Describe your task and press Enter to start.")

func _t91() -> void:
	_b93 = false

	_x4.clear()
	_x88 = false

func _b69() -> void:
	if _a37:
		_a37.visible = true
	if _t5:
		_t5.value = 0
	if _p30:
		_p30.text = "Agent: Starting..."

	_r68()

func _v71() -> void:
	if _a37:
		_a37.visible = false

func _r68() -> void:
	_y39()  

	_t55 = HBoxContainer.new()
	_t55.name = "AgentCancelContainer"
	_t55.alignment = BoxContainer.ALIGNMENT_CENTER

	_w27 = Button.new()
	_w27.text = "Cancel Agent"
	_w27.pressed.connect(_b11)
	_t55.add_child(_w27)

	var _g87 = get_node_or_null("MarginContainer/TabContainer/Chat")
	if _g87:
		var _v100 = _g87.get_child(0) if _g87.get_child_count() > 0 else null
		if _v100 and _v100 is VBoxContainer:
			var _i36 = -1
			for i in range(_v100.get_child_count()):
				var _j75 = _v100.get_child(i)
				if _j75.name == "InputContainer" or (_j75 is HBoxContainer and _j75.get_node_or_null("_h22") != null):
					_i36 = i
					break

			if _i36 >= 0:
				_v100.add_child(_t55)
				_v100.move_child(_t55, _i36)
			else:
				_v100.add_child(_t55)
		else:
			add_child(_t55)
	else:
		add_child(_t55)

func _y39() -> void:
	if _t55 and is_instance_valid(_t55):
		_t55.queue_free()
		_t55 = null
		_w27 = null

func _f69() -> void:
	_d36()  

	_o7 = HBoxContainer.new()
	_o7.name = "AgentForceResetContainer"
	_o7.alignment = BoxContainer.ALIGNMENT_CENTER
	_o7.add_theme_constant_override("separation", 8)

	var _c40 = Button.new()
	_c40.text = "Reset Agent"
	_c40.tooltip_text = "Force reset all agent state and start fresh"
	_c40.pressed.connect(_b32)
	_o7.add_child(_c40)

	var _g87 = get_node_or_null("MarginContainer/TabContainer/Chat")
	if _g87:
		var _v100 = _g87.get_child(0) if _g87.get_child_count() > 0 else null
		if _v100 and _v100 is VBoxContainer:
			var _i36 = -1
			for i in range(_v100.get_child_count()):
				var _j75 = _v100.get_child(i)
				if _j75.name == "InputContainer" or (_j75 is HBoxContainer and _j75.get_node_or_null("_h22") != null):
					_i36 = i
					break

			if _i36 >= 0:
				_v100.add_child(_o7)
				_v100.move_child(_o7, _i36)
			else:
				_v100.add_child(_o7)
		else:
			add_child(_o7)
	else:
		add_child(_o7)

func _d36() -> void:
	if _o7 and is_instance_valid(_o7):
		_o7.queue_free()
		_o7 = null

func _b32() -> void:
	if _x14 and _x14.is_active():
		_x14._x83()

	_v71()
	_y39()
	_h59()
	_d36()
	_t91()
	_u51()

	_x4.clear()
	_x88 = false

	_e16("Agent state reset. You can start a new task.", false)

func _e16(text: String, _p40: bool = false) -> void:
	var _w53 = PanelContainer.new()
	_w53.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_w53.add_theme_constant_override("margin_bottom", _t45.message_gap)

	if not _h2:
		_u84()
	_w53.add_theme_stylebox_override("panel", _h2)

	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.selection_enabled = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.fit_content = true
	label.scroll_active = false
	label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())

	var _u18 = Color.RED if _p40 else _h73
	label.add_theme_color_override("default_color", _u18)
	label.text = "[b][Agent][/b] " + _a53(text)

	_w53.add_child(label)
	_m29.add_child(_w53)
	_u44.call_deferred()

func _j69(_n17: String, details: Array, _p40: bool = false) -> void:
	var _w53 = PanelContainer.new()
	_w53.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_w53.add_theme_constant_override("margin_bottom", _t45.message_gap)

	if not _h2:
		_u84()
	_w53.add_theme_stylebox_override("panel", _h2)

	var _v100 = VBoxContainer.new()
	_v100.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var _u92 = HBoxContainer.new()
	_u92.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var _i31 = Button.new()
	_i31.flat = true
	_i31.text = "▶"  
	_i31.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_i31.tooltip_text = "Click to expand/collapse"

	_y10(_i31)
	_u92.add_child(_i31)

	var _m83 = RichTextLabel.new()
	_m83.bbcode_enabled = true
	_m83.selection_enabled = true
	_m83.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_m83.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_m83.fit_content = true
	_m83.scroll_active = false
	_m83.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var _u18 = Color.RED if _p40 else _h73
	_m83.add_theme_color_override("default_color", _u18)
	_m83.text = "[b][Agent][/b] " + _a53(_n17)
	_u92.add_child(_m83)

	_v100.add_child(_u92)

	var _v36 = VBoxContainer.new()
	_v36.visible = false
	_v36.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_v36.add_theme_constant_override("separation", 4)

	var _p59 = MarginContainer.new()
	var indent_size = _b74() * 2  
	_p59.add_theme_constant_override("margin_left", indent_size)
	_p59.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var _u36 = VBoxContainer.new()
	_u36.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	for _o32 in details:
		var _q88 = Label.new()
		_q88.text = _o32
		_q88.add_theme_color_override("font_color", _u18.darkened(0.15))

		_y10(_q88)
		_u36.add_child(_q88)

	_p59.add_child(_u36)
	_v36.add_child(_p59)
	_v100.add_child(_v36)

	_i31.pressed.connect(func():
		_v36.visible = not _v36.visible
		_i31.text = "▼" if _v36.visible else "▶"
		_u44.call_deferred()
	)

	_w53.add_child(_v100)
	_m29.add_child(_w53)
	_u44.call_deferred()

func _y10(_r29: Control) -> void:
	if _a97:
		var _i86 = _a97.get_editor_interface()
		if _i86:
			var theme = _i86.get_editor_theme()
			if theme:
				var _q80 = theme.get_font("main", "EditorFonts")
				if _q80:
					_r29.add_theme_font_override("font", _q80)
				var _n62 = theme.get_font_size("main_size", "EditorFonts")
				if _n62 > 0:
					_r29.add_theme_font_size_override("font_size", _n62)

func _b74() -> int:
	if _a97:
		var _i86 = _a97.get_editor_interface()
		if _i86:
			var theme = _i86.get_editor_theme()
			if theme:
				var _n62 = theme.get_font_size("main_size", "EditorFonts")
				if _n62 > 0:
					return _n62
	return 14  

func _c48(session_id: String) -> void:
	_e16("Agent session started. Analyzing your request...")
func _t51(status: Dictionary) -> void:
	var progress = status.get("progress_percent", 0)
	var _s57 = status.get("status_message", "Processing...")

	if _s57 == null:
		_s57 = "Processing..."

	if _t5:
		_t5.value = progress
	if _p30:
		_p30.text = "Agent: " + _s57

	if status.has("tier"):
		var _s76 = status.get("tier", "")
		if _s76 is String and not _s76.is_empty() and _t46:
			_t46._m44(_s76)

func _m6(_a29: Array) -> void:
	if _a29.is_empty():
		return

	var _d89: Array = []
	var _k37: Array = []

	for _z7 in _a29:
		var _w25 = _z7.get("tool_name", "")
		var _l73 = _z2._l73(_w25)
		if _l73:
			_k37.append(_z7)
		else:
			_d89.append(_z7)

	for _z7 in _d89:
		var _w25 = _z7.get("tool_name", "")
		var _n77 = _z7.get("tool_call_id", "")
		var _n73 = _z7.get("parameters", {})
		if _n73 == null:
			_n73 = {}

		var _v42 = _z2._p65(_w25, _n73)
		_x14._s61(_n77, true, _v42)
		_c73(_w25, _n73, _v42)

	for _z7 in _k37:
		_x4.append(_z7)

	if not _x88 and _x4.size() > 0:
		_o36()

func _o36() -> void:
	if _x4.is_empty():
		_x88 = false
		return

	_x88 = true
	var _z7 = _x4.pop_front()
	var _w25 = _z7.get("tool_name", "")
	var _n77 = _z7.get("tool_call_id", "")

	var _k94 = _o22.new()
	_k94._a87(_i86)
	_k94._u41(_z7)
	_k94._u32.connect(_c86.bind(_n77))
	_k94._y81.connect(_b80.bind(_n77))
	add_child(_k94)
	_k94.popup_centered()

func _c86(_z7: Dictionary, _x12: Dictionary, _n77: String) -> void:
	var _w25 = _z7.get("tool_name", "")
	if _w25 == null:
		_w25 = ""
	var _n73 = _z7.get("parameters", {})
	if _n73 == null:
		_n73 = {}
	var _v42 = _z2._p65(_w25, _n73)
	_x14._s61(_n77, true, _v42)
	_c73(_w25, _n73, _v42)

	_o36()

func _b80(_z7: Dictionary, _g45: String, _n77: String) -> void:
	var _w25 = _z7.get("tool_name", "")
	if _w25 == null:
		_w25 = ""
	var _n73 = _z7.get("parameters", {})
	if _n73 == null:
		_n73 = {}
	_x14._s61(_n77, false, {}, _g45)

	var path = _n73.get("path", "")
	if path == null:
		path = ""
	if not path.is_empty():
		_e16("Rejected " + _w25 + ": " + path)
	else:
		_e16("Rejected: " + _w25)

	_o36()

func _u34(message: String) -> void:
	_e88(message, [])

	_e16("Tip: Reopen modified scenes or reload the project to see changes")
	_v71()
	_y39()  
	_h59()
	_d36()  
	_t91()
	_u51()

func _o49(error: String) -> void:
	_e16("Agent failed: " + error, true)
	_v71()

	_f69()
	_h59()

func _u93() -> void:
	_e16("Agent cancelled")
	_v71()
	_y39()  
	_h59()
	_d36()  
	_t91()
	_u51()

func _y89(session_id: String, message: String) -> void:
	var _q85 = message + " You can continue to allow more processing."
	_e16(_q85, true)
	_m10()
	_v71()
	_y39()  

func _c97(message: String, _a27: String) -> void:
	if message.is_empty() and _a27.is_empty():
		return

	if not message.is_empty():
		_e88(message, [])

	if not _a27.is_empty():
		_r17(_a27)

func _r17(_a27: String) -> void:
	var _w53 = PanelContainer.new()
	_w53.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_w53.add_theme_constant_override("margin_bottom", _t45.message_gap)

	if not _h2:
		_u84()
	_w53.add_theme_stylebox_override("panel", _h2)

	var _v100 = VBoxContainer.new()
	_v100.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var _u92 = HBoxContainer.new()
	_u92.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var _i31 = Button.new()
	_i31.flat = true
	_i31.text = ">"  
	_i31.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_i31.tooltip_text = "Click to expand/collapse reasoning"

	_y10(_i31)
	_u92.add_child(_i31)

	var _m83 = RichTextLabel.new()
	_m83.bbcode_enabled = true
	_m83.selection_enabled = true
	_m83.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_m83.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_m83.fit_content = true
	_m83.scroll_active = false
	_m83.add_theme_stylebox_override("normal", StyleBoxEmpty.new())

	var _k30 = _h73.darkened(0.2)
	_m83.add_theme_color_override("default_color", _k30)
	_m83.text = "[i]View reasoning[/i]"
	_u92.add_child(_m83)

	_v100.add_child(_u92)

	var _v36 = VBoxContainer.new()
	_v36.visible = false
	_v36.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_v36.add_theme_constant_override("separation", 4)

	var _p59 = MarginContainer.new()
	var indent_size = _b74() * 2  
	_p59.add_theme_constant_override("margin_left", indent_size)
	_p59.add_theme_constant_override("margin_top", 4)
	_p59.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var _d64 = RichTextLabel.new()
	_d64.bbcode_enabled = true
	_d64.selection_enabled = true
	_d64.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_d64.fit_content = true
	_d64.scroll_active = false
	_d64.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_d64.add_theme_color_override("default_color", _k30)

	_d64.text = _a53(_a27)

	_p59.add_child(_d64)
	_v36.add_child(_p59)
	_v100.add_child(_v36)

	_i31.pressed.connect(func():
		_v36.visible = not _v36.visible
		_i31.text = "v" if _v36.visible else ">"
		_u44.call_deferred()
	)

	_w53.add_child(_v100)
	_m29.add_child(_w53)
	_u44.call_deferred()

func _m10() -> void:
	_h59()  

	_z87 = HBoxContainer.new()
	_z87.name = "AgentContinueContainer"
	_z87.alignment = BoxContainer.ALIGNMENT_CENTER
	_z87.add_theme_constant_override("separation", 8)

	var _u20 = Button.new()
	_u20.text = "Continue Session"
	_u20.pressed.connect(_v37)
	_z87.add_child(_u20)

	var _s6 = Button.new()
	_s6.text = "Start New Task"
	_s6.pressed.connect(_j36)
	_z87.add_child(_s6)

	var _g87 = get_node_or_null("MarginContainer/TabContainer/Chat")
	if _g87:
		var _v100 = _g87.get_child(0) if _g87.get_child_count() > 0 else null
		if _v100 and _v100 is VBoxContainer:
			var _i36 = -1
			for i in range(_v100.get_child_count()):
				var _j75 = _v100.get_child(i)
				if _j75.name == "InputContainer" or (_j75 is HBoxContainer and _j75.get_node_or_null("_h22") != null):
					_i36 = i
					break

			if _i36 >= 0:
				_v100.add_child(_z87)
				_v100.move_child(_z87, _i36)
			else:
				_v100.add_child(_z87)
		else:
			add_child(_z87)
	else:
		add_child(_z87)

func _v37() -> void:
	_h59()
	_b69()
	if _x14:
		_x14._j17()

func _j36() -> void:
	_h59()
	_d36()  
	if _x14:
		_x14._k13()
	_t91()
	_u51()

func _h59() -> void:
	if _z87 and is_instance_valid(_z87):
		_z87.queue_free()
		_z87 = null

func _b11() -> void:
	if _x14 and _x14.is_active():
		_x14._x83()

func _g42(_w25: String, _n73: Dictionary, _v42: Dictionary) -> Dictionary:
	var success = _v42.get("success", false)
	var _p98 = "✓ " if success else "✗ "
	var details: Array = []

	match _w25:
		"read_file":
			var path = _n73.get("path", "unknown")
			if success:
				var content = _v42.get("content", "")
				var _s40 = content.count("\n") + 1 if not content.is_empty() else 0
				return {"summary": _p98 + "Read file: " + path + " (" + str(_s40) + " lines)", "details": [], "is_error": false}
			else:
				return {"summary": _p98 + "Failed to read: " + path, "details": [], "is_error": true}

		"list_files":
			var path = _n73.get("path", "res://")
			if success:
				var _h63 = _v42.get("files", [])
				var _n96 = _v42.get("directories", [])
				var _q21 = _h63.size() if _h63 is Array else 0
				var _s70 = _n96.size() if _n96 is Array else 0

				for _b3 in _n96:
					details.append("📁 " + str(_b3) + "/")
				for _p88 in _h63:
					details.append("📄 " + str(_p88))
				return {"summary": _p98 + "Listed " + path + " (" + str(_q21) + " files, " + str(_s70) + " dirs)", "details": details, "is_error": false}
			else:
				return {"summary": _p98 + "Failed to list: " + path, "details": [], "is_error": true}

		"get_project_info":
			if success:
				var _l4 = _v42.get("project_name", "Unknown")
				var _c52 = _v42.get("godot_version", "")

				details.append("Project: " + str(_l4))
				details.append("Godot: " + str(_c52))
				if _v42.has("main_scene"):
					details.append("Main Scene: " + str(_v42.get("main_scene")))
				return {"summary": _p98 + "Project: " + _l4 + " (Godot " + _c52 + ")", "details": details, "is_error": false}
			else:
				return {"summary": _p98 + "Failed to get project info", "details": [], "is_error": true}

		"run_project":
			if success:
				return {"summary": _p98 + "Running project in debug mode", "details": [], "is_error": false}
			else:
				return {"summary": _p98 + "Failed to run project", "details": [], "is_error": true}

		"stop_project":
			if success:
				return {"summary": _p98 + "Stopped project", "details": [], "is_error": false}
			else:
				return {"summary": _p98 + "Failed to stop project", "details": [], "is_error": true}

		"create_file":
			var path = _n73.get("path", "unknown")
			if success:
				return {"summary": _p98 + "Created: " + path, "details": [], "is_error": false}
			else:
				var _s52 = _v42.get("error", "Unknown error")
				return {"summary": _p98 + "Failed to create " + path + ": " + _s52, "details": [], "is_error": true}

		"edit_file":
			var path = _n73.get("path", "unknown")
			if success:
				return {"summary": _p98 + "Modified: " + path, "details": [], "is_error": false}
			else:
				var _s52 = _v42.get("error", "Unknown error")
				return {"summary": _p98 + "Failed to edit " + path + ": " + _s52, "details": [], "is_error": true}

		"delete_file":
			var path = _n73.get("path", "unknown")
			if success:
				return {"summary": _p98 + "Deleted: " + path, "details": [], "is_error": false}
			else:
				var _s52 = _v42.get("error", "Unknown error")
				return {"summary": _p98 + "Failed to delete " + path + ": " + _s52, "details": [], "is_error": true}

		_:
			if success:
				return {"summary": _p98 + "Executed: " + _w25, "details": [], "is_error": false}
			else:
				return {"summary": _p98 + "Failed: " + _w25, "details": [], "is_error": true}

func _c73(_w25: String, _n73: Dictionary, _v42: Dictionary) -> void:
	var status = _g42(_w25, _n73, _v42)
	var _n17 = status.get("summary", "")
	var details = status.get("details", [])
	var _p40 = status.get("is_error", false)

	if details.size() > 0:
		_j69(_n17, details, _p40)
	else:
		_e16(_n17, _p40)

