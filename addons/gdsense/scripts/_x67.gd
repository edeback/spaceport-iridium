@tool
extends RefCounted
class_name _j43
var _k94: ScriptEditor
func _init(_w31: ScriptEditor = null):
	_k94 = _w31
func _p39() -> String:
	var _g90 = Engine.get_version_info()
	return "%d.%d.%d" % [_g90.get("major", 0), _g90.get("minor", 0), _g90.get("patch", 0)]
func get_current_line(_x7: CodeEdit) -> String:
	var _c88 = _x7.get_caret_line()
	if _c88 >= 0 and _c88 < _x7.get_line_count():
		return _x7.get_line(_c88)
	return ""
func _m98(_x7: CodeEdit, _v10: int = 500) -> String:
	var _c88 = _x7.get_caret_line()
	var caret_column = _x7.get_caret_column()
	var _x97 = ""
	if _c88 >= 0 and _c88 < _x7.get_line_count():
		var _p23 = _x7.get_line(_c88)
		if caret_column > 0:
			_x97 = _p23.substr(0, caret_column)
	var line = _c88 - 1
	while line >= 0 and _x97.length() < _v10:
		var _f62 = _x7.get_line(line)
		_x97 = _f62 + "\n" + _x97
		line -= 1
	if _x97.length() > _v10:
		_x97 = _x97.substr(_x97.length() - _v10)
	return _x97
func _f74(_x7: CodeEdit, _v10: int = 500) -> String:
	var _c88 = _x7.get_caret_line()
	var caret_column = _x7.get_caret_column()
	var _x97 = ""
	if _c88 >= 0 and _c88 < _x7.get_line_count():
		var _p23 = _x7.get_line(_c88)
		if caret_column < _p23.length():
			_x97 = _p23.substr(caret_column)
	var line = _c88 + 1
	while line < _x7.get_line_count() and _x97.length() < _v10:
		_x97 = _x97 + "\n" + _x7.get_line(line)
		line += 1
	if _x97.length() > _v10:
		_x97 = _x97.substr(0, _v10)
	return _x97
func _i94() -> String:
	if not _k94:
		return "gd"  
	var _d90 = _k94.get_current_script()
	if _d90:
		var path = _d90.resource_path
		if path.ends_with(".cs"):
			return "cs"
		elif path.ends_with(".gd"):
			return "gd"
	return "gd"  
func _t69(_x7: CodeEdit) -> int:
	var _c88 = _x7.get_caret_line()
	if _c88 >= 0 and _c88 < _x7.get_line_count():
		var line = _x7.get_line(_c88)
		var indent = 0
		for _o41 in line:
			if _o41 == "\t":
				indent += 1
			elif _o41 == " ":
				indent += 0.25  
			else:
				break
		return int(indent)
	return 0
func is_in_comment(_x7: CodeEdit) -> bool:
	var line = get_current_line(_x7)
	var caret_column = _x7.get_caret_column()
	var _y75 = line.find("#")
	if _y75 != -1 and _y75 < caret_column:
		return true
	return false
func is_in_string(_x7: CodeEdit) -> bool:
	var line = get_current_line(_x7)
	var caret_column = _x7.get_caret_column()
	var _y15 = 0
	var _k25 = 0
	var _r90 = 0
	for i in range(min(caret_column, line.length())):
		if i + 2 < line.length() and line.substr(i, 3) == "\"\"\"":
			_r90 += 1
			i += 2
		elif line[i] == "\"" and (i == 0 or line[i-1] != "\\"):
			_y15 += 1
		elif line[i] == "'" and (i == 0 or line[i-1] != "\\"):
			_k25 += 1
	return (_y15 % 2 == 1) or (_k25 % 2 == 1) or (_r90 % 2 == 1)
func _z84(_x7: CodeEdit) -> String:
	var line = get_current_line(_x7)
	var caret_column = _x7.get_caret_column()
	if caret_column == 0:
		return ""
	var _d76 = line.substr(0, caret_column)
	var _t16 = _d76.split(" ", false)
	if _t16.size() > 0:
		return _t16[-1]
	return ""
func _e55(_x7: CodeEdit) -> bool:
	var line = get_current_line(_x7)
	var caret_column = _x7.get_caret_column()
	if caret_column == 0:
		return false
	var _b83 = [".", "(", ":", "=", " "]
	var _u100 = line.substr(caret_column - 1, 1) if caret_column > 0 else ""
	return _u100 in _b83
func _y22(_x7: CodeEdit) -> bool:
	var line = get_current_line(_x7).strip_edges()
	if line.length() < 3:
		return false
	var _o14 = ["if", "for", "while", "func", "var", "const"]
	if line in _o14:
		return false
	return true
func _o62(_x7: CodeEdit) -> Dictionary:
	var _p23 = get_current_line(_x7)
	if _p23.length() > 200:
		_p23 = _p23.substr(0, 200)
	return {
		"currentLine": _p23,
		"before": _m98(_x7, 300),  
		"after": _f74(_x7, 300),    
		"cursorPosition": _x7.get_caret_column(),
		"fileType": _i94(),
		"indentLevel": _t69(_x7),
		"godotVersion": _p39()
	}
