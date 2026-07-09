@tool
class_name _s40
extends RefCounted
var _n78: _m33
var _h47: _r92
var _b72: EditorInterface
func _init(_i91: _m33 = null, _o10: EditorInterface = null):
	_n78 = _i91
	_b72 = _o10
	_h47 = _r92.new()
func _e86(_b58: String, commands: Array) -> String:
	if commands.is_empty():
		return _b58
	var _i66 = []
	var _v87 = 0
	for _y59 in commands:
		var _v25 = ""
		if _y59.get("type", "") == "openscript":
			_v87 += 1
			_v25 = _j65(_y59, _v87)
		else:
			_v25 = _j65(_y59)
		if _v25 != "":
			_i66.append(_v25)
	if _i66.is_empty():
		return _b58
	var _t53 = "# Context Information\n\n"
	_t53 += "\n\n".join(_i66)
	_t53 += "\n\n---\n\n"
	_t53 += "# User Request\n\n"
	_t53 += _b58
	return _t53
func _j65(_y59: Dictionary, _l96: int = -1) -> String:
	var _g82 = _y59.get("type", "")
	match _g82:
		"file":
			return _a73(_y59)
		"scene":
			return _j82(_y59)
		"node":
			return _m100(_y59)
		"selection":
			return _p15(_y59)
		"openscript":
			return _n29(_y59, _l96)
		"error":
			return "## Command Error\n\n" + _y59.get("error", "Unknown command error")
		_:
			return ""
func _a73(_y59: Dictionary) -> String:
	if _n78 == null:
		return ""
	var _b7 = _n78._s65(_y59)
	if not _b7.get("success", false):
		var _w11 = "## File Error: " + _y59.get("path", "") + "\n\n"
		_w11 += "Could not read file: " + _b7.get("error", "Unknown error")
		return _w11
	var file_path = _b7.get("path", "")
	var _v25 = "## File: " + file_path + "\n\n"
	if _b7.get("start_line", 1) > 1 or _b7.get("end_line", -1) > 0:
		var start_line = _b7.get("start_line", 1)
		var end_line = _b7.get("end_line", -1)
		if end_line > 0:
			_v25 += "**Lines " + str(start_line) + "-" + str(end_line) + ":**\n\n"
		else:
			_v25 += "**From line " + str(start_line) + ":**\n\n"
	var language = _j29(file_path)
	var content = _b7.get("content", "")
	_v25 += "```" + language + "\n"
	_v25 += content
	if not content.ends_with("\n"):
		_v25 += "\n"
	_v25 += "```"
	return _v25
func _j82(_y59: Dictionary) -> String:
	if _h47 == null:
		return "## Scene Error\n\nTSCN parser not available"
	var scene_path = _y59.get("path", "")
	var node_path = _y59.get("node_path", "")
	var include_scripts = _y59.get("include_scripts", false)
	var _u84 = _h47._a55(scene_path, node_path, include_scripts)
	if not _u84.get("success", false):
		var _w11 = "## Scene Error: " + scene_path + "\n\n"
		_w11 += "Could not parse scene: " + _u84.get("error", "Unknown error")
		return _w11
	var _v25 = "## Scene: " + scene_path
	if node_path != "":
		_v25 += " (subtree: " + node_path + ")"
	_v25 += "\n\n"
	_v25 += _u84.get("filtered_content", "")
	if include_scripts and not _u84.get("scripts", []).is_empty():
		_v25 += "\n\n## Associated Scripts:\n\n"
		var _h83 = 0
		for _z36 in _u84.get("scripts", []):
			if _h83 >= 3:  
				_v25 += "\n... (additional scripts truncated)\n"
				break
			var _s100 = ""
			var _q89 = ""
			var _l56 = false
			var _w11 = ""
			if _z36 is Dictionary:
				_s100 = _z36.get("path", "")
				_q89 = _z36.get("content", "")
				_l56 = _z36.get("error", false)
				if _l56:
					_w11 = _q89
			else:
				_s100 = str(_z36)
				var _y92 = _v56(_s100)
				if _y92.get("success", false):
					_q89 = _y92.get("content", "")
				else:
					_l56 = true
					_w11 = _y92.get("error", "Unknown error")
			if not _l56 and _q89 != "":
				_v25 += "### Script: " + _s100 + "\n\n"
				_v25 += "```gdscript\n"
				_v25 += _q89
				if not _q89.ends_with("\n"):
					_v25 += "\n"
				_v25 += "```\n\n"
			elif _l56:
				_v25 += "### Script: " + _s100 + " (Error: " + _w11 + ")\n\n"
			_h83 += 1
	return _v25
func _m100(_y59: Dictionary) -> String:
	if _h47 == null or _b72 == null:
		return "## Node Error\n\nTSCN parser or editor interface not available"
	var node_path = _y59.get("node_path", "")
	var _q61 = _h47._s56(_b72, node_path)
	if not _q61.get("success", false):
		var _w11 = "## Node Error: " + node_path + "\n\n"
		_w11 += "Could not find node: " + _q61.get("error", "Unknown error")
		return _w11
	var _h39 = _q61.get("node", {})
	var scene_info = _q61.get("scene_info", {})
	var _v25 = "## Node: " + node_path + "\n\n"
	_v25 += "**Name:** " + _h39.get("name", "Unknown") + "\n"
	_v25 += "**Type:** " + _h39.get("type", "Unknown") + "\n"
	_v25 += "**Full Path:** " + _h39.get("full_path", "Unknown") + "\n"
	var parent = _h39.get("parent", "")
	if parent != "":
		_v25 += "**Parent:** " + parent + "\n"
	else:
		_v25 += "**Parent:** Root node\n"
	var _s100 = _h39.get("script_path", "")
	if _s100 != "":
		_v25 += "**Script:** " + _s100 + "\n\n"
		var _y92 = _v56(_s100)
		if _y92.get("success", false):
			var _e75 = _y92.get("content", "")
			_v25 += "### Script Content:\n\n"
			_v25 += "```gdscript\n"
			_v25 += _e75
			if not _e75.ends_with("\n"):
				_v25 += "\n"
			_v25 += "```\n"
		else:
			_v25 += "### Script Content: (Error: " + _y92.get("error", "Unknown error") + ")\n"
	else:
		_v25 += "**Script:** None\n"
	_v25 += "\n### Scene Context:\n\n"
	_v25 += "Current scene root: " + scene_info.get("root_node", "Unknown") + "\n"
	_v25 += "Total nodes in scene: " + str(scene_info.get("nodes", []).size()) + "\n"
	return _v25
func _v56(_s100: String) -> Dictionary:
	if _s100.begins_with("ExtResource_"):
		return {"success": false, "error": "ExtResource resolution not yet implemented"}
	if not _s100.begins_with("res://"):
		return {"success": false, "error": "Invalid script path: " + _s100}
	if not FileAccess.file_exists(_s100):
		return {"success": false, "error": "Script file not found: " + _s100}
	var file = FileAccess.open(_s100, FileAccess.READ)
	if file == null:
		return {"success": false, "error": "Cannot open script file: " + _s100}
	var content = file.get_as_text()
	file.close()
	var _w43 = 10000  
	if content.length() > _w43:
		content = content.substr(0, _w43) + "\n... [script truncated]"
	return {
		"success": true,
		"content": content,
		"path": _s100
	}
func _p15(_y59: Dictionary) -> String:
	if _n78 == null:
		return ""
	var _x60 = _n78._m29()
	if not _x60.get("success", false):
		return "## Selection Error\n\nNo text currently selected: " + _x60.get("error", "Unknown error")
	var _v25 = "## Selected Text"
	var _t74 = _x60.get("path", "")
	if _t74 != "":
		_v25 += " from " + _t74
	var start_line = _x60.get("start_line", 1)
	var end_line = _x60.get("end_line", 1)
	if start_line == end_line:
		_v25 += " (Line " + str(start_line) + ")"
	else:
		_v25 += " (Lines " + str(start_line) + "-" + str(end_line) + ")"
	_v25 += "\n\n"
	var language = _j29(_x60.get("path", ""))
	var _y78 = _x60.get("content", "")
	_v25 += "```" + language + "\n"
	_v25 += _y78
	if not _y78.ends_with("\n"):
		_v25 += "\n"
	_v25 += "```"
	return _v25
func _n29(_y59: Dictionary, _l96: int = -1) -> String:
	var _s100 = _y59.get("path", "")
	var _y92 = _y59.get("content", "")
	if _s100 == "" or _y92 == "":
		if _n78 == null:
			return ""
		var _o73 = _n78.get_current_script()
		if not _o73.get("success", false):
			return "## Current Script Error\n\n" + _o73.get("error", "Could not retrieve current script")
		if _s100 == "":
			_s100 = _o73.get("path", "Unknown")
		if _y92 == "":
			_y92 = _o73.get("content", "")
	if _y92 == "":
		return "## Current Script Error\n\nCould not retrieve current script content"
	if _s100 == "":
		_s100 = "current_script.gd"
	var _v25 = ""
	if _l96 > 0:
		_v25 = "## Script #%d: %s\n\n" % [_l96, _s100]
	else:
		_v25 = "## Current Script: " + _s100 + "\n\n"
	var language = _j29(_s100)
	_v25 += "```" + language + "\n"
	_v25 += _y92
	if not _y92.ends_with("\n"):
		_v25 += "\n"
	_v25 += "```"
	return _v25
func _j29(file_path: String) -> String:
	if file_path == "":
		return "gdscript"  
	var _p58 = file_path.get_extension().to_lower()
	match _p58:
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
func _i50(_l58: String) -> int:
	return int(_l58.length() / 4.0)
func _g39(_l58: String, max_tokens: int = 32000) -> Dictionary:
	var estimated_tokens = _i50(_l58)
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
func _z41(commands: Array) -> String:
	if commands.is_empty():
		return "No context commands"
	var _t57 = []
	for _y59 in commands:
		var _g82 = _y59.get("type", "")
		match _g82:
			"file":
				var path = _y59.get("path", "unknown")
				var _v79 = "@file " + path
				if _y59.get("start_line", -1) > 0:
					_v79 += ":" + str(_y59.get("start_line", 0)) + "-" + str(_y59.get("end_line", 0))
				if _y59.get("symbol", "") != "":
					_v79 += "#" + _y59.get("symbol", "")
				_t57.append(_v79)
			"scene":
				var path = _y59.get("path", "unknown")
				var _v79 = "@scene " + path
				if _y59.get("node_path", "") != "":
					_v79 += "#" + _y59.get("node_path", "")
				if _y59.get("include_scripts", false):
					_v79 += " --scripts"
				_t57.append(_v79)
			"node":
				var node_path = _y59.get("node_path", "unknown")
				_t57.append("@node " + node_path + " (current scene)")
			"selection":
				_t57.append("@selection (current editor selection)")
			"openscript":
				var _s100 = _y59.get("path", "")
				if _s100 == "":
					_s100 = "current script"
				_t57.append("@openscript " + _s100)
			_:
				_t57.append("@" + _g82)
	return "Context: " + ", ".join(_t57)
