@tool
class_name _a14
extends RefCounted
signal _z90(_k52: String, path: String)
enum _f40 {
	_a87,              
	_k24, 
	_y57        
}
const _a95: Array[String] = ["@file", "@selection", "@openscript", "@scene", "@node"]
const _h93: Array[String] = ["@file", "@scene"]
const _l66: int = 12
const _t70: int = 60
var _k67: _f40 = _f40._a87
var _s82: TextEdit
var _c35: Control
var _r15: EditorInterface
var _b65: _g64
var _e89: _m52
var _o98: String = ""  
var _w81: int = -1        
var _h3: int = -1      
var _g65: String = ""        
func initialize(_t40: TextEdit, parent: Control, _k71: EditorInterface) -> void:
	_s82 = _t40
	_c35 = parent
	_r15 = _k71
	_e89 = _m52.new()
	_b65 = _g64.new()
	_b65.initialize(_k71)
	_b65.item_selected.connect(_v12)
	_b65._b99.connect(_v42)
	_c35.add_child(_b65)
	_s82.text_changed.connect(_b45)
	_s82.caret_changed.connect(_l80)
	_g65 = _s82.text
func _u75() -> void:
	if _b65 and is_instance_valid(_b65):
		_b65._u75()
		_b65.queue_free()
		_b65 = null
	if _s82 and is_instance_valid(_s82):
		if _s82.text_changed.is_connected(_b45):
			_s82.text_changed.disconnect(_b45)
		if _s82.caret_changed.is_connected(_l80):
			_s82.caret_changed.disconnect(_l80)
func _s67(_t27: InputEvent) -> bool:
	if _k67 == _f40._a87:
		return false
	if not _t27 is InputEventKey:
		return false
	var _a64 = _t27 as InputEventKey
	if not _a64.pressed:
		return false
	match _a64.keycode:
		KEY_UP:
			_b65._i86()
			return true
		KEY_DOWN:
			_b65._w7()
			return true
		KEY_ENTER, KEY_KP_ENTER:
			_b65._q54()
			return true
		KEY_TAB:
			_b65._q54()
			return true
		KEY_ESCAPE:
			_v78()
			return true
		_:
			return false
func _b45() -> void:
	var _q92 = _s82.text
	var _t41 = _s82.get_caret_line()
	var caret_column = _s82.get_caret_column()
	match _k67:
		_f40._a87:
			var _p72 = _p28(_t41, caret_column)
			if _p72 != "":
				_k65(_p72, _t41, caret_column)
			elif _n41(_q92, _t41, caret_column):
				_k32()
		_f40._k24:
			var _g90 = _j34(_t41, caret_column)
			if _g90 == null:
				_v78()
			else:
				_x47(_g90)
		_f40._y57:
			var _g90 = _a12(_t41, caret_column)
			if _g90 == null:
				_v78()
			else:
				_c36(_g90)
	_g65 = _q92
func _l80() -> void:
	if _k67 == _f40._a87:
		return
	var _t41 = _s82.get_caret_line()
	var caret_column = _s82.get_caret_column()
	if _t41 != _w81:
		_v78()
		return
	if caret_column < _h3:
		_v78()
func _n41(text: String, line: int, _g88: int) -> bool:
	var _h39 = _s82.get_line(line)
	if _g88 == 0:
		return false
	var _v65 = _h39[_g88 - 1] if _g88 <= _h39.length() else ""
	if _v65 != "@":
		return false
	if _g88 >= 2:
		var _i70 = _h39[_g88 - 2] if _g88 - 1 < _h39.length() else ""
		if _i70.is_valid_identifier():
			return false
	if _g88 < _h39.length():
		var _j67 = _h39[_g88]
		if _j67 != "" and _j67 != " ":
			var _p70 = _h39.substr(_g88 - 1)
			for _z91 in _a95:
				if _p70.begins_with(_z91):
					return false
	return true
func _p28(line: int, _g88: int) -> String:
	var _h39 = _s82.get_line(line)
	if _g88 < 6:  
		return ""
	var _f50 = _h39.substr(0, _g88)
	for _z91 in _h93:
		var _j73 = _z91 + " "  
		if _f50.ends_with(_j73):
			var _m81 = _g88 - _j73.length()
			if _m81 == 0:
				return _z91
			var _v65 = _h39[_m81 - 1]
			if _v65 == " " or _v65 == "\t" or _v65 == "\n":
				return _z91
	return ""
func _k65(_k52: String, line: int, _g88: int) -> void:
	_o98 = _k52
	_k67 = _f40._y57
	var _z8 = _k52.length() + 1  
	_w81 = line
	_h3 = _g88 - _z8 + 1  
	var _a59 = "scene" if _k52 == "@scene" else "all"
	_o4(_a59)
func _j34(line: int, _g88: int) -> Variant:
	if line != _w81:
		return null
	if _g88 < _h3:
		return null
	var _h39 = _s82.get_line(line)
	var start = _h3  
	var _a75 = _g88
	if start > _h39.length() or _a75 > _h39.length():
		return ""
	return _h39.substr(start, _a75 - start)
func _a12(line: int, _g88: int) -> Variant:
	if line != _w81:
		return null
	var _h39 = _s82.get_line(line)
	var _n29 = _h3 - 1 + _o98.length()
	while _n29 < _h39.length() and _h39[_n29] == " ":
		_n29 += 1
	if _g88 < _n29:
		return null
	return _h39.substr(_n29, _g88 - _n29)
func _k32() -> void:
	_k67 = _f40._k24
	_w81 = _s82.get_caret_line()
	_h3 = _s82.get_caret_column()  
	var _r4 = _z71(_g64._w20)
	_b65._g20(_r4, _a95.duplicate(), _g64._w20)
func _o4(_a59: String) -> void:
	if _k67 != _f40._y57:
		return
	var _q72 = _e89._e26("", _a59)
	var _r4 = _z71(_g64._g49)
	_b65._g20(_r4, _q72, _g64._g49)
func _x47(_g90: String) -> void:
	var _s30 = _g90.to_lower()
	for _z91 in _h93:
		var _p46 = _z91.substr(1)  
		if _s30 == _p46 + " " or _s30.begins_with(_p46 + " "):
			_o98 = _z91
			_k67 = _f40._y57
			var _a59 = "scene" if _z91 == "@scene" else "all"
			_o4.call_deferred(_a59)
			return
	var _f9: Array[String] = []
	for _z91 in _a95:
		var _p46 = _z91.substr(1)  
		if _p46.begins_with(_s30) or _z91.to_lower().begins_with("@" + _s30):
			_f9.append(_z91)
	if _f9.is_empty():
		_v78()
	else:
		_b65._g20(_z71(_g64._w20), _f9, _g64._w20)
func _c36(_g90: String) -> void:
	var _a59 = "scene" if _o98 == "@scene" else "all"
	var _q72 = _e89._e26(_g90, _a59)
	if _q72.is_empty() and not _g90.is_empty():
		_b65._d7(_g90)
	elif _q72.is_empty():
		pass
	else:
		_b65._g20(_z71(_g64._g49), _q72, _g64._g49)
func _v12(_d48: String) -> void:
	match _k67:
		_f40._k24:
			if _d48 in _h93:
				_o98 = _d48
				_k67 = _f40._y57
				_i65(_d48 + " ")
				_o4.call_deferred("scene" if _d48 == "@scene" else "all")
			else:
				_i65(_d48 + " ")
				_v78()
				_z90.emit(_d48, "")
		_f40._y57:
			var _d73 = _o98 + " " + _d48
			_f11(_d73 + " ")
			_v78()
			_z90.emit(_o98, _d48)
func _v42() -> void:
	_k67 = _f40._a87
	_o98 = ""
	_w81 = -1
	_h3 = -1
func _v78() -> void:
	_b65._z77()
	_k67 = _f40._a87
	_o98 = ""
	_w81 = -1
	_h3 = -1
func _i65(text: String) -> void:
	var _h39 = _s82.get_line(_w81)
	var before = _h39.substr(0, _h3 - 1)  
	var _z80 = _h39.substr(_s82.get_caret_column())
	var _q34 = before + text + _z80
	_s82.set_line(_w81, _q34)
	_s82.set_caret_line(_w81)
	_s82.set_caret_column(before.length() + text.length())
func _f11(text: String) -> void:
	var _h39 = _s82.get_line(_w81)
	var before = _h39.substr(0, _h3 - 1)  
	var _z80 = _h39.substr(_s82.get_caret_column())
	var _q34 = before + text + _z80
	_s82.set_line(_w81, _q34)
	_s82.set_caret_line(_w81)
	_s82.set_caret_column(before.length() + text.length())
func _s98() -> int:
	if _r15:
		var theme = _r15.get_editor_theme()
		if theme:
			var _b87 = theme.get_font_size("main_size", "EditorFonts")
			if _b87 > 0:
				return _b87
	return 14  
func _z71(_a100: int = _g64._g49) -> Vector2:
	var _w21 = _s98()
	var _h37 = float(_w21) / 14.0
	var _a27 = int(_l66 * _h37)
	var _m60 = _w21 * 2
	var _v59 = int(_g64._n24 * _h37)
	var _e28 = _a100 * _m60 + _v59 * 2
	var _n54 = _c35.get_node_or_null("%_s74") if _c35 else null
	var _a83: float
	if _n54:
		_a83 = _n54.position.y + _n54.size.y
	else:
		var _d89 = _s82.position.y if _s82 else 1800.0
		var _t74 = int(_t70 * _h37)
		_a83 = _d89 - _t74
	var _a39 = _a83 - _e28
	return Vector2(_a27, _a39)
func is_active() -> bool:
	return _k67 != _f40._a87
