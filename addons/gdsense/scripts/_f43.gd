@tool
class_name _d40
extends Control

signal _n51(function_name: String, _z29: String)

const _z11 = 300

var _v62: EditorPlugin
var _z76: EditorInterface
var _j30: ScriptEditor
var _f37: CodeEdit
var _o77: bool = true
var _r87: Array = []
var _s13: bool = false
var _l100: int = -1  
var _m22: Timer  

func _init(_u86: EditorPlugin):
	_v62 = _u86
	_z76 = _u86.get_editor_interface()
	_j30 = _z76.get_script_editor()
	
	_m22 = Timer.new()
	_m22.wait_time = 0.5  
	_m22.one_shot = true
	_m22.timeout.connect(_i71)
	add_child(_m22)
	
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
	_l100 = -1

func _f23():
	if not _f37:
		return
	
	var _x73 = _f37.get_gutter_count()
	var _m80 = -1
	
	for i in range(_x73):
		if _f37.get_gutter_name(i) == "explain":
			_m80 = i
			break
	
	if _m80 >= 0:
		_l100 = _m80

		_s13 = true
	elif not _s13:
		_f37.add_gutter()
		_l100 = _x73  
		
		_f37.set_gutter_name(_l100, "explain")
		_f37.set_gutter_width(_l100, 28)  
		_f37.set_gutter_draw(_l100, true)
		_f37.set_gutter_clickable(_l100, true)
		_f37.set_gutter_overwritable(_l100, false)
		_f37.set_gutter_type(_l100, TextEdit.GUTTER_TYPE_ICON)
		
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
	
	var _f3 = RegEx.new()

	_f3.compile("^\\s*func\\s+([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\(")
	
	for _g69 in range(_b26.size()):
		var line = _b26[_g69]
		var _v42 = _f3.search(line)
		
		if _v42:
			if not _k96(line):
				continue
			
			var function_name = _v42.get_string(1)
			
			var _b85 = _e55(_b26, _g69)
			var _e15 = _b85 - _g69 + 1
			if _e15 > _z11:
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
	
	var _i60 = _w48()
	
	_f37.set_line_gutter_icon(_g69, _l100, _i60)
	_f37.set_line_gutter_clickable(_g69, _l100, true)
	
func _w48() -> ImageTexture:
	var _p15 = Image.create(28, 28, false, Image.FORMAT_RGBA8)
	_p15.fill(Color(0, 0, 0, 0))  

	var color = Color(1.0, 1.0, 1.0, 1.0)  

	for x in range(7, 21):
		_p15.set_pixel(x, 5, color)
		_p15.set_pixel(x, 6, color)
		_p15.set_pixel(x, 7, color)
		_p15.set_pixel(x, 8, color)

	for y in range(5, 12):
		_p15.set_pixel(6, y, color)
		_p15.set_pixel(7, y, color)
		_p15.set_pixel(8, y, color)

	for y in range(5, 15):
		_p15.set_pixel(19, y, color)
		_p15.set_pixel(20, y, color)
		_p15.set_pixel(21, y, color)

	for x in range(12, 21):
		_p15.set_pixel(x, 12, color)
		_p15.set_pixel(x, 13, color)
		_p15.set_pixel(x, 14, color)

	for y in range(15, 19):
		_p15.set_pixel(12, y, color)
		_p15.set_pixel(13, y, color)
		_p15.set_pixel(14, y, color)
		_p15.set_pixel(15, y, color)

	for x in range(12, 16):
		for y in range(21, 25):
			_p15.set_pixel(x, y, color)

	var texture = ImageTexture.new()
	texture.set_image(_p15)
	return texture

func _m20(line: int, _p29: int):
	if not _o77 or _p29 != _l100:
		return
	
	var _c28 = _h68(line)
	if _c28.is_empty():
		return
	
	if not _v62 or not _v62._e64:
		return
	
	var _z29 = _u95(_c28)
	if _z29.is_empty():
		return
	
	_n51.emit(_c28.name, _z29)

func _u95(_f50: Dictionary) -> String:
	if not _f37:
		return ""
	
	var text = _f37.text
	var _b26 = text.split("\n")
	var start_line = _f50.line
	var function_name = _f50.name
	
	if start_line < 0 or start_line >= _b26.size():
		return ""
	
	var end_line: int
	if _f50.has("end_line"):
		end_line = _f50.end_line
	else:
		end_line = _e55(_b26, start_line)
	
	if end_line < start_line:
		return ""
	
	var _e15 = end_line - start_line + 1
	if _e15 > _z11:
		return ""
	
	var _o69 = []
	for i in range(start_line, min(end_line + 1, _b26.size())):
		_o69.append(_b26[i])
	
	if _o69.is_empty():
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
		_f37.set_line_gutter_icon(line, _l100, null)
		_f37.set_line_gutter_clickable(line, _l100, false)

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

