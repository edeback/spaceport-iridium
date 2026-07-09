@tool
class_name _a79
extends RefCounted
var _r14: _d21
var _r58: _q68
var _f21: EditorInterface
func _init(_m57: _d21 = null, _i13: EditorInterface = null):
	_r14 = _m57
	_f21 = _i13
	_r58 = _q68.new()
func _m83(_h91: String, commands: Array) -> String:
	if commands.is_empty():
		return _h91
	var _y77 = []
	var _m51 = 0
	for _u54 in commands:
		var _w22 = ""
		if _u54.get("type", "") == "openscript":
			_m51 += 1
			_w22 = _j28(_u54, _m51)
		else:
			_w22 = _j28(_u54)
		if _w22 != "":
			_y77.append(_w22)
	if _y77.is_empty():
		return _h91
	var _y33 = "# Context Information\n\n"
	_y33 += "\n\n".join(_y77)
	_y33 += "\n\n---\n\n"
	_y33 += "# User Request\n\n"
	_y33 += _h91
	return _y33
func _j28(_u54: Dictionary, _g75: int = -1) -> String:
	var _w95 = _u54.get("type", "")
	match _w95:
		"file":
			return _l9(_u54)
		"scene":
			return _n14(_u54)
		"node":
			return _a16(_u54)
		"selection":
			return _i76(_u54)
		"openscript":
			return _u33(_u54, _g75)
		"error":
			return "## Command Error\n\n" + _u54.get("error", "Unknown command error")
		_:
			return ""
func _l9(_u54: Dictionary) -> String:
	if _r14 == null:
		return ""
	var _z92 = _r14._g65(_u54)
	if not _z92.get("success", false):
		var _x73 = "## File Error: " + _u54.get("path", "") + "\n\n"
		_x73 += "Could not read file: " + _z92.get("error", "Unknown error")
		return _x73
	var file_path = _z92.get("path", "")
	var _w22 = "## File: " + file_path + "\n\n"
	if _z92.get("start_line", 1) > 1 or _z92.get("end_line", -1) > 0:
		var start_line = _z92.get("start_line", 1)
		var end_line = _z92.get("end_line", -1)
		if end_line > 0:
			_w22 += "**Lines " + str(start_line) + "-" + str(end_line) + ":**\n\n"
		else:
			_w22 += "**From line " + str(start_line) + ":**\n\n"
	var language = _e34(file_path)
	var content = _z92.get("content", "")
	_w22 += "```" + language + "\n"
	_w22 += content
	if not content.ends_with("\n"):
		_w22 += "\n"
	_w22 += "```"
	return _w22
func _n14(_u54: Dictionary) -> String:
	if _r58 == null:
		return "## Scene Error\n\nTSCN parser not available"
	var scene_path = _u54.get("path", "")
	var node_path = _u54.get("node_path", "")
	var include_scripts = _u54.get("include_scripts", false)
	var _k27 = _r58._z97(scene_path, node_path, include_scripts)
	if not _k27.get("success", false):
		var _x73 = "## Scene Error: " + scene_path + "\n\n"
		_x73 += "Could not parse scene: " + _k27.get("error", "Unknown error")
		return _x73
	var _w22 = "## Scene: " + scene_path
	if node_path != "":
		_w22 += " (subtree: " + node_path + ")"
	_w22 += "\n\n"
	_w22 += _k27.get("filtered_content", "")
	if include_scripts and not _k27.get("scripts", []).is_empty():
		_w22 += "\n\n## Associated Scripts:\n\n"
		var _t38 = 0
		for _f76 in _k27.get("scripts", []):
			if _t38 >= 3:  
				_w22 += "\n... (additional scripts truncated)\n"
				break
			var _w48 = ""
			var _m85 = ""
			var _w56 = false
			var _x73 = ""
			if _f76 is Dictionary:
				_w48 = _f76.get("path", "")
				_m85 = _f76.get("content", "")
				_w56 = _f76.get("error", false)
				if _w56:
					_x73 = _m85
			else:
				_w48 = str(_f76)
				var _r40 = _p5(_w48)
				if _r40.get("success", false):
					_m85 = _r40.get("content", "")
				else:
					_w56 = true
					_x73 = _r40.get("error", "Unknown error")
			if not _w56 and _m85 != "":
				_w22 += "### Script: " + _w48 + "\n\n"
				_w22 += "```gdscript\n"
				_w22 += _m85
				if not _m85.ends_with("\n"):
					_w22 += "\n"
				_w22 += "```\n\n"
			elif _w56:
				_w22 += "### Script: " + _w48 + " (Error: " + _x73 + ")\n\n"
			_t38 += 1
	return _w22
func _a16(_u54: Dictionary) -> String:
	if _r58 == null or _f21 == null:
		return "## Node Error\n\nTSCN parser or editor interface not available"
	var node_path = _u54.get("node_path", "")
	var _i81 = _r58._c17(_f21, node_path)
	if not _i81.get("success", false):
		var _x73 = "## Node Error: " + node_path + "\n\n"
		_x73 += "Could not find node: " + _i81.get("error", "Unknown error")
		return _x73
	var _e50 = _i81.get("node", {})
	var scene_info = _i81.get("scene_info", {})
	var _w22 = "## Node: " + node_path + "\n\n"
	_w22 += "**Name:** " + _e50.get("name", "Unknown") + "\n"
	_w22 += "**Type:** " + _e50.get("type", "Unknown") + "\n"
	_w22 += "**Full Path:** " + _e50.get("full_path", "Unknown") + "\n"
	var parent = _e50.get("parent", "")
	if parent != "":
		_w22 += "**Parent:** " + parent + "\n"
	else:
		_w22 += "**Parent:** Root node\n"
	var _w48 = _e50.get("script_path", "")
	if _w48 != "":
		_w22 += "**Script:** " + _w48 + "\n\n"
		var _r40 = _p5(_w48)
		if _r40.get("success", false):
			var _m33 = _r40.get("content", "")
			_w22 += "### Script Content:\n\n"
			_w22 += "```gdscript\n"
			_w22 += _m33
			if not _m33.ends_with("\n"):
				_w22 += "\n"
			_w22 += "```\n"
		else:
			_w22 += "### Script Content: (Error: " + _r40.get("error", "Unknown error") + ")\n"
	else:
		_w22 += "**Script:** None\n"
	_w22 += "\n### Scene Context:\n\n"
	_w22 += "Current scene root: " + scene_info.get("root_node", "Unknown") + "\n"
	_w22 += "Total nodes in scene: " + str(scene_info.get("nodes", []).size()) + "\n"
	return _w22
func _p5(_w48: String) -> Dictionary:
	if _w48.begins_with("ExtResource_"):
		return {"success": false, "error": "ExtResource resolution not yet implemented"}
	if not _w48.begins_with("res://"):
		return {"success": false, "error": "Invalid script path: " + _w48}
	if not FileAccess.file_exists(_w48):
		return {"success": false, "error": "Script file not found: " + _w48}
	var file = FileAccess.open(_w48, FileAccess.READ)
	if file == null:
		return {"success": false, "error": "Cannot open script file: " + _w48}
	var content = file.get_as_text()
	file.close()
	var _l45 = 10000  
	if content.length() > _l45:
		content = content.substr(0, _l45) + "\n... [script truncated]"
	return {
		"success": true,
		"content": content,
		"path": _w48
	}
func _i76(_u54: Dictionary) -> String:
	if _r14 == null:
		return ""
	var _c60 = _r14._e20()
	if not _c60.get("success", false):
		return "## Selection Error\n\nNo text currently selected: " + _c60.get("error", "Unknown error")
	var _w22 = "## Selected Text"
	var _i67 = _c60.get("path", "")
	if _i67 != "":
		_w22 += " from " + _i67
	var start_line = _c60.get("start_line", 1)
	var end_line = _c60.get("end_line", 1)
	if start_line == end_line:
		_w22 += " (Line " + str(start_line) + ")"
	else:
		_w22 += " (Lines " + str(start_line) + "-" + str(end_line) + ")"
	_w22 += "\n\n"
	var language = _e34(_c60.get("path", ""))
	var _r2 = _c60.get("content", "")
	_w22 += "```" + language + "\n"
	_w22 += _r2
	if not _r2.ends_with("\n"):
		_w22 += "\n"
	_w22 += "```"
	return _w22
func _u33(_u54: Dictionary, _g75: int = -1) -> String:
	var _w48 = _u54.get("path", "")
	var _r40 = _u54.get("content", "")
	if _w48 == "" or _r40 == "":
		if _r14 == null:
			return ""
		var _p50 = _r14.get_current_script()
		if not _p50.get("success", false):
			return "## Current Script Error\n\n" + _p50.get("error", "Could not retrieve current script")
		if _w48 == "":
			_w48 = _p50.get("path", "Unknown")
		if _r40 == "":
			_r40 = _p50.get("content", "")
	if _r40 == "":
		return "## Current Script Error\n\nCould not retrieve current script content"
	if _w48 == "":
		_w48 = "current_script.gd"
	var _w22 = ""
	if _g75 > 0:
		_w22 = "## Script #%d: %s\n\n" % [_g75, _w48]
	else:
		_w22 = "## Current Script: " + _w48 + "\n\n"
	var language = _e34(_w48)
	_w22 += "```" + language + "\n"
	_w22 += _r40
	if not _r40.ends_with("\n"):
		_w22 += "\n"
	_w22 += "```"
	return _w22
func _e34(file_path: String) -> String:
	if file_path == "":
		return "gdscript"  
	var _b62 = file_path.get_extension().to_lower()
	match _b62:
		"gd":
			return "gdscript"
		"cs":
			return "csharp"
		"shader":
			return "glsl"
		"json":
			return "json"
		"cfg", "ini":
			return "ini"
		"tscn", "tres":
			return "gdscript"  
		"txt":
			return "text"
		"md":
			return "markdown"
		"js":
			return "javascript"
		"ts":
			return "typescript"
		"py":
			return "python"
		"cpp", "cc", "cxx":
			return "cpp"
		"c":
			return "c"
		"h", "hpp":
			return "cpp"
		"html", "htm":
			return "html"
		"css":
			return "css"
		"xml":
			return "xml"
		"yaml", "yml":
			return "yaml"
		"sh":
			return "bash"
		_:
			return "text"
func _h81(_v58: String) -> int:
	return int(_v58.length() / 4.0)
func _l2(_v58: String, max_tokens: int = 32000) -> Dictionary:
	var estimated_tokens = _h81(_v58)
	if estimated_tokens > max_tokens:
		return {
			"valid": false,
			"estimated_tokens": estimated_tokens,
			"max_tokens": max_tokens,
			"message": "Context too large (" + str(estimated_tokens) + " estimated tokens). Consider reducing file sizes or number of @commands."
		}
	return {
		"valid": true,
		"estimated_tokens": estimated_tokens,
		"max_tokens": max_tokens
	}
func _q17(commands: Array) -> String:
	if commands.is_empty():
		return "No context commands"
	var _u25 = []
	for _u54 in commands:
		var _w95 = _u54.get("type", "")
		match _w95:
			"file":
				var path = _u54.get("path", "unknown")
				var _v42 = "@file " + path
				if _u54.get("start_line", -1) > 0:
					_v42 += ":" + str(_u54.get("start_line", 0)) + "-" + str(_u54.get("end_line", 0))
				if _u54.get("symbol", "") != "":
					_v42 += "#" + _u54.get("symbol", "")
				_u25.append(_v42)
			"scene":
				var path = _u54.get("path", "unknown")
				var _v42 = "@scene " + path
				if _u54.get("node_path", "") != "":
					_v42 += "#" + _u54.get("node_path", "")
				if _u54.get("include_scripts", false):
					_v42 += " --scripts"
				_u25.append(_v42)
			"node":
				var node_path = _u54.get("node_path", "unknown")
				_u25.append("@node " + node_path + " (current scene)")
			"selection":
				_u25.append("@selection (current editor selection)")
			"openscript":
				var _w48 = _u54.get("path", "")
				if _w48 == "":
					_w48 = "current script"
				_u25.append("@openscript " + _w48)
			_:
				_u25.append("@" + _w95)
	return "Context: " + ", ".join(_u25)
