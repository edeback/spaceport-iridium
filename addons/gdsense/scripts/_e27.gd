@tool
class_name _z9
extends RefCounted
class _l87:
	var function_name: String
	var original_code: String
	var refactored_code: String
	var timestamp: String
	var file_path: String
	var function_line: int
	func _init(func_name: String, _h86: String, _y10: String, path: String, line: int):
		function_name = func_name
		original_code = _h86
		refactored_code = _y10
		timestamp = Time.get_datetime_string_from_system()
		file_path = path
		function_line = line
	func _v7() -> String:
		var _s58 = Time.get_datetime_dict_from_system()
		return "%04d-%02d-%02d %02d:%02d:%02d" % [_s58.year, _s58.month, _s58.day, _s58.hour, _s58.minute, _s58.second]
	func _c59(_x29: int = 3) -> String:
		var _p91 = original_code.split("\n")
		var _z79 = []
		for i in range(min(_x29, _p91.size())):
			_z79.append(_p91[i])
		if _p91.size() > _x29:
			_z79.append("...")
		return "\n".join(_z79)
const _j30 = 10
var _c25: Dictionary = {}
func _o76(function_name: String, original_code: String, refactored_code: String, file_path: String, function_line: int = 0) -> void:
	var _r10 = _l87.new(function_name, original_code, refactored_code, file_path, function_line)
	if not _c25.has(file_path):
		_c25[file_path] = []
	var _t18: Array = _c25[file_path]
	_t18.push_front(_r10)
	while _t18.size() > _j30:
		_t18.pop_back()
func _m18(function_name: String, file_path: String) -> _l87:
	if not _c25.has(file_path):
		return null
	var _t18: Array = _c25[file_path]
	for _r10 in _t18:
		if _r10.function_name == function_name:
			return _r10
	return null
func _f87(file_path: String) -> Array[_l87]:
	if not _c25.has(file_path):
		return []
	return _c25[file_path].duplicate()
func _g33() -> Dictionary:
	return _c25.duplicate(true)
func _t8(file_path: String) -> void:
	if _c25.has(file_path):
		_c25.erase(file_path)
func _c91() -> void:
	_c25.clear()
func _c19(function_name: String, file_path: String) -> bool:
	return _m18(function_name, file_path) != null
func _b42() -> int:
	var _y18 = 0
	for file_path in _c25.keys():
		_y18 += _c25[file_path].size()
	return _y18
func _i29() -> Array[String]:
	return _c25.keys()
func _l89(function_name: String, file_path: String, timestamp: String) -> bool:
	if not _c25.has(file_path):
		return false
	var _t18: Array = _c25[file_path]
	for i in range(_t18.size()):
		var _r10: _l87 = _t18[i]
		if _r10.function_name == function_name and _r10.timestamp == timestamp:
			_t18.remove_at(i)
			return true
	return false
func _n13() -> String:
	var _s83 = "RefactorHistory Debug Info:\n"
	_s83 += "Total files with history: %d\n" % _c25.size()
	_s83 += "Total entries: %d\n" % _b42()
	for file_path in _c25.keys():
		var _t18: Array = _c25[file_path]
		_s83 += "  %s: %d entries\n" % [file_path.get_file(), _t18.size()]
		for _r10 in _t18:
			_s83 += "    - %s (%s)\n" % [_r10.function_name, _r10._v7()]
	return _s83
func _b56(function_name: String, file_path: String) -> _l87:
	return _m18(function_name, file_path)
const _d55 = "user://refactor_history.json"
const _n26 = "user://refactor_history_backup.json"
func _d97():
	var _b55 = {}
	for file_path in _c25.keys():
		var _r94 = []
		for _r10 in _c25[file_path]:
			if _s59(_r10):
				_r94.append(_w83(_r10))
			else:
				pass
		if _r94.size() > 0:
			_b55[file_path] = _r94
	_f37()
	var file = FileAccess.open(_d55, FileAccess.WRITE)
	if file:
		var _f74 = JSON.stringify(_b55, "\t")
		if _f74 and not _f74.is_empty():
			file.store_string(_f74)
			file.close()
		else:
			file.close()
			push_error("[RefactorHistory] Failed to serialize history data")
			_k43()
	else:
		push_error("[RefactorHistory] Failed to save history to disk")
		_k43()
func _v97():
	var file = FileAccess.open(_d55, FileAccess.READ)
	if not file:
		return
	var _f74 = file.get_as_text()
	file.close()
	var json = JSON.new()
	var _n76 = json.parse(_f74)
	if _n76 != OK:
		push_error("[RefactorHistory] Failed to parse history file: %s" % json.get_error_message())
		_k43()
		return
	var _b55 = json.data
	if not _b55 is Dictionary:
		push_error("[RefactorHistory] Invalid history data format")
		_k43()
		return
	_c25.clear()
	for file_path in _b55.keys():
		var _r94 = _b55[file_path]
		if not _r94 is Array:
			continue
		var _e43 = []
		for _m84 in _r94:
			if _m84 is Dictionary:
				var _r10 = _q90(_m84)
				if _r10 and _s59(_r10):
					_e43.append(_r10)
		if _e43.size() > 0:
			_c25[file_path] = _e43
func _s59(_r10: _l87) -> bool:
	if not _r10:
		return false
	if _r10.function_name.is_empty():
		return false
	if _r10.original_code.is_empty() or _r10.refactored_code.is_empty():
		return false
	if _r10.file_path.is_empty():
		return false
	if _r10.function_line < 0:
		return false
	return true
func _w83(_r10: _l87) -> Dictionary:
	return {
		"function_name": _r10.function_name,
		"original_code": _r10.original_code,
		"refactored_code": _r10.refactored_code,
		"timestamp": _r10.timestamp,
		"file_path": _r10.file_path,
		"function_line": _r10.function_line
	}
func _q90(data: Dictionary) -> _l87:
	if not data.has_all(["function_name", "original_code", "refactored_code", "file_path"]):
		return null
	var _r10 = _l87.new(
		data.get("function_name", ""),
		data.get("original_code", ""),
		data.get("refactored_code", ""),
		data.get("file_path", ""),
		data.get("function_line", 0)
	)
	if data.has("timestamp"):
		_r10.timestamp = data["timestamp"]
	return _r10
func _f37():
	if FileAccess.file_exists(_d55):
		var source = FileAccess.open(_d55, FileAccess.READ)
		if source:
			var content = source.get_as_text()
			source.close()
			var _o38 = FileAccess.open(_n26, FileAccess.WRITE)
			if _o38:
				_o38.store_string(content)
				_o38.close()
func _k43():
	if not FileAccess.file_exists(_n26):
		return
	var _o38 = FileAccess.open(_n26, FileAccess.READ)
	if _o38:
		var content = _o38.get_as_text()
		_o38.close()
		var _b14 = FileAccess.open(_d55, FileAccess.WRITE)
		if _b14:
			_b14.store_string(content)
			_b14.close()
			_v97()
