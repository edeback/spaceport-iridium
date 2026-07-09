@tool
class_name _j50
extends RefCounted

signal _v71(_r33: String, path: String)

enum _z2 {
	_i83,              
	_m7, 
	_b42        
}

const _n27: Array[String] = ["@file", "@selection", "@openscript", "@scene", "@node"]

const _g74: Array[String] = ["@file", "@scene"]

const _y24: int = 12
const _x74: int = 60

var _g3: _z2 = _z2._i83
var _e95: TextEdit
var _r25: Control
var _q86: EditorInterface
var _r61: _d15
var _l85: _o58
var _t92: String = ""  
var _t13: int = -1        
var _k32: int = -1      
var _y40: String = ""        

func initialize(_l34: TextEdit, parent: Control, _t15: EditorInterface) -> void:
	_e95 = _l34
	_r25 = parent
	_q86 = _t15

	_l85 = _o58.new()

	_r61 = _d15.new()
	_r61.initialize(_t15)
	_r61.item_selected.connect(_h20)
	_r61._x100.connect(_o68)
	_r25.add_child(_r61)

	_e95.text_changed.connect(_z28)
	_e95.caret_changed.connect(_c62)

	_y40 = _e95.text

func _k63() -> void:
	if _r61 and is_instance_valid(_r61):
		_r61._k63()
		_r61.queue_free()
		_r61 = null

	if _e95 and is_instance_valid(_e95):
		if _e95.text_changed.is_connected(_z28):
			_e95.text_changed.disconnect(_z28)
		if _e95.caret_changed.is_connected(_c62):
			_e95.caret_changed.disconnect(_c62)

func _y20(_n74: InputEvent) -> bool:
	if _g3 == _z2._i83:
		return false

	if not _n74 is InputEventKey:
		return false

	var _k56 = _n74 as InputEventKey
	if not _k56.pressed:
		return false

	match _k56.keycode:
		KEY_UP:
			_r61._c49()
			return true
		KEY_DOWN:
			_r61._a43()
			return true
		KEY_ENTER, KEY_KP_ENTER:
			_r61._m92()
			return true
		KEY_TAB:
			_r61._m92()
			return true
		KEY_ESCAPE:
			_f39()
			return true
		_:
			return false

func _z28() -> void:
	var _n98 = _e95.text
	var _i77 = _e95.get_caret_line()
	var caret_column = _e95.get_caret_column()

	match _g3:
		_z2._i83:
			var _k25 = _k17(_i77, caret_column)
			if _k25 != "":
				_c1(_k25, _i77, caret_column)

			elif _q3(_n98, _i77, caret_column):
				_a81()

		_z2._m7:
			var _e33 = _q11(_i77, caret_column)
			if _e33 == null:
				_f39()
			else:
				_h86(_e33)

		_z2._b42:
			var _e33 = _b95(_i77, caret_column)
			if _e33 == null:
				_f39()
			else:
				_n94(_e33)

	_y40 = _n98

func _c62() -> void:
	if _g3 == _z2._i83:
		return

	var _i77 = _e95.get_caret_line()
	var caret_column = _e95.get_caret_column()

	if _i77 != _t13:
		_f39()
		return

	if caret_column < _k32:
		_f39()

func _q3(text: String, line: int, _o37: int) -> bool:
	var _c71 = _e95.get_line(line)

	if _o37 == 0:
		return false

	var _k79 = _c71[_o37 - 1] if _o37 <= _c71.length() else ""
	if _k79 != "@":
		return false

	if _o37 >= 2:
		var _z40 = _c71[_o37 - 2] if _o37 - 1 < _c71.length() else ""

		if _z40.is_valid_identifier():
			return false

	if _o37 < _c71.length():
		var _i96 = _c71[_o37]

		if _i96 != "" and _i96 != " ":
			var _u26 = _c71.substr(_o37 - 1)
			for _p56 in _n27:
				if _u26.begins_with(_p56):
					return false

	return true

func _k17(line: int, _o37: int) -> String:
	var _c71 = _e95.get_line(line)

	if _o37 < 6:  
		return ""

	var _i20 = _c71.substr(0, _o37)

	for _p56 in _g74:
		var _c84 = _p56 + " "  
		if _i20.ends_with(_c84):
			var _c28 = _o37 - _c84.length()
			if _c28 == 0:
				return _p56
			var _k79 = _c71[_c28 - 1]
			if _k79 == " " or _k79 == "\t" or _k79 == "\n":
				return _p56

	return ""

func _c1(_r33: String, line: int, _o37: int) -> void:
	_t92 = _r33
	_g3 = _z2._b42

	var _x19 = _r33.length() + 1  
	_t13 = line
	_k32 = _o37 - _x19 + 1  

	var _e97 = "scene" if _r33 == "@scene" else "all"
	_w46(_e97)

func _q11(line: int, _o37: int) -> Variant:
	if line != _t13:
		return null

	if _o37 < _k32:
		return null

	var _c71 = _e95.get_line(line)
	var start = _k32  
	var _g88 = _o37

	if start > _c71.length() or _g88 > _c71.length():
		return ""

	return _c71.substr(start, _g88 - start)

func _b95(line: int, _o37: int) -> Variant:
	if line != _t13:
		return null

	var _c71 = _e95.get_line(line)

	var _d90 = _k32 - 1 + _t92.length()

	while _d90 < _c71.length() and _c71[_d90] == " ":
		_d90 += 1

	if _o37 < _d90:
		return null

	return _c71.substr(_d90, _o37 - _d90)

func _a81() -> void:
	_g3 = _z2._m7
	_t13 = _e95.get_caret_line()
	_k32 = _e95.get_caret_column()  

	var _g47 = _h30(_d15._u13)
	_r61._h90(_g47, _n27.duplicate(), _d15._u13)

func _w46(_e97: String) -> void:
	if _g3 != _z2._b42:
		return

	var _i67 = _l85._s6("", _e97)

	var _g47 = _h30(_d15._y4)
	_r61._h90(_g47, _i67, _d15._y4)

func _h86(_e33: String) -> void:
	var _m97 = _e33.to_lower()

	for _p56 in _g74:
		var _x14 = _p56.substr(1)  
		if _m97 == _x14 + " " or _m97.begins_with(_x14 + " "):
			_t92 = _p56
			_g3 = _z2._b42
			var _e97 = "scene" if _p56 == "@scene" else "all"
			_w46.call_deferred(_e97)
			return

	var _m16: Array[String] = []
	for _p56 in _n27:
		var _x14 = _p56.substr(1)  
		if _x14.begins_with(_m97) or _p56.to_lower().begins_with("@" + _m97):
			_m16.append(_p56)

	if _m16.is_empty():
		_f39()
	else:
		_r61._h90(_h30(_d15._u13), _m16, _d15._u13)

func _n94(_e33: String) -> void:
	var _e97 = "scene" if _t92 == "@scene" else "all"
	var _i67 = _l85._s6(_e33, _e97)

	if _i67.is_empty() and not _e33.is_empty():
		_r61._y63(_e33)
	elif _i67.is_empty():
		pass

	else:
		_r61._h90(_h30(_d15._y4), _i67, _d15._y4)

func _h20(_c53: String) -> void:
	match _g3:
		_z2._m7:
			if _c53 in _g74:
				_t92 = _c53

				_g3 = _z2._b42
				_e78(_c53 + " ")

				_w46.call_deferred("scene" if _c53 == "@scene" else "all")
			else:
				_e78(_c53 + " ")
				_f39()
				_v71.emit(_c53, "")

		_z2._b42:
			var _e39 = _t92 + " " + _c53
			_e98(_e39 + " ")
			_f39()
			_v71.emit(_t92, _c53)

func _o68() -> void:
	_g3 = _z2._i83
	_t92 = ""
	_t13 = -1
	_k32 = -1

func _f39() -> void:
	_r61._n73()
	_g3 = _z2._i83
	_t92 = ""
	_t13 = -1
	_k32 = -1

func _e78(text: String) -> void:
	var _c71 = _e95.get_line(_t13)

	var before = _c71.substr(0, _k32 - 1)  
	var _h71 = _c71.substr(_e95.get_caret_column())

	var _b79 = before + text + _h71
	_e95.set_line(_t13, _b79)

	_e95.set_caret_line(_t13)
	_e95.set_caret_column(before.length() + text.length())

func _e98(text: String) -> void:
	var _c71 = _e95.get_line(_t13)

	var before = _c71.substr(0, _k32 - 1)  
	var _h71 = _c71.substr(_e95.get_caret_column())

	var _b79 = before + text + _h71
	_e95.set_line(_t13, _b79)

	_e95.set_caret_line(_t13)
	_e95.set_caret_column(before.length() + text.length())

func _c77() -> int:
	if _q86:
		var theme = _q86.get_editor_theme()
		if theme:
			var _z95 = theme.get_font_size("main_size", "EditorFonts")
			if _z95 > 0:
				return _z95
	return 14  

func _h30(_o42: int = _d15._y4) -> Vector2:
	var _r90 = _c77()
	var _j64 = float(_r90) / 14.0

	var _r50 = int(_y24 * _j64)

	var _u94 = _r90 * 2
	var _n67 = int(_d15._z54 * _j64)
	var _v29 = _o42 * _u94 + _n67 * 2

	var _k71 = _r25.get_node_or_null("%_y21") if _r25 else null

	var _a51: float
	if _k71:
		_a51 = _k71.position.y + _k71.size.y
	else:
		var _v40 = _e95.position.y if _e95 else 1800.0
		var _u77 = int(_x74 * _j64)
		_a51 = _v40 - _u77

	var _b25 = _a51 - _v29

	return Vector2(_r50, _b25)

func is_active() -> bool:
	return _g3 != _z2._i83

