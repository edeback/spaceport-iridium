@tool
class_name AirlockModule
extends ModuleBase


func on_place() -> void:
	super()
	for point in get_structure_component().internal_points:
		if Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.MODULE, module_cell + point) == null:
			# add a truss segment below
			Global.world_manager.add_module(structural_backfill(), module_cell + point)
