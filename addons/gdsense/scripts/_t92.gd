@tool
class_name _t27
extends RefCounted
const _y59: Array[String] = [
	"res://.godot/",
	"res://.import/",
	"res://project.godot",
	"res://addons/gdsense/",
	"res://.git/"
]
const _o36: int = 50000
const _v51: int = 500
const _k90: int = 200
const _n37: Array[String] = [
	"create_file",
	"edit_file",
	"delete_file"
]
var _w27: EditorInterface
func initialize(_d84: EditorInterface) -> void:
	_w27 = _d84
func _z5(_c79: String) -> bool:
	return _c79 in _n37
func _r48(_c79: String, _e52: Dictionary) -> Dictionary:
	match _c79:
		"read_file":
			return _a61(_e52.get("path", ""))
		"list_files":
			return _u9(_e52.get("directory", "res://"), _e52.get("recursive", false))
		"glob":
			return _t99(_e52.get("pattern", ""), _e52.get("path", "res://"))
		"grep":
			return _p15(_e52.get("pattern", ""), _e52.get("path", "res://"), _e52.get("glob", ""), _e52.get("context_lines", 2))
		"get_project_info":
			return _a96()
		"run_project":
			return _n28()
		"stop_project":
			return _m6()
		"create_file":
			return _f46(_e52.get("path", ""), _e52.get("content", ""))
		"edit_file":
			return _w15(_e52.get("path", ""), _e52.get("old_string", ""), _e52.get("new_string", ""), _e52.get("replace_all", false))
		"delete_file":
			return _b98(_e52.get("path", ""))
		_:
			return {"success": false, "error": "Unknown tool: " + _c79}
func _i5(path: String) -> bool:
	if not path.begins_with("res://"):
		return false
	if ".." in path:
		return false
	var normalized = path.simplify_path()
	for _i90 in _y59:
		var _c73 = _i90.simplify_path()
		if normalized.begins_with(_c73) or normalized == _c73.trim_suffix("/"):
			return false
	return true
func _e14(path: String) -> String:
	if not path.begins_with("res://"):
		return "Path must start with res://"
	if ".." in path:
		return "Path traversal (..) is not allowed"
	var normalized = path.simplify_path()
	for _i90 in _y59:
		var _c73 = _i90.simplify_path()
		if normalized.begins_with(_c73) or normalized == _c73.trim_suffix("/"):
			return "Path is protected: " + _i90
	return "Path validation failed"
func _a61(path: String) -> Dictionary:
	if path.is_empty():
		return {"success": false, "error": "Path is required"}
	if not _i5(path):
		return {"success": false, "error": _e14(path)}
	if not FileAccess.file_exists(path):
		return {"success": false, "error": "File not found: " + path}
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		var _m46 = FileAccess.get_open_error()
		return {"success": false, "error": "Cannot open file: " + path + " (error: " + str(_m46) + ")"}
	var _b65 = file.get_length()
	var content = file.get_as_text()
	file.close()
	var _n60 = false
	if content.length() > _o36:
		content = content.substr(0, _o36) + "\n... [truncated, file too large]"
		_n60 = true
	return {
		"success": true,
		"content": content,
		"path": path,
		"size": _b65,
		"truncated": _n60
	}
func _u9(_g97: String, _p91: bool) -> Dictionary:
	if _g97.is_empty():
		_g97 = "res://"
	if not _i5(_g97):
		return {"success": false, "error": _e14(_g97)}
	var _v15 = DirAccess.open(_g97)
	if not _v15:
		var _m46 = DirAccess.get_open_error()
		return {"success": false, "error": "Cannot open directory: " + _g97 + " (error: " + str(_m46) + ")"}
	var _w56: Array[String] = []
	var _c76: Array[String] = []
	_v15.list_dir_begin()
	var _f63 = _v15.get_next()
	while _f63 != "":
		if _f63 != "." and _f63 != "..":
			var full_path = _g97.path_join(_f63)
			if _i5(full_path):
				if _v15.current_is_dir():
					_c76.append(_f63 + "/")
					if _p91:
						var _s20 = _u9(full_path, true)
						if _s20.get("success", false):
							var _x59 = _s20.get("files", [])
							for f in _x59:
								_w56.append(_f63 + "/" + f)
				else:
					_w56.append(_f63)
		_f63 = _v15.get_next()
	_v15.list_dir_end()
	return {
		"success": true,
		"directory": _g97,
		"files": _w56,
		"directories": _c76,
		"total_files": _w56.size(),
		"total_directories": _c76.size()
	}
func _t99(_y99: String, base_path: String) -> Dictionary:
	if _y99.is_empty():
		return {"success": false, "error": "Pattern is required"}
	if base_path.is_empty():
		base_path = "res://"
	if not _i5(base_path):
		return {"success": false, "error": _e14(base_path)}
	var _l62: Array[String] = []
	var _i45: int = 0
	var segments = _y99.split("/")
	_j51(base_path, segments, 0, _l62, _i45)
	var _n60 = false
	if _l62.size() > _v51:
		_l62.resize(_v51)
		_n60 = true
	return {
		"success": true,
		"matches": _l62,
		"total_found": _l62.size(),
		"truncated": _n60,
		"pattern": _y99,
		"base_path": base_path
	}
func _j51(current_path: String, segments: Array, _y72: int, _l62: Array[String], _i45: int) -> void:
	if _l62.size() >= _v51:
		return
	if _y72 >= segments.size():
		return
	var _m65 = segments[_y72]
	var _d33 = (_y72 == segments.size() - 1)
	if _m65 == "**":
		if _y72 + 1 < segments.size():
			_j51(current_path, segments, _y72 + 1, _l62, _i45)
		var _v15 = DirAccess.open(current_path)
		if _v15:
			_v15.list_dir_begin()
			var _v92 = _v15.get_next()
			while _v92 != "" and _l62.size() < _v51:
				if _v92 != "." and _v92 != "..":
					var full_path = current_path.path_join(_v92)
					if _i5(full_path) and _v15.current_is_dir():
						_j51(full_path, segments, _y72, _l62, _i45 + 1)
				_v92 = _v15.get_next()
			_v15.list_dir_end()
		return
	var _v15 = DirAccess.open(current_path)
	if not _v15:
		return
	_v15.list_dir_begin()
	var _v92 = _v15.get_next()
	while _v92 != "" and _l62.size() < _v51:
		if _v92 != "." and _v92 != "..":
			var full_path = current_path.path_join(_v92)
			if _i5(full_path):
				var _i92 = _v15.current_is_dir()
				if _j46(_v92, _m65):
					if _d33:
						if not _i92 or _m65.ends_with("/"):
							_l62.append(full_path)
						elif _i92 and not _m65.ends_with("/"):
							_l62.append(full_path)
					elif _i92:
						_j51(full_path, segments, _y72 + 1, _l62, _i45 + 1)
		_v92 = _v15.get_next()
	_v15.list_dir_end()
func _j46(name: String, _y99: String) -> bool:
	if _y99 == "*":
		return true
	if _y99 == name:
		return true
	var _g33 = "^"
	var i = 0
	while i < _y99.length():
		var c = _y99[i]
		match c:
			"*":
				_g33 += ".*"
			"?":
				_g33 += "."
			".":
				_g33 += "\\."
			"[":
				var _c77 = _y99.find("]", i)
				if _c77 > i:
					_g33 += _y99.substr(i, _c77 - i + 1)
					i = _c77
				else:
					_g33 += "\\["
			_:
				if c in "\\^$|+(){}":
					_g33 += "\\" + c
				else:
					_g33 += c
		i += 1
	_g33 += "$"
	var _v54 = RegEx.new()
	if _v54.compile(_g33) != OK:
		return name == _y99
	return _v54.search(name) != null
func _p15(_y99: String, base_path: String, _r61: String, _u47: int) -> Dictionary:
	if _y99.is_empty():
		return {"success": false, "error": "Pattern is required"}
	if base_path.is_empty():
		base_path = "res://"
	if not _i5(base_path):
		return {"success": false, "error": _e14(base_path)}
	var _v54 = RegEx.new()
	var _e16 = _v54.compile(_y99)
	if _e16 != OK:
		return {"success": false, "error": "Invalid regex pattern: " + _y99}
	var _l7: Array[String] = []
	if _r61.is_empty():
		_s31(base_path, _l7)
	else:
		var _m3 = _t99(_r61, base_path)
		if not _m3.get("success", false):
			return _m3
		for f in _m3.get("matches", []):
			_l7.append(f)
	var _l62: Array[Dictionary] = []
	var _m95: int = 0
	var _v94: int = 0
	for file_path in _l7:
		if _l62.size() >= _k90:
			break
		if _d44(file_path):
			continue
		if not FileAccess.file_exists(file_path):
			continue
		var file = FileAccess.open(file_path, FileAccess.READ)
		if not file:
			continue
		var content = file.get_as_text()
		file.close()
		_m95 += 1
		var _j90 = content.split("\n")
		var _t10 = false
		for _w41 in range(_j90.size()):
			if _l62.size() >= _k90:
				break
			var line = _j90[_w41]
			var _u56 = _v54.search(line)
			if _u56:
				_t10 = true
				var _q49: Array[String] = []
				var _s48: Array[String] = []
				for i in range(max(0, _w41 - _u47), _w41):
					_q49.append(_j90[i])
				for i in range(_w41 + 1, min(_j90.size(), _w41 + _u47 + 1)):
					_s48.append(_j90[i])
				_l62.append({
					"file": file_path,
					"line_number": _w41 + 1,
					"line": line,
					"before_context": _q49,
					"after_context": _s48,
					"match_start": _u56.get_start(),
					"match_end": _u56.get_end()
				})
		if _t10:
			_v94 += 1
	var _n60 = _l62.size() >= _k90
	return {
		"success": true,
		"matches": _l62,
		"total_matches": _l62.size(),
		"files_searched": _m95,
		"files_with_matches": _v94,
		"truncated": _n60,
		"pattern": _y99
	}
func _s31(_g97: String, _w56: Array[String]) -> void:
	var _v15 = DirAccess.open(_g97)
	if not _v15:
		return
	_v15.list_dir_begin()
	var _v92 = _v15.get_next()
	while _v92 != "":
		if _v92 != "." and _v92 != "..":
			var full_path = _g97.path_join(_v92)
			if _i5(full_path):
				if _v15.current_is_dir():
					_s31(full_path, _w56)
				else:
					_w56.append(full_path)
		_v92 = _v15.get_next()
	_v15.list_dir_end()
func _d44(path: String) -> bool:
	var _c95 = [
		".png", ".jpg", ".jpeg", ".gif", ".bmp", ".webp", ".svg",
		".ogg", ".wav", ".mp3", ".flac",
		".ttf", ".otf", ".woff", ".woff2",
		".zip", ".tar", ".gz", ".7z", ".rar",
		".exe", ".dll", ".so", ".dylib",
		".res", ".import", ".scn", ".bin",
		".glb", ".gltf", ".fbx", ".obj", ".dae"
	]
	var _z94 = path.get_extension().to_lower()
	if _z94.is_empty():
		return false
	return ("." + _z94) in _c95
func _a96() -> Dictionary:
	var _g90 = Engine.get_version_info()
	var _w12 = "%d.%d.%d" % [_g90.get("major", 0), _g90.get("minor", 0), _g90.get("patch", 0)]
	var _p29 = {
		"success": true,
		"godot_version": _w12,
		"godot_version_full": _g90.get("string", _w12),
		"project_name": ProjectSettings.get_setting("application/config/name", "Unknown"),
		"project_path": ProjectSettings.globalize_path("res://")
	}
	var _l64 = ProjectSettings.get_setting("application/run/main_scene", "")
	if not _l64.is_empty():
		_p29["main_scene"] = _l64
	var description = ProjectSettings.get_setting("application/config/description", "")
	if not description.is_empty():
		_p29["description"] = description
	var _r92: Array[String] = []
	for _w79 in ProjectSettings.get_property_list():
		var name = _w79.get("name", "")
		if name.begins_with("autoload/"):
			_r92.append(name.replace("autoload/", ""))
	if not _r92.is_empty():
		_p29["autoloads"] = _r92
	return _p29
func _n28() -> Dictionary:
	if _w27 == null:
		return {"success": false, "error": "Editor interface not available"}
	if _w27.is_playing_scene():
		return {"success": false, "error": "Project is already running"}
	_w27.play_main_scene()
	return {"success": true, "message": "Project started"}
func _m6() -> Dictionary:
	if _w27 == null:
		return {"success": false, "error": "Editor interface not available"}
	if not _w27.is_playing_scene():
		return {"success": false, "error": "Project is not running"}
	_w27.stop_playing_scene()
	return {"success": true, "message": "Project stopped"}
func _f46(path: String, content: String) -> Dictionary:
	if path.is_empty():
		return {"success": false, "error": "Path is required"}
	if not _i5(path):
		return {"success": false, "error": _e14(path)}
	if FileAccess.file_exists(path):
		return {"success": false, "error": "File already exists: " + path + ". Use edit_file to modify existing files."}
	var _z35 = path.get_base_dir()
	if not _z35.is_empty() and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_z35)):
		var _d74 = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_z35))
		if _d74 != OK:
			return {"success": false, "error": "Cannot create directory: " + _z35 + " (error: " + str(_d74) + ")"}
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		var _m46 = FileAccess.get_open_error()
		return {"success": false, "error": "Cannot create file: " + path + " (error: " + str(_m46) + ")"}
	file.store_string(content)
	file.close()
	if _w27:
		_w27.get_resource_filesystem().scan()
	var _x97 = {
		"success": true,
		"message": "File created: " + path,
		"path": path,
		"size": content.length()
	}
	var _p32 = _f100(path)
	if not _p32["valid"]:
		_x97["warning"] = _p32["error"]
		_x97["message"] += " (WARNING: " + _p32["error"] + ")"
	return _x97
func _w15(path: String, _l54: String, _i95: String, _j95: bool) -> Dictionary:
	if path.is_empty():
		return {"success": false, "error": "Path is required"}
	if _l54.is_empty():
		return {"success": false, "error": "old_string is required"}
	if not _i5(path):
		return {"success": false, "error": _e14(path)}
	if not FileAccess.file_exists(path):
		return {"success": false, "error": "File not found: " + path + ". Use create_file to create new files."}
	var _o28 = FileAccess.open(path, FileAccess.READ)
	if not _o28:
		var _m46 = FileAccess.get_open_error()
		return {"success": false, "error": "Cannot read file: " + path + " (error: " + str(_m46) + ")"}
	var _u43 = _o28.get_as_text()
	_o28.close()
	var _u33 = _u43.find(_l54)
	if _u33 == -1:
		return {"success": false, "error": "old_string not found in file. The exact text must exist in the file."}
	var _t26 = _u43.count(_l54)
	if _t26 > 1 and not _j95:
		return {
			"success": false,
			"error": "Found " + str(_t26) + " occurrences of old_string. Set replace_all=true to replace all, or provide more context to make the string unique."
		}
	var _e82: String
	var _a10: int
	if _j95:
		_e82 = _u43.replace(_l54, _i95)
		_a10 = _t26
	else:
		_e82 = _u43.substr(0, _u33) + _i95 + _u43.substr(_u33 + _l54.length())
		_a10 = 1
	var _b62 = path + ".agent_backup"
	var _c81 = FileAccess.open(_b62, FileAccess.WRITE)
	if _c81:
		_c81.store_string(_u43)
		_c81.close()
	else:
		pass
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		var _m46 = FileAccess.get_open_error()
		return {"success": false, "error": "Cannot write file: " + path + " (error: " + str(_m46) + ")"}
	file.store_string(_e82)
	file.close()
	if _w27:
		_w27.get_resource_filesystem().scan()
	var _m31 = _a16(_l54, _i95)
	var _x97 = {
		"success": true,
		"message": "File modified: " + path,
		"path": path,
		"replacements_made": _a10,
		"diff_preview": _m31,
		"original_size": _u43.length(),
		"new_size": _e82.length()
	}
	if FileAccess.file_exists(_b62):
		_x97["backup"] = _b62
	var _p32 = _f100(path)
	if not _p32["valid"]:
		_x97["warning"] = _p32["error"]
		_x97["message"] += " (WARNING: " + _p32["error"] + ")"
	return _x97
func _a16(_l54: String, _i95: String) -> String:
	var _x88 = _l54.split("\n")
	var _m32 = _i95.split("\n")
	var _u74 = ""
	for line in _x88:
		_u74 += "- " + line + "\n"
	for line in _m32:
		_u74 += "+ " + line + "\n"
	return _u74.strip_edges()
func _f100(path: String) -> Dictionary:
	if not path.ends_with(".tscn") and not path.ends_with(".tres"):
		return {"valid": true}
	var _j39 = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if _j39 == null:
		var _y14 = ""
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			_y14 = file.get_as_text()
			file.close()
		var _j90 = _y14.split("\n")
		var _q46 = ""
		for i in range(_j90.size()):
			_q46 += str(i + 1) + ": " + _j90[i] + "\n"
		return {
			"valid": false,
			"error": "PARSE ERROR in " + path.get_file() + ". The file has invalid format and cannot be loaded by Godot. Review the content below and fix the syntax:\n\n" + _q46
		}
	return {"valid": true}
func _b98(path: String) -> Dictionary:
	if path.is_empty():
		return {"success": false, "error": "Path is required"}
	if not _i5(path):
		return {"success": false, "error": _e14(path)}
	if not FileAccess.file_exists(path):
		return {"success": false, "error": "File not found: " + path}
	var _u96 = ProjectSettings.globalize_path(path)
	var _d74 = DirAccess.remove_absolute(_u96)
	if _d74 != OK:
		return {"success": false, "error": "Cannot delete file: " + path + " (error: " + str(_d74) + ")"}
	if _w27:
		_w27.get_resource_filesystem().scan()
	return {
		"success": true,
		"message": "File deleted: " + path,
		"path": path
	}
func _g98() -> Array[Dictionary]:
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
func _r58(_c79: String, _e52: Dictionary) -> Dictionary:
	match _c79:
		"read_file":
			if not _e52.has("path") or _e52.get("path", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: path"}
		"list_files":
			pass  
		"glob":
			if not _e52.has("pattern") or _e52.get("pattern", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: pattern"}
		"grep":
			if not _e52.has("pattern") or _e52.get("pattern", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: pattern"}
		"get_project_info":
			pass  
		"run_project":
			pass  
		"stop_project":
			pass  
		"create_file":
			if not _e52.has("path") or _e52.get("path", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: path"}
			if not _e52.has("content"):
				return {"valid": false, "error": "Missing required parameter: content"}
		"edit_file":
			if not _e52.has("path") or _e52.get("path", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: path"}
			if not _e52.has("old_string") or _e52.get("old_string", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: old_string"}
			if not _e52.has("new_string"):
				return {"valid": false, "error": "Missing required parameter: new_string"}
		"delete_file":
			if not _e52.has("path") or _e52.get("path", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: path"}
		_:
			return {"valid": false, "error": "Unknown tool: " + _c79}
	return {"valid": true}
