## Results from building rule validation tests.
class_name ValidationResults
extends RefCounted

## Success or failure message.
var message : String

## Individual rule results
var rule_results : Dictionary[PlacementRule, RuleResult] = {}

## Setup/configuration errors (developer problems)
## Fix these issues for your game
var _errors : Array[String] = []

## Constructor for creating validation results.[br][br]
## [code]p_is_successful[/code]: [i]bool[/i] - Whether validation passed[br]
## [code]p_message[/code]: [i]String[/i] - Success or failure message[br]
## [code]p_rule_results[/code]: [i]Dictionary[PlacementRule, Array][/i] - Individual rule results including an array of issues for each rule prevent successful placement validation
func _init(p_is_successful : bool = false, p_message : String = "", p_rule_results : Dictionary[PlacementRule, RuleResult] = {}):
	self.message = p_message
	self.rule_results = p_rule_results

## Adds a rule result for a specific placement rule.
func add_rule_result(p_placement_rule : PlacementRule, p_result : RuleResult) -> void:
	assert(p_result != null, "Rule result being added is null.")
	rule_results[p_placement_rule] = p_result

func get_issues() -> Array[String]:
	var all_issues: Array[String] = []

	for result in rule_results.values():
			all_issues.append_array(result.get_issues())

	return all_issues

## Adds a configuration/setup error
## This should be reported to the developer appropriately
func add_error(p_error : String) -> void:
	_errors.append(p_error)

## Checks that there were no validation issues with the placement of the object
func is_successful() -> bool:
	return not has_errors() and not has_failing_rules()

## Whether the validation had any failing placement rules
func has_failing_rules() -> bool:
	return not get_failing_rules().is_empty()

## Whether the validation had any development configuration or setup errors
## These should be reported to the developer
func has_errors() -> bool:
	return not _errors.is_empty()

## Gets the successful rules
func get_successful_rules() -> Array[PlacementRule]:
	var successful_rules: Array[PlacementRule] = []
	for rule in rule_results.keys():
		var rule_result : RuleResult = rule_results[rule]
		if rule_result.issues.is_empty():
			successful_rules.append(rule)
	return successful_rules

## Gets the failing rules
func get_failing_rules() -> Array[PlacementRule]:
	var failing_rules: Array[PlacementRule] = []
	for rule in rule_results.keys():
		var rule_result : RuleResult = rule_results[rule]
		if not rule_result.get_issues().is_empty():
			failing_rules.append(rule)
	return failing_rules

## Gets the configuration/setup errors in a duplicated array
func get_errors() -> Array[String]:
	return _errors.duplicate()

## Gets the failing rules and their issues Array[String]
func get_failing_rule_results() -> Dictionary[PlacementRule, Array]:
	var failing_results: Dictionary[PlacementRule, Array] = {}
	for rule in get_failing_rules():
		failing_results[rule] = rule_results[rule].get_issues()
	return failing_results

## Generates a concise summary string of the validation results.
func get_summary_string() -> String:
	var total_rules = rule_results.size()
	var successful_rules = get_successful_rules().size()
	var failed_rules = get_failing_rules().size()
	var success_rate = 0.0
	if total_rules > 0:
		success_rate = float(successful_rules) / float(total_rules)
	
	var all_issues = get_issues()
	
	return "Validation Summary: Total Rules: %d, Successful: %d, Failed: %d, Success Rate: %.2f%%, Issues: %s" % [
		total_rules, successful_rules, failed_rules, success_rate * 100, str(all_issues)
	]
