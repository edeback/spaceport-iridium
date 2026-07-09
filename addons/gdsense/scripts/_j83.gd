@tool
class_name _o9
extends RefCounted

class _c71:
	var function_name: String
	var original_code: String
	var refactored_code: String
	var timestamp: String
	var file_path: String
	var function_line: int
	
	func _init(func_name: String, _h20: String, _u7: String, path: String, line: int):
		function_name = func_name
		original_code = _h20
		refactored_code = _u7
		timestamp = Time.get_datetime_string_from_system()
		file_path = path
		function_line = line
	
	func _c45() -> String:
		var _p48 = Time.get_datetime_dict_from_system()
		return "%04d-%02d-%02d %02d:%02d:%02d" % [_p48.year, _p48.month, _p48.day, _p48.hour, _p48.minute, _p48.second]
	
	func _k12(_m69: int = 3) -> String:
		var _b26 = original_code.split("\n")
		var _i99 = []
		for i in range(min(_m69, _b26.size())):
			_i99.append(_b26[i])
		if _b26.size() > _m69:
			_i99.append("...")
		return "\n".join(_i99)

const _k35 = 10

var _i74: Dictionary = {}

func _n14(function_name: String, original_code: String, refactored_code: String, file_path: String, function_line: int = 0) -> void:
	var _w90 = _c71.new(function_name, original_code, refactored_code, file_path, function_line)
	
	if not _i74.has(file_path):
		_i74[file_path] = []
	
	var _u68: Array = _i74[file_path]
	
	_u68.push_front(_w90)
	
	while _u68.size() > _k35:
		_u68.pop_back()
	
func _t6(function_name: String, file_path: String) -> _c71:
	if not _i74.has(file_path):
		return null
	
	var _u68: Array = _i74[file_path]
	
	for _w90 in _u68:
		if _w90.function_name == function_name:
			return _w90
	
	return null

func _s37(file_path: String) -> Array[_c71]:
	if not _i74.has(file_path):
		return []
	
	return _i74[file_path].duplicate()

func _n70() -> Dictionary:
	return _i74.duplicate(true)

func _f9(file_path: String) -> void:
	if _i74.has(file_path):
		_i74.erase(file_path)
func _g81() -> void:
	_i74.clear()
func _e76(function_name: String, file_path: String) -> bool:
	return _t6(function_name, file_path) != null

func _e63() -> int:
	var _g84 = 0
	for file_path in _i74.keys():
		_g84 += _i74[file_path].size()
	return _g84

func _r39() -> Array[String]:
	return _i74.keys()

func _e22(function_name: String, file_path: String, timestamp: String) -> bool:
	if not _i74.has(file_path):
		return false
	
	var _u68: Array = _i74[file_path]
	
	for i in range(_u68.size()):
		var _w90: _c71 = _u68[i]
		if _w90.function_name == function_name and _w90.timestamp == timestamp:
			_u68.remove_at(i)
			return true
	
	return false

func _z48() -> String:
	var _x17 = "RefactorHistory Debug Info:\n"
	_x17 += "Total files with history: %d\n" % _i74.size()
	_x17 += "Total entries: %d\n" % _e63()
	
	for file_path in _i74.keys():
		var _u68: Array = _i74[file_path]
		_x17 += "  %s: %d entries\n" % [file_path.get_file(), _u68.size()]
		
		for _w90 in _u68:
			_x17 += "    - %s (%s)\n" % [_w90.function_name, _w90._c45()]
	
	return _x17

func _u16(function_name: String, file_path: String) -> _c71:
	return _t6(function_name, file_path)

const _k91 = "user://refactor_history.json"
const _y73 = "user://refactor_history_backup.json"

func _g15():
	var _u72 = {}
	
	for file_path in _i74.keys():
		var _p45 = []
		for _w90 in _i74[file_path]:
			if _l62(_w90):
				_p45.append(_d22(_w90))
			else:
				pass

		if _p45.size() > 0:
			_u72[file_path] = _p45
	
	_y9()
	
	var file = FileAccess.open(_k91, FileAccess.WRITE)
	if file:
		var _w7 = JSON.stringify(_u72, "\t")
		if _w7 and not _w7.is_empty():
			file.store_string(_w7)
			file.close()
			
		else:
			file.close()
			push_error("[RefactorHistory] Failed to serialize history data")
			_x11()
	else:
		push_error("[RefactorHistory] Failed to save history to disk")
		_x11()

func _x5():
	var file = FileAccess.open(_k91, FileAccess.READ)
	if not file:
		return
	
	var _w7 = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var _q58 = json.parse(_w7)
	
	if _q58 != OK:
		push_error("[RefactorHistory] Failed to parse history file: %s" % json.get_error_message())
		_x11()
		return
	
	var _u72 = json.data
	if not _u72 is Dictionary:
		push_error("[RefactorHistory] Invalid history data format")
		_x11()
		return
	
	_i74.clear()
	
	for file_path in _u72.keys():
		var _p45 = _u72[file_path]
		if not _p45 is Array:
			continue
		
		var _r3 = []
		for _u25 in _p45:
			if _u25 is Dictionary:
				var _w90 = _m100(_u25)
				if _w90 and _l62(_w90):
					_r3.append(_w90)
		
		if _r3.size() > 0:
			_i74[file_path] = _r3
	
func _l62(_w90: _c71) -> bool:
	if not _w90:
		return false
	
	if _w90.function_name.is_empty():
		return false
	
	if _w90.original_code.is_empty() or _w90.refactored_code.is_empty():
		return false
	
	if _w90.file_path.is_empty():
		return false
	
	if _w90.function_line < 0:
		return false
	
	return true

func _d22(_w90: _c71) -> Dictionary:
	return {
		"function_name": _w90.function_name,
		"original_code": _w90.original_code,
		"refactored_code": _w90.refactored_code,
		"timestamp": _w90.timestamp,
		"file_path": _w90.file_path,
		"function_line": _w90.function_line
	}

func _m100(data: Dictionary) -> _c71:
	if not data.has_all(["function_name", "original_code", "refactored_code", "file_path"]):
		return null
	
	var _w90 = _c71.new(
		data.get("function_name", ""),
		data.get("original_code", ""),
		data.get("refactored_code", ""),
		data.get("file_path", ""),
		data.get("function_line", 0)
	)
	
	if data.has("timestamp"):
		_w90.timestamp = data["timestamp"]
	
	return _w90

func _y9():
	if FileAccess.file_exists(_k91):
		var source = FileAccess.open(_k91, FileAccess.READ)
		if source:
			var content = source.get_as_text()
			source.close()
			
			var _y3 = FileAccess.open(_y73, FileAccess.WRITE)
			if _y3:
				_y3.store_string(content)
				_y3.close()
func _x11():
	if not FileAccess.file_exists(_y73):
		return
	
	var _y3 = FileAccess.open(_y73, FileAccess.READ)
	if _y3:
		var content = _y3.get_as_text()
		_y3.close()
		
		var _c55 = FileAccess.open(_k91, FileAccess.WRITE)
		if _c55:
			_c55.store_string(content)
			_c55.close()

			_x5()

