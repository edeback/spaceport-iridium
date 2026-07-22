class_name TraderManager
extends Node

## Trader visits (WI-08): a guaranteed caravan docks every caravan_cycles for
## visit_hours. All trades run against the visiting trader's own inventory at
## prices snapshotted on arrival; the shared market settles the visit's NET
## trades only at departure, so prices stay stable for the whole visit.
## Committed trades fulfill incrementally on slow_tick while docked
## (charge/credit on fulfillment, never on commit), so late-hauled goods
## still sell and an unfilled buy remainder costs nothing.

## Days between caravan visits
@export var caravan_cycles: int = 4
@export var visit_hours: float = 10.0
## First arrival lands sooner than the steady cadence - the caravan is the
## early-game safety valve.
@export var first_visit_hours: float = 48.0
## The fixed first visitor: cheap plentiful steel, pays high for ore.
@export var first_caravan_profile: TraderData
@export var trader_shuttle_scene: PackedScene
## Market-derived generic traders carry this fraction of current market stock.
@export var generic_stock_fraction: float = 0.4
@export var generic_cargo_hold: int = 150

var hours_to_next_visit: float = 12.0
var _had_first_caravan: bool = false

# --- active visit -------------------------------------------------------------
var visit_active: bool = false
var trader: TraderData = null # duplicated profile; stock mutates as we buy
var visit_remaining_hours: float = 0.0
var cargo_used: int = 0
## Price snapshots taken at arrival (market price x trader multiplier).
var buy_prices: Dictionary[ResourceData, int] = {}   # what we pay per unit
var sell_prices: Dictionary[ResourceData, int] = {}  # what we receive per unit
## Player-committed trade amounts still to fulfill this visit.
var committed_buys: Dictionary[ResourceData, int] = {}
var committed_sells: Dictionary[ResourceData, int] = {}
## + = station sold to trader (market gains at settlement), - = station bought.
var _net_market_delta: Dictionary[ResourceData, int] = {}
var _bay_ref: Dictionary = {}
var _departure_warned: bool = false
var _import_full_alerted: bool = false
var _shuttle: ArrivalShuttle = null
## True from _begin_visit until the shuttle docks - the schedule timer must
## not keep firing (and re-rolling the trader) during the fly-in.
var _inbound: bool = false

## Anything about the active visit changed (fulfillment, commit, arrival,
## departure) - UI countdowns and the trader screen refresh off this.
signal visit_changed

func _ready() -> void:
	Global.trader_manager = self
	hours_to_next_visit = first_visit_hours
	Global.time_manager.slow_tick.connect(_on_slow_tick)

func _process(delta: float) -> void:
	var sim_hours: float = Global.time_manager.scale(delta) / TimeManager.SECONDS_PER_HOUR
	if sim_hours <= 0.0:
		return
	if not visit_active:
		if _inbound:
			return # shuttle already on its way in
		hours_to_next_visit -= sim_hours
		if hours_to_next_visit <= 0.0:
			_begin_visit()
		return
	visit_remaining_hours -= sim_hours
	if visit_remaining_hours <= 1.0 and not _departure_warned:
		_departure_warned = true
		SignalBus.station_alert.emit("%s departs in about an hour" % trader.trader_name)
	if visit_remaining_hours <= 0.0:
		_end_visit("visit time over")

# --- scheduling & arrival -------------------------------------------------------

func _begin_visit() -> void:
	var bay: ModuleBase = find_trade_bay()
	if bay == null:
		# No (constructed) docking bay: the trader passes by. Reschedule the
		# full cadence - the safety valve resumes once a bay exists.
		SignalBus.station_alert.emit("A trader passed by — no docking bay to receive them")
		hours_to_next_visit = caravan_cycles * TimeManager.HOURS_PER_CYCLE
		return
	if not _had_first_caravan and first_caravan_profile != null:
		trader = first_caravan_profile.duplicate(true)
		_had_first_caravan = true
	else:
		trader = _build_generic_trader()
	_snapshot_prices()
	_bay_ref = SaveManager.module_ref(bay)
	cargo_used = 0
	committed_buys.clear()
	committed_sells.clear()
	_net_market_delta.clear()
	_departure_warned = false
	_import_full_alerted = false
	if trader_shuttle_scene == null:
		_dock(true)
		return
	_inbound = true
	_shuttle = trader_shuttle_scene.instantiate() as ArrivalShuttle
	Global.world_manager.pawn_layer.add_child(_shuttle)
	var dock: Vector2 = DockingBay.dock_position_for(bay)
	_shuttle.setup(dock, dock + Vector2(DockingBay.approach_sign_for(bay) * 1500.0, 0.0))
	_shuttle.docked.connect(_dock.bind(true), CONNECT_ONE_SHOT)

## announce=false on the save/load restore path: the trader screen popup
## isn't persisted, so a reload shouldn't re-pop it (reopen from the bay).
func _dock(announce: bool) -> void:
	_inbound = false
	visit_active = true
	if announce:
		visit_remaining_hours = visit_hours
		SignalBus.trader_arrived.emit(trader)
	visit_changed.emit()

func _build_generic_trader() -> TraderData:
	var generic := TraderData.new()
	generic.id = &"generic"
	generic.trader_name = "Trader"
	generic.cargo_hold = generic_cargo_hold
	for resource: ResourceData in Global.market_manager.get_tradeable_resources():
		var carried: int = int(Global.market_manager.get_quantity_available(resource) * generic_stock_fraction)
		if carried > 0:
			generic.stock[resource] = carried
	return generic

func _snapshot_prices() -> void:
	buy_prices.clear()
	sell_prices.clear()
	for resource: ResourceData in Global.market_manager.get_tradeable_resources():
		var multiplier: float = trader.price_multiplier(resource)
		buy_prices[resource] = maxi(ceili(Global.market_manager.get_buy_price(resource) * multiplier), 1)
		sell_prices[resource] = maxi(floori(Global.market_manager.get_sell_price(resource) * multiplier), 1)

## First constructed docking bay with a TradeComponent. Multi-bay routing is
## deliberately future work (WI-08 edge case). Public: ContractManager syncs
## its demand registration against this too.
func find_trade_bay() -> ModuleBase:
	for node: Node in get_tree().get_nodes_in_group(Groups.MODULE):
		var module: ModuleBase = node as ModuleBase
		if module == null or not module is DockingBay or not module.is_complete():
			continue
		if module.get_component_by_type(TradeComponent) != null:
			return module
	return null

func active_bay_trade_component() -> TradeComponent:
	var bay: ModuleBase = SaveManager.resolve_module_ref(_bay_ref)
	if bay == null or not is_instance_valid(bay):
		return null
	return bay.get_component_by_type(TradeComponent) as TradeComponent

# --- committing & fulfillment ---------------------------------------------------

## The trader screen writes the player's confirmed numbers here; fulfillment
## then drains them on slow_tick as bin contents / space / credits allow.
func commit_trades(buys: Dictionary[ResourceData, int], sells: Dictionary[ResourceData, int]) -> void:
	if not visit_active:
		return
	committed_buys = buys.duplicate()
	committed_sells = sells.duplicate()
	for resource: ResourceData in committed_buys.keys():
		if committed_buys[resource] <= 0:
			committed_buys.erase(resource)
	for resource: ResourceData in committed_sells.keys():
		if committed_sells[resource] <= 0:
			committed_sells.erase(resource)
	visit_changed.emit()

func trader_stock(resource: ResourceData) -> int:
	if trader == null:
		return 0
	return trader.stock.get(resource, 0)

func cargo_space() -> int:
	if trader == null:
		return 0
	return maxi(trader.cargo_hold - cargo_used, 0)

func _on_slow_tick(_interval: float) -> void:
	if not visit_active:
		return
	var bay_trade: TradeComponent = active_bay_trade_component()
	if bay_trade == null:
		# Bay deconstructed mid-visit: depart immediately, settling whatever
		# already fulfilled (WI-08 edge case).
		_end_visit("docking bay lost")
		return
	_fulfill(bay_trade)

func _fulfill(bay_trade: TradeComponent) -> void:
	var credits: ResourceData = Global.resource_manager.credit_resource
	var traded: bool = false
	# Contract goods first (WI-14): allocation beats generic sales, and what
	# the contracts take never reaches the sell loop below. Consigned freight -
	# no cargo space used, no market settlement, paid by the issuer on
	# completion rather than here.
	Global.contract_manager.collect_contract_goods(bay_trade)
	# Sells: bin contents -> trader hold, credits in.
	for resource: ResourceData in committed_sells.keys():
		var in_bin: int = bay_trade.export_storage.total_stored_by_resource(resource)
		var amount: int = mini(mini(committed_sells[resource], in_bin), cargo_space())
		if amount <= 0:
			continue
		if not bay_trade.export_storage.withdraw(resource, amount):
			continue
		# Route through the ARC levy (WI-25): the player banks the net, ARC skims
		# its cut off the top. Levy-disabled games get the gross back unchanged.
		credits.change_global_total(Global.economy_manager.record_income(amount * sell_prices.get(resource, 0), &"trade"))
		# Goods physically left the station (WI-26): counts toward the tier goals.
		SignalBus.resources_exported.emit(resource, amount)
		cargo_used += amount
		committed_sells[resource] -= amount
		if committed_sells[resource] <= 0:
			committed_sells.erase(resource)
		bay_trade.reduce_sell_order(resource, amount)
		_net_market_delta[resource] = _net_market_delta.get(resource, 0) + amount
		traded = true
	# Buys: trader stock -> import bin, credits out. Charge on fulfillment.
	for resource: ResourceData in committed_buys.keys():
		var price: int = buy_prices.get(resource, 0)
		var affordable: int = committed_buys[resource] if price <= 0 else mini(committed_buys[resource], credits.get_total() / price)
		var amount: int = mini(mini(affordable, trader_stock(resource)), bay_trade.import_storage.space_available())
		if amount <= 0:
			if bay_trade.import_storage.space_available() <= 0 and not _import_full_alerted:
				_import_full_alerted = true
				SignalBus.station_alert.emit("Import bin full — haul it out to keep buying")
			continue
		if not bay_trade.import_storage.deposit(resource, amount):
			continue
		credits.change_global_total(-amount * price)
		trader.stock[resource] = trader_stock(resource) - amount
		committed_buys[resource] -= amount
		if committed_buys[resource] <= 0:
			committed_buys.erase(resource)
		bay_trade.reduce_buy_order(resource, amount)
		_net_market_delta[resource] = _net_market_delta.get(resource, 0) - amount
		traded = true
	if traded:
		visit_changed.emit()

# --- contract courier (WI-14) -----------------------------------------------------
# The final-day rescue: if contract goods sit staged with no caravan due, the
# issuer sends their own shuttle. It ONLY collects contract-allocated goods -
# no trade screen, no market settlement, no cargo limit.

var _courier_active: bool = false

func is_inbound() -> bool:
	return _inbound

func dispatch_contract_courier() -> bool:
	if visit_active or _inbound or _courier_active:
		return false
	var bay: ModuleBase = find_trade_bay()
	if bay == null:
		return false
	_courier_active = true
	if trader_shuttle_scene == null:
		_courier_collect(bay, null)
		return true
	var shuttle := trader_shuttle_scene.instantiate() as ArrivalShuttle
	Global.world_manager.pawn_layer.add_child(shuttle)
	var dock: Vector2 = DockingBay.dock_position_for(bay)
	shuttle.setup(dock, dock + Vector2(DockingBay.approach_sign_for(bay) * 1500.0, 0.0))
	shuttle.docked.connect(_courier_collect.bind(bay, shuttle), CONNECT_ONE_SHOT)
	return true

func _courier_collect(bay: ModuleBase, shuttle: ArrivalShuttle) -> void:
	if is_instance_valid(bay):
		var bay_trade: TradeComponent = bay.get_component_by_type(TradeComponent) as TradeComponent
		if bay_trade != null:
			Global.contract_manager.collect_contract_goods(bay_trade)
	if shuttle != null and is_instance_valid(shuttle):
		# Linger briefly at the dock before flying off, like the hire shuttle.
		await Global.time_manager.sim_seconds(TimeManager.SECONDS_PER_HOUR)
		shuttle.depart()
	_courier_active = false

# --- departure ------------------------------------------------------------------

func _end_visit(reason: String) -> void:
	print("Trader departing (%s), %.1fh remaining" % [reason, visit_remaining_hours])
	visit_active = false
	# Net market settlement, deferred to departure for visit-long price
	# stability (WI-08 design).
	for resource: ResourceData in _net_market_delta:
		var delta: int = _net_market_delta[resource]
		if delta > 0:
			Global.market_manager.deposit_resource(resource, delta)
		elif delta < 0:
			var available: int = Global.market_manager.get_quantity_available(resource)
			Global.market_manager.withdraw_resource(resource, mini(-delta, available))
	Global.market_manager.market_updated.emit()
	SignalBus.trader_departed.emit(trader)
	if _shuttle != null and is_instance_valid(_shuttle):
		_shuttle.depart()
	_shuttle = null
	trader = null
	committed_buys.clear()
	committed_sells.clear()
	_net_market_delta.clear()
	_bay_ref = {}
	hours_to_next_visit = caravan_cycles * TimeManager.HOURS_PER_CYCLE
	visit_changed.emit()

# --- persistence ----------------------------------------------------------------

func get_save_data() -> Dictionary:
	var data: Dictionary = {
		"hours_to_next": hours_to_next_visit,
		"had_first": _had_first_caravan,
	}
	if visit_active and trader != null:
		data["visit"] = {
			"remaining": visit_remaining_hours,
			"cargo_used": cargo_used,
			"cargo_hold": trader.cargo_hold,
			"trader_name": trader.trader_name,
			"stock": _resource_dict_to_ids(trader.stock),
			"buy_prices": _resource_dict_to_ids(buy_prices),
			"sell_prices": _resource_dict_to_ids(sell_prices),
			"committed_buys": _resource_dict_to_ids(committed_buys),
			"committed_sells": _resource_dict_to_ids(committed_sells),
			"market_delta": _resource_dict_to_ids(_net_market_delta),
			"bay": _bay_ref,
			"warned": _departure_warned,
		}
	return data

func load_save_data(data: Dictionary) -> void:
	hours_to_next_visit = float(data.get("hours_to_next", first_visit_hours))
	_had_first_caravan = bool(data.get("had_first", false))
	if not data.has("visit"):
		return
	var visit: Dictionary = data["visit"]
	trader = TraderData.new()
	trader.trader_name = String(visit.get("trader_name", "Trader"))
	trader.cargo_hold = int(visit.get("cargo_hold", generic_cargo_hold))
	_ids_to_resource_dict(visit.get("stock", {}), trader.stock)
	_ids_to_resource_dict(visit.get("buy_prices", {}), buy_prices)
	_ids_to_resource_dict(visit.get("sell_prices", {}), sell_prices)
	_ids_to_resource_dict(visit.get("committed_buys", {}), committed_buys)
	_ids_to_resource_dict(visit.get("committed_sells", {}), committed_sells)
	_ids_to_resource_dict(visit.get("market_delta", {}), _net_market_delta)
	visit_remaining_hours = float(visit.get("remaining", 0.0))
	cargo_used = int(visit.get("cargo_used", 0))
	_bay_ref = visit.get("bay", {})
	_departure_warned = bool(visit.get("warned", false))
	# Re-spawn the shuttle already parked at the dock (no fly-in, no popup).
	var bay: ModuleBase = SaveManager.resolve_module_ref(_bay_ref)
	if bay != null and trader_shuttle_scene != null:
		_shuttle = trader_shuttle_scene.instantiate() as ArrivalShuttle
		Global.world_manager.pawn_layer.add_child(_shuttle)
		var dock: Vector2 = DockingBay.dock_position_for(bay)
		_shuttle.setup(dock, dock)
	_dock(false)

func _resource_dict_to_ids(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for resource: ResourceData in source:
		if resource.id != &"":
			out[String(resource.id)] = source[resource]
	return out

func _ids_to_resource_dict(source: Dictionary, target: Dictionary) -> void:
	target.clear()
	for id_str: String in source:
		var resource: ResourceData = Global.save_manager.get_resource_by_id(StringName(id_str))
		if resource != null:
			target[resource] = int(source[id_str])
