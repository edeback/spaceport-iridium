extends Node

@export var structure_tile_map: TileMapLayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.tilemap = structure_tile_map
	get_viewport().set_physics_object_picking_sort(true)
	#get_viewport().set_physics_object_picking_first_only(true)
	_install_cheats()
	# The root readies after every child, so this is the first moment where every
	# Global.* manager is guaranteed registered - the deterministic point to bring
	# the world online (WI-18). New game: spawn the starting station here. Load:
	# SaveManager owns the spawn (its world section) and emits game_bootstrapped
	# from _apply_pending_load once every section is applied.
	if not SaveManager.has_pending_load():
		Global.world_manager.spawn_starting_station()
		SignalBus.game_bootstrapped.emit()

## Install the cheat surface (WI-19) and expose it to the Panku REPL. Autoloads
## (including Panku) are ready before this main-scene node, so the console's
## expression env exists here. Registering `Global` makes the whole manager
## graph reachable from the REPL - `Global.cheats.<method>(...)` is the intended
## entry point (Panku's Expression can't resolve autoloads on its own, so the
## bare name has to be registered). Guarded so nothing breaks in builds where
## the Panku singleton was stripped (disable_on_release).
func _install_cheats() -> void:
	Global.cheats = Cheats.new()
	var panku: PankuConsole = get_node_or_null("/root/Panku") as PankuConsole
	if panku != null:
		panku.gd_exprenv.register_env("Global", Global)
		panku.gd_exprenv.register_env("cheats", Global.cheats)
