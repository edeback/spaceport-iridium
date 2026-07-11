@tool
extends ModuleBase
	
func pre_delete() -> void:
	super()
	Global.tilemap.set_cells_terrain_connect([module_cell], 0, -1)

func overlap_module(_new_module: ModuleData, _is_horizontal: bool) -> bool:
	Global.world_manager.remove_module(self, false)
	return false
