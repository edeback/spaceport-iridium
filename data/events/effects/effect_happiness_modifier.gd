class_name EventEffectHappinessModifier
extends EventEffect

## Station-wide timed happiness modifier: applied to every current crew
## member's PawnNeedsComponent, and tracked by EventManager so crew hired
## while it's active get it too and the remaining duration survives
## save/load (per-pawn modifiers themselves aren't persisted).

## Modifier id - re-applying the same id refreshes rather than stacks.
@export var id: StringName = &""
## Direct addition to 0..1 happiness (negative = penalty).
@export var value: float = -0.1
@export var duration_hours: float = 24.0

func apply(_event: EventData) -> void:
	var effect_id: StringName = id if id != &"" else StringName("event_" + String(_event.id))
	Global.event_manager.apply_station_happiness(effect_id, value, duration_hours)

func describe() -> String:
	return "crew morale %+d%% for %dh" % [int(value * 100.0), int(duration_hours)]
