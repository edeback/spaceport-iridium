@tool
class_name _w59
extends RefCounted

const _f76: Array[String] = [".gd", ".tscn", ".tres", ".cfg", ".shader", ".json", ".txt", ".md"]

const _k34: Array[String] = [".tscn"]

const _f57: Array[String] = [
	"res://.godot/",
	"res://.import/",
	"res://addons/gdsense/",
	"res://.git/"
]

const _w13: int = 30000  
const _r31: int = 50

var _i16: Array[String] = []
var _c38: Array[String] = []
var _a1: int = 0
var _is_initialized: bool = false

func _j77() -> void:
	if _is_initialized and not _l81():
		return
	_z3()

func _z3() -> void:
	_i16.clear()
	_c38.clear()

	var _j57 = DirAccess.open("res://")
	if _j57 == null:
		_is_initialized = true  
		return

	_h77("res://", _f76, _i16)

	for file_path in _i16:
		if file_path.to_lower().ends_with(".tscn"):
			_c38.append(file_path)

	_a1 = Time.get_ticks_msec()
	_is_initialized = true

func _o88(_q68: String, _n58: String = "all") -> Array[String]:
	_j77()

	var _g19: Array[String] = _c38 if _n58 == "scene" else _i16

	if _q68.is_empty():
		var _x97: Array[String] = []
		for i in range(mini(_g19.size(), _r31)):
			_x97.append(_g19[i])
		return _x97

	var _x15: Array[Dictionary] = []

	for file_path in _g19:
		var _x31 = _s49(file_path, _q68)
		if _x31 > 0:
			_x15.append({"path": file_path, "score": _x31})

	_x15.sort_custom(func(a, b): return a.get("score", 0) > b.get("score", 0))

	var _x97: Array[String] = []
	for i in range(mini(_x15.size(), _r31)):
		_x97.append(_x15[i].get("path", ""))

	return _x97

func _s49(file_path: String, _q68: String) -> int:
	if _q68.is_empty():
		return 1

	var _i15 = file_path.to_lower()
	var _h60 = _q68.to_lower()
	var filename = file_path.get_file().to_lower()

	if filename.begins_with(_h60):
		return 1000 + (100 - filename.length())  

	if filename.contains(_h60):
		return 800 + (100 - filename.length())

	if _i15.begins_with(_h60) or _i15.begins_with("res://" + _h60):
		return 600 + (200 - file_path.length())

	if _i15.contains(_h60):
		return 400 + (200 - file_path.length())

	var _v52 = 0
	var _d88 = 0
	var _x31 = 0
	var _c27 = 0

	for i in range(_h60.length()):
		var _d38 = _h60[i]
		var _a85 = false

		while _v52 < _i15.length():
			if _i15[_v52] == _d38:
				_c27 += 1

				if _v52 > 0 and i > 0:
					var _x17 = _v52 - 1
					if _i15[_x17] == _h60[i - 1]:
						_d88 += 5

				_x31 += 10 + _d88
				_v52 += 1
				_a85 = true
				break
			_v52 += 1

		if not _a85:
			return 0  

	if _c27 == _h60.length():
		if filename.contains(_h60[0]):
			_x31 += 50
		return _x31

	return 0

func _h77(path: String, _e13: Array[String], _x97: Array[String]) -> void:
	var _j57 = DirAccess.open(path)
	if _j57 == null:
		return

	_j57.list_dir_begin()
	var _x87 = _j57.get_next()

	while _x87 != "":
		if _x87.begins_with("."):
			_x87 = _j57.get_next()
			continue

		var full_path = path.path_join(_x87)

		var _z65 = full_path.simplify_path()
		if not _z65.begins_with("res://"):
			_x87 = _j57.get_next()
			continue

		var skip = false
		for _i40 in _f57:
			if _z65.begins_with(_i40):
				skip = true
				break

		if skip:
			_x87 = _j57.get_next()
			continue

		if _j57.current_is_dir():
			_h77(_z65, _e13, _x97)
		else:
			var _w61 = _x87.get_extension()
			if not _w61.is_empty():
				_w61 = "." + _w61.to_lower()
				if _w61 in _e13:
					_x97.append(_z65)

		_x87 = _j57.get_next()

	_j57.list_dir_end()

func _l81() -> bool:
	if _a1 == 0:
		return true
	return (Time.get_ticks_msec() - _a1) > _w13

func get_file_count() -> int:
	return _i16.size()

func _u65() -> int:
	return _c38.size()

