@tool
class_name _w4
extends RefCounted
signal _l75(_y59: String, path: String)
enum _r24 {
	_u38,              
	_j22, 
	_k34        
}
const _h20: Array[String] = ["@file", "@selection", "@openscript", "@scene", "@node"]
const _h58: Array[String] = ["@file", "@scene"]
const _c18: int = 12
const _r77: int = 60
var _b73: _r24 = _r24._u38
var _c51: TextEdit
var _g44: Control
var _b72: EditorInterface
var _k72: _f81
var _f49: _i29
var _d36: String = ""  
var _u93: int = -1        
var _y86: int = -1      
var _z54: String = ""        
func initialize(_b18: TextEdit, parent: Control, _o10: EditorInterface) -> void:
	_c51 = _b18
	_g44 = parent
	_b72 = _o10
	_f49 = _i29.new()
	_k72 = _f81.new()
	_k72.initialize(_o10)
	_k72.item_selected.connect(_m3)
	_k72._x52.connect(_t79)
	_g44.add_child(_k72)
	_c51.text_changed.connect(_w3)
	_c51.caret_changed.connect(_x61)
	_z54 = _c51.text
func _h41() -> void:
	if _k72 and is_instance_valid(_k72):
		_k72._h41()
		_k72.queue_free()
		_k72 = null
	if _c51 and is_instance_valid(_c51):
		if _c51.text_changed.is_connected(_w3):
			_c51.text_changed.disconnect(_w3)
		if _c51.caret_changed.is_connected(_x61):
			_c51.caret_changed.disconnect(_x61)
func _z16(_v53: InputEvent) -> bool:
	if _b73 == _r24._u38:
		return false
	if not _v53 is InputEventKey:
		return false
	var _j58 = _v53 as InputEventKey
	if not _j58.pressed:
		return false
	match _j58.keycode:
		KEY_UP:
			_k72._q57()
			return true
		KEY_DOWN:
			_k72._r30()
			return true
		KEY_ENTER, KEY_KP_ENTER:
			_k72._w92()
			return true
		KEY_TAB:
			_k72._w92()
			return true
		KEY_ESCAPE:
			_t24()
			return true
		_:
			return false
func _w3() -> void:
	var _r34 = _c51.text
	var _e26 = _c51.get_caret_line()
	var caret_column = _c51.get_caret_column()
	match _b73:
		_r24._u38:
			var _t6 = _b36(_e26, caret_column)
			if _t6 != "":
				_t14(_t6, _e26, caret_column)
			elif _m81(_r34, _e26, caret_column):
				_r81()
		_r24._j22:
			var _k81 = _p90(_e26, caret_column)
			if _k81 == null:
				_t24()
			else:
				_a41(_k81)
		_r24._k34:
			var _k81 = _m36(_e26, caret_column)
			if _k81 == null:
				_t24()
			else:
				_v29(_k81)
	_z54 = _r34
func _x61() -> void:
	if _b73 == _r24._u38:
		return
	var _e26 = _c51.get_caret_line()
	var caret_column = _c51.get_caret_column()
	if _e26 != _u93:
		_t24()
		return
	if caret_column < _y86:
		_t24()
func _m81(text: String, line: int, _d31: int) -> bool:
	var _n45 = _c51.get_line(line)
	if _d31 == 0:
		return false
	var _d71 = _n45[_d31 - 1] if _d31 <= _n45.length() else ""
	if _d71 != "@":
		return false
	if _d31 >= 2:
		var _m73 = _n45[_d31 - 2] if _d31 - 1 < _n45.length() else ""
		if _m73.is_valid_identifier():
			return false
	if _d31 < _n45.length():
		var _y36 = _n45[_d31]
		if _y36 != "" and _y36 != " ":
			var _g14 = _n45.substr(_d31 - 1)
			for _j88 in _h20:
				if _g14.begins_with(_j88):
					return false
	return true
func _b36(line: int, _d31: int) -> String:
	var _n45 = _c51.get_line(line)
	if _d31 < 6:  
		return ""
	var _u100 = _n45.substr(0, _d31)
	for _j88 in _h58:
		var _a45 = _j88 + " "  
		if _u100.ends_with(_a45):
			var _l9 = _d31 - _a45.length()
			if _l9 == 0:
				return _j88
			var _d71 = _n45[_l9 - 1]
			if _d71 == " " or _d71 == "\t" or _d71 == "\n":
				return _j88
	return ""
func _t14(_y59: String, line: int, _d31: int) -> void:
	_d36 = _y59
	_b73 = _r24._k34
	var _q59 = _y59.length() + 1  
	_u93 = line
	_y86 = _d31 - _q59 + 1  
	var _y70 = "scene" if _y59 == "@scene" else "all"
	_c1(_y70)
func _p90(line: int, _d31: int) -> Variant:
	if line != _u93:
		return null
	if _d31 < _y86:
		return null
	var _n45 = _c51.get_line(line)
	var start = _y86  
	var _e34 = _d31
	if start > _n45.length() or _e34 > _n45.length():
		return ""
	return _n45.substr(start, _e34 - start)
func _m36(line: int, _d31: int) -> Variant:
	if line != _u93:
		return null
	var _n45 = _c51.get_line(line)
	var _t51 = _y86 - 1 + _d36.length()
	while _t51 < _n45.length() and _n45[_t51] == " ":
		_t51 += 1
	if _d31 < _t51:
		return null
	return _n45.substr(_t51, _d31 - _t51)
func _r81() -> void:
	_b73 = _r24._j22
	_u93 = _c51.get_caret_line()
	_y86 = _c51.get_caret_column()  
	var _b3 = _d61(_f81._x20)
	_k72._l47(_b3, _h20.duplicate(), _f81._x20)
func _c1(_y70: String) -> void:
	if _b73 != _r24._k34:
		return
	var _u72 = _f49._e72("", _y70)
	var _b3 = _d61(_f81._v4)
	_k72._l47(_b3, _u72, _f81._v4)
func _a41(_k81: String) -> void:
	var _p21 = _k81.to_lower()
	for _j88 in _h58:
		var _f77 = _j88.substr(1)  
		if _p21 == _f77 + " " or _p21.begins_with(_f77 + " "):
			_d36 = _j88
			_b73 = _r24._k34
			var _y70 = "scene" if _j88 == "@scene" else "all"
			_c1.call_deferred(_y70)
			return
	var _v10: Array[String] = []
	for _j88 in _h20:
		var _f77 = _j88.substr(1)  
		if _f77.begins_with(_p21) or _j88.to_lower().begins_with("@" + _p21):
			_v10.append(_j88)
	if _v10.is_empty():
		_t24()
	else:
		_k72._l47(_d61(_f81._x20), _v10, _f81._x20)
func _v29(_k81: String) -> void:
	var _y70 = "scene" if _d36 == "@scene" else "all"
	var _u72 = _f49._e72(_k81, _y70)
	if _u72.is_empty() and not _k81.is_empty():
		_k72._o52(_k81)
	elif _u72.is_empty():
		pass
	else:
		_k72._l47(_d61(_f81._v4), _u72, _f81._v4)
func _m3(_o18: String) -> void:
	match _b73:
		_r24._j22:
			if _o18 in _h58:
				_d36 = _o18
				_b73 = _r24._k34
				_b79(_o18 + " ")
				_c1.call_deferred("scene" if _o18 == "@scene" else "all")
			else:
				_b79(_o18 + " ")
				_t24()
				_l75.emit(_o18, "")
		_r24._k34:
			var _t75 = _d36 + " " + _o18
			_l15(_t75 + " ")
			_t24()
			_l75.emit(_d36, _o18)
func _t79() -> void:
	_b73 = _r24._u38
	_d36 = ""
	_u93 = -1
	_y86 = -1
func _t24() -> void:
	_k72._p10()
	_b73 = _r24._u38
	_d36 = ""
	_u93 = -1
	_y86 = -1
func _b79(text: String) -> void:
	var _n45 = _c51.get_line(_u93)
	var before = _n45.substr(0, _y86 - 1)  
	var _s35 = _n45.substr(_c51.get_caret_column())
	var _i80 = before + text + _s35
	_c51.set_line(_u93, _i80)
	_c51.set_caret_line(_u93)
	_c51.set_caret_column(before.length() + text.length())
func _l15(text: String) -> void:
	var _n45 = _c51.get_line(_u93)
	var before = _n45.substr(0, _y86 - 1)  
	var _s35 = _n45.substr(_c51.get_caret_column())
	var _i80 = before + text + _s35
	_c51.set_line(_u93, _i80)
	_c51.set_caret_line(_u93)
	_c51.set_caret_column(before.length() + text.length())
func _k97() -> int:
	if _b72:
		var theme = _b72.get_editor_theme()
		if theme:
			var _a72 = theme.get_font_size("main_size", "EditorFonts")
			if _a72 > 0:
				return _a72
	return 14  
func _d61(_a71: int = _f81._v4) -> Vector2:
	var _q44 = _k97()
	var _u53 = float(_q44) / 14.0
	var _d24 = int(_c18 * _u53)
	var _z72 = _q44 * 2
	var _o87 = int(_f81._c40 * _u53)
	var _y37 = _a71 * _z72 + _o87 * 2
	var _s63 = _g44.get_node_or_null("%_c80") if _g44 else null
	var _f46: float
	if _s63:
		_f46 = _s63.position.y + _s63.size.y
	else:
		var _v70 = _c51.position.y if _c51 else 1800.0
		var _q97 = int(_r77 * _u53)
		_f46 = _v70 - _q97
	var _u33 = _f46 - _y37
	return Vector2(_d24, _u33)
func is_active() -> bool:
	return _b73 != _r24._u38
