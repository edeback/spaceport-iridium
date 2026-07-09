@tool
extends Control
func _q60(type: String) -> Color:
	if _k71:
		var _a74 = _k71.get_editor_settings()
		if _a74:
			match type:
				"text_color": return _a74.get_setting("text_editor/theme/highlighting/text_color")
				"comment": return _a74.get_setting("text_editor/theme/highlighting/comment_color")
				"string": return _a74.get_setting("text_editor/theme/highlighting/string_color")
				"number": return _a74.get_setting("text_editor/theme/highlighting/number_color")
				"keyword": return _a74.get_setting("text_editor/theme/highlighting/keyword_color")
				"class": return _a74.get_setting("text_editor/theme/highlighting/base_type_color")
				"function": return _a74.get_setting("text_editor/theme/highlighting/function_color")
				"symbol": return _a74.get_setting("text_editor/theme/highlighting/symbol_color")
	match type:
		"comment": return Color.GRAY
		"string": return Color.ORANGE
		"number": return Color.SKY_BLUE
		"keyword": return Color.PALE_VIOLET_RED
		"class": return Color.LIGHT_GREEN
		"function": return Color.LIGHT_BLUE
		"symbol": return Color.WHITE
	return Color.WHITE
const _q49 = [
	"if", "elif", "else", "for", "while", "match", "break", "continue", "pass",
	"return", "class", "extends", "is", "as", "self", "super", "func", "signal",
	"const", "var", "static", "enum", "in", "not", "and", "or", "true", "false",
	"null", "export", "onready", "tool", "setget", "breakpoint", "preload", "yield",
	"assert", "remote", "sync", "master", "puppet"
]
const _q30 = [
	"public", "private", "protected", "internal", "static", "void", 
	"class", "interface", "namespace", "using", "new", "this", "base",
	"if", "else", "for", "foreach", "while", "do", "switch", "case",
	"return", "throw", "try", "catch", "finally", "async", "await",
	"var", "const", "readonly", "override", "virtual", "abstract",
	"int", "string", "bool", "float", "double", "decimal", "byte", "true", "false", "null"
]
func _g72():
	if not _k71:
		return
	var theme = _k71.get_editor_theme()
	if not theme:
		return
	var _v22 = theme.get_color("base_color", "Editor")
	var _q8 = theme.get_color("dark_color_2", "Editor")
	var _c39 = theme.get_color("contrast_color_1", "Editor")
	var font_color = theme.get_color("font_color", "Editor")
	var _g56 = theme.get_color("accent_color", "Editor")
	if not _o97:
		_q23()
	var _f20 = _v22.lerp(_g56, 0.1)
	if _v22.get_luminance() > 0.5:
		_f20 = _v22.darkened(0.05).lerp(_g56, 0.1)
	_o97.bg_color = _f20
	_o97.border_color = _g56.darkened(0.3)
	if _f20.get_luminance() > 0.5:
		_p66 = Color.BLACK
	else:
		_p66 = Color(0.9, 0.9, 0.9) 
	var _c40 = _q8
	_i100.bg_color = _c40
	_i100.border_color = _c40.lightened(0.05)
	_i71 = font_color
	var _d25 = _c37("normal", "TextEdit")
	if _d25 is StyleBoxFlat:
		_a2.bg_color = _d25.bg_color
		_a2.border_color = _d25.border_color
		_a2.border_width_left = _d25.border_width_left
		_a2.border_width_top = _d25.border_width_top
		_a2.border_width_right = _d25.border_width_right
		_a2.border_width_bottom = _d25.border_width_bottom
		_a2.corner_radius_top_left = _d25.corner_radius_top_left
		_a2.corner_radius_top_right = _d25.corner_radius_top_right
		_a2.corner_radius_bottom_right = _d25.corner_radius_bottom_right
		_a2.corner_radius_bottom_left = _d25.corner_radius_bottom_left
	else:
		_a2.bg_color = _v22
		_a2.border_color = _v22.lightened(0.1)
	_i5.bg_color = _q8
	_i5.border_color = _q8.lightened(0.1)
	_l21 = font_color
	_c28.bg_color = _q8.lightened(0.05)
func _j64(name: String, type: String = "Editor") -> Color:
	if _k71:
		var theme = _k71.get_editor_theme()
		if theme:
			return theme.get_color(name, type)
	return Color.GRAY 
func _c37(name: String, type: String = "Editor") -> StyleBox:
	if _k71:
		var theme = _k71.get_editor_theme()
		if theme:
			return theme.get_stylebox(name, type)
	return null
var _o97: StyleBoxFlat
var _i100: StyleBoxFlat
var _i5: StyleBoxFlat
var _c28: StyleBoxFlat
var _a2: StyleBoxFlat
var _p66: Color
var _i71: Color
var _l21: Color
const _u22 = {
	"message_gap": 16,
	"padding": 12,
	"code_padding": 10
}
func _q23():
	_o97 = StyleBoxFlat.new()
	_o97.corner_radius_top_left = 8
	_o97.corner_radius_top_right = 8
	_o97.corner_radius_bottom_left = 8
	_o97.corner_radius_bottom_right = 8
	_o97.content_margin_left = _u22.padding
	_o97.content_margin_right = _u22.padding
	_o97.content_margin_top = _u22.padding
	_o97.content_margin_bottom = _u22.padding
	_o97.border_width_bottom = 1
	_o97.border_width_top = 1
	_o97.border_width_left = 1
	_o97.border_width_right = 1
	_i100 = StyleBoxFlat.new()
	_i100.corner_radius_top_left = 8
	_i100.corner_radius_top_right = 8
	_i100.corner_radius_bottom_left = 8
	_i100.corner_radius_bottom_right = 8
	_i100.content_margin_left = _u22.padding
	_i100.content_margin_right = _u22.padding
	_i100.content_margin_top = _u22.padding
	_i100.content_margin_bottom = _u22.padding
	_i100.border_width_bottom = 1
	_i100.border_width_top = 1
	_i100.border_width_left = 1
	_i100.border_width_right = 1
	_i5 = StyleBoxFlat.new()
	_i5.corner_radius_top_left = 4
	_i5.corner_radius_top_right = 4
	_i5.corner_radius_bottom_left = 4
	_i5.corner_radius_bottom_right = 4
	_i5.border_width_bottom = 1
	_i5.border_width_top = 1
	_i5.border_width_left = 1
	_i5.border_width_right = 1
	_i5.border_width_left = 1
	_i5.border_width_right = 1
	_c28 = StyleBoxFlat.new()
	_c28.corner_radius_top_left = 6
	_c28.corner_radius_top_right = 6
	_c28.content_margin_left = 12
	_c28.content_margin_right = 12
	_c28.content_margin_top = 4
	_c28.content_margin_bottom = 4
	_a2 = StyleBoxFlat.new()
	_a2.bg_color = Color(0.1, 0.1, 0.1) 
	_a2.border_width_left = 1
	_a2.border_width_top = 1
	_a2.border_width_right = 1
	_a2.border_width_bottom = 1
	_a2.corner_radius_top_left = 4
	_a2.corner_radius_top_right = 4
	_a2.corner_radius_bottom_right = 4
	_a2.corner_radius_bottom_left = 4
const _o1 = {
	"gdscript": "GDScript",
	"csharp": "C#",
	"cs": "C#",
	"": "GDScript"  
}
const _g73 = {
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
const _o75 = {
	"1080p": {"width": 1920, "height": 1080, "scale": 1.0},  
	"1440p": {"width": 2560, "height": 1440, "scale": 1.15}, 
	"4k": {"width": 3840, "height": 2160, "scale": 1.5},     
	"user": {"width": 1800, "height": 1169, "scale": 1.1}    
}
const _h73 = {
	0: "auto",    
	1: 0.8,       
	2: 1.0,       
	3: 1.25,      
	4: 1.5        
}
const _c20 = 16  
var _n64: EditorPlugin
var _k71: EditorInterface
var _y11: ScriptEditor
var _r70: VBoxContainer
var _q86: EditorPlugin  
var _z87: _i10
var _u48: _i81
var _i84: _a14
@onready var _n22: ScrollContainer = %_m71
@onready var _d30: TextEdit = %_w39
@onready var _y89: Button = %_n57
@onready var _j69: LineEdit = %_s70
@onready var _b86: Button = %_l85
@onready var _l47: Label = %_k66
@onready var _z17: CheckButton = %_x10
@onready var _c64: Label = %_o12
@onready var _n91: HBoxContainer = %_t37
@onready var _o37: Label = %_e77
@onready var _b43: Label = %_c70
@onready var _m56: Label = %_n19
@onready var _n87: Button = %_h84
@onready var _c56: Label = %_c23
@onready var _y71: OptionButton = %_p76
@onready var _b62: OptionButton = %_i74
@onready var _a96: OptionButton = %_d1
@onready var _w77: VBoxContainer = $MarginContainer/TabContainer/Settings/_p82/VBoxContainer
@onready var _b5: TabContainer = $MarginContainer/TabContainer
@onready var _e64: ProgressBar = %_p58
@onready var _p13: Label = %_v81
@onready var _r35: Label = %_s75
@onready var _o2: Label = %_s22
@onready var _f34: OptionButton = %_f54
@onready var _p48: Panel = %_k90
@onready var _p63: Label = %_o26
@onready var _x11: TabContainer = %_s11
@onready var _w66: ItemList = %_y13
@onready var _v63: Label = %_q31
@onready var _f32: RichTextLabel = %_w62
@onready var _b4: RichTextLabel = %_o100
@onready var _s18: Button = %_b98
@onready var _s51: Button = %_e54
@onready var _u24: Button = %_q93
@onready var _m50: Button = %_j94
@onready var _h74: ItemList = %_c10
@onready var _x46: Label = %_l93
@onready var _u66: RichTextLabel = %_f70
@onready var _f15: RichTextLabel = %_e66
@onready var _g96: Button = %_y81
@onready var _m85: Button = %_o71
@onready var _n62: Button = %_b32
@onready var _a9: Button = %_g34
@onready var _u92: Button = %_g86
@onready var _a57: Button = %_r30
@onready var _z75: Button = %_c51
@onready var _a24: Button = %_p78
@onready var _z27: AcceptDialog = %_s3
@onready var _r92: LineEdit = %_s8
@onready var _j47: FileDialog = %_a15
@onready var _y77: FileDialog = %_n75
@onready var _n73: OptionButton = %_d91
@onready var _p51: Label = %_l67
var _m75: CheckBox
var _z93: OptionButton
var _y62: SpinBox
var _r52: CheckBox
var _e57: CheckBox
var _a71: Button
var _r46: _p17
var _o85: Array = []
var _z43: bool = false
var _y40: float = 0.0
var _s42: int = 0
var _b81: Dictionary = {}  
var _j78: int = 0
var _q63: int = 30000  
var _c84: Dictionary = {}
var _x100: Array[String] = []
var _l64: int = 0
var _g38: _m71
var _t81: int = -1
var _m67: int = -1
var _c48: String = ""
var _j68: bool = false
var _i78: String = ""  
var _l69: String = ""  
var _g36: bool = false
var _j75: Vector2 = Vector2.ZERO
var _g30: float = 0.0
var _a43: HBoxContainer
var _n66: OptionButton
var _q21: Label
var _r37: OptionButton  
const _g16 = [
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
var _l46: TextEdit
var _i2: Label
var _p85: Label
const _e94 = 3
var _l99: int = 0
var _z5: float = 1.0
var _f84: String = "auto"  
var _r60: int = 128000  
const _l16 = 0.85  
const _q19 = 1.0  
const _s60 = [
	"@file",
	"@selection",
	"@openscript",
	"@scene",
	"@node"
]
const _f72: int = 0
const _a6: int = 1
const _j41 = {
	_f72: "Chat",
	_a6: "Agent"
}
var _b34: _z35
var _t36: _v17
var _a38: ProgressBar
var _b47: Label
var _x2: Button
var _o41: bool = false
var _v28: VBoxContainer
var _i59: HBoxContainer
var _b6: Array = []  
var _z3: bool = false  
var _i85: HBoxContainer  
var _z97: HBoxContainer  
var _y100 = 0
var _e59 = []
var _c2 = {}
var _w99: Timer
var _x16: int = 0
var _p21: PanelContainer
var _q67: bool = false  
func _x7() -> void:
	_b81 = {}
func set_gdsense_manager(_v55: _p17) -> void:
	_r46 = _v55
	if _r46:
		if not _r46._d99.is_connected(_n52):
			_r46._d99.connect(_n52)
		if not _r46._m5.is_connected(_l31):
			_r46._m5.connect(_l31)
		if not _r46._b33.is_connected(_i95):
			_r46._b33.connect(_i95)
func set_plugin(_b89: EditorPlugin) -> void:
	_q86 = _b89
func _notification(_u78):
	if _u78 == NOTIFICATION_THEME_CHANGED:
		_f17()
func _ready() -> void:
	_q23()
	_v95.call_deferred()
	_n64 = EditorPlugin.new()
	_k71 = _n64.get_editor_interface()
	_y11 = _k71.get_script_editor()
	var _n54 = %_s74
	if _n54:
		_n54.add_theme_stylebox_override("panel", _a2)
	_g72()
	_c9()
	_z87 = _i10.new(_k71, _y11)
	_u48 = _i81.new(_z87, _k71)
	_i84 = _a14.new()
	_i84.initialize(_d30, self, _k71)
	_i84._z90.connect(_r16)
	_r70 = %_v53
	_n22.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_r70.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_b86.pressed.connect(_z20)
	_y89.pressed.connect(_v34)
	_z17.toggled.connect(_l12)
	_n87.pressed.connect(_i3)
	_y71.item_selected.connect(_s57)
	_b62.item_selected.connect(_s57)
	_d30.gui_input.connect(_g54)
	_d30.text_changed.connect(_c45)
	_p48.mouse_entered.connect(_i12)
	_p48.mouse_exited.connect(_e49)
	_p48.gui_input.connect(_m92)
	_m61()
	_l91()
	_n2()
	_w99 = Timer.new()
	_w99.wait_time = 0.5  
	_w99.one_shot = true
	_w99.timeout.connect(_f10)
	add_child(_w99)
	if _r46:
		_r46._a16.connect(_k48)
		_r46._b16.connect(_c94)
		_r46._i36.connect(_g59)
		_r46._l25.connect(_l4)
		_r46._q89.connect(_s87)
		_r46._k81.connect(_k34)
		_r46._i99.connect(_a80)
		_r46._u64.connect(_w79)
	var _i19 = _r46._a77() if _r46 else ""
	_j69.text = _i19
	if _i19.is_empty():
		if _r46 and _r46._b17():
			var env = _r46._j19()
			_l47.text = "No API Key (%s)" % env.capitalize()
		else:
			_l47.text = "API Key Not Set"
	else:
		if _r46 and _r46._b17():
			var env = _r46._j19()
			_l47.text = "API Key Loaded (%s)" % env.capitalize()
		else:
			_l47.text = "API Key Loaded"
	_t29()
	_r8()
	_p5()
	_q9()
	_s37()
	_a73()
	_p86()
	_f83.call_deferred()
	_c64.visible = false
	_n91.visible = false
	if not (_r46 and _r46._b17()):
		_c56.visible = false
	_e93()
	_n88()
func _v95():
	if not _r46:
		if _l99 >= _e94:
			return
		_l99 += 1
		if is_inside_tree():
			get_tree().create_timer(1.0).timeout.connect(_j35)
		else:
			_f69.call_deferred()
func _f69():
	if _l99 >= _e94:
		return
	_v95()
func _j35():
	if not _r46:
		if _l99 >= _e94:
			pass
		else:
			pass
	else:
		_l99 = 0
func _process(delta: float):
	if _z43:
		var elapsed_time = (Time.get_ticks_msec() / 1000.0) - _y40
		_c64.text = "Request time: %.1fs" % elapsed_time
func _g54(_t27: InputEvent):
	if _i84 and _i84._s67(_t27):
		get_viewport().set_input_as_handled()
		return
	if _t27 is InputEventKey and _t27.pressed:
		if _t27.keycode == KEY_ENTER:
			if _t27.shift_pressed:
				_d30.text += "\n"
				_d30.set_caret_line(_d30.get_line_count() - 1)
				_d30.set_caret_column(0)
				get_viewport().set_input_as_handled()
			else:
				var text = _d30.text.strip_edges()
				if text.is_empty():
					return
				_d30.text = ""
				_c45() 
				if _a96 and _a96.selected == _a6:
					_e88(text)
				else:
					_t16(text)
				get_viewport().set_input_as_handled()
func _z20():
	if _r46:
		_r46._g9(_j69.text)
func _v34():
	var _z21: String = _d30.text
	if not _z21.is_empty():
		if _a96 and _a96.selected == _a6:
			_e88(_z21)
		else:
			_t16(_z21)
func _e88(_q65: String) -> void:
	if not _b34:
		_m77("Agent mode not available", true)
		return
	var _y32 = _a13(_q65)
	if _y32.is_empty():
		return
	_d30.text = ""
	_y69(_q65)
	_i20()
	_d30.editable = false
	_y89.disabled = true
	var _p44 = {
		"godot_version": Engine.get_version_info().get("string", "4.x"),
		"project_name": ProjectSettings.get_setting("application/config/name", "")
	}
	var _g50 = ""
	if _r37:
		_g50 = _q26()
	_b34._j52(_y32, _p44, _g50)
func _t16(_z21: String):
	_i78 = _z21
	_o16()
	_o85.append({"role": "user", "content": _z21, "original_content": _z21})
	_x7()
	var _t73 = _z21
	if _z21.begins_with("@explain"):
		var _z89 = _z21.find("\n")
		if _z89 != -1:
			_t73 = _z21.substr(0, _z89) + " (code attached)"
	_y69(_t73)
	_d30.text = ""
	_d30.editable = false
	_y89.disabled = true
	_z43 = true
	_y40 = Time.get_ticks_msec() / 1000.0
	_c64.visible = true
	_n91.visible = false
	_c64.text = "Request time: 0.0s"
	_d12.call_deferred()
	var _u70 = _w40(_z21, true)
	var processed_prompt = _u70["processed_prompt"]
	var context_metadata = _u70["context_metadata"]
	if processed_prompt == "":
		_m83()
		if _o85.size() > 0:
			_o85.pop_back()
			_x7()
		return
	if processed_prompt.strip_edges().begins_with("@explain"):
		var _j50 = _g28(processed_prompt)
		if _j50.has("function_context") and not _j50["function_context"].is_empty():
			if _r46:
				_r46._p35(_o85, "@explain", _j50["function_context"], context_metadata if context_metadata else {})
		else:
			_o85[_o85.size() - 1]["content"] = processed_prompt
			if _r46:
				_r46._p35(_o85, "", "", context_metadata if context_metadata else {})
	else:
		_o85[_o85.size() - 1]["content"] = processed_prompt
		if _r46:
			_r46._p35(_o85, "", "", context_metadata if context_metadata else {})
func _k48(_x77: String, _x42: Array, _j43: String = "", _u30: String = ""):
	if not _u30.is_empty() and _o85.size() > 0:
		for i in range(_o85.size() - 1, -1, -1):
			if _o85[i].get("role", "") == "user":
				_o85[i]["content"] = _u30
				break
	var _u61 = {"role": "agent", "content": _x77}
	if not _j43.is_empty():
		_u61["thought_signature"] = _j43
	_o85.append(_u61)
	_l69 = _j43
	_x7()
	_g2(_x77, _x42)
	if _g38 and not _i78.is_empty():
		var session_id = _r46._b11() if _r46 else ""
		var _x13 = _g38._t91()
		var _k4 = (not _x13 or _x13.session_id != session_id)
		if _k4 and _o85.size() > 2:
			for i in range(0, _o85.size() - 2, 2):  
				if i + 1 < _o85.size():
					var _p23 = _o85[i]
					var _b51 = _o85[i + 1]
					if _p23.get("role", "") == "user" and _b51.get("role", "") == "agent":
						var _e46 = _b51.get("thought_signature", "")
						var _r29 = _p23.get("original_content", _p23.get("content", ""))
						var _l42 = _p23.get("content", "")
						_g38._o78(_r29, _b51.get("content", ""), session_id, _e46, _l42, "")
		var _h97 = _i78
		var _g61 = _u30 if not _u30.is_empty() else _i78
		var _t88 = _r46._v41() if _r46 else ""
		_g38._o78(_h97, _x77, session_id, _j43, _g61, _t88)
		_g38._d97()
		_i78 = ""  
		_h15()
	_m83()
	_d12.call_deferred()
	_o16.call_deferred(true)
func _c94():
	_l47.text = "Invalid API Key"
	_n15("Your API key is invalid. Please check your settings.")
	_m83()
	_d12.call_deferred()
func _g59(_j100: int, _q64: String):
	var _l2 = _n96(_q64)
	var _m16: String
	if _l2 != _q64:
		_m16 = _l2
	else:
		_m16 = "API Error %d: %s" % [_j100, _q64]
		if _j100 == 400:
			if "custom_rules" in _q64.to_lower():
				_m16 += "\n\nPlease check your custom rules in the Settings tab."
			elif "godot_version" in _q64.to_lower():
				_m16 += "\n\nGodot version detection failed. Try restarting the editor."
		elif _j100 == 422:
			_m16 += "\n\nPlease verify your custom rules and parameter settings."
	_n15(_m16)
	_m83()
	_d12.call_deferred()
func _l4():
	if _r46 and _r46._b17():
		var env = _r46._j19()
		_l47.text = "API Key Saved (%s)!" % env.capitalize()
	else:
		_l47.text = "API Key Saved!"
func _i3():
	_o85.clear()
	_x7()
	_h91()
	for _x15 in _r70.get_children():
		_x15.queue_free()
	_n88()
	_j21()
	_n91.visible = false
	_s42 = 0
	_c56.text = "Total Token Usage for this chat: 0"
	if _g38:
		_g38._r74()
		_g38._d97()
		_h15()
	if _r46:
		_r46._x37()
	_d12.call_deferred()
func _d12():
	await get_tree().process_frame
	_n22.get_v_scroll_bar().value = _n22.get_v_scroll_bar().max_value
func _s87(_b79: int, _m15: int, _c92: int):
	_s42 += _c92
	if _r46 and _r46._b17():
		_o37.text = "P: %d" % _b79
		_b43.text = "C: %d" % _m15
		_m56.text = "T: %d" % _c92
		_c56.text = "Total Token Usage for this chat: %d" % _s42
		_n91.visible = true
	else:
		_n91.visible = false
		_c56.visible = false
	_d12.call_deferred()
func _k34(success: bool):
	if success:
		pass
	else:
		pass
func _l12(_o83: bool):
	_j69.secret = not _o83
func _i12():
	Input.set_default_cursor_shape(Input.CURSOR_VSIZE)
func _e49():
	if not _g36:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
func _m92(_t27: InputEvent):
	if _t27 is InputEventMouseButton:
		if _t27.button_index == MOUSE_BUTTON_LEFT:
			if _t27.pressed:
				_g36 = true
				_j75 = _p48.get_global_mouse_position()
				_g30 = _d30.custom_minimum_size.y
			else:
				_g36 = false
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	elif _t27 is InputEventMouseMotion and _g36:
		var _d60 = _p48.get_global_mouse_position()
		var _s78 = _d60.y - _j75.y
		var _i97 = clamp(_g30 + _s78, 40.0, 600.0)
		_d30.custom_minimum_size.y = _i97
func _x1(text: String) -> String:
	var _p91: PackedStringArray = text.split("\n")
	for i in range(_p91.size()):
		var line: String = _p91[i]
		var _z10: int = 0
		for char in line:
			if char == ' ':
				_z10 += 1
			else:
				break
		var _j2: int = _z10 / 4
		if _j2 > 0:
			_p91[i] = "\t".repeat(_j2) + line.lstrip(" ")
	return "\n".join(_p91)
func _m83():
	_d30.editable = true
	_y89.disabled = false
	_z43 = false
	_c64.visible = false
func _a60(text: String) -> PackedStringArray:
	var _x62 = RegEx.new()
	_x62.compile("[A-Z][a-zA-Z0-9]+")
	var _g27 = _x62.search_all(text)
	var _d13: PackedStringArray = []
	for _e21 in _g27:
		_d13.append(_e21.get_string())
	return _d13
func _m46(_w49: String) -> String:
	if not ClassDB.class_exists(_w49):
		return ""
	var _x91 := ""
	var _n14 = ClassDB.class_get_method_list(_w49)
	if _n14.size() > 0:
		_x91 = "Class: " + _w49 + "\n"
	return _x91
func _j36(user_prompt: String) -> String:
	if user_prompt.strip_edges().begins_with("@explain"):
		return _z32(user_prompt)
	if not _w47(user_prompt):
		return user_prompt
	var _d13 = _a60(user_prompt)
	if _d13.is_empty():
		return user_prompt
	var _m66 = "Godot Editor Context:\n"
	for _q97 in _d13:
		var _x91 = _m46(_q97)
		if not _x91.is_empty():
			_m66 += _x91 + "\n"
	if _m66 == "Godot Editor Context:\n":
		return user_prompt
	var _e12 = _m66 + "\nUser Question: " + user_prompt
	return _e12
func _g28(user_prompt: String) -> Dictionary:
	var _e21 = {}
	var _a46 = RegEx.new()
	_a46.compile("@explain\\s+([a-zA-Z_][a-zA-Z0-9_]*)")
	var _b27 = _a46.search(user_prompt)
	var function_name = ""
	if _b27:
		function_name = _b27.get_string(1)
		_e21["function_name"] = function_name
	var _w42 = RegEx.new()
	_w42.compile("```(?:gdscript)?\n([^`]+?)```")
	var _f4 = _w42.search(user_prompt)
	if _f4:
		var _k94 = _f4.get_string(1).strip_edges()
		_e21["function_context"] = _k94
	return _e21
func _z32(user_prompt: String) -> String:
	var _a46 = RegEx.new()
	_a46.compile("@explain\\s+([a-zA-Z_][a-zA-Z0-9_]*)")
	var _e21 = _a46.search(user_prompt)
	var function_name = ""
	if _e21:
		function_name = _e21.get_string(1)
	var _j89 = "Please explain this GDScript function"
	if not function_name.is_empty():
		_j89 += " called '%s'" % function_name
	_j89 += ". Focus on:\n"
	_j89 += "- What the function does (purpose and behavior)\n"
	_j89 += "- How to use it (parameters and return value)\n"
	_j89 += "- Any important implementation details\n"
	_j89 += "- Potential improvements or best practices\n\n"
	_j89 += user_prompt.replace("@explain %s" % function_name, "").strip_edges()
	return _j89
func _a13(user_prompt: String) -> String:
	if _z87 == null:
		return user_prompt
	var _n76 = _z87._y88(user_prompt)
	var commands = _n76.get("commands", [])
	var cleaned_prompt = _n76.get("cleaned_prompt", user_prompt)
	for _k52 in commands:
		if _k52.get("type", "") == "error":
			var _u39 = _k52.get("error", "Unknown error")
			if "path traversal" in _u39.to_lower() or "not allowed" in _u39.to_lower() or "blocked" in _u39.to_lower():
				_n15("⚠️ Security: " + _u39)
				return ""
			else:
				_n15("⚠️ " + _u39)
				return ""
	if commands.is_empty():
		return user_prompt
	var _k87: Array[String] = []
	for _k52 in commands:
		var _k3 = _k52.get("type", "")
		match _k3:
			"file":
				var path = _k52.get("path", "")
				if not path.is_empty():
					_k87.append("File: " + path)
			"selection":
				var _x58 = _k52.get("script_path", "")
				var _c58 = _k52.get("line_start", 0)
				var _p52 = _k52.get("line_end", 0)
				if (_x58.is_empty() or not _x58.begins_with("res://")) and _z87:
					var _j9 = _z87._o92()
					if _j9.get("success", false):
						_x58 = _j9.get("path", "")
						_c58 = _j9.get("start_line", 0)
						_p52 = _j9.get("end_line", 0)
				if not _x58.is_empty() and _x58.begins_with("res://"):
					_k87.append("Selection in %s (lines %d-%d)" % [_x58, _c58, _p52])
			"openscript":
				var path = _k52.get("path", "")
				if path.is_empty() or not path.begins_with("res://"):
					if _z87:
						var _u1 = _z87.get_current_script()
						if _u1.get("success", false):
							path = _u1.get("path", "")
				if not path.is_empty() and path.begins_with("res://"):
					_k87.append("Open script: " + path)
			"scene":
				var path = _k52.get("path", "")
				if not path.is_empty():
					_k87.append("Scene: " + path)
			"node":
				var node_path = _k52.get("node_path", "")
				if not node_path.is_empty():
					_k87.append("Node: " + node_path)
	if _k87.is_empty():
		return cleaned_prompt
	var _t62 = "\n\n[Referenced files - use read_file to access]:\n- " + "\n- ".join(_k87)
	return cleaned_prompt + _t62
func _w40(user_prompt: String, _x57: bool = false) -> Dictionary:
	if _z87 == null or _u48 == null:
		return {"processed_prompt": user_prompt, "context_metadata": null}
	var _n76 = _z87._y88(user_prompt)
	var commands = _n76.get("commands", [])
	var cleaned_prompt = _n76.get("cleaned_prompt", user_prompt)
	if _x57:
		_e41(commands)
		for _k52 in commands:
			if _k52.get("type", "") == "openscript":
				var snapshot_id = _k52.get("snapshot_id", "")
				if snapshot_id != "" and _c84.has(snapshot_id):
					_c84[snapshot_id]["sent_in_conversation"] = true
	var _j76 = _m88(commands)
	var _j17 = _r42(_j76)
	if not _j17.is_empty():
		var _q48 = []
		_q48.append_array(_j17)
		_q48.append_array(commands)
		commands = _q48
	var _b76 = []
	for _k52 in commands:
		if _k52.get("type", "") == "error":
			var _u39 = _k52.get("error", "Unknown error")
			if _u39.begins_with("Security:"):
				_b76.append("⚠️ " + _u39)
			elif "path traversal" in _u39.to_lower() or "not allowed" in _u39.to_lower() or "blocked" in _u39.to_lower():
				_b76.append("⚠️ Security: " + _u39)
			else:
				_b76.append("⚠️ " + _u39)
	if not _b76.is_empty():
		var _l27 = "\n".join(_b76)
		_n15(_l27)
		return {"processed_prompt": "", "context_metadata": null}
	if commands.is_empty():
		return {"processed_prompt": user_prompt, "context_metadata": null}
	var _o77 = _u48._s99(cleaned_prompt, commands)
	var _e2 = _u48._r90(_o77)
	if not _e2.get("valid", false):
		var _w98 = _e2.get("message", "Unknown validation error")
		_n15("Context too large: " + _w98)
		return {"processed_prompt": "", "context_metadata": null}
	var context_metadata = _u34(commands, _e2.get("estimated_tokens", 0))
	if OS.is_debug_build() and context_metadata:
		pass
	return {"processed_prompt": _o77, "context_metadata": context_metadata}
func _e41(commands: Array) -> void:
	if commands.is_empty():
		return
	var _q71 = false
	for _k52 in commands:
		if _k52.get("type", "") != "openscript":
			continue
		var snapshot_id = _k52.get("snapshot_id", "")
		if snapshot_id == "":
			snapshot_id = _w4()
			_k52["snapshot_id"] = snapshot_id
		var _x58 = _k52.get("path", "")
		var _p30 = _k52.get("content", "")
		if _p30 == "" and _z87:
			var _u1 = _z87.get_current_script()
			if _u1.get("success", false):
				_p30 = _u1.get("content", "")
				_k52["content"] = _p30
				if _x58 == "":
					_x58 = _u1.get("path", "")
					_k52["path"] = _x58
		if _p30 == "":
			continue
		if _x58 == "":
			_x58 = "current_script.gd"
			_k52["path"] = _x58
		_c84[snapshot_id] = {
			"path": _x58,
			"content": _p30,
			"size_bytes": _p30.length(),
			"created_at": _k52.get("created_at", Time.get_unix_time_from_system()),
			"sent_in_conversation": false  
		}
		if not _x100.has(snapshot_id):
			_x100.append(snapshot_id)
		_q71 = true
	if _q71:
		_e99()
func _m88(commands: Array) -> PackedStringArray:
	var _c61 = PackedStringArray()
	for _k52 in commands:
		if _k52.get("type", "") != "openscript":
			continue
		var snapshot_id = _k52.get("snapshot_id", "")
		if snapshot_id != "":
			_c61.append(snapshot_id)
	return _c61
func _r42(_t33: PackedStringArray = PackedStringArray()) -> Array:
	var commands: Array = []
	for snapshot_id in _x100:
		if _t33.has(snapshot_id):
			continue
		if not _c84.has(snapshot_id):
			continue
		var _r10 = _c84[snapshot_id]
		if _r10.get("sent_in_conversation", false):
			continue
		var _k52 = {
			"type": "openscript",
			"snapshot_id": snapshot_id,
			"path": _r10.get("path", ""),
			"content": _r10.get("content", "")
		}
		commands.append(_k52)
	return commands
func _f53(_k52: Dictionary) -> Dictionary:
	var _x58 = _k52.get("path", "")
	var _p30 = _k52.get("content", "")
	var snapshot_id = _k52.get("snapshot_id", "")
	if snapshot_id != "" and _c84.has(snapshot_id):
		var _z41 = _c84[snapshot_id]
		if _x58 == "":
			_x58 = _z41.get("path", "")
		if _p30 == "":
			_p30 = _z41.get("content", "")
	return {
		"path": _x58,
		"content": _p30,
		"snapshot_id": snapshot_id
	}
func _w4() -> String:
	_l64 += 1
	return "panel_openscript_%d_%d" % [Time.get_ticks_msec(), _l64]
func _h91() -> void:
	_c84.clear()
	_x100.clear()
	_l64 = 0
	_e99()
func _e99() -> void:
	if _g38:
		_g38._e60(_c84, _x100)
func _u34(commands: Array, _q50: int) -> Dictionary:
	var _z100 = []
	var _w64 = 0
	for _k52 in commands:
		var _o34 = {}
		var _k3 = _k52.get("type", "unknown")
		_o34["type"] = _k3
		match _k3:
			"file":
				_o34["path"] = _k52.get("path", "")
				if _k52.get("start_line", -1) > 0:
					_o34["start_line"] = _k52.get("start_line", 0)
				if _k52.get("end_line", -1) > 0:
					_o34["end_line"] = _k52.get("end_line", 0)
				if _k52.get("symbol", "") != "":
					_o34["symbol"] = _k52.get("symbol", "")
				if _z87:
					var _s47 = _z87._c89(_k52)
					if _s47.get("success", false):
						var _o36 = _s47.get("content", "").length()
						_o34["size_bytes"] = _o36
						_w64 += _o36
			"scene":
				_o34["path"] = _k52.get("path", "")
				if _k52.get("node_path", "") != "":
					_o34["node_path"] = _k52.get("node_path", "")
				if _k52.get("include_scripts", false):
					_o34["include_scripts"] = true
				var _s89 = 500  
				if _k52.get("include_scripts", false):
					_s89 += 2000  
				_o34["size_bytes"] = _s89
				_w64 += _s89
			"node":
				_o34["node_path"] = _k52.get("node_path", "")
				var _s89 = 200  
				_o34["size_bytes"] = _s89
				_w64 += _s89
			"selection":
				if _z87:
					var _j9 = _z87._o92()
					if _j9.get("success", false):
						var _o36 = _j9.get("content", "").length()
						_o34["size_bytes"] = _o36
						_w64 += _o36
						var _j90 = _j9.get("path", "")
						if _j90 != "":
							_o34["path"] = _j90
						var _m9 = _j9.get("start_line", 0)
						if _m9 > 0:
							_o34["start_line"] = _m9
						var _u59 = _j9.get("end_line", 0)
						if _u59 > 0:
							_o34["end_line"] = _u59
			"openscript":
				var _c38 = _f53(_k52)
				var _p30 = _c38.get("content", "")
				var _x58 = _c38.get("path", "")
				var snapshot_id = _c38.get("snapshot_id", "")
				if _p30 != "":
					var _o36 = _p30.length()
					_o34["size_bytes"] = _o36
					_w64 += _o36
				if _x58 != "":
					_o34["path"] = _x58
				if snapshot_id != "":
					_o34["snapshot_id"] = snapshot_id
		_z100.append(_o34)
	var _o27 = {
		"commands": _z100,
		"total_context_size": _w64,
		"command_count": commands.size(),
		"estimated_tokens": _q50
	}
	if _r46 and not _r46._b11().is_empty():
		_o27["session_id"] = _r46._b11()
	return _o27
func _w47(user_prompt: String) -> bool:
	var _u85 = [
		"CharacterBody2D", "RigidBody2D", "StaticBody2D", "Area2D",
		"Node2D", "Node3D", "Control", "Panel", "Button", "Label",
		"AnimationPlayer", "AnimationTree", "TileMap", "PackedScene",
		"Resource", "RefCounted", "Object", "Variant",
		"Vector2", "Vector3", "Transform2D", "Transform3D",
		"InputEvent", "Camera2D", "Camera3D", "CollisionShape2D"
	]
	var _y72 = user_prompt.to_lower()
	for _j73 in _u85:
		if _y72.find(_j73.to_lower()) != -1:
			return true
	return false
func _d64(code: String) -> String:
	var _p60 = ""
	var _p91 = code.split("\n")
	var _z57 = RegEx.new()
	_z57.compile("\\b(" + "|".join(_q49) + ")\\b")
	var _x86 = RegEx.new()
	_x86.compile("(?<!#)\\b(Vector2|Input|Node2D|Control|CharacterBody2D|[A-Z][a-zA-Z0-9]*)\\b")
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
func _y69(text: String):
	var _p40 = PanelContainer.new()
	_p40.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_p40.add_theme_constant_override("margin_bottom", _u22.message_gap)
	if not _o97:
		_g72()
	_p40.add_theme_stylebox_override("panel", _o97)
	var _c71 = VBoxContainer.new()
	_c71.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_c71.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var _n100 = Label.new()
	_n100.text = "You:"
	_n100.add_theme_color_override("font_color", _p66)
	var _w45 = get_theme_font_size("font_size", "Label")
	_n100.add_theme_font_size_override("font_size", int(_w45 * 1.15))
	_c71.add_child(_n100)
	var _q52 = Control.new()
	_q52.custom_minimum_size.y = 6
	_c71.add_child(_q52)
	var _j97 = ColorRect.new()
	_j97.custom_minimum_size.y = 1
	_j97.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_j97.color = _p66
	_j97.color.a = 0.5
	_c71.add_child(_j97)
	var _y67 = Control.new()
	_y67.custom_minimum_size.y = 6
	_c71.add_child(_y67)
	var _h29 = RichTextLabel.new()
	_h29.bbcode_enabled = true
	_h29.selection_enabled = true
	_h29.text = _v100(text)
	_h29.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_h29.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_h29.fit_content = true
	_h29.scroll_active = false
	_h29.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_h29.add_theme_color_override("default_color", _p66)
	_c71.add_child(_h29)
	_p40.add_child(_c71)
	_r70.add_child(_p40)
func _g2(text: String, _x42: Array = []):
	var _p40 = PanelContainer.new()
	_p40.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_p40.add_theme_constant_override("margin_bottom", _u22.message_gap)
	if not _i100:
		_g72()
	_p40.add_theme_stylebox_override("panel", _i100)
	var _c71 = VBoxContainer.new()
	_c71.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_c71.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_c71.add_theme_constant_override("separation", 4)
	var _n100 = Label.new()
	_n100.text = "GDSense:"
	_n100.add_theme_color_override("font_color", _i71)
	var _w45 = get_theme_font_size("font_size", "Label")
	_n100.add_theme_font_size_override("font_size", int(_w45 * 1.15))
	_c71.add_child(_n100)
	var _q52 = Control.new()
	_q52.custom_minimum_size.y = 6
	_c71.add_child(_q52)
	var _j97 = ColorRect.new()
	_j97.custom_minimum_size.y = 1
	_j97.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_j97.color = _i71
	_j97.color.a = 0.5
	_c71.add_child(_j97)
	var _y67 = Control.new()
	_y67.custom_minimum_size.y = 6
	_c71.add_child(_y67)
	_a89(text, _c71)
	if _x42.size() > 0:
		_r48(_x42, _c71)
	if _r46:
		var _s25 = _r46._z33()
		if not _s25.is_empty():
			_k13(_c71)
		else:
			pass
	_p40.add_child(_c71)
	_r70.add_child(_p40)
func _a89(text: String, parent: Node):
	var _w42 = RegEx.new()
	_w42.compile("```([a-zA-Z]*)\n([^`]+?)```")
	var _f39 = 0
	var _w34 = _w42.search_all(text)
	for match in _w34:
		var _h33 = text.substr(_f39, match.get_start() - _f39)
		if not _h33.strip_edges().is_empty():
			_j4(_h33.strip_edges(), parent)
		var language = match.get_string(1).to_lower()
		if language.is_empty():
			language = "gdscript"  
		var code = match.get_string(2)
		_u3(code, language, parent)
		_f39 = match.get_end()
	if _f39 < text.length():
		var _f98 = text.substr(_f39)
		if not _f98.strip_edges().is_empty():
			_j4(_f98.strip_edges(), parent)
func _j4(text: String, parent: Node):
	var _e74 = text.strip_edges()
	_e74 = _e74.replace("**", "")
	var _n84 = RegEx.new()
	_n84.compile("`([^`]+)`")
	var _v75 = _n84.search_all(_e74)
	if _v75:
		for i in range(_v75.size() - 1, -1, -1):
			var _n30 = _v75[i]
			var full_match = _n30.get_string(0)
			var content = _n30.get_string(1)
			var _l81 = _v100(content)
			var _s54 = "[i]" + _l81 + "[/i]"
			_e74 = _e74.substr(0, _n30.get_start()) + _s54 + _e74.substr(_n30.get_end())
	var _e35 = RegEx.new()
	_e35.compile("'([A-Za-z0-9_\\-\\.]+)'")
	var _f97 = _e35.search_all(_e74)
	if _f97:
		for i in range(_f97.size() - 1, -1, -1):
			var _n30 = _f97[i]
			var full_match = _n30.get_string(0)
			var content = _n30.get_string(1)
			var _l81 = _v100(content)
			var _s54 = "[i]" + _l81 + "[/i]"
			_e74 = _e74.substr(0, _n30.get_start()) + _s54 + _e74.substr(_n30.get_end())
	var _i76 = "___SAFE_ITALIC_START___"
	var _w24 = "___SAFE_ITALIC_END___"
	_e74 = _e74.replace("[i]", _i76)
	_e74 = _e74.replace("[/i]", _w24)
	if _e74.begins_with("Explanation:") or _e74.begins_with("To use this:") or _e74.begins_with("To make this work:"):
		var _c57 = _e74.split(":", true, 1)
		if _c57.size() > 1:
			_e74 = "[b]" + _v100(_c57[0]) + ":[/b]" + _v100(_c57[1])
	var _p91 = _e74.split("\n")
	var _p94 = []
	var _d15 = RegEx.new()
	_d15.compile("^(#{1,4})\\s+(.+)$")
	var _g40 = RegEx.new()
	_g40.compile("^\\|\\s*[-:]+\\s*(\\|\\s*[-:]+\\s*)+\\|\\s*$")
	var _r33: Array = []  
	var _u16 = false
	var _u42 = func():
		if _p94.is_empty():
			return
		var _l72 = "\n".join(_p94)
		_l72 = _l72.replace(_i76, "[i]")
		_l72 = _l72.replace(_w24, "[/i]")
		if _l72.strip_edges().is_empty():
			_p94.clear()
			return
		var _y22 = RichTextLabel.new()
		_y22.bbcode_enabled = true
		_y22.selection_enabled = true
		_y22.text = _l72
		_y22.add_theme_constant_override("line_separation", 6)
		_y22.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_y22.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_y22.fit_content = true
		_y22.scroll_active = false
		_y22.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		_y22.add_theme_color_override("default_color", _i71)
		parent.add_child(_y22)
		_p94.clear()
	var _x92 = func():
		if _r33.is_empty():
			return
		_u42.call()
		var _e20 = 0
		for _m96 in _r33:
			if _m96.size() > _e20:
				_e20 = _m96.size()
		if _e20 == 0:
			_r33.clear()
			_u16 = false
			return
		var _i31 = MarginContainer.new()
		_i31.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_i31.add_theme_constant_override("margin_top", 8)
		_i31.add_theme_constant_override("margin_bottom", 12)
		var _g74 = PanelContainer.new()
		_g74.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var _i33 = StyleBoxFlat.new()
		_i33.bg_color = Color(0.15, 0.15, 0.18, 1.0)
		_i33.set_corner_radius_all(6)
		_i33.set_content_margin_all(12)
		_g74.add_theme_stylebox_override("panel", _i33)
		var _a85 = VBoxContainer.new()
		_a85.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_a85.add_theme_constant_override("separation", 0)
		var _t3 = GridContainer.new()
		_t3.columns = _e20
		_t3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_t3.add_theme_constant_override("h_separation", 24)
		var _m31 = GridContainer.new()
		_m31.columns = _e20
		_m31.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_m31.add_theme_constant_override("h_separation", 24)
		_m31.add_theme_constant_override("v_separation", 10)
		var _j77 = int(14 * _z5)
		var _k29 = int(15 * _z5)
		for _m100 in range(_r33.size()):
			var _m96 = _r33[_m100]
			for _u49 in range(_e20):
				var _p38 = _m96[_u49] if _u49 < _m96.size() else ""
				_p38 = _p38.replace(_i76, "[i]")
				_p38 = _p38.replace(_w24, "[/i]")
				var _r56 = RichTextLabel.new()
				_r56.bbcode_enabled = true
				_r56.fit_content = true
				_r56.scroll_active = false
				_r56.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				_r56.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
				_r56.add_theme_color_override("default_color", _i71)
				if _m100 == 0 and _u16:
					_r56.add_theme_font_size_override("normal_font_size", _k29)
					_r56.text = "[b][u]" + _p38 + "[/u][/b]"
					_t3.add_child(_r56)
				else:
					_r56.add_theme_font_size_override("normal_font_size", _j77)
					_r56.text = _p38
					_m31.add_child(_r56)
		if _u16:
			_a85.add_child(_t3)
			var _j97 = HSeparator.new()
			_j97.add_theme_constant_override("separation", 8)
			_a85.add_child(_j97)
		_a85.add_child(_m31)
		_g74.add_child(_a85)
		_i31.add_child(_g74)
		parent.add_child(_i31)
		_r33.clear()
		_u16 = false
	for i in range(_p91.size()):
		var line = _p91[i]
		var _w61 = line.strip_edges()
		var _y24 = _g40.search(_w61) != null
		if _y24:
			if not _r33.is_empty():
				_u16 = true
			continue
		var _o23 = _d15.search(_w61)
		if _o23:
			_x92.call()
			var _l88 = _o23.get_string(1).length()
			var _p87 = _o23.get_string(2)
			var _w45 = 24  
			if _l88 == 2:
				_w45 = 20  
			elif _l88 == 3:
				_w45 = 18  
			elif _l88 == 4:
				_w45 = 16  
			var _j77 = int(_w45 * _z5)
			var _d93 = _v100(_p87)
			_p94.append("\n[b][font_size=" + str(_j77) + "]" + _d93 + "[/font_size][/b]\n")
		elif _w61.begins_with("|") and _w61.ends_with("|"):
			var _k6 = _w61.split("|")
			var _w100: Array = []
			for _k15 in _k6:
				var _d14 = _k15.strip_edges()
				if _d14.is_empty():
					continue
				if _d14.match("^-+$") or _d14.match("^:?-+:?$"):
					continue
				_w100.append(_v100(_d14))
			if not _w100.is_empty():
				_r33.append(_w100)
		elif _w61.begins_with("* "):
			_x92.call()
			var _l51 = _w61.substr(2).replace("*", "")
			_p94.append("• " + _v100(_l51))
			if i < _p91.size() - 1 and not _p91[i + 1].strip_edges().begins_with("* "):
				_p94.append("")
		elif _w61.match("^[0-9]+\\."):
			_x92.call()
			_p94.append(_v100(_w61))
		else:
			_x92.call()
			_p94.append(_v100(line.replace("*", "")))
	_x92.call()
	_u42.call()
func _u3(code: String, language: String, parent: Node):
	var _z83 = MarginContainer.new()
	_z83.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_z83.add_theme_constant_override("margin_left", 16)
	_z83.add_theme_constant_override("margin_right", 16)
	_z83.add_theme_constant_override("margin_top", 12)
	_z83.add_theme_constant_override("margin_bottom", 12)
	var _c15 = PanelContainer.new()
	_c15.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not _i5:
		_g72()
	_c15.add_theme_stylebox_override("panel", _i5)
	var _z19 = VBoxContainer.new()
	_z19.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _u80 = PanelContainer.new()
	_u80.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_u80.add_theme_stylebox_override("panel", _c28)
	var _l39 = HBoxContainer.new()
	_l39.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_l39.layout_mode = 2  
	var _f56 = Label.new()
	_f56.layout_mode = 2
	_f56.text = _o1.get(language, "Code")
	_f56.add_theme_color_override("font_color", _l21)
	_l39.add_child(_f56)
	var _t25 = Control.new()
	_t25.layout_mode = 2
	_t25.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_l39.add_child(_t25)
	var _b44 = Button.new()
	_b44.layout_mode = 2
	_b44.text = "Copy"
	_b44.flat = true
	_b44.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_b44.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	_b44.pressed.connect(func(): _p89(code))
	_l39.add_child(_b44)
	_u80.add_child(_l39)
	_z19.add_child(_u80)
	var _f88 = MarginContainer.new()
	_f88.layout_mode = 2
	_f88.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_f88.add_theme_constant_override("margin_left", _u22.code_padding)
	_f88.add_theme_constant_override("margin_right", _u22.code_padding)
	_f88.add_theme_constant_override("margin_top", _u22.code_padding)
	_f88.add_theme_constant_override("margin_bottom", _u22.code_padding)
	var _k45 = RichTextLabel.new()
	_k45.bbcode_enabled = true
	_k45.selection_enabled = true
	_k45.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_k45.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_k45.fit_content = true
	_k45.scroll_active = false
	_k45.scroll_active = false
	var _l98 = _q60("text_color")
	_k45.add_theme_color_override("default_color", _l98)
	var _p60 = _s100(code, language)
	_k45.text = _p60
	var _q84 = SystemFont.new()
	_q84.font_names = ["Consolas", "Courier New", "Monospace"]
	_k45.add_theme_font_override("normal_font", _q84)
	_k45.add_theme_font_override("mono_font", _q84)
	_f88.add_child(_k45)
	_z19.add_child(_f88)
	_c15.add_child(_z19)
	_z83.add_child(_c15)
	parent.add_child(_z83)
func _s100(code: String, language: String) -> String:
	match language:
		"gdscript", "":
			return _d64(_x1(code))
		"csharp", "cs":
			return _i14(code)
		_:
			return code
func _p89(code: String):
	DisplayServer.clipboard_set(code)
func _i14(code: String) -> String:
	var _p60 = ""
	var _p91 = code.split("\n")
	var _z57 = RegEx.new()
	_z57.compile("\\b(" + "|".join(_q30) + ")\\b")
	var _x86 = RegEx.new()
	_x86.compile("\\b([A-Z][a-zA-Z0-9]*)\\b")
	var _g81 = RegEx.new()
	_g81.compile("\\b([a-z_][a-zA-Z0-9_]*)\\s*\\(")
	var _h45 = RegEx.new()
	_h45.compile("(\"[^\"]*\"|'[^']*')")
	var _r59 = RegEx.new()
	_r59.compile("\\b\\d+(\\.\\d+)?[fFdD]?\\b")
	var _p3 = RegEx.new()
	_p3.compile("(//.*$|/\\*.*?\\*/)")
	for line in _p91:
		if line.strip_edges().is_empty():
			_p60 += "\n"
			continue
		var _o10 = line
		_o10 = _p3.sub(_o10, "[color=#%s]$1[/color]" % [_q60("comment").to_html(false)], true)
		_o10 = _h45.sub(_o10, "[color=#%s]$1[/color]" % [_q60("string").to_html(false)], true)
		_o10 = _z57.sub(_o10, "[color=#%s]$1[/color]" % [_q60("keyword").to_html(false)], true)
		_o10 = _x86.sub(_o10, "[color=#%s]$1[/color]" % [_q60("class").to_html(false)], true)
		_o10 = _g81.sub(_o10, "[color=#%s]$1[/color](" % [_q60("function").to_html(false)], true)
		_o10 = _r59.sub(_o10, "[color=#%s]$0[/color]" % [_q60("number").to_html(false)], true)
		_p60 += _o10 + "\n"
	return _p60.strip_edges()
func _n15(text: String):
	var _p40 = PanelContainer.new()
	_p40.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_p40.add_theme_constant_override("margin_bottom", _u22.message_gap)
	var _f41 = Color("#ff6666")
	if _k71:
		var theme = _k71.get_editor_theme()
		if theme:
			_f41 = theme.get_color("error_color", "Editor")
	var _s48 = StyleBoxFlat.new()
	_s48.bg_color = _f41.darkened(0.8)
	_s48.border_color = _f41
	_s48.border_width_bottom = 1
	_s48.border_width_top = 1
	_s48.border_width_left = 1
	_s48.border_width_right = 1
	_s48.corner_radius_top_left = 8
	_s48.corner_radius_top_right = 8
	_s48.corner_radius_bottom_left = 8
	_s48.corner_radius_bottom_right = 8
	_s48.content_margin_left = _u22.padding
	_s48.content_margin_right = _u22.padding
	_s48.content_margin_top = _u22.padding
	_s48.content_margin_bottom = _u22.padding
	_p40.add_theme_stylebox_override("panel", _s48)
	var _c71 = VBoxContainer.new()
	_c71.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_c71.layout_mode = 2  
	var _q28 = _f41.lightened(0.3)  
	var _o93 = Color(1.0, 0.9, 0.9)  
	var _v66 = Label.new()
	_v66.text = "GDSense Error"
	_v66.add_theme_color_override("font_color", _q28)
	_v66.add_theme_font_size_override("font_size", 16)
	_c71.add_child(_v66)
	var _h29 = Label.new()
	_h29.text = text
	_h29.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_h29.add_theme_color_override("font_color", _o93)
	_c71.add_child(_h29)
	_p40.add_child(_c71)
	_r70.add_child(_p40)
func _n88():
	var _p40 = PanelContainer.new()
	_p40.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_p40.add_theme_constant_override("margin_bottom", _u22.message_gap)
	if not _i100:
		_g72()
	_p40.add_theme_stylebox_override("panel", _i100)
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.selection_enabled = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.fit_content = true
	label.scroll_active = false
	label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	label.add_theme_color_override("default_color", _j64("font_color"))
	label.text = "[b]Welcome to GDSense![/b] Your AI coding partner for Godot."
	_p40.add_child(label)
	_r70.add_child(_p40)
func _m27(text: String):
	if text.strip_edges().is_empty():
		return
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.selection_enabled = true
	label.text = _v100(text)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.fit_content = true
	label.scroll_active = false
	label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	label.add_theme_color_override("default_color", _i71)
	_r70.add_child(label)
func _r8() -> void:
	_r37 = OptionButton.new()
	_r37.name = "AgentModelSelector"
	_f60()
	_r37.visible = false  
	_r37.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _b62:
		var _o95 = _b62.get_parent()
		if _o95:
			var _r75 = _o95.get_children().find(_b62)
			_o95.add_child(_r37)
			_o95.move_child(_r37, _r75)
func _t29():
	_y71.clear()
	_b62.clear()
	var _x88 = []
	if _r46:
		_x88 = _r46._k12()
	else:
		_x88 = [
			"openai/gpt-oss-20b",
			"gemini-2.5-flash-lite",
			"gpt-5-nano"
		]
	for _c33 in _x88:
		var _r69: String
		var _i21: String
		if _c33 is Dictionary and _c33.has("id"):
			_i21 = _c33.get("id", "")
			_r69 = _c33.get("display_name", _i21)
		else:
			_i21 = str(_c33)
			_r69 = _g73.get(_i21, _i21)
		_y71.add_item(_r69)
		_b62.add_item(_r69)
	if _r46:
		var _s26 = _r46._v41()
		if _s2(_s26, _x88):
			_t76(_s26)
		else:
			if _x88.size() > 0:
				var _q4 = _r79(_x88[0])
				_t76(_q4)
				_r46._m58(_q4)
	_o43()
func _r79(_c33) -> String:
	if _c33 is Dictionary and _c33.has("id"):
		return _c33.get("id", "")
	return str(_c33)
func _s2(_i21: String, _x88: Array) -> bool:
	for _c33 in _x88:
		var _g63 = _r79(_c33)
		if _g63 == _i21:
			return true
	return false
func _o43():
	pass
func _f43(index: int) -> String:
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
func _s57(index: int) -> void:
	var _x88 = []
	if _r46:
		_x88 = _r46._k12()
	if index < 0 or index >= _x88.size():
		return
	var _i21 = _r79(_x88[index])
	if _r46:
		_r46._m58(_i21)
	_y71.selected = index
	_b62.selected = index
	_o16(true)
func _t76(model: String) -> void:
	var _x88 = []
	if _r46:
		_x88 = _r46._k12()
	for i in range(_x88.size()):
		var _g63 = _r79(_x88[i])
		if _g63 == model:
			_y71.selected = i
			_b62.selected = i
			return
	_y71.selected = 0
	_b62.selected = 0
func _p5():
	if not _r46 or not _r46._b17():
		return
	_a43 = HBoxContainer.new()
	_a43.add_theme_constant_override("separation", 10)
	_q21 = Label.new()
	_q21.text = "Environment:"
	_a43.add_child(_q21)
	_n66 = OptionButton.new()
	_n66.add_item("Production")
	_n66.add_item("Development (localhost:8080)")
	var _y16 = _r46._j19() if _r46 else "production"
	if _y16 == "development":
		_n66.selected = 1
	else:
		_n66.selected = 0
	_n66.item_selected.connect(_n71)
	_a43.add_child(_n66)
	var _l18 = Label.new()
	_l18.text = "[DEV MODE]"
	_l18.modulate = Color(1, 0.5, 0.5)
	_a43.add_child(_l18)
	var _p81 = _j69.get_parent()
	var parent = _p81.get_parent()
	var index = parent.get_children().find(_p81)
	parent.add_child(_a43)
	parent.move_child(_a43, index + 1)
func _f60() -> void:
	if not _r37:
		return
	_r37.clear()
	var _x88 = []
	if _r46:
		_x88 = _r46._l40()
	if _x88.size() > 0 and _x88[0] is Dictionary and _x88[0].has("id"):
		for _c33 in _x88:
			var _r69 = _c33.get("display_name", _c33.get("id", "Unknown"))
			_r37.add_item(_r69)
	else:
		for _y55 in _g16:
			_r37.add_item(_y55["name"])
	_r37.selected = 0  
func _q26() -> String:
	if not _r37:
		return ""
	var _g99 = _r37.selected
	if _g99 < 0:
		return ""
	var _x88 = []
	if _r46:
		_x88 = _r46._l40()
	if _x88.size() > 0 and _x88[0] is Dictionary and _x88[0].has("id"):
		if _g99 < _x88.size():
			return _x88[_g99].get("id", "")
	else:
		if _g99 < _g16.size():
			return _g16[_g99]["id"]
	return ""
func _n71(index: int):
	var _t5 = ["production", "development"][index]
	var _i19 = ""
	if _r46:
		_r46._s71(_t5)
		_i19 = _r46._a77()
		_j69.text = _i19
	if _i19.is_empty():
		_l47.text = "No API Key (%s)" % _t5.capitalize()
	else:
		_l47.text = "API Key Loaded (%s)" % _t5.capitalize()
func _q9():
	if not _w77:
		return
	var _j97 = HSeparator.new()
	_w77.add_child(_j97)
	var _m97 = VBoxContainer.new()
	_m97.add_theme_constant_override("separation", 5)
	_w77.add_child(_m97)
	var _m48 = Label.new()
	_m48.text = "Ghost Text Autocomplete"
	_m48.add_theme_font_size_override("font_size", int(20 * _z5))
	_m97.add_child(_m48)
	_m75 = CheckBox.new()
	_m75.text = "Enable Autocomplete"
	_m75.button_pressed = true  
	_m75.toggled.connect(_w50)
	_m97.add_child(_m75)
	var _o45 = HBoxContainer.new()
	_o45.layout_mode = 2
	_m97.add_child(_o45)
	var _x28 = Label.new()
	_x28.text = "Trigger Mode:"
	_x28.custom_minimum_size.x = 150
	_o45.add_child(_x28)
	_z93 = OptionButton.new()
	_z93.layout_mode = 2
	_z93.add_item("Automatic")
	_z93.add_item("Manual (Ctrl+Space)")
	_z93.selected = 0
	_z93.item_selected.connect(_m91)
	_o45.add_child(_z93)
	var _f35 = HBoxContainer.new()
	_f35.layout_mode = 2
	_m97.add_child(_f35)
	var _h42 = Label.new()
	_h42.text = "Minimum Characters:"
	_h42.custom_minimum_size.x = 150
	_f35.add_child(_h42)
	_y62 = SpinBox.new()
	_y62.layout_mode = 2
	_y62.min_value = 1
	_y62.max_value = 10
	_y62.value = 3
	_y62.step = 1
	_y62.value_changed.connect(_t77)
	_f35.add_child(_y62)
	var _i49 = Label.new()
	_i49.text = "Smart triggers: After '.', '(', ':', '=', or space following keywords"
	_i49.layout_mode = 2
	var _c82 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_i49.add_theme_color_override("font_color", Color(_c82, 0.6))
	_i49.set_meta("secondary", true)
	_i49.add_theme_font_size_override("font_size", 12)
	_i49.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_m97.add_child(_i49)
	var _w91 = HSeparator.new()
	_m97.add_child(_w91)
	var _b84 = HBoxContainer.new()
	_b84.layout_mode = 2
	_m97.add_child(_b84)
	var _z39 = Label.new()
	_z39.text = "Inline Explain Buttons"
	_z39.add_theme_font_size_override("font_size", int(16 * _z5))
	_b84.add_child(_z39)
	_r52 = CheckBox.new()
	_r52.text = "Show Explain Buttons Above Functions"
	_r52.button_pressed = true  
	_r52.toggled.connect(_y75)
	_m97.add_child(_r52)
	var _j84 = Label.new()
	_j84.text = "Adds clickable help icons above function declarations to explain code"
	_j84.layout_mode = 2
	var _u41 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_j84.add_theme_color_override("font_color", Color(_u41, 0.6))
	_j84.set_meta("secondary", true)
	_j84.add_theme_font_size_override("font_size", 12)
	_j84.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_m97.add_child(_j84)
	var _z26 = HSeparator.new()
	_m97.add_child(_z26)
	var _k80 = Label.new()
	_k80.text = "Inline Refactor Buttons"
	_k80.add_theme_font_size_override("font_size", int(18 * _z5))
	_m97.add_child(_k80)
	_e57 = CheckBox.new()
	_e57.text = "Show Refactor Buttons Above Functions"
	_e57.button_pressed = true  
	_e57.toggled.connect(_o64)
	_m97.add_child(_e57)
	var _d38 = Label.new()
	_d38.text = "Adds clickable ↻ icons above function declarations for AI-powered refactoring"
	_d38.layout_mode = 2
	var _s50 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_d38.add_theme_color_override("font_color", Color(_s50, 0.6))
	_d38.set_meta("secondary", true)
	_d38.add_theme_font_size_override("font_size", 12)
	_d38.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_m97.add_child(_d38)
	var _f16 = HSeparator.new()
	_m97.add_child(_f16)
	_p31(_m97)
	_g58()
func _g58():
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		_m75.button_pressed = config.get_value("autocomplete", "enabled", true)
		var mode = config.get_value("autocomplete", "mode", "automatic")
		_z93.selected = 0 if mode == "automatic" else 1
		_y62.value = config.get_value("autocomplete", "min_chars", 3)
		_r52.button_pressed = config.get_value("explain_button", "enabled", true)
		_e57.button_pressed = config.get_value("refactor_button", "enabled", true)
		var _b50 = find_child("_u52", true)
		var _c47 = find_child("_v82", true)
		var _s64 = find_child("_d88", true)
		if _b50:
			_b50.button_pressed = config.get_value("undo", "enabled", true)
		if _c47:
			_c47.value = config.get_value("undo", "max_history_items", 20)
		if _s64:
			_s64.button_pressed = config.get_value("undo", "show_history_button", true)
func _b30():
	var mode = "automatic" if _z93.selected == 0 else "manual"
	const _j58 = 1000
	const _v18 = 150
	if _q86 and _q86.has_method("save_autocomplete_config"):
		_q86.save_autocomplete_config(
			_m75.button_pressed,
			_j58,
			_v18,
			mode,
			int(_y62.value)
		)
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_api_key.cfg")
		config.set_value("autocomplete", "enabled", _m75.button_pressed)
		config.set_value("autocomplete", "delay_ms", _j58)
		config.set_value("autocomplete", "max_length", _v18)
		config.set_value("autocomplete", "mode", mode)
		config.set_value("autocomplete", "min_chars", int(_y62.value))
		config.save("user://gdsense_api_key.cfg")
func _w50(enabled: bool):
	_b30()
func _m91(index: int):
	_b30()
func _t77(value: float):
	_b30()
func _y75(enabled: bool):
	if _q86 and _q86.has_method("save_explain_button_config"):
		_q86.save_explain_button_config(enabled)
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_api_key.cfg")
		config.set_value("explain_button", "enabled", enabled)
		config.save("user://gdsense_api_key.cfg")
func _o64(enabled: bool):
	if _q86 and _q86.has_method("save_refactor_config"):
		_q86.save_refactor_config(enabled)
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_api_key.cfg")
		config.set_value("refactor_button", "enabled", enabled)
		config.save("user://gdsense_api_key.cfg")
func _p31(_u58: VBoxContainer):
	var _b7 = Label.new()
	_b7.text = "Refactor Undo System"
	_b7.add_theme_font_size_override("font_size", int(18 * _z5))
	_u58.add_child(_b7)
	var _b50 = CheckBox.new()
	_b50.name = "UndoEnabledCheckbox"
	_b50.text = "Enable Undo for Refactored Functions"
	_b50.button_pressed = true  
	_b50.toggled.connect(_o6)
	_u58.add_child(_b50)
	var _u2 = HBoxContainer.new()
	_u2.layout_mode = 2
	_u58.add_child(_u2)
	var _y12 = Label.new()
	_y12.text = "Max History Items:"
	_y12.custom_minimum_size.x = 150
	_u2.add_child(_y12)
	var _c47 = SpinBox.new()
	_c47.name = "MaxHistorySpinbox"
	_c47.layout_mode = 2
	_c47.min_value = 5
	_c47.max_value = 50
	_c47.value = 20
	_c47.step = 1
	_c47.value_changed.connect(_j80)
	_u2.add_child(_c47)
	var _s64 = CheckBox.new()
	_s64.name = "ShowHistoryCheckbox"
	_s64.text = "Show History Button in Panel"
	_s64.button_pressed = true  
	_s64.toggled.connect(_f85)
	_u58.add_child(_s64)
	var _i22 = Label.new()
	_i22.text = "Track refactored functions with visual indicators and one-click undo"
	_i22.layout_mode = 2
	_i22.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_i22.add_theme_font_size_override("font_size", 12)
	_i22.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_u58.add_child(_i22)
func _o6(enabled: bool):
	if _q86 and _q86.has_method("save_undo_config"):
		_q86.save_undo_config(enabled)
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_settings.cfg")
		config.set_value("undo", "enabled", enabled)
		config.save("user://gdsense_settings.cfg")
func _j80(value: float):
	if _q86 and _q86.has_method("save_undo_max_history"):
		_q86.save_undo_max_history(int(value))
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_settings.cfg")
		config.set_value("undo", "max_history_items", int(value))
		config.save("user://gdsense_settings.cfg")
func _f85(enabled: bool):
	if _q86 and _q86.has_method("save_undo_show_history"):
		_q86.save_undo_show_history(enabled)
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_settings.cfg")
		config.set_value("undo", "show_history_button", enabled)
		config.save("user://gdsense_settings.cfg")
func _s37():
	if not _w77:
		return
	var _j97 = HSeparator.new()
	_w77.add_child(_j97)
	var _e45 = VBoxContainer.new()
	_e45.add_theme_constant_override("separation", 10)
	_w77.add_child(_e45)
	var _b1 = Label.new()
	_b1.text = "Custom Instructions"
	_b1.add_theme_font_size_override("font_size", int(20 * _z5))
	_e45.add_child(_b1)
	var _a34 = HBoxContainer.new()
	_e45.add_child(_a34)
	var _w27 = Label.new()
	_w27.text = "Godot Version:"
	_w27.custom_minimum_size.x = 120
	_a34.add_child(_w27)
	var _c1 = Label.new()
	_c1.text = _r46._o31() if _r46 else "Unknown"
	var _s13 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_c1.add_theme_color_override("font_color", Color(_s13, 0.6))
	_c1.set_meta("secondary", true)
	_a34.add_child(_c1)
	var _t80 = HBoxContainer.new()
	_e45.add_child(_t80)
	var _p59 = Label.new()
	_p59.text = "Temperature:"
	_p59.custom_minimum_size.x = 120
	_t80.add_child(_p59)
	var _g39 = SpinBox.new()
	_g39.name = "TemperatureSpinBox"
	_g39.min_value = 0.0
	_g39.max_value = 1.0
	_g39.step = 0.1
	_g39.value = 0.0
	_g39.value_changed.connect(_j12)
	_t80.add_child(_g39)
	var _k41 = Label.new()
	_k41.text = "(0.0 = use default)"
	var _v56 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_k41.add_theme_color_override("font_color", Color(_v56, 0.6))
	_k41.set_meta("secondary", true)
	_k41.add_theme_font_size_override("font_size", 11)
	_t80.add_child(_k41)
	var _u6 = Label.new()
	_u6.text = "Custom Rules (500 char limit):"
	_u6.add_theme_font_size_override("font_size", int(18 * _z5))
	_e45.add_child(_u6)
	_l46 = TextEdit.new()
	_l46.name = "CustomRulesInput"
	_l46.custom_minimum_size = Vector2(0, 100)
	_l46.placeholder_text = "Enter custom rules for AI responses (one per line)..."
	_l46.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_l46.text_changed.connect(_o32)
	_e45.add_child(_l46)
	_i2 = Label.new()
	_i2.name = "CharCounter"
	_i2.text = "0/500"
	_i2.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_i2.add_theme_font_size_override("font_size", 12)
	_i2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_e45.add_child(_i2)
	_p85 = Label.new()
	_p85.name = "ValidationMessage"
	_p85.text = ""
	_p85.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	_p85.add_theme_font_size_override("font_size", 12)
	_p85.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_p85.visible = false
	_e45.add_child(_p85)
	_d17.call_deferred()
func _a73():
	_g38 = _m71.new()
	_g38._v97()
	if _w66:
		_w66.item_selected.connect(_w67)
	if _h74:
		_h74.item_selected.connect(_l49)
	if _s18:
		_s18.pressed.connect(_r23)
	if _s51:
		_s51.pressed.connect(_n1)
	if _u24:
		_u24.pressed.connect(_b74)
	if _m50:
		_m50.pressed.connect(_a94)
	if _g96:
		_g96.pressed.connect(_i24)
	if _m85:
		_m85.pressed.connect(_y50)
	if _n62:
		_n62.pressed.connect(_n9)
	if _a9:
		_a9.pressed.connect(_t79)
	if _u92:
		_u92.pressed.connect(_h13)
	if _a57:
		_a57.pressed.connect(_s28)
	if _z75:
		_z75.pressed.connect(_w48)
	if _a24:
		_a24.pressed.connect(_u28)
	if _j47:
		_j47.file_selected.connect(_l33)
	if _y77:
		_y77.file_selected.connect(_l17)
	if _z27:
		_z27.confirmed.connect(_y14)
	_w11()
	_h15()
func _p86():
	if _n73:
		_n73.item_selected.connect(_t49)
	_v11()
	var _r7 = _x25()
	var _d33 = _k44()
	_p51.text = "Auto: %.0f%% (%s detected). Your resolution: %dx%d" % [
		_d33 * 100,
		_r7,
		get_viewport().get_visible_rect().size.x,
		get_viewport().get_visible_rect().size.y
	]
	_n51()
func _x25() -> String:
	var _o67 = get_viewport().get_visible_rect().size
	var width = int(_o67.x)
	var height = int(_o67.y)
	if width < 800 or width > 16384 or height < 600 or height > 16384:
		width = 1920
		height = 1080
	var _j32 = 100
	for _w72 in _o75:
		var _o90 = _o75[_w72]
		if abs(width - _o90.width) <= _j32 and abs(height - _o90.height) <= _j32:
			return _w72
	var _a11 = width * height
	var _q61 = "1080p"
	var _y47 = INF
	for _w72 in _o75:
		var _o90 = _o75[_w72]
		var _g17 = _o90.width * _o90.height
		var _k74 = abs(_a11 - _g17)
		if _k74 < _y47:
			_y47 = _k74
			_q61 = _w72
	return _q61
func _k44() -> float:
	var _w72 = _x25()
	return _o75[_w72].scale
func _m44() -> float:
	if _f84 == "auto":
		return _k44()
	else:
		var _n89 = float(_f84)
		_n89 = clamp(_n89, 0.5, 3.0)  
		if is_nan(_n89) or is_inf(_n89):
			_n89 = 1.0  
		return _n89
func _n51():
	_z5 = _m44()
	var _m40 = int(_c20 * _z5)
	var _w92 = get_node_or_null("MarginContainer/TabContainer/History")
	if _w92:
		for label in _m2(_w92):
			if label is Label:
				label.add_theme_font_size_override("font_size", _m40)
			elif label is RichTextLabel:
				label.add_theme_font_size_override("normal_font_size", _m40)
	_m82(_m40)
func _m82(_m40: int):
	var _y53 = get_node_or_null("MarginContainer/TabContainer/Settings/_p82/VBoxContainer")
	if not _y53:
		return
	var _m29 = ["Ghost Text Autocomplete", "Custom Instructions"]
	var _d23 = ["Inline Explain Buttons", "Inline Refactor Buttons", "Refactor Undo System",
					   "Custom Rules", "Parameter Overrides"]
	for _x15 in _m2(_y53):
		if _x15 is Label:
			var _b90 = _x15.text
			var target_size = _m40
			for _i9 in _m29:
				if _b90.begins_with(_i9):
					target_size = int(20 * _z5)
					break
			if target_size == _m40:  
				for _g44 in _d23:
					if _b90.begins_with(_g44):
						target_size = int(18 * _z5)
						break
			_x15.add_theme_font_size_override("font_size", target_size)
		elif _x15 is RichTextLabel:
			_x15.add_theme_font_size_override("normal_font_size", _m40)
func _v77(text: String) -> bool:
	var _j8 = [
		"highest-volume", "smart triggers", "fixed settings", "adds clickable",
		"track refactored", "use default", "auto detects", "char limit",
		"following keywords", "second delay", "token max", "help icons",
		"visual indicators", "one-click undo", "AI-powered"
	]
	for _j73 in _j8:
		if _j73 in text:
			return true
	return false
func _m2(node: Node) -> Array:
	var children = []
	for _x15 in node.get_children():
		children.append(_x15)
		children.append_array(_m2(_x15))
	return children
func _t49(index: int):
	var _f8 = _h73[index]
	if typeof(_f8) == TYPE_STRING and _f8 == "auto":
		_f84 = "auto"
	else:
		_f84 = str(_f8)
	_x84()
	_n51()
	if _f84 == "auto":
		var _r7 = _x25()
		var _d33 = _k44()
		_p51.text = "Auto: %.0f%% (%s detected). Your resolution: %dx%d" % [
			_d33 * 100,
			_r7,
			get_viewport().get_visible_rect().size.x,
			get_viewport().get_visible_rect().size.y
		]
	else:
		_p51.text = "Manual: %.0f%%. Auto detects based on 1080p/1440p/4K presets" % [
			float(_f84) * 100
		]
func _x84():
	var config = ConfigFile.new()
	config.load("user://gdsense_settings.cfg")
	config.set_value("font_scale", "mode", _f84)
	config.save("user://gdsense_settings.cfg")
func _v11():
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		_f84 = config.get_value("font_scale", "mode", "auto")
		if _f84 == "auto":
			_n73.selected = 0
		elif _f84 == "0.8":
			_n73.selected = 1
		elif _f84 == "1.0":
			_n73.selected = 2
		elif _f84 == "1.25":
			_n73.selected = 3
		elif _f84 == "1.5":
			_n73.selected = 4
	else:
		_f84 = "auto"
		_n73.selected = 0
func _k13(parent: Node) -> void:
	var _t45 = HBoxContainer.new()
	_t45.add_theme_constant_override("separation", 10)
	var _t25 = Control.new()
	_t25.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_t45.add_child(_t25)
	var _u35 = Button.new()
	_u35.text = "👍"
	_u35.tooltip_text = "Good response"
	_u35.flat = false  
	_u35.custom_minimum_size = Vector2(36, 36)  
	_u35.add_theme_font_size_override("font_size", 16)
	_u35.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	_u35.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9))
	_u35.add_theme_stylebox_override("normal", _a7())
	_u35.add_theme_stylebox_override("hover", _h59())
	_u35.add_theme_stylebox_override("pressed", _g69())
	_u35.pressed.connect(_s20)
	_o29(_u35)
	_t45.add_child(_u35)
	var _l41 = Button.new()
	_l41.text = "👎"
	_l41.tooltip_text = "Poor response"
	_l41.flat = false  
	_l41.custom_minimum_size = Vector2(36, 36)  
	_l41.add_theme_font_size_override("font_size", 16)
	_l41.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	_l41.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9))
	_l41.add_theme_stylebox_override("normal", _a7())
	_l41.add_theme_stylebox_override("hover", _h59())
	_l41.add_theme_stylebox_override("pressed", _g69())
	_l41.pressed.connect(_o40)
	_o29(_l41)
	_t45.add_child(_l41)
	parent.add_child(_t45)
func _a7() -> StyleBoxFlat:
	var _c4 = StyleBoxFlat.new()
	_c4.bg_color = Color(0, 0, 0, 0)  
	_c4.set_corner_radius_all(4)
	return _c4
func _h59() -> StyleBoxFlat:
	var _c4 = StyleBoxFlat.new()
	_c4.bg_color = Color(0.3, 0.3, 0.3, 0.3)  
	_c4.set_corner_radius_all(6)
	_c4.set_border_width_all(1)
	_c4.border_color = Color(0.5, 0.5, 0.5, 0.5)
	return _c4
func _g69() -> StyleBoxFlat:
	var _c4 = StyleBoxFlat.new()
	_c4.bg_color = Color(0.2, 0.2, 0.2, 0.4)  
	_c4.set_corner_radius_all(6)
	_c4.set_border_width_all(1)
	_c4.border_color = Color(0.4, 0.4, 0.4, 0.6)
	return _c4
func _o29(_d75: Button) -> void:
	_d75.set_meta("original_scale", Vector2.ONE)
	_d75.set_meta("is_hovering", false)
	_d75.modulate.a = 0.7  
	_d75.pivot_offset = _d75.custom_minimum_size / 2  
	_d75.mouse_entered.connect(_i40.bind(_d75))
	_d75.mouse_exited.connect(_y27.bind(_d75))
	_d75.button_down.connect(_j13.bind(_d75))
	_d75.button_up.connect(_n34.bind(_d75))
func _i40(_d75: Button) -> void:
	if _d75.get_meta("is_hovering", false):
		return
	_d75.set_meta("is_hovering", true)
	var _o48 = get_tree().create_tween()
	_o48.set_parallel(true)
	_o48.set_ease(Tween.EASE_OUT)
	_o48.set_trans(Tween.TRANS_CUBIC)
	_o48.tween_property(_d75, "scale", Vector2(1.2, 1.2), 0.2)
	_o48.tween_property(_d75, "modulate:a", 1.0, 0.2)
	_o48.tween_property(_d75, "modulate", Color(1.1, 1.1, 1.1, 1.0), 0.2)
func _y27(_d75: Button) -> void:
	_d75.set_meta("is_hovering", false)
	var _o48 = get_tree().create_tween()
	_o48.set_parallel(true)
	_o48.set_ease(Tween.EASE_OUT)
	_o48.set_trans(Tween.TRANS_CUBIC)
	_o48.tween_property(_d75, "scale", Vector2.ONE, 0.2)
	_o48.tween_property(_d75, "modulate", Color(1.0, 1.0, 1.0, 0.7), 0.2)
func _j13(_d75: Button) -> void:
	var _o48 = get_tree().create_tween()
	_o48.set_ease(Tween.EASE_OUT)
	_o48.set_trans(Tween.TRANS_CUBIC)
	_o48.tween_property(_d75, "scale", Vector2(0.95, 0.95), 0.1)
func _n34(_d75: Button) -> void:
	var _v29 = Vector2(1.2, 1.2) if _d75.get_meta("is_hovering", false) else Vector2.ONE
	var _o48 = get_tree().create_tween()
	_o48.set_ease(Tween.EASE_OUT)
	_o48.set_trans(Tween.TRANS_CUBIC)
	_o48.tween_property(_d75, "scale", _v29, 0.1)
func _s20():
	if _r46:
		_r46._q81("positive", "helpful", "")
func _o40():
	_g47()
func _g47():
	var _c65 = AcceptDialog.new()
	_c65.title = "Help Us Improve"
	_c65.dialog_close_on_escape = true
	_c65.size = Vector2(400, 300)
	var _c71 = VBoxContainer.new()
	_c71.add_theme_constant_override("separation", 10)
	var _m36 = Label.new()
	_m36.text = "What was wrong with this response?"
	_c71.add_child(_m36)
	var _h26 = OptionButton.new()
	_h26.name = "CategoryOptions"
	_h26.add_item("Incorrect information")
	_h26.add_item("Wrong Godot version")
	_h26.add_item("Code doesn't work")
	_h26.add_item("Too complex")
	_h26.add_item("Not helpful")
	_h26.add_item("Other")
	_c71.add_child(_h26)
	var _i48 = Label.new()
	_i48.text = "Additional details (optional):"
	_c71.add_child(_i48)
	var _w30 = TextEdit.new()
	_w30.name = "DetailsText"
	_w30.custom_minimum_size = Vector2(0, 80)
	_w30.placeholder_text = "Describe what went wrong..."
	_c71.add_child(_w30)
	var _g48 = HBoxContainer.new()
	_g48.alignment = BoxContainer.ALIGNMENT_END
	var _c21 = Button.new()
	_c21.text = "Cancel"
	_c21.pressed.connect(_c65.hide)
	_g48.add_child(_c21)
	var _y99 = Button.new()
	_y99.text = "Submit Feedback"
	_y99.pressed.connect(_a10.bind(_c65))
	_g48.add_child(_y99)
	_c71.add_child(_g48)
	_c65.add_child(_c71)
	add_child(_c65)
	_c65.popup_centered()
func _a10(_w85: AcceptDialog):
	var _c71 = _w85.get_child(0)
	var _h26: OptionButton = null
	var _w30: TextEdit = null
	for _x15 in _c71.get_children():
		if _x15 is OptionButton and not _h26:
			_h26 = _x15
		elif _x15 is TextEdit and not _w30:
			_w30 = _x15
	var _p12 = ""
	if _h26.selected >= 0:
		_p12 = _h26.get_item_text(_h26.selected)
	var details = _w30.text.strip_edges()
	if _r46:
		_r46._q81("negative", _p12, details)
	_w85.hide()
	_w85.queue_free()
func _o32():
	if not _l46 or not _i2 or not _p85:
		return
	var _g21 = _l46.text
	var _d5 = _g21.length()
	_i2.text = "%d/500" % _d5
	if _d5 > 500:
		_i2.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	elif _d5 > 400:
		_i2.add_theme_color_override("font_color", Color(1.0, 0.8, 0.5))
	else:
		_i2.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	if _r46:
		var _q62 = _r46._q10(_g21)
		if _q62.get("valid", false):
			_p85.visible = false
			_r46._r62(_g21)
		else:
			var _u55 = _q62.get("errors", ["Unknown error"])
			_p85.text = _u55[0] if not _u55.is_empty() else "Unknown error"
			_p85.visible = true
func _j12(value: float):
	if _r46:
		var _j48 = find_child("_v38", true)
		var max_tokens = _j48.value if _j48 else 0
		_r46._x21(value, int(max_tokens))
func _s81(value: float):
	if _r46:
		var _g39 = find_child("_l34", true)
		var _a54 = _g39.value if _g39 else 0.0
		_r46._x21(_a54, int(value))
func _d17():
	if not _r46:
		return
	var _g39 = find_child("_l34", true)
	var _j48 = find_child("_v38", true)
	if _l46:
		var config = ConfigFile.new()
		if config.load("user://gdsense_settings.cfg") == OK:
			var _g21 = config.get_value("custom_rules", "rules_text", "")
			_l46.text = _g21
			if _i2:
				_i2.text = "%d/500" % _g21.length()
		else:
			pass
	else:
		pass
	if _g39:
		var config = ConfigFile.new()
		if config.load("user://gdsense_settings.cfg") == OK:
			var _a54 = config.get_value("parameters", "temperature_override", 0.0)
			_g39.value = _a54
	if _j48:
		var config = ConfigFile.new()
		if config.load("user://gdsense_settings.cfg") == OK:
			var max_tokens = config.get_value("parameters", "max_tokens_override", 0)
			_j48.value = max_tokens
func _r48(_x66: Array, parent: Node):
	var _j97 = HSeparator.new()
	_j97.add_theme_constant_override("separation", 8)
	parent.add_child(_j97)
	var _p61 = Label.new()
	_p61.text = "📚 Documentation Sources:"
	_p61.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	_p61.add_theme_font_size_override("font_size", 25)
	parent.add_child(_p61)
	var _v64 = VBoxContainer.new()
	_v64.add_theme_constant_override("separation", 1)
	parent.add_child(_v64)
	_x66.sort_custom(func(a, b): return a.get("priority", 0.0) > b.get("priority", 0.0))
	var _a48 = min(_x66.size(), 5)
	for i in range(_a48):
		var source = _x66[i]
		var _p8 = source.get("url", "")
		var title = source.get("title", "Godot Documentation")
		if not _p8.is_empty():
			var _e70 = HBoxContainer.new()
			_e70.add_theme_constant_override("separation", 8)
			_v64.add_child(_e70)
			var _k2 = Label.new()
			_k2.text = "•"
			_k2.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
			_k2.custom_minimum_size.x = 12
			_e70.add_child(_k2)
			var _s66 = Button.new()
			var _w86 = title if title.length() <= 60 else title.substr(0, 57) + "..."
			_s66.text = _w86
			_s66.tooltip_text = title  
			_s66.flat = true
			_s66.clip_text = true  
			_s66.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
			_s66.add_theme_color_override("font_hover_color", Color(0.8, 0.9, 1.0))
			_s66.add_theme_font_size_override("font_size", 20)
			_s66.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_s66.alignment = HORIZONTAL_ALIGNMENT_LEFT
			_s66.pressed.connect(_l15.bind(_p8))
			_e70.add_child(_s66)
func _l15(_p8: String):
	OS.shell_open(_p8)
func send_explain_request(function_name: String, _k94: String):
	if not _r46:
		return
	var _i62 = "@explain %s\n\nFunction source:\n```gdscript\n%s\n```" % [function_name, _k94]
	_t16(_i62)
func _j11(function_name: String, _k94: String):
	if not _d30:
		return
	_d30.text = ""
	var _i62 = "@explain %s\n\nFunction source:\n```gdscript\n%s\n```" % [function_name, _k94]
	_d30.text = _i62
	_d30.grab_focus()
	_d30.set_caret_line(_d30.get_line_count() - 1)
	_d30.set_caret_column(_d30.get_line(_d30.get_line_count() - 1).length())
func _exit_tree() -> void:
	_h91()
	_f30()
	_r31()
	_k64()
	if _b34:
		if _b34._q47.is_connected(_e13):
			_b34._q47.disconnect(_e13)
		if _b34._n50.is_connected(_o99):
			_b34._n50.disconnect(_o99)
		if _b34._e91.is_connected(_v10):
			_b34._e91.disconnect(_v10)
		if _b34._f28.is_connected(_g8):
			_b34._f28.disconnect(_g8)
		if _b34._l70.is_connected(_p68):
			_b34._l70.disconnect(_p68)
		if _b34._d10.is_connected(_a20):
			_b34._d10.disconnect(_a20)
		if _b34._u51.is_connected(_j59):
			_b34._u51.disconnect(_j59)
		if _b34._n70.is_connected(_h61):
			_b34._n70.disconnect(_h61)
		_b34._u75()
		_b34 = null
	_t36 = null
	if is_instance_valid(_a71):
		if _a71.pressed.is_connected(_h57):
			_a71.pressed.disconnect(_h57)
		_a71.queue_free()
		_a71 = null
	if _z87:
		if _z87._m93:
			_z87._m93.clear()
		_z87 = null
	if _u48:
		_u48._z87 = null
		_u48 = null
	if _i84:
		_i84._u75()
		_i84 = null
	if _r70:
		for _x15 in _r70.get_children():
			_x15.queue_free()
		_r70 = null
	_o85.clear()
	if _r46:
		if _r46._a16.is_connected(_k48):
			_r46._a16.disconnect(_k48)
		if _r46._b16.is_connected(_c94):
			_r46._b16.disconnect(_c94)
		if _r46._i36.is_connected(_g59):
			_r46._i36.disconnect(_g59)
		if _r46._l25.is_connected(_l4):
			_r46._l25.disconnect(_l4)
		if _r46._q89.is_connected(_s87):
			_r46._q89.disconnect(_s87)
		if _r46._k81.is_connected(_k34):
			_r46._k81.disconnect(_k34)
		if _r46._u64.is_connected(_w79):
			_r46._u64.disconnect(_w79)
	if _n64:
		_n64.free()
		_n64 = null
	_k71 = null
	_y11 = null
	_r46 = null
	_q86 = null
func _m61() -> void:
	if _e64:
		_e64.custom_minimum_size.y = 8
		_e64.show_percentage = false
		var _l73 = StyleBoxFlat.new()
		_l73.bg_color = Color(0.1, 0.1, 0.1, 0.5)
		_l73.corner_radius_top_left = 4
		_l73.corner_radius_top_right = 4
		_l73.corner_radius_bottom_left = 4
		_l73.corner_radius_bottom_right = 4
		_e64.add_theme_stylebox_override("background", _l73)
		_e64.mouse_entered.connect(_o52)
		_e64.mouse_exited.connect(_t11)
	_x76(0.0)
	if _p13:
		_p13.mouse_entered.connect(_o52)
		_p13.mouse_exited.connect(_t11)
func _l91() -> void:
	if not _f34:
		return
	_f34.clear()
	_f34.add_item("Commands")
	_f34.selected = 0
	_f34.add_separator()
	for _k52 in _s60:
		_f34.add_item(_k52)
	_f34.item_selected.connect(_j42)
func _n2() -> void:
	if not _a96:
		return
	_a96.clear()
	_a96.add_item(_j41[_f72])
	_f93()
	_a96.item_selected.connect(_j53)
	_n10()
func _n10() -> void:
	if not _a96 or not _k71:
		return
func _f93() -> void:
	if not _a96:
		return
	var _r58 = false
	if _r46:
		var _e19 = _r46._m90()
		if _e19 and _e19.has("features"):
			var features = _e19.get("features", {})
			_r58 = features.get("agent", false)
	var _y86 = _a96.item_count > 1
	if _r58:
		if not _y86:
			_a96.add_item(_j41[_a6])
	else:
		if _y86:
			if _a96.selected == _a6:
				_a96.selected = _f72
				_l75()
			_a96.remove_item(_a6)
func _j53(index: int) -> void:
	match index:
		_f72:
			_o41 = false
			if _y71:
				_y71.visible = true
			if _b62:
				_b62.visible = true
			if _r37:
				_r37.visible = false
			_d30.placeholder_text = "Ask me anything about Godot..."
		_a6:
			_l61()
	_d30.grab_focus()
func _c45() -> void:
	_x7()
	var _q92 = _d30.text
	var command_count = 0
	for _z91 in _s60:
		var _x62 = RegEx.new()
		_x62.compile(_z91 + "\\b")  
		var _w34 = _x62.search_all(_q92)
		command_count += _w34.size()
	if command_count != _x16:
		_x16 = command_count
		if _w99:
			_w99.stop()
			_w99.start()
func _f10() -> void:
	_o16(true)
func _r16(_k52: String, path: String) -> void:
	_o16(true)
func _o16(_a86: bool = false) -> void:
	if _z43 and not _a86:
		return
	var _q92 = _d30.text
	var _r87 = not _q92.strip_edges().is_empty()
	var _c88 = _o85.size() > 0
	if not _r87 and not _c88:
		_f75(0, [])
		return
	var _s36 = Time.get_ticks_msec()
	if not _a86 and not _b81.is_empty():
		var _i27 = _s36 - _b81.get("time", 0)
		if _i27 < _q63:
			var _g77 = _b81.get("tokens", 0)
			var _g18 = _b81.get("breakdown", [])
			_f75(_g77, _g18)
			return
	if _p13:
		_p13.text = "Context: Updating..."
	if _r46 and not _r46._a77().is_empty():
		var messages = []
		for message in _o85:
			messages.append(message)
		var context_metadata: Dictionary = {}
		if _r87:
			var _u70 = _w40(_q92, false)
			var processed_prompt = _u70.get("processed_prompt", _q92)
			if not processed_prompt.is_empty():
				messages.append({
					"role": "user",
					"content": processed_prompt
				})
			var _o27 = _u70.get("context_metadata", {})
			if _o27 == null or not _o27 is Dictionary:
				_o27 = {}
			context_metadata = _o27
		else:
			context_metadata = {}
		_r46._s12(messages, context_metadata)
	else:
		_e5()
func _e5() -> void:
	var _q92 = _d30.text
	var _u70 = _w40(_q92, false)
	var estimated_tokens = _u70.get("estimated_tokens", 0)
	var _c17 = _a30()
	var _d50 = estimated_tokens + _c17
	var breakdown = [
		{"name": "current_prompt", "tokens": estimated_tokens},
		{"name": "chat_history", "tokens": _c17}
	]
	_f75(_d50, breakdown)
func _a80(_c92: int, breakdown: Array, _y2: int = 128000) -> void:
	_r60 = _y2
	_b81 = {
		"tokens": _c92,
		"breakdown": breakdown,
		"limit": _y2,
		"time": Time.get_ticks_msec()
	}
	_f75(_c92, breakdown)
func _a30() -> int:
	var _e65 = 0
	for message in _o85:
		if message.has("content"):
			_e65 += message["content"].length()
	return _e65 / 4
func _f75(tokens: int, breakdown: Array) -> void:
	_y100 = tokens
	_e59 = breakdown
	var _d51 = float(tokens) / float(_r60) * 100.0
	if _e64:
		var _c5 = min(_d51, 100.0)
		if _c5 > 0 and _c5 < 0.5:
			_c5 = 0.5  
		_e64.value = _c5
	if _p13:
		if _d51 < 1.0 and _d51 > 0:
			_p13.text = "Context: " + str(snapped(_d51, 0.1)) + "%"
		else:
			_p13.text = "Context: " + str(int(_d51)) + "%"
		if _d51 >= 100.0:
			_p13.modulate = Color.RED
		elif _d51 >= 85.0:
			_p13.modulate = Color.YELLOW
		else:
			_p13.modulate = Color.LIGHT_GREEN
	_x76(_d51 / 100.0)
	if _d51 >= 95.0 and _r46:
		var _a8 = _r46._v41() if _r46 else ""
		_r46._m5.emit("critical", _a8, _d51, "")
	elif _d51 >= 90.0 and _r46:
		var _a8 = _r46._v41() if _r46 else ""
		_r46._m5.emit("high", _a8, _d51, "")
	elif _d51 >= 75.0 and _r46:
		var _a8 = _r46._v41() if _r46 else ""
		_r46._m5.emit("medium", _a8, _d51, "")
	if _d51 >= _l16 * 100.0:
		_r35.show()
		if _d51 >= 100.0:
			_r35.text = "⚠ Context capacity exceeded! Please reduce content."
			_r35.modulate = Color.RED
		else:
			_r35.text = "⚠ Context capacity at " + str(int(_d51)) + "% - consider reducing @ commands"
			_r35.modulate = Color.YELLOW
	else:
		_r35.hide()
func _j21() -> void:
	_f75(0, [])
	if _e64:
		_e64.tooltip_text = ""
	if _p13:
		_p13.tooltip_text = ""
	if _o2:
		_o2.hide()
func _x76(_t44: float) -> void:
	var color: Color
	if _t44 <= 0.6:  
		color = Color.GREEN
	elif _t44 <= 0.85:  
		color = Color.YELLOW
	else:  
		color = Color.RED
	var _p49 = StyleBoxFlat.new()
	_p49.bg_color = color
	_p49.corner_radius_top_left = 4
	_p49.corner_radius_top_right = 4
	_p49.corner_radius_bottom_left = 4
	_p49.corner_radius_bottom_right = 4
	if _e64:
		_e64.add_theme_stylebox_override("fill", _p49)
func _o52() -> void:
	var tooltip_text = "Context Usage Breakdown:\n"
	if _e59.size() > 0:
		for _d48 in _e59:
			if _d48 is Dictionary and _d48.has("name") and _d48.has("tokens"):
				var _z63 = _d48["tokens"]
				var _j15 = float(_z63) / float(_r60) * 100.0
				tooltip_text += str(_d48["name"]) + ": " + str(int(_j15)) + "%\n"
		tooltip_text = tooltip_text.rstrip("\n")
	else:
		tooltip_text += "No breakdown available"
	if _e64:
		_e64.tooltip_text = tooltip_text
	if _p13:
		_p13.tooltip_text = tooltip_text
func _t11() -> void:
	if _e64:
		_e64.tooltip_text = ""
	if _p13:
		_p13.tooltip_text = ""
func _j42(index: int) -> void:
	if index <= 1:
		return
	var _e67 = index - 2
	if _e67 >= 0 and _e67 < _s60.size():
		var _k52 = _s60[_e67]
		var _q92 = _d30.text
		var _t41 = _d30.get_caret_line()
		var caret_column = _d30.get_caret_column()
		if _t41 < _d30.get_line_count():
			var _h39 = _d30.get_line(_t41)
			var _a44 = _h39.substr(0, caret_column)
			var _z80 = _h39.substr(caret_column)
			var _q34 = _a44 + _k52 + " " + _z80
			_d30.set_line(_t41, _q34)
			_d30.set_caret_column(caret_column + _k52.length() + 1)
		else:
			_d30.text += _k52 + " "
			_d30.set_caret_column(_d30.text.length())
		_f34.selected = 0
		_o16()
		_d30.grab_focus()
func _h22(_x77: String) -> bool:
	var _k35 = [
		"truncated",
		"trimmed",
		"shortened",
		"context limit",
		"content limited"
	]
	var _a55 = _x77.to_lower()
	for _b8 in _k35:
		if _b8 in _a55:
			return true
	return false
func _j33(message: String) -> void:
	_o2.text = "ℹ " + message
	_o2.show()
	var _e34 = Timer.new()
	add_child(_e34)
	_e34.timeout.connect(func(): 
		_o2.hide()
		_e34.queue_free()
	)
	_e34.one_shot = true
	_e34.start(10.0)
func _n96(_h97: String) -> String:
	var _x63 = _h97.to_lower()
	if "token" in _x63 and ("limit" in _x63 or "exceed" in _x63):
		return "Your request is too large. Try reducing the amount of context or splitting into smaller requests."
	elif "rate limit" in _x63:
		return "You're sending requests too quickly. Please wait a moment before trying again."
	elif "unauthorized" in _x63 or "invalid api key" in _x63:
		return "Your API key is invalid or has expired. Please check your settings."
	elif "network" in _x63 or "connection" in _x63:
		return "Unable to connect to the AI service. Please check your internet connection."
	elif "timeout" in _x63:
		return "The request took too long to process. Please try again with a smaller request."
	elif "model" in _x63 and "not found" in _x63:
		return "The selected AI model is not available. Please try a different model."
	else:
		return _h97  
func _n52(_g93: Dictionary) -> void:
	_t29()
	_f60()
	_v16()
	_f93()
	_y7(_g93)
func _g60(_c95: String) -> String:
	if _c95.is_empty():
		return ""
	var _x12 = _c95.split("T")[0] if "T" in _c95 else _c95
	var _c57 = _x12.split("-")
	if _c57.size() < 3:
		return _c95  
	var year = _c57[0]
	var month = int(_c57[1]) if _c57[1].is_valid_int() else 0
	var day = int(_c57[2]) if _c57[2].is_valid_int() else 0
	if month < 1 or month > 12 or day < 1 or day > 31:
		return _c95  
	var _m98 = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
					   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%s %d, %s" % [_m98[month - 1], day, year]
func _l31(_e30: String, _i61: String, _d51: float, _q3: String = "") -> void:
	var _z29 = _y6()
	if _z29:
		var title = ""
		var message = ""
		var _z4 = _n28._t78.WARNING
		var _n79 = "credits"
		match _e30:
			"low":  
				title = "Usage Notice"
				message = "You've used %d%% of your %s for this period." % [int(_d51), _n79]
				_z4 = _n28._t78.INFO
			"medium":  
				title = "Usage Alert"
				message = "Heads up: you've used %d%% of your %s this period." % [int(_d51), _n79]
			"high":    
				title = "Usage Warning"
				message = "You've used %d%% of your %s. Consider switching models or upgrading." % [int(_d51), _n79]
				_z4 = _n28._t78.WARNING
			"critical": 
				title = "Critical Usage"
				message = "Critical: only %d%% of your %s remain." % [int(100 - _d51), _n79]
				_z4 = _n28._t78.ERROR
		if not _q3.is_empty():
			var _g75 = _g60(_q3)
			message += " Usage resets on %s." % _g75
		if _r46:
			var _j38 = _r46._d68()
			if _j38 != "ULTRA" and _j38 != "BETA_FREE":
				message += " Upgrade: gdsense.com/pricing"
		_z29._p99(title, message, _z4, 8.0)  
	if _e30 == "critical" and _l47:
		var _g85 = "⚠️ CRITICAL: %d%% of credits used" % [int(_d51)]
		_l47.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))  
		_l47.text = _g85
		await get_tree().create_timer(10.0).timeout
		if is_instance_valid(_l47):
			_l47.remove_theme_color_override("font_color")
			if _r46 and _r46._u46():
				_l47.text = "API Key Loaded"
				var _e19 = _r46._m90()
				if _e19 and _e19.has("tier"):
					_y7(_e19)
			else:
				_l47.text = "No API Key"
func _w79(message: String) -> void:
	var _z29 = _y6()
	if _z29:
		_z29._p99("Context Truncated", message, _n28._t78.WARNING, 5.0)
func _v16() -> void:
	if not _r46:
		return
	var _n53 = _r46._n53()
	if _e57:
		_e57.disabled = not _n53
		if not _n53:
			_e57.button_pressed = false
			_e57.tooltip_text = "Refactor is not available in Free tier"
		else:
			_e57.tooltip_text = "Show Refactor Buttons Above Functions"
	if _q86 and _q86.has_method("update_refactor_button_availability"):
		_q86.update_refactor_button_availability(_n53)
func _e93() -> void:
	if _p21:
		return  
	_p21 = PanelContainer.new()
	_p21.name = "UpdateBanner"
	_p21.visible = false
	var _z56 = StyleBoxFlat.new()
	if _k71:
		var _w36 = _k71.get_editor_settings()
		if _w36:
			var _v22 = _w36.get_setting("interface/theme/base_color")
			var _g56 = _w36.get_setting("interface/theme/accent_color")
			_z56.bg_color = _g56.lerp(_v22, 0.8)  
		else:
			_z56.bg_color = Color(0.2, 0.4, 0.6, 1.0)  
	else:
		_z56.bg_color = Color(0.2, 0.4, 0.6, 1.0)  
	_z56.set_corner_radius_all(4)
	_z56.set_content_margin_all(8)
	_p21.add_theme_stylebox_override("panel", _z56)
	var _u86 = HBoxContainer.new()
	_u86.add_theme_constant_override("separation", 8)
	var _x39 = Label.new()
	_x39.name = "UpdateMessage"
	_x39.text = "Update Available"
	_x39.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_u86.add_child(_x39)
	var _h71 = Label.new()
	_h71.name = "DownloadLink"
	_h71.text = "Download at gdsense.com"
	_h71.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))  
	_u86.add_child(_h71)
	var _h18 = Button.new()
	_h18.name = "DismissButton"
	_h18.text = "X"
	_h18.tooltip_text = "Dismiss update notification"
	_h18.custom_minimum_size = Vector2(24, 24)
	_h18.flat = true
	_h18.pressed.connect(_u88)
	_u86.add_child(_h18)
	_p21.add_child(_u86)
	var _i51 = get_node_or_null("MarginContainer/TabContainer/Chat")
	if _i51:
		var _o79 = _i51.get_child(0) if _i51.get_child_count() > 0 else null
		if _o79 and _o79 is VBoxContainer:
			_o79.add_child(_p21)
			_o79.move_child(_p21, 0)  
		else:
			_i51.add_child(_p21)
	else:
		add_child(_p21)
func _i95(_v8: String, _j18: String) -> void:
	if _q67:
		return
	if not _p21:
		_e93()
	var _x39 = _p21.find_child("_v20", true)
	if _x39:
		_x39.text = "Update Available: v%s (you have v%s)" % [_v8, _j18]
	_p21.visible = true
func _u88() -> void:
	_q67 = true
	if _p21:
		_p21.visible = false
func _y7(_g93: Dictionary) -> void:
	var _j38 = _g93.get("tier", "Unknown")
	if _l47:
		var _q92 = _l47.text
		if "API Key Loaded" in _q92:
			if _r46 and _r46._b17():
				var env = _r46._j19()
				_l47.text = "API Key Loaded (%s) - %s Tier" % [env.capitalize(), _j38]
			else:
				_l47.text = "API Key Loaded - %s Tier" % _j38
	_j99()
func _j99() -> void:
	if _a71:
		return  
	if not _l47 or not _r46:
		return
	_a71 = Button.new()
	_a71.text = "↻"  
	_a71.tooltip_text = "Refresh tier info"
	_a71.flat = true
	_a71.custom_minimum_size = Vector2(24, 24)
	_a71.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_o96(_a71)
	var parent = _l47.get_parent()
	if parent:
		var _l94 = _l47.get_index()
		parent.add_child(_a71)
		parent.move_child(_a71, _l94 + 1)
	_a71.pressed.connect(_h57)
func _h57() -> void:
	if _r46:
		_r46._n80()
func _e78(model: String) -> String:
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
func _y6() -> _n28:
	var _z29 = find_child("_n28", true)
	if _z29 and _z29 is _n28:
		return _z29
	var _v98 = preload("res://addons/gdsense/scenes/_n78.tscn")
	if _v98:
		_z29 = _v98.instantiate()
		if _n64:
			var _k71 = _n64.get_editor_interface()
			if _k71:
				_z29._r95(_k71)
		add_child(_z29)
		_z29.z_index = 1000
		return _z29
	return null
func _h15():
	if not _g38:
		return
	_q58()
	_o19()
	_y65()
func _q58():
	if not _g38 or not _w66:
		return
	var recent_chats = _g38._n5()
	_w66.clear()
	_t81 = -1
	for _r10 in recent_chats:
		var _r69 = _r10._y97()
		var timestamp = _r10._v7()
		var _l26 = "%s - %s" % [_r69, timestamp]
		var index = _w66.add_item(_l26)
		_w66.set_item_metadata(index, _r10.timestamp)
		_w66.set_item_tooltip(index, _r10._c59(80))
	_i15()
	_w11()
func _o19():
	if not _g38 or not _h74:
		return
	var favorite_chats = _g38._n61()
	_h74.clear()
	_m67 = -1
	for _r10 in favorite_chats:
		var _r69 = _r10._y97()
		var timestamp = _r10._v7()
		var _l26 = "★ %s - %s" % [_r69, timestamp]
		var index = _h74.add_item(_l26)
		_h74.set_item_metadata(index, _r10.timestamp)
		_h74.set_item_tooltip(index, _r10._c59(80))
	_v96()
	_w11()
func _y65():
	if not _g38 or not _p63:
		return
	var _k63 = _g38._n5().size()
	var _j63 = _g38._n61().size()
	_p63.text = "Recent: %d | Favorites: %d" % [_k63, _j63]
	var font_color = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_p63.add_theme_color_override("font_color", font_color)
func _w67(index: int):
	if index < 0 or not _g38:
		return
	_t81 = index
	var timestamp = _w66.get_item_metadata(index)
	var _r10 = _g38._b36(timestamp)
	if _r10:
		_w57(_r10)
	_w11()
func _l49(index: int):
	if index < 0 or not _g38:
		return
	_m67 = index
	var timestamp = _h74.get_item_metadata(index)
	var _r10 = _g38._b36(timestamp)
	if _r10:
		_v36(_r10)
	_w11()
func _w57(_r10: _m71._m35):
	if not _r10 or not _v63 or not _f32 or not _b4:
		return
	var _a67 = _r10._t1()
	_v63.text = "%s - %s (%d exchange%s)" % [
		_r10._y97(),
		_r10._v7(),
		_a67,
		"s" if _a67 != 1 else ""
	]
	_f32.bbcode_enabled = true
	_f32.text = _w33(_r10)
	var _v1 = _r10._n25 if not _r10._n25.is_empty() else "Unknown"
	_b4.text = "[Model: %s]\n[Session ID: %s]" % [_v1, _r10.session_id]
func _v36(_r10: _m71._m35):
	if not _r10 or not _x46 or not _u66 or not _f15:
		return
	var _a67 = _r10._t1()
	_x46.text = "%s - %s (%d exchange%s)" % [
		_r10._y97(),
		_r10._v7(),
		_a67,
		"s" if _a67 != 1 else ""
	]
	_u66.bbcode_enabled = true
	_u66.text = _w33(_r10)
	var _v1 = _r10._n25 if not _r10._n25.is_empty() else "Unknown"
	_f15.text = "[Model: %s]\n[Session ID: %s]" % [_v1, _r10.session_id]
func _w33(_r10: _m71._m35) -> String:
	var _s72 = ""
	for _c85 in _r10.exchanges:
		if not _c85 is Dictionary:
			continue
		var _p23 = _c85.get("user_message", "")
		if _p23.begins_with("@explain"):
			var _z89 = _p23.find("\n")
			if _z89 != -1:
				_p23 = _p23.substr(0, _z89) + " (code attached)"
		var _j83 = _p66.to_html()
		_s72 += "[b][color=#%s]You:[/color][/b]\n" % _j83
		_s72 += _v100(_p23) + "\n\n"
		var _b51 = _c85.get("ai_response", "")
		var _p26 = _i71.to_html()
		_s72 += "[b][color=#%s]GDSense:[/color][/b]\n" % _p26
		var _c57 = _b51.split("```")
		var _h52 = get_theme_color("base_color", "Editor")
		var _l56 = _h52.darkened(0.2) if _h52.get_luminance() > 0.5 else _h52.lightened(0.1)
		var _f47 = _l56.to_html()
		for i in range(_c57.size()):
			var _z78 = _c57[i]
			if i % 2 == 0:
				_s72 += _v100(_z78)
			else:
				var _u95 = _z78.find("\n")
				var _c8 = _z78
				if _u95 != -1:
					_c8 = _z78.substr(_u95 + 1)
				var _s62 = _d64(_c8)
				_s72 += "\n[bgcolor=#%s]%s[/bgcolor]\n" % [_f47, _s62]
		_s72 += "\n\n"
		_s72 += "[color=#666666]────────────────────────────────[/color]\n\n"
	return _s72
func _i15():
	if _v63:
		_v63.text = "Select a chat to preview"
	if _f32:
		_f32.text = "Select a chat to view"
	if _b4:
		_b4.text = "Select a chat to view"
func _v96():
	if _x46:
		_x46.text = "Select a favorite to preview"
	if _u66:
		_u66.text = "Select a favorite chat to view"
	if _f15:
		_f15.text = "Select a favorite chat to view"
func _v100(text: String) -> String:
	var _t65 = text
	_t65 = _t65.replace("[", "\\[")
	_t65 = _t65.replace("]", "\\]")
	return _t65
func _w11():
	var _z25 = _t81 >= 0
	if _s18:
		_s18.disabled = not _z25
	if _s51:
		_s51.disabled = not _z25
	if _u24:
		_u24.disabled = not _z25
	if _m50:
		_m50.disabled = not _z25
	var _b15 = _m67 >= 0
	if _g96:
		_g96.disabled = not _b15
	if _m85:
		_m85.disabled = not _b15
	if _n62:
		_n62.disabled = not _b15
	if _a9:
		_a9.disabled = not _b15
func _r23():
	if _t81 < 0 or not _g38:
		return
	var timestamp = _w66.get_item_metadata(_t81)
	var _r10 = _g38._b36(timestamp)
	if _r10:
		_w78(_r10)
func _n1():
	if _t81 < 0 or not _g38:
		return
	var timestamp = _w66.get_item_metadata(_t81)
	if _g38._u62(timestamp):
		_h15()
func _b74():
	if _t81 < 0 or not _g38:
		return
	var timestamp = _w66.get_item_metadata(_t81)
	var _r10 = _g38._b36(timestamp)
	if _r10:
		_c48 = timestamp
		_j68 = false
		_r92.text = _r10.custom_name
		_z27.popup_centered()
func _a94():
	if _t81 < 0 or not _g38:
		return
	var timestamp = _w66.get_item_metadata(_t81)
	if _g38._t97(timestamp):
		_h15()
func _i24():
	if _m67 < 0 or not _g38:
		return
	var timestamp = _h74.get_item_metadata(_m67)
	var _r10 = _g38._b36(timestamp)
	if _r10:
		_w78(_r10)
func _y50():
	if _m67 < 0 or not _g38:
		return
	var timestamp = _h74.get_item_metadata(_m67)
	if _g38._v62(timestamp):
		_h15()
func _n9():
	if _m67 < 0 or not _g38:
		return
	var timestamp = _h74.get_item_metadata(_m67)
	var _r10 = _g38._b36(timestamp)
	if _r10:
		_c48 = timestamp
		_j68 = true
		_r92.text = _r10.custom_name
		_z27.popup_centered()
func _t79():
	if _m67 < 0 or not _g38:
		return
	var timestamp = _h74.get_item_metadata(_m67)
	if _g38._t97(timestamp):
		_h15()
func _y14():
	if not _g38 or _c48.is_empty():
		return
	var _y39 = _r92.text.strip_edges()
	if _g38._b75(_c48, _y39):
		_h15()
	_c48 = ""
	_j68 = false
func _h13():
	if not _g38:
		return
	_g38._y35()
	_g38._d97()
	_h15()
func _s28():
	if not _g38:
		return
	_g38._y25()
	_g38._d97()
	_h15()
func _u28():
	var _y98: _m71._m35 = null
	if _w66 and _w66.get_selected_items().size() > 0:
		var _e75 = _w66.get_selected_items()[0]
		var recent_chats = _g38._n5()
		if _e75 < recent_chats.size():
			_y98 = recent_chats[_e75]
	elif _h74 and _h74.get_selected_items().size() > 0:
		var _e75 = _h74.get_selected_items()[0]
		var favorite_chats = _g38._n61()
		if _e75 < favorite_chats.size():
			_y98 = favorite_chats[_e75]
	if not _y98:
		_q24("Please select a chat session to export", Color(1, 0.7, 0.3))
		return
	var filename = "gdsense_session_%s.json" % _y98.session_id
	_j47.current_file = filename
	_j47.current_path = "user://" + filename
	_j47.popup_centered()
func _l33(path: String):
	var _y98: _m71._m35 = null
	if _w66 and _w66.get_selected_items().size() > 0:
		var _e75 = _w66.get_selected_items()[0]
		var recent_chats = _g38._n5()
		if _e75 < recent_chats.size():
			_y98 = recent_chats[_e75]
	elif _h74 and _h74.get_selected_items().size() > 0:
		var _e75 = _h74.get_selected_items()[0]
		var favorite_chats = _g38._n61()
		if _e75 < favorite_chats.size():
			_y98 = favorite_chats[_e75]
	if not _y98:
		push_error("[GDSense] Failed to export: No session selected")
		return
	var _h82 = {
		"format_version": "1.0",
		"exported_at": Time.get_datetime_string_from_system(),
		"session": _g38._w83(_y98)
	}
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		var _f74 = JSON.stringify(_h82, "\t")
		file.store_string(_f74)
		file.close()
		_q24("Session exported successfully", Color(0.3, 1, 0.5))
	else:
		push_error("[GDSense] Failed to write export file: %s" % path)
		_q24("Export failed: Could not write file", Color(1, 0.3, 0.3))
func _w48():
	_y77.current_path = "user://"
	_y77.popup_centered()
func _l17(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("[GDSense] Failed to open import file: %s" % path)
		_q24("Import failed: Could not open file", Color(1, 0.3, 0.3))
		return
	var _f74 = file.get_as_text()
	file.close()
	var json = JSON.new()
	var _n76 = json.parse(_f74)
	if _n76 != OK:
		push_error("[GDSense] Failed to parse import file: %s" % json.get_error_message())
		_q24("Import failed: Invalid JSON format", Color(1, 0.3, 0.3))
		return
	var _q68 = json.data
	if not _q68 is Dictionary:
		push_error("[GDSense] Import data is not a Dictionary")
		_q24("Import failed: Invalid data structure", Color(1, 0.3, 0.3))
		return
	if not _q68.has("format_version"):
		push_error("[GDSense] Import file missing format_version")
		_q24("Import failed: Missing format version", Color(1, 0.3, 0.3))
		return
	if _q68["format_version"] != "1.0":
		push_error("[GDSense] Unsupported format version: %s" % _q68["format_version"])
		_q24("Import failed: Unsupported format version", Color(1, 0.3, 0.3))
		return
	if not _q68.has("session"):
		push_error("[GDSense] Import file missing session data")
		_q24("Import failed: Missing session data", Color(1, 0.3, 0.3))
		return
	var _v70 = _q68["session"]
	if not _v70 is Dictionary:
		push_error("[GDSense] Session data is not a Dictionary")
		_q24("Import failed: Invalid session format", Color(1, 0.3, 0.3))
		return
	var _e90 = ["exchanges", "timestamp", "session_id"]
	for _p27 in _e90:
		if not _v70.has(_p27):
			push_error("[GDSense] Session missing required field: %s" % _p27)
			_q24("Import failed: Incomplete session data", Color(1, 0.3, 0.3))
			return
	if not _v70["exchanges"] is Array:
		push_error("[GDSense] Session exchanges is not an Array")
		_q24("Import failed: Invalid exchanges format", Color(1, 0.3, 0.3))
		return
	if _v70["exchanges"].is_empty():
		push_error("[GDSense] Session has no exchanges")
		_q24("Import failed: Empty session", Color(1, 0.3, 0.3))
		return
	for _c85 in _v70["exchanges"]:
		if not _c85 is Dictionary:
			push_error("[GDSense] Invalid exchange format")
			_q24("Import failed: Invalid exchange data", Color(1, 0.3, 0.3))
			return
		if not _c85.has("user_message") or not _c85.has("ai_response"):
			push_error("[GDSense] Exchange missing user_message or ai_response")
			_q24("Import failed: Incomplete exchange", Color(1, 0.3, 0.3))
			return
		if _c85["user_message"].length() > 100000 or _c85["ai_response"].length() > 500000:
			push_error("[GDSense] Exchange messages too long (possible attack)")
			_q24("Import failed: Messages exceed size limits", Color(1, 0.3, 0.3))
			return
		if _c85.has("enhanced_user_message") and _c85["enhanced_user_message"].length() > 200000:
			push_error("[GDSense] Enhanced message too long (possible attack)")
			_q24("Import failed: Messages exceed size limits", Color(1, 0.3, 0.3))
			return
	var _x40 = _g38._b36(_v70["timestamp"])
	if _x40:
		_q24("Warning: Session may already exist", Color(1, 0.7, 0.3))
	var _r93 = _g38._q90(_v70)
	if not _r93:
		push_error("[GDSense] Failed to convert imported data to ChatEntry")
		_q24("Import failed: Could not create session", Color(1, 0.3, 0.3))
		return
	_g38._d79.push_front(_r93)
	while _g38._d79.size() > _m71._f95:
		_g38._d79.pop_back()
	_g38._d97()
	_h15()
	_q24("Session imported successfully (%d exchanges)" % _r93._t1(), Color(0.3, 1, 0.5))
func _q24(message: String, color: Color):
	if color.r > color.g and color.r > color.b:
		pass
	else:
		pass
func _n36(message: String) -> String:
	var _f68 = _m71._m35._e24(message)
	if _f68 != message and OS.is_debug_build():
		pass
	return _f68
func _w78(_r10: _m71._m35):
	if not _r10:
		return
	_o85.clear()
	_h91()
	for _x15 in _r70.get_children():
		_x15.queue_free()
	var _g78 = _r10._k19()
	var _g4 = _r10._q20()
	_c84 = _g78 if _g78 else {}
	if _g4 and not _g4.is_empty():
		_x100 = _g4
	else:
		_x100.clear()  
	_e99()
	for _c85 in _r10.exchanges:
		if not _c85 is Dictionary:
			continue
		if not _c85.has("user_message") or not _c85.has("ai_response"):
			continue
		var _t73 = _n36(_c85["user_message"])
		if _t73.begins_with("@explain"):
			var _z89 = _t73.find("\n")
			if _z89 != -1:
				_t73 = _t73.substr(0, _z89) + " (code attached)"
		_y69(_t73)
		_g2(_c85["ai_response"], [])
		var _g3 = _c85.get("enhanced_user_message", _c85["user_message"])
		var _h97 = _n36(_c85["user_message"])
		_o85.append({"role": "user", "content": _g3, "original_content": _h97})
		var _b51 = {"role": "agent", "content": _c85["ai_response"]}
		if _c85.has("thought_signature") and not _c85["thought_signature"].is_empty():
			_b51["thought_signature"] = _c85["thought_signature"]
		_o85.append(_b51)
	if _b5:
		_b5.current_tab = 0
	_d12.call_deferred()
func _c9():
	var _q37 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	var _i18 = func(_g11: Node):
		if not _g11: return
		for _x15 in _g11.get_children():
			if _x15 is Label:
				if "Full Conversation" in _x15.text or "Session Info" in _x15.text:
					_x15.add_theme_color_override("font_color", _q37)
	if _f32:
		_i18.call(_f32.get_parent())
	if _u66:
		_i18.call(_u66.get_parent())
func _f17():
	_g72()
	_c9()
	_p67()
	if _g38:
		if _t81 >= 0:
			_w67(_t81)
		if _m67 >= 0:
			_l49(_m67)
func _p67():
	var _y53 = get_node_or_null("MarginContainer/TabContainer/Settings/_p82/VBoxContainer")
	if not _y53: return
	var _a68 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	var _u9 = Color(_a68, 0.6)
	var _h34 = func(node: Node, _n12: Callable):
		if node is Label:
			if node.has_meta("secondary"):
				node.add_theme_color_override("font_color", _u9)
			else:
				node.add_theme_color_override("font_color", _a68)
		for _x15 in node.get_children():
			_n12.call(_x15, _n12)
	_h34.call(_y53, _h34)
func _f83() -> void:
	_b34 = _z35.new()
	_b34.initialize(self, _r46)
	_b34._q47.connect(_e13)
	_b34._n50.connect(_o99)
	_b34._e91.connect(_v10)
	_b34._f28.connect(_g8)
	_b34._l70.connect(_p68)
	_b34._d10.connect(_a20)
	_b34._u51.connect(_j59)
	_b34._n70.connect(_h61)
	_t36 = _v17.new()
	_t36.initialize(_k71)
	_j6()
func _j6() -> void:
	_v28 = VBoxContainer.new()
	_v28.name = "AgentUIContainer"
	_v28.visible = false
	_v28.add_theme_constant_override("separation", 4)
	_b47 = Label.new()
	_b47.text = "Agent: Initializing..."
	_b47.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_v28.add_child(_b47)
	_a38 = ProgressBar.new()
	_a38.min_value = 0
	_a38.max_value = 100
	_a38.value = 0
	_a38.show_percentage = false
	_a38.custom_minimum_size = Vector2(0, 8)
	_v28.add_child(_a38)
	var _i51 = get_node_or_null("MarginContainer/TabContainer/Chat")
	if _i51:
		var _o79 = _i51.get_child(0) if _i51.get_child_count() > 0 else null
		if _o79 and _o79 is VBoxContainer:
			var _t42 = -1
			for i in range(_o79.get_child_count()):
				var _x15 = _o79.get_child(i)
				if _x15.name == "InputContainer" or (_x15 is HBoxContainer and _x15.get_node_or_null("_w39") != null):
					_t42 = i
					break
			if _t42 >= 0:
				_o79.add_child(_v28)
				_o79.move_child(_v28, _t42)
			else:
				_o79.add_child(_v28)
		else:
			add_child(_v28)
	else:
		add_child(_v28)
func _l61() -> void:
	_o41 = true
	if _a96 and _a96.item_count > _a6 and _a96.selected != _a6:
		_a96.selected = _a6
	if _y71:
		_y71.visible = false
	if _b62:
		_b62.visible = false
	if _r37:
		_r37.visible = true
	_d30.placeholder_text = "[Agent Mode] Describe your task..."
	_m77("Agent mode enabled. Describe your task and press Enter to start.")
func _l75() -> void:
	_o41 = false
	_b6.clear()
	_z3 = false
func _i20() -> void:
	if _v28:
		_v28.visible = true
	if _a38:
		_a38.value = 0
	if _b47:
		_b47.text = "Agent: Starting..."
	_z72()
func _d61() -> void:
	if _v28:
		_v28.visible = false
func _z72() -> void:
	_r31()  
	_i85 = HBoxContainer.new()
	_i85.name = "AgentCancelContainer"
	_i85.alignment = BoxContainer.ALIGNMENT_CENTER
	_x2 = Button.new()
	_x2.text = "Cancel Agent"
	_x2.pressed.connect(_z11)
	_i85.add_child(_x2)
	var _i51 = get_node_or_null("MarginContainer/TabContainer/Chat")
	if _i51:
		var _o79 = _i51.get_child(0) if _i51.get_child_count() > 0 else null
		if _o79 and _o79 is VBoxContainer:
			var _t42 = -1
			for i in range(_o79.get_child_count()):
				var _x15 = _o79.get_child(i)
				if _x15.name == "InputContainer" or (_x15 is HBoxContainer and _x15.get_node_or_null("_w39") != null):
					_t42 = i
					break
			if _t42 >= 0:
				_o79.add_child(_i85)
				_o79.move_child(_i85, _t42)
			else:
				_o79.add_child(_i85)
		else:
			add_child(_i85)
	else:
		add_child(_i85)
func _r31() -> void:
	if _i85 and is_instance_valid(_i85):
		_i85.queue_free()
		_i85 = null
		_x2 = null
func _r34() -> void:
	_k64()  
	_z97 = HBoxContainer.new()
	_z97.name = "AgentForceResetContainer"
	_z97.alignment = BoxContainer.ALIGNMENT_CENTER
	_z97.add_theme_constant_override("separation", 8)
	var _l45 = Button.new()
	_l45.text = "Reset Agent"
	_l45.tooltip_text = "Force reset all agent state and start fresh"
	_l45.pressed.connect(_s95)
	_z97.add_child(_l45)
	var _i51 = get_node_or_null("MarginContainer/TabContainer/Chat")
	if _i51:
		var _o79 = _i51.get_child(0) if _i51.get_child_count() > 0 else null
		if _o79 and _o79 is VBoxContainer:
			var _t42 = -1
			for i in range(_o79.get_child_count()):
				var _x15 = _o79.get_child(i)
				if _x15.name == "InputContainer" or (_x15 is HBoxContainer and _x15.get_node_or_null("_w39") != null):
					_t42 = i
					break
			if _t42 >= 0:
				_o79.add_child(_z97)
				_o79.move_child(_z97, _t42)
			else:
				_o79.add_child(_z97)
		else:
			add_child(_z97)
	else:
		add_child(_z97)
func _k64() -> void:
	if _z97 and is_instance_valid(_z97):
		_z97.queue_free()
		_z97 = null
func _s95() -> void:
	if _b34 and _b34.is_active():
		_b34._v44()
	_d61()
	_r31()
	_f30()
	_k64()
	_l75()
	_m83()
	_b6.clear()
	_z3 = false
	_m77("Agent state reset. You can start a new task.", false)
func _m77(text: String, _g98: bool = false) -> void:
	var _p40 = PanelContainer.new()
	_p40.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_p40.add_theme_constant_override("margin_bottom", _u22.message_gap)
	if not _i100:
		_g72()
	_p40.add_theme_stylebox_override("panel", _i100)
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.selection_enabled = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.fit_content = true
	label.scroll_active = false
	label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var _o93 = Color.RED if _g98 else _i71
	label.add_theme_color_override("default_color", _o93)
	label.text = "[b][Agent][/b] " + _v100(text)
	_p40.add_child(label)
	_r70.add_child(_p40)
	_d12.call_deferred()
func _o47(_q38: String, details: Array, _g98: bool = false) -> void:
	var _p40 = PanelContainer.new()
	_p40.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_p40.add_theme_constant_override("margin_bottom", _u22.message_gap)
	if not _i100:
		_g72()
	_p40.add_theme_stylebox_override("panel", _i100)
	var _o79 = VBoxContainer.new()
	_o79.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _l39 = HBoxContainer.new()
	_l39.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _w13 = Button.new()
	_w13.flat = true
	_w13.text = "▶"  
	_w13.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_w13.tooltip_text = "Click to expand/collapse"
	_o96(_w13)
	_l39.add_child(_w13)
	var _j3 = RichTextLabel.new()
	_j3.bbcode_enabled = true
	_j3.selection_enabled = true
	_j3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_j3.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_j3.fit_content = true
	_j3.scroll_active = false
	_j3.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var _o93 = Color.RED if _g98 else _i71
	_j3.add_theme_color_override("default_color", _o93)
	_j3.text = "[b][Agent][/b] " + _v100(_q38)
	_l39.add_child(_j3)
	_o79.add_child(_l39)
	var _s86 = VBoxContainer.new()
	_s86.visible = false
	_s86.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_s86.add_theme_constant_override("separation", 4)
	var _z83 = MarginContainer.new()
	var indent_size = _s98() * 2  
	_z83.add_theme_constant_override("margin_left", indent_size)
	_z83.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _f89 = VBoxContainer.new()
	_f89.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for _d48 in details:
		var _n8 = Label.new()
		_n8.text = _d48
		_n8.add_theme_color_override("font_color", _o93.darkened(0.15))
		_o96(_n8)
		_f89.add_child(_n8)
	_z83.add_child(_f89)
	_s86.add_child(_z83)
	_o79.add_child(_s86)
	_w13.pressed.connect(func():
		_s86.visible = not _s86.visible
		_w13.text = "▼" if _s86.visible else "▶"
		_d12.call_deferred()
	)
	_p40.add_child(_o79)
	_r70.add_child(_p40)
	_d12.call_deferred()
func _o96(_d69: Control) -> void:
	if _n64:
		var _k71 = _n64.get_editor_interface()
		if _k71:
			var theme = _k71.get_editor_theme()
			if theme:
				var _z50 = theme.get_font("main", "EditorFonts")
				if _z50:
					_d69.add_theme_font_override("font", _z50)
				var _b87 = theme.get_font_size("main_size", "EditorFonts")
				if _b87 > 0:
					_d69.add_theme_font_size_override("font_size", _b87)
func _s98() -> int:
	if _n64:
		var _k71 = _n64.get_editor_interface()
		if _k71:
			var theme = _k71.get_editor_theme()
			if theme:
				var _b87 = theme.get_font_size("main_size", "EditorFonts")
				if _b87 > 0:
					return _b87
	return 14  
func _e13(session_id: String) -> void:
	_m77("Agent session started. Analyzing your request...")
func _o99(status: Dictionary) -> void:
	var progress = status.get("progress_percent", 0)
	var _t90 = status.get("status_message", "Processing...")
	if _t90 == null:
		_t90 = "Processing..."
	if _a38:
		_a38.value = progress
	if _b47:
		_b47.text = "Agent: " + _t90
	if status.has("tier"):
		var _j38 = status.get("tier", "")
		if _j38 is String and not _j38.is_empty() and _r46:
			_r46._x73(_j38)
func _v10(_p16: Array) -> void:
	if _p16.is_empty():
		return
	var _x23: Array = []
	var _z54: Array = []
	for _m7 in _p16:
		var _u36 = _m7.get("tool_name", "")
		var _d94 = _t36._d94(_u36)
		if _d94:
			_z54.append(_m7)
		else:
			_x23.append(_m7)
	for _m7 in _x23:
		var _u36 = _m7.get("tool_name", "")
		var _j74 = _m7.get("tool_call_id", "")
		var _f44 = _m7.get("parameters", {})
		if _f44 == null:
			_f44 = {}
		var _e21 = _t36._m62(_u36, _f44)
		_b34._e81(_j74, true, _e21)
		_v90(_u36, _f44, _e21)
	for _m7 in _z54:
		_b6.append(_m7)
	if not _z3 and _b6.size() > 0:
		_l71()
func _l71() -> void:
	if _b6.is_empty():
		_z3 = false
		return
	_z3 = true
	var _m7 = _b6.pop_front()
	var _u36 = _m7.get("tool_name", "")
	var _j74 = _m7.get("tool_call_id", "")
	var _w85 = _y3.new()
	_w85._r95(_k71)
	_w85._p55(_m7)
	_w85._s24.connect(_j5.bind(_j74))
	_w85._h32.connect(_b25.bind(_j74))
	add_child(_w85)
	_w85.popup_centered()
func _j5(_m7: Dictionary, _b77: Dictionary, _j74: String) -> void:
	var _u36 = _m7.get("tool_name", "")
	if _u36 == null:
		_u36 = ""
	var _f44 = _m7.get("parameters", {})
	if _f44 == null:
		_f44 = {}
	var _e21 = _t36._m62(_u36, _f44)
	_b34._e81(_j74, true, _e21)
	_v90(_u36, _f44, _e21)
	_l71()
func _b25(_m7: Dictionary, _q64: String, _j74: String) -> void:
	var _u36 = _m7.get("tool_name", "")
	if _u36 == null:
		_u36 = ""
	var _f44 = _m7.get("parameters", {})
	if _f44 == null:
		_f44 = {}
	_b34._e81(_j74, false, {}, _q64)
	var path = _f44.get("path", "")
	if path == null:
		path = ""
	if not path.is_empty():
		_m77("Rejected " + _u36 + ": " + path)
	else:
		_m77("Rejected: " + _u36)
	_l71()
func _g8(message: String) -> void:
	_g2(message, [])
	_m77("Tip: Reopen modified scenes or reload the project to see changes")
	_d61()
	_r31()  
	_f30()
	_k64()  
	_l75()
	_m83()
func _p68(error: String) -> void:
	_m77("Agent failed: " + error, true)
	_d61()
	_r34()
	_f30()
func _a20() -> void:
	_m77("Agent cancelled")
	_d61()
	_r31()  
	_f30()
	_k64()  
	_l75()
	_m83()
func _j59(session_id: String, message: String) -> void:
	var _b10 = message + " You can continue to allow more processing."
	_m77(_b10, true)
	_z66()
	_d61()
	_r31()  
func _h61(message: String, _q11: String) -> void:
	if message.is_empty() and _q11.is_empty():
		return
	if not message.is_empty():
		_g2(message, [])
	if not _q11.is_empty():
		_i55(_q11)
func _i55(_q11: String) -> void:
	var _p40 = PanelContainer.new()
	_p40.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_p40.add_theme_constant_override("margin_bottom", _u22.message_gap)
	if not _i100:
		_g72()
	_p40.add_theme_stylebox_override("panel", _i100)
	var _o79 = VBoxContainer.new()
	_o79.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _l39 = HBoxContainer.new()
	_l39.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _w13 = Button.new()
	_w13.flat = true
	_w13.text = ">"  
	_w13.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_w13.tooltip_text = "Click to expand/collapse reasoning"
	_o96(_w13)
	_l39.add_child(_w13)
	var _j3 = RichTextLabel.new()
	_j3.bbcode_enabled = true
	_j3.selection_enabled = true
	_j3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_j3.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_j3.fit_content = true
	_j3.scroll_active = false
	_j3.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var _x3 = _i71.darkened(0.2)
	_j3.add_theme_color_override("default_color", _x3)
	_j3.text = "[i]View reasoning[/i]"
	_l39.add_child(_j3)
	_o79.add_child(_l39)
	var _s86 = VBoxContainer.new()
	_s86.visible = false
	_s86.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_s86.add_theme_constant_override("separation", 4)
	var _z83 = MarginContainer.new()
	var indent_size = _s98() * 2  
	_z83.add_theme_constant_override("margin_left", indent_size)
	_z83.add_theme_constant_override("margin_top", 4)
	_z83.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _h31 = RichTextLabel.new()
	_h31.bbcode_enabled = true
	_h31.selection_enabled = true
	_h31.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_h31.fit_content = true
	_h31.scroll_active = false
	_h31.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_h31.add_theme_color_override("default_color", _x3)
	_h31.text = _v100(_q11)
	_z83.add_child(_h31)
	_s86.add_child(_z83)
	_o79.add_child(_s86)
	_w13.pressed.connect(func():
		_s86.visible = not _s86.visible
		_w13.text = "v" if _s86.visible else ">"
		_d12.call_deferred()
	)
	_p40.add_child(_o79)
	_r70.add_child(_p40)
	_d12.call_deferred()
func _z66() -> void:
	_f30()  
	_i59 = HBoxContainer.new()
	_i59.name = "AgentContinueContainer"
	_i59.alignment = BoxContainer.ALIGNMENT_CENTER
	_i59.add_theme_constant_override("separation", 8)
	var _y94 = Button.new()
	_y94.text = "Continue Session"
	_y94.pressed.connect(_k61)
	_i59.add_child(_y94)
	var _h18 = Button.new()
	_h18.text = "Start New Task"
	_h18.pressed.connect(_h40)
	_i59.add_child(_h18)
	var _i51 = get_node_or_null("MarginContainer/TabContainer/Chat")
	if _i51:
		var _o79 = _i51.get_child(0) if _i51.get_child_count() > 0 else null
		if _o79 and _o79 is VBoxContainer:
			var _t42 = -1
			for i in range(_o79.get_child_count()):
				var _x15 = _o79.get_child(i)
				if _x15.name == "InputContainer" or (_x15 is HBoxContainer and _x15.get_node_or_null("_w39") != null):
					_t42 = i
					break
			if _t42 >= 0:
				_o79.add_child(_i59)
				_o79.move_child(_i59, _t42)
			else:
				_o79.add_child(_i59)
		else:
			add_child(_i59)
	else:
		add_child(_i59)
func _k61() -> void:
	_f30()
	_i20()
	if _b34:
		_b34._y83()
func _h40() -> void:
	_f30()
	_k64()  
	if _b34:
		_b34._o50()
	_l75()
	_m83()
func _f30() -> void:
	if _i59 and is_instance_valid(_i59):
		_i59.queue_free()
		_i59 = null
func _z11() -> void:
	if _b34 and _b34.is_active():
		_b34._v44()
func _b69(_u36: String, _f44: Dictionary, _e21: Dictionary) -> Dictionary:
	var success = _e21.get("success", false)
	var _u7 = "✓ " if success else "✗ "
	var details: Array = []
	match _u36:
		"read_file":
			var path = _f44.get("path", "unknown")
			if success:
				var content = _e21.get("content", "")
				var _t98 = content.count("\n") + 1 if not content.is_empty() else 0
				return {"summary": _u7 + "Read file: " + path + " (" + str(_t98) + " lines)", "details": [], "is_error": false}
			else:
				return {"summary": _u7 + "Failed to read: " + path, "details": [], "is_error": true}
		"list_files":
			var path = _f44.get("path", "res://")
			if success:
				var _q72 = _e21.get("files", [])
				var _d80 = _e21.get("directories", [])
				var _m25 = _q72.size() if _q72 is Array else 0
				var _z13 = _d80.size() if _d80 is Array else 0
				for _x30 in _d80:
					details.append("📁 " + str(_x30) + "/")
				for _g95 in _q72:
					details.append("📄 " + str(_g95))
				return {"summary": _u7 + "Listed " + path + " (" + str(_m25) + " files, " + str(_z13) + " dirs)", "details": details, "is_error": false}
			else:
				return {"summary": _u7 + "Failed to list: " + path, "details": [], "is_error": true}
		"get_project_info":
			if success:
				var _h51 = _e21.get("project_name", "Unknown")
				var _q5 = _e21.get("godot_version", "")
				details.append("Project: " + str(_h51))
				details.append("Godot: " + str(_q5))
				if _e21.has("main_scene"):
					details.append("Main Scene: " + str(_e21.get("main_scene")))
				return {"summary": _u7 + "Project: " + _h51 + " (Godot " + _q5 + ")", "details": details, "is_error": false}
			else:
				return {"summary": _u7 + "Failed to get project info", "details": [], "is_error": true}
		"run_project":
			if success:
				return {"summary": _u7 + "Running project in debug mode", "details": [], "is_error": false}
			else:
				return {"summary": _u7 + "Failed to run project", "details": [], "is_error": true}
		"stop_project":
			if success:
				return {"summary": _u7 + "Stopped project", "details": [], "is_error": false}
			else:
				return {"summary": _u7 + "Failed to stop project", "details": [], "is_error": true}
		"create_file":
			var path = _f44.get("path", "unknown")
			if success:
				return {"summary": _u7 + "Created: " + path, "details": [], "is_error": false}
			else:
				var _u39 = _e21.get("error", "Unknown error")
				return {"summary": _u7 + "Failed to create " + path + ": " + _u39, "details": [], "is_error": true}
		"edit_file":
			var path = _f44.get("path", "unknown")
			if success:
				return {"summary": _u7 + "Modified: " + path, "details": [], "is_error": false}
			else:
				var _u39 = _e21.get("error", "Unknown error")
				return {"summary": _u7 + "Failed to edit " + path + ": " + _u39, "details": [], "is_error": true}
		"delete_file":
			var path = _f44.get("path", "unknown")
			if success:
				return {"summary": _u7 + "Deleted: " + path, "details": [], "is_error": false}
			else:
				var _u39 = _e21.get("error", "Unknown error")
				return {"summary": _u7 + "Failed to delete " + path + ": " + _u39, "details": [], "is_error": true}
		_:
			if success:
				return {"summary": _u7 + "Executed: " + _u36, "details": [], "is_error": false}
			else:
				return {"summary": _u7 + "Failed: " + _u36, "details": [], "is_error": true}
func _v90(_u36: String, _f44: Dictionary, _e21: Dictionary) -> void:
	var status = _b69(_u36, _f44, _e21)
	var _q38 = status.get("summary", "")
	var details = status.get("details", [])
	var _g98 = status.get("is_error", false)
	if details.size() > 0:
		_o47(_q38, details, _g98)
	else:
		_m77(_q38, _g98)
