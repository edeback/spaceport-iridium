## IndicatorService - Service component for managing rule-check indicators within IndicatorManager.
##
## This class is a service component that IndicatorManager uses to handle the creation, placement,
## and lifecycle management of RuleCheckIndicator instances. It encapsulates the complex logic
## for indicator setup, collision mapping, and diagnostic reporting while providing a clean
## interface for IndicatorManager to delegate indicator-related operations.
##
## ## Architecture Role
## IndicatorService acts as a specialized component within the IndicatorManager architecture:
## - **IndicatorManager**: Main coordinator that owns and orchestrates indicator operations
## - **IndicatorService**: Service component that handles the detailed implementation
## - **IndicatorFactory**: Pure logic class for indicator creation and validation
##
## ## Key Responsibilities
## - Execute indicator setup workflows with collision mapping and validation
## - Manage indicator lifecycle including creation, positioning, and cleanup
## - Provide diagnostic capabilities and comprehensive error reporting
## - Handle collision detection integration with CollisionMapper
## - Generate detailed setup reports for testing and debugging
##
## ## Usage Pattern
## ```
## var service = IndicatorService.create_with_injection(container, parent_node)
## var report = service.setup_indicators(test_object, rules, parent_node)
## var indicators = service.get_indicators()
## service.reset()
## ```
##
## For detailed usage guide and examples, see: docs_website/docs/systems/indicator_manager_guide.md
##
## Responsibilities:
## - Execute indicator setup workflows with collision mapping and validation
## - Manage indicator lifecycle including creation, positioning, and cleanup
## - Provide diagnostic capabilities and comprehensive error reporting
## - Handle collision detection integration with CollisionMapper
## - Generate detailed setup reports for testing and debugging
## - Maintain indicator state and provide access to managed indicators
## - Support comprehensive reset functionality with orphaned indicator detection
##
## Key Features:
## - Comprehensive reset() function with critical cleanup logging and orphaned indicator detection
## - Guarded indicator setup with detailed error reporting and diagnostic metadata
## - Collision mapper integration with test setup management and validation
## - Grid alignment utilities for stable geometry calculations
## - Diagnostic information reporting for debugging indicator state and issues
## - Dependency injection support with comprehensive validation
## - Signal emission for indicator state changes to support reactive programming
class_name IndicatorService
extends GBInjectable

## Emitted when the active RuleCheckIndicators change. Usually in response
## to a placement or move action that needs rule evaluation for TileCheckRules.
## Also emitted during reset operations when indicators are cleared.
signal indicators_changed(_indicators: Array[RuleCheckIndicator])

var _indicators: Array[RuleCheckIndicator] = []
var _collision_mapper : CollisionMapper
var _testing_indicator: RuleCheckIndicator
var _indicator_template: PackedScene
var _targeting_state: GridTargetingState
var _logger : GBLogger
var _indicator_contact_positions: Array = []
var _indicators_parent : Node
var _starting_rotation : float
var _starting_scale : Vector2

func _init(p_indicators_parent : Node, p_targeting_state: GridTargetingState, p_indicator_template : PackedScene, p_logger : GBLogger) -> void:
	_indicators_parent = p_indicators_parent
	_indicator_template = p_indicator_template
	_targeting_state = p_targeting_state
	_logger = p_logger
	# Create CollisionMapper through dependency injection if available, fallback to direct instantiation
	_collision_mapper = CollisionMapper.new(_targeting_state, _logger)
	
## Creates an IndicatorService with dependency injection from container.
## Container serves as single source of truth for all dependencies.
## This method handles the complete setup including dependency resolution,
## validation, and logging of any issues found during initialization.
##
## Parameters:
##   [code]container[/code]: [i]GBCompositionContainer[/i] - The dependency container providing all required services
##   [code]parent[/code]: [i]Node2D[/i] - The parent node for indicators (required - cannot be resolved from container)
##
## Returns:
##   [i]IndicatorService[/i] - Fully configured indicator service with validated dependencies
##
## Note: Callers should check get_runtime_issues() after creation to handle any validation warnings.
static func create_with_injection(container: GBCompositionContainer, parent: Node) -> IndicatorService:
	# Get dependencies from container as single source of truth
	var targeting_state = container.get_targeting_state()
	var logger = container.get_logger()
	var template = container.get_templates().rule_check_indicator
	
	var manager = IndicatorService.new(parent, targeting_state, template, logger)
	
	# Inject dependencies into the manager itself
	manager.resolve_gb_dependencies(container)
	
	# Validate dependencies were properly injected
	var issues = manager.get_runtime_issues()
	if not issues.is_empty():
		logger.log_warnings(issues)
	
	return manager

## Resolves dependencies from the composition container.
## This method is called during initialization and can be called again if the container
## becomes available later. Primarily used to inject dependencies into the collision mapper.
##
## Parameters: [br]
##   [code]container[/code]: [i]GBCompositionContainer[/i] - The dependency container to resolve dependencies from
## [b]Returns[/b]: [i]bool[/i] - True if dependencies were successfully resolved, false otherwise
func resolve_gb_dependencies(container: GBCompositionContainer) -> bool:
	var collision_mapper_injected : bool = _collision_mapper.resolve_gb_dependencies(container)
	return collision_mapper_injected

## Forces all managed indicators to update their shapecast collision detection.
## This is useful when the scene state has changed and indicators need to recalculate
## their collision status without regenerating the indicators themselves.
## Only processes indicators that are still valid instances.
func force_update() -> void:
	for indicator in _indicators:
		if is_instance_valid(indicator):
			indicator.force_shapecast_update()

## Validates that all required dependencies and state are properly set.
## Performs comprehensive validation of the indicator service's internal state
## including parent node validity, template availability, targeting state readiness,
## logger availability, and collision mapper dependency issues.
##
## Returns:
##   [i]Array[String][/i] - List of validation issues (empty if all dependencies are valid)
##
## Note: This method is non-mutating and safe to call frequently for diagnostic purposes.
func get_runtime_issues() -> Array[String]:
	var issues: Array[String] = []
	
	if not _indicators_parent:
		issues.append("Indicators parent node is not set")
	elif not is_instance_valid(_indicators_parent):
		issues.append("Indicators parent node is not valid")
	
	if not _indicator_template:
		issues.append("Indicator template is not set")
	elif not is_instance_valid(_indicator_template):
		issues.append("Indicator template is not valid")
	
	if not _targeting_state:
		issues.append("GridTargetingState is not set")
	
	if not _logger:
		issues.append("GBLogger is not set")
	
	if _collision_mapper:
		issues.append_array(_collision_mapper.get_runtime_issues())
	
	return issues
	
## Performs comprehensive cleanup of all managed indicators and test setups.
## This enhanced reset function provides critical cleanup logging and orphaned indicator
## detection to prevent test pollution and ensure proper teardown.
##
## Cleanup sequence:
## 1. Frees all managed indicators with proper validation
## 2. Clears collision mapper test setups
## 3. Cleans up testing indicator with extra validation
## 4. Detects and removes orphaned testing indicators from the scene tree
## 5. Emits indicators_changed signal to notify listeners
##
## Parameters:
##   [code]parent_node[/code]: [i]Node[/i] - Optional parent node to check for orphaned indicators
##
## Note: This method includes critical logging for debugging cleanup issues and
##       double-validation to ensure indicators array is properly cleared.
func reset(parent_node: Node = null) -> void:
	# CRITICAL: Ensure indicators array is cleared first to prevent stale references
	free_indicators(_indicators)
	
	# Double-check: Ensure indicators array is actually empty
	if not _indicators.is_empty():
		_logger.log_warning( "Indicators array not properly cleared after free_indicators. Forcing clear.")
		_indicators.clear()
		indicators_changed.emit(_indicators)
	
	# Clean up collision mapper test setups
	if _collision_mapper != null and not _collision_mapper.test_setups.is_empty():
		for test_setup in _collision_mapper.test_setups:
			if test_setup != null and test_setup.has_method("free_testing_nodes"):
				test_setup.free_testing_nodes()
		_collision_mapper.test_setups.clear()
		
	# Clear test indicator with extra validation
	if _testing_indicator != null:
		if is_instance_valid(_testing_indicator):
			# CRITICAL: Use free() instead of queue_free() for immediate cleanup
			# queue_free() is deferred and causes test isolation issues
			_testing_indicator.free()
		_testing_indicator = null
		
	# Additional cleanup: Check for any orphaned indicators that might still exist
	if parent_node != null:
		for child in parent_node.get_children():
			if child is RuleCheckIndicator and child.name.begins_with("_TestingIndicator"):
				_logger.log_warning( "Found orphaned testing indicator during reset: %s" % child.name)
				# CRITICAL: Use free() instead of queue_free() for immediate cleanup
				# queue_free() is deferred and causes test isolation issues when tests
				# run back-to-back in test suites - indicators persist into next test
				child.free()

## Returns a duplicate of the current indicators array for safe external use.
## This method provides read-only access to the managed indicators without
## allowing external modification of the internal indicators array.
##
## Returns:
##   [i]Array[RuleCheckIndicator][/i] - Duplicate of current indicators (safe for external iteration)
func get_indicators() -> Array[RuleCheckIndicator]:
	return _indicators.duplicate()

## Returns diagnostic information about the current state of the indicator service.
## This method provides comprehensive diagnostic data useful for debugging indicator
## cleanup issues, test pollution, and understanding the current state of the service.
##
## The returned dictionary includes:
## - [code]indicators_count[/code]: Number of currently managed indicators
## - [code]has_testing_indicator[/code]: Whether a testing indicator exists
## - [code]testing_indicator_valid[/code]: Whether the testing indicator is a valid instance
## - [code]collision_mapper_setups_count[/code]: Number of collision mapper test setups
## - [code]orphaned_indicators[/code]: Array of orphaned indicators found (currently unused)
##
## Returns:
##   [i]Dictionary[/i] - Diagnostic information about the indicator service's current state
##
## Note: This method is non-mutating and safe to call for debugging purposes.
func get_diagnostic_info() -> Dictionary:
	var info = {
		"indicators_count": _indicators.size(),
		"has_testing_indicator": _testing_indicator != null,
		"testing_indicator_valid": is_instance_valid(_testing_indicator) if _testing_indicator else false,
		"collision_mapper_setups_count": 0,
		"orphaned_indicators": []
	}
	
	if _collision_mapper != null and not _collision_mapper.test_setups.is_empty():
		info["collision_mapper_setups_count"] = _collision_mapper.test_setups.size()
	
	# Check for orphaned indicators in the scene tree (only if this is a Node)
	# Note: IndicatorService is not a Node, so we can't directly access scene tree
	# This would need to be implemented differently if scene tree access is required
	
	return info

## Gets the collision mapper instance.
## [returns] The collision mapper instance.
func get_collision_mapper() -> CollisionMapper:
	return _collision_mapper

## Helper method to recursively find all RuleCheckIndicator nodes in the scene tree.
## Used internally for diagnostic purposes to locate indicator instances.
##
## Parameters:
##   [code]node[/code]: [i]Node[/i] - Root node to start the recursive search from
##   [code]result[/code]: [i]Array[/i] - Array to append found indicators to (modified in-place)
func _find_all_indicators(node: Node, result: Array) -> void:
	if node is RuleCheckIndicator:
		result.append(node)
	
	for child in node.get_children():
		_find_all_indicators(child, result)

func set_indicators(value: Array[RuleCheckIndicator]) -> void:
	if value == _indicators:
		return
	_indicators = value
	indicators_changed.emit(_indicators)
	
## Creates and positions rule check indicators for validation.
## This is the main method for setting up indicators based on a test object and tile check rules.
## The method performs comprehensive validation, collision mapping, and indicator generation
## with detailed error reporting and diagnostic metadata.
##
## Process overview:
## 1. Validates environment and inputs through guard checks
## 2. Normalizes positioning for stable geometry calculations
## 3. Gathers collision shapes from the test object
## 4. Sets up collision mapper with test configurations
## 5. Maps collision positions to applicable rules
## 6. Generates indicators using the factory pattern
## 7. Builds and returns comprehensive setup report
##
## Parameters:
##   [code]p_test_object[/code]: [code]Node2D[/code] - The object being tested for placement
##   [code]p_tile_check_rules[/code]: [code]Array[TileCheckRule][/code] - Rules to create indicators for
##   [code]parent_node[/code]: [code]Node[/code] - Parent node to attach indicators to
##
## Returns:
##   [i]IndicatorSetupReport[/i] - Contains created indicators plus diagnostic metadata
##
## Note: This method includes extensive logging and error handling to support debugging
##       and testing scenarios. It will return error reports instead of throwing exceptions.
func setup_indicators(p_test_object: Node2D, p_tile_check_rules: Array[TileCheckRule]) -> IndicatorSetupReport:
	var report := IndicatorSetupReport.new(p_tile_check_rules, _targeting_state, _indicator_template)
	if not report.validate_setup_environment(p_test_object):
		report.add_issue("setup_indicators: guard prevented indicator setup; report issues=" + str(report.issues))
		return report

	# DIAGNOSTIC: Log indicator setup inputs
	_logger.log_debug("setup_indicators: p_test_object=%s, rules_count=%d, template=%s, parent=%s" % [
		p_test_object.name if p_test_object else "null",
		p_tile_check_rules.size(),
		_indicator_template.resource_path if _indicator_template else "null",
		_indicators_parent.name if _indicators_parent else "null"
	])

	# Use static utility to execute the core setup logic
	var setup_result = IndicatorSetupUtils.execute_indicator_setup(
		p_test_object,
		p_tile_check_rules,
		_collision_mapper,
		_indicator_template,
		_indicators_parent,
		_targeting_state
	)
	
	# DIAGNOSTIC: Log setup result details
	_logger.log_debug("setup_indicators: setup_result has_issues=%s, indicators_count=%d, position_rules_map_size=%d" % [
		setup_result.has_issues(),
		setup_result.indicators.size(),
		setup_result.position_rules_map.size()
	])
	if setup_result.has_issues():
		for issue in setup_result.issues:
			_logger.log_warning("setup_indicators issue: %s" % issue)
	
	# Handle any issues from the setup
	if setup_result.has_issues():
		for issue in setup_result.issues:
			report.add_issue("setup_indicators: " + issue)
		return report
	
	# Update report with results
	report.owner_shapes = setup_result.owner_shapes
	var test_setups: Array[CollisionTestSetup2D] = setup_result.test_setups
	report.set_test_setups(test_setups)

	# Populate report with generated indicators and position/rules mapping
	# Try to reconcile newly generated indicators with existing managed indicators
	# to avoid unnecessary instantiation. This will reuse indicators that match
	# by tile position and update their rules, freeing the freshly created
	# duplicates when appropriate.
	var reconciled: Array[RuleCheckIndicator] = _reconcile_indicators(setup_result.indicators)
	report.indicators = reconciled
	report.position_rules_map = setup_result.position_rules_map
	report.tile_positions = setup_result.position_rules_map.keys()

	# Add indicators to service (manage lifecycle) - we've already reconciled
	set_indicators(report.indicators)
	
	# Log diagnostic information
	report.add_note("setup_indicators: computed position_rules_map with %d entries" % setup_result.position_rules_map.size())
	report.add_note("setup_indicators: completed")
	
	# Finalize and log
	report.finalize()
	_log_summary(report)
	return report

## Calculates the number of indicators that would be created for a test object without actually creating them.
## This performs the same collision analysis as setup_indicators but stops before indicator creation.
## [param p_test_object] The object to test for placement.
## [param p_tile_check_rules] The tile check rules to apply.
## [returns] The number of indicators that would be created, or -1 if calculation fails.
func calculate_indicator_count(p_test_object: Node2D, p_tile_check_rules: Array[TileCheckRule]) -> int:
	return IndicatorSetupUtils.calculate_indicator_count(
		p_test_object, 
		p_tile_check_rules, 
		_collision_mapper, 
		_indicator_template, 
		_indicators_parent
	)

## Builds per-owner collision test setups for CollisionMapper using utility function.
## Creates appropriate test setup configurations for different collision owner types.
## This is a convenience wrapper around IndicatorSetupUtils.build_collision_test_setups().
##
## Parameters:
##   [code]owner_shapes[/code]: [i]Dictionary[Node2D, Array][/i] - Mapping of collision owners to their shapes
##   [code]tile_size[/code]: [i]Vector2i[/i] - Size of tiles for positioning calculations
##
## Returns:
##   [i]Dictionary[/i] - Test setups keyed by collision owner
func build_collision_test_setups(owner_shapes: Dictionary, tile_size: Vector2i) -> Dictionary:
	return IndicatorSetupUtils.build_collision_test_setups(owner_shapes, tile_size)

## Builds collision test setups using targeting state for more accurate configuration.
## This variant uses the service's GridTargetingState for consistent tile size handling.
## This is a convenience wrapper around IndicatorSetupUtils.build_collision_test_setups_with_factory().
##
## Parameters:
##   [code]owner_shapes[/code]: [i]Dictionary[Node2D, Array][/i] - Mapping of collision owners to their shapes
##
## Returns:
##   [i]Dictionary[/i] - Test setups keyed by collision owner
func build_collision_test_setups_with_targeting_state(owner_shapes: Dictionary) -> Dictionary:
	return IndicatorSetupUtils.build_collision_test_setups_with_factory(owner_shapes, _targeting_state)

## Gathers collision shapes from a test object.
## This is a convenience wrapper around IndicatorSetupUtils.gather_collision_shapes().
##
## Parameters:
##   [code]test_object[/code]: [i]Node2D[/i] - Object to gather collision shapes from
##
## Returns:
##   [i]Dictionary[Node2D, Array][/i] - Mapping of collision owners to their shapes
func gather_collision_shapes(test_object: Node2D) -> Dictionary:
	return IndicatorSetupUtils.gather_collision_shapes(test_object)

## Validates indicator positions against expected positions.
## This is a convenience wrapper around IndicatorSetupUtils.validate_indicator_positions().
##
## Parameters:
##   [code]indicators[/code]: [i]Array[RuleCheckIndicator][/i] - Indicators to validate
##   [code]expected_positions[/code]: [i]Array[Vector2i][/i] - Expected tile positions
##
## Returns:
##   [i]IndicatorSetupUtils.PositionValidationResult[/i] - Validation result with details
func validate_indicator_positions(indicators: Array[RuleCheckIndicator], expected_positions: Array[Vector2i]) -> IndicatorSetupUtils.PositionValidationResult:
	return IndicatorSetupUtils.validate_indicator_positions(indicators, expected_positions, _targeting_state)

## Validates setup preconditions for indicator creation.
## This is a convenience wrapper around IndicatorSetupUtils.validate_setup_preconditions().
##
## Parameters:
##   [code]test_object[/code]: [i]Node2D[/i] - Object being tested for placement
##   [code]tile_check_rules[/code]: [i]Array[TileCheckRule][/i] - Rules to validate
##
## Returns:
##   [i]Array[String][/i] - List of validation issues (empty if all valid)
func validate_setup_preconditions(test_object: Node2D, tile_check_rules: Array[TileCheckRule]) -> Array[String]:
	return IndicatorSetupUtils.validate_setup_preconditions(test_object, tile_check_rules, _collision_mapper)

## Gets or creates a testing indicator using the utility function.
## Uses lazy initialization to create the testing indicator only when needed.
## This is a convenience wrapper around IndicatorSetupUtils.create_testing_indicator().
##
## Parameters:
##   [i]parent_node[/i] - The parent node for the testing indicator
##
## Returns:
##   [i]RuleCheckIndicator[/i] - The testing indicator instance, or null if creation fails
func get_or_create_testing_indicator(parent_node: Node) -> RuleCheckIndicator:
	if _testing_indicator == null or not is_instance_valid(_testing_indicator):
		_testing_indicator = IndicatorSetupUtils.create_testing_indicator(_indicator_template, parent_node)
	return _testing_indicator

## Returns array of indicators that are currently colliding with other objects.
## Filters all managed indicators to find only those with active collision states.
## This is useful for determining which placement positions are blocked or invalid.
##
## Returns:
##   [i]Array[RuleCheckIndicator][/i] - Array of indicators currently in collision state
##
## Note: Only includes indicators that are valid instances and have active collisions.
func get_colliding_indicators() -> Array[RuleCheckIndicator]:
	var colliding_indicators : Array[RuleCheckIndicator] = []
	for indicator in _indicators:
		if is_instance_valid(indicator) and indicator.is_colliding():
			colliding_indicators.append(indicator)
	return colliding_indicators

## Returns array of Node2D objects that are colliding with any indicators.
## Collects all unique collision objects from all colliding indicators.
## This provides a convenient way to identify which scene objects are blocking placement.
##
## Returns:
##   [i]Array[/i] - Array of unique [i]Node2D[/i] objects colliding with any managed indicators
##
## Note: Automatically deduplicates colliding nodes to avoid duplicates in the result.
func get_colliding_nodes() -> Array[Node2D]:
	var colliding_nodes: Array[Node2D] = []
	for indicator in get_colliding_indicators():
		var count = indicator.get_collision_count()
		for i in range(count):
			var collider = indicator.get_collider(i)
			if collider != null and not colliding_nodes.has(collider):
				colliding_nodes.append(collider)
	return colliding_nodes



## Adds new indicators to the managed collection.
## Appends the provided indicators to the internal indicators array and emits
## the indicators_changed signal to notify listeners of the change.
##
## Parameters:
##   [code]new_indicators[/code]: [i]Array[RuleCheckIndicator][/i] - New indicators to add to the collection
##
## Note: Safely handles null or empty arrays by returning early without modification.
func add_indicators(new_indicators: Array[RuleCheckIndicator]) -> void:
	if new_indicators == null or new_indicators.is_empty():
		return

	for indicator in new_indicators:
		if indicator == null:
			_logger.log_warning( "Attempted to add null indicator.")
			continue

		if indicator.rules.is_empty():
			_logger.log_warning( "Adding indicator with no rules: %s" % indicator)

		_indicators.append(indicator)

	indicators_changed.emit(_indicators)

## Frees and removes indicators from memory and scene tree.
## Enhanced cleanup method that properly handles indicator lifecycle management
## with validation and comprehensive cleanup logging.	
##
## Parameters:
##   [code]to_free[/code]: [i]Array[RuleCheckIndicator][/i] - Indicators to free and remove
##
## Note: Creates a copy of the array before clearing to avoid modification during iteration.
##       Includes validation and error logging for debugging cleanup issues.
func free_indicators(to_free: Array[RuleCheckIndicator]) -> void:
	if to_free == null or to_free.is_empty():
		return

	# Create a copy of the array before clearing to avoid modifying the array we're iterating over
	var indicators_to_free = to_free.duplicate()

	# Clear the indicators array immediately to prevent stale references
	_indicators.clear()
	indicators_changed.emit(_indicators)

	for indicator in indicators_to_free:
		if is_instance_valid(indicator):
			# Clear the indicator's rule references before freeing
			indicator.clear()
			
			# CRITICAL: Use free() instead of queue_free() for immediate cleanup
			# queue_free() is deferred and causes test isolation issues
			indicator.free()
		else:
			_logger.log_warning( "Attempted to free invalid indicator: %s" % indicator)
			
	# Verify the array is actually cleared
	if not _indicators.is_empty():
		_logger.log_error( "CRITICAL: Indicators array should be empty after free_indicators but contains %d items" % _indicators.size())
		_indicators.clear()
		indicators_changed.emit(_indicators)    

func clear_indicators() -> void:
	# Only log clear_indicators at verbose level to reduce test noise
	if OS.get_environment("GB_VERBOSE_INDICATORS") == "1":
		print("DEBUG: clear_indicators called")
	free_indicators(_indicators.duplicate())

## Helper function to determine if a tile position is at a corner and return appropriate suffix.
## Analyzes the current indicator positions to determine bounds and identifies corner positions.
##
## Parameters:
##   [code]tile_pos[/code]: [i]Vector2i[/i] - The tile position to check for corner status
##
## Returns:
##   [i]String[/i] - Corner abbreviation (TL, TR, BL, BR) or empty string if not a corner
func _get_corner_suffix(tile_pos: Vector2i) -> String:
	# Get all current indicator positions to find bounds
	if _indicators.is_empty():
		return ""
	
	# Find min/max tile positions among all indicators
	var min_x = tile_pos.x
	var max_x = tile_pos.x
	var min_y = tile_pos.y
	var max_y = tile_pos.y
	
	# Check existing indicators to determine current bounds
	for indicator in _indicators:
		if not is_instance_valid(indicator):
			continue
		var map = _targeting_state.target_map
		if map == null:
			continue
		var indicator_tile = map.local_to_map(map.to_local(indicator.global_position))
		min_x = min(min_x, indicator_tile.x)
		max_x = max(max_x, indicator_tile.x)
		min_y = min(min_y, indicator_tile.y)
		max_y = max(max_y, indicator_tile.y)
	
	# Determine corner position
	var is_left = (tile_pos.x == min_x)
	var is_right = (tile_pos.x == max_x)
	var is_top = (tile_pos.y == min_y)
	var is_bottom = (tile_pos.y == max_y)
	
	# Return corner abbreviation
	if is_top and is_left:
		return "TL"
	elif is_top and is_right:
		return "TR"
	elif is_bottom and is_left:
		return "BL"
	elif is_bottom and is_right:
		return "BR"
	else:
		return ""

func _log_summary(p_report : IndicatorSetupReport):
	_logger.log_verbose( "Indicator Setup Report Summary:")
	for note in p_report.notes:
		_logger.log_verbose( "%s" % note)


## Helper: compute tile position for an indicator using targeting state
func _get_indicator_tile_pos(indicator: RuleCheckIndicator):
	if indicator == null:
		return null
	# Access the target_map as a property; do not gate behind has_method (it's not a method)
	var map_layer = _targeting_state.target_map if _targeting_state else null
	if map_layer == null:
		return null
	return map_layer.local_to_map(map_layer.to_local(indicator.global_position))


## Reconcile newly created indicators with existing managed indicators.
## Strategy:
## - Build a map of existing indicators keyed by tile position
## - For each new indicator, compute its tile position; if an existing indicator
##   exists at that position, reuse it: clear its rules and add the rules from
##   the new indicator, update its global_position and visuals, then free the
##   newly created duplicate.
## - Any existing indicators not matched are freed.
## - Returns the final array of indicators managed by the service.
func _reconcile_indicators(new_indicators: Array[RuleCheckIndicator]) -> Array[RuleCheckIndicator]:
	var final_indicators: Array[RuleCheckIndicator] = []

	# Build lookup of existing indicators by tile position
	var existing_by_pos := {}
	for ind in _indicators:
		if not is_instance_valid(ind):
			continue
		var pos = _get_indicator_tile_pos(ind)
		if pos != null:
			existing_by_pos[pos] = ind

	var reused_existing := []

	# Process newly generated indicators
	for new_ind in new_indicators:
		if not is_instance_valid(new_ind):
			continue
		var new_pos = _get_indicator_tile_pos(new_ind)
		var used: RuleCheckIndicator = null
		if new_pos != null and existing_by_pos.has(new_pos):
			used = existing_by_pos[new_pos]
			# Remove from lookup so we know it's matched
			existing_by_pos.erase(new_pos)

		if used != null and is_instance_valid(used):
			# Reuse existing indicator: update its position, rules and visuals
			used.clear()
			# Transfer rules from new_ind to used
			for r in new_ind.get_rules():
				used.add_rule(r)
			# Update transform/position to match the generated one
			used.global_position = new_ind.global_position
			# Remove the newly created duplicate from the scene and free it
			if is_instance_valid(new_ind):
				var p = new_ind.get_parent()
				if p != null:
					p.remove_child(new_ind)
				# CRITICAL: Use free() for immediate cleanup
				new_ind.free()
			final_indicators.append(used)
			reused_existing.append(used)
		else:
			# No existing match - keep the newly created indicator
			final_indicators.append(new_ind)

	# Any remaining existing indicators that were not matched should be freed
	for pos_key in existing_by_pos.keys():
		var leftover = existing_by_pos[pos_key]
		if is_instance_valid(leftover):
			leftover.clear()
			# Remove from scene and free
			var p2 = leftover.get_parent()
			if p2 != null:
				p2.remove_child(leftover)
			# CRITICAL: Use free() for immediate cleanup
			leftover.free()

	return final_indicators
