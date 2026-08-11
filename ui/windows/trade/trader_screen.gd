class_name TraderScreen
extends Control

## The docked-trader confirmation screen (WI-08). Pops on arrival and is
## reopenable from the docking bay panel while the trader is in dock. Unlike
## the order sheet (what's *desired*), this shows what's *actually possible*
## right now - capped by trader stock, cargo hold, and the order sheet - at
## the visit's snapshot prices, and lets the player edit numbers down before
## committing. The sim pauses while open so the trader can't leave mid-trade
## (UI stays real-time by design, so the screen keeps working).

## This screen's entry in [TimeManager]'s hold set (WI-53). WI-53 §edge-cases
## names this exact collision as its most likely bug: a critical alert and a
## docked trader both stopping the sim, each restoring "the state before I
## opened", and whichever closes second handing the game back to a holder that
## still wants it stopped. Named holds compose instead.
const PAUSE_HOLD: StringName = &"trader_screen"

var _rows: Array[Dictionary] = []

func open() -> void:
	var manager: TraderManager = Global.trader_manager
	if manager == null or not manager.visit_active:
		return
	Global.time_manager.hold_pause(PAUSE_HOLD)
	%TraderNameLabel.text = manager.trader.trader_name
	_build_rows()
	visible = true

func close() -> void:
	visible = false
	Global.time_manager.release_pause(PAUSE_HOLD)
	for child: Node in %TradeRows.get_children():
		child.queue_free()

func _build_rows() -> void:
	for child: Node in %TradeRows.get_children():
		child.queue_free()
	_rows.clear()
	var manager: TraderManager = Global.trader_manager
	var bay_trade: TradeComponent = manager.active_bay_trade_component()
	if bay_trade == null:
		return
	# One row per resource the sheet wants moved or the trader carries.
	var resources: Array[ResourceData] = []
	for resource: ResourceData in Global.market_manager.get_tradeable_resources():
		if bay_trade.buy_orders.has(resource) or bay_trade.sell_orders.has(resource) \
				or manager.trader_stock(resource) > 0:
			resources.append(resource)
	for resource: ResourceData in resources:
		var buy_ordered: int = bay_trade.buy_orders.get(resource, 0)
		var sell_ordered: int = bay_trade.sell_orders.get(resource, 0)
		var buy_cap: int = manager.trader_stock(resource)
		var in_bin: int = bay_trade.export_storage.total_stored_by_resource(resource)
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = resource.name
		name_label.add_theme_font_size_override("font_size", 24)
		name_label.custom_minimum_size.x = 110
		row.add_child(name_label)
		var buy_spin := _make_spin(buy_cap, mini(manager.committed_buys.get(resource, buy_cap), buy_ordered))
		buy_spin.value_changed.connect(_update_total)
		var sell_spin := _make_spin(resource.get_total(), mini(manager.committed_sells.get(resource, sell_ordered), sell_ordered))
		sell_spin.value_changed.connect(_update_total)
		row.add_child(_make_caption("Buy (of %d held) @ %dcr" % [manager.trader_stock(resource), manager.buy_prices.get(resource, 0)]))
		row.add_child(buy_spin)
		row.add_child(_make_caption("Sell (%d staged) @ %dcr" % [in_bin, manager.sell_prices.get(resource, 0)]))
		row.add_child(sell_spin)
		%TradeRows.add_child(row)
		_rows.append({"resource": resource, "buy": buy_spin, "sell": sell_spin})
	_update_total()

func _make_caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	return label

func _make_spin(max_value: int, value: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.rounded = true
	spin.max_value = max_value
	spin.set_value_no_signal(clampi(value, 0, max_value))
	spin.editable = max_value > 0
	return spin

func _update_total(_value: int = 0) -> void:
	var manager: TraderManager = Global.trader_manager
	var total: int = 0
	for row: Dictionary in _rows:
		var resource: ResourceData = row["resource"]
		total -= int((row["buy"] as SpinBox).value) * manager.buy_prices.get(resource, 0)
		total += int((row["sell"] as SpinBox).value) * manager.sell_prices.get(resource, 0)
	%TotalCreditsLabel.text = str(total)
	%TotalCreditsLabel.add_theme_color_override("font_color",
		UIPalette.ATTENTION if Global.resource_manager.credit_resource.get_total() + total < 0
		else UIPalette.TEXT_EMPHASIS)
		
func _on_commit_pressed() -> void:
	var buys: Dictionary[ResourceData, int] = {}
	var sells: Dictionary[ResourceData, int] = {}
	for row: Dictionary in _rows:
		buys[row["resource"]] = int((row["buy"] as SpinBox).value)
		sells[row["resource"]] = int((row["sell"] as SpinBox).value)
	Global.trader_manager.commit_trades(buys, sells)
	close()

func _on_close_pressed() -> void:
	close()
