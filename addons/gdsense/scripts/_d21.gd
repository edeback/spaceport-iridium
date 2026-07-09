@tool
class_name _d21
extends RefCounted
const _w96 = [".gd", ".tscn", ".tres", ".cfg", ".shader", ".json", ".txt", ".md"]
const _d46 = [".env", ".key", ".pem", ".exe", ".bin", ".so", ".dll", ".dylib", ".p12", ".pfx", ".crt", ".csr"]
const _t5 = [".env", "api_key", "secret", "password", "private", "token", "auth", "credential", "config", ".git", ".svn"]
const _u15 = r'@file\s+(?:"([^"]+)"|([^\s]+))(?::(\d+)-(\d+))?(?:#(\w+))?'
const _n97 = r'@scene\s+(?:"([^"]+)"|([^\s#]+))(?:#([A-Za-z0-9_/]+))?(?:\s+(--scripts))?'
const _x53 = r'@node\s+([A-Za-z0-9_/]+)'
const _w97 = r'@selection\b'
const _t55 = r'@openscript\b'
var _f21: EditorInterface
var _n12: ScriptEditor
var _m86: Dictionary = {}
var _s3: int = 0
func _init(_i13: EditorInterface = null, _t27: ScriptEditor = null):
	_f21 = _i13
	_n12 = _t27
func _i94(_s76: String) -> RegEx:
	if not _m86.has(_s76):
		var _r9 = RegEx.new()
		var _s61 = _r9.compile(_s76)
		if _s61 != OK:
			return null
		_m86[_s76] = _r9
	return _m86[_s76]
func _f10() -> String:
	_s3 += 1
	var timestamp = Time.get_ticks_msec()
	return "openscript_%d_%d" % [timestamp, _s3]
func _r93(prompt: String) -> Dictionary:
	var _s61 = {
		"commands": [],
		"cleaned_prompt": prompt
	}
	var _o31 = _i94(_u15)
	var _i58 = _i94(_n97)
	var _n11 = _i94(_x53)
	var _f75 = _i94(_w97)
	var _u80 = _i94(_t55)
	if not _o31 or not _i58 or not _n11 or not _f75 or not _u80:
		return _s61
	var _e48 = _o31.search_all(prompt)
	for match in _e48:
		var _u54 = _p3(match)
		if _u54 != null and not _u54.is_empty():
			_s61.commands.append(_u54)
			if _u54.get("type", "") == "error" and OS.is_debug_build():
				pass
	var _c64 = _i58.search_all(prompt)
	for match in _c64:
		var _u54 = _i64(match)
		if _u54 != null and not _u54.is_empty():
			_s61.commands.append(_u54)
			if _u54.get("type", "") == "error" and OS.is_debug_build():
				pass
	var _l59 = _n11.search_all(prompt)
	for match in _l59:
		var _u54 = _x91(match)
		if _u54 != null and not _u54.is_empty():
			_s61.commands.append(_u54)
			if _u54.get("type", "") == "error" and OS.is_debug_build():
				pass
	var _e15 = _f75.search_all(prompt)
	for match in _e15:
		var _u54 = _b95(match)
		if _u54 != null:
			_s61.commands.append(_u54)
	var _z50 = _u80.search_all(prompt)
	for match in _z50:
		var _u54 = _u66(match)
		if _u54 != null:
			_s61.commands.append(_u54)
	_s61.cleaned_prompt = _h88(prompt)
	return _s61
func _p3(match: RegExMatch) -> Dictionary:
	var file_path = ""
	if match.get_string(1) != "":  
		file_path = match.get_string(1)
	elif match.get_string(2) != "":  
		file_path = match.get_string(2)
	else:
		return {"type": "error", "error": "Invalid @file command syntax"}
	var _r57 = _s43(file_path)
	if not _e2(_r57):
		return {"type": "error", "error": "File not allowed: " + _r57}
	var _u54 = {
		"type": "file",
		"path": _r57,  
		"start_line": -1,
		"end_line": -1,
		"symbol": "",
		"full_match": match.get_string(0)
	}
	if match.get_string(3) != "" and match.get_string(4) != "":
		_u54["start_line"] = int(match.get_string(3))
		_u54["end_line"] = int(match.get_string(4))
	if match.get_string(5) != "":
		_u54["symbol"] = match.get_string(5)
	return _u54
func _b95(match: RegExMatch) -> Dictionary:
	return {
		"type": "selection",
		"full_match": match.get_string(0)
	}
func _i64(match: RegExMatch) -> Dictionary:
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
	var _u54 = {
		"type": "scene",
		"path": scene_path,
		"node_path": "",
		"include_scripts": false,
		"full_match": match.get_string(0)
	}
	if match.get_string(3) != "":
		var _k13 = match.get_string(3)
		var _w33 = _y91(_k13)
		if _w33.is_empty():
			return {"type": "error", "error": "Invalid scene node path"}
		if _w33.length() > 256:
			return {"type": "error", "error": "Scene node path too long"}
		_u54["node_path"] = _w33
	if match.get_string(4) == "--scripts":
		_u54["include_scripts"] = true
	return _u54
func _y91(node_path: String) -> String:
	var _o90 = ""
	var segments = node_path.split("/")
	for i in range(segments.size()):
		var _p33 = segments[i]
		if _p33.is_empty():
			if i == 0:
				_o90 += "/"
			continue
		var _w67 = ""
		var _g57 = true
		for j in range(_p33.length()):
			var _q64 = _p33[j]
			if _g57:
				if (_q64 >= 'A' and _q64 <= 'Z') or (_q64 >= 'a' and _q64 <= 'z') or _q64 == '_':
					_w67 += _q64
					_g57 = false
				else:
					continue
			else:
				if (_q64 >= 'A' and _q64 <= 'Z') or (_q64 >= 'a' and _q64 <= 'z') or (_q64 >= '0' and _q64 <= '9') or _q64 == '_':
					_w67 += _q64
		if not _w67.is_empty():
			if not _o90.is_empty() and not _o90.ends_with("/"):
				_o90 += "/"
			_o90 += _w67
	return _o90
func _x91(match: RegExMatch) -> Dictionary:
	var node_path = match.get_string(1)
	if node_path == "":
		return {"type": "error", "error": "Invalid @node command syntax"}
	var _h28 = _y91(node_path)
	if _h28.is_empty():
		return {"type": "error", "error": "Invalid node path"}
	if _h28.length() > 256:
		return {"type": "error", "error": "Node path too long"}
	return {
		"type": "node",
		"node_path": _h28,
		"full_match": match.get_string(0)
	}
func _u66(match: RegExMatch) -> Dictionary:
	var _p50 = get_current_script()
	if not _p50.get("success", false):
		return {
			"type": "error",
			"error": _p50.get("error", "Could not retrieve current script"),
			"full_match": match.get_string(0)
		}
	var snapshot_id = _f10()
	return {
		"type": "openscript",
		"full_match": match.get_string(0),
		"path": _p50.get("path", ""),
		"content": _p50.get("content", ""),
		"snapshot_id": snapshot_id,
		"created_at": Time.get_unix_time_from_system()
	}
func _h88(prompt: String) -> String:
	var _e16 = prompt
	var _o31 = _i94(_u15)
	if _o31:
		_e16 = _o31.sub(_e16, "", true)
	var _i58 = _i94(_n97)
	if _i58:
		_e16 = _i58.sub(_e16, "", true)
	var _n11 = _i94(_x53)
	if _n11:
		_e16 = _n11.sub(_e16, "", true)
	var _f75 = _i94(_w97)
	if _f75:
		_e16 = _f75.sub(_e16, "", true)
	var _u80 = _i94(_t55)
	if _u80:
		_e16 = _u80.sub(_e16, "", true)
	var _t60 = _i94(r'\s+')
	if _t60:
		_e16 = _t60.sub(_e16, " ", true)
	_e16 = _e16.strip_edges()
	return _e16
func _s43(file_path: String) -> String:
	var _x13 = _i94(r':([0-9]+-[0-9]+)$')
	if _x13 and _x13.search(file_path):
		return _x13.sub(file_path, "")
	var _u42 = _i94(r':[0-9]+$')
	if _u42 and _u42.search(file_path):
		return _u42.sub(file_path, "")
	var _i34 = _i94(r'#[a-zA-Z_][a-zA-Z0-9_]*$')
	if _i34 and _i34.search(file_path):
		return _i34.sub(file_path, "")
	return file_path
func _t49(scene_path: String) -> bool:
	if not scene_path.to_lower().ends_with(".tscn"):
		return false
	if not scene_path.begins_with("res://"):
		return false
	if "../" in scene_path or scene_path.contains("..\\"):
		return false
	return true
func _e2(file_path: String) -> bool:
	if "../" in file_path or file_path.contains("..\\"):
		return false
	if file_path.begins_with("/") and not file_path.begins_with("res://"):
		return false
	if file_path.length() > 2 and file_path[1] == ":":
		return false
	if file_path.begins_with("~"):
		return false
	var _q45 = file_path.to_lower()
	var filename = file_path.get_file().to_lower()
	for _n28 in _d46:
		if _q45.ends_with(_n28):
			return false
	for _m31 in _t5:
		if filename == _m31 or filename.begins_with(_m31 + "."):
			return false
	for _v18 in _w96:
		if _q45.ends_with(_v18):
			return true
	return false
func _g65(_u54: Dictionary) -> Dictionary:
	if _u54.get("type", "") != "file":
		return {"success": false, "error": "Invalid command type"}
	var file_path = _u54.get("path", "")
	var full_path = _f34(file_path)
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
	if _u54.get("start_line", -1) > 0 and _u54.get("end_line", -1) > 0:
		var _t70 = content.split("\n")
		start_line = _u54.get("start_line", 1)
		end_line = _u54.get("end_line", -1)
		if start_line > _t70.size() or end_line > _t70.size() or start_line > end_line:
			return {"success": false, "error": "Invalid line range"}
		var _f81 = []
		for i in range(start_line - 1, end_line):
			if i < _t70.size():
				_f81.append(_t70[i])
		filtered_content = "\n".join(_f81)
	elif _u54.get("symbol", "") != "":
		var _a5 = _u54.get("symbol", "")
		var _z18 = _f92(content, _a5)
		if _z18.get("success", false):
			filtered_content = _z18.get("content", "")
			start_line = _z18.get("start_line", 1)
			end_line = _z18.get("end_line", -1)
		else:
			return {"success": false, "error": "Symbol not found: " + _a5}
	return {
		"success": true,
		"content": filtered_content,
		"path": file_path,
		"start_line": start_line,
		"end_line": end_line
	}
func _e20() -> Dictionary:
	if _n12 == null:
		return {"success": false, "error": "Script editor not available"}
	var _k74 = _n12.get_current_editor()
	if _k74 == null:
		return {"success": false, "error": "No script currently open"}
	var _v93 = _k74.get_base_editor()
	if _v93 == null:
		return {"success": false, "error": "Cannot access code editor"}
	var _a49 = _v93.get_selected_text()
	if _a49.is_empty():
		return {"success": false, "error": "No text selected"}
	var _k49 = _v93.get_selection_from_line()
	var _l31 = _v93.get_selection_to_line()
	var _w48 = ""
	if _k74.has_method("get_edited_resource"):
		var _d33 = _k74.get_edited_resource()
		if _d33 != null:
			_w48 = _d33.resource_path
	return {
		"success": true,
		"content": _a49,
		"path": _w48,
		"start_line": _k49 + 1,
		"end_line": _l31 + 1
	}
func get_current_script() -> Dictionary:
	if _n12 == null:
		return {"success": false, "error": "Script editor not available"}
	var _k74 = _n12.get_current_editor()
	if _k74 == null:
		return {"success": false, "error": "No script currently open"}
	var _v93 = _k74.get_base_editor()
	if _v93 == null:
		return {"success": false, "error": "Cannot access code editor"}
	var content = _v93.text
	if content.is_empty():
		return {"success": false, "error": "Script content is empty"}
	var _w48 = ""
	if _k74.has_method("get_edited_resource"):
		var _k84 = _k74.get_edited_resource()
		if _k84 != null:
			_w48 = _k84.resource_path  
	if _w48.is_empty():
		var _y7 = _n12.get_open_script_editors()
		for _c27 in _y7:
			if _c27 == _k74:
				if _c27.has_method("get_edited_resource"):
					var res = _c27.get_edited_resource()
					if res != null:
						_w48 = res.resource_path
						break
	if _w48.is_empty():
		_w48 = "[Unsaved Script]"
	var max_size = 30000  
	var _p76 = content.to_utf8_buffer().size()
	if _p76 > max_size:
		var _z37 = content.substr(0, max_size)
		var _x97 = "\n... [truncated]"
		var _v65 = _z37 + _x97
		if _v65.to_utf8_buffer().size() > max_size:
			var _g33 = _x97.to_utf8_buffer().size()
			var _f54 = max_size - _g33
			if _f54 > 0:
				_z37 = content.substr(0, _f54)
				content = _z37 + _x97
			else:
				content = content.substr(0, max_size)
		else:
			content = _v65
	return {
		"success": true,
		"path": _w48,
		"content": content
	}
func _f34(file_path: String) -> String:
	if "../" in file_path or file_path.contains("..\\"):
		return ""
	if file_path.begins_with("~"):
		return ""
	if file_path.begins_with("/") and not file_path.begins_with("res://"):
		return ""
	if file_path.length() > 2 and file_path[1] == ":":
		return ""
	if file_path.begins_with("res://"):
		var _o54 = file_path.simplify_path()
		if not _o54.begins_with("res://"):
			return ""
		return _o54
	var _m64 = ProjectSettings.globalize_path("res://")
	var full_path = _m64.path_join(file_path)
	var _s48 = full_path.simplify_path()
	var _r92 = ProjectSettings.globalize_path("res://").simplify_path()
	if not _s48.begins_with(_r92):
		return ""
	if FileAccess.file_exists(_s48):
		return _s48
	var _k47 = ("res://" + file_path).simplify_path()
	if not _k47.begins_with("res://"):
		return ""
	if FileAccess.file_exists(_k47):
		return _k47
	return ""
func _v17(symbol: String) -> String:
	var _o90 = ""
	var _g57 = true
	for i in range(symbol.length()):
		var _q64 = symbol[i]
		if _g57:
			if (_q64 >= 'A' and _q64 <= 'Z') or (_q64 >= 'a' and _q64 <= 'z') or _q64 == '_':
				_o90 += _q64
				_g57 = false
			else:
				continue
		else:
			if (_q64 >= 'A' and _q64 <= 'Z') or (_q64 >= 'a' and _q64 <= 'z') or (_q64 >= '0' and _q64 <= '9') or _q64 == '_':
				_o90 += _q64
	return _o90
func _f92(content: String, symbol: String) -> Dictionary:
	var _o96 = _v17(symbol)
	if _o96.is_empty():
		return {"success": false, "error": "Invalid symbol name"}
	if _o96.length() > 128:
		return {"success": false, "error": "Symbol name too long"}
	var _t70 = content.split("\n")
	var _x21 = _i94("^\\s*func\\s+" + _o96 + "\\s*\\(")
	var _v31 = _i94("^\\s*class\\s+" + _o96 + "\\s*:")
	var _y53 = _i94("^\\s*signal\\s+" + _o96 + "\\s*")
	var _u88 = _i94("^\\s*(?:var|const)\\s+" + _o96 + "\\s*[=:]")
	if not _x21 or not _v31 or not _y53 or not _u88:
		return {"success": false, "error": "Failed to compile regex patterns"}
	for i in range(_t70.size()):
		var line = _t70[i]
		if _x21.search(line) or _v31.search(line) or _y53.search(line) or _u88.search(line):
			var start_line = i + 1
			var end_line = start_line
			if _x21.search(line) or _v31.search(line):
				var _l96 = _x59(line)
				for j in range(i + 1, _t70.size()):
					var _o98 = _t70[j]
					if _o98.strip_edges() == "":
						continue  
					var _n83 = _x59(_o98)
					if _n83 <= _l96:
						end_line = j
						break
					end_line = j + 1
			var _k62 = []
			for k in range(start_line - 1, min(end_line, _t70.size())):
				_k62.append(_t70[k])
			return {
				"success": true,
				"content": "\n".join(_k62),
				"start_line": start_line,
				"end_line": end_line
			}
	return {"success": false, "error": "Symbol not found"}
func _x59(line: String) -> int:
	var count = 0
	for _q64 in line:
		if _q64 == '\t':
			count += 4  
		elif _q64 == ' ':
			count += 1
		else:
			break
	return count
func _x77(node: Node) -> TabContainer:
	if node is TabContainer:
		var _h17 = node as TabContainer
		if _h17.get_tab_count() > 0:
			var _e29 = _h17.get_tab_control(0)
			if _e29 != null and _f99(_e29):
				return _h17
	for _o14 in node.get_children():
		var _s61 = _x77(_o14)
		if _s61 != null:
			return _s61
	return null
func _f99(node: Node) -> bool:
	if node is CodeEdit:
		return true
	for _o14 in node.get_children():
		if _f99(_o14):
			return true
	return false
func _j65(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node
	for _o14 in node.get_children():
		var _s61 = _j65(_o14)
		if _s61 != null:
			return _s61
	return null
