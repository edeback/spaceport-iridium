@tool
class_name _j6
extends Control
signal _j4(function_name: String, file_path: String)
var _p68: EditorPlugin
var _b72: EditorInterface
var _y14: ScriptEditor
var _e95: CodeEdit
var _z42: bool = true
var _u95: Array = []
var _u90: bool = false
var _t36: int = -1  
var _d70: Timer
var _m99: RegEx  
var _t28: _z30
func _init(_z23: EditorPlugin, _q40: _z30):
	_p68 = _z23
	_t28 = _q40
	_b72 = _z23.get_editor_interface()
	_y14 = _b72.get_script_editor()
	_d70 = Timer.new()
	_d70.wait_time = 0.5  
	_d70.one_shot = true
	_d70.timeout.connect(_m94)
	add_child(_d70)
	_m99 = RegEx.new()
	_m99.compile("^\\s*func\\s+([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\(")
	if _y14 and not _y14.editor_script_changed.is_connected(_c17):
		_y14.editor_script_changed.connect(_c17)
	if _y14:
		_c17(_y14.get_current_script())
func set_enabled(enabled: bool):
	_z42 = enabled
	if _z42:
		_b56()
	else:
		_u31()
func is_enabled() -> bool:
	return _z42
func _c17(script: Script):
	if not script or not script.source_code:
		_v94()
		return
	var _s100 = script.resource_path
	if not _s100.is_empty() and not _s100.get_extension() == "gd":
		_v94()
		return
	if _s100.is_empty() or _s100.get_extension().is_empty():
		if not _k46(script.source_code):
			_v94()
			return
	_b56()
func _b56():
	_v94()
	var _j1 = _y14.get_current_editor()
	if not _j1:
		return
	_e95 = _b96(_j1)
	if not _e95:
		return
	if _z42:
		_u19()
	else:
		pass
func _b96(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node
	for _i64 in node.get_children():
		var _n37 = _b96(_i64)
		if _n37:
			return _n37
	return null
func _v94():
	_u31()
	if _e95:
		if _e95.text_changed.is_connected(_w3):
			_e95.text_changed.disconnect(_w3)
		if _e95.gutter_clicked.is_connected(_i26):
			_e95.gutter_clicked.disconnect(_i26)
	_e95 = null
	_u95.clear()
	_u90 = false
	_t36 = -1
func _u19():
	if not _e95:
		return
	var _z55 = _e95.get_gutter_count()
	var _j27 = -1
	for i in range(_z55):
		if _e95.get_gutter_name(i) == "undo":
			_j27 = i
			break
	if _j27 >= 0:
		_t36 = _j27
		_u90 = true
	elif not _u90:
		_e95.add_gutter()
		_t36 = _z55  
		_e95.set_gutter_name(_t36, "undo")
		_e95.set_gutter_width(_t36, 28)  
		_e95.set_gutter_draw(_t36, true)
		_e95.set_gutter_clickable(_t36, true)
		_e95.set_gutter_overwritable(_t36, false)
		_e95.set_gutter_type(_t36, TextEdit.GUTTER_TYPE_ICON)
		_u90 = true
	if _e95.has_signal("text_changed"):
		if not _e95.text_changed.is_connected(_w3):
			_e95.text_changed.connect(_w3)
	if _e95.has_signal("gutter_clicked"):
		if not _e95.gutter_clicked.is_connected(_i26):
			_e95.gutter_clicked.connect(_i26)
	_m76()
func _m76():
	if not _e95 or not _u90:
		return
	_u31()
	_u95.clear()
	var text = _e95.text
	var _a62 = text.split("\n")
	var _l100 = _y14.get_current_script()
	var file_path = _l100.resource_path if _l100 else ""
	for _s87 in range(_a62.size()):
		var line = _a62[_s87]
		var _n37 = _m99.search(line)
		if _n37:
			if not _z74(line):
				continue
			var function_name = _n37.get_string(1)
			if _t28._k38(function_name, file_path):
				var _e82 = _w78(_a62, _s87)
				var _j61 = _e82 - _s87 + 1
				var _a20 = {
					"name": function_name,
					"line": _s87,
					"declaration_line": line,
					"end_line": _e82
				}
				_u95.append(_a20)
				_n75(_s87, function_name)
func _n75(_s87: int, function_name: String):
	if not _e95 or not _u90:
		return
	var _h99 = _f32()
	_e95.set_line_gutter_icon(_s87, _t36, _h99)
	_e95.set_line_gutter_clickable(_s87, _t36, true)
func _f32() -> ImageTexture:
	var _h18 = Image.create(28, 28, false, Image.FORMAT_RGBA8)
	_h18.fill(Color(0, 0, 0, 0))  
	var color = Color(1.0, 0.7, 0.3, 1.0)  
	for angle in range(90, 270, 10):  
		var _b100 = deg_to_rad(angle)
		var x = int(14 + 9 * cos(_b100))
		var y = int(14 + 9 * sin(_b100))
		if x >= 0 and x < 28 and y >= 0 and y < 28:
			_h18.set_pixel(x, y, color)
			if x + 1 < 28:
				_h18.set_pixel(x + 1, y, color)
			if y + 1 < 28:
				_h18.set_pixel(x, y + 1, color)
			if x + 2 < 28:
				_h18.set_pixel(x + 2, y, color)
			if y + 2 < 28:
				_h18.set_pixel(x, y + 2, color)
	for x in range(2, 9):
		_h18.set_pixel(x, 5, color)
		_h18.set_pixel(x, 6, color)
		_h18.set_pixel(x, 7, color)
	for y in range(2, 9):
		_h18.set_pixel(5, y, color)
		_h18.set_pixel(6, y, color)
		_h18.set_pixel(7, y, color)
	_h18.set_pixel(3, 3, color)
	_h18.set_pixel(4, 4, color)
	_h18.set_pixel(8, 8, color)
	_h18.set_pixel(9, 9, color)
	var texture = ImageTexture.new()
	texture.set_image(_h18)
	return texture
func _i26(line: int, _a75: int):
	if not _z42 or _a75 != _t36:
		return
	var _a20 = _k88(line)
	if _a20.is_empty():
		return
	var _s100 = ""
	var _l100 = _y14.get_current_script()
	if _l100:
		_s100 = _l100.resource_path
	if not _s100.is_empty() and not FileAccess.file_exists(_s100):
		push_error("Cannot undo refactor: File has been moved or deleted")
		return
	if not _y73(_a20.name, _s100):
		pass
	_j4.emit(_a20.name, _s100)
func _w78(_a62: PackedStringArray, start_line: int) -> int:
	if start_line >= _a62.size():
		return start_line
	var _v93 = _d23(_a62[start_line])
	for i in range(start_line + 1, _a62.size()):
		var line = _a62[i]
		var _o40 = line.strip_edges()
		if _o40.is_empty() or _o40.begins_with("#"):
			continue
		var _h92 = _d23(line)
		if _h92 <= _v93:
			if _o40.begins_with("func ") or _o40.begins_with("class ") or _o40.begins_with("extends") or _o40.begins_with("@"):
				return i - 1
	return _a62.size() - 1
func _d23(line: String) -> int:
	var indent = 0
	for _c28 in line:
		if _c28 == '\t':
			indent += 4  
		elif _c28 == ' ':
			indent += 1
		else:
			break
	return indent
func _u31():
	if not _e95 or not _u90:
		return
	var _d99 = _e95.get_line_count()
	for line in range(_d99):
		_e95.set_line_gutter_icon(line, _t36, null)
		_e95.set_line_gutter_clickable(line, _t36, false)
func _w3():
	if not _e95 or not is_instance_valid(_d70):
		return
	if not is_inside_tree():
		return
	_d70.stop()
	_d70.start()
func _k88(line: int) -> Dictionary:
	for _a20 in _u95:
		if _a20.line == line:
			return _a20
	return {}
func _m94():
	if _z42 and _e95 and _u90:
		_m76()
func _h100():
	if _z42 and _e95 and _u90:
		_m76()
func _h41():
	_v94()
	if is_instance_valid(_d70):
		_d70.stop()
		if _d70.timeout.is_connected(_m94):
			_d70.timeout.disconnect(_m94)
		_d70.queue_free()
		_d70 = null
	if _y14 and _y14.editor_script_changed.is_connected(_c17):
		_y14.editor_script_changed.disconnect(_c17)
	_p68 = null
	_b72 = null
	_y14 = null
	_e95 = null
	_u95.clear()
	_m99 = null
	_t28 = null
func _a89(line: int) -> Dictionary:
	for _a20 in _u95:
		if _a20.line == line:
			return _a20
	return {}
func _o95() -> Array:
	return _u95.duplicate()
func _k46(content: String) -> bool:
	if content.is_empty():
		return false
	var _q21 = [
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
	for _a45 in _q21:
		if _a45 in content:
			return true
	return false
func _z74(line: String) -> bool:
	var _o40 = line.strip_edges()
	return "func " in _o40 and "(" in _o40
func _y73(function_name: String, file_path: String) -> bool:
	if not _t28 or file_path.is_empty():
		return true  
	var _x74 = _t28._o96(function_name, file_path)
	if not _x74:
		return true  
	var _f74 = _t44(function_name)
	if _f74.is_empty():
		return true  
	var _s75 = _f60(_f74)
	var _i35 = _f60(_x74.refactored_code)
	return _s75 == _i35
func _f60(code: String) -> String:
	var _a62 = code.split("\n")
	var _r47 = []
	for line in _a62:
		var _o62 = line.rstrip(" \t")
		_r47.append(_o62)
	while _r47.size() > 0 and _r47[-1].strip_edges().is_empty():
		_r47.pop_back()
	return "\n".join(_r47)
func _t44(function_name: String) -> String:
	if not _e95:
		return ""
	var text = _e95.text
	var _a62 = text.split("\n")
	var _a20 = {}
	for _x34 in _u95:
		if _x34.name == function_name:
			_a20 = _x34
			break
	if _a20.is_empty():
		return ""
	var start_line = _a20.line
	var end_line = _a20.end_line
	if start_line < 0 or end_line >= _a62.size():
		return ""
	var _m35 = []
	for i in range(start_line, end_line + 1):
		_m35.append(_a62[i])
	return "\n".join(_m35)
