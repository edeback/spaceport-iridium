## PlacementRuleValidationLogic
## Pure logic class for placement rule validation.
## Contains no state and can be easily tested in isolation.
## Focuses on core validation logic without orchestration concerns.
extends RefCounted

## Pure function to validate a set of rules and return results.
## No side effects - just validates rules and collects issues.
## Returns validation results with rule-issue mappings.
static func validate_placement_rules(rules: Array[PlacementRule]) -> ValidationResults:
	var results := ValidationResults.new()
	
	if rules.is_empty():
		results.message = "No rules provided for validation"
		results.add_issue("Rules array is empty")
		return results
	
	for rule in rules:
		if not rule:
			results.add_issue("Null rule in rules array")
			continue
			
		if not is_instance_valid(rule):
			results.add_issue("Invalid rule instance found")
			continue
		
		var rule_result : RuleResult = rule.validate_placement()
		results.add_rule_result(rule, rule_result)

	return results

## Pure function to clean null indicators from tile check rules.
## Returns count of cleaned indicators.
static func cleanup_null_indicators_from_rules(rules: Array[PlacementRule]) -> int:
	var cleaned_count = 0
	
	for rule in rules:
		if rule is TileCheckRule:
			var tile_rule = rule as TileCheckRule
			var i = 0
			while i < tile_rule.indicators.size():
				if tile_rule.indicators[i] == null or not is_instance_valid(tile_rule.indicators[i]):
					tile_rule.indicators.remove_at(i)
					cleaned_count += 1
				else:
					i += 1
	
	return cleaned_count

## Pure function to validate prerequisites for rule validation.
## Returns array of prerequisite issues.
static func validate_validation_prerequisites(rules: Array[PlacementRule]) -> Array[String]:
	var issues: Array[String] = []
	
	if rules.is_empty():
		issues.append("No active rules. Setup must be called first.")
		return issues
	
	# Check for null or invalid rules
	var invalid_count = 0
	for rule in rules:
		if not rule or not is_instance_valid(rule):
			invalid_count += 1
	
	if invalid_count > 0:
		issues.append("Found %d invalid or null rules" % invalid_count)
	
	return issues

## Extract rule setup logic
## Returns dictionary of issues for each rule that failed setup
static func setup_rules(rules: Array[PlacementRule], p_gts : GridTargetingState) -> Dictionary:
	var issues : Dictionary = {}
	
	if not p_gts:
		# Return issues for all rules since params are invalid
		for rule in rules:
			if rule:
				issues[rule] = ["GridTargetingState is null"]
		return issues
	
	for rule in rules:
		if not rule:
			continue

		var rule_issues = rule.setup(p_gts)
		if not rule_issues.is_empty():
			issues[rule] = rule_issues
	
	return issues

## Pure function to check if rules are ready for validation
static func are_rules_ready(rules: Array[PlacementRule]) -> bool:
	for rule in rules:
		if not rule or not rule._ready:
			return false
	return true

## Combines base_rules that apply to all placements within a context
## with additional_rules that apply to specific placements[br]
## [br]	[code]base_rules[/code] The rules that apply to all placements
## [br]	[code]additional_rules[/code] The rules that apply to specific placements
## [br]	[code]ignore_base[/code] Whether to ignore base rules completely and return only the additional_rules
static func combine_rules(base_rules: Array[PlacementRule], additional_rules: Array[PlacementRule], ignore_base: bool = false) -> Array[PlacementRule]:
	var combined_rules: Array[PlacementRule] = []
	
	if not ignore_base:
		combined_rules.append_array(base_rules)
	
	combined_rules.append_array(additional_rules)
	
	# Remove duplicates while preserving order
	var unique_rules: Array[PlacementRule] = []
	for rule in combined_rules:
		if rule and not rule in unique_rules:
			unique_rules.append(rule)
	
	return unique_rules
