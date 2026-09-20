class_name MarketManager
extends Node

## The base game's tradable list. A mod's resource joins by setting
## ResourceData.tradable rather than by reaching into this - see
## _tradable_resources().
@export var market_resources: Array[ResourceData]
## Built once from market_resources + everything declaring itself tradable.
var _tradable_cache: Array[ResourceData] = []
@export var purchase_price_multiplier: float = 1.5
@export var sell_price_multiplier: float = 0.5
## Share of the gap between a resource's effective supply and its current stock
## that closes each game-hour - 0.1 is a tenth of the way back per hour. Raise it
## and the market recovers faster from a big sale; 0 freezes stock where it is.
## Rounded away from zero (ceili), so a gap of any size moves by at least one unit
## an hour and the drift cannot stall short of its target (WI-72 §4).
@export var restock_drift_per_hour: float = 0.1

## Resource -> Current stock
var market_data: Dictionary[ResourceData, int] = {}

## Active timed supply modifiers (WI-13 market shocks): each entry is
## {"resource": ResourceData, "multiplier": float, "remaining": float
## game-hours}. They scale the drift TARGET (effective supply), so stock -
## and therefore price, which compares stock against the unmodified default -
## moves while a shock is active and drifts back after it expires.
var _supply_modifiers: Array[Dictionary] = []

signal market_updated

func _ready() -> void:
	Global.market_manager = self
	SaveManager.register_section(&"market", 40, get_save_data, load_save_data)
	for resource: ResourceData in _tradable_resources():
		market_data[resource] = resource.default_market_supply
	# Market supply drifts back toward default once per game-hour.
	Global.time_manager.hour_changed.connect(_on_hour_changed)

## Hands the slot back (WI-71 §7). Godot 4.7 reports a freed object as `== null`,
## so the guards around the game already take their null branch after a Quit to
## Menu - but `is_instance_valid(Global.market_manager)` and the debugger both lie until
## the slot is actually cleared. `== self` because a second scene can register
## before this one leaves.
func _exit_tree() -> void:
	if Global.market_manager == self:
		Global.market_manager = null


func _on_hour_changed(_hour: int) -> void:
	_expire_supply_modifiers(1.0)
	update_market()

func update_market() -> void:
	for resource: ResourceData in market_data:
		var cur_stock: int = market_data[resource]
		var diff: int = effective_supply(resource) - cur_stock
		market_data[resource] = cur_stock + ceili(diff * restock_drift_per_hour)
	market_updated.emit()

# --- timed supply modifiers (WI-13) -------------------------------------------

## Registers a temporary supply multiplier and snaps current stock by the
## same factor, so the price jump is immediate rather than waiting a full
## drift. snap_stock=false on the save/load path - saved stock already
## reflects the snap.
func apply_supply_modifier(resource: ResourceData, multiplier: float, duration_hours: float, snap_stock: bool = true) -> void:
	if resource == null or multiplier <= 0.0 or duration_hours <= 0.0:
		return
	_supply_modifiers.append({
		"resource": resource,
		"multiplier": multiplier,
		"remaining": duration_hours,
	})
	if snap_stock and market_data.has(resource):
		market_data[resource] = maxi(int(market_data[resource] * multiplier), 1)
	market_updated.emit()

## The drift target: default supply scaled by every active modifier on this
## resource (they stack multiplicatively).
func effective_supply(resource: ResourceData) -> int:
	var supply: float = float(resource.default_market_supply)
	for modifier: Dictionary in _supply_modifiers:
		if modifier["resource"] == resource:
			supply *= float(modifier["multiplier"])
	return maxi(int(supply), 1)

func get_supply_modifier(resource: ResourceData) -> float:
	var mult: float = 1.0
	for modifier: Dictionary in _supply_modifiers:
		if modifier["resource"] == resource:
			mult *= float(modifier["multiplier"])
	return mult

func _expire_supply_modifiers(hours: float) -> void:
	for i: int in range(_supply_modifiers.size() - 1, -1, -1):
		_supply_modifiers[i]["remaining"] = float(_supply_modifiers[i]["remaining"]) - hours
		if float(_supply_modifiers[i]["remaining"]) <= 0.0:
			_supply_modifiers.remove_at(i)
	
func get_tradeable_resources() -> Array[ResourceData]:
	return _tradable_resources()

## The authored list, plus every scanned resource that declares itself tradable
## (WI-47 audit sweep). market_resources is an @export on a node in main.tscn, so
## a mod's ore could never join the market, and TraderManager's stock and
## ContractManager's demand both read this list - all three were one gap.
##
## Cached: the answer can't change during a run, and this is called per trader
## visit and per contract roll.
func _tradable_resources() -> Array[ResourceData]:
	if not _tradable_cache.is_empty():
		return _tradable_cache
	_tradable_cache = market_resources.duplicate()
	for path: String in ContentPaths.scan(ContentPaths.RESOURCES):
		var resource: ResourceData = ResourceLoader.load(path) as ResourceData
		if resource != null and resource.tradable and not _tradable_cache.has(resource):
			_tradable_cache.append(resource)
	return _tradable_cache
		
func get_quantity_available(resource: ResourceData) -> int:
	if market_data.has(resource):
		return market_data[resource]
	return 0

func get_base_price(resource: ResourceData) -> float:
	if market_data.has(resource):
		var cur_stock: int = market_data[resource]
		var diff: float = resource.default_market_supply - cur_stock
		var multiplier: float = pow(2, diff / resource.default_market_supply)
		return resource.default_cost * multiplier
	return 0

func get_buy_price(resource: ResourceData) -> int:
	return ceili(get_base_price(resource) * purchase_price_multiplier)
	
func get_sell_price(resource: ResourceData) -> int:
	return floori(get_base_price(resource) * sell_price_multiplier)

func withdraw_resource(resource: ResourceData, amount: int) -> bool:
	if market_data.has(resource):
		var cur_stock: int = market_data[resource]
		if amount <= cur_stock:
			market_data[resource] = cur_stock - amount
			return true
	return false
	
func deposit_resource(resource: ResourceData, amount: int) -> bool:
	if market_data.has(resource):
		market_data[resource] += amount
		return true
	return false

# --- persistence -------------------------------------------------------------
# Shock state persists inside EventManager's save section (not here) so this
# section keeps its original flat resource->stock shape.

func get_supply_modifiers_save() -> Array:
	var out: Array = []
	for modifier: Dictionary in _supply_modifiers:
		var resource: ResourceData = modifier["resource"]
		if resource.id != &"":
			out.append({
				"resource": String(resource.id),
				"multiplier": float(modifier["multiplier"]),
				"remaining": float(modifier["remaining"]),
			})
	return out

func load_supply_modifiers_save(data: Array) -> void:
	_supply_modifiers.clear()
	for entry: Dictionary in data:
		var resource: ResourceData = Global.save_manager.get_resource_by_id(StringName(String(entry.get("resource", ""))))
		if resource != null:
			apply_supply_modifier(resource, float(entry.get("multiplier", 1.0)), float(entry.get("remaining", 0.0)), false)

func get_save_data() -> Dictionary:
	var out: Dictionary = {}
	for resource: ResourceData in market_data:
		if resource.id != &"":
			out[String(resource.id)] = market_data[resource]
	return out

func load_save_data(data: Dictionary) -> void:
	for resource: ResourceData in market_data:
		if data.has(String(resource.id)):
			market_data[resource] = int(data[String(resource.id)])
	market_updated.emit()
