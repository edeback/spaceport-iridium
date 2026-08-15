class_name AlertFeed
extends ReadoutPanel

## The alert feed (WI-53): the second readout in the permanent right column,
## under the station map.
##
## It replaces `ui_main.gd`'s top-centre `VBoxContainer` of red [Label]s, which
## was every alert in the same colour, the same size, in the same place, for the
## same fifteen seconds, and then gone forever. Here a row's treatment says how
## much it matters, a sticky row will not leave until it is read, and the ones
## worth keeping go to the history log.
##
## Ordering, coalescing and the cap are [AlertRules]; this panel renders what it
## is handed. It rebuilds wholesale on [signal SignalBus.alerts_changed] rather
## than diffing, because a feed is at most six rows and the alternative is a
## reconciliation pass whose bugs would be invisible until something important
## failed to appear.

const SCENE_PATH: String = "res://ui/alerts/alert_feed.tscn"

const EMPTY_TEXT: String = "No active alerts"

## Route id -> console mode, for an alert about something with no position. The
## table lives here rather than on [AlertData] so the record stays free of any
## dependency on `ui/` (an alert is raised by managers and components, which must
## not have to know the console exists).
const ROUTES: Dictionary[StringName, ModeManager.Mode] = {
	&"build": ModeManager.Mode.BUILD,
	&"crew": ModeManager.Mode.CREW,
	&"stores": ModeManager.Mode.STORES,
	&"trade": ModeManager.Mode.TRADE,
	&"research": ModeManager.Mode.RND,
	&"comms": ModeManager.Mode.COMMS,
}

## Emitted when the header's HISTORY action is pressed. [UIMain] owns the flyout,
## for the same reason it owns the resource ledger: a flyout has to sit beside
## the column rather than inside a panel that is 344px wide.
signal history_requested

var _column: VBoxContainer
var _scroll: ScrollContainer
var _rows_box: VBoxContainer
var _empty: Label
var _overflow: ListRow
var _clear_button: ActionButton

var _rows: Array[AlertRow] = []
var _refitting: bool = false

## Rows the feed will actually render, which is [constant AlertRules.FEED_CAP]
## capped by what its current budget has room for (WI-58).
##
## The design's cap and the geometric one are different questions and the smaller
## has to win. WI-53 sized the feed so FEED_CAP rows fit without an inner
## scrollbar and wrote down that the two limits must agree; once the raid readout
## takes 96px out of the column that stops being true, and left alone the feed
## rendered four rows into two-and-a-half rows' worth of space - the last one
## sliced across the bottom edge, with a `+ 3 more` line underneath it that no
## longer described what was on screen. That is the exact failure FEED_CAP's own
## comment warns about, and only a screenshot showed it.
var _row_cap: int = AlertRules.FEED_CAP

## Tallest this feed may become, pushed in by [UIMain] as the column re-stacks
## (WI-58). The feed is the readout that yields: the raid readout appearing above
## it shrinks this, and the rows scroll rather than the inspector below losing its
## content region. Defaults to the no-raid budget so a feed mounted on its own -
## a probe, a test scene - still renders sanely.
var height_budget: int = UIMetrics.alert_feed_max_height(false):
	set(value):
		var clamped: int = maxi(value, 0)
		if height_budget == clamped:
			return
		height_budget = clamped
		_refit()

static func create() -> AlertFeed:
	return load(SCENE_PATH).instantiate() as AlertFeed

func _ready() -> void:
	super()
	_build_body()
	SignalBus.alerts_changed.connect(refresh)
	refresh()

# --- construction ---------------------------------------------------------------

func _build_body() -> void:
	panel_width = UIMetrics.RIGHT_COLUMN_WIDTH
	content_padding = UIMetrics.READOUT_CONTENT_PAD
	label = "Alerts"
	# The one place a readout is allowed to spend colour, and alerts are what the
	# amber budget exists for (invariant 5) - but only while there *are* any. Set
	# once at build, the accent bar was amber over an empty feed on a station where
	# nothing had ever gone wrong (WI-58). [method _apply_accent_for] swaps it by
	# state, the way `InspectorPanel` swaps TEXT_META for LIVE when it holds a
	# selection.
	_apply_accent_for([] as Array[AlertData])

	# The count goes in the readout's own label rather than the action slot. A
	# 34px header on a 344px readout has room for the label and two short
	# buttons and no more, and `ReadoutPanel`'s header row is anchored to grow
	# both ways - so anything that does not fit does not clip, it spills out of
	# both edges of the panel.
	var history_button: ActionButton = ActionButton.create("Log", ActionButton.Weight.SECONDARY)
	history_button.tooltip_text = "Every high and critical alert this station has seen"
	history_button.pressed.connect(history_requested.emit)
	add_action(history_button)

	_clear_button = ActionButton.create("Clear", ActionButton.Weight.SECONDARY)
	_clear_button.tooltip_text = ("Dismiss every alert that can be dismissed."
		+ " Outstanding critical alerts stay, and the log keeps everything.")
	_clear_button.pressed.connect(_on_clear_pressed)
	add_action(_clear_button)

	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	content().add_child(_column)

	_empty = Label.new()
	_empty.name = "Empty"
	_empty.theme_type_variation = UIType.META_LINE
	_empty.text = EMPTY_TEXT.to_upper()
	_empty.add_theme_color_override("font_color", UIPalette.TEXT_META)
	_column.add_child(_empty)

	# A ScrollContainer reports a minimum height of zero (WI-48's deviation 8), so
	# the fit below drives its height from the row block's own combined minimum.
	_scroll = ScrollContainer.new()
	_scroll.name = "Rows"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_child(_scroll)

	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	_scroll.add_child(_rows_box)

	_overflow = ListRow.create()
	_overflow.name = "Overflow"
	_overflow.pressed.connect(history_requested.emit)
	_column.add_child(_overflow)

	# Re-fit whenever anything below changes size rather than measuring once: a
	# row's height settles after the fonts do, and a title that wraps onto a
	# second line asks for more than it did when it was built (the WI-51 rule).
	_rows_box.minimum_size_changed.connect(_queue_refit)

# --- rendering ------------------------------------------------------------------

func refresh() -> void:
	if _rows_box == null:
		return
	var manager: AlertManager = Global.alert_manager
	var alerts: Array[AlertData] = manager.live() if manager != null else [] as Array[AlertData]
	var rows: Array[AlertRules.Group] = AlertRules.group(alerts)
	var shown: Array[AlertRules.Group] = AlertRules.visible(rows, _row_cap)
	var hidden: int = AlertRules.overflow(rows, _row_cap)

	_sync_row_count(shown.size())
	for index: int in shown.size():
		_rows[index].bind(shown[index])

	_empty.visible = alerts.is_empty()
	_scroll.visible = not shown.is_empty()
	_overflow.visible = hidden > 0
	if hidden > 0:
		_overflow.configure("+ %d more" % hidden, "in the alert log", "Log ▸",
			UIPalette.Row.INERT)
	label = _header_text(alerts)
	_apply_accent_for(alerts)
	_clear_button.disabled = AlertRules.survives_clear(alerts).size() == alerts.size()
	_refit()

## The accent bar by state (WI-58): dim when the feed is empty, cyan when it holds
## only transient rows the player can let expire, amber when something sticky is
## waiting. Amber is a budget, and "this readout is about alerts" is not one of
## its four sanctioned spends - an alert that will not leave until it is read is.
##
## The predicate is [method AlertRules.is_sticky], which is the same one
## [method AlertRow.treatment_of] paints the rows with, so the bar and the rows
## under it can never disagree about whether the feed is alarming.
func _apply_accent_for(alerts: Array[AlertData]) -> void:
	if alerts.is_empty():
		accent_color = UIPalette.TEXT_META
		return
	for alert: AlertData in alerts:
		if AlertRules.is_sticky(alert.priority):
			accent_color = UIPalette.ATTENTION
			return
	accent_color = UIPalette.LIVE

## "ALERTS · 3" normally. An outstanding critical replaces the count outright,
## because it is the number that explains why the game has stopped and it should
## not have to compete with a total for the header's attention.
func _header_text(alerts: Array[AlertData]) -> String:
	var outstanding: int = AlertRules.outstanding_count(alerts)
	if outstanding > 0:
		return "Alerts · %d critical" % outstanding
	if alerts.is_empty():
		return "Alerts"
	return "Alerts · %d" % alerts.size()

## Grows or shrinks the row pool to `wanted`. Rows are reused rather than rebuilt
## because the feed re-renders on every alert change, and a pool of six buttons
## churning through `queue_free` on each one is both wasteful and a way to hand a
## freed row to a click that is already in flight.
func _sync_row_count(wanted: int) -> void:
	while _rows.size() < wanted:
		var row: AlertRow = AlertRow.create()
		row.pressed.connect(_on_row_pressed.bind(row))
		_rows_box.add_child(row)
		_rows.append(row)
	for index: int in _rows.size():
		_rows[index].visible = index < wanted

# --- interaction ----------------------------------------------------------------

## One press does both halves: acknowledge, then follow.
##
## Acknowledgement runs **first** so the pause is released before the camera
## moves - jumping to a module while the sim is still frozen would make the
## release look like it had not happened.
func _on_row_pressed(row: AlertRow) -> void:
	var group: AlertRules.Group = row.group
	if group == null:
		return
	var lead: AlertData = group.lead()
	if Global.alert_manager != null:
		Global.alert_manager.acknowledge_group(group)
	if lead != null:
		_follow(lead)

func _on_clear_pressed() -> void:
	if Global.alert_manager != null:
		Global.alert_manager.clear_dismissible()

## Jump-to (WI-53 §7), through the two accessors WI-51 exposed for it.
##
## [method InspectorPanel.select] toggles when handed the already-selected
## subject, which is right for a click on the station and wrong here - a jump
## that deselects would be a jump to nothing.
func _follow(alert: AlertData) -> void:
	var node: Node2D = alert.subject_node()
	if node != null:
		var inspector: InspectorPanel = _inspector()
		if inspector != null:
			if inspector.selected_subject() != node:
				inspector.select(node)
			var target: Node2D = inspector.camera_target()
			_jump_to(target if target != null else node)
		else:
			_jump_to(node)
		return
	if alert.route != &"" and ROUTES.has(alert.route):
		var manager: ModeManager = _modes()
		if manager != null:
			manager.open(ROUTES[alert.route])

func _jump_to(node: Node2D) -> void:
	var camera: GameCamera = get_viewport().get_camera_2d() as GameCamera
	if camera != null:
		camera.jump_to(node.global_position)

func _inspector() -> InspectorPanel:
	if Global.ui_main == null or not is_instance_valid(Global.ui_main):
		return null
	return Global.ui_main.inspector

func _modes() -> ModeManager:
	if Global.ui_main == null or not is_instance_valid(Global.ui_main):
		return null
	return Global.ui_main.mode_manager

# --- geometry -------------------------------------------------------------------

## Sizes the content region to the rows, capped so the feed cannot squeeze the
## inspector below it out of the column. [UIMain] re-stacks the column off the
## `minimum_size_changed` this produces.
func _refit() -> void:
	if _column == null or _refitting:
		return
	_refitting = true
	var budget: float = float(maxi(height_budget - UIMetrics.READOUT_HEADER_HEIGHT, 0))
	var chrome: float = float(content_padding) * 2.0
	var shown: int = 0
	for child: Node in _column.get_children():
		var control: Control = child as Control
		if control == null or not control.visible:
			continue
		shown += 1
		if control != _scroll:
			chrome += control.get_combined_minimum_size().y
	chrome += float(maxi(shown - 1, 0)) * float(UIMetrics.ROW_GAP)
	var rows: float = _rows_box.get_combined_minimum_size().y if _scroll.visible else 0.0
	var rows_height: float = minf(rows, maxf(0.0, budget - chrome))
	_scroll.custom_minimum_size.y = rows_height
	content_height = int(ceilf(minf(chrome + rows_height, budget)))
	var wanted: int = _cap_for(budget)
	_refitting = false
	if wanted != _row_cap:
		_row_cap = wanted
		# Deferred rather than recursive: the rebuild changes the very sizes this
		# fit just measured.
		refresh.call_deferred()

## How many whole rows fit in a content region of `budget` pixels.
##
## The overflow row's space is reserved **unconditionally**, even when nothing is
## hidden. Slightly wasteful, and deliberate: measuring against the live chrome
## instead would make this a function of its own last answer - shrinking the cap
## reveals the overflow row, which shrinks the room, which shrinks the cap - and a
## layout that feeds back into itself is one bad frame away from oscillating once
## per refresh forever.
func _cap_for(budget: float) -> int:
	var row: float = _row_height()
	if row <= 0.0:
		return AlertRules.FEED_CAP # nothing built yet; the next fit corrects it
	var gap: float = float(UIMetrics.ROW_GAP)
	var available: float = budget - float(content_padding) * 2.0 - (row + gap)
	return clampi(int(floorf((available + gap) / (row + gap))), 1, AlertRules.FEED_CAP)

func _row_height() -> float:
	for row: AlertRow in _rows:
		if row.visible:
			return row.get_combined_minimum_size().y
	return 0.0

func _queue_refit() -> void:
	if _refitting:
		return
	_refit.call_deferred()
