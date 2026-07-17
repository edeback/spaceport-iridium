class_name EventConditionMinCredits
extends EventCondition

## Eligible only while the station holds at least this many credits - gates
## "someone wants your money" events (the ARC levy) off broke stations.

@export var min_credits: int = 0

func is_met() -> bool:
	return Global.resource_manager.credit_resource.get_total() >= min_credits
