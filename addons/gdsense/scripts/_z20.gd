@tool
class_name _z20
extends RefCounted

const _v57 = 30000  
const _n39 = 1000       
const _y3 = 500 
const _u1 = 3        

var _l45: int
var _j11: bool = false

func _u98(scene_path: String, _b16: String = "", include_scripts: bool = false) -> Dictionary:
	_l45 = Time.get_ticks_msec()
	_j11 = false
	
	if not _g76(scene_path):
		return {"success": false, "error": "Invalid or insecure scene path: " + scene_path}
	
	if not FileAccess.file_exists(scene_path):
		return {"success": false, "error": "Scene file not found: " + scene_path}
	
	var file = FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		return {"success": false, "error": "Cannot open scene file: " + scene_path}
	
	var _g9 = file.get_length()
	if _g9 > _v57:
		file.close()
		return {"success": false, "error": "Scene file too large (" + str(_g9) + " bytes, max " + str(_v57) + ")"}
	
	var content = file.get_as_text()
	file.close()
	
	return _b4(content, scene_path, _b16, include_scripts)

func _b4(content: String, scene_path: String, _b16: String = "", include_scripts: bool = false) -> Dictionary:
	var _d41 = content.split("\n")
	var scene_info = {
		"success": true,
		"scene_path": scene_path,
		"nodes": [],
		"scripts": [],
		"root_node": "",
		"filtered_content": content
	}
	
	var _p8 = _t29(_d41)
	
	if OS.is_debug_build() and not _p8.is_empty():
		pass

	var _w50 = 0
	var _o3 = {}
	var _y32 = false
	
	if _b88():
		return {"success": false, "error": "Scene parsing timeout exceeded"}
	
	for i in range(_d41.size()):
		if _b88():
			return {"success": false, "error": "Scene parsing timeout exceeded"}
		
		var line = _d41[i]
		var _b43 = line.strip_edges()
		
		if _b43.begins_with("[node "):
			if _y32 and not _o3.is_empty():
				scene_info["nodes"].append(_o3)
				_w50 += 1
				
				if _w50 > _n39:
					return {"success": false, "error": "Scene contains too many nodes (>" + str(_n39) + ")"}
			
			_o3 = _y15(_b43)
			if not _o3.is_empty():
				_y32 = true
				if scene_info.root_node == "" and _o3.get("parent", "") == "":
					scene_info.root_node = _o3.get("name", "")
		
		elif _y32:
			if _b43.begins_with("["):
				if not _o3.is_empty():
					scene_info["nodes"].append(_o3)
					_w50 += 1
				_y32 = false
				_o3 = {}
			elif "=" in _b43:
				_t71(_o3, _b43)
	
	if _y32 and not _o3.is_empty():
		scene_info["nodes"].append(_o3)
	
	if _b16 != "":
		scene_info = _t56(scene_info, _b16)
	
	if include_scripts:
		scene_info["scripts"] = _h39(scene_info["nodes"], _p8)

	scene_info["filtered_content"] = _h35(scene_info)
	
	return scene_info

func _y15(line: String) -> Dictionary:
	var _i57 = {}
	
	var _r34 = RegEx.new()
	if _r34.compile(r'name="([^"]*)"') == OK:
		var _p5 = _r34.search(line)
		if _p5:
			_i57["name"] = _p5.get_string(1)
	
	if _r34.compile(r'type="([^"]*)"') == OK:
		var _b1 = _r34.search(line)
		if _b1:
			_i57["type"] = _b1.get_string(1)
	
	if _r34.compile(r'parent="([^"]*)"') == OK:
		var _c4 = _r34.search(line)
		if _c4:
			_i57["parent"] = _c4.get_string(1)
	
	if not _i57.has("parent"):
		_i57["parent"] = ""
	
	_i57["properties"] = {}
	_i57["full_path"] = _i35(_i57)
	
	return _i57

func _t71(_i57: Dictionary, line: String) -> void:
	var _f22 = line.find("=")
	if _f22 > 0:
		var _t90 = line.substr(0, _f22).strip_edges()
		var value = line.substr(_f22 + 1).strip_edges()
		_i57.properties[_t90] = value
		
		if _t90 == "script":
			_i57["script_path"] = value
			_i57["has_script"] = true

func _i35(_i57: Dictionary) -> String:
	var name = _i57.get("name", "")
	var parent = _i57.get("parent", "")
	
	if parent == "" or parent == ".":
		return name  
	else:
		return parent + "/" + name

func _t56(scene_info: Dictionary, _b16: String) -> Dictionary:
	var _i80 = scene_info.duplicate(true)
	_i80["nodes"] = []
	
	for node in scene_info["nodes"]:
		var node_path = node.get("full_path", "")
		var _u27 = node.get("name", "")
		
		if _u27 == _b16 or node_path == _b16 or node_path.begins_with(_b16 + "/"):
			_i80.nodes.append(node)
	
	return _i80

func _h39(nodes: Array, _p8: Dictionary) -> Array:
	var scripts = []
	
	for node in nodes:
		if scripts.size() >= _u1:
			break
		
		var _f85 = node.get("script_path", "")
		if _f85 != "" and _f85 != "null":
			var _a8 = _g70(_f85, _p8)
			if _a8 != "":
				var _z44 = null
				for script in scripts:
					if script.get("path", "") == _a8:
						_z44 = script
						break
				
				if _z44 == null:
					var _v80 = _q27(_a8)
					if _v80 != null:
						scripts.append(_v80)
	
	return scripts

func _t29(_d41: Array) -> Dictionary:
	var _p8 = {}
	
	for line in _d41:
		var _b43 = line.strip_edges()
		
		if _b43.begins_with("[ext_resource"):
			var _z66 = _c56(_b43)
			if _z66.has("id") and _z66.has("path"):
				_p8[_z66["id"]] = _z66["path"]
	
	return _p8

func _c56(line: String) -> Dictionary:
	var _z66 = {}
	
	var _m83 = RegEx.new()
	if _m83.compile(r'path="([^"]+)"') == OK:
		var _c12 = _m83.search(line)
		if _c12:
			_z66["path"] = _c12.get_string(1)
	
	var _r50 = RegEx.new()
	if _r50.compile(r'id="([^"]+)"') == OK:
		var _r20 = _r50.search(line)
		if _r20:
			_z66["id"] = _r20.get_string(1)
	
	return _z66

func _g70(_f43: String, _p8: Dictionary) -> String:
	var _q99 = RegEx.new()
	if _q99.compile(r'ExtResource\("([^"]+)"\)') == OK:
		var match = _q99.search(_f43)
		if match:
			var _e62 = match.get_string(1)
			if _p8.has(_e62):
				return _p8[_e62]
			else:
				return ""
	
	if _f43.begins_with("res://"):
		return _f43
	
	return ""

func _q27(_f85: String) -> Dictionary:
	if not FileAccess.file_exists(_f85):
		return {"path": _f85, "content": "Error: File not found", "error": true}
	
	var file = FileAccess.open(_f85, FileAccess.READ)
	if file == null:
		return {"path": _f85, "content": "Error: Cannot open file", "error": true}
	
	var _g9 = file.get_length()
	if _g9 > _v57:
		file.close()
		return {"path": _f85, "content": "Error: Script file too large (" + str(_g9) + " bytes, max " + str(_v57) + ")", "error": true}
	
	var content = file.get_as_text()
	file.close()
	
	return {
		"path": _f85,
		"content": content,
		"size": _g9,
		"error": false
	}

func _h35(scene_info: Dictionary) -> String:
	var scene_path = scene_info.get("scene_path", "")
	var root_node = scene_info.get("root_node", "")
	var nodes = scene_info.get("nodes", [])
	var scripts = scene_info.get("scripts", [])

	var content = "# Scene: " + scene_path + "\n"
	content += "# Root Node: " + root_node + "\n"
	content += "# Total Nodes: " + str(nodes.size()) + "\n\n"

	content += "## Node Tree:\n"
	var _q16 = _v86(nodes)
	for _x99 in _q16:
		content += _x99 + "\n"

	if not scripts.is_empty():
		content += "\n## Associated Scripts:\n"
		for _v80 in scripts:
			var _f85 = _v80.get("path", "")
			var _z73 = _v80.get("error", false)
			
			if _z73:
				content += "### Script: " + _f85 + " (" + _v80.get("content", "Error") + ")\n"
			else:
				content += "### Script: " + _f85 + "\n"
				content += "```gdscript\n"
				content += _v80.get("content", "")
				if not _v80.get("content", "").ends_with("\n"):
					content += "\n"
				content += "```\n\n"
	
	return content

func _v86(nodes: Array) -> Array:
	var _q16 = []
	var _w94 = {}
	
	for node in nodes:
		var path = node.get("full_path", node.get("name", ""))
		_w94[path] = node
	
	for node in nodes:
		var _u27 = node.get("name", "")
		var _a88 = node.get("type", "")
		var parent = node.get("parent", "")
		var full_path = node.get("full_path", "")
		
		var depth = 0
		if parent != "" and parent != ".":
			depth = parent.split("/").size()
		
		var indent = "  ".repeat(depth)
		var line = indent + "- " + _u27 + " (" + _a88 + ")"
		
		if node.has("script_path") and node.get("script_path", "") != "":
			line += " [script]"
		
		_q16.append(line)
	
	return _q16

func _g76(scene_path: String) -> bool:
	if not scene_path.begins_with("res://"):
		return false
	
	if not scene_path.to_lower().ends_with(".tscn"):
		return false
	
	if "../" in scene_path or scene_path.contains("..\\"):
		return false
	
	return true

func _b88() -> bool:
	if _j11:
		return true
	
	var _l95 = Time.get_ticks_msec()
	if (_l95 - _l45) > _y3:
		_j11 = true
		return true
	
	return false

func get_current_scene_nodes(_f28: EditorInterface) -> Dictionary:
	if not _f28:
		return {"success": false, "error": "Editor interface not available"}
	
	var _t48 = _f28.get_edited_scene_root()
	if not _t48:
		return {"success": false, "error": "No scene currently open in editor"}
	
	_l45 = Time.get_ticks_msec()
	_j11 = false
	
	var scene_info = {
		"success": true,
		"scene_path": "current_scene",
		"nodes": [],
		"root_node": _t48.name
	}
	
	_n11(_t48, scene_info["nodes"], "")
	
	return scene_info

func _n11(node: Node, nodes: Array, _b59: String) -> void:
	if _b88():
		return
	
	if nodes.size() > _n39:
		return
	
	var node_path = _b59
	if node_path != "":
		node_path += "/" + node.name
	else:
		node_path = node.name
	
	var _i57 = {
		"name": node.name,
		"type": node.get_class(),
		"full_path": node_path,
		"parent": _b59,
		"properties": {}
	}
	
	var script = node.get_script()
	if script:
		var _f85 = script.resource_path
		if _f85 != "":
			_i57["script_path"] = _f85
	
	nodes.append(_i57)
	
	for _c100 in node.get_children():
		_n11(_c100, nodes, node_path)

func _r64(_f28: EditorInterface, node_path: String) -> Dictionary:
	var scene_info = get_current_scene_nodes(_f28)
	
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

