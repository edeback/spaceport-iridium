class_name EventConditionMinCrew
extends EventCondition

## Eligible only with at least this many (staying) crew - events that need
## hands, or morale events that need someone to have morale.

@export var min_crew: int = 1

func is_met() -> bool:
	return Global.crew_manager.crew_count(false) >= min_crew
