class_name ModuleData
extends Resource

@export var name: String = ""
@export var description: String = ""
@export var scene: PackedScene
@export var icon: Texture2D
@export var instant_build: bool = true
@export var resource_costs: Dictionary[ResourceData, int]
@export var tags: Array[String]
## Can you click-drag to place multiples?
@export var multiplacement := WorldManager.Multiplacement.NONE
@export var ignore_multiplacement_connection_check: bool = false
## If hidden, does not show in UI
@export var hidden: bool = false

## If true, this module is buildable from the start. Set false for modules gated
## behind a global unlock - a GrantModuleEffect flips it on at runtime.
@export var unlocked_by_default: bool = true

## Where the structure is placed
@export var interaction_layer: WorldManager.StructureLayer = WorldManager.StructureLayer.MODULE
## Where the structure connects to, could be cross-layer
@export var connection_layer: WorldManager.StructureLayer = WorldManager.StructureLayer.MODULE

@export var flippable: bool = false
@export var flipped_scene: PackedScene

signal module_lock_changed(locked: bool)

func can_afford() -> bool:
	for resource in resource_costs:
		if resource.get_total() < resource_costs[resource]:
			return false
	return true

## TODO Mostly debug as instantly withdraws instead of setting up jobs
func withdraw_cost() -> void:
	for resource in resource_costs:
		resource.force_withdraw(resource_costs[resource])

func withdraw_credit_cost() -> void:
	var cost = resource_costs.get(Global.resource_manager.credit_resource, 0)
	if cost > 0:
		Global.resource_manager.credit_resource.force_withdraw(cost)

func is_unlocked() -> bool:
	if unlocked_by_default:
		return true
	if Global.unlock_manager != null:
		return Global.unlock_manager.is_module_granted(self)
	return false
