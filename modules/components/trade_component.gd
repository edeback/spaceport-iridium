class_name TradeComponent
extends ComponentBase

## The docking bay's trade brain (WI-08): holds the standing ORDER SHEET -
## what the player wants moved, independent of any particular trader visit.
## Sell orders create INPUT slots so crew stage goods there continuously; buy
## orders wait for a trader, and bought goods land in OUTPUT slots that haul
## themselves out to the station's storerooms.
## Actual trading happens in TraderManager against the docked trader.
##
## v1 orders are finite amounts in both directions ("sell 60 ore", "buy 50
## steel") that count down as they fulfill and clear at zero - a standing
## "keep exporting forever" is approximated by a large amount.
##
## WI-65 renamed the two bins and merged them into one component. The old names
## were the exact inverse of what they held: `storage` was where goods
## were IMPORTED to await export, and `storage` was where imports landed
## to be EXPORTED onward. They are now roles on one bin - staging is INPUT,
## arrivals are OUTPUT - which is also what stops a large sell order eating the
## space an inbound purchase needs, since the two roles have separate pools.

## The bay's single bin. Its staging slots are INPUT (`max_stored`), its arrival
## slots are OUTPUT (`output_capacity`).
@export var storage: StorageComponent

## resource -> amount still wanted. Persisted via the module save section.
var sell_orders: Dictionary[ResourceData, int] = {}
var buy_orders: Dictionary[ResourceData, int] = {}
## resource -> units still to be staged+picked up for accepted contracts
## (WI-14). NOT persisted here: ContractManager re-registers from its own
## saved contract states each slow_tick, so the two can't drift apart.
var contract_demand: Dictionary[ResourceData, int] = {}

var override_ui: bool = false

signal orders_changed

func ready_preview() -> void:
	override_ui = false

func ready_blueprint() -> void:
	override_ui = false

func ready_constructed() -> void:
	override_ui = true
	# The staging slots pull sell-order goods from ordinary storerooms, so this
	# bin's priority must beat theirs while staying under real consumers
	# (kitchen, construction) - see the JobPriorities band table. Arrivals are
	# unaffected: an OUTPUT slot ships at the floor whatever this is set to.
	storage.update_priority(JobPriorities.TRADE_EXPORT_BIN)
	assert(storage.max_stored > 0 and storage.output_capacity > 0,
		"a trade bay needs both pools: max_stored stages sell orders, output_capacity receives purchases")

# --- order sheet ----------------------------------------------------------------

func set_sell_order(resource: ResourceData, amount: int) -> void:
	if amount <= 0:
		clear_sell_order(resource)
		return
	sell_orders[resource] = amount
	storage.add_stored_resource(resource, StorageData.Role.INPUT)
	_sync_sell_slot(resource)
	orders_changed.emit()

func set_buy_order(resource: ResourceData, amount: int) -> void:
	if amount <= 0:
		buy_orders.erase(resource)
	else:
		buy_orders[resource] = amount
	orders_changed.emit()

## Cancelling a sell order with goods already staged: the bin is not a
## general storage (its slots are INPUT), so stranded stock is dumped to
## a ResourcePile at the bay for haulers to sweep up (WI-08 edge case).
func clear_sell_order(resource: ResourceData) -> void:
	sell_orders.erase(resource)
	# Contract-earmarked stock stays in the bin (WI-14) - only the surplus
	# beyond remaining contract demand gets dumped.
	var staged: int = storage.total_stored_by_resource(resource) - contract_demand.get(resource, 0)
	if staged > 0:
		var stacks: Array[ResourceStack] = storage.withdraw_stacks(resource, staged)
		if not stacks.is_empty():
			var pile := ResourcePile.spawn(
					Global.world_manager.get_canvas_for_module(owner_module),
					DockingBay.dock_position_for(owner_module), owner_module)
			pile.add_stacks(resource, stacks)
	if not contract_demand.has(resource):
		storage.remove_stored_resource(resource)
	_sync_sell_slot(resource)
	orders_changed.emit()

## Called by TraderManager as committed trades fulfill.
func reduce_sell_order(resource: ResourceData, amount: int) -> void:
	if not sell_orders.has(resource):
		return
	sell_orders[resource] -= amount
	if sell_orders[resource] <= 0:
		sell_orders.erase(resource)
	# Re-sync rather than zero: a contract may still want hauls of this
	# resource even when the generic order just completed.
	_sync_sell_slot(resource)
	orders_changed.emit()

func reduce_buy_order(resource: ResourceData, amount: int) -> void:
	if not buy_orders.has(resource):
		return
	buy_orders[resource] -= amount
	if buy_orders[resource] <= 0:
		buy_orders.erase(resource)
	orders_changed.emit()

# --- contract allocation (WI-14) ---------------------------------------------------
# Contract goods ride the same export bin as sell orders; the demand ledger
# here only sizes the bin's `desired` so crew keep hauling. Which units belong
# to which contract is decided at pickup time (ContractManager iterates its
# active list in accept order) - the bin itself stays fungible.

func add_contract_demand(resource: ResourceData, amount: int) -> void:
	if resource == null or amount <= 0:
		return
	contract_demand[resource] = contract_demand.get(resource, 0) + amount
	storage.add_stored_resource(resource, StorageData.Role.INPUT)
	_sync_sell_slot(resource)
	orders_changed.emit()

## A trader/courier picked up `amount` of contract goods from the bin.
func reduce_contract_demand(resource: ResourceData, amount: int) -> void:
	if not contract_demand.has(resource) or amount <= 0:
		return
	contract_demand[resource] -= amount
	if contract_demand[resource] <= 0:
		contract_demand.erase(resource)
	_sync_sell_slot(resource)
	orders_changed.emit()

## A contract stopped wanting `amount` units WITHOUT them shipping (failure,
## or a demand re-sync shrinking it). Staged stock beyond everything still
## wanted is dumped to a pile at the bay, same as cancelling a sell order.
func release_contract_demand(resource: ResourceData, amount: int) -> void:
	reduce_contract_demand(resource, amount)
	var wanted: int = sell_orders.get(resource, 0) + contract_demand.get(resource, 0)
	var surplus: int = storage.total_stored_by_resource(resource) - wanted
	if surplus > 0:
		var stacks: Array[ResourceStack] = storage.withdraw_stacks(resource, surplus)
		if not stacks.is_empty():
			var pile := ResourcePile.spawn(
					Global.world_manager.get_canvas_for_module(owner_module),
					DockingBay.dock_position_for(owner_module), owner_module)
			pile.add_stacks(resource, stacks)

## The bin's per-resource `desired` drives the existing import-job posting:
## keep it equal to the outstanding orders + contract demand (capped by bin
## capacity) so crew stage exactly what's still wanted and no more.
func _sync_sell_slot(resource: ResourceData) -> void:
	var wanted: int = sell_orders.get(resource, 0) + contract_demand.get(resource, 0)
	_set_slot_desired(resource, mini(wanted, storage.max_stored))

func _set_slot_desired(resource: ResourceData, desired: int) -> void:
	var slot: StorageData = storage.storage_data.get(resource)
	if slot != null:
		slot.desired = desired

# --- persistence ----------------------------------------------------------------
# Aggregated into the module's save entry by ModuleBase.get_save_data().

func save_order() -> int:
	return 50

func save_key() -> StringName:
	return &"trade"

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
