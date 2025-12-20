## Settings for locating inventory nodes during rule validation.
class_name NodeLocator
extends Resource

## Search method options.
enum SEARCH_METHOD { NODE_NAME, SCRIPT_NAME_WITH_EXTENSION, IS_IN_GROUP }

## Method for finding the inventory node.
@export var method: SEARCH_METHOD = SEARCH_METHOD.NODE_NAME

## Search string to use with the search method.
@export var search_string: String = "<Set me>"

func _init(
	p_search_method: SEARCH_METHOD = SEARCH_METHOD.NODE_NAME,
	p_search_string: String = search_string
):
	method = p_search_method
	search_string = p_search_string


## Locates a container node based on the configured search method.
## Searches the node tree using the specified method and search string.
## Uses pure logic class for composition over inheritance.
## [code]search_root[/code]: [i]Node[/i] - Root node to start the search from[br]
func locate_container(search_root: Node) -> Node:
	if search_root == null:
		return null

	var inventory_container: Node
	var all_nodes : Array[Node] = [search_root]
	
	# Collect all child nodes for search
	for child in search_root.find_children("", "Node", true, false):
		all_nodes.append(child)

	match method:
		SEARCH_METHOD.NODE_NAME:
			# Use pure logic class for node search
			var found_nodes = NodeSearchLogic.find_nodes_by_name(all_nodes, search_string)
			if not found_nodes.is_empty():
				inventory_container = found_nodes[0]
		SEARCH_METHOD.SCRIPT_NAME_WITH_EXTENSION:
			# Use pure logic class for script search
			var found_nodes = NodeSearchLogic.find_nodes_by_script(all_nodes, search_string)
			if not found_nodes.is_empty():
				inventory_container = found_nodes[0]
		SEARCH_METHOD.IS_IN_GROUP:
			# Use pure logic class for group search
			var found_nodes = NodeSearchLogic.find_nodes_by_group(all_nodes, search_string)
			if not found_nodes.is_empty():
				inventory_container = found_nodes[0]

	return inventory_container

## Extracts the script file name from an object's attached script.
## Uses pure logic class for composition over inheritance.
## Returns the script filename with extension, or empty string if no script.[br][br]
## [code]p_check[/code]: [i]Object[/i] - Object to get script name from
func get_script_name(p_check: Object) -> String:
	# Use pure logic class for script name extraction
	return NodeSearchLogic.get_script_name(p_check)
