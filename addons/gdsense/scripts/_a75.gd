@tool
class_name _w85
extends Control

signal _x10(function_name: String, _g33: String, file_path: String)

var _u65: EditorPlugin
var _q86: EditorInterface
var _b50: ScriptEditor
var _t5: CodeEdit
var _p60: bool = true
var _e29: Array = []
var _g7: bool = false
var _l31: int = -1  
var _c67: Timer
var _w47: RegEx  
var _v99: int = 300  
var _w18: WeakRef  

func _init(_u63: EditorPlugin):
	_u65 = _u63
	_q86 = _u63.get_editor_interface()
	_b50 = _q86.get_script_editor()
	
	_c67 = Timer.new()
	_c67.wait_time = 0.5  
	_c67.one_shot = true
	_c67.timeout.connect(_g67)
	add_child(_c67)
	
	_w47 = RegEx.new()
	_w47.compile("^\\s*func\\s+([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\(")
	
	_z87()
	
	if _b50 and not _b50.editor_script_changed.is_connected(_u14):
		_b50.editor_script_changed.connect(_u14)
	
	if _b50:
		_u14(_b50.get_current_script())

func set_enabled(enabled: bool):
	_p60 = enabled
	if _p60:
		_g60()
	else:
		_v78()

func is_enabled() -> bool:
	return _p60

func _u14(script: Script):
	if not script or not script.source_code:
		_y22()
		return
	
	var _d36 = script.resource_path
	if not _d36.is_empty() and not _d36.get_extension() == "gd":
		_y22()
		return
	
	if _d36.is_empty() or _d36.get_extension().is_empty():
		if not _i70(script.source_code):
			_y22()
			return
	
	_g60()

func _g60():
	_y22()
	
	var _y53 = _b50.get_current_editor()
	if not _y53:
		return
	
	_t5 = _j24(_y53)
	if not _t5:
		return
	
	if _p60:
		_w77()
	else:
		pass
func _j24(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node
	
	for _w15 in node.get_children():
		var _k3 = _j24(_w15)
		if _k3:
			return _k3
	
	return null

func _y22():
	_v78()
	
	if _t5:
		if _t5.text_changed.is_connected(_z28):
			_t5.text_changed.disconnect(_z28)
		if _t5.gutter_clicked.is_connected(_a23):
			_t5.gutter_clicked.disconnect(_a23)
	
	_t5 = null
	_e29.clear()
	_g7 = false
	_l31 = -1

func _w77():
	if not _t5:
		return
	
	var _e52 = _t5.get_gutter_count()
	var _q51 = -1
	
	for i in range(_e52):
		if _t5.get_gutter_name(i) == "refactor":
			_q51 = i
			break
	
	if _q51 >= 0:
		_l31 = _q51
		_g7 = true
	elif not _g7:
		_t5.add_gutter()
		_l31 = _e52  
		
		_t5.set_gutter_name(_l31, "refactor")
		_t5.set_gutter_width(_l31, 28)  
		_t5.set_gutter_draw(_l31, true)
		_t5.set_gutter_clickable(_l31, true)
		_t5.set_gutter_overwritable(_l31, false)
		_t5.set_gutter_type(_l31, TextEdit.GUTTER_TYPE_ICON)
		
		_g7 = true
	
	if _t5.has_signal("text_changed"):
		if not _t5.text_changed.is_connected(_z28):
			_t5.text_changed.connect(_z28)
	
	if _t5.has_signal("gutter_clicked"):
		if not _t5.gutter_clicked.is_connected(_a23):
			_t5.gutter_clicked.connect(_a23)
	
	_d68()

func _d68():
	if not _t5 or not _g7:
		return
	
	_v78()
	_e29.clear()
	
	var text = _t5.text
	var _m12 = text.split("\n")
	
	for _u8 in range(_m12.size()):
		var line = _m12[_u8]
		var _k3 = _w47.search(line)
		
		if _k3:
			if not _h100(line):
				continue
			
			var function_name = _k3.get_string(1)
			
			var _z44 = _i9(_m12, _u8)
			var _g12 = _z44 - _u8 + 1
			if _g12 > _v99:
				continue
			
			var _s29 = {
				"name": function_name,
				"line": _u8,
				"declaration_line": line,
				"end_line": _z44
			}
			_e29.append(_s29)
			
			_s86(_u8, function_name)
	
func _s86(_u8: int, function_name: String):
	if not _t5 or not _g7:
		return
	
	var _n18 = _c22()
	
	_t5.set_line_gutter_icon(_u8, _l31, _n18)
	_t5.set_line_gutter_clickable(_u8, _l31, true)
	
func _c22() -> ImageTexture:
	var _g32 = Image.create(28, 28, false, Image.FORMAT_RGBA8)
	_g32.fill(Color(0, 0, 0, 0))  

	var color = Color(0.8, 1.0, 0.8, 1.0)  

	for angle in range(0, 360, 10):
		var _l21 = deg_to_rad(angle)
		var x = int(14 + 9 * cos(_l21))
		var y = int(14 + 9 * sin(_l21))
		if x >= 0 and x < 28 and y >= 0 and y < 28:
			_g32.set_pixel(x, y, color)

			if x + 1 < 28:
				_g32.set_pixel(x + 1, y, color)
			if y + 1 < 28:
				_g32.set_pixel(x, y + 1, color)
			if x + 2 < 28:
				_g32.set_pixel(x + 2, y, color)
			if y + 2 < 28:
				_g32.set_pixel(x, y + 2, color)

	for x in range(21, 26):
		_g32.set_pixel(x, 7, color)
		_g32.set_pixel(x, 8, color)
		_g32.set_pixel(x, 9, color)

	_g32.set_pixel(22, 5, color)
	_g32.set_pixel(23, 4, color)
	_g32.set_pixel(24, 3, color)
	_g32.set_pixel(22, 6, color)
	_g32.set_pixel(23, 5, color)

	_g32.set_pixel(22, 10, color)
	_g32.set_pixel(23, 11, color)
	_g32.set_pixel(24, 12, color)
	_g32.set_pixel(22, 11, color)
	_g32.set_pixel(23, 12, color)

	var texture = ImageTexture.new()
	texture.set_image(_g32)
	return texture

func _a23(line: int, _g51: int):
	if not _p60 or _g51 != _l31:
		return
	
	var _s29 = _g80(line)
	if _s29.is_empty():
		return
	
	var _g33 = _h99(_s29)
	if _g33.is_empty():
		return
	
	var _d36 = ""
	var _w66 = _b50.get_current_script()
	if _w66:
		_d36 = _w66.resource_path
	
	_x10.emit(_s29.name, _g33, _d36)

func _h99(_o77: Dictionary) -> String:
	if not _t5:
		push_error("ScriptRefactorOverlay: No current script editor available for function extraction")
		return ""
	
	var text = _t5.text
	var _m12 = text.split("\n")
	var start_line = _o77.line
	var function_name = _o77.name
	
	if start_line < 0 or start_line >= _m12.size():
		push_error("ScriptRefactorOverlay: Invalid start line %d for function '%s'. Check script integrity." % [start_line, function_name])
		return ""
	
	var end_line: int
	if _o77.has("end_line"):
		end_line = _o77.end_line
	else:
		end_line = _i9(_m12, start_line)
	
	if end_line < start_line:
		push_error("ScriptRefactorOverlay: Invalid end line %d for function '%s'. Function parsing failed." % [end_line, function_name])
		return ""
	
	var _g12 = end_line - start_line + 1
	if _g12 > _v99:
		push_error("ScriptRefactorOverlay: Function '%s' is too large (%d lines, max %d). Consider breaking it into smaller functions." % [function_name, _g12, _v99])
		return ""
	
	var _r23 = []
	for i in range(start_line, min(end_line + 1, _m12.size())):
		_r23.append(_m12[i])
	
	if _r23.is_empty():
		push_error("ScriptRefactorOverlay: No function lines extracted for '%s'. The function may be malformed." % function_name)
		return ""
	
	return "\n".join(_r23)

func _i9(_m12: PackedStringArray, start_line: int) -> int:
	if start_line >= _m12.size():
		return start_line
	
	var _g68 = _z22(_m12[start_line])
	
	for i in range(start_line + 1, _m12.size()):
		var line = _m12[i]
		var _e54 = line.strip_edges()
		
		if _e54.is_empty() or _e54.begins_with("#"):
			continue
		
		var _k30 = _z22(line)
		
		if _k30 <= _g68:
			if _e54.begins_with("func ") or _e54.begins_with("class ") or _e54.begins_with("extends") or _e54.begins_with("@"):
				return i - 1
	
	return _m12.size() - 1

func _z22(line: String) -> int:
	var indent = 0
	for char in line:
		if char == '\t':
			indent += 4  
		elif char == ' ':
			indent += 1
		else:
			break
	return indent

func _v78():
	if not _t5 or not _g7:
		return
	
	var _e63 = _t5.get_line_count()
	for line in range(_e63):
		_t5.set_line_gutter_icon(line, _l31, null)
		_t5.set_line_gutter_clickable(line, _l31, false)

func _z28():
	if not _t5 or not is_instance_valid(_c67):
		return
	
	if not is_inside_tree():
		return
	
	_c67.stop()
	_c67.start()

func _g80(line: int) -> Dictionary:
	for _s29 in _e29:
		if _s29.line == line:
			return _s29
	return {}

func _g67():
	if _p60 and _t5 and _g7:
		_d68()

func _e25():
	if _p60 and _t5 and _g7:
		_d68()

func _k63():
	_y22()
	
	if is_instance_valid(_c67):
		_c67.queue_free()
		_c67 = null
	
	if _b50 and _b50.editor_script_changed.is_connected(_u14):
		_b50.editor_script_changed.disconnect(_u14)
	
	_u65 = null
	_q86 = null
	_b50 = null
	_t5 = null
	_e29.clear()
	_w47 = null

func _b81(line: int) -> Dictionary:
	for _s29 in _e29:
		if _s29.line == line:
			return _s29
	return {}

func _r2() -> Array:
	return _e29.duplicate()

func _i70(content: String) -> bool:
	if content.is_empty():
		return false
	
	var _o34 = [
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
	
	for _c84 in _o34:
		if _c84 in content:
			return true
	
	return false

func _h100(line: String) -> bool:
	var _e54 = line.strip_edges()
	
	return "func " in _e54 and "(" in _e54

func _z87():
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		_v99 = config.get_value("refactor", "max_function_lines", 300)
	else:
		_v99 = 300

func _d91(limit: int):
	_v99 = max(50, limit)  
	
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")
	config.set_value("refactor", "max_function_lines", _v99)
	config.save("user://gdsense_api_key.cfg")

func get_function_size_limit() -> int:
	return _v99

func _l82(_s100):
	_w18 = weakref(_s100)

func _m65(_u75: Dictionary):
	if _w18 and _w18.get_ref():
		var _s100 = _w18.get_ref()
		if _s100.has_method("update_gutters_after_refactor"):
			_s100.update_gutters_after_refactor(_u75)
func get_current_script_editor() -> CodeEdit:
	return _t5

func _t81():
	if _p60 and _t5 and _g7:
		_d68()

