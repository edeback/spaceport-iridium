extends Node

const CELL_SIZE: Vector2i = Vector2i(64, 64)

var world_manager: WorldManager
var path_manager: PathManager
var structure_manager: StructureManager
var power_manager: PowerManager
var job_manager: JobManager
var turbolift_manager: TurboliftManager
var resource_manager: ResourceManager
var market_manager: MarketManager
var asteroid_manager: AsteroidManager
var ui_in_game: UIInGame
var tilemap: TileMapLayer

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

# All the below functions don't really work as they don't read values that aren't overridden
# Need to figure out how to find the base class
func get_node_index_from_scene(scene: PackedScene, node: String) -> int:
	var packed_state = scene.get_state()
	for id in packed_state.get_node_count():
		var node_name = packed_state.get_node_name(id)
		if node_name == node:
			return id
	return -1

func get_property_from_scene(scene: PackedScene, node: String, property: String):
	debug_print_properties_from_scene(scene)
	var node_id = get_node_index_from_scene(scene, node)
	if node_id >= 0:
		var packed_state = scene.get_state()
		for prop_id in packed_state.get_node_property_count(node_id):
			if packed_state.get_node_property_name(node_id, prop_id) == property:
				return packed_state.get_node_property_value(node_id, prop_id)
		
	return null

func debug_print_properties_from_scene(scene: PackedScene) -> void:
	print(scene._bundled)
	var packed_state = scene.get_state()
	for node_id in packed_state.get_node_count():
		var node_name = packed_state.get_node_name(node_id)
		print("Node: " + node_name)
		for prop_id in packed_state.get_node_property_count(node_id):
			print(packed_state.get_node_property_name(node_id, prop_id))
			if packed_state.get_node_property_name(node_id, prop_id) == "script":
				var script_instance = packed_state.get_node_property_value(node_id, prop_id) as GDScript
				print(script_instance.get_script_property_list())
