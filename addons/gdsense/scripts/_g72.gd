@tool
class_name _n17
extends RefCounted
class _f84:
	var function_name: String
	var original_code: String
	var refactored_code: String
	var timestamp: String
	var file_path: String
	var function_line: int
	func _init(func_name: String, _s58: String, _a90: String, path: String, line: int):
		function_name = func_name
		original_code = _s58
		refactored_code = _a90
		timestamp = Time.get_datetime_string_from_system()
		file_path = path
		function_line = line
	func _s30() -> String:
		var _h22 = Time.get_datetime_dict_from_system()
		return "%04d-%02d-%02d %02d:%02d:%02d" % [_h22.year, _h22.month, _h22.day, _h22.hour, _h22.minute, _h22.second]
	func _x69(_u89: int = 3) -> String:
		var _j90 = original_code.split("\n")
		var _c14 = []
		for i in range(min(_u89, _j90.size())):
			_c14.append(_j90[i])
		if _j90.size() > _u89:
			_c14.append("...")
		return "\n".join(_c14)
const _q94 = 10
var _k14: Dictionary = {}
func _z70(function_name: String, original_code: String, refactored_code: String, file_path: String, function_line: int = 0) -> void:
	var _p42 = _f84.new(function_name, original_code, refactored_code, file_path, function_line)
	if not _k14.has(file_path):
		_k14[file_path] = []
	var _v95: Array = _k14[file_path]
	_v95.push_front(_p42)
	while _v95.size() > _q94:
		_v95.pop_back()
func _h84(function_name: String, file_path: String) -> _f84:
	if not _k14.has(file_path):
		return null
	var _v95: Array = _k14[file_path]
	for _p42 in _v95:
		if _p42.function_name == function_name:
			return _p42
	return null
func _l91(file_path: String) -> Array[_f84]:
	if not _k14.has(file_path):
		return []
	return _k14[file_path].duplicate()
func _n94() -> Dictionary:
	return _k14.duplicate(true)
func _k91(file_path: String) -> void:
	if _k14.has(file_path):
		_k14.erase(file_path)
func _x77() -> void:
	_k14.clear()
func _a64(function_name: String, file_path: String) -> bool:
	return _h84(function_name, file_path) != null
func _y25() -> int:
	var _b42 = 0
	for file_path in _k14.keys():
		_b42 += _k14[file_path].size()
	return _b42
func _k4() -> Array[String]:
	return _k14.keys()
func _p4(function_name: String, file_path: String, timestamp: String) -> bool:
	if not _k14.has(file_path):
		return false
	var _v95: Array = _k14[file_path]
	for i in range(_v95.size()):
		var _p42: _f84 = _v95[i]
		if _p42.function_name == function_name and _p42.timestamp == timestamp:
			_v95.remove_at(i)
			return true
	return false
func _g5() -> String:
	var _p29 = "RefactorHistory Debug Info:\n"
	_p29 += "Total files with history: %d\n" % _k14.size()
	_p29 += "Total entries: %d\n" % _y25()
	for file_path in _k14.keys():
		var _v95: Array = _k14[file_path]
		_p29 += "  %s: %d entries\n" % [file_path.get_file(), _v95.size()]
		for _p42 in _v95:
			_p29 += "    - %s (%s)\n" % [_p42.function_name, _p42._s30()]
	return _p29
func _q4(function_name: String, file_path: String) -> _f84:
	return _h84(function_name, file_path)
const _a97 = "user://refactor_history.json"
const _i53 = "user://refactor_history_backup.json"
func _w10():
	var _x8 = {}
	for file_path in _k14.keys():
		var _x43 = []
		for _p42 in _k14[file_path]:
			if _l63(_p42):
				_x43.append(_n23(_p42))
			else:
				pass
		if _x43.size() > 0:
			_x8[file_path] = _x43
	_m45()
	var file = FileAccess.open(_a97, FileAccess.WRITE)
	if file:
		var _t31 = JSON.stringify(_x8, "\t")
		if _t31 and not _t31.is_empty():
			file.store_string(_t31)
			file.close()
		else:
			file.close()
			push_error("[RefactorHistory] Failed to serialize history data")
			_h59()
	else:
		push_error("[RefactorHistory] Failed to save history to disk")
		_h59()
func _m53():
	var file = FileAccess.open(_a97, FileAccess.READ)
	if not file:
		return
	var _t31 = file.get_as_text()
	file.close()
	var json = JSON.new()
	var _v55 = json.parse(_t31)
	if _v55 != OK:
		push_error("[RefactorHistory] Failed to parse history file: %s" % json.get_error_message())
		_h59()
		return
	var _x8 = json.data
	if not _x8 is Dictionary:
		push_error("[RefactorHistory] Invalid history data format")
		_h59()
		return
	_k14.clear()
	for file_path in _x8.keys():
		var _x43 = _x8[file_path]
		if not _x43 is Array:
			continue
		var _l50 = []
		for _x47 in _x43:
			if _x47 is Dictionary:
				var _p42 = _y29(_x47)
				if _p42 and _l63(_p42):
					_l50.append(_p42)
		if _l50.size() > 0:
			_k14[file_path] = _l50
func _l63(_p42: _f84) -> bool:
	if not _p42:
		return false
	if _p42.function_name.is_empty():
		return false
	if _p42.original_code.is_empty() or _p42.refactored_code.is_empty():
		return false
	if _p42.file_path.is_empty():
		return false
	if _p42.function_line < 0:
		return false
	return true
func _n23(_p42: _f84) -> Dictionary:
	return {
		"function_name": _p42.function_name,
		"original_code": _p42.original_code,
		"refactored_code": _p42.refactored_code,
		"timestamp": _p42.timestamp,
		"file_path": _p42.file_path,
		"function_line": _p42.function_line
	}
func _y29(data: Dictionary) -> _f84:
	if not data.has_all(["function_name", "original_code", "refactored_code", "file_path"]):
		return null
	var _p42 = _f84.new(
		data.get("function_name", ""),
		data.get("original_code", ""),
		data.get("refactored_code", ""),
		data.get("file_path", ""),
		data.get("function_line", 0)
	)
	if data.has("timestamp"):
		_p42.timestamp = data["timestamp"]
	return _p42
func _m45():
	if FileAccess.file_exists(_a97):
		var source = FileAccess.open(_a97, FileAccess.READ)
		if source:
			var content = source.get_as_text()
			source.close()
			var _c81 = FileAccess.open(_i53, FileAccess.WRITE)
			if _c81:
				_c81.store_string(content)
				_c81.close()
func _h59():
	if not FileAccess.file_exists(_i53):
		return
	var _c81 = FileAccess.open(_i53, FileAccess.READ)
	if _c81:
		var content = _c81.get_as_text()
		_c81.close()
		var _t13 = FileAccess.open(_a97, FileAccess.WRITE)
		if _t13:
			_t13.store_string(content)
			_t13.close()
			_m53()
