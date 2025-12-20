## IndicatorSetupUtils - Static utility functions for indicator setup operations.
##
## This class provides static utility functions for complex indicator setup logic
## that has been extracted from IndicatorService for better testability. All functions
## are static and do not depend on instance state, making them suitable for unit testing.
##
## Key Features:
## - Static functions for collision test setup building
## - Testing indicator creation and management
## - Indicator count calculation without side effects
## - Tile-based positioning using tile map layers
class_name IndicatorSetupUtils
extends RefCounted

## Returns a shared testing indicator, creating it if it doesn't exist.
## The testing indicator is used for collision setup and validation before creating
## real indicators. This method implements lazy initialization and is safe to call
## multiple times. The testing indicator is configured to suppress rule-ready logs
## and is named "_TestingIndicator" for easy identification.
##
## Parameters:
##   [code]indicator_template[/code]: [i]PackedScene[/i] - Template for creating the indicator
##   [code]parent_node[/code]: [i]Node[/i] - Parent node to attach the testing indicator to
##
## Returns:
##   [i]RuleCheckIndicator[/i] - The shared testing indicator instance, or null if creation fails
static func create_testing_indicator(indicator_template: PackedScene, parent_node: Node) -> RuleCheckIndicator:
	if not indicator_template or not parent_node:
		return null

	# Use the factory for consistent indicator creation (no rules, position at origin)
	var testing_indicator = IndicatorFactory.create_indicator(Vector2i.ZERO, [], indicator_template, parent_node)
	if testing_indicator:
		testing_indicator.name = "_TestingIndicator"
	return testing_indicator

## Calculates the number of indicators that would be created for a test object without actually creating them.
## This performs the same collision analysis as setup_indicators but stops before indicator creation.
##
## Parameters:
##   [code]test_object[/code]: [i]Node2D[/i] - The object being tested for placement
##   [code]tile_check_rules[/code]: [i]Array[TileCheckRule][/i] - Rules to create indicators for
##   [code]collision_mapper[/code]: [i]CollisionMapper[/i] - Collision mapper for position mapping
##   [code]indicator_template[/code]: [i]PackedScene[/i] - Template for testing indicator
##   [code]parent_node[/code]: [i]Node[/i] - Parent node for testing indicator
##
## Returns:
##   [i]int[/i] - The number of indicators that would be created, or -1 if calculation fails
static func calculate_indicator_count(
	test_object: Node2D,
	tile_check_rules: Array[TileCheckRule],
	collision_mapper: CollisionMapper,
	indicator_template: PackedScene,
	parent_node: Node
) -> int:
	if not test_object or not is_instance_valid(test_object):
		return 0

	if tile_check_rules.is_empty():
		return 0

	if not collision_mapper:
		return -1

	# 1) Gather all collision owners/shapes from the preview object
	var owner_shapes = GBGeometryUtils.get_all_collision_shapes_by_owner(test_object)

	if owner_shapes.is_empty():
		return 0

	# 2) Build collision test setups
	var indicator_test_setups = build_collision_test_setups_with_factory(owner_shapes, collision_mapper._targeting_state)
	var setups_array: Array[CollisionTestSetup2D] = []
	for setup in indicator_test_setups.values():
		if setup is CollisionTestSetup2D:
			setups_array.append(setup)

	# 3) Configure collision mapper with test setups
	var testing_indicator := create_testing_indicator(indicator_template, parent_node)
	if not testing_indicator:
		return -1

	collision_mapper.setup(testing_indicator, setups_array)

	# 4) Compute position-to-rules mapping (this determines indicator count)
	var position_rules_map: Dictionary = collision_mapper.map_collision_positions_to_rules(owner_shapes.keys(), tile_check_rules)

	return position_rules_map.size()

## Sets up collision mapper with test configurations for indicator setup.
## This is a static wrapper around the collision mapper setup process.
##
## Parameters:
##   [code]collision_mapper[/code]: [i]CollisionMapper[/i] - The collision mapper to configure
##   [code]testing_indicator[/code]: [i]RuleCheckIndicator[/i] - Testing indicator for setup
##   [code]test_setups[/code]: [i]Array[CollisionTestSetup2D][/i] - Test setups to configure
static func setup_collision_mapper(
	collision_mapper: CollisionMapper,
	testing_indicator: RuleCheckIndicator,
	test_setups: Array[CollisionTestSetup2D]
) -> void:
	if collision_mapper and testing_indicator and not test_setups.is_empty():
		collision_mapper.setup(testing_indicator, test_setups)

## Performs the complete indicator setup workflow for a test object.
## This is the core logic extracted from IndicatorService.setup_indicators for better testability.
## Handles collision shape gathering, test setup creation, collision mapping, and indicator generation.
##
## Parameters:
##   [code]test_object[/code]: [i]Node2D[/i] - The object being tested for placement
##   [code]tile_check_rules[/code]: [i]Array[TileCheckRule][/i] - Rules to create indicators for
##   [code]collision_mapper[/code]: [i]CollisionMapper[/i] - Collision mapper for position mapping
##   [code]indicator_template[/code]: [i]PackedScene[/i] - Template for indicator creation
##   [code]parent_node[/code]: [i]Node[/i] - Parent node for indicators
##   [code]targeting_state[/code]: [i]GridTargetingState[/i] - Grid targeting configuration
##
## Returns:
##   [i]SetupResult[/i] - Result containing generated indicators and diagnostic info
## Gathers collision shapes from a test object, organized by owner nodes.
## This is a wrapper around GBGeometryUtils for consistent API in tests.
##
## Parameters:
##   [code]test_object[/code]: [i]Node2D[/i] - Object to gather collision shapes from
##
## Returns:
##   [i]Dictionary[Node2D, Array][/i] - Dictionary mapping collision owners to their shapes
static func gather_collision_shapes(test_object: Node2D) -> Dictionary:
	if not test_object or not is_instance_valid(test_object):
		return {}
	
	return GBGeometryUtils.get_all_collision_shapes_by_owner(test_object)

## Builds collision test setups for collision owners.
## Creates test setups based on collision owner type and tile size configuration.
##
## Parameters:
##   [code]owner_shapes[/code]: [i]Dictionary[Node2D, Array][/i] - Collision owners and their shapes
##   [code]tile_size[/code]: [i]Vector2i[/i] - Grid tile size for calculations
##
## Returns:
##   [i]Dictionary[Node2D, CollisionTestSetup2D][/i] - Test setups mapped by collision owner
static func build_collision_test_setups(
	owner_shapes: Dictionary,
	tile_size: Vector2i
) -> Dictionary:
	if owner_shapes.is_empty():
		return {}
	
	var result: Dictionary = {}
	
	for owner in owner_shapes.keys():
		if owner is CollisionObject2D:
			# Create test setup with stretched collision shapes
			var setup = CollisionTestSetup2D.new(owner, Vector2(tile_size.x * 2.0, tile_size.y * 2.0))
			result[owner] = setup
		elif owner is CollisionPolygon2D:
			# CollisionPolygon2D gets null setup
			result[owner] = null
	
	return result

## Builds collision test setups using factory methods for better consistency.
## This version uses targeting state for more accurate tile size handling.
##
## Parameters:
##   [code]owner_shapes[/code]: [i]Dictionary[Node2D, Array][/i] - Collision owners and their shapes
##   [code]targeting_state[/code]: [i]GridTargetingState[/i] - Grid configuration state
##
## Returns:
##   [i]Dictionary[Node2D, CollisionTestSetup2D][/i] - Test setups mapped by collision owner
static func build_collision_test_setups_with_factory(
	owner_shapes: Dictionary,
	targeting_state: GridTargetingState
) -> Dictionary:
	return CollisionTestSetup2D.create_test_setups_for_collision_owners(owner_shapes, targeting_state)

## Maps collision positions to tile check rules using collision mapper.
## This function delegates to the collision mapper for position-to-rule mapping.
##
## Parameters:
##   [code]collision_mapper[/code]: [i]CollisionMapper[/i] - Mapper to use for position mapping
##   [code]owner_shapes[/code]: [i]Dictionary[Node2D, Array][/i] - Collision owners and shapes
##   [code]tile_check_rules[/code]: [i]Array[TileCheckRule][/i] - Rules to map positions to
##
## Returns:
##   [i]Dictionary[Vector2i, Array][/i] - Position to rules mapping
static func map_positions_to_rules(
	collision_mapper: CollisionMapper,
	owner_shapes: Dictionary,
	tile_check_rules: Array[TileCheckRule]
) -> Dictionary:
	if not collision_mapper or owner_shapes.is_empty() or tile_check_rules.is_empty():
		return {}
	
	return collision_mapper.map_collision_positions_to_rules(owner_shapes.keys(), tile_check_rules)

static func execute_indicator_setup(
	test_object: Node2D,
	tile_check_rules: Array[TileCheckRule],
	collision_mapper: CollisionMapper,
	indicator_template: PackedScene,
	parent_node: Node,
	targeting_state: GridTargetingState
) -> SetupResult:
	var result = SetupResult.new()
	
	# 1) Validate preconditions
	var validation_issues = validate_setup_preconditions(test_object, tile_check_rules, collision_mapper)
	if not validation_issues.is_empty():
		result.issues.append_array(validation_issues)
		return result
	
	# 2) Gather collision shapes from test object
	# Always gather ALL collision shapes - the collision_mask filtering in TileCheckRules
	# will handle which shapes are relevant for each rule
	var owner_shapes: Dictionary[Node2D, Array] = GBGeometryUtils.get_all_collision_shapes_by_owner(test_object)
	
	if owner_shapes.is_empty():
		result.issues.append("No collision shapes found on test object")
		return result
	
	# 3) Create testing indicator for collision mapping
	var testing_indicator = create_testing_indicator(indicator_template, parent_node)
	if not testing_indicator:
		result.issues.append("Failed to create testing indicator")
		return result
	
	# 4) Build collision test setups
	var test_setups = CollisionTestSetup2D.create_test_setups_for_collision_owners(owner_shapes, targeting_state)
	var setups_array: Array[CollisionTestSetup2D] = []
	for setup in test_setups.values():
		if setup is CollisionTestSetup2D:
			setups_array.append(setup)
	
	# 5) Configure collision mapper with test setups
	setup_collision_mapper(collision_mapper, testing_indicator, setups_array)
	
	# 6) Map collision positions to rules
	var position_rules_map: Dictionary[Vector2i, Array] = collision_mapper.map_collision_positions_to_rules(owner_shapes.keys(), tile_check_rules)

	# IMPORTANT CONTRACT NORMALIZATION:
	# CollisionMapper.map_collision_positions_to_rules() publishes ABSOLUTE tile positions as keys.
	# IndicatorFactory.generate_indicators() expects RELATIVE OFFSETS from the positioner tile.
	# Convert absolute keys to relative offsets from positioner.
	var normalized_map: Dictionary[Vector2i, Array] = {}
	if not position_rules_map.is_empty():
		var map_layer: TileMapLayer = targeting_state.target_map
		var positioner_tile: Vector2i = map_layer.local_to_map(map_layer.to_local(targeting_state.positioner.global_position))
		for abs_tile in position_rules_map.keys():
			var rel_off: Vector2i = abs_tile - positioner_tile
			normalized_map[rel_off] = position_rules_map[abs_tile]
		# Replace with normalized (relative) offsets for indicator generation
		position_rules_map = normalized_map
	
	# 7) Generate indicators using factory
	var indicators = IndicatorFactory.generate_indicators(
		position_rules_map,
		indicator_template,
		parent_node,
		targeting_state,
		test_object  # Pass test_object for preview instance relative positioning
	)

	# 8) Clean up temporary testing nodes created during setup to avoid polluting subsequent runs
	#    This frees the Area2D/CollisionShape2D helpers created inside RectCollisionTestingSetup
	#    while keeping the CollisionTestSetup2D objects themselves for diagnostics in the report.
	for ts in setups_array:
		if ts != null:
			ts.free_testing_nodes()

	# 9) Clean up testing indicator
	if is_instance_valid(testing_indicator):
		testing_indicator.queue_free()
	
	result.indicators = indicators
	result.owner_shapes = owner_shapes
	result.position_rules_map = position_rules_map
	result.test_setups = setups_array
	
	return result

## Validates indicator positioning by checking if indicators are placed at expected tile positions.
## This utility helps verify that generated indicators are positioned correctly on the grid.
##
## Parameters:
##   [code]indicators[/code]: [i]Array[RuleCheckIndicator][/i] - Indicators to validate
##   [code]expected_positions[/code]: [i]Array[Vector2i][/i] - Expected tile positions
##   [code]targeting_state[/code]: [i]GridTargetingState[/i] - Grid configuration for position calculations
##
## Returns:
##   [i]PositionValidationResult[/i] - Result containing validation status and mismatches
static func validate_indicator_positions(
	indicators: Array[RuleCheckIndicator],
	expected_positions: Array[Vector2i],
	targeting_state: GridTargetingState
) -> PositionValidationResult:
	var result = PositionValidationResult.new()
	
	if indicators.size() != expected_positions.size():
		result.is_valid = false
		result.size_mismatch = true
		result.expected_count = expected_positions.size()
		result.actual_count = indicators.size()
		return result
	
	# Check each indicator's position
	for i in range(indicators.size()):
		var indicator = indicators[i]
		var expected_tile_pos = expected_positions[i]
		
		# Convert indicator's world position to tile position
		var actual_tile_pos = targeting_state.target_map.local_to_map(targeting_state.target_map.to_local(indicator.global_position))
		
		if actual_tile_pos != expected_tile_pos:
			result.is_valid = false
			result.position_mismatches.append({
				"indicator_index": i,
				"expected": expected_tile_pos,
				"actual": actual_tile_pos,
				"world_position": indicator.global_position
			})
	
	result.is_valid = result.position_mismatches.is_empty() and not result.size_mismatch
	return result

## Validates basic setup preconditions for indicator generation.
## Checks that all required parameters are valid before attempting setup.
##
## Parameters:
##   [code]test_object[/code]: [i]Node2D[/i] - Object to validate
##   [code]tile_check_rules[/code]: [i]Array[TileCheckRule][/i] - Rules to validate
##   [code]collision_mapper[/code]: [i]CollisionMapper[/i] - Collision mapper to validate
##
## Returns:
##   [i]Array[String][/i] - List of validation issues (empty if valid)
static func validate_setup_preconditions(
	test_object: Node2D,
	tile_check_rules: Array[TileCheckRule],
	collision_mapper: CollisionMapper
) -> Array[String]:
	var issues: Array[String] = []
	
	if not test_object or not is_instance_valid(test_object):
		issues.append("Test object is null or invalid")
	
	if tile_check_rules.is_empty():
		issues.append("No tile check rules provided")
	
	if not collision_mapper:
		issues.append("Collision mapper is not available")
	
	return issues

## Result class for indicator setup operations
class SetupResult extends RefCounted:
	var indicators: Array[RuleCheckIndicator] = []
	var owner_shapes: Dictionary = {}
	var position_rules_map: Dictionary = {}
	var test_setups: Array[CollisionTestSetup2D] = []
	var issues: Array[String] = []
	
	func has_issues() -> bool:
		return not issues.is_empty()
	
	func is_successful() -> bool:
		return not has_issues() and not indicators.is_empty()

## Result class for position validation operations
class PositionValidationResult extends RefCounted:
	var is_valid: bool = true
	var size_mismatch: bool = false
	var expected_count: int = 0
	var actual_count: int = 0
	var position_mismatches: Array = []
	
	func get_mismatch_summary() -> String:
		if size_mismatch:
			return "Size mismatch: expected %d indicators, got %d" % [expected_count, actual_count]
		elif not position_mismatches.is_empty():
			return "%d position mismatches detected" % position_mismatches.size()
		else:
			return "All positions valid"
