@tool
class_name _b33
extends RefCounted

const _t59 = 30000  
const _f82 = 1000       
const _q63 = 500 
const _o89 = 3        

var _z17: int
var _w94: bool = false

func _z99(scene_path: String, _e10: String = "", include_scripts: bool = false) -> Dictionary:
	_z17 = Time.get_ticks_msec()
	_w94 = false
	
	if not _i24(scene_path):
		return {"success": false, "error": "Invalid or insecure scene path: " + scene_path}
	
	if not FileAccess.file_exists(scene_path):
		return {"success": false, "error": "Scene file not found: " + scene_path}
	
	var file = FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		return {"success": false, "error": "Cannot open scene file: " + scene_path}
	
	var _q1 = file.get_length()
	if _q1 > _t59:
		file.close()
		return {"success": false, "error": "Scene file too large (" + str(_q1) + " bytes, max " + str(_t59) + ")"}
	
	var content = file.get_as_text()
	file.close()
	
	return _y29(content, scene_path, _e10, include_scripts)

func _y29(content: String, scene_path: String, _e10: String = "", include_scripts: bool = false) -> Dictionary:
	var _b26 = content.split("\n")
	var scene_info = {
		"success": true,
		"scene_path": scene_path,
		"nodes": [],
		"scripts": [],
		"root_node": "",
		"filtered_content": content
	}
	
	var _q6 = _m7(_b26)
	
	if OS.is_debug_build() and not _q6.is_empty():
		pass

	var _t30 = 0
	var _l30 = {}
	var _a28 = false
	
	if _s24():
		return {"success": false, "error": "Scene parsing timeout exceeded"}
	
	for i in range(_b26.size()):
		if _s24():
			return {"success": false, "error": "Scene parsing timeout exceeded"}
		
		var line = _b26[i]
		var _e56 = line.strip_edges()
		
		if _e56.begins_with("[node "):
			if _a28 and not _l30.is_empty():
				scene_info["nodes"].append(_l30)
				_t30 += 1
				
				if _t30 > _f82:
					return {"success": false, "error": "Scene contains too many nodes (>" + str(_f82) + ")"}
			
			_l30 = _v99(_e56)
			if not _l30.is_empty():
				_a28 = true
				if scene_info.root_node == "" and _l30.get("parent", "") == "":
					scene_info.root_node = _l30.get("name", "")
		
		elif _a28:
			if _e56.begins_with("["):
				if not _l30.is_empty():
					scene_info["nodes"].append(_l30)
					_t30 += 1
				_a28 = false
				_l30 = {}
			elif "=" in _e56:
				_s39(_l30, _e56)
	
	if _a28 and not _l30.is_empty():
		scene_info["nodes"].append(_l30)
	
	if _e10 != "":
		scene_info = _q43(scene_info, _e10)
	
	if include_scripts:
		scene_info["scripts"] = _j38(scene_info["nodes"], _q6)

	scene_info["filtered_content"] = _j50(scene_info)
	
	return scene_info

func _v99(line: String) -> Dictionary:
	var _g30 = {}
	
	var _w38 = RegEx.new()
	if _w38.compile(r'name="([^"]*)"') == OK:
		var _c43 = _w38.search(line)
		if _c43:
			_g30["name"] = _c43.get_string(1)
	
	if _w38.compile(r'type="([^"]*)"') == OK:
		var _o25 = _w38.search(line)
		if _o25:
			_g30["type"] = _o25.get_string(1)
	
	if _w38.compile(r'parent="([^"]*)"') == OK:
		var _a95 = _w38.search(line)
		if _a95:
			_g30["parent"] = _a95.get_string(1)
	
	if not _g30.has("parent"):
		_g30["parent"] = ""
	
	_g30["properties"] = {}
	_g30["full_path"] = _d28(_g30)
	
	return _g30

func _s39(_g30: Dictionary, line: String) -> void:
	var _f56 = line.find("=")
	if _f56 > 0:
		var _m15 = line.substr(0, _f56).strip_edges()
		var value = line.substr(_f56 + 1).strip_edges()
		_g30.properties[_m15] = value
		
		if _m15 == "script":
			_g30["script_path"] = value
			_g30["has_script"] = true

func _d28(_g30: Dictionary) -> String:
	var name = _g30.get("name", "")
	var parent = _g30.get("parent", "")
	
	if parent == "" or parent == ".":
		return name  
	else:
		return parent + "/" + name

func _q43(scene_info: Dictionary, _e10: String) -> Dictionary:
	var _u43 = scene_info.duplicate(true)
	_u43["nodes"] = []
	
	for node in scene_info["nodes"]:
		var node_path = node.get("full_path", "")
		var _d97 = node.get("name", "")
		
		if _d97 == _e10 or node_path == _e10 or node_path.begins_with(_e10 + "/"):
			_u43.nodes.append(node)
	
	return _u43

func _j38(nodes: Array, _q6: Dictionary) -> Array:
	var scripts = []
	
	for node in nodes:
		if scripts.size() >= _o89:
			break
		
		var _r21 = node.get("script_path", "")
		if _r21 != "" and _r21 != "null":
			var _g95 = _f35(_r21, _q6)
			if _g95 != "":
				var _x53 = null
				for script in scripts:
					if script.get("path", "") == _g95:
						_x53 = script
						break
				
				if _x53 == null:
					var _j18 = _i50(_g95)
					if _j18 != null:
						scripts.append(_j18)
	
	return scripts

func _m7(_b26: Array) -> Dictionary:
	var _q6 = {}
	
	for line in _b26:
		var _e56 = line.strip_edges()
		
		if _e56.begins_with("[ext_resource"):
			var _q15 = _v59(_e56)
			if _q15.has("id") and _q15.has("path"):
				_q6[_q15["id"]] = _q15["path"]
	
	return _q6

func _v59(line: String) -> Dictionary:
	var _q15 = {}
	
	var _m82 = RegEx.new()
	if _m82.compile(r'path="([^"]+)"') == OK:
		var _r47 = _m82.search(line)
		if _r47:
			_q15["path"] = _r47.get_string(1)
	
	var _a66 = RegEx.new()
	if _a66.compile(r'id="([^"]+)"') == OK:
		var _l94 = _a66.search(line)
		if _l94:
			_q15["id"] = _l94.get_string(1)
	
	return _q15

func _f35(_e17: String, _q6: Dictionary) -> String:
	var _s41 = RegEx.new()
	if _s41.compile(r'ExtResource\("([^"]+)"\)') == OK:
		var match = _s41.search(_e17)
		if match:
			var _s86 = match.get_string(1)
			if _q6.has(_s86):
				return _q6[_s86]
			else:
				return ""
	
	if _e17.begins_with("res://"):
		return _e17
	
	return ""

func _i50(_r21: String) -> Dictionary:
	if not FileAccess.file_exists(_r21):
		return {"path": _r21, "content": "Error: File not found", "error": true}
	
	var file = FileAccess.open(_r21, FileAccess.READ)
	if file == null:
		return {"path": _r21, "content": "Error: Cannot open file", "error": true}
	
	var _q1 = file.get_length()
	if _q1 > _t59:
		file.close()
		return {"path": _r21, "content": "Error: Script file too large (" + str(_q1) + " bytes, max " + str(_t59) + ")", "error": true}
	
	var content = file.get_as_text()
	file.close()
	
	return {
		"path": _r21,
		"content": content,
		"size": _q1,
		"error": false
	}

func _j50(scene_info: Dictionary) -> String:
	var scene_path = scene_info.get("scene_path", "")
	var root_node = scene_info.get("root_node", "")
	var nodes = scene_info.get("nodes", [])
	var scripts = scene_info.get("scripts", [])

	var content = "# Scene: " + scene_path + "\n"
	content += "# Root Node: " + root_node + "\n"
	content += "# Total Nodes: " + str(nodes.size()) + "\n\n"

	content += "## Node Tree:\n"
	var _c2 = _u76(nodes)
	for _f44 in _c2:
		content += _f44 + "\n"

	if not scripts.is_empty():
		content += "\n## Associated Scripts:\n"
		for _j18 in scripts:
			var _r21 = _j18.get("path", "")
			var _r46 = _j18.get("error", false)
			
			if _r46:
				content += "### Script: " + _r21 + " (" + _j18.get("content", "Error") + ")\n"
			else:
				content += "### Script: " + _r21 + "\n"
				content += "```gdscript\n"
				content += _j18.get("content", "")
				if not _j18.get("content", "").ends_with("\n"):
					content += "\n"
				content += "```\n\n"
	
	return content

func _u76(nodes: Array) -> Array:
	var _c2 = []
	var _d11 = {}
	
	for node in nodes:
		var path = node.get("full_path", node.get("name", ""))
		_d11[path] = node
	
	for node in nodes:
		var _d97 = node.get("name", "")
		var _k34 = node.get("type", "")
		var parent = node.get("parent", "")
		var full_path = node.get("full_path", "")
		
		var depth = 0
		if parent != "" and parent != ".":
			depth = parent.split("/").size()
		
		var indent = "  ".repeat(depth)
		var line = indent + "- " + _d97 + " (" + _k34 + ")"
		
		if node.has("script_path") and node.get("script_path", "") != "":
			line += " [script]"
		
		_c2.append(line)
	
	return _c2

func _i24(scene_path: String) -> bool:
	if not scene_path.begins_with("res://"):
		return false
	
	if not scene_path.to_lower().ends_with(".tscn"):
		return false
	
	if "../" in scene_path or scene_path.contains("..\\"):
		return false
	
	return true

func _s24() -> bool:
	if _w94:
		return true
	
	var _y68 = Time.get_ticks_msec()
	if (_y68 - _z17) > _q63:
		_w94 = true
		return true
	
	return false

func get_current_scene_nodes(_i86: EditorInterface) -> Dictionary:
	if not _i86:
		return {"success": false, "error": "Editor interface not available"}
	
	var _u59 = _i86.get_edited_scene_root()
	if not _u59:
		return {"success": false, "error": "No scene currently open in editor"}
	
	_z17 = Time.get_ticks_msec()
	_w94 = false
	
	var scene_info = {
		"success": true,
		"scene_path": "current_scene",
		"nodes": [],
		"root_node": _u59.name
	}
	
	_r25(_u59, scene_info["nodes"], "")
	
	return scene_info

func _r25(node: Node, nodes: Array, _p23: String) -> void:
	if _s24():
		return
	
	if nodes.size() > _f82:
		return
	
	var node_path = _p23
	if node_path != "":
		node_path += "/" + node.name
	else:
		node_path = node.name
	
	var _g30 = {
		"name": node.name,
		"type": node.get_class(),
		"full_path": node_path,
		"parent": _p23,
		"properties": {}
	}
	
	var script = node.get_script()
	if script:
		var _r21 = script.resource_path
		if _r21 != "":
			_g30["script_path"] = _r21
	
	nodes.append(_g30)
	
	for _j75 in node.get_children():
		_r25(_j75, nodes, node_path)

func _p93(_i86: EditorInterface, node_path: String) -> Dictionary:
	var scene_info = get_current_scene_nodes(_i86)
	
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

