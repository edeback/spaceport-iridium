class_name ContractManager
extends Node

## Deadline-driven delivery contracts (WI-14). Owns the offer/active/history
## lists and the resolution rules; fulfillment rides the docking bay's
## existing export flow - an accepted contract registers "contract demand" on
## the bay's TradeComponent so crew stage goods into the export bin, and
## visiting traders (or a deadline courier) pick them up contract-first.
##
## Demand registration is re-synced lazily on slow_tick against whichever
## constructed bay currently exists: that one mechanism covers accepting,
## save/load restore, bay destruction, and a replacement bay being built.

@export var max_active: int = 3
## Offers rolled per trader visit (inclusive band).
@export var min_offers_per_visit: int = 1
@export var max_offers_per_visit: int = 2
## Premium over current market sell price, rolled per offer.
@export var premium_range: Vector2 = Vector2(1.2, 1.5)
## Deadline: cycles from now, rolled per offer (inclusive band).
@export var min_deadline_cycles: int = 3
@export var max_deadline_cycles: int = 6
## Penalty as a fraction of the contract's total payout.
@export var penalty_fraction: float = 0.25
## Offer amount ~= this fraction of the station's current stored total of the
## resource (v1 production proxy), floored at min_offer_amount.
@export var offer_amount_fraction: float = 0.5
@export var min_offer_amount: int = 10
## Station must hold at least this much of a resource for it to be offered.
@export var min_stored_to_offer: int = 5
@export var history_cap: int = 20
@export var issuer_names: Array[String] = [
	"ARC Logistics", "Meridian Combine", "Halcyon Freight", "Vesta Syndicate",
	"Outer Ring Cooperative", "Kessler & Sons", "Hypervelocity Acquisitions, Limited",
	"Charon Shipping", "X-cel Products", "Stellar Shipyards",
]

var offers: Array[ContractData] = []
var active: Array[ContractData] = []
var history: Array[ContractData] = []
## Completed-contract counter, stored for future foreign-relations work.
var reputation: int = 0

var _next_id: int = 1
## The TradeComponent contract demand is currently registered on (null if no
## bay). Compared against the live bay each slow_tick.
var _demand_component: TradeComponent = null
## Alert-suppression latch only; not saved (WI-45 A7). A load re-warns once that
## the contracts have no bay, which is true at that moment anyway.
var _bay_lost_alerted: bool = false

## Anything about the lists changed - the contracts screen refreshes off this.
signal contracts_changed

func _ready() -> void:
	Global.contract_manager = self
	# After world: contract demand re-registers on the restored bay via the first
	# slow_tick; staged goods are already back in the bin.
	SaveManager.register_section(&"contracts", 140, get_save_data, load_save_data)
	SignalBus.trader_arrived.connect(_on_trader_arrived)
	Global.time_manager.cycle_changed.connect(_on_cycle_changed)
	Global.time_manager.slow_tick.connect(_on_slow_tick)

func _unhandled_input(event: InputEvent) -> void:
	# A developer key, not a player one (WI-68 F5); see EventManager's twin.
	if not OS.is_debug_build():
		return
	if event.is_action_pressed("debug_offer_contract"):
		get_viewport().set_input_as_handled()
		if generate_offer(0.0) == null:
			SignalBus.station_alert.emit("Debug: nothing stored worth contracting")

# --- offer generation -------------------------------------------------------------

func _on_trader_arrived(_trader: TraderData) -> void:
	# Standing offers expire if unaccepted by the next visit (WI-14 design).
	for offer: ContractData in offers:
		offer.state = ContractData.State.EXPIRED
		AlertManager.resolve_alert(AlertRules.make_id(&"contract_offered", offer.id))
		_push_history(offer)
	if not offers.is_empty():
		SignalBus.station_alert.emit("Unclaimed contract offers have expired")
	offers.clear()
	for i: int in randi_range(min_offers_per_visit, max_offers_per_visit):
		generate_offer(0.0)
	contracts_changed.emit()

## Rolls one offer scaled to station stores. Returns null when the station
## holds nothing worth contracting. Also the entry point for event effects
## (EventEffectOfferContract) and the debug key.
func generate_offer(premium_bonus: float) -> ContractData:
	var candidates: Array[ResourceData] = []
	for resource: ResourceData in Global.market_manager.get_tradeable_resources():
		if resource.get_total() >= min_stored_to_offer:
			candidates.append(resource)
	if candidates.is_empty():
		return null
	var resource: ResourceData = candidates.pick_random() as ResourceData
	var contract := ContractData.new()
	contract.id = _next_id
	_next_id += 1
	contract.resource = resource
	contract.amount = maxi(int(resource.get_total() * offer_amount_fraction), min_offer_amount)
	var premium: float = randf_range(premium_range.x, premium_range.y) + premium_bonus
	contract.unit_price = maxi(ceili(Global.market_manager.get_sell_price(resource) * premium), 1)
	contract.deadline_cycle = Global.time_manager.cycle + randi_range(min_deadline_cycles, max_deadline_cycles)
	contract.penalty = maxi(int(contract.total_payout() * penalty_fraction), 1)
	contract.issuer = String(issuer_names.pick_random()) if not issuer_names.is_empty() else "A trading house"
	contract.offered_cycle = Global.time_manager.cycle
	offers.append(contract)
	SignalBus.contract_offered.emit(contract)
	# Both halves (WI-57): an offer is the textbook case of a notification that is
	# "look at this now" *and* "this arrived and you can read it later" - it is an
	# approach from a trading house with terms, and the terms outlive the alert.
	AlertManager.transmit(AlertRules.make_id(&"contract_offered", contract.id),
		AlertData.Priority.HIGH, "Contract offered",
		"%s · %d %s by cycle %d" % [contract.issuer, contract.amount, resource.name,
		contract.deadline_cycle],
		&"contract", contract.issuer,
		("We will take %d %s at %d credits a unit, delivered to your bay by cycle %d."
			+ " Fail to ship and the penalty is %d credits.")
			% [contract.amount, resource.name, contract.unit_price,
			contract.deadline_cycle, contract.penalty],
		&"trade", null, "%d contracts are on offer")
	contracts_changed.emit()
	return contract

# --- accept / decline -------------------------------------------------------------

## "" = accepting is currently allowed; otherwise a player-facing reason.
func accept_block_reason() -> String:
	if active.size() >= max_active:
		return "Contract limit reached (%d)" % max_active
	if Global.trader_manager.find_trade_bay() == null:
		return "No docking bay"
	return ""

func accept(contract: ContractData) -> bool:
	if contract == null or contract.state != ContractData.State.OFFERED:
		return false
	if not offers.has(contract) or accept_block_reason() != "":
		return false
	offers.erase(contract)
	# The offer is no longer on the table, so its sticky alert should not be
	# either - a HIGH row the player has already acted on is exactly the clutter
	# that trains dismissal reflexes (WI-53).
	AlertManager.resolve_alert(AlertRules.make_id(&"contract_offered", contract.id))
	contract.state = ContractData.State.ACCEPTED
	active.append(contract)
	# Demand registers on the bay via the next _sync_demand tick.
	SignalBus.contract_accepted.emit(contract)
	contracts_changed.emit()
	return true

## Declined offers simply disappear (WI-14 edge case) - no history entry.
func decline(contract: ContractData) -> void:
	if offers.has(contract):
		offers.erase(contract)
		AlertManager.resolve_alert(AlertRules.make_id(&"contract_offered", contract.id))
		contracts_changed.emit()

# --- fulfillment ------------------------------------------------------------------

## Units of a contract's goods currently sitting in the export bin and
## earmarked for it (for the progress UI).
func staged_for(contract: ContractData) -> int:
	if _demand_component == null or not is_instance_valid(_demand_component):
		return 0
	var stock: int = _demand_component.storage.total_stored_by_resource(contract.resource)
	# Earlier active contracts on the same resource claim the stock first.
	for other: ContractData in active:
		if other == contract:
			break
		if other.resource == contract.resource:
			stock -= other.remaining()
	return clampi(stock, 0, contract.remaining())

## Called by TraderManager while any trader/courier is docked, BEFORE generic
## sell orders fulfill - contract allocation beats generic sales (WI-14).
## Contract goods are consigned to the issuer, so they consume no trader
## cargo space and never touch the shared market. Returns true if anything
## was picked up.
func collect_contract_goods(bay_trade: TradeComponent) -> bool:
	if bay_trade == null:
		return false
	var collected: bool = false
	# Iterate over a copy: completion mutates `active`.
	for contract: ContractData in active.duplicate():
		var in_bin: int = bay_trade.storage.total_stored_by_resource(contract.resource)
		var take: int = mini(contract.remaining(), in_bin)
		if take <= 0:
			continue
		if not bay_trade.storage.withdraw(contract.resource, take):
			continue
		bay_trade.reduce_contract_demand(contract.resource, take)
		contract.delivered += take
		# Delivered goods leave the station (WI-26): they count toward tier goals
		# just like a plain trader sale (verification 2 fills bars from both paths).
		SignalBus.resources_exported.emit(contract.resource, take)
		collected = true
		if contract.remaining() <= 0:
			_complete(contract)
	if collected:
		contracts_changed.emit()
	return collected

func _complete(contract: ContractData) -> void:
	contract.state = ContractData.State.FULFILLED
	active.erase(contract)
	# Contract payouts are income - the ARC levy applies (WI-25).
	var net: int = Global.economy_manager.record_income(contract.total_payout(), &"contract")
	Global.resource_manager.credit_resource.change_global_total(net)
	reputation += 1
	_push_history(contract)
	SignalBus.contract_completed.emit(contract)
	AlertManager.resolve_alert(AlertRules.make_id(&"contract_due", contract.id))
	AlertManager.raise_alert(AlertRules.make_id(&"contract_done", contract.id),
		AlertData.Priority.HIGH, "Contract fulfilled",
		"%s · +%d credits" % [contract.issuer, contract.total_payout()], null, &"trade")
	contracts_changed.emit()

# --- deadlines & resolution --------------------------------------------------------

func _on_cycle_changed(cycle: int) -> void:
	# Iterate over a copy: failing mutates `active`.
	for contract: ContractData in active.duplicate():
		if cycle > contract.deadline_cycle:
			_fail(contract)
		elif cycle == contract.deadline_cycle and not contract.deadline_warned:
			contract.deadline_warned = true
			# CRITICAL (WI-53): the penalty lands at the end of *this* cycle, and a
			# cycle is four real minutes - long enough to miss and short enough
			# that there is still time to ship if the player is told now.
			AlertManager.raise_alert(AlertRules.make_id(&"contract_due", contract.id),
				AlertData.Priority.CRITICAL, "Contract due this cycle",
				"%s · %d %s still owed" % [contract.issuer, contract.remaining(),
				contract.resource.name], null, &"trade", "%d contracts are due this cycle")

## All-or-nothing bonus: goods already shipped only earn ordinary market sell
## price, and the penalty lands on top. Credits may go negative - debt is the
## game-over pressure valve (WI-13/14 edge case).
func _fail(contract: ContractData) -> void:
	contract.state = ContractData.State.FAILED
	active.erase(contract)
	var salvage_pay: int = contract.delivered * Global.market_manager.get_sell_price(contract.resource)
	Global.resource_manager.credit_resource.change_global_total(salvage_pay - contract.penalty)
	# A penalty is a cost, not negative income: it bypasses the levy but still
	# shows on the economy page (WI-25 edge case). Salvage on partial goods is a
	# loss recovery, deliberately not booked as levy-eligible income.
	Global.economy_manager.record_external_cost(contract.penalty, &"penalty")
	if _demand_component != null and is_instance_valid(_demand_component):
		_demand_component.release_contract_demand(contract.resource, contract.remaining())
	_push_history(contract)
	SignalBus.contract_failed.emit(contract)
	AlertManager.resolve_alert(AlertRules.make_id(&"contract_due", contract.id))
	AlertManager.raise_alert(AlertRules.make_id(&"contract_failed", contract.id),
		AlertData.Priority.HIGH, "Contract failed",
		"%s · penalty -%d credits%s" % [contract.issuer, contract.penalty,
		" · partial goods paid %d" % salvage_pay if salvage_pay > 0 else ""], null, &"trade")
	contracts_changed.emit()

func _push_history(contract: ContractData) -> void:
	history.push_front(contract)
	while history.size() > history_cap:
		history.pop_back()

# --- demand sync & courier dispatch -------------------------------------------------

func _on_slow_tick(_interval: float) -> void:
	_sync_demand()
	_check_courier_dispatch()

## Keeps contract demand registered on whichever constructed bay currently
## exists. Handles accept, load restore, bay destruction, and rebuilt bays
## with one comparison.
func _sync_demand() -> void:
	var bay: ModuleBase = Global.trader_manager.find_trade_bay()
	var component: TradeComponent = null
	if bay != null:
		component = bay.get_component_by_type(TradeComponent) as TradeComponent
	if component == _demand_component:
		if component != null:
			_ensure_demand_amounts(component)
		return
	# Old bay gone (or replaced): its component died with it, nothing to release.
	_demand_component = component
	if component == null:
		if not active.is_empty() and not _bay_lost_alerted:
			_bay_lost_alerted = true
			AlertManager.raise_alert(&"no_docking_bay", AlertData.Priority.HIGH,
				"No docking bay", "Active contracts cannot ship", null, &"build")
		return
	_bay_lost_alerted = false
	_ensure_demand_amounts(component)

## Demand on the component must equal the sum of remaining() across active
## contracts per resource - top up or release the difference.
func _ensure_demand_amounts(component: TradeComponent) -> void:
	var wanted: Dictionary[ResourceData, int] = {}
	for contract: ContractData in active:
		wanted[contract.resource] = wanted.get(contract.resource, 0) + contract.remaining()
	for resource: ResourceData in wanted:
		var diff: int = wanted[resource] - component.contract_demand.get(resource, 0)
		if diff > 0:
			component.add_contract_demand(resource, diff)
	for resource: ResourceData in component.contract_demand.keys():
		var over: int = component.contract_demand[resource] - wanted.get(resource, 0)
		if over > 0:
			component.release_contract_demand(resource, over)

## Final-day rescue (WI-14 edge case): if a contract reaches its last cycle
## fully staged but no trader is around, the issuer sends a courier that only
## picks up contract goods.
func _check_courier_dispatch() -> void:
	if Global.trader_manager.visit_active or Global.trader_manager.is_inbound():
		return
	if _demand_component == null or not is_instance_valid(_demand_component):
		return
	var cycle: int = Global.time_manager.cycle
	for contract: ContractData in active:
		if contract.is_final_cycle(cycle) and staged_for(contract) >= contract.remaining():
			if Global.trader_manager.dispatch_contract_courier():
				SignalBus.station_alert.emit("%s dispatched a courier for their contract goods" % contract.issuer)
			return

# --- persistence ------------------------------------------------------------------

func get_save_data() -> Dictionary:
	var out: Dictionary = {
		"next_id": _next_id,
		"reputation": reputation,
		"offers": [],
		"active": [],
		"history": [],
	}
	for contract: ContractData in offers:
		out["offers"].append(contract.to_dict())
	for contract: ContractData in active:
		out["active"].append(contract.to_dict())
	for contract: ContractData in history:
		out["history"].append(contract.to_dict())
	return out

## Loads after world/market: demand re-registers on the restored bay via the
## first _sync_demand tick, and staged-but-unshipped goods are already back
## in the bin from the module save.
func load_save_data(data: Dictionary) -> void:
	_next_id = int(data.get("next_id", 1))
	reputation = int(data.get("reputation", 0))
	offers.clear()
	active.clear()
	history.clear()
	_demand_component = null
	for entry: Dictionary in data.get("offers", []):
		var contract: ContractData = ContractData.from_dict(entry)
		if contract != null:
			offers.append(contract)
	for entry: Dictionary in data.get("active", []):
		var contract: ContractData = ContractData.from_dict(entry)
		if contract != null:
			active.append(contract)
	for entry: Dictionary in data.get("history", []):
		var contract: ContractData = ContractData.from_dict(entry)
		if contract != null:
			history.append(contract)
	contracts_changed.emit()
