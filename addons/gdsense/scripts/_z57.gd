@tool
class_name _z54
extends Control
signal _s39(function_name: String, _w13: String, file_path: String)
var _g23: EditorPlugin
var _w27: EditorInterface
var _k94: ScriptEditor
var _g87: CodeEdit
var _o9: bool = true
var _n44: Array = []
var _k44: bool = false
var _k13: int = -1  
var _t86: Timer
var _i81: RegEx  
var _j70: int = 300  
var _u31: WeakRef  
func _init(_m21: EditorPlugin):
	_g23 = _m21
	_w27 = _m21.get_editor_interface()
	_k94 = _w27.get_script_editor()
	_t86 = Timer.new()
	_t86.wait_time = 0.5  
	_t86.one_shot = true
	_t86.timeout.connect(_b17)
	add_child(_t86)
	_i81 = RegEx.new()
	_i81.compile("^\\s*func\\s+([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\(")
	_p68()
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
	_k13 = -1
func _y32():
	if not _g87:
		return
	var _d71 = _g87.get_gutter_count()
	var _y86 = -1
	for i in range(_d71):
		if _g87.get_gutter_name(i) == "refactor":
			_y86 = i
			break
	if _y86 >= 0:
		_k13 = _y86
		_k44 = true
	elif not _k44:
		_g87.add_gutter()
		_k13 = _d71  
		_g87.set_gutter_name(_k13, "refactor")
		_g87.set_gutter_width(_k13, 28)  
		_g87.set_gutter_draw(_k13, true)
		_g87.set_gutter_clickable(_k13, true)
		_g87.set_gutter_overwritable(_k13, false)
		_g87.set_gutter_type(_k13, TextEdit.GUTTER_TYPE_ICON)
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
	for _x19 in range(_j90.size()):
		var line = _j90[_x19]
		var _x97 = _i81.search(line)
		if _x97:
			if not _u6(line):
				continue
			var function_name = _x97.get_string(1)
			var _e8 = _p36(_j90, _x19)
			var _v33 = _e8 - _x19 + 1
			if _v33 > _j70:
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
	var _d21 = _v60()
	_g87.set_line_gutter_icon(_x19, _k13, _d21)
	_g87.set_line_gutter_clickable(_x19, _k13, true)
func _v60() -> ImageTexture:
	var _k48 = Image.create(28, 28, false, Image.FORMAT_RGBA8)
	_k48.fill(Color(0, 0, 0, 0))  
	var color = Color(0.8, 1.0, 0.8, 1.0)  
	for angle in range(0, 360, 10):
		var _f80 = deg_to_rad(angle)
		var x = int(14 + 9 * cos(_f80))
		var y = int(14 + 9 * sin(_f80))
		if x >= 0 and x < 28 and y >= 0 and y < 28:
			_k48.set_pixel(x, y, color)
			if x + 1 < 28:
				_k48.set_pixel(x + 1, y, color)
			if y + 1 < 28:
				_k48.set_pixel(x, y + 1, color)
			if x + 2 < 28:
				_k48.set_pixel(x + 2, y, color)
			if y + 2 < 28:
				_k48.set_pixel(x, y + 2, color)
	for x in range(21, 26):
		_k48.set_pixel(x, 7, color)
		_k48.set_pixel(x, 8, color)
		_k48.set_pixel(x, 9, color)
	_k48.set_pixel(22, 5, color)
	_k48.set_pixel(23, 4, color)
	_k48.set_pixel(24, 3, color)
	_k48.set_pixel(22, 6, color)
	_k48.set_pixel(23, 5, color)
	_k48.set_pixel(22, 10, color)
	_k48.set_pixel(23, 11, color)
	_k48.set_pixel(24, 12, color)
	_k48.set_pixel(22, 11, color)
	_k48.set_pixel(23, 12, color)
	var texture = ImageTexture.new()
	texture.set_image(_k48)
	return texture
func _e43(line: int, _k100: int):
	if not _o9 or _k100 != _k13:
		return
	var _l98 = _r71(line)
	if _l98.is_empty():
		return
	var _w13 = _y91(_l98)
	if _w13.is_empty():
		return
	var _r98 = ""
	var _d90 = _k94.get_current_script()
	if _d90:
		_r98 = _d90.resource_path
	_s39.emit(_l98.name, _w13, _r98)
func _y91(_v83: Dictionary) -> String:
	if not _g87:
		push_error("ScriptRefactorOverlay: No current script editor available for function extraction")
		return ""
	var text = _g87.text
	var _j90 = text.split("\n")
	var start_line = _v83.line
	var function_name = _v83.name
	if start_line < 0 or start_line >= _j90.size():
		push_error("ScriptRefactorOverlay: Invalid start line %d for function '%s'. Check script integrity." % [start_line, function_name])
		return ""
	var end_line: int
	if _v83.has("end_line"):
		end_line = _v83.end_line
	else:
		end_line = _p36(_j90, start_line)
	if end_line < start_line:
		push_error("ScriptRefactorOverlay: Invalid end line %d for function '%s'. Function parsing failed." % [end_line, function_name])
		return ""
	var _v33 = end_line - start_line + 1
	if _v33 > _j70:
		push_error("ScriptRefactorOverlay: Function '%s' is too large (%d lines, max %d). Consider breaking it into smaller functions." % [function_name, _v33, _j70])
		return ""
	var _g49 = []
	for i in range(start_line, min(end_line + 1, _j90.size())):
		_g49.append(_j90[i])
	if _g49.is_empty():
		push_error("ScriptRefactorOverlay: No function lines extracted for '%s'. The function may be malformed." % function_name)
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
		_g87.set_line_gutter_icon(line, _k13, null)
		_g87.set_line_gutter_clickable(line, _k13, false)
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
	_i81 = null
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
func _p68():
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		_j70 = config.get_value("refactor", "max_function_lines", 300)
	else:
		_j70 = 300
func _o53(limit: int):
	_j70 = max(50, limit)  
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")
	config.set_value("refactor", "max_function_lines", _j70)
	config.save("user://gdsense_api_key.cfg")
func get_function_size_limit() -> int:
	return _j70
func _o78(_w30):
	_u31 = weakref(_w30)
func _v65(_n86: Dictionary):
	if _u31 and _u31.get_ref():
		var _w30 = _u31.get_ref()
		if _w30.has_method("update_gutters_after_refactor"):
			_w30.update_gutters_after_refactor(_n86)
func get_current_script_editor() -> CodeEdit:
	return _g87
func _i67():
	if _o9 and _g87 and _k44:
		_b88()
