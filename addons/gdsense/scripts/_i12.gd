@tool
class_name _i12
extends RefCounted

var _i17: _e97
var _v30: _z20
var _b58: EditorInterface

func _init(_n98: _e97 = null, _f28: EditorInterface = null):
	_i17 = _n98
	_b58 = _f28
	_v30 = _z20.new()

func _j59(_m63: String, commands: Array) -> String:
	if commands.is_empty():
		return _m63

	var _y75 = []

	var _p48 = 0

	for _n49 in commands:
		var _l80 = ""

		if _n49.get("type", "") == "openscript":
			_p48 += 1
			_l80 = _l35(_n49, _p48)
		else:
			_l80 = _l35(_n49)

		if _l80 != "":
			_y75.append(_l80)

	if _y75.is_empty():
		return _m63

	var _a89 = "# Context Information\n\n"
	_a89 += "\n\n".join(_y75)
	_a89 += "\n\n---\n\n"
	_a89 += "# User Request\n\n"
	_a89 += _m63

	return _a89

func _l35(_n49: Dictionary, _r87: int = -1) -> String:
	var _s10 = _n49.get("type", "")
	match _s10:
		"file":
			return _g30(_n49)
		"scene":
			return _h59(_n49)
		"node":
			return _l30(_n49)
		"selection":
			return _g1(_n49)
		"openscript":
			return _d62(_n49, _r87)
		"error":
			return "## Command Error\n\n" + _n49.get("error", "Unknown command error")
		_:
			return ""

func _g30(_n49: Dictionary) -> String:
	if _i17 == null:
		return ""
	
	var _q28 = _i17._t68(_n49)

	if not _q28.get("success", false):
		var _e22 = "## File Error: " + _n49.get("path", "") + "\n\n"
		_e22 += "Could not read file: " + _q28.get("error", "Unknown error")
		return _e22

	var file_path = _q28.get("path", "")
	var _l80 = "## File: " + file_path + "\n\n"

	if _q28.get("start_line", 1) > 1 or _q28.get("end_line", -1) > 0:
		var start_line = _q28.get("start_line", 1)
		var end_line = _q28.get("end_line", -1)
		if end_line > 0:
			_l80 += "**Lines " + str(start_line) + "-" + str(end_line) + ":**\n\n"
		else:
			_l80 += "**From line " + str(start_line) + ":**\n\n"

	var language = _f33(file_path)
	var content = _q28.get("content", "")
	_l80 += "```" + language + "\n"
	_l80 += content
	if not content.ends_with("\n"):
		_l80 += "\n"
	_l80 += "```"
	
	return _l80

func _h59(_n49: Dictionary) -> String:
	if _v30 == null:
		return "## Scene Error\n\nTSCN parser not available"
	
	var scene_path = _n49.get("path", "")
	var node_path = _n49.get("node_path", "")
	var include_scripts = _n49.get("include_scripts", false)
	
	var _y43 = _v30._u98(scene_path, node_path, include_scripts)

	if not _y43.get("success", false):
		var _e22 = "## Scene Error: " + scene_path + "\n\n"
		_e22 += "Could not parse scene: " + _y43.get("error", "Unknown error")
		return _e22
	
	var _l80 = "## Scene: " + scene_path
	
	if node_path != "":
		_l80 += " (subtree: " + node_path + ")"
	
	_l80 += "\n\n"
	
	_l80 += _y43.get("filtered_content", "")
	
	if include_scripts and not _y43.get("scripts", []).is_empty():
		_l80 += "\n\n## Associated Scripts:\n\n"
		var _h97 = 0
		for _v80 in _y43.get("scripts", []):
			if _h97 >= 3:  
				_l80 += "\n... (additional scripts truncated)\n"
				break
			
			var _f85 = ""
			var _y28 = ""
			var _z73 = false
			var _e22 = ""
			
			if _v80 is Dictionary:
				_f85 = _v80.get("path", "")
				_y28 = _v80.get("content", "")
				_z73 = _v80.get("error", false)
				if _z73:
					_e22 = _y28
			else:
				_f85 = str(_v80)
				var _l37 = _m45(_f85)
				if _l37.get("success", false):
					_y28 = _l37.get("content", "")
				else:
					_z73 = true
					_e22 = _l37.get("error", "Unknown error")
			
			if not _z73 and _y28 != "":
				_l80 += "### Script: " + _f85 + "\n\n"
				_l80 += "```gdscript\n"
				_l80 += _y28
				if not _y28.ends_with("\n"):
					_l80 += "\n"
				_l80 += "```\n\n"
			elif _z73:
				_l80 += "### Script: " + _f85 + " (Error: " + _e22 + ")\n\n"
			
			_h97 += 1
	
	return _l80

func _l30(_n49: Dictionary) -> String:
	if _v30 == null or _b58 == null:
		return "## Node Error\n\nTSCN parser or editor interface not available"
	
	var node_path = _n49.get("node_path", "")
	
	var _o4 = _v30._r64(_b58, node_path)

	if not _o4.get("success", false):
		var _e22 = "## Node Error: " + node_path + "\n\n"
		_e22 += "Could not find node: " + _o4.get("error", "Unknown error")
		return _e22
	
	var _i57 = _o4.get("node", {})
	var scene_info = _o4.get("scene_info", {})
	
	var _l80 = "## Node: " + node_path + "\n\n"
	
	_l80 += "**Name:** " + _i57.get("name", "Unknown") + "\n"
	_l80 += "**Type:** " + _i57.get("type", "Unknown") + "\n"
	_l80 += "**Full Path:** " + _i57.get("full_path", "Unknown") + "\n"
	
	var parent = _i57.get("parent", "")
	if parent != "":
		_l80 += "**Parent:** " + parent + "\n"
	else:
		_l80 += "**Parent:** Root node\n"
	
	var _f85 = _i57.get("script_path", "")
	if _f85 != "":
		_l80 += "**Script:** " + _f85 + "\n\n"

		var _l37 = _m45(_f85)
		if _l37.get("success", false):
			var _m7 = _l37.get("content", "")
			_l80 += "### Script Content:\n\n"
			_l80 += "```gdscript\n"
			_l80 += _m7
			if not _m7.ends_with("\n"):
				_l80 += "\n"
			_l80 += "```\n"
		else:
			_l80 += "### Script Content: (Error: " + _l37.get("error", "Unknown error") + ")\n"
	else:
		_l80 += "**Script:** None\n"
	
	_l80 += "\n### Scene Context:\n\n"
	_l80 += "Current scene root: " + scene_info.get("root_node", "Unknown") + "\n"
	_l80 += "Total nodes in scene: " + str(scene_info.get("nodes", []).size()) + "\n"
	
	return _l80

func _m45(_f85: String) -> Dictionary:
	if _f85.begins_with("ExtResource_"):
		return {"success": false, "error": "ExtResource resolution not yet implemented"}
	
	if not _f85.begins_with("res://"):
		return {"success": false, "error": "Invalid script path: " + _f85}
	
	if not FileAccess.file_exists(_f85):
		return {"success": false, "error": "Script file not found: " + _f85}
	
	var file = FileAccess.open(_f85, FileAccess.READ)
	if file == null:
		return {"success": false, "error": "Cannot open script file: " + _f85}
	
	var content = file.get_as_text()
	file.close()
	
	var _x55 = 10000  
	if content.length() > _x55:
		content = content.substr(0, _x55) + "\n... [script truncated]"
	
	return {
		"success": true,
		"content": content,
		"path": _f85
	}

func _g1(_n49: Dictionary) -> String:
	if _i17 == null:
		return ""
	
	var _o89 = _i17._l5()

	if not _o89.get("success", false):
		return "## Selection Error\n\nNo text currently selected: " + _o89.get("error", "Unknown error")

	var _l80 = "## Selected Text"

	var _h33 = _o89.get("path", "")
	if _h33 != "":
		_l80 += " from " + _h33
	
	var start_line = _o89.get("start_line", 1)
	var end_line = _o89.get("end_line", 1)
	if start_line == end_line:
		_l80 += " (Line " + str(start_line) + ")"
	else:
		_l80 += " (Lines " + str(start_line) + "-" + str(end_line) + ")"
	
	_l80 += "\n\n"
	
	var language = _f33(_o89.get("path", ""))
	var _r70 = _o89.get("content", "")
	_l80 += "```" + language + "\n"
	_l80 += _r70
	if not _r70.ends_with("\n"):
		_l80 += "\n"
	_l80 += "```"
	
	return _l80

func _d62(_n49: Dictionary, _r87: int = -1) -> String:
	var _f85 = _n49.get("path", "")
	var _l37 = _n49.get("content", "")

	if _f85 == "" or _l37 == "":
		if _i17 == null:
			return ""

		var _v28 = _i17.get_current_script()

		if not _v28.get("success", false):
			return "## Current Script Error\n\n" + _v28.get("error", "Could not retrieve current script")

		if _f85 == "":
			_f85 = _v28.get("path", "Unknown")
		if _l37 == "":
			_l37 = _v28.get("content", "")

	if _l37 == "":
		return "## Current Script Error\n\nCould not retrieve current script content"

	if _f85 == "":
		_f85 = "current_script.gd"

	var _l80 = ""
	if _r87 > 0:
		_l80 = "## Script #%d: %s\n\n" % [_r87, _f85]
	else:
		_l80 = "## Current Script: " + _f85 + "\n\n"

	var language = _f33(_f85)
	_l80 += "```" + language + "\n"
	_l80 += _l37
	if not _l37.ends_with("\n"):
		_l80 += "\n"
	_l80 += "```"

	return _l80

func _f33(file_path: String) -> String:
	if file_path == "":
		return "gdscript"  
	
	var _p39 = file_path.get_extension().to_lower()
	
	match _p39:
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

func _k61(_z52: String) -> int:
	return int(_z52.length() / 4.0)

func _e35(_z52: String, max_tokens: int = 32000) -> Dictionary:
	var estimated_tokens = _k61(_z52)
	
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

func _d53(commands: Array) -> String:
	if commands.is_empty():
		return "No context commands"

	var _x44 = []

	for _n49 in commands:
		var _s10 = _n49.get("type", "")
		match _s10:
			"file":
				var path = _n49.get("path", "unknown")
				var _b86 = "@file " + path

				if _n49.get("start_line", -1) > 0:
					_b86 += ":" + str(_n49.get("start_line", 0)) + "-" + str(_n49.get("end_line", 0))

				if _n49.get("symbol", "") != "":
					_b86 += "#" + _n49.get("symbol", "")

				_x44.append(_b86)

			"scene":
				var path = _n49.get("path", "unknown")
				var _b86 = "@scene " + path

				if _n49.get("node_path", "") != "":
					_b86 += "#" + _n49.get("node_path", "")

				if _n49.get("include_scripts", false):
					_b86 += " --scripts"

				_x44.append(_b86)

			"node":
				var node_path = _n49.get("node_path", "unknown")
				_x44.append("@node " + node_path + " (current scene)")

			"selection":
				_x44.append("@selection (current editor selection)")

			"openscript":
				var _f85 = _n49.get("path", "")
				if _f85 == "":
					_f85 = "current script"
				_x44.append("@openscript " + _f85)

			_:
				_x44.append("@" + _s10)

	return "Context: " + ", ".join(_x44)

