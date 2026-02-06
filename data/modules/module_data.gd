class_name ModuleData
extends Resource

@export var name: String = ""
@export var description: String = ""
@export var scene: PackedScene
@export var icon: Texture2D
@export var resource_costs: Dictionary[ResourceData, int]
@export var tags: Array[String]
## Can you click-drag to place multiples?
@export var multiplacement: bool = false
## If hidden, does not show in UI
@export var hidden: bool = false

@export var interaction_layer: WorldManager.InteractionLayer = WorldManager.InteractionLayer.MODULE

@export var flippable: bool = false
@export var flipped_scene: PackedScene


func can_afford() -> bool:
	for resource in resource_costs:
		if resource.get_total() < resource_costs[resource]:
			return false
	return true

## TODO Mostly debug as instantly withdraws instead of setting up jobs
func withdraw_cost() -> void:
	for resource in resource_costs:
		resource.force_withdraw(resource_costs[resource])
