class_name EventConditionDiseaseUnlocked
extends EventCondition

## Eligible only when at least one infectious disease is unlocked at the current
## station tier (WI-31). Gates the outbreak event so it can never fire - nor be
## force-fired with nothing to pick - on a Tier-1 station that has no disease.

func is_met() -> bool:
	if Global.unlock_manager == null:
		return false
	return not DiseaseData.outbreak_pool(Global.unlock_manager.current_tier).is_empty()
