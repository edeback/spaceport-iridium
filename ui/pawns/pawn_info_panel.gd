class_name PawnInfoPanel
extends MarginContainer

@export var data_tabs: TabContainer
var pawn: PawnBase


func set_pawn(_pawn: PawnBase) -> void:
	pawn = _pawn
	if pawn == null:
		_on_exit_button_pressed()
		return
	_refresh_title()
	# Shift state flips on the hour, not per frame.
	Global.time_manager.hour_changed.connect(_on_hour_changed)
	%AlertLabel.text = ""
	for child_node: Node in data_tabs.get_children():
		child_node.set_pawn(pawn)
	if pawn.movement_component:
		Global.ui_in_game.debug_path_position = pawn.movement_component.get_debug_path_detailed()
		pawn.movement_component.movement_started.connect(_movement_started)
	if pawn.schedule != null:
		pawn.schedule.this_shift_changed.connect(_refresh_title)
	
func _process(_delta: float) -> void:
	if is_instance_valid(pawn):
		set_position(pawn.get_global_transform_with_canvas().get_origin())
	else:
		pawn = null
		_on_exit_button_pressed()

func _movement_started() -> void:
	Global.ui_in_game.debug_path_position = pawn.movement_component.get_debug_path_detailed()

func _on_hour_changed(_hour: int) -> void:
	if is_instance_valid(pawn):
		_refresh_title()

## Name plus shift indicator (WI-06); unscheduled pawns (drones) show no
## indicator rather than a meaningless "On shift".
func _refresh_title() -> void:
	var display_name: String = pawn.pawn_name if not pawn.pawn_name.is_empty() else "Crew member"
	if pawn.schedule == null:
		%PawnNameLabel.text = display_name
	else:
		%PawnNameLabel.text = "%s — %s" % [display_name, "On shift" if pawn.is_on_shift() else "Off shift"]

func _on_exit_button_pressed() -> void:
	if Global.time_manager.hour_changed.is_connected(_on_hour_changed):
		Global.time_manager.hour_changed.disconnect(_on_hour_changed)
	if is_instance_valid(pawn):
		pawn.movement_component.movement_started.disconnect(_movement_started)
		if pawn.schedule != null:
			pawn.schedule.this_shift_changed.disconnect(_refresh_title)
	Global.ui_in_game.debug_path_position = []
	queue_free()
