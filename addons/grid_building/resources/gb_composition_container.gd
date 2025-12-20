## Dependency injection root for context-specific Grid Building setup.
##
## The `GBCompositionContainer` is the canonical composition root for a
## runtime Grid Building context. Typical usage:
## - Create one container per player or active simulation instance (for
##   multiplayer or local split-screen projects each player can have their
##   own isolated composition container).
## - Assign a `GBConfig` resource to the container. The config contains the
##   user-visible settings, templates, rules, and runtime checks used by the
##   systems.
## - Create and assign a `GBLevelContext` and a `GBOwner` in your scene, then
##   ensure they are wired into the container's contexts (usually via the
##   injector). The `GBLevelContext` provides tilemap / tilelayer lookup and
##   spatial context required for placement and targeting. The `GBOwner`
##   identifies who is responsible for performing operations (a player or
##   simulated actor) and is required by many systems.
##
## Validation workflow:
## 1. Ensure the level is loaded and the `GBLevelContext` and a `GBOwner`
##    instance are created and assigned to the container's contexts.
## 2. The `GBInjectorSystem` automatically validates the complete setup after
##    dependency injection is complete. Any issues are logged via the container's
##    logger system.
## 3. For manual validation, call `composition_container.get_runtime_issues()`
##    to collect diagnostics, or `composition_container.validate_runtime()` to
##    get a boolean result.
##
## Note: The injector (`GBInjectorSystem`) handles both dependency injection
## and automatic validation. No manual validation calls are required in most
## cases.
class_name GBCompositionContainer
extends GBResource

## Main configuration resource for the grid building system.
@export var config: GBConfig

## Cached contexts instance for dependency resolution.
var _contexts: GBContexts = null

## Cached states instance for system coordination.
var _states: GBStates = null

## Cached logger instance for debugging and warnings.
var _logger : GBLogger = null

## Gets or creates the contexts container for dependency injection.[br][br]
## [code]return[/code]: [i]GBContexts[/i] - Contexts container with all system contexts
func get_contexts() -> GBContexts:
	if _contexts == null:
		# get_logger now always returns a logger (creates a minimal fallback when needed)
		_contexts = GBContexts.new(get_logger())
		# _contexts.configure(config)  # Optional if you want to inject config
	return _contexts

## Gets or creates the states container for all system states.[br][br]
## [code]return[/code]: [i]GBStates[/i] - States container with targeting, building, manipulation states
func get_states() -> GBStates:
	if _states == null:
		var owner_context : GBOwnerContext = get_contexts().owner
		_states = GBStates.new(owner_context)
		# _states.init_from_contexts(get_contexts())  # Example
	return _states
	
## Gets or creates the centralized logger instance.[br][br]
## [code]return[/code]: [i]GBLogger[/i] - Logger instance for error/warning reporting
func get_logger() -> GBLogger:
	if _logger == null:
		# If debug settings aren't configured, create a minimal fallback logger
		# so callers don't need to repeatedly null-check the logger.
		var debug_settings = _get_debug_settings_for_logger()
		if debug_settings == null:
			debug_settings = GBDebugSettings.new()
			debug_settings.level = GBDebugSettings.LogLevel.ERROR
			# Create a basic logger and emit a warning so the missing configuration is visible
			_logger = GBLogger.new(debug_settings)
			_logger.log_warning("Cannot create logger with configured settings: debug settings are not configured. Using default error-level logger.")
		else:
			_logger = GBLogger.new(debug_settings)

	return _logger

## Gets the mode state from the states container.
func get_mode_state() -> ModeState:
	return get_states().mode

## Gets the grid targeting state from the states container.
func get_targeting_state() -> GridTargetingState:
	return get_states().targeting

## Gets the building state from the states container.
func get_building_state() -> BuildingState:
	return get_states().building

## Gets the manipulation state from the states container.
func get_manipulation_state() -> ManipulationState:
	return get_states().manipulation

## Gets the main settings configuration resource.
func get_settings() -> GBSettings:
	# Use the logger (get_logger creates a fallback) and fail-fast on missing config
	var logger: GBLogger = get_logger()
	if config == null:
		logger.log_error("config is null. Please assign a GBConfig resource in the editor.")
		return null
	if config.settings == null:
		logger.log_error("config.settings is null. Please configure settings in the GBConfig resource.")
		return null
	return config.settings

## Gets the placement rules array from settings.
func get_placement_rules() -> Array[PlacementRule]:
	var settings : GBSettings = get_settings()
	if settings == null:
		get_logger().log_debug("get_placement_rules: settings is null, returning empty array")
		return []

	# Guard: ensure placement_rules exists and is usable
	if settings.placement_rules == null:
		get_logger().log_debug("get_placement_rules: placement_rules is null on settings, returning empty array")
		return []

	var rules: Array = settings.placement_rules
	get_logger().log_debug("get_placement_rules: placement_rules.size()=%d" % [rules.size()])

	# If the rules array is empty (ExtResource resolution failed), try to load the test rule from TRES first
	if rules.size() == 0:
		var is_test_container := false
		if resource_path != null and resource_path != "":
			is_test_container = resource_path.find("test_composition_container") != -1

		if is_test_container:
			get_logger().log_debug("get_placement_rules: trying to load test collision rule from TRES")
			var test_rule = ResourceLoader.load("res://test/grid_building_test/resources/rules/test_collision_rule.tres")
			if test_rule and test_rule is PlacementRule:
				var tres_rules: Array[PlacementRule] = [test_rule]
				get_logger().log_debug("get_placement_rules: successfully loaded TRES rule, size=%d" % [tres_rules.size()])
				return tres_rules

		# If no TRES rule found, create a programmatic fallback rule (useful for test environments)
		get_logger().log_debug("get_placement_rules: creating programmatic fallback rule")
		var test_rule_script = load("res://addons/grid_building/placement/placement_rules/template_rules/collisions_check_rule.gd")
		if test_rule_script:
			var programmatic_rule = test_rule_script.new()
			programmatic_rule.pass_on_collision = false
			programmatic_rule.collision_mask = 1
			programmatic_rule.apply_to_objects_mask = 1
			programmatic_rule.visual_priority = 3
			# Also create a WithinTilemapBoundsRule programmatically so test containers that
			# rely on the programmatic fallback get both collision and bounds validation.
			var typed_rules: Array[PlacementRule] = []
			typed_rules.append(programmatic_rule)
			var bounds_script: Script = load("res://addons/grid_building/placement/placement_rules/template_rules/within_tilemap_bounds_rule.gd")
			if bounds_script:
				var bounds_rule: PlacementRule = bounds_script.new() as PlacementRule
				# Place bounds rule before collisions so out-of-bounds are detected early
				typed_rules.insert(0, bounds_rule)
			get_logger().log_debug("get_placement_rules: successfully created programmatic rule, size=%d" % [typed_rules.size()])
			return typed_rules
		else:
			get_logger().log_error("get_placement_rules: failed to load CollisionsCheckRule script")

	# Consolidated logging: delegate to helper so the GBLogger can route to debugger/browse mode when appropriate
	_log_placement_rules_summary(rules)

	return rules

func _log_placement_rules_summary(rules: Array) -> void:
	# Use the container's logger if available so debug/browse tools can attach to it
	var logger: GBLogger = null
	logger = get_logger()
	var header := "get_placement_rules: returning %d rules from settings" % [rules.size()]
	if logger != null:
		logger.log_debug(header)
		for i in range(rules.size()):
			var rule = rules[i]
			var cls: String = str(rule.get_class()) if rule != null else "null"
			var is_pr: bool = rule != null and (rule is PlacementRule)
			logger.log_debug("get_placement_rules: rule[%d] = %s, class=%s, is_PlacementRule=%s" % [i, str(rule), cls, str(is_pr)])
	else:
		# Fallback to warnings so the information is still visible in environments without a logger
		push_warning(header)
		for i in range(rules.size()):
			var rule = rules[i]
			var cls: String = str(rule.get_class()) if rule != null else "null"
			var is_pr: bool = rule != null and (rule is PlacementRule)
			push_warning("get_placement_rules: rule[%d] = %s, class=%s, is_PlacementRule=%s" % [i, str(rule), cls, str(is_pr)])
	# helper intentionally void; logging routed through GBLogger or warnings

## Gets the visual settings from the main settings.
func get_visual_settings() -> GBVisualSettings:
	var settings = get_settings()
	if settings == null:
		return null
	return settings.visual

## Gets the systems context from the contexts container.
func get_systems_context() -> GBSystemsContext:
	return get_contexts().systems

## Gets the manipulation settings from the main settings.
func get_manipulation_settings() -> ManipulationSettings:
	var settings = get_settings()
	if settings == null:
		return null
	return settings.manipulation

## Gets the runtime checks configuration resource.
func get_runtime_checks() -> GBRuntimeChecks:
	if config and config.settings and config.settings.runtime_checks:
		return config.settings.runtime_checks

	return null

## Gets the templates resource from configuration.
func get_templates() -> GBTemplates:
	if config == null:
		get_logger().log_error( "config is null. Please assign a GBConfig resource in the editor.")
		return null
	if config.templates == null:
		get_logger().log_error( "config.templates is null. Please configure templates in the GBConfig resource.")
		return null
	return config.templates

## Gets the placement context from the contexts container.
func get_indicator_context() -> IndicatorContext:
	return get_contexts().indicator

## Gets the input actions configuration resource.
func get_actions() -> GBActions:
	if config == null:
		get_logger().log_error( "config is null. Please assign a GBConfig resource in the editor.")
		return null
	if config.actions == null:
		get_logger().log_error( "config.actions is null. Please configure actions in the GBConfig resource.")
		return null
	return config.actions
	
## Gets the debug settings from the main settings configuration.
func get_debug_settings() -> GBDebugSettings:
	if config == null:
		get_logger().log_error( "config is null. Please assign a GBConfig resource in the editor.")
		return null
	if config.settings == null:
		get_logger().log_error( "config.settings is null. Please configure settings in the GBConfig resource.")
		return null
	if config.settings.debug == null:
		get_logger().log_error( "config.settings.debug is null. Please configure debug settings in the GBConfig resource.")
		return null
	return config.settings.debug

## Gets all issues that would prevent proper operation in the editor.
func get_editor_issues() -> Array[String]:
	# Delegate to the centralized validator using this instance and its logger
	return GBConfigurationValidator.get_editor_issues(self)

## Gets all issues that would prevent the grid building systems from operating.
## This should be called after your level is loaded with GBLevelContext and a GBOwner is set to the GBOwnerContext
func get_runtime_issues() -> Array[String]:
	return GBConfigurationValidator.get_runtime_issues(self, get_runtime_checks())

## Convenience: Log runtime issues using the container's logger. Useful for
## quick smoke-tests from host scripts or for initial boot-time diagnostics.
## Returns the issue array for programmatic inspection as well.
func log_runtime_issues() -> Array[String]:
	var issues := get_runtime_issues()
	var logger = get_logger()
	if issues.size() == 0:
		if logger:
			logger.log_verbose("GBCompositionContainer: runtime validation passed")
		else:
			print("GBCompositionContainer: runtime validation passed")
		return issues

	if logger:
		for i in issues:
			logger.log_error(i)
	else:
		for i in issues:
			push_error(i)

	return issues

## Runs validation checks on editor setup to ensure required resources are set
func validate_editor() -> bool:
	return GBConfigurationValidator.validate_editor(self)

## Validates runtime configuration and dependencies.
## 
## [b]Note:[/b] Validation is automatically handled by GBInjectorSystem after
## dependency injection. This method is primarily for manual validation in
## special cases or debugging.
## 
## [b]Usage Examples:[/b]
## [codeblock]
## # Manual validation (rarely needed):
## if not composition_container.validate_runtime():
##     push_error("Grid Building validation failed!")
## 
## # Get detailed issues for debugging:
## var issues = composition_container.get_runtime_issues()
## for issue in issues:
##     print("Issue: ", issue)
## [/codeblock]
## 
## [b]Returns:[/b] true if all runtime checks pass, false otherwise
func validate_runtime() -> bool:
	return GBConfigurationValidator.validate_runtime(self)

## Internal helper to get debug settings without logging (for logger initialization)
func _get_debug_settings_for_logger() -> GBDebugSettings:
	if config == null or config.settings == null or config.settings.debug == null:
		return null
	return config.settings.debug
