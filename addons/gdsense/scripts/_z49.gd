@tool
class_name _h17
extends RefCounted

const _o83: Array[String] = [
	"res://.godot/",
	"res://.import/",
	"res://project.godot",
	"res://addons/gdsense/",
	"res://.git/"
]

const _t59: int = 50000

const _p2: int = 500

const _x66: int = 200

const _r57: Array[String] = [
	"create_file",
	"edit_file",
	"delete_file"
]

var _z76: EditorInterface

func initialize(_i86: EditorInterface) -> void:
	_z76 = _i86

func _l73(_w25: String) -> bool:
	return _w25 in _r57

func _p65(_w25: String, _n73: Dictionary) -> Dictionary:
	match _w25:
		"read_file":
			return _r81(_n73.get("path", ""))
		"list_files":
			return _x38(_n73.get("directory", "res://"), _n73.get("recursive", false))
		"glob":
			return _e49(_n73.get("pattern", ""), _n73.get("path", "res://"))
		"grep":
			return _g62(_n73.get("pattern", ""), _n73.get("path", "res://"), _n73.get("glob", ""), _n73.get("context_lines", 2))
		"get_project_info":
			return _g34()
		"run_project":
			return _r78()
		"stop_project":
			return _b83()
		"create_file":
			return _z33(_n73.get("path", ""), _n73.get("content", ""))
		"edit_file":
			return _h12(_n73.get("path", ""), _n73.get("old_string", ""), _n73.get("new_string", ""), _n73.get("replace_all", false))
		"delete_file":
			return _a63(_n73.get("path", ""))
		_:
			return {"success": false, "error": "Unknown tool: " + _w25}

func _c9(path: String) -> bool:
	if not path.begins_with("res://"):
		return false

	if ".." in path:
		return false

	var normalized = path.simplify_path()

	for _l53 in _o83:
		var _t36 = _l53.simplify_path()
		if normalized.begins_with(_t36) or normalized == _t36.trim_suffix("/"):
			return false

	return true

func _o5(path: String) -> String:
	if not path.begins_with("res://"):
		return "Path must start with res://"

	if ".." in path:
		return "Path traversal (..) is not allowed"

	var normalized = path.simplify_path()
	for _l53 in _o83:
		var _t36 = _l53.simplify_path()
		if normalized.begins_with(_t36) or normalized == _t36.trim_suffix("/"):
			return "Path is protected: " + _l53

	return "Path validation failed"

func _r81(path: String) -> Dictionary:
	if path.is_empty():
		return {"success": false, "error": "Path is required"}

	if not _c9(path):
		return {"success": false, "error": _o5(path)}

	if not FileAccess.file_exists(path):
		return {"success": false, "error": "File not found: " + path}

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		var _h40 = FileAccess.get_open_error()
		return {"success": false, "error": "Cannot open file: " + path + " (error: " + str(_h40) + ")"}

	var _q1 = file.get_length()
	var content = file.get_as_text()
	file.close()

	var _q53 = false
	if content.length() > _t59:
		content = content.substr(0, _t59) + "\n... [truncated, file too large]"
		_q53 = true

	return {
		"success": true,
		"content": content,
		"path": path,
		"size": _q1,
		"truncated": _q53
	}

func _x38(_d92: String, _o3: bool) -> Dictionary:
	if _d92.is_empty():
		_d92 = "res://"

	if not _c9(_d92):
		return {"success": false, "error": _o5(_d92)}

	var _g27 = DirAccess.open(_d92)
	if not _g27:
		var _h40 = DirAccess.get_open_error()
		return {"success": false, "error": "Cannot open directory: " + _d92 + " (error: " + str(_h40) + ")"}

	var _h63: Array[String] = []
	var _n96: Array[String] = []

	_g27.list_dir_begin()
	var _p88 = _g27.get_next()

	while _p88 != "":
		if _p88 != "." and _p88 != "..":
			var full_path = _d92.path_join(_p88)

			if _c9(full_path):
				if _g27.current_is_dir():
					_n96.append(_p88 + "/")
					if _o3:
						var _y13 = _x38(full_path, true)
						if _y13.get("success", false):
							var _s5 = _y13.get("files", [])
							for f in _s5:
								_h63.append(_p88 + "/" + f)
				else:
					_h63.append(_p88)

		_p88 = _g27.get_next()

	_g27.list_dir_end()

	return {
		"success": true,
		"directory": _d92,
		"files": _h63,
		"directories": _n96,
		"total_files": _h63.size(),
		"total_directories": _n96.size()
	}

func _e49(_v48: String, base_path: String) -> Dictionary:
	if _v48.is_empty():
		return {"success": false, "error": "Pattern is required"}

	if base_path.is_empty():
		base_path = "res://"

	if not _c9(base_path):
		return {"success": false, "error": _o5(base_path)}

	var _f79: Array[String] = []
	var _x94: int = 0

	var segments = _v48.split("/")

	_w68(base_path, segments, 0, _f79, _x94)

	var _q53 = false
	if _f79.size() > _p2:
		_f79.resize(_p2)
		_q53 = true

	return {
		"success": true,
		"matches": _f79,
		"total_found": _f79.size(),
		"truncated": _q53,
		"pattern": _v48,
		"base_path": base_path
	}

func _w68(current_path: String, segments: Array, _f74: int, _f79: Array[String], _x94: int) -> void:
	if _f79.size() >= _p2:
		return

	if _f74 >= segments.size():
		return

	var _w14 = segments[_f74]
	var _h74 = (_f74 == segments.size() - 1)

	if _w14 == "**":
		if _f74 + 1 < segments.size():
			_w68(current_path, segments, _f74 + 1, _f79, _x94)

		var _g27 = DirAccess.open(current_path)
		if _g27:
			_g27.list_dir_begin()
			var _o32 = _g27.get_next()
			while _o32 != "" and _f79.size() < _p2:
				if _o32 != "." and _o32 != "..":
					var full_path = current_path.path_join(_o32)
					if _c9(full_path) and _g27.current_is_dir():
						_w68(full_path, segments, _f74, _f79, _x94 + 1)
				_o32 = _g27.get_next()
			_g27.list_dir_end()
		return

	var _g27 = DirAccess.open(current_path)
	if not _g27:
		return

	_g27.list_dir_begin()
	var _o32 = _g27.get_next()

	while _o32 != "" and _f79.size() < _p2:
		if _o32 != "." and _o32 != "..":
			var full_path = current_path.path_join(_o32)

			if _c9(full_path):
				var _r71 = _g27.current_is_dir()

				if _g58(_o32, _w14):
					if _h74:
						if not _r71 or _w14.ends_with("/"):
							_f79.append(full_path)
						elif _r71 and not _w14.ends_with("/"):
							_f79.append(full_path)
					elif _r71:
						_w68(full_path, segments, _f74 + 1, _f79, _x94 + 1)

		_o32 = _g27.get_next()

	_g27.list_dir_end()

func _g58(name: String, _v48: String) -> bool:
	if _v48 == "*":
		return true
	if _v48 == name:
		return true

	var _z20 = "^"
	var i = 0
	while i < _v48.length():
		var c = _v48[i]
		match c:
			"*":
				_z20 += ".*"
			"?":
				_z20 += "."
			".":
				_z20 += "\\."
			"[":
				var _u60 = _v48.find("]", i)
				if _u60 > i:
					_z20 += _v48.substr(i, _u60 - i + 1)
					i = _u60
				else:
					_z20 += "\\["
			_:
				if c in "\\^$|+(){}":
					_z20 += "\\" + c
				else:
					_z20 += c
		i += 1
	_z20 += "$"

	var _t20 = RegEx.new()
	if _t20.compile(_z20) != OK:
		return name == _v48

	return _t20.search(name) != null

func _g62(_v48: String, base_path: String, _r82: String, _m17: int) -> Dictionary:
	if _v48.is_empty():
		return {"success": false, "error": "Pattern is required"}

	if base_path.is_empty():
		base_path = "res://"

	if not _c9(base_path):
		return {"success": false, "error": _o5(base_path)}

	var _t20 = RegEx.new()
	var _o74 = _t20.compile(_v48)
	if _o74 != OK:
		return {"success": false, "error": "Invalid regex pattern: " + _v48}

	var _c53: Array[String] = []

	if _r82.is_empty():
		_m37(base_path, _c53)
	else:
		var _g11 = _e49(_r82, base_path)
		if not _g11.get("success", false):
			return _g11
		for f in _g11.get("matches", []):
			_c53.append(f)

	var _f79: Array[Dictionary] = []
	var _r77: int = 0
	var _w47: int = 0

	for file_path in _c53:
		if _f79.size() >= _x66:
			break

		if _r10(file_path):
			continue

		if not FileAccess.file_exists(file_path):
			continue

		var file = FileAccess.open(file_path, FileAccess.READ)
		if not file:
			continue

		var content = file.get_as_text()
		file.close()
		_r77 += 1

		var _b26 = content.split("\n")
		var _z64 = false

		for _e13 in range(_b26.size()):
			if _f79.size() >= _x66:
				break

			var line = _b26[_e13]
			var _w61 = _t20.search(line)

			if _w61:
				_z64 = true

				var _h100: Array[String] = []
				var _c33: Array[String] = []

				for i in range(max(0, _e13 - _m17), _e13):
					_h100.append(_b26[i])

				for i in range(_e13 + 1, min(_b26.size(), _e13 + _m17 + 1)):
					_c33.append(_b26[i])

				_f79.append({
					"file": file_path,
					"line_number": _e13 + 1,
					"line": line,
					"before_context": _h100,
					"after_context": _c33,
					"match_start": _w61.get_start(),
					"match_end": _w61.get_end()
				})

		if _z64:
			_w47 += 1

	var _q53 = _f79.size() >= _x66

	return {
		"success": true,
		"matches": _f79,
		"total_matches": _f79.size(),
		"files_searched": _r77,
		"files_with_matches": _w47,
		"truncated": _q53,
		"pattern": _v48
	}

func _m37(_d92: String, _h63: Array[String]) -> void:
	var _g27 = DirAccess.open(_d92)
	if not _g27:
		return

	_g27.list_dir_begin()
	var _o32 = _g27.get_next()

	while _o32 != "":
		if _o32 != "." and _o32 != "..":
			var full_path = _d92.path_join(_o32)

			if _c9(full_path):
				if _g27.current_is_dir():
					_m37(full_path, _h63)
				else:
					_h63.append(full_path)

		_o32 = _g27.get_next()

	_g27.list_dir_end()

func _r10(path: String) -> bool:
	var _q65 = [
		".png", ".jpg", ".jpeg", ".gif", ".bmp", ".webp", ".svg",
		".ogg", ".wav", ".mp3", ".flac",
		".ttf", ".otf", ".woff", ".woff2",
		".zip", ".tar", ".gz", ".7z", ".rar",
		".exe", ".dll", ".so", ".dylib",
		".res", ".import", ".scn", ".bin",
		".glb", ".gltf", ".fbx", ".obj", ".dae"
	]

	var _e48 = path.get_extension().to_lower()
	if _e48.is_empty():
		return false

	return ("." + _e48) in _q65

func _g34() -> Dictionary:
	var _t37 = Engine.get_version_info()
	var _c52 = "%d.%d.%d" % [_t37.get("major", 0), _t37.get("minor", 0), _t37.get("patch", 0)]

	var _x17 = {
		"success": true,
		"godot_version": _c52,
		"godot_version_full": _t37.get("string", _c52),
		"project_name": ProjectSettings.get_setting("application/config/name", "Unknown"),
		"project_path": ProjectSettings.globalize_path("res://")
	}

	var _f19 = ProjectSettings.get_setting("application/run/main_scene", "")
	if not _f19.is_empty():
		_x17["main_scene"] = _f19

	var description = ProjectSettings.get_setting("application/config/description", "")
	if not description.is_empty():
		_x17["description"] = description

	var _j96: Array[String] = []
	for _r7 in ProjectSettings.get_property_list():
		var name = _r7.get("name", "")
		if name.begins_with("autoload/"):
			_j96.append(name.replace("autoload/", ""))

	if not _j96.is_empty():
		_x17["autoloads"] = _j96

	return _x17

func _r78() -> Dictionary:
	if _z76 == null:
		return {"success": false, "error": "Editor interface not available"}

	if _z76.is_playing_scene():
		return {"success": false, "error": "Project is already running"}

	_z76.play_main_scene()

	return {"success": true, "message": "Project started"}

func _b83() -> Dictionary:
	if _z76 == null:
		return {"success": false, "error": "Editor interface not available"}

	if not _z76.is_playing_scene():
		return {"success": false, "error": "Project is not running"}

	_z76.stop_playing_scene()

	return {"success": true, "message": "Project stopped"}

func _z33(path: String, content: String) -> Dictionary:
	if path.is_empty():
		return {"success": false, "error": "Path is required"}

	if not _c9(path):
		return {"success": false, "error": _o5(path)}

	if FileAccess.file_exists(path):
		return {"success": false, "error": "File already exists: " + path + ". Use edit_file to modify existing files."}

	var _t80 = path.get_base_dir()
	if not _t80.is_empty() and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_t80)):
		var _w79 = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_t80))
		if _w79 != OK:
			return {"success": false, "error": "Cannot create directory: " + _t80 + " (error: " + str(_w79) + ")"}

	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		var _h40 = FileAccess.get_open_error()
		return {"success": false, "error": "Cannot create file: " + path + " (error: " + str(_h40) + ")"}

	file.store_string(content)
	file.close()

	if _z76:
		_z76.get_resource_filesystem().scan()

	var _v42 = {
		"success": true,
		"message": "File created: " + path,
		"path": path,
		"size": content.length()
	}

	var _i33 = _n97(path)
	if not _i33["valid"]:
		_v42["warning"] = _i33["error"]
		_v42["message"] += " (WARNING: " + _i33["error"] + ")"

	return _v42

func _h12(path: String, _q28: String, _d70: String, _b30: bool) -> Dictionary:
	if path.is_empty():
		return {"success": false, "error": "Path is required"}

	if _q28.is_empty():
		return {"success": false, "error": "old_string is required"}

	if not _c9(path):
		return {"success": false, "error": _o5(path)}

	if not FileAccess.file_exists(path):
		return {"success": false, "error": "File not found: " + path + ". Use create_file to create new files."}

	var _r5 = FileAccess.open(path, FileAccess.READ)
	if not _r5:
		var _h40 = FileAccess.get_open_error()
		return {"success": false, "error": "Cannot read file: " + path + " (error: " + str(_h40) + ")"}

	var _j45 = _r5.get_as_text()
	_r5.close()

	var _i41 = _j45.find(_q28)
	if _i41 == -1:
		return {"success": false, "error": "old_string not found in file. The exact text must exist in the file."}

	var _q12 = _j45.count(_q28)

	if _q12 > 1 and not _b30:
		return {
			"success": false,
			"error": "Found " + str(_q12) + " occurrences of old_string. Set replace_all=true to replace all, or provide more context to make the string unique."
		}

	var _m61: String
	var _c39: int

	if _b30:
		_m61 = _j45.replace(_q28, _d70)
		_c39 = _q12
	else:
		_m61 = _j45.substr(0, _i41) + _d70 + _j45.substr(_i41 + _q28.length())
		_c39 = 1

	var _i51 = path + ".agent_backup"
	var _y3 = FileAccess.open(_i51, FileAccess.WRITE)
	if _y3:
		_y3.store_string(_j45)
		_y3.close()
	else:
		pass

	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		var _h40 = FileAccess.get_open_error()
		return {"success": false, "error": "Cannot write file: " + path + " (error: " + str(_h40) + ")"}

	file.store_string(_m61)
	file.close()

	if _z76:
		_z76.get_resource_filesystem().scan()

	var _n79 = _v43(_q28, _d70)

	var _v42 = {
		"success": true,
		"message": "File modified: " + path,
		"path": path,
		"replacements_made": _c39,
		"diff_preview": _n79,
		"original_size": _j45.length(),
		"new_size": _m61.length()
	}

	if FileAccess.file_exists(_i51):
		_v42["backup"] = _i51

	var _i33 = _n97(path)
	if not _i33["valid"]:
		_v42["warning"] = _i33["error"]
		_v42["message"] += " (WARNING: " + _i33["error"] + ")"

	return _v42

func _v43(_q28: String, _d70: String) -> String:
	var _h25 = _q28.split("\n")
	var _e19 = _d70.split("\n")

	var _n78 = ""

	for line in _h25:
		_n78 += "- " + line + "\n"

	for line in _e19:
		_n78 += "+ " + line + "\n"

	return _n78.strip_edges()

func _n97(path: String) -> Dictionary:
	if not path.ends_with(".tscn") and not path.ends_with(".tres"):
		return {"valid": true}

	var _n6 = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if _n6 == null:
		var _f96 = ""
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			_f96 = file.get_as_text()
			file.close()

		var _b26 = _f96.split("\n")
		var _n9 = ""
		for i in range(_b26.size()):
			_n9 += str(i + 1) + ": " + _b26[i] + "\n"

		return {
			"valid": false,
			"error": "PARSE ERROR in " + path.get_file() + ". The file has invalid format and cannot be loaded by Godot. Review the content below and fix the syntax:\n\n" + _n9
		}

	return {"valid": true}

func _a63(path: String) -> Dictionary:
	if path.is_empty():
		return {"success": false, "error": "Path is required"}

	if not _c9(path):
		return {"success": false, "error": _o5(path)}

	if not FileAccess.file_exists(path):
		return {"success": false, "error": "File not found: " + path}

	var _q93 = ProjectSettings.globalize_path(path)

	var _w79 = DirAccess.remove_absolute(_q93)
	if _w79 != OK:
		return {"success": false, "error": "Cannot delete file: " + path + " (error: " + str(_w79) + ")"}

	if _z76:
		_z76.get_resource_filesystem().scan()

	return {
		"success": true,
		"message": "File deleted: " + path,
		"path": path
	}

func _q8() -> Array[Dictionary]:
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

func _j65(_w25: String, _n73: Dictionary) -> Dictionary:
	match _w25:
		"read_file":
			if not _n73.has("path") or _n73.get("path", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: path"}
		"list_files":
			pass  
		"glob":
			if not _n73.has("pattern") or _n73.get("pattern", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: pattern"}
		"grep":
			if not _n73.has("pattern") or _n73.get("pattern", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: pattern"}
		"get_project_info":
			pass  
		"run_project":
			pass  
		"stop_project":
			pass  
		"create_file":
			if not _n73.has("path") or _n73.get("path", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: path"}
			if not _n73.has("content"):
				return {"valid": false, "error": "Missing required parameter: content"}
		"edit_file":
			if not _n73.has("path") or _n73.get("path", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: path"}
			if not _n73.has("old_string") or _n73.get("old_string", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: old_string"}
			if not _n73.has("new_string"):
				return {"valid": false, "error": "Missing required parameter: new_string"}
		"delete_file":
			if not _n73.has("path") or _n73.get("path", "").is_empty():
				return {"valid": false, "error": "Missing required parameter: path"}
		_:
			return {"valid": false, "error": "Unknown tool: " + _w25}

	return {"valid": true}

