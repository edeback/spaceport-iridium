@tool
extends EditorPlugin

const _o57 = preload("res://addons/gdsense/scripts/_j15.gd")
const _y53 = preload("res://addons/gdsense/scripts/_y82.gd")
const _i79 = preload("res://addons/gdsense/scripts/_d49.gd")
const _b21 = preload("res://addons/gdsense/scripts/_p62.gd")
const _p71 = preload("res://addons/gdsense/scripts/_f14.gd")
const _n47 = preload("res://addons/gdsense/scripts/_y97.gd")
const _k33 = preload("res://addons/gdsense/scenes/_x75.tscn")
const _d1 = preload("res://addons/gdsense/scenes/_b50.tscn")
const _q18 = preload("res://addons/gdsense/scenes/_m94.tscn")
const _s16 = preload("res://addons/gdsense/scenes/_z14.tscn")
const _f73 = preload("res://addons/gdsense/scenes/_v35.tscn")

var _c66: Control
var _j15: _e47
var _d39: _y82

var _d49: _o9
var _z30: Array[_o9] = []

var _p62: _k92
var _x75: _m1
var _b50: _l47
var _i28: Array[_k92] = []

var _f14: _m21
var _y97: _b26
var _m94: _b8
var _m84: _i36
var _v35: _y94
var _k7: Array[_m21] = []

func _enter_tree() -> void:
	_d39 = _y53.new()
	add_child(_d39)
	
	var _l82: PackedScene = preload("res://addons/gdsense/scenes/_k77.tscn")
	_c66 = _l82.instantiate()
	
	if _c66.has_method("set_gdsense_manager"):
		_c66.set_gdsense_manager(_d39)
	
	if _c66.has_method("set_plugin"):
		_c66.set_plugin(self)
	
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _c66)
	
	_j15 = _o57.new(self, _d39)
	
	_a48()
	
	_u70()
	
	_g56()
	
	var _f28 = get_editor_interface()
	if _f28:
		var _f83 = _f28.get_script_editor()
		if _f83 and not _f83.editor_script_changed.is_connected(_r25):
			_f83.editor_script_changed.connect(_r25)
	
	_w14()
	_u53()
	_d94()
	_h2()
	
	_k89.call_deferred()

func _exit_tree() -> void:
	if is_instance_valid(_c66):
		remove_control_from_docks(_c66)
		_c66.free() 
	
	if is_instance_valid(_j15):
		_j15._q17()
		_j15 = null
	
	_h22()
	
	_u38()
	
	_f27()
	
	var _f28 = get_editor_interface()
	if _f28:
		var _f83 = _f28.get_script_editor()
		if _f83 and _f83.editor_script_changed.is_connected(_r25):
			_f83.editor_script_changed.disconnect(_r25)
	
	if is_instance_valid(_d39):
		_d39.queue_free()
		_d39 = null

func _a48():
	_d49 = _i79.new(self)
	_d49._z17.connect(_b94)
	_z30.append(_d49)

func _u70():
	_p62 = _b21.new(self)
	_p62._r35.connect(_j71)
	_i28.append(_p62)
	
	_x75 = _k33.instantiate()
	_x75._b27.connect(_f38)

	if is_instance_valid(_d39):
		_x75.set_gdsense_manager(_d39)

	_b50 = _d1.instantiate()
	_b50._n1.connect(_z80)
	_b50._u59.connect(_n60)
	
	if is_instance_valid(_d39):
		_d39._r67.connect(_h82)
		_d39._l62.connect(_t69)

func _h22():
	for _m39 in _z30:
		if is_instance_valid(_m39):
			_m39._q17()
	_z30.clear()
	_d49 = null

func _u38():
	for _m39 in _i28:
		if is_instance_valid(_m39):
			_m39._q17()
	_i28.clear()
	_p62 = null
	
	if is_instance_valid(_x75):
		_x75.queue_free()
		_x75 = null
	
	if is_instance_valid(_b50):
		_b50.queue_free()
		_b50 = null

func _g56():
	_y97 = _n47.new()
	
	_f14 = _p71.new(self, _y97)
	_f14._x88.connect(_l9)
	_k7.append(_f14)
	
	_m94 = _q18.instantiate()
	_m94._h21(get_editor_interface())
	_m94._v67.connect(_d42)
	
	_m84 = _s16.instantiate()
	_m84._b53(_y97)
	
	_v35 = _f73.instantiate()

func _f27():
	for _m39 in _k7:
		if is_instance_valid(_m39):
			_m39._q17()
	_k7.clear()
	_f14 = null
	
	if is_instance_valid(_m94):
		_m94.queue_free()
		_m94 = null
	
	if is_instance_valid(_m84):
		_m84.queue_free()
		_m84 = null
	
	if is_instance_valid(_v35):
		_v35.queue_free()
		_v35 = null
	
	if _y97:
		_y97._f4()
		_y97 = null

func _w14():
	const _i21 = 1000
	const _v59 = 150
	
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		_j15._a16 = config.get_value("autocomplete", "enabled", true)
		_j15._d19 = _i21  
		_j15._s50 = _v59  
		_j15._f15 = config.get_value("autocomplete", "mode", "automatic")
		_j15._n43 = config.get_value("autocomplete", "min_chars", 3)
	else:
		_j15._a16 = true
		_j15._d19 = _i21
		_j15._s50 = _v59
		_j15._f15 = "automatic"
		_j15._n43 = 3

func save_autocomplete_config(enabled: bool, _m91: int, max_length: int, mode: String = "", _n86: int = 3):
	const _i21 = 1000
	const _v59 = 150
	
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")  
	
	config.set_value("autocomplete", "enabled", enabled)
	config.set_value("autocomplete", "delay_ms", _i21)  
	config.set_value("autocomplete", "max_length", _v59)  
	if mode != "":
		config.set_value("autocomplete", "mode", mode)
	config.set_value("autocomplete", "min_chars", _n86)
	
	config.save("user://gdsense_api_key.cfg")
	
	if is_instance_valid(_j15):
		_j15.set_enabled(enabled)
		_j15.set_delay(_i21)  
		_j15._s50 = _v59  
		if mode != "":
			_j15.set_mode(mode)
		_j15._n43 = _n86

func _u53():
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var enabled = config.get_value("explain_button", "enabled", true)
		if _d49:
			_d49.set_enabled(enabled)
	else:
		if _d49:
			_d49.set_enabled(true)

func _d94():
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var enabled = config.get_value("refactor_button", "enabled", true)
		if is_instance_valid(_p62):
			_p62.set_enabled(enabled)
	else:
		if is_instance_valid(_p62):
			_p62.set_enabled(true)

func _h2():
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var enabled = config.get_value("undo_button", "enabled", true)
		if is_instance_valid(_f14):
			_f14.set_enabled(enabled)
	else:
		if is_instance_valid(_f14):
			_f14.set_enabled(true)

func _k89():
	var _f28 = get_editor_interface()
	if not _f28:
		return
	
	var _f83 = _f28.get_script_editor()
	if not _f83:
		return
	
	var _g40 = _f83.get_current_script()
	if _g40:
		var config = ConfigFile.new()
		if config.load("user://gdsense_api_key.cfg") == OK:
			var _h61 = config.get_value("explain_button", "enabled", true)
			if _h61 and _d49:
				_d49._j68(_g40)
			
			var _q1 = config.get_value("refactor_button", "enabled", true)
			if _q1 and _p62:
				_p62._j68(_g40)
			
			var _d98 = config.get_value("undo_button", "enabled", true)
			if _d98 and _f14:
				_f14._j68(_g40)

func save_explain_button_config(enabled: bool):
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")  
	
	config.set_value("explain_button", "enabled", enabled)
	config.save("user://gdsense_api_key.cfg")
	
	if _d49:
		_d49.set_enabled(enabled)
		
		if enabled:
			_k89.call_deferred()

func save_refactor_config(enabled: bool):
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")  
	
	config.set_value("refactor_button", "enabled", enabled)
	config.save("user://gdsense_api_key.cfg")
	
	if is_instance_valid(_p62):
		_p62.set_enabled(enabled)

func save_undo_config(enabled: bool):
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")  
	
	config.set_value("undo_button", "enabled", enabled)
	config.save("user://gdsense_api_key.cfg")
	
	if is_instance_valid(_f14):
		_f14.set_enabled(enabled)

func _b94(function_name: String, _c25: String):
	if not is_instance_valid(_c66):
		return
	
	if _c66.has_method("send_explain_request"):
		_c66.send_explain_request(function_name, _c25)
	else:
		pass

func _j71(function_name: String, _c25: String, file_path: String):
	if is_instance_valid(_x75):
		_x75.set_meta("file_path", file_path)
		_x75.set_meta("function_source", _c25)
	
	var _f28 = get_editor_interface()
	var current_scene = _f28.get_editor_main_screen() if _f28 else null
	if current_scene and is_instance_valid(_x75):
		if not _x75.is_inside_tree():
			current_scene.add_child(_x75)
		_x75._m14(function_name, _c25)

func _f38(_r44: String, function_name: String, _c25: String, model: String):
	var file_path = ""
	if is_instance_valid(_x75) and _x75.has_meta("file_path"):
		file_path = _x75.get_meta("file_path")

	if is_instance_valid(_d39):
		_d39._s41(function_name, _c25, _r44, file_path, model)

func _h82(refactored_code: String, original_hash: String, function_name: String):
	if is_instance_valid(_x75):
		_x75._y56()
	
	var _f28 = get_editor_interface()
	var current_scene = _f28.get_editor_main_screen() if _f28 else null
	if current_scene and is_instance_valid(_b50):
		if not _b50.is_inside_tree():
			current_scene.add_child(_b50)
		
		var _p46 = ""
		if is_instance_valid(_x75) and _x75.has_meta("function_source"):
			_p46 = _x75.get_meta("function_source")

		if _p46.is_empty():
			_p46 = _j40(function_name)

		if not _p46.is_empty():
			_b50._t9(function_name, _p46, refactored_code)
		else:
			_b50._t9(function_name, "# Original source not available", refactored_code)

func _t69(_u67: int, _q94: String):
	if is_instance_valid(_x75):
		_x75._y56()
	
	push_error("Refactor failed: " + _q94)

func _z80(refactored_code: String, function_name: String):
	var original_code = _j40(function_name)
	var file_path = ""
	var function_line = 0
	
	var _f28 = get_editor_interface()
	if _f28:
		var _f83 = _f28.get_script_editor()
		if _f83:
			var _g40 = _f83.get_current_script()
			if _g40:
				file_path = _g40.resource_path
	
	if is_instance_valid(_p62):
		var _r3 = _p62._z46()
		for _w3 in _r3:
			if _w3.name == function_name:
				function_line = _w3.line
				break
	
	var _y65 = _z48(refactored_code)

	_y65 = _y65.rstrip("\n") + "\n"

	_t82(function_name, _y65)

	if _y97 and not original_code.is_empty():
		var _o78 = _y65.rstrip("\n") + "\n\n"
		_y97._m88(function_name, original_code, _o78, file_path, function_line)
		
		if is_instance_valid(_f14):
			_f14._f95()
		if is_instance_valid(_p62):
			_p62._f95()
		if is_instance_valid(_d49):
			_d49._f95()
		
		_p59()
	
func _n60(function_name: String):
	pass

func _r25(script: Script):
	_k48()

func _k48():
	var _w12: Array[_o9] = []
	for _m39 in _z30:
		if is_instance_valid(_m39):
			_w12.append(_m39)
		else:
			pass

	_z30 = _w12
	
	var _a40: Array[_k92] = []
	for _m39 in _i28:
		if is_instance_valid(_m39):
			_a40.append(_m39)
		else:
			pass

	_i28 = _a40
	
	var _j55: Array[_m21] = []
	for _m39 in _k7:
		if is_instance_valid(_m39):
			_j55.append(_m39)
		else:
			pass

	_k7 = _j55

func _j40(function_name: String) -> String:
	var _f28 = get_editor_interface()
	if not _f28:
		return ""
	
	var _f83 = _f28.get_script_editor()
	if not _f83:
		return ""
	
	var _g40 = _f83.get_current_script()
	if not _g40:
		return ""
	
	if is_instance_valid(_p62):
		var _r3 = _p62._z46()
		for _w3 in _r3:
			if _w3.name == function_name:
				return _p62._q59(_w3)
	
	return ""

func _t82(function_name: String, refactored_code: String):
	var _f28 = get_editor_interface()
	if not _f28:
		return
	
	var _f83 = _f28.get_script_editor()
	if not _f83:
		return
	
	var _c3 = _f83.get_current_editor()
	if not _c3:
		return
	
	var _v78 = _a67(_c3)
	if not _v78:
		return
	
	if is_instance_valid(_p62):
		var _r3 = _p62._z46()
		for _w3 in _r3:
			if _w3.name == function_name:
				var start_line = _w3.line
				var end_line = _w3.get("end_line", start_line)

				var _r40 = refactored_code.rstrip("\n") + "\n\n"

				_h38(_v78, start_line, end_line, _r40)

				return
	
func _a67(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node
	
	for _c100 in node.get_children():
		var _x97 = _a67(_c100)
		if _x97:
			return _x97
	
	return null

func _h38(_v78: CodeEdit, start_line: int, end_line: int, _j94: String):
	_v78.set_caret_line(start_line)
	_v78.set_caret_column(0)
	_v78.select(start_line, 0, end_line + 1, 0)

	var _k50 = _j94
	if not _k50.ends_with("\n"):
		_k50 += "\n"
	_v78.insert_text_at_caret(_k50)

	_v78.deselect()

func _z48(text: String) -> String:
	var _d41 = text.split("\n")
	for i in range(_d41.size()):
		var line = _d41[i]
		var _u12 = 0
		for c in line:
			if c == ' ':
				_u12 += 1
			else:
				break

		var _y99 = _u12 / 4
		if _y99 > 0:
			_d41[i] = "\t".repeat(_y99) + line.substr(_u12)

	return "\n".join(_d41)

func _l9(function_name: String, file_path: String):
	if not _y97 or not _y97._a6(function_name, file_path):
		_p59()
		if is_instance_valid(_v35):
			_v35._c32(function_name)
		return
	
	var _t34 = _y97._j51(function_name, file_path)
	if not _t34:
		_p59()
		if is_instance_valid(_v35):
			_v35._y41(function_name, "No history entry found")
		return
	
	var _i46 = false
	if is_instance_valid(_f14):
		_i46 = not _f14._o22(function_name, file_path)
	
	_j20()
	if is_instance_valid(_m94):
		_m94._m14(_t34, file_path, _i46)

func _d42(function_name: String, original_code: String, file_path: String):
	var refactored_code = ""
	if _y97:
		var _t34 = _y97._j51(function_name, file_path)
		if _t34:
			refactored_code = _t34.refactored_code
	
	var success = _i29(function_name, original_code, refactored_code, file_path)
	
	if success:
		if _y97:
			var _t34 = _y97._j51(function_name, file_path)
			if _t34:
				_y97._c23(function_name, file_path, _t34.timestamp)
		
		if is_instance_valid(_f14):
			_f14._f95()
		if is_instance_valid(_p62):
			_p62._f95()
		if is_instance_valid(_d49):
			_d49._f95()
		
		_p59()
		if is_instance_valid(_v35):
			_v35._z12(function_name)
	else:
		_p59()
		if is_instance_valid(_v35):
			_v35._y41(function_name, "Failed to apply original code")

func _i29(function_name: String, original_code: String, refactored_code: String, file_path: String) -> bool:
	var _f28 = get_editor_interface()
	if not _f28:
		push_error("GDSensePlugin: Could not get editor interface for undo")
		return false
	
	var _f83 = _f28.get_script_editor()
	if not _f83:
		push_error("GDSensePlugin: Could not get script editor for undo")
		return false
	
	var _c3 = _f83.get_current_editor()
	if not _c3:
		push_error("GDSensePlugin: Could not get current editor for undo")
		return false
	
	var _v78 = _a67(_c3)
	if not _v78:
		push_error("GDSensePlugin: Could not find CodeEdit node for undo")
		return false
	
	var text = _v78.text
	var _d41 = text.split("\n")

	var _i45 = RegEx.new()
	_i45.compile("^\\s*func\\s+" + function_name + "\\s*\\(")

	var _o30 = -1
	for i in range(_d41.size()):
		if _i45.search(_d41[i]):
			_o30 = i
			break

	if _o30 == -1:
		push_error("GDSensePlugin: Could not find function to undo: " + function_name)
		return false

	var start_line = _o30
	var _l74 = original_code.strip_edges().begins_with("func ")

	if _l74:
		while start_line > 0:
			var _u3 = _d41[start_line - 1].strip_edges()
			if _u3.begins_with("#"):
				start_line -= 1
			else:
				break

	var end_line = _o7(_d41, _o30)

	var _r40 = original_code.rstrip("\n") + "\n\n"
	_h38(_v78, start_line, end_line, _r40)

	return true

func _o7(_d41: PackedStringArray, start_line: int) -> int:
	if start_line >= _d41.size():
		return start_line
	
	var _y38 = _u6(_d41[start_line])
	
	for i in range(start_line + 1, _d41.size()):
		var line = _d41[i]
		var _c59 = line.strip_edges()
		
		if _c59.is_empty() or _c59.begins_with("#"):
			continue
		
		var _u58 = _u6(line)
		
		if _u58 <= _y38:
			if _c59.begins_with("func ") or _c59.begins_with("class ") or _c59.begins_with("extends") or _c59.begins_with("@"):
				return i - 1
	
	return _d41.size() - 1

func _u6(line: String) -> int:
	var indent = 0
	for _d38 in line:
		if _d38 == '\t':
			indent += 4  
		elif _d38 == ' ':
			indent += 1
		else:
			break
	return indent

func _p59():
	if not is_instance_valid(_v35):
		return
	
	var _f28 = get_editor_interface()
	if not _f28:
		return
	
	var current_scene = _f28.get_editor_main_screen()
	if not current_scene:
		return
	
	if not _v35.is_inside_tree():
		current_scene.add_child(_v35)

func _j20():
	if not is_instance_valid(_m94):
		return
	
	var _f28 = get_editor_interface()
	if not _f28:
		return
	
	var current_scene = _f28.get_editor_main_screen()
	if not current_scene:
		return
	
	if not _m94.is_inside_tree():
		current_scene.add_child(_m94)

func _h78():
	if not is_instance_valid(_m84):
		return
	
	var _f28 = get_editor_interface()
	if not _f28:
		return
	
	var current_scene = _f28.get_editor_main_screen()
	if not current_scene:
		return
	
	if not _m84.is_inside_tree():
		current_scene.add_child(_m84)

func _b74(file_path: String):
	_h78()
	if is_instance_valid(_m84):
		_m84._l46(file_path)

func _g100():
	_h78()
	if is_instance_valid(_m84):
		_m84._q70()

func _m20() -> _b26:
	return _y97

