## Handles processing for CollisionPolygon2D.
extends RefCounted

const PolygonTileMapper = preload("uid://ct6b88fq188yg")

var _targeting_state: GridTargetingState
var _mapper : PolygonTileMapper

func _init(targeting_state: GridTargetingState) -> void:
	_targeting_state = targeting_state
	_mapper = PolygonTileMapper.new()

## Converts collision polygon geometry to tile offsets.
## This method processes a CollisionPolygon2D node and maps its geometry to tile offsets on the given TileMapLayer.
## It returns a dictionary where keys are Vector2i tile offsets and values are arrays of CollisionPolygon2D nodes.
##
## @param polygon_node: The CollisionPolygon2D node to process.
## @param map: The TileMapLayer to map offsets against.
## @param logger: The logger for diagnostic output.
## @return A Dictionary[Vector2i, Array[CollisionPolygon2D]] containing tile offsets as keys and associated collision polygons as values.
func get_tile_offsets_for_collision_polygon(polygon_node: CollisionPolygon2D, map: TileMapLayer, logger: GBLogger = null) -> Dictionary[Vector2i, Array]:
	var collision_positions: Dictionary[Vector2i, Array] = {}
	
	if not polygon_node is CollisionPolygon2D:
		push_error("CollisionPolygonProcessor: Expected CollisionPolygon2D, got " + str(polygon_node.get_class()) + ". This processor only handles CollisionPolygon2D nodes.")
		return collision_positions
	
	if not _targeting_state or not _targeting_state.positioner:
		push_error("CollisionPolygonProcessor: Targeting state or positioner is null. Cannot process collision polygons.")
		return collision_positions

	var offsets = _mapper.compute_tile_offsets(polygon_node, map)

	for off in offsets:
		collision_positions[off] = [polygon_node]
	return collision_positions