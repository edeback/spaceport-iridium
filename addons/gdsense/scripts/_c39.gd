@tool
class_name _b83
extends Control
signal _k61(function_name: String, _j46: String, file_path: String)
var _c49: EditorPlugin
var _f21: EditorInterface
var _n12: ScriptEditor
var _s97: CodeEdit
var _m90: bool = true
var _r76: Array = []
var _n32: bool = false
var _u24: int = -1  
var _a11: Timer
var _m20: RegEx  
var _p62: int = 300  
var _r86: WeakRef  
func _init(_q48: EditorPlugin):
	_c49 = _q48
	_f21 = _q48.get_editor_interface()
	_n12 = _f21.get_script_editor()
	_a11 = Timer.new()
	_a11.wait_time = 0.5  
	_a11.one_shot = true
	_a11.timeout.connect(_o51)
	add_child(_a11)
	_m20 = RegEx.new()
	_m20.compile("^\\s*func\\s+([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\(")
	_t39()
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
	_u24 = -1
func _l77():
	if not _s97:
		return
	var _e54 = _s97.get_gutter_count()
	var _z96 = -1
	for i in range(_e54):
		if _s97.get_gutter_name(i) == "refactor":
			_z96 = i
			break
	if _z96 >= 0:
		_u24 = _z96
		_n32 = true
	elif not _n32:
		_s97.add_gutter()
		_u24 = _e54  
		_s97.set_gutter_name(_u24, "refactor")
		_s97.set_gutter_width(_u24, 28)  
		_s97.set_gutter_draw(_u24, true)
		_s97.set_gutter_clickable(_u24, true)
		_s97.set_gutter_overwritable(_u24, false)
		_s97.set_gutter_type(_u24, TextEdit.GUTTER_TYPE_ICON)
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
	for _p93 in range(_t70.size()):
		var line = _t70[_p93]
		var _s61 = _m20.search(line)
		if _s61:
			if not _q32(line):
				continue
			var function_name = _s61.get_string(1)
			var _l34 = _s74(_t70, _p93)
			var _c91 = _l34 - _p93 + 1
			if _c91 > _p62:
				continue
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
	var _b82 = _a85()
	_s97.set_line_gutter_icon(_p93, _u24, _b82)
	_s97.set_line_gutter_clickable(_p93, _u24, true)
func _a85() -> ImageTexture:
	var _g99 = Image.create(28, 28, false, Image.FORMAT_RGBA8)
	_g99.fill(Color(0, 0, 0, 0))  
	var color = Color(0.8, 1.0, 0.8, 1.0)  
	for angle in range(0, 360, 10):
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
	for x in range(21, 26):
		_g99.set_pixel(x, 7, color)
		_g99.set_pixel(x, 8, color)
		_g99.set_pixel(x, 9, color)
	_g99.set_pixel(22, 5, color)
	_g99.set_pixel(23, 4, color)
	_g99.set_pixel(24, 3, color)
	_g99.set_pixel(22, 6, color)
	_g99.set_pixel(23, 5, color)
	_g99.set_pixel(22, 10, color)
	_g99.set_pixel(23, 11, color)
	_g99.set_pixel(24, 12, color)
	_g99.set_pixel(22, 11, color)
	_g99.set_pixel(23, 12, color)
	var texture = ImageTexture.new()
	texture.set_image(_g99)
	return texture
func _o12(line: int, _f78: int):
	if not _m90 or _f78 != _u24:
		return
	var _b28 = _g55(line)
	if _b28.is_empty():
		return
	var _j46 = _v72(_b28)
	if _j46.is_empty():
		return
	var _w48 = ""
	var _k74 = _n12.get_current_script()
	if _k74:
		_w48 = _k74.resource_path
	_k61.emit(_b28.name, _j46, _w48)
func _v72(_i16: Dictionary) -> String:
	if not _s97:
		push_error("ScriptRefactorOverlay: No current script editor available for function extraction")
		return ""
	var text = _s97.text
	var _t70 = text.split("\n")
	var start_line = _i16.line
	var function_name = _i16.name
	if start_line < 0 or start_line >= _t70.size():
		push_error("ScriptRefactorOverlay: Invalid start line %d for function '%s'. Check script integrity." % [start_line, function_name])
		return ""
	var end_line: int
	if _i16.has("end_line"):
		end_line = _i16.end_line
	else:
		end_line = _s74(_t70, start_line)
	if end_line < start_line:
		push_error("ScriptRefactorOverlay: Invalid end line %d for function '%s'. Function parsing failed." % [end_line, function_name])
		return ""
	var _c91 = end_line - start_line + 1
	if _c91 > _p62:
		push_error("ScriptRefactorOverlay: Function '%s' is too large (%d lines, max %d). Consider breaking it into smaller functions." % [function_name, _c91, _p62])
		return ""
	var _s99 = []
	for i in range(start_line, min(end_line + 1, _t70.size())):
		_s99.append(_t70[i])
	if _s99.is_empty():
		push_error("ScriptRefactorOverlay: No function lines extracted for '%s'. The function may be malformed." % function_name)
		return ""
	return "\n".join(_s99)
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
		_s97.set_line_gutter_icon(line, _u24, null)
		_s97.set_line_gutter_clickable(line, _u24, false)
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
func _t39():
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		_p62 = config.get_value("refactor", "max_function_lines", 300)
	else:
		_p62 = 300
func _b89(limit: int):
	_p62 = max(50, limit)  
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")
	config.set_value("refactor", "max_function_lines", _p62)
	config.save("user://gdsense_api_key.cfg")
func get_function_size_limit() -> int:
	return _p62
func _f58(_k69):
	_r86 = weakref(_k69)
func _j88(_c5: Dictionary):
	if _r86 and _r86.get_ref():
		var _k69 = _r86.get_ref()
		if _k69.has_method("update_gutters_after_refactor"):
			_k69.update_gutters_after_refactor(_c5)
func get_current_script_editor() -> CodeEdit:
	return _s97
func _h40():
	if _m90 and _s97 and _n32:
		_i45()
