@tool
extends EditorPlugin

const _l13 = preload("res://addons/gdsense/scripts/_s11.gd")
const _a59 = preload("res://addons/gdsense/scripts/_b92.gd")
const _v35 = preload("res://addons/gdsense/scripts/_f43.gd")
const _v51 = preload("res://addons/gdsense/scripts/_z69.gd")
const _b96 = preload("res://addons/gdsense/scripts/_k89.gd")
const _g70 = preload("res://addons/gdsense/scripts/_j83.gd")
const _x77 = preload("res://addons/gdsense/scenes/_o4.tscn")
const _w93 = preload("res://addons/gdsense/scenes/_x87.tscn")
const _h3 = preload("res://addons/gdsense/scenes/_h7.tscn")
const _q47 = preload("res://addons/gdsense/scenes/_h69.tscn")
const _y53 = preload("res://addons/gdsense/scenes/_d77.tscn")

var _e64: Control
var _s11: _b81
var _t46: _b92

var _f43: _d40
var _u81: Array[_d40] = []

var _z69: _j99
var _o4: _w60
var _x87: _j98
var _a41: Array[_j99] = []

var _k89: _u83
var _j83: _o9
var _h7: _b39
var _f53: _m65
var _d77: _f34
var _y75: Array[_u83] = []

func _enter_tree() -> void:
	_t46 = _a59.new()
	add_child(_t46)
	
	var _f12: PackedScene = preload("res://addons/gdsense/scenes/_q36.tscn")
	_e64 = _f12.instantiate()
	
	if _e64.has_method("set_gdsense_manager"):
		_e64.set_gdsense_manager(_t46)
	
	if _e64.has_method("set_plugin"):
		_e64.set_plugin(self)
	
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _e64)
	
	_s11 = _l13.new(self, _t46)
	
	_k52()
	
	_p50()
	
	_b31()
	
	var _i86 = get_editor_interface()
	if _i86:
		var _w75 = _i86.get_script_editor()
		if _w75 and not _w75.editor_script_changed.is_connected(_c66):
			_w75.editor_script_changed.connect(_c66)
	
	_l63()
	_b100()
	_y47()
	_x61()
	
	_b97.call_deferred()

func _exit_tree() -> void:
	if is_instance_valid(_e64):
		remove_control_from_docks(_e64)
		_e64.free() 
	
	if is_instance_valid(_s11):
		_s11._o76()
		_s11 = null
	
	_f31()
	
	_x89()
	
	_x79()
	
	var _i86 = get_editor_interface()
	if _i86:
		var _w75 = _i86.get_script_editor()
		if _w75 and _w75.editor_script_changed.is_connected(_c66):
			_w75.editor_script_changed.disconnect(_c66)
	
	if is_instance_valid(_t46):
		_t46.queue_free()
		_t46 = null

func _k52():
	_f43 = _v35.new(self)
	_f43._n51.connect(_p53)
	_u81.append(_f43)

func _p50():
	_z69 = _v51.new(self)
	_z69._y42.connect(_k53)
	_a41.append(_z69)
	
	_o4 = _x77.instantiate()
	_o4._g24.connect(_n69)

	if is_instance_valid(_t46):
		_o4.set_gdsense_manager(_t46)

	_x87 = _w93.instantiate()
	_x87._u46.connect(_a64)
	_x87._h79.connect(_o79)
	
	if is_instance_valid(_t46):
		_t46._n74.connect(_n56)
		_t46._f93.connect(_g40)

func _f31():
	for _i43 in _u81:
		if is_instance_valid(_i43):
			_i43._o76()
	_u81.clear()
	_f43 = null

func _x89():
	for _i43 in _a41:
		if is_instance_valid(_i43):
			_i43._o76()
	_a41.clear()
	_z69 = null
	
	if is_instance_valid(_o4):
		_o4.queue_free()
		_o4 = null
	
	if is_instance_valid(_x87):
		_x87.queue_free()
		_x87 = null

func _b31():
	_j83 = _g70.new()
	
	_k89 = _b96.new(self, _j83)
	_k89._m70.connect(_h8)
	_y75.append(_k89)
	
	_h7 = _h3.instantiate()
	_h7._a87(get_editor_interface())
	_h7._f83.connect(_e75)
	
	_f53 = _q47.instantiate()
	_f53._s42(_j83)
	
	_d77 = _y53.instantiate()

func _x79():
	for _i43 in _y75:
		if is_instance_valid(_i43):
			_i43._o76()
	_y75.clear()
	_k89 = null
	
	if is_instance_valid(_h7):
		_h7.queue_free()
		_h7 = null
	
	if is_instance_valid(_f53):
		_f53.queue_free()
		_f53 = null
	
	if is_instance_valid(_d77):
		_d77.queue_free()
		_d77 = null
	
	if _j83:
		_j83._g81()
		_j83 = null

func _l63():
	const _w1 = 1000
	const _t35 = 150
	
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		_s11._l93 = config.get_value("autocomplete", "enabled", true)
		_s11._e41 = _w1  
		_s11._s47 = _t35  
		_s11._u75 = config.get_value("autocomplete", "mode", "automatic")
		_s11._r56 = config.get_value("autocomplete", "min_chars", 3)
	else:
		_s11._l93 = true
		_s11._e41 = _w1
		_s11._s47 = _t35
		_s11._u75 = "automatic"
		_s11._r56 = 3

func save_autocomplete_config(enabled: bool, _k39: int, max_length: int, mode: String = "", _a69: int = 3):
	const _w1 = 1000
	const _t35 = 150
	
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")  
	
	config.set_value("autocomplete", "enabled", enabled)
	config.set_value("autocomplete", "delay_ms", _w1)  
	config.set_value("autocomplete", "max_length", _t35)  
	if mode != "":
		config.set_value("autocomplete", "mode", mode)
	config.set_value("autocomplete", "min_chars", _a69)
	
	config.save("user://gdsense_api_key.cfg")
	
	if is_instance_valid(_s11):
		_s11.set_enabled(enabled)
		_s11.set_delay(_w1)  
		_s11._s47 = _t35  
		if mode != "":
			_s11.set_mode(mode)
		_s11._r56 = _a69

func _b100():
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var enabled = config.get_value("explain_button", "enabled", true)
		if _f43:
			_f43.set_enabled(enabled)
	else:
		if _f43:
			_f43.set_enabled(true)

func _y47():
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var enabled = config.get_value("refactor_button", "enabled", true)
		if is_instance_valid(_z69):
			_z69.set_enabled(enabled)
	else:
		if is_instance_valid(_z69):
			_z69.set_enabled(true)

func _x61():
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var enabled = config.get_value("undo_button", "enabled", true)
		if is_instance_valid(_k89):
			_k89.set_enabled(enabled)
	else:
		if is_instance_valid(_k89):
			_k89.set_enabled(true)

func _b97():
	var _i86 = get_editor_interface()
	if not _i86:
		return
	
	var _w75 = _i86.get_script_editor()
	if not _w75:
		return
	
	var _f78 = _w75.get_current_script()
	if _f78:
		var config = ConfigFile.new()
		if config.load("user://gdsense_api_key.cfg") == OK:
			var _p28 = config.get_value("explain_button", "enabled", true)
			if _p28 and _f43:
				_f43._f64(_f78)
			
			var _p73 = config.get_value("refactor_button", "enabled", true)
			if _p73 and _z69:
				_z69._f64(_f78)
			
			var _d37 = config.get_value("undo_button", "enabled", true)
			if _d37 and _k89:
				_k89._f64(_f78)

func save_explain_button_config(enabled: bool):
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")  
	
	config.set_value("explain_button", "enabled", enabled)
	config.save("user://gdsense_api_key.cfg")
	
	if _f43:
		_f43.set_enabled(enabled)
		
		if enabled:
			_b97.call_deferred()

func save_refactor_config(enabled: bool):
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")  
	
	config.set_value("refactor_button", "enabled", enabled)
	config.save("user://gdsense_api_key.cfg")
	
	if is_instance_valid(_z69):
		_z69.set_enabled(enabled)

func save_undo_config(enabled: bool):
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")  
	
	config.set_value("undo_button", "enabled", enabled)
	config.save("user://gdsense_api_key.cfg")
	
	if is_instance_valid(_k89):
		_k89.set_enabled(enabled)

func _p53(function_name: String, _z29: String):
	if not is_instance_valid(_e64):
		return
	
	if _e64.has_method("send_explain_request"):
		_e64.send_explain_request(function_name, _z29)
	else:
		pass

func _k53(function_name: String, _z29: String, file_path: String):
	if is_instance_valid(_o4):
		_o4.set_meta("file_path", file_path)
		_o4.set_meta("function_source", _z29)
	
	var _i86 = get_editor_interface()
	var current_scene = _i86.get_editor_main_screen() if _i86 else null
	if current_scene and is_instance_valid(_o4):
		if not _o4.is_inside_tree():
			current_scene.add_child(_o4)
		_o4._k60(function_name, _z29)

func _n69(_r76: String, function_name: String, _z29: String, model: String):
	var file_path = ""
	if is_instance_valid(_o4) and _o4.has_meta("file_path"):
		file_path = _o4.get_meta("file_path")

	if is_instance_valid(_t46):
		_t46._b64(function_name, _z29, _r76, file_path, model)

func _n56(refactored_code: String, original_hash: String, function_name: String):
	if is_instance_valid(_o4):
		_o4._a10()
	
	var _i86 = get_editor_interface()
	var current_scene = _i86.get_editor_main_screen() if _i86 else null
	if current_scene and is_instance_valid(_x87):
		if not _x87.is_inside_tree():
			current_scene.add_child(_x87)
		
		var _z15 = ""
		if is_instance_valid(_o4) and _o4.has_meta("function_source"):
			_z15 = _o4.get_meta("function_source")

		if _z15.is_empty():
			_z15 = _g28(function_name)

		if not _z15.is_empty():
			_x87._s31(function_name, _z15, refactored_code)
		else:
			_x87._s31(function_name, "# Original source not available", refactored_code)

func _g40(_k63: int, _p71: String):
	if is_instance_valid(_o4):
		_o4._a10()
	
	push_error("Refactor failed: " + _p71)

func _a64(refactored_code: String, function_name: String):
	var original_code = _g28(function_name)
	var file_path = ""
	var function_line = 0
	
	var _i86 = get_editor_interface()
	if _i86:
		var _w75 = _i86.get_script_editor()
		if _w75:
			var _f78 = _w75.get_current_script()
			if _f78:
				file_path = _f78.resource_path
	
	if is_instance_valid(_z69):
		var _j67 = _z69._c69()
		for _c28 in _j67:
			if _c28.name == function_name:
				function_line = _c28.line
				break
	
	var _z63 = _j62(refactored_code)

	_z63 = _z63.rstrip("\n") + "\n"

	_q94(function_name, _z63)

	if _j83 and not original_code.is_empty():
		var _p87 = _z63.rstrip("\n") + "\n\n"
		_j83._n14(function_name, original_code, _p87, file_path, function_line)
		
		if is_instance_valid(_k89):
			_k89._f29()
		if is_instance_valid(_z69):
			_z69._f29()
		if is_instance_valid(_f43):
			_f43._f29()
		
		_r80()
	
func _o79(function_name: String):
	pass

func _c66(script: Script):
	_o2()

func _o2():
	var _i8: Array[_d40] = []
	for _i43 in _u81:
		if is_instance_valid(_i43):
			_i8.append(_i43)
		else:
			pass

	_u81 = _i8
	
	var _o39: Array[_j99] = []
	for _i43 in _a41:
		if is_instance_valid(_i43):
			_o39.append(_i43)
		else:
			pass

	_a41 = _o39
	
	var _w71: Array[_u83] = []
	for _i43 in _y75:
		if is_instance_valid(_i43):
			_w71.append(_i43)
		else:
			pass

	_y75 = _w71

func _g28(function_name: String) -> String:
	var _i86 = get_editor_interface()
	if not _i86:
		return ""
	
	var _w75 = _i86.get_script_editor()
	if not _w75:
		return ""
	
	var _f78 = _w75.get_current_script()
	if not _f78:
		return ""
	
	if is_instance_valid(_z69):
		var _j67 = _z69._c69()
		for _c28 in _j67:
			if _c28.name == function_name:
				return _z69._u95(_c28)
	
	return ""

func _q94(function_name: String, refactored_code: String):
	var _i86 = get_editor_interface()
	if not _i86:
		return
	
	var _w75 = _i86.get_script_editor()
	if not _w75:
		return
	
	var _c22 = _w75.get_current_editor()
	if not _c22:
		return
	
	var _o58 = _p60(_c22)
	if not _o58:
		return
	
	if is_instance_valid(_z69):
		var _j67 = _z69._c69()
		for _c28 in _j67:
			if _c28.name == function_name:
				var start_line = _c28.line
				var end_line = _c28.get("end_line", start_line)

				var _w97 = refactored_code.rstrip("\n") + "\n\n"

				_f89(_o58, start_line, end_line, _w97)

				return
	
func _p60(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node
	
	for _j75 in node.get_children():
		var _v42 = _p60(_j75)
		if _v42:
			return _v42
	
	return null

func _f89(_o58: CodeEdit, start_line: int, end_line: int, _f13: String):
	_o58.set_caret_line(start_line)
	_o58.set_caret_column(0)
	_o58.select(start_line, 0, end_line + 1, 0)

	var _n39 = _f13
	if not _n39.ends_with("\n"):
		_n39 += "\n"
	_o58.insert_text_at_caret(_n39)

	_o58.deselect()

func _j62(text: String) -> String:
	var _b26 = text.split("\n")
	for i in range(_b26.size()):
		var line = _b26[i]
		var _l72 = 0
		for c in line:
			if c == ' ':
				_l72 += 1
			else:
				break

		var _n10 = _l72 / 4
		if _n10 > 0:
			_b26[i] = "\t".repeat(_n10) + line.substr(_l72)

	return "\n".join(_b26)

func _h8(function_name: String, file_path: String):
	if not _j83 or not _j83._e76(function_name, file_path):
		_r80()
		if is_instance_valid(_d77):
			_d77._d56(function_name)
		return
	
	var _s58 = _j83._t6(function_name, file_path)
	if not _s58:
		_r80()
		if is_instance_valid(_d77):
			_d77._p19(function_name, "No history entry found")
		return
	
	var _y58 = false
	if is_instance_valid(_k89):
		_y58 = not _k89._w64(function_name, file_path)
	
	_f66()
	if is_instance_valid(_h7):
		_h7._k60(_s58, file_path, _y58)

func _e75(function_name: String, original_code: String, file_path: String):
	var refactored_code = ""
	if _j83:
		var _s58 = _j83._t6(function_name, file_path)
		if _s58:
			refactored_code = _s58.refactored_code
	
	var success = _g21(function_name, original_code, refactored_code, file_path)
	
	if success:
		if _j83:
			var _s58 = _j83._t6(function_name, file_path)
			if _s58:
				_j83._e22(function_name, file_path, _s58.timestamp)
		
		if is_instance_valid(_k89):
			_k89._f29()
		if is_instance_valid(_z69):
			_z69._f29()
		if is_instance_valid(_f43):
			_f43._f29()
		
		_r80()
		if is_instance_valid(_d77):
			_d77._v79(function_name)
	else:
		_r80()
		if is_instance_valid(_d77):
			_d77._p19(function_name, "Failed to apply original code")

func _g21(function_name: String, original_code: String, refactored_code: String, file_path: String) -> bool:
	var _i86 = get_editor_interface()
	if not _i86:
		push_error("GDSensePlugin: Could not get editor interface for undo")
		return false
	
	var _w75 = _i86.get_script_editor()
	if not _w75:
		push_error("GDSensePlugin: Could not get script editor for undo")
		return false
	
	var _c22 = _w75.get_current_editor()
	if not _c22:
		push_error("GDSensePlugin: Could not get current editor for undo")
		return false
	
	var _o58 = _p60(_c22)
	if not _o58:
		push_error("GDSensePlugin: Could not find CodeEdit node for undo")
		return false
	
	var text = _o58.text
	var _b26 = text.split("\n")

	var _f3 = RegEx.new()
	_f3.compile("^\\s*func\\s+" + function_name + "\\s*\\(")

	var _z39 = -1
	for i in range(_b26.size()):
		if _f3.search(_b26[i]):
			_z39 = i
			break

	if _z39 == -1:
		push_error("GDSensePlugin: Could not find function to undo: " + function_name)
		return false

	var start_line = _z39
	var _v46 = original_code.strip_edges().begins_with("func ")

	if _v46:
		while start_line > 0:
			var _j48 = _b26[start_line - 1].strip_edges()
			if _j48.begins_with("#"):
				start_line -= 1
			else:
				break

	var end_line = _v22(_b26, _z39)

	var _w97 = original_code.rstrip("\n") + "\n\n"
	_f89(_o58, start_line, end_line, _w97)

	return true

func _v22(_b26: PackedStringArray, start_line: int) -> int:
	if start_line >= _b26.size():
		return start_line
	
	var _a23 = _p97(_b26[start_line])
	
	for i in range(start_line + 1, _b26.size()):
		var line = _b26[i]
		var _x6 = line.strip_edges()
		
		if _x6.is_empty() or _x6.begins_with("#"):
			continue
		
		var _c34 = _p97(line)
		
		if _c34 <= _a23:
			if _x6.begins_with("func ") or _x6.begins_with("class ") or _x6.begins_with("extends") or _x6.begins_with("@"):
				return i - 1
	
	return _b26.size() - 1

func _p97(line: String) -> int:
	var indent = 0
	for char in line:
		if char == '\t':
			indent += 4  
		elif char == ' ':
			indent += 1
		else:
			break
	return indent

func _r80():
	if not is_instance_valid(_d77):
		return
	
	var _i86 = get_editor_interface()
	if not _i86:
		return
	
	var current_scene = _i86.get_editor_main_screen()
	if not current_scene:
		return
	
	if not _d77.is_inside_tree():
		current_scene.add_child(_d77)

func _f66():
	if not is_instance_valid(_h7):
		return
	
	var _i86 = get_editor_interface()
	if not _i86:
		return
	
	var current_scene = _i86.get_editor_main_screen()
	if not current_scene:
		return
	
	if not _h7.is_inside_tree():
		current_scene.add_child(_h7)

func _z28():
	if not is_instance_valid(_f53):
		return
	
	var _i86 = get_editor_interface()
	if not _i86:
		return
	
	var current_scene = _i86.get_editor_main_screen()
	if not current_scene:
		return
	
	if not _f53.is_inside_tree():
		current_scene.add_child(_f53)

func _h44(file_path: String):
	_z28()
	if is_instance_valid(_f53):
		_f53._z54(file_path)

func _p34():
	_z28()
	if is_instance_valid(_f53):
		_f53._z57()

func _i54() -> _o9:
	return _j83

