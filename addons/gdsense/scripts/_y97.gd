@tool
class_name _b26
extends RefCounted

class _n2:
	var function_name: String
	var original_code: String
	var refactored_code: String
	var timestamp: String
	var file_path: String
	var function_line: int
	
	func _init(func_name: String, _k95: String, _j73: String, path: String, line: int):
		function_name = func_name
		original_code = _k95
		refactored_code = _j73
		timestamp = Time.get_datetime_string_from_system()
		file_path = path
		function_line = line
	
	func _l34() -> String:
		var _r6 = Time.get_datetime_dict_from_system()
		return "%04d-%02d-%02d %02d:%02d:%02d" % [_r6.year, _r6.month, _r6.day, _r6.hour, _r6.minute, _r6.second]
	
	func _e45(_k4: int = 3) -> String:
		var _d41 = original_code.split("\n")
		var _b72 = []
		for i in range(min(_k4, _d41.size())):
			_b72.append(_d41[i])
		if _d41.size() > _k4:
			_b72.append("...")
		return "\n".join(_b72)

const _j23 = 10

var _r72: Dictionary = {}

func _m88(function_name: String, original_code: String, refactored_code: String, file_path: String, function_line: int = 0) -> void:
	var _h5 = _n2.new(function_name, original_code, refactored_code, file_path, function_line)
	
	if not _r72.has(file_path):
		_r72[file_path] = []
	
	var _o40: Array = _r72[file_path]
	
	_o40.push_front(_h5)
	
	while _o40.size() > _j23:
		_o40.pop_back()
	
func _j51(function_name: String, file_path: String) -> _n2:
	if not _r72.has(file_path):
		return null
	
	var _o40: Array = _r72[file_path]
	
	for _h5 in _o40:
		if _h5.function_name == function_name:
			return _h5
	
	return null

func _o92(file_path: String) -> Array[_n2]:
	if not _r72.has(file_path):
		return []
	
	return _r72[file_path].duplicate()

func _w78() -> Dictionary:
	return _r72.duplicate(true)

func _a90(file_path: String) -> void:
	if _r72.has(file_path):
		_r72.erase(file_path)
func _f4() -> void:
	_r72.clear()
func _a6(function_name: String, file_path: String) -> bool:
	return _j51(function_name, file_path) != null

func _v87() -> int:
	var _q56 = 0
	for file_path in _r72.keys():
		_q56 += _r72[file_path].size()
	return _q56

func _o54() -> Array[String]:
	return _r72.keys()

func _c23(function_name: String, file_path: String, timestamp: String) -> bool:
	if not _r72.has(file_path):
		return false
	
	var _o40: Array = _r72[file_path]
	
	for i in range(_o40.size()):
		var _h5: _n2 = _o40[i]
		if _h5.function_name == function_name and _h5.timestamp == timestamp:
			_o40.remove_at(i)
			return true
	
	return false

func _t33() -> String:
	var _z1 = "RefactorHistory Debug Info:\n"
	_z1 += "Total files with history: %d\n" % _r72.size()
	_z1 += "Total entries: %d\n" % _v87()
	
	for file_path in _r72.keys():
		var _o40: Array = _r72[file_path]
		_z1 += "  %s: %d entries\n" % [file_path.get_file(), _o40.size()]
		
		for _h5 in _o40:
			_z1 += "    - %s (%s)\n" % [_h5.function_name, _h5._l34()]
	
	return _z1

func _k43(function_name: String, file_path: String) -> _n2:
	return _j51(function_name, file_path)

const _f34 = "user://refactor_history.json"
const _x47 = "user://refactor_history_backup.json"

func _s19():
	var _m54 = {}
	
	for file_path in _r72.keys():
		var _r7 = []
		for _h5 in _r72[file_path]:
			if _m19(_h5):
				_r7.append(_y22(_h5))
			else:
				pass

		if _r7.size() > 0:
			_m54[file_path] = _r7
	
	_d9()
	
	var file = FileAccess.open(_f34, FileAccess.WRITE)
	if file:
		var _j32 = JSON.stringify(_m54, "\t")
		if _j32 and not _j32.is_empty():
			file.store_string(_j32)
			file.close()
			
		else:
			file.close()
			push_error("[RefactorHistory] Failed to serialize history data")
			_u95()
	else:
		push_error("[RefactorHistory] Failed to save history to disk")
		_u95()

func _m47():
	var file = FileAccess.open(_f34, FileAccess.READ)
	if not file:
		return
	
	var _j32 = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var _o36 = json.parse(_j32)
	
	if _o36 != OK:
		push_error("[RefactorHistory] Failed to parse history file: %s" % json.get_error_message())
		_u95()
		return
	
	var _m54 = json.data
	if not _m54 is Dictionary:
		push_error("[RefactorHistory] Invalid history data format")
		_u95()
		return
	
	_r72.clear()
	
	for file_path in _m54.keys():
		var _r7 = _m54[file_path]
		if not _r7 is Array:
			continue
		
		var _y60 = []
		for _t85 in _r7:
			if _t85 is Dictionary:
				var _h5 = _x8(_t85)
				if _h5 and _m19(_h5):
					_y60.append(_h5)
		
		if _y60.size() > 0:
			_r72[file_path] = _y60
	
func _m19(_h5: _n2) -> bool:
	if not _h5:
		return false
	
	if _h5.function_name.is_empty():
		return false
	
	if _h5.original_code.is_empty() or _h5.refactored_code.is_empty():
		return false
	
	if _h5.file_path.is_empty():
		return false
	
	if _h5.function_line < 0:
		return false
	
	return true

func _y22(_h5: _n2) -> Dictionary:
	return {
		"function_name": _h5.function_name,
		"original_code": _h5.original_code,
		"refactored_code": _h5.refactored_code,
		"timestamp": _h5.timestamp,
		"file_path": _h5.file_path,
		"function_line": _h5.function_line
	}

func _x8(data: Dictionary) -> _n2:
	if not data.has_all(["function_name", "original_code", "refactored_code", "file_path"]):
		return null
	
	var _h5 = _n2.new(
		data.get("function_name", ""),
		data.get("original_code", ""),
		data.get("refactored_code", ""),
		data.get("file_path", ""),
		data.get("function_line", 0)
	)
	
	if data.has("timestamp"):
		_h5.timestamp = data["timestamp"]
	
	return _h5

func _d9():
	if FileAccess.file_exists(_f34):
		var source = FileAccess.open(_f34, FileAccess.READ)
		if source:
			var content = source.get_as_text()
			source.close()
			
			var _s91 = FileAccess.open(_x47, FileAccess.WRITE)
			if _s91:
				_s91.store_string(content)
				_s91.close()
func _u95():
	if not FileAccess.file_exists(_x47):
		return
	
	var _s91 = FileAccess.open(_x47, FileAccess.READ)
	if _s91:
		var content = _s91.get_as_text()
		_s91.close()
		
		var _b93 = FileAccess.open(_f34, FileAccess.WRITE)
		if _b93:
			_b93.store_string(content)
			_b93.close()

			_m47()

