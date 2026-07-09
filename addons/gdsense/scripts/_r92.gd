@tool
class_name _r92
extends RefCounted
const _q52 = 30000  
const _a69 = 1000       
const _m41 = 500 
const _k73 = 3        
var _a74: int
var _l63: bool = false
func _a55(scene_path: String, _c43: String = "", include_scripts: bool = false) -> Dictionary:
	_a74 = Time.get_ticks_msec()
	_l63 = false
	if not _q2(scene_path):
		return {"success": false, "error": "Invalid or insecure scene path: " + scene_path}
	if not FileAccess.file_exists(scene_path):
		return {"success": false, "error": "Scene file not found: " + scene_path}
	var file = FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		return {"success": false, "error": "Cannot open scene file: " + scene_path}
	var _i40 = file.get_length()
	if _i40 > _q52:
		file.close()
		return {"success": false, "error": "Scene file too large (" + str(_i40) + " bytes, max " + str(_q52) + ")"}
	var content = file.get_as_text()
	file.close()
	return _g64(content, scene_path, _c43, include_scripts)
func _g64(content: String, scene_path: String, _c43: String = "", include_scripts: bool = false) -> Dictionary:
	var _a62 = content.split("\n")
	var scene_info = {
		"success": true,
		"scene_path": scene_path,
		"nodes": [],
		"scripts": [],
		"root_node": "",
		"filtered_content": content
	}
	var _e62 = _t76(_a62)
	if OS.is_debug_build() and not _e62.is_empty():
		pass
	var _q19 = 0
	var _f7 = {}
	var _y84 = false
	if _z59():
		return {"success": false, "error": "Scene parsing timeout exceeded"}
	for i in range(_a62.size()):
		if _z59():
			return {"success": false, "error": "Scene parsing timeout exceeded"}
		var line = _a62[i]
		var _f92 = line.strip_edges()
		if _f92.begins_with("[node "):
			if _y84 and not _f7.is_empty():
				scene_info["nodes"].append(_f7)
				_q19 += 1
				if _q19 > _a69:
					return {"success": false, "error": "Scene contains too many nodes (>" + str(_a69) + ")"}
			_f7 = _s64(_f92)
			if not _f7.is_empty():
				_y84 = true
				if scene_info.root_node == "" and _f7.get("parent", "") == "":
					scene_info.root_node = _f7.get("name", "")
		elif _y84:
			if _f92.begins_with("["):
				if not _f7.is_empty():
					scene_info["nodes"].append(_f7)
					_q19 += 1
				_y84 = false
				_f7 = {}
			elif "=" in _f92:
				_e12(_f7, _f92)
	if _y84 and not _f7.is_empty():
		scene_info["nodes"].append(_f7)
	if _c43 != "":
		scene_info = _d79(scene_info, _c43)
	if include_scripts:
		scene_info["scripts"] = _u82(scene_info["nodes"], _e62)
	scene_info["filtered_content"] = _u83(scene_info)
	return scene_info
func _s64(line: String) -> Dictionary:
	var _h39 = {}
	var _w44 = RegEx.new()
	if _w44.compile(r'name="([^"]*)"') == OK:
		var _u20 = _w44.search(line)
		if _u20:
			_h39["name"] = _u20.get_string(1)
	if _w44.compile(r'type="([^"]*)"') == OK:
		var _l28 = _w44.search(line)
		if _l28:
			_h39["type"] = _l28.get_string(1)
	if _w44.compile(r'parent="([^"]*)"') == OK:
		var _c7 = _w44.search(line)
		if _c7:
			_h39["parent"] = _c7.get_string(1)
	if not _h39.has("parent"):
		_h39["parent"] = ""
	_h39["properties"] = {}
	_h39["full_path"] = _m51(_h39)
	return _h39
func _e12(_h39: Dictionary, line: String) -> void:
	var _a5 = line.find("=")
	if _a5 > 0:
		var _b22 = line.substr(0, _a5).strip_edges()
		var value = line.substr(_a5 + 1).strip_edges()
		_h39.properties[_b22] = value
		if _b22 == "script":
			_h39["script_path"] = value
			_h39["has_script"] = true
func _m51(_h39: Dictionary) -> String:
	var name = _h39.get("name", "")
	var parent = _h39.get("parent", "")
	if parent == "" or parent == ".":
		return name  
	else:
		return parent + "/" + name
func _d79(scene_info: Dictionary, _c43: String) -> Dictionary:
	var _u22 = scene_info.duplicate(true)
	_u22["nodes"] = []
	for node in scene_info["nodes"]:
		var node_path = node.get("full_path", "")
		var _d80 = node.get("name", "")
		if _d80 == _c43 or node_path == _c43 or node_path.begins_with(_c43 + "/"):
			_u22.nodes.append(node)
	return _u22
func _u82(nodes: Array, _e62: Dictionary) -> Array:
	var scripts = []
	for node in nodes:
		if scripts.size() >= _k73:
			break
		var _s100 = node.get("script_path", "")
		if _s100 != "" and _s100 != "null":
			var _w41 = _k9(_s100, _e62)
			if _w41 != "":
				var _d58 = null
				for script in scripts:
					if script.get("path", "") == _w41:
						_d58 = script
						break
				if _d58 == null:
					var _z36 = _w25(_w41)
					if _z36 != null:
						scripts.append(_z36)
	return scripts
func _t76(_a62: Array) -> Dictionary:
	var _e62 = {}
	for line in _a62:
		var _f92 = line.strip_edges()
		if _f92.begins_with("[ext_resource"):
			var _y64 = _t18(_f92)
			if _y64.has("id") and _y64.has("path"):
				_e62[_y64["id"]] = _y64["path"]
	return _e62
func _t18(line: String) -> Dictionary:
	var _y64 = {}
	var _h48 = RegEx.new()
	if _h48.compile(r'path="([^"]+)"') == OK:
		var _r66 = _h48.search(line)
		if _r66:
			_y64["path"] = _r66.get_string(1)
	var _w93 = RegEx.new()
	if _w93.compile(r'id="([^"]+)"') == OK:
		var _i51 = _w93.search(line)
		if _i51:
			_y64["id"] = _i51.get_string(1)
	return _y64
func _k9(_h59: String, _e62: Dictionary) -> String:
	var _a3 = RegEx.new()
	if _a3.compile(r'ExtResource\("([^"]+)"\)') == OK:
		var match = _a3.search(_h59)
		if match:
			var _h62 = match.get_string(1)
			if _e62.has(_h62):
				return _e62[_h62]
			else:
				return ""
	if _h59.begins_with("res://"):
		return _h59
	return ""
func _w25(_s100: String) -> Dictionary:
	if not FileAccess.file_exists(_s100):
		return {"path": _s100, "content": "Error: File not found", "error": true}
	var file = FileAccess.open(_s100, FileAccess.READ)
	if file == null:
		return {"path": _s100, "content": "Error: Cannot open file", "error": true}
	var _i40 = file.get_length()
	if _i40 > _q52:
		file.close()
		return {"path": _s100, "content": "Error: Script file too large (" + str(_i40) + " bytes, max " + str(_q52) + ")", "error": true}
	var content = file.get_as_text()
	file.close()
	return {
		"path": _s100,
		"content": content,
		"size": _i40,
		"error": false
	}
func _u83(scene_info: Dictionary) -> String:
	var scene_path = scene_info.get("scene_path", "")
	var root_node = scene_info.get("root_node", "")
	var nodes = scene_info.get("nodes", [])
	var scripts = scene_info.get("scripts", [])
	var content = "# Scene: " + scene_path + "\n"
	content += "# Root Node: " + root_node + "\n"
	content += "# Total Nodes: " + str(nodes.size()) + "\n\n"
	content += "## Node Tree:\n"
	var _t30 = _b90(nodes)
	for _h74 in _t30:
		content += _h74 + "\n"
	if not scripts.is_empty():
		content += "\n## Associated Scripts:\n"
		for _z36 in scripts:
			var _s100 = _z36.get("path", "")
			var _l56 = _z36.get("error", false)
			if _l56:
				content += "### Script: " + _s100 + " (" + _z36.get("content", "Error") + ")\n"
			else:
				content += "### Script: " + _s100 + "\n"
				content += "```gdscript\n"
				content += _z36.get("content", "")
				if not _z36.get("content", "").ends_with("\n"):
					content += "\n"
				content += "```\n\n"
	return content
func _b90(nodes: Array) -> Array:
	var _t30 = []
	var _q78 = {}
	for node in nodes:
		var path = node.get("full_path", node.get("name", ""))
		_q78[path] = node
	for node in nodes:
		var _d80 = node.get("name", "")
		var _p29 = node.get("type", "")
		var parent = node.get("parent", "")
		var full_path = node.get("full_path", "")
		var depth = 0
		if parent != "" and parent != ".":
			depth = parent.split("/").size()
		var indent = "  ".repeat(depth)
		var line = indent + "- " + _d80 + " (" + _p29 + ")"
		if node.has("script_path") and node.get("script_path", "") != "":
			line += " [script]"
		_t30.append(line)
	return _t30
func _q2(scene_path: String) -> bool:
	if not scene_path.begins_with("res://"):
		return false
	if not scene_path.to_lower().ends_with(".tscn"):
		return false
	if "../" in scene_path or scene_path.contains("..\\"):
		return false
	return true
func _z59() -> bool:
	if _l63:
		return true
	var _j33 = Time.get_ticks_msec()
	if (_j33 - _a74) > _m41:
		_l63 = true
		return true
	return false
func get_current_scene_nodes(_o10: EditorInterface) -> Dictionary:
	if not _o10:
		return {"success": false, "error": "Editor interface not available"}
	var _i17 = _o10.get_edited_scene_root()
	if not _i17:
		return {"success": false, "error": "No scene currently open in editor"}
	_a74 = Time.get_ticks_msec()
	_l63 = false
	var scene_info = {
		"success": true,
		"scene_path": "current_scene",
		"nodes": [],
		"root_node": _i17.name
	}
	_r54(_i17, scene_info["nodes"], "")
	return scene_info
func _r54(node: Node, nodes: Array, _m52: String) -> void:
	if _z59():
		return
	if nodes.size() > _a69:
		return
	var node_path = _m52
	if node_path != "":
		node_path += "/" + node.name
	else:
		node_path = node.name
	var _h39 = {
		"name": node.name,
		"type": node.get_class(),
		"full_path": node_path,
		"parent": _m52,
		"properties": {}
	}
	var script = node.get_script()
	if script:
		var _s100 = script.resource_path
		if _s100 != "":
			_h39["script_path"] = _s100
	nodes.append(_h39)
	for _i64 in node.get_children():
		_r54(_i64, nodes, node_path)
func _s56(_o10: EditorInterface, node_path: String) -> Dictionary:
	var scene_info = get_current_scene_nodes(_o10)
	if not scene_info.get("success", false):
		return scene_info
	for node in scene_info["nodes"]:
		var name = node.get("name", "")
		var full_path = node.get("full_path", "")
		if name == node_path or full_path == node_path or full_path.ends_with("/" + node_path):
			return {
				"success": true,
				"node": node,
				"scene_info": scene_info
			}
	return {"success": false, "error": "Node not found: " + node_path}
