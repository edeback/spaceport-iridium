## Static utility methods for collision mapping.
extends RefCounted

## Returns absolute tile coordinates overlapped by a rectangle centered at a world position.
static func get_rect_tile_positions(p_map: TileMapLayer, global_center_position: Vector2, transformed_rect_size: Vector2) -> Array[Vector2i]:
	var tile_positions: Array[Vector2i] = []

	if p_map == null:
		return tile_positions

	if p_map.tile_set == null:
		return tile_positions

	var tile_size = p_map.tile_set.tile_size

	var center_tile = p_map.local_to_map(p_map.to_local(global_center_position))

	var tiles_wide = ceil(transformed_rect_size.x / tile_size.x)
	var tiles_high = ceil(transformed_rect_size.y / tile_size.y)

	var tiles_left = floor(tiles_wide / 2.0)
	var tiles_right = tiles_wide - tiles_left
	var tiles_up = floor(tiles_high / 2.0)
	var tiles_down = tiles_high - tiles_up

	for x_offset in range(-tiles_left, tiles_right):
		for y_offset in range(-tiles_up, tiles_down):
			var tile_coords = center_tile + Vector2i(x_offset, y_offset)
			tile_positions.append(tile_coords)

	return tile_positions

## Tests collision between indicator and a target shape.
static func does_indicator_overlap_shape(tile_indicator: RuleCheckIndicator, shape: Shape2D, shape_owner: Node2D) -> bool:
	if shape == null:
		return false
	
	var indicator_shape: Shape2D = tile_indicator.shape
	if indicator_shape == null:
		return false

	var owner_transform = shape_owner.global_transform
	var indicator_transform = tile_indicator.global_transform
	return indicator_shape.collide(indicator_transform, shape, owner_transform)

## Check if a collision object matches the given layer mask
static func object_matches_layer_mask(collision_object: CollisionObject2D, mask: int) -> bool:
	if not collision_object:
		return false
	
	# Check if any bits match between the object's layer and the mask
	return (collision_object.collision_layer & mask) != 0