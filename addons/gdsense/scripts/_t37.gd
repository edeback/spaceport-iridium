@tool
class_name _k44
extends Control

signal _t27(function_name: String, file_path: String)

var _u65: EditorPlugin
var _q86: EditorInterface
var _b50: ScriptEditor
var _t5: CodeEdit
var _p60: bool = true
var _e29: Array = []
var _g7: bool = false
var _t11: int = -1  
var _c67: Timer
var _w47: RegEx  
var _r38: _w99

func _init(_u63: EditorPlugin, _t25: _w99):
	_u65 = _u63
	_r38 = _t25
	_q86 = _u63.get_editor_interface()
	_b50 = _q86.get_script_editor()
	
	_c67 = Timer.new()
	_c67.wait_time = 0.5  
	_c67.one_shot = true
	_c67.timeout.connect(_g67)
	add_child(_c67)
	
	_w47 = RegEx.new()
	_w47.compile("^\\s*func\\s+([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\(")
	
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
	_t11 = -1

func _w77():
	if not _t5:
		return
	
	var _e52 = _t5.get_gutter_count()
	var _q51 = -1
	
	for i in range(_e52):
		if _t5.get_gutter_name(i) == "undo":
			_q51 = i
			break
	
	if _q51 >= 0:
		_t11 = _q51
		_g7 = true
	elif not _g7:
		_t5.add_gutter()
		_t11 = _e52  
		
		_t5.set_gutter_name(_t11, "undo")
		_t5.set_gutter_width(_t11, 28)  
		_t5.set_gutter_draw(_t11, true)
		_t5.set_gutter_clickable(_t11, true)
		_t5.set_gutter_overwritable(_t11, false)
		_t5.set_gutter_type(_t11, TextEdit.GUTTER_TYPE_ICON)
		
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
	var _w66 = _b50.get_current_script()
	var file_path = _w66.resource_path if _w66 else ""
	
	for _u8 in range(_m12.size()):
		var line = _m12[_u8]
		var _k3 = _w47.search(line)
		
		if _k3:
			if not _h100(line):
				continue
			
			var function_name = _k3.get_string(1)
			
			if _r38._p100(function_name, file_path):
				var _z44 = _i9(_m12, _u8)
				var _g12 = _z44 - _u8 + 1
				
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
	
	var _n18 = _j75()
	
	_t5.set_line_gutter_icon(_u8, _t11, _n18)
	_t5.set_line_gutter_clickable(_u8, _t11, true)
	
func _j75() -> ImageTexture:
	var _g32 = Image.create(28, 28, false, Image.FORMAT_RGBA8)
	_g32.fill(Color(0, 0, 0, 0))  

	var color = Color(1.0, 0.7, 0.3, 1.0)  

	for angle in range(90, 270, 10):  
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

	for x in range(2, 9):
		_g32.set_pixel(x, 5, color)
		_g32.set_pixel(x, 6, color)
		_g32.set_pixel(x, 7, color)

	for y in range(2, 9):
		_g32.set_pixel(5, y, color)
		_g32.set_pixel(6, y, color)
		_g32.set_pixel(7, y, color)

	_g32.set_pixel(3, 3, color)
	_g32.set_pixel(4, 4, color)
	_g32.set_pixel(8, 8, color)
	_g32.set_pixel(9, 9, color)

	var texture = ImageTexture.new()
	texture.set_image(_g32)
	return texture

func _a23(line: int, _g51: int):
	if not _p60 or _g51 != _t11:
		return
	
	var _s29 = _g80(line)
	if _s29.is_empty():
		return
	
	var _d36 = ""
	var _w66 = _b50.get_current_script()
	if _w66:
		_d36 = _w66.resource_path
	
	if not _d36.is_empty() and not FileAccess.file_exists(_d36):
		push_error("Cannot undo refactor: File has been moved or deleted")
		return
	
	if not _z16(_s29.name, _d36):
		pass

	_t27.emit(_s29.name, _d36)

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
		_t5.set_line_gutter_icon(line, _t11, null)
		_t5.set_line_gutter_clickable(line, _t11, false)

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
		_c67.stop()
		if _c67.timeout.is_connected(_g67):
			_c67.timeout.disconnect(_g67)
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
	_r38 = null

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

func _z16(function_name: String, file_path: String) -> bool:
	if not _r38 or file_path.is_empty():
		return true  
	
	var _j91 = _r38._z80(function_name, file_path)
	if not _j91:
		return true  
	
	var _e14 = _r12(function_name)
	if _e14.is_empty():
		return true  
	
	var _l37 = _e84(_e14)
	var _y80 = _e84(_j91.refactored_code)
	
	return _l37 == _y80

func _e84(code: String) -> String:
	var _m12 = code.split("\n")
	var _z51 = []

	for line in _m12:
		var _l9 = line.rstrip(" \t")
		_z51.append(_l9)

	while _z51.size() > 0 and _z51[-1].strip_edges().is_empty():
		_z51.pop_back()

	return "\n".join(_z51)

func _r12(function_name: String) -> String:
	if not _t5:
		return ""
	
	var text = _t5.text
	var _m12 = text.split("\n")
	
	var _s29 = {}
	for _q47 in _e29:
		if _q47.name == function_name:
			_s29 = _q47
			break
	
	if _s29.is_empty():
		return ""
	
	var start_line = _s29.line
	var end_line = _s29.end_line
	
	if start_line < 0 or end_line >= _m12.size():
		return ""
	
	var _r23 = []
	for i in range(start_line, end_line + 1):
		_r23.append(_m12[i])
	
	return "\n".join(_r23)

