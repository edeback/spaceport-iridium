@tool
class_name _b73
extends Control
signal _a26(function_name: String, _k94: String)
const _v51 = 300
var _l1: EditorPlugin
var _r15: EditorInterface
var _e3: ScriptEditor
var _v99: CodeEdit
var _k83: bool = true
var _k33: Array = []
var _d65: bool = false
var _l86: int = -1  
var _u76: Timer  
func _init(_b89: EditorPlugin):
	_l1 = _b89
	_r15 = _b89.get_editor_interface()
	_e3 = _r15.get_script_editor()
	_u76 = Timer.new()
	_u76.wait_time = 0.5  
	_u76.one_shot = true
	_u76.timeout.connect(_y96)
	add_child(_u76)
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
	_l86 = -1
func _z60():
	if not _v99:
		return
	var _o84 = _v99.get_gutter_count()
	var _w69 = -1
	for i in range(_o84):
		if _v99.get_gutter_name(i) == "explain":
			_w69 = i
			break
	if _w69 >= 0:
		_l86 = _w69
		_d65 = true
	elif not _d65:
		_v99.add_gutter()
		_l86 = _o84  
		_v99.set_gutter_name(_l86, "explain")
		_v99.set_gutter_width(_l86, 28)  
		_v99.set_gutter_draw(_l86, true)
		_v99.set_gutter_clickable(_l86, true)
		_v99.set_gutter_overwritable(_l86, false)
		_v99.set_gutter_type(_l86, TextEdit.GUTTER_TYPE_ICON)
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
	var _j39 = RegEx.new()
	_j39.compile("^\\s*func\\s+([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\(")
	for _k72 in range(_p91.size()):
		var line = _p91[_k72]
		var _e21 = _j39.search(line)
		if _e21:
			if not _v74(line):
				continue
			var function_name = _e21.get_string(1)
			var _x99 = _l44(_p91, _k72)
			var _u37 = _x99 - _k72 + 1
			if _u37 > _v51:
				continue
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
	var _h50 = _v54()
	_v99.set_line_gutter_icon(_k72, _l86, _h50)
	_v99.set_line_gutter_clickable(_k72, _l86, true)
func _v54() -> ImageTexture:
	var _f21 = Image.create(28, 28, false, Image.FORMAT_RGBA8)
	_f21.fill(Color(0, 0, 0, 0))  
	var color = Color(1.0, 1.0, 1.0, 1.0)  
	for x in range(7, 21):
		_f21.set_pixel(x, 5, color)
		_f21.set_pixel(x, 6, color)
		_f21.set_pixel(x, 7, color)
		_f21.set_pixel(x, 8, color)
	for y in range(5, 12):
		_f21.set_pixel(6, y, color)
		_f21.set_pixel(7, y, color)
		_f21.set_pixel(8, y, color)
	for y in range(5, 15):
		_f21.set_pixel(19, y, color)
		_f21.set_pixel(20, y, color)
		_f21.set_pixel(21, y, color)
	for x in range(12, 21):
		_f21.set_pixel(x, 12, color)
		_f21.set_pixel(x, 13, color)
		_f21.set_pixel(x, 14, color)
	for y in range(15, 19):
		_f21.set_pixel(12, y, color)
		_f21.set_pixel(13, y, color)
		_f21.set_pixel(14, y, color)
		_f21.set_pixel(15, y, color)
	for x in range(12, 16):
		for y in range(21, 25):
			_f21.set_pixel(x, y, color)
	var texture = ImageTexture.new()
	texture.set_image(_f21)
	return texture
func _r13(line: int, _w96: int):
	if not _k83 or _w96 != _l86:
		return
	var _e92 = _m95(line)
	if _e92.is_empty():
		return
	if not _l1 or not _l1._r50:
		return
	var _k94 = _m11(_e92)
	if _k94.is_empty():
		return
	_a26.emit(_e92.name, _k94)
func _m11(_d36: Dictionary) -> String:
	if not _v99:
		return ""
	var text = _v99.text
	var _p91 = text.split("\n")
	var start_line = _d36.line
	var function_name = _d36.name
	if start_line < 0 or start_line >= _p91.size():
		return ""
	var end_line: int
	if _d36.has("end_line"):
		end_line = _d36.end_line
	else:
		end_line = _l44(_p91, start_line)
	if end_line < start_line:
		return ""
	var _u37 = end_line - start_line + 1
	if _u37 > _v51:
		return ""
	var _o22 = []
	for i in range(start_line, min(end_line + 1, _p91.size())):
		_o22.append(_p91[i])
	if _o22.is_empty():
		return ""
	return "\n".join(_o22)
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
		_v99.set_line_gutter_icon(line, _l86, null)
		_v99.set_line_gutter_clickable(line, _l86, false)
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
		_u76.queue_free()
		_u76 = null
	if _e3 and _e3.editor_script_changed.is_connected(_u5):
		_e3.editor_script_changed.disconnect(_u5)
	_l1 = null
	_r15 = null
	_e3 = null
	_v99 = null
	_k33.clear()
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
