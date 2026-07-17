class_name EventData
extends Resource

## One random event definition (WI-13). Authored as a .tres under
## res://data/events/. Definition only - cooldowns, the pending queue, and
## timed-effect state are runtime state held by EventManager, never written
## back onto this shared resource.

## Stable identifier, used for save/load (cooldowns, pending queue). Must be
## unique and non-empty.
@export var id: StringName = &""
@export var title: String = ""
@export_multiline var body: String = ""
@export var icon: Texture2D
## Relative chance among eligible events when a natural roll fires.
@export var weight: float = 1.0
## Earliest cycle this event may occur naturally.
@export var min_cycle: int = 1
## Cycles after firing before this event is eligible again.
@export var cooldown_cycles: int = 4
## All must hold for the event to be eligible.
@export var conditions: Array[EventCondition] = []
## Zero choices = notification-only: effects of ALL choices would be
## meaningless, so notification events carry their effects here instead.
@export var choices: Array[EventChoice] = []
## Effects auto-applied when the event fires with no choices (notification
## events). Ignored when choices exist.
@export var auto_effects: Array[EventEffect] = []

func is_eligible(current_cycle: int) -> bool:
	if current_cycle < min_cycle:
		return false
	for condition: EventCondition in conditions:
		if condition != null and not condition.is_met():
			return false
	return true

## Every event with choices must keep at least one the player can always
## take, or the card would soft-lock (WI-13 edge case). Checked at load.
func has_free_choice() -> bool:
	if choices.is_empty():
		return true
	for choice: EventChoice in choices:
		if choice != null and choice.cost.is_empty():
			return true
	return false
