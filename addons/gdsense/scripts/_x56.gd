@tool
class_name _x56
extends RefCounted
const _j37 = [".gd", ".tscn", ".tres", ".cfg", ".shader", ".json", ".txt", ".md"]
const _t66 = [".env", ".key", ".pem", ".exe", ".bin", ".so", ".dll", ".dylib", ".p12", ".pfx", ".crt", ".csr"]
const _u94 = [".env", "api_key", "secret", "password", "private", "token", "auth", "credential", "config", ".git", ".svn"]
const _v18 = r'@file\s+(?:"([^"]+)"|([^\s]+))(?::(\d+)-(\d+))?(?:#(\w+))?'
const _a77 = r'@scene\s+(?:"([^"]+)"|([^\s#]+))(?:#([A-Za-z0-9_/]+))?(?:\s+(--scripts))?'
const _l41 = r'@node\s+([A-Za-z0-9_/]+)'
const _o75 = r'@selection\b'
const _d30 = r'@openscript\b'
var _w27: EditorInterface
var _k94: ScriptEditor
var _k20: Dictionary = {}
var _q7: int = 0
func _init(_d84: EditorInterface = null, _w31: ScriptEditor = null):
	_w27 = _d84
	_k94 = _w31
func _a47(_y99: String) -> RegEx:
	if not _k20.has(_y99):
		var _v54 = RegEx.new()
		var _x97 = _v54.compile(_y99)
		if _x97 != OK:
			return null
		_k20[_y99] = _v54
	return _k20[_y99]
func _w82() -> String:
	_q7 += 1
	var timestamp = Time.get_ticks_msec()
	return "openscript_%d_%d" % [timestamp, _q7]
func _t25(prompt: String) -> Dictionary:
	var _x97 = {
		"commands": [],
		"cleaned_prompt": prompt
	}
	var _z9 = _a47(_v18)
	var _s64 = _a47(_a77)
	var _m14 = _a47(_l41)
	var _i82 = _a47(_o75)
	var _p93 = _a47(_d30)
	if not _z9 or not _s64 or not _m14 or not _i82 or not _p93:
		return _x97
	var _h20 = _z9.search_all(prompt)
	for match in _h20:
		var _l5 = _c44(match)
		if _l5 != null and not _l5.is_empty():
			_x97.commands.append(_l5)
			if _l5.get("type", "") == "error" and OS.is_debug_build():
				pass
	var _n70 = _s64.search_all(prompt)
	for match in _n70:
		var _l5 = _g17(match)
		if _l5 != null and not _l5.is_empty():
			_x97.commands.append(_l5)
			if _l5.get("type", "") == "error" and OS.is_debug_build():
				pass
	var _t42 = _m14.search_all(prompt)
	for match in _t42:
		var _l5 = _h87(match)
		if _l5 != null and not _l5.is_empty():
			_x97.commands.append(_l5)
			if _l5.get("type", "") == "error" and OS.is_debug_build():
				pass
	var _l83 = _i82.search_all(prompt)
	for match in _l83:
		var _l5 = _o64(match)
		if _l5 != null:
			_x97.commands.append(_l5)
	var _n59 = _p93.search_all(prompt)
	for match in _n59:
		var _l5 = _p64(match)
		if _l5 != null:
			_x97.commands.append(_l5)
	_x97.cleaned_prompt = _n54(prompt)
	return _x97
func _c44(match: RegExMatch) -> Dictionary:
	var file_path = ""
	if match.get_string(1) != "":  
		file_path = match.get_string(1)
	elif match.get_string(2) != "":  
		file_path = match.get_string(2)
	else:
		return {"type": "error", "error": "Invalid @file command syntax"}
	var _v81 = _f31(file_path)
	if not _d99(_v81):
		return {"type": "error", "error": "File not allowed: " + _v81}
	var _l5 = {
		"type": "file",
		"path": _v81,  
		"start_line": -1,
		"end_line": -1,
		"symbol": "",
		"full_match": match.get_string(0)
	}
	if match.get_string(3) != "" and match.get_string(4) != "":
		_l5["start_line"] = int(match.get_string(3))
		_l5["end_line"] = int(match.get_string(4))
	if match.get_string(5) != "":
		_l5["symbol"] = match.get_string(5)
	return _l5
func _o64(match: RegExMatch) -> Dictionary:
	return {
		"type": "selection",
		"full_match": match.get_string(0)
	}
func _g17(match: RegExMatch) -> Dictionary:
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
	var _l5 = {
		"type": "scene",
		"path": scene_path,
		"node_path": "",
		"include_scripts": false,
		"full_match": match.get_string(0)
	}
	if match.get_string(3) != "":
		var _s75 = match.get_string(3)
		var _r82 = _i7(_s75)
		if _r82.is_empty():
			return {"type": "error", "error": "Invalid scene node path"}
		if _r82.length() > 256:
			return {"type": "error", "error": "Scene node path too long"}
		_l5["node_path"] = _r82
	if match.get_string(4) == "--scripts":
		_l5["include_scripts"] = true
	return _l5
func _i7(node_path: String) -> String:
	var _e76 = ""
	var segments = node_path.split("/")
	for i in range(segments.size()):
		var _m65 = segments[i]
		if _m65.is_empty():
			if i == 0:
				_e76 += "/"
			continue
		var _d78 = ""
		var _a71 = true
		for j in range(_m65.length()):
			var _o41 = _m65[j]
			if _a71:
				if (_o41 >= 'A' and _o41 <= 'Z') or (_o41 >= 'a' and _o41 <= 'z') or _o41 == '_':
					_d78 += _o41
					_a71 = false
				else:
					continue
			else:
				if (_o41 >= 'A' and _o41 <= 'Z') or (_o41 >= 'a' and _o41 <= 'z') or (_o41 >= '0' and _o41 <= '9') or _o41 == '_':
					_d78 += _o41
		if not _d78.is_empty():
			if not _e76.is_empty() and not _e76.ends_with("/"):
				_e76 += "/"
			_e76 += _d78
	return _e76
func _h87(match: RegExMatch) -> Dictionary:
	var node_path = match.get_string(1)
	if node_path == "":
		return {"type": "error", "error": "Invalid @node command syntax"}
	var _q42 = _i7(node_path)
	if _q42.is_empty():
		return {"type": "error", "error": "Invalid node path"}
	if _q42.length() > 256:
		return {"type": "error", "error": "Node path too long"}
	return {
		"type": "node",
		"node_path": _q42,
		"full_match": match.get_string(0)
	}
func _p64(match: RegExMatch) -> Dictionary:
	var _o1 = get_current_script()
	if not _o1.get("success", false):
		return {
			"type": "error",
			"error": _o1.get("error", "Could not retrieve current script"),
			"full_match": match.get_string(0)
		}
	var snapshot_id = _w82()
	return {
		"type": "openscript",
		"full_match": match.get_string(0),
		"path": _o1.get("path", ""),
		"content": _o1.get("content", ""),
		"snapshot_id": snapshot_id,
		"created_at": Time.get_unix_time_from_system()
	}
func _n54(prompt: String) -> String:
	var _o31 = prompt
	var _z9 = _a47(_v18)
	if _z9:
		_o31 = _z9.sub(_o31, "", true)
	var _s64 = _a47(_a77)
	if _s64:
		_o31 = _s64.sub(_o31, "", true)
	var _m14 = _a47(_l41)
	if _m14:
		_o31 = _m14.sub(_o31, "", true)
	var _i82 = _a47(_o75)
	if _i82:
		_o31 = _i82.sub(_o31, "", true)
	var _p93 = _a47(_d30)
	if _p93:
		_o31 = _p93.sub(_o31, "", true)
	var _n87 = _a47(r'\s+')
	if _n87:
		_o31 = _n87.sub(_o31, " ", true)
	_o31 = _o31.strip_edges()
	return _o31
func _f31(file_path: String) -> String:
	var _h100 = _a47(r':([0-9]+-[0-9]+)$')
	if _h100 and _h100.search(file_path):
		return _h100.sub(file_path, "")
	var _y93 = _a47(r':[0-9]+$')
	if _y93 and _y93.search(file_path):
		return _y93.sub(file_path, "")
	var _w64 = _a47(r'#[a-zA-Z_][a-zA-Z0-9_]*$')
	if _w64 and _w64.search(file_path):
		return _w64.sub(file_path, "")
	return file_path
func _i19(scene_path: String) -> bool:
	if not scene_path.to_lower().ends_with(".tscn"):
		return false
	if not scene_path.begins_with("res://"):
		return false
	if "../" in scene_path or scene_path.contains("..\\"):
		return false
	return true
func _d99(file_path: String) -> bool:
	if "../" in file_path or file_path.contains("..\\"):
		return false
	if file_path.begins_with("/") and not file_path.begins_with("res://"):
		return false
	if file_path.length() > 2 and file_path[1] == ":":
		return false
	if file_path.begins_with("~"):
		return false
	var _l31 = file_path.to_lower()
	var filename = file_path.get_file().to_lower()
	for _y82 in _t66:
		if _l31.ends_with(_y82):
			return false
	for _o67 in _u94:
		if filename == _o67 or filename.begins_with(_o67 + "."):
			return false
	for _q52 in _j37:
		if _l31.ends_with(_q52):
			return true
	return false
func _n61(_l5: Dictionary) -> Dictionary:
	if _l5.get("type", "") != "file":
		return {"success": false, "error": "Invalid command type"}
	var file_path = _l5.get("path", "")
	var full_path = _b90(file_path)
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
	if _l5.get("start_line", -1) > 0 and _l5.get("end_line", -1) > 0:
		var _j90 = content.split("\n")
		start_line = _l5.get("start_line", 1)
		end_line = _l5.get("end_line", -1)
		if start_line > _j90.size() or end_line > _j90.size() or start_line > end_line:
			return {"success": false, "error": "Invalid line range"}
		var _m51 = []
		for i in range(start_line - 1, end_line):
			if i < _j90.size():
				_m51.append(_j90[i])
		filtered_content = "\n".join(_m51)
	elif _l5.get("symbol", "") != "":
		var _d27 = _l5.get("symbol", "")
		var _k12 = _e51(content, _d27)
		if _k12.get("success", false):
			filtered_content = _k12.get("content", "")
			start_line = _k12.get("start_line", 1)
			end_line = _k12.get("end_line", -1)
		else:
			return {"success": false, "error": "Symbol not found: " + _d27}
	return {
		"success": true,
		"content": filtered_content,
		"path": file_path,
		"start_line": start_line,
		"end_line": end_line
	}
func _m77() -> Dictionary:
	if _k94 == null:
		return {"success": false, "error": "Script editor not available"}
	var _d90 = _k94.get_current_editor()
	if _d90 == null:
		return {"success": false, "error": "No script currently open"}
	var _x7 = _d90.get_base_editor()
	if _x7 == null:
		return {"success": false, "error": "Cannot access code editor"}
	var _v72 = _x7.get_selected_text()
	if _v72.is_empty():
		return {"success": false, "error": "No text selected"}
	var _s13 = _x7.get_selection_from_line()
	var _i8 = _x7.get_selection_to_line()
	var _r98 = ""
	if _d90.has_method("get_edited_resource"):
		var _j21 = _d90.get_edited_resource()
		if _j21 != null:
			_r98 = _j21.resource_path
	return {
		"success": true,
		"content": _v72,
		"path": _r98,
		"start_line": _s13 + 1,
		"end_line": _i8 + 1
	}
func get_current_script() -> Dictionary:
	if _k94 == null:
		return {"success": false, "error": "Script editor not available"}
	var _d90 = _k94.get_current_editor()
	if _d90 == null:
		return {"success": false, "error": "No script currently open"}
	var _x7 = _d90.get_base_editor()
	if _x7 == null:
		return {"success": false, "error": "Cannot access code editor"}
	var content = _x7.text
	if content.is_empty():
		return {"success": false, "error": "Script content is empty"}
	var _r98 = ""
	if _d90.has_method("get_edited_resource"):
		var _a66 = _d90.get_edited_resource()
		if _a66 != null:
			_r98 = _a66.resource_path  
	if _r98.is_empty():
		var _g86 = _k94.get_open_script_editors()
		for _l77 in _g86:
			if _l77 == _d90:
				if _l77.has_method("get_edited_resource"):
					var res = _l77.get_edited_resource()
					if res != null:
						_r98 = res.resource_path
						break
	if _r98.is_empty():
		_r98 = "[Unsaved Script]"
	var max_size = 30000  
	var _a4 = content.to_utf8_buffer().size()
	if _a4 > max_size:
		var _n60 = content.substr(0, max_size)
		var _r12 = "\n... [truncated]"
		var _l55 = _n60 + _r12
		if _l55.to_utf8_buffer().size() > max_size:
			var _x84 = _r12.to_utf8_buffer().size()
			var _g6 = max_size - _x84
			if _g6 > 0:
				_n60 = content.substr(0, _g6)
				content = _n60 + _r12
			else:
				content = content.substr(0, max_size)
		else:
			content = _l55
	return {
		"success": true,
		"path": _r98,
		"content": content
	}
func _b90(file_path: String) -> String:
	if "../" in file_path or file_path.contains("..\\"):
		return ""
	if file_path.begins_with("~"):
		return ""
	if file_path.begins_with("/") and not file_path.begins_with("res://"):
		return ""
	if file_path.length() > 2 and file_path[1] == ":":
		return ""
	if file_path.begins_with("res://"):
		var _y30 = file_path.simplify_path()
		if not _y30.begins_with("res://"):
			return ""
		return _y30
	var _z47 = ProjectSettings.globalize_path("res://")
	var full_path = _z47.path_join(file_path)
	var _i83 = full_path.simplify_path()
	var _v52 = ProjectSettings.globalize_path("res://").simplify_path()
	if not _i83.begins_with(_v52):
		return ""
	if FileAccess.file_exists(_i83):
		return _i83
	var _q55 = ("res://" + file_path).simplify_path()
	if not _q55.begins_with("res://"):
		return ""
	if FileAccess.file_exists(_q55):
		return _q55
	return ""
func _x35(symbol: String) -> String:
	var _e76 = ""
	var _a71 = true
	for i in range(symbol.length()):
		var _o41 = symbol[i]
		if _a71:
			if (_o41 >= 'A' and _o41 <= 'Z') or (_o41 >= 'a' and _o41 <= 'z') or _o41 == '_':
				_e76 += _o41
				_a71 = false
			else:
				continue
		else:
			if (_o41 >= 'A' and _o41 <= 'Z') or (_o41 >= 'a' and _o41 <= 'z') or (_o41 >= '0' and _o41 <= '9') or _o41 == '_':
				_e76 += _o41
	return _e76
func _e51(content: String, symbol: String) -> Dictionary:
	var _l51 = _x35(symbol)
	if _l51.is_empty():
		return {"success": false, "error": "Invalid symbol name"}
	if _l51.length() > 128:
		return {"success": false, "error": "Symbol name too long"}
	var _j90 = content.split("\n")
	var _h28 = _a47("^\\s*func\\s+" + _l51 + "\\s*\\(")
	var _e19 = _a47("^\\s*class\\s+" + _l51 + "\\s*:")
	var _o57 = _a47("^\\s*signal\\s+" + _l51 + "\\s*")
	var _z52 = _a47("^\\s*(?:var|const)\\s+" + _l51 + "\\s*[=:]")
	if not _h28 or not _e19 or not _o57 or not _z52:
		return {"success": false, "error": "Failed to compile regex patterns"}
	for i in range(_j90.size()):
		var line = _j90[i]
		if _h28.search(line) or _e19.search(line) or _o57.search(line) or _z52.search(line):
			var start_line = i + 1
			var end_line = start_line
			if _h28.search(line) or _e19.search(line):
				var _d5 = _i36(line)
				for j in range(i + 1, _j90.size()):
					var _a42 = _j90[j]
					if _a42.strip_edges() == "":
						continue  
					var _q68 = _i36(_a42)
					if _q68 <= _d5:
						end_line = j
						break
					end_line = j + 1
			var _v56 = []
			for k in range(start_line - 1, min(end_line, _j90.size())):
				_v56.append(_j90[k])
			return {
				"success": true,
				"content": "\n".join(_v56),
				"start_line": start_line,
				"end_line": end_line
			}
	return {"success": false, "error": "Symbol not found"}
func _i36(line: String) -> int:
	var count = 0
	for _o41 in line:
		if _o41 == '\t':
			count += 4  
		elif _o41 == ' ':
			count += 1
		else:
			break
	return count
func _d57(node: Node) -> TabContainer:
	if node is TabContainer:
		var _y23 = node as TabContainer
		if _y23.get_tab_count() > 0:
			var _y16 = _y23.get_tab_control(0)
			if _y16 != null and _d73(_y16):
				return _y23
	for _h61 in node.get_children():
		var _x97 = _d57(_h61)
		if _x97 != null:
			return _x97
	return null
func _d73(node: Node) -> bool:
	if node is CodeEdit:
		return true
	for _h61 in node.get_children():
		if _d73(_h61):
			return true
	return false
func _n90(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node
	for _h61 in node.get_children():
		var _x97 = _n90(_h61)
		if _x97 != null:
			return _x97
	return null
