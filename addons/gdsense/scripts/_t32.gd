@tool
class_name _y30
extends AcceptDialog
signal _e61(refactored_code: String, function_name: String)
signal _g76(function_name: String)
signal _i92(data: Dictionary)
const _r55 = 5000
const _j54 = 10000
const _h65 = 1048576  
const _h70 = 100
var _y93: String
var _a4: String
var _j57: String
var _n98: String
var _w93: String
var _d57: Control
var _n93: Button
var _h47: Button
var _q18: Button
var _n82: bool = true
var _a90: Label
enum _g13 {
	_t22,
	_f57
}
var _o11: _g13
var _d27: float = 1.0
var _v32: float = 1.0  
var _v86: int = 16  
var _w63: ScrollContainer
var _r32: ScrollContainer
var _c76: VBoxContainer
var _c43: VBoxContainer
var _a3: VBoxContainer
var _h12 = {
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
func _k55() -> Color:
	if has_theme_color("font_color", "Editor"):
		return get_theme_color("font_color", "Editor")
	return Color(0.7, 0.7, 0.7)  
func _t55() -> Color:
	if has_theme_color("font_color", "Editor"):
		var font_color = get_theme_color("font_color", "Editor")
		return Color(font_color.r * 0.6, font_color.g * 0.6, font_color.b * 0.6, font_color.a)
	return Color(0.5, 0.5, 0.5)  
func _m73() -> Color:
	if has_theme_color("base_color", "Editor"):
		var _a42 = get_theme_color("base_color", "Editor")
		return Color(_a42.r, _a42.g, _a42.b, 0.3)
	return Color(0.15, 0.15, 0.15, 0.3)  
func _i37():
	var _v22 = get_theme_color("base_color", "Editor") if has_theme_color("base_color", "Editor") else Color(0.2, 0.2, 0.2)
	var _b21 = _v22.get_luminance() > 0.5
	if _b21:
		_h12["comment"] = Color(0.4, 0.5, 0.4)  
		_h12["string"] = Color(0.6, 0.3, 0.1)   
		_h12["number"] = Color(0.1, 0.3, 0.6)   
		_h12["keyword"] = Color(0.6, 0.1, 0.4)  
		_h12["class"] = Color(0.1, 0.5, 0.2)    
		_h12["function"] = Color(0.1, 0.3, 0.6) 
		_h12["symbol"] = Color(0.2, 0.2, 0.2)   
	else:
		_h12["comment"] = Color.GRAY
		_h12["string"] = Color.ORANGE
		_h12["number"] = Color.SKY_BLUE
		_h12["keyword"] = Color.PALE_VIOLET_RED
		_h12["class"] = Color.LIGHT_GREEN
		_h12["function"] = Color.LIGHT_BLUE
		_h12["symbol"] = Color.WHITE
const _q49 = [
	"if", "elif", "else", "for", "while", "match", "break", "continue", "pass",
	"return", "class", "extends", "is", "as", "self", "super", "func", "signal",
	"const", "var", "static", "enum", "in", "not", "and", "or", "true", "false",
	"null", "export", "onready", "tool", "setget", "breakpoint", "preload", "yield",
	"assert", "remote", "sync", "master", "puppet", "@export", "@onready", "@tool"
]
var _x49: RegEx
var _g82: RegEx
var _z18: RegEx
var _v61: RegEx
var _c18: RegEx
func _init():
	_h100()
func _h100():
	_x49 = RegEx.new()
	if _x49.compile("#.*$") != OK:
		push_error("Failed to compile comment regex")
		_x49 = null
	_g82 = RegEx.new()
	if _g82.compile("(\"[^\"]*\"|'[^']*')") != OK:
		push_error("Failed to compile string regex")
		_g82 = null
	_z18 = RegEx.new()
	var _d98 = "\\b(" + "|".join(_q49) + ")\\b"
	if _z18.compile(_d98) != OK:
		push_error("Failed to compile keyword regex")
		_z18 = null
	_v61 = RegEx.new()
	if _v61.compile("\\b\\d+(\\.\\d+)?\\b") != OK:
		push_error("Failed to compile number regex")
		_v61 = null
	_c18 = RegEx.new()
	if _c18.compile("\\b([a-z_][a-zA-Z0-9_]*)\\s*\\(") != OK:
		push_error("Failed to compile function regex")
		_c18 = null
func _ready():
	get_ok_button().hide()
	_v11()
	_i37()
	if not confirmed.is_connected(_o54):
		confirmed.connect(_o54)
	_x75()
	_c74()
	_y9()
	_r5.call_deferred()
func _v11():
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		var _k30 = config.get_value("font_scale", "mode", "auto")
		if _k30 == "auto":
			var _k38 = DisplayServer.screen_get_size()
			var _v76 = _k38.y
			if _v76 >= 2160:  
				_v32 = 1.5
			elif _v76 >= 1440:  
				_v32 = 1.25
			else:  
				_v32 = 1.0
		else:
			_v32 = float(_k30)
	else:
		_v32 = 1.0
func _x75():
	if not is_inside_tree():
		return
	_q18 = %_d70
	_a90 = %_k86  
	_d57 = %_s97
	_n93 = %_m34
	_h47 = %_k56
	_w63 = %_o46
	_r32 = %_o60
	_c76 = %_n83
	_c43 = %_s27
	_a3 = %_i42
	if _q18 and not _q18.pressed.is_connected(_s85):
		_q18.pressed.connect(_s85)
	if _n93 and not _n93.pressed.is_connected(_o54):
		_n93.pressed.connect(_o54)
	if _h47 and not _h47.pressed.is_connected(_b88):
		_h47.pressed.connect(_b88)
	if _w63 and _r32:
		var _g66 = _w63.get_v_scroll_bar()
		var _h30 = _r32.get_v_scroll_bar()
		if not _g66.value_changed.is_connected(_m17):
			_g66.value_changed.connect(_m17)
		if not _h30.value_changed.is_connected(_i80):
			_h30.value_changed.connect(_i80)
func _c74():
	_n82 = true
	_o11 = _g13._t22
func _t28():
	if _c76 and _c43 and _a3:
		if is_instance_valid(_c76) and is_instance_valid(_c43) and is_instance_valid(_a3):
			return
	_c76 = %_n83
	_c43 = %_s27
	_a3 = %_i42
	_w63 = %_o46
	_r32 = %_o60
	if not _c76 or not _c43 or not _a3:
		pass
func _f77(function_name: String, original_code: String, refactored_code: String, file_path: String = "", prompt: String = ""):
	var _e48 = original_code.length() + refactored_code.length()
	if _e48 > _h65:
		push_error("Total input size exceeds maximum allowed size of %d bytes" % _h65)
		return
	if original_code.length() > _j54 * _r55:
		push_error("Original code exceeds maximum allowed size")
		return
	if refactored_code.length() > _j54 * _r55:
		push_error("Refactored code exceeds maximum allowed size")
		return
	var _z28 = original_code.split("\n")
	var _q79 = refactored_code.split("\n")
	if _z28.size() > _r55 or _q79.size() > _r55:
		push_error("Code exceeds maximum line limit of %d" % _r55)
		return
	_j57 = function_name
	_y93 = original_code
	_a4 = refactored_code
	_n98 = file_path
	_w93 = prompt
	if not is_inside_tree():
		var _k71 = Engine.get_singleton("EditorInterface")
		if _k71:
			var _v13 = _k71.get_base_control()
			if _v13:
				_v13.add_child(self)
			else:
				pass
	_e44.call_deferred()
func _o9():
	if not _q18:
		_x75()
		_t28()
func _e44():
	if not is_inside_tree():
		return
	_v11()
	_i37()
	_y9()
	popup_centered()
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_r5()
	_o9()
	if _a90:
		_a90.text = "Function: %s" % _j57
	else:
		pass
	_p11()
func _p11():
	if not _c76 or not _c43 or not _a3:
		return
	if _y93.is_empty() or _a4.is_empty():
		return
	if _n82:
		_i89()
	else:
		_l60()
func _s5(_z28: PackedStringArray, _q79: PackedStringArray) -> Array:
	var _q12 = []
	var _c86 = 0
	var _x41 = 0
	while _c86 < _z28.size() or _x41 < _q79.size():
		if _c86 >= _z28.size():
			_q12.append({
				"type": "added", 
				"line": _q79[_x41],
				"original_line_num": -1,
				"refactored_line_num": _x41 + 1
			})
			_x41 += 1
		elif _x41 >= _q79.size():
			_q12.append({
				"type": "removed", 
				"line": _z28[_c86],
				"original_line_num": _c86 + 1,
				"refactored_line_num": -1
			})
			_c86 += 1
		elif _z28[_c86] == _q79[_x41]:
			_q12.append({
				"type": "context", 
				"line": _z28[_c86],
				"original_line_num": _c86 + 1,
				"refactored_line_num": _x41 + 1
			})
			_c86 += 1
			_x41 += 1
		else:
			_q12.append({
				"type": "removed", 
				"line": _z28[_c86],
				"original_line_num": _c86 + 1,
				"refactored_line_num": -1
			})
			_q12.append({
				"type": "added", 
				"line": _q79[_x41],
				"original_line_num": -1,
				"refactored_line_num": _x41 + 1
			})
			_c86 += 1
			_x41 += 1
	return _q12
func _k25(_k27: Dictionary, _g11: VBoxContainer):
	var _p40 = PanelContainer.new()
	_p40.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _s48 = StyleBoxFlat.new()
	var prefix = ""
	var _o93 = _k55()
	match _k27.type:
		"added":
			_s48.bg_color = _h12.added_bg
			prefix = "+ "
			_o93 = _h12.added
		"removed":
			_s48.bg_color = _h12.removed_bg
			prefix = "- "
			_o93 = _h12.removed
		"context":
			_s48.bg_color = _m73()
			prefix = "  "
			_o93 = _k55()
	_s48.content_margin_left = 8
	_s48.content_margin_right = 8
	_s48.content_margin_top = 2
	_s48.content_margin_bottom = 2
	_p40.add_theme_stylebox_override("panel", _s48)
	var _a61 = HBoxContainer.new()
	var _j56 = Label.new()
	var _w6 = ""
	if _k27.original_line_num > 0 and _k27.refactored_line_num > 0:
		_w6 = "%d:%d" % [_k27.original_line_num, _k27.refactored_line_num]
	elif _k27.original_line_num > 0:
		_w6 = "%d:-" % _k27.original_line_num
	else:
		_w6 = "-:%d" % _k27.refactored_line_num
	_j56.text = _w6
	_j56.custom_minimum_size = Vector2(80, 0)
	_j56.add_theme_color_override("font_color", _t55())
	_j56.add_theme_font_size_override("font_size", _d43(_v86 - 2))
	var _q84 = SystemFont.new()
	_q84.font_names = ["Consolas", "Courier New", "Monospace"]
	_j56.add_theme_font_override("font", _q84)
	_a61.add_child(_j56)
	var _h29 = RichTextLabel.new()
	_h29.bbcode_enabled = true
	_h29.selection_enabled = true
	_h29.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_h29.size_flags_vertical = Control.SIZE_EXPAND_FILL  
	_h29.fit_content = false  
	_h29.scroll_active = true  
	_h29.autowrap_mode = TextServer.AUTOWRAP_OFF  
	_h29.custom_minimum_size = Vector2(400, int(32 * _d27))  
	var _h96 = _h25(_k27.line)
	_h29.text = prefix + _h96
	_h29.add_theme_font_override("normal_font", _q84)
	_h29.add_theme_font_override("mono_font", _q84)
	_h29.add_theme_color_override("default_color", _o93)
	_h29.add_theme_font_size_override("normal_font_size", _d43(_v86))
	_a61.add_child(_h29)
	_p40.add_child(_a61)
	_p40.custom_minimum_size = Vector2(0, int(36 * _d27))  
	_p40.size_flags_vertical = Control.SIZE_EXPAND_FILL  
	_g11.add_child(_p40)
	_l28(_h29)
	if _p40.is_inside_tree():
		_p40.queue_redraw()
func _i89():
	_t28()
	_i79()
	var _x90 = %_t48
	var _t46 = %_r22
	if _x90:
		_x90.visible = true
	if _t46:
		_t46.visible = false
	if not _c76 or not _c43:
		return
	if not is_instance_valid(_c76) or not is_instance_valid(_c43):
		return
	var _z28 = _y93.split("\n")
	var _q79 = _a4.split("\n")
	if _z28.size() > _r55:
		_z28.resize(_r55)
	if _q79.size() > _r55:
		_q79.resize(_r55)
	var _x29 = max(_z28.size(), _q79.size())
	for i in range(_x29):
		var _t71 = _z28[i] if i < _z28.size() else ""
		var _y23 = _q79[i] if i < _q79.size() else ""
		var _s23 = "context"
		var _u17 = "context"
		if i >= _z28.size():
			_s23 = "empty"
			_u17 = "added"
		elif i >= _q79.size():
			_s23 = "removed" 
			_u17 = "empty"
		elif _t71 != _y23:
			_s23 = "removed"
			_u17 = "added"
		if _c76 and _c43:
			_b58(_t71, i + 1, _s23, _c76, true)
			_b58(_y23, i + 1, _u17, _c43, false)
		else:
			return
	if is_inside_tree():
		if _w63 and is_instance_valid(_w63):
			_w63.queue_redraw()
			_w63.notification(Control.NOTIFICATION_RESIZED)
			_w63.queue_sort()
		if _r32 and is_instance_valid(_r32):
			_r32.queue_redraw()
			_r32.notification(Control.NOTIFICATION_RESIZED)
			_r32.queue_sort()
		if _c76 and is_instance_valid(_c76):
			_c76.queue_redraw()
			_c76.queue_sort()
		if _c43 and is_instance_valid(_c43):
			_c43.queue_redraw()
			_c43.queue_sort()
func _l60():
	_t28()
	_i79()
	var _x90 = %_t48
	var _t46 = %_r22
	if _x90:
		_x90.visible = false
	if _t46:
		_t46.visible = true
	if not _a3:
		return
	var _z28 = _y93.split("\n")
	var _q79 = _a4.split("\n")
	var _n21 = _s5(_z28, _q79)
	for _k27 in _n21:
		_k25(_k27, _a3)
func _b58(content: String, _e53: int, _x44: String, _g11: VBoxContainer, _l59: bool):
	if not is_instance_valid(_g11):
		return
	if content.length() > _j54:
		content = content.substr(0, _j54) + "... [TRUNCATED]"
	var _p40 = PanelContainer.new()
	_p40.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_p40.size_flags_vertical = Control.SIZE_EXPAND_FILL  
	_p40.custom_minimum_size = Vector2(0, int(36 * _d27))  
	var _s48 = StyleBoxFlat.new()
	var _o93 = _k55()
	match _x44:
		"added":
			_s48.bg_color = _h12.added_bg
			_o93 = _h12.added
		"removed":
			_s48.bg_color = _h12.removed_bg
			_o93 = _h12.removed
		"empty":
			_s48.bg_color = _m73()
			_o93 = _t55()  
		"context":
			_s48.bg_color = _m73()
			_o93 = _k55()
	_s48.content_margin_left = 8
	_s48.content_margin_right = 8
	_s48.content_margin_top = 2
	_s48.content_margin_bottom = 2
	_p40.add_theme_stylebox_override("panel", _s48)
	var _a61 = HBoxContainer.new()
	_a61.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_a61.size_flags_vertical = Control.SIZE_EXPAND_FILL  
	var _j56 = Label.new()
	if _x44 == "empty":
		_j56.text = ""
	else:
		_j56.text = str(_e53)
	_j56.custom_minimum_size = Vector2(50, 0)
	_j56.add_theme_color_override("font_color", _t55())
	_j56.add_theme_font_size_override("font_size", _d43(_v86 - 2))
	var _q84 = SystemFont.new()
	_q84.font_names = ["Consolas", "Courier New", "Monospace"]
	_j56.add_theme_font_override("font", _q84)
	_a61.add_child(_j56)
	var _h29 = RichTextLabel.new()
	_h29.bbcode_enabled = true
	_h29.selection_enabled = true
	_h29.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_h29.size_flags_vertical = Control.SIZE_EXPAND_FILL  
	_h29.custom_minimum_size = Vector2(400, int(30 * _d27))  
	_h29.fit_content = false  
	_h29.scroll_active = true  
	_h29.autowrap_mode = TextServer.AUTOWRAP_OFF  
	_h29.clip_contents = true  
	_h29.scroll_following = false  
	if _x44 == "empty":
		_h29.text = " "  
	else:
		var _h96 = _h25(content) if not content.is_empty() else content
		_h29.text = _h96
	_h29.add_theme_font_override("normal_font", _q84)
	_h29.add_theme_font_override("mono_font", _q84)
	_h29.add_theme_color_override("default_color", _o93)
	_h29.add_theme_font_size_override("normal_font_size", _d43(_v86))
	_a61.add_child(_h29)
	_p40.add_child(_a61)
	_g11.add_child(_p40)
	_p40.visible = true
	_a61.visible = true
	_h29.visible = true
	_j56.visible = true
	_l28(_h29)
	if _g11.is_inside_tree():
		_g11.queue_redraw()
		var _d52 = _g11.get_parent()
		if _d52 and _d52 is ScrollContainer:
			_d52.queue_redraw()
			_d52.notification(Control.NOTIFICATION_RESIZED)
func _i79():
	if _c76 and is_instance_valid(_c76):
		var children = _c76.get_children()
		for _x15 in children:
			if is_instance_valid(_x15):
				_c76.remove_child(_x15)
				_x15.queue_free()
	if _c43 and is_instance_valid(_c43):
		var children = _c43.get_children()
		for _x15 in children:
			if is_instance_valid(_x15):
				_c43.remove_child(_x15)
				_x15.queue_free()
	if _a3 and is_instance_valid(_a3):
		var children = _a3.get_children()
		for _x15 in children:
			if is_instance_valid(_x15):
				_a3.remove_child(_x15)
				_x15.queue_free()
func _m17(value: float):
	if _r32 and _r32.get_v_scroll_bar().value != value:
		_r32.get_v_scroll_bar().value = value
func _i80(value: float):
	if _w63 and _w63.get_v_scroll_bar().value != value:
		_w63.get_v_scroll_bar().value = value
func _h25(line: String) -> String:
	if line.strip_edges().is_empty():
		return line
	return line
func _i64(text: String) -> String:
	if not _x49 or text.length() > _j54:
		return text
	return _x49.sub(text, "[color=#%s]$0[/color]" % _h12.comment.to_html(false), true)
func _a22(text: String) -> String:
	if not _g82 or text.length() > _j54:
		return text
	return _g82.sub(text, "[color=#%s]$1[/color]" % _h12.string.to_html(false), true)
func _p39(text: String) -> String:
	if not _z18 or text.length() > _j54:
		return text
	return _z18.sub(text, "[color=#%s]$1[/color]" % _h12.keyword.to_html(false), true)
func _u23(text: String) -> String:
	if not _v61 or text.length() > _j54:
		return text
	return _v61.sub(text, "[color=#%s]$0[/color]" % _h12.number.to_html(false), true)
func _y87(text: String) -> String:
	if not _c18 or text.length() > _j54:
		return text
	return _c18.sub(text, "[color=#%s]$1[/color](" % _h12.function.to_html(false), true)
func _o54():
	hide()
	var _b71 = {
		"original_code": _y93,
		"refactored_code": _a4,
		"function_name": _j57,
		"file_path": _n98,
		"prompt": _w93,
		"timestamp": Time.get_unix_time_from_system()
	}
	_i92.emit(_b71)
	_e61.emit(_a4, _j57)
func _b88():
	hide()
	_g76.emit(_j57)
func _s85():
	_n82 = not _n82
	_q18.text = "Switch to Side-by-Side" if not _n82 else "Switch to Unified"
	_p11()
func _i4():
	if is_inside_tree():
		hide()
func _g91():
	if not OS.is_debug_build():
		return
func _notification(_u78: int):
	match _u78:
		Control.NOTIFICATION_RESIZED:
			_k21()
		Control.NOTIFICATION_VISIBILITY_CHANGED:
			if visible and is_inside_tree():
				_k69.call_deferred()
func _k21():
	if not is_inside_tree() or not _d57:
		return
	_y9()
	_r5()
	if not _y93.is_empty() and not _a4.is_empty():
		_i75()
func _r5():
	if not is_inside_tree() or not _d57:
		return
	_d57.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_d57.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for _x15 in _d57.get_children():
		if _x15.name == "SideBySideContainer" and _x15 is HBoxContainer:
			_x15.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_x15.size_flags_vertical = Control.SIZE_EXPAND_FILL
			for _e31 in _x15.get_children():
				if _e31 is VBoxContainer:
					_e31.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					_e31.size_flags_vertical = Control.SIZE_EXPAND_FILL
					for _m14 in _e31.get_children():
						if _m14 is ScrollContainer:
							_m14.size_flags_horizontal = Control.SIZE_EXPAND_FILL
							_m14.size_flags_vertical = Control.SIZE_EXPAND_FILL
		elif _x15.name == "UnifiedContainer" and _x15 is ScrollContainer:
			_x15.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_x15.size_flags_vertical = Control.SIZE_EXPAND_FILL
func _k69():
	if not is_inside_tree():
		return
	_r5()
	if not _y93.is_empty() and not _a4.is_empty():
		_i75()
func _i75():
	var _m53 = _d43(_v86)
	for _g11 in [_c76, _c43, _a3]:
		if _g11 and is_instance_valid(_g11):
			for _p40 in _g11.get_children():
				if _p40 and is_instance_valid(_p40):
					for node in _m2(_p40):
						if node is RichTextLabel:
							node.add_theme_font_size_override("normal_font_size", _m53)
							_l28(node)
						elif node is Label:
							node.add_theme_font_size_override("font_size", _m53)
func _m2(node: Node) -> Array:
	var children = []
	for _x15 in node.get_children():
		children.append(_x15)
		children.append_array(_m2(_x15))
	return children
func _l28(_p75: RichTextLabel):
	if not _p75 or not is_instance_valid(_p75):
		return
	_p75.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_p75.custom_minimum_size.y = int(32 * _d27)
func _d43(_g7: int) -> int:
	var _m40 = int(_g7 * _v32)
	return max(_m40, 12)
func _y9():
	if not is_inside_tree():
		return
	var _t86 = find_child("_w80")
	if _t86 and _t86 is Label:
		_t86.add_theme_font_size_override("font_size", _d43(16))
	if _a90:
		_a90.add_theme_font_size_override("font_size", _d43(14))
	var _p6 = find_child("_z95")
	if _p6 and _p6 is Label:
		_p6.add_theme_font_size_override("font_size", _d43(14))
	var _r44 = find_child("_a25")
	if _r44 and _r44 is Label:
		_r44.add_theme_font_size_override("font_size", _d43(14))
