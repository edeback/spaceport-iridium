## Results from placement rule validation.
##
## RuleResult encapsulates the outcome of evaluating a placement rule, storing validation issues,
## success state, and contextual information for debugging and logging. The class supports both
## incremental construction (for building issues during validation) and complete construction
## (for finished results). Success is determined by the absence of validation issues, making
## the result self-documenting and suitable for build logs and user feedback systems.
class_name RuleResult
extends RefCounted

## The rule that was tested.
var rule: PlacementRule

## Issues found during validation.
var issues: Array[String] = []

## Creates a basic rule result for incremental building during validation.
## Use this when you need to build up issues gradually during rule evaluation.
## [param p_rule] The placement rule being tested. Cannot be null.
func _init(p_rule: PlacementRule) -> void:
	assert(p_rule != null, "Rule cannot be null")
	self.rule = p_rule
	# Ensure issues always starts as an empty array for incremental construction
	if issues == null:
		issues = []

## Factory for creating a finished rule result.
## Creates an immutable result with all validation data complete.
## [param p_rule] The rule that was tested
## [param p_issues] Issues found during validation
## [param p_reason] Reason for success or failure
static func build(p_rule: PlacementRule, p_issues: Array[String]) -> RuleResult:
	assert(p_rule != null, "Rule cannot be null")
	
	var result := RuleResult.new(p_rule)
	result.issues = p_issues.duplicate()
	return result

## Adds a single validation issue to the result.
## [param p_issue] A descriptive validation issue. Should not be empty.
func add_issue(p_issue: String) -> void:
	issues.append(p_issue)

## Adds multiple validation issues to the result.
## [param p_issues] Array of descriptive validation issues. Should not be null.
func add_issues(p_issues: Array[String]) -> void:
	issues.append_array(p_issues)

## Returns whether the rule validation was successful.
## A rule is considered successful if no validation issues were found.
func is_successful() -> bool:
	return issues.is_empty()

## Backward compatibility shim expected by legacy validation code which called is_empty on RuleResult
func is_empty() -> bool:
	return issues.is_empty()

## Convenience accessor returning all issues (alias)
func get_issues() -> Array[String]:
	return issues.duplicate()
