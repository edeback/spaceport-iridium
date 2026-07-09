@tool
class_name _j51
extends Control
signal _i8(function_name: String, file_path: String)
var _l1: EditorPlugin
var _r15: EditorInterface
var _e3: ScriptEditor
var _v99: CodeEdit
var _k83: bool = true
var _k33: Array = []
var _d65: bool = false
var _c54: int = -1  
var _u76: Timer
var _u8: RegEx  
var _m6: _z9
func _init(_b89: EditorPlugin, _t63: _z9):
	_l1 = _b89
	_m6 = _t63
	_r15 = _b89.get_editor_interface()
	_e3 = _r15.get_script_editor()
	_u76 = Timer.new()
	_u76.wait_time = 0.5  
	_u76.one_shot = true
	_u76.timeout.connect(_y96)
	add_child(_u76)
	_u8 = RegEx.new()
	_u8.compile("^\\s*func\\s+([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\(")
	if _e3 and not _e3.editor_script_changed.is_connected(_u5):
		_e3.editor_script_changed.connect(_u5)
	if _e3:
		_u5(_e3.get_current_script())
func set_enabled(enabled: bool):
	_k83 = enabled
	if _k83:
		_n32()
	else:
		_n17()
func is_enabled() -> bool:
	return _k83
func _u5(script: Script):
	if not script or not script.source_code:
		_h98()
		return
	var _x58 = script.resource_path
	if not _x58.is_empty() and not _x58.get_extension() == "gd":
		_h98()
		return
	if _x58.is_empty() or _x58.get_extension().is_empty():
		if not _z88(script.source_code):
			_h98()
			return
	_n32()
func _n32():
	_h98()
	var _d32 = _e3.get_current_editor()
	if not _d32:
		return
	_v99 = _v35(_d32)
	if not _v99:
		return
	if _k83:
		_z60()
	else:
		pass
func _v35(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node
	for _x15 in node.get_children():
		var _e21 = _v35(_x15)
		if _e21:
			return _e21
	return null
func _h98():
	_n17()
	if _v99:
		if _v99.text_changed.is_connected(_b45):
			_v99.text_changed.disconnect(_b45)
		if _v99.gutter_clicked.is_connected(_r13):
			_v99.gutter_clicked.disconnect(_r13)
	_v99 = null
	_k33.clear()
	_d65 = false
	_c54 = -1
func _z60():
	if not _v99:
		return
	var _o84 = _v99.get_gutter_count()
	var _w69 = -1
	for i in range(_o84):
		if _v99.get_gutter_name(i) == "undo":
			_w69 = i
			break
	if _w69 >= 0:
		_c54 = _w69
		_d65 = true
	elif not _d65:
		_v99.add_gutter()
		_c54 = _o84  
		_v99.set_gutter_name(_c54, "undo")
		_v99.set_gutter_width(_c54, 28)  
		_v99.set_gutter_draw(_c54, true)
		_v99.set_gutter_clickable(_c54, true)
		_v99.set_gutter_overwritable(_c54, false)
		_v99.set_gutter_type(_c54, TextEdit.GUTTER_TYPE_ICON)
		_d65 = true
	if _v99.has_signal("text_changed"):
		if not _v99.text_changed.is_connected(_b45):
			_v99.text_changed.connect(_b45)
	if _v99.has_signal("gutter_clicked"):
		if not _v99.gutter_clicked.is_connected(_r13):
			_v99.gutter_clicked.connect(_r13)
	_s17()
func _s17():
	if not _v99 or not _d65:
		return
	_n17()
	_k33.clear()
	var text = _v99.text
	var _p91 = text.split("\n")
	var _y36 = _e3.get_current_script()
	var file_path = _y36.resource_path if _y36 else ""
	for _k72 in range(_p91.size()):
		var line = _p91[_k72]
		var _e21 = _u8.search(line)
		if _e21:
			if not _v74(line):
				continue
			var function_name = _e21.get_string(1)
			if _m6._c19(function_name, file_path):
				var _x99 = _l44(_p91, _k72)
				var _u37 = _x99 - _k72 + 1
				var _e92 = {
					"name": function_name,
					"line": _k72,
					"declaration_line": line,
					"end_line": _x99
				}
				_k33.append(_e92)
				_x50(_k72, function_name)
func _x50(_k72: int, function_name: String):
	if not _v99 or not _d65:
		return
	var _h50 = _m4()
	_v99.set_line_gutter_icon(_k72, _c54, _h50)
	_v99.set_line_gutter_clickable(_k72, _c54, true)
func _m4() -> ImageTexture:
	var _f21 = Image.create(28, 28, false, Image.FORMAT_RGBA8)
	_f21.fill(Color(0, 0, 0, 0))  
	var color = Color(1.0, 0.7, 0.3, 1.0)  
	for angle in range(90, 270, 10):  
		var _j55 = deg_to_rad(angle)
		var x = int(14 + 9 * cos(_j55))
		var y = int(14 + 9 * sin(_j55))
		if x >= 0 and x < 28 and y >= 0 and y < 28:
			_f21.set_pixel(x, y, color)
			if x + 1 < 28:
				_f21.set_pixel(x + 1, y, color)
			if y + 1 < 28:
				_f21.set_pixel(x, y + 1, color)
			if x + 2 < 28:
				_f21.set_pixel(x + 2, y, color)
			if y + 2 < 28:
				_f21.set_pixel(x, y + 2, color)
	for x in range(2, 9):
		_f21.set_pixel(x, 5, color)
		_f21.set_pixel(x, 6, color)
		_f21.set_pixel(x, 7, color)
	for y in range(2, 9):
		_f21.set_pixel(5, y, color)
		_f21.set_pixel(6, y, color)
		_f21.set_pixel(7, y, color)
	_f21.set_pixel(3, 3, color)
	_f21.set_pixel(4, 4, color)
	_f21.set_pixel(8, 8, color)
	_f21.set_pixel(9, 9, color)
	var texture = ImageTexture.new()
	texture.set_image(_f21)
	return texture
func _r13(line: int, _w96: int):
	if not _k83 or _w96 != _c54:
		return
	var _e92 = _m95(line)
	if _e92.is_empty():
		return
	var _x58 = ""
	var _y36 = _e3.get_current_script()
	if _y36:
		_x58 = _y36.resource_path
	if not _x58.is_empty() and not FileAccess.file_exists(_x58):
		push_error("Cannot undo refactor: File has been moved or deleted")
		return
	if not _u21(_e92.name, _x58):
		pass
	_i8.emit(_e92.name, _x58)
func _l44(_p91: PackedStringArray, start_line: int) -> int:
	if start_line >= _p91.size():
		return start_line
	var _u53 = _t61(_p91[start_line])
	for i in range(start_line + 1, _p91.size()):
		var line = _p91[i]
		var _w61 = line.strip_edges()
		if _w61.is_empty() or _w61.begins_with("#"):
			continue
		var _w5 = _t61(line)
		if _w5 <= _u53:
			if _w61.begins_with("func ") or _w61.begins_with("class ") or _w61.begins_with("extends") or _w61.begins_with("@"):
				return i - 1
	return _p91.size() - 1
func _t61(line: String) -> int:
	var indent = 0
	for char in line:
		if char == '\t':
			indent += 4  
		elif char == ' ':
			indent += 1
		else:
			break
	return indent
func _n17():
	if not _v99 or not _d65:
		return
	var _t98 = _v99.get_line_count()
	for line in range(_t98):
		_v99.set_line_gutter_icon(line, _c54, null)
		_v99.set_line_gutter_clickable(line, _c54, false)
func _b45():
	if not _v99 or not is_instance_valid(_u76):
		return
	if not is_inside_tree():
		return
	_u76.stop()
	_u76.start()
func _m95(line: int) -> Dictionary:
	for _e92 in _k33:
		if _e92.line == line:
			return _e92
	return {}
func _y96():
	if _k83 and _v99 and _d65:
		_s17()
func _e55():
	if _k83 and _v99 and _d65:
		_s17()
func _u75():
	_h98()
	if is_instance_valid(_u76):
		_u76.stop()
		if _u76.timeout.is_connected(_y96):
			_u76.timeout.disconnect(_y96)
		_u76.queue_free()
		_u76 = null
	if _e3 and _e3.editor_script_changed.is_connected(_u5):
		_e3.editor_script_changed.disconnect(_u5)
	_l1 = null
	_r15 = null
	_e3 = null
	_v99 = null
	_k33.clear()
	_u8 = null
	_m6 = null
func _f33(line: int) -> Dictionary:
	for _e92 in _k33:
		if _e92.line == line:
			return _e92
	return {}
func _a93() -> Array:
	return _k33.duplicate()
func _z88(content: String) -> bool:
	if content.is_empty():
		return false
	var _c93 = [
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
	for _j73 in _c93:
		if _j73 in content:
			return true
	return false
func _v74(line: String) -> bool:
	var _w61 = line.strip_edges()
	return "func " in _w61 and "(" in _w61
func _u21(function_name: String, file_path: String) -> bool:
	if not _m6 or file_path.is_empty():
		return true  
	var _r10 = _m6._b56(function_name, file_path)
	if not _r10:
		return true  
	var _k11 = _b41(function_name)
	if _k11.is_empty():
		return true  
	var _c27 = _o3(_k11)
	var _x87 = _o3(_r10.refactored_code)
	return _c27 == _x87
func _o3(code: String) -> String:
	var _p91 = code.split("\n")
	var _x17 = []
	for line in _p91:
		var _l58 = line.rstrip(" \t")
		_x17.append(_l58)
	while _x17.size() > 0 and _x17[-1].strip_edges().is_empty():
		_x17.pop_back()
	return "\n".join(_x17)
func _b41(function_name: String) -> String:
	if not _v99:
		return ""
	var text = _v99.text
	var _p91 = text.split("\n")
	var _e92 = {}
	for _f100 in _k33:
		if _f100.name == function_name:
			_e92 = _f100
			break
	if _e92.is_empty():
		return ""
	var start_line = _e92.line
	var end_line = _e92.end_line
	if start_line < 0 or end_line >= _p91.size():
		return ""
	var _o22 = []
	for i in range(start_line, end_line + 1):
		_o22.append(_p91[i])
	return "\n".join(_o22)
