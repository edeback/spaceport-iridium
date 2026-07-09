@tool
class_name _x98
extends Control
signal _k47(function_name: String, _k94: String, file_path: String)
var _l1: EditorPlugin
var _r15: EditorInterface
var _e3: ScriptEditor
var _v99: CodeEdit
var _k83: bool = true
var _k33: Array = []
var _d65: bool = false
var _z61: int = -1  
var _u76: Timer
var _u8: RegEx  
var _d16: int = 300  
var _g42: WeakRef  
func _init(_b89: EditorPlugin):
	_l1 = _b89
	_r15 = _b89.get_editor_interface()
	_e3 = _r15.get_script_editor()
	_u76 = Timer.new()
	_u76.wait_time = 0.5  
	_u76.one_shot = true
	_u76.timeout.connect(_y96)
	add_child(_u76)
	_u8 = RegEx.new()
	_u8.compile("^\\s*func\\s+([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\(")
	_c32()
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
	_z61 = -1
func _z60():
	if not _v99:
		return
	var _o84 = _v99.get_gutter_count()
	var _w69 = -1
	for i in range(_o84):
		if _v99.get_gutter_name(i) == "refactor":
			_w69 = i
			break
	if _w69 >= 0:
		_z61 = _w69
		_d65 = true
	elif not _d65:
		_v99.add_gutter()
		_z61 = _o84  
		_v99.set_gutter_name(_z61, "refactor")
		_v99.set_gutter_width(_z61, 28)  
		_v99.set_gutter_draw(_z61, true)
		_v99.set_gutter_clickable(_z61, true)
		_v99.set_gutter_overwritable(_z61, false)
		_v99.set_gutter_type(_z61, TextEdit.GUTTER_TYPE_ICON)
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
	for _k72 in range(_p91.size()):
		var line = _p91[_k72]
		var _e21 = _u8.search(line)
		if _e21:
			if not _v74(line):
				continue
			var function_name = _e21.get_string(1)
			var _x99 = _l44(_p91, _k72)
			var _u37 = _x99 - _k72 + 1
			if _u37 > _d16:
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
	var _h50 = _r3()
	_v99.set_line_gutter_icon(_k72, _z61, _h50)
	_v99.set_line_gutter_clickable(_k72, _z61, true)
func _r3() -> ImageTexture:
	var _f21 = Image.create(28, 28, false, Image.FORMAT_RGBA8)
	_f21.fill(Color(0, 0, 0, 0))  
	var color = Color(0.8, 1.0, 0.8, 1.0)  
	for angle in range(0, 360, 10):
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
	for x in range(21, 26):
		_f21.set_pixel(x, 7, color)
		_f21.set_pixel(x, 8, color)
		_f21.set_pixel(x, 9, color)
	_f21.set_pixel(22, 5, color)
	_f21.set_pixel(23, 4, color)
	_f21.set_pixel(24, 3, color)
	_f21.set_pixel(22, 6, color)
	_f21.set_pixel(23, 5, color)
	_f21.set_pixel(22, 10, color)
	_f21.set_pixel(23, 11, color)
	_f21.set_pixel(24, 12, color)
	_f21.set_pixel(22, 11, color)
	_f21.set_pixel(23, 12, color)
	var texture = ImageTexture.new()
	texture.set_image(_f21)
	return texture
func _r13(line: int, _w96: int):
	if not _k83 or _w96 != _z61:
		return
	var _e92 = _m95(line)
	if _e92.is_empty():
		return
	var _k94 = _m11(_e92)
	if _k94.is_empty():
		return
	var _x58 = ""
	var _y36 = _e3.get_current_script()
	if _y36:
		_x58 = _y36.resource_path
	_k47.emit(_e92.name, _k94, _x58)
func _m11(_d36: Dictionary) -> String:
	if not _v99:
		push_error("ScriptRefactorOverlay: No current script editor available for function extraction")
		return ""
	var text = _v99.text
	var _p91 = text.split("\n")
	var start_line = _d36.line
	var function_name = _d36.name
	if start_line < 0 or start_line >= _p91.size():
		push_error("ScriptRefactorOverlay: Invalid start line %d for function '%s'. Check script integrity." % [start_line, function_name])
		return ""
	var end_line: int
	if _d36.has("end_line"):
		end_line = _d36.end_line
	else:
		end_line = _l44(_p91, start_line)
	if end_line < start_line:
		push_error("ScriptRefactorOverlay: Invalid end line %d for function '%s'. Function parsing failed." % [end_line, function_name])
		return ""
	var _u37 = end_line - start_line + 1
	if _u37 > _d16:
		push_error("ScriptRefactorOverlay: Function '%s' is too large (%d lines, max %d). Consider breaking it into smaller functions." % [function_name, _u37, _d16])
		return ""
	var _o22 = []
	for i in range(start_line, min(end_line + 1, _p91.size())):
		_o22.append(_p91[i])
	if _o22.is_empty():
		push_error("ScriptRefactorOverlay: No function lines extracted for '%s'. The function may be malformed." % function_name)
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
		_v99.set_line_gutter_icon(line, _z61, null)
		_v99.set_line_gutter_clickable(line, _z61, false)
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
	_u8 = null
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
func _c32():
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		_d16 = config.get_value("refactor", "max_function_lines", 300)
	else:
		_d16 = 300
func _y19(limit: int):
	_d16 = max(50, limit)  
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")
	config.set_value("refactor", "max_function_lines", _d16)
	config.save("user://gdsense_api_key.cfg")
func get_function_size_limit() -> int:
	return _d16
func _d96(_m22):
	_g42 = weakref(_m22)
func _n40(_b71: Dictionary):
	if _g42 and _g42.get_ref():
		var _m22 = _g42.get_ref()
		if _m22.has_method("update_gutters_after_refactor"):
			_m22.update_gutters_after_refactor(_b71)
func get_current_script_editor() -> CodeEdit:
	return _v99
func _m87():
	if _k83 and _v99 and _d65:
		_s17()
