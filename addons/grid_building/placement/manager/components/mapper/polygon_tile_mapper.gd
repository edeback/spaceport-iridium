## Handles polygon-to-tile-offset conversion with testable, separated concerns.
##
## This class extracts the complex polygon processing logic from CollisionMapper
## to enable better testing and separation of responsibilities.
##
## Coordinate semantics
## - Tile addressing is center-based. For 16×16 tiles, the center is at +8,+8 from the tile origin.
## - Tests and runtime share "bottom-inclusive, top-exclusive" behavior on axis-aligned boundaries
##   to avoid fencepost rows when a polygon edge lies exactly on a tile boundary.
##
## Pipeline stages:
## 1. Transform polygon to world space and compute initial tile coverage
## 2. Apply trapezoid expansion heuristics for convex polygons when beneficial
## 3. Prune concave polygon fringes to remove unwanted overhangs
## 4. Filter tiles by minimum area overlap to remove slivers (with concave center-point check)
class_name PolygonTileMapper
const MIN_POLY_TILE_OVERLAP_RATIO := 0.12

## Configuration for area-based filtering thresholds
class AreaThresholds:
	var default_ratio: float = MIN_POLY_TILE_OVERLAP_RATIO
	var convex_ratio: float = 0.01  # Very relaxed from 0.05 to get basic functionality working
	var expanded_trapezoid_ratio: float = 0.01  # Very relaxed
	var expansion_candidate_ratio: float = 0.01  # Very relaxed

## Result of polygon processing with diagnostic information
class ProcessingResult:
	var offsets: Array[Vector2i] = []
	var did_expand_trapezoid: bool = false
	var was_convex: bool = false
	var initial_offset_count: int = 0
	var final_offset_count: int = 0

	# Print diagnostic summary for test logs
	func print_diagnostics() -> void:
		print("[CollisionProcessor:DIAG] mapper.initial_count=%d, mapper.final_count=%d, was_convex=%s, did_expand=%s" % [initial_offset_count, final_offset_count, str(was_convex), str(did_expand_trapezoid)])
		# Also print a short sample of offsets (if any)
		if offsets and offsets.size() > 0:
			print("[CollisionProcessor:DIAG] mapper.offsets_sample=%s" % str(offsets))

## Primary entry point for polygon-to-tile conversion (runtime optimized)
static func compute_tile_offsets(polygon_node: CollisionPolygon2D, map: TileMapLayer) -> Array[Vector2i]:
	# Early validation
	if polygon_node == null or map == null or map.tile_set == null:
		return []

	# Convert the positioner's global position into the TileMap's local space before mapping to tile coords.
	# This maintains correctness when the TileMap has a transform (common in isometric setups).
	var center_tile: Vector2i = map.local_to_map(map.to_local(polygon_node.global_position))
	return _compute_tile_offsets_internal(polygon_node, map, center_tile)

## Primary entry point with positioner reference for consistent positioning
## Uses positioner's position as coordinate reference instead of polygon's position
static func compute_tile_offsets_with_positioner(polygon_node: CollisionPolygon2D, map: TileMapLayer, positioner: Node2D) -> Array[Vector2i]:
	# Early validation
	if polygon_node == null or map == null or map.tile_set == null or positioner == null:
		return []

	# CRITICAL: Use positioner position as coordinate reference for consistency
	var center_tile: Vector2i = map.local_to_map(map.to_local(positioner.global_position))
	return _compute_tile_offsets_internal(polygon_node, map, center_tile)

## Internal implementation shared by both public methods
static func _compute_tile_offsets_internal(polygon_node: CollisionPolygon2D, map: TileMapLayer, center_tile: Vector2i) -> Array[Vector2i]:
	var world_points: PackedVector2Array = _transform_polygon_world(polygon_node)
	var tile_size: Vector2 = Vector2(map.tile_set.tile_size)

	# Guard that the TileSet actually exposes the tile_shape property. Use get_property_list to be robust
	var has_tile_shape: bool = false
	for prop in map.tile_set.get_property_list():
		if prop.has("name") and prop.name == "tile_shape":
			has_tile_shape = true
			break
	if not has_tile_shape:
		# Fallback: try direct access
		var tile_shape_val: int = 0  # Default to TILE_SHAPE_SQUARE
		var offsets: Array[Vector2i] = CollisionGeometryUtils.compute_polygon_tile_offsets(world_points, tile_size, center_tile, tile_shape_val, map)
		return _apply_minimal_processing(offsets, world_points, center_tile, map, tile_size, polygon_node)

	var tile_shape_val: int = map.tile_set.tile_shape

	# Stage 1: Initial geometry-based tile coverage
	var offsets: Array[Vector2i] = CollisionGeometryUtils.compute_polygon_tile_offsets(world_points, tile_size, center_tile, tile_shape_val, map)

	if offsets.is_empty():
		return offsets

	# Analyze polygon properties (needed for processing decisions)
	var is_convex: bool = CollisionGeometryUtils.is_polygon_convex(polygon_node.polygon)

	# Stage 2: Trapezoid expansion for convex polygons
	var did_expand_trapezoid: bool = false
	if is_convex:
		var expansion_result: Dictionary = _apply_trapezoid_expansion(offsets, world_points, tile_size, center_tile)
		if expansion_result.expanded:
			offsets = expansion_result.offsets
			did_expand_trapezoid = true

	# Stage 3: Concave fringe pruning
	if not is_convex:
		offsets = _prune_concave_fringe(world_points, offsets, center_tile, tile_size)

	# Stage 4: Area-based filtering
	var thresholds: AreaThresholds = AreaThresholds.new()
	offsets = _filter_by_area_overlap(offsets, world_points, center_tile, map, tile_size,
		is_convex, did_expand_trapezoid, thresholds)

	return offsets

## Simplified processing for fallback cases
static func _apply_minimal_processing(offsets: Array[Vector2i], world_points: PackedVector2Array,
	center_tile: Vector2i, map: TileMapLayer, tile_size: Vector2, polygon_node: CollisionPolygon2D) -> Array[Vector2i]:
	
	if offsets.is_empty():
		return offsets
	
	# Very relaxed area filtering for basic functionality
	var min_area = tile_size.x * tile_size.y * 0.01  # Only 1% overlap required
	var filtered: Array[Vector2i] = []
	
	for off in offsets:
		var abs_tile = center_tile + off
		var tile_rect = _compute_tile_rect(abs_tile, map, tile_size)
		var area = get_polygon_tile_overlap_area(world_points, tile_rect)
		
		if area >= min_area:
			filtered.append(off)
	
	return filtered

## Full processing with diagnostic information for testing and debugging
static func process_polygon_with_diagnostics(polygon_node: CollisionPolygon2D, map: TileMapLayer) -> ProcessingResult:
	var result = ProcessingResult.new()

	# Early validation
	if polygon_node == null or map == null or map.tile_set == null:
		return result

	# Convert the positioner's global position into the TileMap's local space before mapping to tile coords.
	# This maintains correctness when the TileMap has a transform (common in isometric setups).
	var center_tile = map.local_to_map(map.to_local(polygon_node.global_position))
	var world_points = _transform_polygon_world(polygon_node)
	var tile_size = Vector2(map.tile_set.tile_size)

	# Guard that the TileSet actually exposes the tile_shape property. Use get_property_list to be robust
	var has_tile_shape := false
	for prop in map.tile_set.get_property_list():
		if prop.has("name") and prop.name == "tile_shape":
			has_tile_shape = true
			break
	if not has_tile_shape:
		return result

	var tile_shape_val = map.tile_set.tile_shape

	# Stage 1: Initial geometry-based tile coverage
	var offsets = CollisionGeometryUtils.compute_polygon_tile_offsets(world_points, tile_size, center_tile, tile_shape_val, map)
	result.initial_offset_count = offsets.size()

	if offsets.is_empty():
		return result

	# Analyze polygon properties
	result.was_convex = CollisionGeometryUtils.is_polygon_convex(polygon_node.polygon)

	# Stage 2: Trapezoid expansion for convex polygons
	if result.was_convex:
		var expansion_result = _apply_trapezoid_expansion(offsets, world_points, tile_size, center_tile)
		if expansion_result.expanded:
			offsets = expansion_result.offsets
			result.did_expand_trapezoid = true

	# Stage 3: Concave fringe pruning
	if not result.was_convex:
		offsets = _prune_concave_fringe(world_points, offsets, center_tile, tile_size)

	# Stage 4: Area-based filtering
	var thresholds = AreaThresholds.new()
	offsets = _filter_by_area_overlap(offsets, world_points, center_tile, map, tile_size,
		result.was_convex, result.did_expand_trapezoid, thresholds)

	result.offsets = offsets
	result.final_offset_count = offsets.size()
	return result


## Stage 2: Apply trapezoid expansion with validation
static func _apply_trapezoid_expansion(offsets: Array[Vector2i], world_points: PackedVector2Array, 
	tile_size: Vector2, center_tile: Vector2i) -> Dictionary:
	
	var result: Dictionary = {"expanded": false, "offsets": offsets}
	
	# Check if expansion is beneficial
	var analysis: Dictionary = _analyze_offset_pattern(offsets)
	var hollow_shape: bool = PolygonIndicatorHeuristics.is_hollow(offsets)
	
	if not PolygonIndicatorHeuristics.should_expand_trapezoid(
		true, offsets, analysis.ys, analysis.xs_by_y, hollow_shape):
		return result
	
	# Generate and validate expansion candidates
	var expanded: Array[Vector2i] = PolygonIndicatorHeuristics.generate_trapezoid_offsets()
	var validated: Array[Vector2i] = _validate_expansion_candidates(expanded, world_points, tile_size, center_tile)
	
	# Only apply if we're adding new coverage
	if _expansion_adds_new_tiles(offsets, validated):
		result.expanded = true
		result.offsets = validated
	
	return result

## Stage 3: Remove concave fringe artifacts
static func _prune_concave_fringe(world_points: PackedVector2Array, offsets: Array[Vector2i], 
	center_tile: Vector2i, tile_size: Vector2) -> Array[Vector2i]:
	# Use a slightly higher default ratio to better reject fringe tiles on concave shapes
	return PolygonIndicatorHeuristics.prune_concave_fringe(world_points, offsets, center_tile, tile_size, 0.18)

## Stage 4: Filter tiles by area overlap
static func _filter_by_area_overlap(offsets: Array[Vector2i], world_points: PackedVector2Array,
	center_tile: Vector2i, map: TileMapLayer, tile_size: Vector2, 
	is_convex: bool, did_expand: bool, thresholds: AreaThresholds) -> Array[Vector2i]:
	
	var min_ratio = _determine_area_threshold(is_convex, did_expand, thresholds)
	var min_area = tile_size.x * tile_size.y * min_ratio
	
	var filtered: Array[Vector2i] = []
	for off in offsets:
		var abs_tile = center_tile + off
		var tile_rect = _compute_tile_rect(abs_tile, map, tile_size)
		var area = get_polygon_tile_overlap_area(world_points, tile_rect)
		
		var should_include = area >= min_area
		
		# For concave polygons, also check if tile center is actually inside the polygon
		# This prevents including tiles that are only touched by polygon edges but are in holes/indentations
		if not is_convex and should_include:
			var tile_center_world = tile_rect.position + tile_rect.size / 2.0
			should_include = CollisionGeometryCalculator.point_in_polygon(tile_center_world, world_points)
		
		if should_include:
			filtered.append(off)

	# Post-filter heuristic: axis-aligned rectangles that are an exact multiple of tile height
	# should not include the highest row (top-edge exclusive, bottom-edge inclusive).
	# This matches center-based grid semantics used by tests and prevents an extra row
	# when a rectangle edge lands exactly on a tile boundary. See also: CollisionGeometryUtils.compute_tile_iteration_range
	filtered = _apply_axis_aligned_boundary_exclusion(filtered, world_points, center_tile, map, tile_size, is_convex)

	return filtered

## Heuristic: Exclude the highest Y row for axis-aligned rectangles whose height
## is an exact multiple of the tile height. Keeps bottom-inclusive/top-exclusive behavior.
static func _apply_axis_aligned_boundary_exclusion(
	filtered: Array[Vector2i],
	world_points: PackedVector2Array,
	center_tile: Vector2i,
	map: TileMapLayer,
	tile_size: Vector2,
	is_convex: bool
) -> Array[Vector2i]:
	# Only consider simple convex quads (rectangles) to avoid impacting arbitrary polygons
	if not is_convex:
		return filtered
	if world_points.size() != 4:
		return filtered

	# Determine if polygon is axis-aligned: exactly two unique Xs and two unique Ys (within epsilon)
	var eps := 0.0001
	var xs: Array[float] = []
	var ys: Array[float] = []
	for p in world_points:
		var found_x := false
		for vx in xs:
			if abs(vx - p.x) < eps:
				found_x = true
				break
		if not found_x:
			xs.append(p.x)
		var found_y := false
		for vy in ys:
			if abs(vy - p.y) < eps:
				found_y = true
				break
		if not found_y:
			ys.append(p.y)

	if xs.size() != 2 or ys.size() != 2:
		return filtered

	# Compute polygon bounds and check if height is an exact multiple of tile height
	var bounds: Rect2 = _compute_polygon_bounds(world_points)
	var height_tiles: float = bounds.size.y / tile_size.y
	if abs(height_tiles - round(height_tiles)) > 0.0001:
		return filtered

	# Exclude the highest Y row among currently selected offsets
	if filtered.is_empty():
		return filtered
	var max_y := filtered[0].y
	for off in filtered:
		max_y = max(max_y, off.y)
	# Build new list without the highest row
	var adjusted: Array[Vector2i] = []
	for off in filtered:
		if off.y != max_y:
			adjusted.append(off)
	return adjusted

## Helper: Analyze offset pattern for trapezoid detection
static func _analyze_offset_pattern(offsets: Array[Vector2i]) -> Dictionary:
	var ys: Array[int] = []
	var xs_by_y: Dictionary = {}
	
	for offset in offsets:
		if not ys.has(offset.y): 
			ys.append(offset.y)
		if not xs_by_y.has(offset.y): 
			xs_by_y[offset.y] = []
		xs_by_y[offset.y].append(offset.x)
	
	return {"ys": ys, "xs_by_y": xs_by_y}

## Helper: Validate expansion candidates against actual geometry
static func _validate_expansion_candidates(candidates: Array[Vector2i], world_points: PackedVector2Array,
	tile_size: Vector2, center_tile: Vector2i) -> Array[Vector2i]:
	
	var validated: Array[Vector2i] = []
	var tile_area = tile_size.x * tile_size.y
	var min_expansion_area = tile_area * 0.02  # Very low threshold for expansion
	
	for candidate in candidates:
		var abs_tile = center_tile + candidate
		var tile_center_local = Vector2(abs_tile.x * tile_size.x, abs_tile.y * tile_size.y)
		var tile_rect = Rect2(tile_center_local - tile_size/2.0, tile_size)
		var area = get_polygon_tile_overlap_area(world_points, tile_rect)
		
		if area >= min_expansion_area:
			validated.append(candidate)
	
	return validated

## Helper: Check if expansion adds new tile coverage
static func _expansion_adds_new_tiles(original: Array[Vector2i], expanded: Array[Vector2i]) -> bool:
	var original_set: Dictionary = {}
	for offset in original:
		original_set[str(offset)] = true
	
	for candidate in expanded:
		if not original_set.has(str(candidate)):
			return true
	
	return false

## Helper: Determine area threshold based on polygon type and processing
static func _determine_area_threshold(is_convex: bool, did_expand: bool, thresholds: AreaThresholds) -> float:
	if not is_convex:
		return thresholds.default_ratio
	elif did_expand:
		return thresholds.expanded_trapezoid_ratio
	else:
		return thresholds.convex_ratio

## Helper: Compute tile rectangle in world space
static func _compute_tile_rect(abs_tile: Vector2i, map: TileMapLayer, tile_size: Vector2) -> Rect2:
	var tile_center_local = map.map_to_local(abs_tile)
	var tile_center_world = map.to_global(tile_center_local)
	return Rect2(tile_center_world - tile_size/2.0, tile_size)

## World polygon conversion - delegates to utility
static func _transform_polygon_world(polygon_node: CollisionPolygon2D) -> PackedVector2Array:
	return CollisionGeometryUtils.to_world_polygon(polygon_node)

## Polygon-tile overlap calculation using Sutherland-Hodgman clipping
static func get_polygon_tile_overlap_area(polygon: PackedVector2Array, rect: Rect2) -> float:
	if polygon.is_empty():
		return 0.0
	
	# Quick bounds check
	var poly_bounds: Rect2 = _compute_polygon_bounds(polygon)
	if not poly_bounds.intersects(rect, true):
		return 0.0
	
	# Special case: if polygon is a perfect rectangle matching the tile rect
	if polygon.size() == 4:
		var is_rect: bool = true
		var corners: Array[Vector2] = [
			rect.position,
			Vector2(rect.position.x + rect.size.x, rect.position.y),
			rect.position + rect.size,
			Vector2(rect.position.x, rect.position.y + rect.size.y)
		]
		
		# Check if polygon vertices match rect corners (in any order)
		for corner in corners:
			var found: bool = false
			for vertex in polygon:
				if vertex.distance_to(corner) < 0.001:
					found = true
					break
			if not found:
				is_rect = false
				break
		
		if is_rect:
			return rect.size.x * rect.size.y
	
	# Sutherland-Hodgman clipping
	var clipped: PackedVector2Array = _clip_polygon_to_rect(polygon, rect)
	if clipped.size() < 3:
		return 0.0
	
	return _compute_polygon_area(clipped)

## Helper: Compute polygon bounding rectangle
static func _compute_polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty():
		return Rect2()
	
	var min_pt: Vector2 = polygon[0]
	var max_pt: Vector2 = polygon[0]
	
	for p in polygon:
		min_pt.x = min(min_pt.x, p.x)
		min_pt.y = min(min_pt.y, p.y)
		max_pt.x = max(max_pt.x, p.x)
		max_pt.y = max(max_pt.y, p.y)
	
	return Rect2(min_pt, max_pt - min_pt)

## Helper: Clip polygon against rectangle using Sutherland-Hodgman algorithm
static func _clip_polygon_to_rect(polygon: PackedVector2Array, rect: Rect2) -> PackedVector2Array:
	var output: PackedVector2Array = polygon
	var boundaries: Array[Dictionary] = [
		{"type": "left", "value": rect.position.x},
		{"type": "right", "value": rect.position.x + rect.size.x},
		{"type": "top", "value": rect.position.y},
		{"type": "bottom", "value": rect.position.y + rect.size.y}
	]
	
	for boundary in boundaries:
		if output.is_empty():
			break
		
		var result: PackedVector2Array = PackedVector2Array()
		if output.size() > 0:
			var prev: Vector2 = output[output.size() - 1]
			var prev_inside: bool = _point_inside_boundary(prev, boundary)
			
			for curr in output:
				var curr_inside: bool = _point_inside_boundary(curr, boundary)
				
				if curr_inside:
					if not prev_inside:
						result.append(_compute_intersection(prev, curr, boundary))
					result.append(curr)
				elif prev_inside:
					result.append(_compute_intersection(prev, curr, boundary))
				
				prev = curr
				prev_inside = curr_inside
		
		output = result
	
	return output

## Helper: Test if point is inside clipping boundary
static func _point_inside_boundary(point: Vector2, boundary: Dictionary) -> bool:
	var epsilon = 0.0001
	match boundary.type:
		"left": return point.x >= boundary.value - epsilon
		"right": return point.x <= boundary.value + epsilon
		"top": return point.y >= boundary.value - epsilon
		"bottom": return point.y <= boundary.value + epsilon
		_: return true

## Helper: Compute line-boundary intersection
static func _compute_intersection(a: Vector2, b: Vector2, boundary: Dictionary) -> Vector2:
	var t: float = 0.0
	match boundary.type:
		"left", "right":
			if abs(b.x - a.x) < 0.0001:
				return Vector2(boundary.value, a.y)
			t = (boundary.value - a.x) / (b.x - a.x)
		"top", "bottom":
			if abs(b.y - a.y) < 0.0001:
				return Vector2(a.x, boundary.value)
			t = (boundary.value - a.y) / (b.y - a.y)
	
	return a + (b - a) * t

## Helper: Compute polygon area using shoelace formula
static func _compute_polygon_area(polygon: PackedVector2Array) -> float:
	if polygon.size() < 3:
		return 0.0

	var sum: float = 0.0
	for i in range(polygon.size()):
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i + 1) % polygon.size()]
		sum += a.x * b.y - b.x * a.y

	return abs(sum) * 0.5
