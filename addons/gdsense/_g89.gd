@tool
extends EditorPlugin
const _r22 = preload("res://addons/gdsense/scripts/_z45.gd")
const _e85 = preload("res://addons/gdsense/scripts/_a99.gd")
const _x25 = preload("res://addons/gdsense/scripts/_w22.gd")
const _p22 = preload("res://addons/gdsense/scripts/_k77.gd")
const _a60 = preload("res://addons/gdsense/scripts/_o53.gd")
const _b80 = preload("res://addons/gdsense/scripts/_a51.gd")
const _j7 = preload("res://addons/gdsense/scenes/_b20.tscn")
const _i28 = preload("res://addons/gdsense/scenes/_l81.tscn")
const _m92 = preload("res://addons/gdsense/scenes/_f10.tscn")
const _p87 = preload("res://addons/gdsense/scenes/_v77.tscn")
const _j25 = preload("res://addons/gdsense/scenes/_a42.tscn")
var _e2: Control
var _z45: _n16
var _w18: _a99
var _w22: _e58
var _f27: Array[_e58] = []
var _k77: _s84
var _b20: _v18
var _l81: _z64
var _n48: Array[_s84] = []
var _o53: _j6
var _a51: _z30
var _f10: _l32
var _q92: _n55
var _a42: _y20
var _j57: Array[_j6] = []
func _enter_tree() -> void:
	_w18 = _e85.new()
	add_child(_w18)
	var _y7: PackedScene = preload("res://addons/gdsense/scenes/_w64.tscn")
	_e2 = _y7.instantiate()
	if _e2.has_method("set_gdsense_manager"):
		_e2.set_gdsense_manager(_w18)
	if _e2.has_method("set_plugin"):
		_e2.set_plugin(self)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _e2)
	_z45 = _r22.new(self, _w18)
	_r85()
	_c6()
	_h71()
	var _o10 = get_editor_interface()
	if _o10:
		var _x62 = _o10.get_script_editor()
		if _x62 and not _x62.editor_script_changed.is_connected(_b45):
			_x62.editor_script_changed.connect(_b45)
	_a25()
	_z53()
	_z99()
	_t69()
	_k68.call_deferred()
func _exit_tree() -> void:
	if is_instance_valid(_e2):
		remove_control_from_docks(_e2)
		_e2.free() 
	if is_instance_valid(_z45):
		_z45._h41()
		_z45 = null
	_l92()
	_e69()
	_p6()
	var _o10 = get_editor_interface()
	if _o10:
		var _x62 = _o10.get_script_editor()
		if _x62 and _x62.editor_script_changed.is_connected(_b45):
			_x62.editor_script_changed.disconnect(_b45)
	if is_instance_valid(_w18):
		_w18.queue_free()
		_w18 = null
func _r85():
	_w22 = _x25.new(self)
	_w22._a59.connect(_r44)
	_f27.append(_w22)
func _c6():
	_k77 = _p22.new(self)
	_k77._r17.connect(_o17)
	_n48.append(_k77)
	_b20 = _j7.instantiate()
	_b20._z93.connect(_x17)
	if is_instance_valid(_w18):
		_b20.set_gdsense_manager(_w18)
	_l81 = _i28.instantiate()
	_l81._p51.connect(_c71)
	_l81._t68.connect(_c34)
	if is_instance_valid(_w18):
		_w18._w57.connect(_e31)
		_w18._t37.connect(_n63)
func _l92():
	for _g63 in _f27:
		if is_instance_valid(_g63):
			_g63._h41()
	_f27.clear()
	_w22 = null
func _e69():
	for _g63 in _n48:
		if is_instance_valid(_g63):
			_g63._h41()
	_n48.clear()
	_k77 = null
	if is_instance_valid(_b20):
		_b20.queue_free()
		_b20 = null
	if is_instance_valid(_l81):
		_l81.queue_free()
		_l81 = null
func _h71():
	_a51 = _b80.new()
	_o53 = _a60.new(self, _a51)
	_o53._j4.connect(_h98)
	_j57.append(_o53)
	_f10 = _m92.instantiate()
	_f10._f94(get_editor_interface())
	_f10._k28.connect(_q12)
	_q92 = _p87.instantiate()
	_q92._r76(_a51)
	_a42 = _j25.instantiate()
func _p6():
	for _g63 in _j57:
		if is_instance_valid(_g63):
			_g63._h41()
	_j57.clear()
	_o53 = null
	if is_instance_valid(_f10):
		_f10.queue_free()
		_f10 = null
	if is_instance_valid(_q92):
		_q92.queue_free()
		_q92 = null
	if is_instance_valid(_a42):
		_a42.queue_free()
		_a42 = null
	if _a51:
		_a51._z5()
		_a51 = null
func _a25():
	const _r79 = 1000
	const _g33 = 150
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		_z45._h61 = config.get_value("autocomplete", "enabled", true)
		_z45._m49 = _r79  
		_z45._w73 = _g33  
		_z45._m71 = config.get_value("autocomplete", "mode", "automatic")
		_z45._i59 = config.get_value("autocomplete", "min_chars", 3)
	else:
		_z45._h61 = true
		_z45._m49 = _r79
		_z45._w73 = _g33
		_z45._m71 = "automatic"
		_z45._i59 = 3
func save_autocomplete_config(enabled: bool, _u62: int, max_length: int, mode: String = "", _a65: int = 3):
	const _r79 = 1000
	const _g33 = 150
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")  
	config.set_value("autocomplete", "enabled", enabled)
	config.set_value("autocomplete", "delay_ms", _r79)  
	config.set_value("autocomplete", "max_length", _g33)  
	if mode != "":
		config.set_value("autocomplete", "mode", mode)
	config.set_value("autocomplete", "min_chars", _a65)
	config.save("user://gdsense_api_key.cfg")
	if is_instance_valid(_z45):
		_z45.set_enabled(enabled)
		_z45.set_delay(_r79)  
		_z45._w73 = _g33  
		if mode != "":
			_z45.set_mode(mode)
		_z45._i59 = _a65
func _z53():
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var enabled = config.get_value("explain_button", "enabled", true)
		if _w22:
			_w22.set_enabled(enabled)
	else:
		if _w22:
			_w22.set_enabled(true)
func _z99():
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var enabled = config.get_value("refactor_button", "enabled", true)
		if is_instance_valid(_k77):
			_k77.set_enabled(enabled)
	else:
		if is_instance_valid(_k77):
			_k77.set_enabled(true)
func _t69():
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var enabled = config.get_value("undo_button", "enabled", true)
		if is_instance_valid(_o53):
			_o53.set_enabled(enabled)
	else:
		if is_instance_valid(_o53):
			_o53.set_enabled(true)
func _k68():
	var _o10 = get_editor_interface()
	if not _o10:
		return
	var _x62 = _o10.get_script_editor()
	if not _x62:
		return
	var _l100 = _x62.get_current_script()
	if _l100:
		var config = ConfigFile.new()
		if config.load("user://gdsense_api_key.cfg") == OK:
			var _n34 = config.get_value("explain_button", "enabled", true)
			if _n34 and _w22:
				_w22._c17(_l100)
			var _h15 = config.get_value("refactor_button", "enabled", true)
			if _h15 and _k77:
				_k77._c17(_l100)
			var _q43 = config.get_value("undo_button", "enabled", true)
			if _q43 and _o53:
				_o53._c17(_l100)
func save_explain_button_config(enabled: bool):
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")  
	config.set_value("explain_button", "enabled", enabled)
	config.save("user://gdsense_api_key.cfg")
	if _w22:
		_w22.set_enabled(enabled)
		if enabled:
			_k68.call_deferred()
func save_refactor_config(enabled: bool):
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")  
	config.set_value("refactor_button", "enabled", enabled)
	config.save("user://gdsense_api_key.cfg")
	if is_instance_valid(_k77):
		_k77.set_enabled(enabled)
func save_undo_config(enabled: bool):
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")  
	config.set_value("undo_button", "enabled", enabled)
	config.save("user://gdsense_api_key.cfg")
	if is_instance_valid(_o53):
		_o53.set_enabled(enabled)
func _r44(function_name: String, _w94: String):
	if not is_instance_valid(_e2):
		return
	if _e2.has_method("send_explain_request"):
		_e2.send_explain_request(function_name, _w94)
	else:
		pass
func _o17(function_name: String, _w94: String, file_path: String):
	if is_instance_valid(_b20):
		_b20.set_meta("file_path", file_path)
		_b20.set_meta("function_source", _w94)
	var _o10 = get_editor_interface()
	var current_scene = _o10.get_editor_main_screen() if _o10 else null
	if current_scene and is_instance_valid(_b20):
		if not _b20.is_inside_tree():
			current_scene.add_child(_b20)
		_b20._t47(function_name, _w94)
func _x17(_l70: String, function_name: String, _w94: String, model: String):
	var file_path = ""
	if is_instance_valid(_b20) and _b20.has_meta("file_path"):
		file_path = _b20.get_meta("file_path")
	if is_instance_valid(_w18):
		_w18._b85(function_name, _w94, _l70, file_path, model)
func _e31(refactored_code: String, original_hash: String, function_name: String):
	if is_instance_valid(_b20):
		_b20._e1()
	var _o10 = get_editor_interface()
	var current_scene = _o10.get_editor_main_screen() if _o10 else null
	if current_scene and is_instance_valid(_l81):
		if not _l81.is_inside_tree():
			current_scene.add_child(_l81)
		var _n41 = ""
		if is_instance_valid(_b20) and _b20.has_meta("function_source"):
			_n41 = _b20.get_meta("function_source")
		if _n41.is_empty():
			_n41 = _c19(function_name)
		if not _n41.is_empty():
			_l81._w89(function_name, _n41, refactored_code)
		else:
			_l81._w89(function_name, "# Original source not available", refactored_code)
func _n63(_a6: int, _p7: String):
	if is_instance_valid(_b20):
		_b20._e1()
	push_error("Refactor failed: " + _p7)
func _c71(refactored_code: String, function_name: String):
	var original_code = _c19(function_name)
	var file_path = ""
	var function_line = 0
	var _o10 = get_editor_interface()
	if _o10:
		var _x62 = _o10.get_script_editor()
		if _x62:
			var _l100 = _x62.get_current_script()
			if _l100:
				file_path = _l100.resource_path
	if is_instance_valid(_k77):
		var _s67 = _k77._o95()
		for _a20 in _s67:
			if _a20.name == function_name:
				function_line = _a20.line
				break
	var _u9 = _g20(refactored_code)
	_u9 = _u9.rstrip("\n") + "\n"
	_m78(function_name, _u9)
	if _a51 and not original_code.is_empty():
		var _c12 = _u9.rstrip("\n") + "\n\n"
		_a51._b89(function_name, original_code, _c12, file_path, function_line)
		if is_instance_valid(_o53):
			_o53._h100()
		if is_instance_valid(_k77):
			_k77._h100()
		if is_instance_valid(_w22):
			_w22._h100()
		_z6()
func _c34(function_name: String):
	pass
func _b45(script: Script):
	_j30()
func _j30():
	var _v59: Array[_e58] = []
	for _g63 in _f27:
		if is_instance_valid(_g63):
			_v59.append(_g63)
		else:
			pass
	_f27 = _v59
	var _c100: Array[_s84] = []
	for _g63 in _n48:
		if is_instance_valid(_g63):
			_c100.append(_g63)
		else:
			pass
	_n48 = _c100
	var _v32: Array[_j6] = []
	for _g63 in _j57:
		if is_instance_valid(_g63):
			_v32.append(_g63)
		else:
			pass
	_j57 = _v32
func _c19(function_name: String) -> String:
	var _o10 = get_editor_interface()
	if not _o10:
		return ""
	var _x62 = _o10.get_script_editor()
	if not _x62:
		return ""
	var _l100 = _x62.get_current_script()
	if not _l100:
		return ""
	if is_instance_valid(_k77):
		var _s67 = _k77._o95()
		for _a20 in _s67:
			if _a20.name == function_name:
				return _k77._v21(_a20)
	return ""
func _m78(function_name: String, refactored_code: String):
	var _o10 = get_editor_interface()
	if not _o10:
		return
	var _x62 = _o10.get_script_editor()
	if not _x62:
		return
	var _j1 = _x62.get_current_editor()
	if not _j1:
		return
	var _t5 = _b96(_j1)
	if not _t5:
		return
	if is_instance_valid(_k77):
		var _s67 = _k77._o95()
		for _a20 in _s67:
			if _a20.name == function_name:
				var start_line = _a20.line
				var end_line = _a20.get("end_line", start_line)
				var _n67 = refactored_code.rstrip("\n") + "\n\n"
				_w56(_t5, start_line, end_line, _n67)
				return
func _b96(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node
	for _i64 in node.get_children():
		var _n37 = _b96(_i64)
		if _n37:
			return _n37
	return null
func _w56(_t5: CodeEdit, start_line: int, end_line: int, _q41: String):
	_t5.set_caret_line(start_line)
	_t5.set_caret_column(0)
	_t5.select(start_line, 0, end_line + 1, 0)
	var _k62 = _q41
	if not _k62.ends_with("\n"):
		_k62 += "\n"
	_t5.insert_text_at_caret(_k62)
	_t5.deselect()
func _g20(text: String) -> String:
	var _a62 = text.split("\n")
	for i in range(_a62.size()):
		var line = _a62[i]
		var _l35 = 0
		for c in line:
			if c == ' ':
				_l35 += 1
			else:
				break
		var _z37 = _l35 / 4
		if _z37 > 0:
			_a62[i] = "\t".repeat(_z37) + line.substr(_l35)
	return "\n".join(_a62)
func _h98(function_name: String, file_path: String):
	if not _a51 or not _a51._k38(function_name, file_path):
		_z6()
		if is_instance_valid(_a42):
			_a42._d34(function_name)
		return
	var _w46 = _a51._a18(function_name, file_path)
	if not _w46:
		_z6()
		if is_instance_valid(_a42):
			_a42._f38(function_name, "No history entry found")
		return
	var _w36 = false
	if is_instance_valid(_o53):
		_w36 = not _o53._y73(function_name, file_path)
	_h93()
	if is_instance_valid(_f10):
		_f10._t47(_w46, file_path, _w36)
func _q12(function_name: String, original_code: String, file_path: String):
	var refactored_code = ""
	if _a51:
		var _w46 = _a51._a18(function_name, file_path)
		if _w46:
			refactored_code = _w46.refactored_code
	var success = _i54(function_name, original_code, refactored_code, file_path)
	if success:
		if _a51:
			var _w46 = _a51._a18(function_name, file_path)
			if _w46:
				_a51._e21(function_name, file_path, _w46.timestamp)
		if is_instance_valid(_o53):
			_o53._h100()
		if is_instance_valid(_k77):
			_k77._h100()
		if is_instance_valid(_w22):
			_w22._h100()
		_z6()
		if is_instance_valid(_a42):
			_a42._b70(function_name)
	else:
		_z6()
		if is_instance_valid(_a42):
			_a42._f38(function_name, "Failed to apply original code")
func _i54(function_name: String, original_code: String, refactored_code: String, file_path: String) -> bool:
	var _o10 = get_editor_interface()
	if not _o10:
		push_error("GDSensePlugin: Could not get editor interface for undo")
		return false
	var _x62 = _o10.get_script_editor()
	if not _x62:
		push_error("GDSensePlugin: Could not get script editor for undo")
		return false
	var _j1 = _x62.get_current_editor()
	if not _j1:
		push_error("GDSensePlugin: Could not get current editor for undo")
		return false
	var _t5 = _b96(_j1)
	if not _t5:
		push_error("GDSensePlugin: Could not find CodeEdit node for undo")
		return false
	var text = _t5.text
	var _a62 = text.split("\n")
	var _j70 = RegEx.new()
	_j70.compile("^\\s*func\\s+" + function_name + "\\s*\\(")
	var _j95 = -1
	for i in range(_a62.size()):
		if _j70.search(_a62[i]):
			_j95 = i
			break
	if _j95 == -1:
		push_error("GDSensePlugin: Could not find function to undo: " + function_name)
		return false
	var start_line = _j95
	var _s36 = original_code.strip_edges().begins_with("func ")
	if _s36:
		while start_line > 0:
			var _e38 = _a62[start_line - 1].strip_edges()
			if _e38.begins_with("#"):
				start_line -= 1
			else:
				break
	var end_line = _k11(_a62, _j95)
	var _n67 = original_code.rstrip("\n") + "\n\n"
	_w56(_t5, start_line, end_line, _n67)
	return true
func _k11(_a62: PackedStringArray, start_line: int) -> int:
	if start_line >= _a62.size():
		return start_line
	var _v93 = _h52(_a62[start_line])
	for i in range(start_line + 1, _a62.size()):
		var line = _a62[i]
		var _o40 = line.strip_edges()
		if _o40.is_empty() or _o40.begins_with("#"):
			continue
		var _h92 = _h52(line)
		if _h92 <= _v93:
			if _o40.begins_with("func ") or _o40.begins_with("class ") or _o40.begins_with("extends") or _o40.begins_with("@"):
				return i - 1
	return _a62.size() - 1
func _h52(line: String) -> int:
	var indent = 0
	for _c28 in line:
		if _c28 == '\t':
			indent += 4  
		elif _c28 == ' ':
			indent += 1
		else:
			break
	return indent
func _z6():
	if not is_instance_valid(_a42):
		return
	var _o10 = get_editor_interface()
	if not _o10:
		return
	var current_scene = _o10.get_editor_main_screen()
	if not current_scene:
		return
	if not _a42.is_inside_tree():
		current_scene.add_child(_a42)
func _h93():
	if not is_instance_valid(_f10):
		return
	var _o10 = get_editor_interface()
	if not _o10:
		return
	var current_scene = _o10.get_editor_main_screen()
	if not current_scene:
		return
	if not _f10.is_inside_tree():
		current_scene.add_child(_f10)
func _e68():
	if not is_instance_valid(_q92):
		return
	var _o10 = get_editor_interface()
	if not _o10:
		return
	var current_scene = _o10.get_editor_main_screen()
	if not current_scene:
		return
	if not _q92.is_inside_tree():
		current_scene.add_child(_q92)
func _s13(file_path: String):
	_e68()
	if is_instance_valid(_q92):
		_q92._s93(file_path)
func _r37():
	_e68()
	if is_instance_valid(_q92):
		_q92._u64()
func _k53() -> _z30:
	return _a51
