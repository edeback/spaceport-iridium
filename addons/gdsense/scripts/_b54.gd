@tool
class_name _b54
extends RefCounted

var _g78: _b70
var _o69: _l17
var _q86: EditorInterface

func _init(_g48: _b70 = null, _t15: EditorInterface = null):
	_g78 = _g48
	_q86 = _t15
	_o69 = _l17.new()

func _s56(_z34: String, commands: Array) -> String:
	if commands.is_empty():
		return _z34

	var _y96 = []

	var _k55 = 0

	for _r33 in commands:
		var _f36 = ""

		if _r33.get("type", "") == "openscript":
			_k55 += 1
			_f36 = _f64(_r33, _k55)
		else:
			_f36 = _f64(_r33)

		if _f36 != "":
			_y96.append(_f36)

	if _y96.is_empty():
		return _z34

	var _d26 = "# Context Information\n\n"
	_d26 += "\n\n".join(_y96)
	_d26 += "\n\n---\n\n"
	_d26 += "# User Request\n\n"
	_d26 += _z34

	return _d26

func _f64(_r33: Dictionary, _p8: int = -1) -> String:
	var _m93 = _r33.get("type", "")
	match _m93:
		"file":
			return _u90(_r33)
		"scene":
			return _w68(_r33)
		"node":
			return _v52(_r33)
		"selection":
			return _g41(_r33)
		"openscript":
			return _h81(_r33, _p8)
		"error":
			return "## Command Error\n\n" + _r33.get("error", "Unknown command error")
		_:
			return ""

func _u90(_r33: Dictionary) -> String:
	if _g78 == null:
		return ""
	
	var _d29 = _g78._l8(_r33)

	if not _d29.get("success", false):
		var _p59 = "## File Error: " + _r33.get("path", "") + "\n\n"
		_p59 += "Could not read file: " + _d29.get("error", "Unknown error")
		return _p59

	var file_path = _d29.get("path", "")
	var _f36 = "## File: " + file_path + "\n\n"

	if _d29.get("start_line", 1) > 1 or _d29.get("end_line", -1) > 0:
		var start_line = _d29.get("start_line", 1)
		var end_line = _d29.get("end_line", -1)
		if end_line > 0:
			_f36 += "**Lines " + str(start_line) + "-" + str(end_line) + ":**\n\n"
		else:
			_f36 += "**From line " + str(start_line) + ":**\n\n"

	var language = _q78(file_path)
	var content = _d29.get("content", "")
	_f36 += "```" + language + "\n"
	_f36 += content
	if not content.ends_with("\n"):
		_f36 += "\n"
	_f36 += "```"
	
	return _f36

func _w68(_r33: Dictionary) -> String:
	if _o69 == null:
		return "## Scene Error\n\nTSCN parser not available"
	
	var scene_path = _r33.get("path", "")
	var node_path = _r33.get("node_path", "")
	var include_scripts = _r33.get("include_scripts", false)
	
	var _d45 = _o69._l46(scene_path, node_path, include_scripts)

	if not _d45.get("success", false):
		var _p59 = "## Scene Error: " + scene_path + "\n\n"
		_p59 += "Could not parse scene: " + _d45.get("error", "Unknown error")
		return _p59
	
	var _f36 = "## Scene: " + scene_path
	
	if node_path != "":
		_f36 += " (subtree: " + node_path + ")"
	
	_f36 += "\n\n"
	
	_f36 += _d45.get("filtered_content", "")
	
	if include_scripts and not _d45.get("scripts", []).is_empty():
		_f36 += "\n\n## Associated Scripts:\n\n"
		var _d23 = 0
		for _o93 in _d45.get("scripts", []):
			if _d23 >= 3:  
				_f36 += "\n... (additional scripts truncated)\n"
				break
			
			var _d36 = ""
			var _x68 = ""
			var _j49 = false
			var _p59 = ""
			
			if _o93 is Dictionary:
				_d36 = _o93.get("path", "")
				_x68 = _o93.get("content", "")
				_j49 = _o93.get("error", false)
				if _j49:
					_p59 = _x68
			else:
				_d36 = str(_o93)
				var _l72 = _z25(_d36)
				if _l72.get("success", false):
					_x68 = _l72.get("content", "")
				else:
					_j49 = true
					_p59 = _l72.get("error", "Unknown error")
			
			if not _j49 and _x68 != "":
				_f36 += "### Script: " + _d36 + "\n\n"
				_f36 += "```gdscript\n"
				_f36 += _x68
				if not _x68.ends_with("\n"):
					_f36 += "\n"
				_f36 += "```\n\n"
			elif _j49:
				_f36 += "### Script: " + _d36 + " (Error: " + _p59 + ")\n\n"
			
			_d23 += 1
	
	return _f36

func _v52(_r33: Dictionary) -> String:
	if _o69 == null or _q86 == null:
		return "## Node Error\n\nTSCN parser or editor interface not available"
	
	var node_path = _r33.get("node_path", "")
	
	var _k19 = _o69._s23(_q86, node_path)

	if not _k19.get("success", false):
		var _p59 = "## Node Error: " + node_path + "\n\n"
		_p59 += "Could not find node: " + _k19.get("error", "Unknown error")
		return _p59
	
	var _p92 = _k19.get("node", {})
	var scene_info = _k19.get("scene_info", {})
	
	var _f36 = "## Node: " + node_path + "\n\n"
	
	_f36 += "**Name:** " + _p92.get("name", "Unknown") + "\n"
	_f36 += "**Type:** " + _p92.get("type", "Unknown") + "\n"
	_f36 += "**Full Path:** " + _p92.get("full_path", "Unknown") + "\n"
	
	var parent = _p92.get("parent", "")
	if parent != "":
		_f36 += "**Parent:** " + parent + "\n"
	else:
		_f36 += "**Parent:** Root node\n"
	
	var _d36 = _p92.get("script_path", "")
	if _d36 != "":
		_f36 += "**Script:** " + _d36 + "\n\n"

		var _l72 = _z25(_d36)
		if _l72.get("success", false):
			var _c69 = _l72.get("content", "")
			_f36 += "### Script Content:\n\n"
			_f36 += "```gdscript\n"
			_f36 += _c69
			if not _c69.ends_with("\n"):
				_f36 += "\n"
			_f36 += "```\n"
		else:
			_f36 += "### Script Content: (Error: " + _l72.get("error", "Unknown error") + ")\n"
	else:
		_f36 += "**Script:** None\n"
	
	_f36 += "\n### Scene Context:\n\n"
	_f36 += "Current scene root: " + scene_info.get("root_node", "Unknown") + "\n"
	_f36 += "Total nodes in scene: " + str(scene_info.get("nodes", []).size()) + "\n"
	
	return _f36

func _z25(_d36: String) -> Dictionary:
	if _d36.begins_with("ExtResource_"):
		return {"success": false, "error": "ExtResource resolution not yet implemented"}
	
	if not _d36.begins_with("res://"):
		return {"success": false, "error": "Invalid script path: " + _d36}
	
	if not FileAccess.file_exists(_d36):
		return {"success": false, "error": "Script file not found: " + _d36}
	
	var file = FileAccess.open(_d36, FileAccess.READ)
	if file == null:
		return {"success": false, "error": "Cannot open script file: " + _d36}
	
	var content = file.get_as_text()
	file.close()
	
	var _c20 = 10000  
	if content.length() > _c20:
		content = content.substr(0, _c20) + "\n... [script truncated]"
	
	return {
		"success": true,
		"content": content,
		"path": _d36
	}

func _g41(_r33: Dictionary) -> String:
	if _g78 == null:
		return ""
	
	var _c90 = _g78._z46()

	if not _c90.get("success", false):
		return "## Selection Error\n\nNo text currently selected: " + _c90.get("error", "Unknown error")

	var _f36 = "## Selected Text"

	var _o82 = _c90.get("path", "")
	if _o82 != "":
		_f36 += " from " + _o82
	
	var start_line = _c90.get("start_line", 1)
	var end_line = _c90.get("end_line", 1)
	if start_line == end_line:
		_f36 += " (Line " + str(start_line) + ")"
	else:
		_f36 += " (Lines " + str(start_line) + "-" + str(end_line) + ")"
	
	_f36 += "\n\n"
	
	var language = _q78(_c90.get("path", ""))
	var _a67 = _c90.get("content", "")
	_f36 += "```" + language + "\n"
	_f36 += _a67
	if not _a67.ends_with("\n"):
		_f36 += "\n"
	_f36 += "```"
	
	return _f36

func _h81(_r33: Dictionary, _p8: int = -1) -> String:
	var _d36 = _r33.get("path", "")
	var _l72 = _r33.get("content", "")

	if _d36 == "" or _l72 == "":
		if _g78 == null:
			return ""

		var _f75 = _g78.get_current_script()

		if not _f75.get("success", false):
			return "## Current Script Error\n\n" + _f75.get("error", "Could not retrieve current script")

		if _d36 == "":
			_d36 = _f75.get("path", "Unknown")
		if _l72 == "":
			_l72 = _f75.get("content", "")

	if _l72 == "":
		return "## Current Script Error\n\nCould not retrieve current script content"

	if _d36 == "":
		_d36 = "current_script.gd"

	var _f36 = ""
	if _p8 > 0:
		_f36 = "## Script #%d: %s\n\n" % [_p8, _d36]
	else:
		_f36 = "## Current Script: " + _d36 + "\n\n"

	var language = _q78(_d36)
	_f36 += "```" + language + "\n"
	_f36 += _l72
	if not _l72.ends_with("\n"):
		_f36 += "\n"
	_f36 += "```"

	return _f36

func _q78(file_path: String) -> String:
	if file_path == "":
		return "gdscript"  
	
	var _s83 = file_path.get_extension().to_lower()
	
	match _s83:
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

func _r64(_e17: String) -> int:
	return int(_e17.length() / 4.0)

func _c78(_e17: String, max_tokens: int = 32000) -> Dictionary:
	var estimated_tokens = _r64(_e17)
	
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

func _d92(commands: Array) -> String:
	if commands.is_empty():
		return "No context commands"

	var _x89 = []

	for _r33 in commands:
		var _m93 = _r33.get("type", "")
		match _m93:
			"file":
				var path = _r33.get("path", "unknown")
				var _o96 = "@file " + path

				if _r33.get("start_line", -1) > 0:
					_o96 += ":" + str(_r33.get("start_line", 0)) + "-" + str(_r33.get("end_line", 0))

				if _r33.get("symbol", "") != "":
					_o96 += "#" + _r33.get("symbol", "")

				_x89.append(_o96)

			"scene":
				var path = _r33.get("path", "unknown")
				var _o96 = "@scene " + path

				if _r33.get("node_path", "") != "":
					_o96 += "#" + _r33.get("node_path", "")

				if _r33.get("include_scripts", false):
					_o96 += " --scripts"

				_x89.append(_o96)

			"node":
				var node_path = _r33.get("node_path", "unknown")
				_x89.append("@node " + node_path + " (current scene)")

			"selection":
				_x89.append("@selection (current editor selection)")

			"openscript":
				var _d36 = _r33.get("path", "")
				if _d36 == "":
					_d36 = "current script"
				_x89.append("@openscript " + _d36)

			_:
				_x89.append("@" + _m93)

	return "Context: " + ", ".join(_x89)

