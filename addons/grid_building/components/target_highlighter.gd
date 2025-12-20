## When a target node is set on the build state, marks it by colors
## based on the settings of its Manipulatable node (or lack thereof)
class_name TargetHighlighter
extends GBSystemsComponent

var mode_state : ModeState

var targeting_state : GridTargetingState :
	set(value):
		if is_instance_valid(targeting_state):
			targeting_state.target_changed.disconnect(_on_target_changed)
			
		targeting_state = value
		
		if is_instance_valid(targeting_state):
			targeting_state.target_changed.connect(_on_target_changed)

var manipulation_state : ManipulationState :
	set(value):
		if is_instance_valid(manipulation_state):
			manipulation_state.data_changed.disconnect(_on_data_changed)
			manipulation_state.started.disconnect(_on_started)
			manipulation_state.canceled.disconnect(_on_canceled)
			manipulation_state.finished.disconnect(_on_finished)
			
		manipulation_state = value
		
		if is_instance_valid(manipulation_state):
			manipulation_state.data_changed.connect(_on_data_changed)
			manipulation_state.started.connect(_on_started)
			manipulation_state.canceled.connect(_on_canceled)
			manipulation_state.finished.connect(_on_finished)
		
## Holds color settings for how a highlighted target should be displayed in the game
## world
var highlight_settings : HighlightSettings

## The currently highlighter target. When set to a new value, the old one's modulate clears automatically
var current_target : CanvasItem :
	set(value):
		# Reset colors on old current_target whenever the current_target changes
		if current_target != null:
			current_target.modulate = highlight_settings.reset_color
	
		current_target = value

## Resolves dependencies from the composition container.
## Sets up mode state, targeting state, manipulation state, and highlight settings.[br][br]
## [code]p_container[/code]: [i]GBCompositionContainer[/i] - Container with system dependencies and settings
func resolve_gb_dependencies(p_container : GBCompositionContainer) -> void:
	mode_state = p_container.get_states().mode
	targeting_state = p_container.get_states().targeting
	manipulation_state = p_container.get_states().manipulation
	highlight_settings = p_container.get_visual_settings().highlight
	
	# React to mode changes to refresh colors without requiring a target change
	if is_instance_valid(mode_state) and not mode_state.mode_changed.is_connected(_on_mode_changed):
		mode_state.mode_changed.connect(_on_mode_changed)
	
	var validation_issues = get_runtime_issues()
	if not validation_issues.is_empty():
		for issue in validation_issues:
			push_warning("TargetHighlighter validation: " + issue)

## Sets a canvas item modulate to either the valid or invalid move color.
## Returns the new modulate color.[br][br]
## [code]p_target[/code]: [i]CanvasItem[/i] - Target canvas item to set modulate color on[br]
## [code]p_movable[/code]: [i]bool[/i] - Whether the target is movable (valid) or not (invalid)
func set_movable_display(p_target : CanvasItem, p_movable : bool) -> Color:
	if p_target == null: return Color.BLACK
	
	if p_movable:
		p_target.modulate = highlight_settings.move_valid_color
	else:
		p_target.modulate = highlight_settings.move_invalid_color
		
	return p_target.modulate

## Sets a canvas item modulate to either the valid or invalid demolish color.
## Returns the new modulate color.[br][br]
## [code]p_target[/code]: [i]CanvasItem[/i] - Target canvas item to set modulate color on[br]
## [code]p_demolishable[/code]: [i]bool[/i] - Whether the target is demolishable (valid) or not (invalid)
func set_demolish_display(p_target : CanvasItem, p_demolishable : bool) -> Color:
	if p_target == null: return Color.BLACK
	
	if p_demolishable:
		p_target.modulate = highlight_settings.demolish_valid_color
	else:
		p_target.modulate = highlight_settings.demolish_invalid_color

	return p_target.modulate

## Setsthe color of a build preview to the preview color
func set_build_preview_display(p_target : CanvasItem):
	p_target.modulate = highlight_settings.build_preview_color
	
func set_info_display(p_target : CanvasItem):
	p_target.modulate = highlight_settings.info_hover_color

## Sets the target modulate to colors based on current mode actionability.
## Changes color based on whether the target can be affected by the current mode's action.[br][br]
## [code]p_target[/code]: [i]CanvasItem[/i] - Target canvas item to set actionable colors on
func set_actionable_colors(p_target : CanvasItem) -> Color:
	var manipulatable : Manipulatable = GBSearchUtils.find_first(p_target, Manipulatable)
	var settings : ManipulatableSettings
	
	if manipulatable:
		settings = manipulatable.settings
	
	match(mode_state.current):
		GBEnums.Mode.BUILD:
			# Only highlight preview objects (those with building_node script) in build mode
			if _is_preview_object(p_target):
				set_build_preview_display(p_target)
			else:
				# Don't highlight existing world objects in build mode
				p_target.modulate = highlight_settings.reset_color
		GBEnums.Mode.INFO:
			set_info_display(p_target)
		GBEnums.Mode.MOVE:
			if manipulatable != null:
				set_movable_display(p_target, manipulatable.is_movable())
			else:
				set_movable_display(p_target, false)
		GBEnums.Mode.DEMOLISH:
			if manipulatable != null:
				set_demolish_display(p_target, manipulatable.is_demolishable())
			else:
				set_demolish_display(p_target, false)

	return p_target.modulate

## Checks if the highlighter should highlight the target based on manipulation data.
## Returns true if the target matches the manipulation data target.[br][br]
## [code]p_data[/code]: [i]ManipulationData[/i] - Current manipulation data to compare against[br]
## [code]p_target[/code]: [i]CanvasItem[/i] - Target canvas item to check for highlighting
func should_highlight(p_data : ManipulationData, p_target : CanvasItem) -> bool:
	if p_target == null:
		return false
		
	if p_data == null:
		return true
		
	if p_data.target == null:
		return false
		
	if not is_instance_valid(p_data.target.root):
		return false
		
	return p_data.target.root == p_target

## Returns true if the highlighter is locked by active manipulation state.
## A locked highlighter won't respond to target changes until manipulation finishes.
func is_locked() -> bool:
	if manipulation_state == null: return false
	return manipulation_state.data != null

## Validates that all required dependencies are properly set.
## Returns true if all dependencies are valid, false otherwise.
func get_runtime_issues() -> Array[String]:
	return GBValidation.check_not_null(self, ["mode_state", "manipulation_state", "highlight_settings", "targeting_state"])

func _on_data_changed(p_manipulation : ManipulationData):
	if p_manipulation == null || p_manipulation.target == null || p_manipulation.target.root == null:
		current_target = null # Clear
		return
	
	current_target = p_manipulation.source.root
	
	match mode_state.current:
		GBEnums.Mode.DEMOLISH:
			set_demolish_display(current_target, p_manipulation.target.is_demolishable())

## Move the modulate to the manipulation target and set the manipulation color
func _on_started(p_data : ManipulationData):
	if not is_instance_valid(p_data) || p_data.target == null:
		return
	
	current_target = p_data.target.root
	current_target.modulate = highlight_settings.active_manipulation_color

## Return the modulate to the highlighter and set the color to the default
func _on_canceled(p_data : ManipulationData):
	current_target = null

func _on_finished(p_data : ManipulationData):
	current_target = null

## Response for when the grid targeting state target changes
func _on_target_changed(p_target : Node, p_old : Node):
	if is_locked(): return
	
	var old = current_target
	current_target = p_target
	
	# Manipulation target must match the changed target in order for it's color to be changed
	if not should_highlight(manipulation_state.data, p_target): 
		return
		
		# current_target != old && 
	if is_instance_valid(current_target):
		set_actionable_colors(current_target)

## Refresh colors when mode changes (e.g. MOVE -> DEMOLISH) for the same target
func _on_mode_changed(p_mode : GBEnums.Mode):
	if is_locked():
		return
	if is_instance_valid(current_target):
		set_actionable_colors(current_target)

## Check if the target is a preview object (has building_node script attached)
## Returns true if the target has the building_node script, indicating it's a preview object
func _is_preview_object(p_target: CanvasItem) -> bool:
	if p_target == null:
		return false
	
	# Look for building_node script in the target or its children
	var building_node_script_path := "res://addons/grid_building/components/building_node.gd"
	
	# Check if target itself has the building_node script
	if p_target.get_script() != null and p_target.get_script().resource_path == building_node_script_path:
		return true
	
	# Check children for building_node script (common case where script is on a child node)
	for child in p_target.get_children():
		if child.get_script() != null and child.get_script().resource_path == building_node_script_path:
			return true
	
	return false
