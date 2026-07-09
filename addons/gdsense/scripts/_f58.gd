@tool
class_name _i78
extends RefCounted
signal _u35(_l5: String, path: String)
enum _k11 {
	_y70,              
	_j57, 
	_i46        
}
const _f60: Array[String] = ["@file", "@selection", "@openscript", "@scene", "@node"]
const _k28: Array[String] = ["@file", "@scene"]
const _i84: int = 12
const _o70: int = 60
var _p65: _k11 = _k11._y70
var _z58: TextEdit
var _u18: Control
var _w27: EditorInterface
var _o96: _q98
var _y47: _n48
var _a9: String = ""  
var _i9: int = -1        
var _u80: int = -1      
var _d38: String = ""        
func initialize(_b37: TextEdit, parent: Control, _d84: EditorInterface) -> void:
	_z58 = _b37
	_u18 = parent
	_w27 = _d84
	_y47 = _n48.new()
	_o96 = _q98.new()
	_o96.initialize(_d84)
	_o96.item_selected.connect(_r3)
	_o96._j73.connect(_d64)
	_u18.add_child(_o96)
	_z58.text_changed.connect(_d6)
	_z58.caret_changed.connect(_j65)
	_d38 = _z58.text
func _q60() -> void:
	if _o96 and is_instance_valid(_o96):
		_o96._q60()
		_o96.queue_free()
		_o96 = null
	if _z58 and is_instance_valid(_z58):
		if _z58.text_changed.is_connected(_d6):
			_z58.text_changed.disconnect(_d6)
		if _z58.caret_changed.is_connected(_j65):
			_z58.caret_changed.disconnect(_j65)
func _v70(_x58: InputEvent) -> bool:
	if _p65 == _k11._y70:
		return false
	if not _x58 is InputEventKey:
		return false
	var _d96 = _x58 as InputEventKey
	if not _d96.pressed:
		return false
	match _d96.keycode:
		KEY_UP:
			_o96._h13()
			return true
		KEY_DOWN:
			_o96._x33()
			return true
		KEY_ENTER, KEY_KP_ENTER:
			_o96._f76()
			return true
		KEY_TAB:
			_o96._f76()
			return true
		KEY_ESCAPE:
			_z99()
			return true
		_:
			return false
func _d6() -> void:
	var _r45 = _z58.text
	var _c88 = _z58.get_caret_line()
	var caret_column = _z58.get_caret_column()
	match _p65:
		_k11._y70:
			var _v43 = _i52(_c88, caret_column)
			if _v43 != "":
				_g40(_v43, _c88, caret_column)
			elif _i74(_r45, _c88, caret_column):
				_t84()
		_k11._j57:
			var _x96 = _r40(_c88, caret_column)
			if _x96 == null:
				_z99()
			else:
				_c6(_x96)
		_k11._i46:
			var _x96 = _m4(_c88, caret_column)
			if _x96 == null:
				_z99()
			else:
				_z30(_x96)
	_d38 = _r45
func _j65() -> void:
	if _p65 == _k11._y70:
		return
	var _c88 = _z58.get_caret_line()
	var caret_column = _z58.get_caret_column()
	if _c88 != _i9:
		_z99()
		return
	if caret_column < _u80:
		_z99()
func _i74(text: String, line: int, _j10: int) -> bool:
	var _f62 = _z58.get_line(line)
	if _j10 == 0:
		return false
	var _g10 = _f62[_j10 - 1] if _j10 <= _f62.length() else ""
	if _g10 != "@":
		return false
	if _j10 >= 2:
		var _p30 = _f62[_j10 - 2] if _j10 - 1 < _f62.length() else ""
		if _p30.is_valid_identifier():
			return false
	if _j10 < _f62.length():
		var _m10 = _f62[_j10]
		if _m10 != "" and _m10 != " ":
			var _j61 = _f62.substr(_j10 - 1)
			for _i34 in _f60:
				if _j61.begins_with(_i34):
					return false
	return true
func _i52(line: int, _j10: int) -> String:
	var _f62 = _z58.get_line(line)
	if _j10 < 6:  
		return ""
	var _b40 = _f62.substr(0, _j10)
	for _i34 in _k28:
		var _y99 = _i34 + " "  
		if _b40.ends_with(_y99):
			var _o25 = _j10 - _y99.length()
			if _o25 == 0:
				return _i34
			var _g10 = _f62[_o25 - 1]
			if _g10 == " " or _g10 == "\t" or _g10 == "\n":
				return _i34
	return ""
func _g40(_l5: String, line: int, _j10: int) -> void:
	_a9 = _l5
	_p65 = _k11._i46
	var _k73 = _l5.length() + 1  
	_i9 = line
	_u80 = _j10 - _k73 + 1  
	var _l57 = "scene" if _l5 == "@scene" else "all"
	_o12(_l57)
func _r40(line: int, _j10: int) -> Variant:
	if line != _i9:
		return null
	if _j10 < _u80:
		return null
	var _f62 = _z58.get_line(line)
	var start = _u80  
	var _c77 = _j10
	if start > _f62.length() or _c77 > _f62.length():
		return ""
	return _f62.substr(start, _c77 - start)
func _m4(line: int, _j10: int) -> Variant:
	if line != _i9:
		return null
	var _f62 = _z58.get_line(line)
	var _p96 = _u80 - 1 + _a9.length()
	while _p96 < _f62.length() and _f62[_p96] == " ":
		_p96 += 1
	if _j10 < _p96:
		return null
	return _f62.substr(_p96, _j10 - _p96)
func _t84() -> void:
	_p65 = _k11._j57
	_i9 = _z58.get_caret_line()
	_u80 = _z58.get_caret_column()  
	var _k15 = _i51(_q98._v39)
	_o96._b59(_k15, _f60.duplicate(), _q98._v39)
func _o12(_l57: String) -> void:
	if _p65 != _k11._i46:
		return
	var _w56 = _y47._v79("", _l57)
	var _k15 = _i51(_q98._k40)
	_o96._b59(_k15, _w56, _q98._k40)
func _c6(_x96: String) -> void:
	var _q41 = _x96.to_lower()
	for _i34 in _k28:
		var _g12 = _i34.substr(1)  
		if _q41 == _g12 + " " or _q41.begins_with(_g12 + " "):
			_a9 = _i34
			_p65 = _k11._i46
			var _l57 = "scene" if _i34 == "@scene" else "all"
			_o12.call_deferred(_l57)
			return
	var _b23: Array[String] = []
	for _i34 in _f60:
		var _g12 = _i34.substr(1)  
		if _g12.begins_with(_q41) or _i34.to_lower().begins_with("@" + _q41):
			_b23.append(_i34)
	if _b23.is_empty():
		_z99()
	else:
		_o96._b59(_i51(_q98._v39), _b23, _q98._v39)
func _z30(_x96: String) -> void:
	var _l57 = "scene" if _a9 == "@scene" else "all"
	var _w56 = _y47._v79(_x96, _l57)
	if _w56.is_empty() and not _x96.is_empty():
		_o96._h34(_x96)
	elif _w56.is_empty():
		pass
	else:
		_o96._b59(_i51(_q98._k40), _w56, _q98._k40)
func _r3(_v92: String) -> void:
	match _p65:
		_k11._j57:
			if _v92 in _k28:
				_a9 = _v92
				_p65 = _k11._i46
				_v67(_v92 + " ")
				_o12.call_deferred("scene" if _v92 == "@scene" else "all")
			else:
				_v67(_v92 + " ")
				_z99()
				_u35.emit(_v92, "")
		_k11._i46:
			var _w6 = _a9 + " " + _v92
			_o60(_w6 + " ")
			_z99()
			_u35.emit(_a9, _v92)
func _d64() -> void:
	_p65 = _k11._y70
	_a9 = ""
	_i9 = -1
	_u80 = -1
func _z99() -> void:
	_o96._g26()
	_p65 = _k11._y70
	_a9 = ""
	_i9 = -1
	_u80 = -1
func _v67(text: String) -> void:
	var _f62 = _z58.get_line(_i9)
	var before = _f62.substr(0, _u80 - 1)  
	var _t8 = _f62.substr(_z58.get_caret_column())
	var _r44 = before + text + _t8
	_z58.set_line(_i9, _r44)
	_z58.set_caret_line(_i9)
	_z58.set_caret_column(before.length() + text.length())
func _o60(text: String) -> void:
	var _f62 = _z58.get_line(_i9)
	var before = _f62.substr(0, _u80 - 1)  
	var _t8 = _f62.substr(_z58.get_caret_column())
	var _r44 = before + text + _t8
	_z58.set_line(_i9, _r44)
	_z58.set_caret_line(_i9)
	_z58.set_caret_column(before.length() + text.length())
func _b8() -> int:
	if _w27:
		var theme = _w27.get_editor_theme()
		if theme:
			var _e31 = theme.get_font_size("main_size", "EditorFonts")
			if _e31 > 0:
				return _e31
	return 14  
func _i51(_s61: int = _q98._k40) -> Vector2:
	var _e80 = _b8()
	var _b30 = float(_e80) / 14.0
	var _f4 = int(_i84 * _b30)
	var _c86 = _e80 * 2
	var _y77 = int(_q98._q69 * _b30)
	var _t78 = _s61 * _c86 + _y77 * 2
	var _z27 = _u18.get_node_or_null("%_c33") if _u18 else null
	var _p72: float
	if _z27:
		_p72 = _z27.position.y + _z27.size.y
	else:
		var _j87 = _z58.position.y if _z58 else 1800.0
		var _q97 = int(_o70 * _b30)
		_p72 = _j87 - _q97
	var _k69 = _p72 - _t78
	return Vector2(_f4, _k69)
func is_active() -> bool:
	return _p65 != _k11._y70
