class_name RobotVitalsTab
extends VBoxContainer

## A robot's energy, integrity and what it is currently doing about them (WI-28,
## moved into the inspector by WI-51).
##
## This replaces `Needs` rather than sitting alongside it. Robots carry no
## [PawnNeedsComponent] - they have charge and wear instead of sleep and hunger -
## and the tab set is derived from **which components the pawn carries**, so a
## robot gets this tab for the same reason a crew member gets Needs. No
## `is_robot` check anywhere: ask for the component.

var _robot: RobotPawnBase = null
var _energy: StatBar = null
var _integrity: StatBar = null
var _state: Label = null

func set_pawn(pawn: PawnBase) -> void:
	name = "Vitals"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	_robot = pawn as RobotPawnBase
	if _robot == null:
		return
	if _robot.power_component != null:
		_energy = StatBar.create()
		add_child(_energy)
		_robot.power_component.energy_changed.connect(_on_energy_changed)
	if _robot.integrity_component != null:
		_integrity = StatBar.create()
		add_child(_integrity)
		_robot.integrity_component.integrity_changed.connect(_on_integrity_changed)
	_state = Label.new()
	_state.theme_type_variation = UIType.META_LINE
	_state.add_theme_color_override("font_color", UIPalette.TEXT_SECONDARY)
	add_child(_state)
	_robot.job_changed.connect(_refresh)
	_refresh()

func _on_energy_changed(_value: float) -> void:
	_refresh()

func _on_integrity_changed(_value: float) -> void:
	_refresh()

func _refresh() -> void:
	if _robot == null or not is_instance_valid(_robot):
		return
	var power: RobotPowerComponent = _robot.power_component
	if _energy != null and power != null:
		var fraction: float = clampf(power.energy / power.energy_max, 0.0, 1.0) \
			if power.energy_max > 0.0 else 0.0
		_energy.configure("Energy", fraction, "%d%%" % int(round(fraction * 100.0)),
			UIPalette.ATTENTION if power.wants_recharge() else UIPalette.LIVE)
	var integrity: RobotIntegrityComponent = _robot.integrity_component
	if _integrity != null and integrity != null:
		var fraction: float = clampf(integrity.integrity / integrity.integrity_max, 0.0, 1.0) \
			if integrity.integrity_max > 0.0 else 0.0
		_integrity.configure("Integrity", fraction, "%d%%" % int(round(fraction * 100.0)),
			UIPalette.LIVE if fraction >= 1.0 else UIPalette.ATTENTION)
	if _state != null:
		_state.text = state_text(_robot).to_upper()

## The one-line "what is this drone doing" report. Static and pawn-argumented so
## the crew tab set can print the same words in the subject meta line without
## opening the tab.
static func state_text(robot: RobotPawnBase) -> String:
	if robot == null or not is_instance_valid(robot):
		return ""
	if robot.power_component != null and robot.power_component.must_recharge():
		return "Out of power — crawling"
	var job: Job = robot.current_job
	if job != null and job.is_type(&"recharge"):
		return "Recharging"
	if job != null and job.is_type(&"get_repaired"):
		return "Getting repaired"
	if robot.power_component != null and robot.power_component.wants_recharge():
		return "Seeking a charger"
	# A pawn with nothing to do still has a job - PawnBase hands it idle_wander -
	# so "no job" is `is_idle_type`, not null (the WI-50 readiness-dot trap).
	if job == null or job.is_idle_type():
		return "Idle"
	return "Working"
