class_name ResourceLedger
extends ReadoutPanel

## The ledger flyout (WI-52): every tracked resource, grouped into four columns,
## with its amount and its per-cycle rate.
##
## The completeness half of invariant 4. Six resources are pinned into the
## console strip; this is where the other twelve (or the other ninety, once mods
## are involved) live. The layout's whole claim is that it is indifferent to the
## count, which is why four short columns are the correct look for a station that
## only has eighteen resources.
##
## **It is not a mode**, and it is invariant 1's one deliberate exception:
## checking stock mid-build must not close Build. [ModeManager] does not know it
## exists; it coexists with whatever panel is open, and [UIMain] ranks it *above*
## the open mode on Esc so the flyout closes first.
##
## It anchors bottom-right and grows upward like the inspector, stopping short of
## the right column - console flyouts never open over the map, the alerts or the
## inspector.
##
## PIN MODE is a mode of this panel rather than an always-live pin control on
## every row, because the ledger is read far more often than it is curated and a
## mis-click must not reshuffle the strip.

const SCENE_PATH: String = "res://ui/console/resource_ledger.tscn"

const LEGEND: String = "Pin any resource to promote it into the console strip · Rates are per cycle"

## Real seconds between value refreshes, and only while open. Real time, not
## `slow_tick`: the ledger is chrome and must not sweep four times faster because
## the sim is at 4x.
const REFRESH_INTERVAL: float = 0.5

static func create() -> ResourceLedger:
	return load(SCENE_PATH).instantiate() as ResourceLedger

## The strip the pin toggles act on. Set by [UIMain] right after instantiation;
## without it the panel still renders, just with pinning inert.
var strip: VitalsStrip = null:
	set(value):
		if strip != null and strip.pins_changed.is_connected(_on_pins_changed):
			strip.pins_changed.disconnect(_on_pins_changed)
		strip = value
		if strip != null:
			strip.pins_changed.connect(_on_pins_changed)
		_rebuild()

var _subtitle: Label
var _pin_button: ActionButton
var _column: VBoxContainer
var _scroll: ScrollContainer
var _columns_row: HBoxContainer
var _legend: Label
var _timer: Timer

## Resource id -> its row, so a value refresh writes into the existing rows
## instead of rebuilding eighteen buttons twice a second.
var _rows: Dictionary[StringName, ListRow] = {}
var _resources: Dictionary[StringName, ResourceData] = {}

var _pin_mode: bool = false
var _refitting: bool = false

func _ready() -> void:
	super()
	_build_body()
	visible = false
	_rebuild()

# --- open / close ---------------------------------------------------------------

func is_open() -> bool:
	return visible

func open() -> void:
	if visible:
		return
	visible = true
	# The station changed while nobody was looking; rebuilding on open is what
	# picks up a resource a mod's content pack introduced mid-session, and costs
	# nothing because it only happens on a keypress.
	_rebuild()
	_timer.start()

func close() -> void:
	if not visible:
		return
	visible = false
	# Pin mode is a per-visit state. Leaving it latched means the next glance at
	# the ledger is one mis-click away from reshuffling the strip.
	_set_pin_mode(false)
	_timer.stop()

func toggle() -> void:
	if visible:
		close()
	else:
		open()

# --- construction ---------------------------------------------------------------

## The frame is the scene; everything inside it is built here (program decision
## 8), so no hand-edited layout can drift out of sync with the four columns.
func _build_body() -> void:
	panel_width = UIMetrics.LEDGER_WIDTH
	content_padding = UIMetrics.READOUT_CONTENT_PAD
	drop_shadow = true
	label = "Resource Ledger"

	_subtitle = Label.new()
	_subtitle.theme_type_variation = UIType.META_LINE
	_subtitle.add_theme_color_override("font_color", UIPalette.TEXT_META)
	add_action(_subtitle)

	_pin_button = ActionButton.create("Pin Mode", ActionButton.Weight.SECONDARY)
	_pin_button.toggle_mode = true
	_pin_button.toggled.connect(_set_pin_mode)
	add_action(_pin_button)

	var esc := Label.new()
	esc.theme_type_variation = UIType.HOTKEY
	esc.text = "ESC"
	esc.add_theme_color_override("font_color", UIPalette.TEXT_META)
	add_action(esc)

	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.add_theme_constant_override("separation", UIMetrics.SECTION_GAP)
	content().add_child(_column)

	# The columns scroll as one block. A ScrollContainer reports a minimum height
	# of zero (WI-48's deviation 8, and WI-51 hit it twice), so the fit below
	# drives its height from the row block's own combined minimum.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_child(_scroll)

	_columns_row = HBoxContainer.new()
	_columns_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_columns_row.add_theme_constant_override("separation", UIMetrics.LEDGER_COLUMN_GAP)
	_scroll.add_child(_columns_row)

	_legend = Label.new()
	_legend.theme_type_variation = UIType.META_LINE
	_legend.text = LEGEND.to_upper()
	_legend.add_theme_color_override("font_color", UIPalette.TEXT_META)
	_legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(_legend)

	# Re-fit whenever anything below changes size, rather than measuring once:
	# fonts settle and the autowrapped legend learns its width after the first
	# layout pass. That is the WI-51 binding rule verbatim.
	_columns_row.minimum_size_changed.connect(_queue_refit)

	_timer = Timer.new()
	_timer.name = "RefreshTimer"
	_timer.wait_time = REFRESH_INTERVAL
	_timer.timeout.connect(refresh_values)
	add_child(_timer)

# --- geometry -------------------------------------------------------------------

## Grows the panel upward from its bottom edge, like the inspector.
## [ReadoutPanel.fit_height] grows downward from `offset_top`, which is right for
## the map at the top of the right column and wrong for a flyout whose bottom
## edge is the fixed one.
func fit_height() -> void:
	offset_top = offset_bottom - custom_minimum_size.y

func _refit() -> void:
	if _columns_row == null or _refitting:
		return
	_refitting = true
	var budget: float = float(UIMetrics.ledger_max_content_height())
	var legend: float = _legend.get_combined_minimum_size().y if _legend != null else 0.0
	var chrome: float = legend + float(UIMetrics.SECTION_GAP) + float(content_padding) * 2.0
	var rows: float = _columns_row.get_combined_minimum_size().y
	var rows_height: float = minf(rows, maxf(0.0, budget - chrome))
	_scroll.custom_minimum_size.y = rows_height
	content_height = int(ceilf(minf(chrome + rows_height, budget)))
	_refitting = false

## Deferred so a burst of layout changes in one frame settles into one fit, and
## so the fit never runs inside the notification that caused it.
func _queue_refit() -> void:
	if _refitting:
		return
	_refit.call_deferred()

# --- content --------------------------------------------------------------------

func _set_pin_mode(enabled: bool) -> void:
	_pin_mode = enabled
	if _pin_button != null:
		if _pin_button.button_pressed != enabled:
			_pin_button.button_pressed = enabled
		# The theme's secondary button has no distinct pressed state, so a toggle
		# left at one weight reads as inert in both. Promoting it to the primary
		# weight while it is on is the design's own vocabulary for "this is what
		# the panel is doing right now", rather than a bespoke lit style.
		_pin_button.weight = (ActionButton.Weight.PRIMARY if enabled
			else ActionButton.Weight.SECONDARY)
	_refresh_marks()

func _on_pins_changed() -> void:
	_refresh_marks()

## Rebuilds the four columns from scratch. Called on open and when the resource
## list could have changed - never on the refresh timer, which writes values into
## the rows this leaves behind.
func _rebuild() -> void:
	if _columns_row == null:
		return
	for child: Node in _columns_row.get_children():
		_columns_row.remove_child(child)
		child.queue_free()
	_rows.clear()
	_resources.clear()
	if Global.resource_manager == null:
		return
	var listed: Array[ResourceData] = Global.resource_manager.ledger_resources()
	# All four columns, always, even when a station has no ore yet: a column that
	# appears and disappears is a layout that moves under the player's cursor.
	for category: ResourceData.Category in LedgerModel.CATEGORY_ORDER:
		_columns_row.add_child(_build_column(category, LedgerModel.in_category(listed, category)))
	_refresh_marks()
	refresh_values()
	_queue_refit()

func _build_column(category: ResourceData.Category, resources: Array[ResourceData]) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = float(UIMetrics.LEDGER_COLUMN_WIDTH)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	column.add_child(SectionLabel.create(LedgerModel.category_label(category)))
	for resource: ResourceData in resources:
		var row: ListRow = ListRow.create()
		row.pressed.connect(_on_row_pressed.bind(resource.id))
		column.add_child(row)
		_rows[resource.id] = row
		_resources[resource.id] = resource
	return column

func _on_row_pressed(id: StringName) -> void:
	# Outside pin mode a row is a readout, not a control. The row is still a
	# Button (that is where hover and focus come from), so the press has to be
	# refused here rather than by disabling it - a disabled row greys its own text
	# and would make the whole ledger read as unavailable.
	if not _pin_mode or strip == null:
		return
	if not strip.toggle_pin(id) and not strip.is_pinned(id):
		# Refused, not toggled: the strip is full. Say so rather than doing
		# nothing, which reads as a broken button.
		SignalBus.station_alert.emit("Vitals strip is full - unpin one of the %d first."
			% LedgerModel.PIN_CAP)

## Writes the current amount, rate and variance average into the existing rows.
## Values only - nothing here adds or removes a node, which is what lets this run
## on a timer.
func refresh_values() -> void:
	if Global.resource_manager == null:
		return
	for id: StringName in _rows:
		var resource: ResourceData = _resources[id]
		var rate: float = Global.resource_manager.rate_per_cycle(resource)
		var row: ListRow = _rows[id]
		row.configure(resource.name, _meta_for(resource), LedgerModel.format_per_cycle(rate),
			_kind_for(id))
		row.set_action_color(LedgerModel.rate_color(rate))
	_refresh_subtitle()

## Amount, plus the station-wide average richness/quality for resources that
## carry variance - "142" or "142 · 72% AVG".
func _meta_for(resource: ResourceData) -> String:
	var text: String = LedgerModel.format_compact(resource.get_total())
	if resource.has_variance:
		var average: float = resource.average_instance_value()
		if average >= 0.0:
			text += " · %d%% avg" % roundi(average * 100.0)
	return text

## A pinned row wears the live treatment whether or not pin mode is on, because
## "this one is in the strip" is exactly what cyan means everywhere else. Pin mode
## only changes whether clicking it does anything - and what the left slot shows.
func _kind_for(id: StringName) -> UIPalette.Row:
	if strip != null and strip.is_pinned(id):
		return UIPalette.Row.LIVE
	return UIPalette.Row.INERT

func _refresh_marks() -> void:
	for id: StringName in _rows:
		_apply_mark(id)
	_refresh_subtitle()

## In pin mode the row's left slot stops being the resource icon and becomes the
## pin toggle - a lit swatch for pinned, a dim one for not. That swap is the
## affordance: outside pin mode the rows are a readout and must not look like
## eighteen controls, and inside it every row has to say which state it is in.
func _apply_mark(id: StringName) -> void:
	var row: ListRow = _rows[id]
	row.set_kind(_kind_for(id))
	if _pin_mode:
		row.set_swatch(UIPalette.LIVE if strip != null and strip.is_pinned(id)
			else UIPalette.INERT_ACCENT)
	else:
		row.set_icon(_resources[id].icon)

func _refresh_subtitle() -> void:
	if _subtitle == null:
		return
	var pinned: int = strip.pin_count() if strip != null else 0
	_subtitle.text = "%d TRACKED · %d/%d PINNED" % [_rows.size(), pinned, LedgerModel.PIN_CAP]
