@tool
class_name PathComponent
extends ComponentBase

var astar: AStar2D = AStar2D.new()

class PathTraversalEdgeData:
	var start_pos: Vector2
	var end_pos: Vector2
	var start_index: int
	var end_index: int
	var edge_meta: StringName = ""
	
@export var door_not_connected_image: Texture2D

@export var show_debug: bool = false:
	set(new_show):
		show_debug = new_show
		queue_redraw()

@export var connection_points: Array[Vector2i]:
	set(new_points):
		connection_points = new_points
		queue_redraw()

@export var path_points: Array[Vector2i] = []:
	set(new_points):
		path_points = new_points
		queue_redraw()
## Where X and Y are the indexes of the points in path_points and the string is metadata
@export var path_edges: Dictionary[Vector2i, StringName] = {}:
	set(new_edges):
		path_edges = new_edges
		queue_redraw()

## Which of the path points (by index) are actually doors, and what layer do they connect to?
@export var door_connections: Dictionary[int, WorldManager.StructureLayer] = {}

@export var door_data: Dictionary[int, StringName] = {}

## Do we error if no door is connected?
@export var door_required: bool = false

## Do we prevent movement if not powered?
@export var power_required: bool = false
@export var power_consumption_component: PowerConsumptionComponent
		
var module_connections: Dictionary[Node2D, int] = {}
var space_connections: Array[Node2D] = []

var door_sprites: Dictionary[int, Sprite2D] = {}

signal door_connected(cell: Vector2i, from_layer: WorldManager.StructureLayer)
signal door_disconnected(cell: Vector2i, from_layer: WorldManager.StructureLayer)

func _ready() -> void:
	super()
	for index in path_points.size():
		astar.add_point(index, path_points[index])
	for edge in path_edges:
		astar.connect_points(edge.x, edge.y)
	if power_required and power_consumption_component != null:
		power_consumption_component.powered_changed.connect(_on_power_changed)
	if door_required:
		for index in door_connections:
			var new_sprite: Sprite2D = Sprite2D.new()
			new_sprite.texture = door_not_connected_image
			new_sprite.position = Global.cell_to_world(Global.world_to_cell(path_points[index]), true)
			new_sprite.visible = true
			door_sprites[index] = new_sprite
			add_child(new_sprite)
		
func ready_preview() -> void:
	pass
	
func ready_blueprint() -> void:
	pass
	
func ready_constructed() -> void:
	pass
		
func _on_power_changed(new_power: bool) -> void:
	if new_power:
		Global.path_manager.enable_module(owner_module)
	else:
		Global.path_manager.disable_module(owner_module)
	
func get_closest_path_point(local_vec: Vector2) -> Vector2i:
	var index: int = astar.get_closest_point(local_vec)
	if index >= 0:
		return path_points[index]
	return Vector2i.ZERO
	
func get_connection_index_from(other_module: Node2D) -> int:
	# First check direct connection
	var index: int = module_connections.get(other_module, -1)
	if index < 0:
		# Check group connections
		var owner_vertex: ModuleGraphVertex = Global.path_manager.get_vertex(owner_module)
		var other_vertex: ModuleGraphVertex = Global.path_manager.get_vertex(other_module)
		if owner_vertex and other_vertex and owner_vertex.group and owner_vertex.group == other_vertex.group:
			index = owner_vertex.group_door
	return index
	
func get_connection_point_from(prev_module: Node2D) -> Vector2i:
	var connection_index: int = get_connection_index_from(prev_module)
	if connection_index >= 0 and connection_index < path_points.size():
		return path_points[connection_index]
	return Vector2i.ZERO
	
func get_path_through_module(start_module: Node2D, end_module: Node2D) -> Array[PathTraversalEdgeData]:
	var start_index: int = get_connection_index_from(start_module)
	var end_index: int = get_connection_index_from(end_module)
	return _get_path_within_module(start_index, end_index)
	
func get_path_exiting_module(start_global_position: Vector2, end_module: Node2D) -> Array[PathTraversalEdgeData]:
	var local_vec := start_global_position - owner_module.global_position
	var start_index: int = astar.get_closest_point(local_vec)
	var end_index: int = get_connection_index_from(end_module)
	return _get_path_within_module(start_index, end_index)

func _get_path_within_module(start_index: int, end_index: int) -> Array[PathTraversalEdgeData]:
	var path: Array[PathTraversalEdgeData] = []
	if start_index > -1 and end_index > -1 and start_index != end_index:
		var id_path: PackedInt64Array = astar.get_id_path(start_index, end_index)
		if id_path.size() > 0:
			# Add a starter point so we get here before we move through the module
			var edge_data: PathTraversalEdgeData = PathTraversalEdgeData.new()
			edge_data.start_index = -1
			edge_data.start_pos = Vector2.ZERO
			edge_data.end_index = start_index
			edge_data.end_pos = path_points[start_index]
			path.append(edge_data)
		for index in range(id_path.size() - 1):
			var edge_data: PathTraversalEdgeData = PathTraversalEdgeData.new()
			edge_data.start_index = id_path[index]
			edge_data.end_index = id_path[index + 1]
			edge_data.start_pos = path_points[id_path[index]]
			edge_data.end_pos = path_points[id_path[index + 1]]
			# Gotta check which way we put it in the path_edges dict
			if path_edges.has(Vector2i(id_path[index], id_path[index + 1])):
				edge_data.edge_meta = path_edges[Vector2i(id_path[index], id_path[index + 1])]
			elif path_edges.has(Vector2i(id_path[index + 1], id_path[index])):
				edge_data.edge_meta = path_edges[Vector2i(id_path[index + 1], id_path[index])]
			path.append(edge_data)
	return path

## Do we maybe have any connection?
func _has_possible_connections() -> bool:
	for point in connection_points:
		if Global.world_manager.has_overlaps(owner_module.module_data.interaction_layer, owner_module.module_cell + point):
			return true
	return false
		
## Find the index of a connection between this and another module. -1 if not found
func _find_connection(other_module: ModuleBase) -> int:
	for index: int in connection_points.size():
		var module: ModuleBase = Global.world_manager.get_module_by_cell(owner_module.module_data.interaction_layer, owner_module.module_cell + connection_points[index])
		if module != null and module == other_module:
			return index
	return -1

## Returns a mapping of connected modules -> their connection point
func _find_connections() -> Dictionary[ModuleBase, int]:
	var connected_modules: Dictionary[ModuleBase, int] = {}
	for index: int in connection_points.size():
		var module: ModuleBase = Global.world_manager.get_module_by_cell(owner_module.module_data.interaction_layer, owner_module.module_cell + connection_points[index])
		if module != null and module != owner_module:
			connected_modules[module] = index
	return connected_modules
	
## Connect to the other module if we can, return if successful
func try_connect(other_module: ModuleBase) -> bool:
	var connected_index: int = _find_connection(other_module)
	if connected_index != -1:
		module_connections[other_module] = connected_index
		return true
	return false

func make_connections() -> void:
	var connected_modules: Dictionary[ModuleBase, int] = _find_connections()
	for module in connected_modules:
		if module.get_path_component().try_connect(owner_module):
			module_connections[module] = connected_modules[module]
			Global.path_manager.add_connection(owner_module, module, owner_module.global_position.distance_to(module.global_position))
	connect_doors()
		
	
func manual_connection(other_module: Node2D, connection_index: int) -> void:
	module_connections[other_module] = connection_index
	Global.path_manager.add_connection(owner_module, other_module, 1)
	
func get_door_data_to(other_module: ModuleBase) -> StringName:
	var index: int = get_connection_index_from(other_module)
	if index >= 0:
		return door_data.get(index, "")
	return ""
	
func has_door_to(cell_to_check: Vector2i, target_layer: WorldManager.StructureLayer) -> bool:
	for index: int in door_connections:
		if door_connections[index] == target_layer:
			var door_cell: Vector2i = Global.world_to_cell(path_points[index])
			if door_cell + owner_module.module_cell == cell_to_check:
				return true
	return false
	
func try_connect_door(other_module: ModuleBase, cell_to_check: Vector2i) -> bool:
	for index: int in door_connections:
		if other_module.module_data.interaction_layer == door_connections[index]:
			var door_cell: Vector2i = Global.world_to_cell(path_points[index])
			if door_cell + owner_module.module_cell == cell_to_check:
				if door_required:
					door_sprites[index].visible = false
				module_connections[other_module] = index
				door_connected.emit(door_cell, other_module.module_data.interaction_layer)
				check_doors()
				return true
	check_doors()
	return false
			
func connect_doors() -> void:
	for index: int in door_connections:
		if door_connections[index] == WorldManager.StructureLayer.SPACE:
			# Special case for direct to space!
			var space_node := Node2D.new()
			owner_module.add_child(space_node)
			space_node.global_position = Vector2(path_points[index]) + owner_module.global_position
			Global.path_manager.add_vertex(space_node, false, "space")
			Global.path_manager.add_connection(owner_module, space_node, 30)
			module_connections[space_node] = index
			space_connections.append(space_node)
			continue
		var door_cell: Vector2i = Global.world_to_cell(path_points[index])
		var module: ModuleBase = Global.world_manager.get_module_by_cell(door_connections[index], owner_module.module_cell + door_cell)
		if module != null and module != owner_module and module.get_path_component() and module.get_path_component().try_connect_door(owner_module, owner_module.module_cell + door_cell):
			if door_required:
				door_sprites[index].visible = false
			module_connections[module] = index
			door_connected.emit(door_cell, module.module_data.interaction_layer)
			var data: StringName = door_data.get(index, "")
			if data.is_empty():
				data = module.get_path_component().get_door_data_to(owner_module)
			Global.path_manager.add_connection(owner_module, module, 1, data)
	check_doors()

func check_doors() -> void:
	if door_required:
		var has_door_connected: bool = false
		var connected_indices: Array[int] = module_connections.values()
		for index: int in door_connections:
			if connected_indices.has(index):
				has_door_connected = true
				break
		if !has_door_connected and door_required:
			last_error = "Door not connected!"
		else:
			last_error = ""
			
func remove_connections() -> void:
	for node in module_connections:
		if node is ModuleBase:
			var module := node as ModuleBase
			module.get_path_component().disconnect_from(owner_module)
			if door_connections.has(module_connections[module]):
				if door_required:
					door_sprites[module_connections[module]].visible = true
				door_disconnected.emit(Global.world_to_cell(path_points[module_connections[module]]), module.module_data.interaction_layer)
		SignalBus.module_path_connection_removed.emit(owner_module, node)
	module_connections.clear()
	for node in space_connections:
		Global.path_manager.remove_vertex(node)
	check_doors()
	
func disconnect_from(other_module: ModuleBase) -> void:
	if door_connections.has(module_connections[other_module]):
		if door_required:
			door_sprites[module_connections[other_module]].visible = true
		door_disconnected.emit(Global.world_to_cell(path_points[module_connections[other_module]]), other_module.module_data.interaction_layer)
	module_connections.erase(other_module)
	check_doors()


func _draw() -> void:
	if show_debug && Engine.is_editor_hint():
		for index in connection_points.size():
			var point: Vector2i = connection_points[index]
			var center: Vector2 = Vector2(point * Vector2i(64, 64)) +  Vector2(32, 32)
			draw_circle(center, 12, Color.GREEN)
			draw_string(ThemeDB.fallback_font, center + Vector2(-4, 5), str(index), HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.BLACK)
		for index in path_points.size():
			var point: Vector2i = path_points[index]
			draw_circle(point, 2, Color.GREEN)
			draw_string(ThemeDB.fallback_font, point + Vector2i(-1, 2), str(index), HORIZONTAL_ALIGNMENT_CENTER, -1, 4, Color.BLACK)
		for edge: Vector2i in path_edges:
			draw_line(path_points[edge.x], path_points[edge.y], Color.RED, 1)
