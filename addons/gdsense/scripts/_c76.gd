@tool
class_name _y58
extends RefCounted
signal _z27(_u54: String, path: String)
enum _z49 {
	_e85,              
	_j97, 
	_g62        
}
const _e41: Array[String] = ["@file", "@selection", "@openscript", "@scene", "@node"]
const _g97: Array[String] = ["@file", "@scene"]
const _e7: int = 12
const _x64: int = 60
var _e66: _z49 = _z49._e85
var _o77: TextEdit
var _o27: Control
var _f21: EditorInterface
var _o80: _y17
var _i3: _l47
var _p30: String = ""  
var _o15: int = -1        
var _v9: int = -1      
var _h78: String = ""        
func initialize(_w19: TextEdit, parent: Control, _i13: EditorInterface) -> void:
	_o77 = _w19
	_o27 = parent
	_f21 = _i13
	_i3 = _l47.new()
	_o80 = _y17.new()
	_o80.initialize(_i13)
	_o80.item_selected.connect(_v53)
	_o80._g21.connect(_w59)
	_o27.add_child(_o80)
	_o77.text_changed.connect(_g28)
	_o77.caret_changed.connect(_k55)
	_h78 = _o77.text
func _o36() -> void:
	if _o80 and is_instance_valid(_o80):
		_o80._o36()
		_o80.queue_free()
		_o80 = null
	if _o77 and is_instance_valid(_o77):
		if _o77.text_changed.is_connected(_g28):
			_o77.text_changed.disconnect(_g28)
		if _o77.caret_changed.is_connected(_k55):
			_o77.caret_changed.disconnect(_k55)
func _x83(_x75: InputEvent) -> bool:
	if _e66 == _z49._e85:
		return false
	if not _x75 is InputEventKey:
		return false
	var _d64 = _x75 as InputEventKey
	if not _d64.pressed:
		return false
	match _d64.keycode:
		KEY_UP:
			_o80._s31()
			return true
		KEY_DOWN:
			_o80._j11()
			return true
		KEY_ENTER, KEY_KP_ENTER:
			_o80._m67()
			return true
		KEY_TAB:
			_o80._m67()
			return true
		KEY_ESCAPE:
			_o33()
			return true
		_:
			return false
func _g28() -> void:
	var _d86 = _o77.text
	var _p99 = _o77.get_caret_line()
	var caret_column = _o77.get_caret_column()
	match _e66:
		_z49._e85:
			var _j7 = _k86(_p99, caret_column)
			if _j7 != "":
				_r48(_j7, _p99, caret_column)
			elif _g5(_d86, _p99, caret_column):
				_u63()
		_z49._j97:
			var _q57 = _l52(_p99, caret_column)
			if _q57 == null:
				_o33()
			else:
				_q69(_q57)
		_z49._g62:
			var _q57 = _k39(_p99, caret_column)
			if _q57 == null:
				_o33()
			else:
				_w18(_q57)
	_h78 = _d86
func _k55() -> void:
	if _e66 == _z49._e85:
		return
	var _p99 = _o77.get_caret_line()
	var caret_column = _o77.get_caret_column()
	if _p99 != _o15:
		_o33()
		return
	if caret_column < _v9:
		_o33()
func _g5(text: String, line: int, _o73: int) -> bool:
	var _i71 = _o77.get_line(line)
	if _o73 == 0:
		return false
	var _e37 = _i71[_o73 - 1] if _o73 <= _i71.length() else ""
	if _e37 != "@":
		return false
	if _o73 >= 2:
		var _h92 = _i71[_o73 - 2] if _o73 - 1 < _i71.length() else ""
		if _h92.is_valid_identifier():
			return false
	if _o73 < _i71.length():
		var _y51 = _i71[_o73]
		if _y51 != "" and _y51 != " ":
			var _h8 = _i71.substr(_o73 - 1)
			for _q49 in _e41:
				if _h8.begins_with(_q49):
					return false
	return true
func _k86(line: int, _o73: int) -> String:
	var _i71 = _o77.get_line(line)
	if _o73 < 6:  
		return ""
	var _i77 = _i71.substr(0, _o73)
	for _q49 in _g97:
		var _s76 = _q49 + " "  
		if _i77.ends_with(_s76):
			var _i19 = _o73 - _s76.length()
			if _i19 == 0:
				return _q49
			var _e37 = _i71[_i19 - 1]
			if _e37 == " " or _e37 == "\t" or _e37 == "\n":
				return _q49
	return ""
func _r48(_u54: String, line: int, _o73: int) -> void:
	_p30 = _u54
	_e66 = _z49._g62
	var _a23 = _u54.length() + 1  
	_o15 = line
	_v9 = _o73 - _a23 + 1  
	var _q84 = "scene" if _u54 == "@scene" else "all"
	_y65(_q84)
func _l52(line: int, _o73: int) -> Variant:
	if line != _o15:
		return null
	if _o73 < _v9:
		return null
	var _i71 = _o77.get_line(line)
	var start = _v9  
	var _f66 = _o73
	if start > _i71.length() or _f66 > _i71.length():
		return ""
	return _i71.substr(start, _f66 - start)
func _k39(line: int, _o73: int) -> Variant:
	if line != _o15:
		return null
	var _i71 = _o77.get_line(line)
	var _q33 = _v9 - 1 + _p30.length()
	while _q33 < _i71.length() and _i71[_q33] == " ":
		_q33 += 1
	if _o73 < _q33:
		return null
	return _i71.substr(_q33, _o73 - _q33)
func _u63() -> void:
	_e66 = _z49._j97
	_o15 = _o77.get_caret_line()
	_v9 = _o77.get_caret_column()  
	var _i26 = _n80(_y17._l51)
	_o80._e94(_i26, _e41.duplicate(), _y17._l51)
func _y65(_q84: String) -> void:
	if _e66 != _z49._g62:
		return
	var _s82 = _i3._y82("", _q84)
	var _i26 = _n80(_y17._l30)
	_o80._e94(_i26, _s82, _y17._l30)
func _q69(_q57: String) -> void:
	var _j5 = _q57.to_lower()
	for _q49 in _g97:
		var _p84 = _q49.substr(1)  
		if _j5 == _p84 + " " or _j5.begins_with(_p84 + " "):
			_p30 = _q49
			_e66 = _z49._g62
			var _q84 = "scene" if _q49 == "@scene" else "all"
			_y65.call_deferred(_q84)
			return
	var _q70: Array[String] = []
	for _q49 in _e41:
		var _p84 = _q49.substr(1)  
		if _p84.begins_with(_j5) or _q49.to_lower().begins_with("@" + _j5):
			_q70.append(_q49)
	if _q70.is_empty():
		_o33()
	else:
		_o80._e94(_n80(_y17._l51), _q70, _y17._l51)
func _w18(_q57: String) -> void:
	var _q84 = "scene" if _p30 == "@scene" else "all"
	var _s82 = _i3._y82(_q57, _q84)
	if _s82.is_empty() and not _q57.is_empty():
		_o80._b56(_q57)
	elif _s82.is_empty():
		pass
	else:
		_o80._e94(_n80(_y17._l30), _s82, _y17._l30)
func _v53(_s38: String) -> void:
	match _e66:
		_z49._j97:
			if _s38 in _g97:
				_p30 = _s38
				_e66 = _z49._g62
				_l68(_s38 + " ")
				_y65.call_deferred("scene" if _s38 == "@scene" else "all")
			else:
				_l68(_s38 + " ")
				_o33()
				_z27.emit(_s38, "")
		_z49._g62:
			var _h64 = _p30 + " " + _s38
			_c1(_h64 + " ")
			_o33()
			_z27.emit(_p30, _s38)
func _w59() -> void:
	_e66 = _z49._e85
	_p30 = ""
	_o15 = -1
	_v9 = -1
func _o33() -> void:
	_o80._x36()
	_e66 = _z49._e85
	_p30 = ""
	_o15 = -1
	_v9 = -1
func _l68(text: String) -> void:
	var _i71 = _o77.get_line(_o15)
	var before = _i71.substr(0, _v9 - 1)  
	var _b73 = _i71.substr(_o77.get_caret_column())
	var _v25 = before + text + _b73
	_o77.set_line(_o15, _v25)
	_o77.set_caret_line(_o15)
	_o77.set_caret_column(before.length() + text.length())
func _c1(text: String) -> void:
	var _i71 = _o77.get_line(_o15)
	var before = _i71.substr(0, _v9 - 1)  
	var _b73 = _i71.substr(_o77.get_caret_column())
	var _v25 = before + text + _b73
	_o77.set_line(_o15, _v25)
	_o77.set_caret_line(_o15)
	_o77.set_caret_column(before.length() + text.length())
func _v7() -> int:
	if _f21:
		var theme = _f21.get_editor_theme()
		if theme:
			var _t34 = theme.get_font_size("main_size", "EditorFonts")
			if _t34 > 0:
				return _t34
	return 14  
func _n80(_w31: int = _y17._l30) -> Vector2:
	var _f96 = _v7()
	var _e82 = float(_f96) / 14.0
	var _s44 = int(_e7 * _e82)
	var _y36 = _f96 * 2
	var _u11 = int(_y17._s75 * _e82)
	var _u86 = _w31 * _y36 + _u11 * 2
	var _i36 = _o27.get_node_or_null("%_g22") if _o27 else null
	var _f14: float
	if _i36:
		_f14 = _i36.position.y + _i36.size.y
	else:
		var _y23 = _o77.position.y if _o77 else 1800.0
		var _d10 = int(_x64 * _e82)
		_f14 = _y23 - _d10
	var _p73 = _f14 - _u86
	return Vector2(_s44, _p73)
func is_active() -> bool:
	return _e66 != _z49._e85
