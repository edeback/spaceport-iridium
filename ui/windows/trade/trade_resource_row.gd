class_name TradeResourceRow
extends MarginContainer

var resource: ResourceData = null
var trade_component: TradeComponent = null

signal row_updated

func set_up(_resource: ResourceData) -> void:
	resource = _resource
	%ResourceName.text = resource.name
	%ResourceIcon.texture = resource.icon
	%BuyAmountSpinBox.value_changed.connect(value_changed)
	%SellAmountSpinBox.value_changed.connect(value_changed)
	
func start(_trade_component: TradeComponent) -> void:
	trade_component = _trade_component
	Global.market_manager.market_updated.connect(refresh)
	%BuyAmountSpinBox.value = 0
	%SellAmountSpinBox.value = 0
	refresh()
	
func stop() -> void:
	trade_component = null
	Global.market_manager.market_updated.disconnect(refresh)

func refresh() -> void:
	var buy_amount_available: int = Global.market_manager.get_quantity_available(resource)
	%BuyAmountSpinBox.max_value = buy_amount_available
	%BuyAvailableLabel.text = str(buy_amount_available)
	%BuyPriceLabel.text = str(Global.market_manager.get_buy_price(resource))
	#var sell_amount_available: int = floori(Global.resource_manager.get_total_quantity_of_resource(resource))
	var sell_amount_available: int = 0
	if trade_component.export_storage.cur_stored.has(resource):
		sell_amount_available = floori(trade_component.export_storage.cur_stored[resource])
	%SellAmountSpinBox.max_value = sell_amount_available
	%SellAvailableLabel.text = str(sell_amount_available)
	%SellPriceLabel.text = str(Global.market_manager.get_sell_price(resource))
	
func get_total_credits() -> int:
	var buy_cost: int = %BuyAmountSpinBox.value * Global.market_manager.get_buy_price(resource)
	var sell_profit: int = %SellAmountSpinBox.value * Global.market_manager.get_sell_price(resource)
	return sell_profit - buy_cost

func value_changed(_new_value: float) -> void:
	row_updated.emit()

func commit() -> void:
	var buy_amount: int = %BuyAmountSpinBox.value
	var buy_price: int = Global.market_manager.get_buy_price(resource)
	if  trade_component.import_storage.can_deposit(resource, buy_amount) and Global.market_manager.withdraw_resource(resource, buy_amount):
		trade_component.import_storage.deposit(resource, buy_amount)
		Global.resource_manager.credits -= buy_amount * buy_price
	var sell_amount: int = %SellAmountSpinBox.value
	var sell_price: int = Global.market_manager.get_sell_price(resource)
	if  trade_component.export_storage.can_withdraw(resource, sell_amount) and Global.market_manager.deposit_resource(resource, sell_amount):
		trade_component.export_storage.withdraw(resource, sell_amount)
		Global.resource_manager.credits += sell_amount * sell_price
