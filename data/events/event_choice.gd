class_name EventChoice
extends Resource

## One button on an event card (WI-13): a label, an optional up-front cost,
## and the effects applied when picked. A choice with a cost the player can't
## afford renders disabled; every event must keep at least one cost-free
## choice (validated by EventManager at load).

@export var label: String = ""
## Optional flavor line shown under the button label.
@export var description: String = ""
## Withdrawn when the choice is picked. Same shape as UnlockData.cost.
@export var cost: Dictionary[ResourceData, int] = {}
@export var effects: Array[EventEffect] = []

func can_afford() -> bool:
	for resource: ResourceData in cost:
		if resource.get_total() < cost[resource]:
			return false
	return true

func withdraw_cost() -> void:
	for resource: ResourceData in cost:
		resource.force_withdraw(cost[resource])

func cost_text() -> String:
	var parts: Array[String] = []
	for resource: ResourceData in cost:
		parts.append("%d %s" % [cost[resource], resource.name])
	return ", ".join(parts)
