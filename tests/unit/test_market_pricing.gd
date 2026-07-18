extends GutTest

## Unit tests for MarketManager pricing (scripts/managers/market_manager.gd).
## get_base_price/get_buy_price/get_sell_price and the supply-modifier math read
## only market_data + resource fields, so we instantiate the manager WITHOUT
## adding it to the tree (its _ready, which reaches for Global, never runs) and
## fill market_data by hand.
##
## Pricing model: base = default_cost * 2^((default_supply - stock)/default_supply)
##   - stock == default_supply -> 1x (the reference price)
##   - stock == 0 (scarce)     -> 2x
##   - stock == 2*default      -> 0.5x (glut)

var market: MarketManager
var ore: ResourceData

func before_each() -> void:
	market = MarketManager.new()
	autofree(market) # never entered the tree; free() at test end
	ore = ResourceData.new()
	ore.id = &"ore"
	ore.default_cost = 10
	ore.default_market_supply = 100

func _set_stock(stock: int) -> void:
	market.market_data[ore] = stock

# --- base price ---------------------------------------------------------------

func test_base_price_at_reference_supply_equals_default_cost() -> void:
	_set_stock(100)
	assert_almost_eq(market.get_base_price(ore), 10.0, 0.001, "stock == supply -> default cost")

func test_scarcity_doubles_base_price() -> void:
	_set_stock(0)
	assert_almost_eq(market.get_base_price(ore), 20.0, 0.001, "empty market -> 2x")

func test_glut_halves_base_price() -> void:
	_set_stock(200)
	assert_almost_eq(market.get_base_price(ore), 5.0, 0.001, "double supply -> 0.5x")

func test_unknown_resource_has_zero_base_price() -> void:
	var mystery := ResourceData.new()
	mystery.id = &"unlisted"
	assert_eq(market.get_base_price(mystery), 0.0, "not in market_data -> 0")

# --- buy / sell wrappers ------------------------------------------------------

func test_buy_price_applies_multiplier_and_ceils() -> void:
	ore.default_cost = 7
	_set_stock(100) # base = 7.0
	# ceil(7.0 * 1.5) = ceil(10.5) = 11
	assert_eq(market.get_buy_price(ore), 11, "buy = ceil(base * purchase multiplier)")

func test_sell_price_applies_multiplier_and_floors() -> void:
	ore.default_cost = 7
	_set_stock(100) # base = 7.0
	# floor(7.0 * 0.5) = floor(3.5) = 3
	assert_eq(market.get_sell_price(ore), 3, "sell = floor(base * sell multiplier)")

func test_buy_price_exceeds_sell_price() -> void:
	_set_stock(100)
	assert_gt(market.get_buy_price(ore), market.get_sell_price(ore), "the spread always favors the market")

func test_custom_multipliers_are_honored() -> void:
	market.purchase_price_multiplier = 2.0
	_set_stock(100) # base = 10.0
	assert_eq(market.get_buy_price(ore), 20, "2x purchase multiplier on a base of 10")

# --- timed supply modifiers (WI-13) ------------------------------------------

func test_effective_supply_defaults_to_resource_supply() -> void:
	assert_eq(market.effective_supply(ore), 100, "no modifiers -> the resource's default supply")

func test_supply_modifier_scales_effective_supply() -> void:
	_set_stock(100)
	market.apply_supply_modifier(ore, 2.0, 5.0)
	assert_eq(market.effective_supply(ore), 200, "a 2x supply shock doubles the drift target")
	assert_almost_eq(market.get_supply_modifier(ore), 2.0, 0.001)

func test_supply_modifiers_stack_multiplicatively() -> void:
	_set_stock(100)
	market.apply_supply_modifier(ore, 2.0, 5.0)
	market.apply_supply_modifier(ore, 1.5, 5.0)
	assert_almost_eq(market.get_supply_modifier(ore), 3.0, 0.001, "2x then 1.5x = 3x")
	assert_eq(market.effective_supply(ore), 300)

func test_supply_modifier_snaps_current_stock() -> void:
	_set_stock(100)
	market.apply_supply_modifier(ore, 2.0, 5.0)
	assert_eq(market.get_quantity_available(ore), 200, "stock snaps immediately so price jumps at once")
