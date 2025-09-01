class_name PathManager
extends Node

@onready var ui_in_game: UIInGame = $"../../ModuleLayers/UiInGameLayer/UiInGame"

var astar:AStar2D = AStar2D.new()
var graph:ModuleGraph = ModuleGraph.new()
var debug_path: PackedVector2Array
var selected_modules = {}

var recheck_pathfinding: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.path_manager = self
	SignalBus.module_added.connect(_on_module_added)
	SignalBus.module_removed.connect(_on_module_removed)
	SignalBus.module_connection_added.connect(_on_module_connection_added)
	SignalBus.module_connection_removed.connect(_on_module_connection_removed)
	SignalBus.module_selected.connect(_on_module_selected)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if recheck_pathfinding:
		recheck_pathfinding = false
		check_pathfinding()
	
func _on_module_added(module: ModuleBase) -> void:
	astar.add_point(module.module_id, module.module_cell)
	graph.add_vertex(module)
	recheck_pathfinding = true
	
func _on_module_removed(module: ModuleBase) -> void:
	astar.remove_point(module.module_id)
	graph.remove_vertex(module)
	selected_modules.erase(module)
	recheck_pathfinding = true
	
func _on_module_connection_added(from: ModuleBase, to: ModuleBase, distance: float) -> void:
	graph.add_edge(from, to, distance)
	recheck_pathfinding = true
	
func _on_module_connection_removed(from: ModuleBase, to: ModuleBase) -> void:
	graph.remove_edge(from, to)
	recheck_pathfinding = true
	
func _on_module_selected(module: ModuleBase) -> void:
	if module.selected:
		selected_modules[module] = 1
	else:
		selected_modules.erase(module)
	recheck_pathfinding = true

func check_pathfinding() -> void:
	if selected_modules.size() == 2:
		var modules = selected_modules.keys()
		debug_path = run_pathfinding(modules[0], modules[1])
		ui_in_game.debug_path = debug_path
	else:
		debug_path = []
		ui_in_game.debug_path = debug_path
	
func run_pathfinding(start_module: ModuleBase, end_module: ModuleBase) -> PackedVector2Array:
	return graph.get_point_path(start_module, end_module)
	#return astar.get_point_path(start_module.module_id, end_module.module_id)
	

func get_closest_module_by_cell(start_cell: Vector2i) -> ModuleBase:
	return graph.get_closest_module_to(start_cell)
	#return Global.world_manager.get_module_by_id(astar.get_closest_point(start_cell))
	
func get_closest_module_by_position(start_position: Vector2) -> ModuleBase:
	return get_closest_module_by_cell(Global.world_to_cell(start_position))
