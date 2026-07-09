@tool
extends RefCounted
class_name _n16
var _x87: EditorPlugin
var _i24: _a99
var _y14: ScriptEditor
var _n58: CodeEdit
var _y98: _m22
var _k12: _o92
var _k24: _i5
var _h61: bool = true
var _m49: int = 800
var _w73: int = 150
var _m71: String = "automatic"  
var _i59: int = 3
var _k85: int = 0
var _u92: bool = false
var _x23: int = -1
var _g45: int = -1
func _init(_c9: EditorPlugin, _w18: _a99):
	_x87 = _c9
	_i24 = _w18
	_y14 = _x87.get_editor_interface().get_script_editor()
	_k12 = _o92.new(_y14)
	if _i24:
		if not _i24._z92.is_connected(_k63):
			_i24._z92.connect(_k63)
	_u44()
func _u44():
	if _y14:
		if not _y14.editor_script_changed.is_connected(_c17):
			_y14.editor_script_changed.connect(_c17)
		_h76()
func _c17(script: Script):
	_h76()
func _h76():
	_p20()
	_n58 = _r78()
	if _n58 and _h61:
		if _m71 == "automatic":
			_y98 = _m22.new(_n58)
			_y98.set_delay(_m49)
			_y98._p23.connect(_f55)
			_y98._k87()
		_k24 = _i5.new(_n58)
		if not _n58.gui_input.is_connected(_o93):
			_n58.gui_input.connect(_o93)
		if not _n58.caret_changed.is_connected(_x61):
			_n58.caret_changed.connect(_x61)
		if not _n58.text_changed.is_connected(_w3):
			_n58.text_changed.connect(_w3)
func _r78() -> CodeEdit:
	var _g53 = _y14.get_current_editor()
	if not _g53:
		return null
	return _i1(_g53)
func _i1(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node
	for _i64 in node.get_children():
		var _n37 = _i1(_i64)
		if _n37:
			return _n37
	return null
func _f55():
	if not _n58 or not _h61:
		return
	if _m71 == "manual":
		return
	if Time.get_ticks_msec() - _k85 < 2000:
		return
	if not _h45():
		return
	var context = _k12._c24(_n58)
	if _i24:
		_i24._i39(context)
func _h45() -> bool:
	if _k12.is_in_comment(_n58):
		return false
	if _k12.is_in_string(_n58):
		return false
	if not _k12._o28(_n58):
		return false
	if not _k12._m14(_n58):
		var line = _k12.get_current_line(_n58)
		var _o62 = line.strip_edges()
		if _o62.length() < _i59:
			return false
	var line = _k12.get_current_line(_n58)
	var _c64 = _n58.get_caret_column()
	var _z43 = line.substr(_c64).strip_edges()
	if _z43.length() > 0:
		return false
	return true
func _k63(_k91: String, _v88: int):
	if not _k24 or not _n58:
		return
	if _k91.length() > _w73:
		_k91 = _k91.substr(0, _w73)
	_k24._h85(_k91)
	_u92 = true
	_x23 = _n58.get_caret_line()
	_g45 = _n58.get_caret_column()
func _o93(_v53: InputEvent):
	if _v53 is InputEventKey and _v53.pressed:
		if _v53.keycode == KEY_SPACE and _v53.ctrl_pressed:
			_i14()
			_n58.accept_event()
			return
		if _k24 and _k24._s71():
			match _v53.keycode:
				KEY_TAB:
					_s73()
					_n58.accept_event()
				KEY_ESCAPE:
					_t60()
					_n58.accept_event()
				_:
					_t60()
func _i14():
	if not _n58 or not _h61:
		return
	if _y98:
		_y98._i74()
	var context = _k12._c24(_n58)
	if _i24:
		_i24._i39(context)
func _s73():
	if not _k24 or not _n58:
		return
	var _k91 = _k24._g41()
	if _k91.is_empty():
		return
	_n58.insert_text_at_caret(_k91)
	_k24._o2()
func _t60():
	if _k24:
		_k24._o2()
		_k85 = Time.get_ticks_msec()
		_u92 = false
func _x61():
	if not _n58 or not _k24:
		return
	var _t50 = _n58.get_caret_line()
	var _s5 = _n58.get_caret_column()
	if _t50 != _x23 and _k24._s71():
		_t60()
	elif abs(_s5 - _g45) > 5 and _k24._s71():
		_t60()
	_x23 = _t50
	_g45 = _s5
func _w3():
	if _k24 and _k24._s71():
		_t60()
func _p20():
	if _y98:
		_y98._h41()
		_y98 = null
	if _k24:
		_k24._h41()
		_k24 = null
	if _n58:
		if _n58.gui_input.is_connected(_o93):
			_n58.gui_input.disconnect(_o93)
		if _n58.caret_changed.is_connected(_x61):
			_n58.caret_changed.disconnect(_x61)
		if _n58.text_changed.is_connected(_w3):
			_n58.text_changed.disconnect(_w3)
	_n58 = null
func set_enabled(enabled: bool):
	_h61 = enabled
	if not enabled:
		_p20()
	else:
		_h76()
func set_mode(mode: String):
	_m71 = mode
	_h76()
func set_delay(_u62: int):
	_m49 = _u62
	if _y98:
		_y98.set_delay(_u62)
func _t34(_j36: int):
	_i59 = _j36
func _h41():
	_p20()
	if _y14 and _y14.editor_script_changed.is_connected(_c17):
		_y14.editor_script_changed.disconnect(_c17)
	if _i24 and _i24._z92.is_connected(_k63):
		_i24._z92.disconnect(_k63)
