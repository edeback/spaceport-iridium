@tool
extends RefCounted
class_name _e82

var _b50: ScriptEditor

func _init(_c37: ScriptEditor = null):
	_b50 = _c37

func _s50() -> String:
	var _s67 = Engine.get_version_info()
	return "%d.%d.%d" % [_s67.get("major", 0), _s67.get("minor", 0), _s67.get("patch", 0)]

func get_current_line(_g95: CodeEdit) -> String:
	var _i77 = _g95.get_caret_line()
	if _i77 >= 0 and _i77 < _g95.get_line_count():
		return _g95.get_line(_i77)
	return ""

func _x98(_g95: CodeEdit, _h92: int = 500) -> String:
	var _i77 = _g95.get_caret_line()
	var caret_column = _g95.get_caret_column()
	var _k3 = ""
	
	if _i77 >= 0 and _i77 < _g95.get_line_count():
		var _m70 = _g95.get_line(_i77)
		if caret_column > 0:
			_k3 = _m70.substr(0, caret_column)
	
	var line = _i77 - 1
	while line >= 0 and _k3.length() < _h92:
		var _c71 = _g95.get_line(line)
		_k3 = _c71 + "\n" + _k3
		line -= 1
	
	if _k3.length() > _h92:
		_k3 = _k3.substr(_k3.length() - _h92)
	
	return _k3

func _j93(_g95: CodeEdit, _h92: int = 500) -> String:
	var _i77 = _g95.get_caret_line()
	var caret_column = _g95.get_caret_column()
	var _k3 = ""
	
	if _i77 >= 0 and _i77 < _g95.get_line_count():
		var _m70 = _g95.get_line(_i77)
		if caret_column < _m70.length():
			_k3 = _m70.substr(caret_column)
	
	var line = _i77 + 1
	while line < _g95.get_line_count() and _k3.length() < _h92:
		_k3 = _k3 + "\n" + _g95.get_line(line)
		line += 1
	
	if _k3.length() > _h92:
		_k3 = _k3.substr(0, _h92)
	
	return _k3

func _v53() -> String:
	if not _b50:
		return "gd"  
	
	var _w66 = _b50.get_current_script()
	if _w66:
		var path = _w66.resource_path
		if path.ends_with(".cs"):
			return "cs"
		elif path.ends_with(".gd"):
			return "gd"
	
	return "gd"  

func _q33(_g95: CodeEdit) -> int:
	var _i77 = _g95.get_caret_line()
	if _i77 >= 0 and _i77 < _g95.get_line_count():
		var line = _g95.get_line(_i77)
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

func is_in_comment(_g95: CodeEdit) -> bool:
	var line = get_current_line(_g95)
	var caret_column = _g95.get_caret_column()
	
	var _f27 = line.find("#")
	if _f27 != -1 and _f27 < caret_column:
		return true
	
	return false

func is_in_string(_g95: CodeEdit) -> bool:
	var line = get_current_line(_g95)
	var caret_column = _g95.get_caret_column()
	
	var _p4 = 0
	var _w74 = 0
	var _x36 = 0
	
	for i in range(min(caret_column, line.length())):
		if i + 2 < line.length() and line.substr(i, 3) == "\"\"\"":
			_x36 += 1
			i += 2
		elif line[i] == "\"" and (i == 0 or line[i-1] != "\\"):
			_p4 += 1
		elif line[i] == "'" and (i == 0 or line[i-1] != "\\"):
			_w74 += 1
	
	return (_p4 % 2 == 1) or (_w74 % 2 == 1) or (_x36 % 2 == 1)

func _l57(_g95: CodeEdit) -> String:
	var line = get_current_line(_g95)
	var caret_column = _g95.get_caret_column()
	
	if caret_column == 0:
		return ""
	
	var _y64 = line.substr(0, caret_column)
	var _a46 = _y64.split(" ", false)
	
	if _a46.size() > 0:
		return _a46[-1]
	return ""

func _v30(_g95: CodeEdit) -> bool:
	var line = get_current_line(_g95)
	var caret_column = _g95.get_caret_column()
	
	if caret_column == 0:
		return false
	
	var _w45 = [".", "(", ":", "=", " "]
	var _h8 = line.substr(caret_column - 1, 1) if caret_column > 0 else ""
	
	return _h8 in _w45

func _l43(_g95: CodeEdit) -> bool:
	var line = get_current_line(_g95).strip_edges()
	
	if line.length() < 3:
		return false
	
	var _q58 = ["if", "for", "while", "func", "var", "const"]
	if line in _q58:
		return false
	
	return true

func _o33(_g95: CodeEdit) -> Dictionary:
	var _m70 = get_current_line(_g95)
	if _m70.length() > 200:
		_m70 = _m70.substr(0, 200)

	return {
		"currentLine": _m70,
		"before": _x98(_g95, 300),  
		"after": _j93(_g95, 300),    
		"cursorPosition": _g95.get_caret_column(),
		"fileType": _v53(),
		"indentLevel": _q33(_g95),
		"godotVersion": _s50()
	}

