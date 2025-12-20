## Display UI for showing information about objects being targeted, manipulated, or built
## [br][br]
## TargetInformer provides a dynamic UI component that displays object information based on
## the current game state. It responds to three different contexts with clear priority:[br]
## [br]
## [b]Priority System:[/b][br]
## 1. [b]Manipulation[/b] (Highest Priority): Shows info for actively manipulated objects[br]
## 2. [b]Building[/b]: Shows info for building preview objects[br]
## 3. [b]Targeting[/b] (Lowest Priority): Shows info for hovered/targeted objects[br]
## [br]
## [b]Signal Flow:[/b][br]
## - [code]GridTargetingState.target_changed[/code] → Updates display on hover[br]
## - [code]ManipulationState.active_target_node_changed[/code] → Overrides targeting info[br]
## - [code]BuildingState.preview_changed[/code] → Shows building preview info[br]
## [br]
## [b]Usage:[/b][br]
## [codeblock]
## var informer = TargetInformer.new()
## add_child(informer)
## informer.resolve_gb_dependencies(composition_container)
## # Now responds automatically to targeting/manipulation/building changes
## [/codeblock]
## [br]
## Override [code]_to_string()[/code] on displayed object nodes to show custom names
class_name TargetInformer
extends GBControl


@export var target: Node:
	set(value):
		if target != null:
			target.tree_exiting.disconnect(_on_target_tree_exiting)

		target = value

		if target != null:
			target.tree_exiting.connect(_on_target_tree_exiting)
		setup()

## Building state reference - connects to preview_changed signal.[br]
## When building preview changes, displays preview object information.
var _building_state: BuildingState:
	set(value):
		if _building_state != null:
			_building_state.preview_changed.disconnect(_on_building_preview_changed)

		_building_state = value

		if _building_state != null:
			_building_state.preview_changed.connect(_on_building_preview_changed)

## Manipulation state reference - connects to active_target_node_changed, started, and canceled signals.[br]
## [b]Takes priority[/b] over targeting info when active manipulation exists.
var _manipulation_state: ManipulationState:
	set(value):
		if _manipulation_state != null:
			_manipulation_state.active_target_node_changed.disconnect(_on_manipulation_target_changed)
			_manipulation_state.started.disconnect(_on_manipulation_started)
			_manipulation_state.canceled.disconnect(_on_manipulation_canceled)

		_manipulation_state = value

		if _manipulation_state != null:
			_manipulation_state.active_target_node_changed.connect(_on_manipulation_target_changed)
			_manipulation_state.started.connect(_on_manipulation_started)
			_manipulation_state.canceled.connect(_on_manipulation_canceled)

## Targeting state reference - connects to target_changed signal.[br]
## Displays info for any targeted object (hover). [b]Lowest priority:[/b] overridden by manipulation/building.
var _targeting_state: GridTargetingState:
	set(value):
		if _targeting_state != null:
			_targeting_state.target_changed.disconnect(_on_targeting_target_changed)

		_targeting_state = value

		if _targeting_state != null:
			_targeting_state.target_changed.connect(_on_targeting_target_changed)

## When set, will hide when the mode is off and show otherwise. Optional.
var _mode_state: ModeState:
	set(value):
		if _mode_state != null:
			_mode_state.mode_changed.disconnect(_on_mode_changed)

		_mode_state = value

		if _mode_state != null:
			_on_mode_changed(_mode_state.current)
			_mode_state.mode_changed.connect(_on_mode_changed)

var _settings: TargetInfoSettings

@export_group("Child Nodes")
@export var info_parent: Control

var _name_label: Label
var _position_label: Label


## Initialize the target informer display when ready.
func _ready() -> void:
	refresh()


## Update the target information display every frame.
func _process(delta: float) -> void:
	refresh()


## Resolve dependencies from the composition container.[br][br]
## [code]p_container[/code]: [i]GBCompositionContainer[/i] - Container with states and configuration
func resolve_gb_dependencies(p_container: GBCompositionContainer) -> void:
	var states := p_container.get_states()
	_building_state = states.building
	_manipulation_state = states.manipulation
	_targeting_state = states.targeting
	_mode_state = states.mode
	_settings = p_container.get_visual_settings().target_info


## Clears all child controls from the info parent container.
func clear():
	if info_parent:
		for child in info_parent.get_children():
			child.free()


## Updates the target information display with current target data.
func refresh():
	if target == null:
		return

	if _position_label:
		_position_label.text = _format_position(target)


func setup():
	clear()

	if target == null:
		return

	var display_name = GBObjectUtils.get_display_name(target)
	_name_label = add_info_label(display_name)

	if target is Node2D || target is Node3D:
		_position_label = add_info_label(_format_position(target))


## Adds an information label to the info parent container.
## Creates a new label with the specified text and adds it to the UI.[br][br]
## [code]p_text[/code]: [i]String[/i] - Text to display in the label
func add_info_label(p_text: String) -> Label:
	var label = Label.new()
	label.text = p_text
	info_parent.add_child(label)
	return label


func track_manipulatable_target():
	if _manipulation_state.active_target_node == null:
		# No active manipulation - check if there's a targeting state target to show
		if _targeting_state and _targeting_state.target != null:
			target = _targeting_state.target
		else:
			target = null
		return

	# active_target_node already stores the root node (not Manipulatable wrapper)
	target = _manipulation_state.active_target_node


## Formats a node's global position for display.
## Uses the position format and decimal precision from settings.[br][br]
## [code]p_target[/code]: [i]Node[/i] - Node to format position for (must be Node2D or Node3D)
func _format_position(p_target: Node) -> String:
	# Handle case where settings aren't configured yet
	if _settings == null:
		return "Position: (%s, %s)" % [str(p_target.global_position.x), str(p_target.global_position.y)]
	
	var x_str = str(p_target.global_position.x).pad_decimals(_settings.position_decimals)
	var y_str = str(p_target.global_position.y).pad_decimals(_settings.position_decimals)

	return _settings.position_format % [x_str, y_str]


func _on_manipulation_target_changed(p_target: Manipulatable):
	if p_target == null || p_target.root == null:
		# No active manipulation - check if there's a targeting state target to show
		if _targeting_state and _targeting_state.target != null:
			target = _targeting_state.target
		else:
			target = null
		return

	target = p_target.root


func _on_manipulation_started(p_data: ManipulationData):
	if p_data == null || p_data.target == null:
		return

	target = p_data.target.root


func _on_manipulation_finished(_p_data: ManipulationData):
	track_manipulatable_target()


func _on_manipulation_canceled(_p_data: ManipulationData):
	track_manipulatable_target()


func _on_target_tree_exiting():
	target = null


func _on_building_preview_changed(p_preview: Node):
	if p_preview == null:
		# No building preview - check if there's a targeting state target to show
		if _targeting_state and _targeting_state.target != null:
			target = _targeting_state.target
		else:
			target = null
	else:
		target = p_preview


func _on_mode_changed(p_mode: GBEnums.Mode):
	match p_mode:
		GBEnums.Mode.OFF:
			hide()
		_:
			show()


## Handle targeting state changes - shows info for any targeted object (hover).[br]
## [br]
## [b]Priority Logic:[/b] If manipulation is active (active_target_node != null) or
## building preview is active (preview != null), this handler returns early without 
## updating the display. This ensures manipulation and building preview info takes 
## precedence over targeting info.[br]
## [br]
## [code]p_new[/code]: [i]Node2D[/i] - Newly targeted node (can be null)[br]
## [code]_p_old[/code]: [i]Node2D[/i] - Previously targeted node (unused)
func _on_targeting_target_changed(p_new: Node2D, _p_old: Node2D):
	# Priority: If manipulation is active, don't override with targeting
	if _manipulation_state and _manipulation_state.active_target_node != null:
		return
	
	# Priority: If building preview is active, don't override with targeting
	if _building_state and _building_state.preview != null:
		return
	
	# Show info for the targeted object (hover)
	target = p_new
