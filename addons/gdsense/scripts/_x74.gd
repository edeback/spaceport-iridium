@tool
extends RefCounted
class_name _v45

var _j30: ScriptEditor

func _init(_w75: ScriptEditor = null):
	_j30 = _w75

func _b61() -> String:
	var _t37 = Engine.get_version_info()
	return "%d.%d.%d" % [_t37.get("major", 0), _t37.get("minor", 0), _t37.get("patch", 0)]

func get_current_line(_o58: CodeEdit) -> String:
	var _n63 = _o58.get_caret_line()
	if _n63 >= 0 and _n63 < _o58.get_line_count():
		return _o58.get_line(_n63)
	return ""

func _h91(_o58: CodeEdit, _m71: int = 500) -> String:
	var _n63 = _o58.get_caret_line()
	var caret_column = _o58.get_caret_column()
	var _v42 = ""
	
	if _n63 >= 0 and _n63 < _o58.get_line_count():
		var _r42 = _o58.get_line(_n63)
		if caret_column > 0:
			_v42 = _r42.substr(0, caret_column)
	
	var line = _n63 - 1
	while line >= 0 and _v42.length() < _m71:
		var _h60 = _o58.get_line(line)
		_v42 = _h60 + "\n" + _v42
		line -= 1
	
	if _v42.length() > _m71:
		_v42 = _v42.substr(_v42.length() - _m71)
	
	return _v42

func _p79(_o58: CodeEdit, _m71: int = 500) -> String:
	var _n63 = _o58.get_caret_line()
	var caret_column = _o58.get_caret_column()
	var _v42 = ""
	
	if _n63 >= 0 and _n63 < _o58.get_line_count():
		var _r42 = _o58.get_line(_n63)
		if caret_column < _r42.length():
			_v42 = _r42.substr(caret_column)
	
	var line = _n63 + 1
	while line < _o58.get_line_count() and _v42.length() < _m71:
		_v42 = _v42 + "\n" + _o58.get_line(line)
		line += 1
	
	if _v42.length() > _m71:
		_v42 = _v42.substr(0, _m71)
	
	return _v42

func _o31() -> String:
	if not _j30:
		return "gd"  
	
	var _f78 = _j30.get_current_script()
	if _f78:
		var path = _f78.resource_path
		if path.ends_with(".cs"):
			return "cs"
		elif path.ends_with(".gd"):
			return "gd"
	
	return "gd"  

func _n88(_o58: CodeEdit) -> int:
	var _n63 = _o58.get_caret_line()
	if _n63 >= 0 and _n63 < _o58.get_line_count():
		var line = _o58.get_line(_n63)
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

func is_in_comment(_o58: CodeEdit) -> bool:
	var line = get_current_line(_o58)
	var caret_column = _o58.get_caret_column()
	
	var _s79 = line.find("#")
	if _s79 != -1 and _s79 < caret_column:
		return true
	
	return false

func is_in_string(_o58: CodeEdit) -> bool:
	var line = get_current_line(_o58)
	var caret_column = _o58.get_caret_column()
	
	var _m72 = 0
	var _m53 = 0
	var _c80 = 0
	
	for i in range(min(caret_column, line.length())):
		if i + 2 < line.length() and line.substr(i, 3) == "\"\"\"":
			_c80 += 1
			i += 2
		elif line[i] == "\"" and (i == 0 or line[i-1] != "\\"):
			_m72 += 1
		elif line[i] == "'" and (i == 0 or line[i-1] != "\\"):
			_m53 += 1
	
	return (_m72 % 2 == 1) or (_m53 % 2 == 1) or (_c80 % 2 == 1)

func _h67(_o58: CodeEdit) -> String:
	var line = get_current_line(_o58)
	var caret_column = _o58.get_caret_column()
	
	if caret_column == 0:
		return ""
	
	var _m21 = line.substr(0, caret_column)
	var _q49 = _m21.split(" ", false)
	
	if _q49.size() > 0:
		return _q49[-1]
	return ""

func _h82(_o58: CodeEdit) -> bool:
	var line = get_current_line(_o58)
	var caret_column = _o58.get_caret_column()
	
	if caret_column == 0:
		return false
	
	var _t38 = [".", "(", ":", "=", " "]
	var _p13 = line.substr(caret_column - 1, 1) if caret_column > 0 else ""
	
	return _p13 in _t38

func _i68(_o58: CodeEdit) -> bool:
	var line = get_current_line(_o58).strip_edges()
	
	if line.length() < 3:
		return false
	
	var _g53 = ["if", "for", "while", "func", "var", "const"]
	if line in _g53:
		return false
	
	return true

func _j14(_o58: CodeEdit) -> Dictionary:
	var _r42 = get_current_line(_o58)
	if _r42.length() > 200:
		_r42 = _r42.substr(0, 200)

	return {
		"currentLine": _r42,
		"before": _h91(_o58, 300),  
		"after": _p79(_o58, 300),    
		"cursorPosition": _o58.get_caret_column(),
		"fileType": _o31(),
		"indentLevel": _n88(_o58),
		"godotVersion": _b61()
	}

