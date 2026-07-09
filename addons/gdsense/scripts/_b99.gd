@tool
class_name _i95
extends RefCounted

const _s70: Array[String] = [
	"res://.godot/",
	"res://.import/",
	"res://project.godot",
	"res://addons/gdsense/",
	"res://.git/"
]

const _k58: int = 50000

const _v75: int = 500

const _n66: int = 200

const _c52: Array[String] = [
	"create_file",
	"edit_file",
	"delete_file"
]

var _q86: EditorInterface

func initialize(_t15: EditorInterface) -> void:
	_q86 = _t15

func _c87(_d89: String) -> bool:
	return _d89 in _c52

func _o81(_d89: String, _z42: Dictionary) -> Dictionary:
	match _d89:
		"read_file":
			return _o22(_z42.get("path", ""))
		"list_files":
			return _z32(_z42.get("directory", "res://"), _z42.get("recursive", false))
		"glob":
			return _o53(_z42.get("pattern", ""), _z42.get("path", "res://"))
		"grep":
			return _o36(_z42.get("pattern", ""), _z42.get("path", "res://"), _z42.get("glob", ""), _z42.get("context_lines", 2))
		"get_project_info":
			return _q77()
		"run_project":
			return _z14()
		"stop_project":
			return _j1()
		"create_file":
			return _v48(_z42.get("path", ""), _z42.get("content", ""))
		"edit_file":
			return _q31(_z42.get("path", ""), _z42.get("old_string", ""), _z42.get("new_string", ""), _z42.get("replace_all", false))
		"delete_file":
			return _y43(_z42.get("path", ""))
		_:
			return {"success": false, "error": "Unknown tool: " + _d89}

func _m39(path: String) -> bool:
	if not path.begins_with("res://"):
		return false

	if ".." in path:
		return false

	var normalized = path.simplify_path()

	for _b31 in _s70:
		var _v84 = _b31.simplify_path()
		if normalized.begins_with(_v84) or normalized == _v84.trim_suffix("/"):
			return false

	return true

func _r19(path: String) -> String:
	if not path.begins_with("res://"):
		return "Path must start with res://"

	if ".." in path:
		return "Path traversal (..) is not allowed"

	var normalized = path.simplify_path()
	for _b31 in _s70:
		var _v84 = _b31.simplify_path()
		if normalized.begins_with(_v84) or normalized == _v84.trim_suffix("/"):
			return "Path is protected: " + _b31

	return "Path validation failed"

func _o22(path: String) -> Dictionary:
	if path.is_empty():
		return {"success": false, "error": "Path is required"}

	if not _m39(path):
		return {"success": false, "error": _r19(path)}

	if not FileAccess.file_exists(path):
		return {"success": false, "error": "File not found: " + path}

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		var _u36 = FileAccess.get_open_error()
		return {"success": false, "error": "Cannot open file: " + path + " (error: " + str(_u36) + ")"}

	var _b9 = file.get_length()
	var content = file.get_as_text()
	file.close()

	var _o12 = false
	if content.length() > _k58:
		content = content.substr(0, _k58) + "\n... [truncated, file too large]"
		_o12 = true

	return {
		"success": true,
		"content": content,
		"path": path,
		"size": _b9,
		"truncated": _o12
	}

func _z32(_i11: String, _r32: bool) -> Dictionary:
	if _i11.is_empty():
		_i11 = "res://"

	if not _m39(_i11):
		return {"success": false, "error": _r19(_i11)}

	var _d30 = DirAccess.open(_i11)
	if not _d30:
		var _u36 = DirAccess.get_open_error()
		return {"success": false, "error": "Cannot open directory: " + _i11 + " (error: " + str(_u36) + ")"}

	var _i67: Array[String] = []
	var _i98: Array[String] = []

	_d30.list_dir_begin()
	var _m48 = _d30.get_next()

	while _m48 != "":
		if _m48 != "." and _m48 != "..":
			var full_path = _i11.path_join(_m48)

			if _m39(full_path):
				if _d30.current_is_dir():
					_i98.append(_m48 + "/")
					if _r32:
						var _u91 = _z32(full_path, true)
						if _u91.get("success", false):
							var _u96 = _u91.get("files", [])
							for f in _u96:
								_i67.append(_m48 + "/" + f)
				else:
					_i67.append(_m48)

		_m48 = _d30.get_next()

	_d30.list_dir_end()

	return {
		"success": true,
		"directory": _i11,
		"files": _i67,
		"directories": _i98,
		"total_files": _i67.size(),
		"total_directories": _i98.size()
	}

func _o53(_c84: String, base_path: String) -> Dictionary:
	if _c84.is_empty():
		return {"success": false, "error": "Pattern is required"}

	if base_path.is_empty():
		base_path = "res://"

	if not _m39(base_path):
		return {"success": false, "error": _r19(base_path)}

	var _c95: Array[String] = []
	var _b78: int = 0

	var segments = _c84.split("/")

	_z57(base_path, segments, 0, _c95, _b78)

	var _o12 = false
	if _c95.size() > _v75:
		_c95.resize(_v75)
		_o12 = true

	return {
		"success": true,
		"matches": _c95,
		"total_found": _c95.size(),
		"truncated": _o12,
		"pattern": _c84,
		"base_path": base_path
	}

func _z57(current_path: String, segments: Array, _j58: int, _c95: Array[String], _b78: int) -> void:
	if _c95.size() >= _v75:
		return

	if _j58 >= segments.size():
		return

	var _q19 = segments[_j58]
	var _w33 = (_j58 == segments.size() - 1)

	if _q19 == "**":
		if _j58 + 1 < segments.size():
			_z57(current_path, segments, _j58 + 1, _c95, _b78)

		var _d30 = DirAccess.open(current_path)
		if _d30:
			_d30.list_dir_begin()
			var _c53 = _d30.get_next()
			while _c53 != "" and _c95.size() < _v75:
				if _c53 != "." and _c53 != "..":
					var full_path = current_path.path_join(_c53)
					if _m39(full_path) and _d30.current_is_dir():
						_z57(full_path, segments, _j58, _c95, _b78 + 1)
				_c53 = _d30.get_next()
			_d30.list_dir_end()
		return

	var _d30 = DirAccess.open(current_path)
	if not _d30:
		return

	_d30.list_dir_begin()
	var _c53 = _d30.get_next()

	while _c53 != "" and _c95.size() < _v75:
		if _c53 != "." and _c53 != "..":
			var full_path = current_path.path_join(_c53)

			if _m39(full_path):
				var _s27 = _d30.current_is_dir()

				if _d98(_c53, _q19):
					if _w33:
						if not _s27 or _q19.ends_with("/"):
							_c95.append(full_path)
						elif _s27 and not _q19.ends_with("/"):
							_c95.append(full_path)
					elif _s27:
						_z57(full_path, segments, _j58 + 1, _c95, _b78 + 1)

		_c53 = _d30.get_next()

	_d30.list_dir_end()

func _d98(name: String, _c84: String) -> bool:
	if _c84 == "*":
		return true
	if _c84 == name:
		return true

	var _m36 = "^"
	var i = 0
	while i < _c84.length():
		var c = _c84[i]
		match c:
			"*":
				_m36 += ".*"
			"?":
				_m36 += "."
			".":
				_m36 += "\\."
			"[":
				var _g88 = _c84.find("]", i)
				if _g88 > i:
					_m36 += _c84.substr(i, _g88 - i + 1)
					i = _g88
				else:
					_m36 += "\\["
			_:
				if c in "\\^$|+(){}":
					_m36 += "\\" + c
				else:
					_m36 += c
		i += 1
	_m36 += "$"

	var _p69 = RegEx.new()
	if _p69.compile(_m36) != OK:
		return name == _c84

	return _p69.search(name) != null

func _o36(_c84: String, base_path: String, _c9: String, _q70: int) -> Dictionary:
	if _c84.is_empty():
		return {"success": false, "error": "Pattern is required"}

	if base_path.is_empty():
		base_path = "res://"

	if not _m39(base_path):
		return {"success": false, "error": _r19(base_path)}

	var _p69 = RegEx.new()
	var _q26 = _p69.compile(_c84)
	if _q26 != OK:
		return {"success": false, "error": "Invalid regex pattern: " + _c84}

	var _w5: Array[String] = []

	if _c9.is_empty():
		_o94(base_path, _w5)
	else:
		var _b69 = _o53(_c9, base_path)
		if not _b69.get("success", false):
			return _b69
		for f in _b69.get("matches", []):
			_w5.append(f)

	var _c95: Array[Dictionary] = []
	var _z50: int = 0
	var _j29: int = 0

	for file_path in _w5:
		if _c95.size() >= _n66:
			break

		if _v87(file_path):
			continue

		if not FileAccess.file_exists(file_path):
			continue

		var file = FileAccess.open(file_path, FileAccess.READ)
		if not file:
			continue

		var content = file.get_as_text()
		file.close()
		_z50 += 1

		var _m12 = content.split("\n")
		var _o83 = false

		for _t33 in range(_m12.size()):
			if _c95.size() >= _n66:
				break

			var line = _m12[_t33]
			var _f51 = _p69.search(line)

			if _f51:
				_o83 = true

				var _i82: Array[String] = []
				var _i49: Array[String] = []

				for i in range(max(0, _t33 - _q70), _t33):
					_i82.append(_m12[i])

				for i in range(_t33 + 1, min(_m12.size(), _t33 + _q70 + 1)):
					_i49.append(_m12[i])

				_c95.append({
					"file": file_path,
					"line_number": _t33 + 1,
					"line": line,
					"before_context": _i82,
					"after_context": _i49,
					"match_start": _f51.get_start(),
					"match_end": _f51.get_end()
				})

		if _o83:
			_j29 += 1

	var _o12 = _c95.size() >= _n66

	return {
		"success": true,
		"matches": _c95,
		"total_matches": _c95.size(),
		"files_searched": _z50,
		"files_with_matches": _j29,
		"truncated": _o12,
		"pattern": _c84
	}

func _o94(_i11: String, _i67: Array[String]) -> void:
	var _d30 = DirAccess.open(_i11)
	if not _d30:
		return

	_d30.list_dir_begin()
	var _c53 = _d30.get_next()

	while _c53 != "":
		if _c53 != "." and _c53 != "..":
			var full_path = _i11.path_join(_c53)

			if _m39(full_path):
				if _d30.current_is_dir():
					_o94(full_path, _i67)
				else:
					_i67.append(full_path)

		_c53 = _d30.get_next()

	_d30.list_dir_end()

func _v87(path: String) -> bool:
	var _c82 = [
		".png", ".jpg", ".jpeg", ".gif", ".bmp", ".webp", ".svg",
		".ogg", ".wav", ".mp3", ".flac",
		".ttf", ".otf", ".woff", ".woff2",
		".zip", ".tar", ".gz", ".7z", ".rar",
		".exe", ".dll", ".so", ".dylib",
		".res", ".import", ".scn", ".bin",
		".glb", ".gltf", ".fbx", ".obj", ".dae"
	]

	var _c10 = path.get_extension().to_lower()
	if _c10.is_empty():
		return false

	return ("." + _c10) in _c82

func _q77() -> Dictionary:
	var _s67 = Engine.get_version_info()
	var _y92 = "%d.%d.%d" % [_s67.get("major", 0), _s67.get("minor", 0), _s67.get("patch", 0)]

	var _h31 = {
		"success": true,
		"godot_version": _y92,
		"godot_version_full": _s67.get("string", _y92),
		"project_name": ProjectSettings.get_setting("application/config/name", "Unknown"),
		"project_path": ProjectSettings.globalize_path("res://")
	}

	var _a74 = ProjectSettings.get_setting("application/run/main_scene", "")
	if not _a74.is_empty():
		_h31["main_scene"] = _a74

	var description = ProjectSettings.get_setting("application/config/description", "")
	if not description.is_empty():
		_h31["description"] = description

	var _p89: Array[String] = []
	for _s8 in ProjectSettings.get_property_list():
		var name = _s8.get("name", "")
		if name.begins_with("autoload/"):
			_p89.append(name.replace("autoload/", ""))

	if not _p89.is_empty():
		_h31["autoloads"] = _p89

	return _h31

func _z14() -> Dictionary:
	if _q86 == null:
		return {"success": false, "error": "Editor interface not available"}

	if _q86.is_playing_scene():
		return {"success": false, "error": "Project is already running"}

	_q86.play_main_scene()

	return {"success": true, "message": "Project started"}

func _j1() -> Dictionary:
	if _q86 == null:
		return {"success": false, "error": "Editor interface not available"}

	if not _q86.is_playing_scene():
		return {"success": false, "error": "Project is not running"}

	_q86.stop_playing_scene()

	return {"success": true, "message": "Project stopped"}

func _v48(path: String, content: String) -> Dictionary:
	if path.is_empty():
		return {"success": false, "error": "Path is required"}

	if not _m39(path):
		return {"success": false, "error": _r19(path)}

	if FileAccess.file_exists(path):
		return {"success": false, "error": "File already exists: " + path + ". Use edit_file to modify existing files."}

	var _p27 = path.get_base_dir()
	if not _p27.is_empty() and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_p27)):
		var _a20 = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_p27))
		if _a20 != OK:
			return {"success": false, "error": "Cannot create directory: " + _p27 + " (error: " + str(_a20) + ")"}

	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		var _u36 = FileAccess.get_open_error()
		return {"success": false, "error": "Cannot create file: " + path + " (error: " + str(_u36) + ")"}

	file.store_string(content)
	file.close()

	if _q86:
		_q86.get_resource_filesystem().scan()

	var _k3 = {
		"success": true,
		"message": "File created: " + path,
		"path": path,
		"size": content.length()
	}

	var _i8 = _x66(path)
	if not _i8["valid"]:
		_k3["warning"] = _i8["error"]
		_k3["message"] += " (WARNING: " + _i8["error"] + ")"

	return _k3

func _q31(path: String, _l47: String, _g50: String, _w14: bool) -> Dictionary:
	if path.is_empty():
		return {"success": false, "error": "Path is required"}

	if _l47.is_empty():
		return {"success": false, "error": "old_string is required"}

	if not _m39(path):
		return {"success": false, "error": _r19(path)}

	if not FileAccess.file_exists(path):
		return {"success": false, "error": "File not found: " + path + ". Use create_file to create new files."}

	var _g34 = FileAccess.open(path, FileAccess.READ)
	if not _g34:
		var _u36 = FileAccess.get_open_error()
		return {"success": false, "error": "Cannot read file: " + path + " (error: " + str(_u36) + ")"}

	var _o38 = _g34.get_as_text()
	_g34.close()

	var _a55 = _o38.find(_l47)
	if _a55 == -1:
		return {"success": false, "error": "old_string not found in file. The exact text must exist in the file."}

	var _s4 = _o38.count(_l47)

	if _s4 > 1 and not _w14:
		return {
			"success": false,
			"error": "Found " + str(_s4) + " occurrences of old_string. Set replace_all=true to replace all, or provide more context to make the string unique."
		}

	var _u11: String
	var _s78: int

	if _w14:
		_u11 = _o38.replace(_l47, _g50)
		_s78 = _s4
	else:
		_u11 = _o38.substr(0, _a55) + _g50 + _o38.substr(_a55 + _l47.length())
		_s78 = 1

	var _m42 = path + ".agent_backup"
	var _o46 = FileAccess.open(_m42, FileAccess.WRITE)
	if _o46:
		_o46.store_string(_o38)
		_o46.close()
	else:
		pass

	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		var _u36 = FileAccess.get_open_error()
		return {"success": false, "error": "Cannot write file: " + path + " (error: " + str(_u36) + ")"}

	file.store_string(_u11)
	file.close()

	if _q86:
		_q86.get_resource_filesystem().scan()

	var _k82 = _s38(_l47, _g50)

	var _k3 = {
		"success": true,
		"message": "File modified: " + path,
		"path": path,
		"replacements_made": _s78,
		"diff_preview": _k82,
		"original_size": _o38.length(),
		"new_size": _u11.length()
	}

	if FileAccess.file_exists(_m42):
		_k3["backup"] = _m42

	var _i8 = _x66(path)
	if not _i8["valid"]:
		_k3["warning"] = _i8["error"]
		_k3["message"] += " (WARNING: " + _i8["error"] + ")"

	return _k3

func _s38(_l47: String, _g50: String) -> String:
	var _r27 = _l47.split("\n")
	var _k75 = _g50.split("\n")

	var _e6 = ""

	for line in _r27:
		_e6 += "- " + line + "\n"

	for line in _k75:
		_e6 += "+ " + line + "\n"

	return _e6.strip_edges()

func _x66(path: String) -> Dictionary:
	if not path.ends_with(".tscn") and not path.ends_with(".tres"):
		return {"valid": true}

	var _f76 = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if _f76 == null:
		var _u64 = ""
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			_u64 = file.get_as_text()
			file.close()

		var _m12 = _u64.split("\n")
		var _v98 = ""
		for i in range(_m12.size()):
			_v98 += str(i + 1) + ": " + _m12[i] + "\n"

		return {
			"valid": false,
			"error": "PARSE ERROR in " + path.get_file() + ". The file has invalid format and cannot be loaded by Godot. Review the content below and fix the syntax:\n\n" + _v98
		}

	return {"valid": true}

func _y43(path: String) -> Dictionary:
	if path.is_empty():
		return {"success": false, "error": "Path is required"}

	if not _m39(path):
		return {"success": false, "error": _r19(path)}

	if not FileAccess.file_exists(path):
		return {"success": false, "error": "File not found: " + path}

	var _m57 = ProjectSettings.globalize_path(path)

	var _a20 = DirAccess.remove_absolute(_m57)
	if _a20 != OK:
		return {"success": false, "error": "Cannot delete file: " + path + " (error: " + str(_a20) + ")"}

	if _q86:
		_q86.get_resource_filesystem().scan()

	return {
		"success": true,
		"message": "File deleted: " + path,
		"path": path
	}

func _n14() -> Array[Dictionary]:
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

func _j42(_d89: String, _z42: Dictionary) -> Dictionary:
	match _d89:
		"read_file":
			if not _z42.has("path") or _z42.get("path", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: path"}
		"list_files":
			pass  
		"glob":
			if not _z42.has("pattern") or _z42.get("pattern", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: pattern"}
		"grep":
			if not _z42.has("pattern") or _z42.get("pattern", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: pattern"}
		"get_project_info":
			pass  
		"run_project":
			pass  
		"stop_project":
			pass  
		"create_file":
			if not _z42.has("path") or _z42.get("path", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: path"}
			if not _z42.has("content"):
				return {"valid": false, "error": "Missing required parameter: content"}
		"edit_file":
			if not _z42.has("path") or _z42.get("path", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: path"}
			if not _z42.has("old_string") or _z42.get("old_string", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: old_string"}
			if not _z42.has("new_string"):
				return {"valid": false, "error": "Missing required parameter: new_string"}
		"delete_file":
			if not _z42.has("path") or _z42.get("path", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: path"}
		_:
			return {"valid": false, "error": "Unknown tool: " + _d89}

	return {"valid": true}

