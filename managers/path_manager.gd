class_name PathManager
extends Node

@onready var ui_in_game: Control = $"../../UiInGame"

var astar:AStar2D = AStar2D.new()
var debug_path: PackedVector2Array
var selected_modules = {}

var recheck_pathfinding = false

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
	recheck_pathfinding = true
	
func _on_module_removed(module: ModuleBase) -> void:
	astar.remove_point(module.module_id)
	selected_modules.erase(module)
	recheck_pathfinding = true
	
func _on_module_connection_added(from: int, to: int) -> void:
	astar.connect_points(from, to)
	recheck_pathfinding = true
	
func _on_module_connection_removed(from: int, to: int) -> void:
	astar.disconnect_points(from, to)
	recheck_pathfinding = true
	
func _on_module_selected(module: ModuleBase) -> void:
	if module.selected:
		selected_modules[module] = 1
	else:
		selected_modules.erase(module)
	recheck_pathfinding = true

func check_pathfinding() -> void:
	if selected_modules.size() == 2:
		run_pathfinding()
	else:
		debug_path = []
		ui_in_game.debug_path = debug_path
	
func run_pathfinding() -> void:
	var modules = selected_modules.keys()
	debug_path = astar.get_point_path(modules[0].module_id, modules[1].module_id)
	ui_in_game.debug_path = debug_path
