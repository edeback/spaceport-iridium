## Settings that define what and how the build log UI displays gameplay messaging content
class_name ActionLogSettings
extends GBResource

@export_group("Message Log Settings")
## If set, will show this when the build log starts
@export_multiline var on_ready_message: String = ""

## List bullet style
@export var bullet_style: String = "•"

@export var failed_color: Color = Color.LIGHT_CORAL
@export var success_color: Color = Color.LIGHT_BLUE

@export_group("Validation Results")
## Show the base messages from ValidationResults
@export var show_validation_message: bool = false

## Show the reasons for a build failing
@export var print_failed_reasons: bool = true

## Should printing still happen for drag build. Warning: This may generate
## a lot of messages
@export var print_on_drag_build: bool = false

## When a build validations succeeds, print all of the success reason messages to the log
@export var print_success_reasons: bool = false

@export_group("Action Messages")

## Print message on successful demolish
@export var show_demolish: bool = true

## Print message when move starts (pickup)
@export var show_move_started: bool = false

## Print message when move finishes (placement/cancel)
@export var show_move_finished: bool = true

## Print message when mode changes
@export var show_mode_changes: bool = true

## Message format for mode changes (use %s for mode name)
@export var mode_change_message: String = "Mode changed to: %s"

## Message on successful build
@export var built_message: String = "Built %s."

## Message on failed build
@export var fail_build_message: String = "Unable to build a %s."

## Message format for manipulation operations
@export var manipulation_message: String = "Manipulation: %s"

@export_group("Display Formatting")

## Maximum number of failure reasons to display before truncation
@export var max_failure_reasons: int = 5

## Bullet prefix for issue lists (already exists as bullet_style but this is more specific)
@export var issue_bullet_prefix: String = "- "

## Returns an array of issues found during editor validation
func get_editor_issues() -> Array[String]:
	var issues: Array[String] = []
	
	if bullet_style.is_empty():
		issues.append("ActionLogSettings bullet_style is empty")
	
	return issues

## Returns an array of issues found during runtime validation
func get_runtime_issues() -> Array[String]:
	var issues: Array[String] = []
	
	issues.append_array(get_editor_issues())
	
	return issues
