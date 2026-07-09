@tool
class_name _l47
extends RefCounted
const _w96: Array[String] = [".gd", ".tscn", ".tres", ".cfg", ".shader", ".json", ".txt", ".md"]
const _u57: Array[String] = [".tscn"]
const _n92: Array[String] = [
	"res://.godot/",
	"res://.import/",
	"res://addons/gdsense/",
	"res://.git/"
]
const _x45: int = 30000  
const _r59: int = 50
var _y90: Array[String] = []
var _k96: Array[String] = []
var _l27: int = 0
var _is_initialized: bool = false
func _i48() -> void:
	if _is_initialized and not _a45():
		return
	_t24()
func _t24() -> void:
	_y90.clear()
	_k96.clear()
	var _d5 = DirAccess.open("res://")
	if _d5 == null:
		_is_initialized = true  
		return
	_v33("res://", _w96, _y90)
	for file_path in _y90:
		if file_path.to_lower().ends_with(".tscn"):
			_k96.append(file_path)
	_l27 = Time.get_ticks_msec()
	_is_initialized = true
func _y82(_q57: String, _q84: String = "all") -> Array[String]:
	_i48()
	var _c62: Array[String] = _k96 if _q84 == "scene" else _y90
	if _q57.is_empty():
		var _s61: Array[String] = []
		for i in range(mini(_c62.size(), _r59)):
			_s61.append(_c62[i])
		return _s61
	var _i52: Array[Dictionary] = []
	for file_path in _c62:
		var _n19 = _p67(file_path, _q57)
		if _n19 > 0:
			_i52.append({"path": file_path, "score": _n19})
	_i52.sort_custom(func(a, b): return a.get("score", 0) > b.get("score", 0))
	var _s61: Array[String] = []
	for i in range(mini(_i52.size(), _r59)):
		_s61.append(_i52[i].get("path", ""))
	return _s61
func _p67(file_path: String, _q57: String) -> int:
	if _q57.is_empty():
		return 1
	var _e65 = file_path.to_lower()
	var _j5 = _q57.to_lower()
	var filename = file_path.get_file().to_lower()
	if filename.begins_with(_j5):
		return 1000 + (100 - filename.length())  
	if filename.contains(_j5):
		return 800 + (100 - filename.length())
	if _e65.begins_with(_j5) or _e65.begins_with("res://" + _j5):
		return 600 + (200 - file_path.length())
	if _e65.contains(_j5):
		return 400 + (200 - file_path.length())
	var _g39 = 0
	var _h6 = 0
	var _n19 = 0
	var _j70 = 0
	for i in range(_j5.length()):
		var _q64 = _j5[i]
		var _z71 = false
		while _g39 < _e65.length():
			if _e65[_g39] == _q64:
				_j70 += 1
				if _g39 > 0 and i > 0:
					var _m66 = _g39 - 1
					if _e65[_m66] == _j5[i - 1]:
						_h6 += 5
				_n19 += 10 + _h6
				_g39 += 1
				_z71 = true
				break
			_g39 += 1
		if not _z71:
			return 0  
	if _j70 == _j5.length():
		if filename.contains(_j5[0]):
			_n19 += 50
		return _n19
	return 0
func _v33(path: String, _d40: Array[String], _s61: Array[String]) -> void:
	var _d5 = DirAccess.open(path)
	if _d5 == null:
		return
	_d5.list_dir_begin()
	var _y38 = _d5.get_next()
	while _y38 != "":
		if _y38.begins_with("."):
			_y38 = _d5.get_next()
			continue
		var full_path = path.path_join(_y38)
		var _z26 = full_path.simplify_path()
		if not _z26.begins_with("res://"):
			_y38 = _d5.get_next()
			continue
		var skip = false
		for _r60 in _n92:
			if _z26.begins_with(_r60):
				skip = true
				break
		if skip:
			_y38 = _d5.get_next()
			continue
		if _d5.current_is_dir():
			_v33(_z26, _d40, _s61)
		else:
			var _a76 = _y38.get_extension()
			if not _a76.is_empty():
				_a76 = "." + _a76.to_lower()
				if _a76 in _d40:
					_s61.append(_z26)
		_y38 = _d5.get_next()
	_d5.list_dir_end()
func _a45() -> bool:
	if _l27 == 0:
		return true
	return (Time.get_ticks_msec() - _l27) > _x45
func get_file_count() -> int:
	return _y90.size()
func _u84() -> int:
	return _k96.size()
