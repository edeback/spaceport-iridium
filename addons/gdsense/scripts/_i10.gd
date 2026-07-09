@tool
class_name _i10
extends RefCounted
const _r25 = [".gd", ".tscn", ".tres", ".cfg", ".shader", ".json", ".txt", ".md"]
const _v14 = [".env", ".key", ".pem", ".exe", ".bin", ".so", ".dll", ".dylib", ".p12", ".pfx", ".crt", ".csr"]
const _z40 = [".env", "api_key", "secret", "password", "private", "token", "auth", "credential", "config", ".git", ".svn"]
const _j26 = r'@file\s+(?:"([^"]+)"|([^\s]+))(?::(\d+)-(\d+))?(?:#(\w+))?'
const _o14 = r'@scene\s+(?:"([^"]+)"|([^\s#]+))(?:#([A-Za-z0-9_/]+))?(?:\s+(--scripts))?'
const _w70 = r'@node\s+([A-Za-z0-9_/]+)'
const _k98 = r'@selection\b'
const _s65 = r'@openscript\b'
var _r15: EditorInterface
var _e3: ScriptEditor
var _m93: Dictionary = {}
var _w95: int = 0
func _init(_k71: EditorInterface = null, _y11: ScriptEditor = null):
	_r15 = _k71
	_e3 = _y11
func _g26(_j73: String) -> RegEx:
	if not _m93.has(_j73):
		var _x62 = RegEx.new()
		var _e21 = _x62.compile(_j73)
		if _e21 != OK:
			return null
		_m93[_j73] = _x62
	return _m93[_j73]
func _h62() -> String:
	_w95 += 1
	var timestamp = Time.get_ticks_msec()
	return "openscript_%d_%d" % [timestamp, _w95]
func _y88(prompt: String) -> Dictionary:
	var _e21 = {
		"commands": [],
		"cleaned_prompt": prompt
	}
	var _f67 = _g26(_j26)
	var _r9 = _g26(_o14)
	var _f66 = _g26(_w70)
	var _t4 = _g26(_k98)
	var _g83 = _g26(_s65)
	if not _f67 or not _r9 or not _f66 or not _t4 or not _g83:
		return _e21
	var _k49 = _f67.search_all(prompt)
	for match in _k49:
		var _k52 = _k10(match)
		if _k52 != null and not _k52.is_empty():
			_e21.commands.append(_k52)
			if _k52.get("type", "") == "error" and OS.is_debug_build():
				pass
	var _l23 = _r9.search_all(prompt)
	for match in _l23:
		var _k52 = _y31(match)
		if _k52 != null and not _k52.is_empty():
			_e21.commands.append(_k52)
			if _k52.get("type", "") == "error" and OS.is_debug_build():
				pass
	var _t57 = _f66.search_all(prompt)
	for match in _t57:
		var _k52 = _e4(match)
		if _k52 != null and not _k52.is_empty():
			_e21.commands.append(_k52)
			if _k52.get("type", "") == "error" and OS.is_debug_build():
				pass
	var _l92 = _t4.search_all(prompt)
	for match in _l92:
		var _k52 = _x70(match)
		if _k52 != null:
			_e21.commands.append(_k52)
	var _v92 = _g83.search_all(prompt)
	for match in _v92:
		var _k52 = _e87(match)
		if _k52 != null:
			_e21.commands.append(_k52)
	_e21.cleaned_prompt = _v50(prompt)
	return _e21
func _k10(match: RegExMatch) -> Dictionary:
	var file_path = ""
	if match.get_string(1) != "":  
		file_path = match.get_string(1)
	elif match.get_string(2) != "":  
		file_path = match.get_string(2)
	else:
		return {"type": "error", "error": "Invalid @file command syntax"}
	var _m80 = _p10(file_path)
	if not _m8(_m80):
		return {"type": "error", "error": "File not allowed: " + _m80}
	var _k52 = {
		"type": "file",
		"path": _m80,  
		"start_line": -1,
		"end_line": -1,
		"symbol": "",
		"full_match": match.get_string(0)
	}
	if match.get_string(3) != "" and match.get_string(4) != "":
		_k52["start_line"] = int(match.get_string(3))
		_k52["end_line"] = int(match.get_string(4))
	if match.get_string(5) != "":
		_k52["symbol"] = match.get_string(5)
	return _k52
func _x70(match: RegExMatch) -> Dictionary:
	return {
		"type": "selection",
		"full_match": match.get_string(0)
	}
func _y31(match: RegExMatch) -> Dictionary:
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
	var _k52 = {
		"type": "scene",
		"path": scene_path,
		"node_path": "",
		"include_scripts": false,
		"full_match": match.get_string(0)
	}
	if match.get_string(3) != "":
		var _o59 = match.get_string(3)
		var _s96 = _l10(_o59)
		if _s96.is_empty():
			return {"type": "error", "error": "Invalid scene node path"}
		if _s96.length() > 256:
			return {"type": "error", "error": "Scene node path too long"}
		_k52["node_path"] = _s96
	if match.get_string(4) == "--scripts":
		_k52["include_scripts"] = true
	return _k52
func _l10(node_path: String) -> String:
	var _f61 = ""
	var segments = node_path.split("/")
	for i in range(segments.size()):
		var _d82 = segments[i]
		if _d82.is_empty():
			if i == 0:
				_f61 += "/"
			continue
		var _b66 = ""
		var _d18 = true
		for j in range(_d82.length()):
			var char = _d82[j]
			if _d18:
				if (char >= 'A' and char <= 'Z') or (char >= 'a' and char <= 'z') or char == '_':
					_b66 += char
					_d18 = false
				else:
					continue
			else:
				if (char >= 'A' and char <= 'Z') or (char >= 'a' and char <= 'z') or (char >= '0' and char <= '9') or char == '_':
					_b66 += char
		if not _b66.is_empty():
			if not _f61.is_empty() and not _f61.ends_with("/"):
				_f61 += "/"
			_f61 += _b66
	return _f61
func _e4(match: RegExMatch) -> Dictionary:
	var node_path = match.get_string(1)
	if node_path == "":
		return {"type": "error", "error": "Invalid @node command syntax"}
	var _l37 = _l10(node_path)
	if _l37.is_empty():
		return {"type": "error", "error": "Invalid node path"}
	if _l37.length() > 256:
		return {"type": "error", "error": "Node path too long"}
	return {
		"type": "node",
		"node_path": _l37,
		"full_match": match.get_string(0)
	}
func _e87(match: RegExMatch) -> Dictionary:
	var _u1 = get_current_script()
	if not _u1.get("success", false):
		return {
			"type": "error",
			"error": _u1.get("error", "Could not retrieve current script"),
			"full_match": match.get_string(0)
		}
	var snapshot_id = _h62()
	return {
		"type": "openscript",
		"full_match": match.get_string(0),
		"path": _u1.get("path", ""),
		"content": _u1.get("content", ""),
		"snapshot_id": snapshot_id,
		"created_at": Time.get_unix_time_from_system()
	}
func _v50(prompt: String) -> String:
	var _h16 = prompt
	var _f67 = _g26(_j26)
	if _f67:
		_h16 = _f67.sub(_h16, "", true)
	var _r9 = _g26(_o14)
	if _r9:
		_h16 = _r9.sub(_h16, "", true)
	var _f66 = _g26(_w70)
	if _f66:
		_h16 = _f66.sub(_h16, "", true)
	var _t4 = _g26(_k98)
	if _t4:
		_h16 = _t4.sub(_h16, "", true)
	var _g83 = _g26(_s65)
	if _g83:
		_h16 = _g83.sub(_h16, "", true)
	var _o5 = _g26(r'\s+')
	if _o5:
		_h16 = _o5.sub(_h16, " ", true)
	_h16 = _h16.strip_edges()
	return _h16
func _p10(file_path: String) -> String:
	var _h14 = _g26(r':([0-9]+-[0-9]+)$')
	if _h14 and _h14.search(file_path):
		return _h14.sub(file_path, "")
	var _s88 = _g26(r':[0-9]+$')
	if _s88 and _s88.search(file_path):
		return _s88.sub(file_path, "")
	var _r99 = _g26(r'#[a-zA-Z_][a-zA-Z0-9_]*$')
	if _r99 and _r99.search(file_path):
		return _r99.sub(file_path, "")
	return file_path
func _z34(scene_path: String) -> bool:
	if not scene_path.to_lower().ends_with(".tscn"):
		return false
	if not scene_path.begins_with("res://"):
		return false
	if "../" in scene_path or scene_path.contains("..\\"):
		return false
	return true
func _m8(file_path: String) -> bool:
	if "../" in file_path or file_path.contains("..\\"):
		return false
	if file_path.begins_with("/") and not file_path.begins_with("res://"):
		return false
	if file_path.length() > 2 and file_path[1] == ":":
		return false
	if file_path.begins_with("~"):
		return false
	var _r89 = file_path.to_lower()
	var filename = file_path.get_file().to_lower()
	for _b3 in _v14:
		if _r89.ends_with(_b3):
			return false
	for _i43 in _z40:
		if filename == _i43 or filename.begins_with(_i43 + "."):
			return false
	for _a66 in _r25:
		if _r89.ends_with(_a66):
			return true
	return false
func _c89(_k52: Dictionary) -> Dictionary:
	if _k52.get("type", "") != "file":
		return {"success": false, "error": "Invalid command type"}
	var file_path = _k52.get("path", "")
	var full_path = _d11(file_path)
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
	if _k52.get("start_line", -1) > 0 and _k52.get("end_line", -1) > 0:
		var _p91 = content.split("\n")
		start_line = _k52.get("start_line", 1)
		end_line = _k52.get("end_line", -1)
		if start_line > _p91.size() or end_line > _p91.size() or start_line > end_line:
			return {"success": false, "error": "Invalid line range"}
		var _v21 = []
		for i in range(start_line - 1, end_line):
			if i < _p91.size():
				_v21.append(_p91[i])
		filtered_content = "\n".join(_v21)
	elif _k52.get("symbol", "") != "":
		var _s92 = _k52.get("symbol", "")
		var _c46 = _t99(content, _s92)
		if _c46.get("success", false):
			filtered_content = _c46.get("content", "")
			start_line = _c46.get("start_line", 1)
			end_line = _c46.get("end_line", -1)
		else:
			return {"success": false, "error": "Symbol not found: " + _s92}
	return {
		"success": true,
		"content": filtered_content,
		"path": file_path,
		"start_line": start_line,
		"end_line": end_line
	}
func _o92() -> Dictionary:
	if _e3 == null:
		return {"success": false, "error": "Script editor not available"}
	var _y36 = _e3.get_current_editor()
	if _y36 == null:
		return {"success": false, "error": "No script currently open"}
	var _j81 = _y36.get_base_editor()
	if _j81 == null:
		return {"success": false, "error": "Cannot access code editor"}
	var _j79 = _j81.get_selected_text()
	if _j79.is_empty():
		return {"success": false, "error": "No text selected"}
	var _c75 = _j81.get_selection_from_line()
	var _x53 = _j81.get_selection_to_line()
	var _x58 = ""
	if _y36.has_method("get_edited_resource"):
		var _w18 = _y36.get_edited_resource()
		if _w18 != null:
			_x58 = _w18.resource_path
	return {
		"success": true,
		"content": _j79,
		"path": _x58,
		"start_line": _c75 + 1,
		"end_line": _x53 + 1
	}
func get_current_script() -> Dictionary:
	if _e3 == null:
		return {"success": false, "error": "Script editor not available"}
	var _y36 = _e3.get_current_editor()
	if _y36 == null:
		return {"success": false, "error": "No script currently open"}
	var _j81 = _y36.get_base_editor()
	if _j81 == null:
		return {"success": false, "error": "Cannot access code editor"}
	var content = _j81.text
	if content.is_empty():
		return {"success": false, "error": "Script content is empty"}
	var _x58 = ""
	if _y36.has_method("get_edited_resource"):
		var _v52 = _y36.get_edited_resource()
		if _v52 != null:
			_x58 = _v52.resource_path  
	if _x58.is_empty():
		var _q42 = _e3.get_open_script_editors()
		for _z81 in _q42:
			if _z81 == _y36:
				if _z81.has_method("get_edited_resource"):
					var res = _z81.get_edited_resource()
					if res != null:
						_x58 = res.resource_path
						break
	if _x58.is_empty():
		_x58 = "[Unsaved Script]"
	var max_size = 30000  
	var _y58 = content.to_utf8_buffer().size()
	if _y58 > max_size:
		var _j72 = content.substr(0, max_size)
		var _x60 = "\n... [truncated]"
		var _f27 = _j72 + _x60
		if _f27.to_utf8_buffer().size() > max_size:
			var _n59 = _x60.to_utf8_buffer().size()
			var _d20 = max_size - _n59
			if _d20 > 0:
				_j72 = content.substr(0, _d20)
				content = _j72 + _x60
			else:
				content = content.substr(0, max_size)
		else:
			content = _f27
	return {
		"success": true,
		"path": _x58,
		"content": content
	}
func _d11(file_path: String) -> String:
	if "../" in file_path or file_path.contains("..\\"):
		return ""
	if file_path.begins_with("~"):
		return ""
	if file_path.begins_with("/") and not file_path.begins_with("res://"):
		return ""
	if file_path.length() > 2 and file_path[1] == ":":
		return ""
	if file_path.begins_with("res://"):
		var _h4 = file_path.simplify_path()
		if not _h4.begins_with("res://"):
			return ""
		return _h4
	var _b38 = ProjectSettings.globalize_path("res://")
	var full_path = _b38.path_join(file_path)
	var _e16 = full_path.simplify_path()
	var _f24 = ProjectSettings.globalize_path("res://").simplify_path()
	if not _e16.begins_with(_f24):
		return ""
	if FileAccess.file_exists(_e16):
		return _e16
	var _s45 = ("res://" + file_path).simplify_path()
	if not _s45.begins_with("res://"):
		return ""
	if FileAccess.file_exists(_s45):
		return _s45
	return ""
func _q41(symbol: String) -> String:
	var _f61 = ""
	var _d18 = true
	for i in range(symbol.length()):
		var char = symbol[i]
		if _d18:
			if (char >= 'A' and char <= 'Z') or (char >= 'a' and char <= 'z') or char == '_':
				_f61 += char
				_d18 = false
			else:
				continue
		else:
			if (char >= 'A' and char <= 'Z') or (char >= 'a' and char <= 'z') or (char >= '0' and char <= '9') or char == '_':
				_f61 += char
	return _f61
func _t99(content: String, symbol: String) -> Dictionary:
	var _o42 = _q41(symbol)
	if _o42.is_empty():
		return {"success": false, "error": "Invalid symbol name"}
	if _o42.length() > 128:
		return {"success": false, "error": "Symbol name too long"}
	var _p91 = content.split("\n")
	var _t54 = _g26("^\\s*func\\s+" + _o42 + "\\s*\\(")
	var _f63 = _g26("^\\s*class\\s+" + _o42 + "\\s*:")
	var _h5 = _g26("^\\s*signal\\s+" + _o42 + "\\s*")
	var _q83 = _g26("^\\s*(?:var|const)\\s+" + _o42 + "\\s*[=:]")
	if not _t54 or not _f63 or not _h5 or not _q83:
		return {"success": false, "error": "Failed to compile regex patterns"}
	for i in range(_p91.size()):
		var line = _p91[i]
		if _t54.search(line) or _f63.search(line) or _h5.search(line) or _q83.search(line):
			var start_line = i + 1
			var end_line = start_line
			if _t54.search(line) or _f63.search(line):
				var _f18 = _g37(line)
				for j in range(i + 1, _p91.size()):
					var _i6 = _p91[j]
					if _i6.strip_edges() == "":
						continue  
					var _y28 = _g37(_i6)
					if _y28 <= _f18:
						end_line = j
						break
					end_line = j + 1
			var _x48 = []
			for k in range(start_line - 1, min(end_line, _p91.size())):
				_x48.append(_p91[k])
			return {
				"success": true,
				"content": "\n".join(_x48),
				"start_line": start_line,
				"end_line": end_line
			}
	return {"success": false, "error": "Symbol not found"}
func _g37(line: String) -> int:
	var count = 0
	for char in line:
		if char == '\t':
			count += 4  
		elif char == ' ':
			count += 1
		else:
			break
	return count
func _h75(node: Node) -> TabContainer:
	if node is TabContainer:
		var _b5 = node as TabContainer
		if _b5.get_tab_count() > 0:
			var _y90 = _b5.get_tab_control(0)
			if _y90 != null and _j49(_y90):
				return _b5
	for _x15 in node.get_children():
		var _e21 = _h75(_x15)
		if _e21 != null:
			return _e21
	return null
func _j49(node: Node) -> bool:
	if node is CodeEdit:
		return true
	for _x15 in node.get_children():
		if _j49(_x15):
			return true
	return false
func _w22(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node
	for _x15 in node.get_children():
		var _e21 = _w22(_x15)
		if _e21 != null:
			return _e21
	return null
