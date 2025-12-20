## Static utility class for GridPositioner tile and movement helpers.
class_name GridPositionerUtils
extends RefCounted

## Convert global position to tile coordinates on the target map
static func get_tile_from_global_position(p_global_position: Vector2, p_map: TileMapLayer) -> Vector2i:
	var map_position = p_map.to_local(p_global_position)
	return p_map.local_to_map(map_position)

## Move a node to a specific tile position
static func move_to_tile(p_node: Node2D, p_tile: Vector2i, p_map: TileMapLayer) -> Error:
	var tile_pos = p_map.to_global(p_map.map_to_local(p_tile))
	p_node.global_position = tile_pos
	return OK

## Move the positioner by a specified number of tiles in a given direction
static func move_positioner_by_tile(p_node: Node2D, p_direction: Vector2, p_target_map: TileMapLayer) -> Error:
	var direction_int = Vector2i(p_direction)
	return GridPositionerUtils.move_to_tile(p_node, direction_int, p_target_map)
