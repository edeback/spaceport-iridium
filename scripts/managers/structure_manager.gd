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
	Global.structure_manager = self

## Break the graph's vertex cycles before it is released, or every load and Quit
## to Menu leaks the station's whole structure graph (WI-68 F3).
func _exit_tree() -> void:
	graph.clear()

func _on_module_added(module: ModuleBase) -> void:
	graph.add_vertex(module)
	
func _on_module_removed(module: ModuleBase) -> void:
	graph.remove_vertex(module)
	
func _on_module_connection_added(from: ModuleBase, to: ModuleBase, distance: float) -> void:
	graph.add_edge(from, to, distance)
	
func _on_module_connection_removed(from: ModuleBase, to: ModuleBase) -> void:
	graph.remove_edge(from, to)
	
## Normally in cells, can convert to global
#func run_pathfinding(start_module: Node2D, end_module: Node2D, use_global_position: bool = false) -> PackedVector2Array:
	#return Global.node_path_to_point_path(graph.pathfind(start_module, end_module), use_global_position)
	##return astar.get_point_path(start_module.module_id, end_module.module_id)
	#
#func run_pathfinding_to_type(start_module: Node2D, end_type: ModuleData, use_global_position: bool = false) -> PackedVector2Array:
	#return Global.node_path_to_point_path(graph.pathfind_to_type(start_module, end_type), use_global_position)
	#
#func run_pathfinding_by_module(start_module: Node2D, end_module: Node2D) -> Array[Node2D]:
	#return graph.pathfind(start_module, end_module)
	#
#func run_pathfinding_to_type_by_module(start_module: Node2D, end_type: ModuleData) -> Array[Node2D]:
	#return graph.pathfind_to_type(start_module, end_type)
#
#func get_closest_module_by_cell(start_cell: Vector2i) -> ModuleBase:
	#return graph.get_closest_module_to_position(Global.cell_to_world(start_cell))
	#
#func get_closest_module_by_position(start_position: Vector2) -> ModuleBase:
	#return graph.get_closest_module_to_position(start_position)

## Can we remove this module without splitting the station into disconnected
## pieces? Delegates to the graph's cut-vertex test. Because blueprints now form
## their structural edges the moment they're placed (ModuleBase.ready_blueprint),
## the graph reflects the real physical structure during construction too, so
## this answer is honest for in-progress modules - which is what let the delete
## guard be re-enabled.
func can_remove_module(module: ModuleBase) -> bool:
	return not graph.would_removal_split(module)
