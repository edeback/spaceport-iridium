## Comprehensive report for placement operation results and validation feedback.
##
## The [b]PlacementReport[/b] class serves as a detailed snapshot of any placement attempt
## within the Grid Building system. It encapsulates all relevant information about
## build, move, or placement operations, providing a complete audit trail for
## debugging, logging, and user feedback.
##
## [br][br][b]Core Purpose:[/b][br]
## This class aggregates data from multiple sources to provide a unified view of:[br]
## - The entity performing the placement action[br]
## - The object being placed or manipulated[br]
## - Validation results from rule checking systems[br]
## - Any issues or problems encountered during the process[br]
## - Diagnostic notes for debugging and monitoring[br][br]
##
## [b]Primary Use Cases:[/b][br]
## - [b]Success Validation:[/b] Determine if a placement operation completed successfully[br]
## - [b]Error Reporting:[/b] Collect and present validation failures to users[br]
## - [b]Debugging Support:[/b] Provide detailed diagnostic information for developers[br]
## - [b]Audit Logging:[/b] Maintain records of all placement attempts and outcomes[br]
## - [b]System Integration:[/b] Pass placement results between different system components[br][br]
##
## [b]Architecture Integration:[/b][br]
## The report works closely with:[br]
## - [member indicators_report]: Results from RuleCheckIndicator validation[br]
## - [member placer]: The GBOwner entity initiating the placement[br]
## - [member preview_instance]: The Node2D being tested for placement validity[br][br]
##
## [b]Usage Example:[/b]
## [codeblock]
## # Create a placement report after attempting to build
## var report = PlacementReport.new(placer, preview, indicators_report, GBEnums.Action.BUILD)
##
## # Check if placement was successful
## if report.is_successful():
##     print("Placement completed successfully!")
##     # Log successful placement for analytics
##     log_placement_success(report)
## else:
##     print("Placement failed: ", report.get_issues())
##     # Handle placement failure - show user feedback
##     show_placement_errors(report)
## [/codeblock][br][br]
##
## [b]Key Properties:[/b][br]
## - [member placer]: The GBOwner entity responsible for initiating placement[br]
## - [member preview_instance]: The Node2D object being placed/tested[br]
## - [member indicators_report]: Validation results from IndicatorSetupReport[br]
## - [member action_type]: Type of placement action (GBEnums.Action)[br]
## - [member issues]: Array of error messages and validation failures[br]
## - [member notes]: Additional diagnostic information and metadata[br][br]
##
## [b]Thread Safety:[/b] This class is not thread-safe. All operations should be[br]
## performed on the main thread to ensure proper integration with Godot's scene system.[br][br]
##
## [b]Performance Notes:[/b] Reports are lightweight objects designed for frequent[br]
## creation during placement operations. Memory usage scales with the number of[br]
## issues and notes collected.[br][br]
class_name PlacementReport

## GBOwner for the root entity responsible for placing the preview_instance into the game world.
## This represents the player, AI, or other entity that initiated the placement action.
var placer : GBOwner

## The preview instance for the object being manipulated (built, placed, etc.).
## This is the Node2D that represents the object being tested for placement validity.
var preview_instance : Node

## The root of the placed object (if any).
## This should be set after successful placement
var placed : Node

## The report from RuleCheckIndicator generation for the preview object.
## Contains detailed information about collision detection, rule validation, and indicator setup.
var indicators_report : IndicatorSetupReport

## The type of action that was attempted for this placement.
## Indicates whether this was a BUILD, MOVE, or other type of placement operation.
var action_type : GBEnums.Action

## General setup issues encountered during the placement attempt.
## Contains error messages and validation failures that prevented successful placement.
var issues : Array[String] = []

## Additional notes collected at setup time (aggregated from indicator reports and validator).
## Contains diagnostic information and metadata about the placement process.
var notes : Array[String] = []

## Creates a new PlacementReport with the specified parameters.
## [br][br]
## [param p_placer] The GBOwner entity responsible for the placement action [br]
## [param p_preview_instance] The Node2D being tested for placement [br]
## [param p_indicators_report] The IndicatorSetupReport containing validation results [br]
## [param p_action] The type of placement action being performed [br]
func _init(p_placer : GBOwner, p_preview_instance : Node, p_indicators_report : IndicatorSetupReport, p_action : GBEnums.Action) -> void:
	placer = p_placer	
	preview_instance = p_preview_instance
	indicators_report = p_indicators_report
	action_type = p_action
	

## Adds an issue to the report's issues list.
##
## Issues represent problems or validation failures that occurred during placement.
##
## [param p_issue] The issue message to add to the report
func add_issue(p_issue : String) -> void:
	issues.append(p_issue)

## Adds a diagnostic note to the report's notes list.
##
## Notes contain additional information about the placement process that may be
## useful for debugging or logging, but don't represent errors.
##
## [param p_note] The diagnostic note to add to the report
func add_note(p_note : String) -> void:
	notes.append(p_note)

## Returns the root node of the entity responsible for placement.
##
## This is a convenience method that accesses the owner_root property of the placer.
##
## [return] The root Node of the GBOwner entity, or null if no placer is set
func get_owner_root() -> Node:
	return placer.owner_root

## Converts the report to a detailed multi-line string representation.
##
## Generates a comprehensive string containing all report information including
## success status, action type, preview details, indicator report summary,
## issues, and notes. Useful for debugging and logging.
##
## [return] A formatted string representation of the entire report
func to_verbose_string() -> String:
	var parts: Array[String] = []
	parts.append("PlacementReport")
	parts.append("  success: %s" % str(is_successful()))
	parts.append("  action: %s" % str(action_type))
	parts.append("  preview: %s" % (preview_instance != null and str(preview_instance) or "<null>"))
	if indicators_report != null:
		parts.append("  indicators_report:\n" + indicators_report.to_summary_string())
	if not issues.is_empty():
		parts.append("  issues: %s" % str(issues))
	if not notes.is_empty():
		parts.append("  notes: %s" % str(notes))
	return "\n".join(parts)

## Determines if the placement attempt was successful.
##
## A placement is considered successful if there are no issues in either
## the main report or the indicators report.
##
## [return] [code]true[/code] if placement was successful, [code]false[/code] otherwise
func is_successful() -> bool:
	return get_issues().is_empty()

## Returns all issues from both the main report and indicators report.
##
## Combines issues from the report's own issues array with any issues
## found in the indicators report, providing a complete list of all
## problems encountered during the placement attempt.
##
## [return] An array containing all issues from the report and indicators
func get_issues() -> Array[String]:
	var all_issues: Array[String] = []
	all_issues.append_array(issues)
	if indicators_report:
		all_issues.append_array(indicators_report.get_indicators_issues())
	return all_issues


## Factory: build a PlacementReport from validation issue dictionary
## Builds a PlacementReport using the owning GBOwner (not the owner_root Node)
static func from_failed_validation(validator_issues: Dictionary, owner: GBOwner, target: Node, action: GBEnums.Action = GBEnums.Action.BUILD) -> PlacementReport:
	# Initialize report
	var report = PlacementReport.new(owner, target, null, action)
	# Extract rule keys
	var keys = validator_issues.keys()
	# First error message of first rule
	if keys.size() > 0:
		var first_key = keys[0]
		var msgs = validator_issues[first_key]
		if msgs is Array and msgs.size() > 0:
			report.add_issue(msgs[0])
	# Summary line
	report.add_issue("Placement validation setup failed with %d rule issues:" % keys.size())
	# Detailed per-rule messages
	for key in keys:
		report.add_issue("Rule %s failed: %s" % [str(key), str(validator_issues[key])])
	return report
