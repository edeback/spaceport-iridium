@tool
class_name _b70
extends RefCounted

const _j94 = [".gd", ".tscn", ".tres", ".cfg", ".shader", ".json", ".txt", ".md"]

const _a54 = [".env", ".key", ".pem", ".exe", ".bin", ".so", ".dll", ".dylib", ".p12", ".pfx", ".crt", ".csr"]
const _n51 = [".env", "api_key", "secret", "password", "private", "token", "auth", "credential", "config", ".git", ".svn"]

const _m43 = r'@file\s+(?:"([^"]+)"|([^\s]+))(?::(\d+)-(\d+))?(?:#(\w+))?'
const _w51 = r'@scene\s+(?:"([^"]+)"|([^\s#]+))(?:#([A-Za-z0-9_/]+))?(?:\s+(--scripts))?'
const _d42 = r'@node\s+([A-Za-z0-9_/]+)'
const _a44 = r'@selection\b'
const _i42 = r'@openscript\b'

var _q86: EditorInterface
var _b50: ScriptEditor

var _f8: Dictionary = {}

var _x8: int = 0

func _init(_t15: EditorInterface = null, _c37: ScriptEditor = null):
	_q86 = _t15
	_b50 = _c37

func _f38(_c84: String) -> RegEx:
	if not _f8.has(_c84):
		var _p69 = RegEx.new()
		var _k3 = _p69.compile(_c84)
		if _k3 != OK:
			return null
		_f8[_c84] = _p69
	return _f8[_c84]

func _p93() -> String:
	_x8 += 1
	var timestamp = Time.get_ticks_msec()
	return "openscript_%d_%d" % [timestamp, _x8]

func _j31(prompt: String) -> Dictionary:
	var _k3 = {
		"commands": [],
		"cleaned_prompt": prompt
	}
	
	var _a30 = _f38(_m43)
	var _k81 = _f38(_w51)
	var _l50 = _f38(_d42)
	var _a82 = _f38(_a44)
	var _k76 = _f38(_i42)
	
	if not _a30 or not _k81 or not _l50 or not _a82 or not _k76:
		return _k3
	
	var _t74 = _a30.search_all(prompt)
	for match in _t74:
		var _r33 = _i47(match)
		if _r33 != null and not _r33.is_empty():
			_k3.commands.append(_r33)
			if _r33.get("type", "") == "error" and OS.is_debug_build():
				pass

	var _a65 = _k81.search_all(prompt)
	for match in _a65:
		var _r33 = _x88(match)
		if _r33 != null and not _r33.is_empty():
			_k3.commands.append(_r33)
			if _r33.get("type", "") == "error" and OS.is_debug_build():
				pass

	var _j21 = _l50.search_all(prompt)
	for match in _j21:
		var _r33 = _e65(match)
		if _r33 != null and not _r33.is_empty():
			_k3.commands.append(_r33)
			if _r33.get("type", "") == "error" and OS.is_debug_build():
				pass

	var _u18 = _a82.search_all(prompt)
	for match in _u18:
		var _r33 = _h50(match)
		if _r33 != null:
			_k3.commands.append(_r33)
	
	var _j100 = _k76.search_all(prompt)
	for match in _j100:
		var _r33 = _s43(match)
		if _r33 != null:
			_k3.commands.append(_r33)
	
	_k3.cleaned_prompt = _n58(prompt)
	
	return _k3

func _i47(match: RegExMatch) -> Dictionary:
	var file_path = ""
	
	if match.get_string(1) != "":  
		file_path = match.get_string(1)
	elif match.get_string(2) != "":  
		file_path = match.get_string(2)
	else:
		return {"type": "error", "error": "Invalid @file command syntax"}
	
	var _d9 = _l13(file_path)
	if not _p73(_d9):
		return {"type": "error", "error": "File not allowed: " + _d9}
	
	var _r33 = {
		"type": "file",
		"path": _d9,  
		"start_line": -1,
		"end_line": -1,
		"symbol": "",
		"full_match": match.get_string(0)
	}
	
	if match.get_string(3) != "" and match.get_string(4) != "":
		_r33["start_line"] = int(match.get_string(3))
		_r33["end_line"] = int(match.get_string(4))

	if match.get_string(5) != "":
		_r33["symbol"] = match.get_string(5)
	
	return _r33

func _h50(match: RegExMatch) -> Dictionary:
	return {
		"type": "selection",
		"full_match": match.get_string(0)
	}

func _x88(match: RegExMatch) -> Dictionary:
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
	
	var _r33 = {
		"type": "scene",
		"path": scene_path,
		"node_path": "",
		"include_scripts": false,
		"full_match": match.get_string(0)
	}
	
	if match.get_string(3) != "":
		var _q81 = match.get_string(3)
		var _o43 = _r3(_q81)
		if _o43.is_empty():
			return {"type": "error", "error": "Invalid scene node path"}
		
		if _o43.length() > 256:
			return {"type": "error", "error": "Scene node path too long"}
		
		_r33["node_path"] = _o43
	
	if match.get_string(4) == "--scripts":
		_r33["include_scripts"] = true
	
	return _r33

func _r3(node_path: String) -> String:
	var _r1 = ""
	var segments = node_path.split("/")
	
	for i in range(segments.size()):
		var _q19 = segments[i]
		if _q19.is_empty():
			if i == 0:
				_r1 += "/"
			continue
		
		var _t79 = ""
		var _m29 = true
		
		for j in range(_q19.length()):
			var char = _q19[j]
			if _m29:
				if (char >= 'A' and char <= 'Z') or (char >= 'a' and char <= 'z') or char == '_':
					_t79 += char
					_m29 = false
				else:
					continue
			else:
				if (char >= 'A' and char <= 'Z') or (char >= 'a' and char <= 'z') or (char >= '0' and char <= '9') or char == '_':
					_t79 += char
		
		if not _t79.is_empty():
			if not _r1.is_empty() and not _r1.ends_with("/"):
				_r1 += "/"
			_r1 += _t79
	
	return _r1

func _e65(match: RegExMatch) -> Dictionary:
	var node_path = match.get_string(1)
	
	if node_path == "":
		return {"type": "error", "error": "Invalid @node command syntax"}
	
	var _e24 = _r3(node_path)
	if _e24.is_empty():
		return {"type": "error", "error": "Invalid node path"}
	
	if _e24.length() > 256:
		return {"type": "error", "error": "Node path too long"}
	
	return {
		"type": "node",
		"node_path": _e24,
		"full_match": match.get_string(0)
	}

func _s43(match: RegExMatch) -> Dictionary:
	var _f75 = get_current_script()
	if not _f75.get("success", false):
		return {
			"type": "error",
			"error": _f75.get("error", "Could not retrieve current script"),
			"full_match": match.get_string(0)
		}
	
	var snapshot_id = _p93()
	
	return {
		"type": "openscript",
		"full_match": match.get_string(0),
		"path": _f75.get("path", ""),
		"content": _f75.get("content", ""),
		"snapshot_id": snapshot_id,
		"created_at": Time.get_unix_time_from_system()
	}

func _n58(prompt: String) -> String:
	var _r18 = prompt
	
	var _a30 = _f38(_m43)
	if _a30:
		_r18 = _a30.sub(_r18, "", true)
	
	var _k81 = _f38(_w51)
	if _k81:
		_r18 = _k81.sub(_r18, "", true)
	
	var _l50 = _f38(_d42)
	if _l50:
		_r18 = _l50.sub(_r18, "", true)
	
	var _a82 = _f38(_a44)
	if _a82:
		_r18 = _a82.sub(_r18, "", true)
	
	var _k76 = _f38(_i42)
	if _k76:
		_r18 = _k76.sub(_r18, "", true)
	
	var _c36 = _f38(r'\s+')
	if _c36:
		_r18 = _c36.sub(_r18, " ", true)
	_r18 = _r18.strip_edges()
	
	return _r18

func _l13(file_path: String) -> String:
	var _n4 = _f38(r':([0-9]+-[0-9]+)$')
	if _n4 and _n4.search(file_path):
		return _n4.sub(file_path, "")
	
	var _o11 = _f38(r':[0-9]+$')
	if _o11 and _o11.search(file_path):
		return _o11.sub(file_path, "")
	
	var _x15 = _f38(r'#[a-zA-Z_][a-zA-Z0-9_]*$')
	if _x15 and _x15.search(file_path):
		return _x15.sub(file_path, "")
	
	return file_path

func _h89(scene_path: String) -> bool:
	if not scene_path.to_lower().ends_with(".tscn"):
		return false
	
	if not scene_path.begins_with("res://"):
		return false
	
	if "../" in scene_path or scene_path.contains("..\\"):
		return false
	
	return true

func _p73(file_path: String) -> bool:
	if "../" in file_path or file_path.contains("..\\"):
		return false
	
	if file_path.begins_with("/") and not file_path.begins_with("res://"):
		return false
	
	if file_path.length() > 2 and file_path[1] == ":":
		return false
	
	if file_path.begins_with("~"):
		return false
	
	var _h78 = file_path.to_lower()
	var filename = file_path.get_file().to_lower()
	
	for _l76 in _a54:
		if _h78.ends_with(_l76):
			return false
	
	for _d53 in _n51:
		if filename == _d53 or filename.begins_with(_d53 + "."):
			return false
	
	for _b11 in _j94:
		if _h78.ends_with(_b11):
			return true
	
	return false

func _l8(_r33: Dictionary) -> Dictionary:
	if _r33.get("type", "") != "file":
		return {"success": false, "error": "Invalid command type"}

	var file_path = _r33.get("path", "")
	var full_path = _u100(file_path)
	
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
	
	if _r33.get("start_line", -1) > 0 and _r33.get("end_line", -1) > 0:
		var _m12 = content.split("\n")
		start_line = _r33.get("start_line", 1)
		end_line = _r33.get("end_line", -1)
		
		if start_line > _m12.size() or end_line > _m12.size() or start_line > end_line:
			return {"success": false, "error": "Invalid line range"}
		
		var _g23 = []
		for i in range(start_line - 1, end_line):
			if i < _m12.size():
				_g23.append(_m12[i])
		
		filtered_content = "\n".join(_g23)
	elif _r33.get("symbol", "") != "":
		var _b49 = _r33.get("symbol", "")
		var _d3 = _c14(content, _b49)
		if _d3.get("success", false):
			filtered_content = _d3.get("content", "")
			start_line = _d3.get("start_line", 1)
			end_line = _d3.get("end_line", -1)
		else:
			return {"success": false, "error": "Symbol not found: " + _b49}
	
	return {
		"success": true,
		"content": filtered_content,
		"path": file_path,
		"start_line": start_line,
		"end_line": end_line
	}

func _z46() -> Dictionary:
	if _b50 == null:
		return {"success": false, "error": "Script editor not available"}
	
	var _w66 = _b50.get_current_editor()
	if _w66 == null:
		return {"success": false, "error": "No script currently open"}
	
	var _g95 = _w66.get_base_editor()
	if _g95 == null:
		return {"success": false, "error": "Cannot access code editor"}
	
	var _i25 = _g95.get_selected_text()
	if _i25.is_empty():
		return {"success": false, "error": "No text selected"}
	
	var _s10 = _g95.get_selection_from_line()
	var _r10 = _g95.get_selection_to_line()
	
	var _d36 = ""
	if _w66.has_method("get_edited_resource"):
		var _u40 = _w66.get_edited_resource()
		if _u40 != null:
			_d36 = _u40.resource_path

	return {
		"success": true,
		"content": _i25,
		"path": _d36,
		"start_line": _s10 + 1,
		"end_line": _r10 + 1
	}

func get_current_script() -> Dictionary:
	if _b50 == null:
		return {"success": false, "error": "Script editor not available"}
	
	var _w66 = _b50.get_current_editor()
	if _w66 == null:
		return {"success": false, "error": "No script currently open"}
	
	var _g95 = _w66.get_base_editor()
	if _g95 == null:
		return {"success": false, "error": "Cannot access code editor"}
	
	var content = _g95.text
	if content.is_empty():
		return {"success": false, "error": "Script content is empty"}
	
	var _d36 = ""
	if _w66.has_method("get_edited_resource"):
		var _p79 = _w66.get_edited_resource()
		if _p79 != null:
			_d36 = _p79.resource_path  

	if _d36.is_empty():
		var _z18 = _b50.get_open_script_editors()
		for _p32 in _z18:
			if _p32 == _w66:
				if _p32.has_method("get_edited_resource"):
					var res = _p32.get_edited_resource()
					if res != null:
						_d36 = res.resource_path
						break

	if _d36.is_empty():
		_d36 = "[Unsaved Script]"

	var max_size = 30000  
	var _w49 = content.to_utf8_buffer().size()
	if _w49 > max_size:
		var _o12 = content.substr(0, max_size)

		var _p20 = "\n... [truncated]"
		var _x12 = _o12 + _p20
		
		if _x12.to_utf8_buffer().size() > max_size:
			var _g2 = _p20.to_utf8_buffer().size()
			var _j83 = max_size - _g2
			if _j83 > 0:
				_o12 = content.substr(0, _j83)
				content = _o12 + _p20
			else:
				content = content.substr(0, max_size)
		else:
			content = _x12
	
	return {
		"success": true,
		"path": _d36,
		"content": content
	}

func _u100(file_path: String) -> String:
	if "../" in file_path or file_path.contains("..\\"):
		return ""
	
	if file_path.begins_with("~"):
		return ""
	
	if file_path.begins_with("/") and not file_path.begins_with("res://"):
		return ""
	
	if file_path.length() > 2 and file_path[1] == ":":
		return ""
	
	if file_path.begins_with("res://"):
		var _x75 = file_path.simplify_path()

		if not _x75.begins_with("res://"):
			return ""
		return _x75
	
	var _f66 = ProjectSettings.globalize_path("res://")
	var full_path = _f66.path_join(file_path)
	
	var _o48 = full_path.simplify_path()
	
	var _u80 = ProjectSettings.globalize_path("res://").simplify_path()
	if not _o48.begins_with(_u80):
		return ""
	
	if FileAccess.file_exists(_o48):
		return _o48
	
	var _y18 = ("res://" + file_path).simplify_path()

	if not _y18.begins_with("res://"):
		return ""
	
	if FileAccess.file_exists(_y18):
		return _y18
	
	return ""

func _b30(symbol: String) -> String:
	var _r1 = ""
	var _m29 = true
	
	for i in range(symbol.length()):
		var char = symbol[i]
		if _m29:
			if (char >= 'A' and char <= 'Z') or (char >= 'a' and char <= 'z') or char == '_':
				_r1 += char
				_m29 = false
			else:
				continue
		else:
			if (char >= 'A' and char <= 'Z') or (char >= 'a' and char <= 'z') or (char >= '0' and char <= '9') or char == '_':
				_r1 += char

	return _r1

func _c14(content: String, symbol: String) -> Dictionary:
	var _q29 = _b30(symbol)
	if _q29.is_empty():
		return {"success": false, "error": "Invalid symbol name"}
	
	if _q29.length() > 128:
		return {"success": false, "error": "Symbol name too long"}
	
	var _m12 = content.split("\n")
	
	var _c79 = _f38("^\\s*func\\s+" + _q29 + "\\s*\\(")
	var _b21 = _f38("^\\s*class\\s+" + _q29 + "\\s*:")
	var _i85 = _f38("^\\s*signal\\s+" + _q29 + "\\s*")
	var _g38 = _f38("^\\s*(?:var|const)\\s+" + _q29 + "\\s*[=:]")
	
	if not _c79 or not _b21 or not _i85 or not _g38:
		return {"success": false, "error": "Failed to compile regex patterns"}
	
	for i in range(_m12.size()):
		var line = _m12[i]
		
		if _c79.search(line) or _b21.search(line) or _i85.search(line) or _g38.search(line):
			var start_line = i + 1
			var end_line = start_line
			
			if _c79.search(line) or _b21.search(line):
				var _s13 = _b12(line)
				
				for j in range(i + 1, _m12.size()):
					var _h24 = _m12[j]
					if _h24.strip_edges() == "":
						continue  
					
					var _c83 = _b12(_h24)
					if _c83 <= _s13:
						end_line = j
						break
					end_line = j + 1
			
			var _w3 = []
			for k in range(start_line - 1, min(end_line, _m12.size())):
				_w3.append(_m12[k])
			
			return {
				"success": true,
				"content": "\n".join(_w3),
				"start_line": start_line,
				"end_line": end_line
			}
	
	return {"success": false, "error": "Symbol not found"}

func _b12(line: String) -> int:
	var count = 0
	for char in line:
		if char == '\t':
			count += 4  
		elif char == ' ':
			count += 1
		else:
			break
	return count

func _c60(node: Node) -> TabContainer:
	if node is TabContainer:
		var _n32 = node as TabContainer
		if _n32.get_tab_count() > 0:
			var _r56 = _n32.get_tab_control(0)
			if _r56 != null and _a15(_r56):
				return _n32
	
	for _w15 in node.get_children():
		var _k3 = _c60(_w15)
		if _k3 != null:
			return _k3
	
	return null

func _a15(node: Node) -> bool:
	if node is CodeEdit:
		return true
	
	for _w15 in node.get_children():
		if _a15(_w15):
			return true
	
	return false

func _q64(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node
	
	for _w15 in node.get_children():
		var _k3 = _q64(_w15)
		if _k3 != null:
			return _k3
	
	return null

