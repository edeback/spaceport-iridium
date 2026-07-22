@tool
class_name StairsModule
extends ModuleBase

var truss: ModuleData = preload("res://data/modules/core/truss_mdata.tres")

@export var collision_upper: CollisionShape2D

func _ready() -> void:
	add_to_group(Groups.STAIRS)
	super()
	SignalBus.module_added.connect(set_sprite)
	SignalBus.module_removed.connect(set_sprite)
	set_sprite(null)
	
func on_place() -> void:
	super()
	if Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.MODULE, module_cell) == null:
		# add a truss segment below
		Global.world_manager.add_module(truss, module_cell)
	
func set_sprite(_module: ModuleBase) -> void:
	if _module == null or _module is StairsModule or _module is CorridorModule:
		#if Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.CORRIDOR, module_cell) == null:
			## No corridor behind, this is just a stairwell
			#sprite.region_rect.position.x = Global.CELL_SIZE.x * 3
		#else:
		var image_select: int = 0
		if Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.TURBOLIFT, module_cell + Vector2i(0, -1)) is StairsModule:
			# There are stairs above this
			image_select += 1
			collision_upper.disabled = false
		else:
			collision_upper.disabled = true
		if Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.TURBOLIFT, module_cell + Vector2i(0, 1)) is StairsModule:
			# There are stairs below this
			image_select += 2
		sprite.region_rect.position.x = Global.CELL_SIZE.x * image_select
		queue_redraw()
