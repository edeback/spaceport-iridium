## Factory for creating and injecting RefCounted objects with dependencies.
##
## Provides centralized creation of RefCounted objects that need dependency injection since they cannot be automatically discovered by the GBInjectorSystem.
class_name GBInjectableFactory
extends RefCounted

## Creates and injects a CollisionMapper with dependencies.
static func create_collision_mapper(container: GBCompositionContainer) -> CollisionMapper:
	var targeting_state = container.get_targeting_state()
	var logger = container.get_logger()
	var mapper = CollisionMapper.new(targeting_state, logger)
	
	# Validate dependencies were properly injected
	var issues = mapper.get_runtime_issues()
	if not issues.is_empty():
		logger.log_warnings(issues)
	
	return mapper

## Creates and injects an IndicatorManager with dependencies.[br][br]
## [code]parent[/code]: [i]Node2D[/i] - The parent node for indicators (required - cannot be resolved from container)
static func create_indicator_service(container: GBCompositionContainer, parent: Node2D) -> IndicatorService:
	var targeting_state = container.get_targeting_state()
	var logger = container.get_logger()
	var indicator_template = container.get_templates().rule_check_indicator
	var manager = IndicatorService.new(parent, targeting_state, indicator_template, logger)
	
	# Inject dependencies into the manager itself
	manager.resolve_gb_dependencies(container)
	
	# Validate dependencies were properly injected
	var issues = manager.get_runtime_issues()
	if not issues.is_empty():
		logger.log_warnings(issues)
	
	return manager

## Creates and injects a PlacementValidator with dependencies.
static func create_placement_validator(container: GBCompositionContainer) -> PlacementValidator:
	var logger = container.get_logger()
	var base_rules = container.get_placement_rules()
	var validator = PlacementValidator.new(base_rules, logger)
	
	# Inject dependencies
	validator.resolve_gb_dependencies(container)
	
	# Validate dependencies were properly injected
	var issues = validator.get_runtime_issues()
	if not issues.is_empty():
		logger.log_warnings(issues)
	
	return validator

## Creates and injects a TestSetupFactory with dependencies.
static func create_test_setup_factory(container: GBCompositionContainer) -> TestSetupFactory:
	var targeting_state = container.get_targeting_state()
	var logger = container.get_logger()
	var factory = TestSetupFactory.new(targeting_state, logger)
	
	# Validate dependencies were properly injected
	var issues = factory.get_runtime_issues()
	if not issues.is_empty():
		logger.log_warnings(issues)
	
	return factory

# TODO: Add PreviewBuilder and PreviewFactory factory methods once parsing issues are resolved
# 
# ## Creates and injects a PreviewBuilder with dependencies.
# ## Parameters:
# ##   container: GBCompositionContainer - The dependency container
# ##   building_settings: BuildingSettings - Settings for building system
# ## Returns:
# ##   PreviewBuilder - Fully configured preview builder
# static func create_preview_builder(container: GBCompositionContainer, building_settings: BuildingSettings) -> PreviewBuilder:
# 	var targeting_state = container.get_targeting_state()
# 	var building_state = container.get_states().building
# 	var logger = container.get_logger()
# 	var builder = PreviewBuilder.new(building_settings, targeting_state, building_state, logger)
# 	
# 	# Inject dependencies
# 	builder.resolve_gb_dependencies(container)
# 	
# 	# Validate dependencies were properly injected
# 	var issues = builder.get_runtime_issues()
# 	if not issues.is_empty():
# 		logger.log_warnings(builder, issues)
# 	
# 	return builder
# 
# ## Creates and injects a PreviewFactory with dependencies.
# ## Parameters:
# ##   container: GBCompositionContainer - The dependency container
# ##   building_settings: BuildingSettings - Settings for building system
# ## Returns:
# ##   PreviewFactory - Fully configured preview factory
# static func create_preview_factory(container: GBCompositionContainer, building_settings: BuildingSettings) -> PreviewFactory:
# 	var logger = container.get_logger()
# 	var factory = PreviewFactory.new(building_settings, logger)
# 	
# 	# Inject dependencies
# 	factory.resolve_gb_dependencies(container)
# 	
# 	# Validate dependencies were properly injected
# 	var issues = factory.get_runtime_issues()
# 	if not issues.is_empty():
# 		logger.log_warnings(factory, issues)
# 	
# 	return factory

## Creates and injects any RefCounted object that implements resolve_gb_dependencies.
## Generic factory method for objects that follow the injection pattern.[br][br]
## [code]constructor_args[/code]: [i]Array[/i] - Arguments to pass to the constructor (optional)
static func create_and_inject(container: GBCompositionContainer, object_class: Script, constructor_args: Array = []) -> RefCounted:
	var instance: RefCounted
	
	# Create instance with constructor arguments
	if constructor_args.is_empty():
		instance = object_class.new()
	else:
		instance = object_class.callv("new", constructor_args)
	
	# Inject dependencies if the method exists
	if instance.has_method("resolve_gb_dependencies"):
		instance.resolve_gb_dependencies(container)
		
		# Validate if the method exists
		if instance.has_method("get_dependency_issues"):
			var issues = instance.get_runtime_issues()
			if not issues.is_empty():
				var logger = container.get_logger()
				logger.log_warnings(issues)
	
	return instance
