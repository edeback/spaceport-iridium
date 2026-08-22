class_name CommsPanel
extends VBoxContainer

## The body of the COMMS mode panel (WI-57): the station's relationship with the
## outside world, at 620px. The ninth and last panel of the UI rework program.
##
## ## ARC is a fixture, not a message
##
## The top block is **permanent and amber**, and it sits above the tab strip
## rather than inside a tab: *"the parent corporation gets a permanent amber block
## above the feed because it is always available to hail - it is an action, not
## something that arrived."* Amber here is one of invariant 5's four sanctioned
## uses, and it is spent once, on the block, rather than smeared over the rows
## below it.
##
## The block carries `REQUEST INSPECTION`, which is this item's one gameplay
## change (WI-57 §2): promotion used to be a per-cycle coin flip inside
## [UnlockManager], and it is now a button. Each blocked state **names its own
## blocker on the button** rather than being greyed - the button is the only place
## in the panel a player can be told why they cannot be promoted yet, and a
## disabled control with no reason is the failure mode this replaces.
##
## While a raid is on it also carries the shrinking payoff. Hailing pirates for
## terms is the same category of action as hailing ARC, and Comms is the "talk to
## someone" panel.
##
## ## Three tabs, one of which is the feed
##
## | `INCOMING` | Transmissions - a durable log existing systems post to |
## | `STANDING` | How the station stands with the powers around it (WI-62 §5) |
## | `QUOTA` | WI-26's promotion block, moved out of Research (§5) |
## | `FINANCE` | `economy_screen`, reframed (§4) |
##
## QUOTA and FINANCE are here because they are ARC's business: the levy is ARC's
## skim, the loans are ARC's loans, the quota is ARC's demand, and the cost streams
## switch on the moment ARC promotes you (program decision 1). Neither gets a
## console slot of its own.
##
## ## What INCOMING is, and is not
##
## There is no message system in this game and this does not invent one. The feed
## renders [AlertManager]'s [TransmissionLog] - a bounded, saved list that
## [ContractManager], [TraderManager], [EconomyManager], [EventManager] and the
## ARC lifecycle post to through one helper. The split it keeps sharp: an alert is
## "look at this now", a transmission is "this arrived and you can read it later".
## A hull breach is never a transmission. A contract offer is both.

const TAB_INCOMING: StringName = &"incoming"
const TAB_STANDING: StringName = &"standing"
const TAB_QUOTA: StringName = &"quota"
const TAB_FINANCE: StringName = &"finance"

## The panel's standing instruction per tab, in the frame's footer strip (WI-54
## contract point 1) rather than as the last row of a list that scrolls.
const FOOTER_INCOMING: String = "Click a transmission to read it · ARC is always one hail away"
const FOOTER_STANDING: String = ("Standing moves when you answer a hail · it opens conversations, not prices yet")
const FOOTER_QUOTA: String = "Meet the quota, then request the inspection above"
const FOOTER_FINANCE: String = "ARC skims your income, lends against it, and audits the difference"

## What the ARC block says under its heading. The mockup's caption, verbatim.
const ARC_CAPTION: String = "Parent corporation · quota, loans, personnel"

## The `REQUEST INSPECTION` label per blocker. Each names what is in the way; none
## of them is a bare "unavailable".
const INSPECTION_LABELS: Dictionary[UnlockManager.InspectionBlock, String] = {
	UnlockManager.InspectionBlock.READY: "Request inspection",
	UnlockManager.InspectionBlock.MAX_TIER: "No further promotions",
	UnlockManager.InspectionBlock.IN_PROGRESS: "Inspector aboard",
	UnlockManager.InspectionBlock.NO_BAY: "No docking bay to receive them",
}

## The tooltip on the **first** inspection, which is the one that flips
## [EconomyManager]'s wage, upkeep and levy streams from off to on (WI-26).
##
## Not a modal. A player who does not know that walks into recurring costs they
## did not choose - but now that they choose the moment, saying so on the control
## is enough, and a confirmation dialog on the game's most-anticipated button
## would be worse than the problem.
const FIRST_INSPECTION_TOOLTIP: String = ("Your first promotion puts ARC's wages, upkeep"
	+ " and profit levy in force. Make sure the station can carry them.")
const LATER_INSPECTION_TOOLTIP: String = "Ask ARC to inspect the station for promotion"

var _frame: ConsolePanel
var _tabs: TabStrip
var _incoming_page: Control
var _standing_page: StandingTab
var _quota_page: QuotaTab
var _finance_page: FinanceTab

var _inspection_button: ActionButton
var _arc_status: Label
var _raid_row: HBoxContainer
var _raid_label: Label
var _raid_button: ActionButton

var _feed: VBoxContainer
var _empty: Label
var _mark_read_button: ActionButton
var _rows: Array[TransmissionRow] = []
## Entry id -> whether its row was expanded, so a rebuild does not fold the
## message the player is halfway through reading.
var _expanded_ids: Dictionary[StringName, bool] = {}

## Builds the frame and mounts this body in it. One call, like the widgets have -
## [UIMain] stays a mount table.
static func create() -> ConsolePanel:
	var frame: ConsolePanel = ConsolePanel.create()
	frame.title = "Comms"
	frame.panel_width = UIMetrics.PANEL_COMMS_WIDTH
	frame.content_padding = 0
	frame.hotkey = ModeManager.hotkey_label(ModeManager.Mode.COMMS)
	frame.footer_text = FOOTER_INCOMING
	frame.footer_variation = UIType.BODY
	var body := CommsPanel.new()
	body._frame = frame
	frame.content().add_child(body)
	return frame

func _ready() -> void:
	add_theme_constant_override("separation", 0)
	_build_arc_block()
	_build_tabs()
	_build_pages()
	_connect_sources()
	_tabs.set_tabs([
		{"id": TAB_INCOMING, "text": "Incoming"},
		{"id": TAB_STANDING, "text": "Standing"},
		{"id": TAB_QUOTA, "text": "Quota"},
		{"id": TAB_FINANCE, "text": "Finance"},
	])
	show_tab(_tabs.selected())

# --- the ARC block --------------------------------------------------------------

## Permanent, amber, and **above the tab strip** - it must not be something the
## player has to find a tab for, because it is the one thing in this panel that is
## always available regardless of what arrived.
func _build_arc_block() -> void:
	var block := PanelContainer.new()
	block.name = "ArcBlock"
	var box := StyleBoxFlat.new()
	box.bg_color = UIPalette.tinted(UIPalette.ATTENTION, UIPalette.ROW_AMBER_ALPHA)
	box.border_color = UIPalette.ATTENTION_BORDER
	box.set_border_width_all(0)
	box.border_width_bottom = UIMetrics.BORDER_WIDTH
	box.border_width_left = UIPalette.ROW_ACCENT_WIDTH
	box.set_corner_radius_all(0)
	box.set_content_margin_all(float(UIMetrics.CONTENT_PAD))
	block.add_theme_stylebox_override("panel", box)
	add_child(block)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	block.add_child(column)

	var heading: SectionLabel = SectionLabel.create("Contact ARC")
	heading.accent_color = UIPalette.ATTENTION
	column.add_child(heading)

	var caption := Label.new()
	caption.text = ARC_CAPTION.to_upper()
	caption.theme_type_variation = UIType.META_LINE
	caption.add_theme_color_override("font_color", UIPalette.ATTENTION_META)
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(caption)

	_inspection_button = ActionButton.create("Request inspection", ActionButton.Weight.PRIMARY)
	_inspection_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_inspection_button.pressed.connect(_on_inspection_pressed)
	column.add_child(_inspection_button)

	_arc_status = Label.new()
	_arc_status.theme_type_variation = UIType.BODY
	_arc_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_arc_status.add_theme_color_override("font_color", UIPalette.ATTENTION_META)
	column.add_child(_arc_status)

	column.add_child(_build_raid_row())

## The shrinking payoff, live while a raid is on (WI-57 §6).
##
## It does not replace WI-53's right-column [RaidReadout] - see the deviation in
## the WI. That readout is permanently on screen during a fight, and burying the
## only way to buy off a raid one keypress deep is the risk the WI itself flags a
## fallback for. This is the ARC-block half: hailing pirates for terms sits beside
## hailing ARC because it is the same category of action, and Comms is where the
## player looks for someone to talk to.
func _build_raid_row() -> HBoxContainer:
	_raid_row = HBoxContainer.new()
	_raid_row.name = "RaidRow"
	_raid_row.visible = false
	_raid_row.add_theme_constant_override("separation", UIMetrics.ROW_GAP)

	_raid_label = Label.new()
	_raid_label.theme_type_variation = UIType.META_LINE
	_raid_label.add_theme_color_override("font_color", UIPalette.ATTENTION_TEXT)
	_raid_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_raid_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_raid_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_raid_row.add_child(_raid_label)

	_raid_button = ActionButton.create("Hail", ActionButton.Weight.SECONDARY)
	_raid_button.pressed.connect(_on_hail_pressed)
	_raid_row.add_child(_raid_button)
	return _raid_row

# --- tabs & pages ----------------------------------------------------------------

func _build_tabs() -> void:
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", UIMetrics.CONTENT_PAD)
	pad.add_theme_constant_override("margin_right", UIMetrics.CONTENT_PAD)
	pad.add_theme_constant_override("margin_top", UIMetrics.CONTENT_PAD)
	add_child(pad)
	_tabs = TabStrip.create()
	_tabs.tab_selected.connect(show_tab)
	pad.add_child(_tabs)

func _build_pages() -> void:
	var pad := MarginContainer.new()
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "top", "right", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, UIMetrics.CONTENT_PAD)
	add_child(pad)

	_incoming_page = _build_incoming_page()
	pad.add_child(_incoming_page)
	_standing_page = StandingTab.new()
	pad.add_child(_standing_page)
	_quota_page = QuotaTab.new()
	pad.add_child(_quota_page)
	_finance_page = FinanceTab.new()
	pad.add_child(_finance_page)

func _build_incoming_page() -> Control:
	var column := VBoxContainer.new()
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", UIMetrics.ROW_GAP)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	column.add_child(head)

	var section: SectionLabel = SectionLabel.create("Incoming")
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(section)

	_mark_read_button = ActionButton.create("Mark all read", ActionButton.Weight.SECONDARY)
	_mark_read_button.tooltip_text = ("Clears the console badge. Nothing is deleted -"
		+ " the log keeps every transmission until it rolls over.")
	_mark_read_button.pressed.connect(_on_mark_all_read)
	head.add_child(_mark_read_button)

	_empty = Label.new()
	_empty.theme_type_variation = UIType.META_LINE
	_empty.text = "NOTHING HAS COME IN YET"
	_empty.add_theme_color_override("font_color", UIPalette.TEXT_META)
	column.add_child(_empty)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	_feed = VBoxContainer.new()
	_feed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_feed.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	scroll.add_child(_feed)
	return column

## Everything that can move something in this panel. All of them refresh only
## while it is on screen, which is what [method on_opened] is for.
func _connect_sources() -> void:
	SignalBus.transmissions_changed.connect(_on_transmissions_changed)
	SignalBus.station_tier_progress_changed.connect(_on_arc_state_changed)
	SignalBus.station_tier_changed.connect(_on_arc_state_changed.unbind(1))
	# Ship count, payoff price and warning phase all move without a start/end
	# cycle, and this is the one signal that covers all three (WI-32).
	SignalBus.raid_state_changed.connect(_on_arc_state_changed)
	SignalBus.raid_started.connect(_on_arc_state_changed.unbind(1))
	SignalBus.raid_ended.connect(_on_arc_state_changed.unbind(1))
	# The bay can appear or vanish without a tier signal, and it is one of the
	# button's six states.
	if Global.time_manager != null:
		Global.time_manager.slow_tick.connect(_on_slow_tick.unbind(1))

# --- mode hooks --------------------------------------------------------------------

func on_opened() -> void:
	refresh()

# --- views ---------------------------------------------------------------------------

## Shows a tab by id, exactly as clicking it does.
##
## Public for the reason [method CrewPanel.show_roster] is (WI-56 contract point
## 3): a probe or a screenshot driver that reaches past the strip swaps the page
## while leaving the strip painted on the old tab, and the panel then shows one
## thing under another thing's name. That was a real WI-55 defect.
func show_tab(id: StringName) -> void:
	if _incoming_page == null:
		return
	if _tabs != null and _tabs.selected() != id:
		_tabs.select(id) # emits tab_selected, which lands back here
		return
	_incoming_page.visible = id == TAB_INCOMING
	_standing_page.visible = id == TAB_STANDING
	_quota_page.visible = id == TAB_QUOTA
	_finance_page.visible = id == TAB_FINANCE
	if _frame != null and is_instance_valid(_frame):
		match id:
			TAB_STANDING:
				_frame.footer_text = FOOTER_STANDING
			TAB_QUOTA:
				_frame.footer_text = FOOTER_QUOTA
			TAB_FINANCE:
				_frame.footer_text = FOOTER_FINANCE
			_:
				_frame.footer_text = FOOTER_INCOMING
	refresh()

func open_tab() -> StringName:
	return _tabs.selected() if _tabs != null else &""

# --- refresh -------------------------------------------------------------------------

func _on_slow_tick() -> void:
	if is_visible_in_tree():
		_refresh_arc()

func _on_transmissions_changed() -> void:
	if is_visible_in_tree():
		_refresh_feed()
		_apply_header()

func _on_arc_state_changed() -> void:
	if is_visible_in_tree():
		_refresh_arc()

func refresh() -> void:
	_refresh_arc()
	_refresh_feed()
	_apply_header()
	if _standing_page != null and _standing_page.visible:
		_standing_page.refresh()
	if _quota_page != null and _quota_page.visible:
		_quota_page.refresh()
	if _finance_page != null and _finance_page.visible:
		_finance_page.refresh()

## `n UNREAD` in the frame's subtitle slot, matching the alert feed's header - the
## two lists teach each other.
func _apply_header() -> void:
	if _frame == null or not is_instance_valid(_frame):
		return
	var unread: int = _unread_count()
	var total: int = _log().size() if _log() != null else 0
	if unread > 0:
		_frame.subtitle = "%d unread · %d logged" % [unread, total]
	elif total > 0:
		_frame.subtitle = "%d logged · all read" % total
	else:
		_frame.subtitle = "Nothing logged"

# --- the ARC block ---------------------------------------------------------------------

func _refresh_arc() -> void:
	if _inspection_button == null:
		return
	var manager: UnlockManager = Global.unlock_manager
	if manager == null:
		_inspection_button.disabled = true
		return
	var block: UnlockManager.InspectionBlock = manager.inspection_block()
	_inspection_button.set_label(_inspection_label(manager, block))
	_inspection_button.disabled = block != UnlockManager.InspectionBlock.READY
	# The first promotion is the one that switches the cost streams on, so it is
	# the one that has to say so before the player commits.
	_inspection_button.tooltip_text = (FIRST_INSPECTION_TOOLTIP if manager.current_tier <= 1
		else LATER_INSPECTION_TOOLTIP)
	_arc_status.text = _arc_status_text(manager, block)
	_refresh_raid()

## The button's caption. Four of the six states are fixed strings; the two that
## carry a number build it here.
func _inspection_label(manager: UnlockManager, block: UnlockManager.InspectionBlock) -> String:
	match block:
		UnlockManager.InspectionBlock.COOLING_DOWN:
			var cycles: int = manager.inspection_cooldown_remaining()
			return "ARC will return in %d cycle%s" % [cycles, "" if cycles == 1 else "s"]
		UnlockManager.InspectionBlock.GOALS_UNMET:
			var goals: Vector2i = manager.export_goal_progress()
			return "%d of %d export goals met" % [goals.x, goals.y]
		UnlockManager.InspectionBlock.FACILITY_MISSING:
			return "Needs a %s facility" % manager.missing_inspection_tag()
		_:
			return INSPECTION_LABELS.get(block, "Request inspection")

## The line under the button. It says what a *press* would do, which the button's
## own caption cannot when the caption is busy naming a blocker.
func _arc_status_text(manager: UnlockManager, block: UnlockManager.InspectionBlock) -> String:
	match block:
		UnlockManager.InspectionBlock.READY:
			return ("Tier %d awaits. An inspector will dock and tour your facilities."
				% (manager.current_tier + 1))
		UnlockManager.InspectionBlock.MAX_TIER:
			return "This station has climbed as far as ARC's ladder goes."
		UnlockManager.InspectionBlock.IN_PROGRESS:
			return "Keep their route clear and the air breathable until they are done."
		_:
			return "See the QUOTA tab for what ARC still wants."

func _refresh_raid() -> void:
	var manager: RaidManager = Global.raid_manager
	var active: bool = manager != null and manager.active
	_raid_row.visible = active
	if not active:
		return
	var price: int = manager.current_payoff()
	_raid_label.text = "%d hostile ship(s) · payoff %d cr and falling" % [manager.ship_count(), price]
	_raid_button.set_label("Pay %d cr" % price)
	_raid_button.disabled = not manager.can_pay_off()

func _on_inspection_pressed() -> void:
	var manager: UnlockManager = Global.unlock_manager
	# Asked again at the press: the button is repainted on a slow tick, and the bay
	# it needs can be deconstructed between two of them.
	if manager == null or not manager.can_request_inspection():
		_refresh_arc()
		return
	manager.begin_inspection()
	_refresh_arc()

func _on_hail_pressed() -> void:
	if Global.raid_manager != null:
		Global.raid_manager.pay_off()
	_refresh_raid()

# --- the feed -----------------------------------------------------------------------

func _log() -> TransmissionLog:
	var manager: AlertManager = Global.alert_manager
	return manager.transmissions if manager != null else null

func _unread_count() -> int:
	var log: TransmissionLog = _log()
	return log.unread_count() if log != null else 0

## Brings the list into line with the log.
##
## **A read-state change repaints; only a changed entry set rebuilds.** That
## distinction is load-bearing rather than an optimisation: expanding a row marks
## its transmission read, which emits `transmissions_changed`, which lands back
## here - and an unconditional rebuild would free the row while its own `toggled`
## signal was still propagating out of it. That is the WI-53 pooling lesson
## ("a way to hand a freed row to a click that is already in flight") arriving by
## a different door, and here it is a crash rather than a nuisance.
##
## The expanded set is remembered across a real rebuild too, because a
## transmission the player is halfway through reading must not fold itself because
## a trader docked.
func _refresh_feed() -> void:
	if _feed == null:
		return
	var log: TransmissionLog = _log()
	var entries: Array[TransmissionData] = log.entries() if log != null else [] as Array[TransmissionData]
	if _matches_rendered(entries):
		for row: TransmissionRow in _rows:
			if is_instance_valid(row):
				row.refresh()
	else:
		_rebuild_feed(entries)
	_empty.visible = entries.is_empty()
	_mark_read_button.disabled = _unread_count() == 0

## Whether the rendered rows are already showing exactly these entries, in order.
func _matches_rendered(entries: Array[TransmissionData]) -> bool:
	if _rows.size() != entries.size():
		return false
	for index: int in _rows.size():
		var row: TransmissionRow = _rows[index]
		if not is_instance_valid(row) or row.entry != entries[index]:
			return false
	return true

func _rebuild_feed(entries: Array[TransmissionData]) -> void:
	for row: TransmissionRow in _rows:
		if is_instance_valid(row):
			_feed.remove_child(row)
			row.queue_free()
	_rows.clear()
	for entry: TransmissionData in entries:
		var row: TransmissionRow = TransmissionRow.create()
		_feed.add_child(row)
		row.bind(entry)
		row.toggled.connect(_on_row_toggled)
		row.route_followed.connect(_on_route_followed)
		row.jump_requested.connect(_on_jump_requested)
		_rows.append(row)
		# After the connections, so restoring an open row does not look different
		# from the player opening it.
		if _expanded_ids.get(entry.id, false):
			row.set_expanded(true)

func _on_row_toggled(row: TransmissionRow) -> void:
	if row.entry != null:
		_expanded_ids[row.entry.id] = row.is_expanded()
	_apply_header()
	_mark_read_button.disabled = _unread_count() == 0

func _on_mark_all_read() -> void:
	if Global.alert_manager != null:
		Global.alert_manager.mark_transmissions_read()

## Follows a transmission's route. Routed through [AlertFeed.ROUTES] rather than a
## second table: an alert and its transmission carry the same route id, and two
## tables would be two chances for one of them to point somewhere else.
func _on_route_followed(route: StringName) -> void:
	if not AlertFeed.ROUTES.has(route):
		return
	var modes: ModeManager = _modes()
	if modes != null:
		modes.open(AlertFeed.ROUTES[route])

## Jump-to, through the two accessors WI-51 exposed for it and with the same
## guard: [method InspectorPanel.select] toggles when handed the already-selected
## subject, which is right for a click on the station and wrong for a list row.
func _on_jump_requested(node: Node2D) -> void:
	var inspector: InspectorPanel = _inspector()
	var target: Node2D = node
	if inspector != null:
		if inspector.selected_subject() != node:
			inspector.select(node)
		var camera_target: Node2D = inspector.camera_target()
		if camera_target != null:
			target = camera_target
	var camera: GameCamera = get_viewport().get_camera_2d() as GameCamera
	if camera != null:
		camera.jump_to(target.global_position)

func _inspector() -> InspectorPanel:
	if Global.ui_main == null or not is_instance_valid(Global.ui_main):
		return null
	return Global.ui_main.inspector

func _modes() -> ModeManager:
	if Global.ui_main == null or not is_instance_valid(Global.ui_main):
		return null
	return Global.ui_main.mode_manager
