
## Utility functions for geometry calculations and shape operations.
##
## Provides static methods for working with collision shapes, bounding boxes, and coordinate transformations in grid building contexts.
class_name GBGeometryUtils

## Converts an array of Vector2 points to a bounding Rect2.
## Returns a Rect2 that bounds all points in the given PackedVector2Array, with the origin at p_rect_position.
static func points_array_to_rect_2d(p_vector_array : PackedVector2Array, p_rect_position : Vector2) -> Rect2:
	var left_bound = p_vector_array[0].x
	var right_bound = p_vector_array[0].x
	var top_bound = p_vector_array[0].y
	var bottom_bound = p_vector_array[0].y
	
	for index in range(1, p_vector_array.size(), 1):
		if(p_vector_array[index].x < left_bound):
			left_bound = p_vector_array[index].x
		
		if(p_vector_array[index].x > right_bound):
			right_bound = p_vector_array[index].x
		
		if(p_vector_array[index].y < top_bound):
			top_bound = p_vector_array[index].y
		
		if(p_vector_array[index].y > bottom_bound):
			bottom_bound = p_vector_array[index].y
	
	var size = Vector2(
		abs(left_bound - right_bound),
		abs(top_bound - bottom_bound)
	)
	
	var generated_rect = Rect2(p_rect_position, size)

	return generated_rect


## Returns all Shape2D instances owned by a CollisionObject2D.[br][br]
## [code]p_collision_object[/code]: [i]CollisionObject2D[/i] - Collision object to extract shapes from
static func get_collision_object_shapes(p_collision_object : CollisionObject2D) -> Array[Shape2D]:
	var shapes_dict = {}

	var shape_owners = p_collision_object.get_shape_owners()
	
	for owner in shape_owners:
		var shape_count = p_collision_object.shape_owner_get_shape_count(owner)
		
		for shape_index in shape_count:
			var shape = p_collision_object.shape_owner_get_shape(owner, shape_index)
			shapes_dict[shape] = ""
	
	var shapes : Array[Shape2D] = []
	shapes.append_array(shapes_dict.keys())
	
	return shapes
	
## Returns a dictionary mapping each collidable node (CollisionObject2D or CollisionPolygon2D)
## to its array of Shape2D objects. This allows you to check collision layers/masks and know which shapes belong to which node.
## Supports both standard collision objects and polygon-defined collision shapes.
## Recursively returns a dictionary mapping each collidable node (CollisionObject2D or CollisionPolygon2D)
## to its array of Shape2D objects. Includes root and all children.
## Useful for mapping collision owners to their shapes for collision checks.
static func get_all_collision_shapes_by_owner(root_node: Node2D) -> Dictionary[Node2D, Array]:
	var result: Dictionary[Node2D, Array] = {}
	if root_node == null:
		push_warning("get_all_collision_shapes_by_owner: root_node is null.")
		return result

	# Add root if it's a collidable node
	if root_node is CollisionObject2D or root_node is CollisionPolygon2D:
		var shapes: Array[Shape2D] = GBGeometryUtils.get_shapes_from_owner(root_node)
		if not shapes.is_empty():
			result[root_node] = shapes

	# Recursively add all children that are collision owners
	for child in root_node.get_children():
		if child is Node2D:
			result.merge(get_all_collision_shapes_by_owner(child))

	return result

## Helper to get all shape 2Ds that a owner Node2D has.
## Returns all Shape2D objects owned by a Node2D (CollisionObject2D or CollisionPolygon2D). Converts polygons to ConvexPolygonShape2D if possible.[br][br]
## [code]p_owner[/code]: [i]Node2D[/i] - Node to extract shapes from (CollisionObject2D or CollisionPolygon2D)
static func get_shapes_from_owner(p_owner: Node2D) -> Array[Shape2D]:
	var shapes: Array[Shape2D] = []
	if p_owner is CollisionObject2D:
		var shape_owners = p_owner.get_shape_owners()
		for owner in shape_owners:
			var shape_count = p_owner.shape_owner_get_shape_count(owner)
			for shape_index in shape_count:
				var shape = p_owner.shape_owner_get_shape(owner, shape_index)
				if shape is Shape2D:
					shapes.append(shape)
		
		# REGRESSION FIX: If no shape owners found, check for CollisionShape2D children
		# This handles cases where collision objects are created dynamically and haven't been
		# registered with the physics system yet (e.g., from PackedScene instantiation)
		if shapes.is_empty():
			for child in p_owner.get_children():
				if child is CollisionShape2D:
					var collision_shape = child as CollisionShape2D
					if collision_shape.shape != null:
						shapes.append(collision_shape.shape)
	elif p_owner is CollisionPolygon2D:
		# Convert polygon to ConvexPolygonShape2D if possible
		if p_owner.polygon.size() >= 3:
			var poly_shape: Shape2D = ConvexPolygonShape2D.new()
			poly_shape.points = p_owner.polygon
			shapes.append(poly_shape)
	return shapes
	
## Grows a rect2 by the given increment values
## Returns a Rect2 grown by the given increment vector, handling negative sizes correctly.
## Useful for expanding bounding boxes or shapes by a margin.
static func grow_rect2_to_increment(p_rect : Rect2, p_increment : Vector2) -> Rect2:
	var adjusted_rect = p_rect
	# Handle negative sizes by growing in the appropriate direction
	var new_size_x = p_rect.size.x + p_increment.x * sign(p_rect.size.x) if p_rect.size.x != 0 else p_increment.x
	var new_size_y = p_rect.size.y + p_increment.y * sign(p_rect.size.y) if p_rect.size.y != 0 else p_increment.y
	adjusted_rect.size = Vector2(new_size_x, new_size_y)
	return adjusted_rect

# Makes a rect2 have equal sized sides as a a square and round the sizing up to be able to fit
# all tile squares inside of the original shape to be tested on
## Returns a square Rect2 that fully contains the input Rect2, rounding up to the largest dimension.
## Useful for fitting non-square shapes into square tiles or grids.
static func grow_rect2_to_square(p_rect : Rect2) -> Rect2:
	var abs_rect_size = abs(p_rect.size)
	var abs_larger_dimension = max(abs_rect_size.x, abs_rect_size.y) 
	var larger_dimension_size = Vector2(
		abs_larger_dimension * sign(p_rect.size.x),
		abs_larger_dimension * sign(p_rect.size.y)
	)
	return Rect2(p_rect.position, larger_dimension_size)

## Gets the direction difference between center to position and center to end
##
## Returns the difference vector with magnitude and direction of the 
## further point between position and end
## Returns the offset vector from the center to the position of a Rect2.
## Useful for calculating position differences or alignment offsets.
static func get_rect2_position_offset(p_rect : Rect2) -> Vector2:
	return -p_rect.size

## Returns all tile positions overlapped by a rectangle, with a small buffer (epsilon) to avoid counting adjacent tiles for exact fits.
## Useful for mapping which tiles are covered by a rectangular shape in a TileMapLayer.
static func get_overlapped_tiles_for_rect(rect_center: Vector2, rect_size: Vector2, tile_map: TileMapLayer, epsilon: float = 0.1) -> Array[Vector2i]:
	if tile_map == null or tile_map.tile_set == null:
		return []
	var tile_size: Vector2 = tile_map.tile_set.tile_size
	var half_size = rect_size / 2.0
	var left = rect_center.x - half_size.x + epsilon
	var right = rect_center.x + half_size.x - epsilon
	var top = rect_center.y - half_size.y + epsilon
	var bottom = rect_center.y + half_size.y - epsilon

	var left_tile = tile_map.local_to_map(tile_map.to_local(Vector2(left, rect_center.y)))
	var right_tile = tile_map.local_to_map(tile_map.to_local(Vector2(right, rect_center.y)))
	var top_tile = tile_map.local_to_map(tile_map.to_local(Vector2(rect_center.x, top)))
	var bottom_tile = tile_map.local_to_map(tile_map.to_local(Vector2(rect_center.x, bottom)))

	var tile_positions: Array[Vector2i] = []
	for x in range(left_tile.x, right_tile.x + 1):
		for y in range(top_tile.y, bottom_tile.y + 1):
			tile_positions.append(Vector2i(x, y))
	return tile_positions


## Returns all tile positions overlapped by a polygon (PackedVector2Array), using polygon clipping against each tile rect.
## Only counts tiles where the intersection area exceeds epsilon (default 0.01).
## Useful for strict mapping of which tiles are covered by a polygonal shape in a TileMapLayer.
## tile_type: TileSet.TileShape (required)
## epsilon: minimum intersection area to count as covered (default 0.01)
static func get_overlapped_tiles_for_polygon(
	polygon: PackedVector2Array,
	tile_map: TileMapLayer,
	tile_type: TileSet.TileShape,
	epsilon: float = 0.01
) -> Array[Vector2i]:
	var overlapped: Array[Vector2i] = []
	if polygon.size() < 3:
		return overlapped

	# Use tile_shape directly (no conversion needed)
	var tile_shape: TileSet.TileShape = tile_type

	# Get tile size
	var tile_size: Vector2 = tile_map.tile_set.tile_size

	# Compute bounding box of polygon to limit tile checks
	var aabb := Rect2(polygon[0], Vector2.ZERO)
	for i in range(1, polygon.size()):
		aabb = aabb.expand(polygon[i])

	# Map all AABB corners to grid and use min/max to build a robust scan range (handles isometric skew)
	var aabb_corners: Array[Vector2] = [
		aabb.position,
		Vector2(aabb.end.x, aabb.position.y),
		Vector2(aabb.position.x, aabb.end.y),
		aabb.end
	]
	var mapped: Array[Vector2i] = []
	for corner in aabb_corners:
		mapped.append(tile_map.local_to_map(corner))
	var min_x := mapped[0].x
	var max_x := mapped[0].x
	var min_y := mapped[0].y
	var max_y := mapped[0].y
	for cell in mapped:
		min_x = min(min_x, cell.x)
		max_x = max(max_x, cell.x)
		min_y = min(min_y, cell.y)
		max_y = max(max_y, cell.y)

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var cell := Vector2i(x, y)
			var cell_center := tile_map.map_to_local(cell)
			var cell_pos: Vector2
			if tile_type == TileSet.TILE_SHAPE_SQUARE:
				cell_pos = cell_center - Vector2(tile_size.x / 2.0, tile_size.y / 2.0)
			else:
				# For isometric tiles, use the top-left of the tile's AABB to match GBGeometryMath.get_tile_polygon expectations.
				cell_pos = cell_center - Vector2(tile_size.x / 2.0, tile_size.y / 2.0)
			if GBGeometryMath.does_polygon_overlap_tile(polygon, cell_pos, tile_size, tile_type, epsilon):
				overlapped.append(cell)
	return overlapped
	
## Checks if a tile is covered by a CollisionShape2D (using Geometry2D intersection)
## Returns true if a tile is covered by a CollisionShape2D, using intersection area (with epsilon threshold).
## Useful for strict collision checks between tiles and collision shapes.
## tile_type: TileSet.TileShape (required)
## epsilon: minimum intersection area to count as covered (default 0.01)
static func is_tile_covered_by_collision_shape(tile_pos: Vector2, tile_size: Vector2, collision_shape: CollisionShape2D, tile_type: TileSet.TileShape, epsilon: float = 0.01) -> bool:
	if collision_shape == null or collision_shape.shape == null:
		return false
	var shape_poly: PackedVector2Array
	if collision_shape.shape is RectangleShape2D:
		var rect: RectangleShape2D = collision_shape.shape
		var ext: Vector2 = rect.extents
		var shape_pos: Vector2 = collision_shape.global_position - ext
		shape_poly = PackedVector2Array([
			shape_pos,
			shape_pos + Vector2(ext.x * 2, 0),
			shape_pos + Vector2(ext.x * 2, ext.y * 2),
			shape_pos + Vector2(0, ext.y * 2)
		])
	elif collision_shape.shape is ConvexPolygonShape2D:
		shape_poly = PackedVector2Array(collision_shape.shape.points)
	else:
		return false
	return GBGeometryMath.does_polygon_overlap_tile(shape_poly, tile_pos, tile_size, int(tile_type), epsilon)

## Checks if a tile is covered by a CollisionPolygon2D (using Geometry2D intersection)
## Returns true if a tile is covered by a CollisionPolygon2D, using intersection area (with epsilon threshold).
## Useful for strict collision checks between tiles and collision polygons.
## tile_type: TileSet.TileShape (required)
## epsilon: minimum intersection area to count as covered (default 0.01)
static func is_tile_covered_by_collision_polygon(tile_pos: Vector2, tile_size: Vector2, collision_polygon: CollisionPolygon2D, tile_type: TileSet.TileShape, epsilon: float = 0.01) -> bool:
	if collision_polygon == null or collision_polygon.polygon.size() < 3:
		return false
	return GBGeometryMath.does_polygon_overlap_tile(collision_polygon.polygon, tile_pos, tile_size, tile_type, epsilon)
