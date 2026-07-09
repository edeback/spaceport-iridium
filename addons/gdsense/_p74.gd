@tool
extends EditorPlugin
const _c90 = preload("res://addons/gdsense/scripts/_l78.gd")
const _p84 = preload("res://addons/gdsense/scripts/_p17.gd")
const _z68 = preload("res://addons/gdsense/scripts/_l95.gd")
const _k76 = preload("res://addons/gdsense/scripts/_r77.gd")
const _x54 = preload("res://addons/gdsense/scripts/_f19.gd")
const _l3 = preload("res://addons/gdsense/scripts/_e27.gd")
const _r97 = preload("res://addons/gdsense/scenes/_o88.tscn")
const _d85 = preload("res://addons/gdsense/scenes/_t32.tscn")
const _n77 = preload("res://addons/gdsense/scenes/_p15.tscn")
const _c44 = preload("res://addons/gdsense/scenes/_j96.tscn")
const _g1 = preload("res://addons/gdsense/scenes/_n78.tscn")
var _r50: Control
var _l78: _v37
var _r46: _p17
var _l95: _b73
var _q69: Array[_b73] = []
var _r77: _x98
var _o88: _s4
var _t32: _y30
var _z67: Array[_x98] = []
var _f19: _j51
var _e27: _z9
var _p15: _a88
var _p64: _c16
var _n78: _n28
var _l13: Array[_j51] = []
func _enter_tree() -> void:
	_r46 = _p84.new()
	add_child(_r46)
	var _t75: PackedScene = preload("res://addons/gdsense/scenes/_p9.tscn")
	_r50 = _t75.instantiate()
	if _r50.has_method("set_gdsense_manager"):
		_r50.set_gdsense_manager(_r46)
	if _r50.has_method("set_plugin"):
		_r50.set_plugin(self)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _r50)
	_l78 = _c90.new(self, _r46)
	_c79()
	_n39()
	_p36()
	var _k71 = get_editor_interface()
	if _k71:
		var _y11 = _k71.get_script_editor()
		if _y11 and not _y11.editor_script_changed.is_connected(_z1):
			_y11.editor_script_changed.connect(_z1)
	_r41()
	_n27()
	_t9()
	_n92()
	_z22.call_deferred()
func _exit_tree() -> void:
	if is_instance_valid(_r50):
		remove_control_from_docks(_r50)
		_r50.free() 
	if is_instance_valid(_l78):
		_l78._u75()
		_l78 = null
	_d37()
	_x56()
	_u98()
	var _k71 = get_editor_interface()
	if _k71:
		var _y11 = _k71.get_script_editor()
		if _y11 and _y11.editor_script_changed.is_connected(_z1):
			_y11.editor_script_changed.disconnect(_z1)
	if is_instance_valid(_r46):
		_r46.queue_free()
		_r46 = null
func _c79():
	_l95 = _z68.new(self)
	_l95._a26.connect(_i41)
	_q69.append(_l95)
func _n39():
	_r77 = _k76.new(self)
	_r77._k47.connect(_k60)
	_z67.append(_r77)
	_o88 = _r97.instantiate()
	_o88._e86.connect(_g22)
	if is_instance_valid(_r46):
		_o88.set_gdsense_manager(_r46)
	_t32 = _d85.instantiate()
	_t32._e61.connect(_o87)
	_t32._g76.connect(_p98)
	if is_instance_valid(_r46):
		_r46._d24.connect(_r54)
		_r46._i36.connect(_z62)
func _d37():
	for _x22 in _q69:
		if is_instance_valid(_x22):
			_x22._u75()
	_q69.clear()
	_l95 = null
func _x56():
	for _x22 in _z67:
		if is_instance_valid(_x22):
			_x22._u75()
	_z67.clear()
	_r77 = null
	if is_instance_valid(_o88):
		_o88.queue_free()
		_o88 = null
	if is_instance_valid(_t32):
		_t32.queue_free()
		_t32 = null
func _p36():
	_e27 = _l3.new()
	_f19 = _x54.new(self, _e27)
	_f19._i8.connect(_h67)
	_l13.append(_f19)
	_p15 = _n77.instantiate()
	_p15._r95(get_editor_interface())
	_p15._u90.connect(_c66)
	_p64 = _c44.instantiate()
	_p64._f92(_e27)
	_n78 = _g1.instantiate()
func _u98():
	for _x22 in _l13:
		if is_instance_valid(_x22):
			_x22._u75()
	_l13.clear()
	_f19 = null
	if is_instance_valid(_p15):
		_p15.queue_free()
		_p15 = null
	if is_instance_valid(_p64):
		_p64.queue_free()
		_p64 = null
	if is_instance_valid(_n78):
		_n78.queue_free()
		_n78 = null
	if _e27:
		_e27._c91()
		_e27 = null
func _r41():
	const _j58 = 1000
	const _v18 = 150
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		_l78._h63 = config.get_value("autocomplete", "enabled", true)
		_l78._u45 = _j58  
		_l78._g35 = _v18  
		_l78._p4 = config.get_value("autocomplete", "mode", "automatic")
		_l78._m3 = config.get_value("autocomplete", "min_chars", 3)
	else:
		_l78._h63 = true
		_l78._u45 = _j58
		_l78._g35 = _v18
		_l78._p4 = "automatic"
		_l78._m3 = 3
func save_autocomplete_config(enabled: bool, _x38: int, max_length: int, mode: String = "", _e15: int = 3):
	const _j58 = 1000
	const _v18 = 150
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")  
	config.set_value("autocomplete", "enabled", enabled)
	config.set_value("autocomplete", "delay_ms", _j58)  
	config.set_value("autocomplete", "max_length", _v18)  
	if mode != "":
		config.set_value("autocomplete", "mode", mode)
	config.set_value("autocomplete", "min_chars", _e15)
	config.save("user://gdsense_api_key.cfg")
	if is_instance_valid(_l78):
		_l78.set_enabled(enabled)
		_l78.set_delay(_j58)  
		_l78._g35 = _v18  
		if mode != "":
			_l78.set_mode(mode)
		_l78._m3 = _e15
func _n27():
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var enabled = config.get_value("explain_button", "enabled", true)
		if _l95:
			_l95.set_enabled(enabled)
	else:
		if _l95:
			_l95.set_enabled(true)
func _t9():
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var enabled = config.get_value("refactor_button", "enabled", true)
		if is_instance_valid(_r77):
			_r77.set_enabled(enabled)
	else:
		if is_instance_valid(_r77):
			_r77.set_enabled(true)
func _n92():
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var enabled = config.get_value("undo_button", "enabled", true)
		if is_instance_valid(_f19):
			_f19.set_enabled(enabled)
	else:
		if is_instance_valid(_f19):
			_f19.set_enabled(true)
func _z22():
	var _k71 = get_editor_interface()
	if not _k71:
		return
	var _y11 = _k71.get_script_editor()
	if not _y11:
		return
	var _y36 = _y11.get_current_script()
	if _y36:
		var config = ConfigFile.new()
		if config.load("user://gdsense_api_key.cfg") == OK:
			var _f12 = config.get_value("explain_button", "enabled", true)
			if _f12 and _l95:
				_l95._u5(_y36)
			var _c52 = config.get_value("refactor_button", "enabled", true)
			if _c52 and _r77:
				_r77._u5(_y36)
			var _w54 = config.get_value("undo_button", "enabled", true)
			if _w54 and _f19:
				_f19._u5(_y36)
func save_explain_button_config(enabled: bool):
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")  
	config.set_value("explain_button", "enabled", enabled)
	config.save("user://gdsense_api_key.cfg")
	if _l95:
		_l95.set_enabled(enabled)
		if enabled:
			_z22.call_deferred()
func save_refactor_config(enabled: bool):
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")  
	config.set_value("refactor_button", "enabled", enabled)
	config.save("user://gdsense_api_key.cfg")
	if is_instance_valid(_r77):
		_r77.set_enabled(enabled)
func save_undo_config(enabled: bool):
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")  
	config.set_value("undo_button", "enabled", enabled)
	config.save("user://gdsense_api_key.cfg")
	if is_instance_valid(_f19):
		_f19.set_enabled(enabled)
func _i41(function_name: String, _k94: String):
	if not is_instance_valid(_r50):
		return
	if _r50.has_method("send_explain_request"):
		_r50.send_explain_request(function_name, _k94)
	else:
		pass
func _k60(function_name: String, _k94: String, file_path: String):
	if is_instance_valid(_o88):
		_o88.set_meta("file_path", file_path)
		_o88.set_meta("function_source", _k94)
	var _k71 = get_editor_interface()
	var current_scene = _k71.get_editor_main_screen() if _k71 else null
	if current_scene and is_instance_valid(_o88):
		if not _o88.is_inside_tree():
			current_scene.add_child(_o88)
		_o88._o33(function_name, _k94)
func _g22(_r2: String, function_name: String, _k94: String, model: String):
	var file_path = ""
	if is_instance_valid(_o88) and _o88.has_meta("file_path"):
		file_path = _o88.get_meta("file_path")
	if is_instance_valid(_r46):
		_r46._d4(function_name, _k94, _r2, file_path, model)
func _r54(refactored_code: String, original_hash: String, function_name: String):
	if is_instance_valid(_o88):
		_o88._b94()
	var _k71 = get_editor_interface()
	var current_scene = _k71.get_editor_main_screen() if _k71 else null
	if current_scene and is_instance_valid(_t32):
		if not _t32.is_inside_tree():
			current_scene.add_child(_t32)
		var _m63 = ""
		if is_instance_valid(_o88) and _o88.has_meta("function_source"):
			_m63 = _o88.get_meta("function_source")
		if _m63.is_empty():
			_m63 = _w28(function_name)
		if not _m63.is_empty():
			_t32._f77(function_name, _m63, refactored_code)
		else:
			_t32._f77(function_name, "# Original source not available", refactored_code)
func _z62(_j100: int, _m16: String):
	if is_instance_valid(_o88):
		_o88._b94()
	push_error("Refactor failed: " + _m16)
func _o87(refactored_code: String, function_name: String):
	var original_code = _w28(function_name)
	var file_path = ""
	var function_line = 0
	var _k71 = get_editor_interface()
	if _k71:
		var _y11 = _k71.get_script_editor()
		if _y11:
			var _y36 = _y11.get_current_script()
			if _y36:
				file_path = _y36.resource_path
	if is_instance_valid(_r77):
		var _k100 = _r77._a93()
		for _e92 in _k100:
			if _e92.name == function_name:
				function_line = _e92.line
				break
	var _h60 = _n55(refactored_code)
	_h60 = _h60.rstrip("\n") + "\n"
	_x61(function_name, _h60)
	if _e27 and not original_code.is_empty():
		var _s94 = _h60.rstrip("\n") + "\n\n"
		_e27._o76(function_name, original_code, _s94, file_path, function_line)
		if is_instance_valid(_f19):
			_f19._e55()
		if is_instance_valid(_r77):
			_r77._e55()
		if is_instance_valid(_l95):
			_l95._e55()
		_s43()
func _p98(function_name: String):
	pass
func _z1(script: Script):
	_i50()
func _i50():
	var _a36: Array[_b73] = []
	for _x22 in _q69:
		if is_instance_valid(_x22):
			_a36.append(_x22)
		else:
			pass
	_q69 = _a36
	var _b22: Array[_x98] = []
	for _x22 in _z67:
		if is_instance_valid(_x22):
			_b22.append(_x22)
		else:
			pass
	_z67 = _b22
	var _m23: Array[_j51] = []
	for _x22 in _l13:
		if is_instance_valid(_x22):
			_m23.append(_x22)
		else:
			pass
	_l13 = _m23
func _w28(function_name: String) -> String:
	var _k71 = get_editor_interface()
	if not _k71:
		return ""
	var _y11 = _k71.get_script_editor()
	if not _y11:
		return ""
	var _y36 = _y11.get_current_script()
	if not _y36:
		return ""
	if is_instance_valid(_r77):
		var _k100 = _r77._a93()
		for _e92 in _k100:
			if _e92.name == function_name:
				return _r77._m11(_e92)
	return ""
func _x61(function_name: String, refactored_code: String):
	var _k71 = get_editor_interface()
	if not _k71:
		return
	var _y11 = _k71.get_script_editor()
	if not _y11:
		return
	var _d32 = _y11.get_current_editor()
	if not _d32:
		return
	var _j81 = _v35(_d32)
	if not _j81:
		return
	if is_instance_valid(_r77):
		var _k100 = _r77._a93()
		for _e92 in _k100:
			if _e92.name == function_name:
				var start_line = _e92.line
				var end_line = _e92.get("end_line", start_line)
				var _m30 = refactored_code.rstrip("\n") + "\n\n"
				_i11(_j81, start_line, end_line, _m30)
				return
func _v35(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node
	for _x15 in node.get_children():
		var _e21 = _v35(_x15)
		if _e21:
			return _e21
	return null
func _i11(_j81: CodeEdit, start_line: int, end_line: int, _r96: String):
	_j81.set_caret_line(start_line)
	_j81.set_caret_column(0)
	_j81.select(start_line, 0, end_line + 1, 0)
	var _p100 = _r96
	if not _p100.ends_with("\n"):
		_p100 += "\n"
	_j81.insert_text_at_caret(_p100)
	_j81.deselect()
func _n55(text: String) -> String:
	var _p91 = text.split("\n")
	for i in range(_p91.size()):
		var line = _p91[i]
		var _z10 = 0
		for c in line:
			if c == ' ':
				_z10 += 1
			else:
				break
		var _j2 = _z10 / 4
		if _j2 > 0:
			_p91[i] = "\t".repeat(_j2) + line.substr(_z10)
	return "\n".join(_p91)
func _h67(function_name: String, file_path: String):
	if not _e27 or not _e27._c19(function_name, file_path):
		_s43()
		if is_instance_valid(_n78):
			_n78._g45(function_name)
		return
	var _u27 = _e27._m18(function_name, file_path)
	if not _u27:
		_s43()
		if is_instance_valid(_n78):
			_n78._h6(function_name, "No history entry found")
		return
	var _p18 = false
	if is_instance_valid(_f19):
		_p18 = not _f19._u21(function_name, file_path)
	_g71()
	if is_instance_valid(_p15):
		_p15._o33(_u27, file_path, _p18)
func _c66(function_name: String, original_code: String, file_path: String):
	var refactored_code = ""
	if _e27:
		var _u27 = _e27._m18(function_name, file_path)
		if _u27:
			refactored_code = _u27.refactored_code
	var success = _f80(function_name, original_code, refactored_code, file_path)
	if success:
		if _e27:
			var _u27 = _e27._m18(function_name, file_path)
			if _u27:
				_e27._l89(function_name, file_path, _u27.timestamp)
		if is_instance_valid(_f19):
			_f19._e55()
		if is_instance_valid(_r77):
			_r77._e55()
		if is_instance_valid(_l95):
			_l95._e55()
		_s43()
		if is_instance_valid(_n78):
			_n78._i39(function_name)
	else:
		_s43()
		if is_instance_valid(_n78):
			_n78._h6(function_name, "Failed to apply original code")
func _f80(function_name: String, original_code: String, refactored_code: String, file_path: String) -> bool:
	var _k71 = get_editor_interface()
	if not _k71:
		push_error("GDSensePlugin: Could not get editor interface for undo")
		return false
	var _y11 = _k71.get_script_editor()
	if not _y11:
		push_error("GDSensePlugin: Could not get script editor for undo")
		return false
	var _d32 = _y11.get_current_editor()
	if not _d32:
		push_error("GDSensePlugin: Could not get current editor for undo")
		return false
	var _j81 = _v35(_d32)
	if not _j81:
		push_error("GDSensePlugin: Could not find CodeEdit node for undo")
		return false
	var text = _j81.text
	var _p91 = text.split("\n")
	var _j39 = RegEx.new()
	_j39.compile("^\\s*func\\s+" + function_name + "\\s*\\(")
	var _m68 = -1
	for i in range(_p91.size()):
		if _j39.search(_p91[i]):
			_m68 = i
			break
	if _m68 == -1:
		push_error("GDSensePlugin: Could not find function to undo: " + function_name)
		return false
	var start_line = _m68
	var _v49 = original_code.strip_edges().begins_with("func ")
	if _v49:
		while start_line > 0:
			var _d84 = _p91[start_line - 1].strip_edges()
			if _d84.begins_with("#"):
				start_line -= 1
			else:
				break
	var end_line = _x36(_p91, _m68)
	var _m30 = original_code.rstrip("\n") + "\n\n"
	_i11(_j81, start_line, end_line, _m30)
	return true
func _x36(_p91: PackedStringArray, start_line: int) -> int:
	if start_line >= _p91.size():
		return start_line
	var _u53 = _f79(_p91[start_line])
	for i in range(start_line + 1, _p91.size()):
		var line = _p91[i]
		var _w61 = line.strip_edges()
		if _w61.is_empty() or _w61.begins_with("#"):
			continue
		var _w5 = _f79(line)
		if _w5 <= _u53:
			if _w61.begins_with("func ") or _w61.begins_with("class ") or _w61.begins_with("extends") or _w61.begins_with("@"):
				return i - 1
	return _p91.size() - 1
func _f79(line: String) -> int:
	var indent = 0
	for char in line:
		if char == '\t':
			indent += 4  
		elif char == ' ':
			indent += 1
		else:
			break
	return indent
func _s43():
	if not is_instance_valid(_n78):
		return
	var _k71 = get_editor_interface()
	if not _k71:
		return
	var current_scene = _k71.get_editor_main_screen()
	if not current_scene:
		return
	if not _n78.is_inside_tree():
		current_scene.add_child(_n78)
func _g71():
	if not is_instance_valid(_p15):
		return
	var _k71 = get_editor_interface()
	if not _k71:
		return
	var current_scene = _k71.get_editor_main_screen()
	if not current_scene:
		return
	if not _p15.is_inside_tree():
		current_scene.add_child(_p15)
func _h95():
	if not is_instance_valid(_p64):
		return
	var _k71 = get_editor_interface()
	if not _k71:
		return
	var current_scene = _k71.get_editor_main_screen()
	if not current_scene:
		return
	if not _p64.is_inside_tree():
		current_scene.add_child(_p64)
func _r64(file_path: String):
	_h95()
	if is_instance_valid(_p64):
		_p64._k82(file_path)
func _k16():
	_h95()
	if is_instance_valid(_p64):
		_p64._q25()
func _k97() -> _z9:
	return _e27
