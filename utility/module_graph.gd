class_name ModuleGraph
extends Resource

class PathPoint:
	var node: Node2D = null
	var in_space: bool = false
	var edge_meta: String = ""

signal graph_changed

## StringName, Array[ModuleGraphVertex]
var _linked_groups: Dictionary[StringName, Array]

var _vertices: Dictionary[Node2D, ModuleGraphVertex]

var last_subgraph: int = 0

func add_vertex(vertex: Node2D, is_endpoint: bool = false, group: StringName = "") -> void:
	if _vertices.has(vertex):
		print("trying to add existing vertex! skipping. Module: " + vertex.name)
		return
	_vertices[vertex] = make_vertex(vertex, is_endpoint, group)
	_emit_graph_changed()
	
func make_vertex(vertex: Node2D, is_endpoint: bool = false, group: StringName = "", group_door: int = 0) -> ModuleGraphVertex:
	var new_vertex: ModuleGraphVertex = ModuleGraphVertex.new()
	new_vertex.node = vertex
	new_vertex.endpoint = is_endpoint
	new_vertex.group = group
	new_vertex.group_door = group_door
	last_subgraph += 1
	new_vertex.subgraph = last_subgraph
	if group:
		var group_array : Array = _linked_groups.get_or_add(group, [])
		if not group_array.is_empty():
			# Default dump this in the same subgraph as they're all connected
			new_vertex.subgraph = group_array[0].subgraph
		group_array.append(new_vertex)
	return new_vertex
	
func change_vertex_group(vertex: Node2D, new_group: StringName, new_group_door: int = -1, rebuild: bool = true) -> void:
	var graph_vertex: ModuleGraphVertex = _vertices.get(vertex)
	if graph_vertex != null and graph_vertex.group != new_group:
		if graph_vertex.group:
			_linked_groups[graph_vertex.group].erase(graph_vertex)
		if new_group:
			_linked_groups.get_or_add(new_group, []).append(graph_vertex)
		graph_vertex.group = new_group
		if new_group_door >= 0:
			graph_vertex.group_door = new_group_door
		if rebuild:
			_rebuild_subgraphs()
	
func get_group_subgraph(group: StringName) -> int:
	if group:
		var group_array : Array = _linked_groups.get_or_add(group, [])
		if not group_array.is_empty():
			# Default dump this in the same subgraph as they're all connected
			return group_array[0].subgraph
	return -1
	
## Not for use with adding/removing nodes, this redirects pawn to pawn.current_module if they're in a module
func get_vertex_for_path(node: Node2D) -> ModuleGraphVertex:
	if node and node is PawnBase and (node as PawnBase).current_module != null:
		return _vertices.get((node as PawnBase).current_module)
	return _vertices.get(node)
	
func block_vertex(vertex: Node2D) -> void:
	if _vertices.has(vertex):
		_vertices[vertex].blocked = true
		_rebuild_subgraphs()
		
func unblock_vertex(vertex: Node2D) -> void:
	if _vertices.has(vertex):
		_vertices[vertex].blocked = false
		_rebuild_subgraphs()
		
func is_blocked(vertex: Node2D) -> bool:
	if _vertices.has(vertex):
		return _vertices[vertex].blocked
	return false
	
func remove_vertex(vertex: Node2D) -> void:
	var old_vertex: ModuleGraphVertex = _vertices.get(vertex) as ModuleGraphVertex
	if old_vertex == null:
		return
	for edge_vertex: ModuleGraphVertex in old_vertex.edges.keys():
		edge_vertex.edges.erase(old_vertex)
	if old_vertex.group:
		_linked_groups[old_vertex.group].erase(old_vertex)
	_vertices.erase(vertex)
	old_vertex.free()
	_rebuild_subgraphs() # This may have split our graph
	_emit_graph_changed()
	
func add_edge(start: Node2D, end: Node2D, cost: float, data: StringName = "") -> bool:
	var start_vertex: ModuleGraphVertex = _vertices.get(start)
	var end_vertex: ModuleGraphVertex = _vertices.get(end)
	if (start_vertex == null or end_vertex == null):
		print("tried to add an edge but missing vertex.")
		return false
	start_vertex.add_edge(end_vertex, cost, data)
	end_vertex.add_edge(start_vertex, cost, data)
	# If we connected subgraphs, subsume larger number into smaller
	if start_vertex.subgraph < end_vertex.subgraph:
		_assign_subgraph_from(end_vertex, start_vertex.subgraph)
	if end_vertex.subgraph < start_vertex.subgraph:
		_assign_subgraph_from(start_vertex, end_vertex.subgraph)
	_emit_graph_changed()
	return true

func remove_edge(start: Node2D, end: Node2D) -> bool:
	var start_vertex: ModuleGraphVertex = _vertices.get(start) as ModuleGraphVertex
	var end_vertex: ModuleGraphVertex = _vertices.get(end)
	if (start_vertex == null or end_vertex == null):
		print("tried to remove an edge but missing vertex.")
		return false
	start_vertex.edges.erase(end_vertex)
	end_vertex.edges.erase(start_vertex)
	_rebuild_subgraphs() # This may have split our graph
	_emit_graph_changed()
	return true

func get_edge(start: Node2D, end: Node2D) -> ModuleGraphVertex.EdgeData:
	var start_vertex: ModuleGraphVertex = _vertices.get(start)
	var end_vertex: ModuleGraphVertex = _vertices.get(end)
	if start_vertex != null and end_vertex != null:
		return start_vertex.edges.get(end_vertex)
	return null

func _emit_graph_changed() -> void:
	graph_changed.emit()

func _assign_subgraph_from(start: ModuleGraphVertex, subgraph: int) -> void:
	if start.subgraph == subgraph:
		return
	start.subgraph = subgraph
	var added_groups: Array[StringName] = []
	var frontier: Array[ModuleGraphVertex] = start.edges.keys()
	if start.group and not added_groups.has(start.group):
		added_groups.append(start.group)
		for vertex: ModuleGraphVertex in _linked_groups[start.group]:
			if vertex != start:
				frontier.append(vertex)
	while !frontier.is_empty():
		var next: ModuleGraphVertex = frontier.pop_front() as ModuleGraphVertex
		if next.blocked:
			continue
		if next.subgraph == subgraph:
			continue
		next.subgraph = subgraph
		frontier.append_array(next.edges.keys())
		if next.group and not added_groups.has(next.group):
			added_groups.append(next.group)
			for vertex: ModuleGraphVertex in _linked_groups[next.group]:
				if vertex != next:
					frontier.append(vertex)

func _rebuild_subgraphs() -> void:
	var cur_subgraph: int = 0
	for vertex: ModuleGraphVertex in _vertices.values():
		vertex.subgraph = cur_subgraph
	for vertex: ModuleGraphVertex in _vertices.values():
		if vertex.blocked:
			continue
		if vertex.subgraph == 0:
			cur_subgraph += 1
			_assign_subgraph_from(vertex, cur_subgraph)
	last_subgraph = cur_subgraph

func _rebuild_partial_subgraphs(changed_nodes: Array[ModuleGraphVertex]) -> void:
	for node: ModuleGraphVertex in changed_nodes:
		node.subgraph = -1
	for node: ModuleGraphVertex in changed_nodes:
		if node.subgraph == -1:
			last_subgraph += 1
			_assign_subgraph_from(node, last_subgraph)

func get_closest_module_to_position(vector: Vector2, vertices: Array[ModuleGraphVertex] = _vertices.values()) -> ModuleBase:
	var dist: float = -1
	var module: ModuleBase = null
	for vertex: ModuleGraphVertex in vertices:
		if vertex.node is ModuleBase:
			var new_dist: float = vertex.node.global_position.distance_squared_to(vector)
			if new_dist < dist or dist < 0:
				dist = new_dist
				module = vertex.node as ModuleBase
	return module
	
func get_closest_module_by_group(vector: Vector2, group: StringName) -> ModuleBase:
	var group_vertices: Array[ModuleGraphVertex] = _linked_groups.get(group, [])
	if group_vertices.is_empty():
		return null
	return get_closest_module_to_position(vector, group_vertices)

func is_reachable(start: Node2D, end: Node2D) -> bool:
	var start_vertex: ModuleGraphVertex = get_vertex_for_path(start)
	var end_vertex: ModuleGraphVertex = get_vertex_for_path(end)
	return start_vertex and end_vertex and start_vertex.subgraph == end_vertex.subgraph
	
func is_space_reachable(start: Node2D) -> bool:
	var start_vertex: ModuleGraphVertex = get_vertex_for_path(start)
	return start_vertex and start_vertex.subgraph == get_group_subgraph(&"space")

func pathfind(start: Node2D, end: Node2D) -> Array[PathPoint]:
	var start_vertex: ModuleGraphVertex = get_vertex_for_path(start)
	var end_vertex: ModuleGraphVertex = get_vertex_for_path(end)
	return pathfind_by_vertex(start_vertex, end_vertex)

func pathfind_by_vertex(start_vertex: ModuleGraphVertex, end_vertex: ModuleGraphVertex) -> Array[PathPoint]:
	if start_vertex == null or end_vertex == null or start_vertex.blocked or end_vertex.blocked:
		return []
	if start_vertex.subgraph != end_vertex.subgraph:
		return []
	var frontier: ModuleQueue = ModuleQueue.new()
	frontier.insert(start_vertex, 0)
	var came_from: Dictionary[ModuleGraphVertex, ModuleGraphVertex]
	var cost_so_far: Dictionary[ModuleGraphVertex, float]
	cost_so_far[start_vertex] = 0
	while not frontier.is_empty():
		var current: ModuleGraphVertex = frontier.extract()
		if current == end_vertex:
			break
			
		if current.group:
			for linked: ModuleGraphVertex in _linked_groups[current.group]:
				if linked == end_vertex or (linked != current and not linked.endpoint):
					var new_cost: float = cost_so_far[current] + linked.dist_to(current)
					if not cost_so_far.has(linked) or new_cost < cost_so_far[linked]:
						cost_so_far[linked] = new_cost
						var prio: float = new_cost + _heuristic(linked, end_vertex)
						frontier.insert(linked, prio)
						came_from[linked] = current
						
		for next: ModuleGraphVertex in current.edges.keys():
			if next.blocked or (next.endpoint and next != end_vertex):
				continue
			var new_cost: float = cost_so_far[current] + current.edges[next].cost
			if not cost_so_far.has(next) or new_cost < cost_so_far[next]:
				cost_so_far[next] = new_cost
				var prio: float = new_cost + _heuristic(next, end_vertex)
				frontier.insert(next, prio)
				came_from[next] = current

				
	# Did we ever find it?
	if not came_from.has(end_vertex):
		return []
	
	# Reconstruct path
	var cur_vertex: ModuleGraphVertex = end_vertex
	var path: Array[PathPoint] = []
	var prev_vertex: ModuleGraphVertex = null
	while cur_vertex != start_vertex:
		var next_point := PathPoint.new()
		next_point.node = cur_vertex.node
		next_point.in_space = (cur_vertex.group == &"space")
		if prev_vertex != null:
			var edge_data: ModuleGraphVertex.EdgeData = prev_vertex.edges.get(cur_vertex)
			if edge_data != null:
				next_point.edge_meta = edge_data.data
			else:
				next_point.edge_meta = cur_vertex.group
		path.append(next_point)
		prev_vertex = cur_vertex
		cur_vertex = came_from[cur_vertex]
	var start_point := PathPoint.new()
	start_point.node = start_vertex.node
	start_point.in_space = (start_vertex.group == &"space")
	if prev_vertex != null:
		var edge_data: ModuleGraphVertex.EdgeData = prev_vertex.edges.get(cur_vertex)
		if edge_data != null:
			start_point.edge_meta = edge_data.data
		else:
			start_point.edge_meta = start_vertex.group
	path.append(start_point)
	path.reverse()
	return path

func _heuristic(_start: ModuleGraphVertex, _end: ModuleGraphVertex) -> float:
	# return start.dist_squared_to(end)
	return 0 # Otherwise we never check teleporters...
	#return start.dist_to(end)
	
func pathfind_to_node_in_space(start: Node2D, end: Node2D) -> Array[PathPoint]:
	var temp_vertex: ModuleGraphVertex = make_vertex(end, true, "space")
	_linked_groups.get_or_add("space", []).append(temp_vertex)
	var path := pathfind_by_vertex(get_vertex_for_path(start), temp_vertex)
	_linked_groups["space"].erase(temp_vertex)
	return path
	
func pathfind_to_type(start: Node2D, end_type: ModuleData) -> Array[PathPoint]:
	if end_type == null:
		return []
	var start_vertex: ModuleGraphVertex = get_vertex_for_path(start)
	if start_vertex == null:
		return []
	var type_callable: Callable = func(test_vertex: ModuleGraphVertex) -> bool: return test_vertex.node is ModuleBase and test_vertex.node.module_data == end_type
	return pathfind_to_func(start, type_callable)
	
func pathfind_to_component_type(start: Node2D, end_component_type: Variant) -> Array[PathPoint]:
	if end_component_type == null:
		return []
	var start_vertex: ModuleGraphVertex = get_vertex_for_path(start)
	if start_vertex == null:
		return []
	var component_type_callable: Callable = func(test_vertex: ModuleGraphVertex) -> bool: return test_vertex.node is ModuleBase and test_vertex.node.get_component_by_type(end_component_type) != null
	return pathfind_to_func(start, component_type_callable)	

func pathfind_to_func(start: Node2D, end_func: Callable) -> Array[PathPoint]:
	var start_vertex: ModuleGraphVertex = get_vertex_for_path(start)
	if start_vertex == null or !end_func.is_valid():
		return []
	var frontier: ModuleQueue = ModuleQueue.new()
	frontier.insert(start_vertex, 0)
	var came_from: Dictionary[ModuleGraphVertex, ModuleGraphVertex]
	var cost_so_far: Dictionary[ModuleGraphVertex, float]
	cost_so_far[start_vertex] = 0
	
	var end_vertex: ModuleGraphVertex = null
	while not frontier.is_empty():
		var current: ModuleGraphVertex = frontier.extract()
		if end_func.call(current):
			end_vertex = current
			break
		
		if current.group:
			for linked: ModuleGraphVertex in _linked_groups[current.group]:
				if linked == end_vertex or (linked != current and not linked.endpoint):
					var new_cost: float = cost_so_far[current] + linked.dist_to(current)
					if not cost_so_far.has(linked) or new_cost < cost_so_far[linked]:
						cost_so_far[linked] = new_cost
						var prio: float = new_cost + _heuristic(linked, end_vertex)
						frontier.insert(linked, prio)
						came_from[linked] = current
						
		for next: ModuleGraphVertex in current.edges.keys():
			if next.blocked or (next.endpoint and next != end_vertex):
				continue
			var new_cost: float = cost_so_far[current] + current.edges[next].cost
			if not cost_so_far.has(next) or new_cost < cost_so_far[next]:
				cost_so_far[next] = new_cost
				var prio: float = new_cost + _heuristic(next, end_vertex)
				frontier.insert(next, prio)
				came_from[next] = current
				
	# Did we ever find it?
	if not end_vertex:
		return []
	
	# Reconstruct path
	var cur_vertex: ModuleGraphVertex = end_vertex
	var path: Array[PathPoint] = []
	while cur_vertex != start_vertex:
		var next_point := PathPoint.new()
		next_point.node = cur_vertex.node
		next_point.in_space = (cur_vertex.group == &"space")
		path.append(next_point)
		cur_vertex = came_from[cur_vertex]
	var start_point := PathPoint.new()
	start_point.node = start_vertex.node
	start_point.in_space = (start_vertex.group == &"space")
	path.append(start_point)
	path.reverse()
	return path
