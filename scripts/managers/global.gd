extends Node

const CELL_SIZE: Vector2i = Vector2i(64, 64)

var time_manager: TimeManager
var save_manager: SaveManager
var world_manager: WorldManager
var path_manager: PathManager
var structure_manager: StructureManager
var adjacency_manager: AdjacencyManager
var power_manager: PowerManager
var job_manager: JobManager
var turbolift_manager: TurboliftManager
var resource_manager: ResourceManager
var market_manager: MarketManager
var economy_manager: EconomyManager
var asteroid_manager: AsteroidManager
var unlock_manager: UnlockManager
var crew_manager: CrewManager
var trader_manager: TraderManager
var event_manager: EventManager
var contract_manager: ContractManager
var raid_manager: RaidManager
var visitor_manager: VisitorManager
var atmosphere_manager: AtmosphereManager
var ui_in_game: UIInGame
var ui_main: UIMain
var tilemap: TileMapLayer
## Debug/cheat helper (WI-19), installed by Main. Callable from the Panku REPL
## as Global.cheats.<method>(...). Null in builds where Main hasn't run yet.
var cheats: Cheats

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func world_to_cell(position: Vector2) -> Vector2i:
	return Vector2i(floor((position.x) / CELL_SIZE.x), floor((position.y) / CELL_SIZE.y))
	
func cell_to_world(cell: Vector2i, use_half_offset: bool = false) -> Vector2:
	return cell * CELL_SIZE + (Vector2i.ONE * CELL_SIZE / 2 if use_half_offset else Vector2i.ZERO)

func world_to_tilemap_cell(position: Vector2) -> Vector2i:
	if tilemap != null:
		return tilemap.local_to_map(position)
	return Vector2i()

func node_path_to_point_path(path: Array[Node2D], use_global_position: bool = false) -> PackedVector2Array:
	var point_path: PackedVector2Array = []
	for node: Node2D in path:
		if node is ModuleBase:
			var module := node as ModuleBase
			if use_global_position:
				point_path.append(cell_to_world(module.module_cell))
			else:
				point_path.append(module.module_cell)
		else:
			if use_global_position:
				point_path.append(node.global_position)
			else:
				point_path.append(world_to_cell(node.global_position))
	return point_path
