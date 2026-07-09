@tool
class_name _v17
extends RefCounted
const _v31: Array[String] = [
	"res://.godot/",
	"res://.import/",
	"res://project.godot",
	"res://addons/gdsense/",
	"res://.git/"
]
const _x8: int = 50000
const _z70: int = 500
const _o72: int = 200
const _o28: Array[String] = [
	"create_file",
	"edit_file",
	"delete_file"
]
var _r15: EditorInterface
func initialize(_k71: EditorInterface) -> void:
	_r15 = _k71
func _d94(_u36: String) -> bool:
	return _u36 in _o28
func _m62(_u36: String, _f44: Dictionary) -> Dictionary:
	match _u36:
		"read_file":
			return _k23(_f44.get("path", ""))
		"list_files":
			return _v80(_f44.get("directory", "res://"), _f44.get("recursive", false))
		"glob":
			return _t38(_f44.get("pattern", ""), _f44.get("path", "res://"))
		"grep":
			return _t59(_f44.get("pattern", ""), _f44.get("path", "res://"), _f44.get("glob", ""), _f44.get("context_lines", 2))
		"get_project_info":
			return _b39()
		"run_project":
			return _c97()
		"stop_project":
			return _b67()
		"create_file":
			return _c30(_f44.get("path", ""), _f44.get("content", ""))
		"edit_file":
			return _v23(_f44.get("path", ""), _f44.get("old_string", ""), _f44.get("new_string", ""), _f44.get("replace_all", false))
		"delete_file":
			return _k84(_f44.get("path", ""))
		_:
			return {"success": false, "error": "Unknown tool: " + _u36}
func _h99(path: String) -> bool:
	if not path.begins_with("res://"):
		return false
	if ".." in path:
		return false
	var normalized = path.simplify_path()
	for _p69 in _v31:
		var _x65 = _p69.simplify_path()
		if normalized.begins_with(_x65) or normalized == _x65.trim_suffix("/"):
			return false
	return true
func _h20(path: String) -> String:
	if not path.begins_with("res://"):
		return "Path must start with res://"
	if ".." in path:
		return "Path traversal (..) is not allowed"
	var normalized = path.simplify_path()
	for _p69 in _v31:
		var _x65 = _p69.simplify_path()
		if normalized.begins_with(_x65) or normalized == _x65.trim_suffix("/"):
			return "Path is protected: " + _p69
	return "Path validation failed"
func _k23(path: String) -> Dictionary:
	if path.is_empty():
		return {"success": false, "error": "Path is required"}
	if not _h99(path):
		return {"success": false, "error": _h20(path)}
	if not FileAccess.file_exists(path):
		return {"success": false, "error": "File not found: " + path}
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		var _u31 = FileAccess.get_open_error()
		return {"success": false, "error": "Cannot open file: " + path + " (error: " + str(_u31) + ")"}
	var _q43 = file.get_length()
	var content = file.get_as_text()
	file.close()
	var _j72 = false
	if content.length() > _x8:
		content = content.substr(0, _x8) + "\n... [truncated, file too large]"
		_j72 = true
	return {
		"success": true,
		"content": content,
		"path": path,
		"size": _q43,
		"truncated": _j72
	}
func _v80(_s63: String, _a98: bool) -> Dictionary:
	if _s63.is_empty():
		_s63 = "res://"
	if not _h99(_s63):
		return {"success": false, "error": _h20(_s63)}
	var _b57 = DirAccess.open(_s63)
	if not _b57:
		var _u31 = DirAccess.get_open_error()
		return {"success": false, "error": "Cannot open directory: " + _s63 + " (error: " + str(_u31) + ")"}
	var _q72: Array[String] = []
	var _d80: Array[String] = []
	_b57.list_dir_begin()
	var _g95 = _b57.get_next()
	while _g95 != "":
		if _g95 != "." and _g95 != "..":
			var full_path = _s63.path_join(_g95)
			if _h99(full_path):
				if _b57.current_is_dir():
					_d80.append(_g95 + "/")
					if _a98:
						var _j95 = _v80(full_path, true)
						if _j95.get("success", false):
							var _v24 = _j95.get("files", [])
							for f in _v24:
								_q72.append(_g95 + "/" + f)
				else:
					_q72.append(_g95)
		_g95 = _b57.get_next()
	_b57.list_dir_end()
	return {
		"success": true,
		"directory": _s63,
		"files": _q72,
		"directories": _d80,
		"total_files": _q72.size(),
		"total_directories": _d80.size()
	}
func _t38(_j73: String, base_path: String) -> Dictionary:
	if _j73.is_empty():
		return {"success": false, "error": "Pattern is required"}
	if base_path.is_empty():
		base_path = "res://"
	if not _h99(base_path):
		return {"success": false, "error": _h20(base_path)}
	var _w34: Array[String] = []
	var _q16: int = 0
	var segments = _j73.split("/")
	_u73(base_path, segments, 0, _w34, _q16)
	var _j72 = false
	if _w34.size() > _z70:
		_w34.resize(_z70)
		_j72 = true
	return {
		"success": true,
		"matches": _w34,
		"total_found": _w34.size(),
		"truncated": _j72,
		"pattern": _j73,
		"base_path": base_path
	}
func _u73(current_path: String, segments: Array, _c62: int, _w34: Array[String], _q16: int) -> void:
	if _w34.size() >= _z70:
		return
	if _c62 >= segments.size():
		return
	var _d82 = segments[_c62]
	var _a51 = (_c62 == segments.size() - 1)
	if _d82 == "**":
		if _c62 + 1 < segments.size():
			_u73(current_path, segments, _c62 + 1, _w34, _q16)
		var _b57 = DirAccess.open(current_path)
		if _b57:
			_b57.list_dir_begin()
			var _d48 = _b57.get_next()
			while _d48 != "" and _w34.size() < _z70:
				if _d48 != "." and _d48 != "..":
					var full_path = current_path.path_join(_d48)
					if _h99(full_path) and _b57.current_is_dir():
						_u73(full_path, segments, _c62, _w34, _q16 + 1)
				_d48 = _b57.get_next()
			_b57.list_dir_end()
		return
	var _b57 = DirAccess.open(current_path)
	if not _b57:
		return
	_b57.list_dir_begin()
	var _d48 = _b57.get_next()
	while _d48 != "" and _w34.size() < _z70:
		if _d48 != "." and _d48 != "..":
			var full_path = current_path.path_join(_d48)
			if _h99(full_path):
				var _m76 = _b57.current_is_dir()
				if _x59(_d48, _d82):
					if _a51:
						if not _m76 or _d82.ends_with("/"):
							_w34.append(full_path)
						elif _m76 and not _d82.ends_with("/"):
							_w34.append(full_path)
					elif _m76:
						_u73(full_path, segments, _c62 + 1, _w34, _q16 + 1)
		_d48 = _b57.get_next()
	_b57.list_dir_end()
func _x59(name: String, _j73: String) -> bool:
	if _j73 == "*":
		return true
	if _j73 == name:
		return true
	var _c77 = "^"
	var i = 0
	while i < _j73.length():
		var c = _j73[i]
		match c:
			"*":
				_c77 += ".*"
			"?":
				_c77 += "."
			".":
				_c77 += "\\."
			"[":
				var _a75 = _j73.find("]", i)
				if _a75 > i:
					_c77 += _j73.substr(i, _a75 - i + 1)
					i = _a75
				else:
					_c77 += "\\["
			_:
				if c in "\\^$|+(){}":
					_c77 += "\\" + c
				else:
					_c77 += c
		i += 1
	_c77 += "$"
	var _x62 = RegEx.new()
	if _x62.compile(_c77) != OK:
		return name == _j73
	return _x62.search(name) != null
func _t59(_j73: String, base_path: String, _i73: String, _h41: int) -> Dictionary:
	if _j73.is_empty():
		return {"success": false, "error": "Pattern is required"}
	if base_path.is_empty():
		base_path = "res://"
	if not _h99(base_path):
		return {"success": false, "error": _h20(base_path)}
	var _x62 = RegEx.new()
	var _m38 = _x62.compile(_j73)
	if _m38 != OK:
		return {"success": false, "error": "Invalid regex pattern: " + _j73}
	var _v30: Array[String] = []
	if _i73.is_empty():
		_h27(base_path, _v30)
	else:
		var _w75 = _t38(_i73, base_path)
		if not _w75.get("success", false):
			return _w75
		for f in _w75.get("matches", []):
			_v30.append(f)
	var _w34: Array[Dictionary] = []
	var _z42: int = 0
	var _p37: int = 0
	for file_path in _v30:
		if _w34.size() >= _o72:
			break
		if _u100(file_path):
			continue
		if not FileAccess.file_exists(file_path):
			continue
		var file = FileAccess.open(file_path, FileAccess.READ)
		if not file:
			continue
		var content = file.get_as_text()
		file.close()
		_z42 += 1
		var _p91 = content.split("\n")
		var _z92 = false
		for _e53 in range(_p91.size()):
			if _w34.size() >= _o72:
				break
			var line = _p91[_e53]
			var _h83 = _x62.search(line)
			if _h83:
				_z92 = true
				var _e69: Array[String] = []
				var _e8: Array[String] = []
				for i in range(max(0, _e53 - _h41), _e53):
					_e69.append(_p91[i])
				for i in range(_e53 + 1, min(_p91.size(), _e53 + _h41 + 1)):
					_e8.append(_p91[i])
				_w34.append({
					"file": file_path,
					"line_number": _e53 + 1,
					"line": line,
					"before_context": _e69,
					"after_context": _e8,
					"match_start": _h83.get_start(),
					"match_end": _h83.get_end()
				})
		if _z92:
			_p37 += 1
	var _j72 = _w34.size() >= _o72
	return {
		"success": true,
		"matches": _w34,
		"total_matches": _w34.size(),
		"files_searched": _z42,
		"files_with_matches": _p37,
		"truncated": _j72,
		"pattern": _j73
	}
func _h27(_s63: String, _q72: Array[String]) -> void:
	var _b57 = DirAccess.open(_s63)
	if not _b57:
		return
	_b57.list_dir_begin()
	var _d48 = _b57.get_next()
	while _d48 != "":
		if _d48 != "." and _d48 != "..":
			var full_path = _s63.path_join(_d48)
			if _h99(full_path):
				if _b57.current_is_dir():
					_h27(full_path, _q72)
				else:
					_q72.append(full_path)
		_d48 = _b57.get_next()
	_b57.list_dir_end()
func _u100(path: String) -> bool:
	var _i98 = [
		".png", ".jpg", ".jpeg", ".gif", ".bmp", ".webp", ".svg",
		".ogg", ".wav", ".mp3", ".flac",
		".ttf", ".otf", ".woff", ".woff2",
		".zip", ".tar", ".gz", ".7z", ".rar",
		".exe", ".dll", ".so", ".dylib",
		".res", ".import", ".scn", ".bin",
		".glb", ".gltf", ".fbx", ".obj", ".dae"
	]
	var _u60 = path.get_extension().to_lower()
	if _u60.is_empty():
		return false
	return ("." + _u60) in _i98
func _b39() -> Dictionary:
	var _f90 = Engine.get_version_info()
	var _q5 = "%d.%d.%d" % [_f90.get("major", 0), _f90.get("minor", 0), _f90.get("patch", 0)]
	var _s83 = {
		"success": true,
		"godot_version": _q5,
		"godot_version_full": _f90.get("string", _q5),
		"project_name": ProjectSettings.get_setting("application/config/name", "Unknown"),
		"project_path": ProjectSettings.globalize_path("res://")
	}
	var _k99 = ProjectSettings.get_setting("application/run/main_scene", "")
	if not _k99.is_empty():
		_s83["main_scene"] = _k99
	var description = ProjectSettings.get_setting("application/config/description", "")
	if not description.is_empty():
		_s83["description"] = description
	var _y56: Array[String] = []
	for _u93 in ProjectSettings.get_property_list():
		var name = _u93.get("name", "")
		if name.begins_with("autoload/"):
			_y56.append(name.replace("autoload/", ""))
	if not _y56.is_empty():
		_s83["autoloads"] = _y56
	return _s83
func _c97() -> Dictionary:
	if _r15 == null:
		return {"success": false, "error": "Editor interface not available"}
	if _r15.is_playing_scene():
		return {"success": false, "error": "Project is already running"}
	_r15.play_main_scene()
	return {"success": true, "message": "Project started"}
func _b67() -> Dictionary:
	if _r15 == null:
		return {"success": false, "error": "Editor interface not available"}
	if not _r15.is_playing_scene():
		return {"success": false, "error": "Project is not running"}
	_r15.stop_playing_scene()
	return {"success": true, "message": "Project stopped"}
func _c30(path: String, content: String) -> Dictionary:
	if path.is_empty():
		return {"success": false, "error": "Path is required"}
	if not _h99(path):
		return {"success": false, "error": _h20(path)}
	if FileAccess.file_exists(path):
		return {"success": false, "error": "File already exists: " + path + ". Use edit_file to modify existing files."}
	var _f55 = path.get_base_dir()
	if not _f55.is_empty() and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_f55)):
		var _b20 = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_f55))
		if _b20 != OK:
			return {"success": false, "error": "Cannot create directory: " + _f55 + " (error: " + str(_b20) + ")"}
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		var _u31 = FileAccess.get_open_error()
		return {"success": false, "error": "Cannot create file: " + path + " (error: " + str(_u31) + ")"}
	file.store_string(content)
	file.close()
	if _r15:
		_r15.get_resource_filesystem().scan()
	var _e21 = {
		"success": true,
		"message": "File created: " + path,
		"path": path,
		"size": content.length()
	}
	var _q62 = _l77(path)
	if not _q62["valid"]:
		_e21["warning"] = _q62["error"]
		_e21["message"] += " (WARNING: " + _q62["error"] + ")"
	return _e21
func _v23(path: String, _r65: String, _k92: String, _b46: bool) -> Dictionary:
	if path.is_empty():
		return {"success": false, "error": "Path is required"}
	if _r65.is_empty():
		return {"success": false, "error": "old_string is required"}
	if not _h99(path):
		return {"success": false, "error": _h20(path)}
	if not FileAccess.file_exists(path):
		return {"success": false, "error": "File not found: " + path + ". Use create_file to create new files."}
	var _f68 = FileAccess.open(path, FileAccess.READ)
	if not _f68:
		var _u31 = FileAccess.get_open_error()
		return {"success": false, "error": "Cannot read file: " + path + " (error: " + str(_u31) + ")"}
	var _z48 = _f68.get_as_text()
	_f68.close()
	var _m79 = _z48.find(_r65)
	if _m79 == -1:
		return {"success": false, "error": "old_string not found in file. The exact text must exist in the file."}
	var _t64 = _z48.count(_r65)
	if _t64 > 1 and not _b46:
		return {
			"success": false,
			"error": "Found " + str(_t64) + " occurrences of old_string. Set replace_all=true to replace all, or provide more context to make the string unique."
		}
	var _j65: String
	var _h17: int
	if _b46:
		_j65 = _z48.replace(_r65, _k92)
		_h17 = _t64
	else:
		_j65 = _z48.substr(0, _m79) + _k92 + _z48.substr(_m79 + _r65.length())
		_h17 = 1
	var _l14 = path + ".agent_backup"
	var _o38 = FileAccess.open(_l14, FileAccess.WRITE)
	if _o38:
		_o38.store_string(_z48)
		_o38.close()
	else:
		pass
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		var _u31 = FileAccess.get_open_error()
		return {"success": false, "error": "Cannot write file: " + path + " (error: " + str(_u31) + ")"}
	file.store_string(_j65)
	file.close()
	if _r15:
		_r15.get_resource_filesystem().scan()
	var _n81 = _g15(_r65, _k92)
	var _e21 = {
		"success": true,
		"message": "File modified: " + path,
		"path": path,
		"replacements_made": _h17,
		"diff_preview": _n81,
		"original_size": _z48.length(),
		"new_size": _j65.length()
	}
	if FileAccess.file_exists(_l14):
		_e21["backup"] = _l14
	var _q62 = _l77(path)
	if not _q62["valid"]:
		_e21["warning"] = _q62["error"]
		_e21["message"] += " (WARNING: " + _q62["error"] + ")"
	return _e21
func _g15(_r65: String, _k92: String) -> String:
	var _t53 = _r65.split("\n")
	var _l63 = _k92.split("\n")
	var _k74 = ""
	for line in _t53:
		_k74 += "- " + line + "\n"
	for line in _l63:
		_k74 += "+ " + line + "\n"
	return _k74.strip_edges()
func _l77(path: String) -> Dictionary:
	if not path.ends_with(".tscn") and not path.ends_with(".tres"):
		return {"valid": true}
	var _v84 = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if _v84 == null:
		var _s61 = ""
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			_s61 = file.get_as_text()
			file.close()
		var _p91 = _s61.split("\n")
		var _k75 = ""
		for i in range(_p91.size()):
			_k75 += str(i + 1) + ": " + _p91[i] + "\n"
		return {
			"valid": false,
			"error": "PARSE ERROR in " + path.get_file() + ". The file has invalid format and cannot be loaded by Godot. Review the content below and fix the syntax:\n\n" + _k75
		}
	return {"valid": true}
func _k84(path: String) -> Dictionary:
	if path.is_empty():
		return {"success": false, "error": "Path is required"}
	if not _h99(path):
		return {"success": false, "error": _h20(path)}
	if not FileAccess.file_exists(path):
		return {"success": false, "error": "File not found: " + path}
	var _w26 = ProjectSettings.globalize_path(path)
	var _b20 = DirAccess.remove_absolute(_w26)
	if _b20 != OK:
		return {"success": false, "error": "Cannot delete file: " + path + " (error: " + str(_b20) + ")"}
	if _r15:
		_r15.get_resource_filesystem().scan()
	return {
		"success": true,
		"message": "File deleted: " + path,
		"path": path
	}
func _a32() -> Array[Dictionary]:
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
func _f25(_u36: String, _f44: Dictionary) -> Dictionary:
	match _u36:
		"read_file":
			if not _f44.has("path") or _f44.get("path", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: path"}
		"list_files":
			pass  
		"glob":
			if not _f44.has("pattern") or _f44.get("pattern", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: pattern"}
		"grep":
			if not _f44.has("pattern") or _f44.get("pattern", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: pattern"}
		"get_project_info":
			pass  
		"run_project":
			pass  
		"stop_project":
			pass  
		"create_file":
			if not _f44.has("path") or _f44.get("path", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: path"}
			if not _f44.has("content"):
				return {"valid": false, "error": "Missing required parameter: content"}
		"edit_file":
			if not _f44.has("path") or _f44.get("path", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: path"}
			if not _f44.has("old_string") or _f44.get("old_string", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: old_string"}
			if not _f44.has("new_string"):
				return {"valid": false, "error": "Missing required parameter: new_string"}
		"delete_file":
			if not _f44.has("path") or _f44.get("path", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: path"}
		_:
			return {"valid": false, "error": "Unknown tool: " + _u36}
	return {"valid": true}
