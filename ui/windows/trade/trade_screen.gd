class_name TradeScreen
extends MarginContainer

## The ORDER SHEET (WI-08): standing buy/sell orders per resource. Available
## anytime; nothing trades here - orders configure the docking bay's bins
## (sell orders stage goods for the next trader) and fulfill while a trader
## is docked. The total shown is a projection at today's market prices.

@export var trade_resource_row_scene: PackedScene

var trade_resource_rows: Array[TradeResourceRow] = []
var component_currently_trading: TradeComponent = null

func _ready() -> void:
	for node: Node in %ResourceRowsContainer.get_children():
		node.queue_free()
		%ResourceRowsContainer.remove_child(node)
	for node: Node in %ResourceRowsContainer2.get_children():
		node.queue_free()
		%ResourceRowsContainer2.remove_child(node)
	SignalBus.set_up_trade.connect(set_up_trade)
	var resource_index: int = 0
	for resource: ResourceData in Global.market_manager.get_tradeable_resources():
		var new_resource_row: TradeResourceRow = trade_resource_row_scene.instantiate() as TradeResourceRow
		new_resource_row.set_up(resource)
		if resource_index % 2 == 0:
			%ResourceRowsContainer.add_child(new_resource_row)
		else:
			%ResourceRowsContainer2.add_child(new_resource_row)
		resource_index += 1
		new_resource_row.row_updated.connect(refresh_total)
		trade_resource_rows.append(new_resource_row)

func set_up_trade(trade_component: TradeComponent) -> void:
	component_currently_trading = trade_component
	for row: TradeResourceRow in trade_resource_rows:
		row.start(trade_component)
	refresh_total()
	visible = true

func refresh_total() -> void:
	var total_change: int = 0
	for trade_row: TradeResourceRow in trade_resource_rows:
		total_change += trade_row.get_total_credits()
	%TotalCreditsLabel.text = str(total_change)
	# Orders don't charge anything up front (fulfillment pays as goods move),
	# so a negative projection is allowed - just shown in red as a warning.
	%SubmitButton.disabled = false
	var current_credits: int = Global.resource_manager.credit_resource.get_total()
	%TotalCreditsLabel.add_theme_color_override("font_color",
		UIPalette.ATTENTION if current_credits + total_change < 0 else UIPalette.TEXT_EMPHASIS)

func submit() -> void:
	for row: TradeResourceRow in trade_resource_rows:
		row.commit()
	clean_up()

func cancel() -> void:
	clean_up()

func clean_up() -> void:
	visible = false
	for row: TradeResourceRow in trade_resource_rows:
		row.stop()
	component_currently_trading = null
