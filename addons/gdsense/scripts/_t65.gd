@tool
extends Control
func _q27(type: String) -> Color:
	if _d84:
		var _r43 = _d84.get_editor_settings()
		if _r43:
			match type:
				"text_color": return _r43.get_setting("text_editor/theme/highlighting/text_color")
				"comment": return _r43.get_setting("text_editor/theme/highlighting/comment_color")
				"string": return _r43.get_setting("text_editor/theme/highlighting/string_color")
				"number": return _r43.get_setting("text_editor/theme/highlighting/number_color")
				"keyword": return _r43.get_setting("text_editor/theme/highlighting/keyword_color")
				"class": return _r43.get_setting("text_editor/theme/highlighting/base_type_color")
				"function": return _r43.get_setting("text_editor/theme/highlighting/function_color")
				"symbol": return _r43.get_setting("text_editor/theme/highlighting/symbol_color")
	match type:
		"comment": return Color.GRAY
		"string": return Color.ORANGE
		"number": return Color.SKY_BLUE
		"keyword": return Color.PALE_VIOLET_RED
		"class": return Color.LIGHT_GREEN
		"function": return Color.LIGHT_BLUE
		"symbol": return Color.WHITE
	return Color.WHITE
const _g18 = [
	"if", "elif", "else", "for", "while", "match", "break", "continue", "pass",
	"return", "class", "extends", "is", "as", "self", "super", "func", "signal",
	"const", "var", "static", "enum", "in", "not", "and", "or", "true", "false",
	"null", "export", "onready", "tool", "setget", "breakpoint", "preload", "yield",
	"assert", "remote", "sync", "master", "puppet"
]
const _x38 = [
	"public", "private", "protected", "internal", "static", "void", 
	"class", "interface", "namespace", "using", "new", "this", "base",
	"if", "else", "for", "foreach", "while", "do", "switch", "case",
	"return", "throw", "try", "catch", "finally", "async", "await",
	"var", "const", "readonly", "override", "virtual", "abstract",
	"int", "string", "bool", "float", "double", "decimal", "byte", "true", "false", "null"
]
func _d56():
	if not _d84:
		return
	var theme = _d84.get_editor_theme()
	if not theme:
		return
	var _z13 = theme.get_color("base_color", "Editor")
	var _d48 = theme.get_color("dark_color_2", "Editor")
	var _w61 = theme.get_color("contrast_color_1", "Editor")
	var font_color = theme.get_color("font_color", "Editor")
	var _d43 = theme.get_color("accent_color", "Editor")
	if not _u12:
		_l85()
	var _i31 = _z13.lerp(_d43, 0.1)
	if _z13.get_luminance() > 0.5:
		_i31 = _z13.darkened(0.05).lerp(_d43, 0.1)
	_u12.bg_color = _i31
	_u12.border_color = _d43.darkened(0.3)
	if _i31.get_luminance() > 0.5:
		_t94 = Color.BLACK
	else:
		_t94 = Color(0.9, 0.9, 0.9) 
	var _a17 = _d48
	_v64.bg_color = _a17
	_v64.border_color = _a17.lightened(0.05)
	_w99 = font_color
	var _c83 = _e70("normal", "TextEdit")
	if _c83 is StyleBoxFlat:
		_s9.bg_color = _c83.bg_color
		_s9.border_color = _c83.border_color
		_s9.border_width_left = _c83.border_width_left
		_s9.border_width_top = _c83.border_width_top
		_s9.border_width_right = _c83.border_width_right
		_s9.border_width_bottom = _c83.border_width_bottom
		_s9.corner_radius_top_left = _c83.corner_radius_top_left
		_s9.corner_radius_top_right = _c83.corner_radius_top_right
		_s9.corner_radius_bottom_right = _c83.corner_radius_bottom_right
		_s9.corner_radius_bottom_left = _c83.corner_radius_bottom_left
	else:
		_s9.bg_color = _z13
		_s9.border_color = _z13.lightened(0.1)
	_t58.bg_color = _d48
	_t58.border_color = _d48.lightened(0.1)
	_k85 = font_color
	_r39.bg_color = _d48.lightened(0.05)
func _j54(name: String, type: String = "Editor") -> Color:
	if _d84:
		var theme = _d84.get_editor_theme()
		if theme:
			return theme.get_color(name, type)
	return Color.GRAY 
func _e70(name: String, type: String = "Editor") -> StyleBox:
	if _d84:
		var theme = _d84.get_editor_theme()
		if theme:
			return theme.get_stylebox(name, type)
	return null
var _u12: StyleBoxFlat
var _v64: StyleBoxFlat
var _t58: StyleBoxFlat
var _r39: StyleBoxFlat
var _s9: StyleBoxFlat
var _t94: Color
var _w99: Color
var _k85: Color
const _c34 = {
	"message_gap": 16,
	"padding": 12,
	"code_padding": 10
}
func _l85():
	_u12 = StyleBoxFlat.new()
	_u12.corner_radius_top_left = 8
	_u12.corner_radius_top_right = 8
	_u12.corner_radius_bottom_left = 8
	_u12.corner_radius_bottom_right = 8
	_u12.content_margin_left = _c34.padding
	_u12.content_margin_right = _c34.padding
	_u12.content_margin_top = _c34.padding
	_u12.content_margin_bottom = _c34.padding
	_u12.border_width_bottom = 1
	_u12.border_width_top = 1
	_u12.border_width_left = 1
	_u12.border_width_right = 1
	_v64 = StyleBoxFlat.new()
	_v64.corner_radius_top_left = 8
	_v64.corner_radius_top_right = 8
	_v64.corner_radius_bottom_left = 8
	_v64.corner_radius_bottom_right = 8
	_v64.content_margin_left = _c34.padding
	_v64.content_margin_right = _c34.padding
	_v64.content_margin_top = _c34.padding
	_v64.content_margin_bottom = _c34.padding
	_v64.border_width_bottom = 1
	_v64.border_width_top = 1
	_v64.border_width_left = 1
	_v64.border_width_right = 1
	_t58 = StyleBoxFlat.new()
	_t58.corner_radius_top_left = 4
	_t58.corner_radius_top_right = 4
	_t58.corner_radius_bottom_left = 4
	_t58.corner_radius_bottom_right = 4
	_t58.border_width_bottom = 1
	_t58.border_width_top = 1
	_t58.border_width_left = 1
	_t58.border_width_right = 1
	_t58.border_width_left = 1
	_t58.border_width_right = 1
	_r39 = StyleBoxFlat.new()
	_r39.corner_radius_top_left = 6
	_r39.corner_radius_top_right = 6
	_r39.content_margin_left = 12
	_r39.content_margin_right = 12
	_r39.content_margin_top = 4
	_r39.content_margin_bottom = 4
	_s9 = StyleBoxFlat.new()
	_s9.bg_color = Color(0.1, 0.1, 0.1) 
	_s9.border_width_left = 1
	_s9.border_width_top = 1
	_s9.border_width_right = 1
	_s9.border_width_bottom = 1
	_s9.corner_radius_top_left = 4
	_s9.corner_radius_top_right = 4
	_s9.corner_radius_bottom_right = 4
	_s9.corner_radius_bottom_left = 4
const _n75 = {
	"gdscript": "GDScript",
	"csharp": "C#",
	"cs": "C#",
	"": "GDScript"  
}
const _g38 = {
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
const _f93 = {
	"1080p": {"width": 1920, "height": 1080, "scale": 1.0},  
	"1440p": {"width": 2560, "height": 1440, "scale": 1.15}, 
	"4k": {"width": 3840, "height": 2160, "scale": 1.5},     
	"user": {"width": 1800, "height": 1169, "scale": 1.1}    
}
const _g83 = {
	0: "auto",    
	1: 0.8,       
	2: 1.0,       
	3: 1.25,      
	4: 1.5        
}
const _b34 = 16  
var _k9: EditorPlugin
var _d84: EditorInterface
var _w31: ScriptEditor
var _v1: VBoxContainer
var _r38: EditorPlugin  
var _f65: _x56
var _l66: _h44
var _v3: _i78
@onready var _s1: ScrollContainer = %_d25
@onready var _i91: TextEdit = %_b41
@onready var _s88: Button = %_e93
@onready var _m1: LineEdit = %_j99
@onready var _j96: Button = %_l69
@onready var _g41: Label = %_i65
@onready var _w62: CheckButton = %_c94
@onready var _q12: Label = %_z74
@onready var _k86: HBoxContainer = %_g74
@onready var _h30: Label = %_f12
@onready var _c75: Label = %_f97
@onready var _d95: Label = %_v4
@onready var _e11: Button = %_h49
@onready var _h71: Label = %_v25
@onready var _k54: OptionButton = %_i26
@onready var _n38: OptionButton = %_k38
@onready var _u42: OptionButton = %_z31
@onready var _g34: VBoxContainer = $MarginContainer/TabContainer/Settings/_o99/VBoxContainer
@onready var _y23: TabContainer = $MarginContainer/TabContainer
@onready var _q15: ProgressBar = %_f23
@onready var _k35: Label = %_s38
@onready var _h43: Label = %_e6
@onready var _w9: Label = %_k42
@onready var _p47: OptionButton = %_c18
@onready var _a83: Panel = %_t34
@onready var _w85: Label = %_m30
@onready var _f48: TabContainer = %_u88
@onready var _d47: ItemList = %_u61
@onready var _t79: Label = %_h29
@onready var _j64: RichTextLabel = %_x16
@onready var _n98: RichTextLabel = %_k99
@onready var _g84: Button = %_c16
@onready var _a93: Button = %_g24
@onready var _a32: Button = %_j15
@onready var _k19: Button = %_x57
@onready var _b76: ItemList = %_w49
@onready var _g82: Label = %_d36
@onready var _l11: RichTextLabel = %_a75
@onready var _n55: RichTextLabel = %_s67
@onready var _c67: Button = %_z100
@onready var _a31: Button = %_a98
@onready var _w35: Button = %_s3
@onready var _c42: Button = %_a91
@onready var _d37: Button = %_i15
@onready var _t87: Button = %_s68
@onready var _u26: Button = %_s16
@onready var _j52: Button = %_h36
@onready var _k3: AcceptDialog = %_r23
@onready var _r69: LineEdit = %_y19
@onready var _f41: FileDialog = %_l40
@onready var _o23: FileDialog = %_o35
@onready var _j71: OptionButton = %_z25
@onready var _t24: Label = %_y55
var _t97: CheckBox
var _y12: OptionButton
var _h86: SpinBox
var _k31: CheckBox
var _x12: CheckBox
var _l25: Button
var _f78: _y57
var _d83: Array = []
var _l8: bool = false
var _q30: float = 0.0
var _s82: int = 0
var _l93: Dictionary = {}  
var _q75: int = 0
var _e81: int = 30000  
var _g11: Dictionary = {}
var _w68: Array[String] = []
var _e30: int = 0
var _x86: _d25
var _m52: int = -1
var _j97: int = -1
var _d13: String = ""
var _j85: bool = false
var _h41: String = ""  
var _j25: String = ""  
var _b13: bool = false
var _y85: Vector2 = Vector2.ZERO
var _k23: float = 0.0
var _h24: HBoxContainer
var _m66: OptionButton
var _w53: Label
var _c65: OptionButton  
const _w44 = [
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
var _q99: TextEdit
var _i3: Label
var _a67: Label
const _c23 = 3
var _f64: int = 0
var _v59: float = 1.0
var _v73: String = "auto"  
var _x17: int = 128000  
const _y9 = 0.85  
const _i35 = 1.0  
const _d85 = [
	"@file",
	"@selection",
	"@openscript",
	"@scene",
	"@node"
]
const _q63: int = 0
const _y69: int = 1
const _w72 = {
	_q63: "Chat",
	_y69: "Agent"
}
var _t68: _i29
var _v17: _t27
var _r4: ProgressBar
var _t100: Label
var _d80: Button
var _d29: bool = false
var _d97: VBoxContainer
var _s97: HBoxContainer
var _s98: Array = []  
var _x9: bool = false  
var _l95: HBoxContainer  
var _a43: HBoxContainer  
var _z90 = 0
var _g58 = []
var _l52 = {}
var _d91: Timer
var _o85: int = 0
var _a18: PanelContainer
var _e62: bool = false  
func _u51() -> void:
	_l93 = {}
func set_gdsense_manager(_b44: _y57) -> void:
	_f78 = _b44
	if _f78:
		if not _f78._a7.is_connected(_h97):
			_f78._a7.connect(_h97)
		if not _f78._r2.is_connected(_z60):
			_f78._r2.connect(_z60)
		if not _f78._q20.is_connected(_f5):
			_f78._q20.connect(_f5)
func set_plugin(_m21: EditorPlugin) -> void:
	_r38 = _m21
func _notification(_a3):
	if _a3 == NOTIFICATION_THEME_CHANGED:
		_p57()
func _ready() -> void:
	_l85()
	_e48.call_deferred()
	_k9 = EditorPlugin.new()
	_d84 = _k9.get_editor_interface()
	_w31 = _d84.get_script_editor()
	var _z27 = %_c33
	if _z27:
		_z27.add_theme_stylebox_override("panel", _s9)
	_d56()
	_q13()
	_f65 = _x56.new(_d84, _w31)
	_l66 = _h44.new(_f65, _d84)
	_v3 = _i78.new()
	_v3.initialize(_i91, self, _d84)
	_v3._u35.connect(_h9)
	_v1 = %_r1
	_s1.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_v1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_j96.pressed.connect(_g80)
	_s88.pressed.connect(_b47)
	_w62.toggled.connect(_b69)
	_e11.pressed.connect(_l47)
	_k54.item_selected.connect(_m12)
	_n38.item_selected.connect(_m12)
	_i91.gui_input.connect(_d40)
	_i91.text_changed.connect(_e27)
	_a83.mouse_entered.connect(_z92)
	_a83.mouse_exited.connect(_u72)
	_a83.gui_input.connect(_y1)
	_s11()
	_d98()
	_e32()
	_d91 = Timer.new()
	_d91.wait_time = 0.5  
	_d91.one_shot = true
	_d91.timeout.connect(_b97)
	add_child(_d91)
	if _f78:
		_f78._m76.connect(_v87)
		_f78._r52.connect(_w80)
		_f78._l24.connect(_q6)
		_f78._o39.connect(_x91)
		_f78._j33.connect(_y98)
		_f78._i1.connect(_i89)
		_f78._l86.connect(_t43)
		_f78._j20.connect(_g37)
	var _j26 = _f78._e21() if _f78 else ""
	_m1.text = _j26
	if _j26.is_empty():
		if _f78 and _f78._c4():
			var env = _f78._j83()
			_g41.text = "No API Key (%s)" % env.capitalize()
		else:
			_g41.text = "API Key Not Set"
	else:
		if _f78 and _f78._c4():
			var env = _f78._j83()
			_g41.text = "API Key Loaded (%s)" % env.capitalize()
		else:
			_g41.text = "API Key Loaded"
	_h77()
	_g57()
	_m50()
	_b29()
	_f9()
	_w45()
	_a8()
	_e44.call_deferred()
	_q12.visible = false
	_k86.visible = false
	if not (_f78 and _f78._c4()):
		_h71.visible = false
	_x50()
	_p80()
func _e48():
	if not _f78:
		if _f64 >= _c23:
			return
		_f64 += 1
		if is_inside_tree():
			get_tree().create_timer(1.0).timeout.connect(_u63)
		else:
			_z79.call_deferred()
func _z79():
	if _f64 >= _c23:
		return
	_e48()
func _u63():
	if not _f78:
		if _f64 >= _c23:
			pass
		else:
			pass
	else:
		_f64 = 0
func _process(delta: float):
	if _l8:
		var elapsed_time = (Time.get_ticks_msec() / 1000.0) - _q30
		_q12.text = "Request time: %.1fs" % elapsed_time
func _d40(_x58: InputEvent):
	if _v3 and _v3._v70(_x58):
		get_viewport().set_input_as_handled()
		return
	if _x58 is InputEventKey and _x58.pressed:
		if _x58.keycode == KEY_ENTER:
			if _x58.shift_pressed:
				_i91.text += "\n"
				_i91.set_caret_line(_i91.get_line_count() - 1)
				_i91.set_caret_column(0)
				get_viewport().set_input_as_handled()
			else:
				var text = _i91.text.strip_edges()
				if text.is_empty():
					return
				_i91.text = ""
				_e27() 
				if _u42 and _u42.selected == _y69:
					_a29(text)
				else:
					_t85(text)
				get_viewport().set_input_as_handled()
func _g80():
	if _f78:
		_f78._s7(_m1.text)
func _b47():
	var _v93: String = _i91.text
	if not _v93.is_empty():
		if _u42 and _u42.selected == _y69:
			_a29(_v93)
		else:
			_t85(_v93)
func _a29(_u53: String) -> void:
	if not _t68:
		_s85("Agent mode not available", true)
		return
	var _t18 = _k33(_u53)
	if _t18.is_empty():
		return
	_i91.text = ""
	_b43(_u53)
	_o86()
	_i91.editable = false
	_s88.disabled = true
	var _u87 = {
		"godot_version": Engine.get_version_info().get("string", "4.x"),
		"project_name": ProjectSettings.get_setting("application/config/name", "")
	}
	var _c40 = ""
	if _c65:
		_c40 = _r49()
	_t68._q77(_t18, _u87, _c40)
func _t85(_v93: String):
	_h41 = _v93
	_s23()
	_d83.append({"role": "user", "content": _v93, "original_content": _v93})
	_u51()
	var _t47 = _v93
	if _v93.begins_with("@explain"):
		var _r53 = _v93.find("\n")
		if _r53 != -1:
			_t47 = _v93.substr(0, _r53) + " (code attached)"
	_b43(_t47)
	_i91.text = ""
	_i91.editable = false
	_s88.disabled = true
	_l8 = true
	_q30 = Time.get_ticks_msec() / 1000.0
	_q12.visible = true
	_k86.visible = false
	_q12.text = "Request time: 0.0s"
	_g77.call_deferred()
	var _q10 = _u20(_v93, true)
	var processed_prompt = _q10["processed_prompt"]
	var context_metadata = _q10["context_metadata"]
	if processed_prompt == "":
		_o20()
		if _d83.size() > 0:
			_d83.pop_back()
			_u51()
		return
	if processed_prompt.strip_edges().begins_with("@explain"):
		var _c43 = _c78(processed_prompt)
		if _c43.has("function_context") and not _c43["function_context"].is_empty():
			if _f78:
				_f78._i16(_d83, "@explain", _c43["function_context"], context_metadata if context_metadata else {})
		else:
			_d83[_d83.size() - 1]["content"] = processed_prompt
			if _f78:
				_f78._i16(_d83, "", "", context_metadata if context_metadata else {})
	else:
		_d83[_d83.size() - 1]["content"] = processed_prompt
		if _f78:
			_f78._i16(_d83, "", "", context_metadata if context_metadata else {})
func _v87(_f36: String, _m72: Array, _x6: String = "", _c87: String = ""):
	if not _c87.is_empty() and _d83.size() > 0:
		for i in range(_d83.size() - 1, -1, -1):
			if _d83[i].get("role", "") == "user":
				_d83[i]["content"] = _c87
				break
	var _v7 = {"role": "agent", "content": _f36}
	if not _x6.is_empty():
		_v7["thought_signature"] = _x6
	_d83.append(_v7)
	_j25 = _x6
	_u51()
	_d18(_f36, _m72)
	if _x86 and not _h41.is_empty():
		var session_id = _f78._q65() if _f78 else ""
		var _c37 = _x86._h48()
		var _b80 = (not _c37 or _c37.session_id != session_id)
		if _b80 and _d83.size() > 2:
			for i in range(0, _d83.size() - 2, 2):  
				if i + 1 < _d83.size():
					var _r63 = _d83[i]
					var _n51 = _d83[i + 1]
					if _r63.get("role", "") == "user" and _n51.get("role", "") == "agent":
						var _a34 = _n51.get("thought_signature", "")
						var _e85 = _r63.get("original_content", _r63.get("content", ""))
						var _o54 = _r63.get("content", "")
						_x86._j40(_e85, _n51.get("content", ""), session_id, _a34, _o54, "")
		var _f47 = _h41
		var _j47 = _c87 if not _c87.is_empty() else _h41
		var _h68 = _f78._c80() if _f78 else ""
		_x86._j40(_f47, _f36, session_id, _x6, _j47, _h68)
		_x86._w10()
		_h41 = ""  
		_d60()
	_o20()
	_g77.call_deferred()
	_s23.call_deferred(true)
func _w80():
	_g41.text = "Invalid API Key"
	_p24("Your API key is invalid. Please check your settings.")
	_o20()
	_g77.call_deferred()
func _q6(_g51: int, _m26: String):
	var _o77 = _n26(_m26)
	var _u85: String
	if _o77 != _m26:
		_u85 = _o77
	else:
		_u85 = "API Error %d: %s" % [_g51, _m26]
		if _g51 == 400:
			if "custom_rules" in _m26.to_lower():
				_u85 += "\n\nPlease check your custom rules in the Settings tab."
			elif "godot_version" in _m26.to_lower():
				_u85 += "\n\nGodot version detection failed. Try restarting the editor."
		elif _g51 == 422:
			_u85 += "\n\nPlease verify your custom rules and parameter settings."
	_p24(_u85)
	_o20()
	_g77.call_deferred()
func _x91():
	if _f78 and _f78._c4():
		var env = _f78._j83()
		_g41.text = "API Key Saved (%s)!" % env.capitalize()
	else:
		_g41.text = "API Key Saved!"
func _l47():
	_d83.clear()
	_u51()
	_m67()
	for _h61 in _v1.get_children():
		_h61.queue_free()
	_p80()
	_f13()
	_k86.visible = false
	_s82 = 0
	_h71.text = "Total Token Usage for this chat: 0"
	if _x86:
		_x86._i87()
		_x86._w10()
		_d60()
	if _f78:
		_f78._v76()
	_g77.call_deferred()
func _g77():
	await get_tree().process_frame
	_s1.get_v_scroll_bar().value = _s1.get_v_scroll_bar().max_value
func _y98(_f79: int, _p97: int, _v16: int):
	_s82 += _v16
	if _f78 and _f78._c4():
		_h30.text = "P: %d" % _f79
		_c75.text = "C: %d" % _p97
		_d95.text = "T: %d" % _v16
		_h71.text = "Total Token Usage for this chat: %d" % _s82
		_k86.visible = true
	else:
		_k86.visible = false
		_h71.visible = false
	_g77.call_deferred()
func _i89(success: bool):
	if success:
		pass
	else:
		pass
func _b69(_f71: bool):
	_m1.secret = not _f71
func _z92():
	Input.set_default_cursor_shape(Input.CURSOR_VSIZE)
func _u72():
	if not _b13:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
func _y1(_x58: InputEvent):
	if _x58 is InputEventMouseButton:
		if _x58.button_index == MOUSE_BUTTON_LEFT:
			if _x58.pressed:
				_b13 = true
				_y85 = _a83.get_global_mouse_position()
				_k23 = _i91.custom_minimum_size.y
			else:
				_b13 = false
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	elif _x58 is InputEventMouseMotion and _b13:
		var _o42 = _a83.get_global_mouse_position()
		var _t5 = _o42.y - _y85.y
		var _o100 = clamp(_k23 + _t5, 40.0, 600.0)
		_i91.custom_minimum_size.y = _o100
func _e64(text: String) -> String:
	var _j90: PackedStringArray = text.split("\n")
	for i in range(_j90.size()):
		var line: String = _j90[i]
		var _a94: int = 0
		for _o41 in line:
			if _o41 == ' ':
				_a94 += 1
			else:
				break
		var _h91: int = _a94 / 4
		if _h91 > 0:
			_j90[i] = "\t".repeat(_h91) + line.lstrip(" ")
	return "\n".join(_j90)
func _o20():
	_i91.editable = true
	_s88.disabled = false
	_l8 = false
	_q12.visible = false
func _u16(text: String) -> PackedStringArray:
	var _v54 = RegEx.new()
	_v54.compile("[A-Z][a-zA-Z0-9]+")
	var _x1 = _v54.search_all(text)
	var _c57: PackedStringArray = []
	for _x97 in _x1:
		_c57.append(_x97.get_string())
	return _c57
func _k78(_k59: String) -> String:
	if not ClassDB.class_exists(_k59):
		return ""
	var _j34 := ""
	var _u70 = ClassDB.class_get_method_list(_k59)
	if _u70.size() > 0:
		_j34 = "Class: " + _k59 + "\n"
	return _j34
func _b70(user_prompt: String) -> String:
	if user_prompt.strip_edges().begins_with("@explain"):
		return _k51(user_prompt)
	if not _v42(user_prompt):
		return user_prompt
	var _c57 = _u16(user_prompt)
	if _c57.is_empty():
		return user_prompt
	var _e94 = "Godot Editor Context:\n"
	for _p56 in _c57:
		var _j34 = _k78(_p56)
		if not _j34.is_empty():
			_e94 += _j34 + "\n"
	if _e94 == "Godot Editor Context:\n":
		return user_prompt
	var _i68 = _e94 + "\nUser Question: " + user_prompt
	return _i68
func _c78(user_prompt: String) -> Dictionary:
	var _x97 = {}
	var _o71 = RegEx.new()
	_o71.compile("@explain\\s+([a-zA-Z_][a-zA-Z0-9_]*)")
	var _l97 = _o71.search(user_prompt)
	var function_name = ""
	if _l97:
		function_name = _l97.get_string(1)
		_x97["function_name"] = function_name
	var _y90 = RegEx.new()
	_y90.compile("```(?:gdscript)?\n([^`]+?)```")
	var _f2 = _y90.search(user_prompt)
	if _f2:
		var _w13 = _f2.get_string(1).strip_edges()
		_x97["function_context"] = _w13
	return _x97
func _k51(user_prompt: String) -> String:
	var _o71 = RegEx.new()
	_o71.compile("@explain\\s+([a-zA-Z_][a-zA-Z0-9_]*)")
	var _x97 = _o71.search(user_prompt)
	var function_name = ""
	if _x97:
		function_name = _x97.get_string(1)
	var _p12 = "Please explain this GDScript function"
	if not function_name.is_empty():
		_p12 += " called '%s'" % function_name
	_p12 += ". Focus on:\n"
	_p12 += "- What the function does (purpose and behavior)\n"
	_p12 += "- How to use it (parameters and return value)\n"
	_p12 += "- Any important implementation details\n"
	_p12 += "- Potential improvements or best practices\n\n"
	_p12 += user_prompt.replace("@explain %s" % function_name, "").strip_edges()
	return _p12
func _k33(user_prompt: String) -> String:
	if _f65 == null:
		return user_prompt
	var _v55 = _f65._t25(user_prompt)
	var commands = _v55.get("commands", [])
	var cleaned_prompt = _v55.get("cleaned_prompt", user_prompt)
	for _l5 in commands:
		if _l5.get("type", "") == "error":
			var _q22 = _l5.get("error", "Unknown error")
			if "path traversal" in _q22.to_lower() or "not allowed" in _q22.to_lower() or "blocked" in _q22.to_lower():
				_p24("⚠️ Security: " + _q22)
				return ""
			else:
				_p24("⚠️ " + _q22)
				return ""
	if commands.is_empty():
		return user_prompt
	var _h96: Array[String] = []
	for _l5 in commands:
		var _h8 = _l5.get("type", "")
		match _h8:
			"file":
				var path = _l5.get("path", "")
				if not path.is_empty():
					_h96.append("File: " + path)
			"selection":
				var _r98 = _l5.get("script_path", "")
				var _n46 = _l5.get("line_start", 0)
				var _y97 = _l5.get("line_end", 0)
				if (_r98.is_empty() or not _r98.begins_with("res://")) and _f65:
					var _s21 = _f65._m77()
					if _s21.get("success", false):
						_r98 = _s21.get("path", "")
						_n46 = _s21.get("start_line", 0)
						_y97 = _s21.get("end_line", 0)
				if not _r98.is_empty() and _r98.begins_with("res://"):
					_h96.append("Selection in %s (lines %d-%d)" % [_r98, _n46, _y97])
			"openscript":
				var path = _l5.get("path", "")
				if path.is_empty() or not path.begins_with("res://"):
					if _f65:
						var _o1 = _f65.get_current_script()
						if _o1.get("success", false):
							path = _o1.get("path", "")
				if not path.is_empty() and path.begins_with("res://"):
					_h96.append("Open script: " + path)
			"scene":
				var path = _l5.get("path", "")
				if not path.is_empty():
					_h96.append("Scene: " + path)
			"node":
				var node_path = _l5.get("node_path", "")
				if not node_path.is_empty():
					_h96.append("Node: " + node_path)
	if _h96.is_empty():
		return cleaned_prompt
	var _h5 = "\n\n[Referenced files - use read_file to access]:\n- " + "\n- ".join(_h96)
	return cleaned_prompt + _h5
func _u20(user_prompt: String, _w18: bool = false) -> Dictionary:
	if _f65 == null or _l66 == null:
		return {"processed_prompt": user_prompt, "context_metadata": null}
	var _v55 = _f65._t25(user_prompt)
	var commands = _v55.get("commands", [])
	var cleaned_prompt = _v55.get("cleaned_prompt", user_prompt)
	if _w18:
		_j14(commands)
		for _l5 in commands:
			if _l5.get("type", "") == "openscript":
				var snapshot_id = _l5.get("snapshot_id", "")
				if snapshot_id != "" and _g11.has(snapshot_id):
					_g11[snapshot_id]["sent_in_conversation"] = true
	var _a76 = _k37(commands)
	var _e87 = _r88(_a76)
	if not _e87.is_empty():
		var _k27 = []
		_k27.append_array(_e87)
		_k27.append_array(commands)
		commands = _k27
	var _f8 = []
	for _l5 in commands:
		if _l5.get("type", "") == "error":
			var _q22 = _l5.get("error", "Unknown error")
			if _q22.begins_with("Security:"):
				_f8.append("⚠️ " + _q22)
			elif "path traversal" in _q22.to_lower() or "not allowed" in _q22.to_lower() or "blocked" in _q22.to_lower():
				_f8.append("⚠️ Security: " + _q22)
			else:
				_f8.append("⚠️ " + _q22)
	if not _f8.is_empty():
		var _v57 = "\n".join(_f8)
		_p24(_v57)
		return {"processed_prompt": "", "context_metadata": null}
	if commands.is_empty():
		return {"processed_prompt": user_prompt, "context_metadata": null}
	var _r33 = _l66._a12(cleaned_prompt, commands)
	var _r89 = _l66._c19(_r33)
	if not _r89.get("valid", false):
		var _o95 = _r89.get("message", "Unknown validation error")
		_p24("Context too large: " + _o95)
		return {"processed_prompt": "", "context_metadata": null}
	var context_metadata = _y34(commands, _r89.get("estimated_tokens", 0))
	if OS.is_debug_build() and context_metadata:
		pass
	return {"processed_prompt": _r33, "context_metadata": context_metadata}
func _j14(commands: Array) -> void:
	if commands.is_empty():
		return
	var _h45 = false
	for _l5 in commands:
		if _l5.get("type", "") != "openscript":
			continue
		var snapshot_id = _l5.get("snapshot_id", "")
		if snapshot_id == "":
			snapshot_id = _h25()
			_l5["snapshot_id"] = snapshot_id
		var _r98 = _l5.get("path", "")
		var _k60 = _l5.get("content", "")
		if _k60 == "" and _f65:
			var _o1 = _f65.get_current_script()
			if _o1.get("success", false):
				_k60 = _o1.get("content", "")
				_l5["content"] = _k60
				if _r98 == "":
					_r98 = _o1.get("path", "")
					_l5["path"] = _r98
		if _k60 == "":
			continue
		if _r98 == "":
			_r98 = "current_script.gd"
			_l5["path"] = _r98
		_g11[snapshot_id] = {
			"path": _r98,
			"content": _k60,
			"size_bytes": _k60.length(),
			"created_at": _l5.get("created_at", Time.get_unix_time_from_system()),
			"sent_in_conversation": false  
		}
		if not _w68.has(snapshot_id):
			_w68.append(snapshot_id)
		_h45 = true
	if _h45:
		_i61()
func _k37(commands: Array) -> PackedStringArray:
	var _d94 = PackedStringArray()
	for _l5 in commands:
		if _l5.get("type", "") != "openscript":
			continue
		var snapshot_id = _l5.get("snapshot_id", "")
		if snapshot_id != "":
			_d94.append(snapshot_id)
	return _d94
func _r88(_y56: PackedStringArray = PackedStringArray()) -> Array:
	var commands: Array = []
	for snapshot_id in _w68:
		if _y56.has(snapshot_id):
			continue
		if not _g11.has(snapshot_id):
			continue
		var _p42 = _g11[snapshot_id]
		if _p42.get("sent_in_conversation", false):
			continue
		var _l5 = {
			"type": "openscript",
			"snapshot_id": snapshot_id,
			"path": _p42.get("path", ""),
			"content": _p42.get("content", "")
		}
		commands.append(_l5)
	return commands
func _q96(_l5: Dictionary) -> Dictionary:
	var _r98 = _l5.get("path", "")
	var _k60 = _l5.get("content", "")
	var snapshot_id = _l5.get("snapshot_id", "")
	if snapshot_id != "" and _g11.has(snapshot_id):
		var _m79 = _g11[snapshot_id]
		if _r98 == "":
			_r98 = _m79.get("path", "")
		if _k60 == "":
			_k60 = _m79.get("content", "")
	return {
		"path": _r98,
		"content": _k60,
		"snapshot_id": snapshot_id
	}
func _h25() -> String:
	_e30 += 1
	return "panel_openscript_%d_%d" % [Time.get_ticks_msec(), _e30]
func _m67() -> void:
	_g11.clear()
	_w68.clear()
	_e30 = 0
	_i61()
func _i61() -> void:
	if _x86:
		_x86._m22(_g11, _w68)
func _y34(commands: Array, _q66: int) -> Dictionary:
	var _w46 = []
	var _p71 = 0
	for _l5 in commands:
		var _l23 = {}
		var _h8 = _l5.get("type", "unknown")
		_l23["type"] = _h8
		match _h8:
			"file":
				_l23["path"] = _l5.get("path", "")
				if _l5.get("start_line", -1) > 0:
					_l23["start_line"] = _l5.get("start_line", 0)
				if _l5.get("end_line", -1) > 0:
					_l23["end_line"] = _l5.get("end_line", 0)
				if _l5.get("symbol", "") != "":
					_l23["symbol"] = _l5.get("symbol", "")
				if _f65:
					var _t61 = _f65._n61(_l5)
					if _t61.get("success", false):
						var _g64 = _t61.get("content", "").length()
						_l23["size_bytes"] = _g64
						_p71 += _g64
			"scene":
				_l23["path"] = _l5.get("path", "")
				if _l5.get("node_path", "") != "":
					_l23["node_path"] = _l5.get("node_path", "")
				if _l5.get("include_scripts", false):
					_l23["include_scripts"] = true
				var _l2 = 500  
				if _l5.get("include_scripts", false):
					_l2 += 2000  
				_l23["size_bytes"] = _l2
				_p71 += _l2
			"node":
				_l23["node_path"] = _l5.get("node_path", "")
				var _l2 = 200  
				_l23["size_bytes"] = _l2
				_p71 += _l2
			"selection":
				if _f65:
					var _s21 = _f65._m77()
					if _s21.get("success", false):
						var _g64 = _s21.get("content", "").length()
						_l23["size_bytes"] = _g64
						_p71 += _g64
						var _e47 = _s21.get("path", "")
						if _e47 != "":
							_l23["path"] = _e47
						var _o55 = _s21.get("start_line", 0)
						if _o55 > 0:
							_l23["start_line"] = _o55
						var _h40 = _s21.get("end_line", 0)
						if _h40 > 0:
							_l23["end_line"] = _h40
			"openscript":
				var _a80 = _q96(_l5)
				var _k60 = _a80.get("content", "")
				var _r98 = _a80.get("path", "")
				var snapshot_id = _a80.get("snapshot_id", "")
				if _k60 != "":
					var _g64 = _k60.length()
					_l23["size_bytes"] = _g64
					_p71 += _g64
				if _r98 != "":
					_l23["path"] = _r98
				if snapshot_id != "":
					_l23["snapshot_id"] = snapshot_id
		_w46.append(_l23)
	var _m15 = {
		"commands": _w46,
		"total_context_size": _p71,
		"command_count": commands.size(),
		"estimated_tokens": _q66
	}
	if _f78 and not _f78._q65().is_empty():
		_m15["session_id"] = _f78._q65()
	return _m15
func _v42(user_prompt: String) -> bool:
	var _y54 = [
		"CharacterBody2D", "RigidBody2D", "StaticBody2D", "Area2D",
		"Node2D", "Node3D", "Control", "Panel", "Button", "Label",
		"AnimationPlayer", "AnimationTree", "TileMap", "PackedScene",
		"Resource", "RefCounted", "Object", "Variant",
		"Vector2", "Vector3", "Transform2D", "Transform3D",
		"InputEvent", "Camera2D", "Camera3D", "CollisionShape2D"
	]
	var _h85 = user_prompt.to_lower()
	for _y99 in _y54:
		if _h85.find(_y99.to_lower()) != -1:
			return true
	return false
func _c22(code: String) -> String:
	var _k83 = ""
	var _j90 = code.split("\n")
	var _t51 = RegEx.new()
	_t51.compile("\\b(" + "|".join(_g18) + ")\\b")
	var _c61 = RegEx.new()
	_c61.compile("(?<!#)\\b(Vector2|Input|Node2D|Control|CharacterBody2D|[A-Z][a-zA-Z0-9]*)\\b")
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
func _b43(text: String):
	var _g55 = PanelContainer.new()
	_g55.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_g55.add_theme_constant_override("margin_bottom", _c34.message_gap)
	if not _u12:
		_d56()
	_g55.add_theme_stylebox_override("panel", _u12)
	var _t7 = VBoxContainer.new()
	_t7.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_t7.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var _p79 = Label.new()
	_p79.text = "You:"
	_p79.add_theme_color_override("font_color", _t94)
	var _p55 = get_theme_font_size("font_size", "Label")
	_p79.add_theme_font_size_override("font_size", int(_p55 * 1.15))
	_t7.add_child(_p79)
	var _l88 = Control.new()
	_l88.custom_minimum_size.y = 6
	_t7.add_child(_l88)
	var _k21 = ColorRect.new()
	_k21.custom_minimum_size.y = 1
	_k21.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_k21.color = _t94
	_k21.color.a = 0.5
	_t7.add_child(_k21)
	var _x80 = Control.new()
	_x80.custom_minimum_size.y = 6
	_t7.add_child(_x80)
	var _s78 = RichTextLabel.new()
	_s78.bbcode_enabled = true
	_s78.selection_enabled = true
	_s78.text = _d68(text)
	_s78.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_s78.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_s78.fit_content = true
	_s78.scroll_active = false
	_s78.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_s78.add_theme_color_override("default_color", _t94)
	_t7.add_child(_s78)
	_g55.add_child(_t7)
	_v1.add_child(_g55)
func _d18(text: String, _m72: Array = []):
	var _g55 = PanelContainer.new()
	_g55.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_g55.add_theme_constant_override("margin_bottom", _c34.message_gap)
	if not _v64:
		_d56()
	_g55.add_theme_stylebox_override("panel", _v64)
	var _t7 = VBoxContainer.new()
	_t7.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_t7.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_t7.add_theme_constant_override("separation", 4)
	var _p79 = Label.new()
	_p79.text = "GDSense:"
	_p79.add_theme_color_override("font_color", _w99)
	var _p55 = get_theme_font_size("font_size", "Label")
	_p79.add_theme_font_size_override("font_size", int(_p55 * 1.15))
	_t7.add_child(_p79)
	var _l88 = Control.new()
	_l88.custom_minimum_size.y = 6
	_t7.add_child(_l88)
	var _k21 = ColorRect.new()
	_k21.custom_minimum_size.y = 1
	_k21.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_k21.color = _w99
	_k21.color.a = 0.5
	_t7.add_child(_k21)
	var _x80 = Control.new()
	_x80.custom_minimum_size.y = 6
	_t7.add_child(_x80)
	_n58(text, _t7)
	if _m72.size() > 0:
		_h19(_m72, _t7)
	if _f78:
		var _i13 = _f78._x32()
		if not _i13.is_empty():
			_g4(_t7)
		else:
			pass
	_g55.add_child(_t7)
	_v1.add_child(_g55)
func _n58(text: String, parent: Node):
	var _y90 = RegEx.new()
	_y90.compile("```([a-zA-Z]*)\n([^`]+?)```")
	var _f90 = 0
	var _l62 = _y90.search_all(text)
	for match in _l62:
		var _d76 = text.substr(_f90, match.get_start() - _f90)
		if not _d76.strip_edges().is_empty():
			_r60(_d76.strip_edges(), parent)
		var language = match.get_string(1).to_lower()
		if language.is_empty():
			language = "gdscript"  
		var code = match.get_string(2)
		_a59(code, language, parent)
		_f90 = match.get_end()
	if _f90 < text.length():
		var _l82 = text.substr(_f90)
		if not _l82.strip_edges().is_empty():
			_r60(_l82.strip_edges(), parent)
func _r60(text: String, parent: Node):
	var _g60 = text.strip_edges()
	_g60 = _g60.replace("**", "")
	var _c15 = RegEx.new()
	_c15.compile("`([^`]+)`")
	var _k36 = _c15.search_all(_g60)
	if _k36:
		for i in range(_k36.size() - 1, -1, -1):
			var _b31 = _k36[i]
			var full_match = _b31.get_string(0)
			var content = _b31.get_string(1)
			var _i40 = _d68(content)
			var _f3 = "[i]" + _i40 + "[/i]"
			_g60 = _g60.substr(0, _b31.get_start()) + _f3 + _g60.substr(_b31.get_end())
	var _c32 = RegEx.new()
	_c32.compile("'([A-Za-z0-9_\\-\\.]+)'")
	var _b50 = _c32.search_all(_g60)
	if _b50:
		for i in range(_b50.size() - 1, -1, -1):
			var _b31 = _b50[i]
			var full_match = _b31.get_string(0)
			var content = _b31.get_string(1)
			var _i40 = _d68(content)
			var _f3 = "[i]" + _i40 + "[/i]"
			_g60 = _g60.substr(0, _b31.get_start()) + _f3 + _g60.substr(_b31.get_end())
	var _u29 = "___SAFE_ITALIC_START___"
	var _h73 = "___SAFE_ITALIC_END___"
	_g60 = _g60.replace("[i]", _u29)
	_g60 = _g60.replace("[/i]", _h73)
	if _g60.begins_with("Explanation:") or _g60.begins_with("To use this:") or _g60.begins_with("To make this work:"):
		var _n66 = _g60.split(":", true, 1)
		if _n66.size() > 1:
			_g60 = "[b]" + _d68(_n66[0]) + ":[/b]" + _d68(_n66[1])
	var _j90 = _g60.split("\n")
	var _y24 = []
	var _v30 = RegEx.new()
	_v30.compile("^(#{1,4})\\s+(.+)$")
	var _w89 = RegEx.new()
	_w89.compile("^\\|\\s*[-:]+\\s*(\\|\\s*[-:]+\\s*)+\\|\\s*$")
	var _y78: Array = []  
	var _z29 = false
	var _s95 = func():
		if _y24.is_empty():
			return
		var _i21 = "\n".join(_y24)
		_i21 = _i21.replace(_u29, "[i]")
		_i21 = _i21.replace(_h73, "[/i]")
		if _i21.strip_edges().is_empty():
			_y24.clear()
			return
		var _b10 = RichTextLabel.new()
		_b10.bbcode_enabled = true
		_b10.selection_enabled = true
		_b10.text = _i21
		_b10.add_theme_constant_override("line_separation", 6)
		_b10.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_b10.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_b10.fit_content = true
		_b10.scroll_active = false
		_b10.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		_b10.add_theme_color_override("default_color", _w99)
		parent.add_child(_b10)
		_y24.clear()
	var _j8 = func():
		if _y78.is_empty():
			return
		_s95.call()
		var _k74 = 0
		for _c2 in _y78:
			if _c2.size() > _k74:
				_k74 = _c2.size()
		if _k74 == 0:
			_y78.clear()
			_z29 = false
			return
		var _n8 = MarginContainer.new()
		_n8.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_n8.add_theme_constant_override("margin_top", 8)
		_n8.add_theme_constant_override("margin_bottom", 12)
		var _k32 = PanelContainer.new()
		_k32.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var _c92 = StyleBoxFlat.new()
		_c92.bg_color = Color(0.15, 0.15, 0.18, 1.0)
		_c92.set_corner_radius_all(6)
		_c92.set_content_margin_all(12)
		_k32.add_theme_stylebox_override("panel", _c92)
		var _m16 = VBoxContainer.new()
		_m16.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_m16.add_theme_constant_override("separation", 0)
		var _h11 = GridContainer.new()
		_h11.columns = _k74
		_h11.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_h11.add_theme_constant_override("h_separation", 24)
		var _l72 = GridContainer.new()
		_l72.columns = _k74
		_l72.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_l72.add_theme_constant_override("h_separation", 24)
		_l72.add_theme_constant_override("v_separation", 10)
		var _c48 = int(14 * _v59)
		var _k39 = int(15 * _v59)
		for _z24 in range(_y78.size()):
			var _c2 = _y78[_z24]
			for _a58 in range(_k74):
				var _j3 = _c2[_a58] if _a58 < _c2.size() else ""
				_j3 = _j3.replace(_u29, "[i]")
				_j3 = _j3.replace(_h73, "[/i]")
				var _q78 = RichTextLabel.new()
				_q78.bbcode_enabled = true
				_q78.fit_content = true
				_q78.scroll_active = false
				_q78.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				_q78.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
				_q78.add_theme_color_override("default_color", _w99)
				if _z24 == 0 and _z29:
					_q78.add_theme_font_size_override("normal_font_size", _k39)
					_q78.text = "[b][u]" + _j3 + "[/u][/b]"
					_h11.add_child(_q78)
				else:
					_q78.add_theme_font_size_override("normal_font_size", _c48)
					_q78.text = _j3
					_l72.add_child(_q78)
		if _z29:
			_m16.add_child(_h11)
			var _k21 = HSeparator.new()
			_k21.add_theme_constant_override("separation", 8)
			_m16.add_child(_k21)
		_m16.add_child(_l72)
		_k32.add_child(_m16)
		_n8.add_child(_k32)
		parent.add_child(_n8)
		_y78.clear()
		_z29 = false
	for i in range(_j90.size()):
		var line = _j90[i]
		var _o74 = line.strip_edges()
		var _p17 = _w89.search(_o74) != null
		if _p17:
			if not _y78.is_empty():
				_z29 = true
			continue
		var _l53 = _v30.search(_o74)
		if _l53:
			_j8.call()
			var _i43 = _l53.get_string(1).length()
			var _k30 = _l53.get_string(2)
			var _p55 = 24  
			if _i43 == 2:
				_p55 = 20  
			elif _i43 == 3:
				_p55 = 18  
			elif _i43 == 4:
				_p55 = 16  
			var _c48 = int(_p55 * _v59)
			var _v23 = _d68(_k30)
			_y24.append("\n[b][font_size=" + str(_c48) + "]" + _v23 + "[/font_size][/b]\n")
		elif _o74.begins_with("|") and _o74.ends_with("|"):
			var _n31 = _o74.split("|")
			var _m99: Array = []
			for _x92 in _n31:
				var _v78 = _x92.strip_edges()
				if _v78.is_empty():
					continue
				if _v78.match("^-+$") or _v78.match("^:?-+:?$"):
					continue
				_m99.append(_d68(_v78))
			if not _m99.is_empty():
				_y78.append(_m99)
		elif _o74.begins_with("* "):
			_j8.call()
			var _f18 = _o74.substr(2).replace("*", "")
			_y24.append("• " + _d68(_f18))
			if i < _j90.size() - 1 and not _j90[i + 1].strip_edges().begins_with("* "):
				_y24.append("")
		elif _o74.match("^[0-9]+\\."):
			_j8.call()
			_y24.append(_d68(_o74))
		else:
			_j8.call()
			_y24.append(_d68(line.replace("*", "")))
	_j8.call()
	_s95.call()
func _a59(code: String, language: String, parent: Node):
	var _z2 = MarginContainer.new()
	_z2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_z2.add_theme_constant_override("margin_left", 16)
	_z2.add_theme_constant_override("margin_right", 16)
	_z2.add_theme_constant_override("margin_top", 12)
	_z2.add_theme_constant_override("margin_bottom", 12)
	var _g56 = PanelContainer.new()
	_g56.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not _t58:
		_d56()
	_g56.add_theme_stylebox_override("panel", _t58)
	var _z28 = VBoxContainer.new()
	_z28.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _l43 = PanelContainer.new()
	_l43.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_l43.add_theme_stylebox_override("panel", _r39)
	var _q72 = HBoxContainer.new()
	_q72.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_q72.layout_mode = 2  
	var _d8 = Label.new()
	_d8.layout_mode = 2
	_d8.text = _n75.get(language, "Code")
	_d8.add_theme_color_override("font_color", _k85)
	_q72.add_child(_d8)
	var _m9 = Control.new()
	_m9.layout_mode = 2
	_m9.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_q72.add_child(_m9)
	var _u73 = Button.new()
	_u73.layout_mode = 2
	_u73.text = "Copy"
	_u73.flat = true
	_u73.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_u73.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	_u73.pressed.connect(func(): _m73(code))
	_q72.add_child(_u73)
	_l43.add_child(_q72)
	_z28.add_child(_l43)
	var _s2 = MarginContainer.new()
	_s2.layout_mode = 2
	_s2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_s2.add_theme_constant_override("margin_left", _c34.code_padding)
	_s2.add_theme_constant_override("margin_right", _c34.code_padding)
	_s2.add_theme_constant_override("margin_top", _c34.code_padding)
	_s2.add_theme_constant_override("margin_bottom", _c34.code_padding)
	var _d66 = RichTextLabel.new()
	_d66.bbcode_enabled = true
	_d66.selection_enabled = true
	_d66.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_d66.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_d66.fit_content = true
	_d66.scroll_active = false
	_d66.scroll_active = false
	var _g45 = _q27("text_color")
	_d66.add_theme_color_override("default_color", _g45)
	var _k83 = _d7(code, language)
	_d66.text = _k83
	var _c90 = SystemFont.new()
	_c90.font_names = ["Consolas", "Courier New", "Monospace"]
	_d66.add_theme_font_override("normal_font", _c90)
	_d66.add_theme_font_override("mono_font", _c90)
	_s2.add_child(_d66)
	_z28.add_child(_s2)
	_g56.add_child(_z28)
	_z2.add_child(_g56)
	parent.add_child(_z2)
func _d7(code: String, language: String) -> String:
	match language:
		"gdscript", "":
			return _c22(_e64(code))
		"csharp", "cs":
			return _t75(code)
		_:
			return code
func _m73(code: String):
	DisplayServer.clipboard_set(code)
func _t75(code: String) -> String:
	var _k83 = ""
	var _j90 = code.split("\n")
	var _t51 = RegEx.new()
	_t51.compile("\\b(" + "|".join(_x38) + ")\\b")
	var _c61 = RegEx.new()
	_c61.compile("\\b([A-Z][a-zA-Z0-9]*)\\b")
	var _h47 = RegEx.new()
	_h47.compile("\\b([a-z_][a-zA-Z0-9_]*)\\s*\\(")
	var _l34 = RegEx.new()
	_l34.compile("(\"[^\"]*\"|'[^']*')")
	var _n93 = RegEx.new()
	_n93.compile("\\b\\d+(\\.\\d+)?[fFdD]?\\b")
	var _q9 = RegEx.new()
	_q9.compile("(//.*$|/\\*.*?\\*/)")
	for line in _j90:
		if line.strip_edges().is_empty():
			_k83 += "\n"
			continue
		var _q3 = line
		_q3 = _q9.sub(_q3, "[color=#%s]$1[/color]" % [_q27("comment").to_html(false)], true)
		_q3 = _l34.sub(_q3, "[color=#%s]$1[/color]" % [_q27("string").to_html(false)], true)
		_q3 = _t51.sub(_q3, "[color=#%s]$1[/color]" % [_q27("keyword").to_html(false)], true)
		_q3 = _c61.sub(_q3, "[color=#%s]$1[/color]" % [_q27("class").to_html(false)], true)
		_q3 = _h47.sub(_q3, "[color=#%s]$1[/color](" % [_q27("function").to_html(false)], true)
		_q3 = _n93.sub(_q3, "[color=#%s]$0[/color]" % [_q27("number").to_html(false)], true)
		_k83 += _q3 + "\n"
	return _k83.strip_edges()
func _p24(text: String):
	var _g55 = PanelContainer.new()
	_g55.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_g55.add_theme_constant_override("margin_bottom", _c34.message_gap)
	var _r42 = Color("#ff6666")
	if _d84:
		var theme = _d84.get_editor_theme()
		if theme:
			_r42 = theme.get_color("error_color", "Editor")
	var _c21 = StyleBoxFlat.new()
	_c21.bg_color = _r42.darkened(0.8)
	_c21.border_color = _r42
	_c21.border_width_bottom = 1
	_c21.border_width_top = 1
	_c21.border_width_left = 1
	_c21.border_width_right = 1
	_c21.corner_radius_top_left = 8
	_c21.corner_radius_top_right = 8
	_c21.corner_radius_bottom_left = 8
	_c21.corner_radius_bottom_right = 8
	_c21.content_margin_left = _c34.padding
	_c21.content_margin_right = _c34.padding
	_c21.content_margin_top = _c34.padding
	_c21.content_margin_bottom = _c34.padding
	_g55.add_theme_stylebox_override("panel", _c21)
	var _t7 = VBoxContainer.new()
	_t7.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_t7.layout_mode = 2  
	var _t89 = _r42.lightened(0.3)  
	var _x4 = Color(1.0, 0.9, 0.9)  
	var _q57 = Label.new()
	_q57.text = "GDSense Error"
	_q57.add_theme_color_override("font_color", _t89)
	_q57.add_theme_font_size_override("font_size", 16)
	_t7.add_child(_q57)
	var _s78 = Label.new()
	_s78.text = text
	_s78.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_s78.add_theme_color_override("font_color", _x4)
	_t7.add_child(_s78)
	_g55.add_child(_t7)
	_v1.add_child(_g55)
func _p80():
	var _g55 = PanelContainer.new()
	_g55.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_g55.add_theme_constant_override("margin_bottom", _c34.message_gap)
	if not _v64:
		_d56()
	_g55.add_theme_stylebox_override("panel", _v64)
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.selection_enabled = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.fit_content = true
	label.scroll_active = false
	label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	label.add_theme_color_override("default_color", _j54("font_color"))
	label.text = "[b]Welcome to GDSense![/b] Your AI coding partner for Godot."
	_g55.add_child(label)
	_v1.add_child(_g55)
func _q45(text: String):
	if text.strip_edges().is_empty():
		return
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.selection_enabled = true
	label.text = _d68(text)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.fit_content = true
	label.scroll_active = false
	label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	label.add_theme_color_override("default_color", _w99)
	_v1.add_child(label)
func _g57() -> void:
	_c65 = OptionButton.new()
	_c65.name = "AgentModelSelector"
	_n18()
	_c65.visible = false  
	_c65.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _n38:
		var _k70 = _n38.get_parent()
		if _k70:
			var _j68 = _k70.get_children().find(_n38)
			_k70.add_child(_c65)
			_k70.move_child(_c65, _j68)
func _h77():
	_k54.clear()
	_n38.clear()
	var _w25 = []
	if _f78:
		_w25 = _f78._h58()
	else:
		_w25 = [
			"openai/gpt-oss-20b",
			"gemini-2.5-flash-lite",
			"gpt-5-nano"
		]
	for _b72 in _w25:
		var _a2: String
		var _h80: String
		if _b72 is Dictionary and _b72.has("id"):
			_h80 = _b72.get("id", "")
			_a2 = _b72.get("display_name", _h80)
		else:
			_h80 = str(_b72)
			_a2 = _g38.get(_h80, _h80)
		_k54.add_item(_a2)
		_n38.add_item(_a2)
	if _f78:
		var _d35 = _f78._c80()
		if _o37(_d35, _w25):
			_b68(_d35)
		else:
			if _w25.size() > 0:
				var _s8 = _e73(_w25[0])
				_b68(_s8)
				_f78._s100(_s8)
	_h54()
func _e73(_b72) -> String:
	if _b72 is Dictionary and _b72.has("id"):
		return _b72.get("id", "")
	return str(_b72)
func _o37(_h80: String, _w25: Array) -> bool:
	for _b72 in _w25:
		var _b28 = _e73(_b72)
		if _b28 == _h80:
			return true
	return false
func _h54():
	pass
func _g16(index: int) -> String:
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
func _m12(index: int) -> void:
	var _w25 = []
	if _f78:
		_w25 = _f78._h58()
	if index < 0 or index >= _w25.size():
		return
	var _h80 = _e73(_w25[index])
	if _f78:
		_f78._s100(_h80)
	_k54.selected = index
	_n38.selected = index
	_s23(true)
func _b68(model: String) -> void:
	var _w25 = []
	if _f78:
		_w25 = _f78._h58()
	for i in range(_w25.size()):
		var _b28 = _e73(_w25[i])
		if _b28 == model:
			_k54.selected = i
			_n38.selected = i
			return
	_k54.selected = 0
	_n38.selected = 0
func _m50():
	if not _f78 or not _f78._c4():
		return
	_h24 = HBoxContainer.new()
	_h24.add_theme_constant_override("separation", 10)
	_w53 = Label.new()
	_w53.text = "Environment:"
	_h24.add_child(_w53)
	_m66 = OptionButton.new()
	_m66.add_item("Production")
	_m66.add_item("Development (localhost:8080)")
	var _b54 = _f78._j83() if _f78 else "production"
	if _b54 == "development":
		_m66.selected = 1
	else:
		_m66.selected = 0
	_m66.item_selected.connect(_i69)
	_h24.add_child(_m66)
	var _u71 = Label.new()
	_u71.text = "[DEV MODE]"
	_u71.modulate = Color(1, 0.5, 0.5)
	_h24.add_child(_u71)
	var _m48 = _m1.get_parent()
	var parent = _m48.get_parent()
	var index = parent.get_children().find(_m48)
	parent.add_child(_h24)
	parent.move_child(_h24, index + 1)
func _n18() -> void:
	if not _c65:
		return
	_c65.clear()
	var _w25 = []
	if _f78:
		_w25 = _f78._q95()
	if _w25.size() > 0 and _w25[0] is Dictionary and _w25[0].has("id"):
		for _b72 in _w25:
			var _a2 = _b72.get("display_name", _b72.get("id", "Unknown"))
			_c65.add_item(_a2)
	else:
		for _g35 in _w44:
			_c65.add_item(_g35["name"])
	_c65.selected = 0  
func _r49() -> String:
	if not _c65:
		return ""
	var _z89 = _c65.selected
	if _z89 < 0:
		return ""
	var _w25 = []
	if _f78:
		_w25 = _f78._q95()
	if _w25.size() > 0 and _w25[0] is Dictionary and _w25[0].has("id"):
		if _z89 < _w25.size():
			return _w25[_z89].get("id", "")
	else:
		if _z89 < _w44.size():
			return _w44[_z89]["id"]
	return ""
func _i69(index: int):
	var _f28 = ["production", "development"][index]
	var _j26 = ""
	if _f78:
		_f78._z10(_f28)
		_j26 = _f78._e21()
		_m1.text = _j26
	if _j26.is_empty():
		_g41.text = "No API Key (%s)" % _f28.capitalize()
	else:
		_g41.text = "API Key Loaded (%s)" % _f28.capitalize()
func _b29():
	if not _g34:
		return
	var _k21 = HSeparator.new()
	_g34.add_child(_k21)
	var _s37 = VBoxContainer.new()
	_s37.add_theme_constant_override("separation", 5)
	_g34.add_child(_s37)
	var _z37 = Label.new()
	_z37.text = "Ghost Text Autocomplete"
	_z37.add_theme_font_size_override("font_size", int(20 * _v59))
	_s37.add_child(_z37)
	_t97 = CheckBox.new()
	_t97.text = "Enable Autocomplete"
	_t97.button_pressed = true  
	_t97.toggled.connect(_g8)
	_s37.add_child(_t97)
	var _d77 = HBoxContainer.new()
	_d77.layout_mode = 2
	_s37.add_child(_d77)
	var _z11 = Label.new()
	_z11.text = "Trigger Mode:"
	_z11.custom_minimum_size.x = 150
	_d77.add_child(_z11)
	_y12 = OptionButton.new()
	_y12.layout_mode = 2
	_y12.add_item("Automatic")
	_y12.add_item("Manual (Ctrl+Space)")
	_y12.selected = 0
	_y12.item_selected.connect(_u44)
	_d77.add_child(_y12)
	var _t77 = HBoxContainer.new()
	_t77.layout_mode = 2
	_s37.add_child(_t77)
	var _c8 = Label.new()
	_c8.text = "Minimum Characters:"
	_c8.custom_minimum_size.x = 150
	_t77.add_child(_c8)
	_h86 = SpinBox.new()
	_h86.layout_mode = 2
	_h86.min_value = 1
	_h86.max_value = 10
	_h86.value = 3
	_h86.step = 1
	_h86.value_changed.connect(_y58)
	_t77.add_child(_h86)
	var _g69 = Label.new()
	_g69.text = "Smart triggers: After '.', '(', ':', '=', or space following keywords"
	_g69.layout_mode = 2
	var _c71 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_g69.add_theme_color_override("font_color", Color(_c71, 0.6))
	_g69.set_meta("secondary", true)
	_g69.add_theme_font_size_override("font_size", 12)
	_g69.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_s37.add_child(_g69)
	var _m88 = HSeparator.new()
	_s37.add_child(_m88)
	var _p44 = HBoxContainer.new()
	_p44.layout_mode = 2
	_s37.add_child(_p44)
	var _y87 = Label.new()
	_y87.text = "Inline Explain Buttons"
	_y87.add_theme_font_size_override("font_size", int(16 * _v59))
	_p44.add_child(_y87)
	_k31 = CheckBox.new()
	_k31.text = "Show Explain Buttons Above Functions"
	_k31.button_pressed = true  
	_k31.toggled.connect(_w36)
	_s37.add_child(_k31)
	var _i44 = Label.new()
	_i44.text = "Adds clickable help icons above function declarations to explain code"
	_i44.layout_mode = 2
	var _l35 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_i44.add_theme_color_override("font_color", Color(_l35, 0.6))
	_i44.set_meta("secondary", true)
	_i44.add_theme_font_size_override("font_size", 12)
	_i44.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_s37.add_child(_i44)
	var _o98 = HSeparator.new()
	_s37.add_child(_o98)
	var _c5 = Label.new()
	_c5.text = "Inline Refactor Buttons"
	_c5.add_theme_font_size_override("font_size", int(18 * _v59))
	_s37.add_child(_c5)
	_x12 = CheckBox.new()
	_x12.text = "Show Refactor Buttons Above Functions"
	_x12.button_pressed = true  
	_x12.toggled.connect(_f20)
	_s37.add_child(_x12)
	var _f26 = Label.new()
	_f26.text = "Adds clickable ↻ icons above function declarations for AI-powered refactoring"
	_f26.layout_mode = 2
	var _j79 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_f26.add_theme_color_override("font_color", Color(_j79, 0.6))
	_f26.set_meta("secondary", true)
	_f26.add_theme_font_size_override("font_size", 12)
	_f26.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_s37.add_child(_f26)
	var _h2 = HSeparator.new()
	_s37.add_child(_h2)
	_z56(_s37)
	_e46()
func _e46():
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		_t97.button_pressed = config.get_value("autocomplete", "enabled", true)
		var mode = config.get_value("autocomplete", "mode", "automatic")
		_y12.selected = 0 if mode == "automatic" else 1
		_h86.value = config.get_value("autocomplete", "min_chars", 3)
		_k31.button_pressed = config.get_value("explain_button", "enabled", true)
		_x12.button_pressed = config.get_value("refactor_button", "enabled", true)
		var _s83 = find_child("_b78", true)
		var _g66 = find_child("_y63", true)
		var _v91 = find_child("_i64", true)
		if _s83:
			_s83.button_pressed = config.get_value("undo", "enabled", true)
		if _g66:
			_g66.value = config.get_value("undo", "max_history_items", 20)
		if _v91:
			_v91.button_pressed = config.get_value("undo", "show_history_button", true)
func _q18():
	var mode = "automatic" if _y12.selected == 0 else "manual"
	const _j28 = 1000
	const _t23 = 150
	if _r38 and _r38.has_method("save_autocomplete_config"):
		_r38.save_autocomplete_config(
			_t97.button_pressed,
			_j28,
			_t23,
			mode,
			int(_h86.value)
		)
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_api_key.cfg")
		config.set_value("autocomplete", "enabled", _t97.button_pressed)
		config.set_value("autocomplete", "delay_ms", _j28)
		config.set_value("autocomplete", "max_length", _t23)
		config.set_value("autocomplete", "mode", mode)
		config.set_value("autocomplete", "min_chars", int(_h86.value))
		config.save("user://gdsense_api_key.cfg")
func _g8(enabled: bool):
	_q18()
func _u44(index: int):
	_q18()
func _y58(value: float):
	_q18()
func _w36(enabled: bool):
	if _r38 and _r38.has_method("save_explain_button_config"):
		_r38.save_explain_button_config(enabled)
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_api_key.cfg")
		config.set_value("explain_button", "enabled", enabled)
		config.save("user://gdsense_api_key.cfg")
func _f20(enabled: bool):
	if _r38 and _r38.has_method("save_refactor_config"):
		_r38.save_refactor_config(enabled)
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_api_key.cfg")
		config.set_value("refactor_button", "enabled", enabled)
		config.save("user://gdsense_api_key.cfg")
func _z56(_j74: VBoxContainer):
	var _x93 = Label.new()
	_x93.text = "Refactor Undo System"
	_x93.add_theme_font_size_override("font_size", int(18 * _v59))
	_j74.add_child(_x93)
	var _s83 = CheckBox.new()
	_s83.name = "UndoEnabledCheckbox"
	_s83.text = "Enable Undo for Refactored Functions"
	_s83.button_pressed = true  
	_s83.toggled.connect(_y100)
	_j74.add_child(_s83)
	var _m100 = HBoxContainer.new()
	_m100.layout_mode = 2
	_j74.add_child(_m100)
	var _z95 = Label.new()
	_z95.text = "Max History Items:"
	_z95.custom_minimum_size.x = 150
	_m100.add_child(_z95)
	var _g66 = SpinBox.new()
	_g66.name = "MaxHistorySpinbox"
	_g66.layout_mode = 2
	_g66.min_value = 5
	_g66.max_value = 50
	_g66.value = 20
	_g66.step = 1
	_g66.value_changed.connect(_q67)
	_m100.add_child(_g66)
	var _v91 = CheckBox.new()
	_v91.name = "ShowHistoryCheckbox"
	_v91.text = "Show History Button in Panel"
	_v91.button_pressed = true  
	_v91.toggled.connect(_i77)
	_j74.add_child(_v91)
	var _t9 = Label.new()
	_t9.text = "Track refactored functions with visual indicators and one-click undo"
	_t9.layout_mode = 2
	_t9.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_t9.add_theme_font_size_override("font_size", 12)
	_t9.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_j74.add_child(_t9)
func _y100(enabled: bool):
	if _r38 and _r38.has_method("save_undo_config"):
		_r38.save_undo_config(enabled)
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_settings.cfg")
		config.set_value("undo", "enabled", enabled)
		config.save("user://gdsense_settings.cfg")
func _q67(value: float):
	if _r38 and _r38.has_method("save_undo_max_history"):
		_r38.save_undo_max_history(int(value))
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_settings.cfg")
		config.set_value("undo", "max_history_items", int(value))
		config.save("user://gdsense_settings.cfg")
func _i77(enabled: bool):
	if _r38 and _r38.has_method("save_undo_show_history"):
		_r38.save_undo_show_history(enabled)
	else:
		var config = ConfigFile.new()
		config.load("user://gdsense_settings.cfg")
		config.set_value("undo", "show_history_button", enabled)
		config.save("user://gdsense_settings.cfg")
func _f9():
	if not _g34:
		return
	var _k21 = HSeparator.new()
	_g34.add_child(_k21)
	var _o6 = VBoxContainer.new()
	_o6.add_theme_constant_override("separation", 10)
	_g34.add_child(_o6)
	var _t41 = Label.new()
	_t41.text = "Custom Instructions"
	_t41.add_theme_font_size_override("font_size", int(20 * _v59))
	_o6.add_child(_t41)
	var _v47 = HBoxContainer.new()
	_o6.add_child(_v47)
	var _c26 = Label.new()
	_c26.text = "Godot Version:"
	_c26.custom_minimum_size.x = 120
	_v47.add_child(_c26)
	var _y65 = Label.new()
	_y65.text = _f78._p39() if _f78 else "Unknown"
	var _k17 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_y65.add_theme_color_override("font_color", Color(_k17, 0.6))
	_y65.set_meta("secondary", true)
	_v47.add_child(_y65)
	var _y2 = HBoxContainer.new()
	_o6.add_child(_y2)
	var _i96 = Label.new()
	_i96.text = "Temperature:"
	_i96.custom_minimum_size.x = 120
	_y2.add_child(_i96)
	var _z68 = SpinBox.new()
	_z68.name = "TemperatureSpinBox"
	_z68.min_value = 0.0
	_z68.max_value = 1.0
	_z68.step = 0.1
	_z68.value = 0.0
	_z68.value_changed.connect(_w96)
	_y2.add_child(_z68)
	var _g1 = Label.new()
	_g1.text = "(0.0 = use default)"
	var _g79 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_g1.add_theme_color_override("font_color", Color(_g79, 0.6))
	_g1.set_meta("secondary", true)
	_g1.add_theme_font_size_override("font_size", 11)
	_y2.add_child(_g1)
	var _u86 = Label.new()
	_u86.text = "Custom Rules (500 char limit):"
	_u86.add_theme_font_size_override("font_size", int(18 * _v59))
	_o6.add_child(_u86)
	_q99 = TextEdit.new()
	_q99.name = "CustomRulesInput"
	_q99.custom_minimum_size = Vector2(0, 100)
	_q99.placeholder_text = "Enter custom rules for AI responses (one per line)..."
	_q99.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_q99.text_changed.connect(_s28)
	_o6.add_child(_q99)
	_i3 = Label.new()
	_i3.name = "CharCounter"
	_i3.text = "0/500"
	_i3.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_i3.add_theme_font_size_override("font_size", 12)
	_i3.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_o6.add_child(_i3)
	_a67 = Label.new()
	_a67.name = "ValidationMessage"
	_a67.text = ""
	_a67.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	_a67.add_theme_font_size_override("font_size", 12)
	_a67.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_a67.visible = false
	_o6.add_child(_a67)
	_a36.call_deferred()
func _w45():
	_x86 = _d25.new()
	_x86._m53()
	if _d47:
		_d47.item_selected.connect(_o66)
	if _b76:
		_b76.item_selected.connect(_m84)
	if _g84:
		_g84.pressed.connect(_d100)
	if _a93:
		_a93.pressed.connect(_r24)
	if _a32:
		_a32.pressed.connect(_u78)
	if _k19:
		_k19.pressed.connect(_u22)
	if _c67:
		_c67.pressed.connect(_s93)
	if _a31:
		_a31.pressed.connect(_a100)
	if _w35:
		_w35.pressed.connect(_q83)
	if _c42:
		_c42.pressed.connect(_l74)
	if _d37:
		_d37.pressed.connect(_u62)
	if _t87:
		_t87.pressed.connect(_u7)
	if _u26:
		_u26.pressed.connect(_a5)
	if _j52:
		_j52.pressed.connect(_w20)
	if _f41:
		_f41.file_selected.connect(_m37)
	if _o23:
		_o23.file_selected.connect(_y39)
	if _k3:
		_k3.confirmed.connect(_r13)
	_f81()
	_d60()
func _a8():
	if _j71:
		_j71.item_selected.connect(_o21)
	_m70()
	var _s74 = _a81()
	var _a38 = _s27()
	_t24.text = "Auto: %.0f%% (%s detected). Your resolution: %dx%d" % [
		_a38 * 100,
		_s74,
		get_viewport().get_visible_rect().size.x,
		get_viewport().get_visible_rect().size.y
	]
	_f33()
func _a81() -> String:
	var _p5 = get_viewport().get_visible_rect().size
	var width = int(_p5.x)
	var height = int(_p5.y)
	if width < 800 or width > 16384 or height < 600 or height > 16384:
		width = 1920
		height = 1080
	var _u49 = 100
	for _e10 in _f93:
		var _s50 = _f93[_e10]
		if abs(width - _s50.width) <= _u49 and abs(height - _s50.height) <= _u49:
			return _e10
	var _b56 = width * height
	var _u54 = "1080p"
	var _j9 = INF
	for _e10 in _f93:
		var _s50 = _f93[_e10]
		var _w75 = _s50.width * _s50.height
		var _u74 = abs(_b56 - _w75)
		if _u74 < _j9:
			_j9 = _u74
			_u54 = _e10
	return _u54
func _s27() -> float:
	var _e10 = _a81()
	return _f93[_e10].scale
func _z87() -> float:
	if _v73 == "auto":
		return _s27()
	else:
		var _g94 = float(_v73)
		_g94 = clamp(_g94, 0.5, 3.0)  
		if is_nan(_g94) or is_inf(_g94):
			_g94 = 1.0  
		return _g94
func _f33():
	_v59 = _z87()
	var _b16 = int(_b34 * _v59)
	var _l80 = get_node_or_null("MarginContainer/TabContainer/History")
	if _l80:
		for label in _l75(_l80):
			if label is Label:
				label.add_theme_font_size_override("font_size", _b16)
			elif label is RichTextLabel:
				label.add_theme_font_size_override("normal_font_size", _b16)
	_r56(_b16)
func _r56(_b16: int):
	var _q1 = get_node_or_null("MarginContainer/TabContainer/Settings/_o99/VBoxContainer")
	if not _q1:
		return
	var _t44 = ["Ghost Text Autocomplete", "Custom Instructions"]
	var _j18 = ["Inline Explain Buttons", "Inline Refactor Buttons", "Refactor Undo System",
					   "Custom Rules", "Parameter Overrides"]
	for _h61 in _l75(_q1):
		if _h61 is Label:
			var _y45 = _h61.text
			var target_size = _b16
			for _n79 in _t44:
				if _y45.begins_with(_n79):
					target_size = int(20 * _v59)
					break
			if target_size == _b16:  
				for _b11 in _j18:
					if _y45.begins_with(_b11):
						target_size = int(18 * _v59)
						break
			_h61.add_theme_font_size_override("font_size", target_size)
		elif _h61 is RichTextLabel:
			_h61.add_theme_font_size_override("normal_font_size", _b16)
func _u28(text: String) -> bool:
	var _p73 = [
		"highest-volume", "smart triggers", "fixed settings", "adds clickable",
		"track refactored", "use default", "auto detects", "char limit",
		"following keywords", "second delay", "token max", "help icons",
		"visual indicators", "one-click undo", "AI-powered"
	]
	for _y99 in _p73:
		if _y99 in text:
			return true
	return false
func _l75(node: Node) -> Array:
	var children = []
	for _h61 in node.get_children():
		children.append(_h61)
		children.append_array(_l75(_h61))
	return children
func _o21(index: int):
	var _b81 = _g83[index]
	if typeof(_b81) == TYPE_STRING and _b81 == "auto":
		_v73 = "auto"
	else:
		_v73 = str(_b81)
	_e49()
	_f33()
	if _v73 == "auto":
		var _s74 = _a81()
		var _a38 = _s27()
		_t24.text = "Auto: %.0f%% (%s detected). Your resolution: %dx%d" % [
			_a38 * 100,
			_s74,
			get_viewport().get_visible_rect().size.x,
			get_viewport().get_visible_rect().size.y
		]
	else:
		_t24.text = "Manual: %.0f%%. Auto detects based on 1080p/1440p/4K presets" % [
			float(_v73) * 100
		]
func _e49():
	var config = ConfigFile.new()
	config.load("user://gdsense_settings.cfg")
	config.set_value("font_scale", "mode", _v73)
	config.save("user://gdsense_settings.cfg")
func _m70():
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		_v73 = config.get_value("font_scale", "mode", "auto")
		if _v73 == "auto":
			_j71.selected = 0
		elif _v73 == "0.8":
			_j71.selected = 1
		elif _v73 == "1.0":
			_j71.selected = 2
		elif _v73 == "1.25":
			_j71.selected = 3
		elif _v73 == "1.5":
			_j71.selected = 4
	else:
		_v73 = "auto"
		_j71.selected = 0
func _g4(parent: Node) -> void:
	var _j100 = HBoxContainer.new()
	_j100.add_theme_constant_override("separation", 10)
	var _m9 = Control.new()
	_m9.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_j100.add_child(_m9)
	var _u10 = Button.new()
	_u10.text = "👍"
	_u10.tooltip_text = "Good response"
	_u10.flat = false  
	_u10.custom_minimum_size = Vector2(36, 36)  
	_u10.add_theme_font_size_override("font_size", 16)
	_u10.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	_u10.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9))
	_u10.add_theme_stylebox_override("normal", _h17())
	_u10.add_theme_stylebox_override("hover", _t19())
	_u10.add_theme_stylebox_override("pressed", _o69())
	_u10.pressed.connect(_n40)
	_p25(_u10)
	_j100.add_child(_u10)
	var _q39 = Button.new()
	_q39.text = "👎"
	_q39.tooltip_text = "Poor response"
	_q39.flat = false  
	_q39.custom_minimum_size = Vector2(36, 36)  
	_q39.add_theme_font_size_override("font_size", 16)
	_q39.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	_q39.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9))
	_q39.add_theme_stylebox_override("normal", _h17())
	_q39.add_theme_stylebox_override("hover", _t19())
	_q39.add_theme_stylebox_override("pressed", _o69())
	_q39.pressed.connect(_o17)
	_p25(_q39)
	_j100.add_child(_q39)
	parent.add_child(_j100)
func _h17() -> StyleBoxFlat:
	var _p10 = StyleBoxFlat.new()
	_p10.bg_color = Color(0, 0, 0, 0)  
	_p10.set_corner_radius_all(4)
	return _p10
func _t19() -> StyleBoxFlat:
	var _p10 = StyleBoxFlat.new()
	_p10.bg_color = Color(0.3, 0.3, 0.3, 0.3)  
	_p10.set_corner_radius_all(6)
	_p10.set_border_width_all(1)
	_p10.border_color = Color(0.5, 0.5, 0.5, 0.5)
	return _p10
func _o69() -> StyleBoxFlat:
	var _p10 = StyleBoxFlat.new()
	_p10.bg_color = Color(0.2, 0.2, 0.2, 0.4)  
	_p10.set_corner_radius_all(6)
	_p10.set_border_width_all(1)
	_p10.border_color = Color(0.4, 0.4, 0.4, 0.6)
	return _p10
func _p25(_x2: Button) -> void:
	_x2.set_meta("original_scale", Vector2.ONE)
	_x2.set_meta("is_hovering", false)
	_x2.modulate.a = 0.7  
	_x2.pivot_offset = _x2.custom_minimum_size / 2  
	_x2.mouse_entered.connect(_d32.bind(_x2))
	_x2.mouse_exited.connect(_d82.bind(_x2))
	_x2.button_down.connect(_l33.bind(_x2))
	_x2.button_up.connect(_g28.bind(_x2))
func _d32(_x2: Button) -> void:
	if _x2.get_meta("is_hovering", false):
		return
	_x2.set_meta("is_hovering", true)
	var _p85 = get_tree().create_tween()
	_p85.set_parallel(true)
	_p85.set_ease(Tween.EASE_OUT)
	_p85.set_trans(Tween.TRANS_CUBIC)
	_p85.tween_property(_x2, "scale", Vector2(1.2, 1.2), 0.2)
	_p85.tween_property(_x2, "modulate:a", 1.0, 0.2)
	_p85.tween_property(_x2, "modulate", Color(1.1, 1.1, 1.1, 1.0), 0.2)
func _d82(_x2: Button) -> void:
	_x2.set_meta("is_hovering", false)
	var _p85 = get_tree().create_tween()
	_p85.set_parallel(true)
	_p85.set_ease(Tween.EASE_OUT)
	_p85.set_trans(Tween.TRANS_CUBIC)
	_p85.tween_property(_x2, "scale", Vector2.ONE, 0.2)
	_p85.tween_property(_x2, "modulate", Color(1.0, 1.0, 1.0, 0.7), 0.2)
func _l33(_x2: Button) -> void:
	var _p85 = get_tree().create_tween()
	_p85.set_ease(Tween.EASE_OUT)
	_p85.set_trans(Tween.TRANS_CUBIC)
	_p85.tween_property(_x2, "scale", Vector2(0.95, 0.95), 0.1)
func _g28(_x2: Button) -> void:
	var _q79 = Vector2(1.2, 1.2) if _x2.get_meta("is_hovering", false) else Vector2.ONE
	var _p85 = get_tree().create_tween()
	_p85.set_ease(Tween.EASE_OUT)
	_p85.set_trans(Tween.TRANS_CUBIC)
	_p85.tween_property(_x2, "scale", _q79, 0.1)
func _n40():
	if _f78:
		_f78._v74("positive", "helpful", "")
func _o17():
	_m80()
func _m80():
	var _j80 = AcceptDialog.new()
	_j80.title = "Help Us Improve"
	_j80.dialog_close_on_escape = true
	_j80.size = Vector2(400, 300)
	var _t7 = VBoxContainer.new()
	_t7.add_theme_constant_override("separation", 10)
	var _m11 = Label.new()
	_m11.text = "What was wrong with this response?"
	_t7.add_child(_m11)
	var _g100 = OptionButton.new()
	_g100.name = "CategoryOptions"
	_g100.add_item("Incorrect information")
	_g100.add_item("Wrong Godot version")
	_g100.add_item("Code doesn't work")
	_g100.add_item("Too complex")
	_g100.add_item("Not helpful")
	_g100.add_item("Other")
	_t7.add_child(_g100)
	var _l60 = Label.new()
	_l60.text = "Additional details (optional):"
	_t7.add_child(_l60)
	var _v2 = TextEdit.new()
	_v2.name = "DetailsText"
	_v2.custom_minimum_size = Vector2(0, 80)
	_v2.placeholder_text = "Describe what went wrong..."
	_t7.add_child(_v2)
	var _b27 = HBoxContainer.new()
	_b27.alignment = BoxContainer.ALIGNMENT_END
	var _m56 = Button.new()
	_m56.text = "Cancel"
	_m56.pressed.connect(_j80.hide)
	_b27.add_child(_m56)
	var _a23 = Button.new()
	_a23.text = "Submit Feedback"
	_a23.pressed.connect(_a40.bind(_j80))
	_b27.add_child(_a23)
	_t7.add_child(_b27)
	_j80.add_child(_t7)
	add_child(_j80)
	_j80.popup_centered()
func _a40(_x26: AcceptDialog):
	var _t7 = _x26.get_child(0)
	var _g100: OptionButton = null
	var _v2: TextEdit = null
	for _h61 in _t7.get_children():
		if _h61 is OptionButton and not _g100:
			_g100 = _h61
		elif _h61 is TextEdit and not _v2:
			_v2 = _h61
	var _f94 = ""
	if _g100.selected >= 0:
		_f94 = _g100.get_item_text(_g100.selected)
	var details = _v2.text.strip_edges()
	if _f78:
		_f78._v74("negative", _f94, details)
	_x26.hide()
	_x26.queue_free()
func _s28():
	if not _q99 or not _i3 or not _a67:
		return
	var _l37 = _q99.text
	var _g13 = _l37.length()
	_i3.text = "%d/500" % _g13
	if _g13 > 500:
		_i3.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	elif _g13 > 400:
		_i3.add_theme_color_override("font_color", Color(1.0, 0.8, 0.5))
	else:
		_i3.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	if _f78:
		var _p32 = _f78._p75(_l37)
		if _p32.get("valid", false):
			_a67.visible = false
			_f78._n34(_l37)
		else:
			var _k68 = _p32.get("errors", ["Unknown error"])
			_a67.text = _k68[0] if not _k68.is_empty() else "Unknown error"
			_a67.visible = true
func _w96(value: float):
	if _f78:
		var _w78 = find_child("_b3", true)
		var max_tokens = _w78.value if _w78 else 0
		_f78._y83(value, int(max_tokens))
func _r59(value: float):
	if _f78:
		var _z68 = find_child("_i28", true)
		var _k6 = _z68.value if _z68 else 0.0
		_f78._y83(_k6, int(value))
func _a36():
	if not _f78:
		return
	var _z68 = find_child("_i28", true)
	var _w78 = find_child("_b3", true)
	if _q99:
		var config = ConfigFile.new()
		if config.load("user://gdsense_settings.cfg") == OK:
			var _l37 = config.get_value("custom_rules", "rules_text", "")
			_q99.text = _l37
			if _i3:
				_i3.text = "%d/500" % _l37.length()
		else:
			pass
	else:
		pass
	if _z68:
		var config = ConfigFile.new()
		if config.load("user://gdsense_settings.cfg") == OK:
			var _k6 = config.get_value("parameters", "temperature_override", 0.0)
			_z68.value = _k6
	if _w78:
		var config = ConfigFile.new()
		if config.load("user://gdsense_settings.cfg") == OK:
			var max_tokens = config.get_value("parameters", "max_tokens_override", 0)
			_w78.value = max_tokens
func _h19(_w11: Array, parent: Node):
	var _k21 = HSeparator.new()
	_k21.add_theme_constant_override("separation", 8)
	parent.add_child(_k21)
	var _z69 = Label.new()
	_z69.text = "📚 Documentation Sources:"
	_z69.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	_z69.add_theme_font_size_override("font_size", 25)
	parent.add_child(_z69)
	var _u13 = VBoxContainer.new()
	_u13.add_theme_constant_override("separation", 1)
	parent.add_child(_u13)
	_w11.sort_custom(func(a, b): return a.get("priority", 0.0) > b.get("priority", 0.0))
	var _m97 = min(_w11.size(), 5)
	for i in range(_m97):
		var source = _w11[i]
		var _a28 = source.get("url", "")
		var title = source.get("title", "Godot Documentation")
		if not _a28.is_empty():
			var _a11 = HBoxContainer.new()
			_a11.add_theme_constant_override("separation", 8)
			_u13.add_child(_a11)
			var _u3 = Label.new()
			_u3.text = "•"
			_u3.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
			_u3.custom_minimum_size.x = 12
			_a11.add_child(_u3)
			var _k24 = Button.new()
			var _m27 = title if title.length() <= 60 else title.substr(0, 57) + "..."
			_k24.text = _m27
			_k24.tooltip_text = title  
			_k24.flat = true
			_k24.clip_text = true  
			_k24.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
			_k24.add_theme_color_override("font_hover_color", Color(0.8, 0.9, 1.0))
			_k24.add_theme_font_size_override("font_size", 20)
			_k24.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_k24.alignment = HORIZONTAL_ALIGNMENT_LEFT
			_k24.pressed.connect(_d59.bind(_a28))
			_a11.add_child(_k24)
func _d59(_a28: String):
	OS.shell_open(_a28)
func send_explain_request(function_name: String, _w13: String):
	if not _f78:
		return
	var _r77 = "@explain %s\n\nFunction source:\n```gdscript\n%s\n```" % [function_name, _w13]
	_t85(_r77)
func _m38(function_name: String, _w13: String):
	if not _i91:
		return
	_i91.text = ""
	var _r77 = "@explain %s\n\nFunction source:\n```gdscript\n%s\n```" % [function_name, _w13]
	_i91.text = _r77
	_i91.grab_focus()
	_i91.set_caret_line(_i91.get_line_count() - 1)
	_i91.set_caret_column(_i91.get_line(_i91.get_line_count() - 1).length())
func _exit_tree() -> void:
	_m67()
	_i70()
	_o90()
	_n6()
	if _t68:
		if _t68._f56.is_connected(_z45):
			_t68._f56.disconnect(_z45)
		if _t68._m28.is_connected(_f86):
			_t68._m28.disconnect(_f86)
		if _t68._p31.is_connected(_h66):
			_t68._p31.disconnect(_h66)
		if _t68._w3.is_connected(_r25):
			_t68._w3.disconnect(_r25)
		if _t68._q47.is_connected(_i18):
			_t68._q47.disconnect(_i18)
		if _t68._n32.is_connected(_v26):
			_t68._n32.disconnect(_v26)
		if _t68._y89.is_connected(_f14):
			_t68._y89.disconnect(_f14)
		if _t68._x100.is_connected(_z6):
			_t68._x100.disconnect(_z6)
		_t68._q60()
		_t68 = null
	_v17 = null
	if is_instance_valid(_l25):
		if _l25.pressed.is_connected(_d93):
			_l25.pressed.disconnect(_d93)
		_l25.queue_free()
		_l25 = null
	if _f65:
		if _f65._k20:
			_f65._k20.clear()
		_f65 = null
	if _l66:
		_l66._f65 = null
		_l66 = null
	if _v3:
		_v3._q60()
		_v3 = null
	if _v1:
		for _h61 in _v1.get_children():
			_h61.queue_free()
		_v1 = null
	_d83.clear()
	if _f78:
		if _f78._m76.is_connected(_v87):
			_f78._m76.disconnect(_v87)
		if _f78._r52.is_connected(_w80):
			_f78._r52.disconnect(_w80)
		if _f78._l24.is_connected(_q6):
			_f78._l24.disconnect(_q6)
		if _f78._o39.is_connected(_x91):
			_f78._o39.disconnect(_x91)
		if _f78._j33.is_connected(_y98):
			_f78._j33.disconnect(_y98)
		if _f78._i1.is_connected(_i89):
			_f78._i1.disconnect(_i89)
		if _f78._j20.is_connected(_g37):
			_f78._j20.disconnect(_g37)
	if _k9:
		_k9.free()
		_k9 = null
	_d84 = null
	_w31 = null
	_f78 = null
	_r38 = null
func _s11() -> void:
	if _q15:
		_q15.custom_minimum_size.y = 8
		_q15.show_percentage = false
		var _n19 = StyleBoxFlat.new()
		_n19.bg_color = Color(0.1, 0.1, 0.1, 0.5)
		_n19.corner_radius_top_left = 4
		_n19.corner_radius_top_right = 4
		_n19.corner_radius_bottom_left = 4
		_n19.corner_radius_bottom_right = 4
		_q15.add_theme_stylebox_override("background", _n19)
		_q15.mouse_entered.connect(_p100)
		_q15.mouse_exited.connect(_i55)
	_w77(0.0)
	if _k35:
		_k35.mouse_entered.connect(_p100)
		_k35.mouse_exited.connect(_i55)
func _d98() -> void:
	if not _p47:
		return
	_p47.clear()
	_p47.add_item("Commands")
	_p47.selected = 0
	_p47.add_separator()
	for _l5 in _d85:
		_p47.add_item(_l5)
	_p47.item_selected.connect(_w48)
func _e32() -> void:
	if not _u42:
		return
	_u42.clear()
	_u42.add_item(_w72[_q63])
	_o7()
	_u42.item_selected.connect(_m69)
	_l4()
func _l4() -> void:
	if not _u42 or not _d84:
		return
func _o7() -> void:
	if not _u42:
		return
	var _c93 = false
	if _f78:
		var _v37 = _f78._y64()
		if _v37 and _v37.has("features"):
			var features = _v37.get("features", {})
			_c93 = features.get("agent", false)
	var _g50 = _u42.item_count > 1
	if _c93:
		if not _g50:
			_u42.add_item(_w72[_y69])
	else:
		if _g50:
			if _u42.selected == _y69:
				_u42.selected = _q63
				_u19()
			_u42.remove_item(_y69)
func _m69(index: int) -> void:
	match index:
		_q63:
			_d29 = false
			if _k54:
				_k54.visible = true
			if _n38:
				_n38.visible = true
			if _c65:
				_c65.visible = false
			_i91.placeholder_text = "Ask me anything about Godot..."
		_y69:
			_m62()
	_i91.grab_focus()
func _e27() -> void:
	_u51()
	var _r45 = _i91.text
	var command_count = 0
	for _i34 in _d85:
		var _v54 = RegEx.new()
		_v54.compile(_i34 + "\\b")  
		var _l62 = _v54.search_all(_r45)
		command_count += _l62.size()
	if command_count != _o85:
		_o85 = command_count
		if _d91:
			_d91.stop()
			_d91.start()
func _b97() -> void:
	_s23(true)
func _h9(_l5: String, path: String) -> void:
	_s23(true)
func _s23(_p34: bool = false) -> void:
	if _l8 and not _p34:
		return
	var _r45 = _i91.text
	var _c98 = not _r45.strip_edges().is_empty()
	var _b55 = _d83.size() > 0
	if not _c98 and not _b55:
		_b48(0, [])
		return
	var _v50 = Time.get_ticks_msec()
	if not _p34 and not _l93.is_empty():
		var _k10 = _v50 - _l93.get("time", 0)
		if _k10 < _e81:
			var _z88 = _l93.get("tokens", 0)
			var _g65 = _l93.get("breakdown", [])
			_b48(_z88, _g65)
			return
	if _k35:
		_k35.text = "Context: Updating..."
	if _f78 and not _f78._e21().is_empty():
		var messages = []
		for message in _d83:
			messages.append(message)
		var context_metadata: Dictionary = {}
		if _c98:
			var _q10 = _u20(_r45, false)
			var processed_prompt = _q10.get("processed_prompt", _r45)
			if not processed_prompt.is_empty():
				messages.append({
					"role": "user",
					"content": processed_prompt
				})
			var _m15 = _q10.get("context_metadata", {})
			if _m15 == null or not _m15 is Dictionary:
				_m15 = {}
			context_metadata = _m15
		else:
			context_metadata = {}
		_f78._w87(messages, context_metadata)
	else:
		_s84()
func _s84() -> void:
	var _r45 = _i91.text
	var _q10 = _u20(_r45, false)
	var estimated_tokens = _q10.get("estimated_tokens", 0)
	var _d51 = _c52()
	var _r46 = estimated_tokens + _d51
	var breakdown = [
		{"name": "current_prompt", "tokens": estimated_tokens},
		{"name": "chat_history", "tokens": _d51}
	]
	_b48(_r46, breakdown)
func _t43(_v16: int, breakdown: Array, _o89: int = 128000) -> void:
	_x17 = _o89
	_l93 = {
		"tokens": _v16,
		"breakdown": breakdown,
		"limit": _o89,
		"time": Time.get_ticks_msec()
	}
	_b48(_v16, breakdown)
func _c52() -> int:
	var _o61 = 0
	for message in _d83:
		if message.has("content"):
			_o61 += message["content"].length()
	return _o61 / 4
func _b48(tokens: int, breakdown: Array) -> void:
	_z90 = tokens
	_g58 = breakdown
	var _r27 = float(tokens) / float(_x17) * 100.0
	if _q15:
		var _u30 = min(_r27, 100.0)
		if _u30 > 0 and _u30 < 0.5:
			_u30 = 0.5  
		_q15.value = _u30
	if _k35:
		if _r27 < 1.0 and _r27 > 0:
			_k35.text = "Context: " + str(snapped(_r27, 0.1)) + "%"
		else:
			_k35.text = "Context: " + str(int(_r27)) + "%"
		if _r27 >= 100.0:
			_k35.modulate = Color.RED
		elif _r27 >= 85.0:
			_k35.modulate = Color.YELLOW
		else:
			_k35.modulate = Color.LIGHT_GREEN
	_w77(_r27 / 100.0)
	if _r27 >= 95.0 and _f78:
		var _t55 = _f78._c80() if _f78 else ""
		_f78._r2.emit("critical", _t55, _r27, "")
	elif _r27 >= 90.0 and _f78:
		var _t55 = _f78._c80() if _f78 else ""
		_f78._r2.emit("high", _t55, _r27, "")
	elif _r27 >= 75.0 and _f78:
		var _t55 = _f78._c80() if _f78 else ""
		_f78._r2.emit("medium", _t55, _r27, "")
	if _r27 >= _y9 * 100.0:
		_h43.show()
		if _r27 >= 100.0:
			_h43.text = "⚠ Context capacity exceeded! Please reduce content."
			_h43.modulate = Color.RED
		else:
			_h43.text = "⚠ Context capacity at " + str(int(_r27)) + "% - consider reducing @ commands"
			_h43.modulate = Color.YELLOW
	else:
		_h43.hide()
func _f13() -> void:
	_b48(0, [])
	if _q15:
		_q15.tooltip_text = ""
	if _k35:
		_k35.tooltip_text = ""
	if _w9:
		_w9.hide()
func _w77(_t56: float) -> void:
	var color: Color
	if _t56 <= 0.6:  
		color = Color.GREEN
	elif _t56 <= 0.85:  
		color = Color.YELLOW
	else:  
		color = Color.RED
	var _a89 = StyleBoxFlat.new()
	_a89.bg_color = color
	_a89.corner_radius_top_left = 4
	_a89.corner_radius_top_right = 4
	_a89.corner_radius_bottom_left = 4
	_a89.corner_radius_bottom_right = 4
	if _q15:
		_q15.add_theme_stylebox_override("fill", _a89)
func _p100() -> void:
	var tooltip_text = "Context Usage Breakdown:\n"
	if _g58.size() > 0:
		for _v92 in _g58:
			if _v92 is Dictionary and _v92.has("name") and _v92.has("tokens"):
				var _m13 = _v92["tokens"]
				var _z34 = float(_m13) / float(_x17) * 100.0
				tooltip_text += str(_v92["name"]) + ": " + str(int(_z34)) + "%\n"
		tooltip_text = tooltip_text.rstrip("\n")
	else:
		tooltip_text += "No breakdown available"
	if _q15:
		_q15.tooltip_text = tooltip_text
	if _k35:
		_k35.tooltip_text = tooltip_text
func _i55() -> void:
	if _q15:
		_q15.tooltip_text = ""
	if _k35:
		_k35.tooltip_text = ""
func _w48(index: int) -> void:
	if index <= 1:
		return
	var _y21 = index - 2
	if _y21 >= 0 and _y21 < _d85.size():
		var _l5 = _d85[_y21]
		var _r45 = _i91.text
		var _c88 = _i91.get_caret_line()
		var caret_column = _i91.get_caret_column()
		if _c88 < _i91.get_line_count():
			var _f62 = _i91.get_line(_c88)
			var _r55 = _f62.substr(0, caret_column)
			var _t8 = _f62.substr(caret_column)
			var _r44 = _r55 + _l5 + " " + _t8
			_i91.set_line(_c88, _r44)
			_i91.set_caret_column(caret_column + _l5.length() + 1)
		else:
			_i91.text += _l5 + " "
			_i91.set_caret_column(_i91.text.length())
		_p47.selected = 0
		_s23()
		_i91.grab_focus()
func _x68(_f36: String) -> bool:
	var _d34 = [
		"truncated",
		"trimmed",
		"shortened",
		"context limit",
		"content limited"
	]
	var _b33 = _f36.to_lower()
	for _y33 in _d34:
		if _y33 in _b33:
			return true
	return false
func _z44(message: String) -> void:
	_w9.text = "ℹ " + message
	_w9.show()
	var _e63 = Timer.new()
	add_child(_e63)
	_e63.timeout.connect(func(): 
		_w9.hide()
		_e63.queue_free()
	)
	_e63.one_shot = true
	_e63.start(10.0)
func _n26(_f47: String) -> String:
	var _b51 = _f47.to_lower()
	if "token" in _b51 and ("limit" in _b51 or "exceed" in _b51):
		return "Your request is too large. Try reducing the amount of context or splitting into smaller requests."
	elif "rate limit" in _b51:
		return "You're sending requests too quickly. Please wait a moment before trying again."
	elif "unauthorized" in _b51 or "invalid api key" in _b51:
		return "Your API key is invalid or has expired. Please check your settings."
	elif "network" in _b51 or "connection" in _b51:
		return "Unable to connect to the AI service. Please check your internet connection."
	elif "timeout" in _b51:
		return "The request took too long to process. Please try again with a smaller request."
	elif "model" in _b51 and "not found" in _b51:
		return "The selected AI model is not available. Please try a different model."
	else:
		return _f47  
func _h97(_z33: Dictionary) -> void:
	_h77()
	_n18()
	_q90()
	_o7()
	_q28(_z33)
func _s53(_s25: String) -> String:
	if _s25.is_empty():
		return ""
	var _t35 = _s25.split("T")[0] if "T" in _s25 else _s25
	var _n66 = _t35.split("-")
	if _n66.size() < 3:
		return _s25  
	var year = _n66[0]
	var month = int(_n66[1]) if _n66[1].is_valid_int() else 0
	var day = int(_n66[2]) if _n66[2].is_valid_int() else 0
	if month < 1 or month > 12 or day < 1 or day > 31:
		return _s25  
	var _v36 = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
					   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%s %d, %s" % [_v36[month - 1], day, year]
func _z60(_w39: String, _y88: String, _r27: float, _p18: String = "") -> void:
	var _l29 = _q58()
	if _l29:
		var title = ""
		var message = ""
		var _b26 = _l84._y31.WARNING
		var _o93 = "credits"
		match _w39:
			"low":  
				title = "Usage Notice"
				message = "You've used %d%% of your %s for this period." % [int(_r27), _o93]
				_b26 = _l84._y31.INFO
			"medium":  
				title = "Usage Alert"
				message = "Heads up: you've used %d%% of your %s this period." % [int(_r27), _o93]
			"high":    
				title = "Usage Warning"
				message = "You've used %d%% of your %s. Consider switching models or upgrading." % [int(_r27), _o93]
				_b26 = _l84._y31.WARNING
			"critical": 
				title = "Critical Usage"
				message = "Critical: only %d%% of your %s remain." % [int(100 - _r27), _o93]
				_b26 = _l84._y31.ERROR
		if not _p18.is_empty():
			var _m87 = _s53(_p18)
			message += " Usage resets on %s." % _m87
		if _f78:
			var _p53 = _f78._q88()
			if _p53 != "ULTRA" and _p53 != "BETA_FREE":
				message += " Upgrade: gdsense.com/pricing"
		_l29._o72(title, message, _b26, 8.0)  
	if _w39 == "critical" and _g41:
		var _e1 = "⚠️ CRITICAL: %d%% of credits used" % [int(_r27)]
		_g41.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))  
		_g41.text = _e1
		await get_tree().create_timer(10.0).timeout
		if is_instance_valid(_g41):
			_g41.remove_theme_color_override("font_color")
			if _f78 and _f78._d31():
				_g41.text = "API Key Loaded"
				var _v37 = _f78._y64()
				if _v37 and _v37.has("tier"):
					_q28(_v37)
			else:
				_g41.text = "No API Key"
func _g37(message: String) -> void:
	var _l29 = _q58()
	if _l29:
		_l29._o72("Context Truncated", message, _l84._y31.WARNING, 5.0)
func _q90() -> void:
	if not _f78:
		return
	var _z36 = _f78._z36()
	if _x12:
		_x12.disabled = not _z36
		if not _z36:
			_x12.button_pressed = false
			_x12.tooltip_text = "Refactor is not available in Free tier"
		else:
			_x12.tooltip_text = "Show Refactor Buttons Above Functions"
	if _r38 and _r38.has_method("update_refactor_button_availability"):
		_r38.update_refactor_button_availability(_z36)
func _x50() -> void:
	if _a18:
		return  
	_a18 = PanelContainer.new()
	_a18.name = "UpdateBanner"
	_a18.visible = false
	var _b2 = StyleBoxFlat.new()
	if _d84:
		var _b18 = _d84.get_editor_settings()
		if _b18:
			var _z13 = _b18.get_setting("interface/theme/base_color")
			var _d43 = _b18.get_setting("interface/theme/accent_color")
			_b2.bg_color = _d43.lerp(_z13, 0.8)  
		else:
			_b2.bg_color = Color(0.2, 0.4, 0.6, 1.0)  
	else:
		_b2.bg_color = Color(0.2, 0.4, 0.6, 1.0)  
	_b2.set_corner_radius_all(4)
	_b2.set_content_margin_all(8)
	_a18.add_theme_stylebox_override("panel", _b2)
	var _c70 = HBoxContainer.new()
	_c70.add_theme_constant_override("separation", 8)
	var _r64 = Label.new()
	_r64.name = "UpdateMessage"
	_r64.text = "Update Available"
	_r64.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_c70.add_child(_r64)
	var _h21 = Label.new()
	_h21.name = "DownloadLink"
	_h21.text = "Download at gdsense.com"
	_h21.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))  
	_c70.add_child(_h21)
	var _b92 = Button.new()
	_b92.name = "DismissButton"
	_b92.text = "X"
	_b92.tooltip_text = "Dismiss update notification"
	_b92.custom_minimum_size = Vector2(24, 24)
	_b92.flat = true
	_b92.pressed.connect(_s52)
	_c70.add_child(_b92)
	_a18.add_child(_c70)
	var _v28 = get_node_or_null("MarginContainer/TabContainer/Chat")
	if _v28:
		var _z16 = _v28.get_child(0) if _v28.get_child_count() > 0 else null
		if _z16 and _z16 is VBoxContainer:
			_z16.add_child(_a18)
			_z16.move_child(_a18, 0)  
		else:
			_v28.add_child(_a18)
	else:
		add_child(_a18)
func _f5(_a15: String, _z18: String) -> void:
	if _e62:
		return
	if not _a18:
		_x50()
	var _r64 = _a18.find_child("_u48", true)
	if _r64:
		_r64.text = "Update Available: v%s (you have v%s)" % [_a15, _z18]
	_a18.visible = true
func _s52() -> void:
	_e62 = true
	if _a18:
		_a18.visible = false
func _q28(_z33: Dictionary) -> void:
	var _p53 = _z33.get("tier", "Unknown")
	if _g41:
		var _r45 = _g41.text
		if "API Key Loaded" in _r45:
			if _f78 and _f78._c4():
				var env = _f78._j83()
				_g41.text = "API Key Loaded (%s) - %s Tier" % [env.capitalize(), _p53]
			else:
				_g41.text = "API Key Loaded - %s Tier" % _p53
	_r41()
func _r41() -> void:
	if _l25:
		return  
	if not _g41 or not _f78:
		return
	_l25 = Button.new()
	_l25.text = "↻"  
	_l25.tooltip_text = "Refresh tier info"
	_l25.flat = true
	_l25.custom_minimum_size = Vector2(24, 24)
	_l25.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_x39(_l25)
	var parent = _g41.get_parent()
	if parent:
		var _d26 = _g41.get_index()
		parent.add_child(_l25)
		parent.move_child(_l25, _d26 + 1)
	_l25.pressed.connect(_d93)
func _d93() -> void:
	if _f78:
		_f78._m36()
func _u40(model: String) -> String:
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
func _q58() -> _l84:
	var _l29 = find_child("_l84", true)
	if _l29 and _l29 is _l84:
		return _l29
	var _b82 = preload("res://addons/gdsense/scenes/_y46.tscn")
	if _b82:
		_l29 = _b82.instantiate()
		if _k9:
			var _d84 = _k9.get_editor_interface()
			if _d84:
				_l29._i71(_d84)
		add_child(_l29)
		_l29.z_index = 1000
		return _l29
	return null
func _d60():
	if not _x86:
		return
	_n74()
	_n1()
	_i72()
func _n74():
	if not _x86 or not _d47:
		return
	var recent_chats = _x86._u93()
	_d47.clear()
	_m52 = -1
	for _p42 in recent_chats:
		var _a2 = _p42._i10()
		var timestamp = _p42._s30()
		var _w7 = "%s - %s" % [_a2, timestamp]
		var index = _d47.add_item(_w7)
		_d47.set_item_metadata(index, _p42.timestamp)
		_d47.set_item_tooltip(index, _p42._x69(80))
	_s44()
	_f81()
func _n1():
	if not _x86 or not _b76:
		return
	var favorite_chats = _x86._c60()
	_b76.clear()
	_j97 = -1
	for _p42 in favorite_chats:
		var _a2 = _p42._i10()
		var timestamp = _p42._s30()
		var _w7 = "★ %s - %s" % [_a2, timestamp]
		var index = _b76.add_item(_w7)
		_b76.set_item_metadata(index, _p42.timestamp)
		_b76.set_item_tooltip(index, _p42._x69(80))
	_h74()
	_f81()
func _i72():
	if not _x86 or not _w85:
		return
	var _s32 = _x86._u93().size()
	var _e97 = _x86._c60().size()
	_w85.text = "Recent: %d | Favorites: %d" % [_s32, _e97]
	var font_color = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	_w85.add_theme_color_override("font_color", font_color)
func _o66(index: int):
	if index < 0 or not _x86:
		return
	_m52 = index
	var timestamp = _d47.get_item_metadata(index)
	var _p42 = _x86._i66(timestamp)
	if _p42:
		_s43(_p42)
	_f81()
func _m84(index: int):
	if index < 0 or not _x86:
		return
	_j97 = index
	var timestamp = _b76.get_item_metadata(index)
	var _p42 = _x86._i66(timestamp)
	if _p42:
		_l27(_p42)
	_f81()
func _s43(_p42: _d25._g63):
	if not _p42 or not _t79 or not _j64 or not _n98:
		return
	var _b79 = _p42._c53()
	_t79.text = "%s - %s (%d exchange%s)" % [
		_p42._i10(),
		_p42._s30(),
		_b79,
		"s" if _b79 != 1 else ""
	]
	_j64.bbcode_enabled = true
	_j64.text = _g42(_p42)
	var _b87 = _p42._r14 if not _p42._r14.is_empty() else "Unknown"
	_n98.text = "[Model: %s]\n[Session ID: %s]" % [_b87, _p42.session_id]
func _l27(_p42: _d25._g63):
	if not _p42 or not _g82 or not _l11 or not _n55:
		return
	var _b79 = _p42._c53()
	_g82.text = "%s - %s (%d exchange%s)" % [
		_p42._i10(),
		_p42._s30(),
		_b79,
		"s" if _b79 != 1 else ""
	]
	_l11.bbcode_enabled = true
	_l11.text = _g42(_p42)
	var _b87 = _p42._r14 if not _p42._r14.is_empty() else "Unknown"
	_n55.text = "[Model: %s]\n[Session ID: %s]" % [_b87, _p42.session_id]
func _g42(_p42: _d25._g63) -> String:
	var _t32 = ""
	for _f43 in _p42.exchanges:
		if not _f43 is Dictionary:
			continue
		var _r63 = _f43.get("user_message", "")
		if _r63.begins_with("@explain"):
			var _r53 = _r63.find("\n")
			if _r53 != -1:
				_r63 = _r63.substr(0, _r53) + " (code attached)"
		var _n80 = _t94.to_html()
		_t32 += "[b][color=#%s]You:[/color][/b]\n" % _n80
		_t32 += _d68(_r63) + "\n\n"
		var _n51 = _f43.get("ai_response", "")
		var _o3 = _w99.to_html()
		_t32 += "[b][color=#%s]GDSense:[/color][/b]\n" % _o3
		var _n66 = _n51.split("```")
		var _s17 = get_theme_color("base_color", "Editor")
		var _z23 = _s17.darkened(0.2) if _s17.get_luminance() > 0.5 else _s17.lightened(0.1)
		var _w55 = _z23.to_html()
		for i in range(_n66.size()):
			var _d67 = _n66[i]
			if i % 2 == 0:
				_t32 += _d68(_d67)
			else:
				var _k56 = _d67.find("\n")
				var _v14 = _d67
				if _k56 != -1:
					_v14 = _d67.substr(_k56 + 1)
				var _h81 = _c22(_v14)
				_t32 += "\n[bgcolor=#%s]%s[/bgcolor]\n" % [_w55, _h81]
		_t32 += "\n\n"
		_t32 += "[color=#666666]────────────────────────────────[/color]\n\n"
	return _t32
func _s44():
	if _t79:
		_t79.text = "Select a chat to preview"
	if _j64:
		_j64.text = "Select a chat to view"
	if _n98:
		_n98.text = "Select a chat to view"
func _h74():
	if _g82:
		_g82.text = "Select a favorite to preview"
	if _l11:
		_l11.text = "Select a favorite chat to view"
	if _n55:
		_n55.text = "Select a favorite chat to view"
func _d68(text: String) -> String:
	var _w81 = text
	_w81 = _w81.replace("[", "\\[")
	_w81 = _w81.replace("]", "\\]")
	return _w81
func _f81():
	var _a60 = _m52 >= 0
	if _g84:
		_g84.disabled = not _a60
	if _a93:
		_a93.disabled = not _a60
	if _a32:
		_a32.disabled = not _a60
	if _k19:
		_k19.disabled = not _a60
	var _i27 = _j97 >= 0
	if _c67:
		_c67.disabled = not _i27
	if _a31:
		_a31.disabled = not _i27
	if _w35:
		_w35.disabled = not _i27
	if _c42:
		_c42.disabled = not _i27
func _d100():
	if _m52 < 0 or not _x86:
		return
	var timestamp = _d47.get_item_metadata(_m52)
	var _p42 = _x86._i66(timestamp)
	if _p42:
		_l73(_p42)
func _r24():
	if _m52 < 0 or not _x86:
		return
	var timestamp = _d47.get_item_metadata(_m52)
	if _x86._z42(timestamp):
		_d60()
func _u78():
	if _m52 < 0 or not _x86:
		return
	var timestamp = _d47.get_item_metadata(_m52)
	var _p42 = _x86._i66(timestamp)
	if _p42:
		_d13 = timestamp
		_j85 = false
		_r69.text = _p42.custom_name
		_k3.popup_centered()
func _u22():
	if _m52 < 0 or not _x86:
		return
	var timestamp = _d47.get_item_metadata(_m52)
	if _x86._v77(timestamp):
		_d60()
func _s93():
	if _j97 < 0 or not _x86:
		return
	var timestamp = _b76.get_item_metadata(_j97)
	var _p42 = _x86._i66(timestamp)
	if _p42:
		_l73(_p42)
func _a100():
	if _j97 < 0 or not _x86:
		return
	var timestamp = _b76.get_item_metadata(_j97)
	if _x86._j29(timestamp):
		_d60()
func _q83():
	if _j97 < 0 or not _x86:
		return
	var timestamp = _b76.get_item_metadata(_j97)
	var _p42 = _x86._i66(timestamp)
	if _p42:
		_d13 = timestamp
		_j85 = true
		_r69.text = _p42.custom_name
		_k3.popup_centered()
func _l74():
	if _j97 < 0 or not _x86:
		return
	var timestamp = _b76.get_item_metadata(_j97)
	if _x86._v77(timestamp):
		_d60()
func _r13():
	if not _x86 or _d13.is_empty():
		return
	var _y60 = _r69.text.strip_edges()
	if _x86._m78(_d13, _y60):
		_d60()
	_d13 = ""
	_j85 = false
func _u62():
	if not _x86:
		return
	_x86._s63()
	_x86._w10()
	_d60()
func _u7():
	if not _x86:
		return
	_x86._i85()
	_x86._w10()
	_d60()
func _w20():
	var _x24: _d25._g63 = null
	if _d47 and _d47.get_selected_items().size() > 0:
		var _z78 = _d47.get_selected_items()[0]
		var recent_chats = _x86._u93()
		if _z78 < recent_chats.size():
			_x24 = recent_chats[_z78]
	elif _b76 and _b76.get_selected_items().size() > 0:
		var _z78 = _b76.get_selected_items()[0]
		var favorite_chats = _x86._c60()
		if _z78 < favorite_chats.size():
			_x24 = favorite_chats[_z78]
	if not _x24:
		_b61("Please select a chat session to export", Color(1, 0.7, 0.3))
		return
	var filename = "gdsense_session_%s.json" % _x24.session_id
	_f41.current_file = filename
	_f41.current_path = "user://" + filename
	_f41.popup_centered()
func _m37(path: String):
	var _x24: _d25._g63 = null
	if _d47 and _d47.get_selected_items().size() > 0:
		var _z78 = _d47.get_selected_items()[0]
		var recent_chats = _x86._u93()
		if _z78 < recent_chats.size():
			_x24 = recent_chats[_z78]
	elif _b76 and _b76.get_selected_items().size() > 0:
		var _z78 = _b76.get_selected_items()[0]
		var favorite_chats = _x86._c60()
		if _z78 < favorite_chats.size():
			_x24 = favorite_chats[_z78]
	if not _x24:
		push_error("[GDSense] Failed to export: No session selected")
		return
	var _g7 = {
		"format_version": "1.0",
		"exported_at": Time.get_datetime_string_from_system(),
		"session": _x86._n23(_x24)
	}
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		var _t31 = JSON.stringify(_g7, "\t")
		file.store_string(_t31)
		file.close()
		_b61("Session exported successfully", Color(0.3, 1, 0.5))
	else:
		push_error("[GDSense] Failed to write export file: %s" % path)
		_b61("Export failed: Could not write file", Color(1, 0.3, 0.3))
func _a5():
	_o23.current_path = "user://"
	_o23.popup_centered()
func _y39(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("[GDSense] Failed to open import file: %s" % path)
		_b61("Import failed: Could not open file", Color(1, 0.3, 0.3))
		return
	var _t31 = file.get_as_text()
	file.close()
	var json = JSON.new()
	var _v55 = json.parse(_t31)
	if _v55 != OK:
		push_error("[GDSense] Failed to parse import file: %s" % json.get_error_message())
		_b61("Import failed: Invalid JSON format", Color(1, 0.3, 0.3))
		return
	var _d2 = json.data
	if not _d2 is Dictionary:
		push_error("[GDSense] Import data is not a Dictionary")
		_b61("Import failed: Invalid data structure", Color(1, 0.3, 0.3))
		return
	if not _d2.has("format_version"):
		push_error("[GDSense] Import file missing format_version")
		_b61("Import failed: Missing format version", Color(1, 0.3, 0.3))
		return
	if _d2["format_version"] != "1.0":
		push_error("[GDSense] Unsupported format version: %s" % _d2["format_version"])
		_b61("Import failed: Unsupported format version", Color(1, 0.3, 0.3))
		return
	if not _d2.has("session"):
		push_error("[GDSense] Import file missing session data")
		_b61("Import failed: Missing session data", Color(1, 0.3, 0.3))
		return
	var _o11 = _d2["session"]
	if not _o11 is Dictionary:
		push_error("[GDSense] Session data is not a Dictionary")
		_b61("Import failed: Invalid session format", Color(1, 0.3, 0.3))
		return
	var _q71 = ["exchanges", "timestamp", "session_id"]
	for _u11 in _q71:
		if not _o11.has(_u11):
			push_error("[GDSense] Session missing required field: %s" % _u11)
			_b61("Import failed: Incomplete session data", Color(1, 0.3, 0.3))
			return
	if not _o11["exchanges"] is Array:
		push_error("[GDSense] Session exchanges is not an Array")
		_b61("Import failed: Invalid exchanges format", Color(1, 0.3, 0.3))
		return
	if _o11["exchanges"].is_empty():
		push_error("[GDSense] Session has no exchanges")
		_b61("Import failed: Empty session", Color(1, 0.3, 0.3))
		return
	for _f43 in _o11["exchanges"]:
		if not _f43 is Dictionary:
			push_error("[GDSense] Invalid exchange format")
			_b61("Import failed: Invalid exchange data", Color(1, 0.3, 0.3))
			return
		if not _f43.has("user_message") or not _f43.has("ai_response"):
			push_error("[GDSense] Exchange missing user_message or ai_response")
			_b61("Import failed: Incomplete exchange", Color(1, 0.3, 0.3))
			return
		if _f43["user_message"].length() > 100000 or _f43["ai_response"].length() > 500000:
			push_error("[GDSense] Exchange messages too long (possible attack)")
			_b61("Import failed: Messages exceed size limits", Color(1, 0.3, 0.3))
			return
		if _f43.has("enhanced_user_message") and _f43["enhanced_user_message"].length() > 200000:
			push_error("[GDSense] Enhanced message too long (possible attack)")
			_b61("Import failed: Messages exceed size limits", Color(1, 0.3, 0.3))
			return
	var _i33 = _x86._i66(_o11["timestamp"])
	if _i33:
		_b61("Warning: Session may already exist", Color(1, 0.7, 0.3))
	var _a87 = _x86._y29(_o11)
	if not _a87:
		push_error("[GDSense] Failed to convert imported data to ChatEntry")
		_b61("Import failed: Could not create session", Color(1, 0.3, 0.3))
		return
	_x86._b58.push_front(_a87)
	while _x86._b58.size() > _d25._w16:
		_x86._b58.pop_back()
	_x86._w10()
	_d60()
	_b61("Session imported successfully (%d exchanges)" % _a87._c53(), Color(0.3, 1, 0.5))
func _b61(message: String, color: Color):
	if color.r > color.g and color.r > color.b:
		pass
	else:
		pass
func _c50(message: String) -> String:
	var _o28 = _d25._g63._u46(message)
	if _o28 != message and OS.is_debug_build():
		pass
	return _o28
func _l73(_p42: _d25._g63):
	if not _p42:
		return
	_d83.clear()
	_m67()
	for _h61 in _v1.get_children():
		_h61.queue_free()
	var _i98 = _p42._k67()
	var _d50 = _p42._v35()
	_g11 = _i98 if _i98 else {}
	if _d50 and not _d50.is_empty():
		_w68 = _d50
	else:
		_w68.clear()  
	_i61()
	for _f43 in _p42.exchanges:
		if not _f43 is Dictionary:
			continue
		if not _f43.has("user_message") or not _f43.has("ai_response"):
			continue
		var _t47 = _c50(_f43["user_message"])
		if _t47.begins_with("@explain"):
			var _r53 = _t47.find("\n")
			if _r53 != -1:
				_t47 = _t47.substr(0, _r53) + " (code attached)"
		_b43(_t47)
		_d18(_f43["ai_response"], [])
		var _k63 = _f43.get("enhanced_user_message", _f43["user_message"])
		var _f47 = _c50(_f43["user_message"])
		_d83.append({"role": "user", "content": _k63, "original_content": _f47})
		var _n51 = {"role": "agent", "content": _f43["ai_response"]}
		if _f43.has("thought_signature") and not _f43["thought_signature"].is_empty():
			_n51["thought_signature"] = _f43["thought_signature"]
		_d83.append(_n51)
	if _y23:
		_y23.current_tab = 0
	_g77.call_deferred()
func _q13():
	var _p61 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	var _w34 = func(_y6: Node):
		if not _y6: return
		for _h61 in _y6.get_children():
			if _h61 is Label:
				if "Full Conversation" in _h61.text or "Session Info" in _h61.text:
					_h61.add_theme_color_override("font_color", _p61)
	if _j64:
		_w34.call(_j64.get_parent())
	if _l11:
		_w34.call(_l11.get_parent())
func _p57():
	_d56()
	_q13()
	_y48()
	if _x86:
		if _m52 >= 0:
			_o66(_m52)
		if _j97 >= 0:
			_m84(_j97)
func _y48():
	var _q1 = get_node_or_null("MarginContainer/TabContainer/Settings/_o99/VBoxContainer")
	if not _q1: return
	var _u92 = get_theme_color("font_color", "Label") if has_theme_color("font_color", "Label") else get_theme_color("font_color", "Editor")
	var _d9 = Color(_u92, 0.6)
	var _n62 = func(node: Node, _t91: Callable):
		if node is Label:
			if node.has_meta("secondary"):
				node.add_theme_color_override("font_color", _d9)
			else:
				node.add_theme_color_override("font_color", _u92)
		for _h61 in node.get_children():
			_t91.call(_h61, _t91)
	_n62.call(_q1, _n62)
func _e44() -> void:
	_t68 = _i29.new()
	_t68.initialize(self, _f78)
	_t68._f56.connect(_z45)
	_t68._m28.connect(_f86)
	_t68._p31.connect(_h66)
	_t68._w3.connect(_r25)
	_t68._q47.connect(_i18)
	_t68._n32.connect(_v26)
	_t68._y89.connect(_f14)
	_t68._x100.connect(_z6)
	_v17 = _t27.new()
	_v17.initialize(_d84)
	_l81()
func _l81() -> void:
	_d97 = VBoxContainer.new()
	_d97.name = "AgentUIContainer"
	_d97.visible = false
	_d97.add_theme_constant_override("separation", 4)
	_t100 = Label.new()
	_t100.text = "Agent: Initializing..."
	_t100.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d97.add_child(_t100)
	_r4 = ProgressBar.new()
	_r4.min_value = 0
	_r4.max_value = 100
	_r4.value = 0
	_r4.show_percentage = false
	_r4.custom_minimum_size = Vector2(0, 8)
	_d97.add_child(_r4)
	var _v28 = get_node_or_null("MarginContainer/TabContainer/Chat")
	if _v28:
		var _z16 = _v28.get_child(0) if _v28.get_child_count() > 0 else null
		if _z16 and _z16 is VBoxContainer:
			var _p50 = -1
			for i in range(_z16.get_child_count()):
				var _h61 = _z16.get_child(i)
				if _h61.name == "InputContainer" or (_h61 is HBoxContainer and _h61.get_node_or_null("_b41") != null):
					_p50 = i
					break
			if _p50 >= 0:
				_z16.add_child(_d97)
				_z16.move_child(_d97, _p50)
			else:
				_z16.add_child(_d97)
		else:
			add_child(_d97)
	else:
		add_child(_d97)
func _m62() -> void:
	_d29 = true
	if _u42 and _u42.item_count > _y69 and _u42.selected != _y69:
		_u42.selected = _y69
	if _k54:
		_k54.visible = false
	if _n38:
		_n38.visible = false
	if _c65:
		_c65.visible = true
	_i91.placeholder_text = "[Agent Mode] Describe your task..."
	_s85("Agent mode enabled. Describe your task and press Enter to start.")
func _u19() -> void:
	_d29 = false
	_s98.clear()
	_x9 = false
func _o86() -> void:
	if _d97:
		_d97.visible = true
	if _r4:
		_r4.value = 0
	if _t100:
		_t100.text = "Agent: Starting..."
	_h69()
func _t2() -> void:
	if _d97:
		_d97.visible = false
func _h69() -> void:
	_o90()  
	_l95 = HBoxContainer.new()
	_l95.name = "AgentCancelContainer"
	_l95.alignment = BoxContainer.ALIGNMENT_CENTER
	_d80 = Button.new()
	_d80.text = "Cancel Agent"
	_d80.pressed.connect(_y92)
	_l95.add_child(_d80)
	var _v28 = get_node_or_null("MarginContainer/TabContainer/Chat")
	if _v28:
		var _z16 = _v28.get_child(0) if _v28.get_child_count() > 0 else null
		if _z16 and _z16 is VBoxContainer:
			var _p50 = -1
			for i in range(_z16.get_child_count()):
				var _h61 = _z16.get_child(i)
				if _h61.name == "InputContainer" or (_h61 is HBoxContainer and _h61.get_node_or_null("_b41") != null):
					_p50 = i
					break
			if _p50 >= 0:
				_z16.add_child(_l95)
				_z16.move_child(_l95, _p50)
			else:
				_z16.add_child(_l95)
		else:
			add_child(_l95)
	else:
		add_child(_l95)
func _o90() -> void:
	if _l95 and is_instance_valid(_l95):
		_l95.queue_free()
		_l95 = null
		_d80 = null
func _w5() -> void:
	_n6()  
	_a43 = HBoxContainer.new()
	_a43.name = "AgentForceResetContainer"
	_a43.alignment = BoxContainer.ALIGNMENT_CENTER
	_a43.add_theme_constant_override("separation", 8)
	var _y73 = Button.new()
	_y73.text = "Reset Agent"
	_y73.tooltip_text = "Force reset all agent state and start fresh"
	_y73.pressed.connect(_b45)
	_a43.add_child(_y73)
	var _v28 = get_node_or_null("MarginContainer/TabContainer/Chat")
	if _v28:
		var _z16 = _v28.get_child(0) if _v28.get_child_count() > 0 else null
		if _z16 and _z16 is VBoxContainer:
			var _p50 = -1
			for i in range(_z16.get_child_count()):
				var _h61 = _z16.get_child(i)
				if _h61.name == "InputContainer" or (_h61 is HBoxContainer and _h61.get_node_or_null("_b41") != null):
					_p50 = i
					break
			if _p50 >= 0:
				_z16.add_child(_a43)
				_z16.move_child(_a43, _p50)
			else:
				_z16.add_child(_a43)
		else:
			add_child(_a43)
	else:
		add_child(_a43)
func _n6() -> void:
	if _a43 and is_instance_valid(_a43):
		_a43.queue_free()
		_a43 = null
func _b45() -> void:
	if _t68 and _t68.is_active():
		_t68._o16()
	_t2()
	_o90()
	_i70()
	_n6()
	_u19()
	_o20()
	_s98.clear()
	_x9 = false
	_s85("Agent state reset. You can start a new task.", false)
func _s85(text: String, _y11: bool = false) -> void:
	var _g55 = PanelContainer.new()
	_g55.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_g55.add_theme_constant_override("margin_bottom", _c34.message_gap)
	if not _v64:
		_d56()
	_g55.add_theme_stylebox_override("panel", _v64)
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.selection_enabled = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.fit_content = true
	label.scroll_active = false
	label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var _x4 = Color.RED if _y11 else _w99
	label.add_theme_color_override("default_color", _x4)
	label.text = "[b][Agent][/b] " + _d68(text)
	_g55.add_child(label)
	_v1.add_child(_g55)
	_g77.call_deferred()
func _c74(_e67: String, details: Array, _y11: bool = false) -> void:
	var _g55 = PanelContainer.new()
	_g55.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_g55.add_theme_constant_override("margin_bottom", _c34.message_gap)
	if not _v64:
		_d56()
	_g55.add_theme_stylebox_override("panel", _v64)
	var _z16 = VBoxContainer.new()
	_z16.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _q72 = HBoxContainer.new()
	_q72.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _s14 = Button.new()
	_s14.flat = true
	_s14.text = "▶"  
	_s14.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_s14.tooltip_text = "Click to expand/collapse"
	_x39(_s14)
	_q72.add_child(_s14)
	var _q43 = RichTextLabel.new()
	_q43.bbcode_enabled = true
	_q43.selection_enabled = true
	_q43.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_q43.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_q43.fit_content = true
	_q43.scroll_active = false
	_q43.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var _x4 = Color.RED if _y11 else _w99
	_q43.add_theme_color_override("default_color", _x4)
	_q43.text = "[b][Agent][/b] " + _d68(_e67)
	_q72.add_child(_q43)
	_z16.add_child(_q72)
	var _h57 = VBoxContainer.new()
	_h57.visible = false
	_h57.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_h57.add_theme_constant_override("separation", 4)
	var _z2 = MarginContainer.new()
	var indent_size = _b8() * 2  
	_z2.add_theme_constant_override("margin_left", indent_size)
	_z2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _w88 = VBoxContainer.new()
	_w88.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for _v92 in details:
		var _l87 = Label.new()
		_l87.text = _v92
		_l87.add_theme_color_override("font_color", _x4.darkened(0.15))
		_x39(_l87)
		_w88.add_child(_l87)
	_z2.add_child(_w88)
	_h57.add_child(_z2)
	_z16.add_child(_h57)
	_s14.pressed.connect(func():
		_h57.visible = not _h57.visible
		_s14.text = "▼" if _h57.visible else "▶"
		_g77.call_deferred()
	)
	_g55.add_child(_z16)
	_v1.add_child(_g55)
	_g77.call_deferred()
func _x39(_x76: Control) -> void:
	if _k9:
		var _d84 = _k9.get_editor_interface()
		if _d84:
			var theme = _d84.get_editor_theme()
			if theme:
				var _s54 = theme.get_font("main", "EditorFonts")
				if _s54:
					_x76.add_theme_font_override("font", _s54)
				var _e31 = theme.get_font_size("main_size", "EditorFonts")
				if _e31 > 0:
					_x76.add_theme_font_size_override("font_size", _e31)
func _b8() -> int:
	if _k9:
		var _d84 = _k9.get_editor_interface()
		if _d84:
			var theme = _d84.get_editor_theme()
			if theme:
				var _e31 = theme.get_font_size("main_size", "EditorFonts")
				if _e31 > 0:
					return _e31
	return 14  
func _z45(session_id: String) -> void:
	_s85("Agent session started. Analyzing your request...")
func _f86(status: Dictionary) -> void:
	var progress = status.get("progress_percent", 0)
	var _b96 = status.get("status_message", "Processing...")
	if _b96 == null:
		_b96 = "Processing..."
	if _r4:
		_r4.value = progress
	if _t100:
		_t100.text = "Agent: " + _b96
	if status.has("tier"):
		var _p53 = status.get("tier", "")
		if _p53 is String and not _p53.is_empty() and _f78:
			_f78._e3(_p53)
func _h66(_j5: Array) -> void:
	if _j5.is_empty():
		return
	var _n27: Array = []
	var _d39: Array = []
	for _t3 in _j5:
		var _c79 = _t3.get("tool_name", "")
		var _z5 = _v17._z5(_c79)
		if _z5:
			_d39.append(_t3)
		else:
			_n27.append(_t3)
	for _t3 in _n27:
		var _c79 = _t3.get("tool_name", "")
		var _n3 = _t3.get("tool_call_id", "")
		var _e52 = _t3.get("parameters", {})
		if _e52 == null:
			_e52 = {}
		var _x97 = _v17._r48(_c79, _e52)
		_t68._e59(_n3, true, _x97)
		_a82(_c79, _e52, _x97)
	for _t3 in _d39:
		_s98.append(_t3)
	if not _x9 and _s98.size() > 0:
		_z12()
func _z12() -> void:
	if _s98.is_empty():
		_x9 = false
		return
	_x9 = true
	var _t3 = _s98.pop_front()
	var _c79 = _t3.get("tool_name", "")
	var _n3 = _t3.get("tool_call_id", "")
	var _x26 = _p74.new()
	_x26._i71(_d84)
	_x26._z41(_t3)
	_x26._d45.connect(_i17.bind(_n3))
	_x26._n39.connect(_y79.bind(_n3))
	add_child(_x26)
	_x26.popup_centered()
func _i17(_t3: Dictionary, _b93: Dictionary, _n3: String) -> void:
	var _c79 = _t3.get("tool_name", "")
	if _c79 == null:
		_c79 = ""
	var _e52 = _t3.get("parameters", {})
	if _e52 == null:
		_e52 = {}
	var _x97 = _v17._r48(_c79, _e52)
	_t68._e59(_n3, true, _x97)
	_a82(_c79, _e52, _x97)
	_z12()
func _y79(_t3: Dictionary, _m26: String, _n3: String) -> void:
	var _c79 = _t3.get("tool_name", "")
	if _c79 == null:
		_c79 = ""
	var _e52 = _t3.get("parameters", {})
	if _e52 == null:
		_e52 = {}
	_t68._e59(_n3, false, {}, _m26)
	var path = _e52.get("path", "")
	if path == null:
		path = ""
	if not path.is_empty():
		_s85("Rejected " + _c79 + ": " + path)
	else:
		_s85("Rejected: " + _c79)
	_z12()
func _r25(message: String) -> void:
	_d18(message, [])
	_s85("Tip: Reopen modified scenes or reload the project to see changes")
	_t2()
	_o90()  
	_i70()
	_n6()  
	_u19()
	_o20()
func _i18(error: String) -> void:
	_s85("Agent failed: " + error, true)
	_t2()
	_w5()
	_i70()
func _v26() -> void:
	_s85("Agent cancelled")
	_t2()
	_o90()  
	_i70()
	_n6()  
	_u19()
	_o20()
func _f14(session_id: String, message: String) -> void:
	var _j16 = message + " You can continue to allow more processing."
	_s85(_j16, true)
	_q11()
	_t2()
	_o90()  
func _z6(message: String, _r80: String) -> void:
	if message.is_empty() and _r80.is_empty():
		return
	if not message.is_empty():
		_d18(message, [])
	if not _r80.is_empty():
		_o97(_r80)
func _o97(_r80: String) -> void:
	var _g55 = PanelContainer.new()
	_g55.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_g55.add_theme_constant_override("margin_bottom", _c34.message_gap)
	if not _v64:
		_d56()
	_g55.add_theme_stylebox_override("panel", _v64)
	var _z16 = VBoxContainer.new()
	_z16.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _q72 = HBoxContainer.new()
	_q72.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _s14 = Button.new()
	_s14.flat = true
	_s14.text = ">"  
	_s14.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_s14.tooltip_text = "Click to expand/collapse reasoning"
	_x39(_s14)
	_q72.add_child(_s14)
	var _q43 = RichTextLabel.new()
	_q43.bbcode_enabled = true
	_q43.selection_enabled = true
	_q43.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_q43.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_q43.fit_content = true
	_q43.scroll_active = false
	_q43.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var _r96 = _w99.darkened(0.2)
	_q43.add_theme_color_override("default_color", _r96)
	_q43.text = "[i]View reasoning[/i]"
	_q72.add_child(_q43)
	_z16.add_child(_q72)
	var _h57 = VBoxContainer.new()
	_h57.visible = false
	_h57.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_h57.add_theme_constant_override("separation", 4)
	var _z2 = MarginContainer.new()
	var indent_size = _b8() * 2  
	_z2.add_theme_constant_override("margin_left", indent_size)
	_z2.add_theme_constant_override("margin_top", 4)
	_z2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _h72 = RichTextLabel.new()
	_h72.bbcode_enabled = true
	_h72.selection_enabled = true
	_h72.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_h72.fit_content = true
	_h72.scroll_active = false
	_h72.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_h72.add_theme_color_override("default_color", _r96)
	_h72.text = _d68(_r80)
	_z2.add_child(_h72)
	_h57.add_child(_z2)
	_z16.add_child(_h57)
	_s14.pressed.connect(func():
		_h57.visible = not _h57.visible
		_s14.text = "v" if _h57.visible else ">"
		_g77.call_deferred()
	)
	_g55.add_child(_z16)
	_v1.add_child(_g55)
	_g77.call_deferred()
func _q11() -> void:
	_i70()  
	_s97 = HBoxContainer.new()
	_s97.name = "AgentContinueContainer"
	_s97.alignment = BoxContainer.ALIGNMENT_CENTER
	_s97.add_theme_constant_override("separation", 8)
	var _x29 = Button.new()
	_x29.text = "Continue Session"
	_x29.pressed.connect(_h37)
	_s97.add_child(_x29)
	var _b92 = Button.new()
	_b92.text = "Start New Task"
	_b92.pressed.connect(_b1)
	_s97.add_child(_b92)
	var _v28 = get_node_or_null("MarginContainer/TabContainer/Chat")
	if _v28:
		var _z16 = _v28.get_child(0) if _v28.get_child_count() > 0 else null
		if _z16 and _z16 is VBoxContainer:
			var _p50 = -1
			for i in range(_z16.get_child_count()):
				var _h61 = _z16.get_child(i)
				if _h61.name == "InputContainer" or (_h61 is HBoxContainer and _h61.get_node_or_null("_b41") != null):
					_p50 = i
					break
			if _p50 >= 0:
				_z16.add_child(_s97)
				_z16.move_child(_s97, _p50)
			else:
				_z16.add_child(_s97)
		else:
			add_child(_s97)
	else:
		add_child(_s97)
func _h37() -> void:
	_i70()
	_o86()
	if _t68:
		_t68._r70()
func _b1() -> void:
	_i70()
	_n6()  
	if _t68:
		_t68._a51()
	_u19()
	_o20()
func _i70() -> void:
	if _s97 and is_instance_valid(_s97):
		_s97.queue_free()
		_s97 = null
func _y92() -> void:
	if _t68 and _t68.is_active():
		_t68._o16()
func _c38(_c79: String, _e52: Dictionary, _x97: Dictionary) -> Dictionary:
	var success = _x97.get("success", false)
	var _n43 = "✓ " if success else "✗ "
	var details: Array = []
	match _c79:
		"read_file":
			var path = _e52.get("path", "unknown")
			if success:
				var content = _x97.get("content", "")
				var _k66 = content.count("\n") + 1 if not content.is_empty() else 0
				return {"summary": _n43 + "Read file: " + path + " (" + str(_k66) + " lines)", "details": [], "is_error": false}
			else:
				return {"summary": _n43 + "Failed to read: " + path, "details": [], "is_error": true}
		"list_files":
			var path = _e52.get("path", "res://")
			if success:
				var _w56 = _x97.get("files", [])
				var _c76 = _x97.get("directories", [])
				var _v58 = _w56.size() if _w56 is Array else 0
				var _h46 = _c76.size() if _c76 is Array else 0
				for _b49 in _c76:
					details.append("📁 " + str(_b49) + "/")
				for _f63 in _w56:
					details.append("📄 " + str(_f63))
				return {"summary": _n43 + "Listed " + path + " (" + str(_v58) + " files, " + str(_h46) + " dirs)", "details": details, "is_error": false}
			else:
				return {"summary": _n43 + "Failed to list: " + path, "details": [], "is_error": true}
		"get_project_info":
			if success:
				var _a55 = _x97.get("project_name", "Unknown")
				var _w12 = _x97.get("godot_version", "")
				details.append("Project: " + str(_a55))
				details.append("Godot: " + str(_w12))
				if _x97.has("main_scene"):
					details.append("Main Scene: " + str(_x97.get("main_scene")))
				return {"summary": _n43 + "Project: " + _a55 + " (Godot " + _w12 + ")", "details": details, "is_error": false}
			else:
				return {"summary": _n43 + "Failed to get project info", "details": [], "is_error": true}
		"run_project":
			if success:
				return {"summary": _n43 + "Running project in debug mode", "details": [], "is_error": false}
			else:
				return {"summary": _n43 + "Failed to run project", "details": [], "is_error": true}
		"stop_project":
			if success:
				return {"summary": _n43 + "Stopped project", "details": [], "is_error": false}
			else:
				return {"summary": _n43 + "Failed to stop project", "details": [], "is_error": true}
		"create_file":
			var path = _e52.get("path", "unknown")
			if success:
				return {"summary": _n43 + "Created: " + path, "details": [], "is_error": false}
			else:
				var _q22 = _x97.get("error", "Unknown error")
				return {"summary": _n43 + "Failed to create " + path + ": " + _q22, "details": [], "is_error": true}
		"edit_file":
			var path = _e52.get("path", "unknown")
			if success:
				return {"summary": _n43 + "Modified: " + path, "details": [], "is_error": false}
			else:
				var _q22 = _x97.get("error", "Unknown error")
				return {"summary": _n43 + "Failed to edit " + path + ": " + _q22, "details": [], "is_error": true}
		"delete_file":
			var path = _e52.get("path", "unknown")
			if success:
				return {"summary": _n43 + "Deleted: " + path, "details": [], "is_error": false}
			else:
				var _q22 = _x97.get("error", "Unknown error")
				return {"summary": _n43 + "Failed to delete " + path + ": " + _q22, "details": [], "is_error": true}
		_:
			if success:
				return {"summary": _n43 + "Executed: " + _c79, "details": [], "is_error": false}
			else:
				return {"summary": _n43 + "Failed: " + _c79, "details": [], "is_error": true}
func _a82(_c79: String, _e52: Dictionary, _x97: Dictionary) -> void:
	var status = _c38(_c79, _e52, _x97)
	var _e67 = status.get("summary", "")
	var details = status.get("details", [])
	var _y11 = status.get("is_error", false)
	if details.size() > 0:
		_c74(_e67, details, _y11)
	else:
		_s85(_e67, _y11)
