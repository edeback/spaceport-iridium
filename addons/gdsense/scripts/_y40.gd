@tool
class_name _q64
extends Control
signal _i32(function_name: String, _w13: String)
const _c11 = 300
var _g23: EditorPlugin
var _w27: EditorInterface
var _k94: ScriptEditor
var _g87: CodeEdit
var _o9: bool = true
var _n44: Array = []
var _k44: bool = false
var _u65: int = -1  
var _t86: Timer  
func _init(_m21: EditorPlugin):
	_g23 = _m21
	_w27 = _m21.get_editor_interface()
	_k94 = _w27.get_script_editor()
	_t86 = Timer.new()
	_t86.wait_time = 0.5  
	_t86.one_shot = true
	_t86.timeout.connect(_b17)
	add_child(_t86)
	if _k94 and not _k94.editor_script_changed.is_connected(_c28):
		_k94.editor_script_changed.connect(_c28)
	if _k94:
		_c28(_k94.get_current_script())
func set_enabled(enabled: bool):
	_o9 = enabled
	if _o9:
		_i99()
	else:
		_s51()
func is_enabled() -> bool:
	return _o9
func _c28(script: Script):
	if not script or not script.source_code:
		_b67()
		return
	var _r98 = script.resource_path
	if not _r98.is_empty() and not _r98.get_extension() == "gd":
		_b67()
		return
	if _r98.is_empty() or _r98.get_extension().is_empty():
		if not _r86(script.source_code):
			_b67()
			return
	_i99()
func _i99():
	_b67()
	var _p95 = _k94.get_current_editor()
	if not _p95:
		return
	_g87 = _k97(_p95)
	if not _g87:
		return
	if _o9:
		_y32()
	else:
		pass
func _k97(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node
	for _h61 in node.get_children():
		var _x97 = _k97(_h61)
		if _x97:
			return _x97
	return null
func _b67():
	_s51()
	if _g87:
		if _g87.text_changed.is_connected(_d6):
			_g87.text_changed.disconnect(_d6)
		if _g87.gutter_clicked.is_connected(_e43):
			_g87.gutter_clicked.disconnect(_e43)
	_g87 = null
	_n44.clear()
	_k44 = false
	_u65 = -1
func _y32():
	if not _g87:
		return
	var _d71 = _g87.get_gutter_count()
	var _y86 = -1
	for i in range(_d71):
		if _g87.get_gutter_name(i) == "explain":
			_y86 = i
			break
	if _y86 >= 0:
		_u65 = _y86
		_k44 = true
	elif not _k44:
		_g87.add_gutter()
		_u65 = _d71  
		_g87.set_gutter_name(_u65, "explain")
		_g87.set_gutter_width(_u65, 28)  
		_g87.set_gutter_draw(_u65, true)
		_g87.set_gutter_clickable(_u65, true)
		_g87.set_gutter_overwritable(_u65, false)
		_g87.set_gutter_type(_u65, TextEdit.GUTTER_TYPE_ICON)
		_k44 = true
	if _g87.has_signal("text_changed"):
		if not _g87.text_changed.is_connected(_d6):
			_g87.text_changed.connect(_d6)
	if _g87.has_signal("gutter_clicked"):
		if not _g87.gutter_clicked.is_connected(_e43):
			_g87.gutter_clicked.connect(_e43)
	_b88()
func _b88():
	if not _g87 or not _k44:
		return
	_s51()
	_n44.clear()
	var text = _g87.text
	var _j90 = text.split("\n")
	var _s22 = RegEx.new()
	_s22.compile("^\\s*func\\s+([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\(")
	for _x19 in range(_j90.size()):
		var line = _j90[_x19]
		var _x97 = _s22.search(line)
		if _x97:
			if not _u6(line):
				continue
			var function_name = _x97.get_string(1)
			var _e8 = _p36(_j90, _x19)
			var _v33 = _e8 - _x19 + 1
			if _v33 > _c11:
				continue
			var _l98 = {
				"name": function_name,
				"line": _x19,
				"declaration_line": line,
				"end_line": _e8
			}
			_n44.append(_l98)
			_k45(_x19, function_name)
func _k45(_x19: int, function_name: String):
	if not _g87 or not _k44:
		return
	var _d21 = _e57()
	_g87.set_line_gutter_icon(_x19, _u65, _d21)
	_g87.set_line_gutter_clickable(_x19, _u65, true)
func _e57() -> ImageTexture:
	var _k48 = Image.create(28, 28, false, Image.FORMAT_RGBA8)
	_k48.fill(Color(0, 0, 0, 0))  
	var color = Color(1.0, 1.0, 1.0, 1.0)  
	for x in range(7, 21):
		_k48.set_pixel(x, 5, color)
		_k48.set_pixel(x, 6, color)
		_k48.set_pixel(x, 7, color)
		_k48.set_pixel(x, 8, color)
	for y in range(5, 12):
		_k48.set_pixel(6, y, color)
		_k48.set_pixel(7, y, color)
		_k48.set_pixel(8, y, color)
	for y in range(5, 15):
		_k48.set_pixel(19, y, color)
		_k48.set_pixel(20, y, color)
		_k48.set_pixel(21, y, color)
	for x in range(12, 21):
		_k48.set_pixel(x, 12, color)
		_k48.set_pixel(x, 13, color)
		_k48.set_pixel(x, 14, color)
	for y in range(15, 19):
		_k48.set_pixel(12, y, color)
		_k48.set_pixel(13, y, color)
		_k48.set_pixel(14, y, color)
		_k48.set_pixel(15, y, color)
	for x in range(12, 16):
		for y in range(21, 25):
			_k48.set_pixel(x, y, color)
	var texture = ImageTexture.new()
	texture.set_image(_k48)
	return texture
func _e43(line: int, _k100: int):
	if not _o9 or _k100 != _u65:
		return
	var _l98 = _r71(line)
	if _l98.is_empty():
		return
	if not _g23 or not _g23._p1:
		return
	var _w13 = _y91(_l98)
	if _w13.is_empty():
		return
	_i32.emit(_l98.name, _w13)
func _y91(_v83: Dictionary) -> String:
	if not _g87:
		return ""
	var text = _g87.text
	var _j90 = text.split("\n")
	var start_line = _v83.line
	var function_name = _v83.name
	if start_line < 0 or start_line >= _j90.size():
		return ""
	var end_line: int
	if _v83.has("end_line"):
		end_line = _v83.end_line
	else:
		end_line = _p36(_j90, start_line)
	if end_line < start_line:
		return ""
	var _v33 = end_line - start_line + 1
	if _v33 > _c11:
		return ""
	var _g49 = []
	for i in range(start_line, min(end_line + 1, _j90.size())):
		_g49.append(_j90[i])
	if _g49.is_empty():
		return ""
	return "\n".join(_g49)
func _p36(_j90: PackedStringArray, start_line: int) -> int:
	if start_line >= _j90.size():
		return start_line
	var _f52 = _w73(_j90[start_line])
	for i in range(start_line + 1, _j90.size()):
		var line = _j90[i]
		var _o74 = line.strip_edges()
		if _o74.is_empty() or _o74.begins_with("#"):
			continue
		var _m64 = _w73(line)
		if _m64 <= _f52:
			if _o74.begins_with("func ") or _o74.begins_with("class ") or _o74.begins_with("extends") or _o74.begins_with("@"):
				return i - 1
	return _j90.size() - 1
func _w73(line: String) -> int:
	var indent = 0
	for _o41 in line:
		if _o41 == '\t':
			indent += 4  
		elif _o41 == ' ':
			indent += 1
		else:
			break
	return indent
func _s51():
	if not _g87 or not _k44:
		return
	var _k66 = _g87.get_line_count()
	for line in range(_k66):
		_g87.set_line_gutter_icon(line, _u65, null)
		_g87.set_line_gutter_clickable(line, _u65, false)
func _d6():
	if not _g87 or not is_instance_valid(_t86):
		return
	if not is_inside_tree():
		return
	_t86.stop()
	_t86.start()
func _r71(line: int) -> Dictionary:
	for _l98 in _n44:
		if _l98.line == line:
			return _l98
	return {}
func _b17():
	if _o9 and _g87 and _k44:
		_b88()
func _w86():
	if _o9 and _g87 and _k44:
		_b88()
func _q60():
	_b67()
	if is_instance_valid(_t86):
		_t86.queue_free()
		_t86 = null
	if _k94 and _k94.editor_script_changed.is_connected(_c28):
		_k94.editor_script_changed.disconnect(_c28)
	_g23 = null
	_w27 = null
	_k94 = null
	_g87 = null
	_n44.clear()
func _k84(line: int) -> Dictionary:
	for _l98 in _n44:
		if _l98.line == line:
			return _l98
	return {}
func _f69() -> Array:
	return _n44.duplicate()
func _r86(content: String) -> bool:
	if content.is_empty():
		return false
	var _i42 = [
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
	for _y99 in _i42:
		if _y99 in content:
			return true
	return false
func _u6(line: String) -> bool:
	var _o74 = line.strip_edges()
	return "func " in _o74 and "(" in _o74
