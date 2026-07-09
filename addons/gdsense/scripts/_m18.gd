@tool
class_name _c92
extends RefCounted

signal _s88(_n49: String, path: String)

enum _c31 {
	_q7,              
	_m23, 
	_m75        
}

const _q23: Array[String] = ["@file", "@selection", "@openscript", "@scene", "@node"]

const _q39: Array[String] = ["@file", "@scene"]

const _b65: int = 12
const _r90: int = 60

var _x81: _c31 = _c31._q7
var _h44: TextEdit
var _s61: Control
var _b58: EditorInterface
var _r51: _p76
var _w25: _w59
var _g27: String = ""  
var _k57: int = -1        
var _s24: int = -1      
var _h23: String = ""        

func initialize(_q55: TextEdit, parent: Control, _f28: EditorInterface) -> void:
	_h44 = _q55
	_s61 = parent
	_b58 = _f28

	_w25 = _w59.new()

	_r51 = _p76.new()
	_r51.initialize(_f28)
	_r51.item_selected.connect(_s82)
	_r51._w51.connect(_p17)
	_s61.add_child(_r51)

	_h44.text_changed.connect(_u29)
	_h44.caret_changed.connect(_g29)

	_h23 = _h44.text

func _q17() -> void:
	if _r51 and is_instance_valid(_r51):
		_r51._q17()
		_r51.queue_free()
		_r51 = null

	if _h44 and is_instance_valid(_h44):
		if _h44.text_changed.is_connected(_u29):
			_h44.text_changed.disconnect(_u29)
		if _h44.caret_changed.is_connected(_g29):
			_h44.caret_changed.disconnect(_g29)

func _t27(_x1: InputEvent) -> bool:
	if _x81 == _c31._q7:
		return false

	if not _x1 is InputEventKey:
		return false

	var _z92 = _x1 as InputEventKey
	if not _z92.pressed:
		return false

	match _z92.keycode:
		KEY_UP:
			_r51._s9()
			return true
		KEY_DOWN:
			_r51._c28()
			return true
		KEY_ENTER, KEY_KP_ENTER:
			_r51._z99()
			return true
		KEY_TAB:
			_r51._z99()
			return true
		KEY_ESCAPE:
			_s52()
			return true
		_:
			return false

func _u29() -> void:
	var _d25 = _h44.text
	var _w9 = _h44.get_caret_line()
	var caret_column = _h44.get_caret_column()

	match _x81:
		_c31._q7:
			var _q81 = _w8(_w9, caret_column)
			if _q81 != "":
				_w52(_q81, _w9, caret_column)

			elif _l54(_d25, _w9, caret_column):
				_n31()

		_c31._m23:
			var _q68 = _c49(_w9, caret_column)
			if _q68 == null:
				_s52()
			else:
				_o24(_q68)

		_c31._m75:
			var _q68 = _p38(_w9, caret_column)
			if _q68 == null:
				_s52()
			else:
				_i75(_q68)

	_h23 = _d25

func _g29() -> void:
	if _x81 == _c31._q7:
		return

	var _w9 = _h44.get_caret_line()
	var caret_column = _h44.get_caret_column()

	if _w9 != _k57:
		_s52()
		return

	if caret_column < _s24:
		_s52()

func _l54(text: String, line: int, _p49: int) -> bool:
	var _o75 = _h44.get_line(line)

	if _p49 == 0:
		return false

	var _s28 = _o75[_p49 - 1] if _p49 <= _o75.length() else ""
	if _s28 != "@":
		return false

	if _p49 >= 2:
		var _h45 = _o75[_p49 - 2] if _p49 - 1 < _o75.length() else ""

		if _h45.is_valid_identifier():
			return false

	if _p49 < _o75.length():
		var _e58 = _o75[_p49]

		if _e58 != "" and _e58 != " ":
			var _e48 = _o75.substr(_p49 - 1)
			for _t95 in _q23:
				if _e48.begins_with(_t95):
					return false

	return true

func _w8(line: int, _p49: int) -> String:
	var _o75 = _h44.get_line(line)

	if _p49 < 6:  
		return ""

	var _u51 = _o75.substr(0, _p49)

	for _t95 in _q39:
		var _t30 = _t95 + " "  
		if _u51.ends_with(_t30):
			var _n75 = _p49 - _t30.length()
			if _n75 == 0:
				return _t95
			var _s28 = _o75[_n75 - 1]
			if _s28 == " " or _s28 == "\t" or _s28 == "\n":
				return _t95

	return ""

func _w52(_n49: String, line: int, _p49: int) -> void:
	_g27 = _n49
	_x81 = _c31._m75

	var _u28 = _n49.length() + 1  
	_k57 = line
	_s24 = _p49 - _u28 + 1  

	var _n58 = "scene" if _n49 == "@scene" else "all"
	_e20(_n58)

func _c49(line: int, _p49: int) -> Variant:
	if line != _k57:
		return null

	if _p49 < _s24:
		return null

	var _o75 = _h44.get_line(line)
	var start = _s24  
	var _s7 = _p49

	if start > _o75.length() or _s7 > _o75.length():
		return ""

	return _o75.substr(start, _s7 - start)

func _p38(line: int, _p49: int) -> Variant:
	if line != _k57:
		return null

	var _o75 = _h44.get_line(line)

	var _y9 = _s24 - 1 + _g27.length()

	while _y9 < _o75.length() and _o75[_y9] == " ":
		_y9 += 1

	if _p49 < _y9:
		return null

	return _o75.substr(_y9, _p49 - _y9)

func _n31() -> void:
	_x81 = _c31._m23
	_k57 = _h44.get_caret_line()
	_s24 = _h44.get_caret_column()  

	var _y11 = _m64(_p76._t43)
	_r51._q40(_y11, _q23.duplicate(), _p76._t43)

func _e20(_n58: String) -> void:
	if _x81 != _c31._m75:
		return

	var _n51 = _w25._o88("", _n58)

	var _y11 = _m64(_p76._e52)
	_r51._q40(_y11, _n51, _p76._e52)

func _o24(_q68: String) -> void:
	var _h60 = _q68.to_lower()

	for _t95 in _q39:
		var _g85 = _t95.substr(1)  
		if _h60 == _g85 + " " or _h60.begins_with(_g85 + " "):
			_g27 = _t95
			_x81 = _c31._m75
			var _n58 = "scene" if _t95 == "@scene" else "all"
			_e20.call_deferred(_n58)
			return

	var _s71: Array[String] = []
	for _t95 in _q23:
		var _g85 = _t95.substr(1)  
		if _g85.begins_with(_h60) or _t95.to_lower().begins_with("@" + _h60):
			_s71.append(_t95)

	if _s71.is_empty():
		_s52()
	else:
		_r51._q40(_m64(_p76._t43), _s71, _p76._t43)

func _i75(_q68: String) -> void:
	var _n58 = "scene" if _g27 == "@scene" else "all"
	var _n51 = _w25._o88(_q68, _n58)

	if _n51.is_empty() and not _q68.is_empty():
		_r51._e92(_q68)
	elif _n51.is_empty():
		pass

	else:
		_r51._q40(_m64(_p76._e52), _n51, _p76._e52)

func _s82(_y98: String) -> void:
	match _x81:
		_c31._m23:
			if _y98 in _q39:
				_g27 = _y98

				_x81 = _c31._m75
				_h3(_y98 + " ")

				_e20.call_deferred("scene" if _y98 == "@scene" else "all")
			else:
				_h3(_y98 + " ")
				_s52()
				_s88.emit(_y98, "")

		_c31._m75:
			var _c68 = _g27 + " " + _y98
			_v21(_c68 + " ")
			_s52()
			_s88.emit(_g27, _y98)

func _p17() -> void:
	_x81 = _c31._q7
	_g27 = ""
	_k57 = -1
	_s24 = -1

func _s52() -> void:
	_r51._m34()
	_x81 = _c31._q7
	_g27 = ""
	_k57 = -1
	_s24 = -1

func _h3(text: String) -> void:
	var _o75 = _h44.get_line(_k57)

	var before = _o75.substr(0, _s24 - 1)  
	var _x51 = _o75.substr(_h44.get_caret_column())

	var _q35 = before + text + _x51
	_h44.set_line(_k57, _q35)

	_h44.set_caret_line(_k57)
	_h44.set_caret_column(before.length() + text.length())

func _v21(text: String) -> void:
	var _o75 = _h44.get_line(_k57)

	var before = _o75.substr(0, _s24 - 1)  
	var _x51 = _o75.substr(_h44.get_caret_column())

	var _q35 = before + text + _x51
	_h44.set_line(_k57, _q35)

	_h44.set_caret_line(_k57)
	_h44.set_caret_column(before.length() + text.length())

func _x7() -> int:
	if _b58:
		var theme = _b58.get_editor_theme()
		if theme:
			var _v97 = theme.get_font_size("main_size", "EditorFonts")
			if _v97 > 0:
				return _v97
	return 14  

func _m64(_a72: int = _p76._e52) -> Vector2:
	var _p67 = _x7()
	var _y12 = float(_p67) / 14.0

	var _r65 = int(_b65 * _y12)

	var _t49 = _p67 * 2
	var _y27 = int(_p76._z13 * _y12)
	var _p86 = _a72 * _t49 + _y27 * 2

	var _l31 = _s61.get_node_or_null("%_c72") if _s61 else null

	var _k79: float
	if _l31:
		_k79 = _l31.position.y + _l31.size.y
	else:
		var _w16 = _h44.position.y if _h44 else 1800.0
		var _c79 = int(_r90 * _y12)
		_k79 = _w16 - _c79

	var _k60 = _k79 - _p86

	return Vector2(_r65, _k60)

func is_active() -> bool:
	return _x81 != _c31._q7

