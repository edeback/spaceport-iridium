@tool
class_name _a98
extends RefCounted
const _g72: Array[String] = [
	"res://.godot/",
	"res://.import/",
	"res://project.godot",
	"res://addons/gdsense/",
	"res://.git/"
]
const _q52: int = 50000
const _i4: int = 500
const _w96: int = 200
const _t15: Array[String] = [
	"create_file",
	"edit_file",
	"delete_file"
]
var _b72: EditorInterface
func initialize(_o10: EditorInterface) -> void:
	_b72 = _o10
func _u28(_s46: String) -> bool:
	return _s46 in _t15
func _a91(_s46: String, _m19: Dictionary) -> Dictionary:
	match _s46:
		"read_file":
			return _a46(_m19.get("path", ""))
		"list_files":
			return _n12(_m19.get("directory", "res://"), _m19.get("recursive", false))
		"glob":
			return _d22(_m19.get("pattern", ""), _m19.get("path", "res://"))
		"grep":
			return _s66(_m19.get("pattern", ""), _m19.get("path", "res://"), _m19.get("glob", ""), _m19.get("context_lines", 2))
		"get_project_info":
			return _x78()
		"run_project":
			return _h65()
		"stop_project":
			return _f89()
		"create_file":
			return _i53(_m19.get("path", ""), _m19.get("content", ""))
		"edit_file":
			return _n86(_m19.get("path", ""), _m19.get("old_string", ""), _m19.get("new_string", ""), _m19.get("replace_all", false))
		"delete_file":
			return _z3(_m19.get("path", ""))
		_:
			return {"success": false, "error": "Unknown tool: " + _s46}
func _f2(path: String) -> bool:
	if not path.begins_with("res://"):
		return false
	if ".." in path:
		return false
	var normalized = path.simplify_path()
	for _d43 in _g72:
		var _u37 = _d43.simplify_path()
		if normalized.begins_with(_u37) or normalized == _u37.trim_suffix("/"):
			return false
	return true
func _z21(path: String) -> String:
	if not path.begins_with("res://"):
		return "Path must start with res://"
	if ".." in path:
		return "Path traversal (..) is not allowed"
	var normalized = path.simplify_path()
	for _d43 in _g72:
		var _u37 = _d43.simplify_path()
		if normalized.begins_with(_u37) or normalized == _u37.trim_suffix("/"):
			return "Path is protected: " + _d43
	return "Path validation failed"
func _a46(path: String) -> Dictionary:
	if path.is_empty():
		return {"success": false, "error": "Path is required"}
	if not _f2(path):
		return {"success": false, "error": _z21(path)}
	if not FileAccess.file_exists(path):
		return {"success": false, "error": "File not found: " + path}
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		var _i44 = FileAccess.get_open_error()
		return {"success": false, "error": "Cannot open file: " + path + " (error: " + str(_i44) + ")"}
	var _i40 = file.get_length()
	var content = file.get_as_text()
	file.close()
	var _z80 = false
	if content.length() > _q52:
		content = content.substr(0, _q52) + "\n... [truncated, file too large]"
		_z80 = true
	return {
		"success": true,
		"content": content,
		"path": path,
		"size": _i40,
		"truncated": _z80
	}
func _n12(_m5: String, _w49: bool) -> Dictionary:
	if _m5.is_empty():
		_m5 = "res://"
	if not _f2(_m5):
		return {"success": false, "error": _z21(_m5)}
	var _e23 = DirAccess.open(_m5)
	if not _e23:
		var _i44 = DirAccess.get_open_error()
		return {"success": false, "error": "Cannot open directory: " + _m5 + " (error: " + str(_i44) + ")"}
	var _u72: Array[String] = []
	var _p78: Array[String] = []
	_e23.list_dir_begin()
	var _s80 = _e23.get_next()
	while _s80 != "":
		if _s80 != "." and _s80 != "..":
			var full_path = _m5.path_join(_s80)
			if _f2(full_path):
				if _e23.current_is_dir():
					_p78.append(_s80 + "/")
					if _w49:
						var _l78 = _n12(full_path, true)
						if _l78.get("success", false):
							var _f9 = _l78.get("files", [])
							for f in _f9:
								_u72.append(_s80 + "/" + f)
				else:
					_u72.append(_s80)
		_s80 = _e23.get_next()
	_e23.list_dir_end()
	return {
		"success": true,
		"directory": _m5,
		"files": _u72,
		"directories": _p78,
		"total_files": _u72.size(),
		"total_directories": _p78.size()
	}
func _d22(_a45: String, base_path: String) -> Dictionary:
	if _a45.is_empty():
		return {"success": false, "error": "Pattern is required"}
	if base_path.is_empty():
		base_path = "res://"
	if not _f2(base_path):
		return {"success": false, "error": _z21(base_path)}
	var _i38: Array[String] = []
	var _z60: int = 0
	var segments = _a45.split("/")
	_l2(base_path, segments, 0, _i38, _z60)
	var _z80 = false
	if _i38.size() > _i4:
		_i38.resize(_i4)
		_z80 = true
	return {
		"success": true,
		"matches": _i38,
		"total_found": _i38.size(),
		"truncated": _z80,
		"pattern": _a45,
		"base_path": base_path
	}
func _l2(current_path: String, segments: Array, _a64: int, _i38: Array[String], _z60: int) -> void:
	if _i38.size() >= _i4:
		return
	if _a64 >= segments.size():
		return
	var _x80 = segments[_a64]
	var _k96 = (_a64 == segments.size() - 1)
	if _x80 == "**":
		if _a64 + 1 < segments.size():
			_l2(current_path, segments, _a64 + 1, _i38, _z60)
		var _e23 = DirAccess.open(current_path)
		if _e23:
			_e23.list_dir_begin()
			var _o18 = _e23.get_next()
			while _o18 != "" and _i38.size() < _i4:
				if _o18 != "." and _o18 != "..":
					var full_path = current_path.path_join(_o18)
					if _f2(full_path) and _e23.current_is_dir():
						_l2(full_path, segments, _a64, _i38, _z60 + 1)
				_o18 = _e23.get_next()
			_e23.list_dir_end()
		return
	var _e23 = DirAccess.open(current_path)
	if not _e23:
		return
	_e23.list_dir_begin()
	var _o18 = _e23.get_next()
	while _o18 != "" and _i38.size() < _i4:
		if _o18 != "." and _o18 != "..":
			var full_path = current_path.path_join(_o18)
			if _f2(full_path):
				var _d12 = _e23.current_is_dir()
				if _u67(_o18, _x80):
					if _k96:
						if not _d12 or _x80.ends_with("/"):
							_i38.append(full_path)
						elif _d12 and not _x80.ends_with("/"):
							_i38.append(full_path)
					elif _d12:
						_l2(full_path, segments, _a64 + 1, _i38, _z60 + 1)
		_o18 = _e23.get_next()
	_e23.list_dir_end()
func _u67(name: String, _a45: String) -> bool:
	if _a45 == "*":
		return true
	if _a45 == name:
		return true
	var _s47 = "^"
	var i = 0
	while i < _a45.length():
		var c = _a45[i]
		match c:
			"*":
				_s47 += ".*"
			"?":
				_s47 += "."
			".":
				_s47 += "\\."
			"[":
				var _e34 = _a45.find("]", i)
				if _e34 > i:
					_s47 += _a45.substr(i, _e34 - i + 1)
					i = _e34
				else:
					_s47 += "\\["
			_:
				if c in "\\^$|+(){}":
					_s47 += "\\" + c
				else:
					_s47 += c
		i += 1
	_s47 += "$"
	var _s2 = RegEx.new()
	if _s2.compile(_s47) != OK:
		return name == _a45
	return _s2.search(name) != null
func _s66(_a45: String, base_path: String, _t26: String, _v41: int) -> Dictionary:
	if _a45.is_empty():
		return {"success": false, "error": "Pattern is required"}
	if base_path.is_empty():
		base_path = "res://"
	if not _f2(base_path):
		return {"success": false, "error": _z21(base_path)}
	var _s2 = RegEx.new()
	var _f14 = _s2.compile(_a45)
	if _f14 != OK:
		return {"success": false, "error": "Invalid regex pattern: " + _a45}
	var _n100: Array[String] = []
	if _t26.is_empty():
		_a88(base_path, _n100)
	else:
		var _z31 = _d22(_t26, base_path)
		if not _z31.get("success", false):
			return _z31
		for f in _z31.get("matches", []):
			_n100.append(f)
	var _i38: Array[Dictionary] = []
	var _t46: int = 0
	var _o34: int = 0
	for file_path in _n100:
		if _i38.size() >= _w96:
			break
		if _k26(file_path):
			continue
		if not FileAccess.file_exists(file_path):
			continue
		var file = FileAccess.open(file_path, FileAccess.READ)
		if not file:
			continue
		var content = file.get_as_text()
		file.close()
		_t46 += 1
		var _a62 = content.split("\n")
		var _n97 = false
		for _v36 in range(_a62.size()):
			if _i38.size() >= _w96:
				break
			var line = _a62[_v36]
			var _q91 = _s2.search(line)
			if _q91:
				_n97 = true
				var _r7: Array[String] = []
				var _l54: Array[String] = []
				for i in range(max(0, _v36 - _v41), _v36):
					_r7.append(_a62[i])
				for i in range(_v36 + 1, min(_a62.size(), _v36 + _v41 + 1)):
					_l54.append(_a62[i])
				_i38.append({
					"file": file_path,
					"line_number": _v36 + 1,
					"line": line,
					"before_context": _r7,
					"after_context": _l54,
					"match_start": _q91.get_start(),
					"match_end": _q91.get_end()
				})
		if _n97:
			_o34 += 1
	var _z80 = _i38.size() >= _w96
	return {
		"success": true,
		"matches": _i38,
		"total_matches": _i38.size(),
		"files_searched": _t46,
		"files_with_matches": _o34,
		"truncated": _z80,
		"pattern": _a45
	}
func _a88(_m5: String, _u72: Array[String]) -> void:
	var _e23 = DirAccess.open(_m5)
	if not _e23:
		return
	_e23.list_dir_begin()
	var _o18 = _e23.get_next()
	while _o18 != "":
		if _o18 != "." and _o18 != "..":
			var full_path = _m5.path_join(_o18)
			if _f2(full_path):
				if _e23.current_is_dir():
					_a88(full_path, _u72)
				else:
					_u72.append(full_path)
		_o18 = _e23.get_next()
	_e23.list_dir_end()
func _k26(path: String) -> bool:
	var _r1 = [
		".png", ".jpg", ".jpeg", ".gif", ".bmp", ".webp", ".svg",
		".ogg", ".wav", ".mp3", ".flac",
		".ttf", ".otf", ".woff", ".woff2",
		".zip", ".tar", ".gz", ".7z", ".rar",
		".exe", ".dll", ".so", ".dylib",
		".res", ".import", ".scn", ".bin",
		".glb", ".gltf", ".fbx", ".obj", ".dae"
	]
	var _k95 = path.get_extension().to_lower()
	if _k95.is_empty():
		return false
	return ("." + _k95) in _r1
func _x78() -> Dictionary:
	var _q72 = Engine.get_version_info()
	var _y80 = "%d.%d.%d" % [_q72.get("major", 0), _q72.get("minor", 0), _q72.get("patch", 0)]
	var _y4 = {
		"success": true,
		"godot_version": _y80,
		"godot_version_full": _q72.get("string", _y80),
		"project_name": ProjectSettings.get_setting("application/config/name", "Unknown"),
		"project_path": ProjectSettings.globalize_path("res://")
	}
	var _m4 = ProjectSettings.get_setting("application/run/main_scene", "")
	if not _m4.is_empty():
		_y4["main_scene"] = _m4
	var description = ProjectSettings.get_setting("application/config/description", "")
	if not description.is_empty():
		_y4["description"] = description
	var _k100: Array[String] = []
	for _w99 in ProjectSettings.get_property_list():
		var name = _w99.get("name", "")
		if name.begins_with("autoload/"):
			_k100.append(name.replace("autoload/", ""))
	if not _k100.is_empty():
		_y4["autoloads"] = _k100
	return _y4
func _h65() -> Dictionary:
	if _b72 == null:
		return {"success": false, "error": "Editor interface not available"}
	if _b72.is_playing_scene():
		return {"success": false, "error": "Project is already running"}
	_b72.play_main_scene()
	return {"success": true, "message": "Project started"}
func _f89() -> Dictionary:
	if _b72 == null:
		return {"success": false, "error": "Editor interface not available"}
	if not _b72.is_playing_scene():
		return {"success": false, "error": "Project is not running"}
	_b72.stop_playing_scene()
	return {"success": true, "message": "Project stopped"}
func _i53(path: String, content: String) -> Dictionary:
	if path.is_empty():
		return {"success": false, "error": "Path is required"}
	if not _f2(path):
		return {"success": false, "error": _z21(path)}
	if FileAccess.file_exists(path):
		return {"success": false, "error": "File already exists: " + path + ". Use edit_file to modify existing files."}
	var _w38 = path.get_base_dir()
	if not _w38.is_empty() and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_w38)):
		var _x35 = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_w38))
		if _x35 != OK:
			return {"success": false, "error": "Cannot create directory: " + _w38 + " (error: " + str(_x35) + ")"}
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		var _i44 = FileAccess.get_open_error()
		return {"success": false, "error": "Cannot create file: " + path + " (error: " + str(_i44) + ")"}
	file.store_string(content)
	file.close()
	if _b72:
		_b72.get_resource_filesystem().scan()
	var _n37 = {
		"success": true,
		"message": "File created: " + path,
		"path": path,
		"size": content.length()
	}
	var _w84 = _m13(path)
	if not _w84["valid"]:
		_n37["warning"] = _w84["error"]
		_n37["message"] += " (WARNING: " + _w84["error"] + ")"
	return _n37
func _n86(path: String, _a19: String, _q6: String, _s60: bool) -> Dictionary:
	if path.is_empty():
		return {"success": false, "error": "Path is required"}
	if _a19.is_empty():
		return {"success": false, "error": "old_string is required"}
	if not _f2(path):
		return {"success": false, "error": _z21(path)}
	if not FileAccess.file_exists(path):
		return {"success": false, "error": "File not found: " + path + ". Use create_file to create new files."}
	var _i93 = FileAccess.open(path, FileAccess.READ)
	if not _i93:
		var _i44 = FileAccess.get_open_error()
		return {"success": false, "error": "Cannot read file: " + path + " (error: " + str(_i44) + ")"}
	var _y75 = _i93.get_as_text()
	_i93.close()
	var _o83 = _y75.find(_a19)
	if _o83 == -1:
		return {"success": false, "error": "old_string not found in file. The exact text must exist in the file."}
	var _n88 = _y75.count(_a19)
	if _n88 > 1 and not _s60:
		return {
			"success": false,
			"error": "Found " + str(_n88) + " occurrences of old_string. Set replace_all=true to replace all, or provide more context to make the string unique."
		}
	var _u27: String
	var _t7: int
	if _s60:
		_u27 = _y75.replace(_a19, _q6)
		_t7 = _n88
	else:
		_u27 = _y75.substr(0, _o83) + _q6 + _y75.substr(_o83 + _a19.length())
		_t7 = 1
	var _z49 = path + ".agent_backup"
	var _o35 = FileAccess.open(_z49, FileAccess.WRITE)
	if _o35:
		_o35.store_string(_y75)
		_o35.close()
	else:
		pass
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		var _i44 = FileAccess.get_open_error()
		return {"success": false, "error": "Cannot write file: " + path + " (error: " + str(_i44) + ")"}
	file.store_string(_u27)
	file.close()
	if _b72:
		_b72.get_resource_filesystem().scan()
	var _s50 = _q4(_a19, _q6)
	var _n37 = {
		"success": true,
		"message": "File modified: " + path,
		"path": path,
		"replacements_made": _t7,
		"diff_preview": _s50,
		"original_size": _y75.length(),
		"new_size": _u27.length()
	}
	if FileAccess.file_exists(_z49):
		_n37["backup"] = _z49
	var _w84 = _m13(path)
	if not _w84["valid"]:
		_n37["warning"] = _w84["error"]
		_n37["message"] += " (WARNING: " + _w84["error"] + ")"
	return _n37
func _q4(_a19: String, _q6: String) -> String:
	var _a28 = _a19.split("\n")
	var _l16 = _q6.split("\n")
	var _e45 = ""
	for line in _a28:
		_e45 += "- " + line + "\n"
	for line in _l16:
		_e45 += "+ " + line + "\n"
	return _e45.strip_edges()
func _m13(path: String) -> Dictionary:
	if not path.ends_with(".tscn") and not path.ends_with(".tres"):
		return {"valid": true}
	var _b93 = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if _b93 == null:
		var _r40 = ""
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			_r40 = file.get_as_text()
			file.close()
		var _a62 = _r40.split("\n")
		var _u51 = ""
		for i in range(_a62.size()):
			_u51 += str(i + 1) + ": " + _a62[i] + "\n"
		return {
			"valid": false,
			"error": "PARSE ERROR in " + path.get_file() + ". The file has invalid format and cannot be loaded by Godot. Review the content below and fix the syntax:\n\n" + _u51
		}
	return {"valid": true}
func _z3(path: String) -> Dictionary:
	if path.is_empty():
		return {"success": false, "error": "Path is required"}
	if not _f2(path):
		return {"success": false, "error": _z21(path)}
	if not FileAccess.file_exists(path):
		return {"success": false, "error": "File not found: " + path}
	var _i87 = ProjectSettings.globalize_path(path)
	var _x35 = DirAccess.remove_absolute(_i87)
	if _x35 != OK:
		return {"success": false, "error": "Cannot delete file: " + path + " (error: " + str(_x35) + ")"}
	if _b72:
		_b72.get_resource_filesystem().scan()
	return {
		"success": true,
		"message": "File deleted: " + path,
		"path": path
	}
func _a90() -> Array[Dictionary]:
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
func _u57(_s46: String, _m19: Dictionary) -> Dictionary:
	match _s46:
		"read_file":
			if not _m19.has("path") or _m19.get("path", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: path"}
		"list_files":
			pass  
		"glob":
			if not _m19.has("pattern") or _m19.get("pattern", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: pattern"}
		"grep":
			if not _m19.has("pattern") or _m19.get("pattern", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: pattern"}
		"get_project_info":
			pass  
		"run_project":
			pass  
		"stop_project":
			pass  
		"create_file":
			if not _m19.has("path") or _m19.get("path", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: path"}
			if not _m19.has("content"):
				return {"valid": false, "error": "Missing required parameter: content"}
		"edit_file":
			if not _m19.has("path") or _m19.get("path", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: path"}
			if not _m19.has("old_string") or _m19.get("old_string", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: old_string"}
			if not _m19.has("new_string"):
				return {"valid": false, "error": "Missing required parameter: new_string"}
		"delete_file":
			if not _m19.has("path") or _m19.get("path", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: path"}
		_:
			return {"valid": false, "error": "Unknown tool: " + _s46}
	return {"valid": true}
