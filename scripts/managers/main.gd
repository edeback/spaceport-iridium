extends Node

@export var structure_tile_map: TileMapLayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.tilemap = structure_tile_map
	get_viewport().set_physics_object_picking_sort(true)
	#get_viewport().set_physics_object_picking_first_only(true)
	# The root readies after every child, so this is the first moment where every
	# Global.* manager is guaranteed registered - the deterministic point to bring
	# the world online (WI-18). New game: spawn the starting station here. Load:
	# SaveManager owns the spawn (its world section) and emits game_bootstrapped
	# from _apply_pending_load once every section is applied.
	if not SaveManager.has_pending_load():
		Global.world_manager.spawn_starting_station()
		SignalBus.game_bootstrapped.emit()
