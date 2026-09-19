class_name TradePanel
extends VBoxContainer

## The body of the TRADE mode panel (WI-55): **three screens merged into one**.
##
## | Was | Is |
## | --- | --- |
## | `trade_screen` - the standing order sheet, always available | the `ORDERS` tab, undocked |
## | `trader_screen` - the docked confirmation modal, which paused the sim | the same tab, docked, plus `CONFIRM` |
## | `contracts_screen` - offers, active, history | the `CONTRACTS` tab |
##
## `PRICE HISTORY` and `ROUTES` are in the design's tab strip and are deliberately
## **absent** (program decision 2): [MarketManager] keeps only current supply and
## derives price from it, so there is no history to graph, and routes are an
## undesigned system. The strip takes them the day they exist; faking them now is
## worse than their absence.
##
## ## One table, two states
##
## Undocked the numbers are a *want*: the steppers write standing orders straight
## onto the bay's [TradeComponent] and there is no commit step (the order sheet has
## never had one and must not gain one - the footer says so). Docked they are what
## is actually possible this visit, at the visit's snapshot prices, and `CONFIRM`
## hands them to [method TraderManager.commit_trades].
##
## A docked confirm **also writes the standing order**, which is the one behaviour
## the merge changes. The two screens used to be layered - the sheet arranged the
## hauls, the modal committed against what the sheet had already staged - so the
## modal could cap itself at the sheet's numbers and never touch them. With one
## table there is one number, and it has to mean both things or a docked sell of
## sixty ore would commit sixty units that nothing would ever haul to the bay.
##
## The number counts **goods**, signed the way the station's own stock moves:
## positive buys in, negative sells out. [TradeOffer] argues that; the summary
## bar's NET runs the other way (a sell earns) and is meant to.
##
## ## The pause
##
## Opening this panel while a trader is docked stops the sim, so the trader cannot
## depart mid-trade (`trader_screen`'s guarantee, kept). It is a **named hold**
## ([method TimeManager.hold_pause]), never a write to `TimeManager.paused` - that
## field is the player's own pause and it is what saves. WI-53 built the
## reference count precisely so this hold and a critical alert's can both be
## outstanding without either restoring a state the other still wants.

## This panel's entry in [TimeManager]'s hold set. It replaces `trader_screen`'s,
## which was the same hold under the old name.
const PAUSE_HOLD: StringName = &"trade_panel"

## How many commodity rows go in the left column before the second one starts.
## The design pages the table into two columns; splitting by half rather than at a
## fixed count keeps them level for any number of tradables, a mod's included.
const TAB_ORDERS: StringName = &"orders"
const TAB_CONTRACTS: StringName = &"contracts"

## What the frame prints at its foot. The undocked line exists to answer the one
## question a table with no CONFIRM button raises.
const FOOTER_UNDOCKED: String = "Positive buys in · negative sells out · standing orders save as you set them"
const FOOTER_DOCKED: String = "Positive buys in · negative sells out · confirm to commit this visit"
const FOOTER_NO_BAY: String = "No docking bay · build one to place orders"

signal close_requested

var _frame: ConsolePanel
var _tabs: TabStrip
var _orders_page: Control
var _contracts_page: ContractsTab
var _columns: HBoxContainer
var _rows: Array[TradeResourceRow] = []
var _summary_label: Label
var _net_label: Label
var _clear_button: ActionButton
var _confirm_button: ActionButton
var _summary_bar: PanelContainer

## Lines the last refresh had to trim because somebody else claimed the stock.
## Counted rather than listed: the rows themselves go amber, and the footer only
## has to say that it happened.
var _clamped: int = 0

## Docked lines the player has moved but has not confirmed, signed the way the
## steppers are.
##
## Docked, a stepper is a [i]proposal[/i]: [method _on_row_changed] must not write
## it to the bay's sheet, because the number is not real until `CONFIRM`. That
## left it with nowhere at all to live, so the refresh in the same handler read
## the line straight back off the orders it had deliberately not been written to
## and snatched it to zero - the docked table could not be edited. This is where a
## proposal lives in the meantime; [method TradeOffer.displayed_amount] is where
## it ranks against the visit's commitments and the standing sheet.
##
## Cleared on every [signal TraderManager.visit_changed] - an arrival, a
## departure, a commit and a fulfilment each make the manager's numbers the truth
## again - and deliberately [i]not[/i] on close: a player who shuts the panel
## mid-order during a visit comes back to the order, and the trader cannot have
## left without the signal that empties this.
var _pending: Dictionary[ResourceData, int] = {}

## Builds the frame and mounts this body in it. One call, like the widgets have -
## [UIMain] stays a mount table.
static func create() -> ConsolePanel:
	var frame: ConsolePanel = ConsolePanel.create()
	frame.title = "Trade"
	frame.panel_width = UIMetrics.PANEL_TRADE_WIDTH
	frame.content_padding = 0
	frame.hotkey = ModeManager.hotkey_label(ModeManager.Mode.TRADE)
	# The design gives Trade the whole screen: at 1180px plus the 344px right
	# column there is no room for the inspector, and selection means nothing here.
	frame.hides_inspector = true
	frame.footer_variation = UIType.BODY
	var body := TradePanel.new()
	body._frame = frame
	frame.content().add_child(body)
	return frame

func _ready() -> void:
	add_theme_constant_override("separation", 0)
	_build_tabs()
	_build_pages()
	_build_summary()
	_connect_sources()
	_tabs.set_tabs([
		{"id": TAB_ORDERS, "text": "Orders"},
		{"id": TAB_CONTRACTS, "text": "Contracts"},
	])
	show_tab(_tabs.selected())

# --- construction --------------------------------------------------------------

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

	_orders_page = _build_orders_page()
	pad.add_child(_orders_page)
	_contracts_page = ContractsTab.new()
	pad.add_child(_contracts_page)

## Two paged columns of commodities, inside one scroll. The scroll is for a
## modded station with more tradables than the base game's sixteen; at 1080 the
## table fits without it.
func _build_orders_page() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_columns = HBoxContainer.new()
	_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_columns.add_theme_constant_override("separation", UIMetrics.SECTION_GAP)
	scroll.add_child(_columns)

	var resources: Array[ResourceData] = _tradable_resources()
	var half: int = int(ceil(resources.size() / 2.0))
	for column_index: int in 2:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", UIMetrics.ITEM_GAP)
		column.add_child(TradeResourceRow.make_header())
		_columns.add_child(column)
		var from: int = column_index * half
		for index: int in range(from, mini(from + half, resources.size())):
			var row: TradeResourceRow = TradeResourceRow.create()
			column.add_child(row)
			row.set_up(resources[index])
			row.amount_changed.connect(_on_row_changed)
			_rows.append(row)
	return scroll

## Tradables in display order. Sorted by name rather than left in scan order so
## the two columns are stable across a load and a mod does not shuffle the table.
func _tradable_resources() -> Array[ResourceData]:
	var out: Array[ResourceData] = []
	if Global.market_manager == null:
		return out
	out.assign(Global.market_manager.get_tradeable_resources())
	out.sort_custom(func(a: ResourceData, b: ResourceData) -> bool:
		return a.name.naturalnocasecmp_to(b.name) < 0)
	return out

## The order's running summary and its two actions, welded to the foot of the
## content region.
##
## Not [member ConsolePanel.footer_text]: that strip is the panel's standing
## *instruction*, one line of meta text, and this is a live total with two
## buttons. They stack - the instruction is under this - which is also how the
## undocked "there is no commit step" line stays visible beside a `CLEAR` that
## does have an effect.
func _build_summary() -> void:
	_summary_bar = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = UIPalette.CONTROL_FILL
	box.border_color = UIPalette.DIVIDER
	box.set_border_width_all(0)
	box.border_width_top = UIMetrics.BORDER_WIDTH
	box.set_corner_radius_all(0)
	box.set_content_margin_all(float(UIMetrics.CONTENT_PAD))
	_summary_bar.add_theme_stylebox_override("panel", box)
	add_child(_summary_bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIMetrics.SECTION_GAP)
	_summary_bar.add_child(row)

	_summary_label = Label.new()
	_summary_label.theme_type_variation = UIType.META_LINE
	_summary_label.add_theme_color_override("font_color", UIPalette.TEXT_META)
	_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_summary_label)

	var net_caption := Label.new()
	net_caption.text = "NET"
	net_caption.theme_type_variation = UIType.READOUT_LABEL
	net_caption.add_theme_color_override("font_color", UIPalette.TEXT_META)
	net_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(net_caption)

	_net_label = Label.new()
	_net_label.theme_type_variation = UIType.METRIC_LARGE
	_net_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_net_label)

	_clear_button = ActionButton.create("Clear", ActionButton.Weight.SECONDARY)
	_clear_button.pressed.connect(_on_clear_pressed)
	row.add_child(_clear_button)

	_confirm_button = ActionButton.create("Confirm", ActionButton.Weight.PRIMARY)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	row.add_child(_confirm_button)

## Everything that can move a number in this table. All of them refresh only
## while the panel is on screen, which is what [method on_opened] is for.
##
## `slow_tick` is the AVAIL driver: reservations move whenever a hauler claims or
## releases stock, and there is no signal for that worth subscribing to at HUD
## granularity. It is also why AVAIL holds still while docked - the sim is paused,
## so nothing can be claimed behind the player's back.
func _connect_sources() -> void:
	if Global.trader_manager != null:
		Global.trader_manager.visit_changed.connect(_on_visit_changed)
	if Global.market_manager != null:
		Global.market_manager.market_updated.connect(_on_source_changed)
	if Global.time_manager != null:
		Global.time_manager.slow_tick.connect(_on_slow_tick.unbind(1))

# --- mode hooks ----------------------------------------------------------------

func on_opened() -> void:
	_sync_pause()
	refresh()

func on_closed() -> void:
	# Unconditional rather than routed through _sync_pause: a close must release
	# whatever this panel is holding even if the trader left in the same frame.
	if Global.time_manager != null:
		Global.time_manager.release_pause(PAUSE_HOLD)

## Takes or drops the docked hold to match what is actually on screen. Idempotent
## on both sides, so it is safe to call from every path that could change either
## half of the answer.
func _sync_pause() -> void:
	if Global.time_manager == null:
		return
	if is_visible_in_tree() and _is_docked():
		Global.time_manager.hold_pause(PAUSE_HOLD)
	else:
		Global.time_manager.release_pause(PAUSE_HOLD)

# --- state ---------------------------------------------------------------------

func _is_docked() -> bool:
	return Global.trader_manager != null and Global.trader_manager.visit_active

## The bay's order sheet: the docked bay while a trader is in, otherwise the first
## constructed bay with a [TradeComponent]. Null when the station has no bay -
## which the table renders as a dimmed, uneditable state rather than as an empty
## panel (WI-54: locked is a state, not an absence).
func _bay_trade() -> TradeComponent:
	var manager: TraderManager = Global.trader_manager
	if manager == null:
		return null
	if manager.visit_active:
		var docked: TradeComponent = manager.active_bay_trade_component()
		if docked != null:
			return docked
	var bay: ModuleBase = manager.find_trade_bay()
	if bay == null:
		return null
	return bay.get_component_by_type(TradeComponent) as TradeComponent

# --- refresh -------------------------------------------------------------------

func _on_slow_tick() -> void:
	if is_visible_in_tree():
		refresh()

func _on_source_changed() -> void:
	if is_visible_in_tree():
		refresh()

## A trader arrived, departed, or a committed trade fulfilled.
##
## The departure case is why this exists: the docked pause makes it impossible
## while the panel is open by the normal route, but a cheat, a load, or the bay
## being deconstructed can all end a visit anyway - and the panel must fall back
## to the undocked state rather than leave a `CONFIRM` that commits to nobody.
func _on_visit_changed() -> void:
	# Every emitter of this signal makes the manager authoritative again, so a
	# proposal that outlived one is stale by definition.
	_pending.clear()
	_sync_pause()
	if is_visible_in_tree():
		refresh()

func refresh() -> void:
	var docked: bool = _is_docked()
	var bay_trade: TradeComponent = _bay_trade()
	# Rows first: the header's footer line reports how many of them had to be
	# trimmed, so it cannot be written before they have been.
	_refresh_rows(docked, bay_trade)
	_refresh_summary(docked, bay_trade)
	_apply_header(docked, bay_trade)
	if _contracts_page != null and _contracts_page.visible:
		_contracts_page.refresh()

func _apply_header(docked: bool, bay_trade: TradeComponent) -> void:
	if _frame == null or not is_instance_valid(_frame):
		return
	var manager: TraderManager = Global.trader_manager
	if docked and manager != null and manager.trader != null:
		_frame.subtitle = "%s · docked · departs in %d h" % [
			manager.trader.trader_name, ceili(maxf(manager.visit_remaining_hours, 0.0))]
	elif manager != null:
		_frame.subtitle = "No ship docked · next in %d h" % ceili(maxf(manager.hours_to_next_visit, 0.0))
	else:
		_frame.subtitle = "No ship docked"
	# The Contracts tab has its own standing instruction (none), so the order
	# sheet's line must not sit under it.
	if _tabs != null and _tabs.selected() != TAB_ORDERS:
		_frame.footer_text = ""
		return
	var footer: String = FOOTER_DOCKED if docked else FOOTER_UNDOCKED
	if bay_trade == null:
		footer = FOOTER_NO_BAY
	elif _clamped > 0:
		footer = "%s · %d line(s) trimmed, the stock was claimed elsewhere" % [footer, _clamped]
	_frame.footer_text = footer

func _refresh_rows(docked: bool, bay_trade: TradeComponent) -> void:
	_clamped = 0
	var manager: TraderManager = Global.trader_manager
	var market: MarketManager = Global.market_manager
	var credits: int = Global.resource_manager.credit_resource.get_total() if Global.resource_manager != null else 0
	var cargo_space: int = manager.cargo_space() if docked and manager != null else TradeOffer.ORDER_CAP
	var import_space: int = TradeOffer.ORDER_CAP
	if docked and bay_trade != null:
		import_space = bay_trade.storage.space_available(false, StorageData.Role.OUTPUT)
	for row: TradeResourceRow in _rows:
		var resource: ResourceData = row.resource
		var market_buy: int = market.get_buy_price(resource) if market != null else 0
		var market_sell: int = market.get_sell_price(resource) if market != null else 0
		var buy_price: int = market_buy
		var sell_price: int = market_sell
		if docked and manager != null:
			buy_price = TradeOffer.unit_price(resource, manager.buy_prices, market_buy, true)
			sell_price = TradeOffer.unit_price(resource, manager.sell_prices, market_sell, true)
		var held: int = resource.get_total()
		var avail: int = resource.available_unreserved()
		var wanted: int = _current_amount(row, docked, bay_trade)
		var limit_sell: int = TradeOffer.sell_limit(avail, wanted, cargo_space)
		var limit_buy: int = TradeOffer.ORDER_CAP
		if docked and manager != null:
			limit_buy = TradeOffer.buy_limit(
				manager.trader_stock(resource), credits, buy_price, import_space)
		var clamped_amount: int = TradeOffer.clamp_amount(wanted, limit_buy, limit_sell)
		# Say so rather than silently trimming at confirm: the player set that
		# number against an AVAIL that has since moved.
		var was_clamped: bool = clamped_amount != wanted
		if was_clamped:
			_clamped += 1
		row.refresh(buy_price, sell_price, held, avail, clamped_amount,
			limit_buy, limit_sell, bay_trade != null, was_clamped)

## What this line currently reads: the proposal, then the visit's commitment, then
## the standing order. The precedence is [method TradeOffer.displayed_amount],
## which is where it is argued and where it is tested - this end only gathers the
## three dictionaries.
##
## A row the player is mid-drag on keeps its own number - [TradeResourceRow]
## ignores the push anyway, and feeding it back through the limits here would make
## the footer's total disagree with the table for a frame.
func _current_amount(row: TradeResourceRow, docked: bool, bay_trade: TradeComponent) -> int:
	if bay_trade == null:
		return 0
	var manager: TraderManager = Global.trader_manager
	var committed_sells: Dictionary = {}
	var committed_buys: Dictionary = {}
	if manager != null:
		committed_sells = manager.committed_sells
		committed_buys = manager.committed_buys
	return TradeOffer.displayed_amount(row.resource, docked, _pending,
		committed_sells, committed_buys, bay_trade.sell_orders, bay_trade.buy_orders)

func _refresh_summary(docked: bool, bay_trade: TradeComponent) -> void:
	var lines: Array = _lines(docked)
	_summary_label.text = TradeOffer.summary_text(lines)
	var net: int = TradeOffer.net_credits(lines)
	_net_label.text = "%+d cr" % net if net != 0 else "0 cr"
	_net_label.add_theme_color_override("font_color", UIPalette.sign_color(float(net)))
	# CONFIRM only exists while docked: standing orders have no commit step, and a
	# button that implied they did would be a lie about where the numbers went.
	_confirm_button.visible = docked and bay_trade != null
	_clear_button.disabled = bay_trade == null

## The table as [TradeOffer] sees it - one [TradeOffer.Line] per set row.
func _lines(docked: bool) -> Array:
	var manager: TraderManager = Global.trader_manager
	var market: MarketManager = Global.market_manager
	var lines: Array = []
	for row: TradeResourceRow in _rows:
		if row.amount == 0:
			continue
		var market_buy: int = market.get_buy_price(row.resource) if market != null else 0
		var market_sell: int = market.get_sell_price(row.resource) if market != null else 0
		var buy_price: int = market_buy
		var sell_price: int = market_sell
		if docked and manager != null:
			buy_price = TradeOffer.unit_price(row.resource, manager.buy_prices, market_buy, true)
			sell_price = TradeOffer.unit_price(row.resource, manager.sell_prices, market_sell, true)
		lines.append(TradeOffer.Line.of(row.resource, row.amount, buy_price, sell_price))
	return lines

# --- interaction ----------------------------------------------------------------

## A committed stepper move. Undocked this writes the standing order immediately -
## the sheet has never had a commit step. Docked it stages the number as a
## proposal instead, because it is not real until `CONFIRM` - but it does have to
## be staged somewhere, or the refresh below reads the line back off the orders it
## was deliberately not written to and the move undoes itself.
func _on_row_changed(row: TradeResourceRow) -> void:
	if _is_docked():
		_pending[row.resource] = row.amount
	else:
		_write_order(row.resource, row.amount)
	refresh()

## Pushes one signed line onto the bay's order sheet. Both sides are written every
## time, which is what keeps "positive sells and negative buys" true on the
## component as well as in the table: switching a line from sell to buy has to
## take the sell order away, or the export bin keeps staging goods for an order
## the player has replaced.
func _write_order(resource: ResourceData, amount: int) -> void:
	var bay_trade: TradeComponent = _bay_trade()
	if bay_trade == null:
		return
	var sell: int = maxi(-amount, 0)
	var buy: int = maxi(amount, 0)
	# Guarded rather than written unconditionally: set_sell_order(0) is
	# clear_sell_order, which dumps staged stock to a pile at the bay - correct
	# when the player cancels an order, wrong as a no-op on a line that never had
	# one.
	if bay_trade.sell_orders.get(resource, 0) != sell:
		bay_trade.set_sell_order(resource, sell)
	if bay_trade.buy_orders.get(resource, 0) != buy:
		bay_trade.set_buy_order(resource, buy)

## Empties the table. It clears the standing orders in both states - a docked
## `CLEAR` that left the sheet alone would repopulate every line on the next
## refresh, because an untouched line reads from the sheet - and, while docked,
## withdraws the visit's commitment too, or the manager would keep fulfilling
## numbers the table no longer shows.
func _on_clear_pressed() -> void:
	# Explicit rather than left to the `commit_trades` below: that call only
	# happens while docked, and CLEAR must empty the table in both states.
	_pending.clear()
	for row: TradeResourceRow in _rows:
		_write_order(row.resource, 0)
		row.amount = 0
	if _is_docked() and Global.trader_manager != null:
		var no_buys: Dictionary[ResourceData, int] = {}
		var no_sells: Dictionary[ResourceData, int] = {}
		Global.trader_manager.commit_trades(no_buys, no_sells)
	refresh()

## Commits the visit. Writes the standing orders first: a committed sell only ever
## fulfils out of the export bin, and it is the standing order that makes crew
## haul the goods there.
##
## Closes afterwards, and that is deliberate rather than incidental - fulfilment
## runs on `slow_tick`, this panel holds the sim stopped, so a confirmation that
## left the panel open would look like a button that did nothing.
func _on_confirm_pressed() -> void:
	var bay_trade: TradeComponent = _bay_trade()
	if bay_trade == null or Global.trader_manager == null:
		return
	# Every row, not only the set ones. `_lines()` drops zeros - a zero is not a
	# trade and has no business in a total or a commitment - but a row the player
	# has just zeroed is the one row whose standing order most needs writing: it
	# is a cancellation, and skipping it left the old order on the sheet for the
	# next refresh to read straight back into the table. "Set it to anything but
	# zero" was the shape of that bug.
	for row: TradeResourceRow in _rows:
		_write_order(row.resource, row.amount)
	var lines: Array = _lines(true)
	Global.trader_manager.commit_trades(TradeOffer.buy_orders(lines), TradeOffer.sell_orders(lines))
	close_requested.emit()

## Public and re-routing, matching [method CommsPanel.show_tab] (WI-58).
##
## The guard is the shape of WI-55's own tab-strip defect: a caller that swaps the
## page directly leaves the strip painted on the old tab, and the panel then shows
## one thing under another thing's name. Harmless today - the only caller is the
## strip itself - but a probe or a screenshot driver reaching past the strip is
## exactly how that defect was found in the first place, and closing it is three
## lines.
func show_tab(id: StringName) -> void:
	if _orders_page == null:
		return
	if _tabs != null and is_instance_valid(_tabs) and _tabs.selected() != id:
		_tabs.select(id) # emits tab_selected, which lands back here
		return
	var orders: bool = id == TAB_ORDERS
	_orders_page.visible = orders
	_contracts_page.visible = not orders
	# The summary bar totals the order table, so it belongs to that tab and not to
	# the panel.
	_summary_bar.visible = orders
	if orders:
		refresh()
	else:
		if _frame != null and is_instance_valid(_frame):
			_frame.footer_text = ""
		_contracts_page.refresh()
