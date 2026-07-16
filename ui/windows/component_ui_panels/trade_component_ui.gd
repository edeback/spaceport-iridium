class_name TradeComponentUI
extends ModuleComponentUI

var trade_component: TradeComponent
var _status_label: Label
var _trader_button: Button

func set_trade_component(new_trade_component: TradeComponent) -> void:
	trade_component = new_trade_component

func _ready() -> void:
	# Built in code so the authored .tscn stays untouched: a status line
	# (next trader ETA / docked countdown) and a docked-only trader button.
	var box: VBoxContainer = $MarginContainer/VBoxContainer
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 12)
	box.add_child(_status_label)
	box.move_child(_status_label, 0)
	_trader_button = Button.new()
	_trader_button.text = "Trade with Trader"
	_trader_button.pressed.connect(_on_open_trader_screen)
	box.add_child(_trader_button)
	_refresh()

func _process(_delta: float) -> void:
	# Cheap, and only runs while the panel is open.
	_refresh()

func _refresh() -> void:
	var manager: TraderManager = Global.trader_manager
	if manager == null:
		return
	if manager.visit_active and manager.trader != null:
		_status_label.text = "%s docked — departs in %.1f h" % [manager.trader.trader_name, maxf(manager.visit_remaining_hours, 0.0)]
		_trader_button.visible = true
	else:
		_status_label.text = "Next trader: ~%d h" % ceili(maxf(manager.hours_to_next_visit, 0.0))
		_trader_button.visible = false

func on_open_trade_screen() -> void:
	Global.ui_main.close_info_panel()
	SignalBus.set_up_trade.emit(trade_component)

func _on_open_trader_screen() -> void:
	Global.ui_main.close_info_panel()
	Global.ui_main.open_trader_screen()
