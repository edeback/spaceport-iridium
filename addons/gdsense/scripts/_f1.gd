@tool
extends RefCounted
class_name _u79
var _e3: ScriptEditor
func _init(_y11: ScriptEditor = null):
	_e3 = _y11
func _o31() -> String:
	var _f90 = Engine.get_version_info()
	return "%d.%d.%d" % [_f90.get("major", 0), _f90.get("minor", 0), _f90.get("patch", 0)]
func get_current_line(_j81: CodeEdit) -> String:
	var _t41 = _j81.get_caret_line()
	if _t41 >= 0 and _t41 < _j81.get_line_count():
		return _j81.get_line(_t41)
	return ""
func _l74(_j81: CodeEdit, _t83: int = 500) -> String:
	var _t41 = _j81.get_caret_line()
	var caret_column = _j81.get_caret_column()
	var _e21 = ""
	if _t41 >= 0 and _t41 < _j81.get_line_count():
		var _i52 = _j81.get_line(_t41)
		if caret_column > 0:
			_e21 = _i52.substr(0, caret_column)
	var line = _t41 - 1
	while line >= 0 and _e21.length() < _t83:
		var _h39 = _j81.get_line(line)
		_e21 = _h39 + "\n" + _e21
		line -= 1
	if _e21.length() > _t83:
		_e21 = _e21.substr(_e21.length() - _t83)
	return _e21
func _r39(_j81: CodeEdit, _t83: int = 500) -> String:
	var _t41 = _j81.get_caret_line()
	var caret_column = _j81.get_caret_column()
	var _e21 = ""
	if _t41 >= 0 and _t41 < _j81.get_line_count():
		var _i52 = _j81.get_line(_t41)
		if caret_column < _i52.length():
			_e21 = _i52.substr(caret_column)
	var line = _t41 + 1
	while line < _j81.get_line_count() and _e21.length() < _t83:
		_e21 = _e21 + "\n" + _j81.get_line(line)
		line += 1
	if _e21.length() > _t83:
		_e21 = _e21.substr(0, _t83)
	return _e21
func _u15() -> String:
	if not _e3:
		return "gd"  
	var _y36 = _e3.get_current_script()
	if _y36:
		var path = _y36.resource_path
		if path.ends_with(".cs"):
			return "cs"
		elif path.ends_with(".gd"):
			return "gd"
	return "gd"  
func _z12(_j81: CodeEdit) -> int:
	var _t41 = _j81.get_caret_line()
	if _t41 >= 0 and _t41 < _j81.get_line_count():
		var line = _j81.get_line(_t41)
		var indent = 0
		for char in line:
			if char == "\t":
				indent += 1
			elif char == " ":
				indent += 0.25  
			else:
				break
		return int(indent)
	return 0
func is_in_comment(_j81: CodeEdit) -> bool:
	var line = get_current_line(_j81)
	var caret_column = _j81.get_caret_column()
	var _m78 = line.find("#")
	if _m78 != -1 and _m78 < caret_column:
		return true
	return false
func is_in_string(_j81: CodeEdit) -> bool:
	var line = get_current_line(_j81)
	var caret_column = _j81.get_caret_column()
	var _l9 = 0
	var _f59 = 0
	var _a45 = 0
	for i in range(min(caret_column, line.length())):
		if i + 2 < line.length() and line.substr(i, 3) == "\"\"\"":
			_a45 += 1
			i += 2
		elif line[i] == "\"" and (i == 0 or line[i-1] != "\\"):
			_l9 += 1
		elif line[i] == "'" and (i == 0 or line[i-1] != "\\"):
			_f59 += 1
	return (_l9 % 2 == 1) or (_f59 % 2 == 1) or (_a45 % 2 == 1)
func _u68(_j81: CodeEdit) -> String:
	var line = get_current_line(_j81)
	var caret_column = _j81.get_caret_column()
	if caret_column == 0:
		return ""
	var _h33 = line.substr(0, caret_column)
	var _j25 = _h33.split(" ", false)
	if _j25.size() > 0:
		return _j25[-1]
	return ""
func _x33(_j81: CodeEdit) -> bool:
	var line = get_current_line(_j81)
	var caret_column = _j81.get_caret_column()
	if caret_column == 0:
		return false
	var _q1 = [".", "(", ":", "=", " "]
	var _q88 = line.substr(caret_column - 1, 1) if caret_column > 0 else ""
	return _q88 in _q1
func _u12(_j81: CodeEdit) -> bool:
	var line = get_current_line(_j81).strip_edges()
	if line.length() < 3:
		return false
	var _l57 = ["if", "for", "while", "func", "var", "const"]
	if line in _l57:
		return false
	return true
func _x18(_j81: CodeEdit) -> Dictionary:
	var _i52 = get_current_line(_j81)
	if _i52.length() > 200:
		_i52 = _i52.substr(0, 200)
	return {
		"currentLine": _i52,
		"before": _l74(_j81, 300),  
		"after": _r39(_j81, 300),    
		"cursorPosition": _j81.get_caret_column(),
		"fileType": _u15(),
		"indentLevel": _z12(_j81),
		"godotVersion": _o31()
	}
