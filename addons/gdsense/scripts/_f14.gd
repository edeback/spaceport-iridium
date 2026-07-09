@tool
class_name _m21
extends Control

signal _x88(function_name: String, file_path: String)

var _i34: EditorPlugin
var _b58: EditorInterface
var _i60: ScriptEditor
var _y26: CodeEdit
var _l59: bool = true
var _r59: Array = []
var _z91: bool = false
var _t7: int = -1  
var _a7: Timer
var _s5: RegEx  
var _p47: _b26

func _init(_h95: EditorPlugin, _q89: _b26):
	_i34 = _h95
	_p47 = _q89
	_b58 = _h95.get_editor_interface()
	_i60 = _b58.get_script_editor()
	
	_a7 = Timer.new()
	_a7.wait_time = 0.5  
	_a7.one_shot = true
	_a7.timeout.connect(_y62)
	add_child(_a7)
	
	_s5 = RegEx.new()
	_s5.compile("^\\s*func\\s+([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\(")
	
	if _i60 and not _i60.editor_script_changed.is_connected(_j68):
		_i60.editor_script_changed.connect(_j68)
	
	if _i60:
		_j68(_i60.get_current_script())

func set_enabled(enabled: bool):
	_l59 = enabled
	if _l59:
		_i39()
	else:
		_o55()

func is_enabled() -> bool:
	return _l59

func _j68(script: Script):
	if not script or not script.source_code:
		_v45()
		return
	
	var _f85 = script.resource_path
	if not _f85.is_empty() and not _f85.get_extension() == "gd":
		_v45()
		return
	
	if _f85.is_empty() or _f85.get_extension().is_empty():
		if not _c47(script.source_code):
			_v45()
			return
	
	_i39()

func _i39():
	_v45()
	
	var _c3 = _i60.get_current_editor()
	if not _c3:
		return
	
	_y26 = _a67(_c3)
	if not _y26:
		return
	
	if _l59:
		_t22()
	else:
		pass
func _a67(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node
	
	for _c100 in node.get_children():
		var _x97 = _a67(_c100)
		if _x97:
			return _x97
	
	return null

func _v45():
	_o55()
	
	if _y26:
		if _y26.text_changed.is_connected(_u29):
			_y26.text_changed.disconnect(_u29)
		if _y26.gutter_clicked.is_connected(_f91):
			_y26.gutter_clicked.disconnect(_f91)
	
	_y26 = null
	_r59.clear()
	_z91 = false
	_t7 = -1

func _t22():
	if not _y26:
		return
	
	var _e96 = _y26.get_gutter_count()
	var _f72 = -1
	
	for i in range(_e96):
		if _y26.get_gutter_name(i) == "undo":
			_f72 = i
			break
	
	if _f72 >= 0:
		_t7 = _f72
		_z91 = true
	elif not _z91:
		_y26.add_gutter()
		_t7 = _e96  
		
		_y26.set_gutter_name(_t7, "undo")
		_y26.set_gutter_width(_t7, 28)  
		_y26.set_gutter_draw(_t7, true)
		_y26.set_gutter_clickable(_t7, true)
		_y26.set_gutter_overwritable(_t7, false)
		_y26.set_gutter_type(_t7, TextEdit.GUTTER_TYPE_ICON)
		
		_z91 = true
	
	if _y26.has_signal("text_changed"):
		if not _y26.text_changed.is_connected(_u29):
			_y26.text_changed.connect(_u29)
	
	if _y26.has_signal("gutter_clicked"):
		if not _y26.gutter_clicked.is_connected(_f91):
			_y26.gutter_clicked.connect(_f91)
	
	_i59()

func _i59():
	if not _y26 or not _z91:
		return
	
	_o55()
	_r59.clear()
	
	var text = _y26.text
	var _d41 = text.split("\n")
	var _g40 = _i60.get_current_script()
	var file_path = _g40.resource_path if _g40 else ""
	
	for _g52 in range(_d41.size()):
		var line = _d41[_g52]
		var _x97 = _s5.search(line)
		
		if _x97:
			if not _d85(line):
				continue
			
			var function_name = _x97.get_string(1)
			
			if _p47._a6(function_name, file_path):
				var _h90 = _j42(_d41, _g52)
				var _u89 = _h90 - _g52 + 1
				
				var _w3 = {
					"name": function_name,
					"line": _g52,
					"declaration_line": line,
					"end_line": _h90
				}
				_r59.append(_w3)
				
				_k24(_g52, function_name)
	
func _k24(_g52: int, function_name: String):
	if not _y26 or not _z91:
		return
	
	var _t98 = _l94()
	
	_y26.set_line_gutter_icon(_g52, _t7, _t98)
	_y26.set_line_gutter_clickable(_g52, _t7, true)
	
func _l94() -> ImageTexture:
	var _a62 = Image.create(28, 28, false, Image.FORMAT_RGBA8)
	_a62.fill(Color(0, 0, 0, 0))  

	var color = Color(1.0, 0.7, 0.3, 1.0)  

	for angle in range(90, 270, 10):  
		var _p87 = deg_to_rad(angle)
		var x = int(14 + 9 * cos(_p87))
		var y = int(14 + 9 * sin(_p87))
		if x >= 0 and x < 28 and y >= 0 and y < 28:
			_a62.set_pixel(x, y, color)

			if x + 1 < 28:
				_a62.set_pixel(x + 1, y, color)
			if y + 1 < 28:
				_a62.set_pixel(x, y + 1, color)
			if x + 2 < 28:
				_a62.set_pixel(x + 2, y, color)
			if y + 2 < 28:
				_a62.set_pixel(x, y + 2, color)

	for x in range(2, 9):
		_a62.set_pixel(x, 5, color)
		_a62.set_pixel(x, 6, color)
		_a62.set_pixel(x, 7, color)

	for y in range(2, 9):
		_a62.set_pixel(5, y, color)
		_a62.set_pixel(6, y, color)
		_a62.set_pixel(7, y, color)

	_a62.set_pixel(3, 3, color)
	_a62.set_pixel(4, 4, color)
	_a62.set_pixel(8, 8, color)
	_a62.set_pixel(9, 9, color)

	var texture = ImageTexture.new()
	texture.set_image(_a62)
	return texture

func _f91(line: int, _v26: int):
	if not _l59 or _v26 != _t7:
		return
	
	var _w3 = _a31(line)
	if _w3.is_empty():
		return
	
	var _f85 = ""
	var _g40 = _i60.get_current_script()
	if _g40:
		_f85 = _g40.resource_path
	
	if not _f85.is_empty() and not FileAccess.file_exists(_f85):
		push_error("Cannot undo refactor: File has been moved or deleted")
		return
	
	if not _o22(_w3.name, _f85):
		pass

	_x88.emit(_w3.name, _f85)

func _j42(_d41: PackedStringArray, start_line: int) -> int:
	if start_line >= _d41.size():
		return start_line
	
	var _y38 = _r16(_d41[start_line])
	
	for i in range(start_line + 1, _d41.size()):
		var line = _d41[i]
		var _c59 = line.strip_edges()
		
		if _c59.is_empty() or _c59.begins_with("#"):
			continue
		
		var _u58 = _r16(line)
		
		if _u58 <= _y38:
			if _c59.begins_with("func ") or _c59.begins_with("class ") or _c59.begins_with("extends") or _c59.begins_with("@"):
				return i - 1
	
	return _d41.size() - 1

func _r16(line: String) -> int:
	var indent = 0
	for _d38 in line:
		if _d38 == '\t':
			indent += 4  
		elif _d38 == ' ':
			indent += 1
		else:
			break
	return indent

func _o55():
	if not _y26 or not _z91:
		return
	
	var _q62 = _y26.get_line_count()
	for line in range(_q62):
		_y26.set_line_gutter_icon(line, _t7, null)
		_y26.set_line_gutter_clickable(line, _t7, false)

func _u29():
	if not _y26 or not is_instance_valid(_a7):
		return
	
	if not is_inside_tree():
		return
	
	_a7.stop()
	_a7.start()

func _a31(line: int) -> Dictionary:
	for _w3 in _r59:
		if _w3.line == line:
			return _w3
	return {}

func _y62():
	if _l59 and _y26 and _z91:
		_i59()

func _f95():
	if _l59 and _y26 and _z91:
		_i59()

func _q17():
	_v45()
	
	if is_instance_valid(_a7):
		_a7.stop()
		if _a7.timeout.is_connected(_y62):
			_a7.timeout.disconnect(_y62)
		_a7.queue_free()
		_a7 = null
	
	if _i60 and _i60.editor_script_changed.is_connected(_j68):
		_i60.editor_script_changed.disconnect(_j68)
	
	_i34 = null
	_b58 = null
	_i60 = null
	_y26 = null
	_r59.clear()
	_s5 = null
	_p47 = null

func _b97(line: int) -> Dictionary:
	for _w3 in _r59:
		if _w3.line == line:
			return _w3
	return {}

func _z46() -> Array:
	return _r59.duplicate()

func _c47(content: String) -> bool:
	if content.is_empty():
		return false
	
	var _g22 = [
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
	
	for _t30 in _g22:
		if _t30 in content:
			return true
	
	return false

func _d85(line: String) -> bool:
	var _c59 = line.strip_edges()
	
	return "func " in _c59 and "(" in _c59

func _o22(function_name: String, file_path: String) -> bool:
	if not _p47 or file_path.is_empty():
		return true  
	
	var _h5 = _p47._k43(function_name, file_path)
	if not _h5:
		return true  
	
	var _q54 = _p22(function_name)
	if _q54.is_empty():
		return true  
	
	var _l29 = _v100(_q54)
	var _y23 = _v100(_h5.refactored_code)
	
	return _l29 == _y23

func _v100(code: String) -> String:
	var _d41 = code.split("\n")
	var _g45 = []

	for line in _d41:
		var _q21 = line.rstrip(" \t")
		_g45.append(_q21)

	while _g45.size() > 0 and _g45[-1].strip_edges().is_empty():
		_g45.pop_back()

	return "\n".join(_g45)

func _p22(function_name: String) -> String:
	if not _y26:
		return ""
	
	var text = _y26.text
	var _d41 = text.split("\n")
	
	var _w3 = {}
	for _u85 in _r59:
		if _u85.name == function_name:
			_w3 = _u85
			break
	
	if _w3.is_empty():
		return ""
	
	var start_line = _w3.line
	var end_line = _w3.end_line
	
	if start_line < 0 or end_line >= _d41.size():
		return ""
	
	var _d73 = []
	for i in range(start_line, end_line + 1):
		_d73.append(_d41[i])
	
	return "\n".join(_d73)

