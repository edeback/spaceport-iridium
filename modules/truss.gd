extends ModuleBase
	
func pre_delete() -> void:
	Global.tilemap.set_cells_terrain_connect([module_cell], 0, -1)
	pass
