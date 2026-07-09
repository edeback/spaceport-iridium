@tool
extends RefCounted
class_name _u73
var _n12: ScriptEditor
func _init(_t27: ScriptEditor = null):
	_n12 = _t27
func _k25() -> String:
	var _w99 = Engine.get_version_info()
	return "%d.%d.%d" % [_w99.get("major", 0), _w99.get("minor", 0), _w99.get("patch", 0)]
func get_current_line(_v93: CodeEdit) -> String:
	var _p99 = _v93.get_caret_line()
	if _p99 >= 0 and _p99 < _v93.get_line_count():
		return _v93.get_line(_p99)
	return ""
func _p45(_v93: CodeEdit, _m80: int = 500) -> String:
	var _p99 = _v93.get_caret_line()
	var caret_column = _v93.get_caret_column()
	var _s61 = ""
	if _p99 >= 0 and _p99 < _v93.get_line_count():
		var _f39 = _v93.get_line(_p99)
		if caret_column > 0:
			_s61 = _f39.substr(0, caret_column)
	var line = _p99 - 1
	while line >= 0 and _s61.length() < _m80:
		var _i71 = _v93.get_line(line)
		_s61 = _i71 + "\n" + _s61
		line -= 1
	if _s61.length() > _m80:
		_s61 = _s61.substr(_s61.length() - _m80)
	return _s61
func _z4(_v93: CodeEdit, _m80: int = 500) -> String:
	var _p99 = _v93.get_caret_line()
	var caret_column = _v93.get_caret_column()
	var _s61 = ""
	if _p99 >= 0 and _p99 < _v93.get_line_count():
		var _f39 = _v93.get_line(_p99)
		if caret_column < _f39.length():
			_s61 = _f39.substr(caret_column)
	var line = _p99 + 1
	while line < _v93.get_line_count() and _s61.length() < _m80:
		_s61 = _s61 + "\n" + _v93.get_line(line)
		line += 1
	if _s61.length() > _m80:
		_s61 = _s61.substr(0, _m80)
	return _s61
func _o78() -> String:
	if not _n12:
		return "gd"  
	var _k74 = _n12.get_current_script()
	if _k74:
		var path = _k74.resource_path
		if path.ends_with(".cs"):
			return "cs"
		elif path.ends_with(".gd"):
			return "gd"
	return "gd"  
func _i30(_v93: CodeEdit) -> int:
	var _p99 = _v93.get_caret_line()
	if _p99 >= 0 and _p99 < _v93.get_line_count():
		var line = _v93.get_line(_p99)
		var indent = 0
		for _q64 in line:
			if _q64 == "\t":
				indent += 1
			elif _q64 == " ":
				indent += 0.25  
			else:
				break
		return int(indent)
	return 0
func is_in_comment(_v93: CodeEdit) -> bool:
	var line = get_current_line(_v93)
	var caret_column = _v93.get_caret_column()
	var _h23 = line.find("#")
	if _h23 != -1 and _h23 < caret_column:
		return true
	return false
func is_in_string(_v93: CodeEdit) -> bool:
	var line = get_current_line(_v93)
	var caret_column = _v93.get_caret_column()
	var _q39 = 0
	var _t91 = 0
	var _a14 = 0
	for i in range(min(caret_column, line.length())):
		if i + 2 < line.length() and line.substr(i, 3) == "\"\"\"":
			_a14 += 1
			i += 2
		elif line[i] == "\"" and (i == 0 or line[i-1] != "\\"):
			_q39 += 1
		elif line[i] == "'" and (i == 0 or line[i-1] != "\\"):
			_t91 += 1
	return (_q39 % 2 == 1) or (_t91 % 2 == 1) or (_a14 % 2 == 1)
func _z53(_v93: CodeEdit) -> String:
	var line = get_current_line(_v93)
	var caret_column = _v93.get_caret_column()
	if caret_column == 0:
		return ""
	var _w50 = line.substr(0, caret_column)
	var _z74 = _w50.split(" ", false)
	if _z74.size() > 0:
		return _z74[-1]
	return ""
func _e76(_v93: CodeEdit) -> bool:
	var line = get_current_line(_v93)
	var caret_column = _v93.get_caret_column()
	if caret_column == 0:
		return false
	var _j52 = [".", "(", ":", "=", " "]
	var _n47 = line.substr(caret_column - 1, 1) if caret_column > 0 else ""
	return _n47 in _j52
func _v29(_v93: CodeEdit) -> bool:
	var line = get_current_line(_v93).strip_edges()
	if line.length() < 3:
		return false
	var _f64 = ["if", "for", "while", "func", "var", "const"]
	if line in _f64:
		return false
	return true
func _n1(_v93: CodeEdit) -> Dictionary:
	var _f39 = get_current_line(_v93)
	if _f39.length() > 200:
		_f39 = _f39.substr(0, 200)
	return {
		"currentLine": _f39,
		"before": _p45(_v93, 300),  
		"after": _z4(_v93, 300),    
		"cursorPosition": _v93.get_caret_column(),
		"fileType": _o78(),
		"indentLevel": _i30(_v93),
		"godotVersion": _k25()
	}
