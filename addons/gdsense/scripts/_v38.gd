@tool
class_name _s12
extends AcceptDialog
signal _t38(refactored_code: String, function_name: String)
signal _l59(function_name: String)
signal _x74(data: Dictionary)
const _q14 = 5000
const _e29 = 10000
const _i58 = 1048576  
const _c54 = 100
var _n24: String
var _e39: String
var _j78: String
var _m57: String
var _k80: String
var _c20: Control
var _b95: Button
var _g39: Button
var _u52: Button
var _t71: bool = true
var _d53: Label
enum _n9 {
	_v99,
	_q82
}
var _c66: _n9
var _m61: float = 1.0
var _p78: float = 1.0  
var _c9: int = 16  
var _j6: ScrollContainer
var _y43: ScrollContainer
var _v11: VBoxContainer
var _v75: VBoxContainer
var _r9: VBoxContainer
var _h23 = {
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
func _r21() -> Color:
	if has_theme_color("font_color", "Editor"):
		return get_theme_color("font_color", "Editor")
	return Color(0.7, 0.7, 0.7)  
func _n42() -> Color:
	if has_theme_color("font_color", "Editor"):
		var font_color = get_theme_color("font_color", "Editor")
		return Color(font_color.r * 0.6, font_color.g * 0.6, font_color.b * 0.6, font_color.a)
	return Color(0.5, 0.5, 0.5)  
func _x81() -> Color:
	if has_theme_color("base_color", "Editor"):
		var _j48 = get_theme_color("base_color", "Editor")
		return Color(_j48.r, _j48.g, _j48.b, 0.3)
	return Color(0.15, 0.15, 0.15, 0.3)  
func _b86():
	var _z13 = get_theme_color("base_color", "Editor") if has_theme_color("base_color", "Editor") else Color(0.2, 0.2, 0.2)
	var _q53 = _z13.get_luminance() > 0.5
	if _q53:
		_h23["comment"] = Color(0.4, 0.5, 0.4)  
		_h23["string"] = Color(0.6, 0.3, 0.1)   
		_h23["number"] = Color(0.1, 0.3, 0.6)   
		_h23["keyword"] = Color(0.6, 0.1, 0.4)  
		_h23["class"] = Color(0.1, 0.5, 0.2)    
		_h23["function"] = Color(0.1, 0.3, 0.6) 
		_h23["symbol"] = Color(0.2, 0.2, 0.2)   
	else:
		_h23["comment"] = Color.GRAY
		_h23["string"] = Color.ORANGE
		_h23["number"] = Color.SKY_BLUE
		_h23["keyword"] = Color.PALE_VIOLET_RED
		_h23["class"] = Color.LIGHT_GREEN
		_h23["function"] = Color.LIGHT_BLUE
		_h23["symbol"] = Color.WHITE
const _g18 = [
	"if", "elif", "else", "for", "while", "match", "break", "continue", "pass",
	"return", "class", "extends", "is", "as", "self", "super", "func", "signal",
	"const", "var", "static", "enum", "in", "not", "and", "or", "true", "false",
	"null", "export", "onready", "tool", "setget", "breakpoint", "preload", "yield",
	"assert", "remote", "sync", "master", "puppet", "@export", "@onready", "@tool"
]
var _b4: RegEx
var _b99: RegEx
var _e83: RegEx
var _f73: RegEx
var _s59: RegEx
func _init():
	_k2()
func _k2():
	_b4 = RegEx.new()
	if _b4.compile("#.*$") != OK:
		push_error("Failed to compile comment regex")
		_b4 = null
	_b99 = RegEx.new()
	if _b99.compile("(\"[^\"]*\"|'[^']*')") != OK:
		push_error("Failed to compile string regex")
		_b99 = null
	_e83 = RegEx.new()
	var _p41 = "\\b(" + "|".join(_g18) + ")\\b"
	if _e83.compile(_p41) != OK:
		push_error("Failed to compile keyword regex")
		_e83 = null
	_f73 = RegEx.new()
	if _f73.compile("\\b\\d+(\\.\\d+)?\\b") != OK:
		push_error("Failed to compile number regex")
		_f73 = null
	_s59 = RegEx.new()
	if _s59.compile("\\b([a-z_][a-zA-Z0-9_]*)\\s*\\(") != OK:
		push_error("Failed to compile function regex")
		_s59 = null
func _ready():
	get_ok_button().hide()
	_m70()
	_b86()
	if not confirmed.is_connected(_b89):
		confirmed.connect(_b89)
	_y66()
	_d63()
	_u60()
	_l58.call_deferred()
func _m70():
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		var _t4 = config.get_value("font_scale", "mode", "auto")
		if _t4 == "auto":
			var _e95 = DisplayServer.screen_get_size()
			var _n100 = _e95.y
			if _n100 >= 2160:  
				_p78 = 1.5
			elif _n100 >= 1440:  
				_p78 = 1.25
			else:  
				_p78 = 1.0
		else:
			_p78 = float(_t4)
	else:
		_p78 = 1.0
func _y66():
	if not is_inside_tree():
		return
	_u52 = %_k75
	_d53 = %_h70  
	_c20 = %_c7
	_b95 = %_k81
	_g39 = %_x65
	_j6 = %_r7
	_y43 = %_x15
	_v11 = %_g19
	_v75 = %_h89
	_r9 = %_p7
	if _u52 and not _u52.pressed.is_connected(_y20):
		_u52.pressed.connect(_y20)
	if _b95 and not _b95.pressed.is_connected(_b89):
		_b95.pressed.connect(_b89)
	if _g39 and not _g39.pressed.is_connected(_s35):
		_g39.pressed.connect(_s35)
	if _j6 and _y43:
		var _f39 = _j6.get_v_scroll_bar()
		var _a41 = _y43.get_v_scroll_bar()
		if not _f39.value_changed.is_connected(_x40):
			_f39.value_changed.connect(_x40)
		if not _a41.value_changed.is_connected(_r91):
			_a41.value_changed.connect(_r91)
func _d63():
	_t71 = true
	_c66 = _n9._v99
func _v45():
	if _v11 and _v75 and _r9:
		if is_instance_valid(_v11) and is_instance_valid(_v75) and is_instance_valid(_r9):
			return
	_v11 = %_g19
	_v75 = %_h89
	_r9 = %_p7
	_j6 = %_r7
	_y43 = %_x15
	if not _v11 or not _v75 or not _r9:
		pass
func _t59(function_name: String, original_code: String, refactored_code: String, file_path: String = "", prompt: String = ""):
	var _b94 = original_code.length() + refactored_code.length()
	if _b94 > _i58:
		push_error("Total input size exceeds maximum allowed size of %d bytes" % _i58)
		return
	if original_code.length() > _e29 * _q14:
		push_error("Original code exceeds maximum allowed size")
		return
	if refactored_code.length() > _e29 * _q14:
		push_error("Refactored code exceeds maximum allowed size")
		return
	var _p66 = original_code.split("\n")
	var _j91 = refactored_code.split("\n")
	if _p66.size() > _q14 or _j91.size() > _q14:
		push_error("Code exceeds maximum line limit of %d" % _q14)
		return
	_j78 = function_name
	_n24 = original_code
	_e39 = refactored_code
	_m57 = file_path
	_k80 = prompt
	if not is_inside_tree():
		var _d84 = Engine.get_singleton("EditorInterface")
		if _d84:
			var _g62 = _d84.get_base_control()
			if _g62:
				_g62.add_child(self)
			else:
				pass
	_j66.call_deferred()
func _x37():
	if not _u52:
		_y66()
		_v45()
func _j66():
	if not is_inside_tree():
		return
	_m70()
	_b86()
	_u60()
	popup_centered()
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_l58()
	_x37()
	if _d53:
		_d53.text = "Function: %s" % _j78
	else:
		pass
	_n16()
func _n16():
	if not _v11 or not _v75 or not _r9:
		return
	if _n24.is_empty() or _e39.is_empty():
		return
	if _t71:
		_z81()
	else:
		_t80()
func _k58(_p66: PackedStringArray, _j91: PackedStringArray) -> Array:
	var _c39 = []
	var _e99 = 0
	var _v21 = 0
	while _e99 < _p66.size() or _v21 < _j91.size():
		if _e99 >= _p66.size():
			_c39.append({
				"type": "added", 
				"line": _j91[_v21],
				"original_line_num": -1,
				"refactored_line_num": _v21 + 1
			})
			_v21 += 1
		elif _v21 >= _j91.size():
			_c39.append({
				"type": "removed", 
				"line": _p66[_e99],
				"original_line_num": _e99 + 1,
				"refactored_line_num": -1
			})
			_e99 += 1
		elif _p66[_e99] == _j91[_v21]:
			_c39.append({
				"type": "context", 
				"line": _p66[_e99],
				"original_line_num": _e99 + 1,
				"refactored_line_num": _v21 + 1
			})
			_e99 += 1
			_v21 += 1
		else:
			_c39.append({
				"type": "removed", 
				"line": _p66[_e99],
				"original_line_num": _e99 + 1,
				"refactored_line_num": -1
			})
			_c39.append({
				"type": "added", 
				"line": _j91[_v21],
				"original_line_num": -1,
				"refactored_line_num": _v21 + 1
			})
			_e99 += 1
			_v21 += 1
	return _c39
func _f96(_e77: Dictionary, _y6: VBoxContainer):
	var _g55 = PanelContainer.new()
	_g55.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _c21 = StyleBoxFlat.new()
	var prefix = ""
	var _x4 = _r21()
	match _e77.type:
		"added":
			_c21.bg_color = _h23.added_bg
			prefix = "+ "
			_x4 = _h23.added
		"removed":
			_c21.bg_color = _h23.removed_bg
			prefix = "- "
			_x4 = _h23.removed
		"context":
			_c21.bg_color = _x81()
			prefix = "  "
			_x4 = _r21()
	_c21.content_margin_left = 8
	_c21.content_margin_right = 8
	_c21.content_margin_top = 2
	_c21.content_margin_bottom = 2
	_g55.add_theme_stylebox_override("panel", _c21)
	var _e45 = HBoxContainer.new()
	var _g70 = Label.new()
	var _e5 = ""
	if _e77.original_line_num > 0 and _e77.refactored_line_num > 0:
		_e5 = "%d:%d" % [_e77.original_line_num, _e77.refactored_line_num]
	elif _e77.original_line_num > 0:
		_e5 = "%d:-" % _e77.original_line_num
	else:
		_e5 = "-:%d" % _e77.refactored_line_num
	_g70.text = _e5
	_g70.custom_minimum_size = Vector2(80, 0)
	_g70.add_theme_color_override("font_color", _n42())
	_g70.add_theme_font_size_override("font_size", _m34(_c9 - 2))
	var _c90 = SystemFont.new()
	_c90.font_names = ["Consolas", "Courier New", "Monospace"]
	_g70.add_theme_font_override("font", _c90)
	_e45.add_child(_g70)
	var _s78 = RichTextLabel.new()
	_s78.bbcode_enabled = true
	_s78.selection_enabled = true
	_s78.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_s78.size_flags_vertical = Control.SIZE_EXPAND_FILL  
	_s78.fit_content = false  
	_s78.scroll_active = true  
	_s78.autowrap_mode = TextServer.AUTOWRAP_OFF  
	_s78.custom_minimum_size = Vector2(400, int(32 * _m61))  
	var _n99 = _t49(_e77.line)
	_s78.text = prefix + _n99
	_s78.add_theme_font_override("normal_font", _c90)
	_s78.add_theme_font_override("mono_font", _c90)
	_s78.add_theme_color_override("default_color", _x4)
	_s78.add_theme_font_size_override("normal_font_size", _m34(_c9))
	_e45.add_child(_s78)
	_g55.add_child(_e45)
	_g55.custom_minimum_size = Vector2(0, int(36 * _m61))  
	_g55.size_flags_vertical = Control.SIZE_EXPAND_FILL  
	_y6.add_child(_g55)
	_p6(_s78)
	if _g55.is_inside_tree():
		_g55.queue_redraw()
func _z81():
	_v45()
	_o88()
	var _q87 = %_c27
	var _u67 = %_n2
	if _q87:
		_q87.visible = true
	if _u67:
		_u67.visible = false
	if not _v11 or not _v75:
		return
	if not is_instance_valid(_v11) or not is_instance_valid(_v75):
		return
	var _p66 = _n24.split("\n")
	var _j91 = _e39.split("\n")
	if _p66.size() > _q14:
		_p66.resize(_q14)
	if _j91.size() > _q14:
		_j91.resize(_q14)
	var _u89 = max(_p66.size(), _j91.size())
	for i in range(_u89):
		var _s10 = _p66[i] if i < _p66.size() else ""
		var _t54 = _j91[i] if i < _j91.size() else ""
		var _y26 = "context"
		var _w29 = "context"
		if i >= _p66.size():
			_y26 = "empty"
			_w29 = "added"
		elif i >= _j91.size():
			_y26 = "removed" 
			_w29 = "empty"
		elif _s10 != _t54:
			_y26 = "removed"
			_w29 = "added"
		if _v11 and _v75:
			_n92(_s10, i + 1, _y26, _v11, true)
			_n92(_t54, i + 1, _w29, _v75, false)
		else:
			return
	if is_inside_tree():
		if _j6 and is_instance_valid(_j6):
			_j6.queue_redraw()
			_j6.notification(Control.NOTIFICATION_RESIZED)
			_j6.queue_sort()
		if _y43 and is_instance_valid(_y43):
			_y43.queue_redraw()
			_y43.notification(Control.NOTIFICATION_RESIZED)
			_y43.queue_sort()
		if _v11 and is_instance_valid(_v11):
			_v11.queue_redraw()
			_v11.queue_sort()
		if _v75 and is_instance_valid(_v75):
			_v75.queue_redraw()
			_v75.queue_sort()
func _t80():
	_v45()
	_o88()
	var _q87 = %_c27
	var _u67 = %_n2
	if _q87:
		_q87.visible = false
	if _u67:
		_u67.visible = true
	if not _r9:
		return
	var _p66 = _n24.split("\n")
	var _j91 = _e39.split("\n")
	var _o92 = _k58(_p66, _j91)
	for _e77 in _o92:
		_f96(_e77, _r9)
func _n92(content: String, _w41: int, _x71: String, _y6: VBoxContainer, _y53: bool):
	if not is_instance_valid(_y6):
		return
	if content.length() > _e29:
		content = content.substr(0, _e29) + "... [TRUNCATED]"
	var _g55 = PanelContainer.new()
	_g55.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_g55.size_flags_vertical = Control.SIZE_EXPAND_FILL  
	_g55.custom_minimum_size = Vector2(0, int(36 * _m61))  
	var _c21 = StyleBoxFlat.new()
	var _x4 = _r21()
	match _x71:
		"added":
			_c21.bg_color = _h23.added_bg
			_x4 = _h23.added
		"removed":
			_c21.bg_color = _h23.removed_bg
			_x4 = _h23.removed
		"empty":
			_c21.bg_color = _x81()
			_x4 = _n42()  
		"context":
			_c21.bg_color = _x81()
			_x4 = _r21()
	_c21.content_margin_left = 8
	_c21.content_margin_right = 8
	_c21.content_margin_top = 2
	_c21.content_margin_bottom = 2
	_g55.add_theme_stylebox_override("panel", _c21)
	var _e45 = HBoxContainer.new()
	_e45.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_e45.size_flags_vertical = Control.SIZE_EXPAND_FILL  
	var _g70 = Label.new()
	if _x71 == "empty":
		_g70.text = ""
	else:
		_g70.text = str(_w41)
	_g70.custom_minimum_size = Vector2(50, 0)
	_g70.add_theme_color_override("font_color", _n42())
	_g70.add_theme_font_size_override("font_size", _m34(_c9 - 2))
	var _c90 = SystemFont.new()
	_c90.font_names = ["Consolas", "Courier New", "Monospace"]
	_g70.add_theme_font_override("font", _c90)
	_e45.add_child(_g70)
	var _s78 = RichTextLabel.new()
	_s78.bbcode_enabled = true
	_s78.selection_enabled = true
	_s78.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_s78.size_flags_vertical = Control.SIZE_EXPAND_FILL  
	_s78.custom_minimum_size = Vector2(400, int(30 * _m61))  
	_s78.fit_content = false  
	_s78.scroll_active = true  
	_s78.autowrap_mode = TextServer.AUTOWRAP_OFF  
	_s78.clip_contents = true  
	_s78.scroll_following = false  
	if _x71 == "empty":
		_s78.text = " "  
	else:
		var _n99 = _t49(content) if not content.is_empty() else content
		_s78.text = _n99
	_s78.add_theme_font_override("normal_font", _c90)
	_s78.add_theme_font_override("mono_font", _c90)
	_s78.add_theme_color_override("default_color", _x4)
	_s78.add_theme_font_size_override("normal_font_size", _m34(_c9))
	_e45.add_child(_s78)
	_g55.add_child(_e45)
	_y6.add_child(_g55)
	_g55.visible = true
	_e45.visible = true
	_s78.visible = true
	_g70.visible = true
	_p6(_s78)
	if _y6.is_inside_tree():
		_y6.queue_redraw()
		var _g22 = _y6.get_parent()
		if _g22 and _g22 is ScrollContainer:
			_g22.queue_redraw()
			_g22.notification(Control.NOTIFICATION_RESIZED)
func _o88():
	if _v11 and is_instance_valid(_v11):
		var children = _v11.get_children()
		for _h61 in children:
			if is_instance_valid(_h61):
				_v11.remove_child(_h61)
				_h61.queue_free()
	if _v75 and is_instance_valid(_v75):
		var children = _v75.get_children()
		for _h61 in children:
			if is_instance_valid(_h61):
				_v75.remove_child(_h61)
				_h61.queue_free()
	if _r9 and is_instance_valid(_r9):
		var children = _r9.get_children()
		for _h61 in children:
			if is_instance_valid(_h61):
				_r9.remove_child(_h61)
				_h61.queue_free()
func _x40(value: float):
	if _y43 and _y43.get_v_scroll_bar().value != value:
		_y43.get_v_scroll_bar().value = value
func _r91(value: float):
	if _j6 and _j6.get_v_scroll_bar().value != value:
		_j6.get_v_scroll_bar().value = value
func _t49(line: String) -> String:
	if line.strip_edges().is_empty():
		return line
	return line
func _x46(text: String) -> String:
	if not _b4 or text.length() > _e29:
		return text
	return _b4.sub(text, "[color=#%s]$0[/color]" % _h23.comment.to_html(false), true)
func _l61(text: String) -> String:
	if not _b99 or text.length() > _e29:
		return text
	return _b99.sub(text, "[color=#%s]$1[/color]" % _h23.string.to_html(false), true)
func _d24(text: String) -> String:
	if not _e83 or text.length() > _e29:
		return text
	return _e83.sub(text, "[color=#%s]$1[/color]" % _h23.keyword.to_html(false), true)
func _c56(text: String) -> String:
	if not _f73 or text.length() > _e29:
		return text
	return _f73.sub(text, "[color=#%s]$0[/color]" % _h23.number.to_html(false), true)
func _f11(text: String) -> String:
	if not _s59 or text.length() > _e29:
		return text
	return _s59.sub(text, "[color=#%s]$1[/color](" % _h23.function.to_html(false), true)
func _b89():
	hide()
	var _n86 = {
		"original_code": _n24,
		"refactored_code": _e39,
		"function_name": _j78,
		"file_path": _m57,
		"prompt": _k80,
		"timestamp": Time.get_unix_time_from_system()
	}
	_x74.emit(_n86)
	_t38.emit(_e39, _j78)
func _s35():
	hide()
	_l59.emit(_j78)
func _y20():
	_t71 = not _t71
	_u52.text = "Switch to Side-by-Side" if not _t71 else "Switch to Unified"
	_n16()
func _c96():
	if is_inside_tree():
		hide()
func _o2():
	if not OS.is_debug_build():
		return
func _notification(_a3: int):
	match _a3:
		Control.NOTIFICATION_RESIZED:
			_x98()
		Control.NOTIFICATION_VISIBILITY_CHANGED:
			if visible and is_inside_tree():
				_s73.call_deferred()
func _x98():
	if not is_inside_tree() or not _c20:
		return
	_u60()
	_l58()
	if not _n24.is_empty() and not _e39.is_empty():
		_y27()
func _l58():
	if not is_inside_tree() or not _c20:
		return
	_c20.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_c20.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for _h61 in _c20.get_children():
		if _h61.name == "SideBySideContainer" and _h61 is HBoxContainer:
			_h61.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_h61.size_flags_vertical = Control.SIZE_EXPAND_FILL
			for _u27 in _h61.get_children():
				if _u27 is VBoxContainer:
					_u27.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					_u27.size_flags_vertical = Control.SIZE_EXPAND_FILL
					for _j24 in _u27.get_children():
						if _j24 is ScrollContainer:
							_j24.size_flags_horizontal = Control.SIZE_EXPAND_FILL
							_j24.size_flags_vertical = Control.SIZE_EXPAND_FILL
		elif _h61.name == "UnifiedContainer" and _h61 is ScrollContainer:
			_h61.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_h61.size_flags_vertical = Control.SIZE_EXPAND_FILL
func _s73():
	if not is_inside_tree():
		return
	_l58()
	if not _n24.is_empty() and not _e39.is_empty():
		_y27()
func _y27():
	var _k71 = _m34(_c9)
	for _y6 in [_v11, _v75, _r9]:
		if _y6 and is_instance_valid(_y6):
			for _g55 in _y6.get_children():
				if _g55 and is_instance_valid(_g55):
					for node in _l75(_g55):
						if node is RichTextLabel:
							node.add_theme_font_size_override("normal_font_size", _k71)
							_p6(node)
						elif node is Label:
							node.add_theme_font_size_override("font_size", _k71)
func _l75(node: Node) -> Array:
	var children = []
	for _h61 in node.get_children():
		children.append(_h61)
		children.append_array(_l75(_h61))
	return children
func _p6(_m24: RichTextLabel):
	if not _m24 or not is_instance_valid(_m24):
		return
	_m24.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_m24.custom_minimum_size.y = int(32 * _m61)
func _m34(_e58: int) -> int:
	var _b16 = int(_e58 * _p78)
	return max(_b16, 12)
func _u60():
	if not is_inside_tree():
		return
	var _f82 = find_child("_d42")
	if _f82 and _f82 is Label:
		_f82.add_theme_font_size_override("font_size", _m34(16))
	if _d53:
		_d53.add_theme_font_size_override("font_size", _m34(14))
	var _d92 = find_child("_w23")
	if _d92 and _d92 is Label:
		_d92.add_theme_font_size_override("font_size", _m34(14))
	var _u95 = find_child("_e61")
	if _u95 and _u95 is Label:
		_u95.add_theme_font_size_override("font_size", _m34(14))
