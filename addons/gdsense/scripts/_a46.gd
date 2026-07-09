@tool
class_name _i5
extends Control
signal _b42(function_name: String, file_path: String)
var _c49: EditorPlugin
var _f21: EditorInterface
var _n12: ScriptEditor
var _s97: CodeEdit
var _m90: bool = true
var _r76: Array = []
var _n32: bool = false
var _q79: int = -1  
var _a11: Timer
var _m20: RegEx  
var _q66: _z98
func _init(_q48: EditorPlugin, _k10: _z98):
	_c49 = _q48
	_q66 = _k10
	_f21 = _q48.get_editor_interface()
	_n12 = _f21.get_script_editor()
	_a11 = Timer.new()
	_a11.wait_time = 0.5  
	_a11.one_shot = true
	_a11.timeout.connect(_o51)
	add_child(_a11)
	_m20 = RegEx.new()
	_m20.compile("^\\s*func\\s+([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\(")
	if _n12 and not _n12.editor_script_changed.is_connected(_y87):
		_n12.editor_script_changed.connect(_y87)
	if _n12:
		_y87(_n12.get_current_script())
func set_enabled(enabled: bool):
	_m90 = enabled
	if _m90:
		_f84()
	else:
		_f98()
func is_enabled() -> bool:
	return _m90
func _y87(script: Script):
	if not script or not script.source_code:
		_a10()
		return
	var _w48 = script.resource_path
	if not _w48.is_empty() and not _w48.get_extension() == "gd":
		_a10()
		return
	if _w48.is_empty() or _w48.get_extension().is_empty():
		if not _r77(script.source_code):
			_a10()
			return
	_f84()
func _f84():
	_a10()
	var _d47 = _n12.get_current_editor()
	if not _d47:
		return
	_s97 = _m58(_d47)
	if not _s97:
		return
	if _m90:
		_l77()
	else:
		pass
func _m58(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node
	for _o14 in node.get_children():
		var _s61 = _m58(_o14)
		if _s61:
			return _s61
	return null
func _a10():
	_f98()
	if _s97:
		if _s97.text_changed.is_connected(_g28):
			_s97.text_changed.disconnect(_g28)
		if _s97.gutter_clicked.is_connected(_o12):
			_s97.gutter_clicked.disconnect(_o12)
	_s97 = null
	_r76.clear()
	_n32 = false
	_q79 = -1
func _l77():
	if not _s97:
		return
	var _e54 = _s97.get_gutter_count()
	var _z96 = -1
	for i in range(_e54):
		if _s97.get_gutter_name(i) == "undo":
			_z96 = i
			break
	if _z96 >= 0:
		_q79 = _z96
		_n32 = true
	elif not _n32:
		_s97.add_gutter()
		_q79 = _e54  
		_s97.set_gutter_name(_q79, "undo")
		_s97.set_gutter_width(_q79, 28)  
		_s97.set_gutter_draw(_q79, true)
		_s97.set_gutter_clickable(_q79, true)
		_s97.set_gutter_overwritable(_q79, false)
		_s97.set_gutter_type(_q79, TextEdit.GUTTER_TYPE_ICON)
		_n32 = true
	if _s97.has_signal("text_changed"):
		if not _s97.text_changed.is_connected(_g28):
			_s97.text_changed.connect(_g28)
	if _s97.has_signal("gutter_clicked"):
		if not _s97.gutter_clicked.is_connected(_o12):
			_s97.gutter_clicked.connect(_o12)
	_i45()
func _i45():
	if not _s97 or not _n32:
		return
	_f98()
	_r76.clear()
	var text = _s97.text
	var _t70 = text.split("\n")
	var _k74 = _n12.get_current_script()
	var file_path = _k74.resource_path if _k74 else ""
	for _p93 in range(_t70.size()):
		var line = _t70[_p93]
		var _s61 = _m20.search(line)
		if _s61:
			if not _q32(line):
				continue
			var function_name = _s61.get_string(1)
			if _q66._r30(function_name, file_path):
				var _l34 = _s74(_t70, _p93)
				var _c91 = _l34 - _p93 + 1
				var _b28 = {
					"name": function_name,
					"line": _p93,
					"declaration_line": line,
					"end_line": _l34
				}
				_r76.append(_b28)
				_q60(_p93, function_name)
func _q60(_p93: int, function_name: String):
	if not _s97 or not _n32:
		return
	var _b82 = _z99()
	_s97.set_line_gutter_icon(_p93, _q79, _b82)
	_s97.set_line_gutter_clickable(_p93, _q79, true)
func _z99() -> ImageTexture:
	var _g99 = Image.create(28, 28, false, Image.FORMAT_RGBA8)
	_g99.fill(Color(0, 0, 0, 0))  
	var color = Color(1.0, 0.7, 0.3, 1.0)  
	for angle in range(90, 270, 10):  
		var _v85 = deg_to_rad(angle)
		var x = int(14 + 9 * cos(_v85))
		var y = int(14 + 9 * sin(_v85))
		if x >= 0 and x < 28 and y >= 0 and y < 28:
			_g99.set_pixel(x, y, color)
			if x + 1 < 28:
				_g99.set_pixel(x + 1, y, color)
			if y + 1 < 28:
				_g99.set_pixel(x, y + 1, color)
			if x + 2 < 28:
				_g99.set_pixel(x + 2, y, color)
			if y + 2 < 28:
				_g99.set_pixel(x, y + 2, color)
	for x in range(2, 9):
		_g99.set_pixel(x, 5, color)
		_g99.set_pixel(x, 6, color)
		_g99.set_pixel(x, 7, color)
	for y in range(2, 9):
		_g99.set_pixel(5, y, color)
		_g99.set_pixel(6, y, color)
		_g99.set_pixel(7, y, color)
	_g99.set_pixel(3, 3, color)
	_g99.set_pixel(4, 4, color)
	_g99.set_pixel(8, 8, color)
	_g99.set_pixel(9, 9, color)
	var texture = ImageTexture.new()
	texture.set_image(_g99)
	return texture
func _o12(line: int, _f78: int):
	if not _m90 or _f78 != _q79:
		return
	var _b28 = _g55(line)
	if _b28.is_empty():
		return
	var _w48 = ""
	var _k74 = _n12.get_current_script()
	if _k74:
		_w48 = _k74.resource_path
	if not _w48.is_empty() and not FileAccess.file_exists(_w48):
		push_error("Cannot undo refactor: File has been moved or deleted")
		return
	if not _o39(_b28.name, _w48):
		pass
	_b42.emit(_b28.name, _w48)
func _s74(_t70: PackedStringArray, start_line: int) -> int:
	if start_line >= _t70.size():
		return start_line
	var _b90 = _h60(_t70[start_line])
	for i in range(start_line + 1, _t70.size()):
		var line = _t70[i]
		var _z10 = line.strip_edges()
		if _z10.is_empty() or _z10.begins_with("#"):
			continue
		var _m78 = _h60(line)
		if _m78 <= _b90:
			if _z10.begins_with("func ") or _z10.begins_with("class ") or _z10.begins_with("extends") or _z10.begins_with("@"):
				return i - 1
	return _t70.size() - 1
func _h60(line: String) -> int:
	var indent = 0
	for _q64 in line:
		if _q64 == '\t':
			indent += 4  
		elif _q64 == ' ':
			indent += 1
		else:
			break
	return indent
func _f98():
	if not _s97 or not _n32:
		return
	var _j12 = _s97.get_line_count()
	for line in range(_j12):
		_s97.set_line_gutter_icon(line, _q79, null)
		_s97.set_line_gutter_clickable(line, _q79, false)
func _g28():
	if not _s97 or not is_instance_valid(_a11):
		return
	if not is_inside_tree():
		return
	_a11.stop()
	_a11.start()
func _g55(line: int) -> Dictionary:
	for _b28 in _r76:
		if _b28.line == line:
			return _b28
	return {}
func _o51():
	if _m90 and _s97 and _n32:
		_i45()
func _u67():
	if _m90 and _s97 and _n32:
		_i45()
func _o36():
	_a10()
	if is_instance_valid(_a11):
		_a11.stop()
		if _a11.timeout.is_connected(_o51):
			_a11.timeout.disconnect(_o51)
		_a11.queue_free()
		_a11 = null
	if _n12 and _n12.editor_script_changed.is_connected(_y87):
		_n12.editor_script_changed.disconnect(_y87)
	_c49 = null
	_f21 = null
	_n12 = null
	_s97 = null
	_r76.clear()
	_m20 = null
	_q66 = null
func _c88(line: int) -> Dictionary:
	for _b28 in _r76:
		if _b28.line == line:
			return _b28
	return {}
func _u37() -> Array:
	return _r76.duplicate()
func _r77(content: String) -> bool:
	if content.is_empty():
		return false
	var _f42 = [
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
	for _s76 in _f42:
		if _s76 in content:
			return true
	return false
func _q32(line: String) -> bool:
	var _z10 = line.strip_edges()
	return "func " in _z10 and "(" in _z10
func _o39(function_name: String, file_path: String) -> bool:
	if not _q66 or file_path.is_empty():
		return true  
	var _y92 = _q66._u28(function_name, file_path)
	if not _y92:
		return true  
	var _h53 = _x87(function_name)
	if _h53.is_empty():
		return true  
	var _j40 = _z16(_h53)
	var _j83 = _z16(_y92.refactored_code)
	return _j40 == _j83
func _z16(code: String) -> String:
	var _t70 = code.split("\n")
	var _k70 = []
	for line in _t70:
		var _n62 = line.rstrip(" \t")
		_k70.append(_n62)
	while _k70.size() > 0 and _k70[-1].strip_edges().is_empty():
		_k70.pop_back()
	return "\n".join(_k70)
func _x87(function_name: String) -> String:
	if not _s97:
		return ""
	var text = _s97.text
	var _t70 = text.split("\n")
	var _b28 = {}
	for _v81 in _r76:
		if _v81.name == function_name:
			_b28 = _v81
			break
	if _b28.is_empty():
		return ""
	var start_line = _b28.line
	var end_line = _b28.end_line
	if start_line < 0 or end_line >= _t70.size():
		return ""
	var _s99 = []
	for i in range(start_line, end_line + 1):
		_s99.append(_t70[i])
	return "\n".join(_s99)
