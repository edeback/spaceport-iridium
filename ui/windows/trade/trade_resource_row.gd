class_name TradeResourceRow
extends MarginContainer

## One resource on the ORDER SHEET (WI-08): standing buy/sell targets, not an
## instant trade. "Available" shows market stock (buy side) and total station
## stock (sell side) as previews; prices are current market prices - actual
## trades settle at the docked trader's snapshot prices.

var resource: ResourceData = null
var trade_component: TradeComponent = null

signal row_updated

func set_up(_resource: ResourceData) -> void:
	resource = _resource
	%ResourceName.text = resource.name
	%ResourceIcon.texture = resource.icon
	%BuyAmountSpinBox.value_changed.connect(_buy_changed)
	%SellAmountSpinBox.value_changed.connect(_sell_changed)

func start(_trade_component: TradeComponent) -> void:
	trade_component = _trade_component
	Global.market_manager.market_updated.connect(refresh)
	%BuyAmountSpinBox.set_value_no_signal(trade_component.buy_orders.get(resource, 0))
	%SellAmountSpinBox.set_value_no_signal(trade_component.sell_orders.get(resource, 0))
	%BuyAmountSpinBox.max_value = 9999
	%SellAmountSpinBox.max_value = 9999
	refresh()

func stop() -> void:
	trade_component = null
	Global.market_manager.market_updated.disconnect(refresh)

func refresh() -> void:
	# Orders aren't capped by today's market: the visiting trader's own stock
	# is the real limit at trade time, so the spin boxes stay open-ended.
	%BuyPriceLabel.text = str(Global.market_manager.get_buy_price(resource))
	%SellPriceLabel.text = str(Global.market_manager.get_sell_price(resource))

## Projected credits if the whole standing order fulfilled at today's prices -
## a preview, not a charge.
func get_total_credits() -> int:
	var buy_cost: int = int(%BuyAmountSpinBox.value) * Global.market_manager.get_buy_price(resource)
	var sell_profit: int = int(%SellAmountSpinBox.value) * Global.market_manager.get_sell_price(resource)
	return sell_profit - buy_cost

## Buying and selling the same resource cancels itself - setting one side
## zeroes the other.
func _buy_changed(new_value: float) -> void:
	if new_value > 0:
		%SellAmountSpinBox.set_value_no_signal(0)
	row_updated.emit()

func _sell_changed(new_value: float) -> void:
	if new_value > 0:
		%BuyAmountSpinBox.set_value_no_signal(0)
	row_updated.emit()

## Writes this row's standing order onto the trade component. No credits
## move here - fulfillment (and payment) happens while a trader is docked.
func commit() -> void:
	trade_component.set_buy_order(resource, int(%BuyAmountSpinBox.value))
	trade_component.set_sell_order(resource, int(%SellAmountSpinBox.value))
