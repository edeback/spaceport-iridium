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
	# Hands the slot back (WI-71 §7). Godot 4.7 reports a freed object as
	# `== null`, so the guards around the game already take their null branch
	# after a Quit to Menu - but `is_instance_valid(Global.structure_manager)` and the
	# debugger both lie until the slot is actually cleared. `== self` because a
	# second scene can register before this one leaves.
	if Global.structure_manager == self:
		Global.structure_manager = null

func _on_module_added(module: ModuleBase) -> void:
	graph.add_vertex(module)
	
func _on_module_removed(module: ModuleBase) -> void:
	graph.remove_vertex(module)
	
func _on_module_connection_added(from: ModuleBase, to: ModuleBase, distance: float) -> void:
	graph.add_edge(from, to, distance)
	
func _on_module_connection_removed(from: ModuleBase, to: ModuleBase) -> void:
	graph.remove_edge(from, to)
	
## Normally in cells, can convert to global

## Can we remove this module without splitting the station into disconnected
## pieces? Delegates to the graph's cut-vertex test. Because blueprints now form
## their structural edges the moment they're placed (ModuleBase.ready_blueprint),
## the graph reflects the real physical structure during construction too, so
## this answer is honest for in-progress modules - which is what let the delete
## guard be re-enabled.
func can_remove_module(module: ModuleBase) -> bool:
	return not graph.would_removal_split(module)
