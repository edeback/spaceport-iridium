@tool
extends EditorPlugin

const _a96 = preload("res://addons/gdsense/scripts/_u42.gd")
const _o64 = preload("res://addons/gdsense/scripts/_w70.gd")
const _i2 = preload("res://addons/gdsense/scripts/_d66.gd")
const _g85 = preload("res://addons/gdsense/scripts/_a75.gd")
const _g16 = preload("res://addons/gdsense/scripts/_t37.gd")
const _m78 = preload("res://addons/gdsense/scripts/_y28.gd")
const _f74 = preload("res://addons/gdsense/scenes/_k14.tscn")
const _l22 = preload("res://addons/gdsense/scenes/_e89.tscn")
const _r6 = preload("res://addons/gdsense/scenes/_b97.tscn")
const _q23 = preload("res://addons/gdsense/scenes/_a59.tscn")
const _k5 = preload("res://addons/gdsense/scenes/_q55.tscn")

var _f86: Control
var _u42: _b38
var _a8: _w70

var _d66: _y29
var _l56: Array[_y29] = []

var _a75: _w85
var _k14: _m59
var _e89: _h4
var _a90: Array[_w85] = []

var _t37: _k44
var _y28: _w99
var _b97: _t34
var _m24: _j61
var _q55: _e46
var _w28: Array[_k44] = []

func _enter_tree() -> void:
	_a8 = _o64.new()
	add_child(_a8)
	
	var _t70: PackedScene = preload("res://addons/gdsense/scenes/_h33.tscn")
	_f86 = _t70.instantiate()
	
	if _f86.has_method("set_gdsense_manager"):
		_f86.set_gdsense_manager(_a8)
	
	if _f86.has_method("set_plugin"):
		_f86.set_plugin(self)
	
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _f86)
	
	_u42 = _a96.new(self, _a8)
	
	_o21()
	
	_e59()
	
	_j13()
	
	var _t15 = get_editor_interface()
	if _t15:
		var _c37 = _t15.get_script_editor()
		if _c37 and not _c37.editor_script_changed.is_connected(_s71):
			_c37.editor_script_changed.connect(_s71)
	
	_u43()
	_s85()
	_s46()
	_i97()
	
	_r49.call_deferred()

func _exit_tree() -> void:
	if is_instance_valid(_f86):
		remove_control_from_docks(_f86)
		_f86.free() 
	
	if is_instance_valid(_u42):
		_u42._k63()
		_u42 = null
	
	_u17()
	
	_x94()
	
	_z98()
	
	var _t15 = get_editor_interface()
	if _t15:
		var _c37 = _t15.get_script_editor()
		if _c37 and _c37.editor_script_changed.is_connected(_s71):
			_c37.editor_script_changed.disconnect(_s71)
	
	if is_instance_valid(_a8):
		_a8.queue_free()
		_a8 = null

func _o21():
	_d66 = _i2.new(self)
	_d66._j63.connect(_w80)
	_l56.append(_d66)

func _e59():
	_a75 = _g85.new(self)
	_a75._x10.connect(_u99)
	_a90.append(_a75)
	
	_k14 = _f74.instantiate()
	_k14._g26.connect(_w56)

	if is_instance_valid(_a8):
		_k14.set_gdsense_manager(_a8)

	_e89 = _l22.instantiate()
	_e89._j43.connect(_j33)
	_e89._w13.connect(_w16)
	
	if is_instance_valid(_a8):
		_a8._o98.connect(_o80)
		_a8._i53.connect(_w11)

func _u17():
	for _t26 in _l56:
		if is_instance_valid(_t26):
			_t26._k63()
	_l56.clear()
	_d66 = null

func _x94():
	for _t26 in _a90:
		if is_instance_valid(_t26):
			_t26._k63()
	_a90.clear()
	_a75 = null
	
	if is_instance_valid(_k14):
		_k14.queue_free()
		_k14 = null
	
	if is_instance_valid(_e89):
		_e89.queue_free()
		_e89 = null

func _j13():
	_y28 = _m78.new()
	
	_t37 = _g16.new(self, _y28)
	_t37._t27.connect(_r54)
	_w28.append(_t37)
	
	_b97 = _r6.instantiate()
	_b97._k94(get_editor_interface())
	_b97._s40.connect(_d70)
	
	_m24 = _q23.instantiate()
	_m24._g49(_y28)
	
	_q55 = _k5.instantiate()

func _z98():
	for _t26 in _w28:
		if is_instance_valid(_t26):
			_t26._k63()
	_w28.clear()
	_t37 = null
	
	if is_instance_valid(_b97):
		_b97.queue_free()
		_b97 = null
	
	if is_instance_valid(_m24):
		_m24.queue_free()
		_m24 = null
	
	if is_instance_valid(_q55):
		_q55.queue_free()
		_q55 = null
	
	if _y28:
		_y28._t7()
		_y28 = null

func _u43():
	const _d51 = 1000
	const _w84 = 150
	
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		_u42._u74 = config.get_value("autocomplete", "enabled", true)
		_u42._a85 = _d51  
		_u42._v12 = _w84  
		_u42._v68 = config.get_value("autocomplete", "mode", "automatic")
		_u42._g75 = config.get_value("autocomplete", "min_chars", 3)
	else:
		_u42._u74 = true
		_u42._a85 = _d51
		_u42._v12 = _w84
		_u42._v68 = "automatic"
		_u42._g75 = 3

func save_autocomplete_config(enabled: bool, _p78: int, max_length: int, mode: String = "", _m67: int = 3):
	const _d51 = 1000
	const _w84 = 150
	
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")  
	
	config.set_value("autocomplete", "enabled", enabled)
	config.set_value("autocomplete", "delay_ms", _d51)  
	config.set_value("autocomplete", "max_length", _w84)  
	if mode != "":
		config.set_value("autocomplete", "mode", mode)
	config.set_value("autocomplete", "min_chars", _m67)
	
	config.save("user://gdsense_api_key.cfg")
	
	if is_instance_valid(_u42):
		_u42.set_enabled(enabled)
		_u42.set_delay(_d51)  
		_u42._v12 = _w84  
		if mode != "":
			_u42.set_mode(mode)
		_u42._g75 = _m67

func _s85():
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var enabled = config.get_value("explain_button", "enabled", true)
		if _d66:
			_d66.set_enabled(enabled)
	else:
		if _d66:
			_d66.set_enabled(true)

func _s46():
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var enabled = config.get_value("refactor_button", "enabled", true)
		if is_instance_valid(_a75):
			_a75.set_enabled(enabled)
	else:
		if is_instance_valid(_a75):
			_a75.set_enabled(true)

func _i97():
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var enabled = config.get_value("undo_button", "enabled", true)
		if is_instance_valid(_t37):
			_t37.set_enabled(enabled)
	else:
		if is_instance_valid(_t37):
			_t37.set_enabled(true)

func _r49():
	var _t15 = get_editor_interface()
	if not _t15:
		return
	
	var _c37 = _t15.get_script_editor()
	if not _c37:
		return
	
	var _w66 = _c37.get_current_script()
	if _w66:
		var config = ConfigFile.new()
		if config.load("user://gdsense_api_key.cfg") == OK:
			var _s30 = config.get_value("explain_button", "enabled", true)
			if _s30 and _d66:
				_d66._u14(_w66)
			
			var _b60 = config.get_value("refactor_button", "enabled", true)
			if _b60 and _a75:
				_a75._u14(_w66)
			
			var _z1 = config.get_value("undo_button", "enabled", true)
			if _z1 and _t37:
				_t37._u14(_w66)

func save_explain_button_config(enabled: bool):
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")  
	
	config.set_value("explain_button", "enabled", enabled)
	config.save("user://gdsense_api_key.cfg")
	
	if _d66:
		_d66.set_enabled(enabled)
		
		if enabled:
			_r49.call_deferred()

func save_refactor_config(enabled: bool):
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")  
	
	config.set_value("refactor_button", "enabled", enabled)
	config.save("user://gdsense_api_key.cfg")
	
	if is_instance_valid(_a75):
		_a75.set_enabled(enabled)

func save_undo_config(enabled: bool):
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")  
	
	config.set_value("undo_button", "enabled", enabled)
	config.save("user://gdsense_api_key.cfg")
	
	if is_instance_valid(_t37):
		_t37.set_enabled(enabled)

func _w80(function_name: String, _g33: String):
	if not is_instance_valid(_f86):
		return
	
	if _f86.has_method("send_explain_request"):
		_f86.send_explain_request(function_name, _g33)
	else:
		pass

func _u99(function_name: String, _g33: String, file_path: String):
	if is_instance_valid(_k14):
		_k14.set_meta("file_path", file_path)
		_k14.set_meta("function_source", _g33)
	
	var _t15 = get_editor_interface()
	var current_scene = _t15.get_editor_main_screen() if _t15 else null
	if current_scene and is_instance_valid(_k14):
		if not _k14.is_inside_tree():
			current_scene.add_child(_k14)
		_k14._m52(function_name, _g33)

func _w56(_n1: String, function_name: String, _g33: String, model: String):
	var file_path = ""
	if is_instance_valid(_k14) and _k14.has_meta("file_path"):
		file_path = _k14.get_meta("file_path")

	if is_instance_valid(_a8):
		_a8._j84(function_name, _g33, _n1, file_path, model)

func _o80(refactored_code: String, original_hash: String, function_name: String):
	if is_instance_valid(_k14):
		_k14._f37()
	
	var _t15 = get_editor_interface()
	var current_scene = _t15.get_editor_main_screen() if _t15 else null
	if current_scene and is_instance_valid(_e89):
		if not _e89.is_inside_tree():
			current_scene.add_child(_e89)
		
		var _b82 = ""
		if is_instance_valid(_k14) and _k14.has_meta("function_source"):
			_b82 = _k14.get_meta("function_source")

		if _b82.is_empty():
			_b82 = _y26(function_name)

		if not _b82.is_empty():
			_e89._d54(function_name, _b82, refactored_code)
		else:
			_e89._d54(function_name, "# Original source not available", refactored_code)

func _w11(_s65: int, _y100: String):
	if is_instance_valid(_k14):
		_k14._f37()
	
	push_error("Refactor failed: " + _y100)

func _j33(refactored_code: String, function_name: String):
	var original_code = _y26(function_name)
	var file_path = ""
	var function_line = 0
	
	var _t15 = get_editor_interface()
	if _t15:
		var _c37 = _t15.get_script_editor()
		if _c37:
			var _w66 = _c37.get_current_script()
			if _w66:
				file_path = _w66.resource_path
	
	if is_instance_valid(_a75):
		var _o100 = _a75._r2()
		for _s29 in _o100:
			if _s29.name == function_name:
				function_line = _s29.line
				break
	
	var _r21 = _t48(refactored_code)

	_r21 = _r21.rstrip("\n") + "\n"

	_e99(function_name, _r21)

	if _y28 and not original_code.is_empty():
		var _t69 = _r21.rstrip("\n") + "\n\n"
		_y28._f11(function_name, original_code, _t69, file_path, function_line)
		
		if is_instance_valid(_t37):
			_t37._e25()
		if is_instance_valid(_a75):
			_a75._e25()
		if is_instance_valid(_d66):
			_d66._e25()
		
		_q45()
	
func _w16(function_name: String):
	pass

func _s71(script: Script):
	_e31()

func _e31():
	var _f40: Array[_y29] = []
	for _t26 in _l56:
		if is_instance_valid(_t26):
			_f40.append(_t26)
		else:
			pass

	_l56 = _f40
	
	var _o55: Array[_w85] = []
	for _t26 in _a90:
		if is_instance_valid(_t26):
			_o55.append(_t26)
		else:
			pass

	_a90 = _o55
	
	var _e43: Array[_k44] = []
	for _t26 in _w28:
		if is_instance_valid(_t26):
			_e43.append(_t26)
		else:
			pass

	_w28 = _e43

func _y26(function_name: String) -> String:
	var _t15 = get_editor_interface()
	if not _t15:
		return ""
	
	var _c37 = _t15.get_script_editor()
	if not _c37:
		return ""
	
	var _w66 = _c37.get_current_script()
	if not _w66:
		return ""
	
	if is_instance_valid(_a75):
		var _o100 = _a75._r2()
		for _s29 in _o100:
			if _s29.name == function_name:
				return _a75._h99(_s29)
	
	return ""

func _e99(function_name: String, refactored_code: String):
	var _t15 = get_editor_interface()
	if not _t15:
		return
	
	var _c37 = _t15.get_script_editor()
	if not _c37:
		return
	
	var _y53 = _c37.get_current_editor()
	if not _y53:
		return
	
	var _g95 = _j24(_y53)
	if not _g95:
		return
	
	if is_instance_valid(_a75):
		var _o100 = _a75._r2()
		for _s29 in _o100:
			if _s29.name == function_name:
				var start_line = _s29.line
				var end_line = _s29.get("end_line", start_line)

				var _u47 = refactored_code.rstrip("\n") + "\n\n"

				_p30(_g95, start_line, end_line, _u47)

				return
	
func _j24(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node
	
	for _w15 in node.get_children():
		var _k3 = _j24(_w15)
		if _k3:
			return _k3
	
	return null

func _p30(_g95: CodeEdit, start_line: int, end_line: int, _s1: String):
	_g95.set_caret_line(start_line)
	_g95.set_caret_column(0)
	_g95.select(start_line, 0, end_line + 1, 0)

	var _b40 = _s1
	if not _b40.ends_with("\n"):
		_b40 += "\n"
	_g95.insert_text_at_caret(_b40)

	_g95.deselect()

func _t48(text: String) -> String:
	var _m12 = text.split("\n")
	for i in range(_m12.size()):
		var line = _m12[i]
		var _k47 = 0
		for c in line:
			if c == ' ':
				_k47 += 1
			else:
				break

		var _l44 = _k47 / 4
		if _l44 > 0:
			_m12[i] = "\t".repeat(_l44) + line.substr(_k47)

	return "\n".join(_m12)

func _r54(function_name: String, file_path: String):
	if not _y28 or not _y28._p100(function_name, file_path):
		_q45()
		if is_instance_valid(_q55):
			_q55._k83(function_name)
		return
	
	var _v36 = _y28._e41(function_name, file_path)
	if not _v36:
		_q45()
		if is_instance_valid(_q55):
			_q55._v37(function_name, "No history entry found")
		return
	
	var _t91 = false
	if is_instance_valid(_t37):
		_t91 = not _t37._z16(function_name, file_path)
	
	_s33()
	if is_instance_valid(_b97):
		_b97._m52(_v36, file_path, _t91)

func _d70(function_name: String, original_code: String, file_path: String):
	var refactored_code = ""
	if _y28:
		var _v36 = _y28._e41(function_name, file_path)
		if _v36:
			refactored_code = _v36.refactored_code
	
	var success = _q87(function_name, original_code, refactored_code, file_path)
	
	if success:
		if _y28:
			var _v36 = _y28._e41(function_name, file_path)
			if _v36:
				_y28._e4(function_name, file_path, _v36.timestamp)
		
		if is_instance_valid(_t37):
			_t37._e25()
		if is_instance_valid(_a75):
			_a75._e25()
		if is_instance_valid(_d66):
			_d66._e25()
		
		_q45()
		if is_instance_valid(_q55):
			_q55._i22(function_name)
	else:
		_q45()
		if is_instance_valid(_q55):
			_q55._v37(function_name, "Failed to apply original code")

func _q87(function_name: String, original_code: String, refactored_code: String, file_path: String) -> bool:
	var _t15 = get_editor_interface()
	if not _t15:
		push_error("GDSensePlugin: Could not get editor interface for undo")
		return false
	
	var _c37 = _t15.get_script_editor()
	if not _c37:
		push_error("GDSensePlugin: Could not get script editor for undo")
		return false
	
	var _y53 = _c37.get_current_editor()
	if not _y53:
		push_error("GDSensePlugin: Could not get current editor for undo")
		return false
	
	var _g95 = _j24(_y53)
	if not _g95:
		push_error("GDSensePlugin: Could not find CodeEdit node for undo")
		return false
	
	var text = _g95.text
	var _m12 = text.split("\n")

	var _n84 = RegEx.new()
	_n84.compile("^\\s*func\\s+" + function_name + "\\s*\\(")

	var _a61 = -1
	for i in range(_m12.size()):
		if _n84.search(_m12[i]):
			_a61 = i
			break

	if _a61 == -1:
		push_error("GDSensePlugin: Could not find function to undo: " + function_name)
		return false

	var start_line = _a61
	var _h66 = original_code.strip_edges().begins_with("func ")

	if _h66:
		while start_line > 0:
			var _a86 = _m12[start_line - 1].strip_edges()
			if _a86.begins_with("#"):
				start_line -= 1
			else:
				break

	var end_line = _b92(_m12, _a61)

	var _u47 = original_code.rstrip("\n") + "\n\n"
	_p30(_g95, start_line, end_line, _u47)

	return true

func _b92(_m12: PackedStringArray, start_line: int) -> int:
	if start_line >= _m12.size():
		return start_line
	
	var _g68 = _t80(_m12[start_line])
	
	for i in range(start_line + 1, _m12.size()):
		var line = _m12[i]
		var _e54 = line.strip_edges()
		
		if _e54.is_empty() or _e54.begins_with("#"):
			continue
		
		var _k30 = _t80(line)
		
		if _k30 <= _g68:
			if _e54.begins_with("func ") or _e54.begins_with("class ") or _e54.begins_with("extends") or _e54.begins_with("@"):
				return i - 1
	
	return _m12.size() - 1

func _t80(line: String) -> int:
	var indent = 0
	for char in line:
		if char == '\t':
			indent += 4  
		elif char == ' ':
			indent += 1
		else:
			break
	return indent

func _q45():
	if not is_instance_valid(_q55):
		return
	
	var _t15 = get_editor_interface()
	if not _t15:
		return
	
	var current_scene = _t15.get_editor_main_screen()
	if not current_scene:
		return
	
	if not _q55.is_inside_tree():
		current_scene.add_child(_q55)

func _s33():
	if not is_instance_valid(_b97):
		return
	
	var _t15 = get_editor_interface()
	if not _t15:
		return
	
	var current_scene = _t15.get_editor_main_screen()
	if not current_scene:
		return
	
	if not _b97.is_inside_tree():
		current_scene.add_child(_b97)

func _h38():
	if not is_instance_valid(_m24):
		return
	
	var _t15 = get_editor_interface()
	if not _t15:
		return
	
	var current_scene = _t15.get_editor_main_screen()
	if not current_scene:
		return
	
	if not _m24.is_inside_tree():
		current_scene.add_child(_m24)

func _a48(file_path: String):
	_h38()
	if is_instance_valid(_m24):
		_m24._i54(file_path)

func _v89():
	_h38()
	if is_instance_valid(_m24):
		_m24._r97()

func _l10() -> _w99:
	return _y28

