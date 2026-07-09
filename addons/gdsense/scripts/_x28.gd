@tool
class_name _x28
extends RefCounted

const _h76 = [".gd", ".tscn", ".tres", ".cfg", ".shader", ".json", ".txt", ".md"]

const _o45 = [".env", ".key", ".pem", ".exe", ".bin", ".so", ".dll", ".dylib", ".p12", ".pfx", ".crt", ".csr"]
const _v9 = [".env", "api_key", "secret", "password", "private", "token", "auth", "credential", "config", ".git", ".svn"]

const _n48 = r'@file\s+(?:"([^"]+)"|([^\s]+))(?::(\d+)-(\d+))?(?:#(\w+))?'
const _t31 = r'@scene\s+(?:"([^"]+)"|([^\s#]+))(?:#([A-Za-z0-9_/]+))?(?:\s+(--scripts))?'
const _z40 = r'@node\s+([A-Za-z0-9_/]+)'
const _b16 = r'@selection\b'
const _d41 = r'@openscript\b'

var _z76: EditorInterface
var _j30: ScriptEditor

var _d15: Dictionary = {}

var _a49: int = 0

func _init(_i86: EditorInterface = null, _w75: ScriptEditor = null):
	_z76 = _i86
	_j30 = _w75

func _v50(_v48: String) -> RegEx:
	if not _d15.has(_v48):
		var _t20 = RegEx.new()
		var _v42 = _t20.compile(_v48)
		if _v42 != OK:
			return null
		_d15[_v48] = _t20
	return _d15[_v48]

func _h11() -> String:
	_a49 += 1
	var timestamp = Time.get_ticks_msec()
	return "openscript_%d_%d" % [timestamp, _a49]

func _m78(prompt: String) -> Dictionary:
	var _v42 = {
		"commands": [],
		"cleaned_prompt": prompt
	}
	
	var _r30 = _v50(_n48)
	var _b21 = _v50(_t31)
	var _a54 = _v50(_z40)
	var _f70 = _v50(_b16)
	var _k56 = _v50(_d41)
	
	if not _r30 or not _b21 or not _a54 or not _f70 or not _k56:
		return _v42
	
	var _w67 = _r30.search_all(prompt)
	for match in _w67:
		var _c38 = _h33(match)
		if _c38 != null and not _c38.is_empty():
			_v42.commands.append(_c38)
			if _c38.get("type", "") == "error" and OS.is_debug_build():
				pass

	var _f57 = _b21.search_all(prompt)
	for match in _f57:
		var _c38 = _j77(match)
		if _c38 != null and not _c38.is_empty():
			_v42.commands.append(_c38)
			if _c38.get("type", "") == "error" and OS.is_debug_build():
				pass

	var _l95 = _a54.search_all(prompt)
	for match in _l95:
		var _c38 = _u3(match)
		if _c38 != null and not _c38.is_empty():
			_v42.commands.append(_c38)
			if _c38.get("type", "") == "error" and OS.is_debug_build():
				pass

	var _i84 = _f70.search_all(prompt)
	for match in _i84:
		var _c38 = _v23(match)
		if _c38 != null:
			_v42.commands.append(_c38)
	
	var _h86 = _k56.search_all(prompt)
	for match in _h86:
		var _c38 = _a20(match)
		if _c38 != null:
			_v42.commands.append(_c38)
	
	_v42.cleaned_prompt = _o68(prompt)
	
	return _v42

func _h33(match: RegExMatch) -> Dictionary:
	var file_path = ""
	
	if match.get_string(1) != "":  
		file_path = match.get_string(1)
	elif match.get_string(2) != "":  
		file_path = match.get_string(2)
	else:
		return {"type": "error", "error": "Invalid @file command syntax"}
	
	var _a46 = _m55(file_path)
	if not _x20(_a46):
		return {"type": "error", "error": "File not allowed: " + _a46}
	
	var _c38 = {
		"type": "file",
		"path": _a46,  
		"start_line": -1,
		"end_line": -1,
		"symbol": "",
		"full_match": match.get_string(0)
	}
	
	if match.get_string(3) != "" and match.get_string(4) != "":
		_c38["start_line"] = int(match.get_string(3))
		_c38["end_line"] = int(match.get_string(4))

	if match.get_string(5) != "":
		_c38["symbol"] = match.get_string(5)
	
	return _c38

func _v23(match: RegExMatch) -> Dictionary:
	return {
		"type": "selection",
		"full_match": match.get_string(0)
	}

func _j77(match: RegExMatch) -> Dictionary:
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
	
	var _c38 = {
		"type": "scene",
		"path": scene_path,
		"node_path": "",
		"include_scripts": false,
		"full_match": match.get_string(0)
	}
	
	if match.get_string(3) != "":
		var _h13 = match.get_string(3)
		var _i34 = _h23(_h13)
		if _i34.is_empty():
			return {"type": "error", "error": "Invalid scene node path"}
		
		if _i34.length() > 256:
			return {"type": "error", "error": "Scene node path too long"}
		
		_c38["node_path"] = _i34
	
	if match.get_string(4) == "--scripts":
		_c38["include_scripts"] = true
	
	return _c38

func _h23(node_path: String) -> String:
	var _d74 = ""
	var segments = node_path.split("/")
	
	for i in range(segments.size()):
		var _w14 = segments[i]
		if _w14.is_empty():
			if i == 0:
				_d74 += "/"
			continue
		
		var _l25 = ""
		var _d49 = true
		
		for j in range(_w14.length()):
			var char = _w14[j]
			if _d49:
				if (char >= 'A' and char <= 'Z') or (char >= 'a' and char <= 'z') or char == '_':
					_l25 += char
					_d49 = false
				else:
					continue
			else:
				if (char >= 'A' and char <= 'Z') or (char >= 'a' and char <= 'z') or (char >= '0' and char <= '9') or char == '_':
					_l25 += char
		
		if not _l25.is_empty():
			if not _d74.is_empty() and not _d74.ends_with("/"):
				_d74 += "/"
			_d74 += _l25
	
	return _d74

func _u3(match: RegExMatch) -> Dictionary:
	var node_path = match.get_string(1)
	
	if node_path == "":
		return {"type": "error", "error": "Invalid @node command syntax"}
	
	var _y71 = _h23(node_path)
	if _y71.is_empty():
		return {"type": "error", "error": "Invalid node path"}
	
	if _y71.length() > 256:
		return {"type": "error", "error": "Node path too long"}
	
	return {
		"type": "node",
		"node_path": _y71,
		"full_match": match.get_string(0)
	}

func _a20(match: RegExMatch) -> Dictionary:
	var _d98 = get_current_script()
	if not _d98.get("success", false):
		return {
			"type": "error",
			"error": _d98.get("error", "Could not retrieve current script"),
			"full_match": match.get_string(0)
		}
	
	var snapshot_id = _h11()
	
	return {
		"type": "openscript",
		"full_match": match.get_string(0),
		"path": _d98.get("path", ""),
		"content": _d98.get("content", ""),
		"snapshot_id": snapshot_id,
		"created_at": Time.get_unix_time_from_system()
	}

func _o68(prompt: String) -> String:
	var _q79 = prompt
	
	var _r30 = _v50(_n48)
	if _r30:
		_q79 = _r30.sub(_q79, "", true)
	
	var _b21 = _v50(_t31)
	if _b21:
		_q79 = _b21.sub(_q79, "", true)
	
	var _a54 = _v50(_z40)
	if _a54:
		_q79 = _a54.sub(_q79, "", true)
	
	var _f70 = _v50(_b16)
	if _f70:
		_q79 = _f70.sub(_q79, "", true)
	
	var _k56 = _v50(_d41)
	if _k56:
		_q79 = _k56.sub(_q79, "", true)
	
	var _a6 = _v50(r'\s+')
	if _a6:
		_q79 = _a6.sub(_q79, " ", true)
	_q79 = _q79.strip_edges()
	
	return _q79

func _m55(file_path: String) -> String:
	var _d2 = _v50(r':([0-9]+-[0-9]+)$')
	if _d2 and _d2.search(file_path):
		return _d2.sub(file_path, "")
	
	var _v86 = _v50(r':[0-9]+$')
	if _v86 and _v86.search(file_path):
		return _v86.sub(file_path, "")
	
	var _h10 = _v50(r'#[a-zA-Z_][a-zA-Z0-9_]*$')
	if _h10 and _h10.search(file_path):
		return _h10.sub(file_path, "")
	
	return file_path

func _i94(scene_path: String) -> bool:
	if not scene_path.to_lower().ends_with(".tscn"):
		return false
	
	if not scene_path.begins_with("res://"):
		return false
	
	if "../" in scene_path or scene_path.contains("..\\"):
		return false
	
	return true

func _x20(file_path: String) -> bool:
	if "../" in file_path or file_path.contains("..\\"):
		return false
	
	if file_path.begins_with("/") and not file_path.begins_with("res://"):
		return false
	
	if file_path.length() > 2 and file_path[1] == ":":
		return false
	
	if file_path.begins_with("~"):
		return false
	
	var _n19 = file_path.to_lower()
	var filename = file_path.get_file().to_lower()
	
	for _g91 in _o45:
		if _n19.ends_with(_g91):
			return false
	
	for _u70 in _v9:
		if filename == _u70 or filename.begins_with(_u70 + "."):
			return false
	
	for _w84 in _h76:
		if _n19.ends_with(_w84):
			return true
	
	return false

func _l19(_c38: Dictionary) -> Dictionary:
	if _c38.get("type", "") != "file":
		return {"success": false, "error": "Invalid command type"}

	var file_path = _c38.get("path", "")
	var full_path = _j13(file_path)
	
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
	
	if _c38.get("start_line", -1) > 0 and _c38.get("end_line", -1) > 0:
		var _b26 = content.split("\n")
		start_line = _c38.get("start_line", 1)
		end_line = _c38.get("end_line", -1)
		
		if start_line > _b26.size() or end_line > _b26.size() or start_line > end_line:
			return {"success": false, "error": "Invalid line range"}
		
		var _n23 = []
		for i in range(start_line - 1, end_line):
			if i < _b26.size():
				_n23.append(_b26[i])
		
		filtered_content = "\n".join(_n23)
	elif _c38.get("symbol", "") != "":
		var _h16 = _c38.get("symbol", "")
		var _t32 = _x47(content, _h16)
		if _t32.get("success", false):
			filtered_content = _t32.get("content", "")
			start_line = _t32.get("start_line", 1)
			end_line = _t32.get("end_line", -1)
		else:
			return {"success": false, "error": "Symbol not found: " + _h16}
	
	return {
		"success": true,
		"content": filtered_content,
		"path": file_path,
		"start_line": start_line,
		"end_line": end_line
	}

func _t100() -> Dictionary:
	if _j30 == null:
		return {"success": false, "error": "Script editor not available"}
	
	var _f78 = _j30.get_current_editor()
	if _f78 == null:
		return {"success": false, "error": "No script currently open"}
	
	var _o58 = _f78.get_base_editor()
	if _o58 == null:
		return {"success": false, "error": "Cannot access code editor"}
	
	var _f77 = _o58.get_selected_text()
	if _f77.is_empty():
		return {"success": false, "error": "No text selected"}
	
	var _z31 = _o58.get_selection_from_line()
	var _s49 = _o58.get_selection_to_line()
	
	var _r21 = ""
	if _f78.has_method("get_edited_resource"):
		var _r15 = _f78.get_edited_resource()
		if _r15 != null:
			_r21 = _r15.resource_path

	return {
		"success": true,
		"content": _f77,
		"path": _r21,
		"start_line": _z31 + 1,
		"end_line": _s49 + 1
	}

func get_current_script() -> Dictionary:
	if _j30 == null:
		return {"success": false, "error": "Script editor not available"}
	
	var _f78 = _j30.get_current_editor()
	if _f78 == null:
		return {"success": false, "error": "No script currently open"}
	
	var _o58 = _f78.get_base_editor()
	if _o58 == null:
		return {"success": false, "error": "Cannot access code editor"}
	
	var content = _o58.text
	if content.is_empty():
		return {"success": false, "error": "Script content is empty"}
	
	var _r21 = ""
	if _f78.has_method("get_edited_resource"):
		var _y27 = _f78.get_edited_resource()
		if _y27 != null:
			_r21 = _y27.resource_path  

	if _r21.is_empty():
		var _n31 = _j30.get_open_script_editors()
		for _r48 in _n31:
			if _r48 == _f78:
				if _r48.has_method("get_edited_resource"):
					var res = _r48.get_edited_resource()
					if res != null:
						_r21 = res.resource_path
						break

	if _r21.is_empty():
		_r21 = "[Unsaved Script]"

	var max_size = 30000  
	var _p9 = content.to_utf8_buffer().size()
	if _p9 > max_size:
		var _q53 = content.substr(0, max_size)

		var _s92 = "\n... [truncated]"
		var _x30 = _q53 + _s92
		
		if _x30.to_utf8_buffer().size() > max_size:
			var _k57 = _s92.to_utf8_buffer().size()
			var _r8 = max_size - _k57
			if _r8 > 0:
				_q53 = content.substr(0, _r8)
				content = _q53 + _s92
			else:
				content = content.substr(0, max_size)
		else:
			content = _x30
	
	return {
		"success": true,
		"path": _r21,
		"content": content
	}

func _j13(file_path: String) -> String:
	if "../" in file_path or file_path.contains("..\\"):
		return ""
	
	if file_path.begins_with("~"):
		return ""
	
	if file_path.begins_with("/") and not file_path.begins_with("res://"):
		return ""
	
	if file_path.length() > 2 and file_path[1] == ":":
		return ""
	
	if file_path.begins_with("res://"):
		var _q87 = file_path.simplify_path()

		if not _q87.begins_with("res://"):
			return ""
		return _q87
	
	var _g57 = ProjectSettings.globalize_path("res://")
	var full_path = _g57.path_join(file_path)
	
	var _l87 = full_path.simplify_path()
	
	var _u57 = ProjectSettings.globalize_path("res://").simplify_path()
	if not _l87.begins_with(_u57):
		return ""
	
	if FileAccess.file_exists(_l87):
		return _l87
	
	var _v92 = ("res://" + file_path).simplify_path()

	if not _v92.begins_with("res://"):
		return ""
	
	if FileAccess.file_exists(_v92):
		return _v92
	
	return ""

func _i32(symbol: String) -> String:
	var _d74 = ""
	var _d49 = true
	
	for i in range(symbol.length()):
		var char = symbol[i]
		if _d49:
			if (char >= 'A' and char <= 'Z') or (char >= 'a' and char <= 'z') or char == '_':
				_d74 += char
				_d49 = false
			else:
				continue
		else:
			if (char >= 'A' and char <= 'Z') or (char >= 'a' and char <= 'z') or (char >= '0' and char <= '9') or char == '_':
				_d74 += char

	return _d74

func _x47(content: String, symbol: String) -> Dictionary:
	var _t73 = _i32(symbol)
	if _t73.is_empty():
		return {"success": false, "error": "Invalid symbol name"}
	
	if _t73.length() > 128:
		return {"success": false, "error": "Symbol name too long"}
	
	var _b26 = content.split("\n")
	
	var _q91 = _v50("^\\s*func\\s+" + _t73 + "\\s*\\(")
	var _k61 = _v50("^\\s*class\\s+" + _t73 + "\\s*:")
	var _c5 = _v50("^\\s*signal\\s+" + _t73 + "\\s*")
	var _o24 = _v50("^\\s*(?:var|const)\\s+" + _t73 + "\\s*[=:]")
	
	if not _q91 or not _k61 or not _c5 or not _o24:
		return {"success": false, "error": "Failed to compile regex patterns"}
	
	for i in range(_b26.size()):
		var line = _b26[i]
		
		if _q91.search(line) or _k61.search(line) or _c5.search(line) or _o24.search(line):
			var start_line = i + 1
			var end_line = start_line
			
			if _q91.search(line) or _k61.search(line):
				var _w57 = _n1(line)
				
				for j in range(i + 1, _b26.size()):
					var _q7 = _b26[j]
					if _q7.strip_edges() == "":
						continue  
					
					var _a25 = _n1(_q7)
					if _a25 <= _w57:
						end_line = j
						break
					end_line = j + 1
			
			var _i97 = []
			for k in range(start_line - 1, min(end_line, _b26.size())):
				_i97.append(_b26[k])
			
			return {
				"success": true,
				"content": "\n".join(_i97),
				"start_line": start_line,
				"end_line": end_line
			}
	
	return {"success": false, "error": "Symbol not found"}

func _n1(line: String) -> int:
	var count = 0
	for char in line:
		if char == '\t':
			count += 4  
		elif char == ' ':
			count += 1
		else:
			break
	return count

func _x54(node: Node) -> TabContainer:
	if node is TabContainer:
		var _q61 = node as TabContainer
		if _q61.get_tab_count() > 0:
			var _q68 = _q61.get_tab_control(0)
			if _q68 != null and _f18(_q68):
				return _q61
	
	for _j75 in node.get_children():
		var _v42 = _x54(_j75)
		if _v42 != null:
			return _v42
	
	return null

func _f18(node: Node) -> bool:
	if node is CodeEdit:
		return true
	
	for _j75 in node.get_children():
		if _f18(_j75):
			return true
	
	return false

func _n35(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node
	
	for _j75 in node.get_children():
		var _v42 = _n35(_j75)
		if _v42 != null:
			return _v42
	
	return null

