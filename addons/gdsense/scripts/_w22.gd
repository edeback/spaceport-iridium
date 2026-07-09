@tool
class_name _e58
extends Control
signal _a59(function_name: String, _w94: String)
const _k1 = 300
var _p68: EditorPlugin
var _b72: EditorInterface
var _y14: ScriptEditor
var _e95: CodeEdit
var _z42: bool = true
var _u95: Array = []
var _u90: bool = false
var _b49: int = -1  
var _d70: Timer  
func _init(_z23: EditorPlugin):
	_p68 = _z23
	_b72 = _z23.get_editor_interface()
	_y14 = _b72.get_script_editor()
	_d70 = Timer.new()
	_d70.wait_time = 0.5  
	_d70.one_shot = true
	_d70.timeout.connect(_m94)
	add_child(_d70)
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
	_b49 = -1
func _u19():
	if not _e95:
		return
	var _z55 = _e95.get_gutter_count()
	var _j27 = -1
	for i in range(_z55):
		if _e95.get_gutter_name(i) == "explain":
			_j27 = i
			break
	if _j27 >= 0:
		_b49 = _j27
		_u90 = true
	elif not _u90:
		_e95.add_gutter()
		_b49 = _z55  
		_e95.set_gutter_name(_b49, "explain")
		_e95.set_gutter_width(_b49, 28)  
		_e95.set_gutter_draw(_b49, true)
		_e95.set_gutter_clickable(_b49, true)
		_e95.set_gutter_overwritable(_b49, false)
		_e95.set_gutter_type(_b49, TextEdit.GUTTER_TYPE_ICON)
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
	var _j70 = RegEx.new()
	_j70.compile("^\\s*func\\s+([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\(")
	for _s87 in range(_a62.size()):
		var line = _a62[_s87]
		var _n37 = _j70.search(line)
		if _n37:
			if not _z74(line):
				continue
			var function_name = _n37.get_string(1)
			var _e82 = _w78(_a62, _s87)
			var _j61 = _e82 - _s87 + 1
			if _j61 > _k1:
				continue
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
	var _h99 = _i83()
	_e95.set_line_gutter_icon(_s87, _b49, _h99)
	_e95.set_line_gutter_clickable(_s87, _b49, true)
func _i83() -> ImageTexture:
	var _h18 = Image.create(28, 28, false, Image.FORMAT_RGBA8)
	_h18.fill(Color(0, 0, 0, 0))  
	var color = Color(1.0, 1.0, 1.0, 1.0)  
	for x in range(7, 21):
		_h18.set_pixel(x, 5, color)
		_h18.set_pixel(x, 6, color)
		_h18.set_pixel(x, 7, color)
		_h18.set_pixel(x, 8, color)
	for y in range(5, 12):
		_h18.set_pixel(6, y, color)
		_h18.set_pixel(7, y, color)
		_h18.set_pixel(8, y, color)
	for y in range(5, 15):
		_h18.set_pixel(19, y, color)
		_h18.set_pixel(20, y, color)
		_h18.set_pixel(21, y, color)
	for x in range(12, 21):
		_h18.set_pixel(x, 12, color)
		_h18.set_pixel(x, 13, color)
		_h18.set_pixel(x, 14, color)
	for y in range(15, 19):
		_h18.set_pixel(12, y, color)
		_h18.set_pixel(13, y, color)
		_h18.set_pixel(14, y, color)
		_h18.set_pixel(15, y, color)
	for x in range(12, 16):
		for y in range(21, 25):
			_h18.set_pixel(x, y, color)
	var texture = ImageTexture.new()
	texture.set_image(_h18)
	return texture
func _i26(line: int, _a75: int):
	if not _z42 or _a75 != _b49:
		return
	var _a20 = _k88(line)
	if _a20.is_empty():
		return
	if not _p68 or not _p68._e2:
		return
	var _w94 = _v21(_a20)
	if _w94.is_empty():
		return
	_a59.emit(_a20.name, _w94)
func _v21(_s30: Dictionary) -> String:
	if not _e95:
		return ""
	var text = _e95.text
	var _a62 = text.split("\n")
	var start_line = _s30.line
	var function_name = _s30.name
	if start_line < 0 or start_line >= _a62.size():
		return ""
	var end_line: int
	if _s30.has("end_line"):
		end_line = _s30.end_line
	else:
		end_line = _w78(_a62, start_line)
	if end_line < start_line:
		return ""
	var _j61 = end_line - start_line + 1
	if _j61 > _k1:
		return ""
	var _m35 = []
	for i in range(start_line, min(end_line + 1, _a62.size())):
		_m35.append(_a62[i])
	if _m35.is_empty():
		return ""
	return "\n".join(_m35)
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
		_e95.set_line_gutter_icon(line, _b49, null)
		_e95.set_line_gutter_clickable(line, _b49, false)
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
		_d70.queue_free()
		_d70 = null
	if _y14 and _y14.editor_script_changed.is_connected(_c17):
		_y14.editor_script_changed.disconnect(_c17)
	_p68 = null
	_b72 = null
	_y14 = null
	_e95 = null
	_u95.clear()
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
