class_name PathManager
extends Node

@onready var ui_in_game: UIInGame = $"../../ForegroundLayers/UiInGameLayer/UiInGame"

var graph:ModuleGraph = ModuleGraph.new()
var debug_path: PackedVector2Array
var selected_modules: Array[Node2D] = []

var recheck_pathfinding: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.path_manager = self
	SignalBus.module_added.connect(_on_module_added)
	SignalBus.module_removed.connect(_on_module_removed)
	SignalBus.module_path_connection_removed.connect(_on_module_connection_removed)
	SignalBus.module_selected.connect(_on_module_selected)

## Break the graph's vertex cycles before it is released, or every load and Quit
## to Menu leaks the station's whole path graph (WI-68 F3).
func _exit_tree() -> void:
	graph.clear()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	graph._flush_subgraphs()
	if recheck_pathfinding:
		recheck_pathfinding = false
		check_pathfinding()
		_update_disconnected_indicators()
	
func _on_module_added(module: ModuleBase) -> void:
	graph.add_vertex(module)
	recheck_pathfinding = true
	
func _on_module_removed(module: ModuleBase) -> void:
	graph.remove_vertex(module)
	selected_modules.erase(module)
	recheck_pathfinding = true
	
func _on_module_connection_added(from: ModuleBase, to: ModuleBase, distance: float) -> void:
	graph.add_edge(from, to, distance)
	recheck_pathfinding = true
	
func add_vertex(vertex: Node2D, is_endpoint: bool = false, group: StringName = "", exterior: bool = false) -> void:
	graph.add_vertex(vertex, is_endpoint, group, 0, exterior)

func get_vertex(vertex: Node2D) -> ModuleGraphVertex:
	return graph._vertices.get(vertex)

func change_vertex_group(vertex: Node2D, new_group: StringName, new_group_door: int = -1) -> void:
	graph.change_vertex_group(vertex, new_group, new_group_door)
	if vertex is ModuleBase:
		SignalBus.module_group_changed.emit(vertex as ModuleBase)
		recheck_pathfinding = true

## Exteriorness is derived state (build state, pawn position) - never saved,
## always re-flagged by the same code paths that set it live. Reuses the
## module_group_changed repath hook: in-flight paths crossing this module
## re-check exactly as they do for group swaps.
func set_exterior(vertex: Node2D, exterior: bool) -> void:
	if graph.set_vertex_exterior(vertex, exterior) and vertex is ModuleBase:
		SignalBus.module_group_changed.emit(vertex as ModuleBase)
		# Exterior flips change disconnected-indicator eligibility - recheck.
		recheck_pathfinding = true

func is_exterior(vertex: Node2D) -> bool:
	return graph.is_vertex_exterior(vertex)

## Turbolift floor disable (WI-11): the vertex stays a physical shaft cell but
## stops being a boarding/alighting point for the group jump.
func set_no_group_stop(vertex: Node2D, no_stop: bool) -> void:
	if graph.set_vertex_no_group_stop(vertex, no_stop) and vertex is ModuleBase:
		SignalBus.module_group_changed.emit(vertex as ModuleBase)
		recheck_pathfinding = true
	
func remove_vertex(vertex: Node2D) -> void:
	graph.remove_vertex(vertex)
	selected_modules.erase(vertex)
	recheck_pathfinding = true
	
func add_connection(from: Node2D, to: Node2D, distance: float, data: StringName = "") -> void:
	graph.add_edge(from, to, distance, data)
	recheck_pathfinding = true
	
func _on_module_connection_removed(from: ModuleBase, to: ModuleBase) -> void:
	graph.remove_edge(from, to)
	recheck_pathfinding = true
	
	
func _on_module_selected(module: ModuleBase) -> void:
	if module.selected:
		selected_modules.append(module)
	else:
		selected_modules.erase(module)

## WI-10 no-path indicator: blink any built, pawn-traversable non-SPACE layer
## module whose vertex sits outside the station's largest subgraph. Exempt:
## blueprints and exterior vertices (ConstructionComponent flags
## construction/deconstruction sites exterior deliberately - without the
## exemption every construction site would blink), plus modules with no
## PathComponent (truss, external hardware) - pawns never enter those, so
## "disconnected" is meaningless for them.
func _update_disconnected_indicators() -> void:
	var subgraph_counts: Dictionary[int, int] = {}
	var eligible: Array[ModuleBase] = []
	for node: Node2D in graph._vertices:
		var module := node as ModuleBase
		if module == null or module.module_data == null or module.get_path_component() == null:
			continue
		if module.module_data.interaction_layer == WorldManager.StructureLayer.SPACE:
			continue
		var vertex: ModuleGraphVertex = graph._vertices[node]
		if vertex.is_exterior or not module.is_complete() or module.get_path_component().path_points.is_empty():
			module.get_path_component().set_disconnected_indicator(false)
			continue
		eligible.append(module)
		subgraph_counts[vertex.subgraph] = subgraph_counts.get(vertex.subgraph, 0) + 1
	var main_subgraph: int = -1
	var best_count: int = 0
	for subgraph: int in subgraph_counts:
		if subgraph_counts[subgraph] > best_count:
			best_count = subgraph_counts[subgraph]
			main_subgraph = subgraph
	for module: ModuleBase in eligible:
		module.get_path_component().set_disconnected_indicator(graph._vertices[module].subgraph != main_subgraph)


func check_pathfinding() -> void:
	if selected_modules.size() > 1:
		debug_path = []
		for index in range(selected_modules.size() - 1):
			debug_path.append_array(run_pathfinding(selected_modules[index], selected_modules[index + 1]))
		ui_in_game.debug_path_cell = debug_path
	else:
		debug_path = []
		ui_in_game.debug_path_cell = debug_path
	
func _module_path_to_point_path(path: Array[ModuleGraph.PathPoint], use_global_position: bool = false) -> PackedVector2Array:
	var point_path: PackedVector2Array = []
	for point: ModuleGraph.PathPoint in path:
		var node: Node2D = point.node
		if node is ModuleBase:
			var module := node as ModuleBase
			if use_global_position:
				point_path.append(Global.cell_to_world(module.module_cell))
			else:
				point_path.append(module.module_cell)
		else:
			if use_global_position:
				point_path.append(node.global_position)
			else:
				point_path.append(Global.world_to_cell(node.global_position))
	return point_path
	
func disable_module(module: ModuleBase) -> void:
	graph.block_vertex(module)
	recheck_pathfinding = true
	
func enable_module(module: ModuleBase) -> void:
	graph.unblock_vertex(module)
	recheck_pathfinding = true

func is_reachable(start: Node2D, end: Node2D) -> bool:
	return graph.is_reachable(start, end)
	
func is_space_reachable(start: Node2D) -> bool:
	return graph.is_space_reachable(start)

## Normally in cells, can convert to global
func run_pathfinding(start_module: Node2D, end_module: Node2D, use_global_position: bool = false) -> PackedVector2Array:
	return _module_path_to_point_path(graph.pathfind(start_module, end_module), use_global_position)
	
func run_pathfinding_to_type(start_module: Node2D, end_type: ModuleData, use_global_position: bool = false) -> PackedVector2Array:
	return _module_path_to_point_path(graph.pathfind_to_type(start_module, end_type), use_global_position)
	
func run_pathfinding_by_node(start_module: Node2D, end_module: Node2D, end_in_space: bool = false) -> Array[ModuleGraph.PathPoint]:
	if end_in_space:
		return graph.pathfind_to_node_in_space(start_module, end_module)
	return graph.pathfind(start_module, end_module)
	
func run_pathfinding_to_type_by_node(start_module: Node2D, end_type: ModuleData) -> Array[ModuleGraph.PathPoint]:
	return graph.pathfind_to_type(start_module, end_type)
	
func run_pathfinding_to_component_type(start_module: Node2D, end_component_type: Variant) -> Array[ModuleGraph.PathPoint]:
	return graph.pathfind_to_component_type(start_module, end_component_type)

func run_pathfinding_by_func(start_module: Node2D, function: Callable) -> Array[ModuleGraph.PathPoint]:
	return graph.pathfind_to_func(start_module, function)

func get_closest_module_by_group(start_position: Vector2, group: StringName) -> ModuleBase:
	return graph.get_closest_module_by_group(start_position, group)
