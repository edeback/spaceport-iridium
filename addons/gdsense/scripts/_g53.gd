@tool
class_name _g53
extends RefCounted
const _o36 = 30000  
const _o82 = 1000       
const _p33 = 500 
const _l32 = 3        
var _g81: int
var _n78: bool = false
func _p19(scene_path: String, _d28: String = "", include_scripts: bool = false) -> Dictionary:
	_g81 = Time.get_ticks_msec()
	_n78 = false
	if not _l100(scene_path):
		return {"success": false, "error": "Invalid or insecure scene path: " + scene_path}
	if not FileAccess.file_exists(scene_path):
		return {"success": false, "error": "Scene file not found: " + scene_path}
	var file = FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		return {"success": false, "error": "Cannot open scene file: " + scene_path}
	var _b65 = file.get_length()
	if _b65 > _o36:
		file.close()
		return {"success": false, "error": "Scene file too large (" + str(_b65) + " bytes, max " + str(_o36) + ")"}
	var content = file.get_as_text()
	file.close()
	return _g31(content, scene_path, _d28, include_scripts)
func _g31(content: String, scene_path: String, _d28: String = "", include_scripts: bool = false) -> Dictionary:
	var _j90 = content.split("\n")
	var scene_info = {
		"success": true,
		"scene_path": scene_path,
		"nodes": [],
		"scripts": [],
		"root_node": "",
		"filtered_content": content
	}
	var _f51 = _y41(_j90)
	if OS.is_debug_build() and not _f51.is_empty():
		pass
	var _a57 = 0
	var _l79 = {}
	var _z15 = false
	if _n20():
		return {"success": false, "error": "Scene parsing timeout exceeded"}
	for i in range(_j90.size()):
		if _n20():
			return {"success": false, "error": "Scene parsing timeout exceeded"}
		var line = _j90[i]
		var _m43 = line.strip_edges()
		if _m43.begins_with("[node "):
			if _z15 and not _l79.is_empty():
				scene_info["nodes"].append(_l79)
				_a57 += 1
				if _a57 > _o82:
					return {"success": false, "error": "Scene contains too many nodes (>" + str(_o82) + ")"}
			_l79 = _r99(_m43)
			if not _l79.is_empty():
				_z15 = true
				if scene_info.root_node == "" and _l79.get("parent", "") == "":
					scene_info.root_node = _l79.get("name", "")
		elif _z15:
			if _m43.begins_with("["):
				if not _l79.is_empty():
					scene_info["nodes"].append(_l79)
					_a57 += 1
				_z15 = false
				_l79 = {}
			elif "=" in _m43:
				_c24(_l79, _m43)
	if _z15 and not _l79.is_empty():
		scene_info["nodes"].append(_l79)
	if _d28 != "":
		scene_info = _s24(scene_info, _d28)
	if include_scripts:
		scene_info["scripts"] = _u69(scene_info["nodes"], _f51)
	scene_info["filtered_content"] = _x62(scene_info)
	return scene_info
func _r99(line: String) -> Dictionary:
	var _a84 = {}
	var _h75 = RegEx.new()
	if _h75.compile(r'name="([^"]*)"') == OK:
		var _l97 = _h75.search(line)
		if _l97:
			_a84["name"] = _l97.get_string(1)
	if _h75.compile(r'type="([^"]*)"') == OK:
		var _q31 = _h75.search(line)
		if _q31:
			_a84["type"] = _q31.get_string(1)
	if _h75.compile(r'parent="([^"]*)"') == OK:
		var _q62 = _h75.search(line)
		if _q62:
			_a84["parent"] = _q62.get_string(1)
	if not _a84.has("parent"):
		_a84["parent"] = ""
	_a84["properties"] = {}
	_a84["full_path"] = _q40(_a84)
	return _a84
func _c24(_a84: Dictionary, line: String) -> void:
	var _o52 = line.find("=")
	if _o52 > 0:
		var _j26 = line.substr(0, _o52).strip_edges()
		var value = line.substr(_o52 + 1).strip_edges()
		_a84.properties[_j26] = value
		if _j26 == "script":
			_a84["script_path"] = value
			_a84["has_script"] = true
func _q40(_a84: Dictionary) -> String:
	var name = _a84.get("name", "")
	var parent = _a84.get("parent", "")
	if parent == "" or parent == ".":
		return name  
	else:
		return parent + "/" + name
func _s24(scene_info: Dictionary, _d28: String) -> Dictionary:
	var _v8 = scene_info.duplicate(true)
	_v8["nodes"] = []
	for node in scene_info["nodes"]:
		var node_path = node.get("full_path", "")
		var _d22 = node.get("name", "")
		if _d22 == _d28 or node_path == _d28 or node_path.begins_with(_d28 + "/"):
			_v8.nodes.append(node)
	return _v8
func _u69(nodes: Array, _f51: Dictionary) -> Array:
	var scripts = []
	for node in nodes:
		if scripts.size() >= _l32:
			break
		var _r98 = node.get("script_path", "")
		if _r98 != "" and _r98 != "null":
			var _p81 = _r66(_r98, _f51)
			if _p81 != "":
				var _y61 = null
				for script in scripts:
					if script.get("path", "") == _p81:
						_y61 = script
						break
				if _y61 == null:
					var _p22 = _m63(_p81)
					if _p22 != null:
						scripts.append(_p22)
	return scripts
func _y41(_j90: Array) -> Dictionary:
	var _f51 = {}
	for line in _j90:
		var _m43 = line.strip_edges()
		if _m43.begins_with("[ext_resource"):
			var _n81 = _u97(_m43)
			if _n81.has("id") and _n81.has("path"):
				_f51[_n81["id"]] = _n81["path"]
	return _f51
func _u97(line: String) -> Dictionary:
	var _n81 = {}
	var _w74 = RegEx.new()
	if _w74.compile(r'path="([^"]+)"') == OK:
		var _g29 = _w74.search(line)
		if _g29:
			_n81["path"] = _g29.get_string(1)
	var _z72 = RegEx.new()
	if _z72.compile(r'id="([^"]+)"') == OK:
		var _u83 = _z72.search(line)
		if _u83:
			_n81["id"] = _u83.get_string(1)
	return _n81
func _r66(_n22: String, _f51: Dictionary) -> String:
	var _u24 = RegEx.new()
	if _u24.compile(r'ExtResource\("([^"]+)"\)') == OK:
		var match = _u24.search(_n22)
		if match:
			var _l12 = match.get_string(1)
			if _f51.has(_l12):
				return _f51[_l12]
			else:
				return ""
	if _n22.begins_with("res://"):
		return _n22
	return ""
func _m63(_r98: String) -> Dictionary:
	if not FileAccess.file_exists(_r98):
		return {"path": _r98, "content": "Error: File not found", "error": true}
	var file = FileAccess.open(_r98, FileAccess.READ)
	if file == null:
		return {"path": _r98, "content": "Error: Cannot open file", "error": true}
	var _b65 = file.get_length()
	if _b65 > _o36:
		file.close()
		return {"path": _r98, "content": "Error: Script file too large (" + str(_b65) + " bytes, max " + str(_o36) + ")", "error": true}
	var content = file.get_as_text()
	file.close()
	return {
		"path": _r98,
		"content": content,
		"size": _b65,
		"error": false
	}
func _x62(scene_info: Dictionary) -> String:
	var scene_path = scene_info.get("scene_path", "")
	var root_node = scene_info.get("root_node", "")
	var nodes = scene_info.get("nodes", [])
	var scripts = scene_info.get("scripts", [])
	var content = "# Scene: " + scene_path + "\n"
	content += "# Root Node: " + root_node + "\n"
	content += "# Total Nodes: " + str(nodes.size()) + "\n\n"
	content += "## Node Tree:\n"
	var _j11 = _q81(nodes)
	for _z82 in _j11:
		content += _z82 + "\n"
	if not scripts.is_empty():
		content += "\n## Associated Scripts:\n"
		for _p22 in scripts:
			var _r98 = _p22.get("path", "")
			var _d87 = _p22.get("error", false)
			if _d87:
				content += "### Script: " + _r98 + " (" + _p22.get("content", "Error") + ")\n"
			else:
				content += "### Script: " + _r98 + "\n"
				content += "```gdscript\n"
				content += _p22.get("content", "")
				if not _p22.get("content", "").ends_with("\n"):
					content += "\n"
				content += "```\n\n"
	return content
func _q81(nodes: Array) -> Array:
	var _j11 = []
	var _p8 = {}
	for node in nodes:
		var path = node.get("full_path", node.get("name", ""))
		_p8[path] = node
	for node in nodes:
		var _d22 = node.get("name", "")
		var _k22 = node.get("type", "")
		var parent = node.get("parent", "")
		var full_path = node.get("full_path", "")
		var depth = 0
		if parent != "" and parent != ".":
			depth = parent.split("/").size()
		var indent = "  ".repeat(depth)
		var line = indent + "- " + _d22 + " (" + _k22 + ")"
		if node.has("script_path") and node.get("script_path", "") != "":
			line += " [script]"
		_j11.append(line)
	return _j11
func _l100(scene_path: String) -> bool:
	if not scene_path.begins_with("res://"):
		return false
	if not scene_path.to_lower().ends_with(".tscn"):
		return false
	if "../" in scene_path or scene_path.contains("..\\"):
		return false
	return true
func _n20() -> bool:
	if _n78:
		return true
	var _v50 = Time.get_ticks_msec()
	if (_v50 - _g81) > _p33:
		_n78 = true
		return true
	return false
func get_current_scene_nodes(_d84: EditorInterface) -> Dictionary:
	if not _d84:
		return {"success": false, "error": "Editor interface not available"}
	var _o65 = _d84.get_edited_scene_root()
	if not _o65:
		return {"success": false, "error": "No scene currently open in editor"}
	_g81 = Time.get_ticks_msec()
	_n78 = false
	var scene_info = {
		"success": true,
		"scene_path": "current_scene",
		"nodes": [],
		"root_node": _o65.name
	}
	_p51(_o65, scene_info["nodes"], "")
	return scene_info
func _p51(node: Node, nodes: Array, _y44: String) -> void:
	if _n20():
		return
	if nodes.size() > _o82:
		return
	var node_path = _y44
	if node_path != "":
		node_path += "/" + node.name
	else:
		node_path = node.name
	var _a84 = {
		"name": node.name,
		"type": node.get_class(),
		"full_path": node_path,
		"parent": _y44,
		"properties": {}
	}
	var script = node.get_script()
	if script:
		var _r98 = script.resource_path
		if _r98 != "":
			_a84["script_path"] = _r98
	nodes.append(_a84)
	for _h61 in node.get_children():
		_p51(_h61, nodes, node_path)
func _e56(_d84: EditorInterface, node_path: String) -> Dictionary:
	var scene_info = get_current_scene_nodes(_d84)
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
