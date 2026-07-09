@tool
extends RefCounted
class_name _b38

var _e1: EditorPlugin
var _a12: _w70
var _b50: ScriptEditor
var _w59: CodeEdit
var _k39: _c51
var _m82: _e82
var _o6: _b87

var _u74: bool = true
var _a85: int = 800
var _v12: int = 150
var _v68: String = "automatic"  
var _g75: int = 3
var _u50: int = 0
var _r4: bool = false
var _a57: int = -1
var _j52: int = -1

func _init(_i89: EditorPlugin, _a8: _w70):
	_e1 = _i89
	_a12 = _a8
	_b50 = _e1.get_editor_interface().get_script_editor()
	_m82 = _e82.new(_b50)
	
	if _a12:
		if not _a12._b67.is_connected(_l49):
			_a12._b67.connect(_l49)
	
	_d99()

func _d99():
	if _b50:
		if not _b50.editor_script_changed.is_connected(_u14):
			_b50.editor_script_changed.connect(_u14)
		
		_y14()

func _u14(script: Script):
	_y14()

func _y14():
	_l68()
	
	_w59 = _w40()
	
	if _w59 and _u74:
		if _v68 == "automatic":
			_k39 = _c51.new(_w59)
			_k39.set_delay(_a85)
			_k39._a32.connect(_u95)
			_k39._e10()
		
		_o6 = _b87.new(_w59)
		
		if not _w59.gui_input.is_connected(_d76):
			_w59.gui_input.connect(_d76)
		
		if not _w59.caret_changed.is_connected(_c62):
			_w59.caret_changed.connect(_c62)
		if not _w59.text_changed.is_connected(_z28):
			_w59.text_changed.connect(_z28)

func _w40() -> CodeEdit:
	var _p3 = _b50.get_current_editor()
	if not _p3:
		return null
	
	return _l84(_p3)

func _l84(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node
	
	for _w15 in node.get_children():
		var _k3 = _l84(_w15)
		if _k3:
			return _k3
	
	return null

func _u95():
	if not _w59 or not _u74:
		return
	
	if _v68 == "manual":
		return
	
	if Time.get_ticks_msec() - _u50 < 2000:
		return
	
	if not _l87():
		return
	
	var context = _m82._o33(_w59)
	
	if _a12:
		_a12._w26(context)

func _l87() -> bool:
	if _m82.is_in_comment(_w59):
		return false
	
	if _m82.is_in_string(_w59):
		return false
	
	if not _m82._l43(_w59):
		return false
	
	if not _m82._v30(_w59):
		var line = _m82.get_current_line(_w59)
		var _l9 = line.strip_edges()
		if _l9.length() < _g75:
			return false
	
	var line = _m82.get_current_line(_w59)
	var _c6 = _w59.get_caret_column()
	var _h64 = line.substr(_c6).strip_edges()
	
	if _h64.length() > 0:
		return false
	
	return true

func _l49(_q88: String, _c46: int):
	if not _o6 or not _w59:
		return
	
	if _q88.length() > _v12:
		_q88 = _q88.substr(0, _v12)
	
	_o6._i60(_q88)
	_r4 = true
	
	_a57 = _w59.get_caret_line()
	_j52 = _w59.get_caret_column()
	
func _d76(_n74: InputEvent):
	if _n74 is InputEventKey and _n74.pressed:
		if _n74.keycode == KEY_SPACE and _n74.ctrl_pressed:
			_w54()
			_w59.accept_event()
			return
		
		if _o6 and _o6._t35():
			match _n74.keycode:
				KEY_TAB:
					_o26()
					_w59.accept_event()
				KEY_ESCAPE:
					_k77()
					_w59.accept_event()
				_:
					_k77()

func _w54():
	if not _w59 or not _u74:
		return
	
	if _k39:
		_k39._b1()
	
	var context = _m82._o33(_w59)
	
	if _a12:
		_a12._w26(context)

func _o26():
	if not _o6 or not _w59:
		return
	
	var _q88 = _o6._p53()
	if _q88.is_empty():
		return
	
	_w59.insert_text_at_caret(_q88)
	
	_o6._a53()
	
func _k77():
	if _o6:
		_o6._a53()
		_u50 = Time.get_ticks_msec()
		_r4 = false

func _c62():
	if not _w59 or not _o6:
		return
	
	var _m70 = _w59.get_caret_line()
	var _v28 = _w59.get_caret_column()
	
	if _m70 != _a57 and _o6._t35():
		_k77()

	elif abs(_v28 - _j52) > 5 and _o6._t35():
		_k77()
	
	_a57 = _m70
	_j52 = _v28

func _z28():
	if _o6 and _o6._t35():
		_k77()

func _l68():
	if _k39:
		_k39._k63()
		_k39 = null
	
	if _o6:
		_o6._k63()
		_o6 = null
	
	if _w59:
		if _w59.gui_input.is_connected(_d76):
			_w59.gui_input.disconnect(_d76)
		if _w59.caret_changed.is_connected(_c62):
			_w59.caret_changed.disconnect(_c62)
		if _w59.text_changed.is_connected(_z28):
			_w59.text_changed.disconnect(_z28)
	
	_w59 = null

func set_enabled(enabled: bool):
	_u74 = enabled
	if not enabled:
		_l68()
	else:
		_y14()

func set_mode(mode: String):
	_v68 = mode

	_y14()

func set_delay(_p78: int):
	_a85 = _p78
	if _k39:
		_k39.set_delay(_p78)

func _x6(_g70: int):
	_g75 = _g70

func _k63():
	_l68()
	
	if _b50 and _b50.editor_script_changed.is_connected(_u14):
		_b50.editor_script_changed.disconnect(_u14)
	
	if _a12 and _a12._b67.is_connected(_l49):
		_a12._b67.disconnect(_l49)

