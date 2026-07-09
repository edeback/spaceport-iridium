@tool
class_name _j98
extends AcceptDialog

signal _u46(refactored_code: String, function_name: String)
signal _h79(function_name: String)
signal _e92(data: Dictionary)

const _b75 = 5000
const _v55 = 10000
const _m2 = 1048576  
const _k50 = 100

var _r59: String
var _p85: String
var _k54: String
var _g17: String
var _o64: String
var _r90: Control
var _k58: Button
var _q37: Button
var _k78: Button
var _k38: bool = true
var _h45: Label

enum _e77 {
	_w63,
	_n32
}
var _j93: _e77

var _a60: float = 1.0
var _a31: float = 1.0  
var _d84: int = 16  

var _w56: ScrollContainer
var _p43: ScrollContainer
var _s25: VBoxContainer
var _a17: VBoxContainer
var _v18: VBoxContainer

var _l68 = {
	"comment": Color.GRAY,
	"string": Color.ORANGE,
	"number": Color.SKY_BLUE,
	"keyword": Color.PALE_VIOLET_RED,
	"class": Color.LIGHT_GREEN,
	"function": Color.LIGHT_BLUE,
	"symbol": Color.WHITE,
	"added": Color(0.2, 0.7, 0.2),
	"removed": Color(0.8, 0.2, 0.2),
	"added_bg": Color(0.0, 0.5, 0.0, 0.2),
	"removed_bg": Color(0.5, 0.0, 0.0, 0.2),
	"modified_bg": Color(0.5, 0.5, 0.0, 0.15)
}

func _w99() -> Color:
	if has_theme_color("font_color", "Editor"):
		return get_theme_color("font_color", "Editor")
	return Color(0.7, 0.7, 0.7)  

func _h4() -> Color:
	if has_theme_color("font_color", "Editor"):
		var font_color = get_theme_color("font_color", "Editor")

		return Color(font_color.r * 0.6, font_color.g * 0.6, font_color.b * 0.6, font_color.a)
	return Color(0.5, 0.5, 0.5)  

func _n84() -> Color:
	if has_theme_color("base_color", "Editor"):
		var _d91 = get_theme_color("base_color", "Editor")
		return Color(_d91.r, _d91.g, _d91.b, 0.3)
	return Color(0.15, 0.15, 0.15, 0.3)  

func _p17():
	var _m31 = get_theme_color("base_color", "Editor") if has_theme_color("base_color", "Editor") else Color(0.2, 0.2, 0.2)
	var _o90 = _m31.get_luminance() > 0.5

	if _o90:
		_l68["comment"] = Color(0.4, 0.5, 0.4)  
		_l68["string"] = Color(0.6, 0.3, 0.1)   
		_l68["number"] = Color(0.1, 0.3, 0.6)   
		_l68["keyword"] = Color(0.6, 0.1, 0.4)  
		_l68["class"] = Color(0.1, 0.5, 0.2)    
		_l68["function"] = Color(0.1, 0.3, 0.6) 
		_l68["symbol"] = Color(0.2, 0.2, 0.2)   
	else:
		_l68["comment"] = Color.GRAY
		_l68["string"] = Color.ORANGE
		_l68["number"] = Color.SKY_BLUE
		_l68["keyword"] = Color.PALE_VIOLET_RED
		_l68["class"] = Color.LIGHT_GREEN
		_l68["function"] = Color.LIGHT_BLUE
		_l68["symbol"] = Color.WHITE

const _b45 = [
	"if", "elif", "else", "for", "while", "match", "break", "continue", "pass",
	"return", "class", "extends", "is", "as", "self", "super", "func", "signal",
	"const", "var", "static", "enum", "in", "not", "and", "or", "true", "false",
	"null", "export", "onready", "tool", "setget", "breakpoint", "preload", "yield",
	"assert", "remote", "sync", "master", "puppet", "@export", "@onready", "@tool"
]

var _z8: RegEx
var _r92: RegEx
var _i88: RegEx
var _t57: RegEx
var _c60: RegEx

func _init():
	_k4()

func _k4():
	_z8 = RegEx.new()
	if _z8.compile("#.*$") != OK:
		push_error("Failed to compile comment regex")
		_z8 = null
	
	_r92 = RegEx.new()
	if _r92.compile("(\"[^\"]*\"|'[^']*')") != OK:
		push_error("Failed to compile string regex")
		_r92 = null
	
	_i88 = RegEx.new()
	var _d96 = "\\b(" + "|".join(_b45) + ")\\b"
	if _i88.compile(_d96) != OK:
		push_error("Failed to compile keyword regex")
		_i88 = null
	
	_t57 = RegEx.new()
	if _t57.compile("\\b\\d+(\\.\\d+)?\\b") != OK:
		push_error("Failed to compile number regex")
		_t57 = null
	
	_c60 = RegEx.new()
	if _c60.compile("\\b([a-z_][a-zA-Z0-9_]*)\\s*\\(") != OK:
		push_error("Failed to compile function regex")
		_c60 = null

func _ready():
	get_ok_button().hide()

	_s54()

	_p17()

	if not confirmed.is_connected(_i42):
		confirmed.connect(_i42)

	_x97()
	_e42()

	_n41()

	_w92.call_deferred()

func _s54():
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		var _v66 = config.get_value("font_scale", "mode", "auto")
		if _v66 == "auto":
			var _a77 = DisplayServer.screen_get_size()
			var _u14 = _a77.y
			if _u14 >= 2160:  
				_a31 = 1.5
			elif _u14 >= 1440:  
				_a31 = 1.25
			else:  
				_a31 = 1.0
		else:
			_a31 = float(_v66)
	else:
		_a31 = 1.0

func _x97():
	if not is_inside_tree():
		return
	
	_k78 = %_d79
	_h45 = %_d58  
	_r90 = %_d5
	_k58 = %_a88
	_q37 = %_b48
	
	_w56 = %_u29
	_p43 = %_u78
	_s25 = %_j55
	_a17 = %_i48
	_v18 = %_q35
	
	if _k78 and not _k78.pressed.is_connected(_p61):
		_k78.pressed.connect(_p61)
	if _k58 and not _k58.pressed.is_connected(_i42):
		_k58.pressed.connect(_i42)
	if _q37 and not _q37.pressed.is_connected(_b51):
		_q37.pressed.connect(_b51)
	
	if _w56 and _p43:
		var _w96 = _w56.get_v_scroll_bar()
		var _e68 = _p43.get_v_scroll_bar()
		if not _w96.value_changed.is_connected(_e97):
			_w96.value_changed.connect(_e97)
		if not _e68.value_changed.is_connected(_i16):
			_e68.value_changed.connect(_i16)
	
func _e42():
	_k38 = true
	_j93 = _e77._w63

func _e85():
	if _s25 and _a17 and _v18:
		if is_instance_valid(_s25) and is_instance_valid(_a17) and is_instance_valid(_v18):
			return
	
	_s25 = %_j55
	_a17 = %_i48
	_v18 = %_q35
	_w56 = %_u29
	_p43 = %_u78
	
	if not _s25 or not _a17 or not _v18:
		pass
func _s31(function_name: String, original_code: String, refactored_code: String, file_path: String = "", prompt: String = ""):
	var _e69 = original_code.length() + refactored_code.length()
	if _e69 > _m2:
		push_error("Total input size exceeds maximum allowed size of %d bytes" % _m2)
		return
	
	if original_code.length() > _v55 * _b75:
		push_error("Original code exceeds maximum allowed size")
		return
	if refactored_code.length() > _v55 * _b75:
		push_error("Refactored code exceeds maximum allowed size")
		return
	
	var _m34 = original_code.split("\n")
	var _m67 = refactored_code.split("\n")
	
	if _m34.size() > _b75 or _m67.size() > _b75:
		push_error("Code exceeds maximum line limit of %d" % _b75)
		return
	
	_k54 = function_name
	_r59 = original_code
	_p85 = refactored_code
	_g17 = file_path
	_o64 = prompt
	
	if not is_inside_tree():
		var _i86 = Engine.get_singleton("EditorInterface")
		if _i86:
			var _h71 = _i86.get_base_control()
			if _h71:
				_h71.add_child(self)
			else:
				pass

	_h51.call_deferred()

func _x59():
	if not _k78:
		_x97()
		_e85()

func _h51():
	if not is_inside_tree():
		return

	_s54()
	_p17()
	_n41()

	popup_centered()

	if not is_inside_tree():
		return
	await get_tree().process_frame

	if not is_inside_tree():
		return

	_w92()

	_x59()

	if _h45:
		_h45.text = "Function: %s" % _k54
	else:
		pass

	_a81()

func _a81():
	if not _s25 or not _a17 or not _v18:
		return
		
	if _r59.is_empty() or _p85.is_empty():
		return
	
	if _k38:
		_o30()
	else:
		_b88()

func _b7(_m34: PackedStringArray, _m67: PackedStringArray) -> Array:
	var _q82 = []
	var _z21 = 0
	var _b5 = 0
	
	while _z21 < _m34.size() or _b5 < _m67.size():
		if _z21 >= _m34.size():
			_q82.append({
				"type": "added", 
				"line": _m67[_b5],
				"original_line_num": -1,
				"refactored_line_num": _b5 + 1
			})
			_b5 += 1
		elif _b5 >= _m67.size():
			_q82.append({
				"type": "removed", 
				"line": _m34[_z21],
				"original_line_num": _z21 + 1,
				"refactored_line_num": -1
			})
			_z21 += 1
		elif _m34[_z21] == _m67[_b5]:
			_q82.append({
				"type": "context", 
				"line": _m34[_z21],
				"original_line_num": _z21 + 1,
				"refactored_line_num": _b5 + 1
			})
			_z21 += 1
			_b5 += 1
		else:
			_q82.append({
				"type": "removed", 
				"line": _m34[_z21],
				"original_line_num": _z21 + 1,
				"refactored_line_num": -1
			})
			_q82.append({
				"type": "added", 
				"line": _m67[_b5],
				"original_line_num": -1,
				"refactored_line_num": _b5 + 1
			})
			_z21 += 1
			_b5 += 1
	
	return _q82

func _l48(_e30: Dictionary, _m88: VBoxContainer):
	var _w53 = PanelContainer.new()
	_w53.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var _z9 = StyleBoxFlat.new()
	var prefix = ""
	var _u18 = _w99()

	match _e30.type:
		"added":
			_z9.bg_color = _l68.added_bg
			prefix = "+ "
			_u18 = _l68.added
		"removed":
			_z9.bg_color = _l68.removed_bg
			prefix = "- "
			_u18 = _l68.removed
		"context":
			_z9.bg_color = _n84()
			prefix = "  "
			_u18 = _w99()

	_z9.content_margin_left = 8
	_z9.content_margin_right = 8
	_z9.content_margin_top = 2
	_z9.content_margin_bottom = 2
	_w53.add_theme_stylebox_override("panel", _z9)

	var _w23 = HBoxContainer.new()

	var _d65 = Label.new()
	var _o46 = ""
	if _e30.original_line_num > 0 and _e30.refactored_line_num > 0:
		_o46 = "%d:%d" % [_e30.original_line_num, _e30.refactored_line_num]
	elif _e30.original_line_num > 0:
		_o46 = "%d:-" % _e30.original_line_num
	else:
		_o46 = "-:%d" % _e30.refactored_line_num

	_d65.text = _o46
	_d65.custom_minimum_size = Vector2(80, 0)
	_d65.add_theme_color_override("font_color", _h4())
	_d65.add_theme_font_size_override("font_size", _n36(_d84 - 2))
	var _o61 = SystemFont.new()
	_o61.font_names = ["Consolas", "Courier New", "Monospace"]
	_d65.add_theme_font_override("font", _o61)
	_w23.add_child(_d65)
	
	var _c68 = RichTextLabel.new()
	_c68.bbcode_enabled = true
	_c68.selection_enabled = true
	_c68.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_c68.size_flags_vertical = Control.SIZE_EXPAND_FILL  
	_c68.fit_content = false  
	_c68.scroll_active = true  
	_c68.autowrap_mode = TextServer.AUTOWRAP_OFF  
	_c68.custom_minimum_size = Vector2(400, int(32 * _a60))  
	
	var _z53 = _d35(_e30.line)
	_c68.text = prefix + _z53
	
	_c68.add_theme_font_override("normal_font", _o61)
	_c68.add_theme_font_override("mono_font", _o61)
	_c68.add_theme_color_override("default_color", _u18)
	_c68.add_theme_font_size_override("normal_font_size", _n36(_d84))
	
	_w23.add_child(_c68)
	_w53.add_child(_w23)
	
	_w53.custom_minimum_size = Vector2(0, int(36 * _a60))  
	_w53.size_flags_vertical = Control.SIZE_EXPAND_FILL  
	
	_m88.add_child(_w53)
	
	_l39(_c68)
	
	if _w53.is_inside_tree():
		_w53.queue_redraw()

func _o30():
	_e85()
	
	_j68()
	
	var _j87 = %_o54
	var _s91 = %_h52
	
	if _j87:
		_j87.visible = true
	if _s91:
		_s91.visible = false
	
	if not _s25 or not _a17:
		return
	
	if not is_instance_valid(_s25) or not is_instance_valid(_a17):
		return
	
	var _m34 = _r59.split("\n")
	var _m67 = _p85.split("\n")
	
	if _m34.size() > _b75:
		_m34.resize(_b75)
	if _m67.size() > _b75:
		_m67.resize(_b75)
	
	var _m69 = max(_m34.size(), _m67.size())
	
	for i in range(_m69):
		var _i19 = _m34[i] if i < _m34.size() else ""
		var _q73 = _m67[i] if i < _m67.size() else ""
		
		var _s35 = "context"
		var _e65 = "context"
		
		if i >= _m34.size():
			_s35 = "empty"
			_e65 = "added"
		elif i >= _m67.size():
			_s35 = "removed" 
			_e65 = "empty"
		elif _i19 != _q73:
			_s35 = "removed"
			_e65 = "added"
		
		if _s25 and _a17:
			_c76(_i19, i + 1, _s35, _s25, true)
			_c76(_q73, i + 1, _e65, _a17, false)
		else:
			return
	
	if is_inside_tree():
		if _w56 and is_instance_valid(_w56):
			_w56.queue_redraw()
			_w56.notification(Control.NOTIFICATION_RESIZED)

			_w56.queue_sort()
		if _p43 and is_instance_valid(_p43):
			_p43.queue_redraw()
			_p43.notification(Control.NOTIFICATION_RESIZED)

			_p43.queue_sort()

		if _s25 and is_instance_valid(_s25):
			_s25.queue_redraw()
			_s25.queue_sort()
		if _a17 and is_instance_valid(_a17):
			_a17.queue_redraw()
			_a17.queue_sort()
		
func _b88():
	_e85()
	
	_j68()
	
	var _j87 = %_o54
	var _s91 = %_h52
	
	if _j87:
		_j87.visible = false
		
	if _s91:
		_s91.visible = true
	if not _v18:
		return
	
	var _m34 = _r59.split("\n")
	var _m67 = _p85.split("\n")
	var _m18 = _b7(_m34, _m67)
	
	for _e30 in _m18:
		_l48(_e30, _v18)

func _c76(content: String, _e13: int, _a55: String, _m88: VBoxContainer, _i11: bool):
	if not is_instance_valid(_m88):
		return
	
	if content.length() > _v55:
		content = content.substr(0, _v55) + "... [TRUNCATED]"
	
	var _w53 = PanelContainer.new()
	_w53.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_w53.size_flags_vertical = Control.SIZE_EXPAND_FILL  
	_w53.custom_minimum_size = Vector2(0, int(36 * _a60))  
	
	var _z9 = StyleBoxFlat.new()
	var _u18 = _w99()

	match _a55:
		"added":
			_z9.bg_color = _l68.added_bg
			_u18 = _l68.added
		"removed":
			_z9.bg_color = _l68.removed_bg
			_u18 = _l68.removed
		"empty":
			_z9.bg_color = _n84()
			_u18 = _h4()  
		"context":
			_z9.bg_color = _n84()
			_u18 = _w99()

	_z9.content_margin_left = 8
	_z9.content_margin_right = 8
	_z9.content_margin_top = 2
	_z9.content_margin_bottom = 2
	_w53.add_theme_stylebox_override("panel", _z9)

	var _w23 = HBoxContainer.new()
	_w23.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_w23.size_flags_vertical = Control.SIZE_EXPAND_FILL  

	var _d65 = Label.new()
	if _a55 == "empty":
		_d65.text = ""
	else:
		_d65.text = str(_e13)
	_d65.custom_minimum_size = Vector2(50, 0)
	_d65.add_theme_color_override("font_color", _h4())
	_d65.add_theme_font_size_override("font_size", _n36(_d84 - 2))
	var _o61 = SystemFont.new()
	_o61.font_names = ["Consolas", "Courier New", "Monospace"]
	_d65.add_theme_font_override("font", _o61)
	_w23.add_child(_d65)
	
	var _c68 = RichTextLabel.new()
	_c68.bbcode_enabled = true
	_c68.selection_enabled = true
	_c68.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_c68.size_flags_vertical = Control.SIZE_EXPAND_FILL  
	_c68.custom_minimum_size = Vector2(400, int(30 * _a60))  
	_c68.fit_content = false  
	_c68.scroll_active = true  
	_c68.autowrap_mode = TextServer.AUTOWRAP_OFF  
	_c68.clip_contents = true  
	_c68.scroll_following = false  
	
	if _a55 == "empty":
		_c68.text = " "  
	else:
		var _z53 = _d35(content) if not content.is_empty() else content
		_c68.text = _z53
	
	_c68.add_theme_font_override("normal_font", _o61)
	_c68.add_theme_font_override("mono_font", _o61)
	_c68.add_theme_color_override("default_color", _u18)
	_c68.add_theme_font_size_override("normal_font_size", _n36(_d84))
	
	_w23.add_child(_c68)
	_w53.add_child(_w23)
	
	_m88.add_child(_w53)
	
	_w53.visible = true
	_w23.visible = true
	_c68.visible = true
	_d65.visible = true
	
	_l39(_c68)
	
	if _m88.is_inside_tree():
		_m88.queue_redraw()

		var _v27 = _m88.get_parent()
		if _v27 and _v27 is ScrollContainer:
			_v27.queue_redraw()
			_v27.notification(Control.NOTIFICATION_RESIZED)
	
func _j68():
	if _s25 and is_instance_valid(_s25):
		var children = _s25.get_children()
		for _j75 in children:
			if is_instance_valid(_j75):
				_s25.remove_child(_j75)
				_j75.queue_free()
	
	if _a17 and is_instance_valid(_a17):
		var children = _a17.get_children()
		for _j75 in children:
			if is_instance_valid(_j75):
				_a17.remove_child(_j75)
				_j75.queue_free()
	
	if _v18 and is_instance_valid(_v18):
		var children = _v18.get_children()
		for _j75 in children:
			if is_instance_valid(_j75):
				_v18.remove_child(_j75)
				_j75.queue_free()

func _e97(value: float):
	if _p43 and _p43.get_v_scroll_bar().value != value:
		_p43.get_v_scroll_bar().value = value

func _i16(value: float):
	if _w56 and _w56.get_v_scroll_bar().value != value:
		_w56.get_v_scroll_bar().value = value

func _d35(line: String) -> String:
	if line.strip_edges().is_empty():
		return line

	return line

func _s75(text: String) -> String:
	if not _z8 or text.length() > _v55:
		return text

	return _z8.sub(text, "[color=#%s]$0[/color]" % _l68.comment.to_html(false), true)

func _g90(text: String) -> String:
	if not _r92 or text.length() > _v55:
		return text
	return _r92.sub(text, "[color=#%s]$1[/color]" % _l68.string.to_html(false), true)

func _k80(text: String) -> String:
	if not _i88 or text.length() > _v55:
		return text
	return _i88.sub(text, "[color=#%s]$1[/color]" % _l68.keyword.to_html(false), true)

func _c95(text: String) -> String:
	if not _t57 or text.length() > _v55:
		return text
	return _t57.sub(text, "[color=#%s]$0[/color]" % _l68.number.to_html(false), true)

func _m40(text: String) -> String:
	if not _c60 or text.length() > _v55:
		return text
	return _c60.sub(text, "[color=#%s]$1[/color](" % _l68.function.to_html(false), true)

func _i42():
	hide()

	var _x29 = {
		"original_code": _r59,
		"refactored_code": _p85,
		"function_name": _k54,
		"file_path": _g17,
		"prompt": _o64,
		"timestamp": Time.get_unix_time_from_system()
	}
	_e92.emit(_x29)

	_u46.emit(_p85, _k54)

func _b51():
	hide()

	_h79.emit(_k54)

func _p61():
	_k38 = not _k38
	_k78.text = "Switch to Side-by-Side" if not _k38 else "Switch to Unified"
	_a81()

func _p24():
	if is_inside_tree():
		hide()

func _g12():
	if not OS.is_debug_build():
		return
	
func _notification(_s100: int):
	match _s100:
		Control.NOTIFICATION_RESIZED:
			_a21()
		Control.NOTIFICATION_VISIBILITY_CHANGED:
			if visible and is_inside_tree():
				_b91.call_deferred()

func _a21():
	if not is_inside_tree() or not _r90:
		return
	
	_n41()
	
	_w92()
	
	if not _r59.is_empty() and not _p85.is_empty():
		_h64()

func _w92():
	if not is_inside_tree() or not _r90:
		return
		
	_r90.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_r90.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	for _j75 in _r90.get_children():
		if _j75.name == "SideBySideContainer" and _j75 is HBoxContainer:
			_j75.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_j75.size_flags_vertical = Control.SIZE_EXPAND_FILL
			
			for _p69 in _j75.get_children():
				if _p69 is VBoxContainer:
					_p69.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					_p69.size_flags_vertical = Control.SIZE_EXPAND_FILL
					
					for _e89 in _p69.get_children():
						if _e89 is ScrollContainer:
							_e89.size_flags_horizontal = Control.SIZE_EXPAND_FILL
							_e89.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		elif _j75.name == "UnifiedContainer" and _j75 is ScrollContainer:
			_j75.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_j75.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _b91():
	if not is_inside_tree():
		return
	_w92()
	if not _r59.is_empty() and not _p85.is_empty():
		_h64()

func _h64():
	var _j7 = _n36(_d84)
	
	for _m88 in [_s25, _a17, _v18]:
		if _m88 and is_instance_valid(_m88):
			for _w53 in _m88.get_children():
				if _w53 and is_instance_valid(_w53):
					for node in _a15(_w53):
						if node is RichTextLabel:
							node.add_theme_font_size_override("normal_font_size", _j7)

							_l39(node)
						elif node is Label:
							node.add_theme_font_size_override("font_size", _j7)

func _a15(node: Node) -> Array:
	var children = []
	for _j75 in node.get_children():
		children.append(_j75)
		children.append_array(_a15(_j75))
	return children

func _l39(_i26: RichTextLabel):
	if not _i26 or not is_instance_valid(_i26):
		return
		
	_i26.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_i26.custom_minimum_size.y = int(32 * _a60)

func _n36(_u61: int) -> int:
	var _u13 = int(_u61 * _a31)

	return max(_u13, 12)

func _n41():
	if not is_inside_tree():
		return
	
	var _n81 = find_child("_c49")
	if _n81 and _n81 is Label:
		_n81.add_theme_font_size_override("font_size", _n36(16))
	
	if _h45:
		_h45.add_theme_font_size_override("font_size", _n36(14))
	
	var _v56 = find_child("_u97")
	if _v56 and _v56 is Label:
		_v56.add_theme_font_size_override("font_size", _n36(14))
	
	var _c75 = find_child("_n18")
	if _c75 and _c75 is Label:
		_c75.add_theme_font_size_override("font_size", _n36(14))

