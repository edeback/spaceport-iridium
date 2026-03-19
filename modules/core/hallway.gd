@tool
class_name CorridorModule
extends ModuleBase

var truss: ModuleData = preload("res://data/modules/core/truss_mdata.tres")
		
@export var door_sprite: Sprite2D


func _ready() -> void:
	super()
	SignalBus.module_added.connect(set_sprite)
	SignalBus.module_removed.connect(set_sprite)
	set_sprite(null)
	
func on_place() -> void:
	super()
	if Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.MODULE, module_cell) == null:
		# add a truss segment below
		Global.world_manager.add_module(truss, module_cell)
	
	
func make_connections() -> void:
	get_path_component().door_connected.connect(door_connected_to)
	get_path_component().door_disconnected.connect(door_disconnected_to)
	super()
	
func remove_connections() -> void:
	super()
	get_path_component().door_connected.disconnect(door_connected_to)
	get_path_component().door_disconnected.disconnect(door_disconnected_to)
	
	
func door_connected_to(_cell: Vector2i, from_layer: WorldManager.StructureLayer) -> void:
	if from_layer == WorldManager.StructureLayer.MODULE:
		door_sprite.region_rect.position.x = 0
	
func door_disconnected_to(_cell: Vector2i, from_layer: WorldManager.StructureLayer) -> void:
	if from_layer == WorldManager.StructureLayer.MODULE:
		door_sprite.region_rect.position.x = 128

func set_sprite(_module: ModuleBase) -> void:
	if _module == null or _module is CorridorModule:
		var blocked_value: int = 0
		var left_cell: Vector2i = module_cell - Vector2i(1, 0)
		if Global.world_manager.get_module_by_cell(module_data.interaction_layer, left_cell) is CorridorModule:
			blocked_value += 1
		var right_cell: Vector2i = module_cell + Vector2i(size.x, 0)
		if Global.world_manager.get_module_by_cell(module_data.interaction_layer, right_cell) is CorridorModule:
			blocked_value += 2
		sprite.region_rect.position.x = Global.CELL_SIZE.x * blocked_value
		queue_redraw()
