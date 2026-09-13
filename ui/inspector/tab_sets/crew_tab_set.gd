class_name CrewTabSet
extends InspectorTabSet

## The CREW tab set (WI-51): what `pawns/pawn_info_panel.tscn` used to be, minus
## the frame and minus the per-frame reposition.
##
## The deleted `_process` is the point of the whole item. That panel set its
## position from the pawn's screen transform every single frame, so it overlapped
## the station, overlapped other panels, and **moved while you were reading it**.
## What survives from it is the liveness check, which is now the panel's uniform
## `is_alive()` poll across all five kinds.
##
## The tab set is derived from **which components the pawn carries**, which is
## already how the game distinguishes its three pawn specialisations. There is no
## `is_robot` test here: a robot has no [PawnNeedsComponent] so it gets Vitals
## instead of Needs, and no schedule/skills/traits so those tabs are simply never
## added. A modded pawn kind (WI-47) that carries a needs component gets a Needs
## tab without anyone editing this file.
##
## The three readout blocks the old panel injected under its name row go where
## the design puts them: the wage and FIRE into the Job tab's footer row, side by
## side (WI-25; the inverted inspector moved them off the subject block), the
## robot bars into the Vitals tab (WI-28), and the visitor's wallet and remaining
## stay into the meta line (WI-33).

const JOB_TAB_SCENE: PackedScene = preload("res://ui/pawns/pawn_job_tab.tscn")
const SKILLS_TAB_SCENE: PackedScene = preload("res://ui/pawns/pawn_skills_tab.tscn")
const INVENTORY_TAB_SCENE: PackedScene = preload("res://ui/pawns/pawn_inventory_tab.tscn")
const SCHEDULE_TAB_SCENE: PackedScene = preload("res://ui/pawns/pawn_schedule_tab.tscn")
const SOCIAL_TAB_SCENE: PackedScene = preload("res://ui/pawns/pawn_social_tab.tscn")

var _pawn: PawnBase = null
var _needs: PawnNeedsComponent = null
var _tabs: Array[Dictionary] = []

func bind(subject: Variant) -> void:
	_pawn = subject as PawnBase
	if _pawn == null:
		return
	_needs = _pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
	_tabs = InspectorTabPlan.crew_tabs({
		"needs": _needs != null,
		"vitals": _pawn is RobotPawnBase,
		"skills": _pawn.get_component_by_type(PawnSkillsComponent) != null,
		"inventory": _pawn.inventory_component != null,
		"schedule": _pawn.schedule != null,
		"social": _pawn.get_component_by_type(SocializeComponent) != null,
	})
	# The shift indicator flips on the hour, never per frame.
	Global.time_manager.hour_changed.connect(_on_hour_changed)
	if _pawn.schedule != null:
		_pawn.schedule.this_shift_changed.connect(_on_changed)
	_pawn.job_changed.connect(_on_changed)
	if _needs != null:
		_needs.happiness_changed.connect(_on_value_changed)
	SignalBus.crew_resigning.connect(_on_resignation_changed)
	SignalBus.crew_resignation_cancelled.connect(_on_pawn_event)
	# A visitor's wallet and remaining stay both move on the sim clock rather than
	# on any signal, so the meta line refreshes on the slow tick. The old panel
	# did it in `_process`, which is sixty times more often than the numbers move.
	if _pawn is VisitorPawn:
		Global.time_manager.slow_tick.connect(_on_slow_tick)
	_show_debug_path()

func _exit_tree() -> void:
	# The debug path overlay belongs to the selection, so it goes when the
	# selection does.
	if Global.ui_in_game != null and is_instance_valid(Global.ui_in_game):
		Global.ui_in_game.debug_path_position = PackedVector2Array()

func is_alive() -> bool:
	return _pawn != null and is_instance_valid(_pawn)

func camera_target() -> Node2D:
	return _pawn

# --- subject block -------------------------------------------------------------

func subject_name() -> String:
	if not is_alive():
		return "Crew member"
	if not _pawn.pawn_name.is_empty():
		return _pawn.pawn_name
	return "Visitor" if _pawn.is_visitor else "Crew member"

## What the crew member is doing and how they feel about it - the design's
## `HAULING → SMELTER · HAPPINESS 87%`, the two things you click a colonist to
## find out. The sentence is [PawnStatus]'s, the one place a pawn becomes one.
##
## Guests and drones keep their own readouts. Guests read as outsiders and carry
## no shift indicator; drones carry no shift because they have no schedule, which
## is a different reason for the same absence and one the component check gets
## right for free.
func meta_text() -> String:
	if not is_alive():
		return ""
	var parts: Array[String] = []
	var visitor := _pawn as VisitorPawn
	if visitor != null:
		parts.append("Guest")
		parts.append("Wallet %d cr" % visitor.personal_credits)
		parts.append("%d h left" % int(round(maxf(visitor.stay_hours_remaining, 0.0))))
		return " · ".join(parts)
	var robot := _pawn as RobotPawnBase
	if robot != null:
		parts.append("Drone")
		parts.append(RobotVitalsTab.state_text(robot))
		return " · ".join(parts)
	var activity: String = PawnStatus.of(_pawn).text
	parts.append(activity)
	# Off shift is worth saying only when the sentence has not already said it:
	# an idle pawn off shift already reads "Off duty", and one asleep in a bunk
	# is off shift by the plain meaning of the words.
	if _pawn.schedule != null and not _pawn.is_on_shift() and activity != PawnStatus.TEXT_OFF_DUTY:
		parts.append("Off shift")
	if _needs != null:
		parts.append("Happiness %d%%" % roundi(_needs.happiness * 100.0))
	return " · ".join(parts)

## The one thing about a crew member that is worth spending amber on: they are
## about to walk out.
func status_text() -> String:
	if not is_alive() or _needs == null:
		return ""
	if _needs.resigned:
		return "Has resigned — packing up."
	if _needs.resignation_pending:
		return "Fed up — will leave unless things improve."
	return ""

func icon_color() -> Color:
	if not is_alive():
		return Color(0.0, 0.0, 0.0, 0.0)
	# The pawn's own tint (WI-22 gives every pawn one), so the block reads as the
	# crew member you clicked rather than as a generic slot.
	if _pawn.animated_sprite != null:
		return _pawn.animated_sprite.modulate
	return UIPalette.tinted(UIPalette.LIVE, 0.6)

## The Job tab's footer: the wage beside FIRE (2026-09-13). The number you would
## check before firing someone sits next to the button that does it, and neither
## is on the identity strip - the design keeps anything destructive off it.
##
## The wage is [method EconomyManager.wage_for_pawn], the figure actually charged
## (scaled by difficulty); the meta line used to print the unscaled one. Firing
## costs severance and cannot be undone, so it is confirmed and drawn
## outline-only. Drones draw no wage and cannot be fired; guests are not employed.
func page_footer(id: StringName) -> Control:
	if id != InspectorTabPlan.TAB_JOB or not _is_employed():
		return null
	var economy: EconomyManager = Global.economy_manager
	var row := HBoxContainer.new()
	row.name = "WageRow"
	row.add_theme_constant_override("separation", UIMetrics.INSPECTOR_STRIP_GAP)

	var wage := VBoxContainer.new()
	wage.name = "Wage"
	wage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wage.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wage.add_theme_constant_override("separation", 2)
	row.add_child(wage)
	var amount := Label.new()
	amount.name = "Amount"
	amount.theme_type_variation = UIType.METRIC_LARGE
	amount.text = "%d cr/cycle" % economy.wage_for_pawn(_pawn)
	wage.add_child(amount)
	var caption := Label.new()
	caption.name = "Caption"
	caption.theme_type_variation = UIType.META_LINE
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Wages switch on with ARC's first promotion (WI-26). A figure with no word
	# about that reads as money already leaving.
	caption.text = ("Wage · paid each cycle" if economy.wages_enabled
		else "Wage · starts once ARC promotes the station").to_upper()
	wage.add_child(caption)

	var fire: ActionButton = ActionButton.create("Fire", ActionButton.Weight.DESTRUCTIVE)
	fire.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fire.pressed.connect(_on_fire_pressed)
	row.add_child(fire)
	return row

func _is_employed() -> bool:
	return is_alive() and not _pawn is RobotPawnBase and not _pawn.is_visitor \
		and _needs != null and Global.economy_manager != null

func _on_fire_pressed() -> void:
	if not is_alive():
		return
	var severance: int = Global.economy_manager.severance_for(_pawn)
	var display: String = subject_name()
	var dialog := ConfirmationDialog.new()
	dialog.title = "Fire crew member"
	dialog.dialog_text = ("Fire %s? Severance costs %d cr." % [display, severance]) if severance > 0 \
		else "Fire %s? They will pack up and leave the station." % display
	dialog.ok_button_text = "Fire"
	var target: PawnBase = _pawn
	dialog.confirmed.connect(func() -> void:
		if is_instance_valid(target):
			Global.economy_manager.fire_pawn(target))
	dialog.canceled.connect(dialog.queue_free)
	# Parented to the HUD rather than to this set: the set is freed the moment the
	# selection changes, and a dialog freed out from under the player mid-question
	# is worse than one that outlives its panel.
	Global.ui_main.add_child(dialog)
	dialog.popup_centered()

# --- tabs ----------------------------------------------------------------------

func tabs() -> Array[Dictionary]:
	return _tabs

func make_page(id: StringName) -> Control:
	if not is_alive():
		return null
	var page: Control = _instantiate(id)
	if page == null:
		return null
	# Every pawn tab takes its subject the same way, and always **before** the
	# page enters the tree - which is what the old panel did too, and why any tab
	# that scrolls has to size itself synchronously (WI-48 deviation 8).
	page.call(&"set_pawn", _pawn)
	return page

func _instantiate(id: StringName) -> Control:
	match id:
		InspectorTabPlan.TAB_NEEDS:
			return PawnNeedsTab.new()
		InspectorTabPlan.TAB_VITALS:
			return RobotVitalsTab.new()
		InspectorTabPlan.TAB_JOB:
			return JOB_TAB_SCENE.instantiate() as Control
		InspectorTabPlan.TAB_SKILLS:
			return SKILLS_TAB_SCENE.instantiate() as Control
		InspectorTabPlan.TAB_KIT:
			return INVENTORY_TAB_SCENE.instantiate() as Control
		InspectorTabPlan.TAB_SCHEDULE:
			return SCHEDULE_TAB_SCENE.instantiate() as Control
		InspectorTabPlan.TAB_SOCIAL:
			return SOCIAL_TAB_SCENE.instantiate() as Control
	return null

# --- signals -------------------------------------------------------------------

func _on_changed() -> void:
	subject_changed.emit()

func _on_value_changed(_value: float) -> void:
	subject_changed.emit()

func _on_hour_changed(_hour: int) -> void:
	subject_changed.emit()

func _on_slow_tick(_interval: float) -> void:
	subject_changed.emit()

func _on_pawn_event(pawn: PawnBase) -> void:
	if pawn == _pawn:
		subject_changed.emit()

func _on_resignation_changed(pawn: PawnBase, _grace_hours: float) -> void:
	_on_pawn_event(pawn)

## The movement debug overlay follows the selected pawn, as it did from the old
## panel. It draws on [UIInGame], which shares world coordinates.
func _show_debug_path() -> void:
	if _pawn.movement_component == null or Global.ui_in_game == null:
		return
	Global.ui_in_game.debug_path_position = _pawn.movement_component.get_debug_path_detailed()
	_pawn.movement_component.movement_started.connect(_on_movement_started)

func _on_movement_started() -> void:
	if is_alive() and _pawn.movement_component != null and Global.ui_in_game != null:
		Global.ui_in_game.debug_path_position = _pawn.movement_component.get_debug_path_detailed()
