class_name PawnInfoPanel
extends MarginContainer

@export var data_tabs: TabContainer
var pawn: PawnBase

## Robot readout widgets (WI-28), built in code for RobotPawnBase pawns only.
var _robot_energy_bar: ProgressBar = null
var _robot_integrity_bar: ProgressBar = null
var _robot_state_label: Label = null


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
	_setup_robot_controls()
	_setup_visitor_controls()

## Wage readout + fire button (WI-25) for organic crew only - drones and robots
## draw no wage and can't be fired. Built in code and inserted just under the
## name row; the panel is instantiated fresh per pawn, so nothing to tear down.
func _setup_crew_controls() -> void:
	# Visitors have needs but aren't crew (WI-33): no wage, can't be fired - their
	# own readout is _setup_visitor_controls instead.
	if pawn is RobotPawnBase or pawn.is_visitor or pawn.get_component_by_type(PawnNeedsComponent) == null:
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

## Robot energy + integrity bars and a live state line (WI-28), for RobotPawnBase
## pawns only. Built in code and inserted under the name row, mirroring
## _setup_crew_controls - robots have no needs tab, so this is their vitals view.
func _setup_robot_controls() -> void:
	if not pawn is RobotPawnBase:
		return
	var robot := pawn as RobotPawnBase
	var power: RobotPowerComponent = robot.power_component
	var integrity: RobotIntegrityComponent = robot.integrity_component
	var header_hbox: Node = %PawnNameLabel.get_parent()
	var vbox: Node = header_hbox.get_parent()
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 2)
	if power != null:
		_robot_energy_bar = _make_stat_row(section, "Energy", power.energy_max, power.energy)
		power.energy_changed.connect(_on_robot_energy_changed)
	if integrity != null:
		_robot_integrity_bar = _make_stat_row(section, "Integrity", integrity.integrity_max, integrity.integrity)
		integrity.integrity_changed.connect(_on_robot_integrity_changed)
	_robot_state_label = Label.new()
	_robot_state_label.self_modulate = Color(1, 1, 1, 0.7)
	section.add_child(_robot_state_label)
	vbox.add_child(section)
	vbox.move_child(section, header_hbox.get_index() + 1)
	pawn.job_changed.connect(_refresh_robot_state)
	_refresh_robot_state()

## Guest readout (WI-33): wallet + visit time remaining, inserted under the name
## row like the crew/robot controls. VisitorPawn only; refreshed live in _process.
var _visitor_wallet_label: Label = null
var _visitor_time_label: Label = null

func _setup_visitor_controls() -> void:
	if not pawn is VisitorPawn:
		return
	var header_hbox: Node = %PawnNameLabel.get_parent()
	var vbox: Node = header_hbox.get_parent()
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 2)
	_visitor_wallet_label = Label.new()
	_visitor_wallet_label.self_modulate = Color(1, 1, 1, 0.8)
	section.add_child(_visitor_wallet_label)
	_visitor_time_label = Label.new()
	_visitor_time_label.self_modulate = Color(1, 1, 1, 0.8)
	section.add_child(_visitor_time_label)
	vbox.add_child(section)
	vbox.move_child(section, header_hbox.get_index() + 1)
	_refresh_visitor_readout()

func _refresh_visitor_readout() -> void:
	if not is_instance_valid(pawn) or not pawn is VisitorPawn:
		return
	var visitor := pawn as VisitorPawn
	if is_instance_valid(_visitor_wallet_label):
		_visitor_wallet_label.text = "Wallet: %d cr" % visitor.personal_credits
	if is_instance_valid(_visitor_time_label):
		_visitor_time_label.text = "Visit: %.0f h left" % maxf(visitor.stay_hours_remaining, 0.0)

## A "<label> [====]" row appended to `parent`; returns the ProgressBar.
func _make_stat_row(parent: VBoxContainer, label_text: String, max_value: float, value: float) -> ProgressBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(56, 0)
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(90, 0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.max_value = max_value
	bar.value = value
	bar.show_percentage = true
	row.add_child(bar)
	parent.add_child(row)
	return bar

func _on_robot_energy_changed(new_energy: float) -> void:
	if is_instance_valid(_robot_energy_bar):
		_robot_energy_bar.value = new_energy
	_refresh_robot_state()

func _on_robot_integrity_changed(new_integrity: float) -> void:
	if is_instance_valid(_robot_integrity_bar):
		_robot_integrity_bar.value = new_integrity
	_refresh_robot_state()

func _refresh_robot_state() -> void:
	if not is_instance_valid(_robot_state_label) or not pawn is RobotPawnBase:
		return
	_robot_state_label.text = "State: " + _robot_state_text()

func _robot_state_text() -> String:
	var robot := pawn as RobotPawnBase
	if robot.power_component != null and robot.power_component.must_recharge():
		return "Out of power — crawling"
	var job: JobBase = pawn.current_job
	if job is Job_Recharge:
		return "Recharging"
	if job is Job_GetRepaired:
		return "Getting repaired"
	if robot.power_component != null and robot.power_component.wants_recharge():
		return "Seeking a charger"
	if job == null or job is Job_Idle or job is Job_IdleWander:
		return "Idle"
	return "Working"

func _process(_delta: float) -> void:
	if is_instance_valid(pawn):
		set_position(pawn.get_global_transform_with_canvas().get_origin())
		if pawn is VisitorPawn:
			_refresh_visitor_readout()
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
	if pawn.is_visitor:
		# Guests (WI-33) read as outsiders, no shift indicator.
		%PawnNameLabel.text = "%s — Guest" % (pawn.pawn_name if not pawn.pawn_name.is_empty() else "Visitor")
	elif pawn.schedule == null:
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
