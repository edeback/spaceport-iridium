@tool
extends ModuleBase

## The structural placeholder must never be removed by damage (WI-24): trusses
## carry the station's attachment graph, so destroying one could split the
## station in two. At 0 HP a truss instead becomes wreckage - it stays placed,
## keeps its StructureManager connection, and its damage modifier makes EVA
## across it crawl (via traversal_speed_mult) until a repair job restores it.
func _on_hp_zero(_source: StringName) -> void:
	SignalBus.station_alert.emit("Truss wreckage at %s - structure holding, but barely." % str(module_cell))

func pre_delete() -> void:
	super()
	Global.tilemap.set_cells_terrain_connect([module_cell], 0, -1)

func overlap_module(_new_module: ModuleData) -> bool:
	Global.world_manager.remove_module(self, false)
	return false
