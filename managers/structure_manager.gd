class_name StructureManager
extends Node

@onready var ui_in_game: UIInGame = $"../../ForegroundLayers/UiInGameLayer/UiInGame"

var graph:ModuleGraph = ModuleGraph.new()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SignalBus.module_added.connect(_on_module_added)
	SignalBus.module_removed.connect(_on_module_removed)
	SignalBus.module_structure_connection_added.connect(_on_module_connection_added)
	SignalBus.module_structure_connection_removed.connect(_on_module_connection_removed)
	pass # Replace with function body.
	
func _on_module_added(module: ModuleBase) -> void:
	graph.add_vertex(module)
	
func _on_module_removed(module: ModuleBase) -> void:
	graph.remove_vertex(module)
	
func _on_module_connection_added(from: ModuleBase, to: ModuleBase, distance: float) -> void:
	graph.add_edge(from, to, distance)
	
func _on_module_connection_removed(from: ModuleBase, to: ModuleBase) -> void:
	graph.remove_edge(from, to)
	
func _module_path_to_point_path(path: Array[ModuleBase], use_global_position: bool = false) -> PackedVector2Array:
	var point_path: PackedVector2Array = []
	for module: ModuleBase in path:
		if use_global_position:
			point_path.append(Global.cell_to_world(module.module_cell))
		else:
			point_path.append(module.module_cell)
	return point_path

## Normally in cells, can convert to global
func run_pathfinding(start_module: ModuleBase, end_module: ModuleBase, use_global_position: bool = false) -> PackedVector2Array:
	return _module_path_to_point_path(graph.pathfind(start_module, end_module), use_global_position)
	#return astar.get_point_path(start_module.module_id, end_module.module_id)
	
func run_pathfinding_to_type(start_module: ModuleBase, end_type: ModuleData, use_global_position: bool = false) -> PackedVector2Array:
	return _module_path_to_point_path(graph.pathfind_to_type(start_module, end_type), use_global_position)
	
func run_pathfinding_by_module(start_module: ModuleBase, end_module: ModuleBase) -> Array[ModuleBase]:
	return graph.pathfind(start_module, end_module)
	
func run_pathfinding_to_type_by_module(start_module: ModuleBase, end_type: ModuleData) -> Array[ModuleBase]:
	return graph.pathfind_to_type(start_module, end_type)

func get_closest_module_by_cell(start_cell: Vector2i) -> ModuleBase:
	return graph.get_closest_module_to(start_cell)
	#return Global.world_manager.get_module_by_id(astar.get_closest_point(start_cell))
	
func get_closest_module_by_position(start_position: Vector2) -> ModuleBase:
	return get_closest_module_by_cell(Global.world_to_cell(start_position))
