## Pure logic class for collision geometry calculations.
## Contains no state and can be easily tested in isolation.
##
## POLYGON CLIPPING ALGORITHM - SUTHERLAND-HODGMAN
## ===============================================
## This class implements the Sutherland-Hodgman polygon clipping algorithm for determining
## polygon-rectangle overlap areas. The algorithm is correct for both convex and concave polygons.
##
## Algorithm Overview:
## 1. The polygon is clipped against each of the 4 rectangle boundaries (left, right, top, bottom)
## 2. Each clipping operation produces a new polygon that is guaranteed to be inside that boundary
## 3. The final clipped polygon represents the intersection area between the original polygon and rectangle
## 4. The area of this clipped polygon determines if the overlap meets the minimum threshold
##
## Why Sutherland-Hodgman is Correct:
## - Works for both convex and concave polygons (unlike some simpler algorithms)
## - Produces a valid polygon as output (no self-intersections or invalid geometry)
## - Handles edge cases like polygons completely inside/outside the rectangle
## - Deterministic and numerically stable with proper epsilon handling
##
## Default Overlap Thresholds:
## - Edge epsilon: 0.01 (1% tolerance for numerical precision)
## - Minimum overlap ratio: 0.05 (5% of tile area required for detection)
## - Polygons with < 5% tile overlap are considered non-overlapping (prevents spurious micro-overlaps)
##
## Key Methods:
## - clip_polygon_to_rect(): Implements the core Sutherland-Hodgman algorithm
## - polygon_overlaps_rect(): Uses clipping to determine if overlap meets threshold
## - polygon_area(): Calculates area using shoelace formula for overlap measurement
##
## Testing: All clipping methods are public for comprehensive unit testing validation.
class_name CollisionGeometryCalculator
extends RefCounted

# Toggle verbose polygon overlap debug logging. Set to `true` to enable detailed per-tile output.
# NOTE: This is a temporary diagnostic toggle. Tests may enable this at runtime; therefore we
# expose it as a mutable static variable (default `false`) so test runners can turn it on
# only for targeted unit/integration runs. Debug prints remain gated to near-threshold cases.
static var debug_polygon_overlap: bool = false

# AREA_REL_EPS = "Area Relative Epsilon" (EPS = Epsilon, a small tolerance value)
# This is a PERCENTAGE of the tile's area that we allow as tolerance for numerical errors.
# When clipping a rotated/skewed polygon against a rectangular tile, tiny floating-point
# errors and vertex sanitization can reduce the computed overlap area slightly below
# the required threshold, causing valid overlaps to be missed.
# 
# Formula: relative_tolerance = tile_area * AREA_REL_EPS
# Example: For a 32×32 tile (1024 area), AREA_REL_EPS=0.01 gives 10.24 square units tolerance
# This means if the computed overlap is 51.2 - 10.24 = 40.96, we still consider it valid
# when the minimum required overlap is 51.2 (5% of tile area).
const AREA_REL_EPS: float = 0.01  # 1% of tile area as relative tolerance

# AREA_ABS_EPS = "Area Absolute Epsilon" (EPS = Epsilon, a small tolerance value) 
# This is a FIXED number of square units we allow as tolerance, regardless of tile size.
# This helps with very thin slivers that might lose just a few square units during
# polygon clipping and sanitization, especially at steep rotation angles (45°, 60°).
#
# Combined tolerance = (tile_area * AREA_REL_EPS) + AREA_ABS_EPS
# Example: 32×32 tile gets (1024 * 0.01) + 1.0 = 11.24 total tolerance
# This catches cases where sanitization removes a tiny triangle worth ~1-2 square units.
const AREA_ABS_EPS: float = 1.0   # 1.0 square units as absolute tolerance

## Pure function for tile overlap calculation
## Returns array of tile coordinates that overlap with the given polygon
## 
## IMPORTANT: For isometric tiles, this function requires a TileMapLayer reference
## to properly handle coordinate transformations. When tile_type is ISOMETRIC,
## the tile_map_layer parameter must be provided for accurate calculations.
static func calculate_tile_overlap(
	polygon: PackedVector2Array,
	tile_size: Vector2,
	tile_type: TileSet.TileShape,
	tile_map_layer: TileMapLayer,
	epsilon: float = 0.01,
	min_overlap_ratio: float = 0.05
) -> Array[Vector2i]:
	# Adapter: prefer map-aware path when tile_map_layer provided
	if polygon.is_empty():
		return []

	if tile_map_layer != null:
		# When tile_map_layer is provided prefer map-aware calculation (works for both square & iso)
		if tile_type == TileSet.TILE_SHAPE_ISOMETRIC:
			return _calculate_isometric_tile_overlap(polygon, tile_map_layer, epsilon, min_overlap_ratio)
		return _calculate_square_tile_overlap(polygon, tile_size, epsilon, min_overlap_ratio, tile_map_layer)

	# Fallback: call numeric-only implementation (no TileMapLayer available)
	return calculate_tile_overlap_numeric(polygon, tile_size, tile_type, epsilon, min_overlap_ratio)


## New pure-numeric API: calculates tile overlap without needing a TileMapLayer.
## This accepts numeric tile coordinates and is useful for unit-testing numeric math and for
## consumers that already manage map transforms externally.
static func calculate_tile_overlap_numeric(
	polygon: PackedVector2Array,
	tile_size: Vector2,
	tile_type: TileSet.TileShape,
	epsilon: float = 0.01,
	min_overlap_ratio: float = 0.05
) -> Array[Vector2i]:
	var overlapped_tiles: Array[Vector2i] = []
	if polygon.is_empty():
		return overlapped_tiles

	if tile_type == TileSet.TILE_SHAPE_ISOMETRIC:
		# Numeric isometric fallback is not supported without a TileMapLayer; return empty to be safe
		return overlapped_tiles

	# Square tiles - legacy numeric algorithm: iterate over world-space bounds divided by tile_size
	var bounds = _get_polygon_bounds(polygon)
	var start_tile = Vector2i(floor(bounds.position.x / tile_size.x), floor(bounds.position.y / tile_size.y))
	var end_tile = Vector2i(ceil((bounds.position.x + bounds.size.x) / tile_size.x), ceil((bounds.position.y + bounds.size.y) / tile_size.y))

	for x in range(start_tile.x, end_tile.x):
		for y in range(start_tile.y, end_tile.y):
			var tile_pos = Vector2i(x, y)
			var tile_world_center = Vector2(tile_pos.x * tile_size.x + tile_size.x * 0.5, tile_pos.y * tile_size.y + tile_size.y * 0.5)
			var tile_rect = Rect2(tile_world_center - tile_size * 0.5, tile_size)
			if polygon_overlaps_rect(polygon, tile_rect, epsilon, min_overlap_ratio):
				overlapped_tiles.append(tile_pos)

	return overlapped_tiles

## Calculate tile overlap for square tiles using the original algorithm
static func _calculate_square_tile_overlap(
	polygon: PackedVector2Array,
	tile_size: Vector2,
	epsilon: float,
	min_overlap_ratio: float,
	tile_map_layer: TileMapLayer
) -> Array[Vector2i]:
	var overlapped_tiles: Array[Vector2i] = []
	
	# Calculate bounding box of polygon
	var bounds = _get_polygon_bounds(polygon)
    
	# Use the TileMapLayer to compute an iteration range that respects map transforms
	var range: Dictionary = CollisionGeometryUtils.compute_tile_iteration_range(bounds, tile_map_layer)
	var start_tile: Vector2i = Vector2i()
	var end_exclusive: Vector2i = Vector2i()
	if range.size() == 0:
		# Fallback to legacy calculation if compute_tile_iteration_range fails
		start_tile = Vector2i(floor(bounds.position.x / tile_size.x), floor(bounds.position.y / tile_size.y))
		var end_tile = Vector2i(ceil((bounds.position.x + bounds.size.x) / tile_size.x), ceil((bounds.position.y + bounds.size.y) / tile_size.y))
		end_exclusive = end_tile
	else:
		start_tile = range["start"]
		end_exclusive = range["end_exclusive"]

	# Check each tile for overlap using map-based world rects
	for x in range(start_tile.x, end_exclusive.x):
		for y in range(start_tile.y, end_exclusive.y):
			var tile_pos = Vector2i(x, y)
			var tile_world_center = tile_map_layer.to_global(tile_map_layer.map_to_local(tile_pos))
			var tile_size_vec: Vector2 = Vector2(tile_map_layer.tile_set.tile_size) if tile_map_layer.tile_set else tile_size
			var tile_rect = Rect2(tile_world_center - tile_size_vec * 0.5, tile_size_vec)

			if polygon_overlaps_rect(polygon, tile_rect, epsilon, min_overlap_ratio):
				overlapped_tiles.append(tile_pos)
	
	return overlapped_tiles

## Calculate tile overlap for isometric tiles using TileMapLayer coordinate transformations
static func _calculate_isometric_tile_overlap(
	polygon: PackedVector2Array,
	tile_map_layer: TileMapLayer,
	epsilon: float,
	min_overlap_ratio: float
) -> Array[Vector2i]:
	var overlapped_tiles: Array[Vector2i] = []
	
	# Get polygon bounds in world space
	var bounds = _get_polygon_bounds(polygon)
	
	# Convert world bounds to tile coordinates using TileMapLayer's isometric transformation
	var top_left_world = bounds.position
	var bottom_right_world = bounds.position + bounds.size
	var top_right_world = Vector2(bottom_right_world.x, top_left_world.y)
	var bottom_left_world = Vector2(top_left_world.x, bottom_right_world.y)
	
	# Convert all corners to tile coordinates to get proper tile range
	var corners_tile = [
		tile_map_layer.local_to_map(tile_map_layer.to_local(top_left_world)),
		tile_map_layer.local_to_map(tile_map_layer.to_local(top_right_world)),
		tile_map_layer.local_to_map(tile_map_layer.to_local(bottom_left_world)),
		tile_map_layer.local_to_map(tile_map_layer.to_local(bottom_right_world))
	]
	
	# Find the tile bounding box
	var min_tile_x = corners_tile[0].x
	var max_tile_x = corners_tile[0].x
	var min_tile_y = corners_tile[0].y
	var max_tile_y = corners_tile[0].y
	
	for corner in corners_tile:
		min_tile_x = min(min_tile_x, corner.x)
		max_tile_x = max(max_tile_x, corner.x)
		min_tile_y = min(min_tile_y, corner.y)
		max_tile_y = max(max_tile_y, corner.y)
	
	# No padding - rely on precise polygon overlap detection with min_overlap_ratio
	# Previous padding of 1 tile caused false positives for single-tile diamond buildings
	# The polygon_overlaps_rect() function with 5% overlap threshold provides sufficient
	# edge-case handling without requiring padding that expands single tiles to 3x3 grids
	
	# Check each tile in the range
	for x in range(min_tile_x, max_tile_x + 1):
		for y in range(min_tile_y, max_tile_y + 1):
			var tile_pos = Vector2i(x, y)
			
			# Convert tile position back to world space to get the tile's world bounds
			var tile_world_center = tile_map_layer.to_global(tile_map_layer.map_to_local(tile_pos))
			var tile_size = Vector2(tile_map_layer.tile_set.tile_size) if tile_map_layer.tile_set else Vector2(16, 16)
			
			# For isometric tiles, create a diamond-shaped polygon for accurate overlap detection
			# Diamond vertices: top, right, bottom, left (in world space)
			var half_width = tile_size.x * 0.5
			var half_height = tile_size.y * 0.5
			var tile_diamond = PackedVector2Array([
				tile_world_center + Vector2(0, -half_height),      # Top
				tile_world_center + Vector2(half_width, 0),        # Right
				tile_world_center + Vector2(0, half_height),       # Bottom
				tile_world_center + Vector2(-half_width, 0)        # Left
			])
			
			# Check polygon-to-polygon overlap using Sutherland-Hodgman clipping
			if polygons_overlap(polygon, tile_diamond, min_overlap_ratio, tile_size.x * tile_size.y):
				overlapped_tiles.append(tile_pos)
	
	return overlapped_tiles

## Pure function for collision detection between two polygons
static func detect_collisions(
	shape1: PackedVector2Array, 
	shape2: PackedVector2Array, 
	epsilon: float = 0.01
) -> bool:
	if shape1.is_empty() or shape2.is_empty():
		return false
	
	# Check if bounding boxes overlap first (quick rejection)
	var bounds1 = _get_polygon_bounds(shape1)
	var bounds2 = _get_polygon_bounds(shape2)
	
	if not bounds1.intersects(bounds2, true):
		return false
	
	# Check for actual polygon intersection
	return _polygons_intersect(shape1, shape2, epsilon)

## Pure function to get polygon bounds
static func _get_polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty():
		return Rect2()
	
	var min_x = polygon[0].x
	var min_y = polygon[0].y
	var max_x = polygon[0].x
	var max_y = polygon[0].y
	
	for point in polygon:
		min_x = min(min_x, point.x)
		min_y = min(min_y, point.y)
		max_x = max(max_x, point.x)
		max_y = max(max_y, point.y)
	
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)

## Pure function to check if polygon overlaps with rectangle - PUBLIC for testing
## Clip a polygon against a single edge defined by two points
## Used for general polygon-to-polygon clipping
static func _clip_polygon_to_edge(polygon: PackedVector2Array, edge_start: Vector2, edge_end: Vector2) -> PackedVector2Array:
	if polygon.size() < 3:
		return PackedVector2Array()
	
	var output: PackedVector2Array = PackedVector2Array()
	var edge_vec = edge_end - edge_start
	var edge_normal = Vector2(-edge_vec.y, edge_vec.x).normalized()  # Left-hand normal
	
	var prev = polygon[polygon.size() - 1]
	var prev_inside = (prev - edge_start).dot(edge_normal) >= -0.0001
	
	for curr in polygon:
		var curr_inside = (curr - edge_start).dot(edge_normal) >= -0.0001
		
		if curr_inside:
			if not prev_inside:
				# Entering: add intersection point
				var intersection = _line_intersection(prev, curr, edge_start, edge_end)
				if intersection != Vector2.INF:
					output.append(intersection)
			output.append(curr)
		elif prev_inside:
			# Leaving: add intersection point
			var intersection = _line_intersection(prev, curr, edge_start, edge_end)
			if intersection != Vector2.INF:
				output.append(intersection)
		
		prev = curr
		prev_inside = curr_inside
	
	return output

## Calculate intersection point of two line segments
## Returns Vector2.INF if lines don't intersect
static func _line_intersection(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> Vector2:
	var denominator = (p4.y - p3.y) * (p2.x - p1.x) - (p4.x - p3.x) * (p2.y - p1.y)
	if abs(denominator) < 0.0001:
		return Vector2.INF  # Parallel lines
	
	var ua = ((p4.x - p3.x) * (p1.y - p3.y) - (p4.y - p3.y) * (p1.x - p3.x)) / denominator
	var intersection = p1 + ua * (p2 - p1)
	return intersection

## Check if two arbitrary polygons overlap with a minimum overlap ratio
## Uses Sutherland-Hodgman clipping to compute precise overlap area
static func polygons_overlap(poly1: PackedVector2Array, poly2: PackedVector2Array, min_overlap_ratio: float, reference_area: float) -> bool:
	if poly1.size() < 3 or poly2.size() < 3:
		return false
	
	# Use Sutherland-Hodgman to clip poly1 against poly2
	var clipped = poly1
	for i in range(poly2.size()):
		var edge_start = poly2[i]
		var edge_end = poly2[(i + 1) % poly2.size()]
		clipped = _clip_polygon_to_edge(clipped, edge_start, edge_end)
		if clipped.size() < 3:
			return false
	
	# Sanitize and calculate area
	clipped = _sanitize_polygon(clipped)
	if clipped.size() < 3:
		return false
	
	var overlap_area = polygon_area(clipped)
	var min_area = reference_area * clamp(min_overlap_ratio, 0.0, 1.0)
	
	# Apply epsilon tolerance for small overlaps
	var area_eps: float = 0.0
	if min_overlap_ratio <= 0.05:
		area_eps = reference_area * AREA_REL_EPS + AREA_ABS_EPS
	var adjusted_min_area = max(0.0, min_area - area_eps)
	
	return overlap_area >= adjusted_min_area

## This is a critical method that determines which tiles are considered "covered" by a polygon
##
## Algorithm: Uses Sutherland-Hodgman polygon clipping to compute precise overlap area
## 1. Fast reject via bounding box intersection test
## 2. Clip polygon to rectangle using Sutherland-Hodgman algorithm
## 3. Calculate area of clipped polygon using shoelace formula
## 4. Compare to minimum overlap threshold (min_overlap_ratio * rectangle_area)
##
## The Sutherland-Hodgman algorithm correctly handles both convex and concave polygons,
## producing accurate overlap areas for all polygon shapes.
static func polygon_overlaps_rect(polygon: PackedVector2Array, rect: Rect2, epsilon: float, min_overlap_ratio: float) -> bool:
	# Fast reject via bounds test
	var poly_bounds = _get_polygon_bounds(polygon)
	if not poly_bounds.intersects(rect, true):
		return false

	# Compute precise overlap area using Sutherland–Hodgman clipping against the axis-aligned rect
	var clipped := clip_polygon_to_rect(polygon, rect)
	# Sanitize clipped polygon: remove duplicate consecutive points and collinear points
	clipped = _sanitize_polygon(clipped)
	if clipped.size() < 3:
		return false
	var area := polygon_area(clipped)
	var rect_area := rect.size.x * rect.size.y
	var min_area: float = rect_area * clamp(min_overlap_ratio, 0.0, 1.0)

	# Allow a combined relative+absolute epsilon below the min_area to tolerate
	# clipping/sanitize induced rounding differences on very small slivers. To
	# avoid weakening stricter thresholds (e.g. 15%+), only apply the epsilon
	# for the default/low thresholds (<= 5%). For higher caller-specified
	# thresholds we keep strict comparison.
	var area_eps: float = 0.0
	if min_overlap_ratio <= 0.05:
		area_eps = rect_area * AREA_REL_EPS + AREA_ABS_EPS
	var adjusted_min_area: float = max(0.0, min_area - area_eps)

	# TEMP DEBUG: log clipping details for diagnosing concave polygon indicator failures
	# We only print when both debug_polygon_overlap is enabled and the clipped area is near
	# the configured min_area (within a small multiple of area_eps). This keeps output
	# focused on borderline cases (rotated/skewed slivers) while avoiding noise.
	var debug_near_threshold := false
	if area_eps > 0.0:
		debug_near_threshold = abs(area - min_area) <= (area_eps * 2.0)
	var debug_condition := debug_polygon_overlap and debug_near_threshold
	if debug_condition:
		print("[DBG] polygon_overlaps_rect: rect=", rect, " poly_bounds=", poly_bounds, " clipped_size=", clipped.size(), " clipped=", clipped, " area=", area, " min_area=", min_area, " area_eps=", area_eps, " adjusted_min_area=", adjusted_min_area)
	var result := area >= adjusted_min_area
	if debug_condition:
		print("[DBG] polygon_overlaps_rect result=", result)
	return result


## Remove duplicate consecutive points and collinear middle points from polygon
static func _sanitize_polygon(polygon: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var n := polygon.size()
	if n == 0:
		return out

	# Remove consecutive duplicates (within small epsilon)
	var eps := 0.0001
	var last: Vector2 = polygon[0]
	out.append(last)
	for i in range(1, n):
		var p: Vector2 = polygon[i]
		if (p - last).length() > eps:
			out.append(p)
			last = p

	# If after removing duplicates we have less than 3 points, return empty
	if out.size() < 3:
		return PackedVector2Array()

	# Remove collinear middle points
	var cleaned: PackedVector2Array = PackedVector2Array()
	var m := out.size()
	for i in range(m):
		var a := out[(i - 1 + m) % m]
		var b := out[i]
		var c := out[(i + 1) % m]
		var cross := (b - a).cross(c - b)
		if abs(cross) > eps:
			cleaned.append(b)

	return cleaned

## Clips a polygon to an axis-aligned rectangle (inclusive). Returns resulting polygon points.
## PUBLIC for testing - this is the core clipping algorithm that needs validation for concave polygons
##
## Implements the Sutherland-Hodgman polygon clipping algorithm:
## - Iteratively clips the polygon against each of the 4 rectangle boundaries
## - Each boundary clip produces a new polygon guaranteed to be inside that boundary
## - The final result is the intersection of the polygon with the rectangle
## - Works correctly for both convex and concave input polygons
##
## Algorithm steps for each boundary:
## 1. Start with previous vertex (last vertex for first iteration)
## 2. For each current vertex in the polygon:
##    - If current vertex is inside boundary: add intersection point (if previous was outside), then add current vertex
##    - If current vertex is outside boundary: add intersection point (if previous was inside)
## 3. Repeat for all 4 boundaries (left, right, top, bottom)
##
## The algorithm maintains polygon validity and handles edge cases properly.
static func clip_polygon_to_rect(polygon: PackedVector2Array, rect: Rect2) -> PackedVector2Array:
	var output := polygon
	if output.is_empty():
		return output
	# Boundaries
	var left := rect.position.x
	var right := rect.position.x + rect.size.x
	var top := rect.position.y
	var bottom := rect.position.y + rect.size.y

	# Process each boundary sequentially
	for boundary in [0,1,2,3]:
		if output.is_empty():
			break
		var result: PackedVector2Array = PackedVector2Array()
		var prev: Vector2 = output[output.size()-1]
		var prev_inside := point_inside_boundary(prev, boundary, left, right, top, bottom)
		for curr in output:
			var curr_inside := point_inside_boundary(curr, boundary, left, right, top, bottom)
			if curr_inside:
				if not prev_inside:
					result.append(_compute_intersection(prev, curr, boundary, left, right, top, bottom))
				result.append(curr)
			elif prev_inside:
				result.append(_compute_intersection(prev, curr, boundary, left, right, top, bottom))
			prev = curr
			prev_inside = curr_inside
		output = result
	return output

## Checks if a point is inside a boundary edge for clipping
## PUBLIC for testing - validates point-in-boundary logic used in clipping
##
## Boundary mapping for Sutherland-Hodgman algorithm:
## 0 = left boundary (x >= left)
## 1 = right boundary (x <= right)
## 2 = top boundary (y >= top)
## 3 = bottom boundary (y <= bottom)
##
## Uses small epsilon (-0.0001) to handle floating-point precision issues
## and ensure inclusive boundary checking.
static func point_inside_boundary(p: Vector2, boundary: int, left: float, right: float, top: float, bottom: float) -> bool:
	match boundary:
		0:
			return p.x >= left - 0.0001 # left
		1:
			return p.x <= right + 0.0001 # right
		2:
			return p.y >= top - 0.0001 # top
		3:
			return p.y <= bottom + 0.0001 # bottom
		_:
			return true

static func _compute_intersection(a: Vector2, b: Vector2, boundary: int, left: float, right: float, top: float, bottom: float) -> Vector2:
	var t := 0.0
	match boundary:
		0: # left
			if abs(b.x - a.x) < 0.0001:
				return Vector2(left, a.y)
			t = (left - a.x) / (b.x - a.x)
			return a + (b - a) * t
		1: # right
			if abs(b.x - a.x) < 0.0001:
				return Vector2(right, a.y)
			t = (right - a.x) / (b.x - a.x)
			return a + (b - a) * t
		2: # top
			if abs(b.y - a.y) < 0.0001:
				return Vector2(a.x, top)
			t = (top - a.y) / (b.y - a.y)
			return a + (b - a) * t
		3: # bottom
			if abs(b.y - a.y) < 0.0001:
				return Vector2(a.x, bottom)
			t = (bottom - a.y) / (b.y - a.y)
			return a + (b - a) * t
		_:
			return a

## Computes the area of a polygon using the shoelace formula
## PUBLIC for testing - validates clipped polygon area calculations
## Calculates the area of a polygon using the shoelace formula
## Returns absolute area (always positive) for overlap calculations
##
## Shoelace formula: For polygon with vertices (x1,y1), (x2,y2), ..., (xn,yn):
## Area = 1/2 * |Σ(i=1 to n) (xi*yi+1 - xi+1*yi)|
## where xn+1 = x1 and yn+1 = y1
##
## This gives the signed area; we take the absolute value for overlap measurements.
static func polygon_area(polygon: PackedVector2Array) -> float:
	var n := polygon.size()
	if n < 3:
		return 0.0
	var sum := 0.0
	for i in range(n):
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i + 1) % n]
		sum += a.x * b.y - b.x * a.y
	return abs(sum) * 0.5

## Pure function to check if point is inside polygon
## Pure function to check if point is inside polygon
## PUBLIC for testing - uses ray casting algorithm for point-in-polygon test
static func point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	if polygon.size() < 3:
		return false
	
	var inside = false
	var j = polygon.size() - 1
	
	for i in range(polygon.size()):
		if ((polygon[i].y > point.y) != (polygon[j].y > point.y)) and \
		   (point.x < (polygon[j].x - polygon[i].x) * (point.y - polygon[i].y) / (polygon[j].y - polygon[i].y) + polygon[i].x):
			inside = !inside
		j = i
	
	return inside

## Pure function to check if two lines intersect
static func _lines_intersect(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> bool:
	var denominator = (p4.y - p3.y) * (p2.x - p1.x) - (p4.x - p3.x) * (p2.y - p1.y)
	
	if abs(denominator) < 0.0001:
		return false
	
	var ua = ((p4.x - p3.x) * (p1.y - p3.y) - (p4.y - p3.y) * (p1.x - p3.x)) / denominator
	var ub = ((p2.x - p1.x) * (p1.y - p3.y) - (p2.y - p1.y) * (p1.x - p3.x)) / denominator
	
	return ua >= 0 and ua <= 1 and ub >= 0 and ub <= 1

## Pure function to check if two polygons intersect
static func _polygons_intersect(poly1: PackedVector2Array, poly2: PackedVector2Array, epsilon: float) -> bool:
	# Check if any point from poly1 is inside poly2
	for point in poly1:
		if point_in_polygon(point, poly2):
			return true
	
	# Check if any point from poly2 is inside poly1
	for point in poly2:
		if point_in_polygon(point, poly1):
			return true
	
	# Check if any edges intersect
	for i in range(poly1.size()):
		var edge1_start = poly1[i]
		var edge1_end = poly1[(i + 1) % poly1.size()]
		
		for j in range(poly2.size()):
			var edge2_start = poly2[j]
			var edge2_end = poly2[(j + 1) % poly2.size()]
			
			if _lines_intersect(edge1_start, edge1_end, edge2_start, edge2_end):
				return true
	
	return false
