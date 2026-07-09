@tool
extends RefCounted
class_name _e47

var _v44: EditorPlugin
var _k87: _y82
var _i60: ScriptEditor
var _c96: CodeEdit
var _y100: _n72
var _r88: _r28
var _f47: _x92

var _a16: bool = true
var _d19: int = 800
var _s50: int = 150
var _f15: String = "automatic"  
var _n43: int = 3
var _f53: int = 0
var _s60: bool = false
var _m33: int = -1
var _m82: int = -1

func _init(_w62: EditorPlugin, _d39: _y82):
	_v44 = _w62
	_k87 = _d39
	_i60 = _v44.get_editor_interface().get_script_editor()
	_r88 = _r28.new(_i60)
	
	if _k87:
		if not _k87._x33.is_connected(_a81):
			_k87._x33.connect(_a81)
	
	_w32()

func _w32():
	if _i60:
		if not _i60.editor_script_changed.is_connected(_j68):
			_i60.editor_script_changed.connect(_j68)
		
		_f54()

func _j68(script: Script):
	_f54()

func _f54():
	_p91()
	
	_c96 = _w96()
	
	if _c96 and _a16:
		if _f15 == "automatic":
			_y100 = _n72.new(_c96)
			_y100.set_delay(_d19)
			_y100._z2.connect(_m50)
			_y100._q15()
		
		_f47 = _x92.new(_c96)
		
		if not _c96.gui_input.is_connected(_r26):
			_c96.gui_input.connect(_r26)
		
		if not _c96.caret_changed.is_connected(_g29):
			_c96.caret_changed.connect(_g29)
		if not _c96.text_changed.is_connected(_u29):
			_c96.text_changed.connect(_u29)

func _w96() -> CodeEdit:
	var _z47 = _i60.get_current_editor()
	if not _z47:
		return null
	
	return _n94(_z47)

func _n94(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node
	
	for _c100 in node.get_children():
		var _x97 = _n94(_c100)
		if _x97:
			return _x97
	
	return null

func _m50():
	if not _c96 or not _a16:
		return
	
	if _f15 == "manual":
		return
	
	if Time.get_ticks_msec() - _f53 < 2000:
		return
	
	if not _z27():
		return
	
	var context = _r88._d55(_c96)
	
	if _k87:
		_k87._h96(context)

func _z27() -> bool:
	if _r88.is_in_comment(_c96):
		return false
	
	if _r88.is_in_string(_c96):
		return false
	
	if not _r88._m9(_c96):
		return false
	
	if not _r88._i47(_c96):
		var line = _r88.get_current_line(_c96)
		var _q21 = line.strip_edges()
		if _q21.length() < _n43:
			return false
	
	var line = _r88.get_current_line(_c96)
	var _z11 = _c96.get_caret_column()
	var _c58 = line.substr(_z11).strip_edges()
	
	if _c58.length() > 0:
		return false
	
	return true

func _a81(_i100: String, _m81: int):
	if not _f47 or not _c96:
		return
	
	if _i100.length() > _s50:
		_i100 = _i100.substr(0, _s50)
	
	_f47._l11(_i100)
	_s60 = true
	
	_m33 = _c96.get_caret_line()
	_m82 = _c96.get_caret_column()
	
func _r26(_x1: InputEvent):
	if _x1 is InputEventKey and _x1.pressed:
		if _x1.keycode == KEY_SPACE and _x1.ctrl_pressed:
			_z83()
			_c96.accept_event()
			return
		
		if _f47 and _f47._v8():
			match _x1.keycode:
				KEY_TAB:
					_n42()
					_c96.accept_event()
				KEY_ESCAPE:
					_c33()
					_c96.accept_event()
				_:
					_c33()

func _z83():
	if not _c96 or not _a16:
		return
	
	if _y100:
		_y100._y20()
	
	var context = _r88._d55(_c96)
	
	if _k87:
		_k87._h96(context)

func _n42():
	if not _f47 or not _c96:
		return
	
	var _i100 = _f47._d56()
	if _i100.is_empty():
		return
	
	_c96.insert_text_at_caret(_i100)
	
	_f47._d91()
	
func _c33():
	if _f47:
		_f47._d91()
		_f53 = Time.get_ticks_msec()
		_s60 = false

func _g29():
	if not _c96 or not _f47:
		return
	
	var _n27 = _c96.get_caret_line()
	var _t18 = _c96.get_caret_column()
	
	if _n27 != _m33 and _f47._v8():
		_c33()

	elif abs(_t18 - _m82) > 5 and _f47._v8():
		_c33()
	
	_m33 = _n27
	_m82 = _t18

func _u29():
	if _f47 and _f47._v8():
		_c33()

func _p91():
	if _y100:
		_y100._q17()
		_y100 = null
	
	if _f47:
		_f47._q17()
		_f47 = null
	
	if _c96:
		if _c96.gui_input.is_connected(_r26):
			_c96.gui_input.disconnect(_r26)
		if _c96.caret_changed.is_connected(_g29):
			_c96.caret_changed.disconnect(_g29)
		if _c96.text_changed.is_connected(_u29):
			_c96.text_changed.disconnect(_u29)
	
	_c96 = null

func set_enabled(enabled: bool):
	_a16 = enabled
	if not enabled:
		_p91()
	else:
		_f54()

func set_mode(mode: String):
	_f15 = mode

	_f54()

func set_delay(_m91: int):
	_d19 = _m91
	if _y100:
		_y100.set_delay(_m91)

func _y19(_g34: int):
	_n43 = _g34

func _q17():
	_p91()
	
	if _i60 and _i60.editor_script_changed.is_connected(_j68):
		_i60.editor_script_changed.disconnect(_j68)
	
	if _k87 and _k87._x33.is_connected(_a81):
		_k87._x33.disconnect(_a81)

