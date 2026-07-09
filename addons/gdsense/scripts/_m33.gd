@tool
class_name _m33
extends RefCounted
const _j38 = [".gd", ".tscn", ".tres", ".cfg", ".shader", ".json", ".txt", ".md"]
const _w14 = [".env", ".key", ".pem", ".exe", ".bin", ".so", ".dll", ".dylib", ".p12", ".pfx", ".crt", ".csr"]
const _g9 = [".env", "api_key", "secret", "password", "private", "token", "auth", "credential", "config", ".git", ".svn"]
const _b74 = r'@file\s+(?:"([^"]+)"|([^\s]+))(?::(\d+)-(\d+))?(?:#(\w+))?'
const _f53 = r'@scene\s+(?:"([^"]+)"|([^\s#]+))(?:#([A-Za-z0-9_/]+))?(?:\s+(--scripts))?'
const _u71 = r'@node\s+([A-Za-z0-9_/]+)'
const _v20 = r'@selection\b'
const _d1 = r'@openscript\b'
var _b72: EditorInterface
var _y14: ScriptEditor
var _g80: Dictionary = {}
var _q67: int = 0
func _init(_o10: EditorInterface = null, _x62: ScriptEditor = null):
	_b72 = _o10
	_y14 = _x62
func _h91(_a45: String) -> RegEx:
	if not _g80.has(_a45):
		var _s2 = RegEx.new()
		var _n37 = _s2.compile(_a45)
		if _n37 != OK:
			return null
		_g80[_a45] = _s2
	return _g80[_a45]
func _j76() -> String:
	_q67 += 1
	var timestamp = Time.get_ticks_msec()
	return "openscript_%d_%d" % [timestamp, _q67]
func _w35(prompt: String) -> Dictionary:
	var _n37 = {
		"commands": [],
		"cleaned_prompt": prompt
	}
	var _h73 = _h91(_b74)
	var _e67 = _h91(_f53)
	var _y69 = _h91(_u71)
	var _s86 = _h91(_v20)
	var _k23 = _h91(_d1)
	if not _h73 or not _e67 or not _y69 or not _s86 or not _k23:
		return _n37
	var _e99 = _h73.search_all(prompt)
	for match in _e99:
		var _y59 = _t71(match)
		if _y59 != null and not _y59.is_empty():
			_n37.commands.append(_y59)
			if _y59.get("type", "") == "error" and OS.is_debug_build():
				pass
	var _e51 = _e67.search_all(prompt)
	for match in _e51:
		var _y59 = _q86(match)
		if _y59 != null and not _y59.is_empty():
			_n37.commands.append(_y59)
			if _y59.get("type", "") == "error" and OS.is_debug_build():
				pass
	var _e54 = _y69.search_all(prompt)
	for match in _e54:
		var _y59 = _q76(match)
		if _y59 != null and not _y59.is_empty():
			_n37.commands.append(_y59)
			if _y59.get("type", "") == "error" and OS.is_debug_build():
				pass
	var _c60 = _s86.search_all(prompt)
	for match in _c60:
		var _y59 = _d37(match)
		if _y59 != null:
			_n37.commands.append(_y59)
	var _x30 = _k23.search_all(prompt)
	for match in _x30:
		var _y59 = _w65(match)
		if _y59 != null:
			_n37.commands.append(_y59)
	_n37.cleaned_prompt = _r73(prompt)
	return _n37
func _t71(match: RegExMatch) -> Dictionary:
	var file_path = ""
	if match.get_string(1) != "":  
		file_path = match.get_string(1)
	elif match.get_string(2) != "":  
		file_path = match.get_string(2)
	else:
		return {"type": "error", "error": "Invalid @file command syntax"}
	var _d11 = _y40(file_path)
	if not _o86(_d11):
		return {"type": "error", "error": "File not allowed: " + _d11}
	var _y59 = {
		"type": "file",
		"path": _d11,  
		"start_line": -1,
		"end_line": -1,
		"symbol": "",
		"full_match": match.get_string(0)
	}
	if match.get_string(3) != "" and match.get_string(4) != "":
		_y59["start_line"] = int(match.get_string(3))
		_y59["end_line"] = int(match.get_string(4))
	if match.get_string(5) != "":
		_y59["symbol"] = match.get_string(5)
	return _y59
func _d37(match: RegExMatch) -> Dictionary:
	return {
		"type": "selection",
		"full_match": match.get_string(0)
	}
func _q86(match: RegExMatch) -> Dictionary:
	var scene_path = ""
	if match.get_string(1) != "":  
		scene_path = match.get_string(1)
	elif match.get_string(2) != "":  
		scene_path = match.get_string(2)
	else:
		return {"type": "error", "error": "Invalid @scene command syntax"}
	if "../" in scene_path or scene_path.contains("..\\"):
		return {"type": "error", "error": "Security: Path traversal attempt blocked: " + scene_path}
	if not scene_path.to_lower().ends_with(".tscn"):
		return {"type": "error", "error": "@scene command requires .tscn file: " + scene_path}
	if not scene_path.begins_with("res://"):
		return {"type": "error", "error": "Scene files must use res:// paths: " + scene_path}
	var _y59 = {
		"type": "scene",
		"path": scene_path,
		"node_path": "",
		"include_scripts": false,
		"full_match": match.get_string(0)
	}
	if match.get_string(3) != "":
		var _o19 = match.get_string(3)
		var _w31 = _n19(_o19)
		if _w31.is_empty():
			return {"type": "error", "error": "Invalid scene node path"}
		if _w31.length() > 256:
			return {"type": "error", "error": "Scene node path too long"}
		_y59["node_path"] = _w31
	if match.get_string(4) == "--scripts":
		_y59["include_scripts"] = true
	return _y59
func _n19(node_path: String) -> String:
	var _x22 = ""
	var segments = node_path.split("/")
	for i in range(segments.size()):
		var _x80 = segments[i]
		if _x80.is_empty():
			if i == 0:
				_x22 += "/"
			continue
		var _s77 = ""
		var _q7 = true
		for j in range(_x80.length()):
			var _c28 = _x80[j]
			if _q7:
				if (_c28 >= 'A' and _c28 <= 'Z') or (_c28 >= 'a' and _c28 <= 'z') or _c28 == '_':
					_s77 += _c28
					_q7 = false
				else:
					continue
			else:
				if (_c28 >= 'A' and _c28 <= 'Z') or (_c28 >= 'a' and _c28 <= 'z') or (_c28 >= '0' and _c28 <= '9') or _c28 == '_':
					_s77 += _c28
		if not _s77.is_empty():
			if not _x22.is_empty() and not _x22.ends_with("/"):
				_x22 += "/"
			_x22 += _s77
	return _x22
func _q76(match: RegExMatch) -> Dictionary:
	var node_path = match.get_string(1)
	if node_path == "":
		return {"type": "error", "error": "Invalid @node command syntax"}
	var _e98 = _n19(node_path)
	if _e98.is_empty():
		return {"type": "error", "error": "Invalid node path"}
	if _e98.length() > 256:
		return {"type": "error", "error": "Node path too long"}
	return {
		"type": "node",
		"node_path": _e98,
		"full_match": match.get_string(0)
	}
func _w65(match: RegExMatch) -> Dictionary:
	var _o73 = get_current_script()
	if not _o73.get("success", false):
		return {
			"type": "error",
			"error": _o73.get("error", "Could not retrieve current script"),
			"full_match": match.get_string(0)
		}
	var snapshot_id = _j76()
	return {
		"type": "openscript",
		"full_match": match.get_string(0),
		"path": _o73.get("path", ""),
		"content": _o73.get("content", ""),
		"snapshot_id": snapshot_id,
		"created_at": Time.get_unix_time_from_system()
	}
func _r73(prompt: String) -> String:
	var _b35 = prompt
	var _h73 = _h91(_b74)
	if _h73:
		_b35 = _h73.sub(_b35, "", true)
	var _e67 = _h91(_f53)
	if _e67:
		_b35 = _e67.sub(_b35, "", true)
	var _y69 = _h91(_u71)
	if _y69:
		_b35 = _y69.sub(_b35, "", true)
	var _s86 = _h91(_v20)
	if _s86:
		_b35 = _s86.sub(_b35, "", true)
	var _k23 = _h91(_d1)
	if _k23:
		_b35 = _k23.sub(_b35, "", true)
	var _j74 = _h91(r'\s+')
	if _j74:
		_b35 = _j74.sub(_b35, " ", true)
	_b35 = _b35.strip_edges()
	return _b35
func _y40(file_path: String) -> String:
	var _a48 = _h91(r':([0-9]+-[0-9]+)$')
	if _a48 and _a48.search(file_path):
		return _a48.sub(file_path, "")
	var _n43 = _h91(r':[0-9]+$')
	if _n43 and _n43.search(file_path):
		return _n43.sub(file_path, "")
	var _a61 = _h91(r'#[a-zA-Z_][a-zA-Z0-9_]*$')
	if _a61 and _a61.search(file_path):
		return _a61.sub(file_path, "")
	return file_path
func _b83(scene_path: String) -> bool:
	if not scene_path.to_lower().ends_with(".tscn"):
		return false
	if not scene_path.begins_with("res://"):
		return false
	if "../" in scene_path or scene_path.contains("..\\"):
		return false
	return true
func _o86(file_path: String) -> bool:
	if "../" in file_path or file_path.contains("..\\"):
		return false
	if file_path.begins_with("/") and not file_path.begins_with("res://"):
		return false
	if file_path.length() > 2 and file_path[1] == ":":
		return false
	if file_path.begins_with("~"):
		return false
	var _r31 = file_path.to_lower()
	var filename = file_path.get_file().to_lower()
	for _e25 in _w14:
		if _r31.ends_with(_e25):
			return false
	for _c10 in _g9:
		if filename == _c10 or filename.begins_with(_c10 + "."):
			return false
	for _z87 in _j38:
		if _r31.ends_with(_z87):
			return true
	return false
func _s65(_y59: Dictionary) -> Dictionary:
	if _y59.get("type", "") != "file":
		return {"success": false, "error": "Invalid command type"}
	var file_path = _y59.get("path", "")
	var full_path = _k79(file_path)
	if full_path.is_empty():
		return {"success": false, "error": "File path not allowed or invalid: " + file_path}
	if not FileAccess.file_exists(full_path):
		return {"success": false, "error": "File not found: " + file_path}
	var file = FileAccess.open(full_path, FileAccess.READ)
	if file == null:
		return {"success": false, "error": "Cannot open file: " + file_path}
	var content = file.get_as_text()
	file.close()
	var filtered_content = content
	var start_line = 1
	var end_line = -1
	if _y59.get("start_line", -1) > 0 and _y59.get("end_line", -1) > 0:
		var _a62 = content.split("\n")
		start_line = _y59.get("start_line", 1)
		end_line = _y59.get("end_line", -1)
		if start_line > _a62.size() or end_line > _a62.size() or start_line > end_line:
			return {"success": false, "error": "Invalid line range"}
		var _e46 = []
		for i in range(start_line - 1, end_line):
			if i < _a62.size():
				_e46.append(_a62[i])
		filtered_content = "\n".join(_e46)
	elif _y59.get("symbol", "") != "":
		var _f82 = _y59.get("symbol", "")
		var _x86 = _u75(content, _f82)
		if _x86.get("success", false):
			filtered_content = _x86.get("content", "")
			start_line = _x86.get("start_line", 1)
			end_line = _x86.get("end_line", -1)
		else:
			return {"success": false, "error": "Symbol not found: " + _f82}
	return {
		"success": true,
		"content": filtered_content,
		"path": file_path,
		"start_line": start_line,
		"end_line": end_line
	}
func _m29() -> Dictionary:
	if _y14 == null:
		return {"success": false, "error": "Script editor not available"}
	var _l100 = _y14.get_current_editor()
	if _l100 == null:
		return {"success": false, "error": "No script currently open"}
	var _t5 = _l100.get_base_editor()
	if _t5 == null:
		return {"success": false, "error": "Cannot access code editor"}
	var _t48 = _t5.get_selected_text()
	if _t48.is_empty():
		return {"success": false, "error": "No text selected"}
	var _l41 = _t5.get_selection_from_line()
	var _v55 = _t5.get_selection_to_line()
	var _s100 = ""
	if _l100.has_method("get_edited_resource"):
		var _k5 = _l100.get_edited_resource()
		if _k5 != null:
			_s100 = _k5.resource_path
	return {
		"success": true,
		"content": _t48,
		"path": _s100,
		"start_line": _l41 + 1,
		"end_line": _v55 + 1
	}
func get_current_script() -> Dictionary:
	if _y14 == null:
		return {"success": false, "error": "Script editor not available"}
	var _l100 = _y14.get_current_editor()
	if _l100 == null:
		return {"success": false, "error": "No script currently open"}
	var _t5 = _l100.get_base_editor()
	if _t5 == null:
		return {"success": false, "error": "Cannot access code editor"}
	var content = _t5.text
	if content.is_empty():
		return {"success": false, "error": "Script content is empty"}
	var _s100 = ""
	if _l100.has_method("get_edited_resource"):
		var _s9 = _l100.get_edited_resource()
		if _s9 != null:
			_s100 = _s9.resource_path  
	if _s100.is_empty():
		var _h95 = _y14.get_open_script_editors()
		for _j50 in _h95:
			if _j50 == _l100:
				if _j50.has_method("get_edited_resource"):
					var res = _j50.get_edited_resource()
					if res != null:
						_s100 = res.resource_path
						break
	if _s100.is_empty():
		_s100 = "[Unsaved Script]"
	var max_size = 30000  
	var _j73 = content.to_utf8_buffer().size()
	if _j73 > max_size:
		var _z80 = content.substr(0, max_size)
		var _e88 = "\n... [truncated]"
		var _v31 = _z80 + _e88
		if _v31.to_utf8_buffer().size() > max_size:
			var _z86 = _e88.to_utf8_buffer().size()
			var _d98 = max_size - _z86
			if _d98 > 0:
				_z80 = content.substr(0, _d98)
				content = _z80 + _e88
			else:
				content = content.substr(0, max_size)
		else:
			content = _v31
	return {
		"success": true,
		"path": _s100,
		"content": content
	}
func _k79(file_path: String) -> String:
	if "../" in file_path or file_path.contains("..\\"):
		return ""
	if file_path.begins_with("~"):
		return ""
	if file_path.begins_with("/") and not file_path.begins_with("res://"):
		return ""
	if file_path.length() > 2 and file_path[1] == ":":
		return ""
	if file_path.begins_with("res://"):
		var _n71 = file_path.simplify_path()
		if not _n71.begins_with("res://"):
			return ""
		return _n71
	var _z76 = ProjectSettings.globalize_path("res://")
	var full_path = _z76.path_join(file_path)
	var _f6 = full_path.simplify_path()
	var _a81 = ProjectSettings.globalize_path("res://").simplify_path()
	if not _f6.begins_with(_a81):
		return ""
	if FileAccess.file_exists(_f6):
		return _f6
	var _v15 = ("res://" + file_path).simplify_path()
	if not _v15.begins_with("res://"):
		return ""
	if FileAccess.file_exists(_v15):
		return _v15
	return ""
func _f99(symbol: String) -> String:
	var _x22 = ""
	var _q7 = true
	for i in range(symbol.length()):
		var _c28 = symbol[i]
		if _q7:
			if (_c28 >= 'A' and _c28 <= 'Z') or (_c28 >= 'a' and _c28 <= 'z') or _c28 == '_':
				_x22 += _c28
				_q7 = false
			else:
				continue
		else:
			if (_c28 >= 'A' and _c28 <= 'Z') or (_c28 >= 'a' and _c28 <= 'z') or (_c28 >= '0' and _c28 <= '9') or _c28 == '_':
				_x22 += _c28
	return _x22
func _u75(content: String, symbol: String) -> Dictionary:
	var _w67 = _f99(symbol)
	if _w67.is_empty():
		return {"success": false, "error": "Invalid symbol name"}
	if _w67.length() > 128:
		return {"success": false, "error": "Symbol name too long"}
	var _a62 = content.split("\n")
	var _q82 = _h91("^\\s*func\\s+" + _w67 + "\\s*\\(")
	var _f83 = _h91("^\\s*class\\s+" + _w67 + "\\s*:")
	var _u60 = _h91("^\\s*signal\\s+" + _w67 + "\\s*")
	var _j49 = _h91("^\\s*(?:var|const)\\s+" + _w67 + "\\s*[=:]")
	if not _q82 or not _f83 or not _u60 or not _j49:
		return {"success": false, "error": "Failed to compile regex patterns"}
	for i in range(_a62.size()):
		var line = _a62[i]
		if _q82.search(line) or _f83.search(line) or _u60.search(line) or _j49.search(line):
			var start_line = i + 1
			var end_line = start_line
			if _q82.search(line) or _f83.search(line):
				var _u78 = _z69(line)
				for j in range(i + 1, _a62.size()):
					var _y56 = _a62[j]
					if _y56.strip_edges() == "":
						continue  
					var _s99 = _z69(_y56)
					if _s99 <= _u78:
						end_line = j
						break
					end_line = j + 1
			var _d92 = []
			for k in range(start_line - 1, min(end_line, _a62.size())):
				_d92.append(_a62[k])
			return {
				"success": true,
				"content": "\n".join(_d92),
				"start_line": start_line,
				"end_line": end_line
			}
	return {"success": false, "error": "Symbol not found"}
func _z69(line: String) -> int:
	var count = 0
	for _c28 in line:
		if _c28 == '\t':
			count += 4  
		elif _c28 == ' ':
			count += 1
		else:
			break
	return count
func _y63(node: Node) -> TabContainer:
	if node is TabContainer:
		var _v82 = node as TabContainer
		if _v82.get_tab_count() > 0:
			var _n42 = _v82.get_tab_control(0)
			if _n42 != null and _u10(_n42):
				return _v82
	for _i64 in node.get_children():
		var _n37 = _y63(_i64)
		if _n37 != null:
			return _n37
	return null
func _u10(node: Node) -> bool:
	if node is CodeEdit:
		return true
	for _i64 in node.get_children():
		if _u10(_i64):
			return true
	return false
func _a7(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node
	for _i64 in node.get_children():
		var _n37 = _a7(_i64)
		if _n37 != null:
			return _n37
	return null
