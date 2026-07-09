@tool
class_name _z12
extends RefCounted
const _x84: Array[String] = [
	"res://.godot/",
	"res://.import/",
	"res://project.godot",
	"res://addons/gdsense/",
	"res://.git/"
]
const _q18: int = 50000
const _g11: int = 500
const _x19: int = 200
const _u17: Array[String] = [
	"create_file",
	"edit_file",
	"delete_file"
]
var _f21: EditorInterface
func initialize(_i13: EditorInterface) -> void:
	_f21 = _i13
func _o53(_h10: String) -> bool:
	return _h10 in _u17
func _c48(_h10: String, _m4: Dictionary) -> Dictionary:
	match _h10:
		"read_file":
			return _m40(_m4.get("path", ""))
		"list_files":
			return _x100(_m4.get("directory", "res://"), _m4.get("recursive", false))
		"glob":
			return _r10(_m4.get("pattern", ""), _m4.get("path", "res://"))
		"grep":
			return _l63(_m4.get("pattern", ""), _m4.get("path", "res://"), _m4.get("glob", ""), _m4.get("context_lines", 2))
		"get_project_info":
			return _u4()
		"run_project":
			return _a27()
		"stop_project":
			return _x66()
		"create_file":
			return _w49(_m4.get("path", ""), _m4.get("content", ""))
		"edit_file":
			return _u78(_m4.get("path", ""), _m4.get("old_string", ""), _m4.get("new_string", ""), _m4.get("replace_all", false))
		"delete_file":
			return _y44(_m4.get("path", ""))
		_:
			return {"success": false, "error": "Unknown tool: " + _h10}
func _w47(path: String) -> bool:
	if not path.begins_with("res://"):
		return false
	if ".." in path:
		return false
	var normalized = path.simplify_path()
	for _e8 in _x84:
		var _p71 = _e8.simplify_path()
		if normalized.begins_with(_p71) or normalized == _p71.trim_suffix("/"):
			return false
	return true
func _p95(path: String) -> String:
	if not path.begins_with("res://"):
		return "Path must start with res://"
	if ".." in path:
		return "Path traversal (..) is not allowed"
	var normalized = path.simplify_path()
	for _e8 in _x84:
		var _p71 = _e8.simplify_path()
		if normalized.begins_with(_p71) or normalized == _p71.trim_suffix("/"):
			return "Path is protected: " + _e8
	return "Path validation failed"
func _m40(path: String) -> Dictionary:
	if path.is_empty():
		return {"success": false, "error": "Path is required"}
	if not _w47(path):
		return {"success": false, "error": _p95(path)}
	if not FileAccess.file_exists(path):
		return {"success": false, "error": "File not found: " + path}
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		var _m16 = FileAccess.get_open_error()
		return {"success": false, "error": "Cannot open file: " + path + " (error: " + str(_m16) + ")"}
	var _l43 = file.get_length()
	var content = file.get_as_text()
	file.close()
	var _z37 = false
	if content.length() > _q18:
		content = content.substr(0, _q18) + "\n... [truncated, file too large]"
		_z37 = true
	return {
		"success": true,
		"content": content,
		"path": path,
		"size": _l43,
		"truncated": _z37
	}
func _x100(_d87: String, _p27: bool) -> Dictionary:
	if _d87.is_empty():
		_d87 = "res://"
	if not _w47(_d87):
		return {"success": false, "error": _p95(_d87)}
	var _d5 = DirAccess.open(_d87)
	if not _d5:
		var _m16 = DirAccess.get_open_error()
		return {"success": false, "error": "Cannot open directory: " + _d87 + " (error: " + str(_m16) + ")"}
	var _s82: Array[String] = []
	var _a41: Array[String] = []
	_d5.list_dir_begin()
	var _y38 = _d5.get_next()
	while _y38 != "":
		if _y38 != "." and _y38 != "..":
			var full_path = _d87.path_join(_y38)
			if _w47(full_path):
				if _d5.current_is_dir():
					_a41.append(_y38 + "/")
					if _p27:
						var _w73 = _x100(full_path, true)
						if _w73.get("success", false):
							var _m36 = _w73.get("files", [])
							for f in _m36:
								_s82.append(_y38 + "/" + f)
				else:
					_s82.append(_y38)
		_y38 = _d5.get_next()
	_d5.list_dir_end()
	return {
		"success": true,
		"directory": _d87,
		"files": _s82,
		"directories": _a41,
		"total_files": _s82.size(),
		"total_directories": _a41.size()
	}
func _r10(_s76: String, base_path: String) -> Dictionary:
	if _s76.is_empty():
		return {"success": false, "error": "Pattern is required"}
	if base_path.is_empty():
		base_path = "res://"
	if not _w47(base_path):
		return {"success": false, "error": _p95(base_path)}
	var _q83: Array[String] = []
	var _g95: int = 0
	var segments = _s76.split("/")
	_k38(base_path, segments, 0, _q83, _g95)
	var _z37 = false
	if _q83.size() > _g11:
		_q83.resize(_g11)
		_z37 = true
	return {
		"success": true,
		"matches": _q83,
		"total_found": _q83.size(),
		"truncated": _z37,
		"pattern": _s76,
		"base_path": base_path
	}
func _k38(current_path: String, segments: Array, _c45: int, _q83: Array[String], _g95: int) -> void:
	if _q83.size() >= _g11:
		return
	if _c45 >= segments.size():
		return
	var _p33 = segments[_c45]
	var _k14 = (_c45 == segments.size() - 1)
	if _p33 == "**":
		if _c45 + 1 < segments.size():
			_k38(current_path, segments, _c45 + 1, _q83, _g95)
		var _d5 = DirAccess.open(current_path)
		if _d5:
			_d5.list_dir_begin()
			var _s38 = _d5.get_next()
			while _s38 != "" and _q83.size() < _g11:
				if _s38 != "." and _s38 != "..":
					var full_path = current_path.path_join(_s38)
					if _w47(full_path) and _d5.current_is_dir():
						_k38(full_path, segments, _c45, _q83, _g95 + 1)
				_s38 = _d5.get_next()
			_d5.list_dir_end()
		return
	var _d5 = DirAccess.open(current_path)
	if not _d5:
		return
	_d5.list_dir_begin()
	var _s38 = _d5.get_next()
	while _s38 != "" and _q83.size() < _g11:
		if _s38 != "." and _s38 != "..":
			var full_path = current_path.path_join(_s38)
			if _w47(full_path):
				var _d43 = _d5.current_is_dir()
				if _v37(_s38, _p33):
					if _k14:
						if not _d43 or _p33.ends_with("/"):
							_q83.append(full_path)
						elif _d43 and not _p33.ends_with("/"):
							_q83.append(full_path)
					elif _d43:
						_k38(full_path, segments, _c45 + 1, _q83, _g95 + 1)
		_s38 = _d5.get_next()
	_d5.list_dir_end()
func _v37(name: String, _s76: String) -> bool:
	if _s76 == "*":
		return true
	if _s76 == name:
		return true
	var _v52 = "^"
	var i = 0
	while i < _s76.length():
		var c = _s76[i]
		match c:
			"*":
				_v52 += ".*"
			"?":
				_v52 += "."
			".":
				_v52 += "\\."
			"[":
				var _f66 = _s76.find("]", i)
				if _f66 > i:
					_v52 += _s76.substr(i, _f66 - i + 1)
					i = _f66
				else:
					_v52 += "\\["
			_:
				if c in "\\^$|+(){}":
					_v52 += "\\" + c
				else:
					_v52 += c
		i += 1
	_v52 += "$"
	var _r9 = RegEx.new()
	if _r9.compile(_v52) != OK:
		return name == _s76
	return _r9.search(name) != null
func _l63(_s76: String, base_path: String, _a64: String, _w92: int) -> Dictionary:
	if _s76.is_empty():
		return {"success": false, "error": "Pattern is required"}
	if base_path.is_empty():
		base_path = "res://"
	if not _w47(base_path):
		return {"success": false, "error": _p95(base_path)}
	var _r9 = RegEx.new()
	var _n50 = _r9.compile(_s76)
	if _n50 != OK:
		return {"success": false, "error": "Invalid regex pattern: " + _s76}
	var _w83: Array[String] = []
	if _a64.is_empty():
		_q96(base_path, _w83)
	else:
		var _b32 = _r10(_a64, base_path)
		if not _b32.get("success", false):
			return _b32
		for f in _b32.get("matches", []):
			_w83.append(f)
	var _q83: Array[Dictionary] = []
	var _s11: int = 0
	var _q67: int = 0
	for file_path in _w83:
		if _q83.size() >= _x19:
			break
		if _m8(file_path):
			continue
		if not FileAccess.file_exists(file_path):
			continue
		var file = FileAccess.open(file_path, FileAccess.READ)
		if not file:
			continue
		var content = file.get_as_text()
		file.close()
		_s11 += 1
		var _t70 = content.split("\n")
		var _i95 = false
		for _t84 in range(_t70.size()):
			if _q83.size() >= _x19:
				break
			var line = _t70[_t84]
			var _t62 = _r9.search(line)
			if _t62:
				_i95 = true
				var _r85: Array[String] = []
				var _l60: Array[String] = []
				for i in range(max(0, _t84 - _w92), _t84):
					_r85.append(_t70[i])
				for i in range(_t84 + 1, min(_t70.size(), _t84 + _w92 + 1)):
					_l60.append(_t70[i])
				_q83.append({
					"file": file_path,
					"line_number": _t84 + 1,
					"line": line,
					"before_context": _r85,
					"after_context": _l60,
					"match_start": _t62.get_start(),
					"match_end": _t62.get_end()
				})
		if _i95:
			_q67 += 1
	var _z37 = _q83.size() >= _x19
	return {
		"success": true,
		"matches": _q83,
		"total_matches": _q83.size(),
		"files_searched": _s11,
		"files_with_matches": _q67,
		"truncated": _z37,
		"pattern": _s76
	}
func _q96(_d87: String, _s82: Array[String]) -> void:
	var _d5 = DirAccess.open(_d87)
	if not _d5:
		return
	_d5.list_dir_begin()
	var _s38 = _d5.get_next()
	while _s38 != "":
		if _s38 != "." and _s38 != "..":
			var full_path = _d87.path_join(_s38)
			if _w47(full_path):
				if _d5.current_is_dir():
					_q96(full_path, _s82)
				else:
					_s82.append(full_path)
		_s38 = _d5.get_next()
	_d5.list_dir_end()
func _m8(path: String) -> bool:
	var _m81 = [
		".png", ".jpg", ".jpeg", ".gif", ".bmp", ".webp", ".svg",
		".ogg", ".wav", ".mp3", ".flac",
		".ttf", ".otf", ".woff", ".woff2",
		".zip", ".tar", ".gz", ".7z", ".rar",
		".exe", ".dll", ".so", ".dylib",
		".res", ".import", ".scn", ".bin",
		".glb", ".gltf", ".fbx", ".obj", ".dae"
	]
	var _a76 = path.get_extension().to_lower()
	if _a76.is_empty():
		return false
	return ("." + _a76) in _m81
func _u4() -> Dictionary:
	var _w99 = Engine.get_version_info()
	var _k16 = "%d.%d.%d" % [_w99.get("major", 0), _w99.get("minor", 0), _w99.get("patch", 0)]
	var _k73 = {
		"success": true,
		"godot_version": _k16,
		"godot_version_full": _w99.get("string", _k16),
		"project_name": ProjectSettings.get_setting("application/config/name", "Unknown"),
		"project_path": ProjectSettings.globalize_path("res://")
	}
	var _q24 = ProjectSettings.get_setting("application/run/main_scene", "")
	if not _q24.is_empty():
		_k73["main_scene"] = _q24
	var description = ProjectSettings.get_setting("application/config/description", "")
	if not description.is_empty():
		_k73["description"] = description
	var _s6: Array[String] = []
	for _l64 in ProjectSettings.get_property_list():
		var name = _l64.get("name", "")
		if name.begins_with("autoload/"):
			_s6.append(name.replace("autoload/", ""))
	if not _s6.is_empty():
		_k73["autoloads"] = _s6
	return _k73
func _a27() -> Dictionary:
	if _f21 == null:
		return {"success": false, "error": "Editor interface not available"}
	if _f21.is_playing_scene():
		return {"success": false, "error": "Project is already running"}
	_f21.play_main_scene()
	return {"success": true, "message": "Project started"}
func _x66() -> Dictionary:
	if _f21 == null:
		return {"success": false, "error": "Editor interface not available"}
	if not _f21.is_playing_scene():
		return {"success": false, "error": "Project is not running"}
	_f21.stop_playing_scene()
	return {"success": true, "message": "Project stopped"}
func _w49(path: String, content: String) -> Dictionary:
	if path.is_empty():
		return {"success": false, "error": "Path is required"}
	if not _w47(path):
		return {"success": false, "error": _p95(path)}
	if FileAccess.file_exists(path):
		return {"success": false, "error": "File already exists: " + path + ". Use edit_file to modify existing files."}
	var _n38 = path.get_base_dir()
	if not _n38.is_empty() and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_n38)):
		var _z57 = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_n38))
		if _z57 != OK:
			return {"success": false, "error": "Cannot create directory: " + _n38 + " (error: " + str(_z57) + ")"}
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		var _m16 = FileAccess.get_open_error()
		return {"success": false, "error": "Cannot create file: " + path + " (error: " + str(_m16) + ")"}
	file.store_string(content)
	file.close()
	if _f21:
		_f21.get_resource_filesystem().scan()
	var _s61 = {
		"success": true,
		"message": "File created: " + path,
		"path": path,
		"size": content.length()
	}
	var _o92 = _v99(path)
	if not _o92["valid"]:
		_s61["warning"] = _o92["error"]
		_s61["message"] += " (WARNING: " + _o92["error"] + ")"
	return _s61
func _u78(path: String, _e60: String, _p94: String, _b55: bool) -> Dictionary:
	if path.is_empty():
		return {"success": false, "error": "Path is required"}
	if _e60.is_empty():
		return {"success": false, "error": "old_string is required"}
	if not _w47(path):
		return {"success": false, "error": _p95(path)}
	if not FileAccess.file_exists(path):
		return {"success": false, "error": "File not found: " + path + ". Use create_file to create new files."}
	var _b52 = FileAccess.open(path, FileAccess.READ)
	if not _b52:
		var _m16 = FileAccess.get_open_error()
		return {"success": false, "error": "Cannot read file: " + path + " (error: " + str(_m16) + ")"}
	var _p55 = _b52.get_as_text()
	_b52.close()
	var _n53 = _p55.find(_e60)
	if _n53 == -1:
		return {"success": false, "error": "old_string not found in file. The exact text must exist in the file."}
	var _k85 = _p55.count(_e60)
	if _k85 > 1 and not _b55:
		return {
			"success": false,
			"error": "Found " + str(_k85) + " occurrences of old_string. Set replace_all=true to replace all, or provide more context to make the string unique."
		}
	var _p100: String
	var _o97: int
	if _b55:
		_p100 = _p55.replace(_e60, _p94)
		_o97 = _k85
	else:
		_p100 = _p55.substr(0, _n53) + _p94 + _p55.substr(_n53 + _e60.length())
		_o97 = 1
	var _r65 = path + ".agent_backup"
	var _r66 = FileAccess.open(_r65, FileAccess.WRITE)
	if _r66:
		_r66.store_string(_p55)
		_r66.close()
	else:
		pass
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		var _m16 = FileAccess.get_open_error()
		return {"success": false, "error": "Cannot write file: " + path + " (error: " + str(_m16) + ")"}
	file.store_string(_p100)
	file.close()
	if _f21:
		_f21.get_resource_filesystem().scan()
	var _w65 = _l66(_e60, _p94)
	var _s61 = {
		"success": true,
		"message": "File modified: " + path,
		"path": path,
		"replacements_made": _o97,
		"diff_preview": _w65,
		"original_size": _p55.length(),
		"new_size": _p100.length()
	}
	if FileAccess.file_exists(_r65):
		_s61["backup"] = _r65
	var _o92 = _v99(path)
	if not _o92["valid"]:
		_s61["warning"] = _o92["error"]
		_s61["message"] += " (WARNING: " + _o92["error"] + ")"
	return _s61
func _l66(_e60: String, _p94: String) -> String:
	var _x44 = _e60.split("\n")
	var _b65 = _p94.split("\n")
	var _f56 = ""
	for line in _x44:
		_f56 += "- " + line + "\n"
	for line in _b65:
		_f56 += "+ " + line + "\n"
	return _f56.strip_edges()
func _v99(path: String) -> Dictionary:
	if not path.ends_with(".tscn") and not path.ends_with(".tres"):
		return {"valid": true}
	var _q19 = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if _q19 == null:
		var _e23 = ""
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			_e23 = file.get_as_text()
			file.close()
		var _t70 = _e23.split("\n")
		var _u14 = ""
		for i in range(_t70.size()):
			_u14 += str(i + 1) + ": " + _t70[i] + "\n"
		return {
			"valid": false,
			"error": "PARSE ERROR in " + path.get_file() + ". The file has invalid format and cannot be loaded by Godot. Review the content below and fix the syntax:\n\n" + _u14
		}
	return {"valid": true}
func _y44(path: String) -> Dictionary:
	if path.is_empty():
		return {"success": false, "error": "Path is required"}
	if not _w47(path):
		return {"success": false, "error": _p95(path)}
	if not FileAccess.file_exists(path):
		return {"success": false, "error": "File not found: " + path}
	var _n40 = ProjectSettings.globalize_path(path)
	var _z57 = DirAccess.remove_absolute(_n40)
	if _z57 != OK:
		return {"success": false, "error": "Cannot delete file: " + path + " (error: " + str(_z57) + ")"}
	if _f21:
		_f21.get_resource_filesystem().scan()
	return {
		"success": true,
		"message": "File deleted: " + path,
		"path": path
	}
func _y74() -> Array[Dictionary]:
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
func _h77(_h10: String, _m4: Dictionary) -> Dictionary:
	match _h10:
		"read_file":
			if not _m4.has("path") or _m4.get("path", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: path"}
		"list_files":
			pass  
		"glob":
			if not _m4.has("pattern") or _m4.get("pattern", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: pattern"}
		"grep":
			if not _m4.has("pattern") or _m4.get("pattern", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: pattern"}
		"get_project_info":
			pass  
		"run_project":
			pass  
		"stop_project":
			pass  
		"create_file":
			if not _m4.has("path") or _m4.get("path", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: path"}
			if not _m4.has("content"):
				return {"valid": false, "error": "Missing required parameter: content"}
		"edit_file":
			if not _m4.has("path") or _m4.get("path", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: path"}
			if not _m4.has("old_string") or _m4.get("old_string", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: old_string"}
			if not _m4.has("new_string"):
				return {"valid": false, "error": "Missing required parameter: new_string"}
		"delete_file":
			if not _m4.has("path") or _m4.get("path", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: path"}
		_:
			return {"valid": false, "error": "Unknown tool: " + _h10}
	return {"valid": true}
