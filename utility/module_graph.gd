class_name ModuleGraph
extends Resource

signal graph_changed

## StringName, Array[ModuleGraphVertex]
var _linked_groups: Dictionary[StringName, Array]

var _vertices: Dictionary[Node2D, ModuleGraphVertex]

var last_subgraph: int = 0

func add_vertex(vertex: Node2D, is_endpoint: bool = false, group: StringName = "") -> void:
	if _vertices.has(vertex):
		print("trying to add existing vertex! skipping. Module: " + vertex.name)
		return
	var new_vertex: ModuleGraphVertex = ModuleGraphVertex.new()
	new_vertex.node = vertex
	new_vertex.endpoint = is_endpoint
	new_vertex.group = group
	last_subgraph += 1
	new_vertex.subgraph = last_subgraph
	_vertices[vertex] = new_vertex
	if group:
		_linked_groups.get_or_add(group, []).append(new_vertex)
	_emit_graph_changed()
	
func change_vertex_group(vertex: Node2D, new_group: StringName) -> void:
	var graph_vertex: ModuleGraphVertex = _vertices.get(vertex)
	if graph_vertex != null and graph_vertex.group != new_group:
		if graph_vertex.group:
			_linked_groups[graph_vertex.group].erase(graph_vertex)
		if new_group:
			_linked_groups.get_or_add(new_group, []).append(graph_vertex)
		graph_vertex.group = new_group
	
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
	
func add_edge(start: Node2D, end: Node2D, cost: float, data: Variant = null) -> bool:
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
	
func get_closest_module_to_position(vector: Vector2) -> ModuleBase:
	var dist: float = -1
	var module: ModuleBase = null
	for vertex: ModuleGraphVertex in _vertices.values():
		if vertex.node is ModuleBase:
			var new_dist: float = vertex.node.global_position.distance_squared_to(vector)
			if new_dist < dist or dist < 0:
				dist = new_dist
				module = vertex.node as ModuleBase
	return module

func pathfind(start: Node2D, end: Node2D) -> Array[Node2D]:
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
	var added_groups: Array[StringName] = []
	while not frontier.is_empty():
		var current: ModuleGraphVertex = frontier.extract()
		if current == end_vertex:
			break
			
		if current.group and !added_groups.has(current.group):
			# Group means direct connection, so just go there directly now
			if end_vertex.group == current.group:
				came_from[end_vertex] = current
				break
			# Add all group members, but only once ever!
			added_groups.append(current.group)
			for linked: ModuleGraphVertex in _linked_groups[current.group]:
				if linked != current and not linked.endpoint:
					var new_cost: float = cost_so_far[current] + linked.dist_to(current)
					if not cost_so_far.has(linked) or new_cost < cost_so_far[linked]:
						cost_so_far[linked] = new_cost
						var prio: float = new_cost + _heuristic(linked, end_vertex)
						frontier.insert(linked, prio)
						came_from[linked] = current
						
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
	var path: Array[Node2D] = []
	while cur_vertex != start_vertex:
		path.append(cur_vertex.node)
		cur_vertex = came_from[cur_vertex]
	path.append(start)
	path.reverse()
	return path

func _heuristic(_start: ModuleGraphVertex, _end: ModuleGraphVertex) -> float:
	# return start.dist_squared_to(end)
	return 0 # Otherwise we never check teleporters...
	#return start.dist_to(end)
	
func pathfind_to_type(start: Node2D, end_type: ModuleData) -> Array[Node2D]:
	if end_type == null:
		return []
	var start_vertex: ModuleGraphVertex = _vertices.get(start)
	if start_vertex == null:
		return []
	var type_callable: Callable = func(test_vertex: ModuleGraphVertex) -> bool: return test_vertex.node is ModuleBase and test_vertex.node.module_data == end_type
	return pathfind_to_func(start, type_callable)
	
func pathfind_to_component_type(start: Node2D, end_component_type: Variant) -> Array[Node2D]:
	if end_component_type == null:
		return []
	var start_vertex: ModuleGraphVertex = _vertices.get(start)
	if start_vertex == null:
		return []
	var component_type_callable: Callable = func(test_vertex: ModuleGraphVertex) -> bool: return test_vertex.node is ModuleBase and test_vertex.node.get_component_by_type(end_component_type) != null
	return pathfind_to_func(start, component_type_callable)	
	
	#var frontier: ModuleQueue = ModuleQueue.new()
	#frontier.insert(start_vertex, 0)
	#var came_from: Dictionary[ModuleGraphVertex, ModuleGraphVertex]
	#var cost_so_far: Dictionary[ModuleGraphVertex, float]
	#cost_so_far[start_vertex] = 0
	#
	#var end_vertex: ModuleGraphVertex = null
	#while not frontier.is_empty():
		#var current: ModuleGraphVertex = frontier.extract()
		#if current.module.module_data == end_type:
			#end_vertex = current
			#break
		#
		#for next: ModuleGraphVertex in current.edges.keys():
			#if next.blocked:
				#continue
			#var new_cost: float = cost_so_far[current] + current.edges[next].cost
			#if not cost_so_far.has(next) or new_cost < cost_so_far[next]:
				#cost_so_far[next] = new_cost
				#frontier.insert(next, new_cost)
				#came_from[next] = current
				#
	## Did we ever find it?
	#if not end_vertex:
		#return []
	#
	## Reconstruct path
	#var cur_vertex: ModuleGraphVertex = end_vertex
	#var path: Array[ModuleBase] = []
	#while cur_vertex != start_vertex:
		#path.append(cur_vertex.module)
		#cur_vertex = came_from[cur_vertex]
	#path.append(start)
	#path.reverse()
	#return path

func pathfind_to_func(start: Node2D, end_func: Callable) -> Array[Node2D]:
	var start_vertex: ModuleGraphVertex = _vertices.get(start)
	if start_vertex == null or !end_func.is_valid():
		return []
	var frontier: ModuleQueue = ModuleQueue.new()
	frontier.insert(start_vertex, 0)
	var came_from: Dictionary[ModuleGraphVertex, ModuleGraphVertex]
	var cost_so_far: Dictionary[ModuleGraphVertex, float]
	cost_so_far[start_vertex] = 0
	var added_groups: Array[StringName] = []
	
	var end_vertex: ModuleGraphVertex = null
	while not frontier.is_empty():
		var current: ModuleGraphVertex = frontier.extract()
		if end_func.call(current):
			end_vertex = current
			break
		
		if current.group and !added_groups.has(current.group):
			# Group means direct connection, so just go there directly now
			if end_vertex.group == current.group:
				came_from[end_vertex] = current
				break
			# Add all group members, but only once ever!
			added_groups.append(current.group)
			for linked: ModuleGraphVertex in _linked_groups[current.group]:
				if linked != current and not linked.endpoint:
					var new_cost: float = cost_so_far[current] + linked.dist_to(current)
					if not cost_so_far.has(linked) or new_cost < cost_so_far[linked]:
						cost_so_far[linked] = new_cost
						var prio: float = new_cost + _heuristic(linked, end_vertex)
						frontier.insert(linked, prio)
						came_from[linked] = current
		
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
	var path: Array[Node2D] = []
	while cur_vertex != start_vertex:
		path.append(cur_vertex.node)
		cur_vertex = came_from[cur_vertex]
	path.append(start)
	path.reverse()
	return path
