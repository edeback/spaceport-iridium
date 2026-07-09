@tool
extends EditorPlugin
const _l36 = preload("res://addons/gdsense/scripts/_v61.gd")
const _n49 = preload("res://addons/gdsense/scripts/_y57.gd")
const _n56 = preload("res://addons/gdsense/scripts/_y40.gd")
const _j84 = preload("res://addons/gdsense/scripts/_z57.gd")
const _r16 = preload("res://addons/gdsense/scripts/_l22.gd")
const _a63 = preload("res://addons/gdsense/scripts/_g72.gd")
const _p90 = preload("res://addons/gdsense/scenes/_p20.tscn")
const _d72 = preload("res://addons/gdsense/scenes/_v38.tscn")
const _m35 = preload("res://addons/gdsense/scenes/_u1.tscn")
const _n47 = preload("res://addons/gdsense/scenes/_m55.tscn")
const _n64 = preload("res://addons/gdsense/scenes/_y46.tscn")
var _p1: Control
var _v61: _h26
var _f78: _y57
var _y40: _q64
var _n14: Array[_q64] = []
var _z57: _z54
var _p20: _y96
var _v38: _s12
var _p92: Array[_z54] = []
var _l22: _d86
var _g72: _n17
var _u1: _l45
var _i93: _c59
var _y46: _l84
var _w17: Array[_d86] = []
func _enter_tree() -> void:
	_f78 = _n49.new()
	add_child(_f78)
	var _u91: PackedScene = preload("res://addons/gdsense/scenes/_t65.tscn")
	_p1 = _u91.instantiate()
	if _p1.has_method("set_gdsense_manager"):
		_p1.set_gdsense_manager(_f78)
	if _p1.has_method("set_plugin"):
		_p1.set_plugin(self)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _p1)
	_v61 = _l36.new(self, _f78)
	_v86()
	_u55()
	_l90()
	var _d84 = get_editor_interface()
	if _d84:
		var _w31 = _d84.get_script_editor()
		if _w31 and not _w31.editor_script_changed.is_connected(_g14):
			_w31.editor_script_changed.connect(_g14)
	_w52()
	_l10()
	_e89()
	_l67()
	_f10.call_deferred()
func _exit_tree() -> void:
	if is_instance_valid(_p1):
		remove_control_from_docks(_p1)
		_p1.free() 
	if is_instance_valid(_v61):
		_v61._q60()
		_v61 = null
	_q92()
	_y3()
	_r85()
	var _d84 = get_editor_interface()
	if _d84:
		var _w31 = _d84.get_script_editor()
		if _w31 and _w31.editor_script_changed.is_connected(_g14):
			_w31.editor_script_changed.disconnect(_g14)
	if is_instance_valid(_f78):
		_f78.queue_free()
		_f78 = null
func _v86():
	_y40 = _n56.new(self)
	_y40._i32.connect(_u57)
	_n14.append(_y40)
func _u55():
	_z57 = _j84.new(self)
	_z57._s39.connect(_y62)
	_p92.append(_z57)
	_p20 = _p90.instantiate()
	_p20._u37.connect(_b64)
	if is_instance_valid(_f78):
		_p20.set_gdsense_manager(_f78)
	_v38 = _d72.instantiate()
	_v38._t38.connect(_s89)
	_v38._l59.connect(_b7)
	if is_instance_valid(_f78):
		_f78._u38.connect(_c13)
		_f78._l24.connect(_c29)
func _q92():
	for _v6 in _n14:
		if is_instance_valid(_v6):
			_v6._q60()
	_n14.clear()
	_y40 = null
func _y3():
	for _v6 in _p92:
		if is_instance_valid(_v6):
			_v6._q60()
	_p92.clear()
	_z57 = null
	if is_instance_valid(_p20):
		_p20.queue_free()
		_p20 = null
	if is_instance_valid(_v38):
		_v38.queue_free()
		_v38 = null
func _l90():
	_g72 = _a63.new()
	_l22 = _r16.new(self, _g72)
	_l22._b22.connect(_i11)
	_w17.append(_l22)
	_u1 = _m35.instantiate()
	_u1._i71(get_editor_interface())
	_u1._w67.connect(_i4)
	_i93 = _n47.instantiate()
	_i93._s5(_g72)
	_y46 = _n64.instantiate()
func _r85():
	for _v6 in _w17:
		if is_instance_valid(_v6):
			_v6._q60()
	_w17.clear()
	_l22 = null
	if is_instance_valid(_u1):
		_u1.queue_free()
		_u1 = null
	if is_instance_valid(_i93):
		_i93.queue_free()
		_i93 = null
	if is_instance_valid(_y46):
		_y46.queue_free()
		_y46 = null
	if _g72:
		_g72._x77()
		_g72 = null
func _w52():
	const _j28 = 1000
	const _t23 = 150
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		_v61._q100 = config.get_value("autocomplete", "enabled", true)
		_v61._f44 = _j28  
		_v61._d81 = _t23  
		_v61._w2 = config.get_value("autocomplete", "mode", "automatic")
		_v61._e22 = config.get_value("autocomplete", "min_chars", 3)
	else:
		_v61._q100 = true
		_v61._f44 = _j28
		_v61._d81 = _t23
		_v61._w2 = "automatic"
		_v61._e22 = 3
func save_autocomplete_config(enabled: bool, _z1: int, max_length: int, mode: String = "", _z85: int = 3):
	const _j28 = 1000
	const _t23 = 150
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")  
	config.set_value("autocomplete", "enabled", enabled)
	config.set_value("autocomplete", "delay_ms", _j28)  
	config.set_value("autocomplete", "max_length", _t23)  
	if mode != "":
		config.set_value("autocomplete", "mode", mode)
	config.set_value("autocomplete", "min_chars", _z85)
	config.save("user://gdsense_api_key.cfg")
	if is_instance_valid(_v61):
		_v61.set_enabled(enabled)
		_v61.set_delay(_j28)  
		_v61._d81 = _t23  
		if mode != "":
			_v61.set_mode(mode)
		_v61._e22 = _z85
func _l10():
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var enabled = config.get_value("explain_button", "enabled", true)
		if _y40:
			_y40.set_enabled(enabled)
	else:
		if _y40:
			_y40.set_enabled(true)
func _e89():
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var enabled = config.get_value("refactor_button", "enabled", true)
		if is_instance_valid(_z57):
			_z57.set_enabled(enabled)
	else:
		if is_instance_valid(_z57):
			_z57.set_enabled(true)
func _l67():
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var enabled = config.get_value("undo_button", "enabled", true)
		if is_instance_valid(_l22):
			_l22.set_enabled(enabled)
	else:
		if is_instance_valid(_l22):
			_l22.set_enabled(true)
func _f10():
	var _d84 = get_editor_interface()
	if not _d84:
		return
	var _w31 = _d84.get_script_editor()
	if not _w31:
		return
	var _d90 = _w31.get_current_script()
	if _d90:
		var config = ConfigFile.new()
		if config.load("user://gdsense_api_key.cfg") == OK:
			var _l56 = config.get_value("explain_button", "enabled", true)
			if _l56 and _y40:
				_y40._c28(_d90)
			var _m94 = config.get_value("refactor_button", "enabled", true)
			if _m94 and _z57:
				_z57._c28(_d90)
			var _a22 = config.get_value("undo_button", "enabled", true)
			if _a22 and _l22:
				_l22._c28(_d90)
func save_explain_button_config(enabled: bool):
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")  
	config.set_value("explain_button", "enabled", enabled)
	config.save("user://gdsense_api_key.cfg")
	if _y40:
		_y40.set_enabled(enabled)
		if enabled:
			_f10.call_deferred()
func save_refactor_config(enabled: bool):
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")  
	config.set_value("refactor_button", "enabled", enabled)
	config.save("user://gdsense_api_key.cfg")
	if is_instance_valid(_z57):
		_z57.set_enabled(enabled)
func save_undo_config(enabled: bool):
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")  
	config.set_value("undo_button", "enabled", enabled)
	config.save("user://gdsense_api_key.cfg")
	if is_instance_valid(_l22):
		_l22.set_enabled(enabled)
func _u57(function_name: String, _w13: String):
	if not is_instance_valid(_p1):
		return
	if _p1.has_method("send_explain_request"):
		_p1.send_explain_request(function_name, _w13)
	else:
		pass
func _y62(function_name: String, _w13: String, file_path: String):
	if is_instance_valid(_p20):
		_p20.set_meta("file_path", file_path)
		_p20.set_meta("function_source", _w13)
	var _d84 = get_editor_interface()
	var current_scene = _d84.get_editor_main_screen() if _d84 else null
	if current_scene and is_instance_valid(_p20):
		if not _p20.is_inside_tree():
			current_scene.add_child(_p20)
		_p20._s56(function_name, _w13)
func _b64(_o38: String, function_name: String, _w13: String, model: String):
	var file_path = ""
	if is_instance_valid(_p20) and _p20.has_meta("file_path"):
		file_path = _p20.get_meta("file_path")
	if is_instance_valid(_f78):
		_f78._o8(function_name, _w13, _o38, file_path, model)
func _c13(refactored_code: String, original_hash: String, function_name: String):
	if is_instance_valid(_p20):
		_p20._f91()
	var _d84 = get_editor_interface()
	var current_scene = _d84.get_editor_main_screen() if _d84 else null
	if current_scene and is_instance_valid(_v38):
		if not _v38.is_inside_tree():
			current_scene.add_child(_v38)
		var _h12 = ""
		if is_instance_valid(_p20) and _p20.has_meta("function_source"):
			_h12 = _p20.get_meta("function_source")
		if _h12.is_empty():
			_h12 = _t95(function_name)
		if not _h12.is_empty():
			_v38._t59(function_name, _h12, refactored_code)
		else:
			_v38._t59(function_name, "# Original source not available", refactored_code)
func _c29(_g51: int, _u85: String):
	if is_instance_valid(_p20):
		_p20._f91()
	push_error("Refactor failed: " + _u85)
func _s89(refactored_code: String, function_name: String):
	var original_code = _t95(function_name)
	var file_path = ""
	var function_line = 0
	var _d84 = get_editor_interface()
	if _d84:
		var _w31 = _d84.get_script_editor()
		if _w31:
			var _d90 = _w31.get_current_script()
			if _d90:
				file_path = _d90.resource_path
	if is_instance_valid(_z57):
		var _z61 = _z57._f69()
		for _l98 in _z61:
			if _l98.name == function_name:
				function_line = _l98.line
				break
	var _r36 = _k53(refactored_code)
	_r36 = _r36.rstrip("\n") + "\n"
	_n63(function_name, _r36)
	if _g72 and not original_code.is_empty():
		var _a68 = _r36.rstrip("\n") + "\n\n"
		_g72._z70(function_name, original_code, _a68, file_path, function_line)
		if is_instance_valid(_l22):
			_l22._w86()
		if is_instance_valid(_z57):
			_z57._w86()
		if is_instance_valid(_y40):
			_y40._w86()
		_i47()
func _b7(function_name: String):
	pass
func _g14(script: Script):
	_c36()
func _c36():
	var _q84: Array[_q64] = []
	for _v6 in _n14:
		if is_instance_valid(_v6):
			_q84.append(_v6)
		else:
			pass
	_n14 = _q84
	var _z65: Array[_z54] = []
	for _v6 in _p92:
		if is_instance_valid(_v6):
			_z65.append(_v6)
		else:
			pass
	_p92 = _z65
	var _o91: Array[_d86] = []
	for _v6 in _w17:
		if is_instance_valid(_v6):
			_o91.append(_v6)
		else:
			pass
	_w17 = _o91
func _t95(function_name: String) -> String:
	var _d84 = get_editor_interface()
	if not _d84:
		return ""
	var _w31 = _d84.get_script_editor()
	if not _w31:
		return ""
	var _d90 = _w31.get_current_script()
	if not _d90:
		return ""
	if is_instance_valid(_z57):
		var _z61 = _z57._f69()
		for _l98 in _z61:
			if _l98.name == function_name:
				return _z57._y91(_l98)
	return ""
func _n63(function_name: String, refactored_code: String):
	var _d84 = get_editor_interface()
	if not _d84:
		return
	var _w31 = _d84.get_script_editor()
	if not _w31:
		return
	var _p95 = _w31.get_current_editor()
	if not _p95:
		return
	var _x7 = _k97(_p95)
	if not _x7:
		return
	if is_instance_valid(_z57):
		var _z61 = _z57._f69()
		for _l98 in _z61:
			if _l98.name == function_name:
				var start_line = _l98.line
				var end_line = _l98.get("end_line", start_line)
				var _y67 = refactored_code.rstrip("\n") + "\n\n"
				_t53(_x7, start_line, end_line, _y67)
				return
func _k97(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node
	for _h61 in node.get_children():
		var _x97 = _k97(_h61)
		if _x97:
			return _x97
	return null
func _t53(_x7: CodeEdit, start_line: int, end_line: int, _v29: String):
	_x7.set_caret_line(start_line)
	_x7.set_caret_column(0)
	_x7.select(start_line, 0, end_line + 1, 0)
	var _p49 = _v29
	if not _p49.ends_with("\n"):
		_p49 += "\n"
	_x7.insert_text_at_caret(_p49)
	_x7.deselect()
func _k53(text: String) -> String:
	var _j90 = text.split("\n")
	for i in range(_j90.size()):
		var line = _j90[i]
		var _a94 = 0
		for c in line:
			if c == ' ':
				_a94 += 1
			else:
				break
		var _h91 = _a94 / 4
		if _h91 > 0:
			_j90[i] = "\t".repeat(_h91) + line.substr(_a94)
	return "\n".join(_j90)
func _i11(function_name: String, file_path: String):
	if not _g72 or not _g72._a64(function_name, file_path):
		_i47()
		if is_instance_valid(_y46):
			_y46._g47(function_name)
		return
	var _q26 = _g72._h84(function_name, file_path)
	if not _q26:
		_i47()
		if is_instance_valid(_y46):
			_y46._h95(function_name, "No history entry found")
		return
	var _q73 = false
	if is_instance_valid(_l22):
		_q73 = not _l22._l49(function_name, file_path)
	_m20()
	if is_instance_valid(_u1):
		_u1._s56(_q26, file_path, _q73)
func _i4(function_name: String, original_code: String, file_path: String):
	var refactored_code = ""
	if _g72:
		var _q26 = _g72._h84(function_name, file_path)
		if _q26:
			refactored_code = _q26.refactored_code
	var success = _n29(function_name, original_code, refactored_code, file_path)
	if success:
		if _g72:
			var _q26 = _g72._h84(function_name, file_path)
			if _q26:
				_g72._p4(function_name, file_path, _q26.timestamp)
		if is_instance_valid(_l22):
			_l22._w86()
		if is_instance_valid(_z57):
			_z57._w86()
		if is_instance_valid(_y40):
			_y40._w86()
		_i47()
		if is_instance_valid(_y46):
			_y46._g73(function_name)
	else:
		_i47()
		if is_instance_valid(_y46):
			_y46._h95(function_name, "Failed to apply original code")
func _n29(function_name: String, original_code: String, refactored_code: String, file_path: String) -> bool:
	var _d84 = get_editor_interface()
	if not _d84:
		push_error("GDSensePlugin: Could not get editor interface for undo")
		return false
	var _w31 = _d84.get_script_editor()
	if not _w31:
		push_error("GDSensePlugin: Could not get script editor for undo")
		return false
	var _p95 = _w31.get_current_editor()
	if not _p95:
		push_error("GDSensePlugin: Could not get current editor for undo")
		return false
	var _x7 = _k97(_p95)
	if not _x7:
		push_error("GDSensePlugin: Could not find CodeEdit node for undo")
		return false
	var text = _x7.text
	var _j90 = text.split("\n")
	var _s22 = RegEx.new()
	_s22.compile("^\\s*func\\s+" + function_name + "\\s*\\(")
	var _z4 = -1
	for i in range(_j90.size()):
		if _s22.search(_j90[i]):
			_z4 = i
			break
	if _z4 == -1:
		push_error("GDSensePlugin: Could not find function to undo: " + function_name)
		return false
	var start_line = _z4
	var _i100 = original_code.strip_edges().begins_with("func ")
	if _i100:
		while start_line > 0:
			var _d61 = _j90[start_line - 1].strip_edges()
			if _d61.begins_with("#"):
				start_line -= 1
			else:
				break
	var end_line = _k82(_j90, _z4)
	var _y67 = original_code.rstrip("\n") + "\n\n"
	_t53(_x7, start_line, end_line, _y67)
	return true
func _k82(_j90: PackedStringArray, start_line: int) -> int:
	if start_line >= _j90.size():
		return start_line
	var _f52 = _l6(_j90[start_line])
	for i in range(start_line + 1, _j90.size()):
		var line = _j90[i]
		var _o74 = line.strip_edges()
		if _o74.is_empty() or _o74.begins_with("#"):
			continue
		var _m64 = _l6(line)
		if _m64 <= _f52:
			if _o74.begins_with("func ") or _o74.begins_with("class ") or _o74.begins_with("extends") or _o74.begins_with("@"):
				return i - 1
	return _j90.size() - 1
func _l6(line: String) -> int:
	var indent = 0
	for _o41 in line:
		if _o41 == '\t':
			indent += 4  
		elif _o41 == ' ':
			indent += 1
		else:
			break
	return indent
func _i47():
	if not is_instance_valid(_y46):
		return
	var _d84 = get_editor_interface()
	if not _d84:
		return
	var current_scene = _d84.get_editor_main_screen()
	if not current_scene:
		return
	if not _y46.is_inside_tree():
		current_scene.add_child(_y46)
func _m20():
	if not is_instance_valid(_u1):
		return
	var _d84 = get_editor_interface()
	if not _d84:
		return
	var current_scene = _d84.get_editor_main_screen()
	if not current_scene:
		return
	if not _u1.is_inside_tree():
		current_scene.add_child(_u1)
func _o46():
	if not is_instance_valid(_i93):
		return
	var _d84 = get_editor_interface()
	if not _d84:
		return
	var current_scene = _d84.get_editor_main_screen()
	if not current_scene:
		return
	if not _i93.is_inside_tree():
		current_scene.add_child(_i93)
func _t74(file_path: String):
	_o46()
	if is_instance_valid(_i93):
		_i93._u76(file_path)
func _o29():
	_o46()
	if is_instance_valid(_i93):
		_i93._d55()
func _m75() -> _n17:
	return _g72
