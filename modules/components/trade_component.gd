class_name TradeComponent
extends ComponentBase

@export var export_storage: StorageComponent
@export var import_storage: StorageComponent

func has_ui() -> bool:
	return true

func get_ui() -> ModuleComponentUI:
	var trade_component_ui: TradeComponentUI = ui_info_panel_element.instantiate() as TradeComponentUI
	trade_component_ui.set_module(owner_module)
	trade_component_ui.set_trade_component(self)
	return trade_component_ui
