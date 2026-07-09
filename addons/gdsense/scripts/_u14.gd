@tool
class_name _m52
extends RefCounted
const _r25: Array[String] = [".gd", ".tscn", ".tres", ".cfg", ".shader", ".json", ".txt", ".md"]
const _m55: Array[String] = [".tscn"]
const _k88: Array[String] = [
	"res://.godot/",
	"res://.import/",
	"res://addons/gdsense/",
	"res://.git/"
]
const _d31: int = 30000  
const _a76: int = 50
var _v9: Array[String] = []
var _p43: Array[String] = []
var _u69: int = 0
var _is_initialized: bool = false
func _l30() -> void:
	if _is_initialized and not _b85():
		return
	_e84()
func _e84() -> void:
	_v9.clear()
	_p43.clear()
	var _b57 = DirAccess.open("res://")
	if _b57 == null:
		_is_initialized = true  
		return
	_p88("res://", _r25, _v9)
	for file_path in _v9:
		if file_path.to_lower().ends_with(".tscn"):
			_p43.append(file_path)
	_u69 = Time.get_ticks_msec()
	_is_initialized = true
func _e26(_g90: String, _a59: String = "all") -> Array[String]:
	_l30()
	var _r80: Array[String] = _p43 if _a59 == "scene" else _v9
	if _g90.is_empty():
		var _e21: Array[String] = []
		for i in range(mini(_r80.size(), _a76)):
			_e21.append(_r80[i])
		return _e21
	var _f36: Array[Dictionary] = []
	for file_path in _r80:
		var _d3 = _c50(file_path, _g90)
		if _d3 > 0:
			_f36.append({"path": file_path, "score": _d3})
	_f36.sort_custom(func(a, b): return a.get("score", 0) > b.get("score", 0))
	var _e21: Array[String] = []
	for i in range(mini(_f36.size(), _a76)):
		_e21.append(_f36[i].get("path", ""))
	return _e21
func _c50(file_path: String, _g90: String) -> int:
	if _g90.is_empty():
		return 1
	var _y51 = file_path.to_lower()
	var _s30 = _g90.to_lower()
	var filename = file_path.get_file().to_lower()
	if filename.begins_with(_s30):
		return 1000 + (100 - filename.length())  
	if filename.contains(_s30):
		return 800 + (100 - filename.length())
	if _y51.begins_with(_s30) or _y51.begins_with("res://" + _s30):
		return 600 + (200 - file_path.length())
	if _y51.contains(_s30):
		return 400 + (200 - file_path.length())
	var _f96 = 0
	var _u26 = 0
	var _d3 = 0
	var _z23 = 0
	for i in range(_s30.length()):
		var char = _s30[i]
		var _u84 = false
		while _f96 < _y51.length():
			if _y51[_f96] == char:
				_z23 += 1
				if _f96 > 0 and i > 0:
					var _k59 = _f96 - 1
					if _y51[_k59] == _s30[i - 1]:
						_u26 += 5
				_d3 += 10 + _u26
				_f96 += 1
				_u84 = true
				break
			_f96 += 1
		if not _u84:
			return 0  
	if _z23 == _s30.length():
		if filename.contains(_s30[0]):
			_d3 += 50
		return _d3
	return 0
func _p88(path: String, _e23: Array[String], _e21: Array[String]) -> void:
	var _b57 = DirAccess.open(path)
	if _b57 == null:
		return
	_b57.list_dir_begin()
	var _g95 = _b57.get_next()
	while _g95 != "":
		if _g95.begins_with("."):
			_g95 = _b57.get_next()
			continue
		var full_path = path.path_join(_g95)
		var _t43 = full_path.simplify_path()
		if not _t43.begins_with("res://"):
			_g95 = _b57.get_next()
			continue
		var skip = false
		for _l65 in _k88:
			if _t43.begins_with(_l65):
				skip = true
				break
		if skip:
			_g95 = _b57.get_next()
			continue
		if _b57.current_is_dir():
			_p88(_t43, _e23, _e21)
		else:
			var _u60 = _g95.get_extension()
			if not _u60.is_empty():
				_u60 = "." + _u60.to_lower()
				if _u60 in _e23:
					_e21.append(_t43)
		_g95 = _b57.get_next()
	_b57.list_dir_end()
func _b85() -> bool:
	if _u69 == 0:
		return true
	return (Time.get_ticks_msec() - _u69) > _d31
func get_file_count() -> int:
	return _v9.size()
func _d76() -> int:
	return _p43.size()
