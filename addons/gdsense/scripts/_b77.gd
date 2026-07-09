@tool
extends RefCounted
class_name _d54
var _r75: EditorPlugin
var _r78: _r91
var _n12: ScriptEditor
var _c24: CodeEdit
var _s42: _p65
var _d72: _u73
var _k35: _q59
var _f71: bool = true
var _a100: int = 800
var _n100: int = 150
var _c67: String = "automatic"  
var _b27: int = 3
var _t6: int = 0
var _m100: bool = false
var _o26: int = -1
var _j68: int = -1
func _init(_c44: EditorPlugin, _w86: _r91):
	_r75 = _c44
	_r78 = _w86
	_n12 = _r75.get_editor_interface().get_script_editor()
	_d72 = _u73.new(_n12)
	if _r78:
		if not _r78._i61.is_connected(_f50):
			_r78._i61.connect(_f50)
	_p97()
func _p97():
	if _n12:
		if not _n12.editor_script_changed.is_connected(_y87):
			_n12.editor_script_changed.connect(_y87)
		_a34()
func _y87(script: Script):
	_a34()
func _a34():
	_v39()
	_c24 = _l56()
	if _c24 and _f71:
		if _c67 == "automatic":
			_s42 = _p65.new(_c24)
			_s42.set_delay(_a100)
			_s42._l23.connect(_t87)
			_s42._a91()
		_k35 = _q59.new(_c24)
		if not _c24.gui_input.is_connected(_t75):
			_c24.gui_input.connect(_t75)
		if not _c24.caret_changed.is_connected(_k55):
			_c24.caret_changed.connect(_k55)
		if not _c24.text_changed.is_connected(_g28):
			_c24.text_changed.connect(_g28)
func _l56() -> CodeEdit:
	var _a57 = _n12.get_current_editor()
	if not _a57:
		return null
	return _s53(_a57)
func _s53(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node
	for _o14 in node.get_children():
		var _s61 = _s53(_o14)
		if _s61:
			return _s61
	return null
func _t87():
	if not _c24 or not _f71:
		return
	if _c67 == "manual":
		return
	if Time.get_ticks_msec() - _t6 < 2000:
		return
	if not _x63():
		return
	var context = _d72._n1(_c24)
	if _r78:
		_r78._y35(context)
func _x63() -> bool:
	if _d72.is_in_comment(_c24):
		return false
	if _d72.is_in_string(_c24):
		return false
	if not _d72._v29(_c24):
		return false
	if not _d72._e76(_c24):
		var line = _d72.get_current_line(_c24)
		var _n62 = line.strip_edges()
		if _n62.length() < _b27:
			return false
	var line = _d72.get_current_line(_c24)
	var _z7 = _c24.get_caret_column()
	var _l80 = line.substr(_z7).strip_edges()
	if _l80.length() > 0:
		return false
	return true
func _f50(_n54: String, _d75: int):
	if not _k35 or not _c24:
		return
	if _n54.length() > _n100:
		_n54 = _n54.substr(0, _n100)
	_k35._i74(_n54)
	_m100 = true
	_o26 = _c24.get_caret_line()
	_j68 = _c24.get_caret_column()
func _t75(_x75: InputEvent):
	if _x75 is InputEventKey and _x75.pressed:
		if _x75.keycode == KEY_SPACE and _x75.ctrl_pressed:
			_i18()
			_c24.accept_event()
			return
		if _k35 and _k35._l11():
			match _x75.keycode:
				KEY_TAB:
					_p96()
					_c24.accept_event()
				KEY_ESCAPE:
					_k34()
					_c24.accept_event()
				_:
					_k34()
func _i18():
	if not _c24 or not _f71:
		return
	if _s42:
		_s42._f90()
	var context = _d72._n1(_c24)
	if _r78:
		_r78._y35(context)
func _p96():
	if not _k35 or not _c24:
		return
	var _n54 = _k35._o5()
	if _n54.is_empty():
		return
	_c24.insert_text_at_caret(_n54)
	_k35._w61()
func _k34():
	if _k35:
		_k35._w61()
		_t6 = Time.get_ticks_msec()
		_m100 = false
func _k55():
	if not _c24 or not _k35:
		return
	var _f39 = _c24.get_caret_line()
	var _l24 = _c24.get_caret_column()
	if _f39 != _o26 and _k35._l11():
		_k34()
	elif abs(_l24 - _j68) > 5 and _k35._l11():
		_k34()
	_o26 = _f39
	_j68 = _l24
func _g28():
	if _k35 and _k35._l11():
		_k34()
func _v39():
	if _s42:
		_s42._o36()
		_s42 = null
	if _k35:
		_k35._o36()
		_k35 = null
	if _c24:
		if _c24.gui_input.is_connected(_t75):
			_c24.gui_input.disconnect(_t75)
		if _c24.caret_changed.is_connected(_k55):
			_c24.caret_changed.disconnect(_k55)
		if _c24.text_changed.is_connected(_g28):
			_c24.text_changed.disconnect(_g28)
	_c24 = null
func set_enabled(enabled: bool):
	_f71 = enabled
	if not enabled:
		_v39()
	else:
		_a34()
func set_mode(mode: String):
	_c67 = mode
	_a34()
func set_delay(_b6: int):
	_a100 = _b6
	if _s42:
		_s42.set_delay(_b6)
func _p88(_q100: int):
	_b27 = _q100
func _o36():
	_v39()
	if _n12 and _n12.editor_script_changed.is_connected(_y87):
		_n12.editor_script_changed.disconnect(_y87)
	if _r78 and _r78._i61.is_connected(_f50):
		_r78._i61.disconnect(_f50)
