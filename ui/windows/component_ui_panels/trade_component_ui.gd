class_name TradeComponentUI
extends ModuleComponentUI

## The docking bay's tab in the inspector: what the trade schedule is doing, and
## the way into the TRADE panel.
##
## It used to be the way into *two* surfaces - an "Order Sheet" button that raised
## the standing-order screen and a docked-only "Trade with Trader" button that
## raised the confirmation modal. WI-55 merged both into one panel, so this is one
## button, and it opens a mode rather than instantiating a screen: an entry point
## that raised its own surface would put a second panel on screen and break the
## one-panel invariant the whole console rests on.

var trade_component: TradeComponent
var _status_label: Label
var _open_button: ActionButton

func set_trade_component(new_trade_component: TradeComponent) -> void:
	trade_component = new_trade_component

func _ready() -> void:
	# Built in code so the authored .tscn stays untouched: a status line (next
	# trader ETA / docked countdown) and the button under it.
	var box: VBoxContainer = $MarginContainer/VBoxContainer
	_status_label = Label.new()
	_status_label.theme_type_variation = UIType.BODY
	box.add_child(_status_label)
	_open_button = ActionButton.create("Open Trade Panel", ActionButton.Weight.SECONDARY)
	_open_button.pressed.connect(_on_open_pressed)
	box.add_child(_open_button)
	_refresh()

func _process(_delta: float) -> void:
	# Cheap, and only runs while the inspector tab is open.
	_refresh()

func _refresh() -> void:
	var manager: TraderManager = Global.trader_manager
	if manager == null:
		return
	if manager.visit_active and manager.trader != null:
		_status_label.text = "%s docked — departs in %.1f h" % [
			manager.trader.trader_name, maxf(manager.visit_remaining_hours, 0.0)]
		_open_button.weight = ActionButton.Weight.PRIMARY
	else:
		_status_label.text = "Next trader: ~%d h" % ceili(maxf(manager.hours_to_next_visit, 0.0))
		_open_button.weight = ActionButton.Weight.SECONDARY

## Both trade surfaces used to deselect the module first, because the module info
## panel was a floating box that could sit on top of them. Neither the inspector
## nor the Trade panel has that problem - and Trade hides the inspector anyway
## ([member ConsolePanel.hides_inspector]), so the selection is simply out of the
## way while the player trades and back when they close it.
func _on_open_pressed() -> void:
	if Global.ui_main != null and Global.ui_main.mode_manager != null:
		Global.ui_main.mode_manager.open(ModeManager.Mode.TRADE)
