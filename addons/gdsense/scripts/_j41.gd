@tool
class_name _z51
extends RefCounted

signal _z1(_c38: String, path: String)

enum _d30 {
	_b6,              
	_w5, 
	_m84        
}

const _x49: Array[String] = ["@file", "@selection", "@openscript", "@scene", "@node"]

const _j8: Array[String] = ["@file", "@scene"]

const _t72: int = 12
const _m95: int = 60

var _m98: _d30 = _d30._b6
var _c12: TextEdit
var _i92: Control
var _z76: EditorInterface
var _k85: _c54
var _m45: _t8
var _q57: String = ""  
var _r45: int = -1        
var _l91: int = -1      
var _c1: String = ""        

func initialize(_h50: TextEdit, parent: Control, _i86: EditorInterface) -> void:
	_c12 = _h50
	_i92 = parent
	_z76 = _i86

	_m45 = _t8.new()

	_k85 = _c54.new()
	_k85.initialize(_i86)
	_k85.item_selected.connect(_w54)
	_k85._h83.connect(_n40)
	_i92.add_child(_k85)

	_c12.text_changed.connect(_j1)
	_c12.caret_changed.connect(_m5)

	_c1 = _c12.text

func _o76() -> void:
	if _k85 and is_instance_valid(_k85):
		_k85._o76()
		_k85.queue_free()
		_k85 = null

	if _c12 and is_instance_valid(_c12):
		if _c12.text_changed.is_connected(_j1):
			_c12.text_changed.disconnect(_j1)
		if _c12.caret_changed.is_connected(_m5):
			_c12.caret_changed.disconnect(_m5)

func _k49(_p91: InputEvent) -> bool:
	if _m98 == _d30._b6:
		return false

	if not _p91 is InputEventKey:
		return false

	var _m28 = _p91 as InputEventKey
	if not _m28.pressed:
		return false

	match _m28.keycode:
		KEY_UP:
			_k85._k22()
			return true
		KEY_DOWN:
			_k85._z32()
			return true
		KEY_ENTER, KEY_KP_ENTER:
			_k85._n92()
			return true
		KEY_TAB:
			_k85._n92()
			return true
		KEY_ESCAPE:
			_b50()
			return true
		_:
			return false

func _j1() -> void:
	var _u33 = _c12.text
	var _n63 = _c12.get_caret_line()
	var caret_column = _c12.get_caret_column()

	match _m98:
		_d30._b6:
			var _f75 = _o14(_n63, caret_column)
			if _f75 != "":
				_z81(_f75, _n63, caret_column)

			elif _e38(_u33, _n63, caret_column):
				_g32()

		_d30._w5:
			var _z58 = _y100(_n63, caret_column)
			if _z58 == null:
				_b50()
			else:
				_o73(_z58)

		_d30._m84:
			var _z58 = _f100(_n63, caret_column)
			if _z58 == null:
				_b50()
			else:
				_s20(_z58)

	_c1 = _u33

func _m5() -> void:
	if _m98 == _d30._b6:
		return

	var _n63 = _c12.get_caret_line()
	var caret_column = _c12.get_caret_column()

	if _n63 != _r45:
		_b50()
		return

	if caret_column < _l91:
		_b50()

func _e38(text: String, line: int, _u73: int) -> bool:
	var _h60 = _c12.get_line(line)

	if _u73 == 0:
		return false

	var _l82 = _h60[_u73 - 1] if _u73 <= _h60.length() else ""
	if _l82 != "@":
		return false

	if _u73 >= 2:
		var _k79 = _h60[_u73 - 2] if _u73 - 1 < _h60.length() else ""

		if _k79.is_valid_identifier():
			return false

	if _u73 < _h60.length():
		var _t99 = _h60[_u73]

		if _t99 != "" and _t99 != " ":
			var _t10 = _h60.substr(_u73 - 1)
			for _d73 in _x49:
				if _t10.begins_with(_d73):
					return false

	return true

func _o14(line: int, _u73: int) -> String:
	var _h60 = _c12.get_line(line)

	if _u73 < 6:  
		return ""

	var _s34 = _h60.substr(0, _u73)

	for _d73 in _j8:
		var _v48 = _d73 + " "  
		if _s34.ends_with(_v48):
			var _b62 = _u73 - _v48.length()
			if _b62 == 0:
				return _d73
			var _l82 = _h60[_b62 - 1]
			if _l82 == " " or _l82 == "\t" or _l82 == "\n":
				return _d73

	return ""

func _z81(_c38: String, line: int, _u73: int) -> void:
	_q57 = _c38
	_m98 = _d30._m84

	var _a12 = _c38.length() + 1  
	_r45 = line
	_l91 = _u73 - _a12 + 1  

	var _i73 = "scene" if _c38 == "@scene" else "all"
	_q78(_i73)

func _y100(line: int, _u73: int) -> Variant:
	if line != _r45:
		return null

	if _u73 < _l91:
		return null

	var _h60 = _c12.get_line(line)
	var start = _l91  
	var _u60 = _u73

	if start > _h60.length() or _u60 > _h60.length():
		return ""

	return _h60.substr(start, _u60 - start)

func _f100(line: int, _u73: int) -> Variant:
	if line != _r45:
		return null

	var _h60 = _c12.get_line(line)

	var _w36 = _l91 - 1 + _q57.length()

	while _w36 < _h60.length() and _h60[_w36] == " ":
		_w36 += 1

	if _u73 < _w36:
		return null

	return _h60.substr(_w36, _u73 - _w36)

func _g32() -> void:
	_m98 = _d30._w5
	_r45 = _c12.get_caret_line()
	_l91 = _c12.get_caret_column()  

	var _n86 = _u30(_c54._f58)
	_k85._i82(_n86, _x49.duplicate(), _c54._f58)

func _q78(_i73: String) -> void:
	if _m98 != _d30._m84:
		return

	var _h63 = _m45._j11("", _i73)

	var _n86 = _u30(_c54._z37)
	_k85._i82(_n86, _h63, _c54._z37)

func _o73(_z58: String) -> void:
	var _t54 = _z58.to_lower()

	for _d73 in _j8:
		var _g92 = _d73.substr(1)  
		if _t54 == _g92 + " " or _t54.begins_with(_g92 + " "):
			_q57 = _d73
			_m98 = _d30._m84
			var _i73 = "scene" if _d73 == "@scene" else "all"
			_q78.call_deferred(_i73)
			return

	var _z61: Array[String] = []
	for _d73 in _x49:
		var _g92 = _d73.substr(1)  
		if _g92.begins_with(_t54) or _d73.to_lower().begins_with("@" + _t54):
			_z61.append(_d73)

	if _z61.is_empty():
		_b50()
	else:
		_k85._i82(_u30(_c54._f58), _z61, _c54._f58)

func _s20(_z58: String) -> void:
	var _i73 = "scene" if _q57 == "@scene" else "all"
	var _h63 = _m45._j11(_z58, _i73)

	if _h63.is_empty() and not _z58.is_empty():
		_k85._x7(_z58)
	elif _h63.is_empty():
		pass

	else:
		_k85._i82(_u30(_c54._z37), _h63, _c54._z37)

func _w54(_o32: String) -> void:
	match _m98:
		_d30._w5:
			if _o32 in _j8:
				_q57 = _o32

				_m98 = _d30._m84
				_p35(_o32 + " ")

				_q78.call_deferred("scene" if _o32 == "@scene" else "all")
			else:
				_p35(_o32 + " ")
				_b50()
				_z1.emit(_o32, "")

		_d30._m84:
			var _m23 = _q57 + " " + _o32
			_w29(_m23 + " ")
			_b50()
			_z1.emit(_q57, _o32)

func _n40() -> void:
	_m98 = _d30._b6
	_q57 = ""
	_r45 = -1
	_l91 = -1

func _b50() -> void:
	_k85._j9()
	_m98 = _d30._b6
	_q57 = ""
	_r45 = -1
	_l91 = -1

func _p35(text: String) -> void:
	var _h60 = _c12.get_line(_r45)

	var before = _h60.substr(0, _l91 - 1)  
	var _u42 = _h60.substr(_c12.get_caret_column())

	var _w10 = before + text + _u42
	_c12.set_line(_r45, _w10)

	_c12.set_caret_line(_r45)
	_c12.set_caret_column(before.length() + text.length())

func _w29(text: String) -> void:
	var _h60 = _c12.get_line(_r45)

	var before = _h60.substr(0, _l91 - 1)  
	var _u42 = _h60.substr(_c12.get_caret_column())

	var _w10 = before + text + _u42
	_c12.set_line(_r45, _w10)

	_c12.set_caret_line(_r45)
	_c12.set_caret_column(before.length() + text.length())

func _b74() -> int:
	if _z76:
		var theme = _z76.get_editor_theme()
		if theme:
			var _n62 = theme.get_font_size("main_size", "EditorFonts")
			if _n62 > 0:
				return _n62
	return 14  

func _u30(_x42: int = _c54._z37) -> Vector2:
	var _l9 = _b74()
	var _m8 = float(_l9) / 14.0

	var _x63 = int(_t72 * _m8)

	var _k97 = _l9 * 2
	var _l69 = int(_c54._q26 * _m8)
	var _o98 = _x42 * _k97 + _l69 * 2

	var _f27 = _i92.get_node_or_null("%_x10") if _i92 else null

	var _z67: float
	if _f27:
		_z67 = _f27.position.y + _f27.size.y
	else:
		var _v44 = _c12.position.y if _c12 else 1800.0
		var _h47 = int(_m95 * _m8)
		_z67 = _v44 - _h47

	var _b72 = _z67 - _o98

	return Vector2(_x63, _b72)

func is_active() -> bool:
	return _m98 != _d30._b6

