@tool
class_name _i81
extends RefCounted
var _z87: _i10
var _k1: _q51
var _r15: EditorInterface
func _init(_e10: _i10 = null, _k71: EditorInterface = null):
	_z87 = _e10
	_r15 = _k71
	_k1 = _q51.new()
func _s99(_j60: String, commands: Array) -> String:
	if commands.is_empty():
		return _j60
	var _w60 = []
	var _u65 = 0
	for _k52 in commands:
		var _m66 = ""
		if _k52.get("type", "") == "openscript":
			_u65 += 1
			_m66 = _g62(_k52, _u65)
		else:
			_m66 = _g62(_k52)
		if _m66 != "":
			_w60.append(_m66)
	if _w60.is_empty():
		return _j60
	var _p2 = "# Context Information\n\n"
	_p2 += "\n\n".join(_w60)
	_p2 += "\n\n---\n\n"
	_p2 += "# User Request\n\n"
	_p2 += _j60
	return _p2
func _g62(_k52: Dictionary, _l43: int = -1) -> String:
	var _k3 = _k52.get("type", "")
	match _k3:
		"file":
			return _z64(_k52)
		"scene":
			return _i53(_k52)
		"node":
			return _e6(_k52)
		"selection":
			return _f6(_k52)
		"openscript":
			return _h28(_k52, _l43)
		"error":
			return "## Command Error\n\n" + _k52.get("error", "Unknown command error")
		_:
			return ""
func _z64(_k52: Dictionary) -> String:
	if _z87 == null:
		return ""
	var _s47 = _z87._c89(_k52)
	if not _s47.get("success", false):
		var _u39 = "## File Error: " + _k52.get("path", "") + "\n\n"
		_u39 += "Could not read file: " + _s47.get("error", "Unknown error")
		return _u39
	var file_path = _s47.get("path", "")
	var _m66 = "## File: " + file_path + "\n\n"
	if _s47.get("start_line", 1) > 1 or _s47.get("end_line", -1) > 0:
		var start_line = _s47.get("start_line", 1)
		var end_line = _s47.get("end_line", -1)
		if end_line > 0:
			_m66 += "**Lines " + str(start_line) + "-" + str(end_line) + ":**\n\n"
		else:
			_m66 += "**From line " + str(start_line) + ":**\n\n"
	var language = _a56(file_path)
	var content = _s47.get("content", "")
	_m66 += "```" + language + "\n"
	_m66 += content
	if not content.ends_with("\n"):
		_m66 += "\n"
	_m66 += "```"
	return _m66
func _i53(_k52: Dictionary) -> String:
	if _k1 == null:
		return "## Scene Error\n\nTSCN parser not available"
	var scene_path = _k52.get("path", "")
	var node_path = _k52.get("node_path", "")
	var include_scripts = _k52.get("include_scripts", false)
	var _d2 = _k1._x51(scene_path, node_path, include_scripts)
	if not _d2.get("success", false):
		var _u39 = "## Scene Error: " + scene_path + "\n\n"
		_u39 += "Could not parse scene: " + _d2.get("error", "Unknown error")
		return _u39
	var _m66 = "## Scene: " + scene_path
	if node_path != "":
		_m66 += " (subtree: " + node_path + ")"
	_m66 += "\n\n"
	_m66 += _d2.get("filtered_content", "")
	if include_scripts and not _d2.get("scripts", []).is_empty():
		_m66 += "\n\n## Associated Scripts:\n\n"
		var _d46 = 0
		for _c63 in _d2.get("scripts", []):
			if _d46 >= 3:  
				_m66 += "\n... (additional scripts truncated)\n"
				break
			var _x58 = ""
			var _n90 = ""
			var _v57 = false
			var _u39 = ""
			if _c63 is Dictionary:
				_x58 = _c63.get("path", "")
				_n90 = _c63.get("content", "")
				_v57 = _c63.get("error", false)
				if _v57:
					_u39 = _n90
			else:
				_x58 = str(_c63)
				var _p30 = _s76(_x58)
				if _p30.get("success", false):
					_n90 = _p30.get("content", "")
				else:
					_v57 = true
					_u39 = _p30.get("error", "Unknown error")
			if not _v57 and _n90 != "":
				_m66 += "### Script: " + _x58 + "\n\n"
				_m66 += "```gdscript\n"
				_m66 += _n90
				if not _n90.ends_with("\n"):
					_m66 += "\n"
				_m66 += "```\n\n"
			elif _v57:
				_m66 += "### Script: " + _x58 + " (Error: " + _u39 + ")\n\n"
			_d46 += 1
	return _m66
func _e6(_k52: Dictionary) -> String:
	if _k1 == null or _r15 == null:
		return "## Node Error\n\nTSCN parser or editor interface not available"
	var node_path = _k52.get("node_path", "")
	var _h38 = _k1._f94(_r15, node_path)
	if not _h38.get("success", false):
		var _u39 = "## Node Error: " + node_path + "\n\n"
		_u39 += "Could not find node: " + _h38.get("error", "Unknown error")
		return _u39
	var _k31 = _h38.get("node", {})
	var scene_info = _h38.get("scene_info", {})
	var _m66 = "## Node: " + node_path + "\n\n"
	_m66 += "**Name:** " + _k31.get("name", "Unknown") + "\n"
	_m66 += "**Type:** " + _k31.get("type", "Unknown") + "\n"
	_m66 += "**Full Path:** " + _k31.get("full_path", "Unknown") + "\n"
	var parent = _k31.get("parent", "")
	if parent != "":
		_m66 += "**Parent:** " + parent + "\n"
	else:
		_m66 += "**Parent:** Root node\n"
	var _x58 = _k31.get("script_path", "")
	if _x58 != "":
		_m66 += "**Script:** " + _x58 + "\n\n"
		var _p30 = _s76(_x58)
		if _p30.get("success", false):
			var _m49 = _p30.get("content", "")
			_m66 += "### Script Content:\n\n"
			_m66 += "```gdscript\n"
			_m66 += _m49
			if not _m49.ends_with("\n"):
				_m66 += "\n"
			_m66 += "```\n"
		else:
			_m66 += "### Script Content: (Error: " + _p30.get("error", "Unknown error") + ")\n"
	else:
		_m66 += "**Script:** None\n"
	_m66 += "\n### Scene Context:\n\n"
	_m66 += "Current scene root: " + scene_info.get("root_node", "Unknown") + "\n"
	_m66 += "Total nodes in scene: " + str(scene_info.get("nodes", []).size()) + "\n"
	return _m66
func _s76(_x58: String) -> Dictionary:
	if _x58.begins_with("ExtResource_"):
		return {"success": false, "error": "ExtResource resolution not yet implemented"}
	if not _x58.begins_with("res://"):
		return {"success": false, "error": "Invalid script path: " + _x58}
	if not FileAccess.file_exists(_x58):
		return {"success": false, "error": "Script file not found: " + _x58}
	var file = FileAccess.open(_x58, FileAccess.READ)
	if file == null:
		return {"success": false, "error": "Cannot open script file: " + _x58}
	var content = file.get_as_text()
	file.close()
	var _g94 = 10000  
	if content.length() > _g94:
		content = content.substr(0, _g94) + "\n... [script truncated]"
	return {
		"success": true,
		"content": content,
		"path": _x58
	}
func _f6(_k52: Dictionary) -> String:
	if _z87 == null:
		return ""
	var _j9 = _z87._o92()
	if not _j9.get("success", false):
		return "## Selection Error\n\nNo text currently selected: " + _j9.get("error", "Unknown error")
	var _m66 = "## Selected Text"
	var _l83 = _j9.get("path", "")
	if _l83 != "":
		_m66 += " from " + _l83
	var start_line = _j9.get("start_line", 1)
	var end_line = _j9.get("end_line", 1)
	if start_line == end_line:
		_m66 += " (Line " + str(start_line) + ")"
	else:
		_m66 += " (Lines " + str(start_line) + "-" + str(end_line) + ")"
	_m66 += "\n\n"
	var language = _a56(_j9.get("path", ""))
	var _i91 = _j9.get("content", "")
	_m66 += "```" + language + "\n"
	_m66 += _i91
	if not _i91.ends_with("\n"):
		_m66 += "\n"
	_m66 += "```"
	return _m66
func _h28(_k52: Dictionary, _l43: int = -1) -> String:
	var _x58 = _k52.get("path", "")
	var _p30 = _k52.get("content", "")
	if _x58 == "" or _p30 == "":
		if _z87 == null:
			return ""
		var _u1 = _z87.get_current_script()
		if not _u1.get("success", false):
			return "## Current Script Error\n\n" + _u1.get("error", "Could not retrieve current script")
		if _x58 == "":
			_x58 = _u1.get("path", "Unknown")
		if _p30 == "":
			_p30 = _u1.get("content", "")
	if _p30 == "":
		return "## Current Script Error\n\nCould not retrieve current script content"
	if _x58 == "":
		_x58 = "current_script.gd"
	var _m66 = ""
	if _l43 > 0:
		_m66 = "## Script #%d: %s\n\n" % [_l43, _x58]
	else:
		_m66 = "## Current Script: " + _x58 + "\n\n"
	var language = _a56(_x58)
	_m66 += "```" + language + "\n"
	_m66 += _p30
	if not _p30.ends_with("\n"):
		_m66 += "\n"
	_m66 += "```"
	return _m66
func _a56(file_path: String) -> String:
	if file_path == "":
		return "gdscript"  
	var _x85 = file_path.get_extension().to_lower()
	match _x85:
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
func _a91(_o77: String) -> int:
	return int(_o77.length() / 4.0)
func _r90(_o77: String, max_tokens: int = 32000) -> Dictionary:
	var estimated_tokens = _a91(_o77)
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
func _w71(commands: Array) -> String:
	if commands.is_empty():
		return "No context commands"
	var _x71 = []
	for _k52 in commands:
		var _k3 = _k52.get("type", "")
		match _k3:
			"file":
				var path = _k52.get("path", "unknown")
				var _q38 = "@file " + path
				if _k52.get("start_line", -1) > 0:
					_q38 += ":" + str(_k52.get("start_line", 0)) + "-" + str(_k52.get("end_line", 0))
				if _k52.get("symbol", "") != "":
					_q38 += "#" + _k52.get("symbol", "")
				_x71.append(_q38)
			"scene":
				var path = _k52.get("path", "unknown")
				var _q38 = "@scene " + path
				if _k52.get("node_path", "") != "":
					_q38 += "#" + _k52.get("node_path", "")
				if _k52.get("include_scripts", false):
					_q38 += " --scripts"
				_x71.append(_q38)
			"node":
				var node_path = _k52.get("node_path", "unknown")
				_x71.append("@node " + node_path + " (current scene)")
			"selection":
				_x71.append("@selection (current editor selection)")
			"openscript":
				var _x58 = _k52.get("path", "")
				if _x58 == "":
					_x58 = "current script"
				_x71.append("@openscript " + _x58)
			_:
				_x71.append("@" + _k3)
	return "Context: " + ", ".join(_x71)
