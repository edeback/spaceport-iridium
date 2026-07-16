class_name TradeComponent
extends ComponentBase

## The docking bay's trade brain (WI-08): holds the standing ORDER SHEET -
## what the player wants moved, independent of any particular trader visit.
## Sell orders configure the export bin as a haul destination (crew stage
## goods there continuously); buy orders wait for a trader (bought goods land
## in the import bin, whose existing surplus-export flow hauls them out).
## Actual trading happens in TraderManager against the docked trader.
##
## v1 orders are finite amounts in both directions ("sell 60 ore", "buy 50
## steel") that count down as they fulfill and clear at zero - a standing
## "keep exporting forever" is approximated by a large amount.

@export var export_storage: StorageComponent
@export var import_storage: StorageComponent

## resource -> amount still wanted. Persisted via the module save section.
var sell_orders: Dictionary[ResourceData, int] = {}
var buy_orders: Dictionary[ResourceData, int] = {}

var override_ui: bool = false

signal orders_changed

func ready_preview() -> void:
	override_ui = false

func ready_blueprint() -> void:
	override_ui = false

func ready_constructed() -> void:
	override_ui = true
	# The export bin pulls sell-order goods from ordinary storerooms, so its
	# import priority must beat theirs while staying under real consumers
	# (kitchen, construction) - see the JobPriorities band table.
	export_storage.update_priority(JobPriorities.TRADE_EXPORT_BIN)

# --- order sheet ----------------------------------------------------------------

func set_sell_order(resource: ResourceData, amount: int) -> void:
	if amount <= 0:
		clear_sell_order(resource)
		return
	sell_orders[resource] = amount
	export_storage.add_stored_resource(resource)
	_sync_sell_slot(resource)
	orders_changed.emit()

func set_buy_order(resource: ResourceData, amount: int) -> void:
	if amount <= 0:
		buy_orders.erase(resource)
	else:
		buy_orders[resource] = amount
	orders_changed.emit()

## Cancelling a sell order with goods already staged: the bin is not a
## general storage (accepts_exports = false), so stranded stock is dumped to
## a ResourcePile at the bay for haulers to sweep up (WI-08 edge case).
func clear_sell_order(resource: ResourceData) -> void:
	sell_orders.erase(resource)
	var staged: int = export_storage.total_stored_by_resource(resource)
	if staged > 0:
		var stacks: Array[ResourceStack] = export_storage.withdraw_stacks(resource, staged)
		if not stacks.is_empty():
			var pile := ResourcePile.spawn(Global.world_manager.pawn_layer, DockingBay.dock_position_for(owner_module), owner_module)
			pile.add_stacks(resource, stacks)
	export_storage.remove_stored_resource(resource)
	orders_changed.emit()

## Called by TraderManager as committed trades fulfill.
func reduce_sell_order(resource: ResourceData, amount: int) -> void:
	if not sell_orders.has(resource):
		return
	sell_orders[resource] -= amount
	if sell_orders[resource] <= 0:
		sell_orders.erase(resource)
		# Order complete: the slot stays (residual stock can still sell next
		# visit if re-ordered) but stops requesting hauls.
		_set_slot_desired(resource, 0)
	else:
		_sync_sell_slot(resource)
	orders_changed.emit()

func reduce_buy_order(resource: ResourceData, amount: int) -> void:
	if not buy_orders.has(resource):
		return
	buy_orders[resource] -= amount
	if buy_orders[resource] <= 0:
		buy_orders.erase(resource)
	orders_changed.emit()

## The bin's per-resource `desired` drives the existing import-job posting:
## keep it equal to the outstanding order (capped by bin capacity) so crew
## stage exactly what's still wanted and no more.
func _sync_sell_slot(resource: ResourceData) -> void:
	_set_slot_desired(resource, mini(sell_orders.get(resource, 0), export_storage.max_stored))

func _set_slot_desired(resource: ResourceData, desired: int) -> void:
	var slot: StorageData = export_storage.storage_data.get(resource)
	if slot != null:
		slot.desired = desired

# --- persistence ----------------------------------------------------------------
# Aggregated into the module's save entry by ModuleBase.get_save_data().

func get_save_data() -> Dictionary:
	if sell_orders.is_empty() and buy_orders.is_empty():
		return {}
	var sells: Dictionary = {}
	for resource: ResourceData in sell_orders:
		if resource.id != &"":
			sells[String(resource.id)] = sell_orders[resource]
	var buys: Dictionary = {}
	for resource: ResourceData in buy_orders:
		if resource.id != &"":
			buys[String(resource.id)] = buy_orders[resource]
	return {"sell": sells, "buy": buys}

func load_save_data(data: Dictionary) -> void:
	for id_str: String in data.get("sell", {}):
		var resource: ResourceData = Global.save_manager.get_resource_by_id(StringName(id_str))
		if resource != null:
			set_sell_order(resource, int(data["sell"][id_str]))
	for id_str: String in data.get("buy", {}):
		var resource: ResourceData = Global.save_manager.get_resource_by_id(StringName(id_str))
		if resource != null:
			set_buy_order(resource, int(data["buy"][id_str]))

func has_ui() -> bool:
	return override_ui

func get_ui() -> ModuleComponentUI:
	var trade_component_ui: TradeComponentUI = ui_info_panel_element.instantiate() as TradeComponentUI
	trade_component_ui.set_module(owner_module)
	trade_component_ui.set_trade_component(self)
	return trade_component_ui
