class_name EventEffectMarketSupplyShock
extends EventEffect

## Multiplies one resource's market supply for a while: <1 = scarcity (price
## spikes, stock snaps down), >1 = glut (price crashes). MarketManager owns
## the countdown and expiry; prices drift back once the modifier lapses.

@export var resource: ResourceData
## Supply multiplier while active. 0.3 = supply collapses to 30%.
@export var multiplier: float = 0.5
@export var duration_hours: float = 24.0

func apply(_event: EventData) -> void:
	if resource != null:
		Global.market_manager.apply_supply_modifier(resource, multiplier, duration_hours)

func describe() -> String:
	if resource == null:
		return ""
	var direction: String = "shortage" if multiplier < 1.0 else "glut"
	return "%s %s for %dh" % [resource.name, direction, int(duration_hours)]
