@tool
extends RefCounted
class_name _b81

var _s4: EditorPlugin
var _u56: _b92
var _j30: ScriptEditor
var _i64: CodeEdit
var _d1: _g85
var _v33: _v45
var _n25: _o13

var _l93: bool = true
var _e41: int = 800
var _s47: int = 150
var _u75: String = "automatic"  
var _r56: int = 3
var _n65: int = 0
var _c4: bool = false
var _v52: int = -1
var _v15: int = -1

func _init(_a97: EditorPlugin, _t46: _b92):
	_s4 = _a97
	_u56 = _t46
	_j30 = _s4.get_editor_interface().get_script_editor()
	_v33 = _v45.new(_j30)
	
	if _u56:
		if not _u56._s23.is_connected(_d66):
			_u56._s23.connect(_d66)
	
	_i78()

func _i78():
	if _j30:
		if not _j30.editor_script_changed.is_connected(_f64):
			_j30.editor_script_changed.connect(_f64)
		
		_c37()

func _f64(script: Script):
	_c37()

func _c37():
	_s74()
	
	_i64 = _f67()
	
	if _i64 and _l93:
		if _u75 == "automatic":
			_d1 = _g85.new(_i64)
			_d1.set_delay(_e41)
			_d1._l10.connect(_o75)
			_d1._g47()
		
		_n25 = _o13.new(_i64)
		
		if not _i64.gui_input.is_connected(_e72):
			_i64.gui_input.connect(_e72)
		
		if not _i64.caret_changed.is_connected(_m5):
			_i64.caret_changed.connect(_m5)
		if not _i64.text_changed.is_connected(_j1):
			_i64.text_changed.connect(_j1)

func _f67() -> CodeEdit:
	var _j37 = _j30.get_current_editor()
	if not _j37:
		return null
	
	return _x16(_j37)

func _x16(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node
	
	for _j75 in node.get_children():
		var _v42 = _x16(_j75)
		if _v42:
			return _v42
	
	return null

func _o75():
	if not _i64 or not _l93:
		return
	
	if _u75 == "manual":
		return
	
	if Time.get_ticks_msec() - _n65 < 2000:
		return
	
	if not _f51():
		return
	
	var context = _v33._j14(_i64)
	
	if _u56:
		_u56._x39(context)

func _f51() -> bool:
	if _v33.is_in_comment(_i64):
		return false
	
	if _v33.is_in_string(_i64):
		return false
	
	if not _v33._i68(_i64):
		return false
	
	if not _v33._h82(_i64):
		var line = _v33.get_current_line(_i64)
		var _x50 = line.strip_edges()
		if _x50.length() < _r56:
			return false
	
	var line = _v33.get_current_line(_i64)
	var _u87 = _i64.get_caret_column()
	var _j51 = line.substr(_u87).strip_edges()
	
	if _j51.length() > 0:
		return false
	
	return true

func _d66(_p72: String, _v89: int):
	if not _n25 or not _i64:
		return
	
	if _p72.length() > _s47:
		_p72 = _p72.substr(0, _s47)
	
	_n25._z36(_p72)
	_c4 = true
	
	_v52 = _i64.get_caret_line()
	_v15 = _i64.get_caret_column()
	
func _e72(_p91: InputEvent):
	if _p91 is InputEventKey and _p91.pressed:
		if _p91.keycode == KEY_SPACE and _p91.ctrl_pressed:
			_k92()
			_i64.accept_event()
			return
		
		if _n25 and _n25._m66():
			match _p91.keycode:
				KEY_TAB:
					_a61()
					_i64.accept_event()
				KEY_ESCAPE:
					_d94()
					_i64.accept_event()
				_:
					_d94()

func _k92():
	if not _i64 or not _l93:
		return
	
	if _d1:
		_d1._h93()
	
	var context = _v33._j14(_i64)
	
	if _u56:
		_u56._x39(context)

func _a61():
	if not _n25 or not _i64:
		return
	
	var _p72 = _n25._i29()
	if _p72.is_empty():
		return
	
	_i64.insert_text_at_caret(_p72)
	
	_n25._n5()
	
func _d94():
	if _n25:
		_n25._n5()
		_n65 = Time.get_ticks_msec()
		_c4 = false

func _m5():
	if not _i64 or not _n25:
		return
	
	var _r42 = _i64.get_caret_line()
	var _z59 = _i64.get_caret_column()
	
	if _r42 != _v52 and _n25._m66():
		_d94()

	elif abs(_z59 - _v15) > 5 and _n25._m66():
		_d94()
	
	_v52 = _r42
	_v15 = _z59

func _j1():
	if _n25 and _n25._m66():
		_d94()

func _s74():
	if _d1:
		_d1._o76()
		_d1 = null
	
	if _n25:
		_n25._o76()
		_n25 = null
	
	if _i64:
		if _i64.gui_input.is_connected(_e72):
			_i64.gui_input.disconnect(_e72)
		if _i64.caret_changed.is_connected(_m5):
			_i64.caret_changed.disconnect(_m5)
		if _i64.text_changed.is_connected(_j1):
			_i64.text_changed.disconnect(_j1)
	
	_i64 = null

func set_enabled(enabled: bool):
	_l93 = enabled
	if not enabled:
		_s74()
	else:
		_c37()

func set_mode(mode: String):
	_u75 = mode

	_c37()

func set_delay(_k39: int):
	_e41 = _k39
	if _d1:
		_d1.set_delay(_k39)

func _p56(_p31: int):
	_r56 = _p31

func _o76():
	_s74()
	
	if _j30 and _j30.editor_script_changed.is_connected(_f64):
		_j30.editor_script_changed.disconnect(_f64)
	
	if _u56 and _u56._s23.is_connected(_d66):
		_u56._s23.disconnect(_d66)

