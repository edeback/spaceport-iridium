@tool
class_name _n48
extends RefCounted
const _j37: Array[String] = [".gd", ".tscn", ".tres", ".cfg", ".shader", ".json", ".txt", ".md"]
const _a92: Array[String] = [".tscn"]
const _a44: Array[String] = [
	"res://.godot/",
	"res://.import/",
	"res://addons/gdsense/",
	"res://.git/"
]
const _t93: int = 30000  
const _p94: int = 50
var _j17: Array[String] = []
var _k62: Array[String] = []
var _x14: int = 0
var _is_initialized: bool = false
func _z59() -> void:
	if _is_initialized and not _y84():
		return
	_p16()
func _p16() -> void:
	_j17.clear()
	_k62.clear()
	var _v15 = DirAccess.open("res://")
	if _v15 == null:
		_is_initialized = true  
		return
	_z98("res://", _j37, _j17)
	for file_path in _j17:
		if file_path.to_lower().ends_with(".tscn"):
			_k62.append(file_path)
	_x14 = Time.get_ticks_msec()
	_is_initialized = true
func _v79(_x96: String, _l57: String = "all") -> Array[String]:
	_z59()
	var _a26: Array[String] = _k62 if _l57 == "scene" else _j17
	if _x96.is_empty():
		var _x97: Array[String] = []
		for i in range(mini(_a26.size(), _p94)):
			_x97.append(_a26[i])
		return _x97
	var _i14: Array[Dictionary] = []
	for file_path in _a26:
		var _i63 = _p48(file_path, _x96)
		if _i63 > 0:
			_i14.append({"path": file_path, "score": _i63})
	_i14.sort_custom(func(a, b): return a.get("score", 0) > b.get("score", 0))
	var _x97: Array[String] = []
	for i in range(mini(_i14.size(), _p94)):
		_x97.append(_i14[i].get("path", ""))
	return _x97
func _p48(file_path: String, _x96: String) -> int:
	if _x96.is_empty():
		return 1
	var _h60 = file_path.to_lower()
	var _q41 = _x96.to_lower()
	var filename = file_path.get_file().to_lower()
	if filename.begins_with(_q41):
		return 1000 + (100 - filename.length())  
	if filename.contains(_q41):
		return 800 + (100 - filename.length())
	if _h60.begins_with(_q41) or _h60.begins_with("res://" + _q41):
		return 600 + (200 - file_path.length())
	if _h60.contains(_q41):
		return 400 + (200 - file_path.length())
	var _m47 = 0
	var _w97 = 0
	var _i63 = 0
	var _p87 = 0
	for i in range(_q41.length()):
		var _o41 = _q41[i]
		var _s99 = false
		while _m47 < _h60.length():
			if _h60[_m47] == _o41:
				_p87 += 1
				if _m47 > 0 and i > 0:
					var _z8 = _m47 - 1
					if _h60[_z8] == _q41[i - 1]:
						_w97 += 5
				_i63 += 10 + _w97
				_m47 += 1
				_s99 = true
				break
			_m47 += 1
		if not _s99:
			return 0  
	if _p87 == _q41.length():
		if filename.contains(_q41[0]):
			_i63 += 50
		return _i63
	return 0
func _z98(path: String, _c85: Array[String], _x97: Array[String]) -> void:
	var _v15 = DirAccess.open(path)
	if _v15 == null:
		return
	_v15.list_dir_begin()
	var _f63 = _v15.get_next()
	while _f63 != "":
		if _f63.begins_with("."):
			_f63 = _v15.get_next()
			continue
		var full_path = path.path_join(_f63)
		var _t52 = full_path.simplify_path()
		if not _t52.begins_with("res://"):
			_f63 = _v15.get_next()
			continue
		var skip = false
		for _w100 in _a44:
			if _t52.begins_with(_w100):
				skip = true
				break
		if skip:
			_f63 = _v15.get_next()
			continue
		if _v15.current_is_dir():
			_z98(_t52, _c85, _x97)
		else:
			var _z94 = _f63.get_extension()
			if not _z94.is_empty():
				_z94 = "." + _z94.to_lower()
				if _z94 in _c85:
					_x97.append(_t52)
		_f63 = _v15.get_next()
	_v15.list_dir_end()
func _y84() -> bool:
	if _x14 == 0:
		return true
	return (Time.get_ticks_msec() - _x14) > _t93
func get_file_count() -> int:
	return _j17.size()
func _j88() -> int:
	return _k62.size()
