@tool
extends RefCounted
class_name _h26
var _d14: EditorPlugin
var _k26: _y57
var _k94: ScriptEditor
var _i57: CodeEdit
var _z19: _i25
var _e17: _j43
var _s47: _l71
var _q100: bool = true
var _f44: int = 800
var _d81: int = 150
var _w2: String = "automatic"  
var _e22: int = 3
var _k88: int = 0
var _y8: bool = false
var _l78: int = -1
var _x94: int = -1
func _init(_k9: EditorPlugin, _f78: _y57):
	_d14 = _k9
	_k26 = _f78
	_k94 = _d14.get_editor_interface().get_script_editor()
	_e17 = _j43.new(_k94)
	if _k26:
		if not _k26._a52.is_connected(_g54):
			_k26._a52.connect(_g54)
	_p89()
func _p89():
	if _k94:
		if not _k94.editor_script_changed.is_connected(_c28):
			_k94.editor_script_changed.connect(_c28)
		_u98()
func _c28(script: Script):
	_u98()
func _u98():
	_z64()
	_i57 = _t60()
	if _i57 and _q100:
		if _w2 == "automatic":
			_z19 = _i25.new(_i57)
			_z19.set_delay(_f44)
			_z19._d16.connect(_c49)
			_z19._d58()
		_s47 = _l71.new(_i57)
		if not _i57.gui_input.is_connected(_n15):
			_i57.gui_input.connect(_n15)
		if not _i57.caret_changed.is_connected(_j65):
			_i57.caret_changed.connect(_j65)
		if not _i57.text_changed.is_connected(_d6):
			_i57.text_changed.connect(_d6)
func _t60() -> CodeEdit:
	var _h92 = _k94.get_current_editor()
	if not _h92:
		return null
	return _e28(_h92)
func _e28(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node
	for _h61 in node.get_children():
		var _x97 = _e28(_h61)
		if _x97:
			return _x97
	return null
func _c49():
	if not _i57 or not _q100:
		return
	if _w2 == "manual":
		return
	if Time.get_ticks_msec() - _k88 < 2000:
		return
	if not _i12():
		return
	var context = _e17._o62(_i57)
	if _k26:
		_k26._e66(context)
func _i12() -> bool:
	if _e17.is_in_comment(_i57):
		return false
	if _e17.is_in_string(_i57):
		return false
	if not _e17._y22(_i57):
		return false
	if not _e17._e55(_i57):
		var line = _e17.get_current_line(_i57)
		var _n67 = line.strip_edges()
		if _n67.length() < _e22:
			return false
	var line = _e17.get_current_line(_i57)
	var _f29 = _i57.get_caret_column()
	var _m17 = line.substr(_f29).strip_edges()
	if _m17.length() > 0:
		return false
	return true
func _g54(_q5: String, _e88: int):
	if not _s47 or not _i57:
		return
	if _q5.length() > _d81:
		_q5 = _q5.substr(0, _d81)
	_s47._f83(_q5)
	_y8 = true
	_l78 = _i57.get_caret_line()
	_x94 = _i57.get_caret_column()
func _n15(_x58: InputEvent):
	if _x58 is InputEventKey and _x58.pressed:
		if _x58.keycode == KEY_SPACE and _x58.ctrl_pressed:
			_q85()
			_i57.accept_event()
			return
		if _s47 and _s47._n30():
			match _x58.keycode:
				KEY_TAB:
					_b12()
					_i57.accept_event()
				KEY_ESCAPE:
					_l70()
					_i57.accept_event()
				_:
					_l70()
func _q85():
	if not _i57 or not _q100:
		return
	if _z19:
		_z19._n71()
	var context = _e17._o62(_i57)
	if _k26:
		_k26._e66(context)
func _b12():
	if not _s47 or not _i57:
		return
	var _q5 = _s47._e26()
	if _q5.is_empty():
		return
	_i57.insert_text_at_caret(_q5)
	_s47._x36()
func _l70():
	if _s47:
		_s47._x36()
		_k88 = Time.get_ticks_msec()
		_y8 = false
func _j65():
	if not _i57 or not _s47:
		return
	var _p23 = _i57.get_caret_line()
	var _w69 = _i57.get_caret_column()
	if _p23 != _l78 and _s47._n30():
		_l70()
	elif abs(_w69 - _x94) > 5 and _s47._n30():
		_l70()
	_l78 = _p23
	_x94 = _w69
func _d6():
	if _s47 and _s47._n30():
		_l70()
func _z64():
	if _z19:
		_z19._q60()
		_z19 = null
	if _s47:
		_s47._q60()
		_s47 = null
	if _i57:
		if _i57.gui_input.is_connected(_n15):
			_i57.gui_input.disconnect(_n15)
		if _i57.caret_changed.is_connected(_j65):
			_i57.caret_changed.disconnect(_j65)
		if _i57.text_changed.is_connected(_d6):
			_i57.text_changed.disconnect(_d6)
	_i57 = null
func set_enabled(enabled: bool):
	_q100 = enabled
	if not enabled:
		_z64()
	else:
		_u98()
func set_mode(mode: String):
	_w2 = mode
	_u98()
func set_delay(_z1: int):
	_f44 = _z1
	if _z19:
		_z19.set_delay(_z1)
func _k52(_j77: int):
	_e22 = _j77
func _q60():
	_z64()
	if _k94 and _k94.editor_script_changed.is_connected(_c28):
		_k94.editor_script_changed.disconnect(_c28)
	if _k26 and _k26._a52.is_connected(_g54):
		_k26._a52.disconnect(_g54)
