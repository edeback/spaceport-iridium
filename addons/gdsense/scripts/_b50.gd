@tool
class_name _l47
extends AcceptDialog

signal _n1(refactored_code: String, function_name: String)
signal _u59(function_name: String)
signal _j19(data: Dictionary)

const _o56 = 5000
const _b92 = 10000
const _s3 = 1048576  
const _f69 = 100

var _d18: String
var _h12: String
var _p44: String
var _g33: String
var _e41: String
var _s51: Control
var _b91: Button
var _a35: Button
var _k42: Button
var _h37: bool = true
var _b98: Label

enum _w69 {
	_q96,
	_c44
}
var _q86: _w69

var _z15: float = 1.0
var _v98: float = 1.0  
var _e100: int = 16  

var _r61: ScrollContainer
var _i56: ScrollContainer
var _v94: VBoxContainer
var _o46: VBoxContainer
var _n76: VBoxContainer

var _h58 = {
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

func _t60() -> Color:
	if has_theme_color("font_color", "Editor"):
		return get_theme_color("font_color", "Editor")
	return Color(0.7, 0.7, 0.7)  

func _y14() -> Color:
	if has_theme_color("font_color", "Editor"):
		var font_color = get_theme_color("font_color", "Editor")

		return Color(font_color.r * 0.6, font_color.g * 0.6, font_color.b * 0.6, font_color.a)
	return Color(0.5, 0.5, 0.5)  

func _k40() -> Color:
	if has_theme_color("base_color", "Editor"):
		var _q78 = get_theme_color("base_color", "Editor")
		return Color(_q78.r, _q78.g, _q78.b, 0.3)
	return Color(0.15, 0.15, 0.15, 0.3)  

func _c34():
	var _q75 = get_theme_color("base_color", "Editor") if has_theme_color("base_color", "Editor") else Color(0.2, 0.2, 0.2)
	var _r36 = _q75.get_luminance() > 0.5

	if _r36:
		_h58["comment"] = Color(0.4, 0.5, 0.4)  
		_h58["string"] = Color(0.6, 0.3, 0.1)   
		_h58["number"] = Color(0.1, 0.3, 0.6)   
		_h58["keyword"] = Color(0.6, 0.1, 0.4)  
		_h58["class"] = Color(0.1, 0.5, 0.2)    
		_h58["function"] = Color(0.1, 0.3, 0.6) 
		_h58["symbol"] = Color(0.2, 0.2, 0.2)   
	else:
		_h58["comment"] = Color.GRAY
		_h58["string"] = Color.ORANGE
		_h58["number"] = Color.SKY_BLUE
		_h58["keyword"] = Color.PALE_VIOLET_RED
		_h58["class"] = Color.LIGHT_GREEN
		_h58["function"] = Color.LIGHT_BLUE
		_h58["symbol"] = Color.WHITE

const _k70 = [
	"if", "elif", "else", "for", "while", "match", "break", "continue", "pass",
	"return", "class", "extends", "is", "as", "self", "super", "func", "signal",
	"const", "var", "static", "enum", "in", "not", "and", "or", "true", "false",
	"null", "export", "onready", "tool", "setget", "breakpoint", "preload", "yield",
	"assert", "remote", "sync", "master", "puppet", "@export", "@onready", "@tool"
]

var _y77: RegEx
var _j66: RegEx
var _h51: RegEx
var _o53: RegEx
var _o15: RegEx

func _init():
	_w18()

func _w18():
	_y77 = RegEx.new()
	if _y77.compile("#.*$") != OK:
		push_error("Failed to compile comment regex")
		_y77 = null
	
	_j66 = RegEx.new()
	if _j66.compile("(\"[^\"]*\"|'[^']*')") != OK:
		push_error("Failed to compile string regex")
		_j66 = null
	
	_h51 = RegEx.new()
	var _z28 = "\\b(" + "|".join(_k70) + ")\\b"
	if _h51.compile(_z28) != OK:
		push_error("Failed to compile keyword regex")
		_h51 = null
	
	_o53 = RegEx.new()
	if _o53.compile("\\b\\d+(\\.\\d+)?\\b") != OK:
		push_error("Failed to compile number regex")
		_o53 = null
	
	_o15 = RegEx.new()
	if _o15.compile("\\b([a-z_][a-zA-Z0-9_]*)\\s*\\(") != OK:
		push_error("Failed to compile function regex")
		_o15 = null

func _ready():
	get_ok_button().hide()

	_b52()

	_c34()

	if not confirmed.is_connected(_o81):
		confirmed.connect(_o81)

	_p45()
	_z89()

	_p3()

	_u66.call_deferred()

func _b52():
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		var _i4 = config.get_value("font_scale", "mode", "auto")
		if _i4 == "auto":
			var _s14 = DisplayServer.screen_get_size()
			var _a18 = _s14.y
			if _a18 >= 2160:  
				_v98 = 1.5
			elif _a18 >= 1440:  
				_v98 = 1.25
			else:  
				_v98 = 1.0
		else:
			_v98 = float(_i4)
	else:
		_v98 = 1.0

func _p45():
	if not is_inside_tree():
		return
	
	_k42 = %_h93
	_b98 = %_v96  
	_s51 = %_x30
	_b91 = %_j93
	_a35 = %_b55
	
	_r61 = %_z39
	_i56 = %_w26
	_v94 = %_e32
	_o46 = %_r21
	_n76 = %_h47
	
	if _k42 and not _k42.pressed.is_connected(_y51):
		_k42.pressed.connect(_y51)
	if _b91 and not _b91.pressed.is_connected(_o81):
		_b91.pressed.connect(_o81)
	if _a35 and not _a35.pressed.is_connected(_e44):
		_a35.pressed.connect(_e44)
	
	if _r61 and _i56:
		var _y6 = _r61.get_v_scroll_bar()
		var _v85 = _i56.get_v_scroll_bar()
		if not _y6.value_changed.is_connected(_a25):
			_y6.value_changed.connect(_a25)
		if not _v85.value_changed.is_connected(_p41):
			_v85.value_changed.connect(_p41)
	
func _z89():
	_h37 = true
	_q86 = _w69._q96

func _c93():
	if _v94 and _o46 and _n76:
		if is_instance_valid(_v94) and is_instance_valid(_o46) and is_instance_valid(_n76):
			return
	
	_v94 = %_e32
	_o46 = %_r21
	_n76 = %_h47
	_r61 = %_z39
	_i56 = %_w26
	
	if not _v94 or not _o46 or not _n76:
		pass
func _t9(function_name: String, original_code: String, refactored_code: String, file_path: String = "", prompt: String = ""):
	var _f86 = original_code.length() + refactored_code.length()
	if _f86 > _s3:
		push_error("Total input size exceeds maximum allowed size of %d bytes" % _s3)
		return
	
	if original_code.length() > _b92 * _o56:
		push_error("Original code exceeds maximum allowed size")
		return
	if refactored_code.length() > _b92 * _o56:
		push_error("Refactored code exceeds maximum allowed size")
		return
	
	var _d83 = original_code.split("\n")
	var _d97 = refactored_code.split("\n")
	
	if _d83.size() > _o56 or _d97.size() > _o56:
		push_error("Code exceeds maximum line limit of %d" % _o56)
		return
	
	_p44 = function_name
	_d18 = original_code
	_h12 = refactored_code
	_g33 = file_path
	_e41 = prompt
	
	if not is_inside_tree():
		var _f28 = Engine.get_singleton("EditorInterface")
		if _f28:
			var _e83 = _f28.get_base_control()
			if _e83:
				_e83.add_child(self)
			else:
				pass

	_n28.call_deferred()

func _e21():
	if not _k42:
		_p45()
		_c93()

func _n28():
	if not is_inside_tree():
		return

	_b52()
	_c34()
	_p3()

	popup_centered()

	if not is_inside_tree():
		return
	await get_tree().process_frame

	if not is_inside_tree():
		return

	_u66()

	_e21()

	if _b98:
		_b98.text = "Function: %s" % _p44
	else:
		pass

	_g24()

func _g24():
	if not _v94 or not _o46 or not _n76:
		return
		
	if _d18.is_empty() or _h12.is_empty():
		return
	
	if _h37:
		_b82()
	else:
		_a87()

func _z90(_d83: PackedStringArray, _d97: PackedStringArray) -> Array:
	var _p25 = []
	var _p99 = 0
	var _h18 = 0
	
	while _p99 < _d83.size() or _h18 < _d97.size():
		if _p99 >= _d83.size():
			_p25.append({
				"type": "added", 
				"line": _d97[_h18],
				"original_line_num": -1,
				"refactored_line_num": _h18 + 1
			})
			_h18 += 1
		elif _h18 >= _d97.size():
			_p25.append({
				"type": "removed", 
				"line": _d83[_p99],
				"original_line_num": _p99 + 1,
				"refactored_line_num": -1
			})
			_p99 += 1
		elif _d83[_p99] == _d97[_h18]:
			_p25.append({
				"type": "context", 
				"line": _d83[_p99],
				"original_line_num": _p99 + 1,
				"refactored_line_num": _h18 + 1
			})
			_p99 += 1
			_h18 += 1
		else:
			_p25.append({
				"type": "removed", 
				"line": _d83[_p99],
				"original_line_num": _p99 + 1,
				"refactored_line_num": -1
			})
			_p25.append({
				"type": "added", 
				"line": _d97[_h18],
				"original_line_num": -1,
				"refactored_line_num": _h18 + 1
			})
			_p99 += 1
			_h18 += 1
	
	return _p25

func _e10(_k20: Dictionary, _e5: VBoxContainer):
	var _j45 = PanelContainer.new()
	_j45.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var _i14 = StyleBoxFlat.new()
	var prefix = ""
	var _v16 = _t60()

	match _k20.type:
		"added":
			_i14.bg_color = _h58.added_bg
			prefix = "+ "
			_v16 = _h58.added
		"removed":
			_i14.bg_color = _h58.removed_bg
			prefix = "- "
			_v16 = _h58.removed
		"context":
			_i14.bg_color = _k40()
			prefix = "  "
			_v16 = _t60()

	_i14.content_margin_left = 8
	_i14.content_margin_right = 8
	_i14.content_margin_top = 2
	_i14.content_margin_bottom = 2
	_j45.add_theme_stylebox_override("panel", _i14)

	var _m29 = HBoxContainer.new()

	var _t100 = Label.new()
	var _i27 = ""
	if _k20.original_line_num > 0 and _k20.refactored_line_num > 0:
		_i27 = "%d:%d" % [_k20.original_line_num, _k20.refactored_line_num]
	elif _k20.original_line_num > 0:
		_i27 = "%d:-" % _k20.original_line_num
	else:
		_i27 = "-:%d" % _k20.refactored_line_num

	_t100.text = _i27
	_t100.custom_minimum_size = Vector2(80, 0)
	_t100.add_theme_color_override("font_color", _y14())
	_t100.add_theme_font_size_override("font_size", _r80(_e100 - 2))
	var _x25 = SystemFont.new()
	_x25.font_names = ["Consolas", "Courier New", "Monospace"]
	_t100.add_theme_font_override("font", _x25)
	_m29.add_child(_t100)
	
	var _j1 = RichTextLabel.new()
	_j1.bbcode_enabled = true
	_j1.selection_enabled = true
	_j1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_j1.size_flags_vertical = Control.SIZE_EXPAND_FILL  
	_j1.fit_content = false  
	_j1.scroll_active = true  
	_j1.autowrap_mode = TextServer.AUTOWRAP_OFF  
	_j1.custom_minimum_size = Vector2(400, int(32 * _z15))  
	
	var _x11 = _b15(_k20.line)
	_j1.text = prefix + _x11
	
	_j1.add_theme_font_override("normal_font", _x25)
	_j1.add_theme_font_override("mono_font", _x25)
	_j1.add_theme_color_override("default_color", _v16)
	_j1.add_theme_font_size_override("normal_font_size", _r80(_e100))
	
	_m29.add_child(_j1)
	_j45.add_child(_m29)
	
	_j45.custom_minimum_size = Vector2(0, int(36 * _z15))  
	_j45.size_flags_vertical = Control.SIZE_EXPAND_FILL  
	
	_e5.add_child(_j45)
	
	_o84(_j1)
	
	if _j45.is_inside_tree():
		_j45.queue_redraw()

func _b82():
	_c93()
	
	_i65()
	
	var _m66 = %_x36
	var _q91 = %_v42
	
	if _m66:
		_m66.visible = true
	if _q91:
		_q91.visible = false
	
	if not _v94 or not _o46:
		return
	
	if not is_instance_valid(_v94) or not is_instance_valid(_o46):
		return
	
	var _d83 = _d18.split("\n")
	var _d97 = _h12.split("\n")
	
	if _d83.size() > _o56:
		_d83.resize(_o56)
	if _d97.size() > _o56:
		_d97.resize(_o56)
	
	var _k4 = max(_d83.size(), _d97.size())
	
	for i in range(_k4):
		var _h73 = _d83[i] if i < _d83.size() else ""
		var _c62 = _d97[i] if i < _d97.size() else ""
		
		var _a2 = "context"
		var _u43 = "context"
		
		if i >= _d83.size():
			_a2 = "empty"
			_u43 = "added"
		elif i >= _d97.size():
			_a2 = "removed" 
			_u43 = "empty"
		elif _h73 != _c62:
			_a2 = "removed"
			_u43 = "added"
		
		if _v94 and _o46:
			_u23(_h73, i + 1, _a2, _v94, true)
			_u23(_c62, i + 1, _u43, _o46, false)
		else:
			return
	
	if is_inside_tree():
		if _r61 and is_instance_valid(_r61):
			_r61.queue_redraw()
			_r61.notification(Control.NOTIFICATION_RESIZED)

			_r61.queue_sort()
		if _i56 and is_instance_valid(_i56):
			_i56.queue_redraw()
			_i56.notification(Control.NOTIFICATION_RESIZED)

			_i56.queue_sort()

		if _v94 and is_instance_valid(_v94):
			_v94.queue_redraw()
			_v94.queue_sort()
		if _o46 and is_instance_valid(_o46):
			_o46.queue_redraw()
			_o46.queue_sort()
		
func _a87():
	_c93()
	
	_i65()
	
	var _m66 = %_x36
	var _q91 = %_v42
	
	if _m66:
		_m66.visible = false
		
	if _q91:
		_q91.visible = true
	if not _n76:
		return
	
	var _d83 = _d18.split("\n")
	var _d97 = _h12.split("\n")
	var _s62 = _z90(_d83, _d97)
	
	for _k20 in _s62:
		_e10(_k20, _n76)

func _u23(content: String, _k88: int, _d43: String, _e5: VBoxContainer, _s2: bool):
	if not is_instance_valid(_e5):
		return
	
	if content.length() > _b92:
		content = content.substr(0, _b92) + "... [TRUNCATED]"
	
	var _j45 = PanelContainer.new()
	_j45.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_j45.size_flags_vertical = Control.SIZE_EXPAND_FILL  
	_j45.custom_minimum_size = Vector2(0, int(36 * _z15))  
	
	var _i14 = StyleBoxFlat.new()
	var _v16 = _t60()

	match _d43:
		"added":
			_i14.bg_color = _h58.added_bg
			_v16 = _h58.added
		"removed":
			_i14.bg_color = _h58.removed_bg
			_v16 = _h58.removed
		"empty":
			_i14.bg_color = _k40()
			_v16 = _y14()  
		"context":
			_i14.bg_color = _k40()
			_v16 = _t60()

	_i14.content_margin_left = 8
	_i14.content_margin_right = 8
	_i14.content_margin_top = 2
	_i14.content_margin_bottom = 2
	_j45.add_theme_stylebox_override("panel", _i14)

	var _m29 = HBoxContainer.new()
	_m29.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_m29.size_flags_vertical = Control.SIZE_EXPAND_FILL  

	var _t100 = Label.new()
	if _d43 == "empty":
		_t100.text = ""
	else:
		_t100.text = str(_k88)
	_t100.custom_minimum_size = Vector2(50, 0)
	_t100.add_theme_color_override("font_color", _y14())
	_t100.add_theme_font_size_override("font_size", _r80(_e100 - 2))
	var _x25 = SystemFont.new()
	_x25.font_names = ["Consolas", "Courier New", "Monospace"]
	_t100.add_theme_font_override("font", _x25)
	_m29.add_child(_t100)
	
	var _j1 = RichTextLabel.new()
	_j1.bbcode_enabled = true
	_j1.selection_enabled = true
	_j1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_j1.size_flags_vertical = Control.SIZE_EXPAND_FILL  
	_j1.custom_minimum_size = Vector2(400, int(30 * _z15))  
	_j1.fit_content = false  
	_j1.scroll_active = true  
	_j1.autowrap_mode = TextServer.AUTOWRAP_OFF  
	_j1.clip_contents = true  
	_j1.scroll_following = false  
	
	if _d43 == "empty":
		_j1.text = " "  
	else:
		var _x11 = _b15(content) if not content.is_empty() else content
		_j1.text = _x11
	
	_j1.add_theme_font_override("normal_font", _x25)
	_j1.add_theme_font_override("mono_font", _x25)
	_j1.add_theme_color_override("default_color", _v16)
	_j1.add_theme_font_size_override("normal_font_size", _r80(_e100))
	
	_m29.add_child(_j1)
	_j45.add_child(_m29)
	
	_e5.add_child(_j45)
	
	_j45.visible = true
	_m29.visible = true
	_j1.visible = true
	_t100.visible = true
	
	_o84(_j1)
	
	if _e5.is_inside_tree():
		_e5.queue_redraw()

		var _f98 = _e5.get_parent()
		if _f98 and _f98 is ScrollContainer:
			_f98.queue_redraw()
			_f98.notification(Control.NOTIFICATION_RESIZED)
	
func _i65():
	if _v94 and is_instance_valid(_v94):
		var children = _v94.get_children()
		for _c100 in children:
			if is_instance_valid(_c100):
				_v94.remove_child(_c100)
				_c100.queue_free()
	
	if _o46 and is_instance_valid(_o46):
		var children = _o46.get_children()
		for _c100 in children:
			if is_instance_valid(_c100):
				_o46.remove_child(_c100)
				_c100.queue_free()
	
	if _n76 and is_instance_valid(_n76):
		var children = _n76.get_children()
		for _c100 in children:
			if is_instance_valid(_c100):
				_n76.remove_child(_c100)
				_c100.queue_free()

func _a25(value: float):
	if _i56 and _i56.get_v_scroll_bar().value != value:
		_i56.get_v_scroll_bar().value = value

func _p41(value: float):
	if _r61 and _r61.get_v_scroll_bar().value != value:
		_r61.get_v_scroll_bar().value = value

func _b15(line: String) -> String:
	if line.strip_edges().is_empty():
		return line

	return line

func _p77(text: String) -> String:
	if not _y77 or text.length() > _b92:
		return text

	return _y77.sub(text, "[color=#%s]$0[/color]" % _h58.comment.to_html(false), true)

func _x96(text: String) -> String:
	if not _j66 or text.length() > _b92:
		return text
	return _j66.sub(text, "[color=#%s]$1[/color]" % _h58.string.to_html(false), true)

func _r95(text: String) -> String:
	if not _h51 or text.length() > _b92:
		return text
	return _h51.sub(text, "[color=#%s]$1[/color]" % _h58.keyword.to_html(false), true)

func _a79(text: String) -> String:
	if not _o53 or text.length() > _b92:
		return text
	return _o53.sub(text, "[color=#%s]$0[/color]" % _h58.number.to_html(false), true)

func _e75(text: String) -> String:
	if not _o15 or text.length() > _b92:
		return text
	return _o15.sub(text, "[color=#%s]$1[/color](" % _h58.function.to_html(false), true)

func _o81():
	hide()

	var _r55 = {
		"original_code": _d18,
		"refactored_code": _h12,
		"function_name": _p44,
		"file_path": _g33,
		"prompt": _e41,
		"timestamp": Time.get_unix_time_from_system()
	}
	_j19.emit(_r55)

	_n1.emit(_h12, _p44)

func _e44():
	hide()

	_u59.emit(_p44)

func _y51():
	_h37 = not _h37
	_k42.text = "Switch to Side-by-Side" if not _h37 else "Switch to Unified"
	_g24()

func _a98():
	if is_inside_tree():
		hide()

func _k26():
	if not OS.is_debug_build():
		return
	
func _notification(_e73: int):
	match _e73:
		Control.NOTIFICATION_RESIZED:
			_t76()
		Control.NOTIFICATION_VISIBILITY_CHANGED:
			if visible and is_inside_tree():
				_z81.call_deferred()

func _t76():
	if not is_inside_tree() or not _s51:
		return
	
	_p3()
	
	_u66()
	
	if not _d18.is_empty() and not _h12.is_empty():
		_e66()

func _u66():
	if not is_inside_tree() or not _s51:
		return
		
	_s51.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_s51.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	for _c100 in _s51.get_children():
		if _c100.name == "SideBySideContainer" and _c100 is HBoxContainer:
			_c100.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_c100.size_flags_vertical = Control.SIZE_EXPAND_FILL
			
			for _q93 in _c100.get_children():
				if _q93 is VBoxContainer:
					_q93.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					_q93.size_flags_vertical = Control.SIZE_EXPAND_FILL
					
					for _a58 in _q93.get_children():
						if _a58 is ScrollContainer:
							_a58.size_flags_horizontal = Control.SIZE_EXPAND_FILL
							_a58.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		elif _c100.name == "UnifiedContainer" and _c100 is ScrollContainer:
			_c100.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_c100.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _z81():
	if not is_inside_tree():
		return
	_u66()
	if not _d18.is_empty() and not _h12.is_empty():
		_e66()

func _e66():
	var _d14 = _r80(_e100)
	
	for _e5 in [_v94, _o46, _n76]:
		if _e5 and is_instance_valid(_e5):
			for _j45 in _e5.get_children():
				if _j45 and is_instance_valid(_j45):
					for node in _b90(_j45):
						if node is RichTextLabel:
							node.add_theme_font_size_override("normal_font_size", _d14)

							_o84(node)
						elif node is Label:
							node.add_theme_font_size_override("font_size", _d14)

func _b90(node: Node) -> Array:
	var children = []
	for _c100 in node.get_children():
		children.append(_c100)
		children.append_array(_b90(_c100))
	return children

func _o84(_g68: RichTextLabel):
	if not _g68 or not is_instance_valid(_g68):
		return
		
	_g68.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_g68.custom_minimum_size.y = int(32 * _z15)

func _r80(_w28: int) -> int:
	var _o11 = int(_w28 * _v98)

	return max(_o11, 12)

func _p3():
	if not is_inside_tree():
		return
	
	var _k96 = find_child("_l68")
	if _k96 and _k96 is Label:
		_k96.add_theme_font_size_override("font_size", _r80(16))
	
	if _b98:
		_b98.add_theme_font_size_override("font_size", _r80(14))
	
	var _i48 = find_child("_m32")
	if _i48 and _i48 is Label:
		_i48.add_theme_font_size_override("font_size", _r80(14))
	
	var _x34 = find_child("_b30")
	if _x34 and _x34 is Label:
		_x34.add_theme_font_size_override("font_size", _r80(14))

