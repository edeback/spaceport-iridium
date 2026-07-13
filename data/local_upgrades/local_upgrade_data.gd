class_name LocalUpgradeData
extends Resource

## An upgrade that can be purchased on an individual built module (increased
## output, faster processing, lower power, ...). Definition only - which modules
## have bought it, and to what tier, is per-instance runtime state held on each
## ModuleBase. Two modules of the same type can therefore differ.
##
## Authored as a .tres under res://data/local_upgrades/.

## Stable identifier. Used as the StatModifiers source id, so every tier of this
## upgrade stacks under one source and can be counted/removed together.
@export var id: StringName
@export var name: String = ""
@export var description: String = ""
@export var icon: Texture2D
## Modules with ANY of these tags can receive this upgrade. Empty = all modules.
@export var applies_to: Array[String] = []
## If set, this upgrade stays hidden until the given global unlock is purchased.
## This is how a global tech "opens up" local upgrades on a module type.
@export var required_global_unlock: UnlockData
## Other local upgrades that must already be applied (tier >= 1) on the SAME
## module before this one becomes available.
@export var prerequisites: Array[LocalUpgradeData]
## How many times this can be purchased on one module. 1 = one-shot.
@export var max_tiers: int = 1
## Base cost of the first tier (tier 0). Credits are just a ResourceData.
@export var cost: Dictionary[ResourceData, int]
## Multiplies the base cost per tier: tier 0 = base, tier 1 = base*growth,
## tier 2 = base*growth^2, ... Leave at 1.0 for a flat per-tier cost.
@export var cost_growth: float = 1.0
## Modifiers applied to the module each time a tier is purchased. Because they
## all share this upgrade's id as their source, tiers stack automatically.
@export var modifiers: Array[StatModifierSpec] = []

func matches_module(module_data: ModuleData) -> bool:
	if module_data == null:
		return false
	if applies_to.is_empty():
		return true
	for tag: String in applies_to:
		if module_data.tags.has(tag):
			return true
	return false

func is_globally_unlocked() -> bool:
	if required_global_unlock == null:
		return true
	if Global.unlock_manager == null:
		return false
	return Global.unlock_manager.is_unlocked(required_global_unlock)

## Cost of purchasing the given (0-based) tier, after growth scaling.
func get_cost_for_tier(tier: int) -> Dictionary[ResourceData, int]:
	var scaled: Dictionary[ResourceData, int] = {}
	var factor: float = pow(cost_growth, tier)
	for resource: ResourceData in cost:
		scaled[resource] = int(round(cost[resource] * factor))
	return scaled

func can_afford(tier: int) -> bool:
	var scaled := get_cost_for_tier(tier)
	for resource: ResourceData in scaled:
		if resource.get_total() < scaled[resource]:
			return false
	return true

func withdraw_cost(tier: int) -> void:
	var scaled := get_cost_for_tier(tier)
	for resource: ResourceData in scaled:
		resource.force_withdraw(scaled[resource])
