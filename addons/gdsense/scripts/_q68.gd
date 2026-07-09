@tool
class_name _q68
extends RefCounted
const _q18 = 30000  
const _t45 = 1000       
const _r28 = 500 
const _z41 = 3        
var _u79: int
var _u96: bool = false
func _z97(scene_path: String, _c36: String = "", include_scripts: bool = false) -> Dictionary:
	_u79 = Time.get_ticks_msec()
	_u96 = false
	if not _q4(scene_path):
		return {"success": false, "error": "Invalid or insecure scene path: " + scene_path}
	if not FileAccess.file_exists(scene_path):
		return {"success": false, "error": "Scene file not found: " + scene_path}
	var file = FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		return {"success": false, "error": "Cannot open scene file: " + scene_path}
	var _l43 = file.get_length()
	if _l43 > _q18:
		file.close()
		return {"success": false, "error": "Scene file too large (" + str(_l43) + " bytes, max " + str(_q18) + ")"}
	var content = file.get_as_text()
	file.close()
	return _n59(content, scene_path, _c36, include_scripts)
func _n59(content: String, scene_path: String, _c36: String = "", include_scripts: bool = false) -> Dictionary:
	var _t70 = content.split("\n")
	var scene_info = {
		"success": true,
		"scene_path": scene_path,
		"nodes": [],
		"scripts": [],
		"root_node": "",
		"filtered_content": content
	}
	var _h95 = _n52(_t70)
	if OS.is_debug_build() and not _h95.is_empty():
		pass
	var _w6 = 0
	var _n31 = {}
	var _r35 = false
	if _c15():
		return {"success": false, "error": "Scene parsing timeout exceeded"}
	for i in range(_t70.size()):
		if _c15():
			return {"success": false, "error": "Scene parsing timeout exceeded"}
		var line = _t70[i]
		var _s9 = line.strip_edges()
		if _s9.begins_with("[node "):
			if _r35 and not _n31.is_empty():
				scene_info["nodes"].append(_n31)
				_w6 += 1
				if _w6 > _t45:
					return {"success": false, "error": "Scene contains too many nodes (>" + str(_t45) + ")"}
			_n31 = _q51(_s9)
			if not _n31.is_empty():
				_r35 = true
				if scene_info.root_node == "" and _n31.get("parent", "") == "":
					scene_info.root_node = _n31.get("name", "")
		elif _r35:
			if _s9.begins_with("["):
				if not _n31.is_empty():
					scene_info["nodes"].append(_n31)
					_w6 += 1
				_r35 = false
				_n31 = {}
			elif "=" in _s9:
				_e72(_n31, _s9)
	if _r35 and not _n31.is_empty():
		scene_info["nodes"].append(_n31)
	if _c36 != "":
		scene_info = _b34(scene_info, _c36)
	if include_scripts:
		scene_info["scripts"] = _r25(scene_info["nodes"], _h95)
	scene_info["filtered_content"] = _a26(scene_info)
	return scene_info
func _q51(line: String) -> Dictionary:
	var _e50 = {}
	var _b97 = RegEx.new()
	if _b97.compile(r'name="([^"]*)"') == OK:
		var _u87 = _b97.search(line)
		if _u87:
			_e50["name"] = _u87.get_string(1)
	if _b97.compile(r'type="([^"]*)"') == OK:
		var _v57 = _b97.search(line)
		if _v57:
			_e50["type"] = _v57.get_string(1)
	if _b97.compile(r'parent="([^"]*)"') == OK:
		var _t23 = _b97.search(line)
		if _t23:
			_e50["parent"] = _t23.get_string(1)
	if not _e50.has("parent"):
		_e50["parent"] = ""
	_e50["properties"] = {}
	_e50["full_path"] = _l44(_e50)
	return _e50
func _e72(_e50: Dictionary, line: String) -> void:
	var _h19 = line.find("=")
	if _h19 > 0:
		var _y40 = line.substr(0, _h19).strip_edges()
		var value = line.substr(_h19 + 1).strip_edges()
		_e50.properties[_y40] = value
		if _y40 == "script":
			_e50["script_path"] = value
			_e50["has_script"] = true
func _l44(_e50: Dictionary) -> String:
	var name = _e50.get("name", "")
	var parent = _e50.get("parent", "")
	if parent == "" or parent == ".":
		return name  
	else:
		return parent + "/" + name
func _b34(scene_info: Dictionary, _c36: String) -> Dictionary:
	var _n34 = scene_info.duplicate(true)
	_n34["nodes"] = []
	for node in scene_info["nodes"]:
		var node_path = node.get("full_path", "")
		var _e92 = node.get("name", "")
		if _e92 == _c36 or node_path == _c36 or node_path.begins_with(_c36 + "/"):
			_n34.nodes.append(node)
	return _n34
func _r25(nodes: Array, _h95: Dictionary) -> Array:
	var scripts = []
	for node in nodes:
		if scripts.size() >= _z41:
			break
		var _w48 = node.get("script_path", "")
		if _w48 != "" and _w48 != "null":
			var _k90 = _g94(_w48, _h95)
			if _k90 != "":
				var _l73 = null
				for script in scripts:
					if script.get("path", "") == _k90:
						_l73 = script
						break
				if _l73 == null:
					var _f76 = _c68(_k90)
					if _f76 != null:
						scripts.append(_f76)
	return scripts
func _n52(_t70: Array) -> Dictionary:
	var _h95 = {}
	for line in _t70:
		var _s9 = line.strip_edges()
		if _s9.begins_with("[ext_resource"):
			var _y83 = _a74(_s9)
			if _y83.has("id") and _y83.has("path"):
				_h95[_y83["id"]] = _y83["path"]
	return _h95
func _a74(line: String) -> Dictionary:
	var _y83 = {}
	var _m21 = RegEx.new()
	if _m21.compile(r'path="([^"]+)"') == OK:
		var _f89 = _m21.search(line)
		if _f89:
			_y83["path"] = _f89.get_string(1)
	var _n91 = RegEx.new()
	if _n91.compile(r'id="([^"]+)"') == OK:
		var _j35 = _n91.search(line)
		if _j35:
			_y83["id"] = _j35.get_string(1)
	return _y83
func _g94(_z31: String, _h95: Dictionary) -> String:
	var _f36 = RegEx.new()
	if _f36.compile(r'ExtResource\("([^"]+)"\)') == OK:
		var match = _f36.search(_z31)
		if match:
			var _a54 = match.get_string(1)
			if _h95.has(_a54):
				return _h95[_a54]
			else:
				return ""
	if _z31.begins_with("res://"):
		return _z31
	return ""
func _c68(_w48: String) -> Dictionary:
	if not FileAccess.file_exists(_w48):
		return {"path": _w48, "content": "Error: File not found", "error": true}
	var file = FileAccess.open(_w48, FileAccess.READ)
	if file == null:
		return {"path": _w48, "content": "Error: Cannot open file", "error": true}
	var _l43 = file.get_length()
	if _l43 > _q18:
		file.close()
		return {"path": _w48, "content": "Error: Script file too large (" + str(_l43) + " bytes, max " + str(_q18) + ")", "error": true}
	var content = file.get_as_text()
	file.close()
	return {
		"path": _w48,
		"content": content,
		"size": _l43,
		"error": false
	}
func _a26(scene_info: Dictionary) -> String:
	var scene_path = scene_info.get("scene_path", "")
	var root_node = scene_info.get("root_node", "")
	var nodes = scene_info.get("nodes", [])
	var scripts = scene_info.get("scripts", [])
	var content = "# Scene: " + scene_path + "\n"
	content += "# Root Node: " + root_node + "\n"
	content += "# Total Nodes: " + str(nodes.size()) + "\n\n"
	content += "## Node Tree:\n"
	var _e22 = _w84(nodes)
	for _f85 in _e22:
		content += _f85 + "\n"
	if not scripts.is_empty():
		content += "\n## Associated Scripts:\n"
		for _f76 in scripts:
			var _w48 = _f76.get("path", "")
			var _w56 = _f76.get("error", false)
			if _w56:
				content += "### Script: " + _w48 + " (" + _f76.get("content", "Error") + ")\n"
			else:
				content += "### Script: " + _w48 + "\n"
				content += "```gdscript\n"
				content += _f76.get("content", "")
				if not _f76.get("content", "").ends_with("\n"):
					content += "\n"
				content += "```\n\n"
	return content
func _w84(nodes: Array) -> Array:
	var _e22 = []
	var _o49 = {}
	for node in nodes:
		var path = node.get("full_path", node.get("name", ""))
		_o49[path] = node
	for node in nodes:
		var _e92 = node.get("name", "")
		var _g86 = node.get("type", "")
		var parent = node.get("parent", "")
		var full_path = node.get("full_path", "")
		var depth = 0
		if parent != "" and parent != ".":
			depth = parent.split("/").size()
		var indent = "  ".repeat(depth)
		var line = indent + "- " + _e92 + " (" + _g86 + ")"
		if node.has("script_path") and node.get("script_path", "") != "":
			line += " [script]"
		_e22.append(line)
	return _e22
func _q4(scene_path: String) -> bool:
	if not scene_path.begins_with("res://"):
		return false
	if not scene_path.to_lower().ends_with(".tscn"):
		return false
	if "../" in scene_path or scene_path.contains("..\\"):
		return false
	return true
func _c15() -> bool:
	if _u96:
		return true
	var _n75 = Time.get_ticks_msec()
	if (_n75 - _u79) > _r28:
		_u96 = true
		return true
	return false
func get_current_scene_nodes(_i13: EditorInterface) -> Dictionary:
	if not _i13:
		return {"success": false, "error": "Editor interface not available"}
	var _o34 = _i13.get_edited_scene_root()
	if not _o34:
		return {"success": false, "error": "No scene currently open in editor"}
	_u79 = Time.get_ticks_msec()
	_u96 = false
	var scene_info = {
		"success": true,
		"scene_path": "current_scene",
		"nodes": [],
		"root_node": _o34.name
	}
	_j15(_o34, scene_info["nodes"], "")
	return scene_info
func _j15(node: Node, nodes: Array, _e73: String) -> void:
	if _c15():
		return
	if nodes.size() > _t45:
		return
	var node_path = _e73
	if node_path != "":
		node_path += "/" + node.name
	else:
		node_path = node.name
	var _e50 = {
		"name": node.name,
		"type": node.get_class(),
		"full_path": node_path,
		"parent": _e73,
		"properties": {}
	}
	var script = node.get_script()
	if script:
		var _w48 = script.resource_path
		if _w48 != "":
			_e50["script_path"] = _w48
	nodes.append(_e50)
	for _o14 in node.get_children():
		_j15(_o14, nodes, node_path)
func _c17(_i13: EditorInterface, node_path: String) -> Dictionary:
	var scene_info = get_current_scene_nodes(_i13)
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
