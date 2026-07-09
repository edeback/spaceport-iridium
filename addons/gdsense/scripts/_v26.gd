@tool
extends RefCounted
class_name _o92
var _y14: ScriptEditor
func _init(_x62: ScriptEditor = null):
	_y14 = _x62
func _e35() -> String:
	var _q72 = Engine.get_version_info()
	return "%d.%d.%d" % [_q72.get("major", 0), _q72.get("minor", 0), _q72.get("patch", 0)]
func get_current_line(_t5: CodeEdit) -> String:
	var _e26 = _t5.get_caret_line()
	if _e26 >= 0 and _e26 < _t5.get_line_count():
		return _t5.get_line(_e26)
	return ""
func _k76(_t5: CodeEdit, _m65: int = 500) -> String:
	var _e26 = _t5.get_caret_line()
	var caret_column = _t5.get_caret_column()
	var _n37 = ""
	if _e26 >= 0 and _e26 < _t5.get_line_count():
		var _t50 = _t5.get_line(_e26)
		if caret_column > 0:
			_n37 = _t50.substr(0, caret_column)
	var line = _e26 - 1
	while line >= 0 and _n37.length() < _m65:
		var _n45 = _t5.get_line(line)
		_n37 = _n45 + "\n" + _n37
		line -= 1
	if _n37.length() > _m65:
		_n37 = _n37.substr(_n37.length() - _m65)
	return _n37
func _d48(_t5: CodeEdit, _m65: int = 500) -> String:
	var _e26 = _t5.get_caret_line()
	var caret_column = _t5.get_caret_column()
	var _n37 = ""
	if _e26 >= 0 and _e26 < _t5.get_line_count():
		var _t50 = _t5.get_line(_e26)
		if caret_column < _t50.length():
			_n37 = _t50.substr(caret_column)
	var line = _e26 + 1
	while line < _t5.get_line_count() and _n37.length() < _m65:
		_n37 = _n37 + "\n" + _t5.get_line(line)
		line += 1
	if _n37.length() > _m65:
		_n37 = _n37.substr(0, _m65)
	return _n37
func _h24() -> String:
	if not _y14:
		return "gd"  
	var _l100 = _y14.get_current_script()
	if _l100:
		var path = _l100.resource_path
		if path.ends_with(".cs"):
			return "cs"
		elif path.ends_with(".gd"):
			return "gd"
	return "gd"  
func _g49(_t5: CodeEdit) -> int:
	var _e26 = _t5.get_caret_line()
	if _e26 >= 0 and _e26 < _t5.get_line_count():
		var line = _t5.get_line(_e26)
		var indent = 0
		for _c28 in line:
			if _c28 == "\t":
				indent += 1
			elif _c28 == " ":
				indent += 0.25  
			else:
				break
		return int(indent)
	return 0
func is_in_comment(_t5: CodeEdit) -> bool:
	var line = get_current_line(_t5)
	var caret_column = _t5.get_caret_column()
	var _e18 = line.find("#")
	if _e18 != -1 and _e18 < caret_column:
		return true
	return false
func is_in_string(_t5: CodeEdit) -> bool:
	var line = get_current_line(_t5)
	var caret_column = _t5.get_caret_column()
	var _v100 = 0
	var _h66 = 0
	var _h79 = 0
	for i in range(min(caret_column, line.length())):
		if i + 2 < line.length() and line.substr(i, 3) == "\"\"\"":
			_h79 += 1
			i += 2
		elif line[i] == "\"" and (i == 0 or line[i-1] != "\\"):
			_v100 += 1
		elif line[i] == "'" and (i == 0 or line[i-1] != "\\"):
			_h66 += 1
	return (_v100 % 2 == 1) or (_h66 % 2 == 1) or (_h79 % 2 == 1)
func _d50(_t5: CodeEdit) -> String:
	var line = get_current_line(_t5)
	var caret_column = _t5.get_caret_column()
	if caret_column == 0:
		return ""
	var _e65 = line.substr(0, caret_column)
	var _l91 = _e65.split(" ", false)
	if _l91.size() > 0:
		return _l91[-1]
	return ""
func _m14(_t5: CodeEdit) -> bool:
	var line = get_current_line(_t5)
	var caret_column = _t5.get_caret_column()
	if caret_column == 0:
		return false
	var _m31 = [".", "(", ":", "=", " "]
	var _d94 = line.substr(caret_column - 1, 1) if caret_column > 0 else ""
	return _d94 in _m31
func _o28(_t5: CodeEdit) -> bool:
	var line = get_current_line(_t5).strip_edges()
	if line.length() < 3:
		return false
	var _v45 = ["if", "for", "while", "func", "var", "const"]
	if line in _v45:
		return false
	return true
func _c24(_t5: CodeEdit) -> Dictionary:
	var _t50 = get_current_line(_t5)
	if _t50.length() > 200:
		_t50 = _t50.substr(0, 200)
	return {
		"currentLine": _t50,
		"before": _k76(_t5, 300),  
		"after": _d48(_t5, 300),    
		"cursorPosition": _t5.get_caret_column(),
		"fileType": _h24(),
		"indentLevel": _g49(_t5),
		"godotVersion": _e35()
	}
