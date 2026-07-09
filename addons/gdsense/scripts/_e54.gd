@tool
class_name _f71
extends RefCounted

const _e24: Array[String] = [
	"res://.godot/",
	"res://.import/",
	"res://project.godot",
	"res://addons/gdsense/",
	"res://.git/"
]

const _v57: int = 50000

const _f51: int = 500

const _a55: int = 200

const _f62: Array[String] = [
	"create_file",
	"edit_file",
	"delete_file"
]

var _b58: EditorInterface

func initialize(_f28: EditorInterface) -> void:
	_b58 = _f28

func _q58(_i10: String) -> bool:
	return _i10 in _f62

func _o17(_i10: String, _q41: Dictionary) -> Dictionary:
	match _i10:
		"read_file":
			return _m68(_q41.get("path", ""))
		"list_files":
			return _n81(_q41.get("directory", "res://"), _q41.get("recursive", false))
		"glob":
			return _g35(_q41.get("pattern", ""), _q41.get("path", "res://"))
		"grep":
			return _w83(_q41.get("pattern", ""), _q41.get("path", "res://"), _q41.get("glob", ""), _q41.get("context_lines", 2))
		"get_project_info":
			return _n53()
		"run_project":
			return _g59()
		"stop_project":
			return _w81()
		"create_file":
			return _e95(_q41.get("path", ""), _q41.get("content", ""))
		"edit_file":
			return _j98(_q41.get("path", ""), _q41.get("old_string", ""), _q41.get("new_string", ""), _q41.get("replace_all", false))
		"delete_file":
			return _v20(_q41.get("path", ""))
		_:
			return {"success": false, "error": "Unknown tool: " + _i10}

func _i7(path: String) -> bool:
	if not path.begins_with("res://"):
		return false

	if ".." in path:
		return false

	var normalized = path.simplify_path()

	for _o16 in _e24:
		var _v13 = _o16.simplify_path()
		if normalized.begins_with(_v13) or normalized == _v13.trim_suffix("/"):
			return false

	return true

func _l85(path: String) -> String:
	if not path.begins_with("res://"):
		return "Path must start with res://"

	if ".." in path:
		return "Path traversal (..) is not allowed"

	var normalized = path.simplify_path()
	for _o16 in _e24:
		var _v13 = _o16.simplify_path()
		if normalized.begins_with(_v13) or normalized == _v13.trim_suffix("/"):
			return "Path is protected: " + _o16

	return "Path validation failed"

func _m68(path: String) -> Dictionary:
	if path.is_empty():
		return {"success": false, "error": "Path is required"}

	if not _i7(path):
		return {"success": false, "error": _l85(path)}

	if not FileAccess.file_exists(path):
		return {"success": false, "error": "File not found: " + path}

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		var _u46 = FileAccess.get_open_error()
		return {"success": false, "error": "Cannot open file: " + path + " (error: " + str(_u46) + ")"}

	var _g9 = file.get_length()
	var content = file.get_as_text()
	file.close()

	var _r69 = false
	if content.length() > _v57:
		content = content.substr(0, _v57) + "\n... [truncated, file too large]"
		_r69 = true

	return {
		"success": true,
		"content": content,
		"path": path,
		"size": _g9,
		"truncated": _r69
	}

func _n81(_u52: String, _k99: bool) -> Dictionary:
	if _u52.is_empty():
		_u52 = "res://"

	if not _i7(_u52):
		return {"success": false, "error": _l85(_u52)}

	var _j57 = DirAccess.open(_u52)
	if not _j57:
		var _u46 = DirAccess.get_open_error()
		return {"success": false, "error": "Cannot open directory: " + _u52 + " (error: " + str(_u46) + ")"}

	var _n51: Array[String] = []
	var _b19: Array[String] = []

	_j57.list_dir_begin()
	var _x87 = _j57.get_next()

	while _x87 != "":
		if _x87 != "." and _x87 != "..":
			var full_path = _u52.path_join(_x87)

			if _i7(full_path):
				if _j57.current_is_dir():
					_b19.append(_x87 + "/")
					if _k99:
						var _g12 = _n81(full_path, true)
						if _g12.get("success", false):
							var _c87 = _g12.get("files", [])
							for f in _c87:
								_n51.append(_x87 + "/" + f)
				else:
					_n51.append(_x87)

		_x87 = _j57.get_next()

	_j57.list_dir_end()

	return {
		"success": true,
		"directory": _u52,
		"files": _n51,
		"directories": _b19,
		"total_files": _n51.size(),
		"total_directories": _b19.size()
	}

func _g35(_t30: String, base_path: String) -> Dictionary:
	if _t30.is_empty():
		return {"success": false, "error": "Pattern is required"}

	if base_path.is_empty():
		base_path = "res://"

	if not _i7(base_path):
		return {"success": false, "error": _l85(base_path)}

	var _l93: Array[String] = []
	var _z68: int = 0

	var segments = _t30.split("/")

	_y67(base_path, segments, 0, _l93, _z68)

	var _r69 = false
	if _l93.size() > _f51:
		_l93.resize(_f51)
		_r69 = true

	return {
		"success": true,
		"matches": _l93,
		"total_found": _l93.size(),
		"truncated": _r69,
		"pattern": _t30,
		"base_path": base_path
	}

func _y67(current_path: String, segments: Array, _l91: int, _l93: Array[String], _z68: int) -> void:
	if _l93.size() >= _f51:
		return

	if _l91 >= segments.size():
		return

	var _s77 = segments[_l91]
	var _l89 = (_l91 == segments.size() - 1)

	if _s77 == "**":
		if _l91 + 1 < segments.size():
			_y67(current_path, segments, _l91 + 1, _l93, _z68)

		var _j57 = DirAccess.open(current_path)
		if _j57:
			_j57.list_dir_begin()
			var _y98 = _j57.get_next()
			while _y98 != "" and _l93.size() < _f51:
				if _y98 != "." and _y98 != "..":
					var full_path = current_path.path_join(_y98)
					if _i7(full_path) and _j57.current_is_dir():
						_y67(full_path, segments, _l91, _l93, _z68 + 1)
				_y98 = _j57.get_next()
			_j57.list_dir_end()
		return

	var _j57 = DirAccess.open(current_path)
	if not _j57:
		return

	_j57.list_dir_begin()
	var _y98 = _j57.get_next()

	while _y98 != "" and _l93.size() < _f51:
		if _y98 != "." and _y98 != "..":
			var full_path = current_path.path_join(_y98)

			if _i7(full_path):
				var _a42 = _j57.current_is_dir()

				if _a75(_y98, _s77):
					if _l89:
						if not _a42 or _s77.ends_with("/"):
							_l93.append(full_path)
						elif _a42 and not _s77.ends_with("/"):
							_l93.append(full_path)
					elif _a42:
						_y67(full_path, segments, _l91 + 1, _l93, _z68 + 1)

		_y98 = _j57.get_next()

	_j57.list_dir_end()

func _a75(name: String, _t30: String) -> bool:
	if _t30 == "*":
		return true
	if _t30 == name:
		return true

	var _l72 = "^"
	var i = 0
	while i < _t30.length():
		var c = _t30[i]
		match c:
			"*":
				_l72 += ".*"
			"?":
				_l72 += "."
			".":
				_l72 += "\\."
			"[":
				var _s7 = _t30.find("]", i)
				if _s7 > i:
					_l72 += _t30.substr(i, _s7 - i + 1)
					i = _s7
				else:
					_l72 += "\\["
			_:
				if c in "\\^$|+(){}":
					_l72 += "\\" + c
				else:
					_l72 += c
		i += 1
	_l72 += "$"

	var _g88 = RegEx.new()
	if _g88.compile(_l72) != OK:
		return name == _t30

	return _g88.search(name) != null

func _w83(_t30: String, base_path: String, _i33: String, _j2: int) -> Dictionary:
	if _t30.is_empty():
		return {"success": false, "error": "Pattern is required"}

	if base_path.is_empty():
		base_path = "res://"

	if not _i7(base_path):
		return {"success": false, "error": _l85(base_path)}

	var _g88 = RegEx.new()
	var _i93 = _g88.compile(_t30)
	if _i93 != OK:
		return {"success": false, "error": "Invalid regex pattern: " + _t30}

	var _r56: Array[String] = []

	if _i33.is_empty():
		_h63(base_path, _r56)
	else:
		var _u30 = _g35(_i33, base_path)
		if not _u30.get("success", false):
			return _u30
		for f in _u30.get("matches", []):
			_r56.append(f)

	var _l93: Array[Dictionary] = []
	var _h94: int = 0
	var _k32: int = 0

	for file_path in _r56:
		if _l93.size() >= _a55:
			break

		if _d24(file_path):
			continue

		if not FileAccess.file_exists(file_path):
			continue

		var file = FileAccess.open(file_path, FileAccess.READ)
		if not file:
			continue

		var content = file.get_as_text()
		file.close()
		_h94 += 1

		var _d41 = content.split("\n")
		var _t45 = false

		for _k88 in range(_d41.size()):
			if _l93.size() >= _a55:
				break

			var line = _d41[_k88]
			var _m56 = _g88.search(line)

			if _m56:
				_t45 = true

				var _d80: Array[String] = []
				var _d82: Array[String] = []

				for i in range(max(0, _k88 - _j2), _k88):
					_d80.append(_d41[i])

				for i in range(_k88 + 1, min(_d41.size(), _k88 + _j2 + 1)):
					_d82.append(_d41[i])

				_l93.append({
					"file": file_path,
					"line_number": _k88 + 1,
					"line": line,
					"before_context": _d80,
					"after_context": _d82,
					"match_start": _m56.get_start(),
					"match_end": _m56.get_end()
				})

		if _t45:
			_k32 += 1

	var _r69 = _l93.size() >= _a55

	return {
		"success": true,
		"matches": _l93,
		"total_matches": _l93.size(),
		"files_searched": _h94,
		"files_with_matches": _k32,
		"truncated": _r69,
		"pattern": _t30
	}

func _h63(_u52: String, _n51: Array[String]) -> void:
	var _j57 = DirAccess.open(_u52)
	if not _j57:
		return

	_j57.list_dir_begin()
	var _y98 = _j57.get_next()

	while _y98 != "":
		if _y98 != "." and _y98 != "..":
			var full_path = _u52.path_join(_y98)

			if _i7(full_path):
				if _j57.current_is_dir():
					_h63(full_path, _n51)
				else:
					_n51.append(full_path)

		_y98 = _j57.get_next()

	_j57.list_dir_end()

func _d24(path: String) -> bool:
	var _f36 = [
		".png", ".jpg", ".jpeg", ".gif", ".bmp", ".webp", ".svg",
		".ogg", ".wav", ".mp3", ".flac",
		".ttf", ".otf", ".woff", ".woff2",
		".zip", ".tar", ".gz", ".7z", ".rar",
		".exe", ".dll", ".so", ".dylib",
		".res", ".import", ".scn", ".bin",
		".glb", ".gltf", ".fbx", ".obj", ".dae"
	]

	var _w61 = path.get_extension().to_lower()
	if _w61.is_empty():
		return false

	return ("." + _w61) in _f36

func _n53() -> Dictionary:
	var _m65 = Engine.get_version_info()
	var _r83 = "%d.%d.%d" % [_m65.get("major", 0), _m65.get("minor", 0), _m65.get("patch", 0)]

	var _z1 = {
		"success": true,
		"godot_version": _r83,
		"godot_version_full": _m65.get("string", _r83),
		"project_name": ProjectSettings.get_setting("application/config/name", "Unknown"),
		"project_path": ProjectSettings.globalize_path("res://")
	}

	var _e50 = ProjectSettings.get_setting("application/run/main_scene", "")
	if not _e50.is_empty():
		_z1["main_scene"] = _e50

	var description = ProjectSettings.get_setting("application/config/description", "")
	if not description.is_empty():
		_z1["description"] = description

	var _k66: Array[String] = []
	for _c11 in ProjectSettings.get_property_list():
		var name = _c11.get("name", "")
		if name.begins_with("autoload/"):
			_k66.append(name.replace("autoload/", ""))

	if not _k66.is_empty():
		_z1["autoloads"] = _k66

	return _z1

func _g59() -> Dictionary:
	if _b58 == null:
		return {"success": false, "error": "Editor interface not available"}

	if _b58.is_playing_scene():
		return {"success": false, "error": "Project is already running"}

	_b58.play_main_scene()

	return {"success": true, "message": "Project started"}

func _w81() -> Dictionary:
	if _b58 == null:
		return {"success": false, "error": "Editor interface not available"}

	if not _b58.is_playing_scene():
		return {"success": false, "error": "Project is not running"}

	_b58.stop_playing_scene()

	return {"success": true, "message": "Project stopped"}

func _e95(path: String, content: String) -> Dictionary:
	if path.is_empty():
		return {"success": false, "error": "Path is required"}

	if not _i7(path):
		return {"success": false, "error": _l85(path)}

	if FileAccess.file_exists(path):
		return {"success": false, "error": "File already exists: " + path + ". Use edit_file to modify existing files."}

	var _d48 = path.get_base_dir()
	if not _d48.is_empty() and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_d48)):
		var _j58 = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_d48))
		if _j58 != OK:
			return {"success": false, "error": "Cannot create directory: " + _d48 + " (error: " + str(_j58) + ")"}

	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		var _u46 = FileAccess.get_open_error()
		return {"success": false, "error": "Cannot create file: " + path + " (error: " + str(_u46) + ")"}

	file.store_string(content)
	file.close()

	if _b58:
		_b58.get_resource_filesystem().scan()

	var _x97 = {
		"success": true,
		"message": "File created: " + path,
		"path": path,
		"size": content.length()
	}

	var _u74 = _f20(path)
	if not _u74["valid"]:
		_x97["warning"] = _u74["error"]
		_x97["message"] += " (WARNING: " + _u74["error"] + ")"

	return _x97

func _j98(path: String, _h19: String, _a82: String, _t87: bool) -> Dictionary:
	if path.is_empty():
		return {"success": false, "error": "Path is required"}

	if _h19.is_empty():
		return {"success": false, "error": "old_string is required"}

	if not _i7(path):
		return {"success": false, "error": _l85(path)}

	if not FileAccess.file_exists(path):
		return {"success": false, "error": "File not found: " + path + ". Use create_file to create new files."}

	var _t2 = FileAccess.open(path, FileAccess.READ)
	if not _t2:
		var _u46 = FileAccess.get_open_error()
		return {"success": false, "error": "Cannot read file: " + path + " (error: " + str(_u46) + ")"}

	var _m85 = _t2.get_as_text()
	_t2.close()

	var _b33 = _m85.find(_h19)
	if _b33 == -1:
		return {"success": false, "error": "old_string not found in file. The exact text must exist in the file."}

	var _m72 = _m85.count(_h19)

	if _m72 > 1 and not _t87:
		return {
			"success": false,
			"error": "Found " + str(_m72) + " occurrences of old_string. Set replace_all=true to replace all, or provide more context to make the string unique."
		}

	var _m67: String
	var _p27: int

	if _t87:
		_m67 = _m85.replace(_h19, _a82)
		_p27 = _m72
	else:
		_m67 = _m85.substr(0, _b33) + _a82 + _m85.substr(_b33 + _h19.length())
		_p27 = 1

	var _v68 = path + ".agent_backup"
	var _s91 = FileAccess.open(_v68, FileAccess.WRITE)
	if _s91:
		_s91.store_string(_m85)
		_s91.close()
	else:
		pass

	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		var _u46 = FileAccess.get_open_error()
		return {"success": false, "error": "Cannot write file: " + path + " (error: " + str(_u46) + ")"}

	file.store_string(_m67)
	file.close()

	if _b58:
		_b58.get_resource_filesystem().scan()

	var _x77 = _s13(_h19, _a82)

	var _x97 = {
		"success": true,
		"message": "File modified: " + path,
		"path": path,
		"replacements_made": _p27,
		"diff_preview": _x77,
		"original_size": _m85.length(),
		"new_size": _m67.length()
	}

	if FileAccess.file_exists(_v68):
		_x97["backup"] = _v68

	var _u74 = _f20(path)
	if not _u74["valid"]:
		_x97["warning"] = _u74["error"]
		_x97["message"] += " (WARNING: " + _u74["error"] + ")"

	return _x97

func _s13(_h19: String, _a82: String) -> String:
	var _y33 = _h19.split("\n")
	var _o79 = _a82.split("\n")

	var _e89 = ""

	for line in _y33:
		_e89 += "- " + line + "\n"

	for line in _o79:
		_e89 += "+ " + line + "\n"

	return _e89.strip_edges()

func _f20(path: String) -> Dictionary:
	if not path.ends_with(".tscn") and not path.ends_with(".tres"):
		return {"valid": true}

	var _v36 = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if _v36 == null:
		var _q52 = ""
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			_q52 = file.get_as_text()
			file.close()

		var _d41 = _q52.split("\n")
		var _b20 = ""
		for i in range(_d41.size()):
			_b20 += str(i + 1) + ": " + _d41[i] + "\n"

		return {
			"valid": false,
			"error": "PARSE ERROR in " + path.get_file() + ". The file has invalid format and cannot be loaded by Godot. Review the content below and fix the syntax:\n\n" + _b20
		}

	return {"valid": true}

func _v20(path: String) -> Dictionary:
	if path.is_empty():
		return {"success": false, "error": "Path is required"}

	if not _i7(path):
		return {"success": false, "error": _l85(path)}

	if not FileAccess.file_exists(path):
		return {"success": false, "error": "File not found: " + path}

	var _e39 = ProjectSettings.globalize_path(path)

	var _j58 = DirAccess.remove_absolute(_e39)
	if _j58 != OK:
		return {"success": false, "error": "Cannot delete file: " + path + " (error: " + str(_j58) + ")"}

	if _b58:
		_b58.get_resource_filesystem().scan()

	return {
		"success": true,
		"message": "File deleted: " + path,
		"path": path
	}

func _h80() -> Array[Dictionary]:
	return [
		{
			"name": "read_file",
			"description": "Read the contents of a file",
			"parameters": ["path"],
			"requires_approval": false
		},
		{
			"name": "list_files",
			"description": "List files in a directory",
			"parameters": ["directory", "recursive"],
			"requires_approval": false
		},
		{
			"name": "glob",
			"description": "Find files matching a glob pattern (e.g., **/*.gd)",
			"parameters": ["pattern", "path"],
			"requires_approval": false
		},
		{
			"name": "grep",
			"description": "Search file contents with regex pattern",
			"parameters": ["pattern", "path", "glob", "context_lines"],
			"requires_approval": false
		},
		{
			"name": "get_project_info",
			"description": "Get information about the current Godot project",
			"parameters": [],
			"requires_approval": false
		},
		{
			"name": "run_project",
			"description": "Run the main scene of the project",
			"parameters": [],
			"requires_approval": false
		},
		{
			"name": "stop_project",
			"description": "Stop the running project",
			"parameters": [],
			"requires_approval": false
		},
		{
			"name": "create_file",
			"description": "Create a new file with the specified content",
			"parameters": ["path", "content"],
			"requires_approval": true
		},
		{
			"name": "edit_file",
			"description": "Edit a file by replacing old_string with new_string",
			"parameters": ["path", "old_string", "new_string", "replace_all"],
			"requires_approval": true
		},
		{
			"name": "delete_file",
			"description": "Delete a file",
			"parameters": ["path"],
			"requires_approval": true
		}
	]

func _o71(_i10: String, _q41: Dictionary) -> Dictionary:
	match _i10:
		"read_file":
			if not _q41.has("path") or _q41.get("path", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: path"}
		"list_files":
			pass  
		"glob":
			if not _q41.has("pattern") or _q41.get("pattern", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: pattern"}
		"grep":
			if not _q41.has("pattern") or _q41.get("pattern", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: pattern"}
		"get_project_info":
			pass  
		"run_project":
			pass  
		"stop_project":
			pass  
		"create_file":
			if not _q41.has("path") or _q41.get("path", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: path"}
			if not _q41.has("content"):
				return {"valid": false, "error": "Missing required parameter: content"}
		"edit_file":
			if not _q41.has("path") or _q41.get("path", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: path"}
			if not _q41.has("old_string") or _q41.get("old_string", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: old_string"}
			if not _q41.has("new_string"):
				return {"valid": false, "error": "Missing required parameter: new_string"}
		"delete_file":
			if not _q41.has("path") or _q41.get("path", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: path"}
		_:
			return {"valid": false, "error": "Unknown tool: " + _i10}

	return {"valid": true}

