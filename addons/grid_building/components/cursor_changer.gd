## Optional component for changing the cursors when the grid builder mode state changes.
class_name GBCursorChanger
extends GBSystemsComponent

var _mode_state: ModeState:
	set(value):
		if _mode_state:
			_mode_state.mode_changed.disconnect(_on_mode_changed)

		_mode_state = value

		if _mode_state:
			_mode_state.mode_changed.connect(_on_mode_changed)

var _cursors: CursorSettings
var _logger : GBLogger

func _ready():
	tree_exiting.connect(_on_tree_exiting)

func resolve_gb_dependencies(p_container: GBCompositionContainer) -> void:
	_mode_state = p_container.get_states().mode
	_cursors = p_container.get_visual_settings().cursor
	_logger = p_container.get_logger()
	
	assert(_cursors != null, "Cursor settings must be defined for cursor change to work.")
	get_runtime_issues()
	
func get_runtime_issues() -> bool:
	var issues : Array[String] = []
	
	if _cursors == null:
		issues.append("You must create the cursor settings in the CompositionContainer in the GBInjectorSystem for this node to work.")
	
	_logger.log_issues(issues)
	return issues.is_empty()

func _on_mode_changed(p_mode: GBEnums.Mode):
	var cursor = get_cursor(p_mode)
	Input.set_custom_mouse_cursor(cursor)

func get_cursor(p_mode: GBEnums.Mode):
	match p_mode:
		GBEnums.Mode.OFF:
			return null
		GBEnums.Mode.INFO:
			return _cursors.info
		GBEnums.Mode.BUILD:
			return _cursors.build
		GBEnums.Mode.MOVE:
			return _cursors.move
		GBEnums.Mode.DEMOLISH:
			return _cursors.demolish

func _on_tree_exiting():
	Input.set_custom_mouse_cursor(null)
