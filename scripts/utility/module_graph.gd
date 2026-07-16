class_name ModuleGraph
extends Resource

class PathPoint:
	var node: Node2D = null
	var in_space: bool = false
	var edge_meta: String = ""
	var debug: String = ""

signal graph_changed

## Cost multiplier for travel across the implicit exterior clique. Was the
## "space" group's (defaulted) multiple before exteriorness became a flag.
const EXTERIOR_COST_MULT: float = 1.0

## StringName, Array[ModuleGraphVertex]
var _linked_groups: Dictionary[StringName, Array] = {}
# When pathing through a group, what do we multiply the distance heuristic by?
var _group_multiple: Dictionary[StringName, float] = {}

## All vertices with is_exterior set - the "open space" clique, maintained the
## same way _linked_groups entries are (implicitly interconnected in pathfinding
## and subgraph flooding).
var _exterior_vertices: Array[ModuleGraphVertex] = []

var _vertices: Dictionary[Node2D, ModuleGraphVertex]

var last_subgraph: int = 0

var _subgraph_dirty: bool = false

func _mark_dirty() -> void:
	_subgraph_dirty = true
	
func _flush_subgraphs() -> void:
	if _subgraph_dirty:
		_rebuild_subgraphs()
		_subgraph_dirty = false

func add_vertex(vertex: Node2D, is_endpoint: bool = false, group: StringName = "", group_door: int = 0, exterior: bool = false) -> void:
	if _vertices.has(vertex):
		print("trying to add existing vertex! skipping. Module: " + vertex.name)
		return
	_vertices[vertex] = _make_vertex(vertex, is_endpoint, group, group_door, exterior)
	_emit_graph_changed()

func _make_vertex(vertex: Node2D, is_endpoint: bool = false, group: StringName = "", group_door: int = 0, exterior: bool = false) -> ModuleGraphVertex:
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
	if exterior:
		new_vertex.is_exterior = true
		if not _exterior_vertices.is_empty():
			# Default dump this in the same subgraph as they're all connected
			new_vertex.subgraph = _exterior_vertices[0].subgraph
		_exterior_vertices.append(new_vertex)
	return new_vertex
	
func change_vertex_group(vertex: Node2D, new_group: StringName, new_group_door: int = -1) -> void:
	var graph_vertex: ModuleGraphVertex = _vertices.get(vertex)
	if graph_vertex != null and graph_vertex.group != new_group:
		if graph_vertex.group:
			_linked_groups[graph_vertex.group].erase(graph_vertex)
		if new_group:
			_linked_groups.get_or_add(new_group, []).append(graph_vertex)
			graph_vertex.subgraph = get_group_subgraph(new_group)
		else:
			last_subgraph += 1
			graph_vertex.subgraph = last_subgraph
		graph_vertex.group = new_group
		if new_group_door >= 0:
			graph_vertex.group_door = new_group_door
		if not graph_vertex.endpoint:
			_mark_dirty()
	
## Returns true if the flag actually changed. Mirrors change_vertex_group's
## subgraph bookkeeping: endpoints get their subgraph patched directly (no
## rebuild needed - nothing paths *through* them), everything else marks dirty.
func set_vertex_exterior(vertex: Node2D, exterior: bool, exterior_door: int = -1) -> bool:
	var graph_vertex: ModuleGraphVertex = _vertices.get(vertex)
	if graph_vertex == null or graph_vertex.is_exterior == exterior:
		return false
	graph_vertex.is_exterior = exterior
	if exterior:
		if not _exterior_vertices.is_empty():
			graph_vertex.subgraph = _exterior_vertices[0].subgraph
		_exterior_vertices.append(graph_vertex)
	else:
		_exterior_vertices.erase(graph_vertex)
		last_subgraph += 1
		graph_vertex.subgraph = last_subgraph
	if exterior_door >= 0:
		graph_vertex.exterior_door = exterior_door
	if not graph_vertex.endpoint:
		_mark_dirty()
	return true

func is_vertex_exterior(vertex: Node2D) -> bool:
	var graph_vertex: ModuleGraphVertex = _vertices.get(vertex)
	return graph_vertex != null and graph_vertex.is_exterior

## Returns true if the flag actually changed. Toggling a group stop on/off can
## split or rejoin subgraphs (a floor whose only link to the shaft is the group
## jump), so it always marks dirty.
func set_vertex_no_group_stop(vertex: Node2D, no_stop: bool) -> bool:
	var graph_vertex: ModuleGraphVertex = _vertices.get(vertex)
	if graph_vertex == null or graph_vertex.no_group_stop == no_stop:
		return false
	graph_vertex.no_group_stop = no_stop
	_mark_dirty()
	return true

func set_group_multiple(group: StringName, multiple: float) -> void:
	if group:
		_group_multiple.get_or_add(group, multiple)
		
func get_group_multiple(group: StringName) -> float:
	return _group_multiple.get_or_add(group, 1)
	
func get_group_subgraph(group: StringName) -> int:
	if group:
		var group_array : Array = _linked_groups.get_or_add(group, [])
		if not group_array.is_empty():
			# Default dump this in the same subgraph as they're all connected
			return group_array[0].subgraph
	return -1
	
## Not for use with adding/removing nodes, this redirects pawn to current_module or path_position_override
func get_vertex_for_path(node: Node2D) -> ModuleGraphVertex:
	if node and node is PawnBase:
		var pawn := node as PawnBase
		if pawn.path_position_override != null:
			return _vertices.get(pawn.path_position_override)
		if pawn.current_module != null:
			return _vertices.get(pawn.current_module)
	return _vertices.get(node)
	
func block_vertex(vertex: Node2D) -> void:
	if _vertices.has(vertex):
		_vertices[vertex].blocked = true
		_mark_dirty()
		
func unblock_vertex(vertex: Node2D) -> void:
	if _vertices.has(vertex):
		_vertices[vertex].blocked = false
		_mark_dirty()
		
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
	if old_vertex.is_exterior:
		_exterior_vertices.erase(old_vertex)
	_vertices.erase(vertex)
	# Vertices are RefCounted: dropping the dict/group references above is the
	# cleanup. Erasing its edges from both sides (done above) also breaks the
	# mutual-reference cycles so it can actually be collected.
	_mark_dirty() # This may have split our graph
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
	_mark_dirty()# This may have split our graph
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
	var added_exterior: bool = false
	var frontier: Array[ModuleGraphVertex] = start.edges.keys()
	_expand_implicit_links(start, frontier, added_groups, added_exterior)
	added_exterior = added_exterior or start.is_exterior
	while !frontier.is_empty():
		var next: ModuleGraphVertex = frontier.pop_front() as ModuleGraphVertex
		if next.blocked:
			continue
		if next.subgraph == subgraph:
			continue
		next.subgraph = subgraph
		frontier.append_array(next.edges.keys())
		_expand_implicit_links(next, frontier, added_groups, added_exterior)
		added_exterior = added_exterior or next.is_exterior

## Shared by the flood above: push the vertices this one is implicitly linked
## to (its group clique, the exterior clique) onto the frontier. no_group_stop
## vertices don't ride the group jump in either direction - they only join a
## subgraph through their real edges - so is_reachable stays consistent with
## what pathfinding will actually allow.
func _expand_implicit_links(from: ModuleGraphVertex, frontier: Array[ModuleGraphVertex], added_groups: Array[StringName], added_exterior: bool) -> void:
	if from.group and not from.no_group_stop and not added_groups.has(from.group):
		added_groups.append(from.group)
		for vertex: ModuleGraphVertex in _linked_groups[from.group]:
			if vertex != from and not vertex.no_group_stop:
				frontier.append(vertex)
	if from.is_exterior and not added_exterior:
		for vertex: ModuleGraphVertex in _exterior_vertices:
			if vertex != from:
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
	_emit_graph_changed()

func _rebuild_partial_subgraphs(changed_nodes: Array[ModuleGraphVertex]) -> void:
	for node: ModuleGraphVertex in changed_nodes:
		node.subgraph = -1
	for node: ModuleGraphVertex in changed_nodes:
		if node.subgraph == -1:
			last_subgraph += 1
			_assign_subgraph_from(node, last_subgraph)

func get_closest_module_to_position(vector: Vector2, vertices: Array[ModuleGraphVertex]) -> ModuleBase:
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
	_flush_subgraphs()
	var start_vertex: ModuleGraphVertex = get_vertex_for_path(start)
	var end_vertex: ModuleGraphVertex = get_vertex_for_path(end)
	return start_vertex and end_vertex and start_vertex.subgraph == end_vertex.subgraph
	
func is_space_reachable(start: Node2D) -> bool:
	_flush_subgraphs()
	var start_vertex: ModuleGraphVertex = get_vertex_for_path(start)
	return start_vertex != null and start_vertex.subgraph == get_exterior_subgraph()

## Subgraph shared by every exterior vertex, or -1 when nothing is exterior
## (no airlocks, no blueprints) - is_space_reachable then cleanly returns false.
func get_exterior_subgraph() -> int:
	if _exterior_vertices.is_empty():
		return -1
	return _exterior_vertices[0].subgraph

func pathfind(start: Node2D, end: Node2D) -> Array[PathPoint]:
	var start_vertex: ModuleGraphVertex = get_vertex_for_path(start)
	var end_vertex: ModuleGraphVertex = get_vertex_for_path(end)
	return pathfind_by_vertex(start_vertex, end_vertex)

func pathfind_by_vertex(start_vertex: ModuleGraphVertex, end_vertex: ModuleGraphVertex) -> Array[PathPoint]:
	_flush_subgraphs()
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
			
		# A no_group_stop vertex is a physical shaft cell but never a boarding
		# or alighting point: it neither offers the group jump nor receives it.
		if current.group and not current.no_group_stop:
			for linked: ModuleGraphVertex in _linked_groups[current.group]:
				if linked.no_group_stop:
					continue
				if linked == end_vertex or (linked != current and not linked.endpoint):
					var new_cost: float = cost_so_far[current] + linked.dist_to(current) * get_group_multiple(current.group)
					if not cost_so_far.has(linked) or new_cost < cost_so_far[linked]:
						cost_so_far[linked] = new_cost
						var prio: float = new_cost + _heuristic(linked, end_vertex)
						frontier.insert(linked, prio)
						came_from[linked] = current

		if current.is_exterior:
			for linked: ModuleGraphVertex in _exterior_vertices:
				if linked == end_vertex or (linked != current and not linked.endpoint):
					var new_cost: float = cost_so_far[current] + linked.dist_to(current) * EXTERIOR_COST_MULT
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
		next_point.in_space = cur_vertex.is_exterior
		next_point.debug = cur_vertex.node.name
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
	start_point.in_space = start_vertex.is_exterior
	start_point.debug = start_vertex.node.name
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
	
## Temporarily splice a free-floating node (asteroid, debris pile) into the
## exterior clique for the duration of one pathfind. _make_vertex handles the
## clique membership and subgraph adoption; erase both here so nothing leaks.
func pathfind_to_node_in_space(start: Node2D, end: Node2D) -> Array[PathPoint]:
	var temp_vertex: ModuleGraphVertex = _make_vertex(end, true, "", 0, true)
	var path := pathfind_by_vertex(get_vertex_for_path(start), temp_vertex)
	_exterior_vertices.erase(temp_vertex)
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
	_flush_subgraphs()
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
		
		# Same no_group_stop rules as pathfind_by_vertex: disabled floors never
		# offer or receive the group jump.
		if current.group and not current.no_group_stop:
			for linked: ModuleGraphVertex in _linked_groups[current.group]:
				if linked.no_group_stop:
					continue
				if linked == end_vertex or (linked != current and not linked.endpoint):
					var new_cost: float = cost_so_far[current] + linked.dist_to(current) * get_group_multiple(current.group)
					if not cost_so_far.has(linked) or new_cost < cost_so_far[linked]:
						cost_so_far[linked] = new_cost
						var prio: float = new_cost + _heuristic(linked, end_vertex)
						frontier.insert(linked, prio)
						came_from[linked] = current

		if current.is_exterior:
			for linked: ModuleGraphVertex in _exterior_vertices:
				if linked == end_vertex or (linked != current and not linked.endpoint):
					var new_cost: float = cost_so_far[current] + linked.dist_to(current) * EXTERIOR_COST_MULT
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
		next_point.in_space = cur_vertex.is_exterior
		path.append(next_point)
		cur_vertex = came_from[cur_vertex]
	var start_point := PathPoint.new()
	start_point.node = start_vertex.node
	start_point.in_space = start_vertex.is_exterior
	path.append(start_point)
	path.reverse()
	return path
