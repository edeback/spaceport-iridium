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
	_setup_crew_controls()

## Wage readout + fire button (WI-25) for organic crew only - drones and robots
## draw no wage and can't be fired. Built in code and inserted just under the
## name row; the panel is instantiated fresh per pawn, so nothing to tear down.
func _setup_crew_controls() -> void:
	if pawn is MiningDronePawn or pawn.get_component_by_type(PawnNeedsComponent) == null:
		return
	var header_hbox: Node = %PawnNameLabel.get_parent()
	var vbox: Node = header_hbox.get_parent()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var wage: int = EconomyManager.wage_for(pawn.hire_price, Global.economy_manager.wage_fraction)
	var wage_label := Label.new()
	wage_label.text = "Wage: %d cr/cycle" % wage
	wage_label.self_modulate = Color(1, 1, 1, 0.7)
	wage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(wage_label)
	var fire_btn := Button.new()
	fire_btn.text = "Fire"
	fire_btn.pressed.connect(_on_fire_pressed)
	row.add_child(fire_btn)
	vbox.add_child(row)
	vbox.move_child(row, header_hbox.get_index() + 1)

func _on_fire_pressed() -> void:
	if not is_instance_valid(pawn):
		return
	var severance: int = Global.economy_manager.severance_for(pawn)
	var name_text: String = pawn.pawn_name if not pawn.pawn_name.is_empty() else "this crew member"
	var dialog := ConfirmationDialog.new()
	dialog.title = "Fire crew member"
	dialog.dialog_text = ("Fire %s? Severance costs %d cr." % [name_text, severance]) if severance > 0 \
		else "Fire %s? They will pack up and leave the station." % name_text
	dialog.ok_button_text = "Fire"
	dialog.confirmed.connect(func() -> void:
		if is_instance_valid(pawn):
			Global.economy_manager.fire_pawn(pawn)
		_on_exit_button_pressed())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

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
