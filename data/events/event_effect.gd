class_name EventEffect
extends Resource

## Base class for what an event actually does (WI-13). Composed onto
## EventChoice.effects (or EventData.auto_effects for notification events).
## apply() runs once when the owning choice is picked; timed effects
## (market shocks, happiness modifiers) register their countdown state on the
## relevant manager so expiry and save/load live in one place.

func apply(_event: EventData) -> void:
	pass

## Short player-facing summary shown on the event card ("-300 credits").
## Empty = not shown.
func describe() -> String:
	return ""
