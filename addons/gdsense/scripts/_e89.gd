@tool
class_name _h4
extends AcceptDialog

signal _j43(refactored_code: String, function_name: String)
signal _w13(function_name: String)
signal _i27(data: Dictionary)

const _w94 = 5000
const _o18 = 10000
const _g29 = 1048576  
const _r75 = 100

var _k96: String
var _z60: String
var _t40: String
var _e12: String
var _z12: String
var _m38: Control
var _n11: Button
var _d27: Button
var _m32: Button
var _e57: bool = true
var _u79: Label

enum _b17 {
	_w69,
	_t72
}
var _v97: _b17

var _a14: float = 1.0
var _g83: float = 1.0  
var _g11: int = 16  

var _g8: ScrollContainer
var _g55: ScrollContainer
var _v60: VBoxContainer
var _l32: VBoxContainer
var _e35: VBoxContainer

var _v22 = {
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

func _w4() -> Color:
	if has_theme_color("font_color", "Editor"):
		return get_theme_color("font_color", "Editor")
	return Color(0.7, 0.7, 0.7)  

func _a26() -> Color:
	if has_theme_color("font_color", "Editor"):
		var font_color = get_theme_color("font_color", "Editor")

		return Color(font_color.r * 0.6, font_color.g * 0.6, font_color.b * 0.6, font_color.a)
	return Color(0.5, 0.5, 0.5)  

func _w79() -> Color:
	if has_theme_color("base_color", "Editor"):
		var _t10 = get_theme_color("base_color", "Editor")
		return Color(_t10.r, _t10.g, _t10.b, 0.3)
	return Color(0.15, 0.15, 0.15, 0.3)  

func _y59():
	var _t29 = get_theme_color("base_color", "Editor") if has_theme_color("base_color", "Editor") else Color(0.2, 0.2, 0.2)
	var _r46 = _t29.get_luminance() > 0.5

	if _r46:
		_v22["comment"] = Color(0.4, 0.5, 0.4)  
		_v22["string"] = Color(0.6, 0.3, 0.1)   
		_v22["number"] = Color(0.1, 0.3, 0.6)   
		_v22["keyword"] = Color(0.6, 0.1, 0.4)  
		_v22["class"] = Color(0.1, 0.5, 0.2)    
		_v22["function"] = Color(0.1, 0.3, 0.6) 
		_v22["symbol"] = Color(0.2, 0.2, 0.2)   
	else:
		_v22["comment"] = Color.GRAY
		_v22["string"] = Color.ORANGE
		_v22["number"] = Color.SKY_BLUE
		_v22["keyword"] = Color.PALE_VIOLET_RED
		_v22["class"] = Color.LIGHT_GREEN
		_v22["function"] = Color.LIGHT_BLUE
		_v22["symbol"] = Color.WHITE

const _y51 = [
	"if", "elif", "else", "for", "while", "match", "break", "continue", "pass",
	"return", "class", "extends", "is", "as", "self", "super", "func", "signal",
	"const", "var", "static", "enum", "in", "not", "and", "or", "true", "false",
	"null", "export", "onready", "tool", "setget", "breakpoint", "preload", "yield",
	"assert", "remote", "sync", "master", "puppet", "@export", "@onready", "@tool"
]

var _v11: RegEx
var _v3: RegEx
var _u51: RegEx
var _n96: RegEx
var _d4: RegEx

func _init():
	_t21()

func _t21():
	_v11 = RegEx.new()
	if _v11.compile("#.*$") != OK:
		push_error("Failed to compile comment regex")
		_v11 = null
	
	_v3 = RegEx.new()
	if _v3.compile("(\"[^\"]*\"|'[^']*')") != OK:
		push_error("Failed to compile string regex")
		_v3 = null
	
	_u51 = RegEx.new()
	var _a68 = "\\b(" + "|".join(_y51) + ")\\b"
	if _u51.compile(_a68) != OK:
		push_error("Failed to compile keyword regex")
		_u51 = null
	
	_n96 = RegEx.new()
	if _n96.compile("\\b\\d+(\\.\\d+)?\\b") != OK:
		push_error("Failed to compile number regex")
		_n96 = null
	
	_d4 = RegEx.new()
	if _d4.compile("\\b([a-z_][a-zA-Z0-9_]*)\\s*\\(") != OK:
		push_error("Failed to compile function regex")
		_d4 = null

func _ready():
	get_ok_button().hide()

	_m8()

	_y59()

	if not confirmed.is_connected(_d62):
		confirmed.connect(_d62)

	_i29()
	_c61()

	_t84()

	_e19.call_deferred()

func _m8():
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		var _w39 = config.get_value("font_scale", "mode", "auto")
		if _w39 == "auto":
			var _t53 = DisplayServer.screen_get_size()
			var _d40 = _t53.y
			if _d40 >= 2160:  
				_g83 = 1.5
			elif _d40 >= 1440:  
				_g83 = 1.25
			else:  
				_g83 = 1.0
		else:
			_g83 = float(_w39)
	else:
		_g83 = 1.0

func _i29():
	if not is_inside_tree():
		return
	
	_m32 = %_k65
	_u79 = %_l25  
	_m38 = %_a78
	_n11 = %_l45
	_d27 = %_j65
	
	_g8 = %_w20
	_g55 = %_t20
	_v60 = %_q93
	_l32 = %_t3
	_e35 = %_w57
	
	if _m32 and not _m32.pressed.is_connected(_c21):
		_m32.pressed.connect(_c21)
	if _n11 and not _n11.pressed.is_connected(_d62):
		_n11.pressed.connect(_d62)
	if _d27 and not _d27.pressed.is_connected(_w83):
		_d27.pressed.connect(_w83)
	
	if _g8 and _g55:
		var _k99 = _g8.get_v_scroll_bar()
		var _c40 = _g55.get_v_scroll_bar()
		if not _k99.value_changed.is_connected(_o74):
			_k99.value_changed.connect(_o74)
		if not _c40.value_changed.is_connected(_i69):
			_c40.value_changed.connect(_i69)
	
func _c61():
	_e57 = true
	_v97 = _b17._w69

func _c16():
	if _v60 and _l32 and _e35:
		if is_instance_valid(_v60) and is_instance_valid(_l32) and is_instance_valid(_e35):
			return
	
	_v60 = %_q93
	_l32 = %_t3
	_e35 = %_w57
	_g8 = %_w20
	_g55 = %_t20
	
	if not _v60 or not _l32 or not _e35:
		pass
func _d54(function_name: String, original_code: String, refactored_code: String, file_path: String = "", prompt: String = ""):
	var _c5 = original_code.length() + refactored_code.length()
	if _c5 > _g29:
		push_error("Total input size exceeds maximum allowed size of %d bytes" % _g29)
		return
	
	if original_code.length() > _o18 * _w94:
		push_error("Original code exceeds maximum allowed size")
		return
	if refactored_code.length() > _o18 * _w94:
		push_error("Refactored code exceeds maximum allowed size")
		return
	
	var _u60 = original_code.split("\n")
	var _k45 = refactored_code.split("\n")
	
	if _u60.size() > _w94 or _k45.size() > _w94:
		push_error("Code exceeds maximum line limit of %d" % _w94)
		return
	
	_t40 = function_name
	_k96 = original_code
	_z60 = refactored_code
	_e12 = file_path
	_z12 = prompt
	
	if not is_inside_tree():
		var _t15 = Engine.get_singleton("EditorInterface")
		if _t15:
			var _a9 = _t15.get_base_control()
			if _a9:
				_a9.add_child(self)
			else:
				pass

	_q37.call_deferred()

func _k73():
	if not _m32:
		_i29()
		_c16()

func _q37():
	if not is_inside_tree():
		return

	_m8()
	_y59()
	_t84()

	popup_centered()

	if not is_inside_tree():
		return
	await get_tree().process_frame

	if not is_inside_tree():
		return

	_e19()

	_k73()

	if _u79:
		_u79.text = "Function: %s" % _t40
	else:
		pass

	_f19()

func _f19():
	if not _v60 or not _l32 or not _e35:
		return
		
	if _k96.is_empty() or _z60.is_empty():
		return
	
	if _e57:
		_v42()
	else:
		_z69()

func _j10(_u60: PackedStringArray, _k45: PackedStringArray) -> Array:
	var _m80 = []
	var _l35 = 0
	var _z58 = 0
	
	while _l35 < _u60.size() or _z58 < _k45.size():
		if _l35 >= _u60.size():
			_m80.append({
				"type": "added", 
				"line": _k45[_z58],
				"original_line_num": -1,
				"refactored_line_num": _z58 + 1
			})
			_z58 += 1
		elif _z58 >= _k45.size():
			_m80.append({
				"type": "removed", 
				"line": _u60[_l35],
				"original_line_num": _l35 + 1,
				"refactored_line_num": -1
			})
			_l35 += 1
		elif _u60[_l35] == _k45[_z58]:
			_m80.append({
				"type": "context", 
				"line": _u60[_l35],
				"original_line_num": _l35 + 1,
				"refactored_line_num": _z58 + 1
			})
			_l35 += 1
			_z58 += 1
		else:
			_m80.append({
				"type": "removed", 
				"line": _u60[_l35],
				"original_line_num": _l35 + 1,
				"refactored_line_num": -1
			})
			_m80.append({
				"type": "added", 
				"line": _k45[_z58],
				"original_line_num": -1,
				"refactored_line_num": _z58 + 1
			})
			_l35 += 1
			_z58 += 1
	
	return _m80

func _f56(_p18: Dictionary, _u58: VBoxContainer):
	var _j5 = PanelContainer.new()
	_j5.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var _h76 = StyleBoxFlat.new()
	var prefix = ""
	var _m44 = _w4()

	match _p18.type:
		"added":
			_h76.bg_color = _v22.added_bg
			prefix = "+ "
			_m44 = _v22.added
		"removed":
			_h76.bg_color = _v22.removed_bg
			prefix = "- "
			_m44 = _v22.removed
		"context":
			_h76.bg_color = _w79()
			prefix = "  "
			_m44 = _w4()

	_h76.content_margin_left = 8
	_h76.content_margin_right = 8
	_h76.content_margin_top = 2
	_h76.content_margin_bottom = 2
	_j5.add_theme_stylebox_override("panel", _h76)

	var _y1 = HBoxContainer.new()

	var _b43 = Label.new()
	var _i86 = ""
	if _p18.original_line_num > 0 and _p18.refactored_line_num > 0:
		_i86 = "%d:%d" % [_p18.original_line_num, _p18.refactored_line_num]
	elif _p18.original_line_num > 0:
		_i86 = "%d:-" % _p18.original_line_num
	else:
		_i86 = "-:%d" % _p18.refactored_line_num

	_b43.text = _i86
	_b43.custom_minimum_size = Vector2(80, 0)
	_b43.add_theme_color_override("font_color", _a26())
	_b43.add_theme_font_size_override("font_size", _i68(_g11 - 2))
	var _i72 = SystemFont.new()
	_i72.font_names = ["Consolas", "Courier New", "Monospace"]
	_b43.add_theme_font_override("font", _i72)
	_y1.add_child(_b43)
	
	var _y99 = RichTextLabel.new()
	_y99.bbcode_enabled = true
	_y99.selection_enabled = true
	_y99.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_y99.size_flags_vertical = Control.SIZE_EXPAND_FILL  
	_y99.fit_content = false  
	_y99.scroll_active = true  
	_y99.autowrap_mode = TextServer.AUTOWRAP_OFF  
	_y99.custom_minimum_size = Vector2(400, int(32 * _a14))  
	
	var _y74 = _t98(_p18.line)
	_y99.text = prefix + _y74
	
	_y99.add_theme_font_override("normal_font", _i72)
	_y99.add_theme_font_override("mono_font", _i72)
	_y99.add_theme_color_override("default_color", _m44)
	_y99.add_theme_font_size_override("normal_font_size", _i68(_g11))
	
	_y1.add_child(_y99)
	_j5.add_child(_y1)
	
	_j5.custom_minimum_size = Vector2(0, int(36 * _a14))  
	_j5.size_flags_vertical = Control.SIZE_EXPAND_FILL  
	
	_u58.add_child(_j5)
	
	_h70(_y99)
	
	if _j5.is_inside_tree():
		_j5.queue_redraw()

func _v42():
	_c16()
	
	_j59()
	
	var _s95 = %_m34
	var _j55 = %_p29
	
	if _s95:
		_s95.visible = true
	if _j55:
		_j55.visible = false
	
	if not _v60 or not _l32:
		return
	
	if not is_instance_valid(_v60) or not is_instance_valid(_l32):
		return
	
	var _u60 = _k96.split("\n")
	var _k45 = _z60.split("\n")
	
	if _u60.size() > _w94:
		_u60.resize(_w94)
	if _k45.size() > _w94:
		_k45.resize(_w94)
	
	var _g76 = max(_u60.size(), _k45.size())
	
	for i in range(_g76):
		var _l96 = _u60[i] if i < _u60.size() else ""
		var _c35 = _k45[i] if i < _k45.size() else ""
		
		var _v76 = "context"
		var _a21 = "context"
		
		if i >= _u60.size():
			_v76 = "empty"
			_a21 = "added"
		elif i >= _k45.size():
			_v76 = "removed" 
			_a21 = "empty"
		elif _l96 != _c35:
			_v76 = "removed"
			_a21 = "added"
		
		if _v60 and _l32:
			_c92(_l96, i + 1, _v76, _v60, true)
			_c92(_c35, i + 1, _a21, _l32, false)
		else:
			return
	
	if is_inside_tree():
		if _g8 and is_instance_valid(_g8):
			_g8.queue_redraw()
			_g8.notification(Control.NOTIFICATION_RESIZED)

			_g8.queue_sort()
		if _g55 and is_instance_valid(_g55):
			_g55.queue_redraw()
			_g55.notification(Control.NOTIFICATION_RESIZED)

			_g55.queue_sort()

		if _v60 and is_instance_valid(_v60):
			_v60.queue_redraw()
			_v60.queue_sort()
		if _l32 and is_instance_valid(_l32):
			_l32.queue_redraw()
			_l32.queue_sort()
		
func _z69():
	_c16()
	
	_j59()
	
	var _s95 = %_m34
	var _j55 = %_p29
	
	if _s95:
		_s95.visible = false
		
	if _j55:
		_j55.visible = true
	if not _e35:
		return
	
	var _u60 = _k96.split("\n")
	var _k45 = _z60.split("\n")
	var _m4 = _j10(_u60, _k45)
	
	for _p18 in _m4:
		_f56(_p18, _e35)

func _c92(content: String, _t33: int, _p64: String, _u58: VBoxContainer, _f31: bool):
	if not is_instance_valid(_u58):
		return
	
	if content.length() > _o18:
		content = content.substr(0, _o18) + "... [TRUNCATED]"
	
	var _j5 = PanelContainer.new()
	_j5.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_j5.size_flags_vertical = Control.SIZE_EXPAND_FILL  
	_j5.custom_minimum_size = Vector2(0, int(36 * _a14))  
	
	var _h76 = StyleBoxFlat.new()
	var _m44 = _w4()

	match _p64:
		"added":
			_h76.bg_color = _v22.added_bg
			_m44 = _v22.added
		"removed":
			_h76.bg_color = _v22.removed_bg
			_m44 = _v22.removed
		"empty":
			_h76.bg_color = _w79()
			_m44 = _a26()  
		"context":
			_h76.bg_color = _w79()
			_m44 = _w4()

	_h76.content_margin_left = 8
	_h76.content_margin_right = 8
	_h76.content_margin_top = 2
	_h76.content_margin_bottom = 2
	_j5.add_theme_stylebox_override("panel", _h76)

	var _y1 = HBoxContainer.new()
	_y1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_y1.size_flags_vertical = Control.SIZE_EXPAND_FILL  

	var _b43 = Label.new()
	if _p64 == "empty":
		_b43.text = ""
	else:
		_b43.text = str(_t33)
	_b43.custom_minimum_size = Vector2(50, 0)
	_b43.add_theme_color_override("font_color", _a26())
	_b43.add_theme_font_size_override("font_size", _i68(_g11 - 2))
	var _i72 = SystemFont.new()
	_i72.font_names = ["Consolas", "Courier New", "Monospace"]
	_b43.add_theme_font_override("font", _i72)
	_y1.add_child(_b43)
	
	var _y99 = RichTextLabel.new()
	_y99.bbcode_enabled = true
	_y99.selection_enabled = true
	_y99.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_y99.size_flags_vertical = Control.SIZE_EXPAND_FILL  
	_y99.custom_minimum_size = Vector2(400, int(30 * _a14))  
	_y99.fit_content = false  
	_y99.scroll_active = true  
	_y99.autowrap_mode = TextServer.AUTOWRAP_OFF  
	_y99.clip_contents = true  
	_y99.scroll_following = false  
	
	if _p64 == "empty":
		_y99.text = " "  
	else:
		var _y74 = _t98(content) if not content.is_empty() else content
		_y99.text = _y74
	
	_y99.add_theme_font_override("normal_font", _i72)
	_y99.add_theme_font_override("mono_font", _i72)
	_y99.add_theme_color_override("default_color", _m44)
	_y99.add_theme_font_size_override("normal_font_size", _i68(_g11))
	
	_y1.add_child(_y99)
	_j5.add_child(_y1)
	
	_u58.add_child(_j5)
	
	_j5.visible = true
	_y1.visible = true
	_y99.visible = true
	_b43.visible = true
	
	_h70(_y99)
	
	if _u58.is_inside_tree():
		_u58.queue_redraw()

		var _i63 = _u58.get_parent()
		if _i63 and _i63 is ScrollContainer:
			_i63.queue_redraw()
			_i63.notification(Control.NOTIFICATION_RESIZED)
	
func _j59():
	if _v60 and is_instance_valid(_v60):
		var children = _v60.get_children()
		for _w15 in children:
			if is_instance_valid(_w15):
				_v60.remove_child(_w15)
				_w15.queue_free()
	
	if _l32 and is_instance_valid(_l32):
		var children = _l32.get_children()
		for _w15 in children:
			if is_instance_valid(_w15):
				_l32.remove_child(_w15)
				_w15.queue_free()
	
	if _e35 and is_instance_valid(_e35):
		var children = _e35.get_children()
		for _w15 in children:
			if is_instance_valid(_w15):
				_e35.remove_child(_w15)
				_w15.queue_free()

func _o74(value: float):
	if _g55 and _g55.get_v_scroll_bar().value != value:
		_g55.get_v_scroll_bar().value = value

func _i69(value: float):
	if _g8 and _g8.get_v_scroll_bar().value != value:
		_g8.get_v_scroll_bar().value = value

func _t98(line: String) -> String:
	if line.strip_edges().is_empty():
		return line

	return line

func _x28(text: String) -> String:
	if not _v11 or text.length() > _o18:
		return text

	return _v11.sub(text, "[color=#%s]$0[/color]" % _v22.comment.to_html(false), true)

func _h16(text: String) -> String:
	if not _v3 or text.length() > _o18:
		return text
	return _v3.sub(text, "[color=#%s]$1[/color]" % _v22.string.to_html(false), true)

func _x3(text: String) -> String:
	if not _u51 or text.length() > _o18:
		return text
	return _u51.sub(text, "[color=#%s]$1[/color]" % _v22.keyword.to_html(false), true)

func _d48(text: String) -> String:
	if not _n96 or text.length() > _o18:
		return text
	return _n96.sub(text, "[color=#%s]$0[/color]" % _v22.number.to_html(false), true)

func _m10(text: String) -> String:
	if not _d4 or text.length() > _o18:
		return text
	return _d4.sub(text, "[color=#%s]$1[/color](" % _v22.function.to_html(false), true)

func _d62():
	hide()

	var _u75 = {
		"original_code": _k96,
		"refactored_code": _z60,
		"function_name": _t40,
		"file_path": _e12,
		"prompt": _z12,
		"timestamp": Time.get_unix_time_from_system()
	}
	_i27.emit(_u75)

	_j43.emit(_z60, _t40)

func _w83():
	hide()

	_w13.emit(_t40)

func _c21():
	_e57 = not _e57
	_m32.text = "Switch to Side-by-Side" if not _e57 else "Switch to Unified"
	_f19()

func _h22():
	if is_inside_tree():
		hide()

func _q94():
	if not OS.is_debug_build():
		return
	
func _notification(_f44: int):
	match _f44:
		Control.NOTIFICATION_RESIZED:
			_g72()
		Control.NOTIFICATION_VISIBILITY_CHANGED:
			if visible and is_inside_tree():
				_k89.call_deferred()

func _g72():
	if not is_inside_tree() or not _m38:
		return
	
	_t84()
	
	_e19()
	
	if not _k96.is_empty() and not _z60.is_empty():
		_n53()

func _e19():
	if not is_inside_tree() or not _m38:
		return
		
	_m38.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_m38.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	for _w15 in _m38.get_children():
		if _w15.name == "SideBySideContainer" and _w15 is HBoxContainer:
			_w15.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_w15.size_flags_vertical = Control.SIZE_EXPAND_FILL
			
			for _r77 in _w15.get_children():
				if _r77 is VBoxContainer:
					_r77.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					_r77.size_flags_vertical = Control.SIZE_EXPAND_FILL
					
					for _l40 in _r77.get_children():
						if _l40 is ScrollContainer:
							_l40.size_flags_horizontal = Control.SIZE_EXPAND_FILL
							_l40.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		elif _w15.name == "UnifiedContainer" and _w15 is ScrollContainer:
			_w15.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_w15.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _k89():
	if not is_inside_tree():
		return
	_e19()
	if not _k96.is_empty() and not _z60.is_empty():
		_n53()

func _n53():
	var _g35 = _i68(_g11)
	
	for _u58 in [_v60, _l32, _e35]:
		if _u58 and is_instance_valid(_u58):
			for _j5 in _u58.get_children():
				if _j5 and is_instance_valid(_j5):
					for node in _l26(_j5):
						if node is RichTextLabel:
							node.add_theme_font_size_override("normal_font_size", _g35)

							_h70(node)
						elif node is Label:
							node.add_theme_font_size_override("font_size", _g35)

func _l26(node: Node) -> Array:
	var children = []
	for _w15 in node.get_children():
		children.append(_w15)
		children.append_array(_l26(_w15))
	return children

func _h70(_e30: RichTextLabel):
	if not _e30 or not is_instance_valid(_e30):
		return
		
	_e30.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_e30.custom_minimum_size.y = int(32 * _a14)

func _i68(_g6: int) -> int:
	var _y84 = int(_g6 * _g83)

	return max(_y84, 12)

func _t84():
	if not is_inside_tree():
		return
	
	var _d65 = find_child("_l61")
	if _d65 and _d65 is Label:
		_d65.add_theme_font_size_override("font_size", _i68(16))
	
	if _u79:
		_u79.add_theme_font_size_override("font_size", _i68(14))
	
	var _g24 = find_child("_h98")
	if _g24 and _g24 is Label:
		_g24.add_theme_font_size_override("font_size", _i68(14))
	
	var _y5 = find_child("_l63")
	if _y5 and _y5 is Label:
		_y5.add_theme_font_size_override("font_size", _i68(14))

