## Unified Collision Processor
##
## Handles processing for both CollisionObject2D (with shapes) and CollisionPolygon2D.
## Converts collision geometry to relative tile offsets for indicator positioning.
##
## [b]CRITICAL:[/b] Must use positioner.global_position as coordinate reference to maintain
## relative offsets. Using collision object position causes positioning displacement.
##
## [b]📖 COMPLETE GUIDE:[/b] `/astro_docs/src/content/docs/internal/positioning-regression-fix-guide.mdx`
class_name CollisionProcessor
extends GBInjectable

const GeometryCacheManager = preload("uid://d0cdgiqycnh43")

var _cache_manager: GeometryCacheManager
var _logger: GBLogger

func _init(p_logger: GBLogger) -> void:
	_cache_manager = GeometryCacheManager.new()
	_logger = p_logger

## Invalidate all cached geometry data
func invalidate_cache() -> void:
	_cache_manager.invalidate_cache()

## Resolve dependencies from composition container
func resolve_gb_dependencies(container: GBCompositionContainer) -> bool:
	if container:
		_logger = container.get_logger()
		return true
	return false

## Get runtime validation issues
func get_runtime_issues() -> Array[String]:
	var issues: Array[String] = []
	if not _logger:
		issues.append("CollisionProcessor is missing GBLogger dependency")
	return issues

## Unified public method to process any collision object type
## Automatically detects the type and delegates to the appropriate handler
##
## [b]RETURN VALUE COORDINATE SYSTEM:[/b]
## Returns Dictionary[Vector2i, Array] where Vector2i keys are RELATIVE tile offsets
## from the positioner's tile position, NOT absolute world tile coordinates.
## 
## These offsets represent: "tiles relative to positioner where indicators should appear"
## IndicatorFactory will convert them back to world positions as:
## indicator_position = positioner.global_position + (offset * tile_size)
##
## @param collision_obj: The collision object to process (CollisionObject2D or CollisionPolygon2D)
## @param test_data: CollisionTestSetup2D for CollisionObject2D (null for CollisionPolygon2D)
## @param map: The TileMapLayer to map offsets against
## @param positioner: The positioner node for coordinate transformations (CRITICAL for relative offsets)
## @return Dictionary[Vector2i, Array] containing RELATIVE tile offsets as keys and collision objects as values
func get_tile_offsets_for_collision(collision_obj: Node2D, test_data: CollisionTestSetup2D, map: TileMapLayer, positioner: Node2D) -> Dictionary[Vector2i, Array]:
	var collision_positions: Dictionary[Vector2i, Array] = {}

	# Validate inputs - return empty for invalid cases to be defensive
	if not collision_obj:
		return collision_positions

	if not map:
		return collision_positions

	if not map.tile_set:
		return collision_positions

	# Route to appropriate handler based on object type

	_logger.log_verbose("[CollisionProcessor] get_tile_offsets_for_collision - obj=%s, type=%s, positioner=%s, map=%s" % [str(collision_obj), typeof(collision_obj), str(positioner), str(map)])

	if collision_obj is CollisionPolygon2D:
		if not positioner:
			return collision_positions
		return _get_tile_offsets_for_collision_polygon(collision_obj, map, positioner)
	elif collision_obj is CollisionObject2D:
		if not test_data:
			return collision_positions
		if not positioner:
			return collision_positions
		return _get_tile_offsets_for_collision_object(test_data, map, positioner)
	else:
		# Unsupported collision object type - return empty
		return collision_positions

## Handle CollisionPolygon2D processing
## Uses positioner as coordinate reference for consistent positioning behavior
func _get_tile_offsets_for_collision_polygon(polygon_node: CollisionPolygon2D, map: TileMapLayer, positioner: Node2D) -> Dictionary[Vector2i, Array]:
	var collision_positions: Dictionary[Vector2i, Array] = {}

	# CRITICAL: Use positioner position as coordinate reference for consistency
	# Instrumentation: capture diagnostic ProcessingResult and log it for test diagnostics
	var proc_result := PolygonTileMapper.process_polygon_with_diagnostics(polygon_node, map)

	# Log diagnostics for polygon processing
	_logger.log_verbose("Polygon processing result: %s" % str(proc_result)) 

	var offsets: Array[Vector2i] = PolygonTileMapper.compute_tile_offsets_with_positioner(polygon_node, map, positioner)

	# Diagnostic logging for polygon offsets
	_logger.log_verbose("[CollisionProcessor] polygon offsets_count=%d, offsets=%s" % [offsets.size(), str(offsets)])

	for off in offsets:
		collision_positions[off] = [polygon_node]
	return collision_positions

## Handle CollisionObject2D with shapes processing
## [b]CRITICAL:[/b] Returns offsets relative to positioner position for correct indicator placement.
## See positioning-regression-fix-guide.mdx for coordinate system details.
func _get_tile_offsets_for_collision_object(test_data: CollisionTestSetup2D, map: TileMapLayer, positioner: Node2D) -> Dictionary[Vector2i, Array]:
	var collision_positions: Dictionary[Vector2i, Array] = {}

	if not _initialize_collision_mapping(positioner, collision_positions):
		return collision_positions

	var col_obj = test_data.collision_object
	
	# CRITICAL: Use positioner position as coordinate reference (not collision object position)
	# This ensures returned offsets are relative to where IndicatorFactory expects them.
	var center_tile = map.local_to_map(map.to_local(positioner.global_position))
	
	var tile_size = Vector2(map.tile_set.tile_size)
	var shape_epsilon = 0.035
	var tile_shape: TileSet.TileShape = map.tile_set.tile_shape

	for rect_test_setup in test_data.rect_collision_test_setups:
		var shape_positions = process_shape_offsets(rect_test_setup, test_data, map, center_tile, tile_size, shape_epsilon, col_obj)
		_merge_collision_positions(collision_positions, shape_positions)

	return collision_positions

## Initialize collision mapping with validation
func _initialize_collision_mapping(positioner: Node2D, collision_positions: Dictionary[Vector2i, Array]) -> bool:
	if not positioner:
		return false
	return true

## Process shape offsets for a single collision test setup
##
## [b]COORDINATE MIXING ZONE:[/b] 
## This method combines absolute world coordinates (for collision detection) 
## with relative tile coordinates (for return values). The center_tile parameter 
## is the key bridge between these coordinate systems.
##
## [b]ABSOLUTE WORLD COORDINATES (used internally):[/b]
## - shape_transform.origin: collision object's world position 
## - tile_center_world, tile_top_left_world: world coordinates for overlap testing
## - All geometric calculations happen in world space for accuracy
##
## [b]RELATIVE TILE COORDINATES (return values):[/b]
## - tile_pos - center_tile: converts world tile positions to relative offsets
## - These offsets will be added to positioner position by IndicatorFactory
func process_shape_offsets(rect_test_setup: RectCollisionTestingSetup, test_data: CollisionTestSetup2D, map: TileMapLayer, center_tile: Vector2i, tile_size: Vector2, shape_epsilon: float, col_obj: CollisionObject2D) -> Dictionary[Vector2i, Array]:
	var shape_positions: Dictionary[Vector2i, Array] = {}
	var shape_owner = rect_test_setup.shape_owner

	for shape in rect_test_setup.shapes:
		var shape_transform = CollisionGeometryUtils.build_shape_transform(col_obj, shape_owner)
		var shape_polygon = GBGeometryMath.convert_shape_to_polygon(shape, shape_transform)
		var bounds = _cache_manager.get_cached_polygon_bounds(shape_polygon)

		var tile_range = calculate_tile_range(shape, bounds, map, tile_size, shape_transform)
		var start_tile = tile_range["start"]
		var end_exclusive = tile_range["end_exclusive"]

		var shape_offsets = compute_shape_tile_offsets(shape, shape_transform, map, tile_size, shape_epsilon, start_tile, end_exclusive, center_tile, shape_polygon)

		_merge_offsets_into_positions(shape_offsets, shape_positions, col_obj, center_tile)

	return shape_positions

## Calculate the tile range that needs to be checked for a shape
## Returns a dictionary with 'start' and 'end_exclusive' Vector2i values
func calculate_tile_range(shape: Shape2D, bounds: Rect2, map: TileMapLayer, tile_size: Vector2, shape_transform: Transform2D) -> Dictionary:
	var min_local = map.to_local(bounds.position)
	var max_local = map.to_local(bounds.position + bounds.size)
	var start_tile = Vector2i(
		int(floor(min_local.x / tile_size.x)),
		int(floor(min_local.y / tile_size.y))
	)
	var end_exclusive = Vector2i(
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
		var eff_size = bounds.size
		var shape_center_tile = map.local_to_map(map.to_local(shape_transform.origin))
		var adjusted = GBCollisionTileFilter.adjust_rect_tile_range(eff_size, tile_size, shape_center_tile, start_tile, end_exclusive)
		start_tile = adjusted["start"]
		end_exclusive = adjusted["end_exclusive"]
	
	return {
		"start": start_tile,
		"end_exclusive": end_exclusive
	}

## Compute which tiles a shape overlaps with, returning offset positions
func compute_shape_tile_offsets(shape: Shape2D, shape_transform: Transform2D, map: TileMapLayer, tile_size: Vector2, shape_epsilon: float, start_tile: Vector2i, end_exclusive: Vector2i, center_tile: Vector2i, shape_polygon: PackedVector2Array) -> Array[Vector2i]:
	# New unified path: delegate to CollisionGeometryUtils to compute polygon→tile offsets.
	# This ensures identical behavior to polygon processing and fixes missing edge tiles
	# (e.g., trapezoid bottom-left (-2, -1)) observed in the bespoke per-tile scan.
	var tile_shape: TileSet.TileShape = map.tile_set.tile_shape
	# shape_polygon is expected in world coordinates (built via build_shape_transform above)
	var shape_offsets: Array[Vector2i] = CollisionGeometryUtils.compute_polygon_tile_offsets(
		shape_polygon, tile_size, center_tile, tile_shape, map
	)

	# Debug: only log detailed tile offset calculations at VERBOSE level to reduce test noise
	_logger.log_verbose("compute_shape_tile_offsets -> start_tile=%s end_exclusive=%s center_tile=%s produced_offsets=%s" % [str(start_tile), str(end_exclusive), str(center_tile), str(shape_offsets)])

	return shape_offsets

## Merge offsets into positions with center tile conversion
##
## [b]FINAL COORDINATE VALIDATION:[/b]
## At this point, shape_offsets contains relative tile offsets (Vector2i) 
## calculated as (tile_pos - center_tile) where center_tile is based on 
## positioner.global_position. These offsets are ready for IndicatorFactory 
## to convert back to world positions as: positioner_position + (offset * tile_size)
func _merge_offsets_into_positions(shape_offsets: Array[Vector2i], collision_positions: Dictionary[Vector2i, Array], col_obj: Node2D, center_tile: Vector2i) -> void:
	# Keep keys as relative offsets (tile_pos - center_tile). IndicatorFactory
	# expects relative offsets and will convert them back to absolute tiles
	# by adding the positioner's tile coordinate.
	for off in shape_offsets:
		if collision_positions.has(off):
			if not collision_positions[off].has(col_obj):
				collision_positions[off].append(col_obj)
		else:
			collision_positions[off] = [col_obj]

	# Diagnostic: only log merge summary at verbose level to reduce test noise
	if shape_offsets.size() > 0:
		_logger.log_verbose("[CollisionProcessor] merged_offsets_count= %d, sample_offset=%s, total_positions=%d" % [shape_offsets.size(), str(shape_offsets[0]), collision_positions.size()])
		# Print a compact list of offsets (limit to first 40 to avoid huge logs)
		var sample_list = shape_offsets
		if sample_list.size() > 40:
			sample_list = sample_list.slice(0, 40)
		_logger.log_verbose("[CollisionProcessor] merged_offsets_list_sample=%s" % str(sample_list))

## Merge two collision position dictionaries
func _merge_collision_positions(target_positions: Dictionary[Vector2i, Array], source_positions: Dictionary[Vector2i, Array]) -> void:
	for tile_offset in source_positions.keys():
		var collision_objects = source_positions[tile_offset]
		if target_positions.has(tile_offset):
			for col_obj in collision_objects:
				if not target_positions[tile_offset].has(col_obj):
					target_positions[tile_offset].append(col_obj)
		else:
			target_positions[tile_offset] = collision_objects.duplicate()
