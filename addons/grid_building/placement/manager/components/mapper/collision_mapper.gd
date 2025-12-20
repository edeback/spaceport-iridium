## Responsibilities:
## - Translate CollisionShape2D / CollisionPolygon2D geometry into tile offsets used by placement rules and indicators.
## - Apply filtering, normalization, and heuristics to remove slivers and normalize pivots for consistent indicators.
## - Provide caching and utility helpers consumed by IndicatorManager and the placement pipeline.
##
## See: [Collision Mapping guide](/latest/guides/collision_mapping/)
class_name CollisionMapper
extends GBInjectable

#region Internal dependencies
const _CollisionUtilities = preload("uid://842dmikaq7xu")
const _CollisionObjectResolver = preload("res://addons/grid_building/placement/manager/components/mapper/collision_object_resolver.gd")
#endregion

const MIN_POLY_TILE_OVERLAP_RATIO := 0.12

var _targeting_state: GridTargetingState
var indicator_contact_positions: Array = []
var test_indicator: RuleCheckIndicator

## Maps each CollisionObject2D to its CollisionTestSetup2D for collision testing.
var test_setups : Array[CollisionTestSetup2D] = []

var _logger : GBLogger

# Sub-objects
var _collision_processor: CollisionProcessor
var _object_resolver: CollisionObjectResolver

## [b]Factory[/b]
## Creates a CollisionMapper with injected dependencies and validates wiring.
## This is the preferred method for instantiating a CollisionMapper for test suites to avoid manual injection or instancing owning parent nodes.
## [b]Returns[/b]: CollisionMapper – a ready instance; logs warnings if injection issues are found.
static func create_with_injection(container: GBCompositionContainer) -> CollisionMapper:
	var targeting_state = container.get_targeting_state()
	var logger = container.get_logger()
	var mapper = CollisionMapper.new(targeting_state, logger)
	
	# Validate dependencies were properly injected
	var issues = mapper.get_runtime_issues()
	if not issues.is_empty():
		logger.log_warnings(issues)
	
	return mapper

## [b]Validation[/b]
## Returns a list of issues if required state is missing; empty when valid.
## [b]Returns[/b]: Array[String]
func get_runtime_issues() -> Array[String]:
	var issues: Array[String] = []
	if not _targeting_state:
		issues.append("GridTargetingState is not set")
	return issues

## [b]Constructor[/b]
## Inject targeting state and logger.
## [b]Parameters[/b]:
##  • [code]targeting_state[/code]: GridTargetingState – provides map and positioner.
##  • [code]p_logger[/code]: GBLogger – for diagnostics.
func _init(targeting_state: GridTargetingState, p_logger : GBLogger) -> void:
	_targeting_state = targeting_state
	_logger = p_logger
	_collision_processor = CollisionProcessor.new(p_logger)
	_object_resolver = _CollisionObjectResolver.new()

## [b]Manual Injection[/b]
## Resolve dependencies from the container after construction.
## Useful when the mapper is instantiated without the factory.
## [b]Returns[/b] - [i]bool[/i] - Whether the injection was successful or not
func resolve_gb_dependencies(container: GBCompositionContainer) -> bool:
	_targeting_state = container.get_targeting_state()
	_logger = container.get_logger()
	if _collision_processor:
		_collision_processor.resolve_gb_dependencies(container)
	return true

## [b]Setup[/b]
## Wire the test indicator and per-object collision test setups; invalidates internal caches.
## Call whenever either changes to ensure fresh geometry.
## [b]Parameters[/b]:
##  • [code]p_test_indicator[/code]: RuleCheckIndicator – the reusable indicator shape/owner.
##  • [code]p_collision_object_test_setups[/code]: Array[CollisionTestSetup2D] – precomputed shape info.
func setup(p_test_indicator: RuleCheckIndicator, p_collision_object_test_setups : Array[CollisionTestSetup2D]) -> void:
	test_setups.clear()
	
	test_indicator = p_test_indicator
	test_setups = p_collision_object_test_setups
	
	# Invalidate processor cache when setup changes
	_collision_processor.invalidate_cache()

## [b]Map collision positions to rules[/b]
## Builds a dictionary of [code]tile_offset -> [TileCheckRule][/code] by resolving tile coverage for each
## rule's collision layer mask and aggregating applicable rules at each tile.
## [b]Parameters[/b]:
##  • [code]col_objects[/code]: Array[Node2D] – CollisionObject2Ds and/or CollisionPolygon2Ds to consider.
##  • [code]tile_check_rules[/code]: Array[TileCheckRule] – rules with [code]apply_to_objects_mask[/code] used for filtering.
## [b]Returns[/b]: Dictionary[Vector2i, Array] – tile offset to list of rules that apply at that offset.
func map_collision_positions_to_rules(
	col_objects: Array[Node2D], # Includes ConvexPolygonShape2Ds
	tile_check_rules: Array[TileCheckRule]
) -> Dictionary[Vector2i, Array]:
	assert(_logger != null, "CollisionMapper: GBLogger is null. Ensure GBInjectorSystem is present in the scene or call resolve_gb_dependencies(container) / set_logger(p_logger) in your test setup.")
	assert(_targeting_state != null, "CollisionMapper: GridTargetingState is null. Ensure resolve_gb_dependencies(container) was called or pass targeting_state in constructor.")
	
	var map : Dictionary[Vector2i, Array] = {}

	if not _guard_setup_complete():
		return map

	# Diagnostics: log input objects and rules for debugging
	var dbg_msg = "map_collision_positions_to_rules: col_objects.size=%d, tile_check_rules.size=%d" % [col_objects.size(), tile_check_rules.size()]
	_logger.log_verbose( dbg_msg)

	for idx in range(col_objects.size()):
		var co = col_objects[idx]
		_logger.log_verbose( "col_object[%d]=%s" % [idx, str(co)])

	# If no rules are provided, perform a geometry-only mapping so callers can still
	# obtain positions. Use a default mask (1) which is the convention in tests.
	if tile_check_rules.is_empty():
		var default_mask := 1
		var positions_only := get_collision_tile_positions_with_mask(col_objects, default_mask)
		# Convert relative offsets (keys) to absolute tile positions by adding the positioner's tile.
		var pos_tile: Vector2i = _targeting_state.target_map.local_to_map(_targeting_state.target_map.to_local(_targeting_state.positioner.global_position))
		for rel_off in positions_only.keys():
			var abs_tile: Vector2i = rel_off + pos_tile
			map[abs_tile] = []
		return map

	for rule in tile_check_rules:
		var rule_info = "rule=%s, apply_to_objects_mask=%s" % [str(rule), str(rule.apply_to_objects_mask)]
		_logger.log_verbose( rule_info)

		var found_positions = get_collision_tile_positions_with_mask(
			col_objects, rule.apply_to_objects_mask)
		# Diagnostics: log number of positions found for this rule
		var found_count = found_positions.size() if found_positions else 0
		_logger.log_verbose( "rule found_positions_count=%d" % [found_count])

		# Convert relative offsets to absolute tile positions when publishing externally.
		var pos_tile: Vector2i = _targeting_state.target_map.local_to_map(_targeting_state.target_map.to_local(_targeting_state.positioner.global_position))
		for rel_off in found_positions.keys():
			var abs_tile: Vector2i = rel_off + pos_tile
			if map.has(abs_tile):
				map[abs_tile].append(rule)
			else:
				map[abs_tile] = [rule]

	return map


## [b]Resolve tile offsets with a collision mask[/b]
## Produces [code]tile_offset -> [Node2D][/code] by inspecting each source and applying collision layer filtering.
## Handles both CollisionShape2D and CollisionPolygon2D nodes by checking their parent CollisionObject2D for layer matching.
## Aggregates all sources with no preference and de-duplicates per tile.
## [b]Parameters[/b]:
##  • [code]col_objects[/code]: Array[Node2D] – CollisionShape2D and CollisionPolygon2D nodes to process
##  • [code]collision_mask[/code]: int – layer mask to match via the parent CollisionObject2D.
## [b]Returns[/b]: Dictionary[Vector2i, Array] – tile offset to list of contributing collision nodes.
func get_collision_tile_positions_with_mask(
	col_objects: Array[Node2D], collision_mask: int
) -> Dictionary[Vector2i, Array]:
	var colliding_tile_positions: Dictionary[Vector2i, Array] = {}

	# NOTE: Collision exclusions are NOT filtered here during indicator setup.
	# Exclusions are applied at runtime by CollisionsCheckRule._indicator_apply_target_exceptions()
	# which adds excluded nodes as ShapeCast2D exceptions on each indicator.
	# This ensures indicators can be created at all tile positions, but won't detect
	# collisions with excluded objects during validation.

	# Diagnostics: log detailed input summary
	_logger.log_verbose("get_collision_tile_positions_with_mask: col_objects=%d, collision_mask=%d" % [col_objects.size(), collision_mask])

	# Collect human-visible diagnostic lines for test runs (only shown if we find no positions)
	var diag_lines: Array = []
	for idx in range(col_objects.size()):
		var col_obj = col_objects[idx]
		_logger.log_verbose("  col_obj[%d]=%s" % [idx, str(col_obj)])

	for col_obj in col_objects:
		# Resolve the collision object and test setup
		var resolution = _object_resolver.resolve_collision_object(col_obj, test_setups)

		if not resolution.is_valid:
			_logger.log_warning_once(self, "CollisionMapper: " + resolution.error_message + ". Skipping collision processing.")
			diag_lines.append("%s:resolution_invalid:%s" % [str(col_obj), resolution.error_message])
			continue

		# Check if the collision object matches the layer mask
		var matches = _object_resolver.object_matches_layer_mask(resolution.collision_object, collision_mask)
		# Log layer/mask details for debugging
		var obj_layer := 0
		if resolution.collision_object and resolution.collision_object is CollisionObject2D:
			obj_layer = resolution.collision_object.collision_layer
		var mask_layers := PhysicsMatchingUtils2D.get_layers_from_bitmask(collision_mask)
		var obj_layers := PhysicsMatchingUtils2D.get_layers_from_bitmask(obj_layer)
		# Log detailed collision resolution
		_logger.log_verbose("  resolved collision_object=%s, collision_layer=%d, object_layers=%s, mask=%d, mask_layers=%s, test_setup=%s, matches_mask=%s" % [str(resolution.collision_object), obj_layer, str(obj_layers), collision_mask, str(mask_layers), str(resolution.test_setup), str(matches)])
		if not matches:
			_logger.log_verbose("  Collision object " + str(resolution.collision_object) + " does not match layer mask " + str(collision_mask) + ". Skipping.")
			# Also append detailed numeric layer/mask info for visible diagnostics
			diag_lines.append("%s:matches_mask=false:collision_layer=%d:object_layers=%s:mask=%d:mask_layers=%s" % [str(resolution.collision_object), obj_layer, str(obj_layers), collision_mask, str(mask_layers)])
			continue

		# Log collision processing
		_logger.log_verbose("Processing collision object: " + str(resolution.collision_object) + ", test_setup: " + str(resolution.test_setup))

		# Process the collision object based on its type
		var collision_tile_offsets = _get_tile_offsets_for_resolved_object(resolution.collision_object, resolution.test_setup)

		# Log tile offset diagnostics
		var offsets_count = collision_tile_offsets.size() if collision_tile_offsets else 0
		_logger.log_verbose("  Collision tile offsets for %s: %d tiles" % [str(resolution.collision_object), offsets_count])
		if offsets_count > 0:
			# show up to first 10 offsets for context
			var shown := []
			var i = 0
			for key in collision_tile_offsets.keys():
				if i >= 10:
					break
				shown.append(str(key))
				i += 1
			_logger.log_verbose("    sample_offsets=%s" % [str(shown)])
			diag_lines.append("%s:matches_mask=true:offsets=%d:sample=%s" % [str(resolution.collision_object), offsets_count, str(shown)])
		else:
			diag_lines.append("%s:matches_mask=true:offsets=0" % str(resolution.collision_object))

		# Aggregate results
		for pos in collision_tile_offsets.keys():
			if colliding_tile_positions.has(pos):
				colliding_tile_positions[pos].append(col_obj)
			else:
				colliding_tile_positions[pos] = [col_obj]

	# Final diagnostics
	_logger.log_verbose("get_collision_tile_positions_with_mask: final_tile_positions=%d" % [colliding_tile_positions.size()])
	if colliding_tile_positions.size() == 0:
		# Emit a visible warning with the collected diagnostics to help failing tests
		var msg = "CollisionMapper diagnostic: no tile positions computed. Details:\n" + "\n".join(diag_lines)
		push_warning(msg)

	return colliding_tile_positions


## Process a resolved collision object to get tile offsets
##
## @param collision_node: The original collision node (CollisionObject2D, CollisionShape2D, or CollisionPolygon2D)
## @param test_setup: The resolved CollisionTestSetup2D (may be null for CollisionPolygon2D)
## @return Dictionary[Vector2i, Array] of tile offsets
func _get_tile_offsets_for_resolved_object(collision_node: Node2D, test_setup: CollisionTestSetup2D) -> Dictionary[Vector2i, Array]:
	# Handle CollisionPolygon2D objects directly - they use polygon geometry processing
	if collision_node is CollisionPolygon2D:
		if not _targeting_state or not _targeting_state.target_map:
			push_error("CollisionMapper: Cannot process CollisionPolygon2D without valid targeting state and target map.")
			return {}
		_logger.log_verbose( "Processing CollisionPolygon2D: " + str(collision_node))
		return _collision_processor.get_tile_offsets_for_collision(collision_node, null, _targeting_state.target_map, _targeting_state.positioner)

	# Handle CollisionObject2D without test setups but with CollisionPolygon2D children
	if collision_node is CollisionObject2D and test_setup == null:
		var combined_results: Dictionary[Vector2i, Array] = {}
		for child in collision_node.get_children():
			if child is CollisionPolygon2D:
				_logger.log_verbose( "Processing CollisionPolygon2D child: " + str(child) + " of parent: " + str(collision_node))
				var child_offsets = _collision_processor.get_tile_offsets_for_collision(child, null, _targeting_state.target_map, _targeting_state.positioner)
				# Merge child results into combined results
				for pos in child_offsets.keys():
					if combined_results.has(pos):
						combined_results[pos].append_array(child_offsets[pos])
					else:
						combined_results[pos] = child_offsets[pos]
		return combined_results

	# Handle CollisionObject2D and CollisionShape2D with test setups
	if not test_setup:
		push_warning("CollisionMapper: No test setup available for " + collision_node.name + ". Skipping collision processing.")
		return {}

	# Log test setup details
	_logger.log_verbose("Processing CollisionObject2D with test setup: " + str(collision_node) + ", setup: " + str(test_setup))
	if test_setup:
		_logger.log_verbose("Test setup collision_object: " + str(test_setup.collision_object))
		_logger.log_verbose("Test setup shape_stretch_size: " + str(test_setup.shape_stretch_size))
		_logger.log_verbose("Test setup rect_collision_test_setups count: " + str(test_setup.rect_collision_test_setups.size()))
	return get_tile_offsets_for_test_collisions(test_setup)


## [b]Get tile offsets for a collision polygon[/b]
## Returns tile offsets for a CollisionPolygon2D or CollisionShape2D.
## [b]Parameters[/b]: [code]collision_obj[/code] – The collision object to process, [code]tile_map[/code] – The tile map to use for coordinate conversion.
## [b]Returns[/b]: Dictionary – tile positions mapped to collision objects.
func get_tile_offsets_for_collision_polygon(collision_obj: Node2D, tile_map: TileMapLayer) -> Dictionary[Vector2i, Array]:
	if not _targeting_state or not _targeting_state.target_map:
		push_error("CollisionMapper: Cannot process collision object without valid targeting state and target map.")
		return {}
	
	var collision_tile_offsets = _collision_processor.get_tile_offsets_for_collision(collision_obj, null, _targeting_state.target_map, _targeting_state.positioner)
	var result: Dictionary[Vector2i, Array] = {}
	
	for pos in collision_tile_offsets.keys():
		result[pos] = [collision_obj]
	
	return result


## [b]Resolve tile offsets for a single node[/b]
## Dispatch to polygon or shape path depending on the object type. Returns [code]offset -> owners[/code].
## [b]Parameters[/b]: [code]test_data[/code] – CollisionTestSetup2D for a CollisionObject2D or the polygon node.
## [b]Returns[/b]: Dictionary – offsets to contributing nodes for that source.
func get_tile_offsets_for_test_collisions(test_data: CollisionTestSetup2D) -> Dictionary[Vector2i, Array]:
	var collision_positions: Dictionary[Vector2i, Array] = {}
	assert(_logger != null, "CollisionMapper: GBLogger is null. Add GBInjectorSystem in the test scene or call mapper.resolve_gb_dependencies(container) / mapper.set_logger(p_logger) before invoking get_tile_offsets_for_test_collisions().")
	assert(_targeting_state != null, "CollisionMapper: GridTargetingState is null. Ensure resolve_gb_dependencies(container) was called or pass targeting_state in constructor.")
	
	# Validate input
	if not test_data:
		push_error("CollisionMapper: test_data is null. Cannot process collision test data.")
		return collision_positions
	
	if not test_data.collision_object:
		push_error("CollisionMapper: test_data.collision_object is null. Cannot process collision object.")
		return collision_positions
	
	# Validate state before proceeding
	var validation_issues = get_runtime_issues()
	if not validation_issues.is_empty():
		for issue in validation_issues:
			_logger.log_error( "CollisionMapper validation failed: " + issue)
		return collision_positions

	var col_obj = test_data.collision_object
	var map = _targeting_state.target_map

	# Handle CollisionPolygon2D using polygon-based geometry math
	if col_obj is CollisionPolygon2D:
		return _collision_processor.get_tile_offsets_for_collision(col_obj, null, map, _targeting_state.positioner)
	
	# Handle CollisionObject2D with shapes using shape-based geometry math
	return _collision_processor.get_tile_offsets_for_collision(col_obj, test_data, map, _targeting_state.positioner)

## [b]Absolute tiles overlapped by an axis‑aligned rectangle[/b]
## Returns absolute tile coordinates overlapped by a rectangle centered at a world position.
## Uses symmetric distribution to avoid half‑tile drift.
## [b]Parameters[/b]:
##  • [code]global_center_position[/code]: Vector2 – center in world space.
##  • [code]transformed_rect_size[/code]: Vector2 – rectangle size in world units.
## [b]Returns[/b]: Array[Vector2i]
func get_rect_tile_positions(global_center_position: Vector2, transformed_rect_size: Vector2) -> Array[Vector2i]:
	return _CollisionUtilities.get_rect_tile_positions(_targeting_state.target_map, global_center_position, transformed_rect_size)

## [b]Indicator ↔ Shape overlap[/b]
## Uses Godot’s native Shape2D API to test collision between indicator and a target shape.
## [b]Returns[/b]: bool – [code]true[/code] if overlapping.
func does_indicator_overlap_shape(
	tile_indicator: RuleCheckIndicator, shape: Shape2D, shape_owner: Node2D
) -> bool:
	return _CollisionUtilities.does_indicator_overlap_shape(tile_indicator, shape, shape_owner)

## [b]Guard: Setup Validation[/b]
## Checks if setup() has been called and logs warnings if incomplete.
## [b]Returns[/b]: bool – true if setup is complete, false otherwise (logs and prevents continuation).
func _guard_setup_complete() -> bool:
	# Do not block processing entirely when setup is incomplete. CollisionPolygon2D
	# can be processed without test_setups/test_indicator (polygon path uses direct math).
	# Keep the original warning for diagnostics but allow processing to continue so
	# polygon-only previews will still produce tile mappings.
	if test_indicator == null or test_setups == null or test_setups.is_empty():
		var reasons: Array[String] = []
		if test_indicator == null:
			reasons.append("test_indicator=null")
		if test_setups == null:
			reasons.append("test_setups=null")
		elif test_setups.is_empty():
			reasons.append("test_setups=empty")
		_logger.log_warning( "map_collision_positions_to_rules: setup incomplete: " + ", ".join(reasons))
		# Allow processing to continue to support CollisionPolygon2D-only workflows
		return true
	return true
