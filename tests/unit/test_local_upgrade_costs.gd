extends GutTest

## Unit tests for LocalUpgradeData.get_cost_for_tier (data/local_upgrades/
## local_upgrade_data.gd) - the per-tier cost scaling for repeat-purchasable
## module upgrades. Pure function: scaled = round(base * growth^tier), applied
## to every resource in the cost dict. (can_afford/withdraw_cost reach into
## Global resource stores and aren't covered here.)

var ore: ResourceData
var credits: ResourceData

func before_each() -> void:
	ore = ResourceData.new()
	ore.id = &"ore"
	credits = ResourceData.new()
	credits.id = &"credits"

func _upgrade(base_cost: Dictionary[ResourceData, int], growth: float) -> LocalUpgradeData:
	var upg := LocalUpgradeData.new()
	upg.cost = base_cost
	upg.cost_growth = growth
	return upg

func test_tier_zero_is_the_base_cost() -> void:
	var cost: Dictionary[ResourceData, int] = {}
	cost[ore] = 10
	var upg := _upgrade(cost, 2.0)
	assert_eq(upg.get_cost_for_tier(0)[ore], 10, "growth^0 = 1, so tier 0 is unscaled")

func test_growth_scales_geometrically() -> void:
	var cost: Dictionary[ResourceData, int] = {}
	cost[ore] = 10
	var upg := _upgrade(cost, 2.0)
	assert_eq(upg.get_cost_for_tier(1)[ore], 20, "tier 1 = base * growth")
	assert_eq(upg.get_cost_for_tier(2)[ore], 40, "tier 2 = base * growth^2")
	assert_eq(upg.get_cost_for_tier(3)[ore], 80, "tier 3 = base * growth^3")

func test_flat_cost_when_growth_is_one() -> void:
	var cost: Dictionary[ResourceData, int] = {}
	cost[ore] = 25
	var upg := _upgrade(cost, 1.0)
	assert_eq(upg.get_cost_for_tier(0)[ore], 25)
	assert_eq(upg.get_cost_for_tier(5)[ore], 25, "growth 1.0 keeps every tier the same")

func test_all_resources_in_the_cost_scale() -> void:
	var cost: Dictionary[ResourceData, int] = {}
	cost[ore] = 10
	cost[credits] = 100
	var upg := _upgrade(cost, 2.0)
	var tier1: Dictionary[ResourceData, int] = upg.get_cost_for_tier(1)
	assert_eq(tier1[ore], 20, "ore scales")
	assert_eq(tier1[credits], 200, "credits scale by the same factor")

func test_cost_rounds_to_nearest_int() -> void:
	var cost: Dictionary[ResourceData, int] = {}
	cost[ore] = 10
	var upg := _upgrade(cost, 1.2)
	# 10 * 1.2^2 = 14.4 -> rounds down to 14
	assert_eq(upg.get_cost_for_tier(2)[ore], 14, "14.4 rounds down")

func test_cost_rounds_half_away_from_zero() -> void:
	var cost: Dictionary[ResourceData, int] = {}
	cost[ore] = 5
	var upg := _upgrade(cost, 1.5)
	# 5 * 1.5 = 7.5 -> rounds up to 8
	assert_eq(upg.get_cost_for_tier(1)[ore], 8, "7.5 rounds up")
