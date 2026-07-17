class_name EventEffectHullBreach
extends EventEffect

## Opens a hull breach in a random built module with atmosphere (WI-17).
## The module vents to space fast; emergency bulkheads self-seal after
## `duration_hours` (repair jobs arrive with combat, later). A strike on an
## already-breached module refreshes its timer instead of stacking.

@export var duration_hours: float = 2.0

func apply(_event: EventData) -> void:
	if Global.atmosphere_manager == null:
		return
	var target: AtmosphereComponent = Global.atmosphere_manager.get_random_breach_target()
	if target != null:
		target.start_breach(duration_hours)

func describe() -> String:
	return "Hull breach (~%dh to seal)" % int(ceil(duration_hours))
