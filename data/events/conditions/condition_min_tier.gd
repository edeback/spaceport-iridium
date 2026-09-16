class_name EventConditionMinTier
extends EventCondition

## Eligible only from a given station tier (WI-67).
##
## Added for hull breaches: at Tier 1 the crew live in pressure suits, so a breach
## harms nobody - it is a CRITICAL alert that stops the sim over something with no
## consequence, which is exactly the noise this item exists to remove. From Tier 2
## the crew are out of their suits and a breach is a genuine emergency.
##
## Generic rather than a hardcoded "not at Tier 1", because the next tier-gated
## event will want the same gate at a different number - the same bargain
## EventConditionDiseaseUnlocked struck for the outbreak event.

@export var min_tier: int = 2

func is_met() -> bool:
	if Global.unlock_manager == null:
		return false
	return Global.unlock_manager.current_tier >= min_tier
