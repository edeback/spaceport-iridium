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
	_status_label.theme_type_variation = UIType.BODY
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

## Both trade surfaces used to deselect the module first, because the module info
## panel was a floating box that could sit on top of them. The inspector is
## right-anchored and 420px wide, so neither centred screen reaches it - and
## keeping the docking bay selected while you trade with it is the more useful
## behaviour anyway (WI-51). WI-55 folds both of these into the Trade panel.
func on_open_trade_screen() -> void:
	SignalBus.set_up_trade.emit(trade_component)

func _on_open_trader_screen() -> void:
	Global.ui_main.open_trader_screen()
