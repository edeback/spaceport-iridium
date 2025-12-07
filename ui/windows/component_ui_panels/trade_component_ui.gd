class_name TradeComponentUI
extends ModuleComponentUI

var trade_component: TradeComponent

func set_trade_component(new_trade_component: TradeComponent) -> void:
	trade_component = new_trade_component

func on_open_trade_screen() -> void:
	SignalBus.set_up_trade.emit(trade_component)
	
