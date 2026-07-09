@tool
extends RefCounted
class_name _r28

var _i60: ScriptEditor

func _init(_f83: ScriptEditor = null):
	_i60 = _f83

func _s18() -> String:
	var _m65 = Engine.get_version_info()
	return "%d.%d.%d" % [_m65.get("major", 0), _m65.get("minor", 0), _m65.get("patch", 0)]

func get_current_line(_v78: CodeEdit) -> String:
	var _w9 = _v78.get_caret_line()
	if _w9 >= 0 and _w9 < _v78.get_line_count():
		return _v78.get_line(_w9)
	return ""

func _y2(_v78: CodeEdit, _j35: int = 500) -> String:
	var _w9 = _v78.get_caret_line()
	var caret_column = _v78.get_caret_column()
	var _x97 = ""
	
	if _w9 >= 0 and _w9 < _v78.get_line_count():
		var _n27 = _v78.get_line(_w9)
		if caret_column > 0:
			_x97 = _n27.substr(0, caret_column)
	
	var line = _w9 - 1
	while line >= 0 and _x97.length() < _j35:
		var _o75 = _v78.get_line(line)
		_x97 = _o75 + "\n" + _x97
		line -= 1
	
	if _x97.length() > _j35:
		_x97 = _x97.substr(_x97.length() - _j35)
	
	return _x97

func _s87(_v78: CodeEdit, _j35: int = 500) -> String:
	var _w9 = _v78.get_caret_line()
	var caret_column = _v78.get_caret_column()
	var _x97 = ""
	
	if _w9 >= 0 and _w9 < _v78.get_line_count():
		var _n27 = _v78.get_line(_w9)
		if caret_column < _n27.length():
			_x97 = _n27.substr(caret_column)
	
	var line = _w9 + 1
	while line < _v78.get_line_count() and _x97.length() < _j35:
		_x97 = _x97 + "\n" + _v78.get_line(line)
		line += 1
	
	if _x97.length() > _j35:
		_x97 = _x97.substr(0, _j35)
	
	return _x97

func _h15() -> String:
	if not _i60:
		return "gd"  
	
	var _g40 = _i60.get_current_script()
	if _g40:
		var path = _g40.resource_path
		if path.ends_with(".cs"):
			return "cs"
		elif path.ends_with(".gd"):
			return "gd"
	
	return "gd"  

func _s27(_v78: CodeEdit) -> int:
	var _w9 = _v78.get_caret_line()
	if _w9 >= 0 and _w9 < _v78.get_line_count():
		var line = _v78.get_line(_w9)
		var indent = 0
		for _d38 in line:
			if _d38 == "\t":
				indent += 1
			elif _d38 == " ":
				indent += 0.25  
			else:
				break
		return int(indent)
	return 0

func is_in_comment(_v78: CodeEdit) -> bool:
	var line = get_current_line(_v78)
	var caret_column = _v78.get_caret_column()
	
	var _y37 = line.find("#")
	if _y37 != -1 and _y37 < caret_column:
		return true
	
	return false

func is_in_string(_v78: CodeEdit) -> bool:
	var line = get_current_line(_v78)
	var caret_column = _v78.get_caret_column()
	
	var _j60 = 0
	var _e82 = 0
	var _b71 = 0
	
	for i in range(min(caret_column, line.length())):
		if i + 2 < line.length() and line.substr(i, 3) == "\"\"\"":
			_b71 += 1
			i += 2
		elif line[i] == "\"" and (i == 0 or line[i-1] != "\\"):
			_j60 += 1
		elif line[i] == "'" and (i == 0 or line[i-1] != "\\"):
			_e82 += 1
	
	return (_j60 % 2 == 1) or (_e82 % 2 == 1) or (_b71 % 2 == 1)

func _g3(_v78: CodeEdit) -> String:
	var line = get_current_line(_v78)
	var caret_column = _v78.get_caret_column()
	
	if caret_column == 0:
		return ""
	
	var _o23 = line.substr(0, caret_column)
	var _h43 = _o23.split(" ", false)
	
	if _h43.size() > 0:
		return _h43[-1]
	return ""

func _i47(_v78: CodeEdit) -> bool:
	var line = get_current_line(_v78)
	var caret_column = _v78.get_caret_column()
	
	if caret_column == 0:
		return false
	
	var _p21 = [".", "(", ":", "=", " "]
	var _j100 = line.substr(caret_column - 1, 1) if caret_column > 0 else ""
	
	return _j100 in _p21

func _m9(_v78: CodeEdit) -> bool:
	var line = get_current_line(_v78).strip_edges()
	
	if line.length() < 3:
		return false
	
	var _t65 = ["if", "for", "while", "func", "var", "const"]
	if line in _t65:
		return false
	
	return true

func _d55(_v78: CodeEdit) -> Dictionary:
	var _n27 = get_current_line(_v78)
	if _n27.length() > 200:
		_n27 = _n27.substr(0, 200)

	return {
		"currentLine": _n27,
		"before": _y2(_v78, 300),  
		"after": _s87(_v78, 300),    
		"cursorPosition": _v78.get_caret_column(),
		"fileType": _h15(),
		"indentLevel": _s27(_v78),
		"godotVersion": _s18()
	}

