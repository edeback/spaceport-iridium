class_name HireTab
extends VBoxContainer

## The `HIRE` tab of the Crew panel: who the station *could* take on.
##
## Recruitment used to be a **component UI on the docking bay**, which meant the
## player had to find that one module and click it to learn hiring existed at
## all - the same discoverability failure the roster itself was built to fix.
## WI-56 papered over it with a footer button that opened the component's window
## inside an [AcceptDialog]; this tab replaces both. Crew is the panel about who
## is aboard, so who could be aboard is a **peer of the roster**, not a
## drill-down from it and not a window hanging off a module.
##
## **The docking-bay gate stays.** A hire arrives by shuttle and the shuttle
## needs somewhere to dock, so [method CrewManager.request_hire] still takes the
## bay it will arrive at and this tab still finds it through
## [constant Groups.CREW_RECRUITMENT]. What moved is the window, not the rule.
## With no bay the tab renders its blocker rather than vanishing: a player who
## cannot find hiring is exactly the player who needs to be told that a docking
## bay is the thing they are missing.
##
## The card list rebuilds only when the pool changes
## ([signal SignalBus.hire_candidates_changed]). Per-frame work is the status
## line and each card's blocked state, so a candidate the station cannot
## currently afford greys **with their price still on the card** rather than
## disappearing from a list the player was reading.

## The tab's standing instruction, in the frame's footer strip rather than as a
## row at the bottom of scrolling content.
const FOOTER: String = "Recruits arrive by shuttle · a docking bay is where they land"

## Width reserved for a card's price and its button, so a three-digit price and a
## four-digit one do not shunt the skills column sideways down the list. Same
## argument as [constant CrewRosterRow.MORALE_WIDTH].
const ACTION_WIDTH: int = 132

## Side of the identity swatch, matching [constant CrewRosterRow.SWATCH_SIZE] so
## a candidate card and a roster row line up in the same panel.
const SWATCH_SIZE: int = 24

## One card's live parts, so the per-frame pass can repaint a blocked card
## without rebuilding the list under the player's cursor - the same reason
## [CrewPanel] keeps a pawn -> row map.
class CardRefs extends RefCounted:
	var candidate: HireCandidate
	var button: ActionButton
	var reason: Label

var _status_label: Label
var _gate_label: Label
var _empty_label: Label
var _list: VBoxContainer
var _cards: Array[CardRefs] = []

## The station's crew gateway, re-resolved on a slow tick rather than per frame.
## A bay can appear or vanish with no signal of its own - the same problem
## [CommsPanel] solves the same way - but a *destroyed* one is caught
## immediately, because freeing the module frees this component with it.
var _bay: CrewRecruitmentComponent = null

func _ready() -> void:
	add_theme_constant_override("separation", UIMetrics.SECTION_GAP)
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	add_child(SectionLabel.create("Recruits"))

	# Only the pipeline. Crew and bunk counts are the frame's subtitle on both
	# tabs, and printing "2 CREW · 3 BUNKS" four pixels under "2 ABOARD · 3 BUNKS"
	# is the same fact twice in two vocabularies - which is the drift invariant 8
	# exists to prevent, wearing a layout defect's clothes.
	_status_label = Label.new()
	_status_label.theme_type_variation = UIType.META_LINE
	_status_label.add_theme_color_override("font_color", UIPalette.TEXT_META)
	_status_label.visible = false
	add_child(_status_label)

	# Amber, and one of invariant 5's legitimate spends: this is a station-wide
	# blocker on the one action the tab exists for, not decoration.
	_gate_label = Label.new()
	_gate_label.theme_type_variation = UIType.BODY
	_gate_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gate_label.add_theme_color_override("font_color", UIPalette.ATTENTION_TEXT)
	_gate_label.visible = false
	add_child(_gate_label)

	_empty_label = Label.new()
	_empty_label.theme_type_variation = UIType.META_LINE
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_label.add_theme_color_override("font_color", UIPalette.TEXT_META)
	_empty_label.text = "NO RECRUITS AVAILABLE — CHECK BACK AFTER A TRADER VISITS"
	add_child(_empty_label)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	scroll.add_child(_list)

	SignalBus.hire_candidates_changed.connect(_on_pool_changed)
	if Global.time_manager != null:
		Global.time_manager.slow_tick.connect(_on_slow_tick.unbind(1))
	refresh()

# --- refresh -------------------------------------------------------------------

func _on_pool_changed() -> void:
	if is_visible_in_tree():
		refresh()

func _on_slow_tick() -> void:
	if is_visible_in_tree():
		_bay = _find_bay()

## Everything, including a rebuild of the cards. Called when the tab is opened
## and whenever the pool moves.
func refresh() -> void:
	if _list == null:
		return
	_bay = _find_bay()
	_rebuild()
	_refresh_live()

## The cheap pass: the pipeline line, the gate, and each card's blocked state.
## Runs every frame the tab is on screen, because credits and free bunks both
## move from places that emit nothing this tab listens to.
func _refresh_live() -> void:
	var manager: CrewManager = Global.crew_manager
	if manager == null:
		return
	var arriving: int = manager.pending_hire_count()
	_status_label.text = "%d ARRIVING BY SHUTTLE" % arriving
	_status_label.visible = arriving > 0

	# The facts are gathered here; [HireBoard] decides which of them is the page's
	# sentence and which stays on a row. With no bay the manager is not consulted
	# at all - it has no objection to hiring into a station with nowhere to dock,
	# so its answers would all be "" and hoisting would find nothing.
	var has_bay: bool = _bay_ready()
	var reasons: Array[String] = []
	for card: CardRefs in _cards:
		reasons.append(manager.hire_block_reason(card.candidate) if has_bay else "")
	var gate: String = HireBoard.gate_reason(has_bay, reasons)
	_gate_label.text = gate.to_upper()
	_gate_label.visible = gate != ""

	for index: int in _cards.size():
		var card: CardRefs = _cards[index]
		if not is_instance_valid(card.button):
			continue
		card.button.disabled = not HireBoard.can_hire(reasons[index], gate)
		# The blocker rides on the card rather than inside the button's label.
		# WI-58 put the reason on the control precisely so it would be readable -
		# and on a 660px panel with a 132px action column, "NO FREE SLEEPING PODS"
		# in the label is the ellipsis WI-58 was fixing, not the fix.
		var own: String = HireBoard.card_reason(reasons[index], gate)
		card.reason.text = own.to_upper()
		card.reason.visible = own != ""

func _process(_delta: float) -> void:
	if is_visible_in_tree():
		_refresh_live()

# --- the list ------------------------------------------------------------------

func _rebuild() -> void:
	var manager: CrewManager = Global.crew_manager
	if manager == null:
		return
	for child: Node in _list.get_children():
		# Unparent before freeing: a rebuild can run twice in one frame (opened
		# then the pool moves), and queue_free alone leaves the stale cards on
		# screen for the rest of it - a visibly doubled list.
		_list.remove_child(child)
		child.queue_free()
	_cards.clear()
	var candidates: Array[HireCandidate] = manager.get_candidates()
	_empty_label.visible = candidates.is_empty()
	for candidate: HireCandidate in candidates:
		_list.add_child(_make_card(candidate))

func _make_card(candidate: HireCandidate) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIPalette.row_style(UIPalette.Row.INERT))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIMetrics.READOUT_HEADER_GAP)
	card.add_child(row)

	# The rolled tint, so the card and the roster row this hire becomes are
	# recognisably the same person.
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(float(SWATCH_SIZE), float(SWATCH_SIZE))
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.color = candidate.tint
	row.add_child(swatch)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", UIMetrics.LINE_GAP)
	row.add_child(info)

	var name_label := Label.new()
	name_label.theme_type_variation = UIType.ENTITY_NAME
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.text = candidate.pawn_name
	info.add_child(name_label)

	var skills_label := Label.new()
	skills_label.theme_type_variation = UIType.BODY
	skills_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	skills_label.text = candidate.skills_line()
	info.add_child(skills_label)

	# One hoverable label per trait, each carrying its .tres description (WI-59).
	# A candidate with no traits still shows no line at all, as it always has.
	var traits: Array[TraitData] = candidate.trait_data()
	if not traits.is_empty():
		info.add_child(TraitChips.build(traits, UIPalette.TEXT_SECONDARY, UIType.META_LINE))

	var reason := Label.new()
	reason.theme_type_variation = UIType.META_LINE
	reason.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	reason.add_theme_color_override("font_color", UIPalette.ATTENTION_META)
	reason.visible = false
	info.add_child(reason)

	row.add_child(_make_action(candidate, reason))
	return card

## The price block and the button, in a fixed-width column.
func _make_action(candidate: HireCandidate, reason: Label) -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = float(ACTION_WIDTH)
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override("separation", UIMetrics.LINE_GAP)

	var price := Label.new()
	price.theme_type_variation = UIType.METRIC
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price.text = "%d cr" % candidate.price
	column.add_child(price)

	# The wage, but only once wages are actually levied. A candidate's rolled
	# price IS their salary for the rest of the game, which is worth saying on
	# the card rather than discovering on a payday - but saying it while the
	# first ARC inspection has yet to switch the cost streams on would be a lie.
	var economy: EconomyManager = Global.economy_manager
	if economy != null and economy.wages_enabled:
		var wage := Label.new()
		wage.theme_type_variation = UIType.META_LINE
		wage.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		wage.add_theme_color_override("font_color", UIPalette.TEXT_META)
		wage.text = "%d CR / CYCLE" % EconomyManager.wage_for(
			candidate.price, economy.wage_fraction)
		column.add_child(wage)

	var button: ActionButton = ActionButton.create("Hire", ActionButton.Weight.PRIMARY)
	button.pressed.connect(_on_hire_pressed.bind(candidate))
	column.add_child(button)

	var refs := CardRefs.new()
	refs.candidate = candidate
	refs.button = button
	refs.reason = reason
	_cards.append(refs)
	return column

# --- hiring ---------------------------------------------------------------------

## Hires through the bay rather than around it. [method CrewManager.request_hire]
## emits `hire_candidates_changed` on success, which rebuilds the list and drops
## the hired card from it.
func _on_hire_pressed(candidate: HireCandidate) -> void:
	if not _bay_ready():
		return
	_bay.request_hire(candidate)

func _bay_ready() -> bool:
	return _bay != null and is_instance_valid(_bay)

## The station's crew gateway: the first constructed bay carrying the component,
## which is the same rule arriving shuttles and departing crew already follow.
func _find_bay() -> CrewRecruitmentComponent:
	for node: Node in get_tree().get_nodes_in_group(Groups.CREW_RECRUITMENT):
		var component := node as CrewRecruitmentComponent
		if component != null and component.owner_module != null \
				and component.owner_module.is_complete():
			return component
	return null
