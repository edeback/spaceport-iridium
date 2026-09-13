class_name AlertHistory
extends ReadoutPanel

## The alert log (WI-53): every alert this station has seen, newest first, with a
## cycle/hour stamp and a priority filter.
##
## It is what makes `CLEAR ALL` safe. Clearing is only non-destructive because
## the rows go somewhere, and a clear the player trusts is a clear they will
## actually use instead of letting forty rows pile up in the feed.
##
## LOW alerts are logged too (2026-09-13). WI-53 left them out as missable, but
## the feed's `+ n more` line opens this flyout, and a comet arrival hidden behind
## that line and absent from here read as a broken link. The LOW tab and the two
## above it are what keep them from burying the rest.
##
## Like the resource ledger (WI-52) this is a **flyout, not a mode** - it is
## raised from a permanent readout rather than from the console, it is a readout
## itself rather than a workspace, and closing Build to read what happened would
## be exactly the interruption invariant 1 exists to prevent. It opens to the
## left of the right column and never over it.

const SCENE_PATH: String = "res://ui/alerts/alert_history.tscn"

const EMPTY_TEXT: String = "Nothing logged yet — every alert this station raises is kept here"

## Filter tabs. `ALL` is a sentinel rather than a fourth priority, so the filter
## never has to be an `int` that sometimes means a priority and sometimes does not.
const FILTER_ALL: StringName = &"all"
const FILTER_CRITICAL: StringName = &"critical"
const FILTER_HIGH: StringName = &"high"
const FILTER_LOW: StringName = &"low"

var _column: VBoxContainer
var _scroll: ScrollContainer
var _rows_box: VBoxContainer
var _empty: Label
var _tabs: TabStrip
var _count: Label

var _rows: Array[AlertRow] = []
var _filter: StringName = FILTER_ALL
var _refitting: bool = false

static func create() -> AlertHistory:
	return load(SCENE_PATH).instantiate() as AlertHistory

func _ready() -> void:
	super()
	_build_body()
	visible = false

# --- open / close -----------------------------------------------------------------

func is_open() -> bool:
	return visible

func open() -> void:
	if visible:
		return
	visible = true
	refresh()

func close() -> void:
	if not visible:
		return
	visible = false

func toggle() -> void:
	if visible:
		close()
	else:
		open()

# --- construction -----------------------------------------------------------------

func _build_body() -> void:
	panel_width = UIMetrics.ALERT_HISTORY_WIDTH
	# Same rule as the resource ledger: a flyout sits beside the right column and
	# never over it.
	right_inset = UIMetrics.ALERT_HISTORY_RIGHT_INSET
	content_padding = UIMetrics.READOUT_CONTENT_PAD
	drop_shadow = true
	label = "Alert Log"
	# Cyan, not amber (WI-58). The log is a record of things that have already
	# happened and been dealt with; the amber budget is for "look at this now", and
	# a permanently amber accent on a history flyout spends it on nothing.
	accent_color = UIPalette.LIVE

	_count = Label.new()
	_count.theme_type_variation = UIType.META_LINE
	_count.add_theme_color_override("font_color", UIPalette.TEXT_META)
	add_action(_count)

	var esc := Label.new()
	esc.theme_type_variation = UIType.HOTKEY
	esc.text = "ESC"
	esc.add_theme_color_override("font_color", UIPalette.TEXT_META)
	add_action(esc)

	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	content().add_child(_column)

	_tabs = TabStrip.create()
	_tabs.name = "Filter"
	_tabs.set_tabs([
		{"id": FILTER_ALL, "text": "All"},
		{"id": FILTER_CRITICAL, "text": "Critical"},
		{"id": FILTER_HIGH, "text": "High"},
		{"id": FILTER_LOW, "text": "Low"},
	] as Array[Dictionary])
	_tabs.tab_selected.connect(_on_filter_selected)
	_column.add_child(_tabs)

	_empty = Label.new()
	_empty.name = "Empty"
	_empty.theme_type_variation = UIType.META_LINE
	_empty.text = EMPTY_TEXT.to_upper()
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.add_theme_color_override("font_color", UIPalette.TEXT_META)
	_column.add_child(_empty)

	_scroll = ScrollContainer.new()
	_scroll.name = "Rows"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_child(_scroll)

	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	_scroll.add_child(_rows_box)

	_rows_box.minimum_size_changed.connect(_queue_refit)

func _on_filter_selected(id: StringName) -> void:
	_filter = id
	refresh()

# --- rendering --------------------------------------------------------------------

## Rebuilt on open and on a filter change only. The log does not move while it is
## being read - a new alert arriving would otherwise scroll the row the player is
## looking at out from under them.
func refresh() -> void:
	if _rows_box == null:
		return
	var manager: AlertManager = Global.alert_manager
	var logged: Array[AlertData] = manager.history() if manager != null else [] as Array[AlertData]
	var filtered: Array[AlertData] = _apply_filter(logged)
	_sync_row_count(filtered.size())
	for index: int in filtered.size():
		# One alert per row: the feed coalesces a burst so the important row stays
		# visible, and the log is where the individual entries survive that.
		_rows[index].bind(AlertRules.Group.new(AlertRules.family_of(filtered[index].id),
			[filtered[index]] as Array[AlertData]), true)
	_empty.visible = filtered.is_empty()
	_scroll.visible = not filtered.is_empty()
	_count.text = "%d LOGGED" % logged.size()
	_refit()

func _apply_filter(logged: Array[AlertData]) -> Array[AlertData]:
	match _filter:
		FILTER_CRITICAL:
			return AlertRules.filter_priority(logged, AlertData.Priority.CRITICAL)
		FILTER_HIGH:
			return AlertRules.filter_priority(logged, AlertData.Priority.HIGH)
		FILTER_LOW:
			return AlertRules.filter_priority(logged, AlertData.Priority.LOW)
		_:
			return logged

## A log row is a readout, not a control: its subject is long gone and its
## acknowledgement already happened. Rows are pooled for the same reason the
## feed's are, and the pool is capped by what the filter shows rather than by the
## three hundred entries behind it.
func _sync_row_count(wanted: int) -> void:
	while _rows.size() < wanted:
		var row: AlertRow = AlertRow.create()
		# Inert rather than merely unwired: nothing here is clickable, and a row
		# that lit on hover would promise an action it does not have. [ListRow]
		# already points its disabled style box back at the normal one, so this
		# costs the log nothing visually.
		row.disabled = true
		row.focus_mode = Control.FOCUS_NONE
		_rows_box.add_child(row)
		_rows.append(row)
	for index: int in _rows.size():
		_rows[index].visible = index < wanted

# --- geometry ---------------------------------------------------------------------

## Grows downward from its top edge, which is where the alert feed's header is -
## the flyout reads as coming out of the readout that opened it.
func fit_height() -> void:
	offset_bottom = offset_top + custom_minimum_size.y

func _refit() -> void:
	if _column == null or _refitting:
		return
	_refitting = true
	var budget: float = float(UIMetrics.alert_history_max_content_height())
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
	fit_height()
	_refitting = false

func _queue_refit() -> void:
	if _refitting:
		return
	_refit.call_deferred()
