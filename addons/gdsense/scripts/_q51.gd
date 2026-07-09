@tool
class_name _q51
extends RefCounted
const _x8 = 30000  
const _q96 = 1000       
const _x45 = 500 
const _u4 = 3        
var _i57: int
var _t94: bool = false
func _x51(scene_path: String, _q66: String = "", include_scripts: bool = false) -> Dictionary:
	_i57 = Time.get_ticks_msec()
	_t94 = false
	if not _x72(scene_path):
		return {"success": false, "error": "Invalid or insecure scene path: " + scene_path}
	if not FileAccess.file_exists(scene_path):
		return {"success": false, "error": "Scene file not found: " + scene_path}
	var file = FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		return {"success": false, "error": "Cannot open scene file: " + scene_path}
	var _q43 = file.get_length()
	if _q43 > _x8:
		file.close()
		return {"success": false, "error": "Scene file too large (" + str(_q43) + " bytes, max " + str(_x8) + ")"}
	var content = file.get_as_text()
	file.close()
	return _j82(content, scene_path, _q66, include_scripts)
func _j82(content: String, scene_path: String, _q66: String = "", include_scripts: bool = false) -> Dictionary:
	var _p91 = content.split("\n")
	var scene_info = {
		"success": true,
		"scene_path": scene_path,
		"nodes": [],
		"scripts": [],
		"root_node": "",
		"filtered_content": content
	}
	var _d83 = _b78(_p91)
	if OS.is_debug_build() and not _d83.is_empty():
		pass
	var _p77 = 0
	var _b31 = {}
	var _m21 = false
	if _y42():
		return {"success": false, "error": "Scene parsing timeout exceeded"}
	for i in range(_p91.size()):
		if _y42():
			return {"success": false, "error": "Scene parsing timeout exceeded"}
		var line = _p91[i]
		var _d81 = line.strip_edges()
		if _d81.begins_with("[node "):
			if _m21 and not _b31.is_empty():
				scene_info["nodes"].append(_b31)
				_p77 += 1
				if _p77 > _q96:
					return {"success": false, "error": "Scene contains too many nodes (>" + str(_q96) + ")"}
			_b31 = _u50(_d81)
			if not _b31.is_empty():
				_m21 = true
				if scene_info.root_node == "" and _b31.get("parent", "") == "":
					scene_info.root_node = _b31.get("name", "")
		elif _m21:
			if _d81.begins_with("["):
				if not _b31.is_empty():
					scene_info["nodes"].append(_b31)
					_p77 += 1
				_m21 = false
				_b31 = {}
			elif "=" in _d81:
				_g51(_b31, _d81)
	if _m21 and not _b31.is_empty():
		scene_info["nodes"].append(_b31)
	if _q66 != "":
		scene_info = _c69(scene_info, _q66)
	if include_scripts:
		scene_info["scripts"] = _g89(scene_info["nodes"], _d83)
	scene_info["filtered_content"] = _n94(scene_info)
	return scene_info
func _u50(line: String) -> Dictionary:
	var _k31 = {}
	var _h89 = RegEx.new()
	if _h89.compile(r'name="([^"]*)"') == OK:
		var _b27 = _h89.search(line)
		if _b27:
			_k31["name"] = _b27.get_string(1)
	if _h89.compile(r'type="([^"]*)"') == OK:
		var _w31 = _h89.search(line)
		if _w31:
			_k31["type"] = _w31.get_string(1)
	if _h89.compile(r'parent="([^"]*)"') == OK:
		var _e62 = _h89.search(line)
		if _e62:
			_k31["parent"] = _e62.get_string(1)
	if not _k31.has("parent"):
		_k31["parent"] = ""
	_k31["properties"] = {}
	_k31["full_path"] = _s84(_k31)
	return _k31
func _g51(_k31: Dictionary, line: String) -> void:
	var _o94 = line.find("=")
	if _o94 > 0:
		var _i19 = line.substr(0, _o94).strip_edges()
		var value = line.substr(_o94 + 1).strip_edges()
		_k31.properties[_i19] = value
		if _i19 == "script":
			_k31["script_path"] = value
			_k31["has_script"] = true
func _s84(_k31: Dictionary) -> String:
	var name = _k31.get("name", "")
	var parent = _k31.get("parent", "")
	if parent == "" or parent == ".":
		return name  
	else:
		return parent + "/" + name
func _c69(scene_info: Dictionary, _q66: String) -> Dictionary:
	var _f23 = scene_info.duplicate(true)
	_f23["nodes"] = []
	for node in scene_info["nodes"]:
		var node_path = node.get("full_path", "")
		var _q82 = node.get("name", "")
		if _q82 == _q66 or node_path == _q66 or node_path.begins_with(_q66 + "/"):
			_f23.nodes.append(node)
	return _f23
func _g89(nodes: Array, _d83: Dictionary) -> Array:
	var scripts = []
	for node in nodes:
		if scripts.size() >= _u4:
			break
		var _x58 = node.get("script_path", "")
		if _x58 != "" and _x58 != "null":
			var _v33 = _r88(_x58, _d83)
			if _v33 != "":
				var _q53 = null
				for script in scripts:
					if script.get("path", "") == _v33:
						_q53 = script
						break
				if _q53 == null:
					var _c63 = _g52(_v33)
					if _c63 != null:
						scripts.append(_c63)
	return scripts
func _b78(_p91: Array) -> Dictionary:
	var _d83 = {}
	for line in _p91:
		var _d81 = line.strip_edges()
		if _d81.begins_with("[ext_resource"):
			var _r40 = _d34(_d81)
			if _r40.has("id") and _r40.has("path"):
				_d83[_r40["id"]] = _r40["path"]
	return _d83
func _d34(line: String) -> Dictionary:
	var _r40 = {}
	var _q13 = RegEx.new()
	if _q13.compile(r'path="([^"]+)"') == OK:
		var _e85 = _q13.search(line)
		if _e85:
			_r40["path"] = _e85.get_string(1)
	var _w82 = RegEx.new()
	if _w82.compile(r'id="([^"]+)"') == OK:
		var _c87 = _w82.search(line)
		if _c87:
			_r40["id"] = _c87.get_string(1)
	return _r40
func _r88(_n11: String, _d83: Dictionary) -> String:
	var _t6 = RegEx.new()
	if _t6.compile(r'ExtResource\("([^"]+)"\)') == OK:
		var match = _t6.search(_n11)
		if match:
			var _u11 = match.get_string(1)
			if _d83.has(_u11):
				return _d83[_u11]
			else:
				return ""
	if _n11.begins_with("res://"):
		return _n11
	return ""
func _g52(_x58: String) -> Dictionary:
	if not FileAccess.file_exists(_x58):
		return {"path": _x58, "content": "Error: File not found", "error": true}
	var file = FileAccess.open(_x58, FileAccess.READ)
	if file == null:
		return {"path": _x58, "content": "Error: Cannot open file", "error": true}
	var _q43 = file.get_length()
	if _q43 > _x8:
		file.close()
		return {"path": _x58, "content": "Error: Script file too large (" + str(_q43) + " bytes, max " + str(_x8) + ")", "error": true}
	var content = file.get_as_text()
	file.close()
	return {
		"path": _x58,
		"content": content,
		"size": _q43,
		"error": false
	}
func _n94(scene_info: Dictionary) -> String:
	var scene_path = scene_info.get("scene_path", "")
	var root_node = scene_info.get("root_node", "")
	var nodes = scene_info.get("nodes", [])
	var scripts = scene_info.get("scripts", [])
	var content = "# Scene: " + scene_path + "\n"
	content += "# Root Node: " + root_node + "\n"
	content += "# Total Nodes: " + str(nodes.size()) + "\n\n"
	content += "## Node Tree:\n"
	var _y29 = _h54(nodes)
	for _o57 in _y29:
		content += _o57 + "\n"
	if not scripts.is_empty():
		content += "\n## Associated Scripts:\n"
		for _c63 in scripts:
			var _x58 = _c63.get("path", "")
			var _v57 = _c63.get("error", false)
			if _v57:
				content += "### Script: " + _x58 + " (" + _c63.get("content", "Error") + ")\n"
			else:
				content += "### Script: " + _x58 + "\n"
				content += "```gdscript\n"
				content += _c63.get("content", "")
				if not _c63.get("content", "").ends_with("\n"):
					content += "\n"
				content += "```\n\n"
	return content
func _h54(nodes: Array) -> Array:
	var _y29 = []
	var _i30 = {}
	for node in nodes:
		var path = node.get("full_path", node.get("name", ""))
		_i30[path] = node
	for node in nodes:
		var _q82 = node.get("name", "")
		var _s7 = node.get("type", "")
		var parent = node.get("parent", "")
		var full_path = node.get("full_path", "")
		var depth = 0
		if parent != "" and parent != ".":
			depth = parent.split("/").size()
		var indent = "  ".repeat(depth)
		var line = indent + "- " + _q82 + " (" + _s7 + ")"
		if node.has("script_path") and node.get("script_path", "") != "":
			line += " [script]"
		_y29.append(line)
	return _y29
func _x72(scene_path: String) -> bool:
	if not scene_path.begins_with("res://"):
		return false
	if not scene_path.to_lower().ends_with(".tscn"):
		return false
	if "../" in scene_path or scene_path.contains("..\\"):
		return false
	return true
func _y42() -> bool:
	if _t94:
		return true
	var _s36 = Time.get_ticks_msec()
	if (_s36 - _i57) > _x45:
		_t94 = true
		return true
	return false
func get_current_scene_nodes(_k71: EditorInterface) -> Dictionary:
	if not _k71:
		return {"success": false, "error": "Editor interface not available"}
	var _d100 = _k71.get_edited_scene_root()
	if not _d100:
		return {"success": false, "error": "No scene currently open in editor"}
	_i57 = Time.get_ticks_msec()
	_t94 = false
	var scene_info = {
		"success": true,
		"scene_path": "current_scene",
		"nodes": [],
		"root_node": _d100.name
	}
	_j44(_d100, scene_info["nodes"], "")
	return scene_info
func _j44(node: Node, nodes: Array, _s34: String) -> void:
	if _y42():
		return
	if nodes.size() > _q96:
		return
	var node_path = _s34
	if node_path != "":
		node_path += "/" + node.name
	else:
		node_path = node.name
	var _k31 = {
		"name": node.name,
		"type": node.get_class(),
		"full_path": node_path,
		"parent": _s34,
		"properties": {}
	}
	var script = node.get_script()
	if script:
		var _x58 = script.resource_path
		if _x58 != "":
			_k31["script_path"] = _x58
	nodes.append(_k31)
	for _x15 in node.get_children():
		_j44(_x15, nodes, node_path)
func _f94(_k71: EditorInterface, node_path: String) -> Dictionary:
	var scene_info = get_current_scene_nodes(_k71)
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
