@tool
class_name _z30
extends RefCounted
class _n40:
	var function_name: String
	var original_code: String
	var refactored_code: String
	var timestamp: String
	var file_path: String
	var function_line: int
	func _init(func_name: String, _i56: String, _z52: String, path: String, line: int):
		function_name = func_name
		original_code = _i56
		refactored_code = _z52
		timestamp = Time.get_datetime_string_from_system()
		file_path = path
		function_line = line
	func _s37() -> String:
		var _y49 = Time.get_datetime_dict_from_system()
		return "%04d-%02d-%02d %02d:%02d:%02d" % [_y49.year, _y49.month, _y49.day, _y49.hour, _y49.minute, _y49.second]
	func _v80(_g99: int = 3) -> String:
		var _a62 = original_code.split("\n")
		var _m87 = []
		for i in range(min(_g99, _a62.size())):
			_m87.append(_a62[i])
		if _a62.size() > _g99:
			_m87.append("...")
		return "\n".join(_m87)
const _a96 = 10
var _x49: Dictionary = {}
func _b89(function_name: String, original_code: String, refactored_code: String, file_path: String, function_line: int = 0) -> void:
	var _x74 = _n40.new(function_name, original_code, refactored_code, file_path, function_line)
	if not _x49.has(file_path):
		_x49[file_path] = []
	var _z46: Array = _x49[file_path]
	_z46.push_front(_x74)
	while _z46.size() > _a96:
		_z46.pop_back()
func _a18(function_name: String, file_path: String) -> _n40:
	if not _x49.has(file_path):
		return null
	var _z46: Array = _x49[file_path]
	for _x74 in _z46:
		if _x74.function_name == function_name:
			return _x74
	return null
func _b2(file_path: String) -> Array[_n40]:
	if not _x49.has(file_path):
		return []
	return _x49[file_path].duplicate()
func _l90() -> Dictionary:
	return _x49.duplicate(true)
func _z63(file_path: String) -> void:
	if _x49.has(file_path):
		_x49.erase(file_path)
func _z5() -> void:
	_x49.clear()
func _k38(function_name: String, file_path: String) -> bool:
	return _a18(function_name, file_path) != null
func _b82() -> int:
	var _f64 = 0
	for file_path in _x49.keys():
		_f64 += _x49[file_path].size()
	return _f64
func _n27() -> Array[String]:
	return _x49.keys()
func _e21(function_name: String, file_path: String, timestamp: String) -> bool:
	if not _x49.has(file_path):
		return false
	var _z46: Array = _x49[file_path]
	for i in range(_z46.size()):
		var _x74: _n40 = _z46[i]
		if _x74.function_name == function_name and _x74.timestamp == timestamp:
			_z46.remove_at(i)
			return true
	return false
func _p38() -> String:
	var _y4 = "RefactorHistory Debug Info:\n"
	_y4 += "Total files with history: %d\n" % _x49.size()
	_y4 += "Total entries: %d\n" % _b82()
	for file_path in _x49.keys():
		var _z46: Array = _x49[file_path]
		_y4 += "  %s: %d entries\n" % [file_path.get_file(), _z46.size()]
		for _x74 in _z46:
			_y4 += "    - %s (%s)\n" % [_x74.function_name, _x74._s37()]
	return _y4
func _o96(function_name: String, file_path: String) -> _n40:
	return _a18(function_name, file_path)
const _f61 = "user://refactor_history.json"
const _g76 = "user://refactor_history_backup.json"
func _t72():
	var _s79 = {}
	for file_path in _x49.keys():
		var _g95 = []
		for _x74 in _x49[file_path]:
			if _i73(_x74):
				_g95.append(_s24(_x74))
			else:
				pass
		if _g95.size() > 0:
			_s79[file_path] = _g95
	_n20()
	var file = FileAccess.open(_f61, FileAccess.WRITE)
	if file:
		var _g5 = JSON.stringify(_s79, "\t")
		if _g5 and not _g5.is_empty():
			file.store_string(_g5)
			file.close()
		else:
			file.close()
			push_error("[RefactorHistory] Failed to serialize history data")
			_n61()
	else:
		push_error("[RefactorHistory] Failed to save history to disk")
		_n61()
func _j55():
	var file = FileAccess.open(_f61, FileAccess.READ)
	if not file:
		return
	var _g5 = file.get_as_text()
	file.close()
	var json = JSON.new()
	var _a50 = json.parse(_g5)
	if _a50 != OK:
		push_error("[RefactorHistory] Failed to parse history file: %s" % json.get_error_message())
		_n61()
		return
	var _s79 = json.data
	if not _s79 is Dictionary:
		push_error("[RefactorHistory] Invalid history data format")
		_n61()
		return
	_x49.clear()
	for file_path in _s79.keys():
		var _g95 = _s79[file_path]
		if not _g95 is Array:
			continue
		var _q24 = []
		for _v42 in _g95:
			if _v42 is Dictionary:
				var _x74 = _a31(_v42)
				if _x74 and _i73(_x74):
					_q24.append(_x74)
		if _q24.size() > 0:
			_x49[file_path] = _q24
func _i73(_x74: _n40) -> bool:
	if not _x74:
		return false
	if _x74.function_name.is_empty():
		return false
	if _x74.original_code.is_empty() or _x74.refactored_code.is_empty():
		return false
	if _x74.file_path.is_empty():
		return false
	if _x74.function_line < 0:
		return false
	return true
func _s24(_x74: _n40) -> Dictionary:
	return {
		"function_name": _x74.function_name,
		"original_code": _x74.original_code,
		"refactored_code": _x74.refactored_code,
		"timestamp": _x74.timestamp,
		"file_path": _x74.file_path,
		"function_line": _x74.function_line
	}
func _a31(data: Dictionary) -> _n40:
	if not data.has_all(["function_name", "original_code", "refactored_code", "file_path"]):
		return null
	var _x74 = _n40.new(
		data.get("function_name", ""),
		data.get("original_code", ""),
		data.get("refactored_code", ""),
		data.get("file_path", ""),
		data.get("function_line", 0)
	)
	if data.has("timestamp"):
		_x74.timestamp = data["timestamp"]
	return _x74
func _n20():
	if FileAccess.file_exists(_f61):
		var source = FileAccess.open(_f61, FileAccess.READ)
		if source:
			var content = source.get_as_text()
			source.close()
			var _o35 = FileAccess.open(_g76, FileAccess.WRITE)
			if _o35:
				_o35.store_string(content)
				_o35.close()
func _n61():
	if not FileAccess.file_exists(_g76):
		return
	var _o35 = FileAccess.open(_g76, FileAccess.READ)
	if _o35:
		var content = _o35.get_as_text()
		_o35.close()
		var _t73 = FileAccess.open(_f61, FileAccess.WRITE)
		if _t73:
			_t73.store_string(content)
			_t73.close()
			_j55()
