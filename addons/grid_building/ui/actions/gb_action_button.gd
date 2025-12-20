class_name GBActionButton
extends Button
## Starts / Stops a Grid Builder press_action

@export var press_action : StringName = ""
@export var represented_mode : GBEnums.Mode

## Mode state for monitoring mode changes.
var _mode_state : ModeState :
	set(value):
		if _mode_state != null:
			_mode_state.mode_changed.disconnect(_on_mode_changed)
		
		_mode_state = value
		
		if _mode_state != null:
			_mode_state.mode_changed.connect(_on_mode_changed)

func _ready():
	pressed.connect(_on_pressed)

## Injects dependencies from the composition container.[br][br]
## [code]p_container[/code]: [i]GBCompositionContainer[/i] - Container with required services
func resolve_gb_dependencies(p_container : GBCompositionContainer) -> void:
	_mode_state = p_container.get_mode_state()
	
	var validation_issues = get_runtime_issues()
	if not validation_issues.is_empty():
		for issue in validation_issues:
			push_warning("GBActionButton validation: " + issue)
	
## Validates button configuration and dependencies.
## Returns list of validation issues found.[br][br]
## [code]return[/code]: [i]Array[String][/i] - List of validation issues (empty if valid)
func get_runtime_issues() -> Array[String]:
	var issues: Array[String] = []
	
	if press_action.is_empty():
		issues.append("No [press_action] set on %s" % get_path())
	elif not InputMap.has_action(press_action):
		issues.append("[press_action] name '%s' does not exist in ProjectSettings -> InputMap. press_action set at %s" % [press_action, get_path()])
		
	if toggle_mode == false:
		issues.append("Toggled mode should be on so the button can represent the on / off of it's represented_mode")
	
	if _mode_state == null:
		issues.append("[_mode_state] should be set or injected into button at %s" % get_path())
		
	return issues
		
func _on_pressed():
	# Only send the input event; do not toggle mode directly here
	var event = InputEventAction.new()
	event.action = press_action
	event.pressed = true
	Input.parse_input_event(event)

func _on_mode_changed(p_mode : GBEnums.Mode):
	if p_mode == represented_mode:
		button_pressed = true
	else:
		button_pressed = false
