class_name MarketManager
extends Node

@export var market_resources: Array[ResourceData]
@export var purchase_price_multiplier: float = 1.5
@export var sell_price_multiplier: float = 0.5

## Resource -> Current stock
var market_data: Dictionary[ResourceData, int] = {}

signal market_updated

func _ready() -> void:
	Global.market_manager = self
	for resource: ResourceData in market_resources:
		market_data[resource] = resource.default_market_supply
	# Market supply drifts back toward default once per game-hour.
	Global.time_manager.hour_changed.connect(_on_hour_changed)

func _on_hour_changed(_hour: int) -> void:
	update_market()

func update_market() -> void:
	for resource: ResourceData in market_data:
		var cur_stock: int = market_data[resource]
		var diff: int = resource.default_market_supply - cur_stock
		market_data[resource] = cur_stock + ceili(diff * 0.1)
	market_updated.emit()
	
func get_tradeable_resources() -> Array[ResourceData]:
	return market_resources
		
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
