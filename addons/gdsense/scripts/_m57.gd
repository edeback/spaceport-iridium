@tool
class_name _t8
extends RefCounted

const _h76: Array[String] = [".gd", ".tscn", ".tres", ".cfg", ".shader", ".json", ".txt", ".md"]

const _k36: Array[String] = [".tscn"]

const _c36: Array[String] = [
	"res://.godot/",
	"res://.import/",
	"res://addons/gdsense/",
	"res://.git/"
]

const _w21: int = 30000  
const _f68: int = 50

var _k32: Array[String] = []
var _t15: Array[String] = []
var _v24: int = 0
var _is_initialized: bool = false

func _r89() -> void:
	if _is_initialized and not _p7():
		return
	_k62()

func _k62() -> void:
	_k32.clear()
	_t15.clear()

	var _g27 = DirAccess.open("res://")
	if _g27 == null:
		_is_initialized = true  
		return

	_d48("res://", _h76, _k32)

	for file_path in _k32:
		if file_path.to_lower().ends_with(".tscn"):
			_t15.append(file_path)

	_v24 = Time.get_ticks_msec()
	_is_initialized = true

func _j11(_z58: String, _i73: String = "all") -> Array[String]:
	_r89()

	var _o85: Array[String] = _t15 if _i73 == "scene" else _k32

	if _z58.is_empty():
		var _v42: Array[String] = []
		for i in range(mini(_o85.size(), _f68)):
			_v42.append(_o85[i])
		return _v42

	var _k21: Array[Dictionary] = []

	for file_path in _o85:
		var _t74 = _n42(file_path, _z58)
		if _t74 > 0:
			_k21.append({"path": file_path, "score": _t74})

	_k21.sort_custom(func(a, b): return a.get("score", 0) > b.get("score", 0))

	var _v42: Array[String] = []
	for i in range(mini(_k21.size(), _f68)):
		_v42.append(_k21[i].get("path", ""))

	return _v42

func _n42(file_path: String, _z58: String) -> int:
	if _z58.is_empty():
		return 1

	var _q27 = file_path.to_lower()
	var _t54 = _z58.to_lower()
	var filename = file_path.get_file().to_lower()

	if filename.begins_with(_t54):
		return 1000 + (100 - filename.length())  

	if filename.contains(_t54):
		return 800 + (100 - filename.length())

	if _q27.begins_with(_t54) or _q27.begins_with("res://" + _t54):
		return 600 + (200 - file_path.length())

	if _q27.contains(_t54):
		return 400 + (200 - file_path.length())

	var _s98 = 0
	var _j94 = 0
	var _t74 = 0
	var _g60 = 0

	for i in range(_t54.length()):
		var char = _t54[i]
		var _j5 = false

		while _s98 < _q27.length():
			if _q27[_s98] == char:
				_g60 += 1

				if _s98 > 0 and i > 0:
					var _x32 = _s98 - 1
					if _q27[_x32] == _t54[i - 1]:
						_j94 += 5

				_t74 += 10 + _j94
				_s98 += 1
				_j5 = true
				break
			_s98 += 1

		if not _j5:
			return 0  

	if _g60 == _t54.length():
		if filename.contains(_t54[0]):
			_t74 += 50
		return _t74

	return 0

func _d48(path: String, _l6: Array[String], _v42: Array[String]) -> void:
	var _g27 = DirAccess.open(path)
	if _g27 == null:
		return

	_g27.list_dir_begin()
	var _p88 = _g27.get_next()

	while _p88 != "":
		if _p88.begins_with("."):
			_p88 = _g27.get_next()
			continue

		var full_path = path.path_join(_p88)

		var _m42 = full_path.simplify_path()
		if not _m42.begins_with("res://"):
			_p88 = _g27.get_next()
			continue

		var skip = false
		for _l79 in _c36:
			if _m42.begins_with(_l79):
				skip = true
				break

		if skip:
			_p88 = _g27.get_next()
			continue

		if _g27.current_is_dir():
			_d48(_m42, _l6, _v42)
		else:
			var _e48 = _p88.get_extension()
			if not _e48.is_empty():
				_e48 = "." + _e48.to_lower()
				if _e48 in _l6:
					_v42.append(_m42)

		_p88 = _g27.get_next()

	_g27.list_dir_end()

func _p7() -> bool:
	if _v24 == 0:
		return true
	return (Time.get_ticks_msec() - _v24) > _w21

func get_file_count() -> int:
	return _k32.size()

func _q71() -> int:
	return _t15.size()

