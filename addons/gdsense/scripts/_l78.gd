@tool
extends RefCounted
class_name _v37
var _k54: EditorPlugin
var _x34: _p17
var _e3: ScriptEditor
var _n7: CodeEdit
var _j87: _e98
var _x5: _u79
var _d54: _i44
var _h63: bool = true
var _u45: int = 800
var _g35: int = 150
var _p4: String = "automatic"  
var _m3: int = 3
var _y5: int = 0
var _e47: bool = false
var _i47: int = -1
var _v26: int = -1
func _init(_n64: EditorPlugin, _r46: _p17):
	_k54 = _n64
	_x34 = _r46
	_e3 = _k54.get_editor_interface().get_script_editor()
	_x5 = _u79.new(_e3)
	if _x34:
		if not _x34._v3.is_connected(_x69):
			_x34._v3.connect(_x69)
	_w15()
func _w15():
	if _e3:
		if not _e3.editor_script_changed.is_connected(_u5):
			_e3.editor_script_changed.connect(_u5)
		_w84()
func _u5(script: Script):
	_w84()
func _w84():
	_i13()
	_n7 = _n42()
	if _n7 and _h63:
		if _p4 == "automatic":
			_j87 = _e98.new(_n7)
			_j87.set_delay(_u45)
			_j87._a99.connect(_p90)
			_j87._x97()
		_d54 = _i44.new(_n7)
		if not _n7.gui_input.is_connected(_t56):
			_n7.gui_input.connect(_t56)
		if not _n7.caret_changed.is_connected(_l80):
			_n7.caret_changed.connect(_l80)
		if not _n7.text_changed.is_connected(_b45):
			_n7.text_changed.connect(_b45)
func _n42() -> CodeEdit:
	var _p25 = _e3.get_current_editor()
	if not _p25:
		return null
	return _j66(_p25)
func _j66(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node
	for _x15 in node.get_children():
		var _e21 = _j66(_x15)
		if _e21:
			return _e21
	return null
func _p90():
	if not _n7 or not _h63:
		return
	if _p4 == "manual":
		return
	if Time.get_ticks_msec() - _y5 < 2000:
		return
	if not _d53():
		return
	var context = _x5._x18(_n7)
	if _x34:
		_x34._a63(context)
func _d53() -> bool:
	if _x5.is_in_comment(_n7):
		return false
	if _x5.is_in_string(_n7):
		return false
	if not _x5._u12(_n7):
		return false
	if not _x5._x33(_n7):
		var line = _x5.get_current_line(_n7)
		var _l58 = line.strip_edges()
		if _l58.length() < _m3:
			return false
	var line = _x5.get_current_line(_n7)
	var _y79 = _n7.get_caret_column()
	var _v85 = line.substr(_y79).strip_edges()
	if _v85.length() > 0:
		return false
	return true
func _x69(_x43: String, _i1: int):
	if not _d54 or not _n7:
		return
	if _x43.length() > _g35:
		_x43 = _x43.substr(0, _g35)
	_d54._v43(_x43)
	_e47 = true
	_i47 = _n7.get_caret_line()
	_v26 = _n7.get_caret_column()
func _t56(_t27: InputEvent):
	if _t27 is InputEventKey and _t27.pressed:
		if _t27.keycode == KEY_SPACE and _t27.ctrl_pressed:
			_c80()
			_n7.accept_event()
			return
		if _d54 and _d54._e25():
			match _t27.keycode:
				KEY_TAB:
					_s91()
					_n7.accept_event()
				KEY_ESCAPE:
					_o81()
					_n7.accept_event()
				_:
					_o81()
func _c80():
	if not _n7 or not _h63:
		return
	if _j87:
		_j87._l54()
	var context = _x5._x18(_n7)
	if _x34:
		_x34._a63(context)
func _s91():
	if not _d54 or not _n7:
		return
	var _x43 = _d54._z69()
	if _x43.is_empty():
		return
	_n7.insert_text_at_caret(_x43)
	_d54._f31()
func _o81():
	if _d54:
		_d54._f31()
		_y5 = Time.get_ticks_msec()
		_e47 = false
func _l80():
	if not _n7 or not _d54:
		return
	var _i52 = _n7.get_caret_line()
	var _e63 = _n7.get_caret_column()
	if _i52 != _i47 and _d54._e25():
		_o81()
	elif abs(_e63 - _v26) > 5 and _d54._e25():
		_o81()
	_i47 = _i52
	_v26 = _e63
func _b45():
	if _d54 and _d54._e25():
		_o81()
func _i13():
	if _j87:
		_j87._u75()
		_j87 = null
	if _d54:
		_d54._u75()
		_d54 = null
	if _n7:
		if _n7.gui_input.is_connected(_t56):
			_n7.gui_input.disconnect(_t56)
		if _n7.caret_changed.is_connected(_l80):
			_n7.caret_changed.disconnect(_l80)
		if _n7.text_changed.is_connected(_b45):
			_n7.text_changed.disconnect(_b45)
	_n7 = null
func set_enabled(enabled: bool):
	_h63 = enabled
	if not enabled:
		_i13()
	else:
		_w84()
func set_mode(mode: String):
	_p4 = mode
	_w84()
func set_delay(_x38: int):
	_u45 = _x38
	if _j87:
		_j87.set_delay(_x38)
func _z76(_u83: int):
	_m3 = _u83
func _u75():
	_i13()
	if _e3 and _e3.editor_script_changed.is_connected(_u5):
		_e3.editor_script_changed.disconnect(_u5)
	if _x34 and _x34._v3.is_connected(_x69):
		_x34._v3.disconnect(_x69)
