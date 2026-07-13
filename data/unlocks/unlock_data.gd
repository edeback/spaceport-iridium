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

func can_afford() -> bool:
	for resource: ResourceData in cost:
		if resource.get_total() < cost[resource]:
			return false
	return true

func withdraw_cost() -> void:
	for resource: ResourceData in cost:
		resource.force_withdraw(cost[resource])
