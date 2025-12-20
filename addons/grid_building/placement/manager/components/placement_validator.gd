class_name PlacementValidator
extends GBInjectable
## Runs tests for each rule using RuleCheckIndicators
## to determine if placement in the targeted location is
## valid if all rules validate successfully

const PlacementRuleValidationLogic = preload("uid://glxk6xdp6j35")

## Emitted when the placement validator is done evaluating a set of rules on a scene node
signal finished(results: ValidationResults)

## Emitted when the setup failed
signal setup_failed(issues : Dictionary[PlacementRule, Array])

## Creates a PlacementValidator with dependency injection from container.
## Container serves as single source of truth for all dependencies.
## Parameters:
##   container: GBCompositionContainer - The dependency container
## Returns:
##   PlacementValidator - Fully configured placement validator with validated dependencies
static func create_with_injection(container: GBCompositionContainer) -> PlacementValidator:
	# Get dependencies from container as single source of truth
	var logger = container.get_logger()
	var container_rules = container.get_placement_rules()

	var validator = PlacementValidator.new(container_rules, logger)

	# Inject dependencies
	validator.resolve_gb_dependencies(container)

	# Validate dependencies were properly injected
	var issues = validator.get_runtime_issues()
	if not issues.is_empty():
		logger.log_warnings(issues)

	return validator

## Rules that are enforced whenever placing any object into the game world by default
## Exists so you don't have to add the same rule to every single object individually
var _base_rules: Array[PlacementRule] = []

## Debug settings to pass into rules. Override in resource inspector if desired.
var _logger : GBLogger = null

## Full list of rules being used by the placement validator to test object placement
var active_rules: Array[PlacementRule] = []

const ISSUE_MATCHING_PRIORITY = "Info: %d rules share visual priority [%d] %s (allowed)"

func _init(p_base_rules : Array[PlacementRule], p_logger : GBLogger) -> void:
	_base_rules = p_base_rules
	_logger = p_logger

## Passes. No injection needed.
## [b]Returns[/b]: [i]bool[/i] - True if dependencies were successfully resolved, false otherwise
func resolve_gb_dependencies(container: GBCompositionContainer) -> bool:
	return true

## Validates that all required dependencies are properly set.
## Returns:
##   Array[String] - List of validation issues (empty if valid)
func get_runtime_issues() -> Array[String]:
	var issues: Array[String] = []

	if not _logger:
		issues.append("GBLogger is not set")

	return issues

## Validates placement rules against the current target state.
## Returns the validation results including details of each placement rule result.[br][br]
## Returns: [i]ValidationResults[/i] - Comprehensive validation results with rule details and success status
func validate_placement() -> ValidationResults:
	var results := ValidationResults.new()

	# Check prerequisites using pure logic
	var prerequisite_issues = PlacementRuleValidationLogic.validate_validation_prerequisites(active_rules)
	if not prerequisite_issues.is_empty():
		for issue in prerequisite_issues:
			results.add_error(issue)
			
		results.message = "Placement validator has not been successfully setup. Must run setup with true result."
			
		return results

	# Clean up any null indicators before validation using pure logic
	var cleaned_count = PlacementRuleValidationLogic.cleanup_null_indicators_from_rules(active_rules)
	if cleaned_count > 0 and _logger:
		_logger.log_warning( "Cleaned up %d null indicators from %d active rules" % [cleaned_count, active_rules.size()])

	# Perform core validation using pure logic
	var validation_results = PlacementRuleValidationLogic.validate_placement_rules(active_rules)
	
	# Handle orchestration (logging, result processing)
	_handle_validation_orchestration(validation_results)
	
	return validation_results

## Handles orchestration aspects of validation (logging, result processing)
func _handle_validation_orchestration(results: ValidationResults) -> void:
	# Log issues if any exist (as verbose, not warnings - this is normal gameplay feedback)
	var issues = results.get_issues()
	if not issues.is_empty() and _logger:
		_logger.log_verbose(str(issues))

	# Per-rule trace logging for deep debugging (trace level only)
	if _logger and _logger.is_trace_enabled():
		for rule in results.rule_results.keys():
			var rule_result = results.rule_results[rule]
			var issues_for_rule = rule_result.issues if rule_result else []
			var status := ("PASS" if issues_for_rule.is_empty() else "FAIL")
			var rule_name = rule.get_class() if rule else "Unknown"
			_logger.log_trace( "Rule %s -> %s : %s" % [rule_name, status, issues_for_rule])

	# Set final success state based on rule validation
	if not results.is_successful():
		results.message = "Placement validation failed with issues."
	else:
		results.message = "Placement is valid. All PlacementRules validated successfully."

## Tries setup on all of the p_rules PlacementRule
## Uses pure logic class for composition over inheritance
## Returns a dictionary PlacementRules and the issues found for each rule that had issues
## [param] p_rules : Array[PlacementRule] - The placement rules to setup
## [param] p_gts : GridTargetingState - The current grid targeting state
func _setup_rules(p_rules : Array[PlacementRule], p_gts : GridTargetingState) -> Dictionary:
	return PlacementRuleValidationLogic.setup_rules(p_rules, p_gts)

## Sets the active rules set and rule_check_indicators for
## validating the current target's placement position
## Uses pure logic class for composition over inheritance
## Returns a dictionary of issues
func setup(p_rules : Array[PlacementRule], p_gts : GridTargetingState) -> Dictionary:
	var rule_issues := _setup_rules(p_rules, p_gts)

	if rule_issues.is_empty():
		var tile_check_rules : Array[TileCheckRule] = RuleFilters.only_tile_check(p_rules)
		_pre_check_tile_rules(tile_check_rules) # Find potential warnings
		# Set active rules after successful setup
		active_rules = p_rules
	else:
		setup_failed.emit(rule_issues)

	return rule_issues

## Gets the rules of the placement validator combined with the rules of the placeable resource
## Uses pure logic class for composition over inheritance
func get_combined_rules(p_outside_rules : Array, p_ignore_base = false) -> Array[PlacementRule]:
	# Use pure logic class for rule combination
	return PlacementRuleValidationLogic.combine_rules(_base_rules, p_outside_rules, p_ignore_base)

func _pre_check_tile_rules(p_tile_check_rules: Array[TileCheckRule]):
	var priority_rule_dict = {}

	for rule in p_tile_check_rules:
		if priority_rule_dict.has(rule.visual_priority):
			priority_rule_dict[rule.visual_priority].append(rule)
		else:
			priority_rule_dict[rule.visual_priority] = [rule]

	for key in priority_rule_dict:
		var rules = priority_rule_dict.get(key)
		var rules_names = "["

		for rule in rules:
			rules_names += "%s, " % rule

		rules_names += "]"

		var rules_with_priority = priority_rule_dict[key].size()
		if rules_with_priority > 1:
			# Duplicated priorities are allowed; log only as verbose info to avoid implying action required
			if _logger:
				_logger.log_verbose( ISSUE_MATCHING_PRIORITY % [rules_with_priority, key, rules_names])

## Tear down base & placeable specific rules
func tear_down():
	for rule in active_rules:
		rule.tear_down()

	active_rules.clear()

## Clean up null indicators from all active tile check rules.
## This prevents null reference errors during validation.
## Uses pure logic for composition over inheritance
## Runs execute on each of the active rules
##
## This is code that generally runs after validation is successful and the validated
## action takes place
func apply_rules():
	for rule in active_rules:
		rule.apply()

## Adds rule groups to the test and returns if all were setup successfully
func _add_rules_to_test(
	p_placementing_rules: Array[PlacementRule], p_gts: GridTargetingState
) -> bool:
	var all_rules_setup = true

	for rule in p_placementing_rules:
		var results = rule.setup(p_gts)

		if results == true:
			active_rules.append(rule)
		else:
			all_rules_setup = false
			push_error("Rule " + rule.resource_path + " failed setup.")

	return all_rules_setup
