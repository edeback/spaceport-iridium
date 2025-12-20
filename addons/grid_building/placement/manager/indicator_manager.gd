## Manages placement validation and indicator visualization for grid-based object placement.
##
## Coordinates the creation, validation, and display of placement indicators, integrating
## with rule-based validation systems to provide visual feedback on valid or invalid
## placement locations. Emits signals to notify changes in indicator states.
class_name IndicatorManager
extends GBNode2D

## Emitted when the active placement indicators are updated.
signal indicators_changed(indicators: Array[RuleCheckIndicator])

const DEFAULT_NAME = "IndicatorManager"

## Whether the manager has been initalized yet or not
var initialized : bool = false

# Dependencies injected via resolve_gb_dependencies or _init
var _indicator_context: IndicatorContext = null
var _owner_context : GBOwnerContext
var _logger: GBLogger = null
var _indicator_template: PackedScene = null
var _targeting_state: GridTargetingState = null
var _manipulation_state: ManipulationState = null

#region Subsystem Components
var _indicator_service: IndicatorService
var _placement_validator: PlacementValidator = null
var _test_setup_factory: TestSetupFactory = null
var _last_setup_test_object: Node = null
#endregion

## Creates an IndicatorManager with dependencies injected from the provided container.
## [param container] The dependency injection container.
## [param parent] Optional parent node to attach the IndicatorManager to.
## [returns] A configured IndicatorManager instance.
static func create_with_injection(container: GBCompositionContainer, parent: Node = null) -> IndicatorManager:
	var instance = IndicatorManager.new()
	# Store explicit parent as potential manipulation parent fallback before dependency resolution
	instance.resolve_gb_dependencies(container)
	if parent != null:
		# If auto_free or test harness already parented the instance elsewhere, reparent cleanly
		if instance.get_parent() != parent:
			if instance.get_parent():
				instance.get_parent().remove_child(instance)
			parent.add_child(instance)
	return instance

## Validates required dependencies and returns any issues found.
## [returns] An array of issue strings (empty if valid).
func get_runtime_issues() -> Array[String]:
	var issues: Array[String] = []
	
	if _indicator_context == null:
		issues.append("IndicatorContext is not set")
	if _logger == null:
		issues.append("GBLogger is not set")
	if _indicator_template == null:
		issues.append("Indicator template (rule_check_indicator) not set")
	if _targeting_state == null:
		issues.append("GridTargetingState is not set")
	else:
		issues.append_array(_targeting_state.get_runtime_issues())
			
	if _placement_validator == null:
		issues.append("PlacementValidator not initialized")
	if _indicator_service == null:
		issues.append("IndicatorService not initialized")
	return issues

func _init() -> void:
	name = DEFAULT_NAME

## Resolves and injects dependencies from the composition container.
## [param p_container] The dependency injection container.
func resolve_gb_dependencies(p_container: GBCompositionContainer) -> void:
	var context = p_container.get_contexts().indicator
	var owner_context = p_container.get_contexts().owner
	var logger = p_container.get_logger()
	var indicator_template = p_container.get_templates().rule_check_indicator
	var targeting_state = p_container.get_states().targeting
	var manipulation_state = p_container.get_states().manipulation
	var rules = p_container.get_placement_rules()
	initialize(context, owner_context, indicator_template, targeting_state, manipulation_state, logger, rules)

## Initializes the IndicatorManager with required dependencies.
## [param p_indicator_context] The placement context.
## [param p_indicator_template] The PackedScene for indicator instances.
## [param p_targeting_state] The grid targeting state.
## [param p_manipulation_state] The manipulation state for listening to cancellation signals.
## [param p_logger] The logging system.
## [param p_rules] The placement rules.
## [param p_messages] The message system.
## [param p_manipulation_parent] The manipulation parent node.
func initialize(
	p_indicator_context: IndicatorContext,
	p_owner_context: GBOwnerContext,
	p_indicator_template: PackedScene,
	p_targeting_state: GridTargetingState,
	p_manipulation_state: ManipulationState,
	p_logger: GBLogger,
	p_rules: Array[PlacementRule]
) -> void:
	_indicator_context = p_indicator_context
	_owner_context = p_owner_context
	_logger = p_logger
	_indicator_template = p_indicator_template
	_targeting_state = p_targeting_state
	_manipulation_state = p_manipulation_state

	if p_indicator_template == null:
		var error_msg = "CRITICAL: Indicator template is not set. Cannot generate placement indicators. "
		error_msg += "Check GBConfig.templates configuration."
		_logger.log_error( error_msg) if _logger else push_error(error_msg)
		return

	assert(_indicator_context != null, "IndicatorContext is null in IndicatorManager")
	_indicator_context.set_manager(self)
	
	_placement_validator = PlacementValidator.new(p_rules, p_logger)
	_test_setup_factory = TestSetupFactory.new(p_targeting_state, p_logger)
	_indicator_service = IndicatorService.new(self, p_targeting_state, p_indicator_template, p_logger)
	
	# Listen for manipulation cancellation to auto-cleanup indicators
	# Guard against duplicate connections (e.g., in tests that create multiple managers)
	if _manipulation_state != null:
		if not _manipulation_state.canceled.is_connected(_on_manipulation_canceled):
			_manipulation_state.canceled.connect(_on_manipulation_canceled)
	
	initialized = true

## Sets up placement indicators for a test object using specified tile check rules.
## [param p_test_object] The object to test for placement.
## [param p_tile_check_rules] The tile check rules to apply.
## [returns] An IndicatorSetupReport with indicators and diagnostic information.
func setup_indicators(p_test_object: Node2D, p_tile_check_rules: Array[TileCheckRule]) -> IndicatorSetupReport:
	if p_tile_check_rules.is_empty():
		if _indicator_service != null:
			_indicator_service.reset(self)

		var failure_report := IndicatorSetupReport.new(p_tile_check_rules, _targeting_state, _indicator_template)
		failure_report.add_issue("no tile check rules provided; aborting")
		return failure_report

	# Only reset the service (free indicators) when the preview/test object changes.
	# This allows reusing RuleCheckIndicator instances frame-to-frame for the same preview
	# which reduces allocations. When the passed test object is different from the
	# last one we saw, perform a full reset to avoid visual/pooling issues.
	if _indicator_service != null:
		if p_test_object != self._last_setup_test_object:
			_indicator_service.reset(self)
		# otherwise keep existing indicators for reuse
	queue_redraw()
	if _indicator_service == null:
		push_error("IndicatorService not assigned. Cannot setup indicators.")
		return null
	
	var report := _indicator_service.setup_indicators(p_test_object, p_tile_check_rules)
	# Track last test object used for reuse decisions
	self._last_setup_test_object = p_test_object
	return report

## Calculates the number of indicators that would be created for a test object without actually creating them.
## This is useful for performance-critical scenarios or UI calculations where you only need the count.
## [param p_test_object] The object to test for placement.
## [param p_tile_check_rules] The tile check rules to apply.
## [returns] The number of indicators that would be created, or -1 if calculation fails.
func get_indicator_count(p_test_object: Node2D, p_tile_check_rules: Array[TileCheckRule]) -> int:
	if p_tile_check_rules.is_empty():
		return 0

	if _indicator_service == null:
		push_error("IndicatorService not assigned. Cannot calculate indicator count.")
		return -1
	
	return _indicator_service.calculate_indicator_count(p_test_object, p_tile_check_rules)

## Returns the current active placement indicators.
## [returns] An array of RuleCheckIndicator instances.
func get_indicators() -> Array[RuleCheckIndicator]:
	return _indicator_service.get_indicators() if _indicator_service != null else []

## Returns indicators currently in collision.
## [returns] An array of colliding RuleCheckIndicator instances.
func get_colliding_indicators() -> Array[RuleCheckIndicator]:
	if _indicator_service:
		return _indicator_service.get_colliding_indicators()
	var empty_indicators : Array[RuleCheckIndicator] = []
	return empty_indicators
	
## Returns nodes colliding with any indicators.
## [returns] An array of Node2D instances in collision.
func get_colliding_nodes() -> Array[Node2D]:
	if _indicator_service:
		return _indicator_service.get_colliding_nodes()
	var empty_nodes : Array[Node2D] = []
	return empty_nodes

## Attempts to set up a placement action and returns a setup report.
## [param p_placeable_rules] The placement rules to apply.
## [param p_gts] The grid targeting state.
## [param p_ignore_base] Whether to ignore base rules.
## [returns] A PlacementReport with setup results.

func try_setup(p_placeable_rules: Array[PlacementRule], p_gts : GridTargetingState, p_ignore_base := false) -> PlacementReport:
	assert(initialized, "%s should be initialized before making try_setup calls." % self)
	tear_down()
	var combined_rules = _placement_validator.get_combined_rules(p_placeable_rules, p_ignore_base)
	_logger.log_verbose_once(self, "try_setup: Combined rules count: %d" % combined_rules.size())
	var validator_issues = _placement_validator.setup(combined_rules, p_gts)
	var target : Node = p_gts.target # Note: The node targeted during rule validation is the one being tested. This should absolutely be the node being placed.

	_log_target_diagnostics(target)

	if not validator_issues.is_empty():
		_logger.log_verbose( "try_setup: Validation failed with issues: %s" % str(validator_issues))
		return _build_failed_report(validator_issues, target)

	var tile_check_rules: Array[TileCheckRule] = []
	for rule : PlacementRule in combined_rules:
		if rule is TileCheckRule:
			tile_check_rules.append(rule)

	_logger.log_verbose( "try_setup: Setting up indicators for target %s with %d tile_check_rules" % [str(target), tile_check_rules.size()])
	var indicators_report: IndicatorSetupReport = null
	if target != null:
		indicators_report = setup_indicators(target, tile_check_rules)
	else:
		_logger.log_error( "try_setup: Cannot setup indicators, target must be set on the GridTargetingState before calling try_setup.")
	var report := PlacementReport.new(p_gts.get_owner(), target, indicators_report, GBEnums.Action.BUILD)

	_log_indicator_report(indicators_report)
	return report

#region Logging Helpers
func _log_target_diagnostics(target: Node) -> void:
	if target != null:
		_logger.log_verbose( "try_setup: target='%s' class='%s' children_count=%d" % [target.name, target.get_class(), target.get_child_count()])
	else:
		_logger.log_error( "try_setup: target is null after validator setup!")
	var child_list := []
	if target != null:
		for c in target.get_children():
			child_list.append("%s:%s" % [c.get_class(), c.name])
			# detect collision nodes
			if c is CollisionPolygon2D or c is CollisionShape2D or c.get_class().find("Collision") != -1:
				_logger.log_verbose( "try_setup: Found collision node under target -> %s:%s" % [c.get_class(), c.name])
	_logger.log_verbose( "try_setup: target children = %s" % str(child_list))

func _log_indicator_report(indicators_report: IndicatorSetupReport) -> void:
	if indicators_report != null:
		_logger.log_verbose( "Placement setup report: " + indicators_report.to_summary_string())
	else:
		_logger.log_error( "try_setup: indicators_report is null!")
#endregion

# Helper: Build a PlacementReport for failed validation with detailed issues
func _build_failed_report(validator_issues: Dictionary, target: Node) -> PlacementReport:
	var owner: GBOwner = _owner_context.get_owner() if _owner_context != null else null
	return PlacementReport.from_failed_validation(validator_issues, owner, target)

func clear():
	tear_down()
	_indicator_service.free_indicators(get_indicators())

## Resets the manager, clearing indicators and validation state.
func tear_down() -> void:
	if _indicator_service != null:
		_indicator_service.reset(self)
	if _test_setup_factory != null:
		_test_setup_factory.clear()
	queue_redraw()
	if _placement_validator != null:
		_placement_validator.tear_down()

## Applies placement rules through the validator.
func apply_rules() -> void:
	if _placement_validator != null:
		_placement_validator.apply_rules()

## Validates placement using indicators and rules.
## [returns] A ValidationResults object with validation outcome.
func validate_placement() -> ValidationResults:
	if _placement_validator == null:
		var error_result = ValidationResults.new(false, "PlacementValidator is not initialized")
		error_result.add_issue("PlacementValidator is null")
		return error_result
	return _placement_validator.validate_placement()

## Updates the collision mapper with dependency injection if a composition container is available.
## [param container] The dependency injection container.
## [returns bool] Whether the injection was successful or not
func inject_collision_mapper_dependencies(container: GBCompositionContainer) -> bool:
	if _indicator_service != null:
		return false
		
	_indicator_service.inject_dependencies(container)
	return true

## Returns the shared testing indicator, creating it if it doesn't exist.
## [param parent_node] The parent node for the testing indicator.
## [returns] The testing indicator instance.
func get_or_create_testing_indicator(parent_node: Node) -> RuleCheckIndicator:
	if _indicator_service != null:
		return _indicator_service.get_or_create_testing_indicator(parent_node)
	return null

## Sets up the collision mapper with the testing indicator and test setups.
## [param testing_indicator] The testing indicator to use.
## [param setups] The collision test setups.
func setup_collision_mapper(testing_indicator: RuleCheckIndicator, setups: Dictionary) -> void:
	if _indicator_service != null and _indicator_service.has_method("setup_collision_mapper"):
		_indicator_service.setup_collision_mapper(testing_indicator, setups)

## Gets the collision mapper from the indicator service.
## [returns] The collision mapper instance.
func get_collision_mapper() -> CollisionMapper:
	if _indicator_service != null and _indicator_service.has_method("get_collision_mapper"):
		return _indicator_service.get_collision_mapper()
	return null

## Exposes the underlying PlacementValidator for advanced/test usages.
## Tests use this to drive validation directly when needed.
func get_placement_validator() -> PlacementValidator:
	return _placement_validator

## Forces all managed indicators to update their shapecast collision detection immediately.
## This is useful for tests to avoid waiting for physics frames when you only need
## collision detection updated but don't care about validity state yet.
## For tests that need both collision detection AND validity evaluation, use
## [method force_indicators_validity_evaluation] instead.
func force_shapecast_update() -> void:
	if _indicator_service != null:
		_indicator_service.force_update()

## Forces all managed indicators to immediately update collision detection and
## re-evaluate their validity state based on assigned rules.
## This is the preferred method for tests as it provides deterministic validation
## results without needing to wait for physics frames or process cycles.
## Calls [method RuleCheckIndicator.force_validity_evaluation] on each managed indicator.
## [returns] The number of indicators that were updated.
func force_indicators_validity_evaluation() -> int:
	if _indicator_service == null:
		return 0
	
	var indicators := _indicator_service.get_indicators()
	var updated_count := 0
	
	for indicator in indicators:
		if is_instance_valid(indicator):
			indicator.force_validity_evaluation()
			updated_count += 1
	
	return updated_count

## Handles manipulation cancellation by cleaning up all active indicators.
## This ensures indicators are properly freed when manipulation ends unexpectedly
## (e.g., source object deleted, user cancels, etc.).
## [param _data] The manipulation data (unused, but required by signal signature).
func _on_manipulation_canceled(_data: ManipulationData) -> void:
	if _indicator_service != null:
		_indicator_service.reset(self)
		_last_setup_test_object = null
		_logger.log_verbose("IndicatorManager: Cleared indicators due to manipulation cancellation")
	else:
		push_error("IndicatorManager: Cannot reset indicators - no indicator service initialized")
