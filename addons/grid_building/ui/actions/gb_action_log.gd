## Shows recent messages from the grid building plugin actions within the context of the GBCompositionContainer scope
class_name GBActionLog
extends GBControl

# Constants for validation
const REQUIRED_DEPENDENCIES: Array[String] = ["_actions", "_building_state", "_manipulation_state", "_mode_state"]

## Visual output area for where messages go when output from the build log
@export var message_log : RichTextLabel

## Build log settings injected from centralized configuration (private)
var _settings : ActionLogSettings

var _building_state : BuildingState :
	set(value):
		_disconnect_building_state()
		_building_state = value
		_connect_building_state()
		
var _manipulation_state : ManipulationState :
	set(value):
		_disconnect_manipulation_state()
		_manipulation_state = value
		_connect_manipulation_state()

var _mode_state : ModeState :
	set(value):
		_disconnect_mode_state()
		_mode_state = value
		_connect_mode_state()

var _debug : GBDebugSettings
var _actions : GBActions
var _logger : GBLogger

## DRY helper: Disconnect building state signals
func _disconnect_building_state() -> void:
	if _building_state != null:
		_building_state.success.disconnect(_on_build_success)
		_building_state.failed.disconnect(_on_build_failed)

## DRY helper: Connect building state signals  
func _connect_building_state() -> void:
	if _building_state != null:
		_building_state.success.connect(_on_build_success)
		_building_state.failed.connect(_on_build_failed)

## DRY helper: Disconnect manipulation state signals
func _disconnect_manipulation_state() -> void:
	if is_instance_valid(_manipulation_state):
		if _manipulation_state.started.is_connected(_on_manipulation_started):
			_manipulation_state.started.disconnect(_on_manipulation_started)
		_manipulation_state.failed.disconnect(_on_manipulation_failed)
		_manipulation_state.finished.disconnect(_on_manipulation_finished)

## DRY helper: Connect manipulation state signals
func _connect_manipulation_state() -> void:
	if is_instance_valid(_manipulation_state):
		_manipulation_state.started.connect(_on_manipulation_started)
		_manipulation_state.failed.connect(_on_manipulation_failed)
		_manipulation_state.finished.connect(_on_manipulation_finished)

## DRY helper: Disconnect mode state signals
func _disconnect_mode_state() -> void:
	if is_instance_valid(_mode_state):
		_mode_state.mode_changed.disconnect(_on_mode_changed)

## DRY helper: Connect mode state signals
func _connect_mode_state() -> void:
	if is_instance_valid(_mode_state):
		_mode_state.mode_changed.connect(_on_mode_changed)
		
func _ready():
	clear_log()
	
	# Only show on_ready_message if settings are already injected
	var current_settings = get_settings()
	if current_settings and current_settings.on_ready_message != null && current_settings.on_ready_message != "":
		message_log.append_text(current_settings.on_ready_message + "\n")

func resolve_gb_dependencies(p_container : GBCompositionContainer) -> void:
	assert(p_container != null, "Must pass a reference to the Grid Building composition root to inject dependencies with resolve_gb_dependencies call.")
	_building_state = p_container.get_states().building
	_manipulation_state = p_container.get_states().manipulation
	_mode_state = p_container.get_mode_state()
	_actions = p_container.get_actions()
	_debug = p_container.get_debug_settings()
	_logger = p_container.get_logger()
	_settings = p_container.get_settings().action_log

func clear_log():
	message_log.clear()

## Lazy initialization for settings - only creates defaults if not injected
## Public getter for testing and external access
func get_settings() -> ActionLogSettings:
	if not _settings:
		_settings = ActionLogSettings.new()
		if _logger:
			_logger.log_warning( "GBBuildLog: No ActionLogSettings injected, using defaults")
		else:
			push_warning("GBBuildLog: No ActionLogSettings injected and no logger available, using defaults")
	return _settings
	
## Validates that all required dependencies are present
func validate_setup() -> bool:
	var issues: Array[String] = GBValidation.check_not_null(self, REQUIRED_DEPENDENCIES)
	return issues.is_empty()

## Adds validation results to the log as settings request.
func append_validation_results(p_results : ValidationResults):
	var current_settings = get_settings()
	var is_successful_value: bool = p_results.is_successful()
	
	if current_settings.show_validation_message:
		message_log.append_text(p_results.message + "\n")
	
	if not is_successful_value && current_settings.print_failed_reasons:
		_print_reasons(p_results.rule_results)
		
	if is_successful_value && current_settings.print_success_reasons:
		_print_reasons(p_results.rule_results, false)

## DRY helper: Adds placement report issues to the log
func append_placement_report_issues(p_report: PlacementReport) -> void:
	if not p_report:
		return
		
	var issues: Array[String] = p_report.get_issues()
	if issues.is_empty():
		return
		
	_append_issues_list(issues)

## DRY helper: Appends a list of issue strings to the message log
func _append_issues_list(issues: Array[String]) -> void:
	var current_settings = get_settings()
	var max_issues: int = min(issues.size(), current_settings.max_failure_reasons)
	for i in range(max_issues):
		message_log.append_text(current_settings.issue_bullet_prefix + issues[i] + "\n")
	
	if issues.size() > current_settings.max_failure_reasons:
		message_log.append_text(current_settings.issue_bullet_prefix + "... and %d more issues\n" % (issues.size() - current_settings.max_failure_reasons))

func append_manipulation(p_data : ManipulationData):
	var message : String = p_data.message + "\n"
	
	message_log.append_text(message)

	if p_data.results:
		append_validation_results(p_data.results)

## Checks whether the action data should show in the log or not.
func should_show(p_action : GBEnums.Action) -> bool:
	var current_settings = get_settings()
	if not current_settings.show_move_finished && p_action == GBEnums.Action.MOVE:
		return false
	elif not current_settings.show_demolish && p_action == GBEnums.Action.DEMOLISH:
		return false

	return true

## Prints the reasons for each rule result to the message log.
## p_failed_only: bool - Whether to print only failed results (default true)
func _print_reasons(p_rule_results : Dictionary[PlacementRule, RuleResult], p_failed_only : bool = true):
	if p_rule_results.size() == 0:
		return
	
	var issues_to_show: Array[String] = []
	for rule_key in p_rule_results.keys():
		var rule_result = p_rule_results[rule_key]

		if p_failed_only && rule_result.is_successful():
			continue
			
		# Collect reasons into array for DRY processing
		if rule_result.issues and not rule_result.issues.is_empty():
			issues_to_show.append_array(rule_result.issues)
		elif rule_result.has_method("get_reason") and rule_result.get_reason():
			issues_to_show.append(rule_result.get_reason())
	
	# Use DRY helper to display issues
	_append_issues_list(issues_to_show)
	
## DRY helper: Determines display name for objects with fallback 
func _get_display_name_safe(obj: Node) -> String:
	if not obj:
		return "Unknown"
		
	return GBObjectUtils.get_display_name(obj)

## DRY helper: Handles color and message formatting for build results
func _handle_build_result(p_data: BuildActionData, is_success: bool) -> void:
	var current_settings = get_settings()
	# Suppress drag/area builds unless explicitly enabled
	if not current_settings.print_on_drag_build and p_data.build_type != GBEnums.BuildType.SINGLE:
		return
	
	# Choose color & message depending on success/failure
	if is_success:
		message_log.push_color(current_settings.success_color)
		var placed_obj: Node = p_data.report.placed if p_data.report else null
		var name: String = _get_display_name_safe(placed_obj)
		var msg: String = current_settings.built_message if not current_settings.built_message.is_empty() else "Built: %s"
		message_log.append_text(msg % name + "\n")
	else:
		message_log.push_color(current_settings.failed_color)
		var preview_obj: Node = p_data.get_preview()
		var name: String = _get_display_name_safe(preview_obj)
		var msg: String = current_settings.fail_build_message if not current_settings.fail_build_message.is_empty() else "Build failed: %s"
		message_log.append_text(msg % name + "\n")
	
	# Show validation issues from placement report instead of direct validation
	if (p_data.build_type == GBEnums.BuildType.SINGLE or current_settings.print_on_drag_build) and p_data.report:
		# Only show detailed failure reasons if enabled in settings
		if not is_success and current_settings.print_failed_reasons:
			append_placement_report_issues(p_data.report)
	
	message_log.pop()

func _on_build_success(p_data: BuildActionData) -> void:
	_handle_build_result(p_data, true)

func _on_build_failed(p_data: BuildActionData) -> void:
	_handle_build_result(p_data, false)
	
## DRY helper: Handles manipulation result display with consistent color coding
func _handle_manipulation_result(p_data: ManipulationData, is_finished: bool) -> void:
	if not should_show(p_data.action):
		return
	
	# Determine success state and color
	var settings : ActionLogSettings = get_settings()
	var is_successful: bool = is_finished and (not p_data.results or p_data.results.is_successful())
	var color: Color = settings.success_color if is_successful else settings.failed_color
	
	message_log.push_color(color)
	append_manipulation(p_data)
	message_log.pop()

func _on_manipulation_started(p_data : ManipulationData) -> void:
	var settings : ActionLogSettings = get_settings()
	# Suppress started messages unless explicitly enabled
	if not settings.show_move_started:
		return
	
	# Use neutral color for started messages (not success/failure yet)
	message_log.push_color(settings.success_color)
	append_manipulation(p_data)
	message_log.pop()

func _on_manipulation_failed(p_data : ManipulationData):
	_handle_manipulation_result(p_data, false)
	
func _on_manipulation_finished(p_data : ManipulationData):
	_handle_manipulation_result(p_data, true)

## Handles mode change events and outputs to action log if enabled
func _on_mode_changed(p_mode: GBEnums.Mode) -> void:
	var current_settings = get_settings()
	if not current_settings.show_mode_changes:
		return
	
	# Convert mode enum to readable string
	var mode_name: String = GBEnums.Mode.keys()[p_mode]
	
	# Use neutral color for mode changes (not success/failure)
	message_log.push_color(Color.WHITE)
	var msg: String = current_settings.mode_change_message if not current_settings.mode_change_message.is_empty() else "Mode changed to: %s"
	message_log.append_text(msg % mode_name + "\n")
	message_log.pop()
