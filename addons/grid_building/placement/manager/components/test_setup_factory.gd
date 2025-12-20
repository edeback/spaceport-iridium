class_name TestSetupFactory
extends GBInjectable

## Creates a TestSetupFactory with dependency injection from container.
## Parameters:
##   container: GBCompositionContainer - The dependency container
## Returns:
##   TestSetupFactory - Fully configured test setup factory with validated dependencies
static func create_with_injection(container: GBCompositionContainer) -> TestSetupFactory:
	var targeting_state = container.get_targeting_state()
	var logger = container.get_logger()
	var factory = TestSetupFactory.new(targeting_state, logger)
	
	# Validate dependencies were properly injected
	var issues = factory.get_runtime_issues()
	if not issues.is_empty():
		logger.log_warnings(issues)
	
	return factory

var test_setup: Array[CollisionTestSetup2D] = []

var _targeting_state: GridTargetingState
var _logger : GBLogger
var _debug: GBDebugSettings

func _init(targeting_state: GridTargetingState, p_logger: GBLogger) -> void:
	_targeting_state = targeting_state
	_logger = p_logger

## Resolves dependencies from the composition container.
## Parameters:
##   container: GBCompositionContainer - The dependency container
## [b]Returns[/b]: [i]bool[/i] - True if dependencies were successfully resolved, false otherwise
func resolve_gb_dependencies(container: GBCompositionContainer) -> bool:
	if container == null:
		return false
	
	_targeting_state = container.get_targeting_state()
	_logger = container.get_logger()
	return true

## Validates that all required dependencies are properly set.
## Returns:
##   Array[String] - List of validation issues (empty if valid)
func get_runtime_issues() -> Array[String]:
	var issues: Array[String] = []
	
	if not _targeting_state:
		issues.append("GridTargetingState is not set")
	
	if not _logger:
		issues.append("GBLogger is not set")
	
	return issues

func get_or_create_test_params(col_object: CollisionObject2D) -> CollisionTestSetup2D:
	for existing_params in test_setup:
		if existing_params.collision_object == col_object:
			return existing_params

	var collision_shape_stretch_amount = _targeting_state.get_target_map_tile_set().tile_size * 2.0
	var new_test = CollisionTestSetup2D.new(col_object, collision_shape_stretch_amount)
	test_setup.append(new_test)
	return new_test

func clear() -> void:
	for data in test_setup:
		data.free_testing_nodes()
	test_setup.clear()
