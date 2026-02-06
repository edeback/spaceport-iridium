class_name TradeScreen
extends MarginContainer

@export var trade_resource_row_scene: PackedScene

var trade_resource_rows: Array[TradeResourceRow] = []
var component_currently_trading: TradeComponent = null

func _ready() -> void:
	for node: Node in %ResourceRowsContainer.get_children():
		node.queue_free()
		%ResourceRowsContainer.remove_child(node)
	SignalBus.set_up_trade.connect(set_up_trade)
	for resource: ResourceData in Global.market_manager.get_tradeable_resources():
		var new_resource_row: TradeResourceRow = trade_resource_row_scene.instantiate() as TradeResourceRow
		new_resource_row.set_up(resource)
		%ResourceRowsContainer.add_child(new_resource_row)
		new_resource_row.row_updated.connect(refresh_total)
		trade_resource_rows.append(new_resource_row)
	

func set_up_trade(trade_component: TradeComponent) -> void:
	component_currently_trading = trade_component
	%TotalCreditsLabel.text = "0"
	for row: TradeResourceRow in trade_resource_rows:
		row.start(trade_component)
	visible = true
	
func refresh_total() -> void:
	var total_change: int = 0
	for trade_row: TradeResourceRow in trade_resource_rows:
		total_change += trade_row.get_total_credits()
	%TotalCreditsLabel.text = str(total_change)
	var current_credits: int = Global.resource_manager.credit_resource.get_total()
	if current_credits + total_change < 0:
		%SubmitButton.disabled = true
		%TotalCreditsLabel.self_modulate = Color.RED
	else:
		%SubmitButton.disabled = false
		%TotalCreditsLabel.self_modulate = Color.WHITE
	
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
