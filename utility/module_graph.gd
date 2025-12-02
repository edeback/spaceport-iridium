class_name ModuleGraph
extends Resource

signal graph_changed

var _vertices: Dictionary[ModuleBase, ModuleGraphVertex]

var last_subgraph: int = 0

func add_vertex(vertex: ModuleBase) -> void:
	if _vertices.has(vertex):
		print("trying to add existing vertex! skipping. Module: " + vertex.name)
		return
	var new_vertex: ModuleGraphVertex = ModuleGraphVertex.new()
	new_vertex.module = vertex
	new_vertex.location = vertex.module_cell
	last_subgraph += 1
	new_vertex.subgraph = last_subgraph
	_vertices[vertex] = new_vertex
	_emit_graph_changed()
	
func block_vertex(vertex: ModuleBase) -> void:
	if _vertices.has(vertex):
		_vertices[vertex].blocked = true
		_rebuild_subgraphs()
		
func unblock_vertex(vertex: ModuleBase) -> void:
	if _vertices.has(vertex):
		_vertices[vertex].blocked = false
		_rebuild_subgraphs()
		
func is_blocked(vertex: ModuleBase) -> bool:
	if _vertices.has(vertex):
		return _vertices[vertex].blocked
	return false
	
func remove_vertex(vertex: ModuleBase) -> void:
	var old_vertex: ModuleGraphVertex = _vertices.get(vertex) as ModuleGraphVertex
	if old_vertex == null:
		return
	for edge_vertex: ModuleGraphVertex in old_vertex.edges.keys():
		edge_vertex.edges.erase(old_vertex)
	_vertices.erase(vertex)
	old_vertex.free()
	_rebuild_subgraphs() # This may have split our graph
	_emit_graph_changed()
	
func add_edge(start: ModuleBase, end: ModuleBase, cost: float, data: Variant = null) -> bool:
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

func remove_edge(start: ModuleBase, end: ModuleBase) -> bool:
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

func get_edge(start: ModuleBase, end: ModuleBase) -> ModuleGraphVertex.EdgeData:
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
	var frontier: Array[ModuleGraphVertex] = start.edges.keys()
	while !frontier.is_empty():
		var next: ModuleGraphVertex = frontier.pop_front() as ModuleGraphVertex
		if next.blocked:
			continue
		if next.subgraph == subgraph:
			continue
		next.subgraph = subgraph
		frontier.append_array(next.edges.keys())

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
	
func get_closest_module_to(vector: Vector2) -> ModuleBase:
	var dist: float = -1
	var module: ModuleBase = null
	for vertex: ModuleGraphVertex in _vertices.values():
		var new_dist: float = vertex.location.distance_squared_to(vector)
		if new_dist < dist or dist < 0:
			dist = new_dist
			module = vertex.module
	return module

func pathfind(start: ModuleBase, end: ModuleBase) -> Array[ModuleBase]:
	var start_vertex: ModuleGraphVertex = _vertices.get(start)
	var end_vertex: ModuleGraphVertex = _vertices.get(end)
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
		
		for next: ModuleGraphVertex in current.edges.keys():
			if next.blocked:
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
	var path: Array[ModuleBase] = []
	while cur_vertex != start_vertex:
		path.append(cur_vertex.module)
		cur_vertex = came_from[cur_vertex]
	path.append(start)
	path.reverse()
	return path

func _heuristic(start: ModuleGraphVertex, end: ModuleGraphVertex) -> float:
	# return start.dist_squared_to(end)
	return 0 # Otherwise we never check teleporters...
	#return start.dist_to(end)
	
func pathfind_to_type(start: ModuleBase, end_type: ModuleData) -> Array[ModuleBase]:
	var start_vertex: ModuleGraphVertex = _vertices.get(start)
	if start_vertex == null:
		return []
	var frontier: ModuleQueue = ModuleQueue.new()
	frontier.insert(start_vertex, 0)
	var came_from: Dictionary[ModuleGraphVertex, ModuleGraphVertex]
	var cost_so_far: Dictionary[ModuleGraphVertex, float]
	cost_so_far[start_vertex] = 0
	
	var end_vertex: ModuleGraphVertex = null
	while not frontier.is_empty():
		var current: ModuleGraphVertex = frontier.extract()
		if current.module.module_data == end_type:
			end_vertex = current
			break
		
		for next: ModuleGraphVertex in current.edges.keys():
			if next.blocked:
				continue
			var new_cost: float = cost_so_far[current] + current.edges[next].cost
			if not cost_so_far.has(next) or new_cost < cost_so_far[next]:
				cost_so_far[next] = new_cost
				frontier.insert(next, new_cost)
				came_from[next] = current
				
	# Did we ever find it?
	if not end_vertex:
		return []
	
	# Reconstruct path
	var cur_vertex: ModuleGraphVertex = end_vertex
	var path: Array[ModuleBase] = []
	while cur_vertex != start_vertex:
		path.append(cur_vertex.module)
		cur_vertex = came_from[cur_vertex]
	path.append(start)
	path.reverse()
	return path

func pathfind_to_func(start: ModuleBase, end_func: Callable) -> Array[ModuleBase]:
	var start_vertex: ModuleGraphVertex = _vertices.get(start)
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
		
		for next: ModuleGraphVertex in current.edges.keys():
			if next.blocked:
				continue
			var new_cost: float = cost_so_far[current] + current.edges[next].cost
			if not cost_so_far.has(next) or new_cost < cost_so_far[next]:
				cost_so_far[next] = new_cost
				frontier.insert(next, new_cost)
				came_from[next] = current
				
	# Did we ever find it?
	if not end_vertex:
		return []
	
	# Reconstruct path
	var cur_vertex: ModuleGraphVertex = end_vertex
	var path: Array[ModuleBase] = []
	while cur_vertex != start_vertex:
		path.append(cur_vertex.module)
		cur_vertex = came_from[cur_vertex]
	path.append(start)
	path.reverse()
	return path
