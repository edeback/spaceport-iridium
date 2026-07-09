@tool
class_name _j99
extends Control

signal _y42(function_name: String, _z29: String, file_path: String)

var _v62: EditorPlugin
var _z76: EditorInterface
var _j30: ScriptEditor
var _f37: CodeEdit
var _o77: bool = true
var _r87: Array = []
var _s13: bool = false
var _z88: int = -1  
var _m22: Timer
var _o35: RegEx  
var _n75: int = 300  
var _j78: WeakRef  

func _init(_u86: EditorPlugin):
	_v62 = _u86
	_z76 = _u86.get_editor_interface()
	_j30 = _z76.get_script_editor()
	
	_m22 = Timer.new()
	_m22.wait_time = 0.5  
	_m22.one_shot = true
	_m22.timeout.connect(_i71)
	add_child(_m22)
	
	_o35 = RegEx.new()
	_o35.compile("^\\s*func\\s+([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\(")
	
	_m59()
	
	if _j30 and not _j30.editor_script_changed.is_connected(_f64):
		_j30.editor_script_changed.connect(_f64)
	
	if _j30:
		_f64(_j30.get_current_script())

func set_enabled(enabled: bool):
	_o77 = enabled
	if _o77:
		_q70()
	else:
		_l35()

func is_enabled() -> bool:
	return _o77

func _f64(script: Script):
	if not script or not script.source_code:
		_b70()
		return
	
	var _r21 = script.resource_path
	if not _r21.is_empty() and not _r21.get_extension() == "gd":
		_b70()
		return
	
	if _r21.is_empty() or _r21.get_extension().is_empty():
		if not _m96(script.source_code):
			_b70()
			return
	
	_q70()

func _q70():
	_b70()
	
	var _c22 = _j30.get_current_editor()
	if not _c22:
		return
	
	_f37 = _p60(_c22)
	if not _f37:
		return
	
	if _o77:
		_f23()
	else:
		pass
func _p60(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node
	
	for _j75 in node.get_children():
		var _v42 = _p60(_j75)
		if _v42:
			return _v42
	
	return null

func _b70():
	_l35()
	
	if _f37:
		if _f37.text_changed.is_connected(_j1):
			_f37.text_changed.disconnect(_j1)
		if _f37.gutter_clicked.is_connected(_m20):
			_f37.gutter_clicked.disconnect(_m20)
	
	_f37 = null
	_r87.clear()
	_s13 = false
	_z88 = -1

func _f23():
	if not _f37:
		return
	
	var _x73 = _f37.get_gutter_count()
	var _m80 = -1
	
	for i in range(_x73):
		if _f37.get_gutter_name(i) == "refactor":
			_m80 = i
			break
	
	if _m80 >= 0:
		_z88 = _m80
		_s13 = true
	elif not _s13:
		_f37.add_gutter()
		_z88 = _x73  
		
		_f37.set_gutter_name(_z88, "refactor")
		_f37.set_gutter_width(_z88, 28)  
		_f37.set_gutter_draw(_z88, true)
		_f37.set_gutter_clickable(_z88, true)
		_f37.set_gutter_overwritable(_z88, false)
		_f37.set_gutter_type(_z88, TextEdit.GUTTER_TYPE_ICON)
		
		_s13 = true
	
	if _f37.has_signal("text_changed"):
		if not _f37.text_changed.is_connected(_j1):
			_f37.text_changed.connect(_j1)
	
	if _f37.has_signal("gutter_clicked"):
		if not _f37.gutter_clicked.is_connected(_m20):
			_f37.gutter_clicked.connect(_m20)
	
	_t65()

func _t65():
	if not _f37 or not _s13:
		return
	
	_l35()
	_r87.clear()
	
	var text = _f37.text
	var _b26 = text.split("\n")
	
	for _g69 in range(_b26.size()):
		var line = _b26[_g69]
		var _v42 = _o35.search(line)
		
		if _v42:
			if not _k96(line):
				continue
			
			var function_name = _v42.get_string(1)
			
			var _b85 = _e55(_b26, _g69)
			var _e15 = _b85 - _g69 + 1
			if _e15 > _n75:
				continue
			
			var _c28 = {
				"name": function_name,
				"line": _g69,
				"declaration_line": line,
				"end_line": _b85
			}
			_r87.append(_c28)
			
			_j90(_g69, function_name)
	
func _j90(_g69: int, function_name: String):
	if not _f37 or not _s13:
		return
	
	var _i60 = _n85()
	
	_f37.set_line_gutter_icon(_g69, _z88, _i60)
	_f37.set_line_gutter_clickable(_g69, _z88, true)
	
func _n85() -> ImageTexture:
	var _p15 = Image.create(28, 28, false, Image.FORMAT_RGBA8)
	_p15.fill(Color(0, 0, 0, 0))  

	var color = Color(0.8, 1.0, 0.8, 1.0)  

	for angle in range(0, 360, 10):
		var _p66 = deg_to_rad(angle)
		var x = int(14 + 9 * cos(_p66))
		var y = int(14 + 9 * sin(_p66))
		if x >= 0 and x < 28 and y >= 0 and y < 28:
			_p15.set_pixel(x, y, color)

			if x + 1 < 28:
				_p15.set_pixel(x + 1, y, color)
			if y + 1 < 28:
				_p15.set_pixel(x, y + 1, color)
			if x + 2 < 28:
				_p15.set_pixel(x + 2, y, color)
			if y + 2 < 28:
				_p15.set_pixel(x, y + 2, color)

	for x in range(21, 26):
		_p15.set_pixel(x, 7, color)
		_p15.set_pixel(x, 8, color)
		_p15.set_pixel(x, 9, color)

	_p15.set_pixel(22, 5, color)
	_p15.set_pixel(23, 4, color)
	_p15.set_pixel(24, 3, color)
	_p15.set_pixel(22, 6, color)
	_p15.set_pixel(23, 5, color)

	_p15.set_pixel(22, 10, color)
	_p15.set_pixel(23, 11, color)
	_p15.set_pixel(24, 12, color)
	_p15.set_pixel(22, 11, color)
	_p15.set_pixel(23, 12, color)

	var texture = ImageTexture.new()
	texture.set_image(_p15)
	return texture

func _m20(line: int, _p29: int):
	if not _o77 or _p29 != _z88:
		return
	
	var _c28 = _h68(line)
	if _c28.is_empty():
		return
	
	var _z29 = _u95(_c28)
	if _z29.is_empty():
		return
	
	var _r21 = ""
	var _f78 = _j30.get_current_script()
	if _f78:
		_r21 = _f78.resource_path
	
	_y42.emit(_c28.name, _z29, _r21)

func _u95(_f50: Dictionary) -> String:
	if not _f37:
		push_error("ScriptRefactorOverlay: No current script editor available for function extraction")
		return ""
	
	var text = _f37.text
	var _b26 = text.split("\n")
	var start_line = _f50.line
	var function_name = _f50.name
	
	if start_line < 0 or start_line >= _b26.size():
		push_error("ScriptRefactorOverlay: Invalid start line %d for function '%s'. Check script integrity." % [start_line, function_name])
		return ""
	
	var end_line: int
	if _f50.has("end_line"):
		end_line = _f50.end_line
	else:
		end_line = _e55(_b26, start_line)
	
	if end_line < start_line:
		push_error("ScriptRefactorOverlay: Invalid end line %d for function '%s'. Function parsing failed." % [end_line, function_name])
		return ""
	
	var _e15 = end_line - start_line + 1
	if _e15 > _n75:
		push_error("ScriptRefactorOverlay: Function '%s' is too large (%d lines, max %d). Consider breaking it into smaller functions." % [function_name, _e15, _n75])
		return ""
	
	var _o69 = []
	for i in range(start_line, min(end_line + 1, _b26.size())):
		_o69.append(_b26[i])
	
	if _o69.is_empty():
		push_error("ScriptRefactorOverlay: No function lines extracted for '%s'. The function may be malformed." % function_name)
		return ""
	
	return "\n".join(_o69)

func _e55(_b26: PackedStringArray, start_line: int) -> int:
	if start_line >= _b26.size():
		return start_line
	
	var _a23 = _q64(_b26[start_line])
	
	for i in range(start_line + 1, _b26.size()):
		var line = _b26[i]
		var _x6 = line.strip_edges()
		
		if _x6.is_empty() or _x6.begins_with("#"):
			continue
		
		var _c34 = _q64(line)
		
		if _c34 <= _a23:
			if _x6.begins_with("func ") or _x6.begins_with("class ") or _x6.begins_with("extends") or _x6.begins_with("@"):
				return i - 1
	
	return _b26.size() - 1

func _q64(line: String) -> int:
	var indent = 0
	for char in line:
		if char == '\t':
			indent += 4  
		elif char == ' ':
			indent += 1
		else:
			break
	return indent

func _l35():
	if not _f37 or not _s13:
		return
	
	var _s40 = _f37.get_line_count()
	for line in range(_s40):
		_f37.set_line_gutter_icon(line, _z88, null)
		_f37.set_line_gutter_clickable(line, _z88, false)

func _j1():
	if not _f37 or not is_instance_valid(_m22):
		return
	
	if not is_inside_tree():
		return
	
	_m22.stop()
	_m22.start()

func _h68(line: int) -> Dictionary:
	for _c28 in _r87:
		if _c28.line == line:
			return _c28
	return {}

func _i71():
	if _o77 and _f37 and _s13:
		_t65()

func _f29():
	if _o77 and _f37 and _s13:
		_t65()

func _o76():
	_b70()
	
	if is_instance_valid(_m22):
		_m22.queue_free()
		_m22 = null
	
	if _j30 and _j30.editor_script_changed.is_connected(_f64):
		_j30.editor_script_changed.disconnect(_f64)
	
	_v62 = null
	_z76 = null
	_j30 = null
	_f37 = null
	_r87.clear()
	_o35 = null

func _f55(line: int) -> Dictionary:
	for _c28 in _r87:
		if _c28.line == line:
			return _c28
	return {}

func _c69() -> Array:
	return _r87.duplicate()

func _m96(content: String) -> bool:
	if content.is_empty():
		return false
	
	var _t92 = [
		"@tool",
		"extends ",
		"class_name ",
		"func ",
		"var ",
		"const ",
		"signal ",
		"enum ",
		"@export",
		"@onready"
	]
	
	for _v48 in _t92:
		if _v48 in content:
			return true
	
	return false

func _k96(line: String) -> bool:
	var _x6 = line.strip_edges()
	
	return "func " in _x6 and "(" in _x6

func _m59():
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		_n75 = config.get_value("refactor", "max_function_lines", 300)
	else:
		_n75 = 300

func _n28(limit: int):
	_n75 = max(50, limit)  
	
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")
	config.set_value("refactor", "max_function_lines", _n75)
	config.save("user://gdsense_api_key.cfg")

func get_function_size_limit() -> int:
	return _n75

func _v49(_c81):
	_j78 = weakref(_c81)

func _e62(_x29: Dictionary):
	if _j78 and _j78.get_ref():
		var _c81 = _j78.get_ref()
		if _c81.has_method("update_gutters_after_refactor"):
			_c81.update_gutters_after_refactor(_x29)
func get_current_script_editor() -> CodeEdit:
	return _f37

func _y59():
	if _o77 and _f37 and _s13:
		_t65()

