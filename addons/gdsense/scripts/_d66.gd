@tool
class_name _y29
extends Control

signal _j63(function_name: String, _g33: String)

const _t75 = 300

var _u65: EditorPlugin
var _q86: EditorInterface
var _b50: ScriptEditor
var _t5: CodeEdit
var _p60: bool = true
var _e29: Array = []
var _g7: bool = false
var _e47: int = -1  
var _c67: Timer  

func _init(_u63: EditorPlugin):
	_u65 = _u63
	_q86 = _u63.get_editor_interface()
	_b50 = _q86.get_script_editor()
	
	_c67 = Timer.new()
	_c67.wait_time = 0.5  
	_c67.one_shot = true
	_c67.timeout.connect(_g67)
	add_child(_c67)
	
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
	_e47 = -1

func _w77():
	if not _t5:
		return
	
	var _e52 = _t5.get_gutter_count()
	var _q51 = -1
	
	for i in range(_e52):
		if _t5.get_gutter_name(i) == "explain":
			_q51 = i
			break
	
	if _q51 >= 0:
		_e47 = _q51

		_g7 = true
	elif not _g7:
		_t5.add_gutter()
		_e47 = _e52  
		
		_t5.set_gutter_name(_e47, "explain")
		_t5.set_gutter_width(_e47, 28)  
		_t5.set_gutter_draw(_e47, true)
		_t5.set_gutter_clickable(_e47, true)
		_t5.set_gutter_overwritable(_e47, false)
		_t5.set_gutter_type(_e47, TextEdit.GUTTER_TYPE_ICON)
		
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
	
	var _n84 = RegEx.new()

	_n84.compile("^\\s*func\\s+([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\(")
	
	for _u8 in range(_m12.size()):
		var line = _m12[_u8]
		var _k3 = _n84.search(line)
		
		if _k3:
			if not _h100(line):
				continue
			
			var function_name = _k3.get_string(1)
			
			var _z44 = _i9(_m12, _u8)
			var _g12 = _z44 - _u8 + 1
			if _g12 > _t75:
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
	
	var _n18 = _k23()
	
	_t5.set_line_gutter_icon(_u8, _e47, _n18)
	_t5.set_line_gutter_clickable(_u8, _e47, true)
	
func _k23() -> ImageTexture:
	var _g32 = Image.create(28, 28, false, Image.FORMAT_RGBA8)
	_g32.fill(Color(0, 0, 0, 0))  

	var color = Color(1.0, 1.0, 1.0, 1.0)  

	for x in range(7, 21):
		_g32.set_pixel(x, 5, color)
		_g32.set_pixel(x, 6, color)
		_g32.set_pixel(x, 7, color)
		_g32.set_pixel(x, 8, color)

	for y in range(5, 12):
		_g32.set_pixel(6, y, color)
		_g32.set_pixel(7, y, color)
		_g32.set_pixel(8, y, color)

	for y in range(5, 15):
		_g32.set_pixel(19, y, color)
		_g32.set_pixel(20, y, color)
		_g32.set_pixel(21, y, color)

	for x in range(12, 21):
		_g32.set_pixel(x, 12, color)
		_g32.set_pixel(x, 13, color)
		_g32.set_pixel(x, 14, color)

	for y in range(15, 19):
		_g32.set_pixel(12, y, color)
		_g32.set_pixel(13, y, color)
		_g32.set_pixel(14, y, color)
		_g32.set_pixel(15, y, color)

	for x in range(12, 16):
		for y in range(21, 25):
			_g32.set_pixel(x, y, color)

	var texture = ImageTexture.new()
	texture.set_image(_g32)
	return texture

func _a23(line: int, _g51: int):
	if not _p60 or _g51 != _e47:
		return
	
	var _s29 = _g80(line)
	if _s29.is_empty():
		return
	
	if not _u65 or not _u65._f86:
		return
	
	var _g33 = _h99(_s29)
	if _g33.is_empty():
		return
	
	_j63.emit(_s29.name, _g33)

func _h99(_o77: Dictionary) -> String:
	if not _t5:
		return ""
	
	var text = _t5.text
	var _m12 = text.split("\n")
	var start_line = _o77.line
	var function_name = _o77.name
	
	if start_line < 0 or start_line >= _m12.size():
		return ""
	
	var end_line: int
	if _o77.has("end_line"):
		end_line = _o77.end_line
	else:
		end_line = _i9(_m12, start_line)
	
	if end_line < start_line:
		return ""
	
	var _g12 = end_line - start_line + 1
	if _g12 > _t75:
		return ""
	
	var _r23 = []
	for i in range(start_line, min(end_line + 1, _m12.size())):
		_r23.append(_m12[i])
	
	if _r23.is_empty():
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
		_t5.set_line_gutter_icon(line, _e47, null)
		_t5.set_line_gutter_clickable(line, _e47, false)

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

