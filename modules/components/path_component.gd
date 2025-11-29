@tool
class_name PathComponent
extends ComponentBase

var astar: AStar2D = AStar2D.new()

class PathTraversalEdgeData:
	var start_pos: Vector2
	var end_pos: Vector2
	var edge_meta: String

@export var show_debug: bool = false

@export var connection_points: Array[Vector2i]:
	set(new_points):
		connection_points = new_points
		queue_redraw()

@export var path_points: Array[Vector2i] = []:
	set(new_points):
		path_points = new_points
		queue_redraw()
## Where X and Y are the indexes of the points in path_points and the string is metadata
@export var path_edges: Dictionary[Vector2i, String] = {}:
	set(new_edges):
		path_edges = new_edges
		queue_redraw()

## Which of the path points (by index) are actually doors?
@export var door_indices: Array[int] = []
		
var module_connections: Dictionary[ModuleBase, int] = {}

signal door_connected(cell: Vector2i)
signal door_disconnected(cell: Vector2i)

func _ready() -> void:
	super()
	for index in path_points.size():
		astar.add_point(index, path_points[index])
	for edge in path_edges:
		astar.connect_points(edge.x, edge.y)
	owner_module.path_component = self
	
func get_path_through_module(start_module: ModuleBase, end_module: ModuleBase) -> Array[PathTraversalEdgeData]:
	var path: Array[PathTraversalEdgeData] = []
	var start_index: int = -1
	if module_connections.has(start_module):
		start_index = module_connections[start_module]
	var end_index: int = -1
	if module_connections.has(end_module):
		end_index = module_connections[end_module]
	if start_index != -1 and end_index != -1 and start_index != end_index:
		var id_path: PackedInt64Array = astar.get_id_path(start_index, end_index)
		for index in range(id_path.size() - 1):
			var edge_data: PathTraversalEdgeData = PathTraversalEdgeData.new()
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
		for module in Global.world_manager.get_overlaps(owner_module.module_data.interaction_layer, owner_module.module_cell + connection_points[index]):
			if module == other_module:
				return index
	return -1

## Returns a mapping of connected modules -> their connection point
func _find_connections() -> Dictionary[ModuleBase, int]:
	var connected_modules: Dictionary[ModuleBase, int] = {}
	for index: int in connection_points.size():
		for module in Global.world_manager.get_overlaps(owner_module.module_data.interaction_layer, owner_module.module_cell + connection_points[index]):
			if module != self:
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
		if module.path_component.try_connect(owner_module):
			module_connections[module] = connected_modules[module]
			SignalBus.module_connection_added.emit(owner_module, module, owner_module.module_cell.distance_to(module.module_cell))
	connect_doors()
			
func has_door(cell_to_check: Vector2i) -> bool:
	for index: int in door_indices:
		var door_cell: Vector2i = Global.world_to_cell(path_points[index])
		if door_cell + owner_module.module_cell == cell_to_check:
			return true
	return false
	
func try_connect_door(other_module: ModuleBase, cell_to_check: Vector2i) -> bool:
	for index: int in door_indices:
		var door_cell: Vector2i = Global.world_to_cell(path_points[index])
		if door_cell + owner_module.module_cell == cell_to_check:
			module_connections[other_module] = index
			return true
	return false
			
func connect_doors() -> void:
	var layer_to_check: WorldManager.InteractionLayer = (1 - owner_module.module_data.interaction_layer) as WorldManager.InteractionLayer
	for index: int in door_indices:
		var door_cell: Vector2i = Global.world_to_cell(path_points[index])
		for module: ModuleBase in Global.world_manager.get_overlaps(layer_to_check, owner_module.module_cell + door_cell):
			if module != owner_module and module.path_component.try_connect_door(owner_module, owner_module.module_cell + door_cell):
				module_connections[module] = index
				door_connected.emit(door_cell)
				SignalBus.module_connection_added.emit(owner_module, module, 1)

func remove_connections() -> void:
	for module in module_connections:
		module.path_component.disconnect_from(owner_module)
		if door_indices.has(module_connections[module]):
			door_disconnected.emit(Global.world_to_cell(path_points[module_connections[module]]))
		SignalBus.module_connection_removed.emit(owner_module.module_id, module.module_id)
	module_connections.clear()
	
func disconnect_from(other_module: ModuleBase) -> void:
	module_connections.erase(other_module)


func _draw() -> void:
	if show_debug && Engine.is_editor_hint():
		for index in connection_points.size():
			var point: Vector2i = connection_points[index]
			var center: Vector2 = Vector2(point * Vector2i(64, 64)) +  Vector2(32, 32)
			draw_circle(center, 12, Color.GREEN)
			draw_string(ThemeDB.fallback_font, center + Vector2(-4, 5), str(index), HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.BLACK)
		for index in path_points.size():
			var point: Vector2i = path_points[index]
			draw_circle(point, 4, Color.GREEN)
			draw_string(ThemeDB.fallback_font, point + Vector2i(-2, 3), str(index), HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color.BLACK)
		for edge: Vector2i in path_edges:
			draw_line(path_points[edge.x], path_points[edge.y], Color.RED, 2)
