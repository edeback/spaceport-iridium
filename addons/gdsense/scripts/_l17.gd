@tool
class_name _l17
extends RefCounted

const _k58 = 30000  
const _j99 = 1000       
const _z61 = 500 
const _k67 = 3        

var _w92: int
var _w90: bool = false

func _l46(scene_path: String, _w67: String = "", include_scripts: bool = false) -> Dictionary:
	_w92 = Time.get_ticks_msec()
	_w90 = false
	
	if not _s61(scene_path):
		return {"success": false, "error": "Invalid or insecure scene path: " + scene_path}
	
	if not FileAccess.file_exists(scene_path):
		return {"success": false, "error": "Scene file not found: " + scene_path}
	
	var file = FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		return {"success": false, "error": "Cannot open scene file: " + scene_path}
	
	var _b9 = file.get_length()
	if _b9 > _k58:
		file.close()
		return {"success": false, "error": "Scene file too large (" + str(_b9) + " bytes, max " + str(_k58) + ")"}
	
	var content = file.get_as_text()
	file.close()
	
	return _d24(content, scene_path, _w67, include_scripts)

func _d24(content: String, scene_path: String, _w67: String = "", include_scripts: bool = false) -> Dictionary:
	var _m12 = content.split("\n")
	var scene_info = {
		"success": true,
		"scene_path": scene_path,
		"nodes": [],
		"scripts": [],
		"root_node": "",
		"filtered_content": content
	}
	
	var _b23 = _k87(_m12)
	
	if OS.is_debug_build() and not _b23.is_empty():
		pass

	var _n37 = 0
	var _b35 = {}
	var _r68 = false
	
	if _d72():
		return {"success": false, "error": "Scene parsing timeout exceeded"}
	
	for i in range(_m12.size()):
		if _d72():
			return {"success": false, "error": "Scene parsing timeout exceeded"}
		
		var line = _m12[i]
		var _r86 = line.strip_edges()
		
		if _r86.begins_with("[node "):
			if _r68 and not _b35.is_empty():
				scene_info["nodes"].append(_b35)
				_n37 += 1
				
				if _n37 > _j99:
					return {"success": false, "error": "Scene contains too many nodes (>" + str(_j99) + ")"}
			
			_b35 = _l90(_r86)
			if not _b35.is_empty():
				_r68 = true
				if scene_info.root_node == "" and _b35.get("parent", "") == "":
					scene_info.root_node = _b35.get("name", "")
		
		elif _r68:
			if _r86.begins_with("["):
				if not _b35.is_empty():
					scene_info["nodes"].append(_b35)
					_n37 += 1
				_r68 = false
				_b35 = {}
			elif "=" in _r86:
				_w86(_b35, _r86)
	
	if _r68 and not _b35.is_empty():
		scene_info["nodes"].append(_b35)
	
	if _w67 != "":
		scene_info = _u76(scene_info, _w67)
	
	if include_scripts:
		scene_info["scripts"] = _s96(scene_info["nodes"], _b23)

	scene_info["filtered_content"] = _s17(scene_info)
	
	return scene_info

func _l90(line: String) -> Dictionary:
	var _p92 = {}
	
	var _g53 = RegEx.new()
	if _g53.compile(r'name="([^"]*)"') == OK:
		var _l66 = _g53.search(line)
		if _l66:
			_p92["name"] = _l66.get_string(1)
	
	if _g53.compile(r'type="([^"]*)"') == OK:
		var _t99 = _g53.search(line)
		if _t99:
			_p92["type"] = _t99.get_string(1)
	
	if _g53.compile(r'parent="([^"]*)"') == OK:
		var _x23 = _g53.search(line)
		if _x23:
			_p92["parent"] = _x23.get_string(1)
	
	if not _p92.has("parent"):
		_p92["parent"] = ""
	
	_p92["properties"] = {}
	_p92["full_path"] = _h17(_p92)
	
	return _p92

func _w86(_p92: Dictionary, line: String) -> void:
	var _r98 = line.find("=")
	if _r98 > 0:
		var _y48 = line.substr(0, _r98).strip_edges()
		var value = line.substr(_r98 + 1).strip_edges()
		_p92.properties[_y48] = value
		
		if _y48 == "script":
			_p92["script_path"] = value
			_p92["has_script"] = true

func _h17(_p92: Dictionary) -> String:
	var name = _p92.get("name", "")
	var parent = _p92.get("parent", "")
	
	if parent == "" or parent == ".":
		return name  
	else:
		return parent + "/" + name

func _u76(scene_info: Dictionary, _w67: String) -> Dictionary:
	var _k1 = scene_info.duplicate(true)
	_k1["nodes"] = []
	
	for node in scene_info["nodes"]:
		var node_path = node.get("full_path", "")
		var _z48 = node.get("name", "")
		
		if _z48 == _w67 or node_path == _w67 or node_path.begins_with(_w67 + "/"):
			_k1.nodes.append(node)
	
	return _k1

func _s96(nodes: Array, _b23: Dictionary) -> Array:
	var scripts = []
	
	for node in nodes:
		if scripts.size() >= _k67:
			break
		
		var _d36 = node.get("script_path", "")
		if _d36 != "" and _d36 != "null":
			var _k4 = _g87(_d36, _b23)
			if _k4 != "":
				var _l3 = null
				for script in scripts:
					if script.get("path", "") == _k4:
						_l3 = script
						break
				
				if _l3 == null:
					var _o93 = _l51(_k4)
					if _o93 != null:
						scripts.append(_o93)
	
	return scripts

func _k87(_m12: Array) -> Dictionary:
	var _b23 = {}
	
	for line in _m12:
		var _r86 = line.strip_edges()
		
		if _r86.begins_with("[ext_resource"):
			var _v65 = _a4(_r86)
			if _v65.has("id") and _v65.has("path"):
				_b23[_v65["id"]] = _v65["path"]
	
	return _b23

func _a4(line: String) -> Dictionary:
	var _v65 = {}
	
	var _m15 = RegEx.new()
	if _m15.compile(r'path="([^"]+)"') == OK:
		var _z92 = _m15.search(line)
		if _z92:
			_v65["path"] = _z92.get_string(1)
	
	var _p15 = RegEx.new()
	if _p15.compile(r'id="([^"]+)"') == OK:
		var _a40 = _p15.search(line)
		if _a40:
			_v65["id"] = _a40.get_string(1)
	
	return _v65

func _g87(_q50: String, _b23: Dictionary) -> String:
	var _m60 = RegEx.new()
	if _m60.compile(r'ExtResource\("([^"]+)"\)') == OK:
		var match = _m60.search(_q50)
		if match:
			var _r13 = match.get_string(1)
			if _b23.has(_r13):
				return _b23[_r13]
			else:
				return ""
	
	if _q50.begins_with("res://"):
		return _q50
	
	return ""

func _l51(_d36: String) -> Dictionary:
	if not FileAccess.file_exists(_d36):
		return {"path": _d36, "content": "Error: File not found", "error": true}
	
	var file = FileAccess.open(_d36, FileAccess.READ)
	if file == null:
		return {"path": _d36, "content": "Error: Cannot open file", "error": true}
	
	var _b9 = file.get_length()
	if _b9 > _k58:
		file.close()
		return {"path": _d36, "content": "Error: Script file too large (" + str(_b9) + " bytes, max " + str(_k58) + ")", "error": true}
	
	var content = file.get_as_text()
	file.close()
	
	return {
		"path": _d36,
		"content": content,
		"size": _b9,
		"error": false
	}

func _s17(scene_info: Dictionary) -> String:
	var scene_path = scene_info.get("scene_path", "")
	var root_node = scene_info.get("root_node", "")
	var nodes = scene_info.get("nodes", [])
	var scripts = scene_info.get("scripts", [])

	var content = "# Scene: " + scene_path + "\n"
	content += "# Root Node: " + root_node + "\n"
	content += "# Total Nodes: " + str(nodes.size()) + "\n\n"

	content += "## Node Tree:\n"
	var _c32 = _l41(nodes)
	for _b80 in _c32:
		content += _b80 + "\n"

	if not scripts.is_empty():
		content += "\n## Associated Scripts:\n"
		for _o93 in scripts:
			var _d36 = _o93.get("path", "")
			var _j49 = _o93.get("error", false)
			
			if _j49:
				content += "### Script: " + _d36 + " (" + _o93.get("content", "Error") + ")\n"
			else:
				content += "### Script: " + _d36 + "\n"
				content += "```gdscript\n"
				content += _o93.get("content", "")
				if not _o93.get("content", "").ends_with("\n"):
					content += "\n"
				content += "```\n\n"
	
	return content

func _l41(nodes: Array) -> Array:
	var _c32 = []
	var _n54 = {}
	
	for node in nodes:
		var path = node.get("full_path", node.get("name", ""))
		_n54[path] = node
	
	for node in nodes:
		var _z48 = node.get("name", "")
		var _f47 = node.get("type", "")
		var parent = node.get("parent", "")
		var full_path = node.get("full_path", "")
		
		var depth = 0
		if parent != "" and parent != ".":
			depth = parent.split("/").size()
		
		var indent = "  ".repeat(depth)
		var line = indent + "- " + _z48 + " (" + _f47 + ")"
		
		if node.has("script_path") and node.get("script_path", "") != "":
			line += " [script]"
		
		_c32.append(line)
	
	return _c32

func _s61(scene_path: String) -> bool:
	if not scene_path.begins_with("res://"):
		return false
	
	if not scene_path.to_lower().ends_with(".tscn"):
		return false
	
	if "../" in scene_path or scene_path.contains("..\\"):
		return false
	
	return true

func _d72() -> bool:
	if _w90:
		return true
	
	var _t19 = Time.get_ticks_msec()
	if (_t19 - _w92) > _z61:
		_w90 = true
		return true
	
	return false

func get_current_scene_nodes(_t15: EditorInterface) -> Dictionary:
	if not _t15:
		return {"success": false, "error": "Editor interface not available"}
	
	var _m25 = _t15.get_edited_scene_root()
	if not _m25:
		return {"success": false, "error": "No scene currently open in editor"}
	
	_w92 = Time.get_ticks_msec()
	_w90 = false
	
	var scene_info = {
		"success": true,
		"scene_path": "current_scene",
		"nodes": [],
		"root_node": _m25.name
	}
	
	_s90(_m25, scene_info["nodes"], "")
	
	return scene_info

func _s90(node: Node, nodes: Array, _a72: String) -> void:
	if _d72():
		return
	
	if nodes.size() > _j99:
		return
	
	var node_path = _a72
	if node_path != "":
		node_path += "/" + node.name
	else:
		node_path = node.name
	
	var _p92 = {
		"name": node.name,
		"type": node.get_class(),
		"full_path": node_path,
		"parent": _a72,
		"properties": {}
	}
	
	var script = node.get_script()
	if script:
		var _d36 = script.resource_path
		if _d36 != "":
			_p92["script_path"] = _d36
	
	nodes.append(_p92)
	
	for _w15 in node.get_children():
		_s90(_w15, nodes, node_path)

func _s23(_t15: EditorInterface, node_path: String) -> Dictionary:
	var scene_info = get_current_scene_nodes(_t15)
	
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

