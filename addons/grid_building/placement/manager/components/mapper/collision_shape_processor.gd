## Processes collision shapes to determine tile offsets for grid-based placement.
##
## This component handles the geometric calculations needed to map arbitrary 2D collision 
## shapes onto discrete tile grids. It supports both square and isometric tile layouts,
## providing accurate tile coverage determination for placement validation.
##
## [b]Core Responsibilities:[/b][br]
## - Convert collision shapes to tile offset arrays relative to a center tile[br]
## - Handle shape-to-tile overlap calculations with configurable precision[br]
## - Support different tile geometries (square, isometric) automatically[br]
## - Apply shape-specific optimizations (symmetry enforcement, area thresholds)[br]
## - Cache geometric calculations for performance[br][br]
##
## [b]Tile Shape Support:[/b][br]
## The processor automatically detects tile shape from the TileMapLayer's TileSet and
## applies appropriate geometric calculations. Single source of truth principle ensures
## tile shape information is read directly from the map configuration.[br][br]
##
## [b]Usage:[/b]
## [codeblock]
## var processor = CollisionShapeProcessor.new(cache_manager)
## var tile_offsets = processor.get_tile_offsets_for_collision_object(test_data, map, positioner)
## [/codeblock]
extends RefCounted

const GeometryCacheManager = preload("uid://d0cdgiqycnh43")

var _cache_manager: GeometryCacheManager

## Initializes the processor with required dependencies.
##
## [b]Parameters:[/b][br]
## - [code]cache_manager[/code]: GeometryCacheManager for polygon bounds caching[br]
func _init(cache_manager: GeometryCacheManager) -> void:
	_cache_manager = cache_manager

## Computes tile offsets for all collision shapes in a collision object.
##
## This is the main entry point for collision-to-tile mapping. It processes all shapes
## attached to the collision object and returns their combined tile coverage as offsets
## relative to a calculated center tile.
##
## [b]Tile Shape Detection:[/b][br]
## Automatically reads tile shape from [code]map.tile_set.tile_shape[/code] to ensure
## single source of truth. Supports TileSet.TILE_SHAPE_SQUARE and TileSet.TILE_SHAPE_ISOMETRIC.[br][br]
##
## [b]Returns:[/b] Dictionary[Vector2i, Array] mapping tile offsets to collision objects
func get_tile_offsets_for_collision_object(test_data: CollisionTestSetup2D, map: TileMapLayer, positioner: Node2D) -> Dictionary[Vector2i, Array]:
	var collision_positions: Dictionary[Vector2i, Array] = {}
	
	# Validate input parameters
	if not test_data:
		push_error("CollisionShapeProcessor: test_data is null. Cannot process collision shapes.")
		return collision_positions
	
	if not test_data.collision_object:
		push_error("CollisionShapeProcessor: test_data.collision_object is null. Cannot process collision shapes.")
		return collision_positions
	
	if not test_data.collision_object is CollisionObject2D:
		push_error("CollisionShapeProcessor: Expected CollisionObject2D, got " + str(test_data.collision_object.get_class()) + ". This processor only handles CollisionObject2D nodes with CollisionShape2D children.")
		return collision_positions
	
	if not map:
		push_error("CollisionShapeProcessor: map is null. Cannot process collision shapes without a valid TileMapLayer.")
		return collision_positions
	
	if not map.tile_set:
		push_error("CollisionShapeProcessor: map.tile_set is null. Cannot determine tile size and shape.")
		return collision_positions
	
	var col_obj = test_data.collision_object
	
	if not _initialize_collision_mapping(positioner, collision_positions):
		return collision_positions
	
	var center_tile = CollisionGeometryUtils.center_tile_for_shape_object(map, col_obj)
	var tile_size = Vector2(map.tile_set.tile_size) if map.tile_set else Vector2(16, 16)
	var shape_epsilon = 0.035
	
	# Single source of truth: get tile shape directly from TileMapLayer's TileSet
	var tile_shape: TileSet.TileShape = map.tile_set.tile_shape if map.tile_set else TileSet.TILE_SHAPE_SQUARE
	
	if col_obj.name == "Smithy":
		pass  # Removed logging
	
	for rect_test_setup in test_data.rect_collision_test_setups:
		var shape_positions = _process_shape_offsets(rect_test_setup, test_data, map, center_tile, tile_size, shape_epsilon, col_obj)
		_merge_collision_positions(collision_positions, shape_positions)
	
	return collision_positions

## Validates that required dependencies are available for collision mapping.
func _initialize_collision_mapping(positioner: Node2D, collision_positions: Dictionary[Vector2i, Array]) -> bool:
	if not positioner:
		push_error("CollisionShapeProcessor: positioner is null. Cannot process collision shapes without a valid positioner.")
		return false
	return true

## Processes shape offsets for a single collision test setup.
## 
## Iterates through all shapes in the test setup and calculates which tiles
## they overlap with based on the tile shape defined in the map's TileSet.
## 
## [param rect_test_setup]: Shape and collision test configuration
## @param test_data: Overall test setup containing epsilon values
## @param map: TileMapLayer providing tile configuration via its TileSet
## @param center_tile: Reference tile position for offset calculations
## @param tile_size: Size of each tile in world coordinates
## @param shape_epsilon: Minimum overlap threshold for shape-tile intersection
## @param col_obj: Collision object being processed
## @returns Dictionary[Vector2i, Array] mapping tile offsets to collision objects for this shape setup
func _process_shape_offsets(rect_test_setup: Variant, test_data: CollisionTestSetup2D, map: TileMapLayer, center_tile: Vector2i, tile_size: Vector2, shape_epsilon: float, col_obj: Node2D) -> Dictionary[Vector2i, Array]:
	var shape_positions: Dictionary[Vector2i, Array] = {}
	var shape_owner = rect_test_setup.shape_owner
	var shape_transform = CollisionGeometryUtils.build_shape_transform(col_obj, shape_owner)
	
	for shape in rect_test_setup.shapes:
		var shape_polygon = GBGeometryMath.convert_shape_to_polygon(shape, shape_transform)
		# NOTE: shape_polygon vertices already have rotation/scale/skew applied via shape_transform
		var bounds = _cache_manager.get_cached_polygon_bounds(shape_polygon)
		
		if shape is CapsuleShape2D:
			pass  # Removed logging
		
		var start_tile: Vector2i
		var end_exclusive: Vector2i
		# Pass shape_polygon so tile range calculation can use actual transformed vertices
		# instead of AABB (which expands under rotation)
		_calculate_tile_range(shape, bounds, map, tile_size, shape_transform, start_tile, end_exclusive, shape_polygon)
		
		var shape_offsets = _compute_shape_tile_offsets(shape, shape_transform, map, tile_size, shape_epsilon, start_tile, end_exclusive, center_tile, shape_polygon)
		
		if shape is CircleShape2D or shape is CapsuleShape2D:
			_enforce_horizontal_symmetry(shape_offsets)
		
		_merge_offsets_into_positions(shape_offsets, shape_positions, col_obj, center_tile)
	
	return shape_positions

## Calculates the tile range that needs to be checked for a shape.
## 
## Determines the bounding box of tiles that might intersect with the shape.
## Uses actual polygon vertices (which already have rotation/scale/skew applied)
## instead of AABB to avoid over-expansion under rotation.
## 
## @param shape: Shape2D to calculate range for
## @param bounds: AABB of the shape (fallback for optimization hints)
## @param map: TileMapLayer providing tile configuration via its TileSet
## @param tile_size: Size of each tile in world coordinates
## @param shape_transform: Transform of the shape in world space
## @param start_tile: Output parameter for the starting tile coordinate
## @param end_exclusive: Output parameter for the ending tile coordinate (exclusive)
## @param shape_polygon: Transformed polygon vertices (rotation/scale/skew already applied)
func _calculate_tile_range(shape: Shape2D, bounds: Rect2, map: TileMapLayer, tile_size: Vector2, shape_transform: Transform2D, start_tile: Vector2i, end_exclusive: Vector2i, shape_polygon: PackedVector2Array) -> void:
	# Calculate tile range from actual polygon vertices instead of AABB
	# This prevents over-expansion when shapes are rotated/scaled/skewed
	# shape_polygon already has transform applied (rotation/scale/skew)
	
	if shape_polygon.size() == 0:
		# Fallback to AABB if no polygon vertices (shouldn't happen in practice)
		var min_local = map.to_local(bounds.position)
		var max_local = map.to_local(bounds.position + bounds.size)
		start_tile = Vector2i(
			int(floor(min_local.x / tile_size.x)),
			int(floor(min_local.y / tile_size.y))
		)
		end_exclusive = Vector2i(
			int(ceil(max_local.x / tile_size.x)),
			int(ceil(max_local.y / tile_size.y))
		)
		return
	
	# Find min/max from actual transformed vertices
	var min_world := Vector2(INF, INF)
	var max_world := Vector2(-INF, -INF)
	
	for vertex in shape_polygon:
		min_world.x = min(min_world.x, vertex.x)
		min_world.y = min(min_world.y, vertex.y)
		max_world.x = max(max_world.x, vertex.x)
		max_world.y = max(max_world.y, vertex.y)
	
	# Convert world space bounds to tile coordinates
	var min_local := map.to_local(min_world)
	var max_local := map.to_local(max_world)
	
	start_tile = Vector2i(
		int(floor(min_local.x / tile_size.x)),
		int(floor(min_local.y / tile_size.y))
	)
	end_exclusive = Vector2i(
		int(ceil(max_local.x / tile_size.x)),
		int(ceil(max_local.y / tile_size.y))
	)

	if shape is CircleShape2D or shape is CapsuleShape2D:
		var shape_center_tile = map.local_to_map(map.to_local(shape_transform.origin))
		var left_span = shape_center_tile.x - start_tile.x
		var right_span = end_exclusive.x - shape_center_tile.x
		var desired_right_exclusive = shape_center_tile.x + left_span + 1
		if end_exclusive.x < desired_right_exclusive:
			end_exclusive.x = desired_right_exclusive

	if shape is RectangleShape2D:
		# Calculate effective size from polygon bounds (accounts for rotation/scale)
		var eff_size := max_world - min_world
		var shape_center_tile = map.local_to_map(map.to_local(shape_transform.origin))
		var adjusted = GBCollisionTileFilter.adjust_rect_tile_range(eff_size, tile_size, shape_center_tile, start_tile, end_exclusive)
		start_tile = adjusted["start"]
		end_exclusive = adjusted["end_exclusive"]

## Computes which tiles a shape overlaps with, returning offset positions.
## 
## For each tile in the specified range, calculates the intersection area between
## the shape and tile using the tile geometry defined in the map's TileSet.
## Returns tile positions relative to the center tile.
## 
## @param shape: Shape2D to compute overlaps for
## @param shape_transform: Transform of the shape in world space
## @param map: TileMapLayer providing tile configuration via its TileSet
## @param tile_size: Size of each tile in world coordinates
## @param shape_epsilon: Minimum overlap threshold for inclusion
## @param start_tile: Starting tile coordinate for range
## @param end_exclusive: Ending tile coordinate for range (exclusive)
## @param center_tile: Reference tile for calculating relative offsets
## @param shape_polygon: Polygon representation of the shape
## @returns Array of Vector2i offsets relative to center_tile
func _compute_shape_tile_offsets(shape: Shape2D, shape_transform: Transform2D, map: TileMapLayer, tile_size: Vector2, shape_epsilon: float, start_tile: Vector2i, end_exclusive: Vector2i, center_tile: Vector2i, shape_polygon: PackedVector2Array) -> Array[Vector2i]:
	# Get tile shape from map's TileSet (single source of truth)
	var tile_shape: TileSet.TileShape = map.tile_set.tile_shape
	
	var shape_offsets: Array[Vector2i] = []
	for x in range(start_tile.x, end_exclusive.x):
		for y in range(start_tile.y, end_exclusive.y):
			var tile_pos = Vector2i(x, y)
			var tile_center_local = map.map_to_local(tile_pos)
			var tile_center_world = map.to_global(tile_center_local)
			var tile_top_left_world = tile_center_world - tile_size / 2.0

			var has_overlap = false
			if shape is RectangleShape2D and tile_shape == TileSet.TILE_SHAPE_SQUARE:
				# Use optimized collision detection for rectangle shapes on square tiles
				has_overlap = GBGeometryMath.does_shape_overlap_tile_optimized(shape, shape_transform, tile_top_left_world, tile_size, tile_shape, shape_epsilon)
			else:
				has_overlap = GBGeometryMath.does_polygon_overlap_tile(shape_polygon, tile_top_left_world, tile_size, tile_shape, shape_epsilon)
			
			if has_overlap:
				if shape is CircleShape2D:
					var cshape = shape as CircleShape2D
					var circle_center = shape_transform.origin
					var circle_tile_center = tile_top_left_world + tile_size / 2.0
					if not GBCollisionTileFilter.circle_tile_allowed(circle_center, cshape.radius, circle_tile_center, tile_size):
						continue

				# Calculate tile area based on tile shape
				var tile_area = tile_size.x * tile_size.y
				if tile_shape == TileSet.TILE_SHAPE_ISOMETRIC:
					# For isometric tiles, the effective area is the same as the bounding box
					# since the diamond shape still fits within the same rectangular bounds
					tile_area = tile_size.x * tile_size.y
				var area_epsilon = shape_epsilon
				if shape is CircleShape2D or shape is CapsuleShape2D:
					area_epsilon = 0.025

				var min_area = tile_area * area_epsilon
				var tile_rect = Rect2(tile_top_left_world, tile_size)

				var overlap_area = GBGeometryMath.intersection_area_with_tile(shape_polygon, tile_top_left_world, tile_size, tile_shape)

				# For rectangle shapes on square tiles, if the polygons are the same, assume full overlap
				if shape is RectangleShape2D and tile_shape == TileSet.TILE_SHAPE_SQUARE:
					var shape_bounds = _cache_manager.get_cached_polygon_bounds(shape_polygon)
					var tile_bounds = Rect2(tile_top_left_world, tile_size)
					if shape_bounds == tile_bounds:
						overlap_area = tile_area

				var at_min_x = (x == start_tile.x)
				var at_max_x = (x == end_exclusive.x - 1)
				var at_min_y = (y == start_tile.y)
				var at_max_y = (y == end_exclusive.y - 1)
				var is_corner_tile = (at_min_x or at_max_x) and (at_min_y or at_max_y)
				var required_area = min_area
				if is_corner_tile:
					required_area = max(required_area, tile_area * 0.20)
				if overlap_area < required_area:
					continue
				shape_offsets.append(tile_pos - center_tile)
			else:
				# Special case: for rectangle shapes on square tiles where bounds match but overlap check failed
				if shape is RectangleShape2D and tile_shape == TileSet.TILE_SHAPE_SQUARE:
					var shape_bounds = _cache_manager.get_cached_polygon_bounds(shape_polygon)
					var tile_bounds = Rect2(tile_top_left_world, tile_size)
					if shape_bounds == tile_bounds:
						shape_offsets.append(tile_pos - center_tile)

	return shape_offsets

## Enforces horizontal symmetry for circular and capsule shapes.
## 
## For shapes that should be symmetrical (circles and capsules), ensures that
## if a tile offset exists on one side, the corresponding mirror offset also exists.
## This prevents asymmetrical collision detection for symmetric shapes.
## 
## @param shape_offsets: Array of tile offsets to make symmetric (modified in-place)
func _enforce_horizontal_symmetry(shape_offsets: Array[Vector2i]) -> void:
	var by_row: Dictionary[int, Array] = {}
	for off in shape_offsets:
		if not by_row.has(off.y):
			by_row[off.y] = []
		by_row[off.y].append(off.x)
	var additions: Array[Vector2i] = []
	for y_key in by_row.keys():
		var xs = by_row[y_key]
		xs.sort()
		for xval in xs:
			if xval < 0 and not xs.has(-xval):
				additions.append(Vector2i(-xval, y_key))
	for add_off in additions:
		shape_offsets.append(add_off)

## Merges shape offsets into the collision positions dictionary.
## 
## Adds each calculated tile offset to the collision positions dictionary,
## ensuring each collision object is properly tracked for its affected tiles.
## 
## @param shape_offsets: Array of tile offsets to merge
## @param collision_positions: Dictionary mapping tile positions to collision objects
## @param col_obj: Collision object being processed
func _merge_offsets_into_positions(shape_offsets: Array[Vector2i], collision_positions: Dictionary[Vector2i, Array], col_obj: Node2D, center_tile: Vector2i) -> void:
	# The processor must return relative offsets (keys are offsets from the positioner tile).
	# Store offsets directly as keys so callers (CollisionMapper / IndicatorFactory)
	# can consistently interpret the returned dictionary as relative tile offsets.
	for off in shape_offsets:
		if collision_positions.has(off):
			if not collision_positions[off].has(col_obj):
				collision_positions[off].append(col_obj)
		else:
			# Use a shallow array containing the owner collision object
			collision_positions[off] = [col_obj]

## Merges two collision position dictionaries.
##
## Combines the contents of source_positions into target_positions,
## ensuring each collision object is properly tracked for its affected tiles.
##
## @param target_positions: Dictionary to merge into (modified in-place)
## @param source_positions: Dictionary to merge from
func _merge_collision_positions(target_positions: Dictionary[Vector2i, Array], source_positions: Dictionary[Vector2i, Array]) -> void:
	for tile_offset in source_positions.keys():
		var collision_objects = source_positions[tile_offset]
		if target_positions.has(tile_offset):
			for col_obj in collision_objects:
				if not target_positions[tile_offset].has(col_obj):
					target_positions[tile_offset].append(col_obj)
		else:
			target_positions[tile_offset] = collision_objects.duplicate()
