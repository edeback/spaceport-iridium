@tool
class_name _z98
extends RefCounted
class _c40:
	var function_name: String
	var original_code: String
	var refactored_code: String
	var timestamp: String
	var file_path: String
	var function_line: int
	func _init(func_name: String, _f31: String, _e75: String, path: String, line: int):
		function_name = func_name
		original_code = _f31
		refactored_code = _e75
		timestamp = Time.get_datetime_string_from_system()
		file_path = path
		function_line = line
	func _q22() -> String:
		var _q12 = Time.get_datetime_dict_from_system()
		return "%04d-%02d-%02d %02d:%02d:%02d" % [_q12.year, _q12.month, _q12.day, _q12.hour, _q12.minute, _q12.second]
	func _i49(_f51: int = 3) -> String:
		var _t70 = original_code.split("\n")
		var _k58 = []
		for i in range(min(_f51, _t70.size())):
			_k58.append(_t70[i])
		if _t70.size() > _f51:
			_k58.append("...")
		return "\n".join(_k58)
const _n98 = 10
var _c98: Dictionary = {}
func _i79(function_name: String, original_code: String, refactored_code: String, file_path: String, function_line: int = 0) -> void:
	var _y92 = _c40.new(function_name, original_code, refactored_code, file_path, function_line)
	if not _c98.has(file_path):
		_c98[file_path] = []
	var _r94: Array = _c98[file_path]
	_r94.push_front(_y92)
	while _r94.size() > _n98:
		_r94.pop_back()
func _f32(function_name: String, file_path: String) -> _c40:
	if not _c98.has(file_path):
		return null
	var _r94: Array = _c98[file_path]
	for _y92 in _r94:
		if _y92.function_name == function_name:
			return _y92
	return null
func _z48(file_path: String) -> Array[_c40]:
	if not _c98.has(file_path):
		return []
	return _c98[file_path].duplicate()
func _c80() -> Dictionary:
	return _c98.duplicate(true)
func _m29(file_path: String) -> void:
	if _c98.has(file_path):
		_c98.erase(file_path)
func _k46() -> void:
	_c98.clear()
func _r30(function_name: String, file_path: String) -> bool:
	return _f32(function_name, file_path) != null
func _o10() -> int:
	var _t89 = 0
	for file_path in _c98.keys():
		_t89 += _c98[file_path].size()
	return _t89
func _g58() -> Array[String]:
	return _c98.keys()
func _w9(function_name: String, file_path: String, timestamp: String) -> bool:
	if not _c98.has(file_path):
		return false
	var _r94: Array = _c98[file_path]
	for i in range(_r94.size()):
		var _y92: _c40 = _r94[i]
		if _y92.function_name == function_name and _y92.timestamp == timestamp:
			_r94.remove_at(i)
			return true
	return false
func _t99() -> String:
	var _k73 = "RefactorHistory Debug Info:\n"
	_k73 += "Total files with history: %d\n" % _c98.size()
	_k73 += "Total entries: %d\n" % _o10()
	for file_path in _c98.keys():
		var _r94: Array = _c98[file_path]
		_k73 += "  %s: %d entries\n" % [file_path.get_file(), _r94.size()]
		for _y92 in _r94:
			_k73 += "    - %s (%s)\n" % [_y92.function_name, _y92._q22()]
	return _k73
func _u28(function_name: String, file_path: String) -> _c40:
	return _f32(function_name, file_path)
const _g80 = "user://refactor_history.json"
const _m84 = "user://refactor_history_backup.json"
func _j92():
	var _y94 = {}
	for file_path in _c98.keys():
		var _n41 = []
		for _y92 in _c98[file_path]:
			if _l32(_y92):
				_n41.append(_q92(_y92))
			else:
				pass
		if _n41.size() > 0:
			_y94[file_path] = _n41
	_e97()
	var file = FileAccess.open(_g80, FileAccess.WRITE)
	if file:
		var _y80 = JSON.stringify(_y94, "\t")
		if _y80 and not _y80.is_empty():
			file.store_string(_y80)
			file.close()
		else:
			file.close()
			push_error("[RefactorHistory] Failed to serialize history data")
			_y88()
	else:
		push_error("[RefactorHistory] Failed to save history to disk")
		_y88()
func _z60():
	var file = FileAccess.open(_g80, FileAccess.READ)
	if not file:
		return
	var _y80 = file.get_as_text()
	file.close()
	var json = JSON.new()
	var _v96 = json.parse(_y80)
	if _v96 != OK:
		push_error("[RefactorHistory] Failed to parse history file: %s" % json.get_error_message())
		_y88()
		return
	var _y94 = json.data
	if not _y94 is Dictionary:
		push_error("[RefactorHistory] Invalid history data format")
		_y88()
		return
	_c98.clear()
	for file_path in _y94.keys():
		var _n41 = _y94[file_path]
		if not _n41 is Array:
			continue
		var _e38 = []
		for _j51 in _n41:
			if _j51 is Dictionary:
				var _y92 = _s80(_j51)
				if _y92 and _l32(_y92):
					_e38.append(_y92)
		if _e38.size() > 0:
			_c98[file_path] = _e38
func _l32(_y92: _c40) -> bool:
	if not _y92:
		return false
	if _y92.function_name.is_empty():
		return false
	if _y92.original_code.is_empty() or _y92.refactored_code.is_empty():
		return false
	if _y92.file_path.is_empty():
		return false
	if _y92.function_line < 0:
		return false
	return true
func _q92(_y92: _c40) -> Dictionary:
	return {
		"function_name": _y92.function_name,
		"original_code": _y92.original_code,
		"refactored_code": _y92.refactored_code,
		"timestamp": _y92.timestamp,
		"file_path": _y92.file_path,
		"function_line": _y92.function_line
	}
func _s80(data: Dictionary) -> _c40:
	if not data.has_all(["function_name", "original_code", "refactored_code", "file_path"]):
		return null
	var _y92 = _c40.new(
		data.get("function_name", ""),
		data.get("original_code", ""),
		data.get("refactored_code", ""),
		data.get("file_path", ""),
		data.get("function_line", 0)
	)
	if data.has("timestamp"):
		_y92.timestamp = data["timestamp"]
	return _y92
func _e97():
	if FileAccess.file_exists(_g80):
		var source = FileAccess.open(_g80, FileAccess.READ)
		if source:
			var content = source.get_as_text()
			source.close()
			var _r66 = FileAccess.open(_m84, FileAccess.WRITE)
			if _r66:
				_r66.store_string(content)
				_r66.close()
func _y88():
	if not FileAccess.file_exists(_m84):
		return
	var _r66 = FileAccess.open(_m84, FileAccess.READ)
	if _r66:
		var content = _r66.get_as_text()
		_r66.close()
		var _s21 = FileAccess.open(_g80, FileAccess.WRITE)
		if _s21:
			_s21.store_string(content)
			_s21.close()
			_z60()
