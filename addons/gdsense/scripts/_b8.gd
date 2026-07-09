@tool
class_name _i29
extends RefCounted
const _j38: Array[String] = [".gd", ".tscn", ".tres", ".cfg", ".shader", ".json", ".txt", ".md"]
const _w97: Array[String] = [".tscn"]
const _o79: Array[String] = [
	"res://.godot/",
	"res://.import/",
	"res://addons/gdsense/",
	"res://.git/"
]
const _w80: int = 30000  
const _e6: int = 50
var _l23: Array[String] = []
var _v71: Array[String] = []
var _e28: int = 0
var _is_initialized: bool = false
func _z94() -> void:
	if _is_initialized and not _j14():
		return
	_m7()
func _m7() -> void:
	_l23.clear()
	_v71.clear()
	var _e23 = DirAccess.open("res://")
	if _e23 == null:
		_is_initialized = true  
		return
	_q50("res://", _j38, _l23)
	for file_path in _l23:
		if file_path.to_lower().ends_with(".tscn"):
			_v71.append(file_path)
	_e28 = Time.get_ticks_msec()
	_is_initialized = true
func _e72(_k81: String, _y70: String = "all") -> Array[String]:
	_z94()
	var _y71: Array[String] = _v71 if _y70 == "scene" else _l23
	if _k81.is_empty():
		var _n37: Array[String] = []
		for i in range(mini(_y71.size(), _e6)):
			_n37.append(_y71[i])
		return _n37
	var _r48: Array[Dictionary] = []
	for file_path in _y71:
		var _i30 = _k15(file_path, _k81)
		if _i30 > 0:
			_r48.append({"path": file_path, "score": _i30})
	_r48.sort_custom(func(a, b): return a.get("score", 0) > b.get("score", 0))
	var _n37: Array[String] = []
	for i in range(mini(_r48.size(), _e6)):
		_n37.append(_r48[i].get("path", ""))
	return _n37
func _k15(file_path: String, _k81: String) -> int:
	if _k81.is_empty():
		return 1
	var _x32 = file_path.to_lower()
	var _p21 = _k81.to_lower()
	var filename = file_path.get_file().to_lower()
	if filename.begins_with(_p21):
		return 1000 + (100 - filename.length())  
	if filename.contains(_p21):
		return 800 + (100 - filename.length())
	if _x32.begins_with(_p21) or _x32.begins_with("res://" + _p21):
		return 600 + (200 - file_path.length())
	if _x32.contains(_p21):
		return 400 + (200 - file_path.length())
	var _t59 = 0
	var _t70 = 0
	var _i30 = 0
	var _b51 = 0
	for i in range(_p21.length()):
		var _c28 = _p21[i]
		var _z27 = false
		while _t59 < _x32.length():
			if _x32[_t59] == _c28:
				_b51 += 1
				if _t59 > 0 and i > 0:
					var _z25 = _t59 - 1
					if _x32[_z25] == _p21[i - 1]:
						_t70 += 5
				_i30 += 10 + _t70
				_t59 += 1
				_z27 = true
				break
			_t59 += 1
		if not _z27:
			return 0  
	if _b51 == _p21.length():
		if filename.contains(_p21[0]):
			_i30 += 50
		return _i30
	return 0
func _q50(path: String, _o82: Array[String], _n37: Array[String]) -> void:
	var _e23 = DirAccess.open(path)
	if _e23 == null:
		return
	_e23.list_dir_begin()
	var _s80 = _e23.get_next()
	while _s80 != "":
		if _s80.begins_with("."):
			_s80 = _e23.get_next()
			continue
		var full_path = path.path_join(_s80)
		var _c76 = full_path.simplify_path()
		if not _c76.begins_with("res://"):
			_s80 = _e23.get_next()
			continue
		var skip = false
		for _v37 in _o79:
			if _c76.begins_with(_v37):
				skip = true
				break
		if skip:
			_s80 = _e23.get_next()
			continue
		if _e23.current_is_dir():
			_q50(_c76, _o82, _n37)
		else:
			var _k95 = _s80.get_extension()
			if not _k95.is_empty():
				_k95 = "." + _k95.to_lower()
				if _k95 in _o82:
					_n37.append(_c76)
		_s80 = _e23.get_next()
	_e23.list_dir_end()
func _j14() -> bool:
	if _e28 == 0:
		return true
	return (Time.get_ticks_msec() - _e28) > _w80
func get_file_count() -> int:
	return _l23.size()
func _f93() -> int:
	return _v71.size()
