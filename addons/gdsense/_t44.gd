@tool
extends EditorPlugin
const _m50 = preload("res://addons/gdsense/scripts/_b77.gd")
const _l90 = preload("res://addons/gdsense/scripts/_r91.gd")
const _v88 = preload("res://addons/gdsense/scripts/_p57.gd")
const _a63 = preload("res://addons/gdsense/scripts/_c39.gd")
const _y61 = preload("res://addons/gdsense/scripts/_a46.gd")
const _d67 = preload("res://addons/gdsense/scripts/_s34.gd")
const _a84 = preload("res://addons/gdsense/scenes/_i63.tscn")
const _o94 = preload("res://addons/gdsense/scenes/_b33.tscn")
const _d22 = preload("res://addons/gdsense/scenes/_a98.tscn")
const _j9 = preload("res://addons/gdsense/scenes/_c65.tscn")
const _a96 = preload("res://addons/gdsense/scenes/_v95.tscn")
var _u92: Control
var _b77: _d54
var _w86: _r91
var _p57: _k89
var _v26: Array[_k89] = []
var _c39: _b83
var _i63: _c47
var _b33: _x5
var _b26: Array[_b83] = []
var _a46: _i5
var _s34: _z98
var _a98: _a28
var _d57: _e42
var _v95: _o85
var _r8: Array[_i5] = []
func _enter_tree() -> void:
	_w86 = _l90.new()
	add_child(_w86)
	var _x4: PackedScene = preload("res://addons/gdsense/scenes/_y69.tscn")
	_u92 = _x4.instantiate()
	if _u92.has_method("set_gdsense_manager"):
		_u92.set_gdsense_manager(_w86)
	if _u92.has_method("set_plugin"):
		_u92.set_plugin(self)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _u92)
	_b77 = _m50.new(self, _w86)
	_b24()
	_h75()
	_o56()
	var _i13 = get_editor_interface()
	if _i13:
		var _t27 = _i13.get_script_editor()
		if _t27 and not _t27.editor_script_changed.is_connected(_v68):
			_t27.editor_script_changed.connect(_v68)
	_w27()
	_u43()
	_t76()
	_d9()
	_g76.call_deferred()
func _exit_tree() -> void:
	if is_instance_valid(_u92):
		remove_control_from_docks(_u92)
		_u92.free() 
	if is_instance_valid(_b77):
		_b77._o36()
		_b77 = null
	_d26()
	_c46()
	_a93()
	var _i13 = get_editor_interface()
	if _i13:
		var _t27 = _i13.get_script_editor()
		if _t27 and _t27.editor_script_changed.is_connected(_v68):
			_t27.editor_script_changed.disconnect(_v68)
	if is_instance_valid(_w86):
		_w86.queue_free()
		_w86 = null
func _b24():
	_p57 = _v88.new(self)
	_p57._h42.connect(_o79)
	_v26.append(_p57)
func _h75():
	_c39 = _a63.new(self)
	_c39._k61.connect(_k33)
	_b26.append(_c39)
	_i63 = _a84.instantiate()
	_i63._t63.connect(_r12)
	if is_instance_valid(_w86):
		_i63.set_gdsense_manager(_w86)
	_b33 = _o94.instantiate()
	_b33._h55.connect(_m10)
	_b33._c37.connect(_p14)
	if is_instance_valid(_w86):
		_w86._u52.connect(_m97)
		_w86._p16.connect(_u94)
func _d26():
	for _l62 in _v26:
		if is_instance_valid(_l62):
			_l62._o36()
	_v26.clear()
	_p57 = null
func _c46():
	for _l62 in _b26:
		if is_instance_valid(_l62):
			_l62._o36()
	_b26.clear()
	_c39 = null
	if is_instance_valid(_i63):
		_i63.queue_free()
		_i63 = null
	if is_instance_valid(_b33):
		_b33.queue_free()
		_b33 = null
func _o56():
	_s34 = _d67.new()
	_a46 = _y61.new(self, _s34)
	_a46._b42.connect(_f33)
	_r8.append(_a46)
	_a98 = _d22.instantiate()
	_a98._o81(get_editor_interface())
	_a98._s93.connect(_l50)
	_d57 = _j9.instantiate()
	_d57._f28(_s34)
	_v95 = _a96.instantiate()
func _a93():
	for _l62 in _r8:
		if is_instance_valid(_l62):
			_l62._o36()
	_r8.clear()
	_a46 = null
	if is_instance_valid(_a98):
		_a98.queue_free()
		_a98 = null
	if is_instance_valid(_d57):
		_d57.queue_free()
		_d57 = null
	if is_instance_valid(_v95):
		_v95.queue_free()
		_v95 = null
	if _s34:
		_s34._k46()
		_s34 = null
func _w27():
	const _r55 = 1000
	const _a73 = 150
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		_b77._f71 = config.get_value("autocomplete", "enabled", true)
		_b77._a100 = _r55  
		_b77._n100 = _a73  
		_b77._c67 = config.get_value("autocomplete", "mode", "automatic")
		_b77._b27 = config.get_value("autocomplete", "min_chars", 3)
	else:
		_b77._f71 = true
		_b77._a100 = _r55
		_b77._n100 = _a73
		_b77._c67 = "automatic"
		_b77._b27 = 3
func save_autocomplete_config(enabled: bool, _b6: int, max_length: int, mode: String = "", _d17: int = 3):
	const _r55 = 1000
	const _a73 = 150
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")  
	config.set_value("autocomplete", "enabled", enabled)
	config.set_value("autocomplete", "delay_ms", _r55)  
	config.set_value("autocomplete", "max_length", _a73)  
	if mode != "":
		config.set_value("autocomplete", "mode", mode)
	config.set_value("autocomplete", "min_chars", _d17)
	config.save("user://gdsense_api_key.cfg")
	if is_instance_valid(_b77):
		_b77.set_enabled(enabled)
		_b77.set_delay(_r55)  
		_b77._n100 = _a73  
		if mode != "":
			_b77.set_mode(mode)
		_b77._b27 = _d17
func _u43():
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var enabled = config.get_value("explain_button", "enabled", true)
		if _p57:
			_p57.set_enabled(enabled)
	else:
		if _p57:
			_p57.set_enabled(true)
func _t76():
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var enabled = config.get_value("refactor_button", "enabled", true)
		if is_instance_valid(_c39):
			_c39.set_enabled(enabled)
	else:
		if is_instance_valid(_c39):
			_c39.set_enabled(true)
func _d9():
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var enabled = config.get_value("undo_button", "enabled", true)
		if is_instance_valid(_a46):
			_a46.set_enabled(enabled)
	else:
		if is_instance_valid(_a46):
			_a46.set_enabled(true)
func _g76():
	var _i13 = get_editor_interface()
	if not _i13:
		return
	var _t27 = _i13.get_script_editor()
	if not _t27:
		return
	var _k74 = _t27.get_current_script()
	if _k74:
		var config = ConfigFile.new()
		if config.load("user://gdsense_api_key.cfg") == OK:
			var _x14 = config.get_value("explain_button", "enabled", true)
			if _x14 and _p57:
				_p57._y87(_k74)
			var _d23 = config.get_value("refactor_button", "enabled", true)
			if _d23 and _c39:
				_c39._y87(_k74)
			var _w69 = config.get_value("undo_button", "enabled", true)
			if _w69 and _a46:
				_a46._y87(_k74)
func save_explain_button_config(enabled: bool):
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")  
	config.set_value("explain_button", "enabled", enabled)
	config.save("user://gdsense_api_key.cfg")
	if _p57:
		_p57.set_enabled(enabled)
		if enabled:
			_g76.call_deferred()
func save_refactor_config(enabled: bool):
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")  
	config.set_value("refactor_button", "enabled", enabled)
	config.save("user://gdsense_api_key.cfg")
	if is_instance_valid(_c39):
		_c39.set_enabled(enabled)
func save_undo_config(enabled: bool):
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")  
	config.set_value("undo_button", "enabled", enabled)
	config.save("user://gdsense_api_key.cfg")
	if is_instance_valid(_a46):
		_a46.set_enabled(enabled)
func _o79(function_name: String, _j46: String):
	if not is_instance_valid(_u92):
		return
	if _u92.has_method("send_explain_request"):
		_u92.send_explain_request(function_name, _j46)
	else:
		pass
func _k33(function_name: String, _j46: String, file_path: String):
	if is_instance_valid(_i63):
		_i63.set_meta("file_path", file_path)
		_i63.set_meta("function_source", _j46)
	var _i13 = get_editor_interface()
	var current_scene = _i13.get_editor_main_screen() if _i13 else null
	if current_scene and is_instance_valid(_i63):
		if not _i63.is_inside_tree():
			current_scene.add_child(_i63)
		_i63._c20(function_name, _j46)
func _r12(_v36: String, function_name: String, _j46: String, model: String):
	var file_path = ""
	if is_instance_valid(_i63) and _i63.has_meta("file_path"):
		file_path = _i63.get_meta("file_path")
	if is_instance_valid(_w86):
		_w86._p41(function_name, _j46, _v36, file_path, model)
func _m97(refactored_code: String, original_hash: String, function_name: String):
	if is_instance_valid(_i63):
		_i63._b22()
	var _i13 = get_editor_interface()
	var current_scene = _i13.get_editor_main_screen() if _i13 else null
	if current_scene and is_instance_valid(_b33):
		if not _b33.is_inside_tree():
			current_scene.add_child(_b33)
		var _p82 = ""
		if is_instance_valid(_i63) and _i63.has_meta("function_source"):
			_p82 = _i63.get_meta("function_source")
		if _p82.is_empty():
			_p82 = _z83(function_name)
		if not _p82.is_empty():
			_b33._f97(function_name, _p82, refactored_code)
		else:
			_b33._f97(function_name, "# Original source not available", refactored_code)
func _u94(_j71: int, _b14: String):
	if is_instance_valid(_i63):
		_i63._b22()
	push_error("Refactor failed: " + _b14)
func _m10(refactored_code: String, function_name: String):
	var original_code = _z83(function_name)
	var file_path = ""
	var function_line = 0
	var _i13 = get_editor_interface()
	if _i13:
		var _t27 = _i13.get_script_editor()
		if _t27:
			var _k74 = _t27.get_current_script()
			if _k74:
				file_path = _k74.resource_path
	if is_instance_valid(_c39):
		var _d100 = _c39._u37()
		for _b28 in _d100:
			if _b28.name == function_name:
				function_line = _b28.line
				break
	var _r99 = _w8(refactored_code)
	_r99 = _r99.rstrip("\n") + "\n"
	_c73(function_name, _r99)
	if _s34 and not original_code.is_empty():
		var _y67 = _r99.rstrip("\n") + "\n\n"
		_s34._i79(function_name, original_code, _y67, file_path, function_line)
		if is_instance_valid(_a46):
			_a46._u67()
		if is_instance_valid(_c39):
			_c39._u67()
		if is_instance_valid(_p57):
			_p57._u67()
		_w43()
func _p14(function_name: String):
	pass
func _v68(script: Script):
	_t26()
func _t26():
	var _r100: Array[_k89] = []
	for _l62 in _v26:
		if is_instance_valid(_l62):
			_r100.append(_l62)
		else:
			pass
	_v26 = _r100
	var _c100: Array[_b83] = []
	for _l62 in _b26:
		if is_instance_valid(_l62):
			_c100.append(_l62)
		else:
			pass
	_b26 = _c100
	var _f8: Array[_i5] = []
	for _l62 in _r8:
		if is_instance_valid(_l62):
			_f8.append(_l62)
		else:
			pass
	_r8 = _f8
func _z83(function_name: String) -> String:
	var _i13 = get_editor_interface()
	if not _i13:
		return ""
	var _t27 = _i13.get_script_editor()
	if not _t27:
		return ""
	var _k74 = _t27.get_current_script()
	if not _k74:
		return ""
	if is_instance_valid(_c39):
		var _d100 = _c39._u37()
		for _b28 in _d100:
			if _b28.name == function_name:
				return _c39._v72(_b28)
	return ""
func _c73(function_name: String, refactored_code: String):
	var _i13 = get_editor_interface()
	if not _i13:
		return
	var _t27 = _i13.get_script_editor()
	if not _t27:
		return
	var _d47 = _t27.get_current_editor()
	if not _d47:
		return
	var _v93 = _m58(_d47)
	if not _v93:
		return
	if is_instance_valid(_c39):
		var _d100 = _c39._u37()
		for _b28 in _d100:
			if _b28.name == function_name:
				var start_line = _b28.line
				var end_line = _b28.get("end_line", start_line)
				var _h71 = refactored_code.rstrip("\n") + "\n\n"
				_j10(_v93, start_line, end_line, _h71)
				return
func _m58(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node
	for _o14 in node.get_children():
		var _s61 = _m58(_o14)
		if _s61:
			return _s61
	return null
func _j10(_v93: CodeEdit, start_line: int, end_line: int, _o16: String):
	_v93.set_caret_line(start_line)
	_v93.set_caret_column(0)
	_v93.select(start_line, 0, end_line + 1, 0)
	var _u21 = _o16
	if not _u21.ends_with("\n"):
		_u21 += "\n"
	_v93.insert_text_at_caret(_u21)
	_v93.deselect()
func _w8(text: String) -> String:
	var _t70 = text.split("\n")
	for i in range(_t70.size()):
		var line = _t70[i]
		var _f5 = 0
		for c in line:
			if c == ' ':
				_f5 += 1
			else:
				break
		var _t94 = _f5 / 4
		if _t94 > 0:
			_t70[i] = "\t".repeat(_t94) + line.substr(_f5)
	return "\n".join(_t70)
func _f33(function_name: String, file_path: String):
	if not _s34 or not _s34._r30(function_name, file_path):
		_w43()
		if is_instance_valid(_v95):
			_v95._u47(function_name)
		return
	var _v80 = _s34._f32(function_name, file_path)
	if not _v80:
		_w43()
		if is_instance_valid(_v95):
			_v95._z100(function_name, "No history entry found")
		return
	var _i75 = false
	if is_instance_valid(_a46):
		_i75 = not _a46._o39(function_name, file_path)
	_z76()
	if is_instance_valid(_a98):
		_a98._c20(_v80, file_path, _i75)
func _l50(function_name: String, original_code: String, file_path: String):
	var refactored_code = ""
	if _s34:
		var _v80 = _s34._f32(function_name, file_path)
		if _v80:
			refactored_code = _v80.refactored_code
	var success = _k11(function_name, original_code, refactored_code, file_path)
	if success:
		if _s34:
			var _v80 = _s34._f32(function_name, file_path)
			if _v80:
				_s34._w9(function_name, file_path, _v80.timestamp)
		if is_instance_valid(_a46):
			_a46._u67()
		if is_instance_valid(_c39):
			_c39._u67()
		if is_instance_valid(_p57):
			_p57._u67()
		_w43()
		if is_instance_valid(_v95):
			_v95._s2(function_name)
	else:
		_w43()
		if is_instance_valid(_v95):
			_v95._z100(function_name, "Failed to apply original code")
func _k11(function_name: String, original_code: String, refactored_code: String, file_path: String) -> bool:
	var _i13 = get_editor_interface()
	if not _i13:
		push_error("GDSensePlugin: Could not get editor interface for undo")
		return false
	var _t27 = _i13.get_script_editor()
	if not _t27:
		push_error("GDSensePlugin: Could not get script editor for undo")
		return false
	var _d47 = _t27.get_current_editor()
	if not _d47:
		push_error("GDSensePlugin: Could not get current editor for undo")
		return false
	var _v93 = _m58(_d47)
	if not _v93:
		push_error("GDSensePlugin: Could not find CodeEdit node for undo")
		return false
	var text = _v93.text
	var _t70 = text.split("\n")
	var _q3 = RegEx.new()
	_q3.compile("^\\s*func\\s+" + function_name + "\\s*\\(")
	var _t40 = -1
	for i in range(_t70.size()):
		if _q3.search(_t70[i]):
			_t40 = i
			break
	if _t40 == -1:
		push_error("GDSensePlugin: Could not find function to undo: " + function_name)
		return false
	var start_line = _t40
	var _x94 = original_code.strip_edges().begins_with("func ")
	if _x94:
		while start_line > 0:
			var _t92 = _t70[start_line - 1].strip_edges()
			if _t92.begins_with("#"):
				start_line -= 1
			else:
				break
	var end_line = _r20(_t70, _t40)
	var _h71 = original_code.rstrip("\n") + "\n\n"
	_j10(_v93, start_line, end_line, _h71)
	return true
func _r20(_t70: PackedStringArray, start_line: int) -> int:
	if start_line >= _t70.size():
		return start_line
	var _b90 = _z13(_t70[start_line])
	for i in range(start_line + 1, _t70.size()):
		var line = _t70[i]
		var _z10 = line.strip_edges()
		if _z10.is_empty() or _z10.begins_with("#"):
			continue
		var _m78 = _z13(line)
		if _m78 <= _b90:
			if _z10.begins_with("func ") or _z10.begins_with("class ") or _z10.begins_with("extends") or _z10.begins_with("@"):
				return i - 1
	return _t70.size() - 1
func _z13(line: String) -> int:
	var indent = 0
	for _q64 in line:
		if _q64 == '\t':
			indent += 4  
		elif _q64 == ' ':
			indent += 1
		else:
			break
	return indent
func _w43():
	if not is_instance_valid(_v95):
		return
	var _i13 = get_editor_interface()
	if not _i13:
		return
	var current_scene = _i13.get_editor_main_screen()
	if not current_scene:
		return
	if not _v95.is_inside_tree():
		current_scene.add_child(_v95)
func _z76():
	if not is_instance_valid(_a98):
		return
	var _i13 = get_editor_interface()
	if not _i13:
		return
	var current_scene = _i13.get_editor_main_screen()
	if not current_scene:
		return
	if not _a98.is_inside_tree():
		current_scene.add_child(_a98)
func _g32():
	if not is_instance_valid(_d57):
		return
	var _i13 = get_editor_interface()
	if not _i13:
		return
	var current_scene = _i13.get_editor_main_screen()
	if not current_scene:
		return
	if not _d57.is_inside_tree():
		current_scene.add_child(_d57)
func _j58(file_path: String):
	_g32()
	if is_instance_valid(_d57):
		_d57._o67(file_path)
func _y25():
	_g32()
	if is_instance_valid(_d57):
		_d57._r81()
func _i2() -> _z98:
	return _s34
