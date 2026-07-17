class_name EventCondition
extends Resource

## Base class for an event's eligibility gates (WI-13). Composed onto
## EventData.conditions, mirroring the resource-with-virtual-method pattern
## of UnlockEffect/PathBehavior. Subclasses read live game state and return
## whether the event may fire right now.

func is_met() -> bool:
	return true
