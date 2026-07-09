@tool
class_name _z64
extends AcceptDialog
signal _p51(refactored_code: String, function_name: String)
signal _t68(function_name: String)
signal _d76(data: Dictionary)
const _b23 = 5000
const _h67 = 10000
const _i2 = 1048576  
const _g60 = 100
var _l11: String
var _p54: String
var _p91: String
var _r42: String
var _o55: String
var _o33: Control
var _n46: Button
var _w39: Button
var _x72: Button
var _f69: bool = true
var _z14: Label
enum _b9 {
	_j81,
	_n93
}
var _h68: _b9
var _c46: float = 1.0
var _x27: float = 1.0  
var _t97: int = 16  
var _q22: ScrollContainer
var _h49: ScrollContainer
var _g85: VBoxContainer
var _c98: VBoxContainer
var _e94: VBoxContainer
var _a52 = {
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
func _s61() -> Color:
	if has_theme_color("font_color", "Editor"):
		return get_theme_color("font_color", "Editor")
	return Color(0.7, 0.7, 0.7)  
func _i95() -> Color:
	if has_theme_color("font_color", "Editor"):
		var font_color = get_theme_color("font_color", "Editor")
		return Color(font_color.r * 0.6, font_color.g * 0.6, font_color.b * 0.6, font_color.a)
	return Color(0.5, 0.5, 0.5)  
func _l61() -> Color:
	if has_theme_color("base_color", "Editor"):
		var _w86 = get_theme_color("base_color", "Editor")
		return Color(_w86.r, _w86.g, _w86.b, 0.3)
	return Color(0.15, 0.15, 0.15, 0.3)  
func _n65():
	var _i13 = get_theme_color("base_color", "Editor") if has_theme_color("base_color", "Editor") else Color(0.2, 0.2, 0.2)
	var _m32 = _i13.get_luminance() > 0.5
	if _m32:
		_a52["comment"] = Color(0.4, 0.5, 0.4)  
		_a52["string"] = Color(0.6, 0.3, 0.1)   
		_a52["number"] = Color(0.1, 0.3, 0.6)   
		_a52["keyword"] = Color(0.6, 0.1, 0.4)  
		_a52["class"] = Color(0.1, 0.5, 0.2)    
		_a52["function"] = Color(0.1, 0.3, 0.6) 
		_a52["symbol"] = Color(0.2, 0.2, 0.2)   
	else:
		_a52["comment"] = Color.GRAY
		_a52["string"] = Color.ORANGE
		_a52["number"] = Color.SKY_BLUE
		_a52["keyword"] = Color.PALE_VIOLET_RED
		_a52["class"] = Color.LIGHT_GREEN
		_a52["function"] = Color.LIGHT_BLUE
		_a52["symbol"] = Color.WHITE
const _u46 = [
	"if", "elif", "else", "for", "while", "match", "break", "continue", "pass",
	"return", "class", "extends", "is", "as", "self", "super", "func", "signal",
	"const", "var", "static", "enum", "in", "not", "and", "or", "true", "false",
	"null", "export", "onready", "tool", "setget", "breakpoint", "preload", "yield",
	"assert", "remote", "sync", "master", "puppet", "@export", "@onready", "@tool"
]
var _y32: RegEx
var _q42: RegEx
var _h84: RegEx
var _e89: RegEx
var _z66: RegEx
func _init():
	_i58()
func _i58():
	_y32 = RegEx.new()
	if _y32.compile("#.*$") != OK:
		push_error("Failed to compile comment regex")
		_y32 = null
	_q42 = RegEx.new()
	if _q42.compile("(\"[^\"]*\"|'[^']*')") != OK:
		push_error("Failed to compile string regex")
		_q42 = null
	_h84 = RegEx.new()
	var _x55 = "\\b(" + "|".join(_u46) + ")\\b"
	if _h84.compile(_x55) != OK:
		push_error("Failed to compile keyword regex")
		_h84 = null
	_e89 = RegEx.new()
	if _e89.compile("\\b\\d+(\\.\\d+)?\\b") != OK:
		push_error("Failed to compile number regex")
		_e89 = null
	_z66 = RegEx.new()
	if _z66.compile("\\b([a-z_][a-zA-Z0-9_]*)\\s*\\(") != OK:
		push_error("Failed to compile function regex")
		_z66 = null
func _ready():
	get_ok_button().hide()
	_m61()
	_n65()
	if not confirmed.is_connected(_o16):
		confirmed.connect(_o16)
	_d45()
	_v5()
	_i60()
	_t55.call_deferred()
func _m61():
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		var _n11 = config.get_value("font_scale", "mode", "auto")
		if _n11 == "auto":
			var _p37 = DisplayServer.screen_get_size()
			var _j97 = _p37.y
			if _j97 >= 2160:  
				_x27 = 1.5
			elif _j97 >= 1440:  
				_x27 = 1.25
			else:  
				_x27 = 1.0
		else:
			_x27 = float(_n11)
	else:
		_x27 = 1.0
func _d45():
	if not is_inside_tree():
		return
	_x72 = %_g50
	_z14 = %_u96  
	_o33 = %_e73
	_n46 = %_c59
	_w39 = %_b62
	_q22 = %_o74
	_h49 = %_p57
	_g85 = %_y38
	_c98 = %_d65
	_e94 = %_j98
	if _x72 and not _x72.pressed.is_connected(_s52):
		_x72.pressed.connect(_s52)
	if _n46 and not _n46.pressed.is_connected(_o16):
		_n46.pressed.connect(_o16)
	if _w39 and not _w39.pressed.is_connected(_p62):
		_w39.pressed.connect(_p62)
	if _q22 and _h49:
		var _d67 = _q22.get_v_scroll_bar()
		var _i67 = _h49.get_v_scroll_bar()
		if not _d67.value_changed.is_connected(_v58):
			_d67.value_changed.connect(_v58)
		if not _i67.value_changed.is_connected(_k54):
			_i67.value_changed.connect(_k54)
func _v5():
	_f69 = true
	_h68 = _b9._j81
func _j93():
	if _g85 and _c98 and _e94:
		if is_instance_valid(_g85) and is_instance_valid(_c98) and is_instance_valid(_e94):
			return
	_g85 = %_y38
	_c98 = %_d65
	_e94 = %_j98
	_q22 = %_o74
	_h49 = %_p57
	if not _g85 or not _c98 or not _e94:
		pass
func _w89(function_name: String, original_code: String, refactored_code: String, file_path: String = "", prompt: String = ""):
	var _y89 = original_code.length() + refactored_code.length()
	if _y89 > _i2:
		push_error("Total input size exceeds maximum allowed size of %d bytes" % _i2)
		return
	if original_code.length() > _h67 * _b23:
		push_error("Original code exceeds maximum allowed size")
		return
	if refactored_code.length() > _h67 * _b23:
		push_error("Refactored code exceeds maximum allowed size")
		return
	var _b40 = original_code.split("\n")
	var _r11 = refactored_code.split("\n")
	if _b40.size() > _b23 or _r11.size() > _b23:
		push_error("Code exceeds maximum line limit of %d" % _b23)
		return
	_p91 = function_name
	_l11 = original_code
	_p54 = refactored_code
	_r42 = file_path
	_o55 = prompt
	if not is_inside_tree():
		var _o10 = Engine.get_singleton("EditorInterface")
		if _o10:
			var _v54 = _o10.get_base_control()
			if _v54:
				_v54.add_child(self)
			else:
				pass
	_x85.call_deferred()
func _u6():
	if not _x72:
		_d45()
		_j93()
func _x85():
	if not is_inside_tree():
		return
	_m61()
	_n65()
	_i60()
	popup_centered()
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_t55()
	_u6()
	if _z14:
		_z14.text = "Function: %s" % _p91
	else:
		pass
	_e20()
func _e20():
	if not _g85 or not _c98 or not _e94:
		return
	if _l11.is_empty() or _p54.is_empty():
		return
	if _f69:
		_v3()
	else:
		_i47()
func _l6(_b40: PackedStringArray, _r11: PackedStringArray) -> Array:
	var _z95 = []
	var _d87 = 0
	var _w19 = 0
	while _d87 < _b40.size() or _w19 < _r11.size():
		if _d87 >= _b40.size():
			_z95.append({
				"type": "added", 
				"line": _r11[_w19],
				"original_line_num": -1,
				"refactored_line_num": _w19 + 1
			})
			_w19 += 1
		elif _w19 >= _r11.size():
			_z95.append({
				"type": "removed", 
				"line": _b40[_d87],
				"original_line_num": _d87 + 1,
				"refactored_line_num": -1
			})
			_d87 += 1
		elif _b40[_d87] == _r11[_w19]:
			_z95.append({
				"type": "context", 
				"line": _b40[_d87],
				"original_line_num": _d87 + 1,
				"refactored_line_num": _w19 + 1
			})
			_d87 += 1
			_w19 += 1
		else:
			_z95.append({
				"type": "removed", 
				"line": _b40[_d87],
				"original_line_num": _d87 + 1,
				"refactored_line_num": -1
			})
			_z95.append({
				"type": "added", 
				"line": _r11[_w19],
				"original_line_num": -1,
				"refactored_line_num": _w19 + 1
			})
			_d87 += 1
			_w19 += 1
	return _z95
func _a40(_v48: Dictionary, _m46: VBoxContainer):
	var _q63 = PanelContainer.new()
	_q63.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _j80 = StyleBoxFlat.new()
	var prefix = ""
	var _m44 = _s61()
	match _v48.type:
		"added":
			_j80.bg_color = _a52.added_bg
			prefix = "+ "
			_m44 = _a52.added
		"removed":
			_j80.bg_color = _a52.removed_bg
			prefix = "- "
			_m44 = _a52.removed
		"context":
			_j80.bg_color = _l61()
			prefix = "  "
			_m44 = _s61()
	_j80.content_margin_left = 8
	_j80.content_margin_right = 8
	_j80.content_margin_top = 2
	_j80.content_margin_bottom = 2
	_q63.add_theme_stylebox_override("panel", _j80)
	var _r6 = HBoxContainer.new()
	var _l5 = Label.new()
	var _d13 = ""
	if _v48.original_line_num > 0 and _v48.refactored_line_num > 0:
		_d13 = "%d:%d" % [_v48.original_line_num, _v48.refactored_line_num]
	elif _v48.original_line_num > 0:
		_d13 = "%d:-" % _v48.original_line_num
	else:
		_d13 = "-:%d" % _v48.refactored_line_num
	_l5.text = _d13
	_l5.custom_minimum_size = Vector2(80, 0)
	_l5.add_theme_color_override("font_color", _i95())
	_l5.add_theme_font_size_override("font_size", _k37(_t97 - 2))
	var _k31 = SystemFont.new()
	_k31.font_names = ["Consolas", "Courier New", "Monospace"]
	_l5.add_theme_font_override("font", _k31)
	_r6.add_child(_l5)
	var _l42 = RichTextLabel.new()
	_l42.bbcode_enabled = true
	_l42.selection_enabled = true
	_l42.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_l42.size_flags_vertical = Control.SIZE_EXPAND_FILL  
	_l42.fit_content = false  
	_l42.scroll_active = true  
	_l42.autowrap_mode = TextServer.AUTOWRAP_OFF  
	_l42.custom_minimum_size = Vector2(400, int(32 * _c46))  
	var _r25 = _u61(_v48.line)
	_l42.text = prefix + _r25
	_l42.add_theme_font_override("normal_font", _k31)
	_l42.add_theme_font_override("mono_font", _k31)
	_l42.add_theme_color_override("default_color", _m44)
	_l42.add_theme_font_size_override("normal_font_size", _k37(_t97))
	_r6.add_child(_l42)
	_q63.add_child(_r6)
	_q63.custom_minimum_size = Vector2(0, int(36 * _c46))  
	_q63.size_flags_vertical = Control.SIZE_EXPAND_FILL  
	_m46.add_child(_q63)
	_p66(_l42)
	if _q63.is_inside_tree():
		_q63.queue_redraw()
func _v3():
	_j93()
	_m34()
	var _n90 = %_r8
	var _k80 = %_m48
	if _n90:
		_n90.visible = true
	if _k80:
		_k80.visible = false
	if not _g85 or not _c98:
		return
	if not is_instance_valid(_g85) or not is_instance_valid(_c98):
		return
	var _b40 = _l11.split("\n")
	var _r11 = _p54.split("\n")
	if _b40.size() > _b23:
		_b40.resize(_b23)
	if _r11.size() > _b23:
		_r11.resize(_b23)
	var _g99 = max(_b40.size(), _r11.size())
	for i in range(_g99):
		var _l22 = _b40[i] if i < _b40.size() else ""
		var _u66 = _r11[i] if i < _r11.size() else ""
		var _j53 = "context"
		var _r84 = "context"
		if i >= _b40.size():
			_j53 = "empty"
			_r84 = "added"
		elif i >= _r11.size():
			_j53 = "removed" 
			_r84 = "empty"
		elif _l22 != _u66:
			_j53 = "removed"
			_r84 = "added"
		if _g85 and _c98:
			_h31(_l22, i + 1, _j53, _g85, true)
			_h31(_u66, i + 1, _r84, _c98, false)
		else:
			return
	if is_inside_tree():
		if _q22 and is_instance_valid(_q22):
			_q22.queue_redraw()
			_q22.notification(Control.NOTIFICATION_RESIZED)
			_q22.queue_sort()
		if _h49 and is_instance_valid(_h49):
			_h49.queue_redraw()
			_h49.notification(Control.NOTIFICATION_RESIZED)
			_h49.queue_sort()
		if _g85 and is_instance_valid(_g85):
			_g85.queue_redraw()
			_g85.queue_sort()
		if _c98 and is_instance_valid(_c98):
			_c98.queue_redraw()
			_c98.queue_sort()
func _i47():
	_j93()
	_m34()
	var _n90 = %_r8
	var _k80 = %_m48
	if _n90:
		_n90.visible = false
	if _k80:
		_k80.visible = true
	if not _e94:
		return
	var _b40 = _l11.split("\n")
	var _r11 = _p54.split("\n")
	var _u59 = _l6(_b40, _r11)
	for _v48 in _u59:
		_a40(_v48, _e94)
func _h31(content: String, _v36: int, _u30: String, _m46: VBoxContainer, _u34: bool):
	if not is_instance_valid(_m46):
		return
	if content.length() > _h67:
		content = content.substr(0, _h67) + "... [TRUNCATED]"
	var _q63 = PanelContainer.new()
	_q63.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_q63.size_flags_vertical = Control.SIZE_EXPAND_FILL  
	_q63.custom_minimum_size = Vector2(0, int(36 * _c46))  
	var _j80 = StyleBoxFlat.new()
	var _m44 = _s61()
	match _u30:
		"added":
			_j80.bg_color = _a52.added_bg
			_m44 = _a52.added
		"removed":
			_j80.bg_color = _a52.removed_bg
			_m44 = _a52.removed
		"empty":
			_j80.bg_color = _l61()
			_m44 = _i95()  
		"context":
			_j80.bg_color = _l61()
			_m44 = _s61()
	_j80.content_margin_left = 8
	_j80.content_margin_right = 8
	_j80.content_margin_top = 2
	_j80.content_margin_bottom = 2
	_q63.add_theme_stylebox_override("panel", _j80)
	var _r6 = HBoxContainer.new()
	_r6.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_r6.size_flags_vertical = Control.SIZE_EXPAND_FILL  
	var _l5 = Label.new()
	if _u30 == "empty":
		_l5.text = ""
	else:
		_l5.text = str(_v36)
	_l5.custom_minimum_size = Vector2(50, 0)
	_l5.add_theme_color_override("font_color", _i95())
	_l5.add_theme_font_size_override("font_size", _k37(_t97 - 2))
	var _k31 = SystemFont.new()
	_k31.font_names = ["Consolas", "Courier New", "Monospace"]
	_l5.add_theme_font_override("font", _k31)
	_r6.add_child(_l5)
	var _l42 = RichTextLabel.new()
	_l42.bbcode_enabled = true
	_l42.selection_enabled = true
	_l42.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_l42.size_flags_vertical = Control.SIZE_EXPAND_FILL  
	_l42.custom_minimum_size = Vector2(400, int(30 * _c46))  
	_l42.fit_content = false  
	_l42.scroll_active = true  
	_l42.autowrap_mode = TextServer.AUTOWRAP_OFF  
	_l42.clip_contents = true  
	_l42.scroll_following = false  
	if _u30 == "empty":
		_l42.text = " "  
	else:
		var _r25 = _u61(content) if not content.is_empty() else content
		_l42.text = _r25
	_l42.add_theme_font_override("normal_font", _k31)
	_l42.add_theme_font_override("mono_font", _k31)
	_l42.add_theme_color_override("default_color", _m44)
	_l42.add_theme_font_size_override("normal_font_size", _k37(_t97))
	_r6.add_child(_l42)
	_q63.add_child(_r6)
	_m46.add_child(_q63)
	_q63.visible = true
	_r6.visible = true
	_l42.visible = true
	_l5.visible = true
	_p66(_l42)
	if _m46.is_inside_tree():
		_m46.queue_redraw()
		var _o71 = _m46.get_parent()
		if _o71 and _o71 is ScrollContainer:
			_o71.queue_redraw()
			_o71.notification(Control.NOTIFICATION_RESIZED)
func _m34():
	if _g85 and is_instance_valid(_g85):
		var children = _g85.get_children()
		for _i64 in children:
			if is_instance_valid(_i64):
				_g85.remove_child(_i64)
				_i64.queue_free()
	if _c98 and is_instance_valid(_c98):
		var children = _c98.get_children()
		for _i64 in children:
			if is_instance_valid(_i64):
				_c98.remove_child(_i64)
				_i64.queue_free()
	if _e94 and is_instance_valid(_e94):
		var children = _e94.get_children()
		for _i64 in children:
			if is_instance_valid(_i64):
				_e94.remove_child(_i64)
				_i64.queue_free()
func _v58(value: float):
	if _h49 and _h49.get_v_scroll_bar().value != value:
		_h49.get_v_scroll_bar().value = value
func _k54(value: float):
	if _q22 and _q22.get_v_scroll_bar().value != value:
		_q22.get_v_scroll_bar().value = value
func _u61(line: String) -> String:
	if line.strip_edges().is_empty():
		return line
	return line
func _q58(text: String) -> String:
	if not _y32 or text.length() > _h67:
		return text
	return _y32.sub(text, "[color=#%s]$0[/color]" % _a52.comment.to_html(false), true)
func _x29(text: String) -> String:
	if not _q42 or text.length() > _h67:
		return text
	return _q42.sub(text, "[color=#%s]$1[/color]" % _a52.string.to_html(false), true)
func _o61(text: String) -> String:
	if not _h84 or text.length() > _h67:
		return text
	return _h84.sub(text, "[color=#%s]$1[/color]" % _a52.keyword.to_html(false), true)
func _v99(text: String) -> String:
	if not _e89 or text.length() > _h67:
		return text
	return _e89.sub(text, "[color=#%s]$0[/color]" % _a52.number.to_html(false), true)
func _n8(text: String) -> String:
	if not _z66 or text.length() > _h67:
		return text
	return _z66.sub(text, "[color=#%s]$1[/color](" % _a52.function.to_html(false), true)
func _o16():
	hide()
	var _n84 = {
		"original_code": _l11,
		"refactored_code": _p54,
		"function_name": _p91,
		"file_path": _r42,
		"prompt": _o55,
		"timestamp": Time.get_unix_time_from_system()
	}
	_d76.emit(_n84)
	_p51.emit(_p54, _p91)
func _p62():
	hide()
	_t68.emit(_p91)
func _s52():
	_f69 = not _f69
	_x72.text = "Switch to Side-by-Side" if not _f69 else "Switch to Unified"
	_e20()
func _z75():
	if is_inside_tree():
		hide()
func _a97():
	if not OS.is_debug_build():
		return
func _notification(_h4: int):
	match _h4:
		Control.NOTIFICATION_RESIZED:
			_n36()
		Control.NOTIFICATION_VISIBILITY_CHANGED:
			if visible and is_inside_tree():
				_k10.call_deferred()
func _n36():
	if not is_inside_tree() or not _o33:
		return
	_i60()
	_t55()
	if not _l11.is_empty() and not _p54.is_empty():
		_d30()
func _t55():
	if not is_inside_tree() or not _o33:
		return
	_o33.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_o33.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for _i64 in _o33.get_children():
		if _i64.name == "SideBySideContainer" and _i64 is HBoxContainer:
			_i64.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_i64.size_flags_vertical = Control.SIZE_EXPAND_FILL
			for _n68 in _i64.get_children():
				if _n68 is VBoxContainer:
					_n68.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					_n68.size_flags_vertical = Control.SIZE_EXPAND_FILL
					for _f28 in _n68.get_children():
						if _f28 is ScrollContainer:
							_f28.size_flags_horizontal = Control.SIZE_EXPAND_FILL
							_f28.size_flags_vertical = Control.SIZE_EXPAND_FILL
		elif _i64.name == "UnifiedContainer" and _i64 is ScrollContainer:
			_i64.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_i64.size_flags_vertical = Control.SIZE_EXPAND_FILL
func _k10():
	if not is_inside_tree():
		return
	_t55()
	if not _l11.is_empty() and not _p54.is_empty():
		_d30()
func _d30():
	var _f21 = _k37(_t97)
	for _m46 in [_g85, _c98, _e94]:
		if _m46 and is_instance_valid(_m46):
			for _q63 in _m46.get_children():
				if _q63 and is_instance_valid(_q63):
					for node in _y83(_q63):
						if node is RichTextLabel:
							node.add_theme_font_size_override("normal_font_size", _f21)
							_p66(node)
						elif node is Label:
							node.add_theme_font_size_override("font_size", _f21)
func _y83(node: Node) -> Array:
	var children = []
	for _i64 in node.get_children():
		children.append(_i64)
		children.append_array(_y83(_i64))
	return children
func _p66(_l62: RichTextLabel):
	if not _l62 or not is_instance_valid(_l62):
		return
	_l62.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_l62.custom_minimum_size.y = int(32 * _c46)
func _k37(_l67: int) -> int:
	var _e37 = int(_l67 * _x27)
	return max(_e37, 12)
func _i60():
	if not is_inside_tree():
		return
	var _u43 = find_child("_n17")
	if _u43 and _u43 is Label:
		_u43.add_theme_font_size_override("font_size", _k37(16))
	if _z14:
		_z14.add_theme_font_size_override("font_size", _k37(14))
	var _w75 = find_child("_x14")
	if _w75 and _w75 is Label:
		_w75.add_theme_font_size_override("font_size", _k37(14))
	var _j72 = find_child("_w29")
	if _j72 and _j72 is Label:
		_j72.add_theme_font_size_override("font_size", _k37(14))
