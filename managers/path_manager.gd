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
	SignalBus.module_path_connection_added.connect(_on_module_connection_added)
	SignalBus.module_path_connection_removed.connect(_on_module_connection_removed)
	SignalBus.module_selected.connect(_on_module_selected)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if recheck_pathfinding:
		recheck_pathfinding = false
		check_pathfinding()
	
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
	
func add_vertex(vertex: Node2D, is_endpoint: bool = false, group: StringName = "") -> void:
	graph.add_vertex(vertex, is_endpoint, group)
	
func remove_vertex(vertex: Node2D) -> void:
	graph.remove_vertex(vertex)
	selected_modules.erase(vertex)
	recheck_pathfinding = true
	
func add_connection(from: Node2D, to: Node2D, distance: float) -> void:
	graph.add_edge(from, to, distance)
	recheck_pathfinding = true
	
func _on_module_connection_removed(from: ModuleBase, to: ModuleBase) -> void:
	graph.remove_edge(from, to)
	recheck_pathfinding = true
	
	
func _on_module_selected(module: ModuleBase) -> void:
	if module.selected:
		selected_modules.append(module)
	else:
		selected_modules.erase(module)
	recheck_pathfinding = true

func check_pathfinding() -> void:
	if selected_modules.size() > 1:
		debug_path = []
		for index in range(selected_modules.size() - 1):
			debug_path.append_array(run_pathfinding(selected_modules[index], selected_modules[index + 1]))
		ui_in_game.debug_path_cell = debug_path
	else:
		debug_path = []
		ui_in_game.debug_path_cell = debug_path
	
func _module_path_to_point_path(path: Array[Node2D], use_global_position: bool = false) -> PackedVector2Array:
	var point_path: PackedVector2Array = []
	for node: Node2D in path:
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

## Normally in cells, can convert to global
func run_pathfinding(start_module: Node2D, end_module: Node2D, use_global_position: bool = false) -> PackedVector2Array:
	return _module_path_to_point_path(graph.pathfind(start_module, end_module), use_global_position)
	
func run_pathfinding_to_type(start_module: Node2D, end_type: ModuleData, use_global_position: bool = false) -> PackedVector2Array:
	return _module_path_to_point_path(graph.pathfind_to_type(start_module, end_type), use_global_position)
	
func run_pathfinding_by_node(start_module: Node2D, end_module: Node2D) -> Array[Node2D]:
	return graph.pathfind(start_module, end_module)
	
func run_pathfinding_to_type_by_node(start_module: Node2D, end_type: ModuleData) -> Array[Node2D]:
	return graph.pathfind_to_type(start_module, end_type)
	
func run_pathfinding_to_component_type(start_module: Node2D, end_component_type: Variant) -> Array[Node2D]:
	return graph.pathfind_to_component_type(start_module, end_component_type)

func run_pathfinding_by_func(start_module: Node2D, function: Callable) -> Array[Node2D]:
	return graph.pathfind_to_func(start_module, function)
	
func get_closest_module_by_cell(start_cell: Vector2i) -> ModuleBase:
	return graph.get_closest_module_to_position(Global.cell_to_world(start_cell))
	
func get_closest_module_by_position(start_position: Vector2) -> ModuleBase:
	return graph.get_closest_module_to_position(start_position)

func get_closest_module_by_group(start_position: Vector2, group: StringName) -> ModuleBase:
	return graph.get_closest_module_by_group(start_position, group)
