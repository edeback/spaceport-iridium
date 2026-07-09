@tool
class_name _o58
extends RefCounted

const _j94: Array[String] = [".gd", ".tscn", ".tres", ".cfg", ".shader", ".json", ".txt", ".md"]

const _d44: Array[String] = [".tscn"]

const _e60: Array[String] = [
	"res://.godot/",
	"res://.import/",
	"res://addons/gdsense/",
	"res://.git/"
]

const _p25: int = 30000  
const _q85: int = 50

var _n50: Array[String] = []
var _o87: Array[String] = []
var _g22: int = 0
var _is_initialized: bool = false

func _n21() -> void:
	if _is_initialized and not _p36():
		return
	_f89()

func _f89() -> void:
	_n50.clear()
	_o87.clear()

	var _d30 = DirAccess.open("res://")
	if _d30 == null:
		_is_initialized = true  
		return

	_e73("res://", _j94, _n50)

	for file_path in _n50:
		if file_path.to_lower().ends_with(".tscn"):
			_o87.append(file_path)

	_g22 = Time.get_ticks_msec()
	_is_initialized = true

func _s6(_e33: String, _e97: String = "all") -> Array[String]:
	_n21()

	var _i34: Array[String] = _o87 if _e97 == "scene" else _n50

	if _e33.is_empty():
		var _k3: Array[String] = []
		for i in range(mini(_i34.size(), _q85)):
			_k3.append(_i34[i])
		return _k3

	var _q75: Array[Dictionary] = []

	for file_path in _i34:
		var _g93 = _x46(file_path, _e33)
		if _g93 > 0:
			_q75.append({"path": file_path, "score": _g93})

	_q75.sort_custom(func(a, b): return a.get("score", 0) > b.get("score", 0))

	var _k3: Array[String] = []
	for i in range(mini(_q75.size(), _q85)):
		_k3.append(_q75[i].get("path", ""))

	return _k3

func _x46(file_path: String, _e33: String) -> int:
	if _e33.is_empty():
		return 1

	var _d19 = file_path.to_lower()
	var _m97 = _e33.to_lower()
	var filename = file_path.get_file().to_lower()

	if filename.begins_with(_m97):
		return 1000 + (100 - filename.length())  

	if filename.contains(_m97):
		return 800 + (100 - filename.length())

	if _d19.begins_with(_m97) or _d19.begins_with("res://" + _m97):
		return 600 + (200 - file_path.length())

	if _d19.contains(_m97):
		return 400 + (200 - file_path.length())

	var _q83 = 0
	var _a97 = 0
	var _g93 = 0
	var _z21 = 0

	for i in range(_m97.length()):
		var char = _m97[i]
		var _v96 = false

		while _q83 < _d19.length():
			if _d19[_q83] == char:
				_z21 += 1

				if _q83 > 0 and i > 0:
					var _f68 = _q83 - 1
					if _d19[_f68] == _m97[i - 1]:
						_a97 += 5

				_g93 += 10 + _a97
				_q83 += 1
				_v96 = true
				break
			_q83 += 1

		if not _v96:
			return 0  

	if _z21 == _m97.length():
		if filename.contains(_m97[0]):
			_g93 += 50
		return _g93

	return 0

func _e73(path: String, _s91: Array[String], _k3: Array[String]) -> void:
	var _d30 = DirAccess.open(path)
	if _d30 == null:
		return

	_d30.list_dir_begin()
	var _m48 = _d30.get_next()

	while _m48 != "":
		if _m48.begins_with("."):
			_m48 = _d30.get_next()
			continue

		var full_path = path.path_join(_m48)

		var _n30 = full_path.simplify_path()
		if not _n30.begins_with("res://"):
			_m48 = _d30.get_next()
			continue

		var skip = false
		for _n95 in _e60:
			if _n30.begins_with(_n95):
				skip = true
				break

		if skip:
			_m48 = _d30.get_next()
			continue

		if _d30.current_is_dir():
			_e73(_n30, _s91, _k3)
		else:
			var _c10 = _m48.get_extension()
			if not _c10.is_empty():
				_c10 = "." + _c10.to_lower()
				if _c10 in _s91:
					_k3.append(_n30)

		_m48 = _d30.get_next()

	_d30.list_dir_end()

func _p36() -> bool:
	if _g22 == 0:
		return true
	return (Time.get_ticks_msec() - _g22) > _p25

func get_file_count() -> int:
	return _n50.size()

func _w35() -> int:
	return _o87.size()

