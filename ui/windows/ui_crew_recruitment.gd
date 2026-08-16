class_name UICrewRecruitment
extends ModuleComponentUI

## Recruitment window (WI-22): a list of hire candidates (name, standout skills,
## traits, price) each with a Hire button. The card list rebuilds only when the
## pool changes (hire_candidates_changed); per-frame polling just updates the
## status line and each button's affordability, so a candidate you can't afford
## shows greyed with its price rather than vanishing.

@export var status_label: Label
@export var candidate_list: VBoxContainer

var recruitment_component: CrewRecruitmentComponent
## Hire Button -> the HireCandidate it buys, for per-frame enablement.
var _hire_buttons: Dictionary[Button, HireCandidate] = {}

func set_recruitment_component(component: CrewRecruitmentComponent) -> void:
	name = component.name
	recruitment_component = component
	_rebuild()
	SignalBus.hire_candidates_changed.connect(_rebuild)

func _process(_delta: float) -> void:
	var manager: CrewManager = Global.crew_manager
	if manager == null:
		return
	_update_status(manager)
	# Beds/credits change from many places; refresh each button's enablement
	# without rebuilding the cards (which would drop button connections).
	for button: Button in _hire_buttons:
		button.disabled = manager.hire_block_reason(_hire_buttons[button]) != ""

func _update_status(manager: CrewManager) -> void:
	var status: String = "Crew %d / %d beds" % [manager.crew_count(), manager.sleep_capacity()]
	if manager.pending_hire_count() > 0:
		status += ", %d arriving" % manager.pending_hire_count()
	status_label.text = status

func _rebuild() -> void:
	var manager: CrewManager = Global.crew_manager
	if manager == null:
		return
	for child: Node in candidate_list.get_children():
		child.queue_free()
	_hire_buttons.clear()
	var candidates: Array[HireCandidate] = manager.get_candidates()
	if candidates.is_empty():
		var empty := Label.new()
		empty.theme_type_variation = UIType.META_LINE
		empty.add_theme_color_override("font_color", UIPalette.TEXT_SECONDARY)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.text = "No recruits available — check back after a trader visits."
		candidate_list.add_child(empty)
		return
	for candidate: HireCandidate in candidates:
		candidate_list.add_child(_make_card(candidate))

func _make_card(candidate: HireCandidate) -> Control:
	var card := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	card.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override(&"separation", 0)
	var name_label := Label.new()
	name_label.text = candidate.pawn_name
	info.add_child(name_label)
	var skills_label := Label.new()
	skills_label.theme_type_variation = UIType.META_LINE
	skills_label.text = candidate.skills_line()
	info.add_child(skills_label)
	# One hoverable label per trait, each carrying its .tres description (WI-59).
	# A candidate with no traits still shows no line at all, as it always has.
	var traits: Array[TraitData] = candidate.trait_data()
	if not traits.is_empty():
		info.add_child(TraitChips.build(traits, UIPalette.TEXT_SECONDARY, UIType.META_LINE))
	row.add_child(info)
	var button := Button.new()
	button.text = "Hire\n%d cr" % candidate.price
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(_on_hire_pressed.bind(candidate))
	row.add_child(button)
	_hire_buttons[button] = candidate
	return card

func _on_hire_pressed(candidate: HireCandidate) -> void:
	# request_hire emits hire_candidates_changed on success, which triggers
	# _rebuild and drops the hired card from the list.
	recruitment_component.request_hire(candidate)
