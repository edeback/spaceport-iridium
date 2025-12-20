## Small helpers for node and scene tree searches used across tests and systems.
##
## Contains safe recursive lookup helpers for finding nodes and collision objects within a tree.
class_name GBSearchUtils

## Finds the first node under the original parent that is of the passed class type.[br][br]
## [code]parent[/code]: [i]Node[/i] - The parent node to search within[br]
## [code]type[/code]: [i]Script/Class[/i] - The class type to search for
static func find_first(parent : Node, type):
	if not is_instance_valid(parent):
		return null
	
	for child in parent.get_children():
		if is_instance_of(child, type):
			return child
			
		var grandchild = find_first(child, type)
		
		if is_instance_valid(grandchild):
			return grandchild
			
	return null

## Gets all collision object 2ds from the root (inclusive) and all child objects.
## Performs recursive search to find all CollisionObject2D instances in the node tree.[br][br]
## [code]root[/code]: [i]Node[/i] - The root node to start searching from (inclusive)
static func get_collision_object_2ds(root : Node) -> Array[CollisionObject2D]:
	var col_objects : Array[CollisionObject2D] = []
	
	if root is CollisionObject2D:
		col_objects.append(root)
		
	for col_obj in root.find_children("", "CollisionObject2D", true, false):
		col_objects.append(col_obj)
	
	return col_objects
	
## Gets all collision shapes and collision polygons from the root (inclusive) and all child objects.[br][br]
## Performs recursive search to find all CollisionShape2D and CollisionPolygon2D instances in the node tree.[br][br]
## Returns [code]Array[Node2D][/code] because both CollisionShape2D and CollisionPolygon2D inherit from Node2D.[br][br]
## [code]root[/code]: [i]Node[/i] - The root node to start searching from (inclusive)
static func get_collision_shapes_and_polygons_2d(root : Node) -> Array[Node2D]:
	var collision_nodes : Array[Node2D] = []
	
	# Include the root if it's a collision shape or polygon
	if root is CollisionShape2D or root is CollisionPolygon2D:
		collision_nodes.append(root)
	
	# Find all CollisionShape2D instances
	for col_shape in root.find_children("", "CollisionShape2D", true, false):
		collision_nodes.append(col_shape)
	
	# Find all CollisionPolygon2D instances
	for poly in root.find_children("", "CollisionPolygon2D", true, false):
		collision_nodes.append(poly)
	
	return collision_nodes

## Finds the first visual node (Sprite2D or AnimatedSprite2D) among the direct children of the given parent.
## Returns null if none found.
static func find_visual_node_direct(parent: Node) -> Node:
	if not is_instance_valid(parent):
		return null
	for child in parent.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return child
	return null

## Finds a visual node (Sprite2D or AnimatedSprite2D) optionally searching recursively.
## By default, searches recursively to act as a universal helper.
static func find_visual_node(root: Node, recursive: bool = true) -> Node:
	var visual := find_visual_node_direct(root)
	if visual != null or not recursive:
		return visual
	for child in root.get_children():
		var found := find_visual_node(child, true)
		if found != null:
			return found
	return null

## Returns true if a visual node exists under root and is currently visible.
static func is_visual_visible(root: Node, recursive: bool = true) -> bool:
	var v := find_visual_node(root, recursive)
	return v != null and v.visible if v != null else false
