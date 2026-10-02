class_name UnlockData
extends Resource

## A single node in a global tech tree. Authored as a .tres under
## res://data/unlocks/. Definition only - which nodes are actually unlocked is
## runtime state held by UnlockManager, never stored back onto this resource.

## Stable identifier, used for save/load and as the source id of any stat
## modifiers this unlock registers. Must be unique and non-empty.
@export var id: StringName
@export var name: String = ""
@export var description: String = ""
@export var icon: Texture2D
## Which themed tree this node belongs to (used to group the UI panel).
@export var tree_id: StringName = &"general"
## Credits and/or other resources required to purchase. Credits are just a
## ResourceData (Global.resource_manager.credit_resource), matching module costs.
@export var cost: Dictionary[ResourceData, int]
## Must all be unlocked before this becomes purchasable.
@export var prerequisites: Array[UnlockData]
## Lasting effects applied once, at the moment this is unlocked.
@export var effects: Array[UnlockEffect]
## Some techs are unlocked by default in order to give the tech tree a starting node
@export var unlocked_by_default: bool = false
## Minimum station tier (WI-26) before this node is purchasable. 1 = available
## from the start (today's behavior). Higher values render the node tier-locked
## in the unlock panel until the station is promoted; UnlockManager.can_unlock
## enforces it. The re-bucketing of existing nodes across tiers lives in the
## authored .tres, not here.
@export var min_tier: int = 1

## Pure tier gate (WI-26): is the station high enough for this node? Extracted so
## it's unit-testable without Global (UnlockManager.meets_tier calls it).
func available_at_tier(current_tier: int) -> bool:
	return current_tier >= min_tier

## The station tier the R&D panel opens at (2026-10-02): the lowest `min_tier` of
## any node that does not start owned. Below it the panel holds nothing the player
## can buy, so the console disables it rather than open onto a wall of locks.
##
## Read off the data rather than a `current_tier < 2` test, for the WI-26 reason
## [member TierData.suits_mandatory] gives: a mod - or a rebalance - that moves a
## node to Tier 1 opens R&D at Tier 1 without anyone remembering this rule.
##
## Prerequisites are deliberately not walked. A node whose own gate is lower than
## a prerequisite's can open the panel a tier early, onto nothing affordable; the
## min_tier alone can never open it late, which is the direction that would hide
## something the player could buy. No purchasable node at all is no gate - a
## panel with nothing to sell is still the tree.
static func research_opens_at(unlocks: Array[UnlockData]) -> int:
	var lowest: int = 0
	var found: bool = false
	for unlock: UnlockData in unlocks:
		if unlock == null or unlock.unlocked_by_default:
			continue
		lowest = mini(lowest, unlock.min_tier) if found else unlock.min_tier
		found = true
	return maxi(lowest, 1)

func can_afford() -> bool:
	for resource: ResourceData in cost:
		if resource.get_total() < cost[resource]:
			return false
	return true

func withdraw_cost() -> void:
	for resource: ResourceData in cost:
		resource.force_withdraw(cost[resource])
