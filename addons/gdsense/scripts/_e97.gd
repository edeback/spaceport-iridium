@tool
class_name _e97
extends RefCounted

const _f76 = [".gd", ".tscn", ".tres", ".cfg", ".shader", ".json", ".txt", ".md"]

const _f3 = [".env", ".key", ".pem", ".exe", ".bin", ".so", ".dll", ".dylib", ".p12", ".pfx", ".crt", ".csr"]
const _a47 = [".env", "api_key", "secret", "password", "private", "token", "auth", "credential", "config", ".git", ".svn"]

const _u55 = r'@file\s+(?:"([^"]+)"|([^\s]+))(?::(\d+)-(\d+))?(?:#(\w+))?'
const _p26 = r'@scene\s+(?:"([^"]+)"|([^\s#]+))(?:#([A-Za-z0-9_/]+))?(?:\s+(--scripts))?'
const _c1 = r'@node\s+([A-Za-z0-9_/]+)'
const _c8 = r'@selection\b'
const _j8 = r'@openscript\b'

var _b58: EditorInterface
var _i60: ScriptEditor

var _l17: Dictionary = {}

var _c85: int = 0

func _init(_f28: EditorInterface = null, _f83: ScriptEditor = null):
	_b58 = _f28
	_i60 = _f83

func _c82(_t30: String) -> RegEx:
	if not _l17.has(_t30):
		var _g88 = RegEx.new()
		var _x97 = _g88.compile(_t30)
		if _x97 != OK:
			return null
		_l17[_t30] = _g88
	return _l17[_t30]

func _s34() -> String:
	_c85 += 1
	var timestamp = Time.get_ticks_msec()
	return "openscript_%d_%d" % [timestamp, _c85]

func _n56(prompt: String) -> Dictionary:
	var _x97 = {
		"commands": [],
		"cleaned_prompt": prompt
	}
	
	var _x66 = _c82(_u55)
	var _u86 = _c82(_p26)
	var _j89 = _c82(_c1)
	var _s8 = _c82(_c8)
	var _p10 = _c82(_j8)
	
	if not _x66 or not _u86 or not _j89 or not _s8 or not _p10:
		return _x97
	
	var _d51 = _x66.search_all(prompt)
	for match in _d51:
		var _n49 = _l53(match)
		if _n49 != null and not _n49.is_empty():
			_x97.commands.append(_n49)
			if _n49.get("type", "") == "error" and OS.is_debug_build():
				pass

	var _b22 = _u86.search_all(prompt)
	for match in _b22:
		var _n49 = _n8(match)
		if _n49 != null and not _n49.is_empty():
			_x97.commands.append(_n49)
			if _n49.get("type", "") == "error" and OS.is_debug_build():
				pass

	var _b41 = _j89.search_all(prompt)
	for match in _b41:
		var _n49 = _x90(match)
		if _n49 != null and not _n49.is_empty():
			_x97.commands.append(_n49)
			if _n49.get("type", "") == "error" and OS.is_debug_build():
				pass

	var _u68 = _s8.search_all(prompt)
	for match in _u68:
		var _n49 = _j78(match)
		if _n49 != null:
			_x97.commands.append(_n49)
	
	var _v76 = _p10.search_all(prompt)
	for match in _v76:
		var _n49 = _g60(match)
		if _n49 != null:
			_x97.commands.append(_n49)
	
	_x97.cleaned_prompt = _l76(prompt)
	
	return _x97

func _l53(match: RegExMatch) -> Dictionary:
	var file_path = ""
	
	if match.get_string(1) != "":  
		file_path = match.get_string(1)
	elif match.get_string(2) != "":  
		file_path = match.get_string(2)
	else:
		return {"type": "error", "error": "Invalid @file command syntax"}
	
	var _p83 = _a66(file_path)
	if not _f40(_p83):
		return {"type": "error", "error": "File not allowed: " + _p83}
	
	var _n49 = {
		"type": "file",
		"path": _p83,  
		"start_line": -1,
		"end_line": -1,
		"symbol": "",
		"full_match": match.get_string(0)
	}
	
	if match.get_string(3) != "" and match.get_string(4) != "":
		_n49["start_line"] = int(match.get_string(3))
		_n49["end_line"] = int(match.get_string(4))

	if match.get_string(5) != "":
		_n49["symbol"] = match.get_string(5)
	
	return _n49

func _j78(match: RegExMatch) -> Dictionary:
	return {
		"type": "selection",
		"full_match": match.get_string(0)
	}

func _n8(match: RegExMatch) -> Dictionary:
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
	
	var _n49 = {
		"type": "scene",
		"path": scene_path,
		"node_path": "",
		"include_scripts": false,
		"full_match": match.get_string(0)
	}
	
	if match.get_string(3) != "":
		var _s22 = match.get_string(3)
		var _z26 = _f84(_s22)
		if _z26.is_empty():
			return {"type": "error", "error": "Invalid scene node path"}
		
		if _z26.length() > 256:
			return {"type": "error", "error": "Scene node path too long"}
		
		_n49["node_path"] = _z26
	
	if match.get_string(4) == "--scripts":
		_n49["include_scripts"] = true
	
	return _n49

func _f84(node_path: String) -> String:
	var _c70 = ""
	var segments = node_path.split("/")
	
	for i in range(segments.size()):
		var _s77 = segments[i]
		if _s77.is_empty():
			if i == 0:
				_c70 += "/"
			continue
		
		var _n89 = ""
		var _a36 = true
		
		for j in range(_s77.length()):
			var _d38 = _s77[j]
			if _a36:
				if (_d38 >= 'A' and _d38 <= 'Z') or (_d38 >= 'a' and _d38 <= 'z') or _d38 == '_':
					_n89 += _d38
					_a36 = false
				else:
					continue
			else:
				if (_d38 >= 'A' and _d38 <= 'Z') or (_d38 >= 'a' and _d38 <= 'z') or (_d38 >= '0' and _d38 <= '9') or _d38 == '_':
					_n89 += _d38
		
		if not _n89.is_empty():
			if not _c70.is_empty() and not _c70.ends_with("/"):
				_c70 += "/"
			_c70 += _n89
	
	return _c70

func _x90(match: RegExMatch) -> Dictionary:
	var node_path = match.get_string(1)
	
	if node_path == "":
		return {"type": "error", "error": "Invalid @node command syntax"}
	
	var _d22 = _f84(node_path)
	if _d22.is_empty():
		return {"type": "error", "error": "Invalid node path"}
	
	if _d22.length() > 256:
		return {"type": "error", "error": "Node path too long"}
	
	return {
		"type": "node",
		"node_path": _d22,
		"full_match": match.get_string(0)
	}

func _g60(match: RegExMatch) -> Dictionary:
	var _v28 = get_current_script()
	if not _v28.get("success", false):
		return {
			"type": "error",
			"error": _v28.get("error", "Could not retrieve current script"),
			"full_match": match.get_string(0)
		}
	
	var snapshot_id = _s34()
	
	return {
		"type": "openscript",
		"full_match": match.get_string(0),
		"path": _v28.get("path", ""),
		"content": _v28.get("content", ""),
		"snapshot_id": snapshot_id,
		"created_at": Time.get_unix_time_from_system()
	}

func _l76(prompt: String) -> String:
	var _d66 = prompt
	
	var _x66 = _c82(_u55)
	if _x66:
		_d66 = _x66.sub(_d66, "", true)
	
	var _u86 = _c82(_p26)
	if _u86:
		_d66 = _u86.sub(_d66, "", true)
	
	var _j89 = _c82(_c1)
	if _j89:
		_d66 = _j89.sub(_d66, "", true)
	
	var _s8 = _c82(_c8)
	if _s8:
		_d66 = _s8.sub(_d66, "", true)
	
	var _p10 = _c82(_j8)
	if _p10:
		_d66 = _p10.sub(_d66, "", true)
	
	var _p34 = _c82(r'\s+')
	if _p34:
		_d66 = _p34.sub(_d66, " ", true)
	_d66 = _d66.strip_edges()
	
	return _d66

func _a66(file_path: String) -> String:
	var _u31 = _c82(r':([0-9]+-[0-9]+)$')
	if _u31 and _u31.search(file_path):
		return _u31.sub(file_path, "")
	
	var _u77 = _c82(r':[0-9]+$')
	if _u77 and _u77.search(file_path):
		return _u77.sub(file_path, "")
	
	var _v41 = _c82(r'#[a-zA-Z_][a-zA-Z0-9_]*$')
	if _v41 and _v41.search(file_path):
		return _v41.sub(file_path, "")
	
	return file_path

func _t77(scene_path: String) -> bool:
	if not scene_path.to_lower().ends_with(".tscn"):
		return false
	
	if not scene_path.begins_with("res://"):
		return false
	
	if "../" in scene_path or scene_path.contains("..\\"):
		return false
	
	return true

func _f40(file_path: String) -> bool:
	if "../" in file_path or file_path.contains("..\\"):
		return false
	
	if file_path.begins_with("/") and not file_path.begins_with("res://"):
		return false
	
	if file_path.length() > 2 and file_path[1] == ":":
		return false
	
	if file_path.begins_with("~"):
		return false
	
	var _x67 = file_path.to_lower()
	var filename = file_path.get_file().to_lower()
	
	for _s47 in _f3:
		if _x67.ends_with(_s47):
			return false
	
	for _v2 in _a47:
		if filename == _v2 or filename.begins_with(_v2 + "."):
			return false
	
	for _t67 in _f76:
		if _x67.ends_with(_t67):
			return true
	
	return false

func _t68(_n49: Dictionary) -> Dictionary:
	if _n49.get("type", "") != "file":
		return {"success": false, "error": "Invalid command type"}

	var file_path = _n49.get("path", "")
	var full_path = _h52(file_path)
	
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
	
	if _n49.get("start_line", -1) > 0 and _n49.get("end_line", -1) > 0:
		var _d41 = content.split("\n")
		start_line = _n49.get("start_line", 1)
		end_line = _n49.get("end_line", -1)
		
		if start_line > _d41.size() or end_line > _d41.size() or start_line > end_line:
			return {"success": false, "error": "Invalid line range"}
		
		var _u14 = []
		for i in range(start_line - 1, end_line):
			if i < _d41.size():
				_u14.append(_d41[i])
		
		filtered_content = "\n".join(_u14)
	elif _n49.get("symbol", "") != "":
		var _a74 = _n49.get("symbol", "")
		var _o52 = _m27(content, _a74)
		if _o52.get("success", false):
			filtered_content = _o52.get("content", "")
			start_line = _o52.get("start_line", 1)
			end_line = _o52.get("end_line", -1)
		else:
			return {"success": false, "error": "Symbol not found: " + _a74}
	
	return {
		"success": true,
		"content": filtered_content,
		"path": file_path,
		"start_line": start_line,
		"end_line": end_line
	}

func _l5() -> Dictionary:
	if _i60 == null:
		return {"success": false, "error": "Script editor not available"}
	
	var _g40 = _i60.get_current_editor()
	if _g40 == null:
		return {"success": false, "error": "No script currently open"}
	
	var _v78 = _g40.get_base_editor()
	if _v78 == null:
		return {"success": false, "error": "Cannot access code editor"}
	
	var _g62 = _v78.get_selected_text()
	if _g62.is_empty():
		return {"success": false, "error": "No text selected"}
	
	var _r13 = _v78.get_selection_from_line()
	var _l49 = _v78.get_selection_to_line()
	
	var _f85 = ""
	if _g40.has_method("get_edited_resource"):
		var _j80 = _g40.get_edited_resource()
		if _j80 != null:
			_f85 = _j80.resource_path

	return {
		"success": true,
		"content": _g62,
		"path": _f85,
		"start_line": _r13 + 1,
		"end_line": _l49 + 1
	}

func get_current_script() -> Dictionary:
	if _i60 == null:
		return {"success": false, "error": "Script editor not available"}
	
	var _g40 = _i60.get_current_editor()
	if _g40 == null:
		return {"success": false, "error": "No script currently open"}
	
	var _v78 = _g40.get_base_editor()
	if _v78 == null:
		return {"success": false, "error": "Cannot access code editor"}
	
	var content = _v78.text
	if content.is_empty():
		return {"success": false, "error": "Script content is empty"}
	
	var _f85 = ""
	if _g40.has_method("get_edited_resource"):
		var _h48 = _g40.get_edited_resource()
		if _h48 != null:
			_f85 = _h48.resource_path  

	if _f85.is_empty():
		var _u60 = _i60.get_open_script_editors()
		for _l32 in _u60:
			if _l32 == _g40:
				if _l32.has_method("get_edited_resource"):
					var res = _l32.get_edited_resource()
					if res != null:
						_f85 = res.resource_path
						break

	if _f85.is_empty():
		_f85 = "[Unsaved Script]"

	var max_size = 30000  
	var _k14 = content.to_utf8_buffer().size()
	if _k14 > max_size:
		var _r69 = content.substr(0, max_size)

		var _r85 = "\n... [truncated]"
		var _w38 = _r69 + _r85
		
		if _w38.to_utf8_buffer().size() > max_size:
			var _i71 = _r85.to_utf8_buffer().size()
			var _b3 = max_size - _i71
			if _b3 > 0:
				_r69 = content.substr(0, _b3)
				content = _r69 + _r85
			else:
				content = content.substr(0, max_size)
		else:
			content = _w38
	
	return {
		"success": true,
		"path": _f85,
		"content": content
	}

func _h52(file_path: String) -> String:
	if "../" in file_path or file_path.contains("..\\"):
		return ""
	
	if file_path.begins_with("~"):
		return ""
	
	if file_path.begins_with("/") and not file_path.begins_with("res://"):
		return ""
	
	if file_path.length() > 2 and file_path[1] == ":":
		return ""
	
	if file_path.begins_with("res://"):
		var _g71 = file_path.simplify_path()

		if not _g71.begins_with("res://"):
			return ""
		return _g71
	
	var _k1 = ProjectSettings.globalize_path("res://")
	var full_path = _k1.path_join(file_path)
	
	var _e1 = full_path.simplify_path()
	
	var _t16 = ProjectSettings.globalize_path("res://").simplify_path()
	if not _e1.begins_with(_t16):
		return ""
	
	if FileAccess.file_exists(_e1):
		return _e1
	
	var _x9 = ("res://" + file_path).simplify_path()

	if not _x9.begins_with("res://"):
		return ""
	
	if FileAccess.file_exists(_x9):
		return _x9
	
	return ""

func _q74(symbol: String) -> String:
	var _c70 = ""
	var _a36 = true
	
	for i in range(symbol.length()):
		var _d38 = symbol[i]
		if _a36:
			if (_d38 >= 'A' and _d38 <= 'Z') or (_d38 >= 'a' and _d38 <= 'z') or _d38 == '_':
				_c70 += _d38
				_a36 = false
			else:
				continue
		else:
			if (_d38 >= 'A' and _d38 <= 'Z') or (_d38 >= 'a' and _d38 <= 'z') or (_d38 >= '0' and _d38 <= '9') or _d38 == '_':
				_c70 += _d38

	return _c70

func _m27(content: String, symbol: String) -> Dictionary:
	var _j63 = _q74(symbol)
	if _j63.is_empty():
		return {"success": false, "error": "Invalid symbol name"}
	
	if _j63.length() > 128:
		return {"success": false, "error": "Symbol name too long"}
	
	var _d41 = content.split("\n")
	
	var _a57 = _c82("^\\s*func\\s+" + _j63 + "\\s*\\(")
	var _j85 = _c82("^\\s*class\\s+" + _j63 + "\\s*:")
	var _z60 = _c82("^\\s*signal\\s+" + _j63 + "\\s*")
	var _e8 = _c82("^\\s*(?:var|const)\\s+" + _j63 + "\\s*[=:]")
	
	if not _a57 or not _j85 or not _z60 or not _e8:
		return {"success": false, "error": "Failed to compile regex patterns"}
	
	for i in range(_d41.size()):
		var line = _d41[i]
		
		if _a57.search(line) or _j85.search(line) or _z60.search(line) or _e8.search(line):
			var start_line = i + 1
			var end_line = start_line
			
			if _a57.search(line) or _j85.search(line):
				var _q98 = _b63(line)
				
				for j in range(i + 1, _d41.size()):
					var _k17 = _d41[j]
					if _k17.strip_edges() == "":
						continue  
					
					var _s32 = _b63(_k17)
					if _s32 <= _q98:
						end_line = j
						break
					end_line = j + 1
			
			var _k35 = []
			for k in range(start_line - 1, min(end_line, _d41.size())):
				_k35.append(_d41[k])
			
			return {
				"success": true,
				"content": "\n".join(_k35),
				"start_line": start_line,
				"end_line": end_line
			}
	
	return {"success": false, "error": "Symbol not found"}

func _b63(line: String) -> int:
	var count = 0
	for _d38 in line:
		if _d38 == '\t':
			count += 4  
		elif _d38 == ' ':
			count += 1
		else:
			break
	return count

func _k58(node: Node) -> TabContainer:
	if node is TabContainer:
		var _b49 = node as TabContainer
		if _b49.get_tab_count() > 0:
			var _s56 = _b49.get_tab_control(0)
			if _s56 != null and _c15(_s56):
				return _b49
	
	for _c100 in node.get_children():
		var _x97 = _k58(_c100)
		if _x97 != null:
			return _x97
	
	return null

func _c15(node: Node) -> bool:
	if node is CodeEdit:
		return true
	
	for _c100 in node.get_children():
		if _c15(_c100):
			return true
	
	return false

func _v90(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node
	
	for _c100 in node.get_children():
		var _x97 = _v90(_c100)
		if _x97 != null:
			return _x97
	
	return null

