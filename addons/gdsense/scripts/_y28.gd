@tool
class_name _w99
extends RefCounted

class _u22:
	var function_name: String
	var original_code: String
	var refactored_code: String
	var timestamp: String
	var file_path: String
	var function_line: int
	
	func _init(func_name: String, _h27: String, _o73: String, path: String, line: int):
		function_name = func_name
		original_code = _h27
		refactored_code = _o73
		timestamp = Time.get_datetime_string_from_system()
		file_path = path
		function_line = line
	
	func _s57() -> String:
		var _x79 = Time.get_datetime_dict_from_system()
		return "%04d-%02d-%02d %02d:%02d:%02d" % [_x79.year, _x79.month, _x79.day, _x79.hour, _x79.minute, _x79.second]
	
	func _d86(_g76: int = 3) -> String:
		var _m12 = original_code.split("\n")
		var _k100 = []
		for i in range(min(_g76, _m12.size())):
			_k100.append(_m12[i])
		if _m12.size() > _g76:
			_k100.append("...")
		return "\n".join(_k100)

const _i6 = 10

var _s3: Dictionary = {}

func _f11(function_name: String, original_code: String, refactored_code: String, file_path: String, function_line: int = 0) -> void:
	var _j91 = _u22.new(function_name, original_code, refactored_code, file_path, function_line)
	
	if not _s3.has(file_path):
		_s3[file_path] = []
	
	var _j82: Array = _s3[file_path]
	
	_j82.push_front(_j91)
	
	while _j82.size() > _i6:
		_j82.pop_back()
	
func _e41(function_name: String, file_path: String) -> _u22:
	if not _s3.has(file_path):
		return null
	
	var _j82: Array = _s3[file_path]
	
	for _j91 in _j82:
		if _j91.function_name == function_name:
			return _j91
	
	return null

func _h35(file_path: String) -> Array[_u22]:
	if not _s3.has(file_path):
		return []
	
	return _s3[file_path].duplicate()

func _r80() -> Dictionary:
	return _s3.duplicate(true)

func _e58(file_path: String) -> void:
	if _s3.has(file_path):
		_s3.erase(file_path)
func _t7() -> void:
	_s3.clear()
func _p100(function_name: String, file_path: String) -> bool:
	return _e41(function_name, file_path) != null

func _r85() -> int:
	var _e69 = 0
	for file_path in _s3.keys():
		_e69 += _s3[file_path].size()
	return _e69

func _n79() -> Array[String]:
	return _s3.keys()

func _e4(function_name: String, file_path: String, timestamp: String) -> bool:
	if not _s3.has(file_path):
		return false
	
	var _j82: Array = _s3[file_path]
	
	for i in range(_j82.size()):
		var _j91: _u22 = _j82[i]
		if _j91.function_name == function_name and _j91.timestamp == timestamp:
			_j82.remove_at(i)
			return true
	
	return false

func _h72() -> String:
	var _h31 = "RefactorHistory Debug Info:\n"
	_h31 += "Total files with history: %d\n" % _s3.size()
	_h31 += "Total entries: %d\n" % _r85()
	
	for file_path in _s3.keys():
		var _j82: Array = _s3[file_path]
		_h31 += "  %s: %d entries\n" % [file_path.get_file(), _j82.size()]
		
		for _j91 in _j82:
			_h31 += "    - %s (%s)\n" % [_j91.function_name, _j91._s57()]
	
	return _h31

func _z80(function_name: String, file_path: String) -> _u22:
	return _e41(function_name, file_path)

const _g10 = "user://refactor_history.json"
const _q44 = "user://refactor_history_backup.json"

func _p31():
	var _i66 = {}
	
	for file_path in _s3.keys():
		var _h9 = []
		for _j91 in _s3[file_path]:
			if _f88(_j91):
				_h9.append(_z4(_j91))
			else:
				pass

		if _h9.size() > 0:
			_i66[file_path] = _h9
	
	_t42()
	
	var file = FileAccess.open(_g10, FileAccess.WRITE)
	if file:
		var _r87 = JSON.stringify(_i66, "\t")
		if _r87 and not _r87.is_empty():
			file.store_string(_r87)
			file.close()
			
		else:
			file.close()
			push_error("[RefactorHistory] Failed to serialize history data")
			_z56()
	else:
		push_error("[RefactorHistory] Failed to save history to disk")
		_z56()

func _z100():
	var file = FileAccess.open(_g10, FileAccess.READ)
	if not file:
		return
	
	var _r87 = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var _d58 = json.parse(_r87)
	
	if _d58 != OK:
		push_error("[RefactorHistory] Failed to parse history file: %s" % json.get_error_message())
		_z56()
		return
	
	var _i66 = json.data
	if not _i66 is Dictionary:
		push_error("[RefactorHistory] Invalid history data format")
		_z56()
		return
	
	_s3.clear()
	
	for file_path in _i66.keys():
		var _h9 = _i66[file_path]
		if not _h9 is Array:
			continue
		
		var _r51 = []
		for _h10 in _h9:
			if _h10 is Dictionary:
				var _j91 = _r53(_h10)
				if _j91 and _f88(_j91):
					_r51.append(_j91)
		
		if _r51.size() > 0:
			_s3[file_path] = _r51
	
func _f88(_j91: _u22) -> bool:
	if not _j91:
		return false
	
	if _j91.function_name.is_empty():
		return false
	
	if _j91.original_code.is_empty() or _j91.refactored_code.is_empty():
		return false
	
	if _j91.file_path.is_empty():
		return false
	
	if _j91.function_line < 0:
		return false
	
	return true

func _z4(_j91: _u22) -> Dictionary:
	return {
		"function_name": _j91.function_name,
		"original_code": _j91.original_code,
		"refactored_code": _j91.refactored_code,
		"timestamp": _j91.timestamp,
		"file_path": _j91.file_path,
		"function_line": _j91.function_line
	}

func _r53(data: Dictionary) -> _u22:
	if not data.has_all(["function_name", "original_code", "refactored_code", "file_path"]):
		return null
	
	var _j91 = _u22.new(
		data.get("function_name", ""),
		data.get("original_code", ""),
		data.get("refactored_code", ""),
		data.get("file_path", ""),
		data.get("function_line", 0)
	)
	
	if data.has("timestamp"):
		_j91.timestamp = data["timestamp"]
	
	return _j91

func _t42():
	if FileAccess.file_exists(_g10):
		var source = FileAccess.open(_g10, FileAccess.READ)
		if source:
			var content = source.get_as_text()
			source.close()
			
			var _o46 = FileAccess.open(_q44, FileAccess.WRITE)
			if _o46:
				_o46.store_string(content)
				_o46.close()
func _z56():
	if not FileAccess.file_exists(_q44):
		return
	
	var _o46 = FileAccess.open(_q44, FileAccess.READ)
	if _o46:
		var content = _o46.get_as_text()
		_o46.close()
		
		var _s25 = FileAccess.open(_g10, FileAccess.WRITE)
		if _s25:
			_s25.store_string(content)
			_s25.close()

			_z100()

