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
		# `wants_repair()` for the same reason the line above uses
		# `wants_recharge()` (WI-58): it is the test the drone itself acts on, so
		# the bar goes amber exactly when the robot decides it needs a bay - not on
		# every point of wear.
		_integrity.configure("Integrity", fraction, "%d%%" % int(round(fraction * 100.0)),
			UIPalette.ATTENTION if integrity.wants_repair() else UIPalette.LIVE)
	if _state != null:
		_state.text = state_text(_robot).to_upper()

## The one-line "what is this drone doing" report. Static and pawn-argumented so
## the crew tab set can print the same words in the subject meta line without
## opening the tab.
##
## The six branches this used to hold moved into [PawnStatus] (WI-56), which is
## now the one place in the game that turns a pawn into a sentence - the crew
## roster is a column of exactly this text and a second opinion about what a
## drone is doing would be visible forty rows deep. Kept as a wrapper because
## "state text" is what the two callers here want and neither needs the tone.
##
## Both callers check their stored robot first - `_refresh()` here and
## `is_alive()` in the crew tab set - so it arrives live or null (WI-71 §2c).
static func state_text(robot: RobotPawnBase) -> String:
	if robot == null:
		return ""
	return PawnStatus.of(robot).text
