## Geometry & collision math utilities for the grid building addon.
##
## Provides compact, well-documented helper functions used across the addon for
## tile/polygon overlap and collision tasks. Main responsibilities include:
## - Computing polygon vs polygon intersection areas (uses Godot Geometry2D).
## - Producing tile polygons for square and isometric tiles and testing polygon
##   overlaps against tiles (area-based and optimized native collision checks).
## - Converting various Shape2D types to polygon approximations for geometry
##   processing (Rectangle, Circle, Capsule, ConvexPolygon, fallback to rect).
## - Utility helpers: axis-aligned rectangle detection and polygon bounding rect.
##
## Note: TILE SHAPE ENFORCEMENT: All functions use TileSet.TileShape enum values.[br]
## Use: TileSet.TILE_SHAPE_SQUARE, TileSet.TILE_SHAPE_ISOMETRIC, TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE [br]
## Do NOT use: integers (0, 1, 2) or strings ("square", "isometric", etc.)
class_name GBGeometryMath

## Returns the intersection area between two polygons using Godot's Geometry2D.[br][br]
## [code]poly_a[/code]: [i]PackedVector2Array[/i] - First polygon.[br]
## [code]poly_b[/code]: [i]PackedVector2Array[/i] - Second polygon.[br][br]
## Returns: [b]float[/b] - Area of intersection (0.0 if no overlap).
static func polygon_intersection_area(poly_a: PackedVector2Array, poly_b: PackedVector2Array) -> float:
	# Defensive: If either polygon is degenerate, return 0
	if poly_a.size() < 3 or poly_b.size() < 3:
		return 0.0
	var intersection := Geometry2D.intersect_polygons(poly_a, poly_b)
	if intersection.size() == 0:
		return 0.0
	var area: float = 0.0
	for poly in intersection:
		if poly.size() >= 3:
			# Calculate polygon area using shoelace formula
			var poly_area: float = 0.0
			for i in range(poly.size()):
				var j = (i + 1) % poly.size()
				poly_area += poly[i].x * poly[j].y
				poly_area -= poly[j].x * poly[i].y
			area += abs(poly_area) * 0.5
	return area

## Returns the corners of a tile as a polygon for collision or geometry checks.[br][br]
## [code]tile_top_left_pos[/code]: [i]Vector2[/i] - [b]Top-left position[/b] of the tile in world space.[br]
## [code]tile_size[/code]: [i]Vector2[/i] - Size of the tile (width, height).[br]
## [code]tile_shape[/code]: [i]TileSet.TileShape[/i] - Tile shape from TileSet (SQUARE, ISOMETRIC, HALF_OFFSET_SQUARE).[br][br]
## Returns: [b]PackedVector2Array[/b] - Polygon corners in counterclockwise order.
static func get_tile_polygon(tile_top_left_pos: Vector2, tile_size: Vector2, tile_shape: TileSet.TileShape) -> PackedVector2Array:
	match tile_shape:
		TileSet.TILE_SHAPE_ISOMETRIC:
			# Isometric diamond corners (counterclockwise)
			var half_w = tile_size.x / 2.0
			var half_h = tile_size.y / 2.0
			return PackedVector2Array([
				tile_top_left_pos + Vector2(half_w, 0),          # Top
				tile_top_left_pos + Vector2(tile_size.x, half_h), # Right
				tile_top_left_pos + Vector2(half_w, tile_size.y), # Bottom
				tile_top_left_pos + Vector2(0, half_h)           # Left
			])
		TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE:
			# Half-offset square is still a square shape, just positioned differently
			# The actual offset is handled by the tilemap positioning, not the polygon shape
			return PackedVector2Array([
				tile_top_left_pos,
				tile_top_left_pos + Vector2(tile_size.x, 0),
				tile_top_left_pos + Vector2(tile_size.x, tile_size.y),
				tile_top_left_pos + Vector2(0, tile_size.y)
			])
		_: # TileSet.TILE_SHAPE_SQUARE (default) or any other tile shape
			# Square corners (counterclockwise)
			return PackedVector2Array([
				tile_top_left_pos,
				tile_top_left_pos + Vector2(tile_size.x, 0),
				tile_top_left_pos + Vector2(tile_size.x, tile_size.y),
				tile_top_left_pos + Vector2(0, tile_size.y)
			])

## Returns the intersection area between a polygon and a tile polygon.[br][br]
## [code]polygon[/code]: [i]PackedVector2Array[/i] - The polygon to check.[br]
## [code]tile_top_left_pos[/code]: [i]Vector2[/i] - [b]Top-left position[/b] of the tile in world space (not center).[br]
## [code]tile_size[/code]: [i]Vector2[/i] - Size of the tile (width, height).[br]
## [code]tile_shape[/code]: [i]TileSet.TileShape[/i] - Tile shape from TileSet (SQUARE, ISOMETRIC, etc.).[br][br]
## Returns: [b]float[/b] - Area of intersection (0.0 if no overlap).
static func intersection_area_with_tile(polygon: PackedVector2Array, tile_top_left_pos: Vector2, tile_size: Vector2, tile_shape: TileSet.TileShape) -> float:
	var tile_poly := get_tile_polygon(tile_top_left_pos, tile_size, tile_shape)
	var area := polygon_intersection_area(polygon, tile_poly)
	return area

## Returns true if the intersection area between a polygon and a tile polygon exceeds epsilon.[br][br]
## [code]polygon[/code]: [i]PackedVector2Array[/i] - The polygon to check.[br]
## [code]tile_top_left_pos[/code]: [i]Vector2[/i] - [b]Top-left position[/b] of the tile in world space (not center).[br]
## [code]tile_size[/code]: [i]Vector2[/i] - Size of the tile (width, height).[br]
## [code]tile_shape[/code]: [i]TileSet.TileShape[/i] - Tile shape from TileSet (SQUARE, ISOMETRIC, etc.).[br]
## [code]epsilon[/code]: [i]float[/i] - Minimum intersection area to count as covered.[br][br]
## Returns: [b]bool[/b] - True if intersection area > epsilon.
static func does_polygon_overlap_tile(polygon: PackedVector2Array, tile_top_left_pos: Vector2, tile_size: Vector2, tile_shape: TileSet.TileShape, epsilon: float) -> bool:
	var area := intersection_area_with_tile(polygon, tile_top_left_pos, tile_size, tile_shape)
	return area > epsilon

## Optimized collision detection using native Godot collision as primary method.[br][br]
## [code]shape[/code]: [i]Shape2D[/i] - The collision shape to test.[br]
## [code]shape_transform[/code]: [i]Transform2D[/i] - Transform of the shape.[br]
## [code]tile_top_left_pos[/code]: [i]Vector2[/i] - [b]Top-left position[/b] of the tile in world space (not center).[br]
## [code]tile_size[/code]: [i]Vector2[/i] - Size of the tile.[br]
## [code]tile_shape[/code]: [i]TileSet.TileShape[/i] - Tile shape from TileSet (SQUARE, ISOMETRIC, HALF_OFFSET_SQUARE).[br]
## [code]epsilon[/code]: [i]float[/i] - Minimum overlap area (only used for polygon fallback).[br][br]
## Returns: [b]bool[/b] - True if shape overlaps the tile.
static func does_shape_overlap_tile_optimized(shape: Shape2D, shape_transform: Transform2D, tile_top_left_pos: Vector2, tile_size: Vector2, tile_shape: TileSet.TileShape, epsilon: float = 0.01) -> bool:
	# For square and half-offset square tiles, use fast native collision detection
	if tile_shape == TileSet.TILE_SHAPE_SQUARE or tile_shape == TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE:
		var tile_rect_shape: RectangleShape2D = RectangleShape2D.new()
		tile_rect_shape.size = tile_size
		var tile_transform = Transform2D(0, tile_top_left_pos + tile_size * 0.5)  # Center the tile
		
		# Use native collision detection - much faster than polygon conversion
		return shape.collide(shape_transform, tile_rect_shape, tile_transform)
	
	# For isometric tiles, convert shape to polygon and use polygon intersection
	var shape_polygon = convert_shape_to_polygon(shape, shape_transform)
	return does_polygon_overlap_tile(shape_polygon, tile_top_left_pos, tile_size, tile_shape, epsilon)

## Optimized polygon overlap detection - uses native collision when possible.[br][br]
## [code]polygon[/code]: [i]PackedVector2Array[/i] - The polygon points to test.[br]
## [code]tile_top_left_pos[/code]: [i]Vector2[/i] - [b]Top-left position[/b] of the tile in world space (not center).[br]
## [code]tile_size[/code]: [i]Vector2[/i] - Size of the tile.[br]
## [code]tile_shape[/code]: [i]TileSet.TileShape[/i] - Tile shape from TileSet (SQUARE, ISOMETRIC, HALF_OFFSET_SQUARE).[br]
## [code]epsilon[/code]: [i]float[/i] - Minimum intersection area threshold.[br][br]
## Returns: [b]bool[/b] - True if polygon overlaps the tile significantly.
static func does_polygon_overlap_tile_optimized(polygon: PackedVector2Array, tile_top_left_pos: Vector2, tile_size: Vector2, tile_shape: TileSet.TileShape, epsilon: float = 0.01) -> bool:
	if polygon.size() < 3:
		return false
	
	# For simple rectangles and square/half-offset tiles, convert to RectangleShape2D and use native collision
	if polygon.size() == 4 and _is_axis_aligned_rectangle(polygon) and (tile_shape == TileSet.TILE_SHAPE_SQUARE or tile_shape == TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE):
		var bounds = get_polygon_bounds(polygon)
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = bounds.size
		var rect_transform = Transform2D(0, bounds.position + bounds.size * 0.5)
		return does_shape_overlap_tile_optimized(rect_shape, rect_transform, tile_top_left_pos, tile_size, tile_shape, epsilon)
	
	# Fall back to polygon intersection for complex shapes or isometric tiles
	return does_polygon_overlap_tile(polygon, tile_top_left_pos, tile_size, tile_shape, epsilon)

## Returns true if the polygon is an axis-aligned rectangle (all edges horizontal or vertical).[br][br]
## [code]polygon[/code]: [i]PackedVector2Array[/i] - Polygon to check.[br][br]
## Returns: [b]bool[/b] - True if axis-aligned rectangle.
static func _is_axis_aligned_rectangle(polygon: PackedVector2Array) -> bool:
	if polygon.size() != 4:
		return false
	
	# Check if all edges are horizontal or vertical
	for i in range(4):
		var p1 = polygon[i]
		var p2 = polygon[(i + 1) % 4]
		var diff = p2 - p1
		# Edge must be purely horizontal or vertical
		if not (abs(diff.x) < 0.001 or abs(diff.y) < 0.001):
			return false
	
	return true

## Returns the bounding rectangle of a polygon.[br][br]
## [code]polygon[/code]: [i]PackedVector2Array[/i] - The polygon points.[br][br]
## Returns: [b]Rect2[/b] - Bounding rectangle of the polygon.
static func get_polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	if polygon.size() == 0:
		return Rect2()
	
	var min_pos = polygon[0]
	var max_pos = polygon[0]
	
	for point in polygon:
		min_pos.x = min(min_pos.x, point.x)
		min_pos.y = min(min_pos.y, point.y)
		max_pos.x = max(max_pos.x, point.x)
		max_pos.y = max(max_pos.y, point.y)
	
	return Rect2(min_pos, max_pos - min_pos)

## Converts a Shape2D to a polygon for consistent processing.[br][br]
## [code]shape[/code]: [i]Shape2D[/i] - The shape to convert.[br]
## [code]transform[/code]: [i]Transform2D[/i] - Transform to apply to the shape.[br][br]
## Returns: [b]PackedVector2Array[/b] - Polygon representation of the shape.
static func convert_shape_to_polygon(shape: Shape2D, transform: Transform2D) -> PackedVector2Array:
	var polygon: PackedVector2Array = PackedVector2Array()
	
	if shape is RectangleShape2D:
		var rect_shape = shape as RectangleShape2D
		var size = rect_shape.size
		polygon = PackedVector2Array([
			transform * Vector2(-size.x/2, -size.y/2),
			transform * Vector2(size.x/2, -size.y/2),
			transform * Vector2(size.x/2, size.y/2),
			transform * Vector2(-size.x/2, size.y/2)
		])
	elif shape is CircleShape2D:
		var circle_shape = shape as CircleShape2D
		var radius = circle_shape.radius
		var segments = 16  # Approximate circle with 16 segments
		for i in range(segments):
			var angle = i * 2.0 * PI / segments
			var point = Vector2(cos(angle) * radius, sin(angle) * radius)
			polygon.append(transform * point)
	elif shape is CapsuleShape2D:
		var capsule_shape = shape as CapsuleShape2D
		var radius = capsule_shape.radius
		var height = capsule_shape.height
		var segments = 24  # Higher segments for smoother semicircles (12 per half)
		
		# In Godot 4, CapsuleShape2D's height property represents the full height of the shape.
		# The shape extends from -height/2 to +height/2 in the Y axis.
		# Based on empirical testing with get_rect():
		# - For height=40, radius=10: extends from -20 to +20
		# - For height=22, radius=7: extends from -11 to +11
		# - For height=128, radius=48: extends from -64 to +64
		# This confirms the shape extends from -height/2 to +height/2
		
		var half_height = height / 2.0
		
		# The circle centers are positioned such that the capsule extends to ±half_height
		# For a capsule to extend from -height/2 to +height/2:
		# - Top circle center is at y = -(half_height - radius) 
		# - Bottom circle center is at y = +(half_height - radius)
		# The top of the top circle is at center - radius = -(half_height - radius) - radius = -half_height
		# The bottom of the bottom circle is at center + radius = (half_height - radius) + radius = half_height
		var top_center_y = -(half_height - radius)
		var bottom_center_y = half_height - radius
		
		# Top semicircle (from left to right)
		# For the top half-circle, we want points from angle PI (left) through PI/2 (top) to 0 (right)
		# sin(PI) = 0 (at horizontal), sin(PI/2) = 1 (at top), sin(0) = 0 (at horizontal)
		# Since sin goes positive, we need to negate it to go upward from the center
		for i in range(segments/2 + 1):
			var angle = PI - (i * PI / (segments/2))  # From PI to 0
			var point = Vector2(cos(angle) * radius, -sin(angle) * radius + top_center_y)
			polygon.append(transform * point)
		
		# Bottom semicircle (from right to left to maintain counterclockwise order)
		# For the bottom half-circle, positive sin values should go downward from center
		for i in range(1, segments/2 + 1):  # Skip first point to avoid duplication
			var angle = (i * PI / (segments/2))  # From 0 to PI
			var point = Vector2(cos(angle) * radius, sin(angle) * radius + bottom_center_y)
			polygon.append(transform * point)
	elif shape is ConvexPolygonShape2D:
		var convex_shape = shape as ConvexPolygonShape2D
		for point in convex_shape.points:
			polygon.append(transform * point)
	else:
		# Fallback: try to get a bounding rectangle
		var rect = shape.get_rect()
		polygon = PackedVector2Array([
			transform * rect.position,
			transform * Vector2(rect.position.x + rect.size.x, rect.position.y),
			transform * (rect.position + rect.size),
			transform * Vector2(rect.position.x, rect.position.y + rect.size.y)
		])
	
	return polygon


#region Helpers
## Calculates the area of a polygon defined by a PackedVector2Array.
## Used to determine the area of intersection between two polygons (e.g., tile and collision shape).
## Returns 0.0 if the input does not form a valid polygon (fewer than 3 points).
## This is used in overlap checks to ensure that only true area overlaps (not just edge or point contacts) are counted.
static func intersection_polygon_area(points: PackedVector2Array) -> float:
	var area: float = 0.0
	var n := points.size()
	if n < 3:
		return 0.0
	for i in range(n):
		var j := (i + 1) % n
		area += points[i].x * points[j].y
		area -= points[j].x * points[i].y
	return abs(area) * 0.5

## Checks if two polygons are exactly the same (vertex by vertex)
static func is_exact_polygon_match(poly_a: PackedVector2Array, poly_b: PackedVector2Array) -> bool:
	if poly_a.size() != poly_b.size():
		return false
	for i in range(poly_a.size()):
		if poly_a[i] != poly_b[i]:
			return false
	return true

## Returns area for exact polygon match
static func exact_polygon_area(poly: PackedVector2Array) -> float:
	return intersection_polygon_area(poly)


## Fallback for isometric tiles, checks for floating-point vertex proximity
static func isometric_floating_point_fallback(
	tile_poly: PackedVector2Array, polygon: PackedVector2Array
) -> float:
	if tile_poly.size() != polygon.size():
		return 0.0
	var close := true
	for i in range(tile_poly.size()):
		if not tile_poly[i].is_equal_approx(polygon[i]):
			close = false
			break
	if close:
		return intersection_polygon_area(tile_poly)
	return 0.0


## Fallback for square tiles, uses bounding box intersection
static func square_bounding_box_fallback(
	tile_poly: PackedVector2Array, polygon: PackedVector2Array
) -> float:
	if tile_poly.size() != 4 or polygon.size() != 4:
		return 0.0
	var min_tile = tile_poly[0]
	var max_tile = tile_poly[0]
	for pt in tile_poly:
		min_tile.x = min(min_tile.x, pt.x)
		min_tile.y = min(min_tile.y, pt.y)
		max_tile.x = max(max_tile.x, pt.x)
		max_tile.y = max(max_tile.y, pt.y)
	var tile_rect = Rect2(min_tile, max_tile - min_tile)
	var min_poly = polygon[0]
	var max_poly = polygon[0]
	for pt in polygon:
		min_poly.x = min(min_poly.x, pt.x)
		min_poly.y = min(min_poly.y, pt.y)
		max_poly.x = max(max_poly.x, pt.x)
		max_poly.y = max(max_poly.y, pt.y)
	var poly_rect = Rect2(min_poly, max_poly - min_poly)
	var intersection_rect = tile_rect.intersection(poly_rect)
	if intersection_rect != null:
		var intersection_area = intersection_rect.size.x * intersection_rect.size.y
		if intersection_area > 0.01:
			var overlap_x = (
				min(
					tile_rect.position.x + tile_rect.size.x, poly_rect.position.x + poly_rect.size.x
				)
				- max(tile_rect.position.x, poly_rect.position.x)
			)
			var overlap_y = (
				min(
					tile_rect.position.y + tile_rect.size.y, poly_rect.position.y + poly_rect.size.y
				)
				- max(tile_rect.position.y, poly_rect.position.y)
			)
			if overlap_x > 0.01 and overlap_y > 0.01:
				return intersection_area
	return 0.0
#endregion