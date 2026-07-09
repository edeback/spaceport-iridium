@tool
class_name _c15
extends RefCounted

var _a58: _x28
var _b53: _b33
var _z76: EditorInterface

func _init(_l14: _x28 = null, _i86: EditorInterface = null):
	_a58 = _l14
	_z76 = _i86
	_b53 = _b33.new()

func _l75(_q34: String, commands: Array) -> String:
	if commands.is_empty():
		return _q34

	var _a18 = []

	var _l3 = 0

	for _c38 in commands:
		var _s9 = ""

		if _c38.get("type", "") == "openscript":
			_l3 += 1
			_s9 = _j66(_c38, _l3)
		else:
			_s9 = _j66(_c38)

		if _s9 != "":
			_a18.append(_s9)

	if _a18.is_empty():
		return _q34

	var _i13 = "# Context Information\n\n"
	_i13 += "\n\n".join(_a18)
	_i13 += "\n\n---\n\n"
	_i13 += "# User Request\n\n"
	_i13 += _q34

	return _i13

func _j66(_c38: Dictionary, _j81: int = -1) -> String:
	var _t28 = _c38.get("type", "")
	match _t28:
		"file":
			return _y52(_c38)
		"scene":
			return _b23(_c38)
		"node":
			return _z96(_c38)
		"selection":
			return _c94(_c38)
		"openscript":
			return _n60(_c38, _j81)
		"error":
			return "## Command Error\n\n" + _c38.get("error", "Unknown command error")
		_:
			return ""

func _y52(_c38: Dictionary) -> String:
	if _a58 == null:
		return ""
	
	var _j44 = _a58._l19(_c38)

	if not _j44.get("success", false):
		var _s52 = "## File Error: " + _c38.get("path", "") + "\n\n"
		_s52 += "Could not read file: " + _j44.get("error", "Unknown error")
		return _s52

	var file_path = _j44.get("path", "")
	var _s9 = "## File: " + file_path + "\n\n"

	if _j44.get("start_line", 1) > 1 or _j44.get("end_line", -1) > 0:
		var start_line = _j44.get("start_line", 1)
		var end_line = _j44.get("end_line", -1)
		if end_line > 0:
			_s9 += "**Lines " + str(start_line) + "-" + str(end_line) + ":**\n\n"
		else:
			_s9 += "**From line " + str(start_line) + ":**\n\n"

	var language = _d21(file_path)
	var content = _j44.get("content", "")
	_s9 += "```" + language + "\n"
	_s9 += content
	if not content.ends_with("\n"):
		_s9 += "\n"
	_s9 += "```"
	
	return _s9

func _b23(_c38: Dictionary) -> String:
	if _b53 == null:
		return "## Scene Error\n\nTSCN parser not available"
	
	var scene_path = _c38.get("path", "")
	var node_path = _c38.get("node_path", "")
	var include_scripts = _c38.get("include_scripts", false)
	
	var _a96 = _b53._z99(scene_path, node_path, include_scripts)

	if not _a96.get("success", false):
		var _s52 = "## Scene Error: " + scene_path + "\n\n"
		_s52 += "Could not parse scene: " + _a96.get("error", "Unknown error")
		return _s52
	
	var _s9 = "## Scene: " + scene_path
	
	if node_path != "":
		_s9 += " (subtree: " + node_path + ")"
	
	_s9 += "\n\n"
	
	_s9 += _a96.get("filtered_content", "")
	
	if include_scripts and not _a96.get("scripts", []).is_empty():
		_s9 += "\n\n## Associated Scripts:\n\n"
		var _p96 = 0
		for _j18 in _a96.get("scripts", []):
			if _p96 >= 3:  
				_s9 += "\n... (additional scripts truncated)\n"
				break
			
			var _r21 = ""
			var _v4 = ""
			var _r46 = false
			var _s52 = ""
			
			if _j18 is Dictionary:
				_r21 = _j18.get("path", "")
				_v4 = _j18.get("content", "")
				_r46 = _j18.get("error", false)
				if _r46:
					_s52 = _v4
			else:
				_r21 = str(_j18)
				var _j57 = _w70(_r21)
				if _j57.get("success", false):
					_v4 = _j57.get("content", "")
				else:
					_r46 = true
					_s52 = _j57.get("error", "Unknown error")
			
			if not _r46 and _v4 != "":
				_s9 += "### Script: " + _r21 + "\n\n"
				_s9 += "```gdscript\n"
				_s9 += _v4
				if not _v4.ends_with("\n"):
					_s9 += "\n"
				_s9 += "```\n\n"
			elif _r46:
				_s9 += "### Script: " + _r21 + " (Error: " + _s52 + ")\n\n"
			
			_p96 += 1
	
	return _s9

func _z96(_c38: Dictionary) -> String:
	if _b53 == null or _z76 == null:
		return "## Node Error\n\nTSCN parser or editor interface not available"
	
	var node_path = _c38.get("node_path", "")
	
	var _g79 = _b53._p93(_z76, node_path)

	if not _g79.get("success", false):
		var _s52 = "## Node Error: " + node_path + "\n\n"
		_s52 += "Could not find node: " + _g79.get("error", "Unknown error")
		return _s52
	
	var _g30 = _g79.get("node", {})
	var scene_info = _g79.get("scene_info", {})
	
	var _s9 = "## Node: " + node_path + "\n\n"
	
	_s9 += "**Name:** " + _g30.get("name", "Unknown") + "\n"
	_s9 += "**Type:** " + _g30.get("type", "Unknown") + "\n"
	_s9 += "**Full Path:** " + _g30.get("full_path", "Unknown") + "\n"
	
	var parent = _g30.get("parent", "")
	if parent != "":
		_s9 += "**Parent:** " + parent + "\n"
	else:
		_s9 += "**Parent:** Root node\n"
	
	var _r21 = _g30.get("script_path", "")
	if _r21 != "":
		_s9 += "**Script:** " + _r21 + "\n\n"

		var _j57 = _w70(_r21)
		if _j57.get("success", false):
			var _c18 = _j57.get("content", "")
			_s9 += "### Script Content:\n\n"
			_s9 += "```gdscript\n"
			_s9 += _c18
			if not _c18.ends_with("\n"):
				_s9 += "\n"
			_s9 += "```\n"
		else:
			_s9 += "### Script Content: (Error: " + _j57.get("error", "Unknown error") + ")\n"
	else:
		_s9 += "**Script:** None\n"
	
	_s9 += "\n### Scene Context:\n\n"
	_s9 += "Current scene root: " + scene_info.get("root_node", "Unknown") + "\n"
	_s9 += "Total nodes in scene: " + str(scene_info.get("nodes", []).size()) + "\n"
	
	return _s9

func _w70(_r21: String) -> Dictionary:
	if _r21.begins_with("ExtResource_"):
		return {"success": false, "error": "ExtResource resolution not yet implemented"}
	
	if not _r21.begins_with("res://"):
		return {"success": false, "error": "Invalid script path: " + _r21}
	
	if not FileAccess.file_exists(_r21):
		return {"success": false, "error": "Script file not found: " + _r21}
	
	var file = FileAccess.open(_r21, FileAccess.READ)
	if file == null:
		return {"success": false, "error": "Cannot open script file: " + _r21}
	
	var content = file.get_as_text()
	file.close()
	
	var _n29 = 10000  
	if content.length() > _n29:
		content = content.substr(0, _n29) + "\n... [script truncated]"
	
	return {
		"success": true,
		"content": content,
		"path": _r21
	}

func _c94(_c38: Dictionary) -> String:
	if _a58 == null:
		return ""
	
	var _p22 = _a58._t100()

	if not _p22.get("success", false):
		return "## Selection Error\n\nNo text currently selected: " + _p22.get("error", "Unknown error")

	var _s9 = "## Selected Text"

	var _k72 = _p22.get("path", "")
	if _k72 != "":
		_s9 += " from " + _k72
	
	var start_line = _p22.get("start_line", 1)
	var end_line = _p22.get("end_line", 1)
	if start_line == end_line:
		_s9 += " (Line " + str(start_line) + ")"
	else:
		_s9 += " (Lines " + str(start_line) + "-" + str(end_line) + ")"
	
	_s9 += "\n\n"
	
	var language = _d21(_p22.get("path", ""))
	var _w44 = _p22.get("content", "")
	_s9 += "```" + language + "\n"
	_s9 += _w44
	if not _w44.ends_with("\n"):
		_s9 += "\n"
	_s9 += "```"
	
	return _s9

func _n60(_c38: Dictionary, _j81: int = -1) -> String:
	var _r21 = _c38.get("path", "")
	var _j57 = _c38.get("content", "")

	if _r21 == "" or _j57 == "":
		if _a58 == null:
			return ""

		var _d98 = _a58.get_current_script()

		if not _d98.get("success", false):
			return "## Current Script Error\n\n" + _d98.get("error", "Could not retrieve current script")

		if _r21 == "":
			_r21 = _d98.get("path", "Unknown")
		if _j57 == "":
			_j57 = _d98.get("content", "")

	if _j57 == "":
		return "## Current Script Error\n\nCould not retrieve current script content"

	if _r21 == "":
		_r21 = "current_script.gd"

	var _s9 = ""
	if _j81 > 0:
		_s9 = "## Script #%d: %s\n\n" % [_j81, _r21]
	else:
		_s9 = "## Current Script: " + _r21 + "\n\n"

	var language = _d21(_r21)
	_s9 += "```" + language + "\n"
	_s9 += _j57
	if not _j57.ends_with("\n"):
		_s9 += "\n"
	_s9 += "```"

	return _s9

func _d21(file_path: String) -> String:
	if file_path == "":
		return "gdscript"  
	
	var _s95 = file_path.get_extension().to_lower()
	
	match _s95:
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

func _j61(_s84: String) -> int:
	return int(_s84.length() / 4.0)

func _h24(_s84: String, max_tokens: int = 32000) -> Dictionary:
	var estimated_tokens = _j61(_s84)
	
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

func _n15(commands: Array) -> String:
	if commands.is_empty():
		return "No context commands"

	var _j29 = []

	for _c38 in commands:
		var _t28 = _c38.get("type", "")
		match _t28:
			"file":
				var path = _c38.get("path", "unknown")
				var _n17 = "@file " + path

				if _c38.get("start_line", -1) > 0:
					_n17 += ":" + str(_c38.get("start_line", 0)) + "-" + str(_c38.get("end_line", 0))

				if _c38.get("symbol", "") != "":
					_n17 += "#" + _c38.get("symbol", "")

				_j29.append(_n17)

			"scene":
				var path = _c38.get("path", "unknown")
				var _n17 = "@scene " + path

				if _c38.get("node_path", "") != "":
					_n17 += "#" + _c38.get("node_path", "")

				if _c38.get("include_scripts", false):
					_n17 += " --scripts"

				_j29.append(_n17)

			"node":
				var node_path = _c38.get("node_path", "unknown")
				_j29.append("@node " + node_path + " (current scene)")

			"selection":
				_j29.append("@selection (current editor selection)")

			"openscript":
				var _r21 = _c38.get("path", "")
				if _r21 == "":
					_r21 = "current script"
				_j29.append("@openscript " + _r21)

			_:
				_j29.append("@" + _t28)

	return "Context: " + ", ".join(_j29)

