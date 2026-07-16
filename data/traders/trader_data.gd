class_name TraderData
extends Resource

## One visiting trader's identity and inventory (WI-08). A data object, not a
## ship sim: what they carry to sell us, how their prices skew from the
## market, and how much cargo room they have for goods they buy from us.
## TraderManager duplicates profiles at visit start - stock mutates as the
## visit's trades fulfill.

@export var id: StringName = &""
@export var trader_name: String = "Trader"
## What the trader carries (available for the station to buy).
@export var stock: Dictionary[ResourceData, int] = {}
## Per-resource multiplier applied to BOTH market prices for this trader:
## <1 on a resource they're flush with = they sell it to us cheap;
## >1 = they pay us above market for it. Missing = 1.0.
@export var price_multipliers: Dictionary[ResourceData, float] = {}
## Total units of station goods this trader will buy before their hold is full.
@export var cargo_hold: int = 150

func price_multiplier(resource: ResourceData) -> float:
	return price_multipliers.get(resource, 1.0)
