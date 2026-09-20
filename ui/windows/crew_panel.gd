class_name CrewPanel
extends VBoxContainer

## The body of the CREW mode panel (WI-56): the station roster at 660px.
##
## One of the two panels in this program with **no predecessor**. Comparing two
## crew members' morale meant clicking each of them in turn, which is why an
## unhappy crew member goes unnoticed until they resign - the information existed
## per-entity and nowhere else.
##
## ## What a row says
##
## `swatch · name / status / location · morale`, and **status is the primary
## column**: *"'Working at Mining Bay', 'Moving to Refinery', 'Idle' - a full
## sentence, colour-coded. Idle is what the player is scanning for."* A sentence
## beats a state enum because the player is looking for the *absence* of purpose,
## and "Idle" reads as absence in a way that a blank cell does not. The sentence
## and its colour come from [PawnStatus], which the job board behind this panel
## and the inspector beside it also read - three surfaces inventing three
## sentences for one state is how "Idle" and "No job" end up meaning the same
## thing on two screens.
##
## ## Two tabs and a drill-down
##
## `ROSTER` and `HIRE` are **peers on a tab strip**: who is aboard, and who could
## be. Hiring lived on the docking bay as a component UI until it moved here - see
## [HireTab] for why - and a player who has to find one module to learn that
## recruitment exists is the same failure the roster was built to fix.
##
## `SHOW ALL JOBS` is **not** a third tab. It swaps [JobsScreen] in **in place**
## over the whole body, tab strip included, with a back control in the header. A
## drill-down rather than a peer: the roster is who, the board is what. Same mode,
## same width, same frame - so it is a swap, and putting it on the strip would
## have implied it was an alternative to the roster rather than a view through it.
##
## ## Who is in the list
##
## [method CrewManager.get_crew] - so **not** robots (no needs, no morale, no
## shift) and **not** visitors (guests are not staff). Both exclusions fall out of
## asking for the crew list rather than scanning [constant Groups.PAWN], which is
## also why neither needs an `is_robot` check. Robots hauling do appear in the job
## board view, and the subtitle saying `n ABOARD` rather than `n PAWNS` is the
## mitigation for someone reading that as a bug.
##
## Selection is [method InspectorPanel.select] plus a camera jump, and nothing
## else: *"clicking a name fills the same right-hand inspector as clicking the
## person on the station. One detail view, two ways in."* This panel does not own
## a detail view. Ever.

## The panel's standing instruction, in the frame's footer strip (WI-54 contract
## point 1) rather than as the last row of a list that scrolls.
const FOOTER_ROSTER: String = "Click a name to inspect and jump to them"
const FOOTER_BOARD: String = "The board holds unclaimed work · pick a crew member to see why they are blocked"

## The two peer views on the strip. The board is deliberately not among them.
const TAB_ROSTER: StringName = &"roster"
const TAB_HIRE: StringName = &"hire"

## Filter pill captions, in panel order.
const FILTER_LABELS: Dictionary[PawnStatus.Filter, String] = {
	PawnStatus.Filter.ALL: "All",
	PawnStatus.Filter.ON_SHIFT: "On shift",
	PawnStatus.Filter.IDLE: "Idle",
	PawnStatus.Filter.UNHAPPY: "Unhappy",
}

## Sort captions, in the OptionButton's order. STATUS first: it is the default,
## because it puts the actionable rows at the top.
const SORT_ORDER: Array[PawnStatus.Sort] = [
	PawnStatus.Sort.STATUS, PawnStatus.Sort.MORALE, PawnStatus.Sort.NAME,
]
const SORT_LABELS: Dictionary[PawnStatus.Sort, String] = {
	PawnStatus.Sort.STATUS: "Status",
	PawnStatus.Sort.MORALE: "Morale",
	PawnStatus.Sort.NAME: "Name",
}

var _frame: ConsolePanel
var _tabs: TabStrip
## The strip's padded host, hidden while the board drill-down is up - the board
## is a view *through* the roster tab, not a third entry on the strip.
var _tabs_host: MarginContainer
var _roster_view: VBoxContainer
## The `HIRE` page's padded host, shown and hidden as a peer of `_roster_view`.
var _hire_host: MarginContainer
var _hire_page: HireTab
var _board: JobsScreen
## The board's padded host. It is what gets shown and hidden, so the board itself
## never has to know it is one of two views.
var _board_host: MarginContainer
var _back_button: ActionButton
var _list: VBoxContainer
var _summary_label: Label
var _rota_button: ActionButton
var _filter_buttons: Dictionary[PawnStatus.Filter, Button] = {}
var _sort_picker: OptionButton

var _filter: PawnStatus.Filter = PawnStatus.Filter.ALL
var _sort: PawnStatus.Sort = PawnStatus.Sort.STATUS
## Pawn -> its row, so a selection change can repaint one row rather than rebuild
## the list under the player's cursor.
## Rows by pawn **instance id**, not by pawn (WI-71 §3). The pairing a node key
## would need is a hook that drops the key before the pawn is freed, and this
## has none: [method refresh] early-returns while the roster is off screen (the
## HIRE tab, or a closed panel), so a crew member who dies in that window leaves
## a dangling key behind - and a `Dictionary[PawnBase, ...]` errors on the freed
## key the moment anything iterates it.
var _rows: Dictionary[int, CrewRosterRow] = {}

## Builds the frame and mounts this body in it. One call, like the widgets have -
## [UIMain] stays a mount table.
static func create() -> ConsolePanel:
	var frame: ConsolePanel = ConsolePanel.create()
	frame.title = "Crew"
	frame.panel_width = UIMetrics.PANEL_CREW_WIDTH
	frame.content_padding = 0
	frame.hotkey = ModeManager.hotkey_label(ModeManager.Mode.CREW)
	frame.footer_text = FOOTER_ROSTER
	frame.footer_variation = UIType.BODY
	var body := CrewPanel.new()
	body._frame = frame
	frame.content().add_child(body)
	return frame

func _ready() -> void:
	add_theme_constant_override("separation", 0)
	_build_back_control()
	_build_tabs()
	_build_roster_view()
	_build_hire_view()
	_build_board_view()
	_connect_sources()
	_tabs.set_tabs([
		{"id": TAB_ROSTER, "text": "Roster"},
		{"id": TAB_HIRE, "text": "Hire"},
	])
	show_roster()

# --- construction ----------------------------------------------------------------

## The back control lives in the frame's one header slot, beside the hotkey hint,
## and is hidden while the roster is up. A drill-down needs exactly one way out
## that is not Esc - Esc closes the *mode*, which from the board would drop the
## player two levels at once.
func _build_back_control() -> void:
	_back_button = ActionButton.create("◀ Roster", ActionButton.Weight.SECONDARY)
	_back_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_back_button.visible = false
	_back_button.pressed.connect(show_roster)
	if _frame != null:
		_frame.add_header_control(_back_button)

## The peer strip, above both pages. Padded on three sides only: the strip's own
## underline is what separates it from the page, so a bottom margin would leave
## the rule floating.
func _build_tabs() -> void:
	_tabs_host = MarginContainer.new()
	_tabs_host.name = "TabsPad"
	for side: String in ["left", "top", "right"]:
		_tabs_host.add_theme_constant_override("margin_" + side, UIMetrics.CONTENT_PAD)
	add_child(_tabs_host)

	_tabs = TabStrip.create()
	_tabs.tab_selected.connect(show_tab)
	_tabs_host.add_child(_tabs)

func _build_roster_view() -> void:
	_roster_view = VBoxContainer.new()
	_roster_view.name = "Roster"
	_roster_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_roster_view.add_theme_constant_override("separation", 0)
	add_child(_roster_view)

	var pad := MarginContainer.new()
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "top", "right", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, UIMetrics.CONTENT_PAD)
	_roster_view.add_child(pad)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UIMetrics.SECTION_GAP)
	pad.add_child(column)

	column.add_child(_build_controls())

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	scroll.add_child(_list)

	_roster_view.add_child(_build_summary_bar())

## Filter pills, the sort picker, and `SHOW ALL JOBS`.
##
## The pills are [Button]s wearing the tab type variations rather than [Chip]s,
## which is what the design names them. A [Chip] is a [PanelContainer]: making one
## clickable means hand-rolling hover, press and focus, which is precisely what
## WI-49's widget library exists to prevent. The variations give the pill look
## with a real button underneath.
func _build_controls() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UIMetrics.ROW_GAP)

	var pills := HFlowContainer.new()
	pills.add_theme_constant_override("h_separation", UIMetrics.ROW_GAP)
	pills.add_theme_constant_override("v_separation", UIMetrics.ROW_GAP)
	column.add_child(pills)
	for filter: PawnStatus.Filter in FILTER_LABELS:
		var pill := Button.new()
		pill.text = FILTER_LABELS[filter].to_upper()
		pill.focus_mode = Control.FOCUS_NONE
		pill.pressed.connect(_on_filter_pressed.bind(filter))
		pills.add_child(pill)
		_filter_buttons[filter] = pill

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	column.add_child(tools)

	var sort_caption := Label.new()
	sort_caption.text = "SORT"
	sort_caption.theme_type_variation = UIType.READOUT_LABEL
	sort_caption.add_theme_color_override("font_color", UIPalette.TEXT_META)
	sort_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tools.add_child(sort_caption)

	_sort_picker = OptionButton.new()
	for sort: PawnStatus.Sort in SORT_ORDER:
		_sort_picker.add_item(SORT_LABELS[sort])
	_sort_picker.select(0)
	_sort_picker.item_selected.connect(_on_sort_selected)
	tools.add_child(_sort_picker)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tools.add_child(spacer)

	var board_button: ActionButton = ActionButton.create(
		"Show all jobs", ActionButton.Weight.SECONDARY)
	board_button.pressed.connect(show_board)
	tools.add_child(board_button)

	_paint_filters()
	return column

## The problem line and the two footer actions, welded to the foot of the content.
##
## Not [member ConsolePanel.footer_text]: that strip carries the panel's standing
## *instruction*, one line of meta text, and this is live state plus two buttons.
## They stack, which is how the instruction stays visible under a summary that
## changes every tick. Same split [TradePanel] uses for its NET bar.
func _build_summary_bar() -> PanelContainer:
	var bar := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = UIPalette.CONTROL_FILL
	box.border_color = UIPalette.DIVIDER
	box.set_border_width_all(0)
	box.border_width_top = UIMetrics.BORDER_WIDTH
	box.set_corner_radius_all(0)
	box.set_content_margin_all(float(UIMetrics.CONTENT_PAD))
	bar.add_theme_stylebox_override("panel", box)

	# The problem line above the action rather than beside it (WI-58). It shared
	# the row until the blocked HIRE button started carrying its reason as a label
	# - "NO FREE SLEEPING PODS" is three times the width of "HIRE", and it ellipsed
	# the summary to `2 BUNKS…` on the panel whose whole job is that count. HIRE
	# itself has since moved to its own tab; the stacking stays, because SHIFT ROTA
	# carries a reason of its own and the summary is still live state.
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	bar.add_child(column)

	_summary_label = Label.new()
	_summary_label.theme_type_variation = UIType.META_LINE
	_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_summary_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	column.add_child(row)

	_rota_button = ActionButton.create(ROTA_LABEL, ActionButton.Weight.SECONDARY)
	_rota_button.pressed.connect(_on_rota_pressed)
	row.add_child(_rota_button)
	return bar

func _build_hire_view() -> void:
	_hire_host = MarginContainer.new()
	_hire_host.name = "HirePad"
	_hire_host.visible = false
	_hire_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "top", "right", "bottom"]:
		_hire_host.add_theme_constant_override("margin_" + side, UIMetrics.CONTENT_PAD)
	add_child(_hire_host)

	_hire_page = HireTab.new()
	_hire_page.name = "Hire"
	_hire_host.add_child(_hire_page)

func _build_board_view() -> void:
	_board_host = MarginContainer.new()
	_board_host.name = "BoardPad"
	_board_host.visible = false
	_board_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "top", "right", "bottom"]:
		_board_host.add_theme_constant_override("margin_" + side, UIMetrics.CONTENT_PAD)
	add_child(_board_host)

	_board = JobsScreen.new()
	_board.name = "Board"
	_board_host.add_child(_board)
	_board.subtitle_changed.connect(_on_board_subtitle)

## Everything that can change a row. All of them refresh only while the panel is
## on screen, which is what [method on_opened] is for.
##
## The three departure signals are handled **deferred**: the pawn is still in the
## tree when they fire and is gone by the end of the frame, so rebuilding
## immediately would list somebody who has already left. `ui_main._setup_crew_ui`
## handled it this way for the same reason.
func _connect_sources() -> void:
	SignalBus.crew_hired.connect(_on_roster_changed.unbind(1))
	SignalBus.crew_departed.connect(_on_roster_changed.unbind(1))
	SignalBus.crew_resigned.connect(_on_roster_changed.unbind(1))
	SignalBus.crew_resigning.connect(_on_roster_changed.unbind(2))
	SignalBus.crew_resignation_cancelled.connect(_on_roster_changed.unbind(1))
	if Global.time_manager != null:
		Global.time_manager.slow_tick.connect(_on_slow_tick.unbind(1))

# --- mode hooks --------------------------------------------------------------------

func on_opened() -> void:
	refresh()

# --- views -------------------------------------------------------------------------

## The views are public because the swap **is** part of this panel's contract -
## the strip, `SHOW ALL JOBS` and the back control are three ways into one state
## machine, and a probe or a screenshot driver has to be able to reach every view
## through the same door the player uses. WI-55's tab-strip defect was exactly
## this shape: a view driven around its own entry point paints the wrong header.
##
## Routed through the strip rather than around it for the same reason
## [method CommsPanel.show_tab] is: a caller that set the page directly would
## leave the strip painted on the tab it was on, and the panel would then show one
## thing under another thing's name.
func show_tab(id: StringName) -> void:
	if _roster_view == null:
		return
	if _tabs != null and _tabs.selected() != id:
		_tabs.select(id) # emits tab_selected, which lands back here
		return
	_board_host.visible = false
	_back_button.visible = false
	_tabs_host.visible = true
	_roster_view.visible = id == TAB_ROSTER
	_hire_host.visible = id == TAB_HIRE
	if _frame != null and is_instance_valid(_frame):
		_frame.title = "Crew"
		_frame.footer_text = HireTab.FOOTER if id == TAB_HIRE else FOOTER_ROSTER
	refresh()

func show_roster() -> void:
	show_tab(TAB_ROSTER)

func show_hire() -> void:
	show_tab(TAB_HIRE)

## The drill-down. It covers the strip as well as the page, because it is not one
## of the strip's alternatives - leaving `ROSTER` lit over the job board would say
## it was.
func show_board() -> void:
	if _tabs != null:
		_tabs.select(TAB_ROSTER) # a no-op from the roster, which is the only way in
	_roster_view.visible = false
	_hire_host.visible = false
	_tabs_host.visible = false
	_board_host.visible = true
	_back_button.visible = true
	if _frame != null and is_instance_valid(_frame):
		_frame.title = "Jobs"
		_frame.footer_text = FOOTER_BOARD
	_board.refresh()

## True while the job board is the view on screen.
func board_visible() -> bool:
	return _board_host != null and _board_host.visible

## The tab currently lit, or `&""` before the strip is built. `&"roster"` while
## the board drill-down is up, because the board is a view through that tab.
func open_tab() -> StringName:
	return _tabs.selected() if _tabs != null else &""

## The roster rows currently listed, in display order.
func roster_rows() -> Array[CrewRosterRow]:
	var out: Array[CrewRosterRow] = []
	for child: Node in _list.get_children():
		var row := child as CrewRosterRow
		if row != null:
			out.append(row)
	return out

## The problem line as it currently reads.
func summary_line() -> String:
	return _summary_label.text if _summary_label != null else ""

func _on_board_subtitle(text: String) -> void:
	if _board_host.visible and _frame != null and is_instance_valid(_frame):
		_frame.subtitle = text

# --- refresh -----------------------------------------------------------------------

func _on_slow_tick() -> void:
	if not is_visible_in_tree() or _board_host.visible:
		return
	refresh()

func _on_roster_changed() -> void:
	# Deferred: the departing pawn is still in the tree right now.
	_refresh_deferred.call_deferred()

func _refresh_deferred() -> void:
	if is_visible_in_tree():
		refresh()

## Rebuilds the whole list.
##
## Rows are rebuilt rather than reconciled because the *order* changes with the
## data - a pawn going idle moves to the top under the default sort - so keeping
## row objects alive would only save the allocation while still re-parenting every
## one of them. The roster is a handful of entries; a station with sixty crew is
## not a station this game produces.
func refresh() -> void:
	if _list == null:
		return
	var manager: CrewManager = Global.crew_manager
	var crew: Array[PawnBase] = manager.get_crew() if manager != null else [] as Array[PawnBase]
	var bunks: int = manager.sleep_capacity() if manager != null else 0
	_apply_header(crew.size(), bunks)

	# The subtitle above serves both tabs - bunks are what gates a hire - but the
	# roster's own rebuild is skipped while it is off screen, or reading the Hire
	# tab would re-lay a hidden list of rows on every slow tick.
	if _hire_page != null and _hire_host.visible:
		_hire_page.refresh()
	if not _roster_view.visible:
		return

	var facts: Array[PawnStatus.Facts] = []
	var happiness: Array[float] = []
	for pawn: PawnBase in crew:
		facts.append(PawnStatus.facts_for(pawn))
		happiness.append(_happiness_of(pawn))
	_apply_summary(facts, happiness, bunks)

	var order: Array[int] = _ordered_indices(crew, facts, happiness)
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_rows.clear()
	var selected: Variant = _selected_subject()
	var shown: int = 0
	for index: int in order:
		if not PawnStatus.passes(facts[index], happiness[index], _filter):
			continue
		var pawn: PawnBase = crew[index]
		var row: CrewRosterRow = CrewRosterRow.create()
		_list.add_child(row)
		row.bind(pawn)
		row.set_morale(happiness[index])
		row.pressed.connect(_on_row_pressed.bind(pawn))
		if selected == pawn:
			row.set_selected(true)
		_rows[pawn.get_instance_id()] = row
		shown += 1
	if shown == 0:
		_list.add_child(_empty_line(crew.is_empty()))
	_refresh_actions()

## Indices into `crew`, sorted. Index-based rather than a sort over row objects
## so the three parallel arrays stay in step; the comparator itself is pure and
## tested ([method PawnStatus.compares_before]).
func _ordered_indices(crew: Array[PawnBase], facts: Array[PawnStatus.Facts],
		happiness: Array[float]) -> Array[int]:
	var order: Array[int] = []
	for i: int in crew.size():
		order.append(i)
	var sort: PawnStatus.Sort = _sort
	order.sort_custom(func(a: int, b: int) -> bool:
		return PawnStatus.compares_before(
			facts[a], happiness[a], _name_of(crew[a]),
			facts[b], happiness[b], _name_of(crew[b]), sort))
	return order

func _name_of(pawn: PawnBase) -> String:
	return pawn.pawn_name if not pawn.pawn_name.is_empty() else "Crew member"

func _happiness_of(pawn: PawnBase) -> float:
	var needs: PawnNeedsComponent = pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
	return needs.happiness if needs != null else -1.0

func _apply_header(crew_count: int, bunks: int) -> void:
	if _frame == null or not is_instance_valid(_frame) or _board_host.visible:
		return
	_frame.subtitle = "%d aboard · %d bunks" % [crew_count, bunks]

## *"A one-line summary - idle count, unhappy count, bunks short - so the panel
## answers 'is my crew fine?' without reading six rows."*
func _apply_summary(facts: Array[PawnStatus.Facts], happiness: Array[float],
		bunks: int) -> void:
	var summary: PawnStatus.Summary = PawnStatus.summarize(facts, happiness, bunks)
	_summary_label.text = PawnStatus.summary_text(summary)
	_summary_label.add_theme_color_override("font_color", PawnStatus.summary_color(summary))

## Zero crew is also the game-over condition, so this state is brief - but it must
## render its problem rather than an empty box.
func _empty_line(no_crew: bool) -> Label:
	var label := Label.new()
	label.theme_type_variation = UIType.META_LINE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", UIPalette.TEXT_META)
	label.text = ("NOBODY ABOARD — HIRE SOMEONE BEFORE THE STATION IS WRITTEN OFF" if no_crew
		else "NO CREW MATCH THIS FILTER")
	return label

## A disabled action is disabled with its reason **on the button** rather than
## hidden or merely tooltipped: making the player guess why a button is missing is
## the failure mode this replaces.
##
## WI-58 moved the sentence out of `tooltip_text` and into the label - `SHIFT
## ROTA` was disabled with no reason at all. `HIRE` stood beside it until hiring
## became a tab; [HireTab] keeps the same discipline, putting
## [method CrewManager.hire_block_reason] on each card it blocks.
const ROTA_LABEL: String = "Shift rota"
const NO_CREW_REASON: String = "No crew to schedule"

func _refresh_actions() -> void:
	var manager: CrewManager = Global.crew_manager
	if manager == null:
		_apply_action(_rota_button, ROTA_LABEL, NO_CREW_REASON)
		return
	_apply_action(_rota_button, ROTA_LABEL,
		NO_CREW_REASON if manager.crew_count() == 0 else "",
		"Every crew member's duty hours on one grid")

## A blocked action wears its blocker as its caption; an available one wears its
## verb. The tooltip keeps the sentence too, because the label ellipses on a
## 660px panel and the tooltip does not.
##
## The button is this panel's own child and outlives every call (WI-71 §2c).
func _apply_action(button: ActionButton, verb: String, reason: String,
		ready_tooltip: String = "") -> void:
	if button == null:
		return
	var blocked: bool = reason != ""
	button.disabled = blocked
	button.set_label(reason if blocked else verb)
	button.tooltip_text = reason if blocked else ready_tooltip

# --- interaction ---------------------------------------------------------------------

func _on_filter_pressed(filter: PawnStatus.Filter) -> void:
	_filter = filter
	_paint_filters()
	refresh()

func _paint_filters() -> void:
	for filter: PawnStatus.Filter in _filter_buttons:
		var pill: Button = _filter_buttons[filter]
		if is_instance_valid(pill):
			pill.theme_type_variation = UIType.TAB_ACTIVE if filter == _filter \
				else UIType.TAB_INACTIVE

func _on_sort_selected(index: int) -> void:
	if index < 0 or index >= SORT_ORDER.size():
		return
	_sort = SORT_ORDER[index]
	refresh()

## The one thing a row click does: fill the shared inspector and travel there.
##
## [method InspectorPanel.select] toggles when handed the already-selected
## subject, which is right for a click on the station and wrong here - a roster
## click that deselected would leave the row highlighted with nothing behind it.
## Same guard WI-53's jump-to uses.
func _on_row_pressed(pawn: PawnBase) -> void:
	var inspector: InspectorPanel = _inspector()
	if inspector == null:
		return
	if inspector.selected_subject() != pawn:
		inspector.select(pawn)
	var target: Node2D = inspector.camera_target()
	var camera: GameCamera = get_viewport().get_camera_2d() as GameCamera
	if camera != null and target != null:
		camera.jump_to(target.global_position)
	_paint_selection(pawn)

## Repaints the two rows that can have changed rather than rebuilding the list,
## so a click does not shuffle the row out from under the cursor.
func _paint_selection(selected: PawnBase) -> void:
	var selected_id: int = selected.get_instance_id() if selected != null else 0
	for pawn_id: int in _rows:
		var row: CrewRosterRow = _rows[pawn_id]
		if not is_instance_valid(row):
			continue
		row.refresh()
		if pawn_id == selected_id:
			row.set_selected(true)

func _selected_subject() -> Variant:
	var inspector: InspectorPanel = _inspector()
	return inspector.selected_subject() if inspector != null else null

func _inspector() -> InspectorPanel:
	if Global.ui_main == null or not is_instance_valid(Global.ui_main):
		return null
	return Global.ui_main.inspector

# --- footer actions --------------------------------------------------------------------

## `SHIFT ROTA` is a station-wide view of what the inspector's Schedule tab shows
## per pawn, and it is deliberately **read-only** in v1: a station-wide schedule
## *editor* is a feature, not a reframing, and per-pawn editing already exists one
## click away. Scoped this way by the WI itself.
func _on_rota_pressed() -> void:
	_open_dialog("Shift rota", _build_rota())

func _build_rota() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UIMetrics.ROW_GAP)

	var legend := Label.new()
	legend.theme_type_variation = UIType.META_LINE
	legend.add_theme_color_override("font_color", UIPalette.TEXT_META)
	legend.text = "CYAN ON DUTY · DIM OFF · EDIT A ROTA IN THE INSPECTOR'S SCHEDULE TAB"
	column.add_child(legend)
	column.add_child(_rota_hour_scale())

	var manager: CrewManager = Global.crew_manager
	var crew: Array[PawnBase] = manager.get_crew() if manager != null else [] as Array[PawnBase]
	if crew.is_empty():
		var empty := Label.new()
		empty.theme_type_variation = UIType.META_LINE
		empty.text = "NOBODY ABOARD"
		column.add_child(empty)
		return column
	for pawn: PawnBase in crew:
		column.add_child(_rota_row(pawn))
	return column

## The hour ruler over the grid. Every fourth hour is labelled - a number per
## cell would be unreadable at [constant ROTA_CELL] wide, and every sixth would
## not line up with the shift boundaries the game actually generates.
const ROTA_CELL := Vector2(14, 18)
const ROTA_NAME_WIDTH: int = 150
const ROTA_LABEL_EVERY: int = 4

func _rota_hour_scale() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIMetrics.LINE_GAP)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = float(ROTA_NAME_WIDTH)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	for hour: int in TimeManager.HOURS_PER_CYCLE:
		var label := Label.new()
		label.custom_minimum_size.x = ROTA_CELL.x
		label.theme_type_variation = UIType.META_LINE
		label.add_theme_color_override("font_color", UIPalette.TEXT_META)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.text = "%02d" % hour if hour % ROTA_LABEL_EVERY == 0 else ""
		row.add_child(label)
	return row

func _rota_row(pawn: PawnBase) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIMetrics.LINE_GAP)
	var name_label := Label.new()
	name_label.custom_minimum_size.x = float(ROTA_NAME_WIDTH)
	name_label.theme_type_variation = UIType.ENTITY_NAME
	name_label.text = _name_of(pawn)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)
	var current_hour: int = Global.time_manager.hour if Global.time_manager != null else -1
	for hour: int in TimeManager.HOURS_PER_CYCLE:
		var cell := ColorRect.new()
		cell.custom_minimum_size = ROTA_CELL
		cell.tooltip_text = "%02d:00" % hour
		# A pawn with no schedule (never happens for crew today, but a modded pawn
		# kind can ship one) is always on duty - the same answer is_on_shift gives.
		var working: bool = pawn.schedule == null or pawn.schedule.is_work_hour(hour)
		# Through the palette since WI-58, so this grid and the inspector's schedule
		# editor - the same fact, one keypress apart - cannot drift apart.
		cell.color = UIPalette.shift_cell(working, hour == current_hour)
		row.add_child(cell)
	return row

## Both footer actions open a dialog rather than a second panel, because
## invariant 1 says there is one panel and neither of these is a mode. Parented to
## the HUD rather than to this body so a panel close does not free a question the
## player is halfway through answering - the same rule [CrewTabSet]'s fire
## confirmation follows.
func _open_dialog(title: String, body: Control) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = title
	dialog.ok_button_text = "Close"
	dialog.min_size = Vector2i(UIMetrics.PANEL_CREW_WIDTH, 320)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(float(UIMetrics.PANEL_CREW_WIDTH), 320.0)
	scroll.add_child(body)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialog.add_child(scroll)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	Global.ui_main.add_child(dialog)
	dialog.popup_centered()
